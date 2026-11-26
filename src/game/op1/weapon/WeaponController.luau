local Signal = require("@pkg/Signal")
local Charm = require("@pkg/Charm")
local ModuleController = require("@game/op1/module/ModuleController")
local clientState = require("@game/op1/client/clientState")
local PlayerController = require("@feature/player/PlayerController")
local hook = require("@share/hook")

local peek = Charm.peek

local OWNERSHIP_TEAM = 2
local HEAD_PART = "head"
local TORSO_PART = "torso"
local HEAD_MULT = 2
local LIMB_MULT = 0.5
local BODY_MULT = 1

local WeaponController = {
	shotFired = Signal.new() :: Signal.Signal<Vector3, { any }, string>,
	hitPlayer = Signal.new() :: Signal.Signal<Player, Instance, Vector3, boolean, boolean>,
	damageDealt = Signal.new() :: Signal.Signal<Player, Instance, Vector3, number, boolean, boolean>,
	_shootFn = nil :: any,
	_util = nil :: any,
}

local function resolvePlayer(instance: any): (Player?, any)
	if typeof(instance) ~= "Instance" then
		return nil, nil
	end

	local name = instance.Name

	for player, basePlayer in next, PlayerController.GetAll() do
		local parts = peek((basePlayer :: any).parts)
		if parts and parts[name] == instance then
			return player, basePlayer
		end
	end

	return nil, nil
end

local function partMultiplier(name: string): number
	if name == HEAD_PART then
		return HEAD_MULT
	elseif name == TORSO_PART then
		return BODY_MULT
	end
	return LIMB_MULT
end

local function getBaseDamage(gun: any): number
	local states = gun and gun.states
	local damageState = states and states.damage
	if damageState and type(damageState.get) == "function" then
		local value = damageState:get()
		if type(value) == "number" then
			return value
		end
	end

	local stats = gun and gun.stats
	if stats and type(stats.damage) == "number" then
		return stats.damage
	end

	return 0
end

local fireHits = LPH_NO_VIRTUALIZE(function(gun: any, hits: any): ()
	local baseDamage = getBaseDamage(gun)
	local seen: { [Player]: { part: Instance, position: Vector3, head: boolean, damage: number, basePlayer: any } } = {}

	for _, pellet in next, hits do
		if type(pellet) == "table" then
			for _, hit in next, pellet do
				if type(hit) == "table" and hit.HitHum then
					local instance = hit.Instance
					local position = hit.Position

					if typeof(position) == "Vector3" then
						local player, basePlayer = resolvePlayer(instance)

						if player then
							local name = instance.Name
							local head = name == HEAD_PART
							local damage = baseDamage * partMultiplier(name)
							local existing = seen[player]

							if not existing then
								seen[player] =
									{ part = instance, position = position, head = head, damage = damage, basePlayer = basePlayer }
							else
								existing.damage += damage
								if head and not existing.head then
									existing.part = instance
									existing.position = position
									existing.head = true
								end
							end
						end
					end
				end
			end
		end
	end

	for player, info in next, seen do
		local basePlayer = info.basePlayer
		local isEnemy = basePlayer ~= nil and basePlayer:IsEnemy() or false

		WeaponController.hitPlayer:Fire(player, info.part, info.position, info.head, isEnemy)

		if info.damage > 0 then
			WeaponController.damageDealt:Fire(player, info.part, info.position, info.damage, info.head, isEnemy)
		end
	end
end)

local function relationOf(owner: any): string
	if owner == peek(clientState.charObject) then
		return "local"
	end

	local util = WeaponController._util
	local ownerState = owner.owner
	local player = ownerState and ownerState:get()

	if util and player then
		setthreadidentity(2)
		local value = util.ownership(player)
		setthreadidentity(8)

		if value == OWNERSHIP_TEAM then
			return "friendly"
		end
	end

	return "enemy"
end

function WeaponController.new(): WeaponController
	WeaponController._util = ModuleController.GetModule("Util")

	local gun = ModuleController.GetModule("Gun")
	local shootFn = gun and gun.shoot

	if shootFn then
		WeaponController._shootFn = shootFn

		local old
		old = hook.add(shootFn, function(gunSelf: any, owner: any, look: any, hits: any, ...)
			setthreadidentity(8)

			if type(hits) == "table" and owner then
				local relation = relationOf(owner)
				local shot = gunSelf.shot
				local cframe = shot and shot.CFrame

				if cframe then
					WeaponController.shotFired:Fire(cframe.Position, hits, relation)
				end

				if relation == "local" then
					fireHits(gunSelf, hits)
				end
			end

			setthreadidentity(2)
			return old(gunSelf, owner, look, hits, ...)
		end)
	end

	return WeaponController
end

function WeaponController.Destroy(): ()
	if WeaponController._shootFn then
		hook.restore(WeaponController._shootFn)
		WeaponController._shootFn = nil
	end

	(WeaponController.shotFired :: any):DisconnectAll();
	(WeaponController.hitPlayer :: any):DisconnectAll();
	(WeaponController.damageDealt :: any):DisconnectAll()
end

export type WeaponController = typeof(WeaponController)

return WeaponController
