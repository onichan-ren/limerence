local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local warningRenderer = require("@game/rivals/feature/visual/grenade/warningRenderer")

local e = React.createElement

local DEFAULT_HE_COLOR = Color3.fromRGB(195, 110, 110)
local DEFAULT_FIRE_COLOR = Color3.fromRGB(220, 190, 110)
local DEFAULT_BG_COLOR = Color3.fromRGB(28, 28, 28)

local GrenadeWarning = {}
GrenadeWarning.__index = GrenadeWarning

setmetatable(GrenadeWarning, { __index = BaseFeature })

function GrenadeWarning.new(link: gameUi.Linker): GrenadeWarning
	local self = BaseFeature.new() :: any
	setmetatable(self, GrenadeWarning)

	link:Toggle("throwableWarning", "Throwable Warning", false):SetTip({
		title = "Throwable Warning",
		body = "Warns when a grenade or molotov is close enough to matter.",
	})
	local warningLink = link:OnKey("throwableWarning")
	warningLink:Submenu("opts", "Throwable Warning Options")
	warningLink = warningLink:OnKey("opts")
	warningLink:Colorpicker("bgColor", "Background Color", DEFAULT_BG_COLOR)
	warningLink:Colorpicker("fireColor", "Molotov Color", DEFAULT_FIRE_COLOR)
	warningLink:Colorpicker("heColor", "Grenade Color", DEFAULT_HE_COLOR)

	self._enabledLink = link:Get("throwableWarning")
	self._heColorLink = link:Get("throwableWarning.opts.heColor")
	self._fireColorLink = link:Get("throwableWarning.opts.fireColor")
	self._bgColorLink = link:Get("throwableWarning.opts.bgColor")

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
	if self._root then
		self._root:unmount()
	end
	if self._screenGui then
		self._screenGui:Destroy()
	end
	BaseFeature.Destroy(self)
end

export type GrenadeWarning = typeof(setmetatable(
	{} :: {
		_enabledLink: any,
		_heColorLink: any,
		_fireColorLink: any,
		_bgColorLink: any,
		_screenGui: Instance,
		_root: ReactRoblox.RootType,
	},
	GrenadeWarning
)) & BaseFeature.BaseFeature

return GrenadeWarning
