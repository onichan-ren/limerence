return LPH_JIT(function()
	local Charm = require("@pkg/Charm")
	local BaseFeature = require("@game/BaseFeature")
	local gameUi = require("@game/gameUi")
	local ModuleController = require("@game/ar2/module/ModuleController")
	local NetworkController = require("@game/ar2/network/NetworkController")
	local clientState = require("@game/ar2/client/clientState")
	local autoLootApi = require("@game/ar2/feature/misc/autoLootApi")

	local Players = cloneref(game:GetService("Players")) :: Players

	local sub = Charm.subscribe
	local peek = Charm.peek

	local PICKUP_PACKET = "Inventory Pickup Item"
	local EQUIP_PACKET = "Inventory Equip Item"
	local DROP_PACKET = "Inventory Drop Item"
	local CRAFT_PACKET = "Inventory Craft Item"
	local UNLOAD_PACKET = "Inventory Unload Ammo"
	local FILL_PACKET = "Inventory Fill Ammo"
	local REMOVE_ATTACHMENT_PACKET = "Inventory Remove Attachment"
	local SLOT_UTILITY_PACKET = "Inventory Slot Utility"
	local INTERACT_PACKET = "Client Interacted"
	local CONTAINER_NAME = "LootGroup"
	local DEFAULT_UTILITY_SLOTS = 6

	local WEAPON_STATS = { "Damage", "Velocity", "Fire Rate", "Mag Size" }
	local EQUIP_SLOTS = { "Primary", "Secondary", "Melee" }
	local SUPPLY_KINDS = { "heal", "food", "drink" }
	local SUPPLY_STAT = { heal = "Health", food = "Energy", drink = "Hydration" }
	local FULL_SUPPLY = 1e9

	local NET_TIMEOUT = 0.6
	local MAX_NET_WAIT = 3
	local RETRY_COOLDOWN = 1
	local SAFETY_TICK = 1.5
	local BIND_TRIES = 10
	local PICK_TTL = 2
	local AMMO_OP_TTL = 1.5
	local UNLOAD_MAX = 12
	local AURA_RANGE_PAD = 5
	local DEFAULT_INTERACT_RANGE = 10

	local send = LPH_NO_VIRTUALIZE(function(...): ()
		local old = getthreadidentity()
		setthreadidentity(2)
		NetworkController.send(...)
		setthreadidentity(old)
	end)

	local function num(value: any): number
		return tonumber(value) or 0
	end

	local function toPriority(value: any): { string }?
		if type(value) == "table" and #value > 0 then
			return value
		end
		return nil
	end

	local function toSet(value: any): { [string]: boolean }
		local set: { [string]: boolean } = {}
		if type(value) == "table" then
			for _, name in next, value do
				if type(name) == "string" then
					set[name] = true
				end
			end
		end
		return set
	end

	local function namesOfType(itemType: string): { string }
		local out: { string } = {}
		local seen: { [string]: boolean } = {}
		local items = ModuleController.GetItemData()
		if type(items) == "table" then
			for _, config in next, items do
				if type(config) == "table" and config.Type == itemType then
					local display = config.DisplayName
					if type(display) == "string" and not seen[display] then
						seen[display] = true
						out[#out + 1] = display
					end
				end
			end
		end
		table.sort(out)
		return out
	end

	local function isWeapon(item: any): boolean
		local kind = item.Type
		return kind == "Firearm" or kind == "Melee"
	end

	local function isUtility(item: any): boolean
		return item.Type == "Utility" and item.CanSlotAsUtility == true and item.AutoSlottingBlocked ~= true
	end

	local function addPerks(set: { [string]: boolean }, item: any): ()
		local perks = item.PerksGiven
		if type(perks) ~= "table" then
			return
		end
		for _, perk in next, perks do
			set[perk] = true
		end
	end

	local function givesNewPerk(item: any, covered: { [string]: boolean }): boolean
		local perks = item.PerksGiven
		if type(perks) ~= "table" then
			return false
		end
		for _, perk in next, perks do
			if not covered[perk] then
				return true
			end
		end
		return false
	end

	local function isMagazine(item: any): boolean
		return item.Type == "Ammo" and item.SubType == "Magazine"
	end

	local function isAmmoPack(item: any): boolean
		return item.Type == "Ammo" and item.SubType ~= "Magazine"
	end

	local function isMoving(item: any): boolean
		return item.AmmoMoving == true
	end

	local function hasOpenStack(inventory: any, item: any): boolean
		if not isAmmoPack(item) then
			return false
		end
		local capacity = num(item.Capacity)
		if capacity <= 0 then
			return false
		end
		local name = item.Name
		for _, container in next, inventory.Containers do
			if not container.IsCarried then
				continue
			end
			for _, owned in next, container.Occupants do
				if owned.Name == name and num(owned.Amount) < capacity then
					return true
				end
			end
		end
		return false
	end

	local function magSize(item: any): number
		local fc = item.FireConfig
		if type(fc) == "table" and fc.InternalMag then
			return num(fc.InternalMagSize)
		end
		local attachments = item.Attachments
		local mag = type(attachments) == "table" and attachments.Ammo or nil
		if mag then
			return num(mag.Capacity)
		end
		return 0
	end

	local function weaponStat(item: any, stat: string): number
		if stat == "Mag Size" then
			return magSize(item)
		end
		local fc = item.FireConfig
		if type(fc) == "table" then
			if stat == "Damage" then
				return num(fc.Damage) * math.max(1, num(fc.PelletCount))
			elseif stat == "Velocity" then
				return num(fc.MuzzleVelocity)
			end
			return math.max(num(fc.AutoFireRate), num(fc.SemiFireRate), num(fc.BurstFireRate), num(fc.FireRate))
		end

		if stat == "Damage" then
			local best = 0
			local attacks = item.AttackConfig
			if type(attacks) == "table" then
				for _, attack in next, attacks do
					if type(attack) == "table" then
						best = math.max(best, num(attack.Damage))
					end
				end
			end
			return best
		end
		return 0
	end

	local function weaponBetter(a: any, b: any, priority: { string }): boolean
		for _, stat in next, priority do
			local va, vb = weaponStat(a, stat), weaponStat(b, stat)
			if va ~= vb then
				return va > vb
			end
		end
		return false
	end

	local function magBetter(a: any, b: any): boolean
		local ca, cb = num(a.Capacity), num(b.Capacity)
		if ca ~= cb then
			return ca > cb
		end
		return num(a.Amount) > num(b.Amount)
	end

	local function magWorse(a: any, b: any): boolean
		local ca, cb = num(a.Capacity), num(b.Capacity)
		if ca ~= cb then
			return ca < cb
		end
		return num(a.Amount) < num(b.Amount)
	end

	local function backpackSize(item: any): number
		if not item then
			return 0
		end
		local size = item.ContainerSize
		if type(size) == "table" then
			return num(size[1]) * num(size[2])
		end
		return 0
	end

	local function magFits(weapon: any, mag: any): boolean
		if not weapon or weapon.Caliber == nil or weapon.Caliber ~= mag.Caliber then
			return false
		end
		local types = weapon.MagazineTypes
		return type(types) == "table" and table.find(types, mag.Name) ~= nil
	end

	local function magFitsAny(weapons: { any }, mag: any): boolean
		for _, weapon in next, weapons do
			if magFits(weapon, mag) then
				return true
			end
		end
		return false
	end

	local function consumableStat(item: any, stat: string): number
		local value = 0
		local use = item.UseValue
		if type(use) == "table" then
			value += num(use[stat])
		end
		local restore = item.UseRestore
		if type(restore) == "table" and restore[stat] ~= nil then
			value += FULL_SUPPLY
		end
		return value
	end

	local function classify(item: any): string?
		local kind = item.Type
		if kind == "Firearm" or kind == "Melee" then
			return "weapon"
		end
		if kind == "Ammo" then
			if item.SubType == "Magazine" then
				return "mag"
			end
			return "ammo"
		end
		if kind == "Medical" then
			return "heal"
		end
		if kind == "Consumable" then
			local energy = consumableStat(item, "Energy")
			local hydration = consumableStat(item, "Hydration")
			local health = consumableStat(item, "Health")
			local best, bestKind = health, "heal"
			if energy > best then
				best, bestKind = energy, "food"
			end
			if hydration > best then
				best, bestKind = hydration, "drink"
			end
			if best > 0 then
				return bestKind
			end
		end
		return nil
	end

	local function supplyValue(item: any, kind: string): number
		local stat = SUPPLY_STAT[kind]
		if not stat then
			return 0
		end
		return consumableStat(item, stat)
	end

	local function gridArea(item: any): number
		local g = item.GridSize
		if type(g) == "table" then
			return math.max(1, num(g[1]) * num(g[2]))
		end
		return 1
	end

	local function forEachOwned(inventory: any, fn: (any) -> ()): ()
		for _, container in next, inventory.Containers do
			if not container.IsCarried then
				continue
			end
			for _, item in next, container.Occupants do
				fn(item)
			end
		end

		local equipment = inventory.Equipment
		if type(equipment) ~= "table" then
			return
		end
		for slot, entry in next, equipment do
			if type(entry) ~= "table" then
				continue
			end
			if inventory:IsEquipSlotList(slot) then
				for _, item in next, entry.Items do
					fn(item)
				end
			elseif entry.Id then
				fn(entry)
			end
		end
	end

	local function present(item: any, container: any): boolean
		return container ~= nil and container.Occupants[item.Id] == item
	end

	local function stillHeld(inventory: any, id: any): boolean
		for _, container in next, inventory.Containers do
			if container.IsCarried and container.Occupants[id] then
				return true
			end
		end
		local equipment = inventory.Equipment
		if type(equipment) == "table" then
			for _, entry in next, equipment do
				if type(entry) == "table" and entry.Id == id then
					return true
				end
			end
		end
		return false
	end

	local AutoLoot = {}
	AutoLoot.__index = AutoLoot

	setmetatable(AutoLoot, { __index = BaseFeature })

	function AutoLoot.new(link: gameUi.Linker): AutoLoot
		local self = BaseFeature.new() :: any
		setmetatable(self, AutoLoot)

		self._enabled = false
		self._conns = {} :: { any }
		self._charConn = nil :: (() -> ())?
		self._visConn = nil :: any
		self._bindToken = nil :: any
		self._tickToken = nil :: any
		self._dropped = {} :: { [any]: boolean }
		self._tried = {} :: { [string]: number }
		self._recentPicks = {} :: { [any]: any }
		self._ammoOp = {} :: { [any]: number }
		self._unloading = {} :: { [any]: any }
		self._unloadSettle = {} :: { [any]: number }
		self._pending = false
		self._running = false
		self._lootAura = false
		self._menuVisible = false
		self._registry = nil :: any
		self._interface = nil :: any
		self._utilLimit = nil :: number?

		link:Toggle("autoLoot", "Auto Loot", false):SetTip({
			title = "Auto Loot",
			body = "Grabs the best gear and supplies the moment you open a body, container, or your inventory.",
		})

		local rootLink = link:OnKey("autoLoot")
		rootLink:Submenu("opts", "Auto Loot")
		local opts = rootLink:OnKey("opts")

		opts:Options("weapons", "Weapons")
		local weapons = opts:OnKey("weapons")
		weapons:Toggle("manageWeapons", "Manage Weapons", true):SetTip({
			title = "Manage Weapons",
			body = "Lets Auto Loot equip, stash and swap guns. Turn off to leave your weapons alone.",
		})
		weapons:Toggle("dropWeapons", "Drop Weapons", true):SetTip({
			title = "Drop Weapons",
			body = "Allows dropping guns to swap or trim spares. Turn off to never drop a weapon.",
		})
		weapons:Dropdown("preferredWeapons", "Preferred Weapons", namesOfType("Firearm"), {}):SetMode("multi"):SetTip({
			title = "Preferred Weapons",
			body = "Guns picked here are always kept over any gun not on the list, ignoring stats.",
		})
		weapons:PriorityList("weaponStat", "Weapon Priority", WEAPON_STATS, WEAPON_STATS):SetTip({
			title = "Weapon Priority",
			body = "Ranks your main gun by these stats in order. Also the fallback for slots with no priority set.",
		})
		weapons:Dropdown("secondaryStat", "Secondary Priority", WEAPON_STATS, {}):SetMode("multi"):SetTip({
			title = "Secondary Priority",
			body = "Ranks your sidearm by the stats you pick, in pick order. Leave empty to use Weapon Priority.",
		})
		weapons:Dropdown("spareStat", "Spare Priority", WEAPON_STATS, {}):SetMode("multi"):SetTip({
			title = "Spare Priority",
			body = "Ranks spare guns by the stats you pick, in pick order. Leave empty to use Weapon Priority.",
		})
		weapons:Slider("maxWeapons", "Spare Guns", 1, 0, 5, 1):SetTip({
			title = "Spare Guns",
			body = "Spare guns to stash in your bag, best first. Set 0 to carry none.",
		})
		weapons:Toggle("onlyUpgrade", "Only Upgrades", false):SetTip({
			title = "Only Upgrades",
			body = "Only stashes a spare gun when it beats your best one of that kind.",
		})

		opts:Options("supplies", "Supplies")
		local supplies = opts:OnKey("supplies")
		supplies:Toggle("keepSupplies", "Keep Supplies", true):SetTip({
			title = "Keep Supplies",
			body = "Grabs health, food and drinks, and trades up to better ones when you find them.",
		})
		supplies:Slider("maxHeals", "Health", 5, 0, 15, 1):SetTip({
			title = "Health",
			body = "How many healing items to keep.",
		})
		supplies:Slider("minHeals", "Min Health", 0, 0, 100, 5):SetTip({
			title = "Min Health",
			body = "Skip healing items that restore less than this. Set 0 to grab any.",
		})
		supplies:Slider("maxFood", "Food", 3, 0, 15, 1):SetTip({
			title = "Food",
			body = "How many food items to keep.",
		})
		supplies:Slider("minFood", "Min Energy", 0, 0, 100, 5):SetTip({
			title = "Min Energy",
			body = "Skip food that restores less than this. Set 0 to grab any.",
		})
		supplies:Slider("maxDrinks", "Drinks", 3, 0, 15, 1):SetTip({
			title = "Drinks",
			body = "How many drinks to keep.",
		})
		supplies:Slider("minDrinks", "Min Hydration", 0, 0, 100, 5):SetTip({
			title = "Min Hydration",
			body = "Skip drinks that restore less than this. Set 0 to grab any.",
		})

		opts:Options("general", "General")
		local general = opts:OnKey("general")
		general:Toggle("lootGround", "Loot Ground", true):SetTip({
			title = "Loot Ground",
			body = "Grabs nearby floor loot too, not just open containers.",
		})
		general:Toggle("lootAura", "Loot Aura", false):SetTip({
			title = "Loot Aura",
			body = "Opens every loaded container around you at once when you open your inventory.",
		})
		general:Slider("delay", "Loot Delay", 50, 0, 300, 10, nil, " ms"):SetTip({
			title = "Loot Delay",
			body = "Wait between each grab. Raise it if loot gets dropped.",
		})

		opts:Options("utilities", "Utilities")
		local utilities = opts:OnKey("utilities")
		utilities:Toggle("keepUtilities", "Keep Utilities", true):SetTip({
			title = "Keep Utilities",
			body = "Grabs and slots gear buffs like flashlights and binoculars when a slot is free.",
		})
		utilities:Dropdown("preferredUtilities", "Preferred Utilities", namesOfType("Utility"), {}):SetMode("multi"):SetTip({
			title = "Preferred Utilities",
			body = "Only grab the buffs picked here. Leave empty to grab any that add a new buff.",
		})

		opts:Options("ammo", "Ammo")
		local ammo = opts:OnKey("ammo")
		ammo:Toggle("keepBoxes", "Keep Ammo Boxes", true):SetTip({
			title = "Keep Ammo Boxes",
			body = "Grabs loose ammo boxes that fit your guns, fullest first.",
		})
		ammo:Toggle("keepMags", "Keep Mags", true):SetTip({
			title = "Keep Mags",
			body = "Grabs magazines that fit your guns, fullest first, and fills them from boxes.",
		})
		ammo:Slider("maxAmmo", "Ammo Boxes", 3, 0, 10, 1):SetTip({
			title = "Ammo Boxes",
			body = "Ammo boxes of each type to keep.",
		})
		ammo:Slider("maxMags", "Mags Per Gun", 4, 0, 15, 1):SetTip({
			title = "Mags Per Gun",
			body = "Mags to keep for each caliber of gun you carry.",
		})

		self._manageWeapons = weapons:Peek("manageWeapons") ~= false
		self._dropWeapons = weapons:Peek("dropWeapons") ~= false
		self._weaponStat = weapons:Peek("weaponStat") or WEAPON_STATS
		self._preferred = toSet(weapons:Peek("preferredWeapons"))
		self._secondaryStat = toPriority(weapons:Peek("secondaryStat"))
		self._spareStat = toPriority(weapons:Peek("spareStat"))
		self._maxWeapons = num(weapons:Peek("maxWeapons"))
		self._onlyUpgrade = weapons:Peek("onlyUpgrade") == true
		self._keepBoxes = ammo:Peek("keepBoxes") ~= false
		self._keepMags = ammo:Peek("keepMags") ~= false
		self._maxAmmo = num(ammo:Peek("maxAmmo"))
		self._maxMags = num(ammo:Peek("maxMags"))
		self._keepSupplies = supplies:Peek("keepSupplies") ~= false
		self._maxHeals = num(supplies:Peek("maxHeals"))
		self._maxFood = num(supplies:Peek("maxFood"))
		self._maxDrinks = num(supplies:Peek("maxDrinks"))
		self._minHeals = num(supplies:Peek("minHeals"))
		self._minFood = num(supplies:Peek("minFood"))
		self._minDrinks = num(supplies:Peek("minDrinks"))
		self._keepUtilities = utilities:Peek("keepUtilities") ~= false
		self._preferredUtilities = toSet(utilities:Peek("preferredUtilities"))
		self._lootGround = general:Peek("lootGround") == true
		self._lootAura = general:Peek("lootAura") == true
		self._delay = num(general:Peek("delay"))

		self:Track(link:Get("autoLoot"):OnChange(function(value: boolean): ()
			if value then
				self:Enable()
			else
				self:Disable()
			end
		end))

		self:Track(weapons:Get("weaponStat"):OnChange(function(value: any): ()
			if type(value) == "table" then
				self._weaponStat = value
			end
			self:_wake()
		end))
		self:Track(weapons:Get("manageWeapons"):OnChange(function(value: boolean): ()
			self._manageWeapons = value ~= false
			self:_wake()
		end))
		self:Track(weapons:Get("dropWeapons"):OnChange(function(value: boolean): ()
			self._dropWeapons = value ~= false
			self:_wake()
		end))
		self:Track(weapons:Get("preferredWeapons"):OnChange(function(value: any): ()
			self._preferred = toSet(value)
			self:_wake()
		end))
		self:Track(weapons:Get("secondaryStat"):OnChange(function(value: any): ()
			self._secondaryStat = toPriority(value)
			self:_wake()
		end))
		self:Track(weapons:Get("spareStat"):OnChange(function(value: any): ()
			self._spareStat = toPriority(value)
			self:_wake()
		end))
		self:Track(weapons:Get("maxWeapons"):OnChange(function(value: number): ()
			self._maxWeapons = num(value)
			self:_wake()
		end))
		self:Track(weapons:Get("onlyUpgrade"):OnChange(function(value: boolean): ()
			self._onlyUpgrade = value == true
			self:_wake()
		end))
		self:Track(ammo:Get("keepBoxes"):OnChange(function(value: boolean): ()
			self._keepBoxes = value ~= false
			self:_wake()
		end))
		self:Track(ammo:Get("keepMags"):OnChange(function(value: boolean): ()
			self._keepMags = value ~= false
			self:_wake()
		end))
		self:Track(ammo:Get("maxAmmo"):OnChange(function(value: number): ()
			self._maxAmmo = num(value)
			self:_wake()
		end))
		self:Track(ammo:Get("maxMags"):OnChange(function(value: number): ()
			self._maxMags = num(value)
			self:_wake()
		end))
		self:Track(supplies:Get("keepSupplies"):OnChange(function(value: boolean): ()
			self._keepSupplies = value ~= false
			self:_wake()
		end))
		self:Track(supplies:Get("maxHeals"):OnChange(function(value: number): ()
			self._maxHeals = num(value)
			self:_wake()
		end))
		self:Track(supplies:Get("maxFood"):OnChange(function(value: number): ()
			self._maxFood = num(value)
			self:_wake()
		end))
		self:Track(supplies:Get("maxDrinks"):OnChange(function(value: number): ()
			self._maxDrinks = num(value)
			self:_wake()
		end))
		self:Track(supplies:Get("minHeals"):OnChange(function(value: number): ()
			self._minHeals = num(value)
			self:_wake()
		end))
		self:Track(supplies:Get("minFood"):OnChange(function(value: number): ()
			self._minFood = num(value)
			self:_wake()
		end))
		self:Track(supplies:Get("minDrinks"):OnChange(function(value: number): ()
			self._minDrinks = num(value)
			self:_wake()
		end))
		self:Track(utilities:Get("keepUtilities"):OnChange(function(value: boolean): ()
			self._keepUtilities = value ~= false
			self:_wake()
		end))
		self:Track(utilities:Get("preferredUtilities"):OnChange(function(value: any): ()
			self._preferredUtilities = toSet(value)
			self:_wake()
		end))
		self:Track(general:Get("lootGround"):OnChange(function(value: boolean): ()
			self._lootGround = value == true
			self:_wake()
		end))
		self:Track(general:Get("lootAura"):OnChange(function(value: boolean): ()
			self._lootAura = value == true
			if self._lootAura then
				self:_auraScan()
			end
			self:_wake()
		end))
		self:Track(general:Get("delay"):OnChange(function(value: number): ()
			self._delay = num(value)
			self:_wake()
		end))

		if link:Peek("autoLoot") then
			self:Enable()
		end

		return self
	end

	function AutoLoot._getInventory(_self: AutoLoot): any
		local module = ModuleController.GetModule("LocalPlayer")
		local getter = module and module.module and module.module.get
		local player = getter and getter()
		local character = player and player.Character
		return character and character.Inventory or nil
	end

	function AutoLoot._visibilitySignal(_self: AutoLoot): any
		local interface = ModuleController.FrameworkRequire("Libraries", "Interface")
		if type(interface) ~= "table" or type(interface.GetVisibilityChangedSignal) ~= "function" then
			return nil
		end
		local signal = interface:GetVisibilityChangedSignal("MainMenu")
		if type(signal) == "table" and type(signal.Connect) == "function" then
			return signal
		end
		return nil
	end

	function AutoLoot._interactRegistry(self: AutoLoot): any
		if self._registry then
			return self._registry
		end
		local module = ModuleController.GetModule("Interactables")
		local find = module and module.module and rawget(module.module, "find")
		if type(find) ~= "function" then
			return nil
		end
		for _, value in next, debug.getupvalues(find) :: { any } do
			if type(value) == "table" then
				self._registry = value
				return value
			end
		end
		return nil
	end

	function AutoLoot._utilityLimit(self: AutoLoot): number
		if self._utilLimit then
			return self._utilLimit
		end
		local limit = DEFAULT_UTILITY_SLOTS
		local globals = ModuleController.FrameworkRequire("Configs", "Globals")
		if type(globals) == "table" and tonumber(globals.UtilitySlotLimit) then
			limit = tonumber(globals.UtilitySlotLimit) :: number
		end
		self._utilLimit = limit
		return limit
	end

	function AutoLoot._interfaceLib(self: AutoLoot): any
		if self._interface == nil then
			self._interface = ModuleController.FrameworkRequire("Libraries", "Interface") or false
		end
		return self._interface or nil
	end

	function AutoLoot._isMenuVisible(self: AutoLoot): boolean
		local interface = self:_interfaceLib()
		if interface and type(interface.IsVisible) == "function" then
			return interface:IsVisible("MainMenu") == true
		end
		return false
	end

	function AutoLoot._auraScan(self: AutoLoot): ()
		if not self._enabled or not self._lootAura then
			return
		end
		local registry = self:_interactRegistry()
		if not registry then
			return
		end
		local module = ModuleController.GetModule("LocalPlayer")
		local getter = module and module.module and module.module.get
		local player = getter and getter()
		local character = player and player.Character
		if not character then
			return
		end

		local origin
		local hrp = peek(clientState.hrp)
		if hrp then
			origin = hrp.Position
		end

		for key, interactable in next, registry do
			if type(key) == "userdata" or type(interactable) ~= "table" then
				continue
			end
			local instance = interactable.Instance
			if not instance or instance.Name ~= CONTAINER_NAME or not instance.Parent then
				continue
			end
			if origin then
				local pos
				if instance:IsA("BasePart") then
					pos = instance.Position
				else
					pos = instance:GetPivot().Position
				end
				if not pos then
					continue
				end
				local maxDist = (tonumber(interactable.MaxDistance) or DEFAULT_INTERACT_RANGE) + AURA_RANGE_PAD
				if (pos - origin).Magnitude > maxDist then
					continue
				end
			end
			local action = interactable.InteractAction or interactable.StoredAction
			if not action then
				continue
			end
			local payload = action(character, false)
			send(INTERACT_PACKET, interactable.Id, false, payload)
		end
	end

	function AutoLoot._sources(self: AutoLoot, inventory: any): { any }
		local out = {}
		for _, container in next, inventory.Containers do
			if container.IsCarried then
				continue
			end
			if container.Name == "Ground" and not self._lootGround then
				continue
			end
			out[#out + 1] = container
		end
		return out
	end

	function AutoLoot._ready(self: AutoLoot, key: string, now: number): boolean
		local tried: { [string]: number } = self._tried
		local last = tried[key]
		return last == nil or (now - last) >= RETRY_COOLDOWN
	end

	function AutoLoot._slotPriority(self: AutoLoot, slot: string): { string }
		if slot == "Secondary" and self._secondaryStat then
			return self._secondaryStat
		end
		return self._weaponStat
	end

	function AutoLoot._nextAction(self: AutoLoot, inventory: any): any
		local now = os.clock()
		local priority = self._weaponStat
		local dropped: { [any]: boolean } = self._dropped
		local keepBoxes: boolean = self._keepBoxes
		local keepMags: boolean = self._keepMags
		local keepSupplies: boolean = self._keepSupplies
		local maxWeapons: number = self._maxWeapons
		local maxAmmo: number = self._maxAmmo
		local maxMags: number = self._maxMags
		local preferred: { [string]: boolean } = self._preferred
		local blockedWant = false

		local function betterGun(a: any, b: any, prio: { string }): boolean
			local pa = a.DisplayName ~= nil and preferred[a.DisplayName] == true
			local pb = b.DisplayName ~= nil and preferred[b.DisplayName] == true
			if pa ~= pb then
				return pa
			end
			return weaponBetter(a, b, prio)
		end

		local ownedIds = {}
		local weapons = {}
		local calibers = {}
		local ammoStacks = {}
		local ammoBusy = {}
		local magCounts = {}
		local counts = { heal = 0, food = 0, drink = 0 }
		local spareCounts = {}
		local bestByFamily = {}
		local ownedSupplies = { heal = {}, food = {}, drink = {} }
		local packs = {}

		forEachOwned(inventory, function(item: any): ()
			ownedIds[item.Id] = true
			local kind = classify(item)
			if item.Type == "Firearm" then
				weapons[#weapons + 1] = item
				if item.Caliber then
					calibers[item.Caliber] = (calibers[item.Caliber] or 0) + 1
				end
			end
			if isWeapon(item) then
				local fam = item.EquipSlot
				if fam then
					local cur = bestByFamily[fam]
					if not cur or betterGun(item, cur, priority) then
						bestByFamily[fam] = item
					end
				end
			end
			if kind == "ammo" then
				local caliber = item.Caliber
				local amount = num(item.Amount)
				local capacity = num(item.Capacity)
				local moving = isMoving(item)
				if caliber then
					ammoStacks[caliber] = (ammoStacks[caliber] or 0) + 1
					if moving then
						ammoBusy[caliber] = true
					end
				end
				local name = item.Name
				if name and amount > 0 and not moving then
					local group = packs[name]
					if not group then
						group = { total = 0, count = 0, cap = capacity, ids = {}, caliber = caliber }
						packs[name] = group
					end
					group.total += amount
					group.count += 1
					group.ids[#group.ids + 1] = { id = item.Id, amount = amount }
				end
			elseif kind == "mag" then
				local magKey = item.Name or item.Caliber
				if magKey and num(item.Amount) > 0 then
					magCounts[magKey] = (magCounts[magKey] or 0) + 1
				end
			elseif kind == "heal" or kind == "food" or kind == "drink" then
				counts[kind] += 1
				local list = ownedSupplies[kind]
				list[#list + 1] = { item = item, value = supplyValue(item, kind) }
			end
		end)

		for _, container in next, inventory.Containers do
			if not container.IsCarried then
				continue
			end
			for _, item in next, container.Occupants do
				if isWeapon(item) then
					local fam = item.EquipSlot
					if fam then
						spareCounts[fam] = (spareCounts[fam] or 0) + 1
					end
				end
			end
		end

		local recentPicks: { [any]: any } = self._recentPicks
		for id, rec in next, recentPicks do
			if now - rec.t >= PICK_TTL then
				recentPicks[id] = nil
			elseif not ownedIds[id] then
				local kind = rec.kind
				if kind == "ammo" and rec.caliber then
					ammoStacks[rec.caliber] = (ammoStacks[rec.caliber] or 0) + 1
				elseif kind == "weapon" then
					local fam = rec.slot
					if fam then
						spareCounts[fam] = (spareCounts[fam] or 0) + 1
					end
				elseif kind == "heal" or kind == "food" or kind == "drink" then
					counts[kind] += 1
				end
			end
		end

		local ammoOp: { [any]: number } = self._ammoOp
		for caliber, when in next, ammoOp do
			if now - when >= AMMO_OP_TTL then
				ammoOp[caliber] = nil
			else
				ammoBusy[caliber] = true
			end
		end

		local unloadSettle: { [any]: number } = self._unloadSettle
		for caliber, when in next, unloadSettle do
			if now - when >= AMMO_OP_TTL then
				unloadSettle[caliber] = nil
			end
		end

		local unloading: { [any]: any } = self._unloading
		local unloadInflight = {}
		local unloadCaliberBusy = {}
		for id, rec in next, unloading do
			local active = rec.item ~= nil and rec.item.Destroyed ~= true and num(rec.item.Amount) > 0
			local cal = rec.item and rec.item.Caliber
			if active and now - rec.t < UNLOAD_MAX then
				unloadInflight[id] = true
				if cal then
					unloadCaliberBusy[cal] = true
				end
			else
				unloading[id] = nil
			end
		end

		local sources = self:_sources(inventory)

		local forcedSet = autoLootApi.GetForcedItemSet()
		if forcedSet then
			for _, container in next, sources do
				for _, item in next, container.Occupants do
					if ownedIds[item.Id] or dropped[item.Id] or recentPicks[item.Id] then
						continue
					end
					local name = item.DisplayName or item.Name
					if not (name and forcedSet[name]) then
						continue
					end
					local key = "pk:" .. item.Id
					if self:_ready(key, now) and self:_canPickup(inventory, item) then
						return {
							act = "pickup",
							id = item.Id,
							item = item,
							container = container,
							pickKind = classify(item) or "weapon",
							name = item.Name,
							slot = item.EquipSlot,
							caliber = item.Caliber,
							key = key,
						}
					end
				end
			end
		end

		local lootWeapons = {}
		for _, container in next, sources do
			for _, item in next, container.Occupants do
				if isWeapon(item) and not dropped[item.Id] then
					lootWeapons[#lootWeapons + 1] = { item = item, container = container }
				end
			end
		end
		table.sort(lootWeapons, function(a: any, b: any): boolean
			return betterGun(a.item, b.item, priority)
		end)

		if self._manageWeapons then
			local bestPerSlot = {}
			for _, entry in next, lootWeapons do
				local slot = entry.item.EquipSlot
				if not slot then
					continue
				end
				local current = bestPerSlot[slot]
				if not current or betterGun(entry.item, current.item, self:_slotPriority(slot)) then
					bestPerSlot[slot] = entry
				end
			end
			for _, slot in next, EQUIP_SLOTS do
				local entry = bestPerSlot[slot]
				if not entry or not present(entry.item, entry.container) then
					continue
				end
				local equipped = inventory.Equipment[slot]
				local hasEquipped = type(equipped) == "table" and equipped.Id ~= nil
				if not hasEquipped then
					local key = "eq:" .. entry.item.Id
					if self:_ready(key, now) then
						return { act = "equip", id = entry.item.Id, key = key }
					end
				elseif self._dropWeapons and betterGun(entry.item, equipped, self:_slotPriority(slot)) then
					local key = "drop:" .. equipped.Id
					if self:_ready(key, now) then
						return { act = "drop", id = equipped.Id, rotated = equipped.Rotated == true, key = key }
					end
				end
			end
		end

		do
			local current = backpackSize(inventory.Equipment["Backpack"])
			local best, bestSize = nil, current
			for _, container in next, sources do
				for _, item in next, container.Occupants do
					if item.Type == "Backpack" and not dropped[item.Id] then
						local size = backpackSize(item)
						if size > bestSize then
							best, bestSize = item, size
						end
					end
				end
			end
			if best then
				local key = "eq:" .. best.Id
				if self:_ready(key, now) then
					return { act = "equip", id = best.Id, key = key }
				end
			end
		end

		local equippedBag = inventory.Equipment["Backpack"]
		if type(equippedBag) == "table" and equippedBag.Id ~= nil then
			for _, container in next, inventory.Containers do
				if not container.IsCarried then
					continue
				end
				for _, item in next, container.Occupants do
					if item.Type == "Backpack" and not dropped[item.Id] and item.Id ~= equippedBag.Id then
						local key = "drop:" .. item.Id
						if self:_ready(key, now) then
							return { act = "drop", id = item.Id, rotated = item.Rotated == true, key = key }
						end
					end
				end
			end
		end

		for _, container in next, inventory.Containers do
			if not container.IsCarried then
				continue
			end
			for _, item in next, container.Occupants do
				if
					isMagazine(item)
					and not dropped[item.Id]
					and not unloadInflight[item.Id]
					and num(item.Amount) <= 0
					and not isMoving(item)
					and not magFitsAny(weapons, item)
				then
					local key = "drop:" .. item.Id
					if self:_ready(key, now) then
						return { act = "drop", id = item.Id, rotated = item.Rotated == true, key = key }
					end
				elseif isAmmoPack(item) and not dropped[item.Id] and not isMoving(item) and num(item.Amount) <= 0 then
					local key = "drop:" .. item.Id
					if self:_ready(key, now) then
						return { act = "drop", id = item.Id, rotated = item.Rotated == true, key = key }
					end
				end
			end
		end

		if #weapons > 0 then
			for _, container in next, inventory.Containers do
				if not container.IsCarried then
					continue
				end
				for _, item in next, container.Occupants do
					if isMagazine(item) and not dropped[item.Id] and not magFitsAny(weapons, item) then
						local caliber = item.Caliber
						if caliber and calibers[caliber] and num(item.Amount) > 0 then
							continue
						end
						local key = "drop:" .. item.Id
						if self:_ready(key, now) then
							return { act = "drop", id = item.Id, rotated = item.Rotated == true, key = key }
						end
					elseif isAmmoPack(item) and not dropped[item.Id] and not isMoving(item) then
						local caliber = item.Caliber
						if caliber and not calibers[caliber] then
							local key = "drop:" .. item.Id
							if self:_ready(key, now) then
								return { act = "drop", id = item.Id, rotated = item.Rotated == true, key = key }
							end
						end
					end
				end
			end
		end

		if self._manageWeapons and self._dropWeapons then
			local sparePriority = self._spareStat or priority
			local totalSpares = (spareCounts["Primary"] or 0) + (spareCounts["Secondary"] or 0)
			if totalSpares > maxWeapons then
				local worst, worstContainer = nil, nil
				for _, container in next, inventory.Containers do
					if not container.IsCarried then
						continue
					end
					for _, item in next, container.Occupants do
						if isWeapon(item) and not dropped[item.Id] then
							local fam = item.EquipSlot
							if fam == "Primary" or fam == "Secondary" then
								if not worst or betterGun(worst, item, sparePriority) then
									worst, worstContainer = item, container
								end
							end
						end
					end
				end
				if worst and worstContainer then
					local key = "drop:" .. worst.Id
					if self:_ready(key, now) then
						return { act = "drop", id = worst.Id, rotated = worst.Rotated == true, key = key }
					end
				end
			end
		end

		local ownedMagsByCal: { [any]: { any } } = {}
		if keepMags then
			for _, container in next, inventory.Containers do
				if not container.IsCarried then
					continue
				end
				for _, item in next, container.Occupants do
					if
						isMagazine(item)
						and not dropped[item.Id]
						and not isMoving(item)
						and magFitsAny(weapons, item)
					then
						local cal = item.Caliber
						if cal then
							local list = ownedMagsByCal[cal]
							if not list then
								list = {}
								ownedMagsByCal[cal] = list
							end
							list[#list + 1] = item
						end
					end
				end
			end
		end

		local magInflightCal: { [any]: number } = {}
		for id, rec in next, recentPicks do
			if rec.kind == "mag" and rec.caliber and not ownedIds[id] then
				magInflightCal[rec.caliber] = (magInflightCal[rec.caliber] or 0) + 1
			end
		end

		if keepMags then
			for caliber, list in next, ownedMagsByCal do
				local count = #list + (magInflightCal[caliber] or 0)
				if count < maxMags then
					continue
				end
				local smallest = list[1]
				for _, item in next, list do
					if magWorse(item, smallest) then
						smallest = item
					end
				end
				if not smallest then
					continue
				end
				local swap = false
				if count <= maxMags then
					local smallestCap = num(smallest.Capacity)
					for _, container in next, sources do
						for _, item in next, container.Occupants do
							if
								isMagazine(item)
								and not ownedIds[item.Id]
								and not dropped[item.Id]
								and not isMoving(item)
								and item.Caliber == caliber
								and magFitsAny(weapons, item)
								and num(item.Capacity) > smallestCap
							then
								swap = true
								break
							end
						end
						if swap then
							break
						end
					end
				end
				if count > maxMags or swap then
					local key = "drop:" .. smallest.Id
					if self:_ready(key, now) then
						return { act = "drop", id = smallest.Id, rotated = smallest.Rotated == true, key = key }
					end
				end
			end
		end

		if self._manageWeapons and maxWeapons > 0 then
			local spareStat = self._spareStat
			local sparePriority = spareStat or priority
			local totalSpares = (spareCounts["Primary"] or 0) + (spareCounts["Secondary"] or 0)
			if totalSpares < maxWeapons then
				local pick, pickContainer = nil, nil
				for _, entry in next, lootWeapons do
					local item = entry.item
					local fam = item.EquipSlot
					if fam ~= "Primary" and fam ~= "Secondary" then
						continue
					end
					if not present(item, entry.container) then
						continue
					end
					if self._onlyUpgrade then
						local best = bestByFamily[fam]
						if best and not betterGun(item, best, sparePriority) then
							continue
						end
					end
					if not pick or betterGun(item, pick, sparePriority) then
						pick, pickContainer = item, entry.container
					end
				end
				if pick then
					local key = "pk:" .. pick.Id
					if self:_ready(key, now) then
						if self:_canPickup(inventory, pick) then
							return {
								act = "pickup",
								id = pick.Id,
								item = pick,
								container = pickContainer,
								pickKind = "weapon",
								slot = pick.EquipSlot,
								key = key,
							}
						else
							blockedWant = true
						end
					end
				end
			end
		end

		if keepMags and #weapons > 0 then
			local best, bestContainer = nil, nil
			for _, container in next, sources do
				for _, item in next, container.Occupants do
					if ownedIds[item.Id] or dropped[item.Id] then
						continue
					end
					if not isMagazine(item) or not magFitsAny(weapons, item) then
						continue
					end
					local caliber = item.Caliber
					if not caliber then
						continue
					end
					local count = #(ownedMagsByCal[caliber] or {}) + (magInflightCal[caliber] or 0)
					if count >= maxMags then
						continue
					end
					if not self:_ready("pk:" .. item.Id, now) then
						continue
					end
					if not self:_canPickup(inventory, item) then
						blockedWant = true
						continue
					end
					if not best or magBetter(item, best) then
						best, bestContainer = item, container
					end
				end
			end
			if best then
				return {
					act = "pickup",
					id = best.Id,
					item = best,
					container = bestContainer,
					pickKind = "mag",
					caliber = best.Caliber,
					name = best.Name,
					key = "pk:" .. best.Id,
				}
			end
		end

		if keepBoxes then
			local best, bestContainer, bestAmount = nil, nil, -1
			for _, container in next, sources do
				for _, item in next, container.Occupants do
					if ownedIds[item.Id] or dropped[item.Id] then
						continue
					end
					if classify(item) ~= "ammo" then
						continue
					end
					local caliber = item.Caliber
					if not (caliber and calibers[caliber]) then
						continue
					end
					if (ammoStacks[caliber] or 0) >= maxAmmo then
						continue
					end
					local amount = num(item.Amount)
					if self:_ready("pk:" .. item.Id, now) then
						if self:_canPickup(inventory, item) then
							if amount > bestAmount then
								best, bestContainer, bestAmount = item, container, amount
							end
						else
							blockedWant = true
						end
					end
				end
			end
			if best then
				return {
					act = "pickup",
					id = best.Id,
					item = best,
					container = bestContainer,
					pickKind = "ammo",
					caliber = best.Caliber,
					name = best.Name,
					key = "pk:" .. best.Id,
				}
			end
		end

		if keepSupplies then
			local caps = { heal = self._maxHeals, food = self._maxFood, drink = self._maxDrinks }
			local mins = { heal = self._minHeals, food = self._minFood, drink = self._minDrinks }
			for _, kind in next, SUPPLY_KINDS do
				local cap = caps[kind] or 0
				local minValue = mins[kind] or 0
				local owned = ownedSupplies[kind]
				table.sort(owned, function(a: any, b: any): boolean
					return a.value < b.value
				end)
				local worst = owned[1]

				if cap <= 0 then
					if worst then
						local key = "drop:" .. worst.item.Id
						if self:_ready(key, now) then
							return { act = "drop", id = worst.item.Id, rotated = worst.item.Rotated == true, key = key }
						end
					end
					continue
				end

				local bestLoot, bestVal, bestContainer = nil, -1, nil
				for _, container in next, sources do
					for _, item in next, container.Occupants do
						if ownedIds[item.Id] or dropped[item.Id] or classify(item) ~= kind then
							continue
						end
						local value = supplyValue(item, kind)
						if value < minValue then
							continue
						end
						if value > bestVal then
							bestLoot, bestVal, bestContainer = item, value, container
						end
					end
				end
				if not bestLoot or not present(bestLoot, bestContainer) then
					continue
				end

				local want = counts[kind] < cap or (worst ~= nil and bestVal > worst.value)
				if not want then
					continue
				end

				local key = "pk:" .. bestLoot.Id
				if self:_ready(key, now) then
					if self:_canPickup(inventory, bestLoot) then
						return {
							act = "pickup",
							id = bestLoot.Id,
							item = bestLoot,
							container = bestContainer,
							pickKind = kind,
							name = bestLoot.Name,
							key = key,
						}
					elseif counts[kind] < cap then
						blockedWant = true
					end
				end

				if worst and worst.value < bestVal then
					local worseArea = 0
					for _, entry in next, owned do
						if entry.value < bestVal then
							worseArea += gridArea(entry.item)
						end
					end
					if worseArea >= gridArea(bestLoot) then
						local dropKey = "drop:" .. worst.item.Id
						if self:_ready(dropKey, now) then
							return {
								act = "drop",
								id = worst.item.Id,
								rotated = worst.item.Rotated == true,
								key = dropKey,
							}
						end
					end
				end
			end
		end

		if self._keepUtilities then
			local slotted = inventory.Utilities
			if type(slotted) == "table" then
				local limit = self:_utilityLimit()
				local covered: { [string]: boolean } = {}
				local slottedCount = 0
				for _, util in next, slotted do
					slottedCount += 1
					addPerks(covered, util)
				end

				if slottedCount < limit then
					local prefUtil: { [string]: boolean } = self._preferredUtilities
					local hasPreferred = next(prefUtil) ~= nil
					local function trySlot(item: any): any?
						if not isUtility(item) or dropped[item.Id] then
							return nil
						end
						if hasPreferred and (item.DisplayName == nil or not prefUtil[item.DisplayName]) then
							return nil
						end
						if not givesNewPerk(item, covered) or inventory:IsUtilitySlotted(item) then
							return nil
						end
						local key = "su:" .. item.Id
						if self:_ready(key, now) then
							return { act = "slotUtility", id = item.Id, item = item, key = key }
						end
						return nil
					end

					for _, container in next, inventory.Containers do
						if not container.IsCarried then
							continue
						end
						for _, item in next, container.Occupants do
							local action = trySlot(item)
							if action then
								return action
							end
						end
					end

					for _, container in next, sources do
						for _, item in next, container.Occupants do
							local action = trySlot(item)
							if action then
								return action
							end
						end
					end
				end
			end
		end

		local function canHarvest(caliber: any): boolean
			if not keepBoxes then
				return false
			end
			if not (caliber and calibers[caliber]) then
				return false
			end
			if (ammoStacks[caliber] or 0) >= maxAmmo then
				return false
			end
			if ammoBusy[caliber] or unloadCaliberBusy[caliber] or unloadSettle[caliber] ~= nil then
				return false
			end
			return true
		end

		for _, container in next, sources do
			for _, item in next, container.Occupants do
				if
					not isMagazine(item)
					or ownedIds[item.Id]
					or dropped[item.Id]
					or recentPicks[item.Id]
					or unloadInflight[item.Id]
				then
					continue
				end
				local caliber = item.Caliber
				if num(item.Amount) <= 0 or isMoving(item) or not canHarvest(caliber) then
					continue
				end
				if magFitsAny(weapons, item) then
					if (magCounts[item.Name or item.Caliber] or 0) < maxMags then
						continue
					end
				end
				local key = "ul:" .. item.Id
				if self:_ready(key, now) then
					return { act = "unload", id = item.Id, item = item, caliber = caliber, key = key }
				end
			end
		end

		for _, container in next, inventory.Containers do
			if not container.IsCarried then
				continue
			end
			for _, item in next, container.Occupants do
				if
					not isMagazine(item)
					or dropped[item.Id]
					or recentPicks[item.Id]
					or unloadInflight[item.Id]
					or magFitsAny(weapons, item)
				then
					continue
				end
				local caliber = item.Caliber
				if num(item.Amount) <= 0 or isMoving(item) or not canHarvest(caliber) then
					continue
				end
				local key = "ul:" .. item.Id
				if self:_ready(key, now) then
					return { act = "unload", id = item.Id, item = item, caliber = caliber, key = key }
				end
			end
		end

		for _, container in next, inventory.Containers do
			if not container.IsCarried and container.Name == "Ground" and not self._lootGround then
				continue
			end
			for _, item in next, container.Occupants do
				if item.Type ~= "Firearm" then
					continue
				end
				local attachments = item.Attachments
				local mag = type(attachments) == "table" and attachments.Ammo or nil
				if type(mag) == "table" and isMagazine(mag) and num(mag.Amount) > 0 and canHarvest(mag.Caliber) then
					local key = "ra:" .. mag.Id
					if self:_ready(key, now) then
						return { act = "removeAttach", id = mag.Id, gunId = item.Id, key = key }
					end
				end
			end
		end

		if keepMags and #weapons > 0 then
			local target, targetRoom = nil, 0
			for _, container in next, inventory.Containers do
				if not container.IsCarried then
					continue
				end
				for _, item in next, container.Occupants do
					if not isMagazine(item) or dropped[item.Id] or isMoving(item) or not magFitsAny(weapons, item) then
						continue
					end
					local caliber = item.Caliber
					if
						not caliber
						or ammoBusy[caliber]
						or unloadCaliberBusy[caliber]
						or unloadSettle[caliber] ~= nil
					then
						continue
					end
					local room = num(item.Capacity) - num(item.Amount)
					if room > 0 and room > targetRoom then
						target, targetRoom = item, room
					end
				end
			end

			if target then
				local caliber = target.Caliber
				local source = nil
				for _, container in next, inventory.Containers do
					if container.IsCarried then
						continue
					end
					for _, item in next, container.Occupants do
						if
							item.Type == "Ammo"
							and not isMoving(item)
							and item.Caliber == caliber
							and item.Id ~= target.Id
							and num(item.Amount) > 0
						then
							source = item
							break
						end
					end
					if source then
						break
					end
				end
				if source then
					local key = "cr:" .. tostring(source.Id)
					if self:_ready(key, now) then
						return { act = "craft", id = target.Id, sourceId = source.Id, caliber = caliber, key = key }
					end
				end
			end
		end

		if keepMags and #weapons > 0 then
			local looseAmmo = {}
			for _, group in next, packs do
				if group.caliber and group.total > 0 then
					looseAmmo[group.caliber] = true
				end
			end
			for _, container in next, sources do
				for _, item in next, container.Occupants do
					if isAmmoPack(item) and item.Caliber and num(item.Amount) > 0 then
						looseAmmo[item.Caliber] = true
					end
				end
			end

			for _, container in next, inventory.Containers do
				if not container.IsCarried then
					continue
				end
				for _, item in next, container.Occupants do
					if not isMagazine(item) or dropped[item.Id] or isMoving(item) or not magFitsAny(weapons, item) then
						continue
					end
					local caliber = item.Caliber
					if not caliber or not looseAmmo[caliber] then
						continue
					end
					if ammoBusy[caliber] or unloadCaliberBusy[caliber] then
						continue
					end
					if num(item.Amount) >= num(item.Capacity) then
						continue
					end
					local key = "fl:" .. item.Id
					if self:_ready(key, now) then
						return { act = "fill", id = item.Id, item = item, caliber = caliber, key = key }
					end
				end
			end
		end

		if keepBoxes then
			local target, targetRoom = nil, 0
			for _, container in next, inventory.Containers do
				if not container.IsCarried then
					continue
				end
				for _, item in next, container.Occupants do
					if not isAmmoPack(item) or dropped[item.Id] or isMoving(item) then
						continue
					end
					local caliber = item.Caliber
					if not caliber or not calibers[caliber] then
						continue
					end
					if ammoBusy[caliber] or unloadCaliberBusy[caliber] or unloadSettle[caliber] ~= nil then
						continue
					end
					local amount = num(item.Amount)
					local room = num(item.Capacity) - amount
					if amount > 0 and room > 0 and room > targetRoom then
						target, targetRoom = item, room
					end
				end
			end

			if target then
				local caliber = target.Caliber
				local source, sourceAmount = nil, math.huge
				for _, container in next, inventory.Containers do
					if container.IsCarried then
						continue
					end
					for _, item in next, container.Occupants do
						if
							item.Type == "Ammo"
							and not isMoving(item)
							and item.Caliber == caliber
							and item.Id ~= target.Id
						then
							local amount = num(item.Amount)
							if amount > 0 and amount < sourceAmount then
								source, sourceAmount = item, amount
							end
						end
					end
				end
				if source then
					local key = "cr:" .. tostring(source.Id)
					if self:_ready(key, now) then
						return {
							act = "craft",
							id = target.Id,
							sourceId = source.Id,
							caliber = caliber,
							key = key,
						}
					end
				end
			end
		end

		if blockedWant and keepSupplies then
			local caps = { heal = self._maxHeals, food = self._maxFood, drink = self._maxDrinks }
			local victim = nil
			for _, kind in next, SUPPLY_KINDS do
				local cap = caps[kind] or 0
				local owned = ownedSupplies[kind]
				if #owned > cap then
					for _, entry in next, owned do
						if not dropped[entry.item.Id] and (not victim or entry.value < victim.value) then
							victim = entry
						end
					end
				end
			end
			if victim then
				local key = "drop:" .. victim.item.Id
				if self:_ready(key, now) then
					return { act = "drop", id = victim.item.Id, rotated = victim.item.Rotated == true, key = key }
				end
			end
		end

		return nil
	end

	function AutoLoot._canPickup(_self: AutoLoot, inventory: any, item: any): boolean
		if inventory:ItemPickupCheck(item) == true then
			return true
		end
		return hasOpenStack(inventory, item)
	end

	function AutoLoot._execute(self: AutoLoot, _inventory: any, action: any): ()
		local tried: { [string]: number } = self._tried
		local dropped: { [any]: boolean } = self._dropped
		local recentPicks: { [any]: any } = self._recentPicks
		local ammoOp: { [any]: number } = self._ammoOp
		local unloading: { [any]: any } = self._unloading
		local unloadSettle: { [any]: number } = self._unloadSettle
		tried[action.key] = os.clock()
		autoLootApi.NotifyAction(action)
		local act = action.act
		if act == "equip" then
			send(EQUIP_PACKET, action.id)
		elseif act == "drop" then
			dropped[action.id] = true
			send(DROP_PACKET, action.id, action.rotated == true)
		elseif act == "pickup" then
			if present(action.item, action.container) then
				if action.pickKind then
					recentPicks[action.id] = {
						kind = action.pickKind,
						caliber = action.caliber,
						name = action.name,
						slot = action.slot,
						t = os.clock(),
					}
				end
				send(PICKUP_PACKET, action.id, action.container.Id)
			end
		elseif act == "removeAttach" then
			send(REMOVE_ATTACHMENT_PACKET, action.id, action.gunId)
		elseif act == "slotUtility" then
			send(SLOT_UTILITY_PACKET, action.id)
		elseif act == "unload" then
			unloading[action.id] = { item = action.item, t = os.clock() }
			if action.caliber then
				unloadSettle[action.caliber] = os.clock()
			end
			send(UNLOAD_PACKET, action.id)
		elseif act == "fill" then
			if action.caliber then
				ammoOp[action.caliber] = os.clock()
			end
			send(FILL_PACKET, action.id)
		elseif act == "craft" then
			if action.caliber then
				ammoOp[action.caliber] = os.clock()
			end
			send(CRAFT_PACKET, action.id, action.sourceId)
		end
	end

	function AutoLoot._confirm(_self: AutoLoot, inventory: any, action: any): (() -> boolean)?
		local act = action.act
		if act == "pickup" then
			local item, container = action.item, action.container
			return function(): boolean
				return not present(item, container)
			end
		elseif act == "drop" then
			local id = action.id
			return function(): boolean
				return not stillHeld(inventory, id)
			end
		elseif act == "unload" then
			local item = action.item
			return function(): boolean
				return item.Destroyed == true or num(item.Amount) <= 0
			end
		elseif act == "fill" then
			local item = action.item
			local capacity = num(item.Capacity)
			return function(): boolean
				return item.Destroyed == true or num(item.Amount) >= capacity
			end
		elseif act == "craft" then
			local sourceId = action.sourceId
			return function(): boolean
				local source = inventory:FindItem(sourceId)
				return source == nil or num(source.Amount) <= 0
			end
		elseif act == "slotUtility" then
			local item = action.item
			return function(): boolean
				return inventory:IsUtilitySlotted(item) == true
			end
		end
		return nil
	end

	function AutoLoot._reconcile(self: AutoLoot, inventory: any, action: any): ()
		if action.act ~= "drop" or not inventory then
			return
		end
		local id = action.id
		local stuck = stillHeld(inventory, id)
		if stuck then
			self._dropped[id] = nil
			self._tried[action.key] = nil
		end
	end

	function AutoLoot._fallback(_self: AutoLoot): number
		local localPlayer = Players.LocalPlayer
		if not localPlayer then
			return NET_TIMEOUT
		end
		local ping = localPlayer:GetNetworkPing()
		if type(ping) == "number" and ping > 0 then
			return math.clamp(0.2 + ping * 3, NET_TIMEOUT, MAX_NET_WAIT)
		end
		return NET_TIMEOUT
	end

	function AutoLoot._waitStep(self: AutoLoot, inventory: any, action: any): ()
		local start = os.clock()
		local fallback = self:_fallback()
		local confirm = self:_confirm(inventory, action)
		local signal = inventory and inventory.InventoryChanged
		if type(signal) ~= "table" or type(signal.Connect) ~= "function" then
			task.wait(fallback)
		else
			local thread = coroutine.running()
			local resumed = false
			local conn: any
			local function resume(): ()
				if resumed then
					return
				end
				resumed = true
				if conn then
					conn:Disconnect()
				end
				task.spawn(thread)
			end
			conn = signal:Connect(function(): ()
				if not confirm or confirm() then
					resume()
				end
			end)
			task.delay(fallback, resume)
			coroutine.yield()
		end

		local remaining = self._delay / 1000 - (os.clock() - start)
		if remaining > 0 then
			task.wait(remaining)
		end
	end

	function AutoLoot._wake(self: AutoLoot): ()
		if not self._enabled then
			return
		end
		self._pending = true
		if self._running then
			return
		end
		self._running = true
		autoLootApi.SetActive(true)
		task.spawn(function(): ()
			while self._enabled and self._pending do
				self._pending = false
				while self._enabled do
					local inventory = self:_getInventory()
					local action = inventory and self:_nextAction(inventory)
					if not action then
						local now = os.clock()
						local tried: { [string]: number } = self._tried
						for key, when in next, tried do
							if now - when >= RETRY_COOLDOWN then
								tried[key] = nil
							end
						end
						break
					end
					if not autoLootApi.RunFilters(action) then
						self._tried[action.key] = os.clock()
						continue
					end
					self:_execute(inventory, action)
					self:_waitStep(inventory, action)
					self:_reconcile(inventory, action)
				end
			end
			self._running = false
			autoLootApi.SetActive(false)
		end)
	end

	function AutoLoot._bind(self: AutoLoot): ()
		self:_unbind()

		local token = {}
		self._bindToken = token

		local function attempt(tries: number): ()
			if self._bindToken ~= token or not self._enabled then
				return
			end

			local inventory = self:_getInventory()
			if not inventory or not inventory.ContainerAdded then
				if tries > 0 then
					task.delay(0.5, function(): ()
						attempt(tries - 1)
					end)
				end
				return
			end

			local conns = self._conns
			local function track(connection: any): ()
				conns[#conns + 1] = connection
			end
			local function watchOccupants(container: any): ()
				if type(container.OccupantAdded) == "table" then
					track(container.OccupantAdded:Connect(function(): ()
						self:_wake()
					end))
				end
			end

			track(inventory.ContainerAdded:Connect(function(container: any): ()
				if not self._enabled then
					return
				end
				watchOccupants(container)
				self:_wake()
			end))
			track(inventory.InventoryChanged:Connect(function(): ()
				self:_wake()
			end))

			for _, container in next, inventory.Containers do
				if not container.IsCarried then
					watchOccupants(container)
				end
			end

			self:_wake()
		end

		attempt(BIND_TRIES)
	end

	function AutoLoot._unbind(self: AutoLoot): ()
		self._bindToken = nil
		for _, connection in next, self._conns do
			connection:Disconnect()
		end
		self._conns = {}
		self._dropped = {}
		self._tried = {}
		self._recentPicks = {}
		self._ammoOp = {}
		self._unloading = {}
		self._unloadSettle = {}
	end

	function AutoLoot.Enable(self: AutoLoot): ()
		if self._enabled then
			return
		end
		self._enabled = true
		self._pending = false
		self._running = false
		autoLootApi.SetEnabled(true)
		autoLootApi.SetWaker(function(): ()
			self:_wake()
		end)

		self._charConn = sub(clientState.character, function(model: Model?): ()
			if model then
				task.defer(function(): ()
					if self._enabled then
						self:_bind()
					end
				end)
			else
				self:_unbind()
			end
		end)

		self._menuVisible = self:_isMenuVisible()
		local visibility = self:_visibilitySignal()
		if visibility then
			self._visConn = visibility:Connect(function(): ()
				if not self._enabled then
					return
				end
				self:_wake()
				local visible = self:_isMenuVisible()
				if visible and not self._menuVisible then
					self._menuVisible = true
					if self._lootAura then
						self:_auraScan()
					end
				elseif not visible then
					self._menuVisible = false
				end
			end)
		end

		local token = {}
		self._tickToken = token
		local function tick(): ()
			if self._tickToken ~= token or not self._enabled then
				return
			end
			self:_wake()
			task.delay(SAFETY_TICK, tick)
		end
		task.delay(SAFETY_TICK, tick)

		self:_bind()
	end

	function AutoLoot.Disable(self: AutoLoot): ()
		if not self._enabled then
			return
		end
		self._enabled = false
		self._tickToken = nil
		self._menuVisible = false
		self._pending = false
		autoLootApi.SetEnabled(false)
		autoLootApi.SetActive(false)
		autoLootApi.SetWaker(nil)

		if self._visConn then
			self._visConn:Disconnect()
			self._visConn = nil
		end

		local charConn = self._charConn
		if charConn then
			charConn()
			self._charConn = nil
		end
		self:_unbind()
	end

	function AutoLoot.Destroy(self: AutoLoot): ()
		self:Disable()
		BaseFeature.Destroy(self)
	end

	export type AutoLoot =
		typeof(setmetatable(
			{} :: {
				_enabled: boolean,
				_conns: { any },
				_charConn: (() -> ())?,
				_visConn: any,
				_bindToken: any,
				_tickToken: any,
				_dropped: { [any]: boolean },
				_tried: { [string]: number },
				_recentPicks: { [any]: any },
				_ammoOp: { [any]: number },
				_unloading: { [any]: any },
				_unloadSettle: { [any]: number },
				_pending: boolean,
				_running: boolean,
				_lootAura: boolean,
				_menuVisible: boolean,
				_registry: any,
				_interface: any,
				_manageWeapons: boolean,
				_dropWeapons: boolean,
				_weaponStat: { string },
				_preferred: { [string]: boolean },
				_secondaryStat: { string }?,
				_spareStat: { string }?,
				_maxWeapons: number,
				_onlyUpgrade: boolean,
				_keepBoxes: boolean,
				_keepMags: boolean,
				_maxAmmo: number,
				_maxMags: number,
				_keepSupplies: boolean,
				_maxHeals: number,
				_maxFood: number,
				_maxDrinks: number,
				_minHeals: number,
				_minFood: number,
				_minDrinks: number,
				_keepUtilities: boolean,
				_preferredUtilities: { [string]: boolean },
				_utilLimit: number?,
				_lootGround: boolean,
				_delay: number,
			},
			AutoLoot
		))
		& BaseFeature.BaseFeature

	return AutoLoot
end)()
