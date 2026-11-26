local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService

local Janitor = require("@pkg/Janitor")
local droppedItemRegistry = require("@game/bloxstrike/dropped/droppedItemRegistry")
local droppedItemState = require("@game/bloxstrike/dropped/droppedItemState")
local droppedAmmoTracker = require("@game/bloxstrike/dropped/droppedAmmoTracker")
local gamemodeState = require("@game/bloxstrike/gamemodeState")

local TAG = "WeaponDropped"

local modelJanitors: { [Model]: Janitor.Janitor } = {}

local DroppedItemController = {
	_janitor = Janitor.new(),
}

local function onModelAdded(model: any): ()
	if model.ClassName ~= "Model" then
		return
	end
	if gamemodeState.isDeathmatch() then
		return
	end

	local janitor = Janitor.new()
	modelJanitors[model] = janitor
	droppedItemRegistry.bindModel(model)

	janitor:Add(function()
		modelJanitors[model] = nil
		droppedItemRegistry.unbindModel(model)
	end)
end

local function onModelRemoved(model: any): ()
	if model.ClassName ~= "Model" then
		return
	end
	local janitor = modelJanitors[model]
	if janitor then
		janitor:Destroy()
	end
end

local function clearAll(): ()
	for model, janitor in next, modelJanitors do
		janitor:Destroy()
		modelJanitors[model] = nil
	end
	droppedItemState.entries({})
end

local function scanExisting(): ()
	for _, model in next, CollectionService:GetTagged(TAG) do
		onModelAdded(model)
	end
end

function DroppedItemController.new(): DroppedItemController
	droppedAmmoTracker.init()

	DroppedItemController._janitor:Add(
		CollectionService:GetInstanceAddedSignal(TAG):Connect(onModelAdded),
		"Disconnect"
	)
	DroppedItemController._janitor:Add(
		CollectionService:GetInstanceRemovedSignal(TAG):Connect(onModelRemoved),
		"Disconnect"
	)
	DroppedItemController._janitor:Add(
		workspace:GetAttributeChangedSignal("Gamemode"):Connect(LPH_NO_VIRTUALIZE(function()
			if gamemodeState.isDeathmatch() then
				clearAll()
			else
				scanExisting()
			end
		end)),
		"Disconnect"
	)

	if not gamemodeState.isDeathmatch() then
		scanExisting()
	end

	return DroppedItemController
end

function DroppedItemController.Destroy(): ()
	clearAll()
	droppedAmmoTracker.destroy()
	DroppedItemController._janitor:Destroy()
end

export type DroppedItemController = typeof(DroppedItemController)

return DroppedItemController
