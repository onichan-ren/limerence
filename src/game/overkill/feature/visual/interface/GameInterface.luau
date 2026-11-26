local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")

local LocalPlayer = Players.LocalPlayer

local SAT_MIN = 0.15
local BG_SAT_MAX = 0.25
local BG_VAL_MAX = 0.35
local WIDE_SCALE = 0.9
local MAX_WALK_DEPTH = 3

local SCALE_SKIP: { [string]: boolean } = { Hitmarker = true }

local PROPS_TEXT = { "BackgroundColor3", "TextColor3", "TextStrokeColor3" }
local PROPS_IMAGE = { "BackgroundColor3", "ImageColor3" }
local PROPS_SCROLL = { "BackgroundColor3", "ScrollBarImageColor3" }
local PROPS_BACKGROUND = { "BackgroundColor3" }
local PROPS_COLOR = { "Color" }

type Entry = { gp: boolean, props: { [string]: any } }
type WidgetRecord = {
	own: UIScale?,
	adopted: UIScale?,
	base: number,
	lastWritten: number,
	conns: { RBXScriptConnection },
}

local function propsFor(instance: Instance): { string }?
	if instance:IsA("GuiObject") then
		if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
			return PROPS_TEXT
		end
		if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
			return PROPS_IMAGE
		end
		if instance:IsA("ScrollingFrame") then
			return PROPS_SCROLL
		end
		return PROPS_BACKGROUND
	end
	if instance:IsA("UIStroke") or instance:IsA("UIGradient") then
		return PROPS_COLOR
	end
	return nil
end

local recolorColor3 = LPH_NO_VIRTUALIZE(function(original: Color3, hue: number, saturation: number): Color3
	local _, s, v = original:ToHSV()
	if s < SAT_MIN then
		return original
	end
	return Color3.fromHSV(hue, s * saturation, v)
end)

