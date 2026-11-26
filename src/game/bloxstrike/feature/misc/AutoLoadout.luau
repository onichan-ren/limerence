local Players = cloneref(game:GetService("Players")) :: Players
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local BaseFeature = require("@game/BaseFeature")
local NetworkController = require("@game/bloxstrike/network/NetworkController")
local ClientState = require("@game/bloxstrike/client/clientState")
local inventoryDataAccess = require("@game/bloxstrike/feature/inventory/inventoryDataAccess")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local gameUi = require("@game/gameUi")

local peek = Charm.peek

local LocalPlayer = Players.LocalPlayer

local PRIMARY_CHOICES = { "Rifle", "AWP", "SSG 08" }
local SECONDARY_CHOICES = { "Desert Eagle", "R8 Revolver" }
local UTILITY_CHOICES = { "Flashbang", "Smoke", "Molotov", "HE Grenade", "Decoy Grenade" }

local TEAM_RIFLE: { [string]: string } = {
	["Terrorists"] = "AK-47",
	["Counter-Terrorists"] = "M4A4",
}

local TEAM_MOLOTOV: { [string]: string } = {
	["Terrorists"] = "Molotov",
	["Counter-Terrorists"] = "Incendiary Grenade",
}

local LOADOUT_NAME: { [string]: string } = {
	["Incendiary Grenade"] = "Molotov",
}

local EQUIPMENT_ONLY: { [string]: true } = {
	["Kevlar"] = true,
	["Kevlar + Helmet"] = true,
	["Defuse Kit"] = true,
	["Rescue Kit"] = true,
}

local BUY_PACKET_INTERVAL = 0.35

local SPECIAL_PATHS: { [string]: string } = {
	["Zeus x27"] = "Equipped.Equipped Zeus x27",
}

local function resolveItemName(name: string, team: string?): string
	if name == "Rifle" then
		return TEAM_RIFLE[team or ""] or "AK-47"
	end
	if name == "Molotov" then
		return TEAM_MOLOTOV[team or ""] or "Molotov"
	end
	if name == "Smoke" then
		return "Smoke Grenade"
	end
	return name
end

local function requireGameModule(inst: Instance): any?
	setthreadidentity(2)
	local mod = require(inst)
	setthreadidentity(8)
	return mod
end

local Grenades = requireGameModule((ReplicatedStorage :: any).Database.Custom.GameStats.Grenades) or {}

local GRENADE_LIMITS: { [string]: number } = {
	["Decoy Grenade"] = 1,
	["Smoke Grenade"] = 1,
	["HE Grenade"] = 1,
	Flashbang = 2,
	Molotov = 1,
	["Incendiary Grenade"] = 1,
}

local function getGrenadeLimit(name: string): number?
	local limit = (Grenades :: any)[name]
	if limit ~= nil then
		return limit
	end
	return GRENADE_LIMITS[name]
end

local function isGrenade(name: string): boolean
	return getGrenadeLimit(name) ~= nil
end

local function getCurrentInventory(): any?
	local inv = peek(loadoutState.inventory)
	if type(inv) == "table" and next(inv) ~= nil then
		return inv
	end
	local cachedLoadout = peek(loadoutState.loadout)
	if type(cachedLoadout) == "table" and not (cachedLoadout :: any).IsDestroyed then
		local rawInv = rawget(cachedLoadout, "Inventory")
		if type(rawInv) == "table" then
			return rawInv
		end
	end
	return (type(inv) == "table" and inv or nil)
end

local function getInventoryItemCount(inventory: any, weaponName: string): number
	if type(inventory) ~= "table" then
		return 0
	end
	local count = 0
	for _, slot in next, inventory do
		if type(slot) ~= "table" then
			continue
		end
		local items = rawget(slot, "_items")
		if type(items) ~= "table" then
			continue
		end
		for _, item in next, items do
			if type(item) == "table" and item.Name == weaponName then
				count += 1
			end
		end
	end
	return count
