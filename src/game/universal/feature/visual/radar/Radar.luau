local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local AppController = require("@feature/app/AppController")
local gameUi = require("@game/gameUi")
local radarView = require("@game/universal/feature/visual/radar/radarView")

local at = Charm.atom
local e = React.createElement

local DEFAULT_ENEMY_COLOR = Color3.fromRGB(235, 95, 95)
local DEFAULT_TEAM_COLOR = Color3.fromRGB(90, 230, 120)
local DEFAULT_POSITION = UDim2.new(0, 130, 0, 160)

local Radar = {}
Radar.__index = Radar

setmetatable(Radar, { __index = BaseFeature })

export type RadarOpts = {
	isTeammate: ((basePlayer: any) -> boolean)?,
	getRange: (() -> number?)?,
	filter: ((basePlayer: any) -> boolean)?,
}

function Radar.new(link: gameUi.Linker, opts: RadarOpts?): Radar
	local self = BaseFeature.new() :: any
	setmetatable(self, Radar)

	self._mounted = false
	self._open = at(false)
	self._isTeammate = opts and opts.isTeammate
	self._getRange = opts and opts.getRange
	self._filter = opts and opts.filter

	link:Toggle("radar", "Radar", false):SetTip({
		title = "Radar",
		body = "Top-down radar showing where other players are around you. While the menu is open, drag it to move it and right-click it to reset its position.",
	})
	local rootLink = link:OnKey("radar")

	rootLink:Submenu("opts", "Radar")
	local optionsLink = rootLink:OnKey("opts")

	local showTeam = optionsLink:Toggle("showTeammates", "Show Teammates", true):SetTip({
		title = "Show Teammates",
		body = "Show your teammates on the radar.",
	})

	local range: any = nil
	local mapScale: any = nil
	if self._getRange then
		mapScale = optionsLink:Slider("mapScale", "Map Scale", 100, 25, 200, 5, nil, "%"):SetTip({
			title = "Map Scale",
			body = "Zoom applied on top of the map size. Lower spreads players further apart.",
		})
	else
		range = optionsLink:Slider("range", "Range", 120, 25, 300, 5, nil, "studs"):SetTip({
			title = "Range",
			body = "Distance from you to the radar edge. Players further away are pinned to the edge.",
		})
	end

	optionsLink:Options("appearance", "Appearance")
	local appearanceLink = optionsLink:OnKey("appearance")
	local dotSize = appearanceLink:Slider("dotSize", "Dot Size", 8, 4, 12, 1, nil, "px"):SetTip({
		title = "Dot Size",
		body = "Player dot size in pixels.",
	})
	local size = appearanceLink:Slider("size", "Size", 180, 120, 320, 2, nil, "px"):SetTip({
		title = "Size",
		body = "Radar size in pixels.",
	})
	local teamColor = appearanceLink:Colorpicker("teamColor", "Teammate Color", DEFAULT_TEAM_COLOR, 0):SetTip({
		title = "Teammate Color",
		body = "Dot color for teammates.",
	})
	local enemyColor = appearanceLink:Colorpicker("enemyColor", "Enemy Color", DEFAULT_ENEMY_COLOR, 0):SetTip({
		title = "Enemy Color",
		body = "Dot color for enemies.",
	})

	local position = rootLink:Value("position", DEFAULT_POSITION)

	self._sizeEl = size
	self._rangeEl = range
	self._dotSizeEl = dotSize
	self._showTeamEl = showTeam
	self._enemyColorEl = enemyColor
	self._teamColorEl = teamColor
	self._mapScaleEl = mapScale
	self._position = position

	self:Track(link:Get("radar"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("radar") then
		self:Enable()
	end

	return self
end

function Radar._ensureMounted(self: Radar): ()
	if self._mounted then
		return
	end
	self._mounted = true
	AppController.Render(e(radarView, {
		open = self._open,
		position = self._position,
		sizeEl = self._sizeEl,
		rangeEl = self._rangeEl,
		dotSizeEl = self._dotSizeEl,
		showTeamEl = self._showTeamEl,
		enemyColorEl = self._enemyColorEl,
		teamColorEl = self._teamColorEl,
		resetPosition = DEFAULT_POSITION,
		isTeammate = self._isTeammate,
		getRange = self._getRange,
		filter = self._filter,
		mapScaleEl = self._mapScaleEl,
	}))
end

function Radar.Enable(self: Radar): ()
	self:_ensureMounted()
	self._open(true)
end

function Radar.Disable(self: Radar): ()
	self._open(false)
end

export type Radar =
	typeof(setmetatable(
		{} :: {
			_mounted: boolean,
			_open: Charm.Atom<boolean>,
			_isTeammate: ((basePlayer: any) -> boolean)?,
			_getRange: (() -> number?)?,
			_filter: ((basePlayer: any) -> boolean)?,
			_mapScaleEl: any,
			_sizeEl: any,
			_rangeEl: any,
			_dotSizeEl: any,
			_showTeamEl: any,
			_enemyColorEl: any,
			_teamColorEl: any,
			_position: any,
		},
		Radar
	))
	& BaseFeature.BaseFeature

return Radar
