local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local cameraRenderer = require("@game/op1/feature/visual/camera/cameraRenderer")

local HIDDEN_UI = cloneref(gethui())

local e = React.createElement

local DEFAULT_ENEMY_COLOR = Color3.fromRGB(235, 110, 110)
local DEFAULT_FRIENDLY_COLOR = Color3.fromRGB(120, 180, 230)
local DEFAULT_LOCAL_COLOR = Color3.fromRGB(130, 220, 150)
local DEFAULT_NEUTRAL_COLOR = Color3.fromRGB(220, 220, 220)
local DEFAULT_BG_COLOR = Color3.fromRGB(28, 28, 28)

local CameraIndicator = {}
CameraIndicator.__index = CameraIndicator

setmetatable(CameraIndicator, { __index = BaseFeature })

export type CameraIndicator = typeof(setmetatable({} :: any, CameraIndicator))

function CameraIndicator.new(link: gameUi.Linker): CameraIndicator
	local self = BaseFeature.new() :: any
	setmetatable(self, CameraIndicator)

	link:Toggle("cameraEsp", "Camera ESP", false):SetTip({
		title = "Camera ESP",
		body = "Marks observation cameras placed around the map.",
	})
	link:Extra(link:Get("cameraEsp"), "cameraEspOpts", "Submenu", "Camera ESP")
	local optsLink = link:OnKey("cameraEspOpts")

	local enemyToggle = optsLink:Toggle("showEnemy", "Enemy", true)
	enemyToggle:SetTip({
		title = "Enemy",
		body = "Show enemy cameras.",
	})
	optsLink:Extra(enemyToggle, "enemyColor", "Colorpicker", "Enemy", DEFAULT_ENEMY_COLOR, 0)

	local friendlyToggle = optsLink:Toggle("showFriendly", "Friendly", true)
	friendlyToggle:SetTip({
		title = "Friendly",
		body = "Show teammate cameras.",
	})
	optsLink:Extra(friendlyToggle, "friendlyColor", "Colorpicker", "Friendly", DEFAULT_FRIENDLY_COLOR, 0)

	local localToggle = optsLink:Toggle("showLocal", "Local", true)
	localToggle:SetTip({
		title = "Local",
		body = "Show your own cameras.",
	})
	optsLink:Extra(localToggle, "localColor", "Colorpicker", "Local", DEFAULT_LOCAL_COLOR, 0)

	local neutralToggle = optsLink:Toggle("showNeutral", "Neutral", false)
	neutralToggle:SetTip({
		title = "Neutral",
		body = "Show unowned map cameras.",
	})
	optsLink:Extra(neutralToggle, "neutralColor", "Colorpicker", "Neutral", DEFAULT_NEUTRAL_COLOR, 0)

	optsLink:Colorpicker("bgColor", "Background", DEFAULT_BG_COLOR, 0):SetTip({
		title = "Background",
		body = "Marker background color.",
	})

	self._screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 15,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Secure = true,
	}, HIDDEN_UI) :: ScreenGui

	self._root = ReactRoblox.createRoot(self._screenGui)
	self._root:render(e(cameraRenderer, {
		enabledLink = link:Get("cameraEsp"),
		enemyColorLink = optsLink:Get("enemyColor"),
		friendlyColorLink = optsLink:Get("friendlyColor"),
		localColorLink = optsLink:Get("localColor"),
		neutralColorLink = optsLink:Get("neutralColor"),
		bgColorLink = optsLink:Get("bgColor"),
		showEnemyLink = optsLink:Get("showEnemy"),
		showFriendlyLink = optsLink:Get("showFriendly"),
		showLocalLink = optsLink:Get("showLocal"),
		showNeutralLink = optsLink:Get("showNeutral"),
	}))

	return self
end

function CameraIndicator.Destroy(self: CameraIndicator): ()
	if self._root then
		self._root:unmount()
		self._root = nil
	end
	if self._screenGui then
		self._screenGui:Destroy()
		self._screenGui = nil
	end
	BaseFeature.Destroy(self)
end

return CameraIndicator
