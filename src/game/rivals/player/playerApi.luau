local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local PlayerController = require("@feature/player/PlayerController")
local RivalsPlayer = require("@game/rivals/player/RivalsPlayer")
local playerState = require("@feature/record/module/playerState")

local peek = Charm.peek
local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer

export type EquippedItem = RivalsPlayer.EquippedItem

export type PlayerHandle = {
	getPlayer: () -> Player,
	getCharacter: () -> Model?,
	getHumanoid: () -> Humanoid?,
	getRootPart: () -> BasePart?,
	getParts: () -> { [string]: Instance },
	isAlive: () -> boolean,
	getTeam: () -> string?,
	getHealth: () -> number,
	getMaxHealth: () -> number,
	getHealthFraction: () -> number,
	getPosition: () -> Vector3?,
	getCFrame: () -> CFrame?,
	getWeapon: () -> EquippedItem?,
	getItemName: () -> string?,
	getEnvironmentId: () -> string,
	getItems: () -> { string },
	getVelocity: () -> Vector3,
	getLevel: () -> number,
	getWinStreak: () -> number,
	getDisplayElo: () -> number,
	isInDuel: () -> boolean,
	isSpectating: () -> boolean,
	isCrouching: () -> boolean,
	isSliding: () -> boolean,
	isFirstPerson: () -> boolean,
	isFrozen: () -> boolean,
	isInvincible: () -> boolean,
	isHidden: () -> boolean,
	isReloading: () -> boolean,
	isBlind: () -> boolean,
	isScoped: () -> boolean,
	isBlocking: () -> boolean,
	isDeflecting: () -> boolean,
	isHealing: () -> boolean,
	getState: () -> string?,
}

local signals = {
	onPlayerAdded = Signal.new(),
	onPlayerRemoving = Signal.new(),
	onCharacterAdded = Signal.new(),
	onCharacterRemoving = Signal.new(),
	onSpawn = Signal.new(),
	onDeath = Signal.new(),
	onTeamChanged = Signal.new(),
	onHealthChanged = Signal.new(),
	onWeaponChanged = Signal.new(),
	onReloadingChanged = Signal.new(),
	onScopedChanged = Signal.new(),
	onBlindChanged = Signal.new(),
	onEnvironmentChanged = Signal.new(),
	onFrozenChanged = Signal.new(),
	onInvincibleChanged = Signal.new(),
	onDuelChanged = Signal.new(),
	onBlockingChanged = Signal.new(),
	onDeflectingChanged = Signal.new(),
	onHealingChanged = Signal.new(),
}

local handles: { [Player]: PlayerHandle } = {}

local function getBasePlayer(player: Player): any?
	if player == LocalPlayer then
		return nil
	end
	return PlayerController.Get(player)
end

