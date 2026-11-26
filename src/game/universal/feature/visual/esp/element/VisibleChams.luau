local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")

local peek = Charm.peek
local sub = Charm.subscribe

local MATERIALS: { string } = {
	"ForceField",
	"Neon",
}

local DEFAULT_COLOR = Color3.fromRGB(195, 95, 95)
local DEFAULT_MATERIAL = "Neon"
local ALPHA_EPSILON = 0.005
local HIDDEN_TRANSPARENCY = 1

type SpectateInstance = {
	Player: Player?,
	PerspectiveState: string?,
	TransparencyState: boolean?,
}

type Config = {
	isSpectating: () -> boolean,
	spectatePlayer: Charm.Atom<Player?>?,
	spectateInstance: Charm.Atom<SpectateInstance?>?,
	isSpectatingAtom: Charm.Atom<boolean>?,
	excludedAncestors: { [string]: true },
}

local config: Config = {
	isSpectating = function(): boolean
		return false
	end,
	spectatePlayer = nil,
	spectateInstance = nil,
	isSpectatingAtom = nil,
	excludedAncestors = {},
}

type PatchEntry = {
	material: Enum.Material,
	color: Color3,
	transparency: number,
	textureId: string,
	mesh: SpecialMesh?,
	meshTextureId: string,
	meshVertexColor: Vector3,
	overlays: { Instance },
	materialConn: RBXScriptConnection?,
	colorConn: RBXScriptConnection?,
}

type ClothingEntry = {
	template: string,
	propName: string,
	conn: RBXScriptConnection?,
}

type State = {
	_player: Player,
	patched: { [BasePart]: PatchEntry },
	hiddenClothing: { [Instance]: ClothingEntry },
	characterJanitor: Janitor.Janitor?,
	isApplied: boolean,
	lastAlpha: number,
	_color: Color3,
	_transparency: number,
	spectateFpHidden: boolean,
	_alive: boolean,
	_aliveUnsub: () -> (),
	_character: Model?,
	_playerUnsub: () -> (),
}

type Settings = {
	enabled: any,
	color: any,
	material: any,
	cache: {
		enabled: boolean,
		material: string,
		color: Color3,
		transparency: number,
	},
}

type DeactivateOpts = {
	skipTransparency: boolean?,
	forceHiddenTransparency: boolean?,
}

local pool: { [State]: true } = {}
local masterActive = false
local lastSpectatePlayer: Player? = nil
local _settings: Settings? = nil

local function isClothing(inst: Instance): boolean
	local className = inst.ClassName
	if className == "Shirt" or className == "Pants" then
		return true
	end
	return false
end

local function isExcludedPart(part: BasePart): boolean
	local excluded = config.excludedAncestors
	if not next(excluded) then
		return false
	end
	local current = part.Parent
	while current do
		if excluded[current.Name] then
			return true
		end
		current = current.Parent
	end
	return false
end

local function shouldPatchPart(part: Instance): boolean
	if not part:IsA("BasePart") then
		return false
	end
	local base = part :: BasePart
	if base.Transparency >= HIDDEN_TRANSPARENCY then
		return false
	end
	return not isExcludedPart(base)
end

local function isSpectateFpHiddenPlayer(player: Player): boolean
	if not config.isSpectating() then
		return false
	end
	local instAtom = config.spectateInstance
	if not instAtom then
		return false
	end
	local inst = peek(instAtom)
	if not inst or inst.Player ~= player then
		return false
	end
	if inst.PerspectiveState ~= "First-Person" then
		return false
	end
	return inst.TransparencyState == true
end

local function fadedTransparency(base: number, alpha: number): number
	return 1 - (1 - base) * alpha
end

local resolveAppearanceAlpha = LPH_NO_VIRTUALIZE(function(ctx: EspElement.EspCtx): number
	if ctx.deathFading then
		return ctx.alpha
	end
	return 1
end)

local function syncCache(settings: Settings): ()
	settings.cache.enabled = peek(settings.enabled._state) :: boolean
	settings.cache.material = peek(settings.material._state) :: string
	local snap = settings.color:GetSnapshot()
	settings.cache.color = snap.color
	settings.cache.transparency = snap.transparency
end

local resolveMaterial = LPH_NO_VIRTUALIZE(function(settings: Settings): Enum.Material
	local name = settings.cache.material or DEFAULT_MATERIAL
	return Enum.Material[name] or Enum.Material.Neon
end)

