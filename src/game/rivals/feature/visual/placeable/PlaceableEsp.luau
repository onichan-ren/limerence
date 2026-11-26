local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local placeableRenderer = require("@game/rivals/feature/visual/placeable/placeableRenderer")

local e = React.createElement

local DEFAULT_ENEMY_COLOR = Color3.fromRGB(220, 110, 110)
local DEFAULT_FRIENDLY_COLOR = Color3.fromRGB(120, 175, 200)
local DEFAULT_BAR_COLOR = Color3.fromRGB(42, 42, 42)

local PLACEABLE_TYPES = { "Jump Pad", "Tripmine" }

local PlaceableEsp = {}
PlaceableEsp.__index = PlaceableEsp

setmetatable(PlaceableEsp, { __index = BaseFeature })

function PlaceableEsp.new(link: gameUi.Linker): PlaceableEsp
	local self = BaseFeature.new() :: any
	setmetatable(self, PlaceableEsp)

	local toggle = link:Toggle("placeableEsp", "Placeable ESP", false):SetTip({
		title = "Placeable ESP",
		body = "On-screen markers for jump pads and subspace tripmines, colored by team.",
	})
	local espLink = link:OnKey("placeableEsp")
	espLink:Extra(toggle, "opts", "Submenu", "Placeable ESP Options")
	local optsLink = espLink:OnKey("opts")
	optsLink:Dropdown("types", "Show", PLACEABLE_TYPES, PLACEABLE_TYPES):SetMode("multi"):SetTip({
		title = "Show",
		body = "Pick which placeables get markers.",
	})
	optsLink:Colorpicker("friendlyColor", "Friendly", DEFAULT_FRIENDLY_COLOR)
	optsLink:Colorpicker("enemyColor", "Enemy", DEFAULT_ENEMY_COLOR)
	optsLink:Colorpicker("barColor", "Bar Color", DEFAULT_BAR_COLOR)

	self._enabledLink = link:Get("placeableEsp")
	self._typesLink = link:Get("placeableEsp.opts.types")
	self._friendlyColorLink = link:Get("placeableEsp.opts.friendlyColor")
	self._enemyColorLink = link:Get("placeableEsp.opts.enemyColor")
	self._barColorLink = link:Get("placeableEsp.opts.barColor")

	local screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = 15,
	}, cloneref(gethui()))
	self._screenGui = screenGui

	self._root = ReactRoblox.createRoot(screenGui)
	self._root:render(e(placeableRenderer, {
		enabledLink = self._enabledLink,
		selectionLink = self._typesLink,
		friendlyColorLink = self._friendlyColorLink,
		enemyColorLink = self._enemyColorLink,
		barColorLink = self._barColorLink,
	}))

	return self
end

function PlaceableEsp.Destroy(self: PlaceableEsp): ()
	if self._root then
		self._root:unmount()
	end
	if self._screenGui then
		self._screenGui:Destroy()
	end
	BaseFeature.Destroy(self)
end

export type PlaceableEsp = typeof(setmetatable(
	{} :: {
		_enabledLink: any,
		_typesLink: any,
		_friendlyColorLink: any,
		_enemyColorLink: any,
		_barColorLink: any,
		_screenGui: Instance,
		_root: ReactRoblox.RootType,
	},
	PlaceableEsp
)) & BaseFeature.BaseFeature

return PlaceableEsp
