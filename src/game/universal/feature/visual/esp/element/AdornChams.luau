local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local instances = require("@share/instances")
local gameUi = require("@game/gameUi")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")

local peek = Charm.peek
local sub = Charm.subscribe
local subscribeToBinding = (React :: any).__subscribeToBinding

local DEFAULT_GLOW = Color3.fromRGB(152, 188, 255)
local GLOW_SCALE = 5
local GLOW_SIZE_OFFSET = Vector3.new(0.03, 0.03, 0.03)
local ALPHA_EPSILON = 1e-3

type State = {
	adorns: { [string]: HandleAdornment },
	shown: boolean,
	alpha: number,
	_parts: { [string]: Instance },
	_dirty: boolean,
	_userId: number,
	_lastGlow: Color3?,
	_partsUnsub: () -> (),
}

type Settings = {
	enabled: any,
	color: any,
}

local manager = {
	folder = nil :: Folder?,
	masterActive = false,
	states = {} :: { [State]: true },
	cache = {
		baseColor = DEFAULT_GLOW,
		glowColor = Color3.new(DEFAULT_GLOW.R * GLOW_SCALE, DEFAULT_GLOW.G * GLOW_SCALE, DEFAULT_GLOW.B * GLOW_SCALE),
	},
	initialized = false,
	settings = nil :: Settings?,
	sizeOverrides = nil :: { [string]: Vector3 }?,
}

local function isChamsEnabled(): boolean
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
	local show = manager.masterActive and isChamsEnabled()
	setthreadidentity(8)
	folder.Parent = show and cloneref(gethui()) or nil
end

local function ensureFolder(): Folder
	if manager.folder then
		return manager.folder
	end
	local folder = Instance.new("Folder")
	folder.Name = "EspAdornChams"
	manager.folder = folder
	applyFolderParent()
	return folder
end

local function syncGlowCache(settings: Settings): ()
	local snap = settings.color:GetSnapshot()
	local color = snap.color
	manager.cache.baseColor = color
	manager.cache.glowColor = Color3.new(color.R * GLOW_SCALE, color.G * GLOW_SCALE, color.B * GLOW_SCALE)
end

local applyStyle = LPH_NO_VIRTUALIZE(function(state: State, baseOverride: Color3?): ()
	setthreadidentity(8)
	local base = baseOverride
	if not base then
		local settings = manager.settings
		local cp = settings and espStateColors.ResolvePicker("adornChams", settings.color, state._userId)
		base = cp and cp:GetColor() or DEFAULT_GLOW
	end
	state._lastGlow = base
	local glowColor = Color3.new(base.R * GLOW_SCALE, base.G * GLOW_SCALE, base.B * GLOW_SCALE)
	local glowTransparency = 1 - 2 * state.alpha
	for _, glow in next, state.adorns do
		glow.Color3 = glowColor
		glow.Transparency = glowTransparency
	end
end)

local applyAllStyles = LPH_NO_VIRTUALIZE(function(): ()
	for st in next, manager.states do
		applyStyle(st)
	end
end)

local setShown = LPH_NO_VIRTUALIZE(function(state: State, shown: boolean): ()
	if state.shown == shown then
		return
	end
	state.shown = shown
	setthreadidentity(8)
	for _, glow in next, state.adorns do
		glow.Visible = shown
	end
end)

local function hideAll(): ()
	for st in next, manager.states do
		setShown(st, false)
	end
end

local function clearAdorns(state: State): ()
	setthreadidentity(8)
	for key, glow in next, state.adorns do
		glow:Destroy()
		state.adorns[key] = nil
	end
	state.shown = false
end

local function createAdorn(part: BasePart, state: State, name: string): HandleAdornment
	local folder = ensureFolder()
	local isHead = name == "Head" or name == "FakeHead"

	local overrides = manager.sizeOverrides
	local baseSize = (overrides and overrides[name]) or part.Size

	local glow: HandleAdornment
	if isHead then
		local radius = math.max(baseSize.X, baseSize.Z) * 0.5 + GLOW_SIZE_OFFSET.X
		local height = baseSize.Y * 1.01
		glow = instances.new("CylinderHandleAdornment", {
			Radius = radius,
			Height = height,
			Angle = 360,
			CFrame = CFrame.Angles(math.rad(90), 0, 0),
			AlwaysOnTop = true,
			ZIndex = 10,
			Adornee = part,
			Visible = state.shown,
		}, folder) :: CylinderHandleAdornment
	else
		glow = instances.new("BoxHandleAdornment", {
			Size = baseSize + GLOW_SIZE_OFFSET,
			AlwaysOnTop = true,
			ZIndex = 9,
			Adornee = part,
			Visible = state.shown,
		}, folder) :: BoxHandleAdornment
	end
	(glow :: any).Shading = Enum.AdornShading.XRayShaded

	return glow
