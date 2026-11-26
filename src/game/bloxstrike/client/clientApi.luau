local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local Players = cloneref(game:GetService("Players")) :: Players

local ClientState = require("@game/bloxstrike/client/clientState")
local ClientController = require("@game/bloxstrike/client/ClientController")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer

local state = {
	character = ClientState.character,
	alive = ClientState.alive,
	team = ClientState.team,
	isSpectating = ClientState.isSpectating,
	isFlashed = ClientState.isFlashed,
	flashVisibility = ClientState.flashVisibility,
	isScoped = ClientState.isScoped,
	isDefusing = ClientState.isDefusing,
	hasC4 = ClientState.hasC4,
	armor = ClientState.armor,
	spectatorCount = ClientState.spectatorCount,
	isRescuing = at(LocalPlayer:GetAttribute("IsRescuingHostage") == true),
	isCarrying = at(LocalPlayer:GetAttribute("IsCarryingHostage") == true),
	money = at(tonumber(LocalPlayer:GetAttribute("Money")) or 0),
	parts = ClientState.parts,
	weapon = loadoutState.currentEquipped,
	humanoid = at(nil :: Humanoid?),
	hrp = at(nil :: BasePart?),
}

local signals = {
	onCharacterAdded = Signal.new(),
	onCharacterRemoving = Signal.new(),
	onSpawn = Signal.new(),
	onDeath = Signal.new(),
	onWeaponChanged = Signal.new(),
	onTeamChanged = Signal.new(),
	onHealthChanged = Signal.new(),
	onSpectatingChanged = Signal.new(),
	onBlindChanged = Signal.new(),
	onFlashVisibilityChanged = Signal.new(),
	onScopedChanged = Signal.new(),
	onDefusingChanged = Signal.new(),
	onC4Changed = Signal.new(),
	onArmorChanged = Signal.new(),
	onSpectatorCountChanged = Signal.new(),
	onRescuingChanged = Signal.new(),
	onCarryingChanged = Signal.new(),
	onMoneyChanged = Signal.new(),
	onHit = Signal.new(),
	onKill = Signal.new(),
}

local clientApi = {
	state = state,
	signals = signals,
}

function clientApi.GetLocalPlayer(): Player
	return LocalPlayer
end

function clientApi.GetCharacter(): Model?
	return peek(state.character)
end

function clientApi.GetHumanoid(): Humanoid?
	return peek(state.humanoid)
end

function clientApi.GetRootPart(): BasePart?
	return peek(state.hrp)
end

function clientApi.GetParts(): { [string]: Instance }
	local snap = peek(state.parts)
	local out: { [string]: Instance } = {}
	for k, v in next, snap do
		out[k] = v
	end
	return out
end

function clientApi.IsAlive(): boolean
	return peek(state.alive)
end

function clientApi.IsSpectating(): boolean
	return peek(state.isSpectating)
end

function clientApi.IsBlind(): boolean
	return peek(state.isFlashed)
end

function clientApi.IsFlashed(): boolean
	return peek(state.isFlashed)
end

function clientApi.GetFlashVisibility(): number
	return peek(state.flashVisibility)
end

function clientApi.IsScoped(): boolean
	return peek(state.isScoped)
end

function clientApi.IsClimbing(): boolean
	return ClientController.IsClimbing()
end

function clientApi.IsDefusing(): boolean
	return peek(state.isDefusing)
end

function clientApi.HasC4(): boolean
	return peek(state.hasC4)
end

function clientApi.GetArmor(): ClientState.ArmorState
	return peek(state.armor)
end

function clientApi.HasArmor(): boolean
	return peek(state.armor).kevlar
end

function clientApi.HasHelmet(): boolean
	return peek(state.armor).helmet
end

function clientApi.GetSpectatorCount(): number
	return peek(state.spectatorCount)
end

function clientApi.IsBeingSpectated(): boolean
	return peek(state.spectatorCount) > 0
end

function clientApi.IsRescuingHostage(): boolean
	return peek(state.isRescuing)