local function hideClothing(state: State, inst: Instance): ()
	if state.hiddenClothing[inst] then
		return
	end
	local propName: string
	local template: string
	if inst.ClassName == "Shirt" then
		propName = "ShirtTemplate"
		template = (inst :: any).ShirtTemplate
		;(inst :: any).ShirtTemplate = ""
	else
		propName = "PantsTemplate"
		template = (inst :: any).PantsTemplate
		;(inst :: any).PantsTemplate = ""
	end

	local conn = inst:GetPropertyChangedSignal(propName):Connect(function(): ()
		if not state.hiddenClothing[inst] then
			return
		end
		if (inst :: any)[propName] ~= "" then
			(inst :: any)[propName] = ""
		end
	end)

	state.hiddenClothing[inst] = { template = template, propName = propName, conn = conn }
end

local function restoreClothing(state: State, inst: Instance): ()
	local entry = state.hiddenClothing[inst]
	if not entry then
		return
	end
	state.hiddenClothing[inst] = nil
	if entry.conn then
		entry.conn:Disconnect()
	end
	(inst :: any)[entry.propName] = entry.template
end

local function releaseClothing(state: State, inst: Instance): ()
	local entry = state.hiddenClothing[inst]
	if not entry then
		return
	end
	state.hiddenClothing[inst] = nil
	if entry.conn then
		entry.conn:Disconnect()
	end
end

local function restoreAllClothing(state: State): ()
	for inst in next, state.hiddenClothing do
		restoreClothing(state, inst)
	end
end

