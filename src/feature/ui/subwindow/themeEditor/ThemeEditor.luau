local Charm = require("@pkg/Charm")
local React = require("@pkg/React")

local Subwindow = require("@ui/subwindow/Subwindow")
local renderer = require("@ui/subwindow/themeEditor/renderer")

local at = Charm.atom
local e = React.createElement

local ThemeEditor = {}
ThemeEditor.__index = ThemeEditor

setmetatable(ThemeEditor, { __index = Subwindow })

local function constructor(): ThemeEditor
	local self = Subwindow.new() :: any
	setmetatable(self, ThemeEditor)

	self._title = at("")
	self._themeName = at(nil :: string?)
	self._sections = at({} :: { any })

	self._snapshot = nil :: { [string]: any }?
	self._onSave = nil :: (() -> ())?
	self._onCancel = nil :: (() -> ())?

	return self
end

function ThemeEditor.SetSections(self: ThemeEditor, sections: { any }): ()
	self._sections(sections)
end

export type OpenOptions = {
	title: string,
	name: string,
	position: UDim2?,
	snapshot: { [string]: any }?,
	onSave: (() -> ())?,
	onCancel: (() -> ())?,
}

function ThemeEditor.Open(self: ThemeEditor, opts: OpenOptions): ()
	self._title(opts.title)
	self._themeName(opts.name)
	self._snapshot = opts.snapshot
	self._onSave = opts.onSave
	self._onCancel = opts.onCancel

	self:SetPosition(opts.position or UDim2.fromScale(0.5, 0.5))
	self:SetOpen(true)
end

function ThemeEditor.Save(self: ThemeEditor): ()
	local onSave = self._onSave
	self._snapshot = nil
	self._onSave = nil
	self._onCancel = nil
	self:SetOpen(false)
	if onSave then
		onSave()
	end
end

function ThemeEditor.Cancel(self: ThemeEditor): ()
	local onCancel = self._onCancel
	self._snapshot = nil
	self._onSave = nil
	self._onCancel = nil
	self:SetOpen(false)
	if onCancel then
		onCancel()
	end
end

function ThemeEditor.Render(self: ThemeEditor): React.Element<any>
	return e(renderer, { ThemeEditor = self })
end

export type ThemeEditor =
	typeof(setmetatable(
		{} :: {
			_title: Charm.Atom<string>,
			_themeName: Charm.Atom<string?>,
			_sections: Charm.Atom<{ any }>,
			_snapshot: { [string]: any }?,
			_onSave: (() -> ())?,
			_onCancel: (() -> ())?,
		},
		ThemeEditor
	))
	& Subwindow.Subwindow

return constructor
