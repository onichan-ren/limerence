local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local scopeState = require("@ui/scope/scopeState")
local ScopeController = require("@feature/ui/scope/ScopeController")
local legitbotState = require("@game/universal/feature/combat/legitbot/legitbotState")

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe

export type TargetSnapshot = {
	player: Player,
	part: BasePart,
	hitbox: string,
	distance: number,
	pixelDist: number,
	alignment: number,
}

export type ShotEvent = {
	player: Player?,
	part: BasePart?,
	hitbox: string?,
	predictedDamage: number?,
	hitChance: number?,
	wallbang: boolean?,
	weapon: any?,
	source: string,
	burst: boolean,
}

export type TargetEvent = {
	player: Player?,
	part: BasePart?,
	hitbox: string?,
}

export type TriggerEvent = {
	player: Player,
	part: BasePart,
	hitbox: string?,
}

export type MagnetEvent = {
	player: Player,
	part: BasePart,
	dx: number,
	dy: number,
	strength: number,
}

export type TargetFilterContext = {
	player: Player,
	weapon: any?,
	scope: string,
}

export type ShotGateContext = {
	player: Player?,
	part: BasePart?,
	hitbox: string?,
	weapon: any?,
	predictedDamage: number?,
	hitChance: number?,
	wallbang: boolean?,
	burst: boolean,
}

export type AimTransformContext = {
	player: Player,
	part: BasePart,
	hitbox: string?,
	weapon: any?,
	aimPoint: Vector3,
}

type Entry = { id: number, fn: any, priority: number }
type Registry = { list: { Entry }, next: number }

local function makeRegistry(): Registry
	return { list = {}, next = 0 }
end

local filters: Registry = makeRegistry()
local gates: Registry = makeRegistry()
local transforms: Registry = makeRegistry()

local state = {
	activeTarget = legitbotState.target,
	activeTargetPart = legitbotState.targetPart,
	activeTargetHitbox = at(nil :: string?),
	triggerTarget = at(nil :: Player?),
	triggerTargetPart = at(nil :: BasePart?),
	triggerTargetHitbox = at(nil :: string?),
	redirectionTargetPart = at(nil :: BasePart?),
	activeScope = at(peek(scopeState.equippedScope)),
	lastShotAt = at(nil :: number?),
	burstRemaining = at(nil :: number?),
}

local signals = {
	onShotFired = Signal.new(),
	onTargetAcquired = Signal.new(),
	onTargetLost = Signal.new(),
	onTriggerArmed = Signal.new(),
	onTriggerDisarmed = Signal.new(),
	onScopeChanged = Signal.new(),
	onMagnetPull = Signal.new(),
}

local forcedTarget: Player? = nil
local forcedUntil: number? = nil
local shotRequested = false

local validTargetsProvider: (() -> { TargetSnapshot })? = nil

local legitbotApi = {
	state = state,
	signals = signals,
}

local function insertSorted(reg: Registry, fn: any, priority: number?): number
	reg.next += 1
	local entry: Entry = { id = reg.next, fn = fn, priority = priority or 0 }
	local list = reg.list
	local i = 1
	while i <= #list and list[i].priority >= entry.priority do
		i += 1
	end
	table.insert(list, i, entry)
	return entry.id
end

local function removeById(reg: Registry, id: number): boolean
	for i, entry in next, reg.list do
		if entry.id == id then
			table.remove(reg.list, i)
			return true
		end
	end
	return false
end

function legitbotApi.AddTargetFilter(fn: (Player, TargetFilterContext) -> boolean, priority: number?): number
	return insertSorted(filters, fn, priority)
end

function legitbotApi.RemoveTargetFilter(id: number): boolean
	return removeById(filters, id)
end

function legitbotApi.RunTargetFilters(ctx: TargetFilterContext): boolean
	local list = filters.list
	for i = 1, #list do
		if list[i].fn(ctx.player, ctx) == false then
			return false
		end
	end
	return true
end

function legitbotApi.AddShotGate(fn: (ShotGateContext) -> boolean, priority: number?): number
	return insertSorted(gates, fn, priority)
end

function legitbotApi.RemoveShotGate(id: number): boolean
	return removeById(gates, id)
end

function legitbotApi.RunShotGates(ctx: ShotGateContext): boolean
	local list = gates.list
	for i = 1, #list do
		if list[i].fn(ctx) == false then
			return false
		end
	end
	return true
end

function legitbotApi.AddAimTransform(fn: (AimTransformContext) -> Vector3?, priority: number?): number
	return insertSorted(transforms, fn, priority)
end

function legitbotApi.RemoveAimTransform(id: number): boolean
	return removeById(transforms, id)
end

function legitbotApi.RunAimTransforms(ctx: AimTransformContext): Vector3
	local list = transforms.list
	local point = ctx.aimPoint
	for i = #list, 1, -1 do
		ctx.aimPoint = point
		local result = list[i].fn(ctx)
		if typeof(result) == "Vector3" then
			point = result
		end
	end
	return point
end

