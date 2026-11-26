local UniversalFootsteps = require("@game/universal/feature/visual/footsteps/Footsteps")
local clientState = require("@game/mvsd/client/clientState")
local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")

local peek = Charm.peek

local Footsteps = {}

function Footsteps.new(link: gameUi.Linker): UniversalFootsteps.Footsteps
	return UniversalFootsteps.new(link, {
		getCharacter = function(): Instance?
			return peek(clientState.character)
		end,
		isAlive = function(): boolean
			return peek(clientState.alive)
		end,
		getParts = function(): { [string]: Instance }
			return peek(clientState.parts)
		end,
	})
end

return Footsteps
