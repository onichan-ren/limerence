local Signal = require("@pkg/Signal")
local StateController = require("@game/op1/state/StateController")

local CharacterController = {
	_byPlayer = {} :: { [Player]: any },
	objectAdded = Signal.new() :: Signal.Signal<Player, any>,
	objectRemoving = Signal.new() :: Signal.Signal<Player, any>,
}

local function removeFor(player: Player, object: any): ()
	if CharacterController._byPlayer[player] ~= object then
		return
	end

	CharacterController._byPlayer[player] = nil
	CharacterController.objectRemoving:Fire(player, object)
end

local function onObject(object: any): ()
	object.owner:hook(function(player: Player?): ()
		if not player or CharacterController._byPlayer[player] == object then
			return
		end

		local previous = CharacterController._byPlayer[player]
		if previous and previous ~= object then
			removeFor(player, previous)
		end

		CharacterController._byPlayer[player] = object
		CharacterController.objectAdded:Fire(player, object)
	end)

	object:destroying(function(): ()
		for player, tracked in next, CharacterController._byPlayer do
			if tracked == object then
				removeFor(player, object)
			end
		end
	end)
end

function CharacterController.GetObject(player: Player): any
	return CharacterController._byPlayer[player]
end

function CharacterController.new(): CharacterController
	StateController.HookClass("Character", onObject)
	return CharacterController
end

function CharacterController.Destroy(): ()
	table.clear(CharacterController._byPlayer)
end

export type CharacterController = typeof(CharacterController)

return CharacterController
