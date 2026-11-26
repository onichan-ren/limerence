local Signal = require("@pkg/Signal")
local hook = require("@share/hook")
local ModuleController = require("@game/mvsd/module/ModuleController")

local Players = cloneref(game:GetService("Players")) :: Players
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local LocalPlayer = Players.LocalPlayer

local HIT_WINDOW = 3

local WeaponController = {
	hitPlayer = Signal.new(),
	killedPlayer = Signal.new(),
	shotFired = Signal.new(),
	observedShot = Signal.new(),
	weaponUsed = Signal.new(),
}

local hookedRemotes: { Instance } = {}
local shootGunRemote: RemoteEvent? = nil
local firingDirect = false
local killConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local renderHookTarget: any = nil
local originalRender: any = nil
local suppressLocalRender = false
local observedRenderFilter: ((Player) -> boolean)? = nil
local observedDispatch = false
local observedSuppress = false
local shootTransform: ((origin: Vector3, target: any, hitInstance: any, hitPosition: any) -> (Vector3?, Instance?, Vector3?))? =
	nil
local pendingShot: { redirected: boolean, target: Vector3?, part: Instance?, position: Vector3? }? = nil
local lastHits: { [Player]: { part: BasePart, position: Vector3, time: number } } = setmetatable({}, { __mode = "k" }) :: any

local resolveHitPlayer = LPH_NO_VIRTUALIZE(function(part: any): Player?
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return nil
	end

	local model = part:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end

	return Players:GetPlayerFromCharacter(model)
end)

local recordHit = LPH_NO_VIRTUALIZE(function(part: any, position: any): ()
	local player = resolveHitPlayer(part)
	if not player or player == LocalPlayer then
		return
	end

	lastHits[player] = {
		part = part,
		position = typeof(position) == "Vector3" and position or part.Position,
		time = os.clock(),
	}
end)

local function hookHitRemote(remote: Instance, extract: (...any) -> (any, any)): ()
	hook.addInstance(remote)
	hook.overrideMethod(
		remote,
		"FireServer",
		LPH_NO_VIRTUALIZE(function(...)
			recordHit(extract(...))
			WeaponController.weaponUsed:Fire()
			return ...
		end)
	)
	table.insert(hookedRemotes, remote)
end

