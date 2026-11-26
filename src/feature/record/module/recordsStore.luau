local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")
local HttpService = cloneref(game:GetService("HttpService")) :: HttpService
local logger = require("@share/logger").new("recordsStore")

local at = Charm.atom
local peek = Charm.peek

local RECORDS_DIR = "limerence.biz/records"

export type Record = {
	userId: number,
	username: string,
	displayName: string,
	state: string?,
	note: string?,
	updatedAt: number,
}

local recordsStore = {
	_records = at({} :: { [string]: Record }),
}

local function pathFor(userId: number): string
	return `{RECORDS_DIR}/{userId}.json`
end

local function ensureFolder(): ()
	if not isfolder(RECORDS_DIR) then
		makefolder(RECORDS_DIR)
	end
end

local function writeRecord(record: Record): ()
	ensureFolder()
	local ok, encoded = pcall(function(): string
		return HttpService:JSONEncode(record)
	end)
	if not ok then
		logger:error("failed to encode record " .. tostring(record.userId))
		return
	end
	writefile(pathFor(record.userId), encoded)
end

function recordsStore.Load(): ()
	ensureFolder()

	local map: { [string]: Record } = {}
	for _, path in next, listfiles(RECORDS_DIR) do
		local userIdStr = path:match("([^/\\]+)%.json$")
		if userIdStr then
			local decodeOk, decoded: any = pcall(function(): any
				return HttpService:JSONDecode(readfile(path))
			end)
			if decodeOk and type(decoded) == "table" and type(decoded.userId) == "number" then
				map[tostring(decoded.userId)] = decoded
			end
		end
	end

	local count = 0
	for _ in next, map do
		count += 1
	end

	recordsStore._records(map)
	logger:log(`loaded {count} player records`)
end

function recordsStore.GetAll(): { Record }
	local list: { Record } = {}
	for _, record in next, peek(recordsStore._records) do
		table.insert(list, record)
	end
	return list
end

function recordsStore.Get(userId: number): Record?
	return peek(recordsStore._records)[tostring(userId)]
end

function recordsStore.Has(userId: number): boolean
	return peek(recordsStore._records)[tostring(userId)] ~= nil
end

function recordsStore.Set(record: Record): Record
	local key = tostring(record.userId)
	record.updatedAt = os.time()
	recordsStore._records(Sift.Dictionary.set(peek(recordsStore._records), key, record))
	writeRecord(record)
	return record
end

function recordsStore.Upsert(userId: number, username: string, displayName: string, patch: { [string]: any }?): Record
	local key = tostring(userId)
	local current: Record? = peek(recordsStore._records)[key]
	local base: Record = current
		or {
			userId = userId,
			username = username,
			displayName = displayName,
			state = nil,
			note = nil,
			updatedAt = 0,
		}

	local merged: Record = Sift.Dictionary.join(base, {
		username = username,
		displayName = displayName,
	}, patch or {})
	merged.updatedAt = os.time()

	recordsStore._records(Sift.Dictionary.set(peek(recordsStore._records), key, merged))
	writeRecord(merged)
	return merged
end

function recordsStore.Update(userId: number, patch: { [string]: any }): Record?
	local key = tostring(userId)
	local current: Record? = peek(recordsStore._records)[key]
	if not current then
		return nil
	end
	local merged: Record = Sift.Dictionary.join(current, patch)
	merged.updatedAt = os.time()
	recordsStore._records(Sift.Dictionary.set(peek(recordsStore._records), key, merged))
	writeRecord(merged)
	return merged
end

function recordsStore.Delete(userId: number): boolean
	local key = tostring(userId)
	local current = peek(recordsStore._records)
	if not current[key] then
		return false
	end
	recordsStore._records(Sift.Dictionary.removeKey(current, key))
	if isfile(pathFor(userId)) then
		delfile(pathFor(userId))
	end
	return true
end

function recordsStore.SubscribeAll(callback: (records: { [string]: Record }) -> ()): () -> ()
	return Charm.subscribe(recordsStore._records, callback)
end

function recordsStore.GetAtom(): Charm.Atom<{ [string]: Record }>
	return recordsStore._records
end

return recordsStore