function legitbotApi.HasAimTransforms(): boolean
	return #transforms.list > 0
end

function legitbotApi.HasTargetFilters(): boolean
	return #filters.list > 0
end

function legitbotApi.HasShotGates(): boolean
	return #gates.list > 0
end

local function isForcedActive(): boolean
	if not forcedTarget then
		return false
	end
	if forcedTarget.Parent == nil then
		forcedTarget = nil
		forcedUntil = nil
		return false
	end
	if forcedUntil and os.clock() >= forcedUntil then
		forcedTarget = nil
		forcedUntil = nil
		return false
	end
	return true
end

function legitbotApi.GetForcedTarget(): Player?
	if isForcedActive() then
		return forcedTarget
	end
	return nil
end

function legitbotApi.SetForcedTarget(player: Player?, durationSec: number?): ()
	forcedTarget = player
	if player and durationSec then
		forcedUntil = os.clock() + durationSec
	else
		forcedUntil = nil
	end
end

function legitbotApi.ClearForcedTarget(): ()
	forcedTarget = nil
	forcedUntil = nil
end

function legitbotApi.RequestShot(): ()
	shotRequested = true
end

function legitbotApi.ConsumeShotRequest(): boolean
	if shotRequested then
		shotRequested = false
		return true
	end
	return false
end

function legitbotApi.SetValidTargetsProvider(provider: (() -> { TargetSnapshot })?): ()
	validTargetsProvider = provider
end

function legitbotApi.GetValidTargets(): { TargetSnapshot }
	local provider = validTargetsProvider
	if provider then
		return provider()
	end
	return {}
end

function legitbotApi.GetResolvedValue(key: string, scopeId: string?): any
	return ScopeController.GetResolvedValue(key, scopeId)
end

function legitbotApi.IsFiring(): boolean
	local lastShot = peek(state.lastShotAt)
	if not lastShot then
		return false
	end
	return (os.clock() - lastShot) < 0.1
end

function legitbotApi.NotifyShotFired(event: ShotEvent): ()
	state.lastShotAt(os.clock())
	signals.onShotFired:Fire(event)
end

function legitbotApi.NotifyMagnetPull(event: MagnetEvent): ()
	signals.onMagnetPull:Fire(event)
end

function legitbotApi.SetAimTarget(player: Player?, part: BasePart?, hitbox: string?): ()
	if peek(state.activeTargetHitbox) ~= hitbox then
		state.activeTargetHitbox(hitbox)
	end
end

function legitbotApi.SetTriggerTarget(player: Player?, part: BasePart?, hitbox: string?): ()
	if peek(state.triggerTarget) ~= player then
		state.triggerTarget(player)
	end
	if peek(state.triggerTargetPart) ~= part then
		state.triggerTargetPart(part)
	end
	if peek(state.triggerTargetHitbox) ~= hitbox then
		state.triggerTargetHitbox(hitbox)
	end
end

function legitbotApi.SetRedirectionTarget(part: BasePart?): ()
	if peek(state.redirectionTargetPart) ~= part then
		state.redirectionTargetPart(part)
	end
end

function legitbotApi.SetBurstRemaining(n: number?): ()
	if peek(state.burstRemaining) ~= n then
		state.burstRemaining(n)
	end
end

local lastAimTarget: Player? = nil
sub(state.activeTarget, function(newTarget: Player?): ()
	if newTarget == lastAimTarget then
		return
	end
	if newTarget == nil and peek(state.activeTargetHitbox) ~= nil then
		state.activeTargetHitbox(nil)
	end
	if lastAimTarget then
		signals.onTargetLost:Fire({
			player = lastAimTarget,
			part = nil :: any,
			hitbox = nil :: any,
		})
	end
	if newTarget then
		signals.onTargetAcquired:Fire({
			player = newTarget,
			part = peek(state.activeTargetPart),
			hitbox = peek(state.activeTargetHitbox),
		})
	end
	lastAimTarget = newTarget
end)

local lastTriggerTarget: Player? = nil
sub(state.triggerTarget, function(newTarget: Player?): ()
	if newTarget == lastTriggerTarget then
		return
	end
	if lastTriggerTarget and not newTarget then
		signals.onTriggerDisarmed:Fire()
	elseif newTarget and not lastTriggerTarget then
		signals.onTriggerArmed:Fire({
			player = newTarget,
			part = peek(state.triggerTargetPart) :: any,
			hitbox = peek(state.triggerTargetHitbox),
		})
	elseif newTarget and lastTriggerTarget then
		signals.onTriggerDisarmed:Fire()
		signals.onTriggerArmed:Fire({
			player = newTarget,
			part = peek(state.triggerTargetPart) :: any,
			hitbox = peek(state.triggerTargetHitbox),
		})
	end
	lastTriggerTarget = newTarget
end)

sub(scopeState.equippedScope, function(newScope: string): ()
	local previous = peek(state.activeScope)
	if previous == newScope then
		return
	end
	state.activeScope(newScope)
	signals.onScopeChanged:Fire(newScope)
end)

return legitbotApi
