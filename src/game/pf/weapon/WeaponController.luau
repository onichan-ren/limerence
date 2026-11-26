return LPH_JIT_MAX(function()
	local Charm = require("@pkg/Charm")
	local Signal = require("@pkg/Signal")
	local ModuleController = require("@game/pf/module/ModuleController")
	local NetworkController = require("@game/pf/network/NetworkController")
	local PlayerController = require("@feature/player/PlayerController")
	local hook = require("@share/hook")

	local LocalPlayer = (cloneref(game:GetService("Players")) :: Players).LocalPlayer

	local at = Charm.atom
	local peek = Charm.peek

	local EQUIP_CLASSES: { string } = { "FirearmObject", "MeleeObject", "GrenadeObject" }

	local WeaponController = {
		_equipTargets = {} :: { (...any) -> any },
		_hitTarget = nil :: any,
		_diedUnhook = nil :: (() -> ())?,
		_character = nil :: any,
		_weaponUtils = nil :: any,
		_publicSettings = nil :: any,
		_replication = nil :: any,
		hitPlayer = Signal.new() :: Signal.Signal<Player, Instance, string, Vector3, number, boolean>,
		killedPlayer = Signal.new() :: Signal.Signal<Player, Vector3?>,
		state = {
			equipped = at(false) :: Charm.Atom<boolean>,
			weaponName = at("") :: Charm.Atom<string>,
			weaponType = at("") :: Charm.Atom<string>,
			aiming = at(false) :: Charm.Atom<boolean>,
			scoped = at(false) :: Charm.Atom<boolean>,
			reloading = at(false) :: Charm.Atom<boolean>,
			chambering = at(false) :: Charm.Atom<boolean>,
			inspecting = at(false) :: Charm.Atom<boolean>,
			canFire = at(false) :: Charm.Atom<boolean>,
			magCount = at(0) :: Charm.Atom<number>,
			spareCount = at(0) :: Charm.Atom<number>,
			magSize = at(0) :: Charm.Atom<number>,
			firemode = at("") :: Charm.Atom<string>,
		},
	}

	local state = WeaponController.state

	local function fetchActiveWeapon(ci: any): any?
		local co = ci.getCharacterObject()
		if not co then
			return nil
		end
		local wc = co:getWeaponController()
		return wc and wc:getActiveWeapon()
	end

	local function getActiveWeapon(): any?
		local ci = WeaponController._character or ModuleController.GetModule("CharacterInterface")
		if not ci then
			return nil
		end
		WeaponController._character = ci
		return fetchActiveWeapon(ci)
	end

	local computeScoped = LPH_NO_VIRTUALIZE(function(weapon: any): boolean
		if weapon:getActiveAimStat("blackscope") == true then
			return weapon:isBlackScoped() == true
		end
		if weapon:getActiveAimStat("midscope") == true then
			return weapon:isAiming() == true
		end
		return false
	end)

	local function reset(): ()
		state.equipped(false)
		state.weaponName("")
		state.weaponType("")
		state.aiming(false)
		state.scoped(false)
		state.reloading(false)
		state.chambering(false)
		state.inspecting(false)
		state.canFire(false)
		state.magCount(0)
		state.spareCount(0)
		state.magSize(0)
		state.firemode("")
	end

	local applyWeaponState = LPH_NO_VIRTUALIZE(function(weapon: any): ()
		local weaponType = weapon:getWeaponType()
		state.weaponType(weaponType or "")
		state.weaponName(weapon.weaponName or "")
		state.equipped(weapon:isEquipped() == true)

		if weaponType ~= "Firearm" then
			state.aiming(false)
			state.scoped(false)
			state.reloading(false)
			state.chambering(false)
			state.inspecting(false)
			state.canFire(false)
			state.magCount(0)
			state.spareCount(0)
			state.magSize(0)
			state.firemode("")
			return
		end

		state.aiming(weapon:isAiming() == true)
		state.scoped(computeScoped(weapon) == true)
		state.reloading(weapon:isReloading() == true)
		state.chambering(weapon:isChambering() == true)
		state.inspecting(weapon:isInspecting() == true)
		state.canFire(weapon:canFire() == true)
		state.magCount(weapon:getMagCount() or 0)
		state.spareCount(weapon:getSpareCount() or 0)
		state.magSize(weapon:getWeaponStat("magsize") or 0)
		state.firemode(weapon:getFiremodeString() or "")
	end)

	local refresh = LPH_NO_VIRTUALIZE(function(): ()
		local weapon = getActiveWeapon()
		if not weapon then
			reset()
			return
		end
		applyWeaponState(weapon)
	end)

	local function activeFirearm(): any?
		local weapon = getActiveWeapon()
		if weapon and weapon:getWeaponType() == "Firearm" then
			return weapon
		end
		return nil
	end

	local function computeDamageInner(
		firearm: any,
		weaponUtils: any,
		origin: Vector3,
		partName: string,
		position: Vector3
	): number
		local magnitude = (origin - position).Magnitude
		local graph = firearm:getWeaponStat("damageGraph")
		local base = weaponUtils.interpolateDamageGraph(graph, magnitude)
		if partName == "Head" then
			return base * firearm:getWeaponStat("multhead")
		elseif partName == "Torso" then
			return base * firearm:getWeaponStat("multtorso")
		end
		return base * (firearm:getWeaponStat("multlimb") or 1)
	end

	local computeDamage = LPH_NO_VIRTUALIZE(function(bullet: any, partName: string, position: Vector3): number
		local extra = bullet and bullet.extra
		local firearm = extra and extra.firearmObject
		if not firearm then
			return 0
		end
		local weaponUtils = WeaponController._weaponUtils or ModuleController.GetModule("WeaponUtils")
		if not weaponUtils then
			return 0
		end
		WeaponController._weaponUtils = weaponUtils
		local damage = computeDamageInner(firearm, weaponUtils, bullet.origin, partName, position)
		if type(damage) == "number" then
			return damage
		end
		return 0
	end)

	local processHit = LPH_NO_VIRTUALIZE(function(p1: any, p2: any, p3: any, p4: any, p5: any): ()
		if typeof(p2) ~= "Instance" or not p2:IsA("Player") then
			return
		end
		if typeof(p3) ~= "Instance" or not p3.Parent then
			return
		end
		if p2.TeamColor == LocalPlayer.TeamColor then
			return
		end
		local partName = type(p4) == "string" and p4 or p3.Name
		local position = typeof(p5) == "Vector3" and p5 or (p3 :: BasePart).Position
		local damage = computeDamage(p1, partName, position)
		local id = getthreadidentity()
		setthreadidentity(8)
		WeaponController.hitPlayer:Fire(p2, p3, partName, position, damage, partName == "Head")
		setthreadidentity(id)
	end)

	local function setupHitHook(): ()
		local hitDetection = ModuleController.GetModule("HitDetectionInterface")
		if not hitDetection or not hitDetection.playerHitDection then
			return
		end
		WeaponController._hitTarget = hitDetection.playerHitDection

		local original
		original = hook.add(
			hitDetection.playerHitDection,
			LPH_NO_VIRTUALIZE(function(p1: any, p2: any, p3: any, p4: any, p5: any, p6: any): ...any
				local result = { original(p1, p2, p3, p4, p5, p6) }
				processHit(p1, p2, p3, p4, p5)
				return table.unpack(result)
			end)
		)
	end

	local function setupDiedHook(): ()
		WeaponController._diedUnhook = NetworkController.HookInbound(
			"died",
			LPH_NO_VIRTUALIZE(function(payload: any): ()
				if type(payload) ~= "table" then
					return
				end
				if payload.attacker ~= LocalPlayer or payload.forced then
					return
				end
				local victim = payload.victim
				if typeof(victim) ~= "Instance" or not victim:IsA("Player") then
					return
				end
				local position: Vector3? = nil
				local playerData = PlayerController.Get(victim)
				if playerData then
					local hrp = peek((playerData :: any).hrp)
					if typeof(hrp) == "Instance" then
						position = (hrp :: BasePart).Position
					end
				end
				local id = getthreadidentity()
				setthreadidentity(8)
				WeaponController.killedPlayer:Fire(victim, position)
				setthreadidentity(id)
			end)
		)
	end

	local function setupEquipHooks(): ()
		for i = 1, #EQUIP_CLASSES do
			local class = ModuleController.GetModule(EQUIP_CLASSES[i])
			if not class or type(class.equip) ~= "function" then
				continue
			end
			local target = class.equip
			local original
			original = hook.add(
				target,
				LPH_NO_VIRTUALIZE(function(self: any, ...): ...any
					local results = { original(self, ...) }
					if self then
						applyWeaponState(self)
					else
						refresh()
					end
					return table.unpack(results)
				end)
			)
			WeaponController._equipTargets[#WeaponController._equipTargets + 1] = target
		end
	end

	function WeaponController.new(): WeaponController
		setupHitHook()
		setupDiedHook()
		setupEquipHooks()
		refresh()
		return WeaponController
	end

	function WeaponController.GetWeapon(): any?
		return getActiveWeapon()
	end

	function WeaponController.GetWeaponName(): string
		local name = peek(state.weaponName)
		if name ~= "" then
			return name
		end
		local weapon = getActiveWeapon()
		return weapon and weapon.weaponName or ""
	end

	function WeaponController.GetWeaponType(): string
		local weapon = getActiveWeapon()
		return weapon and weapon:getWeaponType() or ""
	end

	function WeaponController.IsEquipped(): boolean
		local weapon = getActiveWeapon()
		return weapon ~= nil and weapon:isEquipped() == true
	end

	function WeaponController.IsAiming(): boolean
		local weapon = activeFirearm()
		return weapon ~= nil and weapon:isAiming() == true
	end

	function WeaponController.IsScoped(): boolean
		local weapon = activeFirearm()
		return weapon ~= nil and computeScoped(weapon) == true
	end

	function WeaponController.IsReloading(): boolean
		local weapon = activeFirearm()
		return weapon ~= nil and weapon:isReloading() == true
	end

	function WeaponController.IsChambering(): boolean
		local weapon = activeFirearm()
		return weapon ~= nil and weapon:isChambering() == true
	end

	function WeaponController.IsInspecting(): boolean
		local weapon = activeFirearm()
		return weapon ~= nil and weapon:isInspecting() == true
	end

	function WeaponController.CanFire(): boolean
		local weapon = activeFirearm()
		return weapon ~= nil and weapon:canFire() == true
	end

	function WeaponController.GetMagCount(): number
		local weapon = activeFirearm()
		return weapon and weapon:getMagCount() or 0
	end

	function WeaponController.GetSpareCount(): number
		local weapon = activeFirearm()
		return weapon and weapon:getSpareCount() or 0
	end

	function WeaponController.GetMagSize(): number
		local weapon = activeFirearm()
		return weapon and weapon:getWeaponStat("magsize") or 0
	end

	function WeaponController.GetFiremode(): string
		local weapon = activeFirearm()
		return weapon and weapon:getFiremodeString() or ""
	end

	function WeaponController.GetWeaponStat(name: string): any
		local weapon = getActiveWeapon()
		if not weapon then
			return nil
		end
		return weapon:getWeaponStat(name)
	end

	function WeaponController.GetGravity(): Vector3
		local ps = WeaponController._publicSettings or ModuleController.GetModule("PublicSettings")
		if not ps then
			return Vector3.zero
		end
		WeaponController._publicSettings = ps
		local gravity = rawget(ps, "bulletAcceleration")
		return typeof(gravity) == "Vector3" and gravity or Vector3.zero
	end

	export type FireStats = {
		speed: number,
		accel: number,
		penetration: number,
	}

	function WeaponController.ComputeDamage(firearm: any, origin: Vector3, partName: string, position: Vector3): number
		if not firearm then
			return 0
		end
		local weaponUtils = WeaponController._weaponUtils or ModuleController.GetModule("WeaponUtils")
		if not weaponUtils then
			return 0
		end
		WeaponController._weaponUtils = weaponUtils
		local damage = computeDamageInner(firearm, weaponUtils, origin, partName, position)
		return type(damage) == "number" and damage or 0
	end

	function WeaponController.GetLocalFireStats(): FireStats?
		local weapon = getActiveWeapon()
		if not weapon then
			return nil
		end
		local speed = weapon:getWeaponStat("bulletspeed")
		if type(speed) ~= "number" then
			return nil
		end
		local accel = weapon:getWeaponStat("bulletaccel")
		local penetration = weapon:getWeaponStat("penetrationdepth")
		return {
			speed = speed,
			accel = type(accel) == "number" and accel or 0,
			penetration = type(penetration) == "number" and penetration or 0,
		}
	end

	local function fetchPlayerPenetration(rep: any, player: Player, index: any): number?
		local entry = rep.getEntry(player)
		if not entry then
			return nil
		end
		local weaponObject = entry:getWeaponObject(index)
		local weaponData = weaponObject and weaponObject.weaponData
		return weaponData and weaponData.penetrationdepth
	end

	function WeaponController.GetPlayerPenetration(player: Player, index: any): number?
		local rep = WeaponController._replication or ModuleController.GetModule("ReplicationInterface")
		if not rep then
			return nil
		end
		WeaponController._replication = rep
		local value = fetchPlayerPenetration(rep, player, index)
		if type(value) == "number" then
			return value
		end
		return nil
	end

	function WeaponController.Destroy(): ()
		local equipTargets = WeaponController._equipTargets
		for i = #equipTargets, 1, -1 do
			hook.restore(equipTargets[i])
			equipTargets[i] = nil
		end
		if WeaponController._hitTarget then
			hook.restore(WeaponController._hitTarget)
			WeaponController._hitTarget = nil
		end
		if WeaponController._diedUnhook then
			WeaponController._diedUnhook()
			WeaponController._diedUnhook = nil
		end
		WeaponController._character = nil
		WeaponController._weaponUtils = nil
		WeaponController._publicSettings = nil
		WeaponController._replication = nil
		reset()
	end

	export type WeaponController = typeof(WeaponController)

	return WeaponController
end)()
