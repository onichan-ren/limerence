local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local BaseFeature = require("@game/BaseFeature")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local Charm = require("@pkg/Charm")
local instances = require("@share/instances")
local gameUi = require("@game/gameUi")
local PlayerController = require("@feature/player/PlayerController")
local EspState = require("@game/universal/feature/visual/esp/EspState")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local espCanvas = require("@game/universal/feature/visual/esp/espCanvas")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")
local espProject = require("@share/screenProject")

local Box = require("@game/universal/feature/visual/esp/element/Box")
local VisibleChams = require("@game/universal/feature/visual/esp/element/VisibleChams")
local Healthbar = require("@game/universal/feature/visual/esp/element/Healthbar")
local Highlight = require("@game/universal/feature/visual/esp/element/Highlight")
local AdornChams = require("@game/universal/feature/visual/esp/element/AdornChams")
local Skeleton = require("@game/universal/feature/visual/esp/element/Skeleton")
local Name = require("@game/universal/feature/visual/esp/element/Name")
local HealthText = require("@game/universal/feature/visual/esp/element/HealthText")
local OffscreenArrow = require("@game/universal/feature/visual/esp/element/OffscreenArrow")
local espPreview = require("@game/universal/feature/visual/esp/espPreview")
local Submenu = require("@ui/window/element/submenu/Submenu")

local e = React.createElement
local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe
local floor = math.floor
local v2 = Vector2.new
local clock = os.clock

local CHAR_HALF_UP = 2.5
local CHAR_HALF_DOWN = 3.8
local CHAR_HEIGHT = CHAR_HALF_UP + CHAR_HALF_DOWN
local CHAR_WIDTH = 4.2
local CHAR_HALF_WIDTH = CHAR_WIDTH * 0.5

local BOUNDING_PART_NAMES = {
	"Head",
	"LeftHand",
	"RightHand",
	"UpperTorso",
	"LeftFoot",
	"RightFoot",
	"Torso",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
}

local FADE_RATE = 12
local ALPHA_EPSILON = 0.005

type BoundsResult = {
	screen: Vector3,
	depth: number,
	pps: number,
	boxPosition: Vector2,
	boxSize: Vector2,
}

type PlayerFade = {
	alpha: number,
}

type BoxFreeze = {
	uLeft: number,
	uTop: number,
	uW: number,
	uH: number,
}

export type FilterFn = (basePlayer: any) -> boolean
export type PrepareCtxFn = (
	ctx: EspElement.EspCtx,
	entry: EspState.EspEntry,
	elementActive: { [string]: boolean },
	settings: { [string]: any }
) -> ()

export type TargetSource = {
	GetAll: () -> { [any]: any },
	added: any,
	removed: any,
}

export type EspOpts = {
	extraElements: { EspElement.AnyEspElement }?,
	overrideElements: { [string]: EspElement.AnyEspElement }?,
	excludeElements: { [string]: true }?,
	elementOpts: { [string]: any }?,
	extraBoxLayoutIds: { [string]: true }?,
	filter: FilterFn?,
	filterBots: boolean?,
	prepareCtx: PrepareCtxFn?,
	offset: Vector2?,
	targetSource: TargetSource?,
	previewLink: gameUi.Linker?,
	previewAtoms: { [string]: any }?,
	previewControls: { espPreview.ControlSpec }?,
	previewModelProvider: (() -> Model?)?,
	previewApplyState: ((model: Model, states: { [string]: any }) -> ())?,
	previewOnFrame: ((model: Model, dt: number, states: { [string]: any }) -> Model?)?,
	previewOnDestroy: (() -> ())?,
	previewResolveHrp: ((model: Model) -> BasePart?)?,
	previewResolveParts: ((model: Model) -> { [string]: BasePart })?,
	previewManagedModel: boolean?,
	previewDespawnOnHide: boolean?,
	previewCameraDistanceScale: number?,
	previewIdleAnimationId: string?,
}

local BOUNDS_SCRATCH: BoundsResult = {
	screen = Vector3.zero,
	depth = 0,
	pps = 0,
	boxPosition = Vector2.zero,
	boxSize = Vector2.zero,
}

local computeClassicBounds = LPH_NO_VIRTUALIZE(
	function(
		project: (Vector3) -> Vector3,
		hrp: BasePart,
		pixelsPerStudUnit: number,
		halfWidthCoeff: number,
		heightCoeff: number,
		topCoeff: number,
		offsetX: number,
		offsetY: number
	): BoundsResult?
		local rootScreen = project(hrp.Position)
		local depth = rootScreen.Z
		if depth <= 0 then
			return nil
		end

		local invDepth = 1 / depth
		local halfWidth = floor(halfWidthCoeff * invDepth)
		local height = floor(heightCoeff * invDepth)
		local topOffset = floor(topCoeff * invDepth)
		local pps = pixelsPerStudUnit * invDepth

		local sx = rootScreen.X
		local sy = rootScreen.Y
		if offsetX ~= 0 or offsetY ~= 0 then
			sx += offsetX * pps
			sy += offsetY * pps
			rootScreen = Vector3.new(sx, sy, depth)
		end

		local out = BOUNDS_SCRATCH
		out.screen = rootScreen
		out.depth = depth
		out.pps = pps
		out.boxPosition = v2(sx - halfWidth, sy - topOffset)
		out.boxSize = v2(halfWidth + halfWidth, height)
		return out
	end
)

