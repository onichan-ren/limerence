export type WatermarkItemId = "cheat" | "build" | "game" | "ping" | "fps" | "playtime" | "username"

local watermarkOrder = {}

watermarkOrder.DEFAULT = { "cheat", "build", "game", "ping", "fps", "playtime", "username" }

local VALID: { [string]: boolean } = {
	cheat = true,
	build = true,
	game = true,
	ping = true,
	fps = true,
	playtime = true,
	username = true,
}

function watermarkOrder.normalize(raw: any): { WatermarkItemId }
	local out: { WatermarkItemId } = {}
	local seen: { [string]: boolean } = {}

	if type(raw) == "table" then
		for _, entry in next, raw do
			if type(entry) == "string" and VALID[entry] and not seen[entry] then
				seen[entry] = true
				out[#out + 1] = entry :: WatermarkItemId
			end
		end
	end

	for _, id in next, watermarkOrder.DEFAULT do
		if not seen[id] then
			out[#out + 1] = id
		end
	end

	return out
end

function watermarkOrder.swap(order: { WatermarkItemId }, fromIndex: number, toIndex: number): { WatermarkItemId }
	if fromIndex == toIndex then
		return order
	end
	local nextOrder: { WatermarkItemId } = {}
	for i, id in next, order do
		nextOrder[i] = id
	end
	local item = nextOrder[fromIndex]
	table.remove(nextOrder, fromIndex)
	table.insert(nextOrder, toIndex, item)
	return nextOrder
end

function watermarkOrder.indexOf(order: { WatermarkItemId }, id: WatermarkItemId): number?
	for i, entry in next, order do
		if entry == id then
			return i
		end
	end
	return nil
end

return watermarkOrder
