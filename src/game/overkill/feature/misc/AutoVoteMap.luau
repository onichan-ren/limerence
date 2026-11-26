local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local NetworkController = require("@game/overkill/network/NetworkController")
local ModuleController = require("@game/overkill/module/ModuleController")

local LocalPlayer = Players.LocalPlayer

local AUTO = "Auto"
local RANDOM = "Random"
local STRATEGIES: { string } = { "First", "Random" }

local AutoVoteMap = {}
AutoVoteMap.__index = AutoVoteMap

setmetatable(AutoVoteMap, { __index = BaseFeature })

local function buildMaps(): ({ [string]: string }, { string })
	local maps = ModuleController.GetModule("maps")
	local idByName: { [string]: string } = {}
	local entries: { { name: string, order: number } } = {}

	if maps and maps.all then
		for id, data in next, maps.all do
			if id ~= "shooting_range" then
				local name = data.name or id
				idByName[string.lower(name)] = id
				table.insert(entries, { name = name, order = data.order or 999 })
			end
		end
	end

	table.sort(entries, function(a, b): boolean
		return a.order < b.order
	end)

	local options: { string } = { AUTO, RANDOM }
	for _, entry in next, entries do
		table.insert(options, entry.name)
	end

	return idByName, options
end

function AutoVoteMap.new(link: gameUi.Linker): AutoVoteMap
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoVoteMap)

	local idByName, options = buildMaps()
	self._idByName = idByName

	link:Toggle("autoVoteMap", "Auto Vote Map", false):SetTip({
		title = "Auto Vote Map",
		body = "Votes for a map during the round's map pick. Uses your preferred map if it's available, otherwise the fallback.",
	})

	local optsLink = link:OnKey("autoVoteMap")
	optsLink:Submenu("opts", "Map")
	local mapLink = optsLink:OnKey("opts")
	mapLink:Dropdown("preferred", "Preferred Map", options, AUTO)
	mapLink:Dropdown("fallback", "Fallback", STRATEGIES, STRATEGIES[1])

	self._enabled = false
	self._preferred = mapLink:Peek("preferred") or AUTO
	self._fallback = mapLink:Peek("fallback") or STRATEGIES[1]
	self._conn = nil

	self:Track(mapLink:Get("preferred"):OnChange(function(value: string): ()
		self._preferred = value or AUTO
	end))
	self:Track(mapLink:Get("fallback"):OnChange(function(value: string): ()
		self._fallback = value or STRATEGIES[1]
	end))

	self:Track(link:Get("autoVoteMap"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("autoVoteMap") then
		self:Enable()
	end

	return self
end

function AutoVoteMap._pick(self: AutoVoteMap, options: { string }): string?
	local preferred = string.lower(self._preferred)
	if preferred ~= "" and preferred ~= string.lower(AUTO) and preferred ~= string.lower(RANDOM) then
		local wantId = self._idByName[preferred]
		if wantId then
			for _, id in next, options do
				if id == wantId then
					return id
				end
			end
		end
	end

	if #options == 0 then
		return nil
	end

	if preferred == string.lower(RANDOM) or self._fallback == RANDOM then
		return options[math.random(1, #options)]
	end
	return options[1]
end

function AutoVoteMap._onDuel(self: AutoVoteMap, duel: any, options: any): ()
	if type(duel) ~= "table" or not duel.players then
		return
	end
	if not table.find(duel.players, LocalPlayer) then
		return
	end
	if type(options) ~= "table" or #options == 0 then
		return
	end

	task.delay(0.1, function(): ()
		local choice = self:_pick(options)
		if choice then
			setthreadidentity(2)
			NetworkController.Fire("vote_map", choice)
			setthreadidentity(8)
		end
	end)
end

function AutoVoteMap.Enable(self: AutoVoteMap): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local gameplayHandler = ModuleController.GetModule("gameplayHandler")
	if not gameplayHandler or not gameplayHandler.DuelCreated then
		return
	end

	self._conn = gameplayHandler.DuelCreated:Connect(function(duel: any, options: any): ()
		self:_onDuel(duel, options)
	end)
end

function AutoVoteMap.Disable(self: AutoVoteMap): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
end

function AutoVoteMap.Destroy(self: AutoVoteMap): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoVoteMap =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_preferred: string,
			_fallback: string,
			_idByName: { [string]: string },
			_conn: any,
		},
		AutoVoteMap
	))
	& BaseFeature.BaseFeature

return AutoVoteMap
