local Charm = require("@pkg/Charm")

local at = Charm.atom
local peek = Charm.peek

export type EntryKind = "tabGroup" | "tab" | "section" | "element" | "config"

export type EntryMeta = {
	kind: EntryKind?,
	label: string?,
	tags: { string }?,
	configKey: string?,
	parentId: number?,
	location: { tabGroup: string?, tab: string?, section: string? }?,
	serialize: ((any) -> any)?,
	deserialize: ((any) -> any)?,
}

export type Entry = {
	id: number,
	kind: EntryKind,
	label: string,
	ref: any,
	tags: { string },
	configKey: string?,
	parentId: number?,
	location: { tabGroup: string?, tab: string?, section: string? }?,
	serialize: ((any) -> any)?,
	deserialize: ((any) -> any)?,
}

local entries: Charm.Atom<{ [number]: Entry }> = at({})
local byConfigKey: { [string]: number } = {}
local nextId = 1

local deriveLabel = LPH_NO_VIRTUALIZE(function(node: any): string
	if type(node) ~= "table" then
		return tostring(node)
	end
	if node.title then
		return tostring(node.title)
	end
	if node._text then
		local v = peek(node._text)
		if v ~= nil then
			return tostring(v)
		end
	end
	if node._title then
		return tostring(node._title)
	end
	if node._name then
		return tostring(node._name)
	end
	return "unnamed"
end)

local function tokenize(text: string): { string }
	local out: { string } = {}
	for word in string.gmatch(text:lower(), "[%w]+") do
		out[#out + 1] = word
	end
	return out
end

local uiRegistry = {}

function uiRegistry.add(node: any, meta: EntryMeta?): any
	local m: EntryMeta = meta or {}

	local id = nextId
	nextId += 1

	local entry: Entry = {
		id = id,
		kind = m.kind or "element",
		label = m.label or deriveLabel(node),
		ref = node,
		tags = m.tags or {},
		configKey = m.configKey,
		parentId = m.parentId,
		location = m.location,
		serialize = m.serialize,
		deserialize = m.deserialize,
	}

	if entry.configKey then
		byConfigKey[entry.configKey] = id
	end

	local current = peek(entries)
	local nextEntries = table.clone(current)
	nextEntries[id] = entry
	entries(nextEntries)

	return node
end

function uiRegistry.get(id: number): Entry?
	return peek(entries)[id]
end

function uiRegistry.getByConfigKey(configKey: string): Entry?
	local id = byConfigKey[configKey]
	if not id then
		return nil
	end
	return peek(entries)[id]
end

function uiRegistry.getAll(): Charm.Atom<{ [number]: Entry }>
	return entries
end

uiRegistry.search = LPH_NO_VIRTUALIZE(function(query: string, kind: EntryKind?, limit: number?): { Entry }
	local results: { Entry } = {}
	local needles = tokenize(query)
	if #needles == 0 then
		return results
	end

	type Scored = { entry: Entry, score: number }
	local scored: { Scored } = {}

	for _, entry in next, peek(entries) do
		if kind and entry.kind ~= kind then
			continue
		end

		local haystack = entry.label:lower()
		if entry.configKey then
			haystack = haystack .. " " .. entry.configKey:lower()
		end
		for _, tag in next, entry.tags do
			haystack = haystack .. " " .. tag:lower()
		end
		if entry.location then
			local loc = entry.location
			if loc.tabGroup then
				haystack = haystack .. " " .. loc.tabGroup:lower()
			end
			if loc.tab then
				haystack = haystack .. " " .. loc.tab:lower()
			end
			if loc.section then
				haystack = haystack .. " " .. loc.section:lower()
			end
		end

		local score = 0
		local matchedAll = true
		for _, needle in next, needles do
			local pos = string.find(haystack, needle, 1, true)
			if not pos then
				matchedAll = false
				break
			end
			score += 1 / pos
		end

		if matchedAll then
			scored[#scored + 1] = { entry = entry, score = score }
		end
	end

	table.sort(scored, function(a, b)
		return a.score > b.score
	end)

	for i, s in next, scored do
		if limit and i > limit then
			break
		end
		results[#results + 1] = s.entry
	end

	return results
end)

return uiRegistry
