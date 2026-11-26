local Charm = require("@pkg/Charm")
local React = require("@pkg/React")

local Subwindow = require("@ui/subwindow/Subwindow")
local renderer = require("@ui/subwindow/context/renderer")

local at = Charm.atom
local e = React.createElement

local Context = {}
Context.__index = Context

setmetatable(Context, { __index = Subwindow })

export type ContextItem = {
	Label: string?,
	Icon: string?,
	Callback: (() -> ())?,
	Divider: boolean?,
	OnHoverEnter: (() -> ())?,
	OnHoverLeave: (() -> ())?,
	HoverDelay: number?,
}

local function constructor(): Context
	local self = Subwindow.new() :: any

	setmetatable(self, Context)

	self._items = at({} :: { ContextItem })

	return self
end

function Context.Open(self: Context, items: { ContextItem }, position: UDim2?): ()
	if not items or #items == 0 then
		return
	end

	self._items(items)
	self:SetPosition(position or UDim2.new(0, 0, 0, 0))
	self:SetOpen(true)
end

function Context.Close(self: Context): ()
	self:SetOpen(false)
end

function Context.Render(self: Context): React.Element<any>
	return e(renderer, {
		Context = self,
	})
end

export type Subwindow = Subwindow.Subwindow
export type Context = typeof(setmetatable(
	{} :: {
		_items: Charm.Atom<{ ContextItem }>,
	},
	Context
)) & Subwindow

return constructor
