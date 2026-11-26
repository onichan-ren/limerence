local Charm = require("@pkg/Charm")

local at = Charm.atom
local peek = Charm.peek

local colorClipboard = {
	color = at(nil :: (Color3 | ColorSequence)?),
	transparency = at(nil :: number?),
}

function colorClipboard.set(color: Color3 | ColorSequence, transparency: number?): ()
	colorClipboard.color(color)
	colorClipboard.transparency(transparency)
end

function colorClipboard.peek(): (Color3 | ColorSequence | nil, number?)
	return peek(colorClipboard.color), peek(colorClipboard.transparency)
end

function colorClipboard.has(): boolean
	return peek(colorClipboard.color) ~= nil
end

return colorClipboard
