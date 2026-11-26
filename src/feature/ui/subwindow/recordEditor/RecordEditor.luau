local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Subwindow = require("@ui/subwindow/Subwindow")
local subwindowPosition = require("@ui/util/subwindowPosition")
local renderer = require("@ui/subwindow/recordEditor/renderer")

local at = Charm.atom
local peek = Charm.peek
local e = React.createElement

local RecordEditor = {}
RecordEditor.__index = RecordEditor

setmetatable(RecordEditor, { __index = Subwindow })

export type OpenOptions = {
	title: string,
	subtitle: string?,
	position: UDim2?,
	noteValue: string?,
	notePlaceholder: string?,
	onSave: (note: string) -> (),
	onCancel: (() -> ())?,
}

local function constructor(): RecordEditor
	local self = Subwindow.new() :: any
	setmetatable(self, RecordEditor)

	self._title = at("")
	self._subtitle = at("")
	self._note = at("")
	self._notePlaceholder = at("Add a note...")

	self._onSave = nil :: ((note: string) -> ())?
	self._onCancel = nil :: (() -> ())?

	return self
end

function RecordEditor.SetNote(self: RecordEditor, note: string): ()
	self._note(note or "")
end

function RecordEditor.GetNote(self: RecordEditor): string
	return peek(self._note)
end

function RecordEditor.Open(self: RecordEditor, opts: OpenOptions): ()
	self._title(opts.title)
	self._subtitle(opts.subtitle or "")
	self._note(opts.noteValue or "")
	self._notePlaceholder(opts.notePlaceholder or "Add a note...")

	self._onSave = opts.onSave
	self._onCancel = opts.onCancel

	self:SetPosition(opts.position or subwindowPosition.menuCenter())
	self:SetOpen(true)
end

function RecordEditor.Save(self: RecordEditor): ()
	local onSave = self._onSave
	local note = peek(self._note)
	self._onSave = nil
	self._onCancel = nil
	self:SetOpen(false)
	if onSave then
		onSave(note)
	end
end

function RecordEditor.Cancel(self: RecordEditor): ()
	local onCancel = self._onCancel
	self._onSave = nil
	self._onCancel = nil
	self:SetOpen(false)
	if onCancel then
		onCancel()
	end
end

function RecordEditor.Render(self: RecordEditor): React.Element<any>
	return e(renderer, { Editor = self })
end

export type RecordEditor = typeof(setmetatable(
	{} :: {
		_title: Charm.Atom<string>,
		_subtitle: Charm.Atom<string>,
		_note: Charm.Atom<string>,
		_notePlaceholder: Charm.Atom<string>,
		_onSave: ((note: string) -> ())?,
		_onCancel: (() -> ())?,
	},
	RecordEditor
)) & Subwindow.Subwindow

return constructor
