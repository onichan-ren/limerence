local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local StateController = require("@game/op1/state/StateController")
local ModuleController = require("@game/op1/module/ModuleController")

local Players = cloneref(game:GetService("Players")) :: Players

local at = Charm.atom
local peek = Charm.peek

local OWNERSHIP_LOCAL = 3
local OWNERSHIP_TEAM = 2

local FALLBACK_TAGS = { "Drone", "DefaultCamera" }

local _globals: any = nil
local _items: any = nil
local _util: any = nil
local _iconCache: { [string]: string } = {}

export type Entry = {
	id: number,
	tag: string,
	object: any,
	instance: Instance,
	icon: string,
}

local CameraController = {
	active = at({} :: { [number]: Entry }),
	_janitor = nil :: Janitor.Janitor?,
	_tracked = {} :: { [any]: boolean },
	_objectId = {} :: { [any]: number },
	_objectJanitor = {} :: { [any]: Janitor.Janitor },
	_nextId = 0,
}

local function addEntry(entry: Entry): ()
	local current = peek(CameraController.active)
	local replacement = table.clone(current)
	replacement[entry.id] = entry
	CameraController.active(replacement)
end

local function removeId(id: number): ()
	local current = peek(CameraController.active)
	if current[id] == nil then
		return
	end
	local replacement = table.clone(current)
	replacement[id] = nil
	CameraController.active(replacement)
end

local function untrack(object: any): ()
	CameraController._tracked[object] = nil

	local objectJanitor = CameraController._objectJanitor[object]
	if objectJanitor then
		CameraController._objectJanitor[object] = nil
		objectJanitor:Destroy()
	end

	local id = CameraController._objectId[object]
	if id then
		CameraController._objectId[object] = nil
		removeId(id)
	end
end

local function getIcon(tag: string): string
	local cached = _iconCache[tag]
	if cached then
		return cached
	end

	if not _items then
		_items = ModuleController.GetModule("Items")
	end
	if not _items then
		return ""
	end

	setthreadidentity(2)
	local class = _items.get_item_class(tag)
	setthreadidentity(8)

	local icon = class and class.icon or ""
	_iconCache[tag] = icon
	return icon
end

local function computeRelation(object: any): string
	local ownerState = object.owner
	local owner = ownerState and ownerState:get()
	if owner == nil then
		return "neutral"
	end

	if not _util then
		_util = ModuleController.GetModule("Util")
	end
	if not _util then
		return "neutral"
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

function CameraController.GetRelation(entry: Entry): string
	return computeRelation(entry.object)
end

function CameraController.GetController(entry: Entry): string?
	local states = entry.object.states
	local controllerState = states and states.controller
	local controller = controllerState and controllerState:get()
	if controller == nil then
		return nil
	end

	if controller:IsA("Player") then
		return controller.Name
	end

	local userId = controller:GetAttribute("UserId")
	if userId then
		local player = Players:GetPlayerByUserId(tonumber(userId) or -1)
		if player then
			return player.Name
		end
	end

	return controller.Name
end

local function track(tag: string, object: any): ()
	if type(object) ~= "table" or CameraController._tracked[object] then
		return
	end

	CameraController._tracked[object] = true

	task.spawn(function(): ()
		setthreadidentity(8)
		local model = nil
		local attempts = 0
		while CameraController._tracked[object] and attempts < 40 do
			if object.values and object.values.camera and object.instance then
				model = object.instance
				break
			end
			task.wait(0.1)
			attempts += 1
		end

		if not model or not CameraController._tracked[object] then
			CameraController._tracked[object] = nil
			return
		end

		CameraController._nextId += 1
		local id = CameraController._nextId
		CameraController._objectId[object] = id

		setthreadidentity(8)
		local objectJanitor = Janitor.new()
		CameraController._objectJanitor[object] = objectJanitor

		objectJanitor:Add(
			model.Destroying:Connect(function(): ()
				untrack(object)
			end),
			"Disconnect"
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

		setthreadidentity(8)
		addEntry({
			id = id,
			tag = tag,
			object = object,
			instance = model,
			icon = getIcon(tag),
		})
	end)
end

function CameraController.GetActive(): { Entry }
	local result: { Entry } = {}

	for _, entry in next, peek(CameraController.active) do
		if entry.instance.Parent ~= nil then
			result[#result + 1] = entry
		else
			untrack(entry.object)
		end
	end

	return result
end

function CameraController.new(): CameraController
	local janitor = Janitor.new()
	CameraController._janitor = janitor

	if not _globals then
		_globals = ModuleController.GetModule("Globals")
	end

	local tags = (_globals and _globals.device_tags) or FALLBACK_TAGS

	for _, tag in next, tags do
		local existing = StateController.GetAll(tag)
		for _, object in next, existing do
			track(tag, object)
		end

		janitor:Add(
			StateController.HookClass(tag, function(object: any): ()
				track(tag, object)
			end),
			true
		)
	end

	return CameraController
end

function CameraController.Destroy(): ()
	local janitor = CameraController._janitor
	if janitor then
		janitor:Destroy()
		CameraController._janitor = nil
	end

	for _, objectJanitor in next, CameraController._objectJanitor do
		objectJanitor:Destroy()
	end

	table.clear(CameraController._tracked)
	table.clear(CameraController._objectId)
	table.clear(CameraController._objectJanitor)
	CameraController.active({})
end

export type CameraController = typeof(CameraController)

return CameraController
