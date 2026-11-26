local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Element = require("@ui/window/element/Element")
local renderer = require("@ui/window/element/prioritylist/renderer")

local at = Charm.atom
local peek = Charm.peek
local e = React.createElement

local PriorityList = {}
PriorityList.__index = PriorityList

setmetatable(PriorityList, { __index = Element })

local function toStringArray(value: any): { string }
	local out: { string } = {}
	if type(value) ~= "table" then
		return out
	end
	for _, item in value do
		if type(item) == "string" then
			table.insert(out, item)
		end
	end
	return out
end

local function sanitize(options: { string }, order: any): { string }
	local valid: { [string]: true } = {}
	for _, opt in options do
		valid[opt] = true
	end

	local seen: { [string]: true } = {}
	local out: { string } = {}
	for _, id in toStringArray(order) do
		if valid[id] and not seen[id] then
			seen[id] = true
			table.insert(out, id)
		end
	end
	for _, opt in options do
		if not seen[opt] then
			table.insert(out, opt)
		end
	end
	return out
end

local function constructor(text: string, options: { string }?, default: { string }?): PriorityList
	local self = Element.new(text) :: any
	setmetatable(self, PriorityList)

	local opts = toStringArray(options)
	self._options = at(opts)
	self._state(sanitize(opts, default or opts))

	return self
end

function PriorityList.GetOrder(self: PriorityList): { string }
	return sanitize(peek(self._options), peek(self._state))
end

function PriorityList.SetOrder(self: PriorityList, order: { string }): ()
	self._state(sanitize(peek(self._options), order))
end

function PriorityList.MoveTo(self: PriorityList, id: string, index: number): ()
	local order = table.clone(self:GetOrder())
	local from: number? = nil
	for i, v in order do
		if v == id then
			from = i
			break
		end
	end
	if not from then
		return
	end
	index = math.clamp(index, 1, #order)
	if index == from then
		return
	end
	table.remove(order, from)
	table.insert(order, index, id)
	self._state(order)
end

function PriorityList.MoveUp(self: PriorityList, id: string): ()
	local order = table.clone(self:GetOrder())
	local idx: number? = nil
	for i, v in order do
		if v == id then
			idx = i
			break
		end
	end
	if not idx then
		return
	end

	if idx == 1 then
		table.remove(order, 1)
		table.insert(order, id)
	else
		order[idx], order[idx - 1] = order[idx - 1], order[idx]
	end
	self._state(order)
end

function PriorityList.Render(self: PriorityList, layoutOrder: number?): React.Element<any>
	return e(renderer, {
		List = self,
		LayoutOrder = layoutOrder,
	})
end

function PriorityList.RenderInternal(self: PriorityList, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		List = self,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type PriorityList = typeof(setmetatable(
	{} :: {
		_options: Charm.Atom<{ string }>,
	},
	PriorityList
)) & Element.Element

return {
	__call = constructor,
}
