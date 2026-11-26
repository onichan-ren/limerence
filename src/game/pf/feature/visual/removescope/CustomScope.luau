local RunService = cloneref(game:GetService("RunService")) :: RunService
local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local BaseFeature = require("@game/BaseFeature")
local ModuleController = require("@game/pf/module/ModuleController")
local customScope = require("@game/universal/feature/visual/removescope/customScope")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local hook = require("@share/hook")

local e = React.createElement
local peek = Charm.peek
local subscribeToBinding = (React :: any).__subscribeToBinding

local MODES = { "Remove Background", "Remove All", "Custom" }
local DEFAULT_SCOPE_COLOR = Color3.fromRGB(18, 18, 18)
local DEFAULT_CUSTOM_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(225, 225, 225)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
})
local LINE_THICKNESS = 2
local DYNAMIC_GAP_MAX_PX = 140

local CustomScope = {}
CustomScope.__index = CustomScope

setmetatable(CustomScope, { __index = BaseFeature })

function CustomScope.new(link: gameUi.Linker): CustomScope
	local self = BaseFeature.new() :: any
	setmetatable(self, CustomScope)

	link:Toggle("customScope", "Custom Scope Overlay", false):SetTip({
		title = "Custom Scope Overlay",
		body = "Changes or removes the scope sight picture while aiming.",
	})
	local removeLink = link:OnKey("customScope")
	removeLink:Submenu("opts", "Custom Scope Overlay")
	local optsLink = removeLink:OnKey("opts")
	optsLink:Dropdown("mode", "Mode", MODES, "Remove Background"):SetTip({
		title = "Mode",
		body = "Remove Background hides the scope art and shows a simple crosshair. Remove All hides the full overlay. Custom draws your own crosshair with the sliders below.",
	})
	optsLink:Colorpicker("scopeColor", "Scope Color", DEFAULT_SCOPE_COLOR, 0):SetTip({
		title = "Scope Color",
		body = "Color of the simple crosshair drawn in Remove Background mode.",
	})
	optsLink:Submenu("custom", "Custom Crosshair")
	local customLink = optsLink:OnKey("custom")
	customLink:Colorpicker("color", "Color", DEFAULT_CUSTOM_COLOR, 0):SetTip({
		title = "Color",
		body = "Color or gradient applied to the custom crosshair arms.",
	})
	customLink:Slider("gap", "Gap", 8, 0, 80, 1, nil, "px"):SetTip({
		title = "Gap",
		body = "Pixel distance from the center to the inner edge of each arm.",
	})
	customLink:Slider("length", "Length", 14, 1, 80, 1, nil, "px"):SetTip({
		title = "Length",
		body = "Pixel length of each arm.",
	})
	customLink:Slider("thickness", "Thickness", 3, 1, 12, 1, nil, "px"):SetTip({
		title = "Thickness",
		body = "Pixel thickness of each arm.",
	})
	customLink:Toggle("dynamicGap", "Dynamic Gap", false):SetTip({
		title = "Dynamic Gap",
		body = "Expands the gap when your weapon's spread grows (movement, jumping).",
	})

	self._enabled = false
	self._mode = optsLink:Get("mode"):Peek()
	self._optsLink = optsLink
	self._scopeInterface = nil
	self._displayScope = nil
	self._frontLayer = nil
	self._rearLayer = nil
	self._originalSetScope = nil
	self._scoped = false
	self._screenGui = nil
	self._hLine = nil
	self._vLine = nil
	self._customScreenGui = nil
	self._customRoot = nil
	self._customVisibleAtom = Charm.atom(false)
	self._spreadAtom = Charm.atom(0)
	self._crossInterface = nil
	self._leftLine = nil
	self._spreadConn = nil
	self._dynamicGapLink = customLink:Get("dynamicGap")

	self:Track(link:Get("customScope"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optsLink:Get("mode"):OnChange(function(value: string): ()
		self._mode = value
		if self._enabled and self._scoped then
			self:_apply()
		end
	end))

	self:Track(subscribeToBinding(optsLink:Get("scopeColor")._currentColor, function(value: Color3): ()
		if self._hLine then
			self._hLine.BackgroundColor3 = value
		end
		if self._vLine then
			self._vLine.BackgroundColor3 = value
		end
	end))

	return self
end

function CustomScope._resolveScope(self: CustomScope): ()
	if self._displayScope then
		return
	end
	local scopeInterface = self._scopeInterface or ModuleController.GetModule("HudScopeInterface")
	if not scopeInterface then
		return
	end
	self._scopeInterface = scopeInterface
	local setScope = rawget(scopeInterface, "setScope")
	local displayScope = setScope and debug.getupvalue(setScope, 1) :: any
	self._displayScope = displayScope
	if displayScope then
		self._frontLayer = displayScope:FindFirstChild("ImageFrontLayer")
		self._rearLayer = displayScope:FindFirstChild("ImageRearLayer")
	end
end

function CustomScope._resolveCross(self: CustomScope): ()
	if self._leftLine then
		return
	end
	local crossInterface = self._crossInterface or ModuleController.GetModule("HudCrosshairsInterface")
	if not crossInterface then
		return
	end
	self._crossInterface = crossInterface
	local disable = rawget(crossInterface, "disable")
	local displayCross = disable and debug.getupvalue(disable, 1) :: any
	if displayCross then
		self._leftLine = displayCross:FindFirstChild("Left")
	end
end

function CustomScope._createOverlay(self: CustomScope): ()
	if self._screenGui then
		return
	end
	local color = (self._optsLink:Get("scopeColor")._currentColor :: any):getValue() :: Color3

	local screenGui = instances.new("ScreenGui", {
		Name = "CustomScopeSimple",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25,
		Enabled = false,
		Secure = true,
	}, cloneref(gethui())) :: ScreenGui

	local hLine = instances.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, LINE_THICKNESS),
	}, screenGui) :: Frame

	local vLine = instances.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, LINE_THICKNESS, 1, 0),
	}, screenGui) :: Frame

	self._screenGui = screenGui
	self._hLine = hLine
	self._vLine = vLine