local computeBoundingBounds = LPH_NO_VIRTUALIZE(
	function(
		project: (Vector3) -> Vector3,
		hrp: BasePart,
		parts: { [string]: BasePart },
		pixelsPerStudUnit: number
	): BoundsResult?
		local rootScreen = project(hrp.Position)
		local depth = rootScreen.Z
		if depth <= 0 then
			return nil
		end

		local minX = rootScreen.X
		local maxX = rootScreen.X
		local minY = rootScreen.Y
		local maxY = rootScreen.Y

		for i = 1, #BOUNDING_PART_NAMES do
			local part = parts[BOUNDING_PART_NAMES[i]]
			if not part then
				continue
			end
			local s = project(part.Position)
			if s.Z <= 0 then
				continue
			end
			if s.X < minX then
				minX = s.X
			end
			if s.X > maxX then
				maxX = s.X
			end
			if s.Y < minY then
				minY = s.Y
			end
			if s.Y > maxY then
				maxY = s.Y
			end
		end

		local pps = pixelsPerStudUnit / depth
		local pad = floor(pps * 0.85)
		local out = BOUNDS_SCRATCH
		out.screen = rootScreen
		out.depth = depth
		out.pps = pps
		out.boxPosition = v2(minX - pad, minY - pad)
		out.boxSize = v2(maxX - minX + pad + pad, maxY - minY + pad + pad)
		return out
	end
)

local computeFrozenBounds = LPH_NO_VIRTUALIZE(
	function(project: (Vector3) -> Vector3, hrp: BasePart, pixelsPerStudUnit: number, freeze: BoxFreeze): BoundsResult?
		local rootScreen = project(hrp.Position)
		local depth = rootScreen.Z
		if depth <= 0 then
			return nil
		end

		local pps = pixelsPerStudUnit / depth
		local out = BOUNDS_SCRATCH
		out.screen = rootScreen
		out.depth = depth
		out.pps = pps
		out.boxPosition = v2(rootScreen.X + freeze.uLeft * pps, rootScreen.Y + freeze.uTop * pps)
		out.boxSize = v2(freeze.uW * pps, freeze.uH * pps)
		return out
	end
)

local computePreviewBounds = LPH_NO_VIRTUALIZE(
	function(
		project: (Vector3) -> Vector3,
		hrp: BasePart,
		parts: { [string]: BasePart },
		pixelsPerStudUnit: number,
		useBounding: boolean
	): BoundsResult?
		if useBounding then
			return computeBoundingBounds(project, hrp, parts, pixelsPerStudUnit)
		end
		local heightCoeff = pixelsPerStudUnit * CHAR_HEIGHT
		local halfWidthCoeff = pixelsPerStudUnit * CHAR_HALF_WIDTH
		local topCoeff = pixelsPerStudUnit * CHAR_HALF_UP
		return computeClassicBounds(project, hrp, pixelsPerStudUnit, halfWidthCoeff, heightCoeff, topCoeff, 0, 0)
	end
)

local DEFAULT_ELEMENTS: { EspElement.AnyEspElement } = {
	Box,
	VisibleChams,
	Healthbar,
	HealthText,
	Highlight,
	AdornChams,
	Skeleton,
	Name,
	OffscreenArrow,
}

local DEFAULT_BOX_LAYOUT_IDS: { [string]: true } = {
	box = true,
	healthbar = true,
	healthText = true,
	name = true,
}

local HIGHLIGHT_ELEMENT_ID = "highlight"
local SKELETON_ELEMENT_ID = "skeleton"
local OFFSCREEN_ELEMENT_ID = "offscreenArrow"

local STATE_BUCKET_ELEMENT_IDS: { [string]: true } = {
	skeleton = true,
	visibleChams = true,
	adornChams = true,
	highlight = true,
}

local function isSubmenuElement(value: any): boolean
	return type(value) == "table" and type(value.Open) == "function"
end

