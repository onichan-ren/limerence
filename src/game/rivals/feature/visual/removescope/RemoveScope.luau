local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local BaseFeature = require("@game/BaseFeature")
local ModuleController = require("@game/rivals/module/ModuleController")
local customScope = require("@game/universal/feature/visual/removescope/customScope")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local hook = require("@share/hook")

local e = React.createElement
local subscribeToBinding = (React :: any).__subscribeToBinding

local MODES = { "Remove Background", "Remove All", "Custom" }
local DEFAULT_SCOPE_COLOR = Color3.fromRGB(18, 18, 18)
local DEFAULT_CUSTOM_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(225, 225, 225)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
})
local LINE_THICKNESS = 2

local RemoveScope = {}
RemoveScope.__index = RemoveScope

setmetatable(RemoveScope, { __index = BaseFeature })

function RemoveScope.new(link: gameUi.Linker): RemoveScope
	local self = BaseFeature.new() :: any
	setmetatable(self, RemoveScope)

	link:Toggle("removeScope", "Remove Scope Overlay", false):SetTip({
		title = "Remove Scope Overlay",
		body = "Removes the sniper scope visuals while aiming.",
	})
	local removeLink = link:OnKey("removeScope")
	removeLink:Submenu("opts", "Remove Scope Overlay")
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

	self._janitor = Janitor.new()
	self._enabled = false
	self._mode = optsLink:Get("mode"):Peek()
	self._optsLink = optsLink
	self._currentScope = nil
	self._isScopeActive = false
	self._scopeClass = nil
	self._originalSetActive = nil
	self._setActiveHooked = false
	self._screenGui = nil
	self._hLine = nil
	self._vLine = nil
	self._customScreenGui = nil
	self._customRoot = nil
	self._customVisibleAtom = Charm.atom(false)
	self._spreadAtom = Charm.atom(0)

	self:Track(link:Get("removeScope"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optsLink:Get("mode"):OnChange(function(value: string): ()
		self._mode = value
		if self._enabled and self._isScopeActive then
			self:_restoreScope()
			self:_applyMode()
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

function RemoveScope._createOverlay(self: RemoveScope): ()
	if self._screenGui then
		return
	end
	local color = (self._optsLink:Get("scopeColor")._currentColor :: any):getValue() :: Color3

	local screenGui = instances.new("ScreenGui", {
		Name = "RemoveScopeOverlay",
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

function RemoveScope._destroyOverlay(self: RemoveScope): ()
	if self._screenGui then
		self._screenGui:Destroy()
		self._screenGui = nil
		self._hLine = nil
		self._vLine = nil
	end
end

function RemoveScope._createCustomOverlay(self: RemoveScope): ()
	if self._customScreenGui then
		return
	end
	local screenGui = instances.new("ScreenGui", {
		Name = "RemoveScopeCustom",
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

function RemoveScope._destroyCustomOverlay(self: RemoveScope): ()
	if self._customRoot then
		self._customRoot:unmount()
		self._customRoot = nil
	end
	if self._customScreenGui then
		self._customScreenGui:Destroy()
		self._customScreenGui = nil
	end
	self._customVisibleAtom(false)
end

function RemoveScope._applyMode(self: RemoveScope): ()
	local scope = self._currentScope :: any
	if not scope then
		return
	end
	local frame = scope.Frame :: any
	if not frame or not frame.Parent then
		return
	end

	local mode = self._mode

	if mode == "Remove Background" then
		frame.Visible = true
		if scope.BlurFrame then
			(scope.BlurFrame :: any).Visible = false
		end
		if scope.CircleFrame then
			(scope.CircleFrame :: any).Visible = false
		end
		if scope.ReticleFrame then
			(scope.ReticleFrame :: any).Visible = false
		end
	elseif mode == "Remove All" then
		frame.Visible = false
	elseif mode == "Custom" then
		frame.Visible = false
	end

	if self._screenGui then
		self._screenGui.Enabled = mode == "Remove Background"
	end
	self._customVisibleAtom(mode == "Custom")
end

function RemoveScope._restoreScope(self: RemoveScope): ()
	local scope = self._currentScope :: any
	if scope then
		local frame = scope.Frame :: any
		if frame and frame.Parent then
			frame.Visible = self._isScopeActive
			if scope.BlurFrame then
				(scope.BlurFrame :: any).Visible = true
			end
			if scope.CircleFrame then
				(scope.CircleFrame :: any).Visible = true
			end
			if scope.ReticleFrame then
				(scope.ReticleFrame :: any).Visible = true
			end
		end
	end
	if self._screenGui then
		self._screenGui.Enabled = false
	end
	self._customVisibleAtom(false)
end

function RemoveScope._installHook(self: RemoveScope): ()
	local scopeClass = ModuleController.GetModule("Scope")
	if not scopeClass or self._setActiveHooked then
		return
	end
	local setActive = rawget(scopeClass, "SetActive")
	if type(setActive) ~= "function" then
		return
	end

	self._scopeClass = scopeClass
	self._originalSetActive = setActive
	self._setActiveHooked = true

	local originalSetActive: (any, boolean) -> ()
	originalSetActive = hook.add(setActive :: any, function(scope: any, active: boolean): ()
		originalSetActive(scope, active)
		self._currentScope = scope
		self._isScopeActive = active
		if not self._enabled then
			return
		end
		task.defer(function(): ()
			setthreadidentity(8)
			if active then
				self:_applyMode()
			else
				self:_restoreScope()
			end
		end)
	end) :: any
end

function RemoveScope._uninstallHook(self: RemoveScope): ()
	if self._setActiveHooked and self._originalSetActive then
		hook.restore(self._originalSetActive :: any)
	end
	self._setActiveHooked = false
	self._originalSetActive = nil
	self._scopeClass = nil
end

function RemoveScope.Enable(self: RemoveScope): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self:_createOverlay()
	self:_createCustomOverlay()
	self:_installHook()
	if self._isScopeActive then
		self:_applyMode()
	end
end

function RemoveScope.Disable(self: RemoveScope): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self:_restoreScope()
	self:_uninstallHook()
	self:_destroyOverlay()
	self:_destroyCustomOverlay()
end

function RemoveScope.Destroy(self: RemoveScope): ()
	self:Disable()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type RemoveScope =
	typeof(setmetatable(
		{} :: {
			_janitor: Janitor.Janitor,
			_enabled: boolean,
			_mode: string,
			_optsLink: gameUi.Linker,
			_currentScope: any?,
			_isScopeActive: boolean,
			_scopeClass: any?,
			_originalSetActive: ((any, boolean) -> ())?,
			_setActiveHooked: boolean,
			_screenGui: ScreenGui?,
			_hLine: Frame?,
			_vLine: Frame?,
			_customScreenGui: ScreenGui?,
			_customRoot: ReactRoblox.RootType?,
			_customVisibleAtom: Charm.Atom<boolean>,
			_spreadAtom: Charm.Atom<number>,
		},
		RemoveScope
	))
	& BaseFeature.BaseFeature

return RemoveScope
