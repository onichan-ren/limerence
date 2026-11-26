local Players = cloneref(game:GetService("Players")) :: Players
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local hook = require("@share/hook")
local ModuleController = require("@game/mvsd/module/ModuleController")

local LocalPlayer = Players.LocalPlayer

type StatEntry = {
	key: string,
	value: string,
	label: string,
	control: string,
	attribute: string,
	default: number,
	min: number,
	max: number,
	tip: string,
}

type ValueEntry = {
	key: string,
	value: string,
	label: string,
	control: string,
	default: number,
	min: number,
	max: number,
	tip: string,
}

type FlagEntry = {
	key: string,
	label: string,
	attributes: { string },
	tip: string,
}

local SEASON_LEVEL = "spoofSeasonLevel"
local SEASON_CURRENCY = "spoofSeasonCurrency"
local SEASON_PASS = "spoofSeasonPass"
local GEMS = "spoofGems"

local STATS: { [string]: StatEntry } = {
	[SEASON_LEVEL] = {
		key = SEASON_LEVEL,
		value = "level",
		label = "Season Pass Level",
		control = "Level",
		attribute = "SeasonLevel",
		default = 100,
		min = 0,
		max = 999,
		tip = "Replace your displayed season pass level and its reward track progress.",
	},
	spoofBestWinStreak = {
		key = "spoofBestWinStreak",
		value = "bestWinStreak",
		label = "Best Win Streak",
		control = "Best Win Streak",
		attribute = "BestWinStreak",
		default = 250,
		min = 0,
		max = 9999,
		tip = "Replace your displayed best win streak.",
	},
	spoofCareerKills = {
		key = "spoofCareerKills",
		value = "careerKills",
		label = "Career Kills",
		control = "Career Kills",
		attribute = "CareerKills",
		default = 5000,
		min = 0,
		max = 999999,
		tip = "Replace your displayed career kills.",
	},
	spoofWinStreak = {
		key = "spoofWinStreak",
		value = "winStreak",
		label = "Win Streak",
		control = "Win Streak",
		attribute = "WinStreak",
		default = 100,
		min = 0,
		max = 9999,
		tip = "Replace your displayed win streak.",
	},
	spoofWins = {
		key = "spoofWins",
		value = "wins",
		label = "Wins",
		control = "Wins",
		attribute = "Wins",
		default = 1000,
		min = 0,
		max = 99999,
		tip = "Replace your displayed win count.",
	},
}

local VALUES: { [string]: ValueEntry } = {
	[SEASON_CURRENCY] = {
		key = SEASON_CURRENCY,
		value = "currency",
		label = "Season Currency",
		control = "Season Currency",
		default = 50000,
		min = 0,
		max = 999999,
		tip = "Replace the season currency shown in the season pass menu.",
	},
	[GEMS] = {
		key = GEMS,
		value = "gems",
		label = "Gems",
		control = "Gems",
		default = 100000,
		min = 0,
		max = 9999999,
		tip = "Replace the gem balance shown across the interface.",
	},
}

local FLAGS: { [string]: FlagEntry } = {
	[SEASON_PASS] = {
		key = SEASON_PASS,
		label = "Premium Season Pass",
		attributes = { "DoesOwnBattlePass", "OwnsBattlePass" },
		tip = "Shows the premium season pass as owned and unlocks its reward track display.",
	},
	spoofVip = {
		key = "spoofVip",
		label = "VIP",
		attributes = { "IsVip" },
		tip = "Shows you as VIP everywhere the game displays it.",
	},
}

local TRACKS = { "FreeTrack", "BattlePassTrack" }
local PREMIUM_TRACK = "BattlePassTrack"

local StatsSpoofer = {}
StatsSpoofer.__index = StatsSpoofer

setmetatable(StatsSpoofer, { __index = BaseFeature })

