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
		getVelocity = function(): Vector3
			local hrp = peek(basePlayer.hrp) :: BasePart?
			return hrp and hrp.AssemblyLinearVelocity or Vector3.zero
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
local addedConn: any = nil
local removingConn: any = nil
local lastCharacterByPlayer: { [Player]: Model? } = {}

local function attachPlayer(basePlayer: any): ()
	local player = basePlayer:GetPlayer() :: Player
	if perPlayerUnsubs[player] then
		return
	end
	local unsubs: { () -> () } = {}

	local lastAlive = peek(basePlayer.alive)
	table.insert(
		unsubs,
		sub(basePlayer.alive, function(alive: boolean): ()
			if alive == lastAlive then
				return
			end
			lastAlive = alive
			if alive then
				signals.onSpawn:Fire(player)
			else
				signals.onDeath:Fire(player)
			end
		end)
	)

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

local playerApi = {
	signals = signals,
	GetAll = getAll,
	Get = getHandle,
	_bumpListeners = bumpListeners,
}

return playerApi
