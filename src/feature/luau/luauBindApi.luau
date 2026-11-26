--[[
	Luau API contribution: `api.bind`

	Exposes the global keybind registry to user scripts so they can build
	custom keybind lists. Mirrors the data behind the BindEditor right-click
	menu: every keybind a user has attached to a UI element shows up here,
	with live signals for create / remove / activate / deactivate / change.
]]

local Signal = require("@pkg/Signal")
local Charm = require("@pkg/Charm")

local bindState = require("@ui/bind/bindState")
local elementBindController = require("@ui/bind/elementBindController")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")

local peek = Charm.peek
local sub = Charm.subscribe

export type BindInfo = {
	id: number,
	name: string,
	label: string,
	inputs: { string },
	inputLabels: { string },
	mode: string,
	active: boolean,
	targetValue: any,
}

local function serializeInputs(inputs: { Enum.KeyCode | Enum.UserInputType }): { string }
	local out: { string } = {}
	for i, input in next, inputs do
		out[i] = elementBindController.SerializeInput(input)
	end
	return out
end

local function inputLabelList(inputs: { Enum.KeyCode | Enum.UserInputType }): { string }
	local out: { string } = {}
	for i, input in next, inputs do
		out[i] = elementBindController.GetInputLabel(input)
	end
	return out
end

local function makeInfo(entry: elementBindController.BindListEntry): BindInfo
	local eb = entry.bind
	local rawInputs = peek(eb.inputs)
	return {
		id = eb.id,
		name = eb.name,
		label = entry.label,
		inputs = serializeInputs(rawInputs),
		inputLabels = inputLabelList(rawInputs),
		mode = peek(eb.mode),
		active = peek(eb.active),
		targetValue = peek(eb.targetValue),
	}
end

local onCreated = Signal.new()
local onRemoved = Signal.new()
local onActivated = Signal.new()
local onDeactivated = Signal.new()
local onChanged = Signal.new()

local activeUnsubs: { [number]: () -> () } = {}
local inputsUnsubs: { [number]: () -> () } = {}
local modeUnsubs: { [number]: () -> () } = {}
local known: { [number]: elementBindController.BindListEntry } = {}

local function attachWatchers(entry: elementBindController.BindListEntry): ()
	local id = entry.bind.id
	if activeUnsubs[id] then
		return
	end
	activeUnsubs[id] = sub(entry.bind.active, function(active: boolean): ()
		if active then
			onActivated:Fire(makeInfo(entry))
		else
			onDeactivated:Fire(makeInfo(entry))
		end
	end)
	inputsUnsubs[id] = sub(entry.bind.inputs, function(): ()
		onChanged:Fire(makeInfo(entry))
	end)
	modeUnsubs[id] = sub(entry.bind.mode, function(): ()
		onChanged:Fire(makeInfo(entry))
	end)
end

local function detachWatchers(id: number): ()
	if activeUnsubs[id] then
		activeUnsubs[id]()
		activeUnsubs[id] = nil
	end
	if inputsUnsubs[id] then
		inputsUnsubs[id]()
		inputsUnsubs[id] = nil
	end
	if modeUnsubs[id] then
		modeUnsubs[id]()
		modeUnsubs[id] = nil
	end
end

for _, entry in next, peek(elementBindController.allBinds) do
	known[entry.bind.id] = entry
	attachWatchers(entry)
end

sub(elementBindController.allBinds, function(entries: { elementBindController.BindListEntry }): ()
	local nowMap: { [number]: elementBindController.BindListEntry } = {}
	for _, entry in next, entries do
		nowMap[entry.bind.id] = entry
	end

	for id, prev in next, known do
		if not nowMap[id] then
			local info = makeInfo(prev)
			detachWatchers(id)
			onRemoved:Fire(info)
		end
	end

	for id, entry in next, nowMap do
		if not known[id] then
			attachWatchers(entry)
			onCreated:Fire(makeInfo(entry))
		end
	end

	known = nowMap
end)

local function list(): { BindInfo }
	local out: { BindInfo } = {}
	for _, entry in next, peek(elementBindController.allBinds) do
		out[#out + 1] = makeInfo(entry)
	end
	return out
end

local function getActive(): { BindInfo }
	local out: { BindInfo } = {}
	for _, entry in next, peek(elementBindController.allBinds) do
		if peek(entry.bind.active) then
			out[#out + 1] = makeInfo(entry)
		end
	end
	return out
end

local function get(id: number): BindInfo?
	local entry = known[id]
	if entry then
		return makeInfo(entry)
	end
	return nil
end

local function getInputLabel(input: any): string
	if type(input) == "string" then
		local deserialized = elementBindController.DeserializeInput(input)
		if deserialized then
			return elementBindController.GetInputLabel(deserialized)
		end
		return input
	end
	return elementBindController.GetInputLabel(input)
end

local function isAnyBindActive(): boolean
	return next(peek(bindState.activeBinds)) ~= nil
end

local luauBindApi = {}

luauApiRegistry.Register("bind", function(ctx)
	local wrap = luauApiRegistry.WrapSignal
	return {
		list = list,
		getActive = getActive,
		get = get,
		getInputLabel = getInputLabel,
		isAnyBindActive = isAnyBindActive,
		onCreated = wrap(onCreated, ctx.onUnload),
		onRemoved = wrap(onRemoved, ctx.onUnload),
		onActivated = wrap(onActivated, ctx.onUnload),
		onDeactivated = wrap(onDeactivated, ctx.onUnload),
		onChanged = wrap(onChanged, ctx.onUnload),
	}
end)

return luauBindApi
