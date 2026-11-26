local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Subwindow = require("@ui/subwindow/Subwindow")
local subwindowPosition = require("@ui/util/subwindowPosition")
local renderer = require("@ui/subwindow/visualImport/renderer")

local at = Charm.atom
local peek = Charm.peek
local e = React.createElement

local VisualImport = {}
VisualImport.__index = VisualImport

setmetatable(VisualImport, { __index = Subwindow })

export type GameEntry = {
	id: string,
	label: string,
	configs: { string },
}

export type CategoryEntry = {
	id: string,
	label: string,
}

export type OpenOptions = {
	games: { GameEntry },
	categories: { CategoryEntry },
	position: UDim2?,
	onImport: (gameId: string, configName: string, selected: { [string]: boolean }) -> (),
}

local function constructor(): VisualImport
	local self = Subwindow.new() :: any
	setmetatable(self, VisualImport)

	self._games = at({} :: { GameEntry })
	self._categories = at({} :: { CategoryEntry })
	self._selectedGame = at(nil :: string?)
	self._selectedConfig = at(nil :: string?)
	self._selectedCategories = at({} :: { [string]: boolean })

	self._onImport = nil :: ((gameId: string, configName: string, selected: { [string]: boolean }) -> ())?

	return self
end

local function firstConfigOf(self: VisualImport, gameId: string?): string?
	if not gameId then
		return nil
	end
	for _, entry in next, peek(self._games) do
		if entry.id == gameId then
			return entry.configs[1]
		end
	end
	return nil
end

function VisualImport.Open(self: VisualImport, opts: OpenOptions): ()
	self._games(opts.games)
	self._categories(opts.categories)

	local first = opts.games[1]
	local firstId = first and first.id or nil
	self._selectedGame(firstId)
	self._selectedConfig(firstConfigOf(self, firstId))

	local selected: { [string]: boolean } = {}
	for _, category in next, opts.categories do
		selected[category.id] = true
	end
	self._selectedCategories(selected)

	self._onImport = opts.onImport

	self:SetPosition(opts.position or subwindowPosition.menuCenter())
	self:SetOpen(true)
end

function VisualImport.SelectGame(self: VisualImport, gameId: string): ()
	if peek(self._selectedGame) == gameId then
		return
	end
	self._selectedGame(gameId)
	self._selectedConfig(firstConfigOf(self, gameId))
end

function VisualImport.SelectConfig(self: VisualImport, configName: string): ()
	self._selectedConfig(configName)
end

function VisualImport.ToggleCategory(self: VisualImport, categoryId: string): ()
	local selected = peek(self._selectedCategories)
	if selected[categoryId] then
		local enabledCount = 0
		for _, enabled in next, selected do
			if enabled then
				enabledCount += 1
			end
		end
		if enabledCount <= 1 then
			return
		end
	end

	local updated = table.clone(selected)
	updated[categoryId] = not updated[categoryId]
	self._selectedCategories(updated)
end

function VisualImport.CanImport(self: VisualImport): boolean
	return peek(self._selectedGame) ~= nil and peek(self._selectedConfig) ~= nil
end

function VisualImport.Import(self: VisualImport): ()
	local gameId = peek(self._selectedGame)
	local configName = peek(self._selectedConfig)
	if not gameId or not configName then
		return
	end

	local onImport = self._onImport
	self._onImport = nil
	self:SetOpen(false)
	if onImport then
		onImport(gameId, configName, peek(self._selectedCategories))
	end
end

function VisualImport.Close(self: VisualImport): ()
	self._onImport = nil
	self:SetOpen(false)
end

function VisualImport.Render(self: VisualImport): React.Element<any>
	return e(renderer, { Importer = self })
end

export type VisualImport = typeof(setmetatable(
	{} :: {
		_games: Charm.Atom<{ GameEntry }>,
		_categories: Charm.Atom<{ CategoryEntry }>,
		_selectedGame: Charm.Atom<string?>,
		_selectedConfig: Charm.Atom<string?>,
		_selectedCategories: Charm.Atom<{ [string]: boolean }>,
		_onImport: ((gameId: string, configName: string, selected: { [string]: boolean }) -> ())?,
	},
	VisualImport
)) & Subwindow.Subwindow

return constructor