local function buildHandle(basePlayer: any): PlayerHandle
	local player = basePlayer:GetPlayer() :: Player
	return {
		getPlayer = function(): Player
			return player
		end,
		getCharacter = function(): Model?
			return peek(basePlayer.character)
		end,
		getHumanoid = function(): Humanoid?
			return peek(basePlayer.humanoid)
		end,
		getRootPart = function(): BasePart?
			return peek(basePlayer.hrp)
		end,
		getParts = function(): { [string]: Instance }
			local snap = peek(basePlayer.parts)
			local out: { [string]: Instance } = {}
			for k, v in next, snap do
				out[k] = v
			end
			return out
		end,
		isAlive = function(): boolean
			return peek(basePlayer.alive)
		end,
		getTeam = function(): string?
			return peek(basePlayer.team)
		end,
		getHealth = function(): number
			return peek(basePlayer.health)
		end,
		getMaxHealth = function(): number
			return peek(basePlayer.maxHealth)
		end,
		getHealthFraction = function(): number
			local maxH = peek(basePlayer.maxHealth)
			if maxH <= 0 then
				return 0
			end
			return math.clamp(peek(basePlayer.health) / maxH, 0, 1)
		end,
		getPosition = function(): Vector3?
			local hrp = peek(basePlayer.hrp) :: BasePart?
			return hrp and hrp.Position or nil
		end,
		getCFrame = function(): CFrame?
			local hrp = peek(basePlayer.hrp) :: BasePart?
			return hrp and hrp.CFrame or nil
		end,
		getWeapon = function(): EquippedItem?
			return peek(basePlayer.currentEquipped)
		end,
		getItemName = function(): string?
			local item = peek(basePlayer.currentEquipped)
			return item and item.Name or nil
		end,
		getEnvironmentId = function(): string
			return peek(basePlayer.environmentId)
		end,
		getItems = function(): { string }
			return peek(basePlayer.items)
		end,
		getVelocity = function(): Vector3
			return peek(basePlayer.velocity)
		end,
		getLevel = function(): number
			return peek(basePlayer.level)
		end,
		getWinStreak = function(): number
			return peek(basePlayer.winStreak)
		end,
		getDisplayElo = function(): number
			return peek(basePlayer.displayElo)
		end,
		isInDuel = function(): boolean
			return peek(basePlayer.isInDuel)
		end,
		isSpectating = function(): boolean
			return peek(basePlayer.isSpectating)
		end,
		isCrouching = function(): boolean
			return peek(basePlayer.isCrouching)
		end,
		isSliding = function(): boolean
			return peek(basePlayer.isSliding)
		end,
		isFirstPerson = function(): boolean
			return peek(basePlayer.isFirstPerson)
		end,
		isFrozen = function(): boolean
			return peek(basePlayer.isFrozen)
		end,
		isInvincible = function(): boolean
			return peek(basePlayer.isInvincible)
		end,
		isHidden = function(): boolean
			return peek(basePlayer.isHidden)
		end,
		isReloading = function(): boolean
			return peek(basePlayer.isReloading)
		end,
		isBlind = function(): boolean
			return peek(basePlayer.isBlind)
		end,
		isScoped = function(): boolean
			return peek(basePlayer.isScoped)
		end,
		isBlocking = function(): boolean
			return peek(basePlayer.isBlocking)
		end,
		isDeflecting = function(): boolean
			return peek(basePlayer.isDeflecting)
		end,
		isHealing = function(): boolean
			return peek(basePlayer.isHealing)
		end,
		getState = function(): string?
			return playerState.GetState(player.UserId)
		end,
	}
end

local function getHandle(player: Player): PlayerHandle?
	if not player then
		return nil
	end
	local cached = handles[player]
	if cached then
		return cached
	end
	local basePlayer = getBasePlayer(player)
	if not basePlayer then
		return nil
	end
	local handle = buildHandle(basePlayer)
	handles[player] = handle
	return handle
end

local activeListeners = 0
local perPlayerUnsubs: { [Player]: { () -> () } } = {}
local addedConn: RBXScriptConnection? = nil
local removingConn: RBXScriptConnection? = nil
local lastCharacterByPlayer: { [Player]: Model? } = {}

local function watchBool(unsubs: { () -> () }, atom: any, fire: (boolean) -> ()): ()
	local last = peek(atom)
	table.insert(
		unsubs,
		sub(atom, function(value: boolean): ()
			if value == last then
				return
			end
			last = value
			fire(value)
		end)
	)
end

