local RunService = cloneref(game:GetService("RunService")) :: RunService
local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local BaseFeature = require("@game/BaseFeature")
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local LoadoutState = require("@game/bloxstrike/loadout/loadoutState")
local clientState = require("@game/bloxstrike/client/clientState")
local spreadHitChance = require("@game/bloxstrike/feature/legitbot/spreadHitChance")
local customScope = require("@game/universal/feature/visual/removescope/customScope")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local hook = require("@share/hook")

local e = React.createElement
local peek = Charm.peek
local sub = Charm.subscribe
local subscribeToBinding = (React :: any).__subscribeToBinding

local MODES = { "Remove Blur", "Remove Background", "Remove All", "Custom" }
local DEFAULT_SCOPE_COLOR = Color3.fromRGB(18, 18, 18)
local DEFAULT_CUSTOM_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(225, 225, 225)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
})
local LINE_THICKNESS = 2
local SPREAD_GAP_PX_PER_DEGREE = 0.9
local DYNAMIC_GAP_MAX_PX = 140

local RemoveScope = {}
RemoveScope.__index = RemoveScope

setmetatable(RemoveScope, { __index = BaseFeature })

local function resolveScope(): (any?, GuiObject?)
	local sniperScope = ModuleController.GetModule("SniperScope")
	if not sniperScope then
		return nil, nil
	end
	local toggle = rawget(sniperScope, "toggle")
	if not toggle then
		return sniperScope, nil
	end
	local scopeFrame = debug.getupvalue(toggle, 1) :: GuiObject?
	return sniperScope, scopeFrame
