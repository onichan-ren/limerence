local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local ModuleController = require("@game/mvsd/module/ModuleController")
local NotifyController = require("@ui/hud/notify/NotifyController")

local AUTO = "Auto"
local RANDOM = "Random"

local STRATEGIES: { string } = { "First", "Random" }

local MAPS: { string } = {
	AUTO,
	RANDOM,
	"Lodge",
	"Aerial",
	"Prototype",
	"Ridge",
	"Barn",
}

local function getVoteRemote(): RemoteEvent?
	local Map = ReplicatedStorage:FindFirstChild("Map")
	local remote = Map and Map:FindFirstChild("VoteMap")
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	return nil
end

local function displayName(database: { [string]: any }?, id: any): string
	if database then
		local entry = database[id]
		if type(entry) == "table" and entry.Name then
			return entry.Name
		end
	end
	return tostring(id)
end

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

	local voteLink = link:OnKey("autoVoteMap")
	voteLink:Submenu("opts", "Auto Vote Map")
	local optsLink = voteLink:OnKey("opts")
	optsLink:Dropdown("preferred", "Preferred Map", MAPS, AUTO):SetTip({
		title = "Preferred Map",
		body = "Map to vote for when it's one of the choices.",
	})
	optsLink:Dropdown("fallback", "Fallback", STRATEGIES, STRATEGIES[1]):SetTip({
		title = "Fallback",
		body = "Pick when your preferred map isn't a choice.",
	})

	self._janitor = Janitor.new()
	self._preferred = optsLink:Peek("preferred") or AUTO
	self._fallback = optsLink:Peek("fallback") or STRATEGIES[1]

	self:Track(optsLink:Get("preferred"):OnChange(function(value: string): ()
		self._preferred = value or AUTO
	end))
	self:Track(optsLink:Get("fallback"):OnChange(function(value: string): ()
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

function AutoVoteMap._pick(self: AutoVoteMap, options: { any }): any?
	local database = ModuleController.GetModule("MapDatabase")

	local preferred = string.lower(self._preferred)
	if preferred ~= "" and preferred ~= string.lower(AUTO) and preferred ~= string.lower(RANDOM) then
		for _, id in next, options do
			if string.lower(displayName(database, id)) == preferred then
				return id
			end
		end
	end

	local pool: { any } = {}
	for _, id in next, options do
		pool[#pool + 1] = id
	end
	if #pool == 0 then
		return nil
	end

	if preferred == string.lower(RANDOM) or self._fallback == RANDOM then
		return pool[math.random(1, #pool)]
	end
	return pool[1]
end

function AutoVoteMap._onVote(self: AutoVoteMap, options: any): ()
	if type(options) ~= "table" then
		return
	end

	local choice = self:_pick(options)
	if not choice then
		return
	end

	local remote = getVoteRemote()
	if not remote then
		return
	end

	remote:FireServer(choice)

	NotifyController.Push({
		title = "Auto Vote Map",
		subtext = `Voted for {displayName(ModuleController.GetModule("MapDatabase"), choice)}.`,
		icon = "globe",
		duration = 3,
	})
end

function AutoVoteMap.Enable(self: AutoVoteMap): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local service = ModuleController.GetModule("MapService")
	if not service then
		return
	end

	local signal = service.GetMapVotingStartedSignal()
	if not signal then
		return
	end

	self._janitor:Add(
		signal:Connect(function(options: any): ()
			self:_onVote(options)
		end),
		"Disconnect"
	)
end

function AutoVoteMap.Disable(self: AutoVoteMap): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function AutoVoteMap.Destroy(self: AutoVoteMap): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoVoteMap = typeof(setmetatable(
	{} :: {
		_janitor: Janitor.Janitor,
		_enabled: boolean,
		_preferred: string,
		_fallback: string,
		_pick: (AutoVoteMap, { any }) -> any?,
		_onVote: (AutoVoteMap, any) -> (),
	},
	AutoVoteMap
)) & BaseFeature.BaseFeature

return AutoVoteMap