end

local function hasInventoryWeapon(inventory: any, weaponName: string): boolean
	return getInventoryItemCount(inventory, weaponName) > 0
end

local function alreadyOwns(inventory: any, name: string): boolean
	local grenadeLimit = getGrenadeLimit(name)
	if grenadeLimit ~= nil then
		return getInventoryItemCount(inventory, name) >= grenadeLimit
	end
	return hasInventoryWeapon(inventory, name)
end

local function findWeaponDef(name: string): Instance?
	local weapons = (ReplicatedStorage :: any).Database.Custom.Weapons
	local inst = weapons:FindFirstChild(name)
	if inst then
		return inst
	end
	return weapons:FindFirstChild((string.gsub(name, " ", "_")))
end

local function readItemCost(name: string): number
	local db = (ReplicatedStorage :: any).Database
	local defInst = findWeaponDef(name) or db.Custom.GameStats.Equipment:FindFirstChild(name)
	if not defInst then
		return 0
	end
	local def = requireGameModule(defInst)
	if type(def) ~= "table" then
		return 0
	end
	return tonumber((def :: any).Cost) or 0
end

local function findLoadoutPath(weaponName: string, team: string): string?
	local pd = inventoryDataAccess.getPlayerData()
	if not pd then
		return nil
	end
	local loadout = (pd :: any).Loadout
	if type(loadout) ~= "table" then
		return nil
	end
	local teamLoadout = loadout[team]
	if type(teamLoadout) ~= "table" or type(teamLoadout.Loadout) ~= "table" then
		return nil
	end
	for category, categoryData in next, teamLoadout.Loadout do
		local options = type(categoryData) == "table" and categoryData.Options
		if type(options) ~= "table" then
			continue
		end
		for slotIdx, equippedId in next, options do
			if type(equippedId) ~= "string" or equippedId == "" then
				continue
			end
			local item = inventoryDataAccess.findInventoryItem(equippedId, false)
			if item and item.Name == weaponName then
				return `Loadout.{category}.Options.{slotIdx}`
			end
		end
	end
	return nil
end

local function findGrenadePath(weaponName: string, team: string): string?
	weaponName = LOADOUT_NAME[weaponName] or weaponName
	local path = findLoadoutPath(weaponName, team)
	if path then
		return path
	end

	local pd = inventoryDataAccess.getPlayerData()
	if not pd then
		return nil
	end
	local loadout = (pd :: any).Loadout
	if type(loadout) ~= "table" then
		return nil
	end
	local teamLoadout = loadout[team]
	if type(teamLoadout) ~= "table" or type(teamLoadout.Loadout) ~= "table" then
		return nil
	end
	local grenades = teamLoadout.Loadout.Grenades
	if type(grenades) ~= "table" or type(grenades.Options) ~= "table" then
		return nil
	end

	local firstPath: string? = nil
	for slotIdx, equippedId in next, grenades.Options do
		if type(slotIdx) ~= "number" then
			continue
		end
		local slotPath = `Loadout.Grenades.Options.{slotIdx}`
		if not firstPath then
			firstPath = slotPath
		end
		if type(equippedId) ~= "string" or equippedId == "" then
			continue
		end
		local item = inventoryDataAccess.findInventoryItem(equippedId, false)
		if item and item.Name == weaponName then
			return slotPath
		end
	end

	return firstPath
end

local function resolvePath(name: string, team: string): string?
	if SPECIAL_PATHS[name] then
		return SPECIAL_PATHS[name]
	end
	if isGrenade(name) then
		return findGrenadePath(name, team)
	end
	if EQUIPMENT_ONLY[name] then
		return ""
	end
	return findLoadoutPath(name, team)
end

