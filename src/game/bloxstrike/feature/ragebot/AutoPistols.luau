local Charm = require("@pkg/Charm")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

local peek = Charm.peek
local sub = Charm.subscribe

local AutoPistols = {}
AutoPistols.__index = AutoPistols

setmetatable(AutoPistols, { __index = BaseFeature })

local function restore(self: AutoPistols): ()
	local props = self._patched
	if not props then
		return
	end
	setreadonly(props, false)
	props.Automatic = self._originalAutomatic
	setreadonly(props, true)
	self._patched = nil
	self._originalAutomatic = nil
end

local function patch(self: AutoPistols, weapon: any): ()
	if not weapon then
		return
	end
	local props = weapon.Properties
	if not props or props.Class ~= "Weapon" then
		return
	end
	if props.ShootingOptions == "Revolver" or props.Automatic == true then
		return
	end
	self._patched = props
	self._originalAutomatic = props.Automatic
	setreadonly(props, false)
	props.Automatic = true
	setreadonly(props, true)
end

function AutoPistols.new(link: gameUi.Linker): AutoPistols
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoPistols)

	link:Toggle("autoPistols", "Auto Pistols", false):SetTip({
		title = "Auto Pistols",
		body = "Hold fire to automatically shoot semi-automatic weapons.",
	})

	self._janitor = Janitor.new()
	self._enabled = false
	self._patched = nil
	self._originalAutomatic = nil
	self._enabledLink = link:Get("autoPistols")

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("autoPistols") then
		self:Enable()
	end

	return self
end

function AutoPistols.Enable(self: AutoPistols): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._janitor:Add(sub(loadoutState.currentEquipped, function(weapon: any): ()
		restore(self)
		patch(self, weapon)
	end), true)
	self._janitor:Add(function(): ()
		restore(self)
	end, true)

	patch(self, peek(loadoutState.currentEquipped))
end

function AutoPistols.Disable(self: AutoPistols): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function AutoPistols.Destroy(self: AutoPistols): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoPistols =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_enabledLink: any,
			_patched: any,
			_originalAutomatic: any,
			_janitor: Janitor.Janitor,
		},
		AutoPistols
	))
	& BaseFeature.BaseFeature

return AutoPistols
