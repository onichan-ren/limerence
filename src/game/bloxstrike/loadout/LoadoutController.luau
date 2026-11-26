local ModuleController = require("@game/bloxstrike/module/ModuleController")
local WeaponController = require("@game/bloxstrike/weapon/WeaponController")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local peek = Charm.peek
local observe = Charm.observe

local LoadoutController = {
	_janitor = Janitor.new() :: Janitor.Janitor,
}

function LoadoutController.new(): LoadoutController
	local InventoryController = ModuleController.GetModule("Inventory")

	local realDebug = getrenv().debug
	getfenv(InventoryController.getCurrentEquipped).debug = setmetatable({
		info = newcclosure(LPH_NO_VIRTUALIZE(function(n: number, s: string)
			setthreadidentity(2)
			return nil
		end)),
	}, {
		__index = newcclosure(LPH_NO_VIRTUALIZE(function(t, k)
			return realDebug[k]
		end)),
	})

	LoadoutController._janitor:Add(
		InventoryController.OnInventoryItemEquipped:Connect(
			LPH_NO_VIRTUALIZE(function(slot, data: loadoutState.LoadoutEntry)
				task.spawn(function()
					setthreadidentity(8)
					loadoutState.currentEquipped(data)
				end)
				setthreadidentity(2)
			end)
		),
		"Disconnect"
	)

	LoadoutController._janitor:Add(
		InventoryController.OnInventoryChanged:Connect(LPH_NO_VIRTUALIZE(function(inventory: loadoutState.Inventory)
			task.spawn(function()
				setthreadidentity(8)
				loadoutState.inventory(inventory)

				local currentLoadout = debug.getupvalue(InventoryController.getCurrentEquipped, 1)
				if currentLoadout and not currentLoadout.IsDestroyed then
					loadoutState.loadout(currentLoadout)
				end
			end)
			setthreadidentity(2)
		end))
	)

	local currentLoadout = debug.getupvalue(InventoryController.getCurrentEquipped, 1)
	if currentLoadout and not currentLoadout.IsDestroyed then
		task.spawn(function()
			loadoutState.currentEquipped(currentLoadout.CurrentEquipped)
			loadoutState.inventory(currentLoadout.Inventory)
			loadoutState.loadout(currentLoadout)
		end)
	end

	setthreadidentity(8)

	return LoadoutController
end

function LoadoutController.Destroy(): ()
	LoadoutController._janitor:Destroy()
end

export type LoadoutController = typeof(LoadoutController)
return LoadoutController
