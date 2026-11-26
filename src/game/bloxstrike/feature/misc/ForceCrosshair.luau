local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local Janitor = require("@pkg/Janitor")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Charm = require("@pkg/Charm")

local peek = Charm.peek
local sub = Charm.subscribe

local function restore(properties: any): ()
	if not properties then
		return
	end
	setreadonly(properties, false)
	properties.ShowCrosshair = false
	setreadonly(properties, true)
end

local function setShowCrosshair(self: ForceCrosshair, equipped: loadoutState.LoadoutEntry?): ()
	if equipped then
		local properties = equipped.Properties
		if properties and not properties.ShowCrosshair then
			setreadonly(properties, false)
			properties.ShowCrosshair = true
			setreadonly(properties, true)
			self._cache = properties
		end
	end
end

local ForceCrosshair = {}
ForceCrosshair.__index = ForceCrosshair

setmetatable(ForceCrosshair, { __index = BaseFeature })

function ForceCrosshair.new(link: gameUi.Linker): ForceCrosshair
	local self = BaseFeature.new() :: any
	setmetatable(self, ForceCrosshair)

	link:Toggle("forceCrosshair", "Force Crosshair", false):SetTip({
		title = "Force Crosshair",
		body = "Keeps your crosshair visible while scoped or on weapons that normally hide it.",
	})

	self:Track(link:Get("forceCrosshair"):OnChange(function(value: boolean)
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self._janitor = Janitor.new()
	self._cache = nil :: loadoutState.LoadoutEntry?

	return self
end

function ForceCrosshair.Enable(self: ForceCrosshair): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._janitor:Add(
		sub(
			loadoutState.currentEquipped,
			LPH_NO_VIRTUALIZE(function(equipped: loadoutState.LoadoutEntry?)
				local cache = self._cache
				restore(cache)
				self._cache = nil
				setShowCrosshair(self, equipped)
			end)
		),
		false
	)

	self._janitor:Add(function()
		restore(self._cache)
	end, false)

	setShowCrosshair(self, peek(loadoutState.currentEquipped))
end

function ForceCrosshair.Disable(self: ForceCrosshair): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function ForceCrosshair.Destroy(self: ForceCrosshair): ()
	BaseFeature.Destroy(self)
	self._janitor:Destroy()
end

export type ForceCrosshair =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_cache: loadoutState.LoadoutEntry?,
		},
		ForceCrosshair
	))
	& BaseFeature.BaseFeature

return ForceCrosshair
