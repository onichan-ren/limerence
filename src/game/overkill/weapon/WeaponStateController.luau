return LPH_JIT_MAX(function()
	local PlayerController = require("@feature/player/PlayerController")
	local NetworkController = require("@game/overkill/network/NetworkController")
	local ModuleController = require("@game/overkill/module/ModuleController")
	local slotKeys = require("@game/overkill/weapon/slotKeys")

	local WeaponStateController = {}

	local DEFAULT_LINGER = 0.75

	local items: any = nil
	local remoteStates: any = nil
	local neuron: any = nil
	local unsubscribe: (() -> ())? = nil
	local dirty: { [Player]: Instance } = {}
	local flushScheduled = false

	local function lookupItem(weaponId: any): any
		if type(weaponId) ~= "string" or weaponId == "" or not items then
			return nil
		end
		return items.all[weaponId]
	end

	local applyDeflect = function(handle: any, ability: any, lastAbility: any): ()
		local hasValue = type(lastAbility) == "number" and lastAbility > 0

		local last = handle._deflectLast
		if last < 0 then
			handle._deflectLast = hasValue and lastAbility or 0
			return
		end

		if not hasValue or lastAbility <= last + 0.0005 then
			return
		end
		handle._deflectLast = lastAbility
		local token = handle._deflectToken + 1
		handle._deflectToken = token

		handle.deflecting(true)
		task.delay(ability.linger or DEFAULT_LINGER, function(): ()
			if handle._deflectToken == token then
				handle.deflecting(false)
			end
		end)
	end

	local apply = function(handle: any, state: { [string]: any }): ()
		local equipped = state.equippedSlot
		local keys = (type(equipped) == "number" and slotKeys[equipped]) or slotKeys[1]

		local weaponId = state[keys.weaponID]
		local mag = state[keys.magCount]
		local reserve = state[keys.reserveCount]

		local item = lookupItem(weaponId)
		local stats = item and item.stats
		local ammoStats = stats and stats.ammo
		local aiming = state.aiming == true

		handle.weaponId(type(weaponId) == "string" and weaponId or "")
		handle.weaponName(item and item.name or "")
		handle.weaponIcon(item and item.icon or "")
		handle.ammo(type(mag) == "number" and mag or 0)
		handle.ammoReserve(type(reserve) == "number" and reserve or 0)
		handle.magSize(ammoStats and ammoStats.magSize or 0)
		handle.aiming(aiming)
		handle.scoped(aiming and item ~= nil and item.category == "sniper_rifle")

		local ability = stats and stats.melee and stats.melee.ability
		if ability and ability.type == "deflect" then
			applyDeflect(handle, ability, state[keys.lastAbilityServerTime])
		end
	end

	local flush = function(): ()
		flushScheduled = false
		setthreadidentity(8)
		local store = remoteStates and remoteStates.store
		if not store then
			table.clear(dirty)
			return
		end
		for player, character in next, dirty do
			local handle = PlayerController.Get(player) :: any
			local state = store[character]
			if handle and type(state) == "table" then
				apply(handle, state)
			end
		end
		table.clear(dirty)
	end

	local onDelta = function(character: any): ()
		if typeof(character) ~= "Instance" then
			return
		end

		local player = neuron and neuron:get_player(character)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end

		dirty[player] = character
		if not flushScheduled then
			flushScheduled = true
			task.defer(flush)
		end
	end

	function WeaponStateController.new(): WeaponStateController
		items = ModuleController.GetModule("items")
		remoteStates = ModuleController.GetModule("remoteWeaponStates")
		neuron = NetworkController.GetNeuron()

		unsubscribe = NetworkController.HookInbound(
			"weapon_state",
			LPH_NO_VIRTUALIZE(function(payload: any): ()
				if type(payload) ~= "table" then
					return
				end
				local player = payload.player
				if typeof(player) ~= "Instance" then
					return
				end
				onDelta(neuron and neuron:get_character(player))
			end)
		)

		return WeaponStateController
	end

	function WeaponStateController.Destroy(): ()
		if unsubscribe then
			unsubscribe()
			unsubscribe = nil
		end
		table.clear(dirty)
		items = nil
		remoteStates = nil
		neuron = nil
	end

	export type WeaponStateController = typeof(WeaponStateController)

	return WeaponStateController
end)()