local function resolveSubmenuTarget(enabledElement: any): any
	local extras = peek(enabledElement._extras)
	if #extras == 0 then
		return nil
	end
	local flat: { any } = {}
	for _, el in next, extras do
		if isSubmenuElement(el) then
			for _, child in next, peek(el._elements) do
				flat[#flat + 1] = child
			end
		else
			flat[#flat + 1] = el
		end
	end
	if #flat == 0 then
		return nil
	end
	local synth = Submenu(peek(enabledElement._text))
	synth._elements(flat)
	return synth
end

local Esp = {}
Esp.__index = Esp

setmetatable(Esp, { __index = BaseFeature })

Esp.DEFAULT_ELEMENTS = DEFAULT_ELEMENTS
Esp.DEFAULT_BOX_LAYOUT_IDS = DEFAULT_BOX_LAYOUT_IDS

local function buildEntry(
	player: Player,
	basePlayer: any,
	settings: { [string]: any },
	elements: { EspElement.AnyEspElement }
): EspState.EspEntry
	local entry: EspState.EspEntry = {}
	for _, def in next, elements do
		entry[def.id] = def.createState(player, basePlayer, settings[def.id])
	end
	entry.__box = {
		position = EspElement.createBindable(Vector2.zero),
		size = EspElement.createBindable(Vector2.zero),
		visible = EspElement.createBindable(false),
	} :: any
	return entry
end

local function destroyEntry(
	entry: EspState.EspEntry,
	settings: { [string]: any },
	elements: { EspElement.AnyEspElement }
): ()
	for _, def in next, elements do
		if def.destroyState then
			def.destroyState(entry[def.id], settings[def.id])
		end
	end
end

function Esp.new(link: gameUi.Linker, opts: EspOpts?): Esp
	local self = BaseFeature.new() :: any
	setmetatable(self, Esp)

	opts = opts or {}
	local resolvedOpts = opts :: EspOpts
	local overrides = resolvedOpts.overrideElements or {}

	local excluded = resolvedOpts.excludeElements or {}

	local elements: { EspElement.AnyEspElement } = {}
	for _, def in next, DEFAULT_ELEMENTS do
		if not excluded[def.id] then
			table.insert(elements, overrides[def.id] or def)
		end
	end
	if resolvedOpts.extraElements then
		for _, def in next, resolvedOpts.extraElements do
			table.insert(elements, def)
		end
	end

	local boxLayoutIds: { [string]: true } = {}
	for id in next, DEFAULT_BOX_LAYOUT_IDS do
		boxLayoutIds[id] = true
	end
	if resolvedOpts.extraBoxLayoutIds then
		for id in next, resolvedOpts.extraBoxLayoutIds do
			boxLayoutIds[id] = true
		end
	end

	local activeNeedsBoxLayout = LPH_NO_VIRTUALIZE(function(active: { [string]: boolean }): boolean
		for id in next, boxLayoutIds do
			if active[id] then
				return true
			end
		end
		return false
	end)

	self._elements = elements
	self._filter = resolvedOpts.filter
	self._filterBots = resolvedOpts.filterBots
	self._prepareCtx = resolvedOpts.prepareCtx
	self._offset = resolvedOpts.offset
	self._targetSource = resolvedOpts.targetSource
	self._activeNeedsBoxLayout = activeNeedsBoxLayout

	link:StateColors("Color Profile", {
		states = espStateColors.GetEditorStates(),
		selectedState = espStateColors.selectedState,
		getToggle = espStateColors.GetOverrideToggle,
	})
	local overrideDefaultToggle = link:Raw():AddElement("Toggle", "Override Default", false)
	overrideDefaultToggle:SetBindable(false)
	overrideDefaultToggle._displaySelection = espStateColors.selectedState
	overrideDefaultToggle._displayResolver = function(): any
		return espStateColors.GetOverrideToggle(peek(espStateColors.selectedState)) or overrideDefaultToggle
	end
	local enabledToggle = link:Toggle("enabled", "Enabled", false):SetTip({
		title = "Enabled",
		body = "Shows information on other players. Turn on individual elements in the sections below.",
	})
	local function syncEnabledVisibility(): ()
		local editingDefault = peek(espStateColors.selectedState) == "base"
		enabledToggle:SetVisible(editingDefault)
		overrideDefaultToggle:SetVisible(not editingDefault)
	end
	self:Track(sub(espStateColors.selectedState, syncEnabledVisibility))
	syncEnabledVisibility()
	local enabledLink = link:OnKey("enabled")
	enabledLink:Submenu("animations", "Options")
	local animLink = enabledLink:OnKey("animations")
	animLink
		:Slider("maxDistance", "Max Distance", 0, 0, 2000, 50, nil, "st")
		:SetTip({
			title = "Max Distance",
			body = "Hides players farther than this. Zero means no limit.",
		})
		:SetValueTextOverrides({
			[0] = "Off",
		})
	animLink
		:Slider("updateRate", "Update Rate", 0, 0, 240, 1, nil, "hz")
		:SetTip({
			title = "Update Rate",
			body = "Caps how many times per second the ESP refreshes. Zero is unlimited.",
		})
		:SetValueTextOverrides({
			[0] = "Off",
		})
	animLink:Toggle("elementAnimations", "Element Animations", true):SetTip({
		title = "Element Animations",
		body = "Fades ESP elements in and out when players appear or leave view.",
	})
	animLink:Toggle("deathAnimations", "Death Animations", true):SetTip({
		title = "Death Animations",
		body = "Fades ESP out when a player dies instead of removing it instantly.",
	})
	animLink:Toggle("bounding", "Bounding Box", false):SetTip({
		title = "Bounding Box",
		body = "Sizes the ESP box from limb positions so it fits the pose more closely.",
	})

	self._link = link
	self._state = EspState.new()
	self._renderConn = nil :: RBXScriptConnection?
	self._fades = {} :: { [Player]: PlayerFade }
	self._lastVisible = {} :: { [Player]: boolean }
	self._lastOffscreen = {} :: { [Player]: boolean }
	self._boxFreeze = {} :: { [Player]: BoxFreeze }
	self._frameTargets = {} :: { [any]: any }
	self._lastFrame = 0

	self._deathAnimLink = link:Get("enabled.animations.deathAnimations")
	self._elementAnimLink = link:Get("enabled.animations.elementAnimations")
	self._boundingLink = link:Get("enabled.animations.bounding")
	self._maxDistanceLink = link:Get("enabled.animations.maxDistance")
	self._updateRateLink = link:Get("enabled.animations.updateRate")

	self._cachedDeathAnim = peek(self._deathAnimLink._state) :: boolean
	self._cachedElementAnim = peek(self._elementAnimLink._state) :: boolean
	self._cachedBounding = peek(self._boundingLink._state) :: boolean
	self._cachedMaxDistance = peek(self._maxDistanceLink._state) :: number
	self._cachedUpdateRate = peek(self._updateRateLink._state) :: number
	self:Track(sub(self._deathAnimLink._state, function(v: boolean): ()
		self._cachedDeathAnim = v
	end))
	self:Track(sub(self._elementAnimLink._state, function(v: boolean): ()
		self._cachedElementAnim = v
	end))
	self:Track(sub(self._boundingLink._state, function(v: boolean): ()
		self._cachedBounding = v
	end))
	self:Track(sub(self._maxDistanceLink._state, function(v: number): ()
		self._cachedMaxDistance = v
	end))
	self:Track(sub(self._updateRateLink._state, function(v: number): ()
		self._cachedUpdateRate = v
	end))

	local previewLink = resolvedOpts.previewLink
	local elementsLink = previewLink and previewLink:WithPrefix(link._prefix) or link

	local elementOpts = resolvedOpts.elementOpts or {}
	self._settings = {} :: { [string]: any }
	for _, def in next, elements do
		self._settings[def.id] = def.setup(elementsLink, elementOpts[def.id])
		espStateColors.BindElement(def.id, self._settings[def.id])
	end
	local function syncOverrideActive(): ()
		local selectedToggle = espStateColors.GetOverrideToggle(peek(espStateColors.selectedState))
		overrideDefaultToggle._active(selectedToggle ~= nil and peek(selectedToggle._state) == true)
	end
	self:Track(sub(espStateColors.selectedState, syncOverrideActive))
	for _, stateDef in espStateColors.GetStates() do
		local stateToggle = espStateColors.GetOverrideToggle(stateDef.id)
		if stateToggle then
			self:Track(sub(stateToggle._state, syncOverrideActive))
		end
	end
	syncOverrideActive()

	self._elementActive = at({} :: { [string]: boolean })
	self._enabledAtom = at(false)
	self._anyElementActive = false
	self._espMasterActive = false
	self._needsStateBucket = false
	self._needsStateVis = false
	self._cachedNeedsBoxLayout = false
	self._activeElements = {} :: { EspElement.AnyEspElement }
	self._activeCount = 0
	self._offscreenActive = false
	self._highlightCleanupDone = false
	self._highlightDeactivate = nil :: ((settings: any) -> ())?
	self._skeletonCleanupDone = false
	self._skeletonDeactivate = nil :: ((settings: any) -> ())?
	for _, def in next, elements do
		if def.id == HIGHLIGHT_ELEMENT_ID and def.deactivate then
			self._highlightDeactivate = def.deactivate
		elseif def.id == SKELETON_ELEMENT_ID and def.deactivate then
			self._skeletonDeactivate = def.deactivate
		end
	end
	self:_setupActiveTracking()

	local hbSettings = self._settings.healthbar
	self._cachedHbEnabled = hbSettings and peek(hbSettings.enabled._state) or false
	self._cachedHbWidth = hbSettings and peek(hbSettings.width._state) or 0
	if hbSettings then
		self:Track(sub(hbSettings.enabled._state, function(v: boolean): ()
			self._cachedHbEnabled = v
		end))
		self:Track(sub(hbSettings.width._state, function(v: number): ()
			self._cachedHbWidth = v
		end))
	end

	local screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		AutoLocalize = false,
		DisplayOrder = 0,
	}, cloneref(gethui()))
	self._screenGui = screenGui

	self._root = ReactRoblox.createRoot(screenGui)

	local stateRef = self._state
	local settingsRef = self._settings
	local elementsRef = self._elements
	for _, basePlayer in next, PlayerController.GetAll() do
		local player = (basePlayer :: any):GetPlayer()
		stateRef:Set(player, buildEntry(player, basePlayer, settingsRef, elementsRef))
	end

	local addedConn = PlayerController.playerAdded:Connect(function(basePlayer): ()
		setthreadidentity(8)
		local player = (basePlayer :: any):GetPlayer()
		stateRef:Set(player, buildEntry(player, basePlayer, settingsRef, elementsRef))
	end)
	self:Track(function(): ()
		addedConn:Disconnect()
	end)

	local fadesRef = self._fades
	local lastVisibleRef = self._lastVisible
	local lastOffscreenRef = self._lastOffscreen
	local boxFreezeRef = self._boxFreeze
	local removingConn = PlayerController.playerRemoving:Connect(function(basePlayer): ()
		setthreadidentity(8)
		local player = (basePlayer :: any):GetPlayer()
		local existing = stateRef:Get(player)
		if existing then
			destroyEntry(existing, settingsRef, elementsRef)
		end
		stateRef:Remove(player)
		fadesRef[player] = nil
		lastVisibleRef[player] = nil
		lastOffscreenRef[player] = nil
		boxFreezeRef[player] = nil
	end)
	self:Track(function(): ()
		removingConn:Disconnect()
	end)

	local targetSource = self._targetSource
	if targetSource then
		local function addTarget(basePlayer: any): ()
			local player = basePlayer:GetPlayer()
			stateRef:Set(player, buildEntry(player, basePlayer, settingsRef, elementsRef))
		end
		local function removeTarget(basePlayer: any): ()
			local player = basePlayer:GetPlayer()
			local existing = stateRef:Get(player)
			if existing then
				destroyEntry(existing, settingsRef, elementsRef)
			end
			stateRef:Remove(player)
			fadesRef[player] = nil
			lastVisibleRef[player] = nil
			lastOffscreenRef[player] = nil
			boxFreezeRef[player] = nil
		end
		for _, basePlayer in next, targetSource.GetAll() do
			addTarget(basePlayer)
		end
		local botAddedConn = targetSource.added:Connect(addTarget)
		self:Track(function(): ()
			botAddedConn:Disconnect()
		end)
		local botRemovedConn = targetSource.removed:Connect(removeTarget)
		self:Track(function(): ()
			botRemovedConn:Disconnect()
		end)
	end

	local enabledElement = link:Get("enabled")
	self:Track(enabledElement:OnChange(function(value: boolean): ()
		self:_setActive(value)
	end))

	if previewLink then
		self._preview = espPreview.new({
			elements = elements,
			settings = self._settings,
			elementActive = self._elementActive,
			enabledAtom = self._enabledAtom,
			previewAtoms = resolvedOpts.previewAtoms,
			previewControls = resolvedOpts.previewControls,
			modelProvider = resolvedOpts.previewModelProvider,
			applyState = resolvedOpts.previewApplyState,
			onFrame = resolvedOpts.previewOnFrame,
			onDestroy = resolvedOpts.previewOnDestroy,
			resolveHrp = resolvedOpts.previewResolveHrp,
			resolveParts = resolvedOpts.previewResolveParts,
			managedModel = resolvedOpts.previewManagedModel,
			despawnOnHide = resolvedOpts.previewDespawnOnHide,
			offset = self._offset,
			cameraDistanceScale = resolvedOpts.previewCameraDistanceScale,
			idleAnimationId = resolvedOpts.previewIdleAnimationId,
			previewLink = previewLink,
			buildEntry = buildEntry,
			computeBounds = computePreviewBounds,
			needsBoxLayout = function(): boolean
				return self._cachedNeedsBoxLayout
			end,
			boundingActive = function(): boolean
				return self._cachedBounding
			end,
			prepareCtx = self._prepareCtx,
			healthTextExtraLeft = function(): number
				return self._cachedHbEnabled and (self._cachedHbWidth + 2) or 0
			end,
		})

		local chipEntries: { any } = {}
		for _, def in next, elements do
			local enabledElement = self._settings[def.id].enabled
			enabledElement:SetVisible(false)
			local submenuElement = resolveSubmenuTarget(enabledElement)
			chipEntries[#chipEntries + 1] = {
				id = def.id,
				label = peek(enabledElement._text),
				enabledElement = enabledElement,
				submenuElement = submenuElement,
			}
		end
		previewLink:EspElements("Elements", {
			elements = chipEntries,
			enabledMaster = self._enabledAtom,
		})
	end

	return self
