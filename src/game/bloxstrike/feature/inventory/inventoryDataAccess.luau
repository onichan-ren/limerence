local Players = cloneref(game:GetService("Players")) :: Players
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local logger = require("@share/logger").new("inventoryDataAccess")

local LocalPlayer = Players.LocalPlayer

local inventoryDataAccess = {
	_dataController = nil :: any,
	_executeListeners = nil :: ((Player, { string }) -> ())?,
	_playerData = nil :: { [Player]: any }?,
}

local function loadDataController(): any?
	if inventoryDataAccess._dataController then
		return inventoryDataAccess._dataController
	end
	setthreadidentity(2)
	local mod = require(ReplicatedStorage.Controllers.DataController)
	setthreadidentity(8)
	if type(mod) ~= "table" then
		logger:error("failed to require DataController")
		return nil
	end
	inventoryDataAccess._dataController = mod
	return mod
end

local function resolveInternals(): ()
	if inventoryDataAccess._executeListeners and inventoryDataAccess._playerData then
		return
	end
	local mod = loadDataController()
	if not mod or type(mod.ApplyInventoryDelta) ~= "function" then
		return
	end
	local inner = debug.getupvalue(mod.ApplyInventoryDelta, 1)
	if type(inner) ~= "function" then
		logger:error("failed to resolve internal ApplyInventoryDelta")
		return
	end
	local data = debug.getupvalue(inner, 1)
	local exec = debug.getupvalue(inner, 4)
	if type(data) == "table" then
		inventoryDataAccess._playerData = data
	end
	if type(exec) == "function" then
		inventoryDataAccess._executeListeners = exec
	end
end

function inventoryDataAccess.getInventory(): { any }
	local mod = loadDataController()
	if not mod or not LocalPlayer then
		return {}
	end
	setthreadidentity(2)
	local list = mod.Get(LocalPlayer, "Inventory")
	setthreadidentity(8)
	return (type(list) == "table" and list or {})
end

function inventoryDataAccess.applyInventoryDelta(items: { any }, deletedIds: { string }?): ()
	local mod = loadDataController()
	if not mod or not LocalPlayer then
		return
	end
	setthreadidentity(2)
	mod.ApplyInventoryDelta(LocalPlayer, items, deletedIds)
	setthreadidentity(8)
end

function inventoryDataAccess.fireListeners(path: { string }): ()
	resolveInternals()
	local exec = inventoryDataAccess._executeListeners
	if not exec or not LocalPlayer then
		return
	end
	setthreadidentity(2)
	exec(LocalPlayer, path)
	setthreadidentity(8)
end

function inventoryDataAccess.findInventoryItem(idOrName: string, byName: boolean?): any?
	local inventory = inventoryDataAccess.getInventory()
	for _, entry in next, inventory do
		if type(entry) ~= "table" then
			continue
		end
		if byName then
			if entry.Name == idOrName then
				return entry
			end
		else
			if entry._id == idOrName then
				return entry
			end
		end
	end
	return nil
end

function inventoryDataAccess.getPlayerData(): any?
	resolveInternals()
	local pd = inventoryDataAccess._playerData
	if not pd or not LocalPlayer then
		return nil
	end
	return pd[LocalPlayer]
end

return inventoryDataAccess
