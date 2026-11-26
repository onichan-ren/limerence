local Charm = require("@pkg/Charm")
local Players = cloneref(game:GetService("Players")) :: Players

local legitbotApi = require("@game/universal/feature/combat/legitbot/legitbotApi")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")

local peek = Charm.peek

export type RegistrationHandle = luauApiRegistry.RegistrationHandle

export type ForceTargetHandle = {
	Release: (self: ForceTargetHandle) -> (),
	IsReleased: (self: ForceTargetHandle) -> boolean,
	GetPlayer: (self: ForceTargetHandle) -> Player?,
}

type RegistrationKind = "filter" | "gate" | "transform"

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

local luauLegitbotApi = {}

luauApiRegistry.Register("legitbot", function(ctx)
	local onUnload = ctx.onUnload

	local registry = luauApiRegistry.CreateRegistry(onUnload)
	local forcedHandle: { player: Player?, released: boolean }? = nil

	local function add(kind: RegistrationKind, fn: any, priority: number?): RegistrationHandle
		if type(fn) ~= "function" then
			local method = (kind == "filter" and "addTargetFilter" or kind == "gate" and "addShotGate" or "addAimTransform")
			error(`api.legitbot.{method}: callback must be a function`, 3)
		end
		local p = priority or 0
		local addFn: any
		local removeFn: any
		if kind == "filter" then
			addFn, removeFn = legitbotApi.AddTargetFilter, legitbotApi.RemoveTargetFilter
		elseif kind == "gate" then
			addFn, removeFn = legitbotApi.AddShotGate, legitbotApi.RemoveShotGate
		else
			addFn, removeFn = legitbotApi.AddAimTransform, legitbotApi.RemoveAimTransform
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
			if legitbotApi.GetForcedTarget() == forcedHandle.player then
				legitbotApi.ClearForcedTarget()
			end
			forcedHandle = nil
		end
	end)

	local api = {}

	local wrap = luauApiRegistry.WrapSignal
	api.onShotFired = wrap(legitbotApi.signals.onShotFired, onUnload)
	api.onTargetAcquired = wrap(legitbotApi.signals.onTargetAcquired, onUnload)
	api.onTargetLost = wrap(legitbotApi.signals.onTargetLost, onUnload)
	api.onTriggerArmed = wrap(legitbotApi.signals.onTriggerArmed, onUnload)
	api.onTriggerDisarmed = wrap(legitbotApi.signals.onTriggerDisarmed, onUnload)
	api.onScopeChanged = wrap(legitbotApi.signals.onScopeChanged, onUnload)
	api.onMagnetPull = wrap(legitbotApi.signals.onMagnetPull, onUnload)

	function api.getTarget(): { player: Player, part: BasePart?, hitbox: string? }?
		local player = peek(legitbotApi.state.activeTarget)
		if not player then
			return nil
		end
		return {
			player = player,
			part = peek(legitbotApi.state.activeTargetPart),
			hitbox = peek(legitbotApi.state.activeTargetHitbox),
		}
	end

	function api.getTriggerTarget(): { player: Player, part: BasePart?, hitbox: string? }?
		local player = peek(legitbotApi.state.triggerTarget)
		if not player then
			return nil
		end
		return {
			player = player,
			part = peek(legitbotApi.state.triggerTargetPart),
			hitbox = peek(legitbotApi.state.triggerTargetHitbox),
		}
	end

	function api.getValidTargets(): { legitbotApi.TargetSnapshot }
		return legitbotApi.GetValidTargets()
	end

	function api.getActiveScope(): string
		return peek(legitbotApi.state.activeScope)
	end

	function api.getResolvedValue(key: string, scopeId: string?): any
		if type(key) ~= "string" then
			error("api.legitbot.getResolvedValue: key must be a string", 2)
		end
		return legitbotApi.GetResolvedValue(key, scopeId)
	end

	function api.isFiring(): boolean
		return legitbotApi.IsFiring()
	end

	function api.getBurstRemaining(): number?
		return peek(legitbotApi.state.burstRemaining)
	end

	function api.getLastShotTime(): number?
		return peek(legitbotApi.state.lastShotAt)
	end

	function api.addTargetFilter(
		fn: (Player, legitbotApi.TargetFilterContext) -> boolean,
		priority: number?
	): RegistrationHandle
		return add("filter", fn, priority)
	end

	function api.addShotGate(fn: (legitbotApi.ShotGateContext) -> boolean, priority: number?): RegistrationHandle
		return add("gate", fn, priority)
	end

	function api.addAimTransform(
		fn: (legitbotApi.AimTransformContext) -> Vector3?,
		priority: number?
	): RegistrationHandle
		return add("transform", fn, priority)
	end

	function api.forceTarget(player: any, durationSec: number?): ForceTargetHandle?
		local resolved = resolvePlayer(player)
		if not resolved then
			return nil
		end
		if forcedHandle and not forcedHandle.released then
			forcedHandle.released = true
			if legitbotApi.GetForcedTarget() == forcedHandle.player then
				legitbotApi.ClearForcedTarget()
			end
		end
		forcedHandle = { player = resolved, released = false }
		local captured = forcedHandle
		legitbotApi.SetForcedTarget(resolved, durationSec)
		local handle = {} :: any
		function handle.Release(_: any): ()
			if captured.released then
				return
			end
			captured.released = true
			if legitbotApi.GetForcedTarget() == captured.player then
				legitbotApi.ClearForcedTarget()
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
		legitbotApi.ClearForcedTarget()
	end

	function api.requestShot(): ()
		legitbotApi.RequestShot()
	end

	return api
end)

return luauLegitbotApi