local recolorSequence = LPH_NO_VIRTUALIZE(
	function(original: ColorSequence, hue: number, saturation: number): ColorSequence
		local keypoints = original.Keypoints
		local changed = false
		local mapped = table.create(#keypoints)
		for index = 1, #keypoints do
			local keypoint = keypoints[index]
			local color = recolorColor3(keypoint.Value, hue, saturation)
			if color ~= keypoint.Value then
				changed = true
			end
			mapped[index] = ColorSequenceKeypoint.new(keypoint.Time, color)
		end
		if not changed then
			return original
		end
		return ColorSequence.new(mapped)
	end
)

local GameInterface = {}
GameInterface.__index = GameInterface

setmetatable(GameInterface, { __index = BaseFeature })

local transformValue = LPH_NO_VIRTUALIZE(function(self: any, prop: string, value: any, gp: boolean): any
	if typeof(value) == "Color3" then
		local _, s, v = value:ToHSV()
		if s >= SAT_MIN then
			return Color3.fromHSV(self._hue, s * self._saturation, v)
		end
		if gp and prop == "BackgroundColor3" and s < BG_SAT_MAX and v <= BG_VAL_MAX then
			return Color3.fromHSV(self._bgHue, self._bgSat, self._bgVal * (0.7 + 0.3 * (v / BG_VAL_MAX)))
		end
		return value
	end
	return recolorSequence(value, self._hue, self._saturation)
end)

local scanAccent = LPH_NO_VIRTUALIZE(function(self: any, root: Instance, gp: boolean): ()
	local guiObjects = (root :: any):QueryDescendants("GuiObject")
	for index = 1, #guiObjects do
		local instance = guiObjects[index]
		self:_captureApply(instance, propsFor(instance), gp)
	end
	local strokes = (root :: any):QueryDescendants("UIStroke")
	for index = 1, #strokes do
		self:_captureApply(strokes[index], PROPS_COLOR, gp)
	end
	local gradients = (root :: any):QueryDescendants("UIGradient")
	for index = 1, #gradients do
		self:_captureApply(gradients[index], PROPS_COLOR, gp)
	end
end)

local reapplyAll = LPH_NO_VIRTUALIZE(function(self: any): ()
	for instance, entry in next, self._originals do
		self:_applyEntry(instance, entry)
	end
end)

function GameInterface.new(link: gameUi.Linker): GameInterface
	local self = BaseFeature.new() :: any
	setmetatable(self, GameInterface)

	link:Options("gameInterface", "Game Interface")
	local menuLink = link:OnKey("gameInterface")

	local colorsToggle = menuLink:Toggle("customColors", "Custom Colors", false):SetTip({
		title = "Custom Colors",
		body = "Recolors the game's interface and HUD backgrounds with your chosen colors.",
	})
	local customColorsLink = menuLink:OnKey("customColors")
	customColorsLink:Submenu("opts", "Custom Colors Options")
	local colorsOpts = customColorsLink:OnKey("opts")
	colorsOpts:Colorpicker("color", "Interface Color", Color3.fromRGB(135, 104, 207)):SetTip({
		title = "Interface Color",
		body = "Color applied across the game's interface. Grey and white elements keep their look.",
	})
	colorsOpts:Colorpicker("backgroundColor", "Background Color", Color3.fromRGB(20, 20, 30)):SetTip({
		title = "Background Color",
		body = "Color used for HUD panel backgrounds.",
	})
	local scaleToggle = menuLink:Toggle("hudScale", "HUD Scale", false):SetTip({
		title = "HUD Scale",
		body = "Resizes the in-game HUD.",
	})
	local hudScaleLink = menuLink:OnKey("hudScale")
	hudScaleLink:Submenu("opts", "HUD Scale Options")
	local scaleOpts = hudScaleLink:OnKey("opts")
	scaleOpts:Slider("scale", "Scale Amount", 100, 25, 200, 1, nil, "%"):SetTip({
		title = "Scale Amount",
		body = "How large the HUD is drawn.",
	})

	self._scaleMult = (scaleOpts:Peek("scale") or 100) / 100
	self._scaleActive = false
	self._widgets = {} :: { [Instance]: WidgetRecord }
	self._scaleConnections = {} :: { RBXScriptConnection }

	self._hue = 0
	self._saturation = 1
	self._bgHue = 0
	self._bgSat = 0
	self._bgVal = 0
	self._colorsActive = false
	self._engineActive = false
	self._recolorQueued = false
	self._roots = nil
	self._originals = {} :: { [Instance]: Entry }
	self._recolorConnections = {} :: { RBXScriptConnection }
	self:_setAccentColor(colorsOpts:Peek("color"))
	self:_setBgColor(colorsOpts:Peek("backgroundColor"))

	self:Track(scaleToggle:OnChange(function(value: boolean): ()
		if value then
			self:EnableScale()
		else
			self:DisableScale()
		end
	end))

	self:Track(scaleOpts:Get("scale"):OnChange(function(value: number): ()
		self._scaleMult = value / 100
		if self._scaleActive then
			self:_applyScaleAll()
		end
	end))

	self:Track(colorsToggle:OnChange(function(value: boolean): ()
		if value then
			self:EnableColors()
		else
			self:DisableColors()
		end
	end))

	self:Track(colorsOpts:Get("color"):OnChange(function(value: any): ()
		self:_setAccentColor(value)
		if self._colorsActive then
			self:_queueRecolor()
		end
	end))

	self:Track(colorsOpts:Get("backgroundColor"):OnChange(function(value: any): ()
		self:_setBgColor(value)
		if self._colorsActive then
			self:_queueRecolor()
		end
	end))

	return self
end

function GameInterface._setAccentColor(self: GameInterface, color: any): ()
	if typeof(color) == "ColorSequence" then
		color = color.Keypoints[1].Value
	end
	if typeof(color) ~= "Color3" then
		return
	end
	local h, s = color:ToHSV()
	self._hue = h
	self._saturation = s
end

function GameInterface._setBgColor(self: GameInterface, color: any): ()
	if typeof(color) == "ColorSequence" then
		color = color.Keypoints[1].Value
	end
	if typeof(color) ~= "Color3" then
		return
	end
	local h, s, v = color:ToHSV()
	self._bgHue = h
	self._bgSat = s
	self._bgVal = v
end

function GameInterface._getRoots(self: GameInterface): { { root: Instance, gp: boolean } }
	local roots = self._roots
	if roots then
		return roots
	end
	roots = {}
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		local lobby = playerGui:FindFirstChild("Lobby")
		if lobby then
			table.insert(roots, { root = lobby, gp = false })
		end
		local gameplay = playerGui:FindFirstChild("Gameplay")
		if gameplay then
			table.insert(roots, { root = gameplay, gp = true })
		end
	end
	self._roots = roots
	return roots
end

function GameInterface._gameplayRoot(self: GameInterface): Instance?
	local roots = self:_getRoots()
	for index = 1, #roots do
		if roots[index].gp then
			return roots[index].root
		end
	end
	return nil
end

function GameInterface._adoptScale(self: GameInterface, record: WidgetRecord, uiScale: UIScale): ()
	record.adopted = uiScale
	record.base = uiScale.Scale
	local target = record.base * self._scaleMult
	record.lastWritten = target
	uiScale.Scale = target
	table.insert(
		record.conns,
		uiScale:GetPropertyChangedSignal("Scale"):Connect(LPH_NO_VIRTUALIZE(function(): ()
			local value = uiScale.Scale
			if math.abs(value - record.lastWritten) < 1e-4 then
				return
			end
			record.base = value
			local newTarget = value * self._scaleMult
			record.lastWritten = newTarget
			uiScale.Scale = newTarget
		end))
	)
end

function GameInterface._scaleWidget(self: GameInterface, widget: Instance): ()
	local widgets: { [Instance]: WidgetRecord } = self._widgets
	if widgets[widget] then
		return
	end
	local record: WidgetRecord = { base = 1, lastWritten = 1, conns = {} }
	widgets[widget] = record

	local existing = widget:FindFirstChildOfClass("UIScale")
	if existing then
		self:_adoptScale(record, existing)
		return
	end

	local own = Instance.new("UIScale")
	own.Scale = self._scaleMult
	own.Parent = widget
	record.own = own
	table.insert(
		record.conns,
		widget.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(child: Instance): ()
			if child:IsA("UIScale") and child ~= record.own and not record.adopted then
				local ownScale = record.own
				if ownScale then
					record.own = nil
					ownScale:Destroy()
				end
				self:_adoptScale(record, child)
			end
		end))
	)