function WeaponController.new(): WeaponController
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local shootGun = remotes:WaitForChild("ShootGun") :: RemoteEvent
	shootGunRemote = shootGun
	local stab = remotes:WaitForChild("Stab")
	local throwHit = remotes:WaitForChild("ThrowHit")
	local onPlayerKilled = remotes:WaitForChild("OnPlayerKilled") :: RemoteEvent
	local renderBullet = remotes:WaitForChild("RenderBullet") :: RemoteEvent

	hook.addInstance(shootGun)
	hook.overrideMethod(
		shootGun,
		"FireServer",
		LPH_NO_VIRTUALIZE(function(...)
			local origin, target, hitInstance, hitPosition = ...
			local transform = shootTransform
			local decision = nil
			if not firingDirect then
				decision = pendingShot
				pendingShot = nil
			end
			if transform and not firingDirect and typeof(origin) == "Vector3" then
				if decision then
					if decision.redirected then
						target = decision.target
						hitInstance = decision.part
						hitPosition = decision.position
					end
				else
					local newTarget, newHitInstance, newHitPosition =
						transform(origin, target, hitInstance, hitPosition)
					if newTarget then
						target = newTarget
						hitInstance = newHitInstance
						hitPosition = newHitPosition
					end
				end
			end
			recordHit(hitInstance, hitPosition)
			if typeof(origin) == "Vector3" and typeof(target) == "Vector3" then
				local endPosition = typeof(hitPosition) == "Vector3" and hitPosition or target
				WeaponController.shotFired:Fire(origin, endPosition)
			end
			WeaponController.weaponUsed:Fire()
			return origin, target, hitInstance, hitPosition
		end)
	)
	table.insert(hookedRemotes, shootGun)
	hookHitRemote(
		stab,
		LPH_NO_VIRTUALIZE(function(hitInstance)
			return hitInstance, nil
		end)
	)
	hookHitRemote(
		throwHit,
		LPH_NO_VIRTUALIZE(function(hitInstance, hitPosition)
			return hitInstance, hitPosition
		end)
	)

	local bulletRenderer = ModuleController.GetModule("BulletRenderer")
	if type(bulletRenderer) == "function" then
		renderHookTarget = bulletRenderer
		originalRender = hook.add(
			bulletRenderer,
			LPH_NO_VIRTUALIZE(function(origin, target, ...)
				if observedDispatch then
					if observedSuppress then
						return
					end
					return originalRender(origin, target, ...)
				end

				local transform = shootTransform
				if transform and typeof(origin) == "Vector3" and typeof(target) == "Vector3" then
					local newTarget, newPart, newPosition = transform(origin, target, nil, nil)
					pendingShot = {
						redirected = newTarget ~= nil,
						target = newTarget,
						part = newPart,
						position = newPosition,
					}
					if newTarget then
						target = newTarget
					end
				end

				if suppressLocalRender then
					return
				end
				return originalRender(origin, target, ...)
			end)
		)
	end

	renderConnection =
		renderBullet.OnClientEvent:Connect(LPH_NO_VIRTUALIZE(function(tool: any, origin: any, target: any): ()
			observedDispatch = true
			observedSuppress = false
			task.defer(function(): ()
				observedDispatch = false
			end)

			if typeof(tool) ~= "Instance" or typeof(origin) ~= "Vector3" or typeof(target) ~= "Vector3" then
				return
			end

			local character = tool.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if not player or player == LocalPlayer then
				return
			end

			local filter = observedRenderFilter
			observedSuppress = filter ~= nil and filter(player) == true

			WeaponController.observedShot:Fire(player, origin, target)
		end))

	killConnection = onPlayerKilled.OnClientEvent:Connect(LPH_NO_VIRTUALIZE(function(dead: any, killer: any): ()
		if killer ~= LocalPlayer or dead == LocalPlayer then
			return
		end
		if typeof(dead) ~= "Instance" or not dead:IsA("Player") then
			return
		end

		local entry = lastHits[dead]
		lastHits[dead] = nil

		local part: BasePart? = nil
		local position: Vector3? = nil

		if entry and os.clock() - entry.time <= HIT_WINDOW then
			part = entry.part
			position = entry.position
		else
			local character = dead.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				part = hrp
				position = hrp.Position
			end
		end

		if not part or not position then
			WeaponController.killedPlayer:Fire(dead)
			return
		end

		WeaponController.hitPlayer:Fire(dead, part, position)
		WeaponController.killedPlayer:Fire(dead)
	end))

	return WeaponController
end

function WeaponController.FireShot(origin: Vector3, target: Vector3, hitInstance: Instance?, hitPosition: Vector3?): ()
	local remote = shootGunRemote
	if not remote then
		return
	end

	firingDirect = true
	remote:FireServer(origin, target, hitInstance, hitPosition)
	firingDirect = false
end

function WeaponController.SetShootTransform(transform: ((
	origin: Vector3,
	target: any,
	hitInstance: any,
	hitPosition: any
) -> (Vector3?, Instance?, Vector3?))?): ()
	shootTransform = transform
	pendingShot = nil
end

function WeaponController.SetLocalRenderSuppressed(suppressed: boolean): ()
	suppressLocalRender = suppressed
end

function WeaponController.SetObservedRenderFilter(filter: ((Player) -> boolean)?): ()
	observedRenderFilter = filter
	observedSuppress = false
end

function WeaponController.Destroy(): ()
	if killConnection then
		killConnection:Disconnect()
		killConnection = nil
	end

	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end

	if renderHookTarget then
		hook.restore(renderHookTarget)
		renderHookTarget = nil
		originalRender = nil
	end
	suppressLocalRender = false
	observedRenderFilter = nil
	observedDispatch = false
	observedSuppress = false
	shootTransform = nil
	pendingShot = nil
	shootGunRemote = nil
	firingDirect = false

	for _, remote in next, hookedRemotes do
		hook.restoreInstance(remote)
	end
	table.clear(hookedRemotes)
	table.clear(lastHits)
end

export type WeaponController = typeof(WeaponController)

return WeaponController
