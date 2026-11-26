local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local NetworkController = require("@game/overkill/network/NetworkController")
local ModuleController = require("@game/overkill/module/ModuleController")

local LocalPlayer = Players.LocalPlayer

local AUTO = "Auto"
local RANDOM = "Random"

local SLOTS: { { key: string, label: string, slot: number } } = {
	{ key = "primary", label = "Primary", slot = 1 },
	{ key = "secondary", label = "Secondary", slot = 2 },
	{ key = "melee", label = "Melee", slot = 3 },
	{ key = "utility", label = "Utility", slot = 4 },
}

local AutoLoadout = {}
AutoLoadout.__index = AutoLoadout

setmetatable(AutoLoadout, { __index = BaseFeature })

local function isTemp(name: string): boolean
	return string.find(string.lower(name), "_temp", 1, true) ~= nil
end

local function buildSlotOptions(items: any, slotNum: number): ({ string }, { [string]: string })
	local nameToId: { [string]: string } = {}
	local names: { { name: string, order: number } } = {}

	if items and items.all then
		for id, data in next, items.all do
			if type(data) == "table" and data.slot == slotNum then
				local name = data.name or id
				if not isTemp(name) then
					nameToId[string.lower(name)] = id
					table.insert(names, { name = name, order = data.layoutOrder or 9000 })
				end
			end
		end
	end

	table.sort(names, function(a, b): boolean
		return a.order < b.order
	end)

	local options: { string } = { AUTO, RANDOM }
	for _, entry in next, names do
		table.insert(options, entry.name)
	end

	return options, nameToId
end

function AutoLoadout.new(link: gameUi.Linker): AutoLoadout
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoLoadout)

	local items = ModuleController.GetModule("items")
	self._items = items

	link:Toggle("autoLoadout", "Auto Loadout", false):SetTip({
		title = "Auto Loadout",
		body = "Auto-picks your weapons the moment a round's loadout select opens.",
	})

	local loadoutLink = link:OnKey("autoLoadout")
	loadoutLink:Submenu("opts", "Loadout")
	local optsLink = loadoutLink:OnKey("opts")

	self._prefs = {} :: { [number]: string }
	self._nameToId = {} :: { [number]: { [string]: string } }
	for _, entry in next, SLOTS do
		local options, nameToId = buildSlotOptions(items, entry.slot)
		self._nameToId[entry.slot] = nameToId
		optsLink:Dropdown(entry.key, entry.label, options, AUTO)
		self._prefs[entry.slot] = optsLink:Peek(entry.key) or AUTO
		self:Track(optsLink:Get(entry.key):OnChange(function(value: string): ()
			self._prefs[entry.slot] = value or AUTO
			self:_queueRepick()
		end))
	end

	self._enabled = false
	self._repickToken = 0
	self._gameplayHandler = nil
	self._inventoryHandler = nil
	self._cameraHandler = nil

	self:Track(link:Get("autoLoadout"):OnChange(function(value: boolean): ()
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

function AutoLoadout._resolveWeapon(self: AutoLoadout, slotNum: number, isRange: boolean): string?
	local items = self._items
	local inventoryHandler = self._inventoryHandler
	if not items or not items.all then
		return nil
	end

	local function usable(id: string, data: any): boolean
		if data.slot ~= slotNum or isTemp(data.name or id) then
			return false
		end
		return isRange or inventoryHandler:OwnsItem(id) == true
	end

	local pref = self._prefs[slotNum]
	if pref and pref ~= AUTO and pref ~= RANDOM then
		local id = self._nameToId[slotNum][string.lower(pref)]
		local data = id and items.all[id]
		if data and usable(id, data) then
			return id
		end
	end

	local pool: { { id: string, order: number } } = {}
	for id, data in next, items.all do
		if type(data) == "table" and usable(id, data) then
			table.insert(pool, { id = id, order = data.layoutOrder or 9000 })
		end
	end
	if #pool == 0 then
		return nil
	end
	table.sort(pool, function(a, b): boolean
		return a.order < b.order
	end)

	if pref == RANDOM then
		return pool[math.random(1, #pool)].id
	end
	return pool[1].id
end

function AutoLoadout._autoPick(self: AutoLoadout): ()
	if not self._enabled then
		return
	end

	local gameplayHandler = self._gameplayHandler
	if not gameplayHandler then
		return
	end

	local duel = gameplayHandler:GetLocalDuel()
	if type(duel) ~= "table" then
		return
	end

	local roundState = duel.roundState
	if not roundState or roundState.finishedSelectingWeapons then
		return
	end

	local isRange = duel.mode == "range"

	local chosen: { string } = {}
	for slotNum = 1, 4 do
		local weapon = self:_resolveWeapon(slotNum, isRange)
		if not weapon then
			return
		end
		chosen[slotNum] = weapon
	end

	roundState.selectingWeapons = false
	roundState.finishedSelectingWeapons = true
	duel.clientHasSelectedGuns = true

	local weaponSelection = gameplayHandler.weaponSelectionModule
	local cameraHandler = self._cameraHandler

	setthreadidentity(2)
	NetworkController.Fire("select_guns", chosen)
	if weaponSelection and weaponSelection:IsOpen() then
		weaponSelection:Close()
	end
	if cameraHandler then
		cameraHandler:toggleFreeMouse(false)
		cameraHandler:toggleMode(true)
	end
	setthreadidentity(8)
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

	local gameplayHandler = self._gameplayHandler
	if not gameplayHandler or gameplayHandler:IsSpectating() then
		return
	end

	local duel = gameplayHandler:GetLocalDuel()
	if type(duel) ~= "table" or duel.mode == "range" then
		return
	end

	local roundState = duel.roundState
	if not roundState or not roundState.finishedSelectingWeapons then
		return
	end
	if roundState.started or roundState.ended then
		return
	end

	local chosen: { string } = {}
	for slotNum = 1, 4 do
		local weapon = self:_resolveWeapon(slotNum, false)
		if not weapon then
			return
		end
		chosen[slotNum] = weapon
	end

	NetworkController.Fire("begin_weapon_selection")
	if #duel.completedRounds ~= 0 then
		NetworkController.Fire("reset_inventory")
	end
	NetworkController.Fire("select_guns", chosen)
end

function AutoLoadout.Enable(self: AutoLoadout): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._gameplayHandler = ModuleController.GetModule("gameplayHandler")
	self._inventoryHandler = ModuleController.GetModule("inventoryHandler")
	self._cameraHandler = ModuleController.GetModule("cameraHandler")

	NetworkController.HookPacket("begin_weapon_selection", function(): (boolean?, any?)
		task.delay(0.1, function(): ()
			self:_autoPick()
		end)
		return true
	end)
end

function AutoLoadout.Disable(self: AutoLoadout): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._repickToken += 1
	NetworkController.UnhookPacket("begin_weapon_selection")
end

function AutoLoadout.Destroy(self: AutoLoadout): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoLoadout =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_repickToken: number,
			_items: any,
			_prefs: { [number]: string },
			_nameToId: { [number]: { [string]: string } },
			_gameplayHandler: any,
			_inventoryHandler: any,
			_cameraHandler: any,
		},
		AutoLoadout
	))
	& BaseFeature.BaseFeature

return AutoLoadout
