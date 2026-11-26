local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local duelVote = require("@game/rivals/feature/combat/ragebot/duelVote")

local STRATEGIES: { string } = { "First", "Random" }
local RANDOM_OPTION = "Random"
local AUTO = "Auto"

local MAPS: { string } = {
	AUTO,
	"Random",
	"Arena",
	"Big Arena",
	"Backrooms",
	"Big Backrooms",
	"Battleground",
	"Bridge",
	"Chess",
	"Construction",
	"Crossroads",
	"Big Crossroads",
	"Dimension",
	"Docks",
	"Factory",
	"Graveyard",
	"Big Graveyard",
	"Iceberg",
	"Museum",
	"Onyx",
	"Big Onyx",
	"Playground",
	"Sandbox",
	"Splash",
	"Big Splash",
	"Station",
	"Big Station",
	"Studio",
	"Village",
	"Westown",
}

local AutoVoteMap = {}
AutoVoteMap.__index = AutoVoteMap

setmetatable(AutoVoteMap, { __index = BaseFeature })

function AutoVoteMap.new(link: gameUi.Linker): AutoVoteMap
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoVoteMap)

	link:Toggle("autoVoteMap", "Auto Vote Map", false):SetTip({
		title = "Auto Vote Map",
		body = "Votes for a map during the round's map pick. Uses your preferred map if it's available, otherwise the fallback.",
	})

	local mapLink = link:OnKey("autoVoteMap")
	mapLink:Submenu("opts", "Map")
	local optsLink = mapLink:OnKey("opts")
	optsLink:Dropdown("preferred", "Preferred Map", MAPS, AUTO)
	optsLink:Dropdown("fallback", "Fallback", STRATEGIES, STRATEGIES[1])

	self._link = link
	self._enabledLink = link:Get("autoVoteMap")
	self._janitor = Janitor.new()
	self._preferred = optsLink:Peek("preferred") or AUTO
	self._fallback = optsLink:Peek("fallback") or STRATEGIES[1]
	self._lastOptions = nil

	self:Track(optsLink:Get("preferred"):OnChange(function(v: string): ()
		self._preferred = v or AUTO
	end))
	self:Track(optsLink:Get("fallback"):OnChange(function(v: string): ()
		self._fallback = v or STRATEGIES[1]
	end))

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
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

function AutoVoteMap._pick(self: AutoVoteMap, options: { any }): string?
	local preferred = string.lower(self._preferred)
	if preferred ~= "" and preferred ~= string.lower(AUTO) and preferred ~= "random" then
		for _, option in next, options do
			if option.Name and string.lower(option.Name) == preferred then
				return option.Name
			end
		end
	end

	local pool: { string } = {}
	for _, option in next, options do
		if option.Name and option.Name ~= RANDOM_OPTION then
			pool[#pool + 1] = option.Name
		end
	end
	if #pool == 0 then
		return nil
	end

	if preferred == "random" or self._fallback == "Random" then
		return pool[math.random(1, #pool)]
	end
	return pool[1]
end

function AutoVoteMap._onPhase(self: AutoVoteMap, duel: any): ()
	if duel:Get("VoteOptionsType") ~= "Maps" then
		return
	end
	if duelVote.isBanPhase(duel, "Maps") then
		return
	end
	local options = duel:Get("VoteOptions")
	if type(options) ~= "table" then
		return
	end
	if options == self._lastOptions then
		return
	end
	self._lastOptions = options

	local choice = self:_pick(options)
	if choice then
		duelVote.send(choice)
	end
end

function AutoVoteMap.Enable(self: AutoVoteMap): ()
	if self._enabled then
		return
	end
	self._enabled = true
	duelVote.bind(self._janitor, function(duel: any): ()
		self:_onPhase(duel)
	end)
end

function AutoVoteMap.Disable(self: AutoVoteMap): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._lastOptions = nil
	self._janitor:Cleanup()
end

function AutoVoteMap.Destroy(self: AutoVoteMap): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoVoteMap = typeof(setmetatable(
	{} :: {
		_link: gameUi.Linker,
		_enabledLink: any,
		_enabled: boolean,
		_preferred: string,
		_fallback: string,
		_lastOptions: any,
		_janitor: Janitor.Janitor,
	},
	AutoVoteMap
)) & BaseFeature.BaseFeature

return AutoVoteMap
