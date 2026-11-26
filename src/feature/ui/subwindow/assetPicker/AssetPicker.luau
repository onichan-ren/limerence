local Charm = require("@pkg/Charm")
local React = require("@pkg/React")

local Subwindow = require("@ui/subwindow/Subwindow")
local renderer = require("@ui/subwindow/assetPicker/renderer")

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement

local AssetPicker = {}
AssetPicker.__index = AssetPicker

setmetatable(AssetPicker, { __index = Subwindow })

local function constructor(): AssetPicker
	local self = Subwindow.new() :: any
	setmetatable(self, AssetPicker)

	self._title = at("")
	self._source = at(nil :: any)
	self._activePreview = at(nil :: string?)

	sub(self._isOpen, function(isOpen: boolean): ()
		if isOpen then
			return
		end

		local source = peek(self._source)
		if source then
			if source.StopPreview then
				source:StopPreview()
			end
			if source._open then
				source._open(false)
			end
		end

		self._activePreview(nil)
	end)

	return self
end

function AssetPicker.Open(self: AssetPicker, source: any, position: UDim2?): ()
	local previous = peek(self._source)
	if previous and previous ~= source and previous._open then
		previous._open(false)
	end

	if source._open then
		source._open(true)
	end

	if source.Refresh then
		source:Refresh()
	end

	self._source(source)
	self._title(peek(source._text) or "Assets")

	self:SetPosition(position or UDim2.fromScale(0.5, 0.5))
	self:SetOpen(true)
end

function AssetPicker.Close(self: AssetPicker): ()
	self:SetOpen(false)
end

function AssetPicker.SetActivePreview(self: AssetPicker, name: string?): ()
	self._activePreview(name)
end

function AssetPicker.Render(self: AssetPicker): React.Element<any>
	return e(renderer, { AssetPicker = self })
end

export type Subwindow = Subwindow.Subwindow
export type AssetPicker =
	typeof(setmetatable(
		{} :: {
			_title: Charm.Atom<string>,
			_source: Charm.Atom<any>,
			_activePreview: Charm.Atom<string?>,
		},
		AssetPicker
	))
	& Subwindow

return constructor
