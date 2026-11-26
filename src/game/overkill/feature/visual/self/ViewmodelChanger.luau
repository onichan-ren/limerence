local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/overkill/module/ModuleController")

local ViewmodelChanger = {}
ViewmodelChanger.__index = ViewmodelChanger

setmetatable(ViewmodelChanger, { __index = BaseFeature })

function ViewmodelChanger.new(link: gameUi.Linker): ViewmodelChanger
	local self = BaseFeature.new() :: any
	setmetatable(self, ViewmodelChanger)

	local toggle = link:Toggle("viewmodelChanger", "Viewmodel Changer", false):SetTip({
		title = "Viewmodel Changer",
		body = "Lets you adjust the viewmodel position and roll.",
	})
	local viewmodelChangerLink = link:OnKey("viewmodelChanger")
	viewmodelChangerLink:Submenu("opts", "Viewmodel Changer")
	local optsLink = viewmodelChangerLink:OnKey("opts")
	optsLink:Slider("x", "Offset X", 0, -2, 2, 0.05, nil, "st"):SetTip({
		title = "Offset X",
		body = "Moves the viewmodel left or right.",
	})
	optsLink:Slider("y", "Offset Y", 0, -2, 2, 0.05, nil, "st"):SetTip({
		title = "Offset Y",
		body = "Moves the viewmodel up or down.",
	})
	optsLink:Slider("z", "Offset Z", 0, -2, 2, 0.05, nil, "st"):SetTip({
		title = "Offset Z",
		body = "Moves the viewmodel forward or backward. Positive values move it forward.",
	})
	optsLink:Slider("roll", "Roll", 0, -180, 180, 1, nil, "°"):SetTip({
		title = "Roll",
		body = "Rotates the viewmodel around the camera axis.",
	})
	optsLink:Toggle("resetOnAim", "Reset While Aiming", true):SetTip({
		title = "Reset While Aiming",
		body = "Fades the offset out as you aim in so sights line up properly.",
	})

	self._x = optsLink:Get("x"):Peek()
	self._y = optsLink:Get("y"):Peek()
	self._z = optsLink:Get("z"):Peek()
	self._roll = optsLink:Get("roll"):Peek()
	self._resetOnAim = optsLink:Get("resetOnAim"):Peek()
	self._enabled = false
	self._installed = false
	self._offset = CFrame.identity
	self:_recomputeOffset()

	self:Track(toggle:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optsLink:Get("x"):OnChange(function(value: number): ()
		self._x = value
		self:_recomputeOffset()
	end))
	self:Track(optsLink:Get("y"):OnChange(function(value: number): ()
		self._y = value
		self:_recomputeOffset()
	end))
	self:Track(optsLink:Get("z"):OnChange(function(value: number): ()
		self._z = value
		self:_recomputeOffset()
	end))
	self:Track(optsLink:Get("roll"):OnChange(function(value: number): ()
		self._roll = value
		self:_recomputeOffset()
	end))
	self:Track(optsLink:Get("resetOnAim"):OnChange(function(value: boolean): ()
		self._resetOnAim = value
	end))

	return self
end

function ViewmodelChanger._recomputeOffset(self: ViewmodelChanger): ()
	self._offset = CFrame.new(self._x, self._y, -self._z) * CFrame.Angles(0, 0, math.rad(self._roll))
end

function ViewmodelChanger._install(self: ViewmodelChanger): ()
	if self._installed then
		return
	end
	local cameraHandler = ModuleController.GetModule("cameraHandler")
	if not cameraHandler then
		return
	end
	self._installed = true

	setthreadidentity(2)
	cameraHandler:addPostUpdateHook(LPH_NO_VIRTUALIZE(function(): ()
		if not self._enabled then
			return
		end
		if not cameraHandler.firstPerson or cameraHandler.spectatingCharacter then
			return
		end
		local base = cameraHandler.cframe
		if typeof(base) ~= "CFrame" then
			return
		end

		local offset = self._offset
		if self._resetOnAim then
			local aimSpring = cameraHandler.aimSpring
			local fade = 1 - math.clamp(aimSpring and aimSpring.Value or 0, 0, 1)
			if fade <= 0 then
				return
			end
			offset = CFrame.identity:Lerp(offset, fade)
		end

		cameraHandler.cframe = base * offset
	end))
	setthreadidentity(8)
end

function ViewmodelChanger.Enable(self: ViewmodelChanger): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self:_install()
end

function ViewmodelChanger.Disable(self: ViewmodelChanger): ()
	self._enabled = false
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
			_installed: boolean,
			_offset: CFrame,
			_recomputeOffset: (ViewmodelChanger) -> (),
		},
		ViewmodelChanger
	))
	& BaseFeature.BaseFeature

return ViewmodelChanger
