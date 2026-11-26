local Charm = require("@pkg/Charm")
local BindTypes = require("@ui/bind/bindTypes")

local at = Charm.atom

local Bind = {}
Bind.__index = Bind

local function constructor(name: string, callback: (active: boolean) -> ()): Bind
	local self = setmetatable({}, Bind) :: Bind

	self.name = name
	self.inputs = at({})
	self.callback = callback
	self.mode = at("toggle" :: any)
	self.active = at(false) :: Charm.Atom<boolean>

	return self
end

function Bind.SetMode(self: Bind, mode: BindTypes.BindMode): Bind
	self.mode(mode)

	return self
end

function Bind.SetInputs(self: Bind, inputs: { BindTypes.BindInput }): Bind
	self.inputs(inputs)

	return self
end

export type Bind = typeof(setmetatable(
	{} :: {
		name: string,
		inputs: Charm.Atom<{ BindTypes.BindInput }>,
		callback: (active: boolean) -> (),
		mode: Charm.Atom<BindTypes.BindMode>,
		active: Charm.Atom<boolean>,
	},
	Bind
))

return constructor
