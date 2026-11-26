local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")
local espSkeletonLines = require("@game/universal/feature/visual/esp/espSkeletonLines")
local skeletonBones = require("@game/universal/feature/visual/skeletonBones")

local peek = Charm.peek
local sub = Charm.subscribe
local subscribeToBinding = (React :: any).__subscribeToBinding

local DEFAULT_COLOR = Color3.fromRGB(225, 225, 225)
local DEFAULT_OUTLINE = Color3.fromRGB(18, 18, 18)

local MAX_LINE_COUNT = skeletonBones.MAX_EDGES

type LineHandle = espSkeletonLines.LineHandle

type State = {
	lines: { LineHandle },
	_edges: { any },
	_parts: { [string]: BasePart },
	_sizes: { [string]: Vector3 },
	_prevEdgeCount: number,
	_playerUnsub: () -> (),
	_sizesUnsub: () -> (),
}

type Settings = {
	enabled: any,
	color: any,
	thickness: any,
	outline: any,
	outlineColor: any,
	cache: {
		thickness: number,
		color: Color3,
		colorTransparency: number,
		outline: boolean,
		outlineColor: Color3,
		outlineTransparency: number,
	},
}

local manager = {
	masterActive = false,
	settings = nil :: Settings?,
	states = {} :: { [State]: true },
}

local function syncParts(state: State, parts: { [string]: Instance }): ()
	state._parts = parts :: any
	state._edges = skeletonBones.pickEdges(parts) or {}
end

local function hideLines(state: State): ()
	for i = 1, #state.lines do
		espSkeletonLines.hide(state.lines[i])
	end
end

local function hideAllStates(): ()
	for st in next, manager.states do
		hideLines(st)
	end
end

local function setup(link: gameUi.Linker): Settings
	local toggle = link:Toggle("skeleton", "Skeleton", false):SetTip({
		title = "Skeleton",
		body = "Draws bones between character limbs on screen.",
	})
	local skeletonLink = link:OnKey("skeleton")
	skeletonLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0)
	espStateColors.Register({ id = "skeleton", label = "Skeleton", default = DEFAULT_COLOR, transparency = 0 })
	skeletonLink:Submenu("opts", "Skeleton Options")
	local optsLink = skeletonLink:OnKey("opts")
	optsLink:Slider("thickness", "Thickness", 1, 1, 3, 1, nil, "px"):SetTip({
		title = "Thickness",
		body = "Line width in pixels.",
	})
	optsLink:Toggle("outline", "Outline", false):SetTip({
		title = "Outline",
		body = "Draws an outline around each bone line.",
	})
	local outlineLink = optsLink:OnKey("outline")
	outlineLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)
	espStateColors.Register({ id = "skeletonOutline", label = "Skeleton Outline", default = DEFAULT_OUTLINE, transparency = 0 })

	local thicknessLink = link:Get("skeleton.opts.thickness")
	local colorLink = link:Get("skeleton.color")
	local outlineToggleLink = link:Get("skeleton.opts.outline")
	local outlineColorLink = link:Get("skeleton.opts.outline.outlineColor")
	local cache = {
		thickness = peek(thicknessLink._state) :: number,
		color = DEFAULT_COLOR,
		colorTransparency = 0,
		outline = peek(outlineToggleLink._state) :: boolean,
		outlineColor = DEFAULT_OUTLINE,
		outlineTransparency = 0,
	}
	local function syncColor(): ()
		local snap = colorLink:GetSnapshot()
		cache.color = snap.color
		cache.colorTransparency = snap.transparency
	end
	local function syncOutlineColor(): ()
		local snap = outlineColorLink:GetSnapshot()
		cache.outlineColor = snap.color
		cache.outlineTransparency = snap.transparency
	end
	syncColor()
	syncOutlineColor()
	sub(thicknessLink._state, function(v: number): ()
		cache.thickness = v
	end)
	sub(outlineToggleLink._state, function(v: boolean): ()
		cache.outline = v
	end)
	subscribeToBinding(colorLink._current, syncColor)
	subscribeToBinding(outlineColorLink._current, syncOutlineColor)

	local settings: Settings = {
		enabled = toggle,
		color = colorLink,
		thickness = thicknessLink,
		outline = outlineToggleLink,
		outlineColor = outlineColorLink,
		cache = cache,
	}
	manager.settings = settings

	toggle:OnChange(function(enabled: boolean): ()
		if not enabled then
			hideAllStates()
		end
	end)

	return settings