end

local rebuild = LPH_NO_VIRTUALIZE(function(state: State): ()
	setthreadidentity(8)
	state._dirty = false

	local parts = state._parts
	if not next(parts) then
		return
	end

	local desired: { [string]: BasePart } = {}
	for name, inst in next, parts do
		if
			name ~= "HumanoidRootPart"
			and string.sub(name, 1, 6) ~= "Hitbox"
			and inst:IsA("BasePart")
			and (inst :: BasePart).Transparency < 1
		then
			desired[name] = inst :: BasePart
		end
	end

	for name, glow in next, state.adorns do
		if not desired[name] then
			glow:Destroy()
			state.adorns[name] = nil
		end
	end

	local overrides = manager.sizeOverrides
	local created = false
	for name, part in next, desired do
		local glow = state.adorns[name]
		if glow then
			if glow.Adornee ~= part then
				glow.Adornee = part
			end
			if glow:IsA("BoxHandleAdornment") then
				local baseSize = (overrides and overrides[name]) or part.Size
				local size = baseSize + GLOW_SIZE_OFFSET
				if glow.Size ~= size then
					glow.Size = size
				end
			end
		else
			state.adorns[name] = createAdorn(part, state, name)
			created = true
		end
	end

	if created then
		applyStyle(state)
	end
end)

local function setup(link: gameUi.Linker, opts: { sizes: { [string]: Vector3 }? }?): Settings
	if opts and opts.sizes then
		manager.sizeOverrides = opts.sizes
	end

	link:Toggle("adornChams", "Glow Chams", false):SetTip({
		title = "Glow Chams",
		body = "Glowing boxes drawn over enemy bodies, visible through walls.",
	})
	local chamsLink = link:OnKey("adornChams")
	chamsLink:Colorpicker("color", "Color", DEFAULT_GLOW)
	espStateColors.Register({ id = "adornChams", label = "Glow Chams", default = DEFAULT_GLOW })

	local toggle = link:Get("adornChams")
	local settings: Settings = {
		enabled = toggle,
		color = link:Get("adornChams.color"),
	}
	manager.settings = settings

	toggle:OnChange(function(enabled: boolean): ()
		if not enabled then
			hideAll()
		end
		applyFolderParent()
	end)
	if not toggle:Peek() then
		hideAll()
		applyFolderParent()
	end

	if manager.initialized then
		return settings
	end
	manager.initialized = true

	syncGlowCache(settings)

	subscribeToBinding(settings.color._current, function(): ()
		syncGlowCache(settings)
		applyAllStyles()
	end)

	return settings
end

local function createState(player: Player, basePlayer: any, _settings: Settings): State
	local state: State = {
		adorns = {},
		shown = false,
		alpha = 0,
		_parts = {},
		_dirty = true,
		_userId = player.UserId,
		_lastGlow = nil,
		_partsUnsub = function() end,
	}

	if basePlayer then
		state._parts = peek(basePlayer.parts) or {}
		state._partsUnsub = sub(basePlayer.parts, function(parts: { [string]: Instance }): ()
			state._parts = parts
			state._dirty = true
			if not next(parts) then
				setShown(state, false)
			end
		end)
	end

	manager.states[state] = true
	return state
end

local function destroyState(state: State, _settings: Settings): ()
	state._partsUnsub()
	clearAdorns(state)
	manager.states[state] = nil
end

local function deactivate(_settings: Settings): ()
	hideAll()
	applyFolderParent()
end

local function setActive(settings: Settings, active: boolean): ()
	manager.masterActive = active
	manager.settings = settings
	applyFolderParent()
	if not active or not settings.enabled:Peek() then
		hideAll()
	end
end

local update = LPH_NO_VIRTUALIZE(function(state: State, ctx: EspElement.EspCtx, _settings: Settings): ()
	if not ctx.visible then
		setShown(state, false)
		return
	end

	if state._dirty then
		rebuild(state)
	end

	local bucket = ctx.stateBucket
	local cp = bucket and bucket.adornChams
	local resolved = (cp and cp:GetColor()) or manager.cache.baseColor
	local newAlpha = ctx.alpha
	if math.abs(state.alpha - newAlpha) >= ALPHA_EPSILON or state._lastGlow ~= resolved then
		state.alpha = newAlpha
		applyStyle(state, resolved)
	end

	setShown(state, true)
end)

return {
	id = "adornChams",
	setup = setup,
	createState = createState,
	update = update,
	destroyState = destroyState,
	setActive = setActive,
	deactivate = deactivate,
} :: EspElement.EspElement<State, Settings>
