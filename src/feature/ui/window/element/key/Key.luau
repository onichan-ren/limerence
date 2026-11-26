local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Element = require("@ui/window/element/Element")
local BindController = require("@ui/bind/BindController")
local Bind = require("@ui/bind/Bind")
local bindState = require("@ui/bind/bindState")
local renderer = require("@ui/window/element/key/renderer")

local at = Charm.atom
local sub = Charm.subscribe
local peek = Charm.peek
local e = React.createElement

local Key = {}
Key.__index = Key

setmetatable(Key, { __index = Element })

local _idCounter = 0
local function nextId(): number
	_idCounter += 1
	return _idCounter
end

export type KeyMode = "onPress" | "onRelease" | "onHold" | "toggle"
type Input = Enum.KeyCode | Enum.UserInputType

local function firstInput(inputs: { Input }): Input?
	return inputs[1]
end

local function constructor(text: string, default: Input?, mode: KeyMode?, attachBind: string?): Key
	local self = Element.new(text) :: any
	setmetatable(self, Key)

	if typeof(default) ~= "EnumItem" then
		default = nil
	end

	self._callbacks = {} :: { (boolean) -> () }
	self._listening = at(false)
	self._attachedBind = attachBind ~= nil

	if attachBind then
		local bind = peek(bindState.binds)[attachBind]
		if not bind then
			error(`Key: bind "{attachBind}" not found`, 2)
		end

		self._bind = bind
		self._mode = bind.mode

		local inputs = peek(bind.inputs)
		self._state(default or firstInput(inputs))

		self._unsubInputs = sub(self._state, function(value: Input?): ()
			local current = peek(bind.inputs)
			local nextInput = value
			if firstInput(current) == nextInput then
				return
			end
			bind.inputs(nextInput and { nextInput } or {})
		end)

		self._unsubFromBind = sub(bind.inputs, function(inputs: { Input }): ()
			local nextInput = firstInput(inputs)
			if peek(self._state) == nextInput then
				return
			end
			self._state(nextInput)
		end)
	else
		self._state(default)
		self._mode = at(mode or "onPress")

		local id = nextId()
		local name = `keyel_{id}`

		local bind = Bind(name, function(active: boolean): ()
			for _, cb in next, self._callbacks do
				task.spawn(cb, active)
			end
		end)
		bind.mode = self._mode
		bind.inputs(default and { default } or {})
		BindController._registerBind(bind)
		self._bind = bind

		self._unsubInputs = sub(self._state, function(value: Input?): ()
			bind.inputs(value and { value } or {})
		end)
	end

	return self
end

function Key.Destroy(self: Key): ()
	if self._unsubInputs then
		self._unsubInputs()
		self._unsubInputs = nil
	end
	if self._unsubFromBind then
		self._unsubFromBind()
		self._unsubFromBind = nil
	end
	if self._bind and not self._attachedBind then
		BindController.RemoveBind(self._bind.name)
	end
	self._callbacks = {}
	Element.Destroy(self)
end

function Key.OnCallback(self: Key, callback: (active: boolean) -> ()): () -> ()
	table.insert(self._callbacks, callback)
	return function()
		local idx = table.find(self._callbacks, callback)
		if idx then
			table.remove(self._callbacks, idx)
		end
	end
end

function Key.SetMode(self: Key, mode: KeyMode): Key
	if self._attachedBind then
		self._bind.mode(mode)
	else
		self._mode(mode)
	end
	return self
end

function Key.SetKey(self: Key, key: Input?): Key
	self._state(key)
	return self
end

function Key.SetListening(self: Key, listening: boolean): ()
	self._listening(listening)
end

function Key.RenderInternal(self: Key, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		Key = self,
		TextRef = props and props.textRef,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type Key = typeof(setmetatable(
	{} :: {
		_mode: Charm.Atom<KeyMode>,
		_callbacks: { (boolean) -> () },
		_listening: Charm.Atom<boolean>,
		_bind: Bind.Bind,
		_unsubInputs: (() -> ())?,
		_unsubFromBind: (() -> ())?,
		_attachedBind: boolean,
	},
	Key
)) & Element.Element

return constructor