end

function Esp._syncRenderLoop(self: Esp): ()
	local shouldRun = self._espMasterActive and self._anyElementActive
	if shouldRun then
		if not self._renderConn then
			self._renderConn = self:_startRenderLoop()
		end
	elseif self._renderConn then
		self._renderConn:Disconnect()
		self._renderConn = nil
	end
end

function Esp._setupActiveTracking(self: Esp): ()
	local function recomputeAny(): ()
		local active = peek(self._elementActive)
		local activeElements = self._activeElements
		table.clear(activeElements)
		local count = 0
		for _, def in next, self._elements do
			if active[def.id] then
				count += 1
				activeElements[count] = def
			end
		end
		self._activeCount = count
		self._anyElementActive = count > 0
		self._offscreenActive = active[OFFSCREEN_ELEMENT_ID] == true
		self._cachedNeedsBoxLayout = self._activeNeedsBoxLayout(active)

		local needsBucket = false
		for id in next, STATE_BUCKET_ELEMENT_IDS do
			if active[id] then
				needsBucket = true
				break
			end
		end
		self._needsStateBucket = needsBucket
		self._needsStateVis = espStateColors.NeedsStateVis()

		if active[HIGHLIGHT_ELEMENT_ID] then
			self._highlightCleanupDone = false
		elseif not self._highlightCleanupDone and self._highlightDeactivate then
			self._highlightDeactivate(self._settings[HIGHLIGHT_ELEMENT_ID])
			self._highlightCleanupDone = true
		end

		if active[SKELETON_ELEMENT_ID] then
			self._skeletonCleanupDone = false
		elseif not self._skeletonCleanupDone and self._skeletonDeactivate then
			self._skeletonDeactivate(self._settings[SKELETON_ELEMENT_ID])
			self._skeletonCleanupDone = true
		end

		self:_syncRenderLoop()
	end

	for _, def in next, self._elements do
		local settings = self._settings[def.id]
		local atoms: { any } = { settings.enabled._state }

		local id = def.id
		local function recompute(): ()
			local any = false
			for _, atom in next, atoms do
				if peek(atom) then
					any = true
					break
				end
			end
			local current = peek(self._elementActive)
			if current[id] == any then
				return
			end
			local nextActive = table.clone(current)
			nextActive[id] = any
			self._elementActive(nextActive)
			recomputeAny()
		end

		for _, atom in next, atoms do
			self:Track(sub(atom, recompute))
		end
		recompute()
	end

	self:Track(sub(espStateColors.visSignal, recomputeAny))
