local Players = cloneref(game:GetService("Players")) :: Players
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local BaseFeature = require("@game/BaseFeature")
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local NetworkController = require("@game/bloxstrike/network/NetworkController")
local NotifyController = require("@ui/hud/notify/NotifyController")
local gameUi = require("@game/gameUi")

local LocalPlayer = Players.LocalPlayer

local MISSION_INTERVAL = 1.1
local STAR_INTERVAL = 0.15

local function requireGameModule(inst: Instance): any?
	setthreadidentity(2)
	local mod = require(inst)
	setthreadidentity(8)
	return mod
end

local MissionStars = requireGameModule((ReplicatedStorage :: any).Database.Custom.GameStats.MissionStars) or {}

local function isStarClaimed(rewards: any, index: number): boolean
	if type(rewards) ~= "table" then
		return false
	end

	local value = rewards[tostring(index)]
	if value == nil then
		value = rewards[index]
	end

	if type(value) == "string" then
		return string.lower(value) == "true"
	end
	return value == true
end

local AutoRewards = {}
AutoRewards.__index = AutoRewards

setmetatable(AutoRewards, { __index = BaseFeature })

function AutoRewards.new(link: gameUi.Linker): AutoRewards
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoRewards)

	link:Toggle("autoRewards", "Automatic Rewards", false):SetTip({
		title = "Automatic Rewards",
		body = "Claims finished mission rewards and daily streak rewards as soon as they unlock.",
	})

	local rootLink = link:OnKey("autoRewards")
	rootLink:Submenu("opts", "Automatic Rewards")
	local optsLink = rootLink:OnKey("opts")

	optsLink:Toggle("missions", "Missions", true):SetTip({
		title = "Missions",
		body = "Claims each mission reward once its progress is complete.",
	})
	optsLink:Toggle("stars", "Daily Streak", true):SetTip({
		title = "Daily Streak",
		body = "Claims every streak reward you have already unlocked.",
	})

	self._enabled = false
	self._enabledLink = link:Get("autoRewards")
	self._dataController = nil
	self._missionKey = nil
	self._starKey = nil
	self._nextSend = 0
	self._sentMissions = {} :: { [string]: boolean }
	self._sentStars = {} :: { [number]: boolean }
	self._missions = optsLink:Get("missions"):Peek() == true
	self._stars = optsLink:Get("stars"):Peek() == true

	self:Track(optsLink:Get("missions"):OnChange(function(value: boolean): ()
		self._missions = value == true
	end))
	self:Track(optsLink:Get("stars"):OnChange(function(value: boolean): ()
		self._stars = value == true
	end))

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("autoRewards") then
		self:Enable()
	end

	return self
end

function AutoRewards._send(self: AutoRewards, name: string, value: any, interval: number): ()
	local now = os.clock()
	local at = math.max(now, self._nextSend)
	self._nextSend = at + interval

	task.delay(at - now, function(): ()
		if not self._enabled then
			return
		end
		setthreadidentity(2)
		NetworkController.SendPacket("Dashboard", name, value)
		setthreadidentity(8)
	end)
end

function AutoRewards._scanMissions(self: AutoRewards, list: any): ()
	if not self._missions or type(list) ~= "table" then
		return
	end

	local sent = self._sentMissions :: { [string]: boolean }
	local claimed = 0
	for _, entry in next, list do
		if type(entry) ~= "table" then
			continue
		end

		local id = entry.MissionId
		if type(id) ~= "string" or entry.IsClaimed == true or sent[id] then
			continue
		end

		local target = tonumber(entry.Target)
		if not target or (tonumber(entry.Progress) or 0) < target then
			continue
		end

		sent[id] = true
		self:_send("MissionCompleted", id, MISSION_INTERVAL)
		claimed += 1
	end

	if claimed == 0 then
		return
	end

	local subtext = `Claiming {claimed} mission rewards`
	if claimed == 1 then
		subtext = "Claiming 1 mission reward"
	end

	NotifyController.Push({
		title = "Automatic Rewards",
		subtext = subtext,
		icon = "checkmark",
		duration = 3,
	})
end

function AutoRewards._scanStars(self: AutoRewards, data: any): ()
	if not self._stars or type(data) ~= "table" then
		return
	end

	local streak = tonumber(data.CurrentStreak) or 0
	local total = #MissionStars
	if streak > total then
		streak = total
	end

	local sent = self._sentStars :: { [number]: boolean }
	local rewards = data.Rewards
	local claimed = 0
	for index = 1, streak do
		if sent[index] or isStarClaimed(rewards, index) then
			continue
		end

		sent[index] = true
		self:_send("ClaimStarReward", index, STAR_INTERVAL)
		claimed += 1
	end

	if claimed == 0 then
		return
	end

	local subtext = `Claiming {claimed} streak rewards`
	if claimed == 1 then
		subtext = "Claiming 1 streak reward"
	end

	NotifyController.Push({
		title = "Automatic Rewards",
		subtext = subtext,
		icon = "checkmark",
		duration = 3,
	})
end

function AutoRewards.Enable(self: AutoRewards): ()
	if self._enabled then
		return
	end

	local dataController = ModuleController.GetModule("DataController")
	if not dataController then
		return
	end

	self._enabled = true
	self._dataController = dataController
	self._nextSend = os.clock()

	setthreadidentity(2)
	self._missionKey = dataController.CreateListener(LocalPlayer, "Missions", function(list: any): ()
		task.spawn(function(): ()
			setthreadidentity(8)
			self:_scanMissions(list)
		end)
	end)
	self._starKey = dataController.CreateListener(LocalPlayer, "MissionStars", function(data: any): ()
		task.spawn(function(): ()
			setthreadidentity(8)
			self:_scanStars(data)
		end)
	end)
	setthreadidentity(8)
end

function AutoRewards.Disable(self: AutoRewards): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	local dataController = self._dataController
	if dataController then
		setthreadidentity(2)
		if self._missionKey then
			dataController.RemoveListener(LocalPlayer, "Missions", self._missionKey)
		end
		if self._starKey then
			dataController.RemoveListener(LocalPlayer, "MissionStars", self._starKey)
		end
		setthreadidentity(8)
	end

	self._dataController = nil
	self._missionKey = nil
	self._starKey = nil
	table.clear(self._sentMissions)
	table.clear(self._sentStars)
end

function AutoRewards.Destroy(self: AutoRewards): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoRewards =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_enabledLink: any,
			_dataController: any,
			_missionKey: string?,
			_starKey: string?,
			_nextSend: number,
			_sentMissions: { [string]: boolean },
			_sentStars: { [number]: boolean },
			_missions: boolean,
			_stars: boolean,
		},
		AutoRewards
	))
	& BaseFeature.BaseFeature

return AutoRewards