end

local function createState(_player: Player, basePlayer: any, settings: Settings): State
	local color = settings.cache.color
	local lines: { LineHandle } = table.create(MAX_LINE_COUNT)
	for i = 1, MAX_LINE_COUNT do
		lines[i] = espSkeletonLines.create(color)
	end

	local state: State = {
		lines = lines,
		_edges = {},
		_parts = {},
		_sizes = {},
		_prevEdgeCount = -1,
		_playerUnsub = function() end,
		_sizesUnsub = function() end,
	}
	manager.states[state] = true

	if basePlayer then
		syncParts(state, peek(basePlayer.parts))
		state._playerUnsub = sub(basePlayer.parts, function(parts: { [string]: Instance }): ()
			syncParts(state, parts)
		end)
		if basePlayer.partSizes then
			state._sizes = peek(basePlayer.partSizes)
			state._sizesUnsub = sub(basePlayer.partSizes, function(sizes: { [string]: Vector3 }): ()
				state._sizes = sizes
			end)
		end
	end

	return state
end

local function destroyState(state: State, _settings: Settings): ()
	state._playerUnsub()
	state._sizesUnsub()
	manager.states[state] = nil
	for i = 1, #state.lines do
		espSkeletonLines.destroy(state.lines[i])
	end
end

local function setActive(_settings: Settings, active: boolean): ()
	manager.masterActive = active
	if not active then
		hideAllStates()
	end
end

local function deactivate(_settings: Settings): ()
	hideAllStates()
end

local update = LPH_NO_VIRTUALIZE(function(state: State, ctx: EspElement.EspCtx, settings: Settings): ()
	if not manager.masterActive then
		hideLines(state)
		return
	end

	if not ctx.visible or ctx.alpha <= 0 then
		hideLines(state)
		return
	end

	local edges = state._edges
	local edgeCount = #edges
	if edgeCount == 0 then
		hideLines(state)
		return
	end

	local parts = state._parts
	local sizes = state._sizes
	local thickness = settings.cache.thickness
	local bucket = ctx.stateBucket
	local cp = bucket and bucket.skeleton
	local color, baseTransparency
	if cp then
		color = cp:GetColor()
		baseTransparency = cp:GetTransparency()
	else
		color = settings.cache.color
		baseTransparency = settings.cache.colorTransparency
	end
	local transparency = 1 - (1 - baseTransparency) * ctx.alpha
	local outline = settings.cache.outline
	local ocp = bucket and bucket.skeletonOutline
	local outlineColor, outlineBaseTransparency
	if ocp then
		outlineColor = ocp:GetColor()
		outlineBaseTransparency = ocp:GetTransparency()
	else
		outlineColor = settings.cache.outlineColor
		outlineBaseTransparency = settings.cache.outlineTransparency
	end
	local outlineTransparency = 1 - (1 - outlineBaseTransparency) * ctx.alpha

	if state._prevEdgeCount ~= edgeCount then
		state._prevEdgeCount = edgeCount
		for i = edgeCount + 1, #state.lines do
			espSkeletonLines.hide(state.lines[i])
		end
	end

	local project = ctx.project
	local invX, invY = 0, 0
	if project then
		local viewport = ctx.viewport
		invX = 1 / viewport.X
		invY = 1 / viewport.Y
	end

	for i = 1, edgeCount do
		local handle = state.lines[i]
		espSkeletonLines.setColor(handle, color)
		if outline then
			espSkeletonLines.setOutlineColor(handle, outlineColor)
		end
		local edge = edges[i]
		local fromPos = skeletonBones.endpoint(parts, sizes, edge.a)
		local toPos = skeletonBones.endpoint(parts, sizes, edge.b)
		if not fromPos or not toPos then
			espSkeletonLines.hide(handle)
			continue
		end

		local lineState = handle.state
		lineState.from = fromPos
		lineState.to = toPos
		lineState.thickness = thickness
		lineState.transparency = transparency
		lineState.outline = outline
		lineState.outlineTransparency = outlineTransparency
		lineState.visible = true

		if project then
			espSkeletonLines.applyDetached(handle, project, invX, invY)
		end
	end
end)

return {
	id = "skeleton",
	setup = setup,
	createState = createState,
	update = update,
	destroyState = destroyState,
	setActive = setActive,
	deactivate = deactivate,
} :: EspElement.EspElement<State, Settings>
