local ModuleController = require("@game/rivals/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local Janitor = require("@pkg/Janitor")

local ViewmodelChanger = {}
ViewmodelChanger.__index = ViewmodelChanger

setmetatable(ViewmodelChanger, { __index = BaseFeature })

local function getCameraController(): any
	return ModuleController.GetModule("CameraController")
end

local isLocalViewModel = LPH_NO_VIRTUALIZE(function(vm: any): boolean
	local clientItem = rawget(vm, "ClientItem")
	if not clientItem then
		return true
	end
	local clientFighter = rawget(clientItem, "ClientFighter")
	if not clientFighter then
		return true
	end
	local isLocal = clientFighter.IsLocalPlayer == true
	if not isLocal then
		return false
	end
	return true
end)

local isFirstPerson = LPH_NO_VIRTUALIZE(function(cameraController: any?): boolean
	if not cameraController then
		return true
	end

	local cameraState = cameraController.CameraState
	if not cameraState then
		return true
	end

	local getPublicState = cameraState.GetPublicState
	local states = cameraState.States
	if type(getPublicState) ~= "function" or type(states) ~= "table" then
		return true
	end

	local firstPersonState = states.FirstPerson
	if type(firstPersonState) ~= "string" then
		return true
	end

	local publicState = getPublicState(cameraState)
	return publicState == firstPersonState
end)

function ViewmodelChanger.new(link: gameUi.Linker): ViewmodelChanger
	local self = BaseFeature.new() :: any
	setmetatable(self, ViewmodelChanger)

	link:Toggle("viewmodelChanger", "Viewmodel Changer", false):SetTip({
		title = "Viewmodel Changer",
		body = "Lets you adjust the viewmodel position and roll.",
	})
	local viewmodelChangerLink = link:OnKey("viewmodelChanger")
	viewmodelChangerLink:Submenu("opts", "Viewmodel Changer")
	local optionsLink = viewmodelChangerLink:OnKey("opts")
	optionsLink:Slider("x", "Offset X", 0, -2, 2, 0.05, nil, "st"):SetTip({
		title = "Offset X",
		body = "Moves the viewmodel left or right.",
	})
	optionsLink:Slider("y", "Offset Y", 0, -2, 2, 0.05, nil, "st"):SetTip({
		title = "Offset Y",
		body = "Moves the viewmodel up or down.",
	})
	optionsLink:Slider("z", "Offset Z", 0, -2, 2, 0.05, nil, "st"):SetTip({
		title = "Offset Z",
		body = "Moves the viewmodel forward or backward. Positive values move it forward.",
	})
	optionsLink:Slider("roll", "Roll", 0, -180, 180, 1, nil, "°"):SetTip({
		title = "Roll",
		body = "Rotates the viewmodel around the camera axis.",
	})
	optionsLink:Toggle("resetOnAim", "Reset While Aiming", true):SetTip({
		title = "Reset While Aiming",
		body = "Fades the offset out as you aim in so sights line up properly.",
	})

	self._x = 0
	self._y = 0
	self._z = 0
	self._roll = 0
	self._resetOnAim = optionsLink:Get("resetOnAim"):Peek()
	self._enabled = false
	self._janitor = Janitor.new()
	self._setCFrameHookTarget = nil :: any?
	self._cameraController = nil :: any?

	self:Track(link:Get("viewmodelChanger"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(link:Watch("viewmodelChanger.opts.x", function(value: number): ()
		self._x = value
	end))
	self:Track(link:Watch("viewmodelChanger.opts.y", function(value: number): ()
		self._y = value
	end))
	self:Track(link:Watch("viewmodelChanger.opts.z", function(value: number): ()
		self._z = value
	end))
	self:Track(link:Watch("viewmodelChanger.opts.roll", function(value: number): ()
		self._roll = value
	end))
	self:Track(link:Watch("viewmodelChanger.opts.resetOnAim", function(value: boolean): ()
		self._resetOnAim = value
	end))

	return self
end

local function getAimFactor(vm: any): number
	local aimSpring = rawget(vm, "_aim_spring")
	if not aimSpring then
		return 0
	end
	local value = aimSpring.Value
	if type(value) ~= "number" then
		return 0
	end
	if value < 0 then
		return 0
	elseif value > 1 then
		return 1
	end
	return value
end

function ViewmodelChanger._getOffsetCFrame(self: ViewmodelChanger): CFrame
	return CFrame.new(self._x, self._y, -self._z) * CFrame.Angles(0, 0, math.rad(self._roll))
end

function ViewmodelChanger.Enable(self: ViewmodelChanger): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._cameraController = getCameraController()

	local clientViewModel = ModuleController.GetModule("ClientViewModel")
	if not clientViewModel then
		return
	end

	local setCFrame = rawget(clientViewModel, "SetCFrame")
	if type(setCFrame) ~= "function" then
		return
	end

	local originalSetCFrame
	originalSetCFrame = hook.add(
		setCFrame,
		LPH_NO_VIRTUALIZE(function(vm: any, cf: CFrame): ()
			local cameraController = self._cameraController
			if self._enabled and isLocalViewModel(vm) and isFirstPerson(cameraController) then
				local offset = self:_getOffsetCFrame()
				if self._resetOnAim then
					local fade = 1 - getAimFactor(vm)
					if fade <= 0 then
						return originalSetCFrame(vm, cf)
					end
					offset = CFrame.identity:Lerp(offset, fade)
				end
				return originalSetCFrame(vm, cf * offset)
			end
			return originalSetCFrame(vm, cf)
		end)
	)

	self._setCFrameHookTarget = setCFrame
	self._janitor:Add(function(): ()
		if self._setCFrameHookTarget then
			hook.restore(self._setCFrameHookTarget)
			self._setCFrameHookTarget = nil
		end
	end, true)
end

function ViewmodelChanger.Disable(self: ViewmodelChanger): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
	self._cameraController = nil
end

function ViewmodelChanger.Destroy(self: ViewmodelChanger): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type ViewmodelChanger =
	typeof(setmetatable(
		{} :: {
			_x: number,
			_y: number,
			_z: number,
			_roll: number,
			_resetOnAim: boolean,
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_setCFrameHookTarget: any?,
			_cameraController: any?,
		},
		ViewmodelChanger
	))
	& BaseFeature.BaseFeature

return ViewmodelChanger
