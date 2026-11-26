local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local Charm = require("@pkg/Charm")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local bombState = require("@game/bloxstrike/bomb/bombState")
local bombHudRenderer = require("@game/bloxstrike/feature/visual/world/bombHudRenderer")
local dpiState = require("@ui/util/dpiState")
local ReactCharm = require("@pkg/ReactCharm")

local peek = Charm.peek
local e = React.createElement

local HUD_DISPLAY_ORDER = 101

local BombHud = {}
BombHud.__index = BombHud

setmetatable(BombHud, { __index = BaseFeature })

function BombHud.new(link: gameUi.Linker): BombHud
	local self = BaseFeature.new() :: any
	setmetatable(self, BombHud)

	link:Toggle("bombHud", "Bomb HUD", false):SetTip({
		title = "Bomb HUD",
		body = "Draggable HUD with timer and damage estimate while a bomb is planted or planting.",
	})

	self._enabledLink = link:Get("bombHud")
	self:_syncHudEnabled()

	local hudGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Enabled = true,
		DisplayOrder = HUD_DISPLAY_ORDER,
	}, cloneref(gethui()))
	self._hudGui = hudGui

	self._hudRoot = ReactRoblox.createRoot(hudGui)

	local function BombHudRoot(): React.Element<any>
		local scale = ReactCharm.useAtom(dpiState.scale)
		return e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, {
			UIScale = e("UIScale", { Scale = scale }),
			Hud = e(bombHudRenderer),
		})
	end

	self._hudRoot:render(e(BombHudRoot))

	self:Track(self._enabledLink:OnChange(function(): ()
		self:_syncHudEnabled()
	end))

	return self
end

function BombHud._syncHudEnabled(self: BombHud): ()
	bombState.hudEnabled(peek(self._enabledLink._state) == true)
end

function BombHud.Destroy(self: BombHud): ()
	bombState.hudEnabled(false)
	if self._hudRoot then
		self._hudRoot:unmount()
	end
	if self._hudGui then
		self._hudGui:Destroy()
	end
	BaseFeature.Destroy(self)
end

export type BombHud =
	typeof(setmetatable(
		{} :: {
			_enabledLink: any,
			_hudGui: Instance,
			_hudRoot: ReactRoblox.RootType,
		},
		BombHud
	))
	& BaseFeature.BaseFeature

return BombHud