local function stripTextures(part: any, entry: PatchEntry): ()
	if part.ClassName == "MeshPart" then
		entry.textureId = part.TextureID
		part.TextureID = ""
	end

	for _, child in next, part:GetChildren() do
		local className = child.ClassName
		if className == "SpecialMesh" then
			local mesh = child :: SpecialMesh
			entry.mesh = mesh
			entry.meshTextureId = mesh.TextureId
			entry.meshVertexColor = mesh.VertexColor
			mesh.TextureId = ""
			mesh.VertexColor = Vector3.one
		elseif className == "SurfaceAppearance" or className == "Texture" or className == "Decal" then
			entry.overlays[#entry.overlays + 1] = child
			child.Parent = nil
		end
	end
end

local function restoreTransparency(state: State, part: BasePart, entry: PatchEntry, opts: DeactivateOpts?): ()
	if opts and opts.skipTransparency then
		return
	end
	local value = entry.transparency
	if opts and opts.forceHiddenTransparency then
		value = HIDDEN_TRANSPARENCY
	elseif state.spectateFpHidden or isSpectateFpHiddenPlayer(state._player) then
		value = HIDDEN_TRANSPARENCY
	end
	part.Transparency = value
end

local function restorePart(state: State, part: any, opts: DeactivateOpts?): ()
	local entry = state.patched[part]
	if not entry then
		return
	end

	state.patched[part] = nil

	if entry.materialConn then
		entry.materialConn:Disconnect()
	end
	if entry.colorConn then
		entry.colorConn:Disconnect()
	end

	if part.Parent == nil and not part:IsDescendantOf(game) then
		for _, overlay in next, entry.overlays do
			overlay:Destroy()
		end
		return
	end

	part.Material = entry.material
	part.Color = entry.color
	if part.ClassName == "MeshPart" then
		part.TextureID = entry.textureId
	end

	if entry.mesh then
		entry.mesh.TextureId = entry.meshTextureId
		entry.mesh.VertexColor = entry.meshVertexColor
	end

	restoreTransparency(state, part, entry, opts)

	for _, overlay in next, entry.overlays do
		overlay.Parent = part
	end
end

local function restoreAll(state: State, opts: DeactivateOpts?): ()
	local parts: { BasePart } = {}
	for part in next, state.patched do
		parts[#parts + 1] = part
	end
	for i = 1, #parts do
		restorePart(state, parts[i], opts)
	end
	restoreAllClothing(state)
	state.isApplied = false
	state.lastAlpha = 0
	if not (opts and opts.skipTransparency) then
		state.spectateFpHidden = false
	end
end

local function bindPartProperties(state: State, part: BasePart, entry: PatchEntry): ()
	entry.materialConn = part:GetPropertyChangedSignal("Material"):Connect(function(): ()
		if not state.patched[part] or not state.isApplied or not _settings then
			return
		end
		local material = resolveMaterial(_settings)
		if part.Material ~= material then
			part.Material = material
		end
	end)

	entry.colorConn = part:GetPropertyChangedSignal("Color"):Connect(function(): ()
		if not state.patched[part] or not state.isApplied then
			return
		end
		local color = state._color
		if part.Color ~= color then
			part.Color = color
		end
	end)
end

local function applyPart(state: State, part: BasePart): ()
	if state.patched[part] or not shouldPatchPart(part) then
		return
	end

	local entry: PatchEntry = {
		material = part.Material,
		color = part.Color,
		transparency = part.Transparency,
		textureId = "",
		mesh = nil,
		meshTextureId = "",
		meshVertexColor = Vector3.one,
		overlays = {},
		materialConn = nil,
		colorConn = nil,
	}

	stripTextures(part, entry)
	state.patched[part] = entry
	bindPartProperties(state, part, entry)
end

local refreshAppearance = LPH_NO_VIRTUALIZE(function(state: State, settings: Settings, appearanceAlpha: number): ()
	local material = resolveMaterial(settings)
	local color = state._color
	local transparency = fadedTransparency(state._transparency, appearanceAlpha)

	for part in next, state.patched do
		part.Material = material
		part.Color = color
		part.Transparency = transparency
	end
end)

local function hideClothingInModel(state: State, model: Model): ()
	for _, desc in next, model:QueryDescendants("Instance") do
		if isClothing(desc) then
			hideClothing(state, desc)
		end
	end
end

local function patchModel(state: State, model: Model): ()
	for _, desc in next, model:QueryDescendants("Instance") do
		if shouldPatchPart(desc) then
			applyPart(state, desc :: BasePart)
		end
	end
end

local function bindCharacter(state: State, character: Model): ()
	if state.characterJanitor then
		state.characterJanitor:Destroy()
		state.characterJanitor = nil
	end

	local janitor = Janitor.new()
	state.characterJanitor = janitor

	hideClothingInModel(state, character)
	patchModel(state, character)

	janitor:Add(
		character.DescendantAdded:Connect(function(desc: Instance): ()
			if not state.isApplied then
				return
			end
			if isClothing(desc) then
				hideClothing(state, desc)
			elseif shouldPatchPart(desc) then
				applyPart(state, desc :: BasePart)
			end
		end),
		"Disconnect"
	)

	janitor:Add(
		character.DescendantRemoving:Connect(function(desc: Instance): ()
			if isClothing(desc) then
				releaseClothing(state, desc)
			elseif desc:IsA("BasePart") then
				restorePart(state, desc :: BasePart)
			end
		end),
		"Disconnect"
	)
end

local function deactivate(state: State, opts: DeactivateOpts?): ()
	restoreAll(state, opts)
	if state.characterJanitor then
		state.characterJanitor:Destroy()
		state.characterJanitor = nil
	end
end

local function deactivateAll(opts: DeactivateOpts?): ()
	for st in next, pool do
		deactivate(st, opts)
	end
end

local function onSpectateTargetChanged(nextPlayer: Player?): ()
	if lastSpectatePlayer and lastSpectatePlayer ~= nextPlayer then
		for st in next, pool do
			if st._player == lastSpectatePlayer then
				st.spectateFpHidden = true
				if st.isApplied then
					deactivate(st, { forceHiddenTransparency = true })
				end
			end
		end
	end
	lastSpectatePlayer = nextPlayer
end

local activate = LPH_NO_VIRTUALIZE(function(state: State, settings: Settings, ctx: EspElement.EspCtx): ()
	local character = state._character
	if not character then
		deactivate(state)
		return
	end

	if isSpectateFpHiddenPlayer(state._player) then
		if state.isApplied then
			state.spectateFpHidden = true
			deactivate(state, { forceHiddenTransparency = true })
		end
		return
	end

	if not state.isApplied then
		bindCharacter(state, character)
		state.isApplied = true
	end

	local appearanceAlpha = resolveAppearanceAlpha(ctx)
	if math.abs(state.lastAlpha - appearanceAlpha) < ALPHA_EPSILON and state.isApplied then
		return
	end

	state.lastAlpha = appearanceAlpha
	refreshAppearance(state, settings, appearanceAlpha)
end)

local function refreshAll(settings: Settings): ()
	syncCache(settings)
	for st in next, pool do
		if st.isApplied and not isSpectateFpHiddenPlayer(st._player) then
			refreshAppearance(st, settings, st.lastAlpha)
		end
	end
end

local function setup(link: gameUi.Linker): Settings
	local chamsToggle = link:Toggle("visibleChams", "Visible Chams", false):SetTip({
		title = "Visible Chams",
		body = "Recolors enemy player models through walls.",
	})
	link:OnKey("visibleChams"):Extra(chamsToggle, "color", "Colorpicker", "Color", DEFAULT_COLOR, 0):SetTip({
		title = "Color",
		body = "Cham color and transparency.",
	})
	espStateColors.Register({ id = "chams", label = "Chams", default = DEFAULT_COLOR, transparency = 0 })
	link:Extra(chamsToggle, "visibleChamsSettings", "Submenu", "Visible Chams")
	local settingsLink = link:OnKey("visibleChamsSettings")

	settingsLink:Dropdown("material", "Material", MATERIALS, DEFAULT_MATERIAL):SetTip({
		title = "Material",
		body = "Surface style used on enemy chams.",
	})

	local settings: Settings = {
		enabled = link:Get("visibleChams"),
		color = link:Get("visibleChams.color"),
		material = link:Get("visibleChamsSettings.material"),
		cache = {
			enabled = peek(link:Get("visibleChams")._state) :: boolean,
			material = DEFAULT_MATERIAL,
			color = DEFAULT_COLOR,
			transparency = 0,
		},
	}

	syncCache(settings)
	_settings = settings

	sub(settings.enabled._state, function(): ()
		syncCache(settings)
		if not settings.cache.enabled or not masterActive then
			deactivateAll()
		end
	end)

	sub(settings.material._state, function(): ()
		refreshAll(settings)
	end)

	settings.color:OnColorChange(function(): ()
		refreshAll(settings)
	end)
	settings.color:OnTransparencyChange(function(): ()
		refreshAll(settings)
	end)

	local spectatePlayer = config.spectatePlayer
	if spectatePlayer then
		sub(spectatePlayer, onSpectateTargetChanged)
		onSpectateTargetChanged(peek(spectatePlayer))
	end

	local isSpectatingAtom = config.isSpectatingAtom
	if isSpectatingAtom then
		sub(isSpectatingAtom, function(spectating: boolean): ()
			if not spectating then
				deactivateAll()
			end
		end)
	end

	return settings
end

local function createState(player: Player, basePlayer: any, _settings: Settings): State
	local state: State = {
		_player = player,
		patched = {},
		hiddenClothing = {},
		characterJanitor = nil,
		isApplied = false,
		lastAlpha = 0,
		_color = DEFAULT_COLOR,
		_transparency = 0,
		spectateFpHidden = false,
		_alive = false,
		_aliveUnsub = function() end,
		_character = nil,
		_playerUnsub = function() end,
	}

	if not basePlayer then
		state._character = nil
	else
		state._alive = peek(basePlayer.alive) :: boolean
		state._character = peek(basePlayer.character)
		state._aliveUnsub = sub(basePlayer.alive, function(alive: boolean): ()
			state._alive = alive
			if not alive then
				deactivate(state)
			end
		end)
		state._playerUnsub = sub(basePlayer.character, function(character: Model?): ()
			deactivate(state)
			state._character = character
		end)
	end

	pool[state] = true
	return state
end

local function destroyState(state: State, _settings: Settings): ()
	deactivate(state)
	state._aliveUnsub()
	state._playerUnsub()
	pool[state] = nil
end

local function setActive(_settings: Settings, active: boolean): ()
	masterActive = active
	if not active then
		deactivateAll()
	end
end

local update = LPH_NO_VIRTUALIZE(function(state: State, ctx: EspElement.EspCtx, settings: Settings): ()
	if not masterActive or not settings.cache.enabled then
		if state.isApplied then
			deactivate(state, { skipTransparency = config.isSpectating() })
		end
		return
	end

	if isSpectateFpHiddenPlayer(state._player) then
		if state.isApplied then
			state.spectateFpHidden = true
			deactivate(state, { forceHiddenTransparency = true })
		end
		return
	end

	if not state._alive then
		if state.isApplied then
			deactivate(state)
		end
		return
	end

	if not ctx.shouldShow then
		if state.isApplied then
			deactivate(state, { skipTransparency = config.isSpectating() })
		end
		return
	end

	if not ctx.visible then
		return
	end

	local bucket = ctx.stateBucket
	local cp = bucket and bucket.chams
	local color, transparency
	if cp then
		color = cp:GetColor()
		transparency = cp:GetTransparency()
	else
		color = settings.cache.color
		transparency = settings.cache.transparency
	end
	if state._color ~= color or state._transparency ~= transparency then
		state._color = color
		state._transparency = transparency
		state.lastAlpha = -1
	end

	activate(state, settings, ctx)
end)

export type ConfigureOpts = {
	isSpectating: (() -> boolean)?,
	spectatePlayer: Charm.Atom<Player?>?,
	spectateInstance: Charm.Atom<SpectateInstance?>?,
	isSpectatingAtom: Charm.Atom<boolean>?,
	excludedAncestors: { [string]: true }?,
}

local function Configure(opts: ConfigureOpts): ()
	if opts.isSpectating ~= nil then
		config.isSpectating = opts.isSpectating
	end
	if opts.spectatePlayer ~= nil then
		config.spectatePlayer = opts.spectatePlayer
	end
	if opts.spectateInstance ~= nil then
		config.spectateInstance = opts.spectateInstance
	end
	if opts.isSpectatingAtom ~= nil then
		config.isSpectatingAtom = opts.isSpectatingAtom
	end
	if opts.excludedAncestors ~= nil then
		config.excludedAncestors = opts.excludedAncestors
	end
end

return {
	id = "visibleChams",
	setup = setup,
	createState = createState,
	update = update,
	destroyState = destroyState,
	setActive = setActive,
	Configure = Configure,
}
