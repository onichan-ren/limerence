local viewmodelState = require("@game/bloxstrike/viewmodel/viewmodelState")
local localLookController = require("@game/bloxstrike/client/localLookController")
local cameraController = require("@game/bloxstrike/client/cameraController")
local thirdPersonWeaponRenderer = require("@game/bloxstrike/feature/visual/thirdperson/thirdPersonWeaponRenderer")
local clientState = require("@game/bloxstrike/client/clientState")
local spectateState = require("@game/bloxstrike/client/spectateState")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local RunService = cloneref(game:GetService("RunService")) :: RunService
local Camera = workspace.CurrentCamera
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local LocalPlayer = cloneref(game:GetService("Players").LocalPlayer) :: Player

local peek = Charm.peek
local sub = Charm.subscribe

local forceHideViewmodel = LPH_NO_VIRTUALIZE(function(viewmodel: any): ()
	if not viewmodel or type(viewmodel.hide) ~= "function" then
		return
	end
	if viewmodel.Model == nil then
		return
	end
	viewmodel.Hidden = false
	viewmodel.hide(viewmodel)
end)

local safeUnhide = LPH_NO_VIRTUALIZE(function(viewmodel: any): ()
	if not viewmodel or type(viewmodel.unhide) ~= "function" then
		return
	end
	if not viewmodel.Hidden then
		return
	end
	if viewmodel.Model == nil then
		viewmodel.Hidden = false
		return
	end
	viewmodel.unhide(viewmodel)
end)

local ThirdPerson = {}
ThirdPerson.__index = ThirdPerson

setmetatable(ThirdPerson, { __index = BaseFeature })

