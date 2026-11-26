local ModuleController = require("@game/bloxstrike/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local Janitor = require("@pkg/Janitor")

local NoRecoil = {}
NoRecoil.__index = NoRecoil

setmetatable(NoRecoil, { __index = BaseFeature })

function NoRecoil.new(link: gameUi.Linker): NoRecoil
	local self = BaseFeature.new() :: any
	setmetatable(self, NoRecoil)

	link:Toggle("NoRecoil", "Reduce Recoil", false):SetTip({
		title = "Reduce Recoil",
		body = "Reduces view and weapon kick while shooting. Tune vertical and horizontal separately.",
	})

	local masterLink = link:OnKey("NoRecoil")
	masterLink:Submenu("opts", "Reduce Recoil")
	local optsLink = masterLink:OnKey("opts")

	optsLink:Slider("vertical", "Vertical", 100, 0, 100, 1, nil, "%"):SetTip({
		title = "Vertical",
		body = "How much vertical (up/down) recoil to remove. 100% removes all vertical kick.",
	})
	optsLink:Slider("horizontal", "Horizontal", 100, 0, 100, 1, nil, "%"):SetTip({
		title = "Horizontal",
		body = "How much horizontal (left/right) recoil to remove. 100% removes all horizontal kick.",
	})

	self._link = link
	self._enabledLink = link:Get("NoRecoil")
	self._janitor = Janitor.new()
	self._vScale = 1 - (tonumber(link:Peek("NoRecoil.opts.vertical")) or 100) / 100
	self._hScale = 1 - (tonumber(link:Peek("NoRecoil.opts.horizontal")) or 100) / 100

	self:Track(link:Watch("NoRecoil.opts.vertical", function(v: any): ()
		self._vScale = 1 - (tonumber(v) or 100) / 100
	end))
	self:Track(link:Watch("NoRecoil.opts.horizontal", function(v: any): ()
		self._hScale = 1 - (tonumber(v) or 100) / 100
	end))

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("NoRecoil") then
		self:Enable()
	end

	return self
end

function NoRecoil.Enable(self: NoRecoil): ()
	if self._enabled then
		return
	end

	self._enabled = true

	local cameraController = ModuleController.GetModule("CameraController")

	local setWeaponRecoil = cameraController and rawget(cameraController, "setWeaponRecoil")
	if not setWeaponRecoil then
		return
	end

	local oldSpring = getupvalue(setWeaponRecoil, 1)

	local scaledSpring = {
		setDampingRatio = oldSpring.setDampingRatio,
		setFrequency = oldSpring.setFrequency,
		setGoal = LPH_NO_VIRTUALIZE(function(_, goal)
			return oldSpring:setGoal(Vector3.new(goal.X * self._vScale, goal.Y * self._hScale, goal.Z))
		end),
	}

	setupvalue(setWeaponRecoil, 1, scaledSpring)

	self._janitor:Add(function()
		setupvalue(setWeaponRecoil, 1, oldSpring)
	end, true)
end

function NoRecoil.Disable(self: NoRecoil): ()
	if not self._enabled then
		return
	end

	self._enabled = false
	self._janitor:Cleanup()
end

function NoRecoil.Destroy(self: NoRecoil): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type NoRecoil =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_enabledLink: any,
			_enabled: boolean,
			_vScale: number,
			_hScale: number,
			_janitor: Janitor.Janitor,
		},
		NoRecoil
	))
	& BaseFeature.BaseFeature

return NoRecoil