end

function Esp._setActive(self: Esp, active: boolean): ()
	for _, def in next, self._elements do
		if def.setActive then
			def.setActive(self._settings[def.id], active)
		end
	end

	self._espMasterActive = active
	self._enabledAtom(active)

	if active then
		self._root:render(e(espCanvas, {
			state = self._state,
			settings = self._settings,
			elements = self._elements,
			elementActive = self._elementActive,
		}))
		self:_syncRenderLoop()
	else
		self:_syncRenderLoop()
		self._root:render(nil)
	end
end

function Esp._startRenderLoop(self: Esp): RBXScriptConnection
	local state = self._state
	local fades = self._fades
	local lastVisible = self._lastVisible
	local lastOffscreen = self._lastOffscreen
	local boxFreeze = self._boxFreeze
	local filter = self._filter
	local filterBots = self._filterBots
	local prepareCtx = self._prepareCtx
	local offset = self._offset
	local offX = offset and offset.X or 0
	local offY = offset and offset.Y or 0
	local hasOffset = offX ~= 0 or offY ~= 0
	local targetSource = self._targetSource
	local frameTargets = self._frameTargets
	local entriesAtom = state.entries

	local frameCtx: EspElement.EspCtx = {
		basePlayer = nil :: any,
		hrp = nil :: any,
		camera = nil :: any,
		project = nil,
		camPos = Vector3.zero,
		screen = Vector3.zero,
		depth = 0,
		pps = 0,
		visible = false,
		shouldShow = false,
		boxPosition = Vector2.zero,
		boxSize = Vector2.zero,
		alpha = 0,
		deathFading = false,
		dt = 0,
		elementAnimations = false,
		healthTextExtraLeft = 0,
		viewport = Vector2.zero,
		onScreen = false,
		offscreenReady = false,
		userId = 0,
		stateBucket = nil,
		dist = -1,
		extra = {},
	}

	self._lastFrame = clock()

	local render = LPH_NO_VIRTUALIZE(function()
		local nowClock = clock()
		local updateCap = self._cachedUpdateRate
		if updateCap > 0 and nowClock - self._lastFrame < 1 / updateCap then
			return
		end
		local dt = nowClock - self._lastFrame
		self._lastFrame = nowClock

		if not self._anyElementActive then
			return
		end

		local camera = Workspace.CurrentCamera

		local deathAnimations = self._cachedDeathAnim
		local elementAnimations = self._cachedElementAnim
		local needsBoxLayout = self._cachedNeedsBoxLayout
		local useBounding = needsBoxLayout and self._cachedBounding
		local fadeBlend = deathAnimations and (1 - math.exp(-dt * FADE_RATE)) or 1
		local viewport = camera.ViewportSize
		local maxDistance = self._cachedMaxDistance
		local maxDistanceSq = maxDistance * maxDistance
		local camPos = camera.CFrame.Position

		local project, pixelsPerStudUnit = espProject.make(camera, viewport)

		local heightCoeff = 0
		local halfWidthCoeff = 0
		local topCoeff = 0
		local healthTextExtraLeft = 0
		if needsBoxLayout then
			heightCoeff = pixelsPerStudUnit * CHAR_HEIGHT
			halfWidthCoeff = pixelsPerStudUnit * CHAR_HALF_WIDTH
			topCoeff = pixelsPerStudUnit * CHAR_HALF_UP
			healthTextExtraLeft = self._cachedHbEnabled and (self._cachedHbWidth + 2) or 0
		end

		local players = PlayerController.GetAll()
		if targetSource then
			local merged = frameTargets
			table.clear(merged)
			for key, bp in next, players do
				merged[key] = bp
			end
			for _, bp in next, targetSource.GetAll() do
				merged[(bp :: any):GetPlayer()] = bp
			end
			players = merged
		end
		local elementActive = peek(self._elementActive)
		local settings = self._settings
		local offscreenActive = self._offscreenActive
		local entries = peek(entriesAtom)

		local activeElements = self._activeElements
		local activeCount = self._activeCount

		local needsStateBucket = self._needsStateBucket
		local needsStateData = needsStateBucket or self._needsStateVis

		local ctx = frameCtx
		ctx.camera = camera
		ctx.project = project
		ctx.camPos = camPos
		ctx.dt = dt
		ctx.elementAnimations = elementAnimations
		ctx.viewport = viewport
		ctx.screen = Vector3.zero
		ctx.depth = 0
		ctx.pps = 0
		ctx.boxPosition = Vector2.zero
		ctx.boxSize = Vector2.zero
		ctx.stateBucket = nil
		ctx.userId = 0

		for player, basePlayer in next, players do
			local entry = entries[player]
			if not entry then
				continue
			end

			local wasVisible = lastVisible[player] == true
			local wasOffscreen = lastOffscreen[player] == true
			local fadeData = fades[player]
			local fadeAlpha = (fadeData and fadeData.alpha or 0)

			local alive = peek(basePlayer.alive)
			local excluded = (basePlayer :: any).culled ~= nil and peek((basePlayer :: any).culled) == true
			if not excluded and filter and (filterBots or not (basePlayer :: any).isBot) then
				excluded = filter(basePlayer) == true
			end

			if fadeAlpha <= ALPHA_EPSILON and not wasVisible and not wasOffscreen then
				if not alive or excluded then
					continue
				end
			end

			ctx.basePlayer = basePlayer
			ctx.hrp = nil
			ctx.visible = false
			ctx.shouldShow = false
			ctx.alpha = 0
			ctx.deathFading = false
			ctx.healthTextExtraLeft = 0
			ctx.onScreen = false
			ctx.offscreenReady = false
			ctx.dist = -1

			local shouldShow = alive and not excluded

			if not fadeData then
				fadeData = { alpha = 0 }
				fades[player] = fadeData
			end

			local hrp = peek(basePlayer.hrp) :: BasePart?
			if shouldShow and hrp and maxDistance > 0 then
				local rel = hrp.Position - camPos
				if rel.X * rel.X + rel.Y * rel.Y + rel.Z * rel.Z > maxDistanceSq then
					shouldShow = false
				end
			end
			ctx.shouldShow = shouldShow
			if hrp then
				local target = shouldShow and 1 or 0
				local blended = fadeData.alpha + (target - fadeData.alpha) * fadeBlend
				if blended > 1 - ALPHA_EPSILON then
					blended = 1
				elseif blended < ALPHA_EPSILON then
					blended = 0
				end
				fadeData.alpha = blended
			else
				local blended = deathAnimations and (fadeData.alpha * (1 - fadeBlend)) or 0
				fadeData.alpha = blended < ALPHA_EPSILON and 0 or blended
			end

			local alpha = fadeData.alpha

			if hrp and alpha > ALPHA_EPSILON then
				if needsBoxLayout then
					local boundsResult: BoundsResult?
					if useBounding then
						local frozen = boxFreeze[player]
						if alive then
							local parts = peek(basePlayer.parts) :: { [string]: BasePart }
							boundsResult = computeBoundingBounds(project, hrp, parts, pixelsPerStudUnit)
							if boundsResult and boundsResult.pps > 0 then
								local bp = boundsResult.boxPosition
								local sz = boundsResult.boxSize
								local sc = boundsResult.screen
								local invPps = 1 / boundsResult.pps
								local uLeft = (bp.X - sc.X) * invPps
								local uTop = (bp.Y - sc.Y) * invPps
								local uW = sz.X * invPps
								local uH = sz.Y * invPps
								local fr = boxFreeze[player]
								if fr then
									fr.uLeft = uLeft
									fr.uTop = uTop
									fr.uW = uW
									fr.uH = uH
								else
									boxFreeze[player] = { uLeft = uLeft, uTop = uTop, uW = uW, uH = uH }
								end
							end
						elseif frozen then
							boundsResult = computeFrozenBounds(project, hrp, pixelsPerStudUnit, frozen)
						else
							local parts = peek(basePlayer.parts) :: { [string]: BasePart }
							boundsResult = computeBoundingBounds(project, hrp, parts, pixelsPerStudUnit)
						end
					else
						boundsResult = computeClassicBounds(
							project,
							hrp,
							pixelsPerStudUnit,
							halfWidthCoeff,
							heightCoeff,
							topCoeff,
							offX,
							offY
						)
					end

					if boundsResult then
						local bpx = boundsResult.boxPosition
						local bsz = boundsResult.boxSize
						local onScreenBox = boundsResult.depth > 0
							and bpx.X + bsz.X >= 0
							and bpx.X <= viewport.X
							and bpx.Y + bsz.Y >= 0
							and bpx.Y <= viewport.Y
						if onScreenBox then
							ctx.hrp = hrp
							ctx.screen = boundsResult.screen
							ctx.depth = boundsResult.depth
							ctx.pps = boundsResult.pps
							ctx.boxPosition = bpx
							ctx.boxSize = bsz
							ctx.visible = true
							ctx.alpha = alpha
							ctx.deathFading = not alive and deathAnimations
							ctx.healthTextExtraLeft = healthTextExtraLeft
						end
					end
				else
					local rootScreen = project(hrp.Position)
					if rootScreen.Z > 0 then
						if hasOffset then
							local pps = pixelsPerStudUnit / rootScreen.Z
							rootScreen = Vector3.new(rootScreen.X + offX * pps, rootScreen.Y + offY * pps, rootScreen.Z)
						end
						ctx.hrp = hrp
						ctx.screen = rootScreen
						ctx.depth = rootScreen.Z
						ctx.visible = true
						ctx.alpha = alpha
						ctx.deathFading = not alive and deathAnimations
					end
				end
			end

			if offscreenActive and hrp and alpha > ALPHA_EPSILON then
				local screen
				if ctx.visible then
					screen = ctx.screen
				else
					screen = project(hrp.Position)
					ctx.screen = screen
					ctx.depth = screen.Z
				end
				ctx.hrp = hrp
				ctx.onScreen = ctx.depth > 0
					and screen.X >= 0
					and screen.X <= viewport.X
					and screen.Y >= 0
					and screen.Y <= viewport.Y
				ctx.alpha = alpha
				ctx.deathFading = not alive and deathAnimations
				ctx.offscreenReady = true
			end

			if not ctx.visible and not ctx.offscreenReady and not wasVisible and not wasOffscreen then
				continue
			end
			lastVisible[player] = ctx.visible
			lastOffscreen[player] = ctx.offscreenReady

			local container = entry.__box
			if container and needsBoxLayout then
				if ctx.visible then
					container.position.set(ctx.boxPosition)
					container.size.set(ctx.boxSize)
					container.visible.set(true)
				else
					container.visible.set(false)
				end
			end

			ctx.userId = player.UserId
			local stateVis: any = nil
			if needsStateData then
				local bucket, vis = espStateColors.ResolveStateData(player.UserId)
				ctx.stateBucket = bucket
				stateVis = vis
			else
				ctx.stateBucket = nil
			end

			if prepareCtx then
				prepareCtx(ctx, entry, elementActive, settings)
			end

			for i = 1, activeCount do
				local def = activeElements[i]
				if stateVis ~= nil and stateVis[def.id] == false then
					local v, o, r, a, s = ctx.visible, ctx.onScreen, ctx.offscreenReady, ctx.alpha, ctx.shouldShow
					ctx.visible, ctx.onScreen, ctx.offscreenReady, ctx.alpha, ctx.shouldShow =
						false, false, false, 0, false
					def.update(entry[def.id], ctx, settings[def.id])
					ctx.visible, ctx.onScreen, ctx.offscreenReady, ctx.alpha, ctx.shouldShow = v, o, r, a, s
				else
					def.update(entry[def.id], ctx, settings[def.id])
				end
			end
		end
	end)

	return RunService.PreRender:Connect(render)
