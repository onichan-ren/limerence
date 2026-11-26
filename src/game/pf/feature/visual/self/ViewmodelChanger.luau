local RunService = cloneref(game:GetService("RunService")) :: RunService
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local WeaponController = require("@game/pf/weapon/WeaponController")

local ViewmodelChanger = {}
ViewmodelChanger.__index = ViewmodelChanger

setmetatable(ViewmodelChanger, { __index = BaseFeature })

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
	self._tracked = nil :: any
	self._baseOffset = nil :: CFrame?

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

function ViewmodelChanger._getOffsetCFrame(self: ViewmodelChanger): CFrame
	return CFrame.new(self._x, self._y, -self._z) * CFrame.Angles(0, 0, math.rad(self._roll))
end

local function aimFade(firearm: any): number
	local co = firearm._characterObject
	if not co then
		return 1
	end
	local spring = co:getSpring("masteraimspring")
	if not spring then
		return 1
	end
	return 1 - math.clamp(spring.p, 0, 1)
end

function ViewmodelChanger._restore(self: ViewmodelChanger): ()
	if self._tracked and self._baseOffset ~= nil then
		self._tracked._mainOffset = self._baseOffset
	end
	self._tracked = nil
	self._baseOffset = nil
end

function ViewmodelChanger.Enable(self: ViewmodelChanger): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._janitor:Add(
		RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
			local firearm = WeaponController.GetWeapon()
			if not firearm or WeaponController.GetWeaponType() ~= "Firearm" then
				if self._tracked then
					self:_restore()
				end
				return
			end

			if firearm ~= self._tracked then
				self:_restore()
				self._tracked = firearm
				self._baseOffset = firearm._mainOffset
			end

			local base = self._baseOffset
			if typeof(base) ~= "CFrame" then
				return
			end

			local offset = self:_getOffsetCFrame()
			if self._resetOnAim then
				local fade = aimFade(firearm)
				if fade <= 0 then
					firearm._mainOffset = base
					return
				end
				offset = CFrame.identity:Lerp(offset, fade)
			end

			firearm._mainOffset = base * offset
		end)),
		"Disconnect"
	)

	self._janitor:Add(function(): ()
		self:_restore()
	end, true)
end

function ViewmodelChanger.Disable(self: ViewmodelChanger): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
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
			_tracked: any,
			_baseOffset: CFrame?,
		},
		ViewmodelChanger
	))
	& BaseFeature.BaseFeature

return ViewmodelChanger
