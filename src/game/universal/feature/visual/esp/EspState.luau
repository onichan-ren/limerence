local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")

local at = Charm.atom
local peek = Charm.peek

export type EspEntry = { [string]: any }

local EspState = {}
EspState.__index = EspState

function EspState.new(): EspState
	local self = setmetatable({}, EspState)
	self.entries = at({} :: { [Player]: EspEntry })
	return self
end

function EspState.Set(self: EspState, player: Player, entry: EspEntry): ()
	self.entries(Sift.Dictionary.set(peek(self.entries), player, entry))
end

function EspState.Remove(self: EspState, player: Player): ()
	self.entries(Sift.Dictionary.removeKey(peek(self.entries), player))
end

function EspState.Get(self: EspState, player: Player): EspEntry?
	return peek(self.entries)[player]
end

export type EspState = typeof(setmetatable(
	{} :: {
		entries: Charm.Atom<{ [Player]: EspEntry }>,
	},
	EspState
))

return EspState
