local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local TrailController = require("@game/rivals/trail/TrailController")

local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)

local SYSTEMS = {
	{ key = "other", label = "Other Player Trails" },
	{ key = "own", label = "Movement Trail" },
	{ key = "grenade", label = "Grenade Trails" },
}

local TrailColors = {}
TrailColors.__index = TrailColors

setmetatable(TrailColors, { __index = BaseFeature })

function TrailColors.new(link: gameUi.Linker): TrailColors
	local self = BaseFeature.new() :: any
	setmetatable(self, TrailColors)

	link:Options("trailColors", "Trail Colors")
	local root = link:OnKey("trailColors")

	self._states = {}

	for _, system in next, SYSTEMS do
		root:Toggle(system.key, system.label, false):SetTip({
			title = system.label,
			body = "Recolors the " .. string.lower(system.label) .. ". Use the color's alpha for transparency.",
		})
		local optsLink = root:OnKey(system.key)
		optsLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0):SetTip({
			title = "Color",
			body = "Color and transparency applied to the " .. string.lower(system.label) .. ".",
		})

		local colorLink = optsLink:Get("color")
		self._states[system.key] = { enabled = false, colorLink = colorLink }

		self:Track(root:Get(system.key):OnChange(function(value: boolean): ()
			self:_setEnabled(system.key, value)
		end))
		self:Track((colorLink :: any):OnUpdate(function(): ()
			self:_reapply(system.key)
		end))
	end

	return self
end

function TrailColors._apply(self: TrailColors, key: string): ()
	local state = self._states[key]
	if not state then
		return
	end
	TrailController.setColor(key, {
		color = (state.colorLink :: any):GetColor(),
		transparency = (state.colorLink :: any):GetTransparency(),
	})
end

function TrailColors._setEnabled(self: TrailColors, key: string, value: boolean): ()
	local state = self._states[key]
	if not state then
		return
	end
	state.enabled = value == true
	if state.enabled then
		self:_apply(key)
	else
		TrailController.setColor(key, nil)
	end
end

function TrailColors._reapply(self: TrailColors, key: string): ()
	local state = self._states[key]
	if state and state.enabled then
		self:_apply(key)
	end
end

function TrailColors.Destroy(self: TrailColors): ()
	for key in next, self._states do
		TrailController.setColor(key, nil)
	end
	BaseFeature.Destroy(self)
end

export type TrailColors =
	typeof(setmetatable(
		{} :: {
			_states: any,
		},
		TrailColors
	))
	& BaseFeature.BaseFeature

return TrailColors
