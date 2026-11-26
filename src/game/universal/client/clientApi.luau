local Players = cloneref(game:GetService("Players")) :: Players
local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")

local localState = require("@game/universal/client/localState")
local universalAdapter = require("@game/universal/adapter/universalAdapter")
local universalEvents = require("@game/universal/adapter/universalEvents")

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
	onWeaponChanged = Signal.new(),
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
	return peek(localState.character)
end

function clientApi.GetHumanoid(): Humanoid?
	return peek(localState.humanoid)
end

function clientApi.GetRootPart(): BasePart?
	return peek(localState.hrp)
end

function clientApi.GetParts(): { [string]: Instance }
	local snap = peek(localState.parts)
	local out: { [string]: Instance } = {}
	for k, v in next, snap do
		out[k] = v
	end
	return out
end

function clientApi.IsAlive(): boolean
	local resolver = universalAdapter.overrides.resolveLocalAlive
	if resolver then
		return resolver()
	end
	return peek(localState.alive)
end

function clientApi.IsSpectating(): boolean
	return false
end

function clientApi.GetTeam(): string?
	local resolver = universalAdapter.overrides.resolveLocalTeam
	if resolver then
		return resolver()
	end
	return peek(localState.team)
end

function clientApi.GetHealth(): number
	return peek(localState.health)
end

function clientApi.GetMaxHealth(): number
	return peek(localState.maxHealth)
end

function clientApi.GetHealthFraction(): number
	local maxH = peek(localState.maxHealth)
	if maxH <= 0 then
		return 0
	end
	return math.clamp(peek(localState.health) / maxH, 0, 1)
end

function clientApi.GetPosition(): Vector3?
	local hrp = peek(localState.hrp)
	return hrp and hrp.Position
end

function clientApi.GetCFrame(): CFrame?
	local hrp = peek(localState.hrp)
	return hrp and hrp.CFrame
end

function clientApi.GetVelocity(): Vector3
	local hrp = peek(localState.hrp)
	return hrp and hrp.AssemblyLinearVelocity or Vector3.zero
end

function clientApi.GetWeapon(): any?
	return universalAdapter.GetEquippedWeapon()
end

function clientApi.GetItemName(): string?
	local weapon = universalAdapter.GetEquippedWeapon()
	if weapon == nil then
		return nil
	end
	if typeof(weapon) == "Instance" then
		return weapon.Name
	end
	if type(weapon) == "table" and type(weapon.Name) == "string" then
		return weapon.Name
	end
	return nil
end

local _lastAlive = false
sub(localState.character, function(char: Model?): ()
	if char then
		signals.onCharacterAdded:Fire(char)
	else
		signals.onCharacterRemoving:Fire()
	end
end)

sub(localState.alive, function(alive: boolean): ()
	if alive and not _lastAlive then
		_lastAlive = true
		signals.onSpawn:Fire()
	elseif not alive and _lastAlive then
		_lastAlive = false
		signals.onDeath:Fire()
	end
end)

sub(localState.health, function(health: number): ()
	signals.onHealthChanged:Fire(health, peek(localState.maxHealth))
end)

sub(localState.team, function(team: string): ()
	signals.onTeamChanged:Fire(team)
end)

sub(universalAdapter.equippedWeapon, function(weapon: any): ()
	signals.onWeaponChanged:Fire(weapon)
end)

universalEvents.hit:Connect(function(event: universalEvents.HitEvent): ()
	if not event.player then
		return
	end
	signals.onHit:Fire({
		player = event.player,
		part = event.part,
		partName = event.partName,
		position = event.position,
		damage = event.damage,
		headshot = event.headshot,
	})
end)

universalEvents.kill:Connect(function(event: universalEvents.KillEvent): ()
	if not event.player then
		return
	end
	signals.onKill:Fire({
		player = event.player,
		position = event.position,
		headshot = event.headshot,
	})
end)

return clientApi
