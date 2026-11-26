local Charm = require("@pkg/Charm")
local Players = cloneref(game:GetService("Players")) :: Players

local PlayerController = require("@feature/player/PlayerController")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")

local peek = Charm.peek

export type RegistrationHandle = luauApiRegistry.RegistrationHandle

export type ForceTargetHandle = {
	Release: (self: ForceTargetHandle) -> (),
	IsReleased: (self: ForceTargetHandle) -> boolean,
	GetPlayer: (self: ForceTargetHandle) -> Player?,
}

type RegistrationKind = "filter" | "gate" | "strafe"

local function resolvePlayer(input: any): Player?
	if typeof(input) == "Instance" and input.ClassName == "Player" then
		return input :: Player
	end
	if type(input) == "string" then
		return Players:FindFirstChild(input) :: Player?
	end
	if type(input) == "number" then
		for _, plr in next, Players:GetPlayers() do
			if plr.UserId == input then
				return plr
			end
		end
	end
	return nil
end

local function resolveBasePlayer(player: Player): any?
	return PlayerController.Get(player)
end

local luauRagebotApi = {}

local function build(ragebotApi: any, ctx: luauApiRegistry.ApiContext): { [string]: any }
	local onUnload = ctx.onUnload

	local registry = luauApiRegistry.CreateRegistry(onUnload)
	local forcedHandle: { player: Player?, released: boolean }? = nil

	local methodNames: { [RegistrationKind]: string } = {
		filter = "addTargetFilter",
		gate = "addShotGate",
		strafe = "setStrafeOverride",
	}

	local function add(kind: RegistrationKind, fn: any, priority: number?): RegistrationHandle
		if type(fn) ~= "function" then
			error(`api.ragebot.{methodNames[kind]}: callback must be a function`, 3)
		end
		local p = priority or 0
		local addFn: any
		local removeFn: any
		if kind == "filter" then
			addFn, removeFn = ragebotApi.AddTargetFilter, ragebotApi.RemoveTargetFilter
		elseif kind == "strafe" then
			addFn, removeFn = ragebotApi.AddStrafeOverride, ragebotApi.RemoveStrafeOverride
		else
			addFn, removeFn = ragebotApi.AddShotGate, ragebotApi.RemoveShotGate
		end
		return registry.Add({
			id = addFn(fn, p),
			fn = fn,
			priority = p,
			remove = removeFn,
			reAdd = addFn,
		})
	end

	onUnload:Connect(function(): ()
		if forcedHandle and not forcedHandle.released then
			forcedHandle.released = true
			if ragebotApi.GetForcedTarget() == forcedHandle.player then
				ragebotApi.ClearForcedTarget()
			end
			forcedHandle = nil
		end
	end)

	local api = {}

	local wrap = luauApiRegistry.WrapSignal
	api.onShotFired = wrap(ragebotApi.signals.onShotFired, onUnload)
	api.onTargetChanged = wrap(ragebotApi.signals.onTargetChanged, onUnload)

	function api.isEnabled(): boolean
		return ragebotApi.IsEnabled()
	end

	function api.getLastShotTime(): number?
		return peek(ragebotApi.state.lastShotAt)
	end

	function api.getLastTarget(): { player: Player, part: BasePart? }?
		local player = peek(ragebotApi.state.lastTarget)
		if not player then
			return nil
		end
		return {
			player = player,
			part = peek(ragebotApi.state.lastTargetPart),
		}
	end

	function api.getInFlightStats(player: any): { damage: number, shotCount: number }?
		local resolved = resolvePlayer(player)
		if not resolved then
			return nil
		end
		local bp = resolveBasePlayer(resolved)
		if not bp then
			return { damage = 0, shotCount = 0 }
		end
		local damage, shotCount = ragebotApi.GetInFlightStats(bp)
		return { damage = damage, shotCount = shotCount }
	end

	function api.isPlayerCovered(player: any): boolean
		local resolved = resolvePlayer(player)
		if not resolved then
			return false
		end
		local bp = resolveBasePlayer(resolved)
		if not bp then
			return false
		end
		return ragebotApi.IsPlayerCovered(bp)
	end

	function api.clearInFlight(player: any?): ()
		if player == nil then
			ragebotApi.ClearInFlight(nil)
			return
		end
		local resolved = resolvePlayer(player)
		if not resolved then
			return
		end
		local bp = resolveBasePlayer(resolved)
		if bp then
			ragebotApi.ClearInFlight(bp)
		end
	end

	function api.addTargetFilter(fn: (Player, any) -> boolean, priority: number?): RegistrationHandle
		return add("filter", fn, priority)
	end

	function api.addShotGate(fn: (any) -> boolean, priority: number?): RegistrationHandle
		return add("gate", fn, priority)
	end

	function api.forceTarget(player: any, durationSec: number?): ForceTargetHandle?
		local resolved = resolvePlayer(player)
		if not resolved then
			return nil
		end
		if forcedHandle and not forcedHandle.released then
			forcedHandle.released = true
			if ragebotApi.GetForcedTarget() == forcedHandle.player then
				ragebotApi.ClearForcedTarget()
			end
		end
		forcedHandle = { player = resolved, released = false }
		local captured = forcedHandle
		ragebotApi.SetForcedTarget(resolved, durationSec)
		local handle = {} :: any
		function handle.Release(_: any): ()
			if captured.released then
				return
			end
			captured.released = true
			if ragebotApi.GetForcedTarget() == captured.player then
				ragebotApi.ClearForcedTarget()
			end
			if forcedHandle == captured then
				forcedHandle = nil
			end
		end
		function handle.IsReleased(_: any): boolean
			return captured.released
		end
		function handle.GetPlayer(_: any): Player?
			return captured.player
		end
		return handle
	end

	function api.clearForcedTarget(): ()
		if forcedHandle and not forcedHandle.released then
			forcedHandle.released = true
			forcedHandle = nil
		end
		ragebotApi.ClearForcedTarget()
	end

	function api.getForcedTarget(): Player?
		return ragebotApi.GetForcedTarget()
	end

	if ragebotApi.AddStrafeOverride then
		function api.setStrafeOverride(fn: (any) -> any, priority: number?): RegistrationHandle
			return add("strafe", fn, priority)
		end

		function api.getStrafePosition(): CFrame?
			return ragebotApi.GetStrafePosition()
		end
	end

	return api
end

function luauRagebotApi.Install(ragebotApi: any): ()
	luauApiRegistry.Register("ragebot", function(ctx)
		return build(ragebotApi, ctx)
	end)
end

return luauRagebotApi
