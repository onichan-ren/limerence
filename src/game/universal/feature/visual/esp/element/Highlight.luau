local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local instances = require("@share/instances")
local gameUi = require("@game/gameUi")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")

local subscribeToBinding = (React :: any).__subscribeToBinding
local peek = Charm.peek
local sub = Charm.subscribe

local DEFAULT_FILL = Color3.fromRGB(0, 255, 238)
local DEFAULT_OUTLINE = Color3.fromRGB(199, 143, 255)
local ALPHA_EPSILON = 1e-3

type State = {
	highlight: Highlight?,
	alpha: number,
	_lastFill: Color3?,
	_lastFillT: number,
	_lastOutline: Color3?,
	_lastOutlineT: number,
	_alive: boolean,
	_visible: boolean,
	_aliveUnsub: () -> (),
} & EspElement.CharacterCache

type Settings = {
	enabled: any,
	fillColor: any,
	outlineColor: any,
	behindWalls: any,
}

local manager = {
	folder = nil :: Folder?,
	masterActive = false,
	states = {} :: { [State]: true },
	cache = {
		fillColor = DEFAULT_FILL,
		fillTransparency = 0.7,
		outlineColor = DEFAULT_OUTLINE,
		outlineTransparency = 0,
		behindWalls = true,
	},
	initialized = false,
	settings = nil :: Settings?,
}

local function fadedTransparency(base: number, alpha: number): number
	return 1 - (1 - base) * alpha
end

local function isHighlightEnabled(): boolean
	local settings = manager.settings
	if not settings then
		return false
	end
	return settings.enabled:Peek() == true
end

local function applyFolderParent(): ()
	local folder = manager.folder
	if not folder then
		return
	end
	local show = manager.masterActive and isHighlightEnabled()
	setthreadidentity(8)
	folder.Parent = show and cloneref(gethui()) or nil
end

local function ensureFolder(): Folder
	if manager.folder then
		return manager.folder
	end
	local folder = Instance.new("Folder")
	manager.folder = folder
	applyFolderParent()
	return folder
end

local function ensureHighlight(state: State): Highlight
	local hl = state.highlight
	if hl then
		return hl
	end
	hl = instances.new("Highlight", {
		DepthMode = manager.cache.behindWalls and Enum.HighlightDepthMode.AlwaysOnTop
			or Enum.HighlightDepthMode.Occluded,
		Enabled = false,
	}, ensureFolder()) :: Highlight
	state.highlight = hl
	return hl
end

local function destroyHighlight(state: State): ()
	local hl = state.highlight
	if hl then
		hl:Destroy()
		state.highlight = nil
	end
	state._visible = false
end

local function syncFillCache(settings: Settings): ()
	local snap = settings.fillColor:GetSnapshot()
	manager.cache.fillColor = snap.color
	manager.cache.fillTransparency = snap.transparency
end

local function syncOutlineCache(settings: Settings): ()
	local snap = settings.outlineColor:GetSnapshot()
	manager.cache.outlineColor = snap.color
	manager.cache.outlineTransparency = snap.transparency
end

local applyStyle = LPH_NO_VIRTUALIZE(function(state: State): ()
	local hl = state.highlight
	if not hl then
		return
	end
	local cache = manager.cache
	local alpha = state.alpha
	hl.FillColor = cache.fillColor
	hl.OutlineColor = cache.outlineColor
	hl.FillTransparency = fadedTransparency(cache.fillTransparency, alpha)
	hl.OutlineTransparency = fadedTransparency(cache.outlineTransparency, alpha)
end)

local applyAllStyles = LPH_NO_VIRTUALIZE(function(): ()
	for st in next, manager.states do
		applyStyle(st)
	end
end)

local function applyDepthMode(): ()
	local mode = manager.cache.behindWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
	for st in next, manager.states do
		local hl = st.highlight
		if hl then
			hl.DepthMode = mode
		end
	end
end

local function hideOne(state: State): ()
	destroyHighlight(state)
end

local disableAllHighlights = LPH_NO_VIRTUALIZE(function(): ()
	for st in next, manager.states do
		destroyHighlight(st)
	end
end)