local function sendBuy(name: string, team: string): ()
	local path = resolvePath(name, team)
	if isGrenade(name) and (not path or path == "") then
		return
	end
	setthreadidentity(2)
	NetworkController.SendPacket("Inventory", "BuyMenuPurchase", {
		Equipment = EQUIPMENT_ONLY[name] == true,
		Name = name,
		Path = path or "",
	})
	setthreadidentity(8)
end

local function queueBuys(team: string, names: { string }): ()
	for i, name in next, names do
		task.delay(BUY_PACKET_INTERVAL * (i - 1), function()
			sendBuy(name, team)
		end)
	end
end

local AutoLoadout = {}
AutoLoadout.__index = AutoLoadout

setmetatable(AutoLoadout, { __index = BaseFeature })

function AutoLoadout.new(link: gameUi.Linker): AutoLoadout
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoLoadout)

	link:Toggle("autoLoadout", "Automatic Loadout", false):SetTip({
		title = "Automatic Loadout",
		body = "Automatically purchase your weapons when the buy period starts.",
	})
	local rootLink = link:OnKey("autoLoadout")
	rootLink:Submenu("opts", "Automatic Loadout")
	local optsLink = rootLink:OnKey("opts")

	optsLink:Dropdown("primary", "Primary", PRIMARY_CHOICES, "Rifle"):SetTip({
		title = "Primary",
		body = 'Bought first. "Rifle" resolves to your team\'s rifle (AK-47 / M4A4).',
	})
	local primaryLink = optsLink:OnKey("primary")
	primaryLink:Submenu("opts", "Primary")
	primaryLink:OnKey("opts"):Dropdown("fallback", "Fallback", PRIMARY_CHOICES, "SSG 08"):SetTip({
		title = "Fallback",
		body = "Bought instead of the primary when you can't afford it.",
	})

	optsLink:Dropdown("secondary", "Secondary", SECONDARY_CHOICES, "Desert Eagle"):SetTip({
		title = "Secondary Weapon",
		body = "Bought after the primary.",
	})

	optsLink
		:Dropdown("utility", "Utilities", UTILITY_CHOICES, { "Flashbang", "Smoke" } :: any)
		:SetMode("multi")
		:SetMin(0)
		:SetTip({
			title = "Utilities",
			body = "Grenades bought after weapons. Molotov auto-swaps to Incendiary Grenade on CT.",
		})

	optsLink:Toggle("zeus", "Zeus / Taser", false):SetTip({
		title = "Zeus / Taser",
		body = "Buys the taser after your weapons and grenades.",
	})

	self._enabled = false
	self._boughtThisPeriod = false
	self._janitor = Janitor.new()
	self._primary = optsLink:Get("primary"):Peek() or "Rifle"
	self._fallback = primaryLink:Get("opts.fallback"):Peek() or "SSG 08"
	self._secondary = optsLink:Get("secondary"):Peek() or "Desert Eagle"
	self._utility = optsLink:Get("utility"):Peek() or {}
	self._zeus = optsLink:Get("zeus"):Peek() == true

	self:Track(link:Get("autoLoadout"):OnChange(function(value: boolean)
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optsLink:Get("primary"):OnChange(function(value: string)
		self._primary = value
	end))
	self:Track(primaryLink:Get("opts.fallback"):OnChange(function(value: string)
		self._fallback = value
	end))
	self:Track(optsLink:Get("secondary"):OnChange(function(value: string)
		self._secondary = value
	end))
	self:Track(optsLink:Get("utility"):OnChange(function(value: { string })
		self._utility = value or {}
	end))
	self:Track(optsLink:Get("zeus"):OnChange(function(value: boolean)
		self._zeus = value == true
	end))

	return self
end

function AutoLoadout._purchase(self: AutoLoadout): ()
	local team = peek(ClientState.team) :: string?
	if not team then
		return
	end

	task.wait(1)
	if not self._enabled then
		return
	end

	local inventory = getCurrentInventory()
	local money = tonumber(LocalPlayer:GetAttribute("Money")) or 0

	local primaryName = resolveItemName(self._primary, team)
	local fallbackName = resolveItemName(self._fallback, team)
	local secondaryName = resolveItemName(self._secondary, team)

	local utilityNames: { string } = {}
	local utilityCosts: { number } = {}
	local utilityTotal = 0
	for _, name in next, self._utility do
		local resolved = resolveItemName(name, team)
		if alreadyOwns(inventory, resolved) then
			continue
		end
		local cost = readItemCost(resolved)
		utilityNames[#utilityNames + 1] = resolved
		utilityCosts[#utilityCosts + 1] = cost
		utilityTotal += cost
	end

	local primaryCost = readItemCost(primaryName)
	local fallbackCost = readItemCost(fallbackName)
	local secondaryCost = readItemCost(secondaryName)

	local needsPrimary = not alreadyOwns(inventory, primaryName)
	local needsFallback = not alreadyOwns(inventory, fallbackName)
	local needsSecondary = not alreadyOwns(inventory, secondaryName)

	local zeusName = "Zeus x27"
	local needsZeus = self._zeus and not alreadyOwns(inventory, zeusName)
	local zeusCost = needsZeus and readItemCost(zeusName) or 0

	local availableForPrimary = money
	if needsSecondary then
		availableForPrimary -= secondaryCost
	end
	availableForPrimary -= utilityTotal
	availableForPrimary -= zeusCost

	local primaryPick: string? = nil
	local primaryPickCost = 0
	if needsPrimary and availableForPrimary >= primaryCost then
		primaryPick = primaryName
		primaryPickCost = primaryCost
	elseif needsFallback and availableForPrimary >= fallbackCost then
		primaryPick = fallbackName
		primaryPickCost = fallbackCost
	elseif needsFallback and money >= fallbackCost then
		primaryPick = fallbackName
		primaryPickCost = fallbackCost
	end

	local buyQueue: { string } = {}

	if primaryPick and money >= primaryPickCost then
		buyQueue[#buyQueue + 1] = primaryPick
		money -= primaryPickCost
	end

	if needsSecondary and money >= secondaryCost then
		buyQueue[#buyQueue + 1] = secondaryName
		money -= secondaryCost
	end

	for i, name in next, utilityNames do
		if money >= utilityCosts[i] then
			buyQueue[#buyQueue + 1] = name
			money -= utilityCosts[i]
		end
	end

	if needsZeus and money >= zeusCost then
		buyQueue[#buyQueue + 1] = zeusName
		money -= zeusCost
	end

	if #buyQueue > 0 then
		queueBuys(team, buyQueue)
	end
end

function AutoLoadout.Enable(self: AutoLoadout): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._janitor:Add(
		Workspace:GetAttributeChangedSignal("GameState"):Connect(function(): ()
			if Workspace:GetAttribute("GameState") == "Buy Period" then
				if self._boughtThisPeriod then
					return
				end
				self._boughtThisPeriod = true
				task.defer(function()
					if self._enabled then
						self:_purchase()
					end
				end)
			else
				self._boughtThisPeriod = false
			end
		end),
		"Disconnect"
	)

	if Workspace:GetAttribute("GameState") == "Buy Period" and not self._boughtThisPeriod then
		self._boughtThisPeriod = true
		task.defer(function()
			if self._enabled then
				self:_purchase()
			end
		end)
	end
end

function AutoLoadout.Disable(self: AutoLoadout): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._boughtThisPeriod = false
	self._janitor:Cleanup()
end

function AutoLoadout.Destroy(self: AutoLoadout): ()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type AutoLoadout =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_boughtThisPeriod: boolean,
			_janitor: Janitor.Janitor,
			_primary: string,
			_fallback: string,
			_secondary: string,
			_utility: { string },
			_zeus: boolean,
		},
		AutoLoadout
	))
	& BaseFeature.BaseFeature

return AutoLoadout
