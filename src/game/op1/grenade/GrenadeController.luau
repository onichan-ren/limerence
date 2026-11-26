local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local StateController = require("@game/op1/state/StateController")
local clientState = require("@game/op1/client/clientState")
local grenadeProfiles = require("@game/op1/grenade/grenadeProfiles")
local ModuleController = require("@game/op1/module/ModuleController")

local at = Charm.atom
local peek = Charm.peek

local OWNERSHIP_LOCAL = 3
local OWNERSHIP_TEAM = 2

local _util: any = nil

export type Entry = {
	id: number,
	tag: string,
	profile: grenadeProfiles.Profile,
	object: any,
	instance: Instance,
	root: BasePart,
	startedAt: number,
}

local GrenadeController = {
	active = at({} :: { [number]: Entry }),
	_janitor = nil :: Janitor.Janitor?,
	_tracked = {} :: { [any]: boolean },
	_objectId = {} :: { [any]: number },
	_objectUnhooks = {} :: { [any]: { () -> () } },
	_nextId = 0,
}

local function addEntry(entry: Entry): ()
	local current = peek(GrenadeController.active)
	local replacement = table.clone(current)
	replacement[entry.id] = entry
	GrenadeController.active(replacement)
end

local function removeId(id: number): ()
	local current = peek(GrenadeController.active)
	if current[id] == nil then
		return
	end
	local replacement = table.clone(current)
	replacement[id] = nil
	GrenadeController.active(replacement)
end

local function untrack(object: any): ()
	GrenadeController._tracked[object] = nil
	local unhooks = GrenadeController._objectUnhooks[object]
	if unhooks then
		GrenadeController._objectUnhooks[object] = nil
		for index = 1, #unhooks do
			unhooks[index]()
		end
	end
	local id = GrenadeController._objectId[object]
	if id then
		GrenadeController._objectId[object] = nil
		removeId(id)
	end
end

local function computeRelation(object: any): string
	local ownerState = object.owner
	local owner = ownerState and ownerState:get()
	if owner == nil then
		return "enemy"
	end

	if not _util then
		_util = ModuleController.GetModule("Util")
	end
	if not _util then
		return "enemy"
	end

	setthreadidentity(2)
	local value = _util.ownership(owner)
	setthreadidentity(8)

	if value == OWNERSHIP_LOCAL then
		return "local"
	end
	if value == OWNERSHIP_TEAM then
		return "friendly"
	end
	return "enemy"
end

function GrenadeController.GetRelation(entry: Entry): string
	return computeRelation(entry.object)
end

local function track(tag: string, object: any): ()
	if type(object) ~= "table" or GrenadeController._tracked[object] then
		return
	end

	local profile = grenadeProfiles[tag]
	if not profile then
		return
	end

	GrenadeController._tracked[object] = true

	task.spawn(function(): ()
		local model = object.instance
		local attempts = 0
		while model == nil and attempts < 60 and GrenadeController._tracked[object] do
			task.wait()
			model = object.instance
			attempts += 1
		end
		if not model then
			GrenadeController._tracked[object] = nil
			return
		end

		local root = model:FindFirstChild("Root")
		if not root then
			root = model:WaitForChild("Root", 3)
		end

		if not root or not GrenadeController._tracked[object] then
			return
		end

		GrenadeController._nextId += 1
		local id = GrenadeController._nextId
		GrenadeController._objectId[object] = id

		addEntry({
			id = id,
			tag = tag,
			profile = profile,
			object = object,
			instance = model,
			root = root :: BasePart,
			startedAt = os.clock(),
		})
	end)

	local unhooks: { () -> () } = {}
	GrenadeController._objectUnhooks[object] = unhooks

	if object.clean and type(object.clean.hook) == "function" then
		unhooks[#unhooks + 1] = StateController.HookState(object.clean, function(value: any): ()
			if value then
				untrack(object)
			end
		end)
	end

	if object.states and object.states.explode and type(object.states.explode.hook) == "function" then
		unhooks[#unhooks + 1] = StateController.HookState(object.states.explode, function(): ()
			untrack(object)
		end)
	end
end

function GrenadeController.isThrown(entry: Entry): boolean
	local charObject = peek(clientState.charObject)
	if not charObject or not charObject.values then
		return true
	end

	local instance = entry.instance
	if not instance then
		return false
	end

	local viewmodels = charObject.values.viewmodels
	if viewmodels and instance:IsDescendantOf(viewmodels) then
		return false
	end

	local items = charObject.values.Items
	if typeof(items) == "Instance" and instance:IsDescendantOf(items) then
		return false
	end

	return true
end

function GrenadeController.GetActive(scratch: { Entry }?): { Entry }
	local result: { Entry } = scratch or {}
	if scratch then
		table.clear(scratch)
	end

	for _, entry in next, peek(GrenadeController.active) do
		local instance = entry.instance
		local root = entry.root

		if instance.Parent ~= nil and root.Parent ~= nil then
			result[#result + 1] = entry
		else
			untrack(entry.object)
		end
	end

	return result
end

function GrenadeController.new(): GrenadeController
	local janitor = Janitor.new()
	GrenadeController._janitor = janitor

	for tag in next, grenadeProfiles do
		local existing = StateController.GetAll(tag)
		for _, object in next, existing do
			track(tag, object)
		end

		janitor:Add(StateController.HookClass(tag, function(object: any): ()
			track(tag, object)
		end), true)
	end

	return GrenadeController
end

function GrenadeController.Destroy(): ()
	local janitor = GrenadeController._janitor
	if janitor then
		janitor:Destroy()
		GrenadeController._janitor = nil
	end
	for _, unhooks in next, GrenadeController._objectUnhooks do
		for index = 1, #unhooks do
			unhooks[index]()
		end
	end
	table.clear(GrenadeController._objectUnhooks)
	table.clear(GrenadeController._tracked)
	table.clear(GrenadeController._objectId)
	GrenadeController.active({})
end

export type GrenadeController = typeof(GrenadeController)

return GrenadeController