local function attachPlayer(basePlayer: any): ()
	local player = basePlayer:GetPlayer() :: Player
	if perPlayerUnsubs[player] then
		return
	end
	local unsubs: { () -> () } = {}

	watchBool(unsubs, basePlayer.alive, function(alive: boolean): ()
		if alive then
			signals.onSpawn:Fire(player)
		else
			signals.onDeath:Fire(player)
		end
	end)

	local lastChar = peek(basePlayer.character) :: Model?
	lastCharacterByPlayer[player] = lastChar
	table.insert(
		unsubs,
		sub(basePlayer.character, function(character: Model?): ()
			local prev = lastCharacterByPlayer[player]
			if character == prev then
				return
			end
			if prev then
				signals.onCharacterRemoving:Fire(player, prev)
			end
			lastCharacterByPlayer[player] = character
			if character then
				signals.onCharacterAdded:Fire(player, character)
			end
		end)
	)

	local lastTeam = peek(basePlayer.team)
	table.insert(
		unsubs,
		sub(basePlayer.team, function(team: any): ()
			if team == lastTeam then
				return
			end
			lastTeam = team
			signals.onTeamChanged:Fire(player, team)
		end)
	)

	table.insert(
		unsubs,
		sub(basePlayer.health, function(health: number): ()
			signals.onHealthChanged:Fire(player, health, peek(basePlayer.maxHealth))
		end)
	)
	table.insert(
		unsubs,
		sub(basePlayer.maxHealth, function(maxHealth: number): ()
			signals.onHealthChanged:Fire(player, peek(basePlayer.health), maxHealth)
		end)
	)

	local lastWeapon = peek(basePlayer.currentEquipped) :: any
	table.insert(
		unsubs,
		sub(basePlayer.currentEquipped, function(weapon: any): ()
			if weapon == lastWeapon then
				return
			end
			lastWeapon = weapon
			signals.onWeaponChanged:Fire(player, weapon)
		end)
	)

	local lastEnv = peek(basePlayer.environmentId)
	table.insert(
		unsubs,
		sub(basePlayer.environmentId, function(env: string): ()
			if env == lastEnv then
				return
			end
			lastEnv = env
			signals.onEnvironmentChanged:Fire(player, env)
		end)
	)

	watchBool(unsubs, basePlayer.isReloading, function(v: boolean): ()
		signals.onReloadingChanged:Fire(player, v)
	end)
	watchBool(unsubs, basePlayer.isScoped, function(v: boolean): ()
		signals.onScopedChanged:Fire(player, v)
	end)
	watchBool(unsubs, basePlayer.isBlind, function(v: boolean): ()
		signals.onBlindChanged:Fire(player, v)
	end)
	watchBool(unsubs, basePlayer.isFrozen, function(v: boolean): ()
		signals.onFrozenChanged:Fire(player, v)
	end)
	watchBool(unsubs, basePlayer.isInvincible, function(v: boolean): ()
		signals.onInvincibleChanged:Fire(player, v)
	end)
	watchBool(unsubs, basePlayer.isInDuel, function(v: boolean): ()
		signals.onDuelChanged:Fire(player, v)
	end)
	watchBool(unsubs, basePlayer.isBlocking, function(v: boolean): ()
		signals.onBlockingChanged:Fire(player, v)
	end)
	watchBool(unsubs, basePlayer.isDeflecting, function(v: boolean): ()
		signals.onDeflectingChanged:Fire(player, v)
	end)
	watchBool(unsubs, basePlayer.isHealing, function(v: boolean): ()
		signals.onHealingChanged:Fire(player, v)
	end)

	perPlayerUnsubs[player] = unsubs
end

local function detachPlayer(player: Player): ()
	local unsubs = perPlayerUnsubs[player]
	if unsubs then
		for _, u in next, unsubs do
			u()
		end
		perPlayerUnsubs[player] = nil
	end
	lastCharacterByPlayer[player] = nil
end

local function activate(): ()
	if addedConn then
		return
	end
	for _, basePlayer in next, PlayerController.GetAll() do
		attachPlayer(basePlayer)
	end
	addedConn = PlayerController.playerAdded:Connect(function(basePlayer: any): ()
		local player = basePlayer:GetPlayer() :: Player
		signals.onPlayerAdded:Fire(player)
		attachPlayer(basePlayer)
	end)
	removingConn = PlayerController.playerRemoving:Connect(function(basePlayer: any): ()
		local player = basePlayer:GetPlayer() :: Player
		detachPlayer(player)
		handles[player] = nil
		signals.onPlayerRemoving:Fire(player)
	end)
end

local function deactivate(): ()
	if not addedConn then
		return
	end
	addedConn:Disconnect()
	addedConn = nil
	if removingConn then
		removingConn:Disconnect()
		removingConn = nil
	end
	for player in next, perPlayerUnsubs do
		detachPlayer(player)
	end
end

local function bumpListeners(delta: number): ()
	activeListeners += delta
	if activeListeners < 0 then
		activeListeners = 0
	end
	if activeListeners == 0 then
		deactivate()
	elseif not addedConn then
		activate()
	end
end

local function getAll(): { Player }
	local out: { Player } = {}
	for player in next, PlayerController.GetAll() do
		out[#out + 1] = player
	end
	return out
end

local function clearHandleCache(player: Player): ()
	handles[player] = nil
end

local playerApi = {
	signals = signals,
	GetAll = getAll,
	Get = getHandle,
	_bumpListeners = bumpListeners,
	_clearHandle = clearHandleCache,
}

return playerApi
