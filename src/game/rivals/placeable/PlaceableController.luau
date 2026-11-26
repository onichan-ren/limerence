local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService
local Players = cloneref(game:GetService("Players")) :: Players

local Janitor = require("@pkg/Janitor")
local Sift = require("@pkg/Sift")
local Charm = require("@pkg/Charm")
local clientApi = require("@game/rivals/client/clientApi")
local placeableState = require("@game/rivals/placeable/placeableState")

local LocalPlayer = Players.LocalPlayer
local peek = Charm.peek

local KINDS = {
	{ tag = "JumpPadHitbox", kind = "jumppad", label = "JUMP PAD" },
	{ tag = "SubspaceTripmine", kind = "tripmine", label = "TRIPMINE" },
}

local PlaceableController = {
	_janitor = Janitor.new() :: Janitor.Janitor,
	_entryJanitors = {} :: { [string]: Janitor.Janitor },
}

local function getInstanceKey(inst: Instance): string
	local key = inst.GetDebugId(inst)
	if type(key) == "string" and key ~= "" then
		return key
	end
	return tostring(inst)
end

local resolvePosition = LPH_NO_VIRTUALIZE(function(inst: Instance): Vector3
	local pivot = (inst :: any):GetPivot()
	if typeof(pivot) == "CFrame" then
		return pivot.Position
	end
	return Vector3.zero
end)

local isFriendly = LPH_NO_VIRTUALIZE(function(inst: Instance): boolean
	local placedBy = inst:GetAttribute("PlacedByUserID")
	if type(placedBy) == "number" and placedBy == LocalPlayer.UserId then
		return true
	end
	local team = inst:GetAttribute("TeamID")
	if type(team) == "string" and team ~= "" then
		local localTeam = clientApi.GetTeam()
		return type(localTeam) == "string" and localTeam ~= "" and localTeam == team
	end
	return false
end)

local function removeEntry(id: string): ()
	local janitor = PlaceableController._entryJanitors[id]
	if janitor then
		janitor:Destroy()
		PlaceableController._entryJanitors[id] = nil
	end

	local current = peek(placeableState.activePlaceables)
	if current[id] then
		placeableState.activePlaceables((Sift.Dictionary.removeKey :: any)(current, id))
	end
end

local function addEntry(inst: Instance, kind: string, label: string): ()
	if not inst:IsDescendantOf(workspace) then
		return
	end

	local id = kind .. ":" .. getInstanceKey(inst)
	if peek(placeableState.activePlaceables)[id] then
		return
	end

	local entry: placeableState.PlaceableEntry = {
		id = id,
		kind = kind,
		label = label,
		position = resolvePosition(inst),
		instance = inst,
		friendly = isFriendly(inst),
	}

	placeableState.activePlaceables((Sift.Dictionary.set :: any)(peek(placeableState.activePlaceables), id, entry))

	local janitor = Janitor.new()
	PlaceableController._entryJanitors[id] = janitor
	janitor:Add(
		inst.AncestryChanged:Connect(LPH_NO_VIRTUALIZE(function(_, parent: Instance?): ()
			if parent == nil then
				removeEntry(id)
			end
		end)),
		"Disconnect"
	)
end

function PlaceableController.new(): typeof(PlaceableController)
	for _, def in next, KINDS do
		for _, inst in next, CollectionService:GetTagged(def.tag) do
			addEntry(inst, def.kind, def.label)
		end

		PlaceableController._janitor:Add(
			CollectionService:GetInstanceAddedSignal(def.tag):Connect(LPH_NO_VIRTUALIZE(function(inst: Instance): ()
				addEntry(inst, def.kind, def.label)
			end)),
			"Disconnect"
		)
		PlaceableController._janitor:Add(
			CollectionService:GetInstanceRemovedSignal(def.tag):Connect(LPH_NO_VIRTUALIZE(function(inst: Instance): ()
				removeEntry(def.kind .. ":" .. getInstanceKey(inst))
			end)),
			"Disconnect"
		)
	end

	return PlaceableController
end

function PlaceableController.Destroy(): ()
	PlaceableController._janitor:Destroy()
	PlaceableController._janitor = Janitor.new()

	for id, janitor in next, PlaceableController._entryJanitors do
		janitor:Destroy()
		PlaceableController._entryJanitors[id] = nil
	end

	placeableState.activePlaceables({})
end

export type PlaceableController = typeof(PlaceableController)

return PlaceableController
