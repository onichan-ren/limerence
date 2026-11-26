local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local PlayerController = require("@feature/player/PlayerController")
local playerState = require("@feature/record/module/playerState")

local peek = Charm.peek
local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer

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
	getVelocity: () -> Vector3,
	getWeapon: () -> string?,
	getItemName: () -> string?,
	getAmmo: () -> number?,
	getMaxAmmo: () -> number?,
	isReloading: () -> boolean,
	isBlind: () -> boolean,
	isScoped: () -> boolean,
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
	onAmmoChanged = Signal.new(),
	onReloadingChanged = Signal.new(),
	onBlindChanged = Signal.new(),
	onScopedChanged = Signal.new(),
	onHealingChanged = Signal.new(),
}

local handles: { [Player]: PlayerHandle } = {}

PlayerController.playerRemoving:Connect(function(basePlayer: any): ()
	handles[basePlayer:GetPlayer()] = nil
end)

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
			return peek(basePlayer.parts).Humanoid :: Humanoid?
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
			return nil
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
		getVelocity = function(): Vector3
			return basePlayer:GetVelocity()
		end,
		getWeapon = function(): string?
			local name = peek(basePlayer.weapon)
			return name ~= "" and name or nil
		end,
		getItemName = function(): string?
			local name = peek(basePlayer.weapon)
			return name ~= "" and name or nil
		end,
		getAmmo = function(): number?
			return peek(basePlayer.ammo)
		end,
		getMaxAmmo = function(): number?
			return peek(basePlayer.ammoCapacity)
		end,
		isReloading = function(): boolean
			return peek(basePlayer.isReloading)
		end,
		isBlind = function(): boolean
			return false
		end,
		isScoped = function(): boolean
			return false
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

	local lastWeapon = peek(basePlayer.weapon)
	table.insert(
		unsubs,
		sub(basePlayer.weapon, function(weapon: string): ()
			if weapon == lastWeapon then
				return
			end
			lastWeapon = weapon
			signals.onWeaponChanged:Fire(player, weapon ~= "" and weapon or nil)
		end)
	)

	table.insert(
		unsubs,
		sub(basePlayer.ammo, function(ammo: number?): ()
			signals.onAmmoChanged:Fire(player, ammo, peek(basePlayer.ammoCapacity))
		end)
	)

	watchBool(unsubs, basePlayer.isReloading, function(v: boolean): ()
		signals.onReloadingChanged:Fire(player, v)
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