end

function GameInterface._applyScaleAll(self: GameInterface): ()
	local mult = self._scaleMult
	for _, record in next, self._widgets do
		local own = record.own
		if own then
			own.Scale = mult
		else
			local adopted = record.adopted
			if adopted then
				local target = record.base * mult
				record.lastWritten = target
				adopted.Scale = target
			end
		end
	end
end

function GameInterface._walkScale(self: GameInterface, container: Instance, depth: number): ()
	local children = container:GetChildren()
	for index = 1, #children do
		local child = children[index]
		if child:IsA("GuiObject") then
			if not SCALE_SKIP[child.Name] then
				if child.Size.X.Scale > WIDE_SCALE then
					if depth < MAX_WALK_DEPTH then
						self:_watchScale(child, depth + 1)
					end
				else
					self:_scaleWidget(child)
				end
			end
		elseif child:IsA("ScreenGui") then
			self:_watchScale(child, depth)
		end
	end
end

function GameInterface._watchScale(self: GameInterface, container: Instance, depth: number): ()
	self:_walkScale(container, depth)
	table.insert(
		self._scaleConnections,
		container.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(child: Instance): ()
			if not self._scaleActive then
				return
			end
			if child:IsA("GuiObject") then
				if not SCALE_SKIP[child.Name] then
					if child.Size.X.Scale > WIDE_SCALE then
						if depth < MAX_WALK_DEPTH then
							self:_watchScale(child, depth + 1)
						end
					else
						self:_scaleWidget(child)
					end
				end
			elseif child:IsA("ScreenGui") then
				self:_watchScale(child, depth)
			end
		end))
	)
end

function GameInterface.EnableScale(self: GameInterface): ()
	if self._scaleActive then
		return
	end
	self._scaleActive = true
	local gameplay = self:_gameplayRoot()
	if gameplay then
		self:_watchScale(gameplay, 1)
	end
end

function GameInterface.DisableScale(self: GameInterface): ()
	if not self._scaleActive then
		return
	end
	self._scaleActive = false

	local connections = self._scaleConnections
	for index = 1, #connections do
		connections[index]:Disconnect()
	end
	table.clear(connections)

	local widgets: { [Instance]: WidgetRecord } = self._widgets
	for _, record in next, widgets do
		local conns = record.conns
		for index = 1, #conns do
			conns[index]:Disconnect()
		end
		local own = record.own
		if own then
			own:Destroy()
		end
		local adopted = record.adopted
		if adopted then
			adopted.Scale = record.base
		end
	end
	table.clear(widgets)
end

function GameInterface._applyEntry(self: GameInterface, instance: Instance, entry: Entry): ()
	local gp = entry.gp
	for prop, value in next, entry.props do
		(instance :: any)[prop] = transformValue(self, prop, value, gp)
	end
end

