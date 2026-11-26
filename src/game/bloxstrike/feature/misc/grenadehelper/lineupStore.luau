local HttpService = cloneref(game:GetService("HttpService")) :: HttpService

local Signal = require("@pkg/Signal")

local ROOT_DIR = "limerence.biz/lineups"
local FILE_PATH = ROOT_DIR .. "/bloxstrike.json"

export type Lineup = {
	name: string,
	grenade: string,
	throwType: "Far" | "Near",
	position: Vector3,
	direction: Vector3,
	velocity: Vector3,
	jump: boolean,
	crouch: boolean,
	anchor: Vector3,
	markerPos: Vector3?,
	aimPos: Vector3?,
}

local EMPTY: { Lineup } = {}

local lineupStore = {
	Changed = Signal.new() :: Signal.Signal<string>,
}

local _maps: { [string]: { Lineup } } = {}
local _loaded = false

local function ensureDir(): ()
	if not isfolder(ROOT_DIR) then
		makefolder(ROOT_DIR)
	end
end

local function save(): ()
	ensureDir()
	local out: { [string]: any } = { version = 1, maps = {} }
	local maps = out.maps :: { [string]: any }
	for map, list in next, _maps do
		local arr = table.create(#list)
		for i = 1, #list do
			local lineup = list[i]
			arr[i] = {
				name = lineup.name,
				grenade = lineup.grenade,
				throwType = lineup.throwType,
				crouch = lineup.crouch,
				jump = lineup.jump,
				position = { lineup.position.X, lineup.position.Y, lineup.position.Z },
				direction = { lineup.direction.X, lineup.direction.Y, lineup.direction.Z },
				velocity = { lineup.velocity.X, lineup.velocity.Y, lineup.velocity.Z },
			}
		end
		maps[map] = arr
	end
	writefile(FILE_PATH, HttpService:JSONEncode(out))
end

local function hydrate(raw: any): ()
	if type(raw) ~= "table" or type(raw.maps) ~= "table" then
		return
	end
	for map, list in next, raw.maps do
		if type(map) ~= "string" or type(list) ~= "table" then
			continue
		end
		local hydrated: { Lineup } = {}
		for i = 1, #list do
			local entry = list[i]
			local pos = entry.position
			local dir = entry.direction
			if
				type(entry.name) ~= "string"
				or type(entry.grenade) ~= "string"
				or entry.grenade == "Movement"
				or type(pos) ~= "table"
				or type(dir) ~= "table"
			then
				continue
			end
			local vel = entry.velocity
			local position = Vector3.new(pos[1], pos[2], pos[3])
			hydrated[#hydrated + 1] = {
				name = entry.name,
				grenade = entry.grenade,
				throwType = entry.throwType == "Near" and "Near" or "Far",
				crouch = entry.crouch == true,
				jump = entry.jump == true,
				position = position,
				direction = Vector3.new(dir[1], dir[2], dir[3]),
				velocity = type(vel) == "table" and Vector3.new(vel[1], vel[2], vel[3]) or Vector3.zero,
				anchor = position,
			}
		end
		if #hydrated > 0 then
			_maps[map] = hydrated
		end
	end
end

function lineupStore.Load(): ()
	if _loaded then
		return
	end
	_loaded = true
	if not isfile(FILE_PATH) then
		return
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(readfile(FILE_PATH))
	end)
	if ok then
		hydrate(decoded)
	end
end

function lineupStore.GetForMap(map: string): { Lineup }
	lineupStore.Load()
	return _maps[map] or EMPTY
end

function lineupStore.Find(map: string, name: string): Lineup?
	local list = lineupStore.GetForMap(map)
	for i = 1, #list do
		if list[i].name == name then
			return list[i]
		end
	end
	return nil
end

function lineupStore.UniqueName(map: string, base: string): string
	if not lineupStore.Find(map, base) then
		return base
	end
	local index = 2
	while lineupStore.Find(map, `{base} {index}`) do
		index += 1
	end
	return `{base} {index}`
end

function lineupStore.Add(map: string, lineup: Lineup): ()
	lineupStore.Load()
	lineup.anchor = lineup.position
	local list = _maps[map]
	if not list then
		list = {}
		_maps[map] = list
	end
	list[#list + 1] = lineup
	save()
	lineupStore.Changed:Fire(map)
end

function lineupStore.Rename(map: string, oldName: string, newName: string): boolean
	lineupStore.Load()
	if newName == "" or oldName == newName then
		return false
	end
	local lineup = lineupStore.Find(map, oldName)
	if not lineup then
		return false
	end
	lineup.name = lineupStore.UniqueName(map, newName)
	save()
	lineupStore.Changed:Fire(map)
	return true
end

function lineupStore.Remove(map: string, name: string): boolean
	lineupStore.Load()
	local list = _maps[map]
	if not list then
		return false
	end
	for i = 1, #list do
		if list[i].name == name then
			table.remove(list, i)
			if #list == 0 then
				_maps[map] = nil
			end
			save()
			lineupStore.Changed:Fire(map)
			return true
		end
	end
	return false
end

return lineupStore
