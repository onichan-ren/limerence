local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local droppedIndicatorRenderer = require("@game/bloxstrike/feature/visual/dropped/droppedIndicatorRenderer")

local e = React.createElement

local DEFAULT_WEAPON_TEXT = Color3.fromRGB(200, 200, 200)
local DEFAULT_BOMB_COLOR = Color3.fromRGB(220, 190, 110)
local DEFAULT_ITEM_COLOR = Color3.fromRGB(145, 190, 215)
local DEFAULT_OUTLINE = Color3.fromRGB(18, 18, 18)
local DEFAULT_AMMO_FILL = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 95, 95)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 186, 160)),
})
local DEFAULT_AMMO_BACKGROUND = Color3.fromRGB(42, 42, 42)

local DroppedItemIndicator = {}
DroppedItemIndicator.__index = DroppedItemIndicator

setmetatable(DroppedItemIndicator, { __index = BaseFeature })

function DroppedItemIndicator.new(link: gameUi.Linker): DroppedItemIndicator
	local self = BaseFeature.new() :: any
	setmetatable(self, DroppedItemIndicator)

	link:Toggle("droppedItems", "Dropped Items", false):SetTip({
		title = "Dropped Items",
		body = "Small on-screen markers for weapons, C4, and grenades on the ground.",
	})
	local masterLink = link:OnKey("droppedItems")
	masterLink:Submenu("opts", "Dropped Item Options")
	local optsLink = masterLink:OnKey("opts")

	optsLink:Toggle("weapon", "Dropped Weapons", true)
	local weaponLink = optsLink:OnKey("weapon")
	weaponLink:Submenu("opts", "Dropped Weapon Options")
	local weaponOptsLink = weaponLink:OnKey("opts")

	weaponOptsLink:Colorpicker("textColor", "Text Color", DEFAULT_WEAPON_TEXT)
	weaponOptsLink:Toggle("textOutline", "Text Outline", true)
	local textOutlineLink = weaponOptsLink:OnKey("textOutline")
	textOutlineLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)

	weaponOptsLink:Toggle("showAmmo", "Ammo Bar", true):SetTip({
		title = "Ammo Bar",
		body = "Shows how much ammo was left in the gun when it was dropped.",
	})
	local ammoLink = weaponOptsLink:OnKey("showAmmo")
	ammoLink:Colorpicker("color", "Fill", DEFAULT_AMMO_FILL, 0):SetTip({
		title = "Fill",
		body = "Gradient along the ammo bar (left to right).",
	})
	ammoLink:Submenu("opts", "Ammo Bar Options")
	local ammoOptsLink = ammoLink:OnKey("opts")
	ammoOptsLink:Toggle("outline", "Outline", true)
	local barOutlineLink = ammoOptsLink:OnKey("outline")
	barOutlineLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)
	ammoOptsLink:Colorpicker("backgroundColor", "Background", DEFAULT_AMMO_BACKGROUND, 0)

	optsLink:Toggle("bomb", "Dropped Bomb", true)
	local bombLink = optsLink:OnKey("bomb")
	bombLink:Colorpicker("color", "Color", DEFAULT_BOMB_COLOR)

	optsLink:Toggle("item", "Dropped Items", true):SetTip({
		title = "Dropped Items",
		body = "Grenades and other droppable equipment.",
	})
	local itemLink = optsLink:OnKey("item")
	itemLink:Colorpicker("color", "Color", DEFAULT_ITEM_COLOR)

	self._enabledLink = link:Get("droppedItems")
	self._weaponLink = link:Get("droppedItems.opts.weapon")
	self._bombLink = link:Get("droppedItems.opts.bomb")
	self._itemLink = link:Get("droppedItems.opts.item")
	self._weaponTextColorLink = link:Get("droppedItems.opts.weapon.opts.textColor")
	self._weaponTextOutlineLink = link:Get("droppedItems.opts.weapon.opts.textOutline")
	self._weaponTextOutlineColorLink = link:Get("droppedItems.opts.weapon.opts.textOutline.outlineColor")
	self._weaponAmmoLink = link:Get("droppedItems.opts.weapon.opts.showAmmo")
	self._weaponAmmoFillLink = link:Get("droppedItems.opts.weapon.opts.showAmmo.color")
	self._weaponAmmoBackgroundLink = link:Get("droppedItems.opts.weapon.opts.showAmmo.opts.backgroundColor")
	self._weaponBarOutlineLink = link:Get("droppedItems.opts.weapon.opts.showAmmo.opts.outline")
	self._weaponBarOutlineColorLink = link:Get("droppedItems.opts.weapon.opts.showAmmo.opts.outline.outlineColor")
	self._bombColorLink = link:Get("droppedItems.opts.bomb.color")
	self._itemColorLink = link:Get("droppedItems.opts.item.color")

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
	self._root:render(e(droppedIndicatorRenderer, {
		enabledLink = self._enabledLink,
		weaponLink = self._weaponLink,
		bombLink = self._bombLink,
		itemLink = self._itemLink,
		weaponTextColorLink = self._weaponTextColorLink,
		weaponTextOutlineLink = self._weaponTextOutlineLink,
		weaponTextOutlineColorLink = self._weaponTextOutlineColorLink,
		weaponAmmoLink = self._weaponAmmoLink,
		weaponAmmoFillLink = self._weaponAmmoFillLink,
		weaponAmmoBackgroundLink = self._weaponAmmoBackgroundLink,
		weaponBarOutlineLink = self._weaponBarOutlineLink,
		weaponBarOutlineColorLink = self._weaponBarOutlineColorLink,
		bombColorLink = self._bombColorLink,
		itemColorLink = self._itemColorLink,
	}))

	return self
end

function DroppedItemIndicator.Destroy(self: DroppedItemIndicator): ()
	if self._root then
		self._root:unmount()
	end
	if self._screenGui then
		self._screenGui:Destroy()
	end
	BaseFeature.Destroy(self)
end

export type DroppedItemIndicator =
	typeof(setmetatable(
		{} :: {
			_enabledLink: any,
			_weaponLink: any,
			_bombLink: any,
			_itemLink: any,
			_weaponTextColorLink: any,
			_weaponTextOutlineLink: any,
			_weaponTextOutlineColorLink: any,
			_weaponAmmoLink: any,
			_weaponAmmoFillLink: any,
			_weaponAmmoBackgroundLink: any,
			_weaponBarOutlineLink: any,
			_weaponBarOutlineColorLink: any,
			_bombColorLink: any,
			_itemColorLink: any,
			_screenGui: Instance,
			_root: ReactRoblox.RootType,
		},
		DroppedItemIndicator
	))
	& BaseFeature.BaseFeature

return DroppedItemIndicator
