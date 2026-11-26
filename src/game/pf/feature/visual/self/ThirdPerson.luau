local Players = cloneref(game:GetService("Players")) :: Players
local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/pf/module/ModuleController")
local localThirdPerson = require("@game/pf/thirdperson/localThirdPerson")

local LocalPlayer = Players.LocalPlayer

local ThirdPerson = {}
ThirdPerson.__index = ThirdPerson

setmetatable(ThirdPerson, { __index = BaseFeature })

function ThirdPerson.new(link: gameUi.Linker): ThirdPerson
	local self = BaseFeature.new() :: any
	setmetatable(self, ThirdPerson)

	link:Toggle("thirdPerson", "Third Person", false):SetTip({
		title = "Third Person",
		body = "Pulls the camera back to show your character from behind.",
	})
	local thirdPersonLink = link:OnKey("thirdPerson")
	thirdPersonLink:Submenu("opts", "Third Person Options")
	local optionsLink = thirdPersonLink:OnKey("opts")
	optionsLink:Slider("distance", "Distance", 8, 2, 100, 0.5, nil, "st"):SetTip({
		title = "Distance",
		body = "How far behind the character the camera sits.",
	})
	optionsLink:Slider("shoulderX", "Shoulder X", 2, -4, 4, 0.1, nil, "st"):SetTip({
		title = "Shoulder X",
		body = "Shifts the camera left or right.",
	})
	optionsLink:Slider("shoulderY", "Shoulder Y", 0.5, -4, 4, 0.1, nil, "st"):SetTip({
		title = "Shoulder Y",
		body = "Shifts the camera up or down.",
	})
	optionsLink:Slider("posSmoothing", "Smoothing", 100, 0, 100, 1, nil, "%"):SetTip({
		title = "Smoothing",
		body = "Lower makes your body follow your real position more tightly with less lag.",
	})

	self._enabled = false
	self._distance = optionsLink:Get("distance"):Peek()
	self._shoulderX = optionsLink:Get("shoulderX"):Peek()
	self._shoulderY = optionsLink:Get("shoulderY"):Peek()
	self._cameraConn = nil :: RBXScriptConnection?
	self._crosshair = nil :: Frame?
	self._crosshairWasVisible = false
	self._crosshairConn = nil :: RBXScriptConnection?

	localThirdPerson.setPositionSmoothing((optionsLink:Get("posSmoothing"):Peek() or 100) / 100)

	self._raycastParams = RaycastParams.new()
	self._raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self._raycastParams.IgnoreWater = true
	self._filter = {} :: { Instance }

	self:Track(link:Get("thirdPerson"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(link:Watch("thirdPerson.opts.distance", function(value: number): ()
		self._distance = value
	end))
	self:Track(link:Watch("thirdPerson.opts.shoulderX", function(value: number): ()
		self._shoulderX = value
	end))
	self:Track(link:Watch("thirdPerson.opts.shoulderY", function(value: number): ()
		self._shoulderY = value
	end))
	self:Track(link:Watch("thirdPerson.opts.posSmoothing", function(value: number): ()
		localThirdPerson.setPositionSmoothing((value or 100) / 100)
	end))

	return self
end

ThirdPerson._cameraStep = LPH_NO_VIRTUALIZE(function(self: ThirdPerson): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local cf = camera.CFrame
	local origin = cf.Position
	local offset = -cf.LookVector * self._distance + cf.RightVector * self._shoulderX + cf.UpVector * self._shoulderY
	local target = origin + offset

	local filter = self._filter
	table.clear(filter)
	local character = LocalPlayer.Character
	filter[#filter + 1] = camera
	if character then
		filter[#filter + 1] = character
	end
	local body = localThirdPerson.getCharacterModel()
	if body then
		filter[#filter + 1] = body
	end
	local weapon = localThirdPerson.getWeaponModel()
	if weapon then
		filter[#filter + 1] = weapon
	end
	self._raycastParams.FilterDescendantsInstances = filter

	local result = Workspace:Raycast(origin, offset, self._raycastParams)
	if result then
		target = result.Position + result.Normal * 0.2
	end

	local final = CFrame.new(target) * (cf - origin)
	camera.CFrame = final
	localThirdPerson.setCameraCFrame(final)
end)

function ThirdPerson._getCrosshair(self: ThirdPerson): Frame?
	local cached = self._crosshair
	if cached then
		return cached
	end
	local hudGui = ModuleController.GetModule("HudScreenGui")
	if not hudGui then
		return nil
	end
	local crosshair = hudGui.getScreenGui().Main.DisplayCrosshairs
	self._crosshair = crosshair
	return crosshair
end

function ThirdPerson.Enable(self: ThirdPerson): ()
	if self._enabled then
		return
	end
	self._enabled = true

	localThirdPerson.setEnabled(true)

	local crosshair = self:_getCrosshair()
	if crosshair then
		self._crosshairWasVisible = crosshair.Visible
		crosshair.Visible = false
		self._crosshairConn = crosshair:GetPropertyChangedSignal("Visible"):Connect(function(): ()
			if crosshair.Visible then
				crosshair.Visible = false
			end
		end)
	end

	self._cameraConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
		self:_cameraStep()
	end))
end

function ThirdPerson.Disable(self: ThirdPerson): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._cameraConn then
		self._cameraConn:Disconnect()
		self._cameraConn = nil
	end
	if self._crosshairConn then
		self._crosshairConn:Disconnect()
		self._crosshairConn = nil
	end
	local crosshair = self._crosshair
	if crosshair then
		crosshair.Visible = self._crosshairWasVisible
	end
	localThirdPerson.setEnabled(false)
end

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
			_raycastParams: RaycastParams,
			_filter: { Instance },
			_cameraConn: RBXScriptConnection?,
			_crosshair: Frame?,
			_crosshairWasVisible: boolean,
			_crosshairConn: RBXScriptConnection?,
			_getCrosshair: (ThirdPerson) -> Frame?,
		},
		ThirdPerson
	))
	& BaseFeature.BaseFeature

return ThirdPerson
