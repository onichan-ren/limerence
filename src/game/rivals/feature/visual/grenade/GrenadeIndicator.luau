local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local indicatorRenderer = require("@game/rivals/feature/visual/grenade/indicatorRenderer")

local e = React.createElement

local DEFAULT_ENEMY_FLASH_COLOR = Color3.fromRGB(220, 190, 110)
local DEFAULT_FRIENDLY_FLASH_COLOR = Color3.fromRGB(145, 190, 215)
local DEFAULT_ENEMY_SMOKE_COLOR = Color3.fromRGB(195, 110, 110)
local DEFAULT_FRIENDLY_SMOKE_COLOR = Color3.fromRGB(120, 175, 200)
local DEFAULT_BAR_COLOR = Color3.fromRGB(42, 42, 42)

local THROWABLE_TYPES = { "Flashbang", "Molotov", "Smoke Grenade" }

local GrenadeIndicator = {}
GrenadeIndicator.__index = GrenadeIndicator

setmetatable(GrenadeIndicator, { __index = BaseFeature })

function GrenadeIndicator.new(link: gameUi.Linker): GrenadeIndicator
	local self = BaseFeature.new() :: any
	setmetatable(self, GrenadeIndicator)

	local indicator = link:Toggle("throwableIndicator", "Throwable Indicator", false):SetTip({
		title = "Throwable Indicator",
		body = "On-screen bars for active smokes and flashes, colored by team.",
	})
	local indicatorLink = link:OnKey("throwableIndicator")
	indicatorLink:Extra(indicator, "opts", "Submenu", "Throwable Indicator Options")
	local optsLink = indicatorLink:OnKey("opts")
	optsLink:Dropdown("types", "Show", THROWABLE_TYPES, THROWABLE_TYPES):SetMode("multi"):SetTip({
		title = "Show",
		body = "Pick which throwables get markers.",
	})
	optsLink:Colorpicker("friendlySmokeColor", "Friendly Smoke", DEFAULT_FRIENDLY_SMOKE_COLOR)
	optsLink:Colorpicker("friendlyFlashColor", "Friendly Flash", DEFAULT_FRIENDLY_FLASH_COLOR)
	optsLink:Colorpicker("enemySmokeColor", "Enemy Smoke", DEFAULT_ENEMY_SMOKE_COLOR)
	optsLink:Colorpicker("enemyFlashColor", "Enemy Flash", DEFAULT_ENEMY_FLASH_COLOR)
	optsLink:Colorpicker("barColor", "Bar Color", DEFAULT_BAR_COLOR)

	self._enabledLink = link:Get("throwableIndicator")
	self._typesLink = link:Get("throwableIndicator.opts.types")
	self._enemyFlashColorLink = link:Get("throwableIndicator.opts.enemyFlashColor")
	self._friendlyFlashColorLink = link:Get("throwableIndicator.opts.friendlyFlashColor")
	self._enemySmokeColorLink = link:Get("throwableIndicator.opts.enemySmokeColor")
	self._friendlySmokeColorLink = link:Get("throwableIndicator.opts.friendlySmokeColor")
	self._barColorLink = link:Get("throwableIndicator.opts.barColor")

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
	self._root:render(e(indicatorRenderer, {
		enabledLink = self._enabledLink,
		selectionLink = self._typesLink,
		enemyFlashColorLink = self._enemyFlashColorLink,
		friendlyFlashColorLink = self._friendlyFlashColorLink,
		enemySmokeColorLink = self._enemySmokeColorLink,
		friendlySmokeColorLink = self._friendlySmokeColorLink,
		barColorLink = self._barColorLink,
	}))

	return self
end

function GrenadeIndicator.Destroy(self: GrenadeIndicator): ()
	if self._root then
		self._root:unmount()
	end
	if self._screenGui then
		self._screenGui:Destroy()
	end
	BaseFeature.Destroy(self)
end

export type GrenadeIndicator = typeof(setmetatable(
	{} :: {
		_enabledLink: any,
		_typesLink: any,
		_enemyFlashColorLink: any,
		_friendlyFlashColorLink: any,
		_enemySmokeColorLink: any,
		_friendlySmokeColorLink: any,
		_barColorLink: any,
		_screenGui: Instance,
		_root: ReactRoblox.RootType,
	},
	GrenadeIndicator
)) & BaseFeature.BaseFeature

return GrenadeIndicator
