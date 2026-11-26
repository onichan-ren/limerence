local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local PlayerController = require("@feature/player/PlayerController")
local BloxstrikePlayer = require("@game/bloxstrike/player/BloxstrikePlayer")
local playerState = require("@feature/record/module/playerState")

local peek = Charm.peek
local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer

export type ArmorState = BloxstrikePlayer.ArmorState
export type PlayerItem = BloxstrikePlayer.PlayerItem

export type PlayerHandle = {
	getPlayer: () -> Player,
	getCharacter: () -> Model?,
	getHumanoid: () -> Humanoid?,
	getRootPart: () -> BasePart?,
	getParts: () -> { [string]: Instance },
	isAlive: () -> boolean,
	getTeam: () -> any,
	getHealth: () -> number,
	getMaxHealth: () -> number,
	getHealthFraction: () -> number,
	getPosition: () -> Vector3?,
	getCFrame: () -> CFrame?,
	getWeapon: () -> PlayerItem?,
	getItemName: () -> string?,
	getAmmo: () -> number?,
	getMaxAmmo: () -> number?,
	isPlanting: () -> boolean,
	isDefusing: () -> boolean,
	hasC4: () -> boolean,
	getArmor: () -> ArmorState,
	hasArmor: () -> boolean,
	hasHelmet: () -> boolean,
	isReloading: () -> boolean,
	isBlind: () -> boolean,
	isScoped: () -> boolean,
	isRescuingHostage: () -> boolean,
	isCarryingHostage: () -> boolean,
	getMoney: () -> number,
	hasDefuseKit: () -> boolean,
	isInvincible: () -> boolean,
	isCulled: () -> boolean,
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
	onPlantingChanged = Signal.new(),
	onDefusingChanged = Signal.new(),
	onC4Changed = Signal.new(),
	onArmorChanged = Signal.new(),
	onReloadingChanged = Signal.new(),
	onBlindChanged = Signal.new(),
	onScopedChanged = Signal.new(),
	onRescuingChanged = Signal.new(),
	onCarryingChanged = Signal.new(),
	onMoneyChanged = Signal.new(),
	onInvincibleChanged = Signal.new(),
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
		getTeam = function(): any
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
		getWeapon = function(): PlayerItem?
			return peek(basePlayer.currentEquipped)
		end,
		getItemName = function(): string?
			local item = peek(basePlayer.currentEquipped)
			return item and item.Name or nil
		end,
		getAmmo = function(): number?
			local item = peek(basePlayer.currentEquipped)
			return item and tonumber(item.Rounds) or nil
		end,
		getMaxAmmo = function(): number?
			local item = peek(basePlayer.currentEquipped)
			return item and tonumber(item.Capacity) or nil
		end,
		isPlanting = function(): boolean
			return peek(basePlayer.isPlanting)
		end,
		isDefusing = function(): boolean
			return peek(basePlayer.isDefusing)
		end,
		hasC4 = function(): boolean
			return peek(basePlayer.hasC4)
		end,
		getArmor = function(): ArmorState
			return peek(basePlayer.armor)
		end,
		hasArmor = function(): boolean
			return peek(basePlayer.armor).kevlar
		end,
		hasHelmet = function(): boolean
			return peek(basePlayer.armor).helmet
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
		isRescuingHostage = function(): boolean
			return peek(basePlayer.isRescuing)
		end,
		isCarryingHostage = function(): boolean
			return peek(basePlayer.isCarrying)
		end,
		getMoney = function(): number
			return tonumber(player:GetAttribute("Money")) or 0
		end,
		hasDefuseKit = function(): boolean
			return peek(basePlayer.hasDefuseKit)
		end,
		isInvincible = function(): boolean
			return peek(basePlayer.invincible)
		end,
		isCulled = function(): boolean
			return peek(basePlayer.culled)
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

	local lastPlanting = peek(basePlayer.isPlanting)
	table.insert(
		unsubs,
		sub(basePlayer.isPlanting, function(planting: boolean): ()
			if planting == lastPlanting then
				return
			end
			lastPlanting = planting
			signals.onPlantingChanged:Fire(player, planting)
		end)
	)

	local lastDefusing = peek(basePlayer.isDefusing)
	table.insert(
		unsubs,
		sub(basePlayer.isDefusing, function(defusing: boolean): ()
			if defusing == lastDefusing then
				return
			end
			lastDefusing = defusing
			signals.onDefusingChanged:Fire(player, defusing)
		end)
	)

	local lastHasC4 = peek(basePlayer.hasC4)
	table.insert(
		unsubs,
		sub(basePlayer.hasC4, function(hasC4: boolean): ()
			if hasC4 == lastHasC4 then
				return
			end
			lastHasC4 = hasC4
			signals.onC4Changed:Fire(player, hasC4)
		end)
	)

	table.insert(
		unsubs,
		sub(basePlayer.armor, function(armor: ArmorState): ()
			signals.onArmorChanged:Fire(player, armor)
		end)
	)

	local lastReloading = peek(basePlayer.isReloading)
	table.insert(
		unsubs,
		sub(basePlayer.isReloading, function(reloading: boolean): ()
			if reloading == lastReloading then
				return
			end
			lastReloading = reloading
			signals.onReloadingChanged:Fire(player, reloading)
		end)
	)

	local lastBlind = peek(basePlayer.isBlind)
	table.insert(
		unsubs,
		sub(basePlayer.isBlind, function(blind: boolean): ()
			if blind == lastBlind then
				return
			end
			lastBlind = blind
			signals.onBlindChanged:Fire(player, blind)
		end)
	)

	local lastScoped = peek(basePlayer.isScoped)
	table.insert(
		unsubs,
		sub(basePlayer.isScoped, function(scoped: boolean): ()
			if scoped == lastScoped then
				return
			end
			lastScoped = scoped
			signals.onScopedChanged:Fire(player, scoped)
		end)
	)

	local lastRescuing = peek(basePlayer.isRescuing)
	table.insert(
		unsubs,
		sub(basePlayer.isRescuing, function(rescuing: boolean): ()
			if rescuing == lastRescuing then
				return
			end
			lastRescuing = rescuing
			signals.onRescuingChanged:Fire(player, rescuing)
		end)
	)

	local lastCarrying = peek(basePlayer.isCarrying)
	table.insert(
		unsubs,
		sub(basePlayer.isCarrying, function(carrying: boolean): ()
			if carrying == lastCarrying then
				return
			end
			lastCarrying = carrying
			signals.onCarryingChanged:Fire(player, carrying)
		end)
	)

	local lastInvincible = peek(basePlayer.invincible)
	table.insert(
		unsubs,
		sub(basePlayer.invincible, function(invincible: boolean): ()
			if invincible == lastInvincible then
				return
			end
			lastInvincible = invincible
			signals.onInvincibleChanged:Fire(player, invincible)
		end)
	)

	local moneyConn = player:GetAttributeChangedSignal("Money"):Connect(function(): ()
		signals.onMoneyChanged:Fire(player, tonumber(player:GetAttribute("Money")) or 0)
	end)
	table.insert(unsubs, function(): ()
		moneyConn:Disconnect()
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
