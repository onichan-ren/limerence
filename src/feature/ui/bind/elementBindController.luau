local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")

local Bind = require("@ui/bind/Bind")
local BindController = require("@ui/bind/BindController")
local bindState = require("@ui/bind/bindState")
local elementBindTypes = require("@ui/bind/elementBindTypes")

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe

local function isInputHeld(input: Enum.KeyCode | Enum.UserInputType): boolean
	if typeof(input) ~= "EnumItem" then
		return false
	end
	if (input :: any).EnumType == Enum.KeyCode then
		return UserInputService:IsKeyDown(input :: Enum.KeyCode)
	end
	if (input :: any).EnumType == Enum.UserInputType then
		return UserInputService:IsMouseButtonPressed(input :: Enum.UserInputType)
	end
	return false
end

local function isAnyInputHeld(inputs: { Enum.KeyCode | Enum.UserInputType }): boolean
	for _, inp in next, inputs do
		if isInputHeld(inp) then
			return true
		end
	end
	return false
end

export type ElementBind = elementBindTypes.ElementBind
export type BindListEntry = elementBindTypes.BindListEntry

local elementBindController = {
	allBinds = at({} :: { BindListEntry }),
	MAX_BINDS = 3,
}

local _idCounter = 0
local _modeUnsubs: { [number]: () -> () } = {}

local function nextId(): number
	_idCounter += 1
	return _idCounter
end

local function deactivateBind(eb: ElementBind): ()
	if not peek(eb.active) then
		return
	end
	local raw = peek(bindState.activeBinds)
	bindState.activeBinds(Sift.Dictionary.removeKey(raw, eb.name))
	eb.active(false)
	local bind = peek(bindState.binds)[eb.name]
	if bind then
		bind.callback(false)
	end
end

local function activateBind(eb: ElementBind): ()
	if peek(eb.active) then
		return
	end
	local underlying = peek(bindState.binds)[eb.name]
	if not underlying then
		return
	end
	local raw = peek(bindState.activeBinds)
	bindState.activeBinds(Sift.Dictionary.set(raw, eb.name, underlying))
	eb.active(true)
	underlying.callback(true)
end

local function forceInactive(eb: ElementBind): ()
	if peek(eb.active) then
		deactivateBind(eb)
		return
	end
	local bind = peek(bindState.binds)[eb.name]
	if bind then
		bind.callback(false)
	end
end

local function applyModeReset(eb: ElementBind): ()
	local inputs = peek(eb.inputs)
	if #inputs == 0 then
		deactivateBind(eb)
		return
	end
	local mode = peek(eb.mode)
	local held = isAnyInputHeld(inputs)
	if mode == "onHold" then
		if held then
			activateBind(eb)
		else
			forceInactive(eb)
		end
	elseif mode == "offHold" then
		if held then
			forceInactive(eb)
		else
			activateBind(eb)
		end
	else
		deactivateBind(eb)
	end
end

type ValueCtx = { hasBaseline: boolean, baseline: any, activeEb: ElementBind? }
local _valueCtx: { [any]: ValueCtx } = setmetatable({}, { __mode = "k" }) :: any

local function applyValue(element: any, value: any): ()
	if element.SetValue and type(value) == "number" then
		element:SetValue(value, true)
	else
		element._state(value)
	end
end

local function ctxFor(element: any): ValueCtx
	local ctx = _valueCtx[element]
	if not ctx then
		ctx = { hasBaseline = false, baseline = nil, activeEb = nil }
		_valueCtx[element] = ctx
	end
	return ctx
end

local function wireCallback(element: any, eb: ElementBind): ()
	local bind = peek(bindState.binds)[eb.name]
	if not bind then
		return
	end

	bind.callback = function(active: boolean)
		local tv = peek(eb.targetValue)
		if tv == nil then
			element._state(active)
			return
		end

		local ctx = ctxFor(element)
		if active then
			if not ctx.hasBaseline then
				ctx.baseline = peek(element._state)
				ctx.hasBaseline = true
			end
			local previous = ctx.activeEb
			ctx.activeEb = eb
			if previous and previous ~= eb then
				deactivateBind(previous)
			end
			applyValue(element, tv)
		elseif ctx.activeEb == eb then
			ctx.activeEb = nil
			if ctx.hasBaseline then
				applyValue(element, ctx.baseline)
				ctx.hasBaseline = false
				ctx.baseline = nil
			end
		end
	end
end

