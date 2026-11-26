local Players = cloneref(game:GetService("Players")) :: Players
local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")

local ClientState = require("@game/rivals/client/clientState")

local peek = Charm.peek
local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer

local signals = {
	onCharacterAdded = Signal.new(),
	onCharacterRemoving = Signal.new(),
	onSpawn = Signal.new(),
	onDeath = Signal.new(),
	onTeamChanged = Signal.new(),
	onHealthChanged = Signal.new(),
	onEquippedChanged = Signal.new(),
	onHit = Signal.new(),
	onKill = Signal.new(),
}

local clientApi = {
	signals = signals,
}

function clientApi.GetLocalPlayer(): Player
	return LocalPlayer
end

function clientApi.GetCharacter(): Model?
	return peek(ClientState.character)
end

function clientApi.GetHumanoid(): Humanoid?
	return peek(ClientState.humanoid)
end

function clientApi.GetRootPart(): BasePart?
	return peek(ClientState.hrp)
end

function clientApi.GetParts(): { [string]: Instance }
	local snap = peek(ClientState.parts)
	local out: { [string]: Instance } = {}
	for k, v in next, snap do
		out[k] = v
	end
	return out
end

function clientApi.IsAlive(): boolean
	return peek(ClientState.alive)
end

function clientApi.IsSpectating(): boolean
	return peek(ClientState.isSpectating)
end

function clientApi.IsInDuel(): boolean
	return peek(ClientState.isInDuel)
end

function clientApi.IsCrouching(): boolean
	return peek(ClientState.isCrouching)
end

function clientApi.IsSliding(): boolean
	return peek(ClientState.isSliding)
end

function clientApi.IsFirstPerson(): boolean
	return peek(ClientState.isFirstPerson)
end

function clientApi.IsFrozen(): boolean
	return peek(ClientState.isFrozen)
end

function clientApi.IsInvincible(): boolean
	return peek(ClientState.isInvincible)
end

function clientApi.IsHidden(): boolean
	return peek(ClientState.isHidden)
end

function clientApi.GetTeam(): string?
	return peek(ClientState.team)
end

function clientApi.GetEnvironmentId(): string
	return peek(ClientState.environmentId)
end

function clientApi.GetHealth(): number
	return peek(ClientState.health)
end

function clientApi.GetMaxHealth(): number
	return peek(ClientState.maxHealth)
end

function clientApi.GetHealthFraction(): number
	local maxH = peek(ClientState.maxHealth)
	if maxH <= 0 then
		return 0
	end
	return math.clamp(peek(ClientState.health) / maxH, 0, 1)
end

function clientApi.GetPosition(): Vector3?
	local hrp = peek(ClientState.hrp)
	return hrp and hrp.Position
end

function clientApi.GetCFrame(): CFrame?
	local hrp = peek(ClientState.hrp)
	return hrp and hrp.CFrame
end

function clientApi.GetVelocity(): Vector3
	return peek(ClientState.velocity)
end

function clientApi.GetAimCFrame(): CFrame
	return peek(ClientState.aimCFrame)
end

function clientApi.GetEquipped(): ClientState.EquippedItem?
	return peek(ClientState.currentEquipped)
end

function clientApi.GetItemName(): string?
	local equipped = peek(ClientState.currentEquipped)
	return equipped and equipped.Name
end

function clientApi.GetControls(): string
	return peek(ClientState.controls)
end

function clientApi.GetItems(): { string }
	return peek(ClientState.items)
end

function clientApi.GetLevel(): number
	return peek(ClientState.level)
end

function clientApi.GetWinStreak(): number
	return peek(ClientState.winStreak)
end

function clientApi.GetDisplayElo(): number
	return peek(ClientState.displayElo)
end

local _lastAlive = false
sub(ClientState.character, function(char: Model?): ()
	if char then
		signals.onCharacterAdded:Fire(char)
	else
		signals.onCharacterRemoving:Fire()
	end
end)

sub(ClientState.alive, function(alive: boolean): ()
	if alive and not _lastAlive then
		_lastAlive = true
		signals.onSpawn:Fire()
	elseif not alive and _lastAlive then
		_lastAlive = false
		signals.onDeath:Fire()
	end
end)

sub(ClientState.health, function(health: number): ()
	signals.onHealthChanged:Fire(health, peek(ClientState.maxHealth))
end)

sub(ClientState.team, function(team: string): ()
	signals.onTeamChanged:Fire(team)
end)

sub(ClientState.currentEquipped, function(item: ClientState.EquippedItem?): ()
	signals.onEquippedChanged:Fire(item)
end)

return clientApi
