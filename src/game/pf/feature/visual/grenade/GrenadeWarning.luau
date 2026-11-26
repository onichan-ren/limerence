local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local warningRenderer = require("@game/pf/feature/visual/grenade/warningRenderer")
local pathRenderer = require("@game/pf/feature/visual/grenade/pathRenderer")

local e = React.createElement
local subscribeToBinding = (React :: any).__subscribeToBinding

local DEFAULT_ENEMY = Color3.fromRGB(255, 85, 95)
local DEFAULT_FRIENDLY = Color3.fromRGB(120, 200, 255)
local DEFAULT_LETHAL = Color3.fromRGB(255, 60, 60)
local DEFAULT_BACKGROUND = Color3.fromRGB(42, 42, 42)
local DEFAULT_ENEMY_PATH = Color3.fromRGB(255, 85, 95)
local DEFAULT_FRIENDLY_PATH = Color3.fromRGB(120, 200, 255)
local DEFAULT_ENEMY_END = Color3.fromRGB(255, 60, 60)
local DEFAULT_FRIENDLY_END = Color3.fromRGB(85, 155, 215)

local function bindColor(binding: any, setter: (Color3) -> ()): () -> ()
	setter((binding :: any):getValue())
	return subscribeToBinding(binding, function(value: Color3): ()
		setter(value)
	end)
end

local GrenadeWarning = {}
GrenadeWarning.__index = GrenadeWarning

setmetatable(GrenadeWarning, { __index = BaseFeature })

function GrenadeWarning.new(link: gameUi.Linker): GrenadeWarning
	local self = BaseFeature.new() :: any
	setmetatable(self, GrenadeWarning)

	link:Toggle("grenadeWarning", "Grenade Warning", false):SetTip({
		title = "Grenade Warning",
		body = "Marks where incoming grenades will land and can draw their flight path.",
	})
	local masterLink = link:OnKey("grenadeWarning")
	masterLink:Submenu("opts", "Grenade Warning Options")
	local optsLink = masterLink:OnKey("opts")

	optsLink:Colorpicker("enemyColor", "Enemy Color", DEFAULT_ENEMY)
	optsLink:Colorpicker("lethalColor", "Lethal Color", DEFAULT_LETHAL)
	optsLink:Colorpicker("backgroundColor", "Bar Background", DEFAULT_BACKGROUND, 0)
	optsLink:Toggle("showFriendly", "Show Friendly", false):SetTip({
		title = "Show Friendly",
		body = "Also warn for grenades thrown by teammates.",
	})
	local friendlyLink = optsLink:OnKey("showFriendly")
	friendlyLink:Colorpicker("friendlyColor", "Friendly Color", DEFAULT_FRIENDLY)

	optsLink:Toggle("showPath", "Show Path", false):SetTip({
		title = "Show Path",
		body = "Draws the predicted flight path of incoming grenades in the world.",
	})
	local pathLink = optsLink:OnKey("showPath")
	pathLink:Colorpicker("enemyPathColor", "Enemy Path", DEFAULT_ENEMY_PATH)
	pathLink:Colorpicker("friendlyPathColor", "Friendly Path", DEFAULT_FRIENDLY_PATH)
	pathLink:Colorpicker("enemyEndColor", "Enemy Landing", DEFAULT_ENEMY_END)
	pathLink:Colorpicker("friendlyEndColor", "Friendly Landing", DEFAULT_FRIENDLY_END)

	local function refreshPathEnabled(): ()
		local on = link:Peek("grenadeWarning") == true and optsLink:Peek("showPath") == true
		pathRenderer.setEnabled(on)
	end
	self:Track(link:Watch("grenadeWarning", refreshPathEnabled))
	self:Track(optsLink:Watch("showPath", refreshPathEnabled))

	self:Track(bindColor(pathLink:Get("enemyPathColor")._currentColor, pathRenderer.setEnemyPathColor))
	self:Track(bindColor(pathLink:Get("friendlyPathColor")._currentColor, pathRenderer.setFriendlyPathColor))
	self:Track(bindColor(pathLink:Get("enemyEndColor")._currentColor, pathRenderer.setEnemyEndColor))
	self:Track(bindColor(pathLink:Get("friendlyEndColor")._currentColor, pathRenderer.setFriendlyEndColor))

	refreshPathEnabled()

	self._enabledLink = link:Get("grenadeWarning")

	local screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = 16,
	}, cloneref(gethui()))
	self._screenGui = screenGui

	self._root = ReactRoblox.createRoot(screenGui)
	self._root:render(e(warningRenderer, {
		enabledLink = self._enabledLink,
		showFriendlyLink = link:Get("grenadeWarning.opts.showFriendly"),
		enemyColorLink = link:Get("grenadeWarning.opts.enemyColor"),
		friendlyColorLink = link:Get("grenadeWarning.opts.showFriendly.friendlyColor"),
		lethalColorLink = link:Get("grenadeWarning.opts.lethalColor"),
		backgroundColorLink = link:Get("grenadeWarning.opts.backgroundColor"),
	}))

	return self
end

function GrenadeWarning.Destroy(self: GrenadeWarning): ()
	pathRenderer.setEnabled(false)
	if self._root then
		self._root:unmount()
	end
	if self._screenGui then
		self._screenGui:Destroy()
	end
	BaseFeature.Destroy(self)
end

export type GrenadeWarning =
	typeof(setmetatable(
		{} :: {
			_enabledLink: any,
			_screenGui: Instance,
			_root: ReactRoblox.RootType,
		},
		GrenadeWarning
	))
	& BaseFeature.BaseFeature

return GrenadeWarning
