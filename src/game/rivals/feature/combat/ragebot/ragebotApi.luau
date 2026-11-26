local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local sessionState = require("@feature/session/sessionState")
local originState = require("@game/universal/feature/visual/crosshair/originState")

local at = Charm.atom
local peek = Charm.peek

export type ShotEvent = {
	player: Player,
	part: BasePart,
	damage: number,
	wallbang: boolean,
	source: string,
	hitTarget: boolean,
}

export type TargetEvent = {
	player: Player?,
	part: BasePart?,
}

export type InFlightShot = { dmg: number, time: number }

export type InFlightStats = {
	damage: number,
	shotCount: number,
}

export type TargetFilterContext = {
	player: Player,
	character: Model?,
	weapon: any?,
}

export type ShotGateContext = {
	player: Player,
	part: BasePart,
	damage: number,
	wallbang: boolean,
	weapon: any?,
	source: string,
}

export type StrafeContext = {
	cframe: CFrame,
	position: Vector3,
	targetPosition: Vector3?,
	origin: Vector3,
	isVoid: boolean,
	distance: number,
	height: number,
	dt: number,
	angle: number,
	player: Player?,
	time: number,
}

type Entry = { id: number, fn: any, priority: number }
type Registry = { list: { Entry }, next: number }

local INFLIGHT_EXTRA_TTL = 0.1
local COVERED_MIN_SHOTS = 4

local _inFlightDamage: { [any]: { InFlightShot } } = {}
local _forcedTarget: Player? = nil
local _forcedUntil: number? = nil

local state = {
	enabled = at(false),
	lastShotAt = at(nil :: number?),
	lastTarget = at(nil :: Player?),
	lastTargetPart = at(nil :: BasePart?),
}

local signals = {
	onShotFired = Signal.new() :: Signal.Signal<ShotEvent>,
	onTargetChanged = Signal.new() :: Signal.Signal<TargetEvent>,
}

local function makeRegistry(): Registry
	return { list = {}, next = 0 }
end

local filters: Registry = makeRegistry()
local gates: Registry = makeRegistry()
local strafeOverrides: Registry = makeRegistry()

local _strafeProvider: (() -> CFrame?)? = nil

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

local ragebotApi = {
	state = state,
	signals = signals,
	COVERED_MIN_SHOTS = COVERED_MIN_SHOTS,
}

local function inFlightTtl(): number
	return (peek(sessionState.ping) or 0) / 1000 * 2 + INFLIGHT_EXTRA_TTL
end

function ragebotApi.GetInFlightStats(player: any, now: number?): (number, number)
	local shots = _inFlightDamage[player]
	if not shots then
		return 0, 0
	end
	local clock = now or tick()
	local ttl = inFlightTtl()
	local n = #shots
	local writeIdx = 1
	local total = 0
	for i = 1, n do
		local shot = shots[i]
		if clock - shot.time <= ttl then
			if writeIdx ~= i then
				shots[writeIdx] = shot
			end
			writeIdx += 1
			total += shot.dmg
		end
	end
	if writeIdx <= n then
		for i = n, writeIdx, -1 do
			shots[i] = nil
		end
		if writeIdx == 1 then
			_inFlightDamage[player] = nil
		end
	end
	return total, writeIdx - 1
end

