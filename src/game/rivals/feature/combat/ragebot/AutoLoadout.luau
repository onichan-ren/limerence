local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local ModuleController = require("@game/rivals/module/ModuleController")
local NetworkController = require("@game/rivals/network/NetworkController")

local LocalPlayer = Players.LocalPlayer

local AUTO = "Auto"
local RANDOM = "Random"

local PICK_PATH = "Replication.Fighter.PickWeapons"
local PICK_AHEAD_PATH = "Duels.PickWeaponsAheadOfTime"

local SLOTS: { { key: string, label: string, class: string } } = {
	{ key = "primary", label = "Primary", class = "Primary" },
	{ key = "secondary", label = "Secondary", class = "Secondary" },
	{ key = "melee", label = "Melee", class = "Melee" },
	{ key = "utility", label = "Utility", class = "Utility" },
}

local function getController(name: string): any?
	local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local controllers = scripts and scripts:FindFirstChild("Controllers")
	local module = controllers and controllers:FindFirstChild(name)
	if not module then
		return nil
	end
	return require(module :: ModuleScript)
end

local function getLibrary(): (any?, any?)
	local itemLibrary = ModuleController.GetModule("ItemLibrary")
	if not itemLibrary then
		return nil, nil
	end
	return rawget(itemLibrary, "Items"), rawget(itemLibrary, "SlotToClass")
end

local function canUse(fighter: any, name: string): boolean
	return fighter:CanUseWeapon(name) == true
end

local function weaponsForClass(class: string): { string }
	local out: { string } = {}
	local items = (getLibrary())
	if items then
		for name, info in next, items do
			if type(info) == "table" and info.Class == class and name ~= "MISSING_WEAPON" then
				out[#out + 1] = name
			end
		end
	end
	table.sort(out)
	table.insert(out, 1, RANDOM)
	table.insert(out, 1, AUTO)
	return out
end

local AutoLoadout = {}
AutoLoadout.__index = AutoLoadout

setmetatable(AutoLoadout, { __index = BaseFeature })

function AutoLoadout.new(link: gameUi.Linker): AutoLoadout
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoLoadout)

	link:Toggle("autoLoadout", "Auto Select Loadout", false):SetTip({
		title = "Auto Select Loadout",
		body = "Auto-picks your chosen weapons the moment the round lets you select a loadout.",
	})

	local loadoutLink = link:OnKey("autoLoadout")
	loadoutLink:Submenu("opts", "Loadout")
	local optsLink = loadoutLink:OnKey("opts")

	self._prefs = {} :: { [string]: string }
	for _, entry in next, SLOTS do
		optsLink:Dropdown(entry.key, entry.label, weaponsForClass(entry.class), AUTO)
		self._prefs[entry.class] = optsLink:Peek(entry.key) or AUTO
		self:Track(optsLink:Get(entry.key):OnChange(function(v: string): ()
			self._prefs[entry.class] = v or AUTO
			self:_queueRepick()
		end))
	end

	self._link = link
	self._enabledLink = link:Get("autoLoadout")
	self._janitor = Janitor.new()
	self._picked = false
	self._fighter = nil
	self._repickToken = 0

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("autoLoadout") then
		self:Enable()
	end

	return self
end

function AutoLoadout._resolveWeapon(self: AutoLoadout, fighter: any, items: any, class: string): string?
	local pref = self._prefs[class]
	if pref and pref ~= AUTO and pref ~= RANDOM then
		if canUse(fighter, pref) then
			return pref
		end
	end

	local pool: { string } = {}
	for name, info in next, items do
		if type(info) == "table" and info.Class == class and name ~= "MISSING_WEAPON" and canUse(fighter, name) then
			pool[#pool + 1] = name
		end
	end
	if #pool == 0 then
		return nil
	end
	table.sort(pool)
	if pref == RANDOM then
		return pool[math.random(1, #pool)]
	end
	return pool[1]
end

function AutoLoadout._useAheadOfTime(_self: AutoLoadout): boolean
	local duelController = getController("DuelController")
	if not duelController or type(duelController.GetDuel) ~= "function" then
		return false
	end
	local duel = duelController:GetDuel(LocalPlayer)
	local dueler = duel and duel.LocalDueler
	if dueler and type(dueler.GetStaggeredSpawnsTurn) == "function" then
		local turn = dueler:GetStaggeredSpawnsTurn()
		return turn ~= nil and turn ~= false
	end
	return false
end

function AutoLoadout._doPick(self: AutoLoadout, fighter: any): ()
	local items, slotToClass = getLibrary()
	if not items or not slotToClass then
		return
	end

	local maxSlots = 0
	local count = fighter:GetMaxEquippableWeapons()
	if type(count) == "number" then
		maxSlots = count
	end
	if maxSlots <= 0 then
		return
	end

	local chosen: { string } = {}
	for i = 1, maxSlots do
		local classInfo = slotToClass[i]
		local class = classInfo and classInfo.Name
		if not class then
			return
		end
		local weapon = self:_resolveWeapon(fighter, items, class)
		if not weapon then
			return
		end
		chosen[i] = weapon
	end

	if self:_useAheadOfTime() then
		NetworkController.SendRemote(PICK_AHEAD_PATH, chosen)
	else
		NetworkController.SendRemote(PICK_PATH, chosen)
	end
end

function AutoLoadout._queueRepick(self: AutoLoadout): ()
	self._repickToken += 1
	local token = self._repickToken
	task.delay(0.25, function(): ()
		if token == self._repickToken then
			self:_repick()
		end
	end)
end

function AutoLoadout._repick(self: AutoLoadout): ()
	if not self._enabled then
		return
	end

	local fighter = self._fighter
	if not fighter then
		return
	end

	if fighter:Get("CanPickWeapons") or self:_useAheadOfTime() then
		self:_doPick(fighter)
	end
end

function AutoLoadout.Enable(self: AutoLoadout): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._picked = false

	task.spawn(function(): ()
		local fighterController = getController("FighterController")
		if not fighterController then
			return
		end
		local fighter = fighterController.LocalFighter
		if not fighter and type(fighterController.WaitForLocalFighter) == "function" then
			fighter = fighterController:WaitForLocalFighter()
		end
		if not fighter or not self._enabled then
			return
		end
		self._fighter = fighter

		local function check(): ()
			if not self._enabled then
				return
			end
			if fighter:Get("CanPickWeapons") then
				if not self._picked then
					self._picked = true
					self:_doPick(fighter)
				end
			else
				self._picked = false
			end
		end

		self._janitor:Add(fighter:GetDataChangedSignal("CanPickWeapons"):Connect(check), "Disconnect")
		check()
	end)
end

function AutoLoadout.Disable(self: AutoLoadout): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._picked = false
	self._fighter = nil
	self._repickToken += 1
	self._janitor:Cleanup()
end

function AutoLoadout.Destroy(self: AutoLoadout): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoLoadout = typeof(setmetatable(
	{} :: {
		_link: gameUi.Linker,
		_enabledLink: any,
		_enabled: boolean,
		_prefs: { [string]: string },
		_picked: boolean,
		_fighter: any,
		_repickToken: number,
		_janitor: Janitor.Janitor,
	},
	AutoLoadout
)) & BaseFeature.BaseFeature

return AutoLoadout