function ThirdPerson.new(link: gameUi.Linker): ThirdPerson
	local self = BaseFeature.new() :: any
	setmetatable(self, ThirdPerson)

	link:Toggle("thirdPerson", "Force Third Person", false):SetTip({
		title = "Force Third Person",
		body = "Pulls the camera back behind your character (or the spectated character) for a third-person view.",
	})
	local thirdPersonLink = link:OnKey("thirdPerson")
	thirdPersonLink:Submenu("opts", "Third Person Options")
	local optsLink = thirdPersonLink:OnKey("opts")
	optsLink:Toggle("forceInSpectator", "Force in Spectator", false):SetTip({
		title = "Force in Spectator",
		body = "Keeps the third-person offset active while spectating.",
	})
	optsLink:Slider("distance", "Distance", 8, 2, 100, 0.5, nil, "st"):SetTip({
		title = "Distance",
		body = "How far behind the character the camera sits.",
	})
	optsLink:Slider("shoulderX", "Shoulder X", 2, -4, 4, 0.1, nil, "st"):SetTip({
		title = "Shoulder X",
		body = "Shifts the camera left or right.",
	})
	optsLink:Slider("shoulderY", "Shoulder Y", 0.5, -4, 4, 0.1, nil, "st"):SetTip({
		title = "Shoulder Y",
		body = "Shifts the camera up or down.",
	})

	self._distance = optsLink:Get("distance"):Peek()
	self._shoulderX = optsLink:Get("shoulderX"):Peek()
	self._shoulderY = optsLink:Get("shoulderY"):Peek()
	self._forceInSpectator = optsLink:Get("forceInSpectator"):Peek()
	self._enabled = false
	self._janitor = Janitor.new()
	self._spectateInstance = nil
	self._spectateOriginalMethod = nil
	self._spectateOriginalTransparencyState = nil
	self._spectateViewmodelConn = nil
	self._lastSpectateViewmodel = nil
	self._localViewmodel = nil
	self._localViewmodelHadOwnUnhide = false
	self._localViewmodelOriginalUnhide = nil
	self._localViewmodelConn = nil :: RBXScriptConnection?
	self._suppressedHighlight = nil :: Highlight?

	self:Track(link:Get("thirdPerson"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optsLink:Get("distance"):OnChange(function(value: number): ()
		self._distance = value
	end))
	self:Track(optsLink:Get("shoulderX"):OnChange(function(value: number): ()
		self._shoulderX = value
	end))
	self:Track(optsLink:Get("shoulderY"):OnChange(function(value: number): ()
		self._shoulderY = value
	end))

	self:Track(optsLink:Get("forceInSpectator"):OnChange(function(value: boolean): ()
		self._forceInSpectator = value
	end))

	if link:Get("thirdPerson"):Peek() then
		self:Enable()
	end

	return self
end

ThirdPerson.Enable = LPH_NO_VIRTUALIZE(function(self: ThirdPerson): ()
	if self._enabled then
		return
	end
	self._enabled = true

	localLookController.SetThirdPerson(true)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.RespectCanCollide = true
	local filterScratch: { Instance } = {}

	self._janitor:Add(cameraController.Register(
		"thirdPerson",
		10,
		function(value: CFrame): CFrame
			localLookController.SetRealCameraCFrame(value)
			local alive = peek(clientState.alive)
			local force = self._forceInSpectator
			if not alive and not force then
				return value
			end
			local spectateInstance = peek(spectateState.instance)
			if not alive and force and not peek(clientState.isSpectating) then
				return value
			end
			local spectateCharacter = spectateInstance
					and (spectateInstance.Player and spectateInstance.Player.Character :: Model)
				or nil
			table.clear(filterScratch)
			local character = LocalPlayer.Character
			if character then
				filterScratch[#filterScratch + 1] = character
			end
			if spectateCharacter then
				filterScratch[#filterScratch + 1] = spectateCharacter
			end
			filterScratch[#filterScratch + 1] = Camera
			params.FilterDescendantsInstances = filterScratch
			local newValue = value * CFrame.new(self._shoulderX, self._shoulderY, self._distance)
			local result = Workspace:Raycast(value.Position, newValue.Position - value.Position, params)
			if result then
				newValue = value + (result.Position - value.Position)
			end
			return newValue
		end
	))

	self._janitor:Add(sub(spectateState.instance, function(instance: any): ()
		self:_onSpectateChanged(instance)
	end))
	self:_onSpectateChanged(peek(spectateState.instance))
	self._janitor:Add(function(): ()
		self:_unhookSpectate(true)
	end)

	local function detachLocalViewmodel(rehide: boolean): ()
		local vm = self._localViewmodel
		if not vm then
			return
		end
		self._localViewmodel = nil
		if self._localViewmodelHadOwnUnhide then
			vm.unhide = self._localViewmodelOriginalUnhide
		else
			rawset(vm, "unhide", nil)
		end
		self._localViewmodelHadOwnUnhide = false
		self._localViewmodelOriginalUnhide = nil
		if rehide then
			safeUnhide(vm)
		end
	end

	local function attachLocalViewmodel(viewmodel: any): ()
		if not viewmodel then
			detachLocalViewmodel(true)
			return
		end
		local sameViewmodel = self._localViewmodel == viewmodel
		if not sameViewmodel then
			detachLocalViewmodel(true)

			local existing = rawget(viewmodel, "unhide")
			self._localViewmodel = viewmodel
			self._localViewmodelHadOwnUnhide = existing ~= nil
			self._localViewmodelOriginalUnhide = existing

			viewmodel.unhide = function(_self: any): () end
		end

		forceHideViewmodel(viewmodel)
	end

	self._janitor:Add(sub(viewmodelState._viewmodel, attachLocalViewmodel))

	if self._localViewmodelConn then
		self._localViewmodelConn:Disconnect()
	end
	self._localViewmodelConn = RunService.Heartbeat:Connect(function(): ()
		local viewmodel = peek(viewmodelState._viewmodel)
		if viewmodel and not viewmodel.Hidden then
			forceHideViewmodel(viewmodel)
		end
	end)
	self._janitor:Add(function(): ()
		if self._localViewmodelConn then
			self._localViewmodelConn:Disconnect()
			self._localViewmodelConn = nil
		end
	end)

	self._janitor:Add(function(): ()
		detachLocalViewmodel(true)
	end)

	attachLocalViewmodel(peek(viewmodelState._viewmodel))

	local function suppressWarmupHighlight(instance: Instance): ()
		if instance.Name ~= "ViewmodelHighlight" or not instance:IsA("Highlight") then
			return
		end
		instance.Enabled = false
		self._suppressedHighlight = instance
	end

	for _, v in next, Camera:QueryDescendants("Highlight") do
		suppressWarmupHighlight(v)
	end
	self._janitor:Add(Camera.DescendantAdded:Connect(suppressWarmupHighlight))
	self._janitor:Add(function(): ()
		local highlight = self._suppressedHighlight
		self._suppressedHighlight = nil
		if highlight and highlight.Parent then
			highlight.Enabled = true
		end
	end)

	thirdPersonWeaponRenderer.enable()
	self._janitor:Add(function()
		thirdPersonWeaponRenderer.disable()
	end, true)
end)

ThirdPerson._unhookSpectate = LPH_NO_VIRTUALIZE(function(self: ThirdPerson, rehide: boolean): ()
	local previous = self._spectateInstance
	if self._spectateViewmodelConn then
		self._spectateViewmodelConn:Disconnect()
		self._spectateViewmodelConn = nil
	end

	local lastViewmodel = self._lastSpectateViewmodel
	if lastViewmodel then
		safeUnhide(lastViewmodel)
		self._lastSpectateViewmodel = nil
	end

	if not previous then
		self._spectateOriginalMethod = nil
		self._spectateOriginalTransparencyState = nil
		return
	end

	if self._spectateOriginalMethod then
		previous.SetCharacterTransparency = self._spectateOriginalMethod
	end

	if rehide then
		local restoredState = self._spectateOriginalTransparencyState
		if restoredState ~= nil then
			previous.TransparencyState = restoredState
			previous:SetCharacterTransparency(previous.TransparencyState)
		end
	end

	self._spectateInstance = nil
	self._spectateOriginalMethod = nil
	self._spectateOriginalTransparencyState = nil
end)

ThirdPerson._hookSpectate = LPH_NO_VIRTUALIZE(function(self: ThirdPerson, instance: any): ()
	local originalMethod = instance.SetCharacterTransparency
	self._spectateInstance = instance
	self._spectateOriginalMethod = originalMethod
	self._spectateOriginalTransparencyState = instance.TransparencyState
	instance.SetCharacterTransparency = function(self2: any, _value: boolean): ()
		self2.TransparencyState = false
		return originalMethod(self2, false)
	end
	instance.TransparencyState = false
	instance:SetCharacterTransparency(false)

	self._spectateViewmodelConn = RunService.Heartbeat:Connect(function(): ()
		local weaponComponent = instance.WeaponComponent
		local viewmodel = weaponComponent and weaponComponent.Viewmodel
		local last = self._lastSpectateViewmodel
		if last and last ~= viewmodel then
			safeUnhide(last)
			self._lastSpectateViewmodel = nil
		end
		if viewmodel then
			local isNewViewmodel = self._lastSpectateViewmodel ~= viewmodel
			if isNewViewmodel or not viewmodel.Hidden then
				forceHideViewmodel(viewmodel)
			end
			if isNewViewmodel then
				local model = viewmodel.Model
				local scopeCache = instance.WeaponTransparencyCache
				if model and scopeCache then
					for _, v in next, model:QueryDescendants("BasePart") do
						local trueOriginal = scopeCache[v]
						if trueOriginal ~= nil then
							v:SetAttribute("HiddenTransparency", trueOriginal)
						end
					end
				end
			end
			self._lastSpectateViewmodel = viewmodel
		end
	end)
end)

ThirdPerson._onSpectateChanged = LPH_NO_VIRTUALIZE(function(self: ThirdPerson, instance: any): ()
	if self._spectateInstance == instance then
		return
	end
	self:_unhookSpectate(false)
	if instance then
		self:_hookSpectate(instance)
	end
end)

ThirdPerson.Disable = LPH_NO_VIRTUALIZE(function(self: ThirdPerson): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self._janitor:Cleanup()
	localLookController.SetThirdPerson(false)
end)

function ThirdPerson.Destroy(self: ThirdPerson): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type ThirdPerson =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_distance: number,
			_shoulderX: number,
			_shoulderY: number,
			_forceInSpectator: boolean,
			_janitor: Janitor.Janitor,
			_spectateInstance: any?,
			_spectateOriginalMethod: any?,
			_spectateOriginalTransparencyState: any?,
			_spectateViewmodelConn: RBXScriptConnection?,
			_lastSpectateViewmodel: any?,
			_localViewmodel: any?,
			_localViewmodelHadOwnUnhide: boolean,
			_localViewmodelOriginalUnhide: any?,
			_localViewmodelConn: RBXScriptConnection?,
			_suppressedHighlight: Highlight?,
		},
		ThirdPerson
	))
	& BaseFeature.BaseFeature

return ThirdPerson