function ragebotApi.RecordShot(player: any, dmg: number, now: number): ()
	local shots = _inFlightDamage[player]
	if not shots then
		shots = {}
		_inFlightDamage[player] = shots
	end
	shots[#shots + 1] = { dmg = dmg, time = now }
end

function ragebotApi.ClearInFlight(player: any?): ()
	if player == nil then
		table.clear(_inFlightDamage)
	else
		_inFlightDamage[player] = nil
	end
end

function ragebotApi.IsPlayerCovered(player: any, now: number?): boolean
	local health = peek(player.health) or 0
	if health <= 0 then
		return true
	end
	local total, shotCount = ragebotApi.GetInFlightStats(player, now)
	if shotCount < COVERED_MIN_SHOTS then
		return false
	end
	return total >= health
end

function ragebotApi.IsEnabled(): boolean
	return peek(state.enabled) == true
end

function ragebotApi.SetEnabled(value: boolean): ()
	if peek(state.enabled) ~= value then
		state.enabled(value)
	end
end

function ragebotApi.AddTargetFilter(fn: (Player, TargetFilterContext) -> boolean, priority: number?): number
	return insertSorted(filters, fn, priority)
end

function ragebotApi.RemoveTargetFilter(id: number): boolean
	return removeById(filters, id)
end

function ragebotApi.HasTargetFilters(): boolean
	return #filters.list > 0
end

function ragebotApi.RunTargetFilters(ctx: TargetFilterContext): boolean
	local list = filters.list
	if #list == 0 then
		return true
	end
	local snapshot = table.clone(list)
	for _, entry in next, snapshot do
		local ok, allow = pcall(entry.fn, ctx.player, ctx)
		if ok and allow == false then
			return false
		end
	end
	return true
end

function ragebotApi.AddShotGate(fn: (ShotGateContext) -> boolean, priority: number?): number
	return insertSorted(gates, fn, priority)
end

function ragebotApi.RemoveShotGate(id: number): boolean
	return removeById(gates, id)
end

function ragebotApi.HasShotGates(): boolean
	return #gates.list > 0
end

function ragebotApi.RunShotGates(ctx: ShotGateContext): boolean
	local list = gates.list
	if #list == 0 then
		return true
	end
	local snapshot = table.clone(list)
	for _, entry in next, snapshot do
		local ok, allow = pcall(entry.fn, ctx)
		if ok and allow == false then
			return false
		end
	end
	return true
end

local function isFiniteNumber(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function isValidCFrame(cf: any): boolean
	if typeof(cf) ~= "CFrame" then
		return false
	end
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = (cf :: CFrame):GetComponents()
	return isFiniteNumber(x)
		and isFiniteNumber(y)
		and isFiniteNumber(z)
		and isFiniteNumber(r00)
		and isFiniteNumber(r01)
		and isFiniteNumber(r02)
		and isFiniteNumber(r10)
		and isFiniteNumber(r11)
		and isFiniteNumber(r12)
		and isFiniteNumber(r20)
		and isFiniteNumber(r21)
		and isFiniteNumber(r22)
end

local function vectorToStrafeCFrame(pos: Vector3, target: Vector3?): CFrame?
	if typeof(pos) ~= "Vector3" or not isFiniteNumber(pos.X) or not isFiniteNumber(pos.Y) or not isFiniteNumber(pos.Z) then
		return nil
	end
	if typeof(target) == "Vector3" then
		local flat = Vector3.new(target.X, pos.Y, target.Z)
		if (flat - pos).Magnitude > 1e-4 then
			local candidate = CFrame.lookAt(pos, flat)
			if isValidCFrame(candidate) then
				return candidate
			end
		end
	end
	return CFrame.new(pos)
end

function ragebotApi.AddStrafeOverride(fn: (StrafeContext) -> any, priority: number?): number
	return insertSorted(strafeOverrides, fn, priority)
end

function ragebotApi.RemoveStrafeOverride(id: number): boolean
	return removeById(strafeOverrides, id)
end

function ragebotApi.HasStrafeOverrides(): boolean
	return #strafeOverrides.list > 0
end

function ragebotApi.RunStrafeOverride(ctx: StrafeContext, current: CFrame): CFrame
	local list = strafeOverrides.list
	if #list == 0 or not isValidCFrame(current) then
		return current
	end
	local result = current
	local snapshot = table.clone(list)
	for i = #snapshot, 1, -1 do
		local entry = snapshot[i]
		ctx.cframe = result
		ctx.position = result.Position
		local ok, ret = pcall(entry.fn, ctx)
		if ok and ret ~= nil then
			if typeof(ret) == "CFrame" then
				if isValidCFrame(ret) then
					result = ret
				end
			elseif typeof(ret) == "Vector3" then
				local candidate = vectorToStrafeCFrame(ret, ctx.targetPosition)
				if candidate then
					result = candidate
				end
			end
		end
	end
	return result
end

function ragebotApi.SetStrafeProvider(provider: (() -> CFrame?)?): ()
	_strafeProvider = provider
end

function ragebotApi.GetStrafePosition(): CFrame?
	if not _strafeProvider then
		return nil
	end
	local ok, cf = pcall(_strafeProvider)
	if ok and isValidCFrame(cf) then
		return cf
	end
	return nil
end

local function isForcedActive(): boolean
	if not _forcedTarget then
		return false
	end
	if _forcedTarget.Parent == nil then
		_forcedTarget = nil
		_forcedUntil = nil
		return false
	end
	if _forcedUntil and os.clock() >= _forcedUntil then
		_forcedTarget = nil
		_forcedUntil = nil
		return false
	end
	return true
end

function ragebotApi.GetForcedTarget(): Player?
	if isForcedActive() then
		return _forcedTarget
	end
	return nil
end

function ragebotApi.SetForcedTarget(player: Player?, durationSec: number?): ()
	_forcedTarget = player
	if player and durationSec then
		_forcedUntil = os.clock() + durationSec
	else
		_forcedUntil = nil
	end
end

function ragebotApi.ClearForcedTarget(): ()
	_forcedTarget = nil
	_forcedUntil = nil
end

function ragebotApi.NotifyShotFired(event: ShotEvent): ()
	state.lastShotAt(os.clock())
	originState.NotifyRagebotTarget(event.part)
	local prevTarget = peek(state.lastTarget)
	local prevPart = peek(state.lastTargetPart)
	if prevTarget ~= event.player then
		state.lastTarget(event.player)
	end
	if prevPart ~= event.part then
		state.lastTargetPart(event.part)
	end
	signals.onShotFired:Fire(event)
	if prevTarget ~= event.player or prevPart ~= event.part then
		signals.onTargetChanged:Fire({ player = event.player, part = event.part })
	end
end

function ragebotApi.NotifyTargetChanged(event: TargetEvent): ()
	signals.onTargetChanged:Fire(event)
end

return ragebotApi