function elementBindController.CreateBind(element: any, label: string, targetValue: any?): ElementBind
	local id = nextId()
	local name = `elb_{id}`

	local resolvedTarget = targetValue
	if resolvedTarget == nil then
		local state = peek(element._state)
		if type(state) ~= "boolean" then
			resolvedTarget = state
		end
	end

	local eb: ElementBind = {
		id = id,
		name = name,
		mode = at("toggle" :: elementBindTypes.ElementBindMode),
		inputs = at({}),
		targetValue = at(resolvedTarget),
		showInList = at(true),
		active = at(false),
		savedValue = at(nil),
	}

	local bind = Bind(name, function() end)
	bind.mode = eb.mode
	bind.inputs = eb.inputs
	bind.active = eb.active
	BindController._registerBind(bind)

	wireCallback(element, eb)

	local modeUnsub = sub(eb.mode, function()
		applyModeReset(eb)
	end)
	local inputsUnsub = sub(eb.inputs, function()
		if #peek(eb.inputs) == 0 then
			deactivateBind(eb)
			return
		end
		local mode = peek(eb.mode)
		if mode == "offHold" or mode == "onHold" then
			applyModeReset(eb)
		end
	end)
	_modeUnsubs[id] = function()
		modeUnsub()
		inputsUnsub()
	end

	local rawAll = peek(elementBindController.allBinds)
	elementBindController.allBinds(Sift.Array.push(rawAll, {
		element = element,
		label = label,
		bind = eb,
	}))

	return eb
end

function elementBindController.DestroyBind(eb: ElementBind): ()
	deactivateBind(eb)

	local unsub = _modeUnsubs[eb.id]
	if unsub then
		unsub()
		_modeUnsubs[eb.id] = nil
	end

	local raw = peek(bindState.binds)
	bindState.binds(Sift.Dictionary.removeKey(raw, eb.name))

	local rawAll = peek(elementBindController.allBinds)
	elementBindController.allBinds(Sift.Array.filter(rawAll, function(entry: BindListEntry)
		return entry.bind.id ~= eb.id
	end))
end

function elementBindController.RestoreActive(eb: ElementBind): ()
	if peek(eb.active) then
		return
	end
	local underlying = peek(bindState.binds)[eb.name]
	if not underlying then
		return
	end
	local raw = peek(bindState.activeBinds)
	bindState.activeBinds(Sift.Dictionary.set(raw, eb.name, underlying))
	eb.active(true)
end

function elementBindController.RewireAll(element: any): ()
	local rawAll = peek(elementBindController.allBinds)
	for _, entry in next, rawAll do
		if entry.element == element then
			wireCallback(element, entry.bind)
		end
	end
end

function elementBindController.GetAllBinds(): { BindListEntry }
	return peek(elementBindController.allBinds)
end

function elementBindController.HasBindFor(element: any): boolean
	for _, entry in next, peek(elementBindController.allBinds) do
		if entry.element == element and #peek(entry.bind.inputs) > 0 then
			return true
		end
	end
	return false
end

function elementBindController.GetInputLabel(input: Enum.KeyCode | Enum.UserInputType): string
	local labels: { [any]: string } = {
		[Enum.KeyCode.LeftControl] = "LCtrl",
		[Enum.KeyCode.RightControl] = "RCtrl",
		[Enum.KeyCode.LeftShift] = "LShift",
		[Enum.KeyCode.RightShift] = "RShift",
		[Enum.KeyCode.LeftAlt] = "LAlt",
		[Enum.KeyCode.RightAlt] = "RAlt",
		[Enum.KeyCode.Return] = "Enter",
		[Enum.KeyCode.Backspace] = "Back",
		[Enum.KeyCode.CapsLock] = "Caps",
		[Enum.KeyCode.Space] = "Space",
		[Enum.KeyCode.Delete] = "Del",
		[Enum.KeyCode.Home] = "Home",
		[Enum.KeyCode.End] = "End",
		[Enum.KeyCode.PageUp] = "PgUp",
		[Enum.KeyCode.PageDown] = "PgDn",
		[Enum.UserInputType.MouseButton1] = "LMB",
		[Enum.UserInputType.MouseButton2] = "RMB",
		[Enum.UserInputType.MouseButton3] = "MMB",
	}

	local custom = labels[input]
	if custom then
		return custom
	end

	local str = tostring(input)
	return str:match("KeyCode%.(.+)$") or str:match("UserInputType%.(.+)$") or str
end

function elementBindController.SerializeInput(input: Enum.KeyCode | Enum.UserInputType): string
	local str = tostring(input)
	return str:match("Enum%.(.+)$") or str
end

function elementBindController.DeserializeInput(str: string): (Enum.KeyCode | Enum.UserInputType)?
	local enumType, enumValue = str:match("^(.-)%.(.+)$")
	if not enumType or not enumValue then
		return nil
	end
	if enumType == "KeyCode" then
		return (Enum.KeyCode :: any)[enumValue]
	elseif enumType == "UserInputType" then
		return (Enum.UserInputType :: any)[enumValue]
	end
	return nil
end

return elementBindController
