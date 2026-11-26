local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local at = Charm.atom

local BasePlayer = {}
BasePlayer.__index = BasePlayer

function BasePlayer.new(player: Player): BasePlayer
	local self = setmetatable({}, BasePlayer) :: any

	self._player = player

	local janitor = Janitor.new()
	self._janitor = janitor
	self._exists = at(true)

	return self
end

function BasePlayer.GetPlayer(self: BasePlayer): Player
	return self._player
end

function BasePlayer.Destroy(self: BasePlayer): ()
	self._exists(false)
	self._janitor:Destroy()
end

export type BasePlayer =
	typeof(setmetatable(
		{} :: {
			_player: Player,
			_janitor: Janitor.Janitor,
			_exists: Charm.Atom<boolean>,
		},
		BasePlayer
	))
	& any

return BasePlayer