function StatsSpoofer.new(link: gameUi.Linker): StatsSpoofer
	local self = BaseFeature.new() :: any
	setmetatable(self, StatsSpoofer)

	link:Toggle("statsSpoofer", "Stats Spoofer", false):SetTip({
		title = "Stats Spoofer",
		body = "Replaces your wins, streaks, and kills everywhere the game shows them.",
	})
	local statsSpooferLink = link:OnKey("statsSpoofer")
	statsSpooferLink:Submenu("opts", "Stats Spoofer")
	local optionsLink = statsSpooferLink:OnKey("opts")

	self._values = {} :: { [string]: number }
	self._toggles = {} :: { [string]: boolean }
	self._real = {} :: { [string]: any }
	self._writing = false
	self._janitor = Janitor.new()

	self._seasonService = nil :: any
	self._seasonProgress = nil :: any
	self._seasonReal = {} :: { [string]: any }
	self._seasonLevels = nil :: { number }?
	self._seasonClaimed = false
	self._seasonFakeClaims = { FreeTrack = {}, BattlePassTrack = {} } :: { [string]: { number } }
	self._seasonRemote = nil :: RemoteFunction?
	self._seasonHooked = false

	self._economy = nil :: any
	self._gemsOffset = 0
	self._gemsWriting = false

	local function numberBlock(entry: ValueEntry, onChange: () -> ()): gameUi.Linker
		local toggleLabel = `Spoof {entry.label}`
		optionsLink:Toggle(entry.key, toggleLabel, false):SetTip({
			title = toggleLabel,
			body = entry.tip,
		})

		local blockLink = optionsLink:OnKey(entry.key)
		blockLink:Submenu("opts", entry.label)
		local blockOptionsLink = blockLink:OnKey("opts")
		blockOptionsLink:Slider(entry.value, entry.control, entry.default, entry.min, entry.max, 1, nil, nil):SetTip({
			title = entry.control,
			body = `The {string.lower(entry.label)} value shown in place of your real one.`,
		})

		self._toggles[entry.key] = link:Peek(`statsSpoofer.opts.{entry.key}`) == true
		self._values[entry.key] = link:Peek(`statsSpoofer.opts.{entry.key}.opts.{entry.value}`) or entry.default

		self:Track(link:Watch(`statsSpoofer.opts.{entry.key}`, function(value: boolean)
			self._toggles[entry.key] = value == true
			if self._enabled then
				onChange()
			end
		end))
		self:Track(link:Watch(`statsSpoofer.opts.{entry.key}.opts.{entry.value}`, function(value: number)
			self._values[entry.key] = value
			if self._enabled and self._toggles[entry.key] then
				onChange()
			end
		end))

		return blockOptionsLink
	end

	local function statBlock(stat: StatEntry): gameUi.Linker
		return numberBlock(stat, function(): ()
			self:_applyStat(stat)
			if stat.key == SEASON_LEVEL then
				self:_applySeason()
			end
		end)
	end

	local function flagBlock(flag: FlagEntry): ()
		local toggleLabel = `Spoof {flag.label}`
		optionsLink:Toggle(flag.key, toggleLabel, false):SetTip({
			title = toggleLabel,
			body = flag.tip,
		})

		self._toggles[flag.key] = link:Peek(`statsSpoofer.opts.{flag.key}`) == true
		self:Track(link:Watch(`statsSpoofer.opts.{flag.key}`, function(value: boolean)
			self._toggles[flag.key] = value == true
			if not self._enabled then
				return
			end
			self:_applyFlag(flag)
			if flag.key == SEASON_PASS then
				self:_applySeason()
			end
		end))
	end

	flagBlock(FLAGS[SEASON_PASS])

	local seasonLevelLink = statBlock(STATS[SEASON_LEVEL])
	seasonLevelLink:Toggle("claimed", "Show Rewards As Claimed", false):SetTip({
		title = "Show Rewards As Claimed",
		body = "Marks every season pass reward as already claimed.",
	})
	self._seasonClaimed = link:Peek(`statsSpoofer.opts.{SEASON_LEVEL}.opts.claimed`) == true
	self:Track(link:Watch(`statsSpoofer.opts.{SEASON_LEVEL}.opts.claimed`, function(value: boolean)
		self._seasonClaimed = value == true
		if self._enabled then
			self:_applySeason()
		end
	end))

	statBlock(STATS.spoofBestWinStreak)

	numberBlock(VALUES[SEASON_CURRENCY], function(): ()
		self:_applySeason()
	end)

	statBlock(STATS.spoofCareerKills)
	statBlock(STATS.spoofWinStreak)

	numberBlock(VALUES[GEMS], function(): ()
		self:_applyGems()
	end)

	statBlock(STATS.spoofWins)
	flagBlock(FLAGS.spoofVip)

	local service = ModuleController.GetModule("LocalBattlePassService")
	if service then
		self._seasonService = service
		service.ListenForProgressMapReplication(function(progress: any): ()
			self._seasonProgress = progress
			self:_readSeason()
			if self._enabled then
				self:_applySeason()
			end
		end)
	end

	local economy = ModuleController.GetModule("EconomyService")
	if economy then
		self._economy = economy
		self._gemsOffset = 0
		if self._enabled then
			self:_watchGems()
			self:_applyGems()
		end
	end

	self:Track(link:Get("statsSpoofer"):OnChange(function(value: boolean)
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("statsSpoofer") then
		self:Enable()
	end

	return self
end

function StatsSpoofer._applyStat(self: StatsSpoofer, stat: StatEntry): ()
	local value = self._real[stat.attribute]
	if self._toggles[stat.key] then
		value = self._values[stat.key]
	end

	if LocalPlayer:GetAttribute(stat.attribute) == value then
		return
	end

	self._writing = true
	LocalPlayer:SetAttribute(stat.attribute, value)
	self._writing = false
end

function StatsSpoofer._applyFlag(self: StatsSpoofer, flag: FlagEntry): ()
	local enabled = self._toggles[flag.key]
	for i = 1, #flag.attributes do
		local attribute = flag.attributes[i]
		local value
		if enabled then
			value = true
		else
			value = self._real[attribute]
		end

		if LocalPlayer:GetAttribute(attribute) == value then
			continue
		end

		self._writing = true
		LocalPlayer:SetAttribute(attribute, value)
		self._writing = false
	end
end

function StatsSpoofer._levels(self: StatsSpoofer): { number }?
	local cached = self._seasonLevels
	if cached then
		return cached
	end

	local provider = ModuleController.GetModule("BattlePassProvider")
	if not provider then
		return nil
	end

	local levels = provider.GetLevels()
	if type(levels) ~= "table" or #levels == 0 then
		return nil
	end

	local thresholds = table.create(#levels)
	local total = 0
	for i = 1, #levels do
		total += levels[i].Xp
		thresholds[i] = total
	end

	self._seasonLevels = thresholds
	return thresholds
end

function StatsSpoofer._levelFromXp(self: StatsSpoofer, xp: any): number
	local thresholds = self:_levels()
	if not thresholds or type(xp) ~= "number" then
		return 0
	end

	local level = 0
	for i = 1, #thresholds do
		if xp < thresholds[i] then
			break
		end
		level = i
	end
	return level
end

function StatsSpoofer._readSeason(self: StatsSpoofer): ()
	local progress = self._seasonProgress
	if not progress then
		return
	end

	for i = 1, #TRACKS do
		table.clear(self._seasonFakeClaims[TRACKS[i]])
	end

	local real = self._seasonReal
	real.Xp = progress.Xp
	real.HighestRecordedLevel = progress.HighestRecordedLevel
	real.DoesOwnBattlePass = progress.DoesOwnBattlePass
	real.TotalSeasonCurrency = progress.TotalSeasonCurrency
end

function StatsSpoofer._fireSeason(self: StatsSpoofer, currency: any): ()
	local service = self._seasonService
	if not service then
		return
	end

	self._writing = true
	setthreadidentity(2)
	service.GetProgressMapChangedSignal():Fire(self._seasonProgress)
	if currency ~= nil then
		service.GetSeasonCurrencyChangedSignal():Fire(currency)
	end
	setthreadidentity(8)
	self._writing = false
end

function StatsSpoofer._markClaimed(self: StatsSpoofer, track: string, tier: number): ()
	local progress = self._seasonProgress
	local claimed = progress and progress.ClaimedLevelsMap[track]
	if type(claimed) ~= "table" or table.find(claimed, tier) then
		return
	end

	claimed[#claimed + 1] = tier
	local injected = self._seasonFakeClaims[track]
	injected[#injected + 1] = tier
end

function StatsSpoofer._applyClaims(self: StatsSpoofer): ()
	local progress = self._seasonProgress
	if not progress or type(progress.ClaimedLevelsMap) ~= "table" then
		return
	end

	if not self._seasonClaimed then
		self:_restoreClaims()
		return
	end

	local thresholds = self:_levels()
	if not thresholds then
		return
	end

	for i = 1, #TRACKS do
		local track = TRACKS[i]
		for tier = 1, #thresholds do
			self:_markClaimed(track, tier)
		end
	end
end

function StatsSpoofer._restoreClaims(self: StatsSpoofer): ()
	local progress = self._seasonProgress
	if not progress or type(progress.ClaimedLevelsMap) ~= "table" then
		return
	end

	for i = 1, #TRACKS do
		local track = TRACKS[i]
		local injected = self._seasonFakeClaims[track]
		local claimed = progress.ClaimedLevelsMap[track]
		if type(claimed) == "table" then
			for j = #injected, 1, -1 do
				local at = table.find(claimed, injected[j])
				if at then
					table.remove(claimed, at)
				end
			end
		end
		table.clear(injected)
	end
end

function StatsSpoofer._applySeason(self: StatsSpoofer): ()
	local progress = self._seasonProgress
	if not progress then
		return
	end

	local real = self._seasonReal
	local xp = real.Xp
	local highest = real.HighestRecordedLevel

	local thresholds = self:_levels()
	if self._toggles[SEASON_LEVEL] and thresholds then
		local index = math.clamp(self._values[SEASON_LEVEL], 1, #thresholds)
		xp = thresholds[index]
		highest = index
	end

	local owned = real.DoesOwnBattlePass
	if self._toggles[SEASON_PASS] then
		owned = true
	end

	local currency = real.TotalSeasonCurrency
	if self._toggles[SEASON_CURRENCY] then
		currency = self._values[SEASON_CURRENCY]
	end

	if xp ~= nil then
		progress.Xp = xp
	end
	if highest ~= nil then
		progress.HighestRecordedLevel = highest
	end
	if owned ~= nil then
		progress.DoesOwnBattlePass = owned
	end
	if currency ~= nil then
		progress.TotalSeasonCurrency = currency
	end

	self:_applyClaims()
	self:_fireSeason(currency)
end

function StatsSpoofer._restoreSeason(self: StatsSpoofer): ()
	local progress = self._seasonProgress
	if not progress then
		return
	end

	local real = self._seasonReal
	self:_restoreClaims()

	if real.Xp ~= nil then
		progress.Xp = real.Xp
	end
	if real.HighestRecordedLevel ~= nil then
		progress.HighestRecordedLevel = real.HighestRecordedLevel
	end
	if real.DoesOwnBattlePass ~= nil then
		progress.DoesOwnBattlePass = real.DoesOwnBattlePass
	end
	if real.TotalSeasonCurrency ~= nil then
		progress.TotalSeasonCurrency = real.TotalSeasonCurrency
	end

	self:_fireSeason(real.TotalSeasonCurrency)
end

function StatsSpoofer._claimRemote(self: StatsSpoofer): RemoteFunction?
	local cached = self._seasonRemote
	if cached then
		return cached
	end

	local folder = ReplicatedStorage:FindFirstChild("BattlePass")
	local remote = folder and folder:FindFirstChild("ClaimReward")
	if not remote or not remote:IsA("RemoteFunction") then
		return nil
	end

	self._seasonRemote = remote
	return remote
end

function StatsSpoofer._installClaimHook(self: StatsSpoofer): ()
	if self._seasonHooked then
		return
	end

	local remote = self:_claimRemote()
	if not remote then
		return
	end

	self._seasonHooked = true
	hook.addInstance(remote)
	hook.overrideMethod(
		remote,
		"InvokeServer",
		LPH_NO_VIRTUALIZE(function(track: any, tier: any): (...any)
			if not self._enabled or type(track) ~= "string" or type(tier) ~= "number" then
				return track, tier
			end

			local progress = self._seasonProgress
			if not progress then
				return track, tier
			end

			local real = self._seasonReal
			local overLevel = tier > self:_levelFromXp(real.Xp)
			local fakeOwned = track == PREMIUM_TRACK and real.DoesOwnBattlePass ~= true
			if not overLevel and not fakeOwned then
				return track, tier
			end

			self:_markClaimed(track, tier)
			self:_fireSeason(nil)
			return
		end)
	)
end

function StatsSpoofer._removeClaimHook(self: StatsSpoofer): ()
	if not self._seasonHooked then
		return
	end
	self._seasonHooked = false

	local remote = self._seasonRemote
	if remote then
		hook.restoreInstance(remote)
	end
end

function StatsSpoofer._applyGems(self: StatsSpoofer): ()
	local economy = self._economy
	if not economy then
		return
	end

	local current = economy.GetCredits()
	local target = current - self._gemsOffset
	if self._toggles[GEMS] then
		target = self._values[GEMS]
	end

	local delta = target - current
	if delta == 0 then
		return
	end

	self._gemsWriting = true
	setthreadidentity(2)
	economy.IncrementCredits(delta)
	setthreadidentity(8)
	self._gemsWriting = false
	self._gemsOffset += delta
end

function StatsSpoofer._watchGems(self: StatsSpoofer): ()
	local economy = self._economy
	if not economy then
		return
	end

	self._janitor:Add(
		economy.GetCreditsChangedSignal():Connect(function(): ()
			if self._gemsWriting then
				return
			end
			self:_applyGems()
		end),
		"Disconnect"
	)
end

function StatsSpoofer._restoreGems(self: StatsSpoofer): ()
	local economy = self._economy
	if not economy or self._gemsOffset == 0 then
		return
	end

	self._gemsWriting = true
	setthreadidentity(2)
	economy.IncrementCredits(-self._gemsOffset)
	setthreadidentity(8)
	self._gemsWriting = false
	self._gemsOffset = 0
end

function StatsSpoofer.Enable(self: StatsSpoofer): ()
	if self._enabled then
		return
	end
	self._enabled = true

	for _, stat in next, STATS do
		self._real[stat.attribute] = LocalPlayer:GetAttribute(stat.attribute)

		self._janitor:Add(
			LocalPlayer:GetAttributeChangedSignal(stat.attribute):Connect(function(): ()
				if self._writing then
					return
				end
				self._real[stat.attribute] = LocalPlayer:GetAttribute(stat.attribute)
				self:_applyStat(stat)
			end),
			"Disconnect"
		)

		self:_applyStat(stat)
	end

	for _, flag in next, FLAGS do
		for i = 1, #flag.attributes do
			local attribute = flag.attributes[i]
			self._real[attribute] = LocalPlayer:GetAttribute(attribute)

			self._janitor:Add(
				LocalPlayer:GetAttributeChangedSignal(attribute):Connect(function(): ()
					if self._writing then
						return
					end
					self._real[attribute] = LocalPlayer:GetAttribute(attribute)
					self:_applyFlag(flag)
				end),
				"Disconnect"
			)
		end

		self:_applyFlag(flag)
	end

	self:_installClaimHook()
	self:_applySeason()
	self:_watchGems()
	self:_applyGems()
end

function StatsSpoofer.Disable(self: StatsSpoofer): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()

	self:_removeClaimHook()
	self:_restoreSeason()
	self:_restoreGems()

	self._writing = true
	for _, stat in next, STATS do
		LocalPlayer:SetAttribute(stat.attribute, self._real[stat.attribute])
		self._real[stat.attribute] = nil
	end
	for _, flag in next, FLAGS do
		for i = 1, #flag.attributes do
			local attribute = flag.attributes[i]
			LocalPlayer:SetAttribute(attribute, self._real[attribute])
			self._real[attribute] = nil
		end
	end
	self._writing = false
end

function StatsSpoofer.Destroy(self: StatsSpoofer): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type StatsSpoofer =
	typeof(setmetatable(
		{} :: {
			_values: { [string]: number },
			_toggles: { [string]: boolean },
			_real: { [string]: any },
			_writing: boolean,
			_janitor: Janitor.Janitor,
			_seasonService: any,
			_seasonProgress: any,
			_seasonReal: { [string]: any },
			_seasonLevels: { number }?,
			_seasonClaimed: boolean,
			_seasonFakeClaims: { [string]: { number } },
			_seasonRemote: RemoteFunction?,
			_seasonHooked: boolean,
			_economy: any,
			_gemsOffset: number,
			_gemsWriting: boolean,
			_enabled: boolean,
			_applyStat: (StatsSpoofer, StatEntry) -> (),
			_applyFlag: (StatsSpoofer, FlagEntry) -> (),
			_levels: (StatsSpoofer) -> { number }?,
			_levelFromXp: (StatsSpoofer, any) -> number,
			_readSeason: (StatsSpoofer) -> (),
			_fireSeason: (StatsSpoofer, any) -> (),
			_markClaimed: (StatsSpoofer, string, number) -> (),
			_applyClaims: (StatsSpoofer) -> (),
			_restoreClaims: (StatsSpoofer) -> (),
			_applySeason: (StatsSpoofer) -> (),
			_restoreSeason: (StatsSpoofer) -> (),
			_claimRemote: (StatsSpoofer) -> RemoteFunction?,
			_installClaimHook: (StatsSpoofer) -> (),
			_removeClaimHook: (StatsSpoofer) -> (),
			_applyGems: (StatsSpoofer) -> (),
			_watchGems: (StatsSpoofer) -> (),
			_restoreGems: (StatsSpoofer) -> (),
		},
		StatsSpoofer
	))
	& BaseFeature.BaseFeature

return StatsSpoofer