local function setup(link: gameUi.Linker): Settings
	link:Toggle("highlight", "Highlight", false):SetTip({
		title = "Highlight",
		body = "Colored fill and outline drawn over enemy players.",
	})
	local highlightLink = link:OnKey("highlight")
	highlightLink:Colorpicker("fillColor", "Fill Color", DEFAULT_FILL, 0.7)
	espStateColors.Register({ id = "highlight", label = "Highlight", default = DEFAULT_FILL, transparency = 0.7 })
	highlightLink:Submenu("opts", "Highlight Options")
	local optsLink = highlightLink:OnKey("opts")
	optsLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)
	espStateColors.Register({ id = "highlightOutline", label = "Highlight Outline", default = DEFAULT_OUTLINE, transparency = 0 })
	optsLink:Toggle("behindWalls", "Behind Walls", true):SetTip({
		title = "Behind Walls",
		body = "Keeps the highlight visible through walls.",
	})

	local toggle = link:Get("highlight")
	local settings: Settings = {
		enabled = toggle,
		fillColor = link:Get("highlight.fillColor"),
		outlineColor = link:Get("highlight.opts.outlineColor"),
		behindWalls = link:Get("highlight.opts.behindWalls"),
	}
	manager.settings = settings

	toggle:OnChange(function(enabled: boolean): ()
		if enabled then
			applyFolderParent()
		else
			disableAllHighlights()
			applyFolderParent()
		end
	end)
	if not toggle:Peek() then
		disableAllHighlights()
		applyFolderParent()
	end

	if manager.initialized then
		return settings
	end
	manager.initialized = true

	syncFillCache(settings)
	syncOutlineCache(settings)
	manager.cache.behindWalls = peek(settings.behindWalls._state) == true

	subscribeToBinding(settings.fillColor._current, function(): ()
		syncFillCache(settings)
		applyAllStyles()
	end)
	subscribeToBinding(settings.outlineColor._current, function(): ()
		syncOutlineCache(settings)
		applyAllStyles()
	end)
	sub(settings.behindWalls._state, function(enabled: boolean): ()
		manager.cache.behindWalls = enabled == true
		applyDepthMode()
	end)

	return settings
end

local function createState(_player: Player, basePlayer: any, _settings: Settings): State
	local state: State = {
		highlight = nil,
		alpha = 0,
		_lastFill = nil,
		_lastFillT = -1,
		_lastOutline = nil,
		_lastOutlineT = -1,
		_character = nil,
		_playerUnsub = function() end,
		_alive = false,
		_visible = false,
		_aliveUnsub = function() end,
	}
	EspElement.attachCharacterCache(basePlayer, state)
	if basePlayer then
		state._alive = peek(basePlayer.alive) :: boolean
		state._aliveUnsub = sub(basePlayer.alive, function(alive: boolean): ()
			state._alive = alive
			if not alive and not state._visible then
				hideOne(state)
			end
		end)
	end
	manager.states[state] = true
	return state
end

local function destroyState(state: State, _settings: Settings): ()
	state._playerUnsub()
	state._aliveUnsub()
	manager.states[state] = nil
	destroyHighlight(state)
end

local function deactivate(_settings: Settings): ()
	disableAllHighlights()
	applyFolderParent()
end

local function setActive(settings: Settings, active: boolean): ()
	manager.masterActive = active
	manager.settings = settings
	applyFolderParent()
	if not active or not settings.enabled:Peek() then
		disableAllHighlights()
	end
end

local update = LPH_NO_VIRTUALIZE(function(state: State, ctx: EspElement.EspCtx, _settings: Settings): ()
	if not ctx.visible then
		state._visible = false
		if not ctx.shouldShow or not state._alive or not state._character then
			hideOne(state)
		end
		return
	end

	local character = state._character
	if not character then
		hideOne(state)
		return
	end

	local hl = state.highlight
	local fresh = hl == nil
	if not hl then
		hl = ensureHighlight(state)
	end

	local bucket = ctx.stateBucket
	local cp = bucket and bucket.highlight
	local fillColor, fillTransparency
	if cp then
		fillColor = cp:GetColor()
		fillTransparency = cp:GetTransparency()
	else
		fillColor = manager.cache.fillColor
		fillTransparency = manager.cache.fillTransparency
	end

	local ocp = bucket and bucket.highlightOutline
	local outlineColor, outlineTransparency
	if ocp then
		outlineColor = ocp:GetColor()
		outlineTransparency = ocp:GetTransparency()
	else
		outlineColor = manager.cache.outlineColor
		outlineTransparency = manager.cache.outlineTransparency
	end

	local newAlpha = ctx.alpha
	if
		fresh
		or math.abs(state.alpha - newAlpha) >= ALPHA_EPSILON
		or state._lastFill ~= fillColor
		or state._lastFillT ~= fillTransparency
		or state._lastOutline ~= outlineColor
		or state._lastOutlineT ~= outlineTransparency
	then
		state.alpha = newAlpha
		state._lastFill = fillColor
		state._lastFillT = fillTransparency
		state._lastOutline = outlineColor
		state._lastOutlineT = outlineTransparency
		hl.FillColor = fillColor
		hl.OutlineColor = outlineColor
		hl.FillTransparency = fadedTransparency(fillTransparency, newAlpha)
		hl.OutlineTransparency = fadedTransparency(outlineTransparency, newAlpha)
	end

	hl.Adornee = character
	hl.Enabled = true
	state._visible = true
end)

return {
	id = "highlight",
	setup = setup,
	createState = createState,
	update = update,
	destroyState = destroyState,
	setActive = setActive,
	deactivate = deactivate,
} :: EspElement.EspElement<State, Settings>
