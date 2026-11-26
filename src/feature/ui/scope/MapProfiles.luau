local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")
local configState = require("@src/feature/config/configState")
local stateConverter = require("@src/feature/config/module/stateConverter")

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe

local GLOBAL_ID = "global"

local MapProfiles = {}
MapProfiles.__index = MapProfiles
MapProfiles.GLOBAL_ID = GLOBAL_ID

export type MapSource = {
	GetCurrent: () -> string?,
	Changed: (callback: (map: string?) -> ()) -> () -> (),
	GetAll: (() -> { string })?,
}

local function serializeValue(value: any): any
	local valueType = typeof(value)

	if valueType == "Color3" then
		return { __t = "Color3", r = value.R, g = value.G, b = value.B }
	end

	if valueType == "ColorSequence" then
		local keypoints = {}
		for index, keypoint in next, value.Keypoints do
			keypoints[index] = {
				time = keypoint.Time,
				r = keypoint.Value.R,
				g = keypoint.Value.G,
				b = keypoint.Value.B,
			}
		end
		return { __t = "ColorSequence", keypoints = keypoints }
	end

	return value
end

local function deserializeValue(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local tag = value.__t
	if tag == "Color3" then
		return Color3.new(value.r, value.g, value.b)
	end

	if tag == "ColorSequence" then
		local keypoints = {}
		for index, keypoint in next, value.keypoints do
			keypoints[index] = ColorSequenceKeypoint.new(keypoint.time, Color3.new(keypoint.r, keypoint.g, keypoint.b))
		end
		return ColorSequence.new(keypoints)
	end

	return value
end

function MapProfiles.new(id: string, source: MapSource): MapProfiles
	local self = setmetatable({}, MapProfiles) :: any

	self._id = id
	self._source = source
	self._profiles = at({} :: { string })
	self._allMaps = at(source.GetAll and source.GetAll() or {} :: { string })
	self._values = at({} :: { [string]: { [string]: any } })
	self._enabled = at({} :: { [string]: boolean })
	self._selected = at(GLOBAL_ID)
	self._currentMap = at(source.GetCurrent())
	self._bound = {} :: { [string]: { element: any, unsubs: { () -> () } } }
	self._unsubs = {} :: { () -> () }

	self._sourceUnsub = source.Changed(function(map: string?)
		self._currentMap(map)
	end)

	table.insert(self._unsubs, sub(self._currentMap, function()
		self._selected(self:ActiveProfile())
	end))

	stateConverter.RegisterExtension(`mapProfiles.{id}`, function(): any
		return self:_save()
	end, function(data: any)
		self:_load(data)
	end)

	return self
end

function MapProfiles._save(self: MapProfiles): any
	local values: { [string]: { [string]: any } } = {}
	for profile, bucket in next, peek(self._values) do
		local out: { [string]: any } = {}
		for key, value in next, bucket do
			out[key] = serializeValue(value)
		end
		values[profile] = out
	end
	return {
		profiles = peek(self._profiles),
		enabled = peek(self._enabled),
		values = values,
	}
end

function MapProfiles._load(self: MapProfiles, data: any): ()
	if type(data) ~= "table" then
		return
	end

	local profiles: { string } = {}
	if type(data.profiles) == "table" then
		for _, name in next, data.profiles do
			if type(name) == "string" then
				profiles[#profiles + 1] = name
			end
		end
	end

	local enabled: { [string]: boolean } = {}
	if type(data.enabled) == "table" then
		for name, state in next, data.enabled do
			if state == true then
				enabled[name] = true
			end
		end
	end

	local values: { [string]: { [string]: any } } = {}
	if type(data.values) == "table" then
		for profile, bucket in next, data.values do
			if type(bucket) == "table" then
				local out: { [string]: any } = {}
				for key, value in next, bucket do
					out[key] = deserializeValue(value)
				end
				values[profile] = out
			end
		end
	end

	self._profiles(profiles)
	self._enabled(enabled)
	self._values(values)
	self._selected(self:ActiveProfile())
	self:_pushAll()
end

function MapProfiles.ActiveProfile(self: MapProfiles): string
	local map = peek(self._currentMap)
	if map and peek(self._enabled)[map] == true and table.find(peek(self._profiles), map) then
		return map
	end
	return GLOBAL_ID
end

function MapProfiles.Select(self: MapProfiles, id: string): ()
	if id ~= GLOBAL_ID and not table.find(peek(self._profiles), id) then
		return
	end
	self._selected(id)
end

function MapProfiles.EnsureProfile(self: MapProfiles, name: string): ()
	local profiles = peek(self._profiles)
	if table.find(profiles, name) then
		return
	end
	self._profiles(Sift.Array.push(profiles, name))
end

function MapProfiles.AddProfile(self: MapProfiles, name: string): ()
	self:EnsureProfile(name)
	self:SetEnabled(name, true)
end

function MapProfiles.RemoveProfile(self: MapProfiles, name: string): ()
	local profiles = peek(self._profiles)
	local index = table.find(profiles, name)
	if not index then
		return
	end
	self._profiles(Sift.Array.removeIndex(profiles, index))
	self._enabled(Sift.Dictionary.removeKey(peek(self._enabled), name))
	self._values(Sift.Dictionary.removeKey(peek(self._values), name))
	if peek(self._selected) == name then
		self._selected(self:ActiveProfile())
	end
end

function MapProfiles.SetEnabled(self: MapProfiles, name: string, enabled: boolean): ()
	local store = peek(self._enabled)
	if (store[name] == true) == enabled then
		return
	end
	if enabled then
		self:EnsureProfile(name)
		self._enabled(Sift.Dictionary.set(store, name, true))
	else
		self._enabled(Sift.Dictionary.removeKey(store, name))
	end
end

function MapProfiles.IsEnabled(self: MapProfiles, name: string): boolean
	return peek(self._enabled)[name] == true
end

function MapProfiles._setValue(self: MapProfiles, profile: string, key: string, value: any): ()
	local store = peek(self._values)
	local bucket = store[profile] or {}
	if bucket[key] == value then
		return
	end
	self._values(Sift.Dictionary.set(store, profile, Sift.Dictionary.set(bucket, key, value)))
end

function MapProfiles._pushAll(self: MapProfiles): ()
	for _, entry in next, self._bound do
		entry.push()
	end
end

function MapProfiles.BindElement(self: MapProfiles, element: any, key: string): ()
	if self._bound[key] then
		return
	end

	local syncing = false

	local function resolve(): (any, boolean)
		local values = peek(self._values)
		local selected = peek(self._selected)
		if selected ~= GLOBAL_ID then
			local bucket = values[selected]
			if bucket and bucket[key] ~= nil then
				return bucket[key], true
			end
		end
		local globalBucket = values[GLOBAL_ID]
		if globalBucket and globalBucket[key] ~= nil then
			return globalBucket[key], true
		end
		return nil, false
	end

	local function push(): ()
		local value, exists = resolve()
		if not exists then
			return
		end
		syncing = true
		element._state(value)
		syncing = false
	end

	local globalBucket = peek(self._values)[GLOBAL_ID]
	if not globalBucket or globalBucket[key] == nil then
		self:_setValue(GLOBAL_ID, key, peek(element._state))
	end

	local unsubs: { () -> () } = {}

	table.insert(
		unsubs,
		sub(element._state, function(value: any)
			if syncing then
				return
			end
			self:_setValue(peek(self._selected), key, value)
		end)
	)
	table.insert(unsubs, sub(self._selected, push))

	self._bound[key] = { element = element, unsubs = unsubs, push = push }
end

function MapProfiles.BindPrefix(self: MapProfiles, prefix: string): ()
	local prefixDot = `{prefix}.`
	local length = #prefixDot
	for key, element in next, configState.elements do
		if string.sub(key, 1, length) == prefixDot then
			self:BindElement(element, key)
		end
	end
end

function MapProfiles.Destroy(self: MapProfiles): ()
	stateConverter.UnregisterExtension(`mapProfiles.{self._id}`)
	if self._sourceUnsub then
		self._sourceUnsub()
		self._sourceUnsub = nil
	end
	for _, fn in next, self._unsubs do
		fn()
	end
	self._unsubs = {}
	for _, entry in next, self._bound do
		for _, fn in next, entry.unsubs do
			fn()
		end
	end
	self._bound = {}
end

export type MapProfiles = typeof(setmetatable(
	{} :: {
		_id: string,
		_source: MapSource,
		_profiles: Charm.Atom<{ string }>,
		_allMaps: Charm.Atom<{ string }>,
		_values: Charm.Atom<{ [string]: { [string]: any } }>,
		_enabled: Charm.Atom<{ [string]: boolean }>,
		_selected: Charm.Atom<string>,
		_currentMap: Charm.Atom<string?>,
		_bound: { [string]: { element: any, unsubs: { () -> () }, push: () -> () } },
		_unsubs: { () -> () },
		_sourceUnsub: (() -> ())?,
	},
	MapProfiles
))

return MapProfiles