end

function clientApi.IsCarryingHostage(): boolean
	return peek(state.isCarrying)
end

function clientApi.GetTeam(): string?
	return peek(state.team)
end

function clientApi.GetHealth(): number
	local hum = peek(state.humanoid)
	if not hum then
		return 0
	end
	return hum.Health
end

function clientApi.GetMaxHealth(): number
	local hum = peek(state.humanoid)
	if not hum then
		return 100
	end
	return hum.MaxHealth
end

function clientApi.GetHealthFraction(): number
	local hum = peek(state.humanoid)
	if not hum then
		return 0
	end
	local maxH = hum.MaxHealth
	if maxH <= 0 then
		return 0
	end
	return math.clamp(hum.Health / maxH, 0, 1)
end

function clientApi.GetPosition(): Vector3?
	local hrp = peek(state.hrp)
	return hrp and hrp.Position
end

function clientApi.GetCFrame(): CFrame?
	local hrp = peek(state.hrp)
	return hrp and hrp.CFrame
end

function clientApi.GetVelocity(): Vector3
	local hrp = peek(state.hrp)
	return hrp and hrp.AssemblyLinearVelocity or Vector3.zero
end

function clientApi.GetWeapon(): loadoutState.LoadoutEntry?
	return peek(state.weapon)
end

function clientApi.GetItemName(): string?
	local w = peek(state.weapon)
	if not w then
		return nil
	end
	return w.Name
end

function clientApi.GetWeaponProperties(): any?
	local w = peek(state.weapon)
	if not w then
		return nil
	end
	return w.Properties
end

function clientApi.GetMoney(): number
	return peek(state.money)
end

function clientApi.GetAmmo(): { rounds: number, reserve: number }?
	local w = peek(state.weapon)
	if not w then
		return nil
	end
	local rounds = (w :: any).Rounds
	local reserve = (w :: any).Capacity
	if type(rounds) ~= "number" and type(reserve) ~= "number" then
		return nil
	end
	return {
		rounds = type(rounds) == "number" and math.max(rounds, 0) or 0,
		reserve = type(reserve) == "number" and math.max(reserve, 0) or 0,
	}
end

function clientApi.GetInventory(): { loadoutState.LoadoutEntry }
	local inv = peek(loadoutState.inventory)
	local out: { loadoutState.LoadoutEntry } = {}
	for i, v in next, inv do
		out[i] = v
	end
	return out
end

local lastCharacter: Model? = nil
local humanoidConn: RBXScriptConnection? = nil
local maxHealthConn: RBXScriptConnection? = nil

local function clearHumanoidHooks(): ()
	if humanoidConn then
		humanoidConn:Disconnect()
		humanoidConn = nil
	end
	if maxHealthConn then
		maxHealthConn:Disconnect()
		maxHealthConn = nil
	end
end

local function bindHumanoid(humanoid: Humanoid): ()
	clearHumanoidHooks()
	humanoidConn = humanoid.HealthChanged:Connect(function(health: number): ()
		signals.onHealthChanged:Fire(health, humanoid.MaxHealth)
	end)
	maxHealthConn = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function(): ()
		signals.onHealthChanged:Fire(humanoid.Health, humanoid.MaxHealth)
	end)
end

sub(state.character, function(character: Model?): ()
	if character == lastCharacter then
		return
	end
	local previous = lastCharacter
	if previous then
		clearHumanoidHooks()
		state.humanoid(nil)
		state.hrp(nil)
		signals.onCharacterRemoving:Fire(previous)
	end
	lastCharacter = character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		state.humanoid(humanoid)
		state.hrp(hrp)
		if humanoid then
			bindHumanoid(humanoid)
		end
		signals.onCharacterAdded:Fire(character)
	end
end)

if peek(state.character) then
	local character = peek(state.character) :: Model
	lastCharacter = character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	state.humanoid(humanoid)
	state.hrp(hrp)
	if humanoid then
		bindHumanoid(humanoid)
	end
end