end

function CustomScope._destroyOverlay(self: CustomScope): ()
	if self._screenGui then
		self._screenGui:Destroy()
		self._screenGui = nil
		self._hLine = nil
		self._vLine = nil
	end
end

function CustomScope._createCustomOverlay(self: CustomScope): ()
	if self._customScreenGui then
		return
	end
	local screenGui = instances.new("ScreenGui", {
		Name = "CustomScopeCustom",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 26,
		Enabled = true,
		Secure = true,
	}, cloneref(gethui())) :: ScreenGui

	local customLink = self._optsLink:OnKey("custom")
	local root = ReactRoblox.createRoot(screenGui)
	root:render(e(customScope, {
		enabledAtom = self._customVisibleAtom,
		gapLink = customLink:Get("gap"),
		lengthLink = customLink:Get("length"),
		thicknessLink = customLink:Get("thickness"),
		colorLink = customLink:Get("color"),
		spreadAtom = self._spreadAtom,
	}))

	self._customScreenGui = screenGui
	self._customRoot = root
end

function CustomScope._destroyCustomOverlay(self: CustomScope): ()
	if self._customRoot then
		self._customRoot:unmount()
		self._customRoot = nil
	end
	if self._customScreenGui then
		self._customScreenGui:Destroy()
		self._customScreenGui = nil
	end
	self._customVisibleAtom(false)
	self._spreadAtom(0)
end

function CustomScope._bindDynamicSpread(self: CustomScope): ()
	if self._spreadConn then
		return
	end
	local custom = "Custom"
	self._spreadConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
		local shouldRun = self._enabled and self._scoped and self._mode == custom
		if not shouldRun or not self._dynamicGapLink:Peek() then
			if peek(self._spreadAtom) ~= 0 then
				self._spreadAtom(0)
			end
			return
		end
		local line = self._leftLine :: any
		if not line then
			self:_resolveCross()
			line = self._leftLine
			if not line then
				return
			end
		end
		local px = math.min(math.abs(line.Position.X.Offset), DYNAMIC_GAP_MAX_PX)
		if peek(self._spreadAtom) ~= px then
			self._spreadAtom(px)
		end
	end))
end

