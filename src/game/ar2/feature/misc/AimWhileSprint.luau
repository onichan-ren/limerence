local RunService = cloneref(game:GetService("RunService")) :: RunService

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local StateReport = require("@game/ar2/network/stateReport")

local RENDER_BIND = "Limerence AR2 AimWhileSprint"
local RENDER_PRIORITY = Enum.RenderPriority.First.Value + 1

local AimWhileSprint = {}
AimWhileSprint.__index = AimWhileSprint

setmetatable(AimWhileSprint, { __index = BaseFeature })

local function shouldAim(character: any): boolean
	if not character or not character.AimingInput then
		return false
	end
	local item = character.EquippedItem
	return item ~= nil and item.AimFieldOfView ~= nil
end

function AimWhileSprint.new(link: gameUi.Linker): AimWhileSprint
	local self = BaseFeature.new() :: any
	setmetatable(self, AimWhileSprint)

	self._enabled = false
	self._character = nil :: any
	self._charConn = nil :: RBXScriptConnection?
	self._bound = false
	self._originalUseItem = nil :: any

	self._spoofer = function(overrides: { [number]: any }): ()
		if not self._enabled then
			return
		end
		if shouldAim(self._character) then
			overrides[StateReport.Field.Zooming] = true
		end
	end

	link:Toggle("aimWhileSprint", "Aim While Sprinting", false):SetTip({
		title = "Aim While Sprinting",
		body = "Keep aiming down sights while you sprint.",
	})

	self:Track(link:Get("aimWhileSprint"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("aimWhileSprint") then
		self:Enable()
	end

	return self
end

function AimWhileSprint.Enable(self: AimWhileSprint): ()
	if self._enabled then
		return
	end
	self._enabled = true

	StateReport.register(self._spoofer)

	local playersModule = ModuleController.GetModule("LocalPlayer")
	if not playersModule then
		return
	end

	local arLocalPlayer = playersModule.module.get()

	self._charConn = arLocalPlayer.CharacterAdded:Connect(function(character: any): ()
		self:_apply(character)
	end)
	self:_apply(arLocalPlayer.Character)

	RunService:BindToRenderStep(
		RENDER_BIND,
		RENDER_PRIORITY,
		LPH_NO_VIRTUALIZE(function(): ()
			local character = self._character
			if shouldAim(character) then
				character.Zooming = true
				character.Animator:SetState("Zooming", true)
			end
		end)
	)
	self._bound = true
end

function AimWhileSprint.Disable(self: AimWhileSprint): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	StateReport.unregister(self._spoofer)

	if self._bound then
		RunService:UnbindFromRenderStep(RENDER_BIND)
		self._bound = false
	end

	if self._charConn then
		self._charConn:Disconnect()
		self._charConn = nil
	end

	self:_restoreCharacter()
	self._character = nil
end

function AimWhileSprint._apply(self: AimWhileSprint, character: any): ()
	if not character or not character.Actions then
		return
	end

	self:_restoreCharacter()
	self._character = character

	local original = character.Actions.UseItem
	if type(original) ~= "function" then
		return
	end

	self._originalUseItem = original
	character.Actions.UseItem = function(actionSelf: any, ...): ...any
		if self._enabled and shouldAim(actionSelf) then
			actionSelf.Zooming = true
		end
		return original(actionSelf, ...)
	end
end

function AimWhileSprint._restoreCharacter(self: AimWhileSprint): ()
	local character = self._character
	if character and self._originalUseItem and character.Actions then
		character.Actions.UseItem = self._originalUseItem
	end
	self._originalUseItem = nil
end

function AimWhileSprint.Destroy(self: AimWhileSprint): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AimWhileSprint =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_character: any,
			_charConn: RBXScriptConnection?,
			_bound: boolean,
			_originalUseItem: any,
			_spoofer: (overrides: { [number]: any }) -> (),
		},
		AimWhileSprint
	))
	& BaseFeature.BaseFeature

return AimWhileSprint
