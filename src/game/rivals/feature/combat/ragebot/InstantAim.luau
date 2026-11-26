local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local WeaponController = require("@game/rivals/weapon/WeaponController")

local peek = Charm.peek
local sub = Charm.subscribe

local AIM_SPEED = 9999

local InstantAim = {}
InstantAim.__index = InstantAim

setmetatable(InstantAim, { __index = BaseFeature })

function InstantAim.new(link: gameUi.Linker): InstantAim
	local self = BaseFeature.new() :: any
	setmetatable(self, InstantAim)

	link:Toggle("instantAim", "Instant Aim", false):SetTip({
		title = "Instant Aim",
		body = "Removes view and weapon kick while shooting.",
	})

	self._link = link
	self._enabledLink = link:Get("instantAim")
	self._janitor = Janitor.new()

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	return self
end

function InstantAim._restore(self: InstantAim): ()
	local info = self._patchedInfo
	if info then
		info.AimSpeed = self._originalSpeed
		self._patchedInfo = nil
		self._originalSpeed = nil
	end
end

function InstantAim._apply(self: InstantAim): ()
	self:_restore()
	if not self._enabled then
		return
	end

	local item = peek(WeaponController.item)
	local info = item and item.Info
	if type(info) ~= "table" then
		return
	end

	self._patchedInfo = info
	self._originalSpeed = info.AimSpeed
	info.AimSpeed = AIM_SPEED
end

function InstantAim.Enable(self: InstantAim): ()
	if self._enabled then
		return
	end

	self._enabled = true
	self._janitor:Add(sub(WeaponController.item, function(): ()
		self:_apply()
	end))
	self:_apply()
end

function InstantAim.Disable(self: InstantAim): ()
	if not self._enabled then
		return
	end

	self._enabled = false
	self._janitor:Cleanup()
	self:_restore()
end

function InstantAim.Destroy(self: InstantAim): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type InstantAim =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_patchedInfo: any,
			_originalSpeed: any,
		},
		InstantAim
	))
	& BaseFeature.BaseFeature

return InstantAim
