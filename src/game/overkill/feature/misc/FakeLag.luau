local UniversalFakeLag = require("@game/universal/feature/misc/FakeLag")
local clientState = require("@game/overkill/client/clientState")
local ChokeController = require("@game/overkill/network/ChokeController")
local CommandController = require("@game/overkill/weapon/CommandController")
local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")

local peek = Charm.peek

local FakeLag = {}

function FakeLag.new(link: gameUi.Linker): UniversalFakeLag.FakeLag
	local tick = 0

	local self = UniversalFakeLag.new(link, {
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
		tickMode = true,
		getTick = function(): number
			return tick
		end,
		setFrozen = function(frozen: boolean, depth: number?): ()
			ChokeController.SetRequest("fakeLag", frozen, "action", depth or 6)
		end,
	})

	self:Track(CommandController.Register(function(): ()
		tick += 1
	end, 0))

	return self
end

return FakeLag
