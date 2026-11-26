local ModuleController = require("@game/ar2/module/ModuleController")
local NetworkController = require("@game/ar2/network/NetworkController")

local InteractionController = {
	_registry = nil :: any,
	_player = nil :: any,
}

function InteractionController.new(): InteractionController
	local interactablesData = ModuleController.GetModule("Interactables")
	local interactables = interactablesData and interactablesData.module
	local find = interactables and rawget(interactables, "find")

	if type(find) == "function" then
		for _, value in next, debug.getupvalues(find) :: { any } do
			if type(value) == "table" then
				InteractionController._registry = value
				break
			end
		end
	end

	local playerData = ModuleController.GetModule("LocalPlayer")
	local players = playerData and playerData.module
	local get = players and rawget(players, "get")
	if type(get) == "function" then
		InteractionController._player = get()
	end

	return InteractionController
end

function InteractionController.GetRegistry(): any
	return InteractionController._registry
end

function InteractionController.GetPromptData(interactable: any): any
	local interactablesData = ModuleController.GetModule("Interactables")
	local interactables = interactablesData and interactablesData.module
	local getPromptData = interactables and rawget(interactables, "GetInteractPromptData")
	if type(getPromptData) ~= "function" then
		return nil
	end

	return getPromptData(interactable)
end

function InteractionController.Interact(interactable: any, alternate: boolean?): boolean
	local action = rawget(interactable, "InteractAction") or rawget(interactable, "StoredAction")
	local player = InteractionController._player
	local character = player and player.Character
	if type(action) ~= "function" or not character then
		return false
	end

	local old = getthreadidentity()
	setthreadidentity(2)
	local result = action(character, alternate == true)
	NetworkController.send("Client Interacted", interactable.Id, alternate == true, result)
	setthreadidentity(old)

	return true
end

function InteractionController.Destroy(): ()
	InteractionController._registry = nil
	InteractionController._player = nil
end

export type InteractionController = typeof(InteractionController)
return InteractionController
