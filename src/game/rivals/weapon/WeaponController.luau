return LPH_JIT_MAX(function()
	local Players = cloneref(game:GetService("Players")) :: Players
	local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

	local Charm = require("@pkg/Charm")
	local Janitor = require("@pkg/Janitor")
	local Signal = require("@pkg/Signal")
	local hook = require("@share/hook")
	local ModuleController = require("@game/rivals/module/ModuleController")
	local viewmodelState = require("@game/rivals/viewmodel/viewmodelState")
	local ClientState = require("@game/rivals/client/clientState")

	local at = Charm.atom
	local peek = Charm.peek

	local LocalPlayer = Players.LocalPlayer

	local DEFAULT_SHOOT_COOLDOWN = 0.08
	local BUSY_COOLDOWN_FRACTION = 1

	local USE_ITEM_START_KEY = utf8.char(0)
	local USE_ITEM_PART_KEY = utf8.char(2)
	local USE_ITEM_HIT_KEY = utf8.char(3)
	local MELEE_REACH_PAD = 3
	local MELEE_REACH_FALLBACK = 8
	local CF_KEY_X, CF_KEY_Y, CF_KEY_Z = utf8.char(0), utf8.char(1), utf8.char(2)
	local CF_KEY_RX, CF_KEY_RY, CF_KEY_RZ = utf8.char(3), utf8.char(4), utf8.char(5)
	local SHOOT_EFFECT_INSTANCE_KEY = utf8.char(1)

	local WeaponController = {
		item = at(nil :: any),
		name = at(nil :: string?),
		class = at(nil :: string?),
		info = at(nil :: any),
		ammo = at(0),
		ammoReserve = at(0),
		maxAmmo = at(0),
		maxAmmoReserve = at(0),
		isBusy = at(false),
		reloading = at(false),

		hitPlayer = Signal.new() :: Signal.Signal<Player, boolean>,
		killedPlayer = Signal.new() :: Signal.Signal<Player>,
		hitTarget = Signal.new() :: Signal.Signal<Model, BasePart>,
		hitDealt = Signal.new() :: Signal.Signal<boolean>,
		shotFired = Signal.new() :: Signal.Signal<{ Vector3 }>,
		gunTracer = Signal.new() :: Signal.Signal<{ { Vector3 } }>,

		_lastFireTime = 0,
		_busyToken = 0,
		_firing = false,
		_selfFiring = false,
		_fireToken = 0,
		_janitor = nil :: Janitor.Janitor?,
		_fighterJanitor = nil :: Janitor.Janitor?,
		_itemJanitor = nil :: Janitor.Janitor?,
		_useItemRemote = nil :: Instance?,
		_crosshairVisualHook = nil :: ((...any) -> any)?,
		_crosshairVisualOriginal = nil :: ((...any) -> any)?,
		_hitmarkerSoundHook = nil :: ((...any) -> any)?,
		_eliminationFeedHook = nil :: ((...any) -> any)?,
		_gunTracerHook = nil :: ((...any) -> any)?,
		_gunShootEffectHook = nil :: ((...any) -> any)?,
		_suppressGameHit = false,
		_suppressHitmarkerSound = false,
		_impactCallbacks = {} :: { (BasePart) -> BasePart },
		_shotManipulators = {} :: { (cameraData: any) -> () },
	}

	local runShotManipulators = LPH_NO_VIRTUALIZE(function(manipulators: { (cameraData: any) -> () }, payload: any)
		for i = 1, #manipulators do
			manipulators[i](payload)
		end
	end)

	local function getShootCooldown(): number
		local info = peek(WeaponController.info)
		if type(info) == "table" and type(info.ShootCooldown) == "number" and info.ShootCooldown > 0 then
			return info.ShootCooldown
		end
		return DEFAULT_SHOOT_COOLDOWN
	end

	function WeaponController.GetLocalFighter(): any?
		local fc = ModuleController.GetModule("FighterController")
		if not fc then
			return nil
		end
		local map = rawget(fc, "_player_to_fighter")
		if type(map) ~= "table" then
			return nil
		end
		return map[LocalPlayer]
	end

	function WeaponController.IsGun(): boolean
		return peek(WeaponController.class) == "Gun"
	end

	function WeaponController.IsMelee(): boolean
		return peek(WeaponController.class) == "Melee"
	end

	function WeaponController.IsProjectile(): boolean
		local info = peek(WeaponController.info)
		return type(info) == "table" and info.IsProjectile == true
	end

	function WeaponController.HasAmmo(): boolean
		return peek(WeaponController.ammo) > 0
	end

	local function isReloadCooldownActive(): boolean
		local item = peek(WeaponController.item)
		if not item then
			return false
		end
		local now = tick()
		if now >= item._reload_cooldown then
			return false
		end
		return now < item._reload_cancel_cooldown or now >= item._reload_cancel_expiration
	end

	function WeaponController.CanShoot(): boolean
		if not WeaponController.IsGun() then
			return false
		end
		if peek(WeaponController.ammo) <= 0 then
			return false
		end
		if isReloadCooldownActive() then
			return false
		end
		return true
	end

	function WeaponController.CanFire(): boolean
		if not WeaponController.CanShoot() then
			return false
		end
		if peek(WeaponController.isBusy) then
			return false
		end
		return true
	end

	function WeaponController.NotifyFired(): ()
		WeaponController._lastFireTime = tick()
		WeaponController.isBusy(true)

		WeaponController._busyToken += 1
		local token = WeaponController._busyToken
		local cooldown = getShootCooldown() * BUSY_COOLDOWN_FRACTION
		task.delay(cooldown, function(): ()
			if WeaponController._busyToken ~= token then
				return
			end
			WeaponController.isBusy(false)
		end)
	end

	function WeaponController.StopFire(): ()
		if not WeaponController._firing then
			return
		end
		WeaponController._firing = false
		WeaponController._fireToken += 1
		mouse1release()
	end

	function WeaponController.Fire(): boolean
		if not WeaponController.CanFire() then
			return false
		end
		local fighter = WeaponController.GetLocalFighter()
		if not fighter then
			return false
		end
		mouse1press()
		WeaponController._firing = true
		WeaponController._fireToken += 1
		local token = WeaponController._fireToken
		local hold = getShootCooldown() * 0.5
		task.delay(hold, function(): ()
			if WeaponController._fireToken ~= token or not WeaponController._firing then
				return
			end
			WeaponController._firing = false
			mouse1release()
		end)
		WeaponController.NotifyFired()
		return true
	end

	local function sendItemInput(name: string): boolean
		local mechanics = ModuleController.GetModule("MechanicsController")
		if not mechanics or not rawget(mechanics, "LocalFighter") then
			return false
		end
		local input = mechanics.EquippedItemInput
		if type(input) ~= "function" then
			return false
		end
		local identity = getthreadidentity()
		setthreadidentity(2)
		input(mechanics, name)
		setthreadidentity(identity)
		return true
	end

	setstackhidden(sendItemInput :: any, true)

	function WeaponController.FireInput(): boolean
		if not WeaponController.CanFire() then
			return false
		end
		WeaponController._selfFiring = true
		local started = sendItemInput("StartShooting")
		WeaponController._selfFiring = false
		if not started then
			return false
		end
		WeaponController._fireToken += 1
		local token = WeaponController._fireToken
		task.delay(0.03, function(): ()
			if WeaponController._fireToken ~= token then
				return
			end
			sendItemInput("FinishShooting")
		end)
		WeaponController.NotifyFired()
		return true
	end

	function WeaponController.Deflect(): boolean
		return sendItemInput("StartAiming")
	end

	function WeaponController.AddShotManipulator(fn: (cameraData: any) -> ()): ()
		table.insert(WeaponController._shotManipulators, fn)
	end

	function WeaponController.RemoveShotManipulator(fn: (cameraData: any) -> ()): ()
		local list = WeaponController._shotManipulators
		for i = #list, 1, -1 do
			if list[i] == fn then
				table.remove(list, i)
				return
			end
		end
	end

	function WeaponController.ReleaseCharge(): boolean
		if not WeaponController.CanFire() then
			return false
		end
		if not sendItemInput("FinishAiming") then
			return false
		end
		WeaponController.NotifyFired()
		return true
	end

	function WeaponController.Reload(): boolean
		return sendItemInput("StartReloading")
	end

	function WeaponController.GetEquippedSlot(): number?
		local info = peek(WeaponController.info)
		return info and info.Slot or nil
	end

	function WeaponController.EquipSlot(slot: number): boolean
		local mechanics = ModuleController.GetModule("MechanicsController")
		local fighter = mechanics and rawget(mechanics, "LocalFighter")
		if not fighter then
			return false
		end
		setthreadidentity(2)
		fighter:EquipItem(slot)
		setthreadidentity(8)
		return true
	end

	setstackhidden(WeaponController.EquipSlot :: any, true)

	function WeaponController.QuickMelee(): boolean
		local mechanics = ModuleController.GetModule("MechanicsController")
		local fighter = mechanics and rawget(mechanics, "LocalFighter")
		if not fighter then
			return false
		end
		setthreadidentity(2)
		fighter:QuickAttack("Melee")
		setthreadidentity(8)
		return true
	end

	setstackhidden(WeaponController.QuickMelee :: any, true)

	local readNumberField = LPH_NO_VIRTUALIZE(function(item: any, key: string, fallback: number): number
		local direct = rawget(item, key)
		if type(direct) == "number" then
			return direct
		end
		local got = item:Get(key)
		if type(got) == "number" then
			return got
		end
		return fallback
	end)

	local function bindItem(item: any): ()
		if WeaponController._itemJanitor then
			WeaponController._itemJanitor:Destroy()
			WeaponController._itemJanitor = nil
		end

		if not item then
			WeaponController.item(nil)
			WeaponController.name(nil)
			WeaponController.class(nil)
			WeaponController.info(nil)
			WeaponController.ammo(0)
			WeaponController.ammoReserve(0)
			WeaponController.maxAmmo(0)
			WeaponController.maxAmmoReserve(0)
			WeaponController.isBusy(false)
			WeaponController.reloading(false)
			WeaponController._busyToken += 1
			return
		end

		local itemJanitor = Janitor.new()
		WeaponController._itemJanitor = itemJanitor

		WeaponController.item(item)
		WeaponController.reloading(false)

		local name: string? = nil
		if type(item.Name) == "string" and item.Name ~= "" then
			name = item.Name
		end
		WeaponController.name(name)

		local itemLibrary = ModuleController.GetModule("ItemLibrary")
		local entry: any = nil
		if itemLibrary and name then
			local items = rawget(itemLibrary, "Items")
			if type(items) == "table" then
				entry = items[name]
			end
		end
		if type(entry) == "table" then
			WeaponController.class(type(entry.Type) == "string" and entry.Type or nil)
			WeaponController.info(entry)
			local info = entry
			WeaponController.maxAmmo(type(info) == "table" and type(info.MaxAmmo) == "number" and info.MaxAmmo or 0)
			WeaponController.maxAmmoReserve(
				type(info) == "table" and type(info.MaxAmmoReserve) == "number" and info.MaxAmmoReserve or 0
			)
		else
			WeaponController.class(nil)
			WeaponController.info(nil)
			WeaponController.maxAmmo(0)
			WeaponController.maxAmmoReserve(0)
		end

		local syncAmmo = LPH_NO_VIRTUALIZE(function(): ()
			local newAmmo = readNumberField(item, "Ammo", 0)
			if newAmmo > peek(WeaponController.ammo) then
				WeaponController.reloading(false)
			end
			WeaponController.ammo(newAmmo)
		end)
		local syncReserve = LPH_NO_VIRTUALIZE(function(): ()
			WeaponController.ammoReserve(readNumberField(item, "AmmoReserve", 0))
		end)

		syncAmmo()
		syncReserve()

		itemJanitor:Add(item:GetDataChangedSignal("Ammo"):Connect(syncAmmo), "Disconnect")
		itemJanitor:Add(item:GetDataChangedSignal("AmmoReserve"):Connect(syncReserve), "Disconnect")
	end

	local function bindFighter(fighter: any): ()
		if WeaponController._fighterJanitor then
			WeaponController._fighterJanitor:Destroy()
			WeaponController._fighterJanitor = nil
		end

		if not fighter then
			bindItem(nil)
			return
		end

		local fighterJanitor = Janitor.new()
		WeaponController._fighterJanitor = fighterJanitor

		local syncEquipped = LPH_NO_VIRTUALIZE(function(): ()
			bindItem(fighter.EquippedItem)
		end)

		syncEquipped()

		fighterJanitor:Add(fighter.EquippedItemChanged:Connect(syncEquipped), "Disconnect")
		fighterJanitor:Add(fighter.ItemAdded:Connect(syncEquipped), "Disconnect")
		fighterJanitor:Add(fighter.ItemRemoved:Connect(syncEquipped), "Disconnect")
	end

	local function findUseItemRemote(): Instance?
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if not remotes then
			return nil
		end
		local replication = remotes:FindFirstChild("Replication")
		if not replication then
			return nil
		end
		local fighter = replication:FindFirstChild("Fighter")
		if not fighter then
			return nil
		end
		return fighter:FindFirstChild("UseItem")
	end

	local decodeCFrame = LPH_NO_VIRTUALIZE(function(encoded: any): CFrame?
		if type(encoded) ~= "table" then
			return nil
		end
		local x, y, z = encoded[CF_KEY_X], encoded[CF_KEY_Y], encoded[CF_KEY_Z]
		if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
			return nil
		end
		local cf = CFrame.new(x, y, z)
		local rx, ry, rz = encoded[CF_KEY_RX], encoded[CF_KEY_RY], encoded[CF_KEY_RZ]
		if type(rx) == "number" and type(ry) == "number" and type(rz) == "number" then
			cf = cf * CFrame.fromOrientation(rx, ry, rz)
		end
		return cf
	end)

	local cachedEnums: { [string]: any } = {}
	local getActionEnum = LPH_NO_VIRTUALIZE(function(name: string): any
		local cached = cachedEnums[name]
		if cached ~= nil then
			return cached
		end
		local EnumLibrary = ModuleController.GetModule("EnumLibrary")
		if not EnumLibrary then
			return nil
		end
		local value: any = nil
		local toEnum = rawget(EnumLibrary, "_to_enum")
		if type(toEnum) == "table" then
			value = toEnum[name]
		end

		if value == nil then
			local toEnumFn = rawget(EnumLibrary, "ToEnum")
			if type(toEnumFn) == "function" then
				local resolved = toEnumFn(EnumLibrary, name)
				if resolved ~= nil then
					value = resolved
				end
			end
		end

		cachedEnums[name] = value
		return value
	end)

	local getShootEnum = LPH_NO_VIRTUALIZE(function(): any
		return getActionEnum("StartShooting")
	end)

	local getReloadEnum = LPH_NO_VIRTUALIZE(function(): any
		return getActionEnum("StartReloading")
	end)

	local processUseItemPayload = LPH_NO_VIRTUALIZE(function(payload: any): { Vector3 }
		local hits: { Vector3 } = {}
		if type(payload) ~= "table" then
			return hits
		end

		local isHitscanGun = WeaponController.IsGun() and not WeaponController.IsProjectile()

		local seenPlayers: { [Player]: boolean } = {}
		local seenModels: { [Model]: boolean } = {}
		local hasCallbacks = next(WeaponController._impactCallbacks) ~= nil

		local meleeMaxDist: number? = nil
		if peek(WeaponController.class) == "Melee" then
			local info = peek(WeaponController.info)
			local reach = type(info) == "table" and type(info.AttackReach) == "number" and info.AttackReach
				or MELEE_REACH_FALLBACK
			meleeMaxDist = reach + MELEE_REACH_PAD
		end

		for _, entry in next, payload do
			if type(entry) ~= "table" then
				continue
			end
			local part = entry[USE_ITEM_PART_KEY]
			if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
				continue
			end
			local hitPosition: Vector3? = nil
			local offset = decodeCFrame(entry[USE_ITEM_HIT_KEY])
			if offset then
				hitPosition = (part.CFrame * offset).Position
			end
			if hasCallbacks then
				for _, cb in next, WeaponController._impactCallbacks do
					local resolved = cb(part)
					if resolved ~= part then
						part = resolved
						entry[USE_ITEM_PART_KEY] = resolved
						break
					end
				end
			end
			if meleeMaxDist then
				local hrp = peek(ClientState.hrp)
				local origin: Vector3? = hrp and hrp.Position
				if not origin then
					local start = decodeCFrame(entry[USE_ITEM_START_KEY])
					origin = start and start.Position
				end
				local reference = hitPosition or part.Position
				if origin and (reference - origin).Magnitude > meleeMaxDist then
					continue
				end
			end
			if hitPosition then
				hits[#hits + 1] = hitPosition
			end
			local character = part:FindFirstAncestorOfClass("Model")
			if not character then
				continue
			end
			if not isHitscanGun and not seenModels[character] then
				seenModels[character] = true
				WeaponController.hitTarget:Fire(character, part)
			end
			local player = Players:GetPlayerFromCharacter(character)
			if not player or player == LocalPlayer then
				continue
			end
			local isHead = string.find(part.Name, "Head") ~= nil
			if not isHitscanGun and not seenPlayers[player] then
				seenPlayers[player] = true
				WeaponController.hitPlayer:Fire(player, isHead)
			end
		end

		return hits
	end)

	local function installUseItemHook(): ()
		local useItem = findUseItemRemote()
		if not useItem then
			return
		end

		local origNamecall: any = nil
		origNamecall = hookmetamethod(
			game,
			"__namecall",
			newcclosure(function(self: any, ...: any): ...any
				if self == useItem and getnamecallmethod() == "FireServer" then
					local action = (select(1, ...))
					local payload = (select(2, ...))
					local shootEnum = getShootEnum()
					local reloadEnum = getReloadEnum()
					local isShoot = shootEnum == nil or action == shootEnum
					if isShoot and (WeaponController._selfFiring or not checkcaller()) then
						local manipulators = WeaponController._shotManipulators
						runShotManipulators(manipulators, payload)
					end
					local isReload = reloadEnum ~= nil and action == reloadEnum
					if isShoot or isReload then
						task.defer(function(deferredAction: any, deferredPayload: any)
							if reloadEnum ~= nil and deferredAction == reloadEnum then
								WeaponController.reloading(true)
								return
							end
							if shootEnum == nil or deferredAction == shootEnum then
								WeaponController.reloading(false)
								local hits = processUseItemPayload(deferredPayload)
								WeaponController.shotFired:Fire(hits)
							end
						end, action, payload)
					end
				end
				return origNamecall(self, ...)
			end)
		)

		WeaponController._useItemRemote = useItem
		WeaponController._origNamecall = origNamecall
	end

	local function installCrosshairVisualHook(): ()
		local crosshair = ModuleController.GetModule("Crosshair")
		if not crosshair then
			return
		end
		local setVisuals = rawget(crosshair, "SetHitmarkerVisuals")
		if type(setVisuals) ~= "function" then
			return
		end

		rawset(
			crosshair,
			"SetHitmarkerVisuals",
			LPH_NO_VIRTUALIZE(function(self: any, spacing: any, size: any, alpha: any, rotation: any, ...)
				if WeaponController._suppressGameHit then
					return setVisuals(self, spacing, size, 1, rotation, ...)
				end
				return setVisuals(self, spacing, size, alpha, rotation, ...)
			end)
		)

		WeaponController._crosshairVisualHook = { crosshair, "SetHitmarkerVisuals", setVisuals }
		WeaponController._crosshairVisualOriginal = setVisuals
	end

	WeaponController.SetSuppressGameHit = LPH_NO_VIRTUALIZE(function(suppress: boolean): ()
		WeaponController._suppressGameHit = suppress
	end)

	WeaponController.SetSuppressHitmarkerSound = LPH_NO_VIRTUALIZE(function(suppress: boolean): ()
		WeaponController._suppressHitmarkerSound = suppress
	end)

	local function installHitmarkerSoundHook(): ()
		local viewModel = ModuleController.GetModule("ClientViewModel")
		if not viewModel then
			return
		end
		local playHitmarkerSound = rawget(viewModel, "PlayHitmarkerSound") :: ((...any) -> ())?
		if type(playHitmarkerSound) ~= "function" then
			return
		end

		rawset(
			viewModel,
			"PlayHitmarkerSound",
			LPH_NO_VIRTUALIZE(function(self: any, isHeadshot: boolean, ...)
				WeaponController.hitDealt:Fire(isHeadshot == true)
				if WeaponController._suppressHitmarkerSound then
					return
				end
				return playHitmarkerSound(self, isHeadshot, ...)
			end)
		)

		WeaponController._hitmarkerSoundHook = { viewModel, "PlayHitmarkerSound", playHitmarkerSound }
	end

	local function installEliminationFeedHook(): ()
		local feedClass = ModuleController.GetModule("EliminationFeed")
		if not feedClass then
			return
		end
		local play = rawget(feedClass, "Play") :: ((...any) -> ())?
		if type(play) ~= "function" then
			return
		end

		rawset(
			feedClass,
			"Play",
			LPH_NO_VIRTUALIZE(function(self: any, victim: any, eliminator: any, ...)
				if eliminator == LocalPlayer and typeof(victim) == "Instance" and victim:IsA("Player") then
					WeaponController.killedPlayer:Fire(victim)
				end
				return play(self, victim, eliminator, ...)
			end)
		)

		WeaponController._eliminationFeedHook = { feedClass, "Play", play }
	end

	local readMuzzlePosition = LPH_NO_VIRTUALIZE(function(viewModel: any): Vector3?
		if type(viewModel) ~= "table" then
			return nil
		end
		local getMuzzle = viewModel.GetMuzzlePosition
		if type(getMuzzle) ~= "function" then
			return nil
		end
		local position = getMuzzle(viewModel)
		if typeof(position) == "Vector3" then
			return position
		end
		return nil
	end)

	local buildTracerSegments = LPH_NO_VIRTUALIZE(function(results: any, muzzle: Vector3): { { Vector3 } }?
		if type(results) ~= "table" then
			return nil
		end
		local segments = {}
		for _, entry in next, results do
			if type(entry) ~= "table" then
				continue
			end
			local target = entry.Position
			if typeof(target) ~= "Vector3" then
				continue
			end
			local start = entry.StartPosition
			if typeof(start) ~= "Vector3" then
				start = muzzle
			end
			segments[#segments + 1] = { start, target }
		end
		if #segments == 0 then
			return nil
		end
		return segments
	end)

	local applyImpactCallbacks = LPH_NO_VIRTUALIZE(function(part: BasePart): BasePart
		local callbacks = WeaponController._impactCallbacks
		if next(callbacks) == nil then
			return part
		end
		for _, cb in next, callbacks do
			local resolved = cb(part)
			if resolved ~= part then
				return resolved
			end
		end
		return part
	end)

	local processShootEffect = LPH_NO_VIRTUALIZE(function(effectData: any): ()
		local seenPlayers: { [Player]: boolean } = {}
		local seenModels: { [Model]: boolean } = {}
		for _, entry in next, effectData do
			if type(entry) ~= "table" then
				continue
			end
			local part = entry[SHOOT_EFFECT_INSTANCE_KEY]
			if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
				continue
			end
			part = applyImpactCallbacks(part)
			local character = part:FindFirstAncestorOfClass("Model")
			if not character then
				continue
			end
			local player = Players:GetPlayerFromCharacter(character)
			if not player or player == LocalPlayer then
				continue
			end
			if not seenModels[character] then
				seenModels[character] = true
				WeaponController.hitTarget:Fire(character, part)
			end
			if not seenPlayers[player] then
				seenPlayers[player] = true
				WeaponController.hitPlayer:Fire(player, string.find(part.Name, "Head") ~= nil)
			end
		end
	end)

	local function installGunEffectsHook(): ()
		local gun = ModuleController.GetModule("Gun")
		if not gun then
			return
		end

		local tracersFn = rawget(gun, "_Tracers")
		if type(tracersFn) == "function" then
			rawset(
				gun,
				"_Tracers",
				LPH_NO_VIRTUALIZE(function(self: any, tracerData: any, ...)
					if
						self
						and type(tracerData) == "table"
						and tracerData.IsLocal
						and WeaponController.gunTracer._handlerListHead
					then
						local muzzle = readMuzzlePosition(self.ViewModel)
						if muzzle then
							local segments = buildTracerSegments(tracerData.RaycastResults, muzzle)
							if segments then
								WeaponController.gunTracer:Fire(segments)
							end
						end
					end
					return tracersFn(self, tracerData, ...)
				end)
			)
			WeaponController._gunTracerHook = { gun, "_Tracers", tracersFn }
		end

		local shootEffectFn = rawget(gun, "_ShootEffect")
		if type(shootEffectFn) == "function" then
			rawset(
				gun,
				"_ShootEffect",
				LPH_NO_VIRTUALIZE(function(self: any, effectData: any, ...)
					local clientFighter = self and self.ClientFighter
					if
						clientFighter
						and clientFighter.IsLocalPlayer
						and type(effectData) == "table"
						and (WeaponController.hitTarget._handlerListHead or WeaponController.hitPlayer._handlerListHead)
					then
						processShootEffect(effectData)
					end
					return shootEffectFn(self, effectData, ...)
				end)
			)
			WeaponController._gunShootEffectHook = { gun, "_ShootEffect", shootEffectFn }
		end
	end

	function WeaponController.AddImpactCallback(fn: (BasePart) -> BasePart): ()
		table.insert(WeaponController._impactCallbacks, fn)
	end

	function WeaponController.RemoveImpactCallback(fn: (BasePart) -> BasePart): ()
		local callbacks = WeaponController._impactCallbacks
		for i = #callbacks, 1, -1 do
			if callbacks[i] == fn then
				table.remove(callbacks, i)
				return
			end
		end
	end

	local isViewmodelEquipped = LPH_NO_VIRTUALIZE(function(viewModel: any): boolean
		if type(viewModel) ~= "table" then
			return false
		end
		setthreadidentity(2)
		local isEquipped = viewModel:IsEquipped()
		setthreadidentity(8)
		return isEquipped
	end)

	local function refreshHeldHud(item: any): ()
		local fighter = WeaponController.GetLocalFighter()
		if not fighter then
			return
		end

		local fighterInterface = rawget(fighter, "FighterInterface")
		local hotbar = fighterInterface and rawget(fighterInterface, "Hotbar")
		if type(hotbar) ~= "table" then
			return
		end

		local slots = rawget(hotbar, "_hotbar_slots")
		if type(slots) == "table" then
			for _, slot in next, slots do
				if type(slot) ~= "table" or rawget(slot, "ClientItem") ~= item then
					continue
				end
				local setup = slot._Setup
				if type(setup) == "function" then
					setthreadidentity(2)
					slot:_Setup()
					setthreadidentity(8)
				elseif slot.Icon and item.ViewModel and item.ViewModel.GetImage then
					setthreadidentity(2)
					slot.Icon.Image = item.ViewModel:GetImage()
					setthreadidentity(8)
				end
				local updateVisuals = slot.UpdateVisuals
				if updateVisuals then
					setthreadidentity(2)
					slot:UpdateVisuals()
					setthreadidentity(8)
				end
			end
		end
	end

	local function refreshItemViewModel(item: any, mode: string?, syncViewmodelState: boolean?): boolean
		if not item then
			return false
		end

		local viewModel = item.ViewModel
		if type(viewModel) ~= "table" then
			return false
		end

		if mode == "wrap" then
			local updateWrap = viewModel._UpdateWrap
			if type(updateWrap) == "function" then
				setthreadidentity(2)
				updateWrap(viewModel)
				setthreadidentity(8)
				if syncViewmodelState then
					viewmodelState._viewmodel(viewModel)
				end
				refreshHeldHud(item)
				return true
			end
		end

		local class = getmetatable(viewModel)
		if type(class) ~= "table" or type(class.new) ~= "function" then
			return false
		end

		local serial = viewModel._serial
		local shouldEquip = isViewmodelEquipped(viewModel)
		local wasAiming = false
		local rootPartOffsetOverride = nil
		local armShirtId: any = nil
		local armLeftColor: any = nil
		local armRightColor: any = nil

		wasAiming = viewModel._aim_spring and viewModel._aim_spring.Target >= 1
		rootPartOffsetOverride = viewModel._root_part_offset_override
		armShirtId = viewModel._shirt_id
		armLeftColor = viewModel._left_arm_color
		armRightColor = viewModel._right_arm_color

		setthreadidentity(2)
		local rebuiltViewModel = class.new(serial, item)
		setthreadidentity(8)
		if type(rebuiltViewModel) ~= "table" then
			return false
		end

		if
			type(rebuiltViewModel.SetArmsData) == "function"
			and (armShirtId ~= nil or armLeftColor ~= nil or armRightColor ~= nil)
		then
			setthreadidentity(2)
			rebuiltViewModel:SetArmsData(armShirtId, armLeftColor, armRightColor)
			setthreadidentity(8)
		end

		if rootPartOffsetOverride ~= nil and type(rebuiltViewModel.OverrideRootPartOffset) == "function" then
			setthreadidentity(2)
			rebuiltViewModel:OverrideRootPartOffset(rootPartOffsetOverride)
			setthreadidentity(8)
		end

		if shouldEquip and type(rebuiltViewModel.Equip) == "function" then
			setthreadidentity(2)
			rebuiltViewModel:Equip(true)
			setthreadidentity(8)
		end

		if wasAiming and type(rebuiltViewModel.SetAiming) == "function" then
			setthreadidentity(2)
			rebuiltViewModel:SetAiming(true)
			setthreadidentity(8)
		end

		item.ViewModel = rebuiltViewModel
		if syncViewmodelState then
			viewmodelState._viewmodel(rebuiltViewModel)
		end
		refreshHeldHud(item)
		setthreadidentity(2)
		viewModel:Destroy()
		setthreadidentity(8)

		return true
	end

	local itemMatchesWeapon = LPH_NO_VIRTUALIZE(function(item: any, weaponName: string): boolean
		if type(item) ~= "table" then
			return false
		end
		if type(item.Name) == "string" and item.Name == weaponName then
			return true
		end

		local data = rawget(item, "Data")
		if type(data) == "table" then
			local dataName = rawget(data, "Name")
			if type(dataName) == "string" and dataName == weaponName then
				return true
			end
			local itemName = rawget(data, "ItemName")
			if type(itemName) == "string" and itemName == weaponName then
				return true
			end
			local weaponNameField = rawget(data, "WeaponName")
			if type(weaponNameField) == "string" and weaponNameField == weaponName then
				return true
			end
		end

		return false
	end)

	local function refreshMatchingLoadoutItems(weaponName: string?, mode: string?): boolean
		local fighter = WeaponController.GetLocalFighter()
		if not fighter then
			return false
		end

		local items = rawget(fighter, "Items")
		if type(items) ~= "table" then
			return false
		end

		local heldItem = peek(WeaponController.item)
		local refreshedAny = false

		for _, item in next, items do
			if type(item) ~= "table" then
				continue
			end
			if weaponName ~= nil and not itemMatchesWeapon(item, weaponName) then
				continue
			end

			if refreshItemViewModel(item, mode, item == heldItem) then
				refreshedAny = true
			end
		end

		return refreshedAny
	end

	function WeaponController.RefreshLoadoutViewModel(weaponName: string?, mode: string?): boolean
		return refreshMatchingLoadoutItems(weaponName, mode)
	end

	WeaponController.RefreshHeldViewModel = LPH_NO_VIRTUALIZE(function(mode: string?): boolean
		local item = peek(WeaponController.item)
		if not item then
			return false
		end

		return refreshItemViewModel(item, mode, true)
	end)

	function WeaponController.new(): WeaponController
		local janitor = Janitor.new()
		WeaponController._janitor = janitor

		installUseItemHook()
		installCrosshairVisualHook()
		installHitmarkerSoundHook()
		installEliminationFeedHook()
		installGunEffectsHook()

		local fc = ModuleController.GetModule("FighterController")
		if not fc then
			return WeaponController
		end
		local map = rawget(fc, "_player_to_fighter")
		if type(map) ~= "table" then
			return WeaponController
		end

		local function refreshLocal(): ()
			bindFighter(map[LocalPlayer])
		end

		refreshLocal()

		janitor:Add(
			fc.ObjectAdded:Connect(LPH_NO_VIRTUALIZE(function(fighter: any): ()
				if fighter.Player == LocalPlayer then
					refreshLocal()
				end
			end)),
			"Disconnect"
		)

		janitor:Add(
			fc.ObjectRemoved:Connect(LPH_NO_VIRTUALIZE(function(fighter: any): ()
				if fighter.Player == LocalPlayer then
					refreshLocal()
				end
			end)),
			"Disconnect"
		)

		return WeaponController
	end

	function WeaponController.Destroy(): ()
		if WeaponController._crosshairVisualHook then
			local h = WeaponController._crosshairVisualHook
			rawset(h[1], h[2], h[3])
			WeaponController._crosshairVisualHook = nil
			WeaponController._crosshairVisualOriginal = nil
		end
		if WeaponController._hitmarkerSoundHook then
			local h = WeaponController._hitmarkerSoundHook
			rawset(h[1], h[2], h[3])
			WeaponController._hitmarkerSoundHook = nil
		end
		if WeaponController._eliminationFeedHook then
			local h = WeaponController._eliminationFeedHook
			rawset(h[1], h[2], h[3])
			WeaponController._eliminationFeedHook = nil
		end
		if WeaponController._gunTracerHook then
			local h = WeaponController._gunTracerHook
			rawset(h[1], h[2], h[3])
			WeaponController._gunTracerHook = nil
		end
		if WeaponController._gunShootEffectHook then
			local h = WeaponController._gunShootEffectHook
			rawset(h[1], h[2], h[3])
			WeaponController._gunShootEffectHook = nil
		end
		if WeaponController._origNamecall then
			hookmetamethod(game, "__namecall", WeaponController._origNamecall)
			WeaponController._origNamecall = nil
		end
		WeaponController._useItemRemote = nil
		if WeaponController._itemJanitor then
			WeaponController._itemJanitor:Destroy()
			WeaponController._itemJanitor = nil
		end
		if WeaponController._fighterJanitor then
			WeaponController._fighterJanitor:Destroy()
			WeaponController._fighterJanitor = nil
		end
		if WeaponController._janitor then
			WeaponController._janitor:Destroy()
			WeaponController._janitor = nil
		end
		table.clear(WeaponController._impactCallbacks)
	end

	export type WeaponController = typeof(WeaponController)

	return WeaponController
end)()
