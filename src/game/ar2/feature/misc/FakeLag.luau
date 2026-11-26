local UniversalFakeLag = require("@game/universal/feature/misc/FakeLag")
local clientState = require("@game/ar2/client/clientState")
local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")

local peek = Charm.peek

local FakeLag = {}

function FakeLag.new(link: gameUi.Linker): UniversalFakeLag.FakeLag
	return UniversalFakeLag.new(link, {
		getCharacter = function(): Instance?
			return peek(clientState.character)
		end,
		isAlive = function(): boolean
			return peek(clientState.alive)
		end,
		getRoot = function(): BasePart?
			return peek(clientState.hrp)
		end,
		getParts = function(): { [string]: Instance }
			return peek(clientState.parts)
		end,
	})
end

return FakeLag
