local Janitor = require("@pkg/Janitor")
local StateController = require("@game/op1/state/StateController")
local PlayerController = require("@feature/player/PlayerController")

local Players = cloneref(game:GetService("Players")) :: Players

local PLACEABLE_TAG = "Placeable"
local DEFUSER_NAME = "Defuser"
local IDENTITY = CFrame.new()

local DefuserController = {
	_janitor = nil :: Janitor.Janitor?,
	_tracked = {} :: { [any]: boolean },
	_objectJanitor = {} :: { [any]: Janitor.Janitor },
}

local function resolvePlayer(owner: any): Player?
	if owner == nil then
		return nil
	end

	if owner:IsA("Player") then
		return owner
	end

	local userId = owner:GetAttribute("UserId")
	if userId then
		return Players:GetPlayerByUserId(tonumber(userId) or -1)
	end

	return nil
end

local function setPlanting(object: any, value: boolean): ()
	local ownerState = object.owner
	local owner = ownerState and ownerState:get()
	local player = resolvePlayer(owner)
	if not player then
		return
	end

	local wrapper = PlayerController.Get(player) :: any
	if wrapper and wrapper.planting then
		wrapper.planting(value)
	end
end

local function untrack(object: any): ()
	DefuserController._tracked[object] = nil

	local objectJanitor = DefuserController._objectJanitor[object]
	if objectJanitor then
		DefuserController._objectJanitor[object] = nil
		objectJanitor:Destroy()
	end

	setPlanting(object, false)
end

local function track(object: any): ()
	if type(object) ~= "table" or DefuserController._tracked[object] then
		return
	end

	DefuserController._tracked[object] = true

	task.spawn(function(): ()
		setthreadidentity(8)
		local model = nil
		local attempts = 0
		while DefuserController._tracked[object] and attempts < 40 do
			if object.instance and object.states and object.states.placing then
				model = object.instance
				break
			end
			task.wait(0.1)
			attempts += 1
		end

		if not model or not DefuserController._tracked[object] then
			DefuserController._tracked[object] = nil
			return
		end

		if model.Name ~= DEFUSER_NAME then
			DefuserController._tracked[object] = nil
			return
		end

		local objectJanitor = Janitor.new()
		DefuserController._objectJanitor[object] = objectJanitor

		objectJanitor:Add(
			StateController.HookState(object.states.placing, function(value: any): ()
				setPlanting(object, value ~= IDENTITY)
			end, true),
			true
		)

		if object.clean and type(object.clean.hook) == "function" then
			objectJanitor:Add(
				StateController.HookState(object.clean, function(value: any): ()
					if value then
						untrack(object)
					end
				end, true),
				true
			)
		end

		objectJanitor:Add(
			model.Destroying:Connect(function(): ()
				untrack(object)
			end),
			"Disconnect"
		)

		setPlanting(object, object.states.placing:get() ~= IDENTITY)
	end)
end

function DefuserController.new(): DefuserController
	local janitor = Janitor.new()
	DefuserController._janitor = janitor

	for _, object in next, StateController.GetAll(PLACEABLE_TAG) do
		track(object)
	end

	janitor:Add(
		StateController.HookClass(PLACEABLE_TAG, function(object: any): ()
			track(object)
		end),
		true
	)

	return DefuserController
end

function DefuserController.Destroy(): ()
	local janitor = DefuserController._janitor
	if janitor then
		janitor:Destroy()
		DefuserController._janitor = nil
	end

	for _, objectJanitor in next, DefuserController._objectJanitor do
		objectJanitor:Destroy()
	end

	table.clear(DefuserController._tracked)
	table.clear(DefuserController._objectJanitor)
end

export type DefuserController = typeof(DefuserController)

return DefuserController
