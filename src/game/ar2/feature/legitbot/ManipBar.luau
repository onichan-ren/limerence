local RunService = cloneref(game:GetService("RunService")) :: RunService
local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRoblox = require("@pkg/ReactRoblox")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local themeState = require("@ui/theme/themeState")
local useShadow = require("@ui/hook/useShadow")
local bulletRedirection = require("@game/ar2/feature/legitbot/bulletRedirection")

local e = React.createElement
local peek = Charm.peek
local useAt = ReactCharm.useAtom

local elementColors = themeState.colors.window.element

local DEFAULT_LOW = Color3.fromRGB(225, 45, 45)
local DEFAULT_HIGH = Color3.fromRGB(60, 220, 70)
local DEFAULT_BG = Color3.fromRGB(18, 18, 22)
local DEFAULT_SHADOW = Color3.fromRGB(0, 0, 0)

local toColor3 = LPH_NO_VIRTUALIZE(function(v: any): Color3
	if typeof(v) == "ColorSequence" then
		local kp = v.Keypoints[1]
		return (kp and kp.Value) or Color3.new(1, 1, 1)
	end
	return v
end)

local lerp = LPH_NO_VIRTUALIZE(function(a: number, b: number, t: number): number
	return a + (b - a) * t
end)

local function ManipBarView(props: {
	alphaAtom: Charm.Atom<number>,
	fillAtom: Charm.Atom<number>,
	colorAtom: Charm.Atom<Color3>,
	yLink: any,
	widthLink: any,
	thicknessLink: any,
	bgLink: any,
	shadowLink: any,
}): React.Element<any>
	local alpha = useAt(props.alphaAtom)
	local fill = math.clamp(useAt(props.fillAtom), 0, 1)
	local color = useAt(props.colorAtom)
	local y = useAt(props.yLink._state) :: number
	local width = useAt(props.widthLink._state) :: number
	local thickness = useAt(props.thicknessLink._state) :: number
	local bg = toColor3(useAt(props.bgLink._state))
	local bgT = (useAt(props.bgLink._transparency) or 0) :: number
	local shadow = toColor3(useAt(props.shadowLink._state))
	local shadowT = (useAt(props.shadowLink._transparency) or 0.35) :: number

	local surfaceStroke = useAt(elementColors.surfaceStroke)

	local pop = lerp(0.9, 1, alpha)
	local riseY = y + (1 - alpha) * 0.012

	return e("Frame", {
		Name = "ManipBar",
		Visible = alpha > 0.01,
		Size = UDim2.fromOffset((width + 4) * pop, (thickness + 4) * pop),
		Position = UDim2.fromScale(0.5, riseY),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = bg,
		BackgroundTransparency = lerp(1, bgT, alpha),
		BorderSizePixel = 0,
	}, {
		Shadow = useShadow({
			color = shadow,
			transparency = lerp(1, shadowT, alpha),
			multiplier = Vector2.new(1.45, 4.5),
			zIndex = 0,
		}),
		UICorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIStroke = e("UIStroke", {
			Color = surfaceStroke,
			Thickness = 1,
			Transparency = lerp(1, 0.4, alpha),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		}),
		Fill = e("Frame", {
			Name = "Fill",
			Size = UDim2.new(fill, 0, 1, 0),
			Position = UDim2.fromScale(0, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = lerp(1, 0.05, alpha),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
	})
end

local ManipBar = {}
ManipBar.__index = ManipBar

setmetatable(ManipBar, { __index = BaseFeature })

function ManipBar.new(link: gameUi.Linker): ManipBar
	local self = BaseFeature.new() :: any
	setmetatable(self, ManipBar)

	local toggle = link:Toggle("manipBar", "Manipulation Bar", false):SetTip({
		title = "Manipulation Bar",
		body = "Shows a meter under your crosshair for how reachable your target is.",
	})
	local barLink = link:OnKey("manipBar")
	barLink:Extra(toggle, "opts", "Submenu", "Manipulation Bar")
	local optsLink = barLink:OnKey("opts")

	optsLink:Slider("yOffset", "Y Position", 0.55, 0.05, 0.95, 0.01):SetTip({
		title = "Y Position",
		body = "Vertical screen position of the bar.",
	})
	optsLink:Slider("width", "Width", 120, 20, 400, 1, nil, "px"):SetTip({
		title = "Width",
		body = "Pixel width of the bar.",
	})
	optsLink:Slider("thickness", "Thickness", 3, 3, 6, 1, nil, "px"):SetTip({
		title = "Thickness",
		body = "Pixel height of the bar.",
	})
	optsLink:Colorpicker("lowColor", "No Reach", DEFAULT_LOW):SetTip({
		title = "No Reach",
		body = "Color when the target can't be reached.",
	})
	optsLink:Colorpicker("highColor", "Full Reach", DEFAULT_HIGH):SetTip({
		title = "Full Reach",
		body = "Color when the target is fully reachable.",
	})
	optsLink:Colorpicker("bgColor", "Background", DEFAULT_BG, 0):SetTip({
		title = "Background",
		body = "Color and opacity of the bar track behind the fill.",
	})
	optsLink:Colorpicker("shadowColor", "Shadow", DEFAULT_SHADOW, 0.35):SetTip({
		title = "Shadow",
		body = "Color and opacity of the drop shadow behind the bar.",
	})

	self._enabled = false
	self._optsLink = optsLink
	self._lowLink = optsLink:Get("lowColor")
	self._highLink = optsLink:Get("highColor")
	self._alphaAtom = Charm.atom(0)
	self._fillAtom = Charm.atom(0)
	self._colorAtom = Charm.atom(DEFAULT_LOW)
	self._screenGui = nil
	self._root = nil
	self._renderConn = nil

	self:Track(link:Get("manipBar"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("manipBar") then
		self:Enable()
	end

	return self
end

function ManipBar._createOverlay(self: ManipBar): ()
	if self._screenGui then
		return
	end

	local screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25,
		Enabled = true,
		Secure = true,
	}, cloneref(gethui())) :: ScreenGui

	local root = ReactRoblox.createRoot(screenGui)
	root:render(e(ManipBarView, {
		alphaAtom = self._alphaAtom,
		fillAtom = self._fillAtom,
		colorAtom = self._colorAtom,
		yLink = self._optsLink:Get("yOffset"),
		widthLink = self._optsLink:Get("width"),
		thicknessLink = self._optsLink:Get("thickness"),
		bgLink = self._optsLink:Get("bgColor"),
		shadowLink = self._optsLink:Get("shadowColor"),
	}))

	self._screenGui = screenGui
	self._root = root
end

function ManipBar._destroyOverlay(self: ManipBar): ()
	if self._root then
		self._root:unmount()
		self._root = nil
	end
	if self._screenGui then
		self._screenGui:Destroy()
		self._screenGui = nil
	end
	self._alphaAtom(0)
end

function ManipBar._bindRender(self: ManipBar): ()
	if self._renderConn then
		return
	end

	local alphaAtom = self._alphaAtom
	local fillAtom = self._fillAtom
	local colorAtom = self._colorAtom
	local lowLink = self._lowLink
	local highLink = self._highLink

	local FILL_RATE = 16
	local FADE_RATE = 13

	self._renderConn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
		dt = math.min(dt, 0.1)

		local level = peek(bulletRedirection.manipLevel)
		local active = level ~= nil

		local targetAlpha = active and 1 or 0
		local alpha = peek(alphaAtom)
		alpha += (targetAlpha - alpha) * math.min(dt * FADE_RATE, 1)
		if math.abs(alpha - targetAlpha) < 0.004 then
			alpha = targetAlpha
		end
		if peek(alphaAtom) ~= alpha then
			alphaAtom(alpha)
		end

		if not active and alpha <= 0 then
			return
		end

		if active then
			local target = math.clamp(level, 0, 1)
			local fill = peek(fillAtom)
			fill += (target - fill) * math.min(dt * FILL_RATE, 1)
			if math.abs(fill - target) < 0.001 then
				fill = target
			end
			fillAtom(fill)
		end

		local color = toColor3(peek(lowLink._state)):Lerp(toColor3(peek(highLink._state)), peek(fillAtom))
		if peek(colorAtom) ~= color then
			colorAtom(color)
		end
	end))
end

function ManipBar._unbindRender(self: ManipBar): ()
	if self._renderConn then
		self._renderConn:Disconnect()
		self._renderConn = nil
	end
end

function ManipBar.Enable(self: ManipBar): ()
	if self._enabled then
		return
	end
	self._enabled = true
	bulletRedirection.setManipBarActive(true)
	self:_createOverlay()
	self:_bindRender()
end

function ManipBar.Disable(self: ManipBar): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self:_unbindRender()
	bulletRedirection.setManipBarActive(false)
	self:_destroyOverlay()
end

function ManipBar.Destroy(self: ManipBar): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type ManipBar =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_optsLink: gameUi.Linker,
			_lowLink: any,
			_highLink: any,
			_alphaAtom: Charm.Atom<number>,
			_fillAtom: Charm.Atom<number>,
			_colorAtom: Charm.Atom<Color3>,
			_screenGui: ScreenGui?,
			_root: ReactRoblox.RootType?,
			_renderConn: RBXScriptConnection?,
		},
		ManipBar
	))
	& BaseFeature.BaseFeature

return ManipBar
