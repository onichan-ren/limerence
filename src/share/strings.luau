local random = Random.new()
local nextInteger = random.NextInteger

local utf8 = utf8.char

local strings = {}

local safeChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

strings.random = LPH_NO_VIRTUALIZE(function(length: number?): string
	local result = ""

	for i = 1, length or 15 do
		result ..= utf8(nextInteger(random, 33, 255))
	end

	return result
end :: (length: number?) -> string)

strings.randomSafe = LPH_NO_VIRTUALIZE(function(length: number?): string
	local result = ""

	for i = 1, length or 15 do
		local pos = nextInteger(random, 1, #safeChars)
		result ..= safeChars:sub(pos, pos)
	end

	return result
end :: (length: number?) -> string)

return strings