end

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
	optsLink:Dropdown("mode", "Mode", MODES, "Remove Blur"):SetTip({
		title = "Mode",
		body = "Remove Blur clears scope blur. Remove Background hides the scope art and shows a simple crosshair. Remove All hides the full overlay. Custom draws your own crosshair with the sliders below.",
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
	self._sniperScope = nil
	self._scopeFrame = nil
	self._originalToggle = nil
	self._toggleHooked = false
	self._sharpInstance = nil
	self._sharpOverrideActive = false
	self._crosshairInstance = nil
	self._crosshairOverrideActive = false
	self._isAiming = false
	self._screenGui = nil
	self._hLine = nil
	self._vLine = nil
	self._customScreenGui = nil
	self._customRoot = nil
	self._customVisibleAtom = Charm.atom(false)
	self._spreadAtom = Charm.atom(0)
	self._spreadConn = nil
	self._dynamicGapLink = customLink:Get("dynamicGap")

	self:Track(link:Get("removeScope"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optsLink:Get("mode"):OnChange(function(value: string): ()
		self._mode = value
		if self._enabled and self._isAiming then
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

	self:Track(sub(clientState.isScoped, function(scoped: boolean): ()
		if scoped or not self._isAiming then
			return
		end
		self._isAiming = false
		if self._enabled then
			self:_restoreScope()
		end
	end))

	if link:Get("removeScope"):Peek() then
		self:Enable()
	end

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
	self._spreadAtom(0)
end

function RemoveScope._bindDynamicSpread(self: RemoveScope): ()
	if self._spreadConn then
		return
	end
	local dynamicGapLink = self._dynamicGapLink
	local custom = "Custom"
	self._spreadConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
		local shouldRun = self._enabled and self._isAiming and self._mode == custom
		if not shouldRun or not dynamicGapLink:Peek() then
			if peek(self._spreadAtom) ~= 0 then
				self._spreadAtom(0)
			end
			return
		end
		local weapon = peek(LoadoutState.currentEquipped) :: any
		local degrees = (weapon and spreadHitChance.getSpreadDegrees(weapon) or 0)
		local px = math.min(math.max(0, degrees * SPREAD_GAP_PX_PER_DEGREE), DYNAMIC_GAP_MAX_PX)
		if peek(self._spreadAtom) ~= px then
			self._spreadAtom(px)
		end
	end))
end

function RemoveScope._unbindDynamicSpread(self: RemoveScope): ()
	if self._spreadConn then
		self._spreadConn:Disconnect()
		self._spreadConn = nil
	end
	self._spreadAtom(0)
end

function RemoveScope._resolveTargets(self: RemoveScope): boolean
	local frame = self._scopeFrame :: any
	if frame and frame.Parent then
		return true
	end
	local sniperScope, scopeFrame = resolveScope()
	self._scopeFrame = scopeFrame
	if not self._sniperScope then
		self._sniperScope = sniperScope
	end
	return scopeFrame ~= nil
end

function RemoveScope._ensureSharpHook(self: RemoveScope): ()
	if self._sharpInstance then
		return
	end
	local frame = self._scopeFrame :: any
	if not frame or not frame.Parent then
		return
	end
	local sharp = frame:FindFirstChild("Sharp")
	if not sharp then
		return
	end
	hook.addInstance(sharp)
	self._sharpInstance = sharp
end

function RemoveScope._setSharpForced(self: RemoveScope, active: boolean): ()
	if active then
		self:_ensureSharpHook()
		local sharp = self._sharpInstance :: any
		if not sharp then
			return
		end
		if not self._sharpOverrideActive then
			hook.overrideProperty(
				sharp,
				"ImageTransparency",
				LPH_NO_VIRTUALIZE(function(): number
					return 0
				end)
			)
			self._sharpOverrideActive = true
		end
		sharp.ImageTransparency = 0
	else
		if self._sharpInstance and self._sharpOverrideActive then
			hook.restoreProperty(self._sharpInstance :: any, "ImageTransparency")
			self._sharpOverrideActive = false
		end
	end
end

function RemoveScope._ensureCrosshairHook(self: RemoveScope): ()
	if self._crosshairInstance then
		return
	end
	local frame = self._scopeFrame :: any
	if not frame or not frame.Parent then
		return
	end
	local crosshair = frame.Parent:FindFirstChild("Crosshair")
	if not crosshair then
		return
	end
	hook.addInstance(crosshair)
	self._crosshairInstance = crosshair
end

function RemoveScope._setCrosshairForced(self: RemoveScope, active: boolean): ()
	if active then
		self:_ensureCrosshairHook()
		local crosshair = self._crosshairInstance :: any
		if not crosshair then
			return
		end
		if not self._crosshairOverrideActive then
			hook.overrideProperty(
				crosshair,
				"Visible",
				LPH_NO_VIRTUALIZE(function(): boolean
					return true
				end)
			)
			self._crosshairOverrideActive = true
		end
		crosshair.Visible = true
	else
		if self._crosshairInstance and self._crosshairOverrideActive then
			hook.restoreProperty(self._crosshairInstance :: any, "Visible")
			self._crosshairOverrideActive = false
		end
	end
end

function RemoveScope._applyMode(self: RemoveScope): ()
	if not self:_resolveTargets() then
		return
	end
	local frame = self._scopeFrame :: any
	local mode = self._mode

	if mode == "Remove Blur" then
		if frame:FindFirstChild("Blur") then
			frame.Blur.Visible = false
		end
		self:_setSharpForced(true)
		self:_setCrosshairForced(false)
	elseif mode == "Remove Background" then
		self:_setSharpForced(false)
		self:_setCrosshairForced(false)
		if frame:FindFirstChild("Blur") then
			frame.Blur.Visible = false
		end
		if frame:FindFirstChild("Sharp") then
			frame.Sharp.Visible = false
		end
	elseif mode == "Remove All" then
		self:_setSharpForced(false)
		if frame:FindFirstChild("Blur") then
			frame.Blur.Visible = false
		end
		if frame:FindFirstChild("Sharp") then
			frame.Sharp.Visible = false
		end
		self:_setCrosshairForced(true)
	elseif mode == "Custom" then
		self:_setSharpForced(false)
		self:_setCrosshairForced(false)
		if frame:FindFirstChild("Blur") then
			frame.Blur.Visible = false
		end
		if frame:FindFirstChild("Sharp") then
			frame.Sharp.Visible = false
		end
	end

	if self._screenGui then
		self._screenGui.Enabled = mode == "Remove Background"
	end
	self._customVisibleAtom(mode == "Custom")
end

function RemoveScope._restoreScope(self: RemoveScope): ()
	self:_setSharpForced(false)
	self:_setCrosshairForced(false)
	local frame = self._scopeFrame :: any
	if frame and frame.Parent then
		if frame:FindFirstChild("Blur") then
			frame.Blur.Visible = true
		end
		if frame:FindFirstChild("Sharp") then
			frame.Sharp.Visible = true
		end
	end
	if self._screenGui then
		self._screenGui.Enabled = false
	end
	self._customVisibleAtom(false)
end

function RemoveScope._installHook(self: RemoveScope): ()
	self:_resolveTargets()
	local sniperScope = self._sniperScope
	if not sniperScope then
		return
	end
	local toggle = rawget(sniperScope, "toggle")
	if not toggle or self._toggleHooked then
		return
	end
	self._originalToggle = toggle
	self._toggleHooked = true

	local originalToggle: (boolean) -> ()

	local replacement = LPH_NO_VIRTUALIZE(function(b: boolean): ()
		originalToggle(b)
		self._isAiming = b
		if not self._enabled then
			return
		end
		task.defer(function(): ()
			setthreadidentity(8)
			if b then
				self:_applyMode()
			else
				self:_restoreScope()
			end
		end)
	end)
	setstackhidden(replacement, true)
	originalToggle = hook.add(toggle :: any, replacement) :: any
end

function RemoveScope._uninstallHook(self: RemoveScope): ()
	if self._toggleHooked and self._originalToggle then
		hook.restore(self._originalToggle :: any)
	end
	self._toggleHooked = false
	self._originalToggle = nil
end

function RemoveScope.Enable(self: RemoveScope): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self:_createOverlay()
	self:_createCustomOverlay()
	self:_bindDynamicSpread()
	self:_installHook()
	if self._isAiming then
		self:_applyMode()
	end
end

function RemoveScope.Disable(self: RemoveScope): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self:_restoreScope()
	if self._sharpInstance then
		hook.restoreInstance(self._sharpInstance)
		self._sharpInstance = nil
		self._sharpOverrideActive = false
	end
	if self._crosshairInstance then
		hook.restoreInstance(self._crosshairInstance)
		self._crosshairInstance = nil
		self._crosshairOverrideActive = false
	end
	self:_uninstallHook()
	self:_unbindDynamicSpread()
	self:_destroyOverlay()
	self:_destroyCustomOverlay()
end

function RemoveScope.Destroy(self: RemoveScope): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type RemoveScope =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_mode: string,
			_optsLink: gameUi.Linker,
			_sniperScope: any?,
			_scopeFrame: GuiObject?,
			_originalToggle: ((boolean) -> ())?,
			_toggleHooked: boolean,
			_sharpInstance: any?,
			_sharpOverrideActive: boolean,
			_crosshairInstance: any?,
			_crosshairOverrideActive: boolean,
			_isAiming: boolean,
			_screenGui: ScreenGui?,
			_hLine: Frame?,
			_vLine: Frame?,
			_customScreenGui: ScreenGui?,
			_customRoot: ReactRoblox.RootType?,
			_customVisibleAtom: Charm.Atom<boolean>,
			_spreadAtom: Charm.Atom<number>,
			_spreadConn: RBXScriptConnection?,
			_dynamicGapLink: any,
		},
		RemoveScope
	))
	& BaseFeature.BaseFeature

return RemoveScope
