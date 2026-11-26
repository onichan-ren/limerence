export type InfoEntry = {
	key: string,
	order: number,
	text: string,
}

local entries: { InfoEntry } = {}
local version = 0

local hudState = {}

function hudState.SetInfo(key: string, text: string?, order: number?): ()
	for i = 1, #entries do
		local entry = entries[i]
		if entry.key == key then
			if text == nil then
				table.remove(entries, i)
				version += 1
			elseif entry.text ~= text then
				entry.text = text
				version += 1
			end
			return
		end
	end
	if text == nil then
		return
	end
	local rank = order or 0
	local index = #entries + 1
	for i = 1, #entries do
		if entries[i].order > rank then
			index = i
			break
		end
	end
	table.insert(entries, index, { key = key, order = rank, text = text })
	version += 1
end

function hudState.HasInfo(key: string): boolean
	for i = 1, #entries do
		if entries[i].key == key then
			return true
		end
	end
	return false
end

function hudState.InfoVersion(): number
	return version
end

function hudState.GetInfoEntries(): { InfoEntry }
	return entries
end

return hudState