end

function Esp.Destroy(self: Esp): ()
	if self._preview then
		self._preview:Destroy()
		self._preview = nil
	end
	if self._renderConn then
		self._renderConn:Disconnect()
		self._renderConn = nil
	end
	self._root:unmount()
	self._screenGui:Destroy()

	local entries = peek(self._state.entries)
	for _, entry in next, entries do
		destroyEntry(entry, self._settings, self._elements)
	end

	BaseFeature.Destroy(self)
end

export type Esp =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_state: EspState.EspState,
			_settings: { [string]: any },
			_elements: { EspElement.AnyEspElement },
			_filter: FilterFn?,
			_filterBots: boolean?,
			_prepareCtx: PrepareCtxFn?,
			_targetSource: TargetSource?,
			_frameTargets: { [any]: any },
			_activeNeedsBoxLayout: (active: { [string]: boolean }) -> boolean,
			_root: ReactRoblox.RootType,
			_screenGui: Instance,
			_renderConn: RBXScriptConnection?,
			_fades: { [Player]: PlayerFade },
			_lastVisible: { [Player]: boolean },
			_lastOffscreen: { [Player]: boolean },
			_boxFreeze: { [Player]: BoxFreeze },
			_lastFrame: number,
			_deathAnimLink: any,
			_elementAnimLink: any,
			_boundingLink: any,
			_maxDistanceLink: any,
			_updateRateLink: any,
			_cachedDeathAnim: boolean,
			_cachedElementAnim: boolean,
			_cachedBounding: boolean,
			_cachedMaxDistance: number,
			_cachedUpdateRate: number,
			_cachedNeedsBoxLayout: boolean,
			_needsStateBucket: boolean,
			_needsStateVis: boolean,
			_cachedHbEnabled: boolean,
			_cachedHbWidth: number,
			_highlightCleanupDone: boolean,
			_highlightDeactivate: ((settings: any) -> ())?,
			_skeletonCleanupDone: boolean,
			_skeletonDeactivate: ((settings: any) -> ())?,
			_elementActive: Charm.Atom<{ [string]: boolean }>,
			_enabledAtom: Charm.Atom<boolean>,
			_anyElementActive: boolean,
			_espMasterActive: boolean,
			_activeElements: { EspElement.AnyEspElement },
			_activeCount: number,
			_offscreenActive: boolean,
			_preview: any,
		},
		Esp
	))
	& BaseFeature.BaseFeature

return Esp
