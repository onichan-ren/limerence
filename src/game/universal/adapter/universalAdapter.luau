return LPH_JIT_MAX(function()
	local Charm = require("@pkg/Charm")
	local Signal = require("@pkg/Signal")
	local localState = require("@game/universal/client/localState")
	
	local at = Charm.atom
	local peek = Charm.peek
	local sub = Charm.subscribe
	
	export type CharacterResolver = (player: Player) -> Model?
	export type PartsResolver = (character: Model, player: Player) -> { [string]: Instance }?
	export type TeamResolver = (player: Player) -> string?
	export type HealthResolver = (player: Player) -> (number?, number?)
	export type AliveResolver = (player: Player) -> boolean?
	export type WeaponResolver = () -> any?
	export type WeaponPredicate = (weapon: any) -> boolean
	export type FireFn = (weapon: any) -> ()
	export type EspFilter = (player: Player) -> boolean
	
	export type Overrides = {
		resolveCharacter: CharacterResolver?,
		resolveParts: PartsResolver?,
		resolveTeam: TeamResolver?,
		resolveHealth: HealthResolver?,
		resolveAlive: AliveResolver?,
		resolveLocalTeam: (() -> string?)?,
		resolveLocalAlive: (() -> boolean)?,
		resolveWeapon: WeaponResolver?,
		canShoot: WeaponPredicate?,
		canFire: WeaponPredicate?,
		fire: FireFn?,
		stopFire: (() -> ())?,
		espFilter: EspFilter?,
		hitboxParts: { [string]: { string } }?,
	}
	
	local universalAdapter = {
		overrides = {} :: Overrides,
		equippedWeapon = at(nil :: any) :: Charm.Atom<any>,
		playersChanged = Signal.new() :: Signal.Signal<Player?>,
		_autoWeapon = true,
		_unsubParts = nil :: (() -> ())?,
	}
	
	local REFRESH_SLOTS: { [string]: boolean } = {
		resolveCharacter = true,
		resolveParts = true,
		resolveTeam = true,
		resolveHealth = true,
		resolveAlive = true,
	}
	
	function universalAdapter.SetOverride(slot: string, fn: any): ()
		(universalAdapter.overrides :: any)[slot] = fn
		if REFRESH_SLOTS[slot] then
			universalAdapter.playersChanged:Fire(nil)
		end
	end
	
	function universalAdapter.Refresh(player: Player?): ()
		universalAdapter.playersChanged:Fire(player)
	end
	
	local function findEquippedTool(): Tool?
		local parts = peek(localState.parts)
		for _, child in next, parts do
			if child:IsA("Tool") then
				return child
			end
		end
		return nil
	end
	
	function universalAdapter.SetWeapon(weapon: any): ()
		universalAdapter._autoWeapon = false
		universalAdapter.equippedWeapon(weapon)
	end
	
	function universalAdapter.ClearWeapon(): ()
		universalAdapter._autoWeapon = true
		universalAdapter.equippedWeapon(findEquippedTool())
	end
	
	function universalAdapter.GetEquippedWeapon(): any?
		local resolver = universalAdapter.overrides.resolveWeapon
		if resolver then
			return resolver()
		end
		return peek(universalAdapter.equippedWeapon)
	end
	
	function universalAdapter.CanShoot(weapon: any): boolean
		local override = universalAdapter.overrides.canShoot
		if override then
			return override(weapon)
		end
		if typeof(weapon) == "Instance" and weapon:IsA("Tool") then
			return weapon.Enabled
		end
		return true
	end
	
	function universalAdapter.GetHitboxParts(hitboxName: string): { string }?
		local map = universalAdapter.overrides.hitboxParts
		return map and map[hitboxName]
	end
	
	function universalAdapter.setup(): ()
		if universalAdapter._unsubParts then
			return
		end
		universalAdapter._unsubParts = sub(localState.parts, function(): ()
			if not universalAdapter._autoWeapon then
				return
			end
			local tool = findEquippedTool()
			if peek(universalAdapter.equippedWeapon) ~= tool then
				universalAdapter.equippedWeapon(tool)
			end
		end)
	end
	
	function universalAdapter.Destroy(): ()
		local unsub = universalAdapter._unsubParts
		if unsub then
			unsub()
			universalAdapter._unsubParts = nil
		end
		table.clear(universalAdapter.overrides :: any)
		universalAdapter._autoWeapon = true
		universalAdapter.equippedWeapon(nil)
	end
	
	export type universalAdapter = typeof(universalAdapter)
	
	return universalAdapter	
end)()