local lastAlive = peek(state.alive)
sub(state.alive, function(alive: boolean): ()
	if alive == lastAlive then
		return
	end
	lastAlive = alive
	if alive then
		signals.onSpawn:Fire()
	else
		signals.onDeath:Fire()
	end
end)

local lastWeapon = peek(state.weapon)
sub(state.weapon, function(weapon: loadoutState.LoadoutEntry?): ()
	if weapon == lastWeapon then
		return
	end
	lastWeapon = weapon
	signals.onWeaponChanged:Fire(weapon)
end)

local lastTeam = peek(state.team)
sub(state.team, function(team: any): ()
	if team == lastTeam then
		return
	end
	lastTeam = team
	signals.onTeamChanged:Fire(team)
end)

local lastSpectating = peek(state.isSpectating)
sub(state.isSpectating, function(spectating: boolean): ()
	if spectating == lastSpectating then
		return
	end
	lastSpectating = spectating
	signals.onSpectatingChanged:Fire(spectating)
end)

local lastFlashed = peek(state.isFlashed)
sub(state.isFlashed, function(flashed: boolean): ()
	if flashed == lastFlashed then
		return
	end
	lastFlashed = flashed
	signals.onBlindChanged:Fire(flashed)
end)

local lastFlashVis = peek(state.flashVisibility)
sub(state.flashVisibility, function(visibility: number): ()
	if visibility == lastFlashVis then
		return
	end
	lastFlashVis = visibility
	signals.onFlashVisibilityChanged:Fire(visibility)
end)

local lastScoped = peek(state.isScoped)
sub(state.isScoped, function(scoped: boolean): ()
	if scoped == lastScoped then
		return
	end
	lastScoped = scoped
	signals.onScopedChanged:Fire(scoped)
end)

local lastDefusing = peek(state.isDefusing)
sub(state.isDefusing, function(defusing: boolean): ()
	if defusing == lastDefusing then
		return
	end
	lastDefusing = defusing
	signals.onDefusingChanged:Fire(defusing)
end)

local lastHasC4 = peek(state.hasC4)
sub(state.hasC4, function(hasC4: boolean): ()
	if hasC4 == lastHasC4 then
		return
	end
	lastHasC4 = hasC4
	signals.onC4Changed:Fire(hasC4)
end)

sub(state.armor, function(armor: ClientState.ArmorState): ()
	signals.onArmorChanged:Fire(armor)
end)

local lastSpectatorCount = peek(state.spectatorCount)
sub(state.spectatorCount, function(count: number): ()
	if count == lastSpectatorCount then
		return
	end
	lastSpectatorCount = count
	signals.onSpectatorCountChanged:Fire(count)
end)

LocalPlayer:GetAttributeChangedSignal("IsRescuingHostage"):Connect(function(): ()
	state.isRescuing(LocalPlayer:GetAttribute("IsRescuingHostage") == true)
end)
LocalPlayer:GetAttributeChangedSignal("IsCarryingHostage"):Connect(function(): ()
	state.isCarrying(LocalPlayer:GetAttribute("IsCarryingHostage") == true)
end)
LocalPlayer:GetAttributeChangedSignal("Money"):Connect(function(): ()
	state.money(tonumber(LocalPlayer:GetAttribute("Money")) or 0)
end)

local lastRescuing = peek(state.isRescuing)
sub(state.isRescuing, function(rescuing: boolean): ()
	if rescuing == lastRescuing then
		return
	end
	lastRescuing = rescuing
	signals.onRescuingChanged:Fire(rescuing)
end)

local lastCarrying = peek(state.isCarrying)
sub(state.isCarrying, function(carrying: boolean): ()
	if carrying == lastCarrying then
		return
	end
	lastCarrying = carrying
	signals.onCarryingChanged:Fire(carrying)
end)

local lastMoney = peek(state.money)
sub(state.money, function(money: number): ()
	if money == lastMoney then
		return
	end
	lastMoney = money
	signals.onMoneyChanged:Fire(money)
end)

return clientApi
