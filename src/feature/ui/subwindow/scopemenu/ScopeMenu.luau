local Charm = require("@pkg/Charm")
local React = require("@pkg/React")

local Subwindow = require("@ui/subwindow/Subwindow")
local scopeState = require("@ui/scope/scopeState")
local renderer = require("@ui/subwindow/scopemenu/renderer")

local at = Charm.atom
local sub = Charm.subscribe
local e = React.createElement

local ScopeMenu = {}
ScopeMenu.__index = ScopeMenu

setmetatable(ScopeMenu, { __index = Subwindow })

export type OnManageHandler = () -> ()

local function constructor(): ScopeMenu
	local self = Subwindow.new() :: any
	setmetatable(self, ScopeMenu)

	self._onManage = at(nil :: OnManageHandler?)
	self._anchorRef = at(nil :: { current: GuiObject? }?)
	self._lastClosedAt = 0

	sub(self._isOpen, function(open: boolean): ()
		scopeState.menuOpen(open)
	end)

	return self
end

function ScopeMenu.Open(self: ScopeMenu, position: UDim2?, anchorRef: { current: GuiObject? }?): ()
	self._anchorRef(anchorRef)
	self:SetPosition(position or UDim2.new(0, 0, 0, 0))
	self:SetOpen(true)
end

function ScopeMenu.Close(self: ScopeMenu): ()
	self._lastClosedAt = os.clock()
	self:SetOpen(false)
end

function ScopeMenu.WasJustClosed(self: ScopeMenu): boolean
	return os.clock() - self._lastClosedAt < 0.1
end

function ScopeMenu.SetOnManage(self: ScopeMenu, handler: OnManageHandler?): ()
	self._onManage(handler)
end

function ScopeMenu.Render(self: ScopeMenu): React.Element<any>
	return e(renderer, {
		ScopeMenu = self,
	})
end

export type Subwindow = Subwindow.Subwindow
export type ScopeMenu = typeof(setmetatable(
	{} :: {
		_onManage: Charm.Atom<OnManageHandler?>,
		_anchorRef: Charm.Atom<{ current: GuiObject? }?>,
		_lastClosedAt: number,
	},
	ScopeMenu
)) & Subwindow

return constructor
