local worldMapSource = require("@game/mvsd/feature/visual/world/worldMapSource")

local TRIM = 0.05
local SPAN_SCALE = 0.6
local MIN_RANGE = 25
local MAX_RANGE = 600

local xs: { number } = {}
local zs: { number } = {}

local cachedModel: Instance? = nil
local cachedRange: number? = nil

local function percentile(values: { number }, alpha: number): number
	local index = math.clamp(math.floor(#values * alpha + 0.5), 1, #values)
	return values[index]
end

local function computeRange(model: Instance): number?
	local parts = model:QueryDescendants("BasePart")
	local count = #parts
	if count == 0 then
		return nil
	end

	table.clear(xs)
	table.clear(zs)

	for i = 1, count do
		local position = (parts[i] :: BasePart).Position
		xs[i] = position.X
		zs[i] = position.Z
	end

	table.sort(xs)
	table.sort(zs)

	local spanX = percentile(xs, 1 - TRIM) - percentile(xs, TRIM)
	local spanZ = percentile(zs, 1 - TRIM) - percentile(zs, TRIM)

	table.clear(xs)
	table.clear(zs)

	return math.clamp(math.max(spanX, spanZ) * SPAN_SCALE, MIN_RANGE, MAX_RANGE)
end

local mapRange = {}

function mapRange.Get(): number?
	local model = worldMapSource.GetCurrentModel()
	if model ~= cachedModel then
		cachedModel = model
		cachedRange = model and computeRange(model) or nil
	end
	return cachedRange
end

return mapRange
