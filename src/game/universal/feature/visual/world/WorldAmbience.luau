local BaseFeature = require("@game/BaseFeature")
local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local gameUi = require("@game/gameUi")
local Lighting = require("@game/universal/feature/visual/world/Lighting")
local Atmosphere = require("@game/universal/feature/visual/world/Atmosphere")
local SkyboxChanger = require("@game/universal/feature/visual/world/SkyboxChanger")
local MapProfiles = require("@ui/scope/MapProfiles")
local MapProfilePane = require("@ui/scope/MapProfilePane")

local sub = Charm.subscribe
local e = React.createElement

local WorldAmbience = {}
WorldAmbience.__index = WorldAmbience

setmetatable(WorldAmbience, { __index = BaseFeature })

export type WorldAmbienceOpts = {
	mapSource: MapProfiles.MapSource?,
}

local function createProfileUi(self: WorldAmbience, options: any): ()
	local profiles = self._profiles :: MapProfiles.MapProfiles

	options:SetSidePane(function()
		return e(MapProfilePane, {
			Profiles = profiles,
		})
	end)

	self:Track(sub(options._open, function(open: boolean)
		if not open then
			profiles:Select(profiles:ActiveProfile())
		end
	end))
end

function WorldAmbience.new(link: gameUi.Linker, opts: WorldAmbienceOpts?): WorldAmbience
	local self = BaseFeature.new() :: any
	setmetatable(self, WorldAmbience)

	local options = link:Options("worldAmbience", "World Ambience")
	options:SetTip({
		title = "World Ambience",
		body = "Customize lighting, sky, and atmosphere.",
	})
	local ambienceLink = link:On(options)

	local source = opts and opts.mapSource
	if source then
		self._profiles = MapProfiles.new("worldAmbience", source)
		createProfileUi(self, options)
	end

	self._lighting = Lighting.new(ambienceLink)
	self._atmosphere = Atmosphere.new(ambienceLink)
	self._skybox = SkyboxChanger.new(ambienceLink)

	if self._profiles then
		self._profiles:BindPrefix(link._prefix)
		self._profiles:_pushAll()
	end

	return self
end

function WorldAmbience.Destroy(self: WorldAmbience): ()
	self._lighting:Destroy()
	self._atmosphere:Destroy()
	self._skybox:Destroy()
	if self._profiles then
		self._profiles:Destroy()
	end
	BaseFeature.Destroy(self)
end

export type WorldAmbience =
	typeof(setmetatable(
		{} :: {
			_lighting: Lighting.Lighting,
			_atmosphere: Atmosphere.Atmosphere,
			_skybox: SkyboxChanger.SkyboxChanger,
			_profiles: MapProfiles.MapProfiles?,
		},
		WorldAmbience
	))
	& BaseFeature.BaseFeature

return WorldAmbience