function CustomScope._unbindDynamicSpread(self: CustomScope): ()
	if self._spreadConn then
		self._spreadConn:Disconnect()
		self._spreadConn = nil
	end
	self._spreadAtom(0)
end

function CustomScope._apply(self: CustomScope): ()
	local frame = self._displayScope :: any
	if not frame then
		return
	end
	local front = self._frontLayer :: any
	local rear = self._rearLayer :: any
	local mode = self._mode

	if mode == "Remove Background" then
		frame.Visible = true
		if front then
			front.Visible = false
		end
		if rear then
			rear.Visible = false
		end
		if self._screenGui then
			self._screenGui.Enabled = true
		end
		self._customVisibleAtom(false)
	elseif mode == "Remove All" then
		if front then
			front.Visible = true
		end
		if rear then
			rear.Visible = true
		end
		frame.Visible = false
		if self._screenGui then
			self._screenGui.Enabled = false
		end
		self._customVisibleAtom(false)
	else
		if front then
			front.Visible = true
		end
		if rear then
			rear.Visible = true
		end
		frame.Visible = false
		if self._screenGui then
			self._screenGui.Enabled = false
		end
		self._customVisibleAtom(true)
	end
end

function CustomScope._restore(self: CustomScope): ()
	local frame = self._displayScope :: any
	if self._frontLayer then
		(self._frontLayer :: any).Visible = true
	end
	if self._rearLayer then
		(self._rearLayer :: any).Visible = true
	end
	if frame and self._scoped then
		frame.Visible = true
	end
	if self._screenGui then
		self._screenGui.Enabled = false
	end
	self._customVisibleAtom(false)
end

function CustomScope._installHook(self: CustomScope): ()
	self:_resolveScope()
	local scopeInterface = self._scopeInterface
	if not scopeInterface then
		return
	end
	local setScope = rawget(scopeInterface, "setScope")
	if not setScope or self._originalSetScope then
		return
	end

	local original: (boolean, boolean) -> ()
	original = hook.add(
		setScope :: any,
		LPH_NO_VIRTUALIZE(function(visible: boolean, steady: boolean): ()
			original(visible, steady)
			setthreadidentity(8)
			self._scoped = visible
			if not self._enabled then
				return
			end
			if visible then
				self:_apply()
			else
				self:_restore()
			end
			setthreadidentity(2)
		end)
	) :: any
	self._originalSetScope = original

	local frame = self._displayScope :: any
	if frame then
		self._scoped = frame.Visible
	end
end

function CustomScope._uninstallHook(self: CustomScope): ()
	if self._originalSetScope then
		hook.restore(self._originalSetScope :: any)
		self._originalSetScope = nil
	end
end

function CustomScope.Enable(self: CustomScope): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self:_createOverlay()
	self:_createCustomOverlay()
	self:_resolveCross()
	self:_bindDynamicSpread()
	self:_installHook()
	if self._scoped then
		self:_apply()
	end
end

function CustomScope.Disable(self: CustomScope): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self:_restore()
	self:_uninstallHook()
	self:_unbindDynamicSpread()
	self:_destroyOverlay()
	self:_destroyCustomOverlay()
end

function CustomScope.Destroy(self: CustomScope): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type CustomScope =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_mode: string,
			_optsLink: gameUi.Linker,
			_scopeInterface: any?,
			_displayScope: GuiObject?,
			_frontLayer: GuiObject?,
			_rearLayer: GuiObject?,
			_originalSetScope: ((boolean, boolean) -> ())?,
			_scoped: boolean,
			_screenGui: ScreenGui?,
			_hLine: Frame?,
			_vLine: Frame?,
			_customScreenGui: ScreenGui?,
			_customRoot: ReactRoblox.RootType?,
			_customVisibleAtom: Charm.Atom<boolean>,
			_spreadAtom: Charm.Atom<number>,
			_crossInterface: any?,
			_leftLine: GuiObject?,
			_spreadConn: RBXScriptConnection?,
			_dynamicGapLink: any,
			Enable: (CustomScope) -> (),
			Disable: (CustomScope) -> (),
		},
		CustomScope
	))
	& BaseFeature.BaseFeature

return CustomScope
