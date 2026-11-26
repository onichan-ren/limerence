local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local warningRenderer = require("@game/bloxstrike/feature/visual/grenade/warningRenderer")
local pathRenderer = require("@game/bloxstrike/feature/visual/grenade/pathRenderer")

local e = React.createElement
local subscribeToBinding = (React :: any).__subscribeToBinding

local DEFAULT_HE_COLOR = Color3.fromRGB(195, 110, 110)
local DEFAULT_FIRE_COLOR = Color3.fromRGB(220, 190, 110)
local DEFAULT_BG_COLOR = Color3.fromRGB(28, 28, 28)
local DEFAULT_ENEMY_PATH_COLOR = Color3.fromRGB(195, 110, 110)
local DEFAULT_FRIENDLY_PATH_COLOR = Color3.fromRGB(120, 175, 200)
local DEFAULT_ENEMY_END_COLOR = Color3.fromRGB(165, 75, 75)
local DEFAULT_FRIENDLY_END_COLOR = Color3.fromRGB(85, 130, 155)

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

	local warning = link:Toggle("grenadeWarning", "Grenade Warning", false):SetTip({
		title = "Grenade Warning",
		body = "Marks where incoming grenades will land and can draw their flight path.",
	})
	local warningLink = link:OnKey("grenadeWarning")
	warningLink:Extra(warning, "opts", "Submenu", "Grenade Warning Options")
	local optsLink = warningLink:OnKey("opts")
	optsLink:Colorpicker("bgColor", "Background Color", DEFAULT_BG_COLOR)
	optsLink:Colorpicker("fireColor", "Molotov Color", DEFAULT_FIRE_COLOR)
	optsLink:Colorpicker("heColor", "HE Color", DEFAULT_HE_COLOR)

	local showPath = optsLink:Toggle("showPath", "Show Path", false):SetTip({
		title = "Show Path",
		body = "Draws the predicted flight path of incoming grenades in the world.",
	})
	optsLink:Extra(showPath, "pathOpts", "Submenu", "Grenade Path Options")
	local pathOpts = optsLink:OnKey("pathOpts")
	pathOpts:Colorpicker("friendlyEndColor", "Friendly Landing", DEFAULT_FRIENDLY_END_COLOR)
	pathOpts:Colorpicker("enemyEndColor", "Enemy Landing", DEFAULT_ENEMY_END_COLOR)
	pathOpts:Colorpicker("friendlyPathColor", "Friendly Path", DEFAULT_FRIENDLY_PATH_COLOR)
	pathOpts:Colorpicker("enemyPathColor", "Enemy Path", DEFAULT_ENEMY_PATH_COLOR)

	self._enabledLink = link:Get("grenadeWarning")
	self._heColorLink = link:Get("grenadeWarning.opts.heColor")
	self._fireColorLink = link:Get("grenadeWarning.opts.fireColor")
	self._bgColorLink = link:Get("grenadeWarning.opts.bgColor")

	local enabledWatch = link:Watch("grenadeWarning", function(enabled: any)
		local showPathValue = optsLink:Peek("showPath") == true
		pathRenderer.setEnabled(enabled == true and showPathValue)
	end)
	self:Track(enabledWatch)

	local showPathWatch = optsLink:Watch("showPath", function(value: any)
		local enabled = link:Peek("grenadeWarning") == true
		pathRenderer.setEnabled(enabled and value == true)
	end)
	self:Track(showPathWatch)

	self:Track(bindColor(pathOpts:Get("enemyPathColor")._currentColor, pathRenderer.setEnemyPathColor))
	self:Track(bindColor(pathOpts:Get("friendlyPathColor")._currentColor, pathRenderer.setFriendlyPathColor))
	self:Track(bindColor(pathOpts:Get("enemyEndColor")._currentColor, pathRenderer.setEnemyEndColor))
	self:Track(bindColor(pathOpts:Get("friendlyEndColor")._currentColor, pathRenderer.setFriendlyEndColor))

	local enabledNow = link:Peek("grenadeWarning") == true
	local showPathNow = optsLink:Peek("showPath") == true
	pathRenderer.setEnabled(enabledNow and showPathNow)

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
	self._root:render(e(warningRenderer, {
		enabledLink = self._enabledLink,
		heColorLink = self._heColorLink,
		fireColorLink = self._fireColorLink,
		bgColorLink = self._bgColorLink,
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
			_heColorLink: any,
			_fireColorLink: any,
			_bgColorLink: any,
			_screenGui: Instance,
			_root: ReactRoblox.RootType,
		},
		GrenadeWarning
	))
	& BaseFeature.BaseFeature

return GrenadeWarning
