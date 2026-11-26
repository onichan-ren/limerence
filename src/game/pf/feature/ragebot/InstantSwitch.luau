local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/pf/module/ModuleController")
local hook = require("@share/hook")

local InstantSwitch = {}
InstantSwitch.__index = InstantSwitch

setmetatable(InstantSwitch, { __index = BaseFeature })

local WEAPON_CLASSES = { "FirearmObject", "MeleeObject", "GrenadeObject" }

function InstantSwitch.new(link: gameUi.Linker): InstantSwitch
	local self = BaseFeature.new() :: any
	setmetatable(self, InstantSwitch)

	link:Toggle("instantSwitch", "Instant Switch", false):SetTip({
		title = "Instant Switch",
		body = "Removes the weapon swap delay so weapons are ready instantly.",
	})

	self._enabled = false
	self._targets = {}

	self:Track(link:Get("instantSwitch"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("instantSwitch") then
		self:Enable()
	end

	return self
end

function InstantSwitch.Enable(self: InstantSwitch): ()
	if self._enabled then
		return
	end
	self._enabled = true

	for i = 1, #WEAPON_CLASSES do
		local class = ModuleController.GetModule(WEAPON_CLASSES[i])
		local target = class and class.stateTimeCheck
		if type(target) == "function" then
			local original
			original = hook.add(
				target,
				LPH_NO_VIRTUALIZE(function(weapon: any, state: any, duration: any, time: any): ...any
					if state == "equipping" or state == "unequipping" then
						return original(weapon, state, 0, time)
					end
					return original(weapon, state, duration, time)
				end)
			)
			table.insert(self._targets, target)
		end
	end
end

function InstantSwitch.Disable(self: InstantSwitch): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	for i = 1, #self._targets do
		hook.restore(self._targets[i])
	end
	table.clear(self._targets)
end

function InstantSwitch.Destroy(self: InstantSwitch): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type InstantSwitch =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_targets: { any },
		},
		InstantSwitch
	))
	& BaseFeature.BaseFeature

return InstantSwitch