function GameInterface._captureApply(self: GameInterface, instance: Instance, props: { string }?, gp: boolean): ()
	if not props then
		return
	end
	local originals: { [Instance]: Entry } = self._originals
	local entry = originals[instance]
	if not entry then
		entry = { gp = gp, props = {} }
		originals[instance] = entry
	end
	local captured = entry.props
	for index = 1, #props do
		local prop = props[index]
		if captured[prop] == nil then
			captured[prop] = (instance :: any)[prop]
		end
	end
	self:_applyEntry(instance, entry)
end

function GameInterface._ensureEngine(self: GameInterface): ()
	if self._engineActive then
		return
	end
	self._engineActive = true

	local roots = self:_getRoots()
	local connections = self._recolorConnections
	for index = 1, #roots do
		local root = roots[index].root
		local gp = roots[index].gp
		table.insert(
			connections,
			root.DescendantAdded:Connect(LPH_NO_VIRTUALIZE(function(descendant: Instance): ()
				self:_captureApply(descendant, propsFor(descendant), gp)
			end))
		)
		table.insert(
			connections,
			root.DescendantRemoving:Connect(LPH_NO_VIRTUALIZE(function(descendant: Instance): ()
				local originals: { [Instance]: Entry } = self._originals
				local entry = originals[descendant]
				if entry then
					originals[descendant] = nil
					for prop, value in next, entry.props do
						(descendant :: any)[prop] = value
					end
				end
			end))
		)
	end
end

function GameInterface._teardownEngine(self: GameInterface): ()
	if not self._engineActive then
		return
	end
	self._engineActive = false

	local connections = self._recolorConnections
	for index = 1, #connections do
		connections[index]:Disconnect()
	end
	table.clear(connections)

	local originals: { [Instance]: Entry } = self._originals
	for instance, entry in next, originals do
		for prop, value in next, entry.props do
			(instance :: any)[prop] = value
		end
	end
	table.clear(originals)
end

function GameInterface.EnableColors(self: GameInterface): ()
	if self._colorsActive then
		return
	end
	self._colorsActive = true
	self:_ensureEngine()
	local roots = self:_getRoots()
	for index = 1, #roots do
		scanAccent(self, roots[index].root, roots[index].gp)
	end
end

function GameInterface.DisableColors(self: GameInterface): ()
	if not self._colorsActive then
		return
	end
	self._colorsActive = false
	self:_teardownEngine()
end

function GameInterface._queueRecolor(self: GameInterface): ()
	if self._recolorQueued then
		return
	end
	self._recolorQueued = true
	task.delay(0.1, function(): ()
		self._recolorQueued = false
		if not self._engineActive then
			return
		end
		reapplyAll(self)
	end)
end

function GameInterface.Destroy(self: GameInterface): ()
	self:DisableScale()
	self._colorsActive = false
	self:_teardownEngine()
	BaseFeature.Destroy(self)
end

export type GameInterface =
	typeof(setmetatable(
		{} :: {
			_scaleMult: number,
			_scaleActive: boolean,
			_widgets: { [Instance]: WidgetRecord },
			_scaleConnections: { RBXScriptConnection },
			_hue: number,
			_saturation: number,
			_bgHue: number,
			_bgSat: number,
			_bgVal: number,
			_colorsActive: boolean,
			_engineActive: boolean,
			_recolorQueued: boolean,
			_roots: { { root: Instance, gp: boolean } }?,
			_originals: { [Instance]: Entry },
			_recolorConnections: { RBXScriptConnection },
			_setAccentColor: (GameInterface, any) -> (),
			_setBgColor: (GameInterface, any) -> (),
			_getRoots: (GameInterface) -> { { root: Instance, gp: boolean } },
			_gameplayRoot: (GameInterface) -> Instance?,
			_adoptScale: (GameInterface, WidgetRecord, UIScale) -> (),
			_scaleWidget: (GameInterface, Instance) -> (),
			_applyScaleAll: (GameInterface) -> (),
			_walkScale: (GameInterface, Instance, number) -> (),
			_watchScale: (GameInterface, Instance, number) -> (),
			EnableScale: (GameInterface) -> (),
			DisableScale: (GameInterface) -> (),
			_applyEntry: (GameInterface, Instance, Entry) -> (),
			_captureApply: (GameInterface, Instance, { string }?, boolean) -> (),
			_ensureEngine: (GameInterface) -> (),
			_teardownEngine: (GameInterface) -> (),
			EnableColors: (GameInterface) -> (),
			DisableColors: (GameInterface) -> (),
			_queueRecolor: (GameInterface) -> (),
		},
		GameInterface
	))
	& BaseFeature.BaseFeature

return GameInterface
