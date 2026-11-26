local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService
local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")

local hostageState = require("@game/bloxstrike/hostage/hostageState")

local peek = Charm.peek

local RESCUE_DURATION_DEFAULT = 4
local RESCUE_DURATION_KIT = 1

local HostageController = {
	_janitor = Janitor.new() :: Janitor.Janitor,
	_modelJanitors = {} :: { [string]: Janitor.Janitor },
}

local function keyOf(model: Model): string
	return tostring(model)
end

local function findPlayer(name: string): Player?
	for _, player in next, Players:GetPlayers() do
		if player.Name == name then
			return player
		end
	end
	return nil
end

local function buildEntry(model: Model): hostageState.HostageEntry
	local rescuingName = model:GetAttribute("RescuingPlayer") :: string?
	local rescuingPlayer = rescuingName and findPlayer(rescuingName) or nil
	local startedAt: number? = nil
	local duration: number? = nil
	if rescuingPlayer then
		local raw = rescuingPlayer:GetAttribute("RescueStartTime")
		startedAt = type(raw) == "number" and raw or nil
		duration = (
			rescuingPlayer:GetAttribute("HasRescueKit") == true and RESCUE_DURATION_KIT or RESCUE_DURATION_DEFAULT
		)
	end
	return {
		model = model,
		state = model:GetAttribute("State") or "Idle",
		canRescue = model:GetAttribute("CanRescue") ~= false,
		rescuingPlayer = rescuingName,
		carryingPlayer = model:GetAttribute("CarryingPlayer") :: string?,
		rescueStartedAt = startedAt,
		rescueDuration = duration,
	}
end

local function updateEntry(model: Model): ()
	local key = keyOf(model)
	local cur = peek(hostageState.hostages)
	if not cur[key] then
		return
	end
	local updated = table.clone(cur)
	updated[key] = buildEntry(model)
	hostageState.hostages(updated)
end

function HostageController._attachHostage(model: Model): ()
	local key = keyOf(model)

	local cur = peek(hostageState.hostages)
	local added = table.clone(cur)
	added[key] = buildEntry(model)
	hostageState.hostages(added)

	local janitor = Janitor.new()
	HostageController._modelJanitors[key] = janitor

	janitor:Add(
		model.AttributeChanged:Connect(function(attr: string): ()
			if attr == "State" or attr == "CanRescue" or attr == "CarryingPlayer" then
				updateEntry(model)
			elseif attr == "RescuingPlayer" then
				task.defer(function()
					updateEntry(model)
				end)
			end
		end),
		"Disconnect"
	)

	janitor:Add(
		model.AncestryChanged:Connect(function(_, newParent: Instance?): ()
			if newParent == nil then
				HostageController._detachHostage(model)
			end
		end),
		"Disconnect"
	)
end

function HostageController._detachHostage(model: Model): ()
	local key = keyOf(model)
	local janitor = HostageController._modelJanitors[key]
	if janitor then
		janitor:Destroy()
		HostageController._modelJanitors[key] = nil
	end
	local cur = peek(hostageState.hostages)
	if cur[key] then
		local removed = table.clone(cur)
		removed[key] = nil
		hostageState.hostages(removed)
	end
end

function HostageController.new(): typeof(HostageController)
	HostageController._janitor:Add(
		CollectionService:GetInstanceAddedSignal("Hostage"):Connect(LPH_NO_VIRTUALIZE(function(inst: Instance): ()
			if inst.ClassName == "Model" then
				HostageController._attachHostage(inst :: Model)
			end
		end)),
		"Disconnect"
	)
	HostageController._janitor:Add(
		CollectionService:GetInstanceRemovedSignal("Hostage"):Connect(LPH_NO_VIRTUALIZE(function(inst: Instance): ()
			if inst.ClassName == "Model" then
				HostageController._detachHostage(inst :: Model)
			end
		end)),
		"Disconnect"
	)

	for _, inst in next, CollectionService:GetTagged("Hostage") do
		if inst.ClassName == "Model" then
			HostageController._attachHostage(inst :: Model)
		end
	end

	return HostageController
end

function HostageController.Destroy(): ()
	for _, janitor in next, HostageController._modelJanitors do
		janitor:Destroy()
	end
	HostageController._modelJanitors = {}
	HostageController._janitor:Cleanup()
	hostageState.hostages({})
end

export type HostageController = typeof(HostageController)

return HostageController
