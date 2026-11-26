local Players = cloneref(game:GetService("Players")) :: Players
local CoreGui = cloneref(game:GetService("CoreGui")) :: CoreGui
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local ModuleController = require("@game/overkill/module/ModuleController")
local NetworkController = require("@game/overkill/network/NetworkController")
local overkillInventoryState = require("@game/overkill/feature/inventory/overkillInventoryState")
local spoofEngine = require("@game/universal/feature/misc/spoofEngine")

local LocalPlayer = Players.LocalPlayer
local peek = Charm.peek

local function cleanName(value: any): string
	if type(value) ~= "string" then
		return ""
	end
	return string.match(value, "^%s*(.-)%s*$") or ""
end

local commaValue = LPH_NO_VIRTUALIZE(function(value: number): string
	local s = tostring(value)
	while true do
		local count
		s, count = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
		if count == 0 then
			break
		end
	end
	return s
end)

local KIND_KEY: { [string]: string } = {
	level = "level",
	streak = "winStreak",
	wins = "wins",
	kills = "kills",
	deaths = "deaths",
	duels = "duelsPlayed",
	crowns = "crowns",
}

local SPOOF_CURRENCIES: { [string]: string } = {
	crowns = "crowns",
}

local statKindFromTitle = LPH_NO_VIRTUALIZE(function(text: string): string?
	local t = string.lower(text)
	if string.find(t, "streak", 1, true) then
		return "streak"
	end
	if string.find(t, "rate", 1, true) or string.find(t, "kdr", 1, true) then
		return nil
	end
	if string.find(t, "kill", 1, true) then
		return "kills"
	end
	if string.find(t, "death", 1, true) then
		return "deaths"
	end
	if string.find(t, "duel", 1, true) then
		return "duels"
	end
	if string.find(t, "win", 1, true) then
		return "wins"
	end
	if string.find(t, "lvl", 1, true) or string.find(t, "level", 1, true) then
		return "level"
	end
	return nil
end)

local classifyGui = LPH_NO_VIRTUALIZE(function(inst: Instance): string?
	if not (inst:IsA("TextLabel") or inst:IsA("TextButton")) then
		return nil
	end
	local text = (inst :: any).Text
	local numeric = string.match(text, "^%s*[%d,]+%s*$") ~= nil

	if numeric and inst.Name == "Value" then
		local parent = inst.Parent
		local title = parent and parent:FindFirstChild("Title")
		if title and (title:IsA("TextLabel") or title:IsA("TextButton")) then
			local kind = statKindFromTitle((title :: any).Text)
			if kind then
				return kind
			end
		end
	end

	if string.match(text, "^%s*[Ll][Vv][Ll]%.?%s*[%d,]+%s*$") then
		return "level"
	end
	if not numeric then
		return nil
	end

	local node = inst.Parent
	local depth = 0
	while node and depth < 6 do
		local name = node.Name
		if string.find(name, "[Ss]treak") then
			return "streak"
		end
		if string.find(name, "[Ll]evel") then
			return "level"
		end
		node = node.Parent
		depth += 1
	end
	return nil
end)

local nameMatches = LPH_NO_VIRTUALIZE(function(text: string, name: string): boolean
	text = spoofEngine.stripInvisible(text)
	if text == name then
		return true
	end
	if #name == 0 or string.sub(text, 1, #name) ~= name then
		return false
	end
	return string.match(string.sub(text, #name + 1), "^[%w_]") == nil
end)

local SCAN_CLASSES = { "TextLabel", "TextButton" }

local containsLocalName = LPH_NO_VIRTUALIZE(function(root: Instance, localNames: { string }): boolean
	for c = 1, #SCAN_CLASSES do
		local descendants = root:QueryDescendants(SCAN_CLASSES[c])
		local limit = math.min(#descendants, 250)
		for i = 1, limit do
			local text = (descendants[i] :: any).Text
			for _, name in next, localNames do
				if nameMatches(text, name) then
					return true
				end
			end
		end
	end
	return false
end)

local IDENTITY_NAMES: { [string]: boolean } = {
	Username = true,
	DisplayName = true,
	PlayerName = true,
}

local identityLabelCache: { [Instance]: { Instance } } = setmetatable({}, { __mode = "k" }) :: any

local scanIdentityLabels = LPH_NO_VIRTUALIZE(function(node: Instance): { Instance }
	local found: { Instance } = {}
	for c = 1, #SCAN_CLASSES do
		local descendants = node:QueryDescendants(SCAN_CLASSES[c])
		local limit = math.min(#descendants, 250)
		for i = 1, limit do
			local d = descendants[i]
			if IDENTITY_NAMES[d.Name] then
				found[#found + 1] = d
			end
		end
	end
	return found
end)

local scopeMatch = LPH_NO_VIRTUALIZE(function(node: Instance, localNames: { string }): string
	local labels = identityLabelCache[node]
	local valid = labels ~= nil and #labels > 0
	if valid then
		for i = 1, #labels do
			if not labels[i]:IsDescendantOf(node) then
				valid = false
				break
			end
		end
	end
	if not valid then
		labels = scanIdentityLabels(node)
		identityLabelCache[node] = labels
	end
	if #labels == 0 then
		return "none"
	end
	for i = 1, #labels do
		local text = (labels[i] :: any).Text
		for _, name in next, localNames do
			if nameMatches(text, name) then
				return "local"
			end
		end
	end
	return "foreign"
end)

local function isLocalScope(label: Instance, localNames: { string }): boolean
	local node = label.Parent
	local depth = 0
	while node and depth < 6 do
		local result = scopeMatch(node, localNames)
		if result == "local" then
			return true
		end
		if result == "foreign" then
			return false
		end
		if node:IsA("BillboardGui") then
			return false
		end
		node = node.Parent
		depth += 1
	end
	return false
end

local resolveCellKind = LPH_NO_VIRTUALIZE(function(leaderboard: Instance, statName: string): string?
	local topBar = leaderboard:FindFirstChild("TopBar")
	local header = topBar and topBar:FindFirstChild(statName)
	local value = header and header:FindFirstChild("Value")
	if not (value and (value:IsA("TextLabel") or value:IsA("TextButton"))) then
		return nil
	end
	return statKindFromTitle((value :: any).Text)
end)

local leaderboardCell = LPH_NO_VIRTUALIZE(function(inst: Instance): (Instance?, string?, Instance?)
	if not (inst:IsA("TextLabel") or inst:IsA("TextButton")) then
		return nil
	end
	if inst.Name ~= "Value" then
		return nil
	end
	if string.match((inst :: any).Text, "^%s*[%d,]+%s*$") == nil then
		return nil
	end
	local title = inst.Parent
	if not title or title.Name ~= "Title" then
		return nil
	end
	local statFrame = title.Parent
	if not statFrame or string.match(statFrame.Name, "^Stat_%d+$") == nil then
		return nil
	end
	local row = statFrame.Parent
	local scrolling = row and row.Parent
	local leaderboard = scrolling and scrolling.Parent
	if not leaderboard or leaderboard.Name ~= "Leaderboard" then
		return nil
	end
	return leaderboard, statFrame.Name, row
end)

local function getBounds(element: any): (number?, number?)
	if not element then
		return nil, nil
	end
	local low, high = element:GetValues()
	if type(low) == "number" and type(high) == "number" then
		return low, high
	end
	return nil, nil
end

local drift = LPH_NO_VIRTUALIZE(function(current: number?, low: number, high: number, advance: boolean): number
	if high <= low then
		return low
	end
	if current == nil or current < low or current > high then
		return low + math.random() * (high - low)
	end
	if not advance then
		return current
	end
	local range = high - low
	local maxStep = math.max(range * 0.12, 1)
	local center = (low + high) * 0.5
	local nextValue = current + (math.random() * 2 - 1) * maxStep + (center - current) * 0.05
	if nextValue < low then
		nextValue = low
	elseif nextValue > high then
		nextValue = high
	end
	return nextValue
end)

local PERF_ANCESTOR = "ServerInfo"

local function hasAncestorNamed(inst: Instance, name: string, depth: number): boolean
	local node = inst.Parent
	local d = 0
	while node and d < depth do
		if node.Name == name then
			return true
		end
		node = node.Parent
		d += 1
	end
	return false
end

local classifyPerf = LPH_NO_VIRTUALIZE(function(inst: Instance): string?
	if not (inst:IsA("TextLabel") or inst:IsA("TextButton")) then
		return nil
	end
	local name = inst.Name
	if name ~= "FPS" and name ~= "Latency" then
		return nil
	end
	if not hasAncestorNamed(inst, PERF_ANCESTOR, 6) then
		return nil
	end
	return name == "FPS" and "fps" or "ping"
end)

local classifyCurrency = LPH_NO_VIRTUALIZE(function(inst: Instance): string?
	if not (inst:IsA("TextLabel") or inst:IsA("TextButton")) then
		return nil
	end
	if inst.Name ~= "Value" then
		return nil
	end
	local frame = inst.Parent
	if not frame then
		return nil
	end
	local kind = SPOOF_CURRENCIES[frame.Name]
	if not kind then
		return nil
	end
	if string.match((inst :: any).Text, "^%s*[%d,]+%s*$") == nil then
		return nil
	end
	if not hasAncestorNamed(inst, "Currency", 5) then
		return nil
	end
	return kind
end)

local function replaceNumber(text: string, valueStr: string): string
	return (string.gsub(text, "%d[%d%.,]*", valueStr, 1))
end

type StatEntry = {
	key: string,
	label: string,
	default: string,
	group: string,
	field: string,
	nested: boolean,
	container: string?,
}

local STATS: { StatEntry } = {
	{ key = "level", label = "Level", default = "100", group = "XP", field = "XP", nested = false },
	{ key = "xp", label = "XP", default = "0", group = "XP", field = "XP", nested = false },
	{
		key = "bpLevel",
		label = "Level",
		default = "50",
		group = "Battlepasses",
		field = "XP",
		nested = false,
	},
	{
		key = "winStreak",
		label = "Win Streak",
		default = "100",
		group = "WinStreak",
		field = "WinStreak",
		nested = false,
	},
	{
		key = "wins",
		label = "Wins",
		default = "1000",
		group = "Stats",
		field = "wins",
		nested = true,
		container = "Stats",
	},
	{
		key = "kills",
		label = "Kills",
		default = "5000",
		group = "Stats",
		field = "kills",
		nested = true,
		container = "Stats",
	},
	{
		key = "deaths",
		label = "Deaths",
		default = "100",
		group = "Stats",
		field = "deaths",
		nested = true,
		container = "Stats",
	},
	{
		key = "duelsPlayed",
		label = "Duels Played",
		default = "1000",
		group = "Stats",
		field = "duels_played",
		nested = true,
		container = "Stats",
	},
	{
		key = "crowns",
		label = "Crowns",
		default = "100000",
		group = "Currency",
		field = "crowns",
		nested = true,
		container = "Currency",
	},
}

local GROUPS = { "XP", "WinStreak", "Stats", "Currency", "Battlepasses" }

local STAT_TIP: { [string]: string } = {
	xp = "How far into your current level the progress bar is filled.",
	bpLevel = "The battle pass tier shown in the battle pass menu.",
}

local MP_NONE = "None"
local TITLE_NONE = "None"

local MP_SLOTS = {
	{ key = "primary", label = "Primary", slot = 1 },
	{ key = "secondary", label = "Secondary", slot = 2 },
	{ key = "melee", label = "Melee", slot = 3 },
	{ key = "grenade", label = "Grenade", slot = 4 },
}

local StatsSpoofer = {}
StatsSpoofer.__index = StatsSpoofer

setmetatable(StatsSpoofer, { __index = BaseFeature })

local function parseStat(value: any): number?
	local amount = tonumber(value)
	if not amount or amount < 0 then
		return nil
	end
	return math.floor(amount)
end

local function readStat(data: any, stat: StatEntry, bp: any): any
	if stat.group == "XP" then
		return data.XP
	elseif stat.group == "Battlepasses" then
		return bp and bp.XP
	elseif stat.nested then
		local container = data[stat.container]
		return container and container[stat.field]
	end
	return data[stat.field]
end

function StatsSpoofer.new(link: gameUi.Linker): StatsSpoofer
	local self = BaseFeature.new() :: any
	setmetatable(self, StatsSpoofer)

	link:Toggle("statsSpoofer", "Stats Spoofer", false):SetTip({
		title = "Stats Spoofer",
		body = "Replaces your level, streak, wins, and kills everywhere the game shows them.",
	})
	local statsSpooferLink = link:OnKey("statsSpoofer")
	statsSpooferLink:Submenu("opts", "Stats Spoofer")
	local optionsLink = statsSpooferLink:OnKey("opts")

	optionsLink:Options("performance", "Performance")
	local performanceLink = optionsLink:OnKey("performance")
	optionsLink:Options("battlePass", "Battle Pass")
	local battlePassLink = optionsLink:OnKey("battlePass")
	optionsLink:Options("profile", "Profile")
	local profileLink = optionsLink:OnKey("profile")
	optionsLink:Options("stats", "Stats")
	local statsLink = optionsLink:OnKey("stats")

	self._values = {} :: { [string]: number? }
	self._real = {} :: { [string]: any }
	self._signals = {} :: { [string]: any }
	self._dataHandler = nil :: any
	self._levelHelper = nil :: any
	self._writing = false
	self._bound = false
	self._retry = false
	self._rescanQueued = false
	self._scanToken = 0
	self._janitor = Janitor.new()
	self._link = link
	self._localNames = {} :: { string }
	self._guiLabels = setmetatable({}, { __mode = "k" }) :: any
	self._guiReal = setmetatable({}, { __mode = "k" }) :: any
	self._guiWrite = setmetatable({}, { __mode = "k" }) :: any
	self._guiResolvers = setmetatable({}, { __mode = "k" }) :: any
	self._guiScopeChecks = setmetatable({}, { __mode = "k" }) :: any
	self._guiForceVisible = setmetatable({}, { __mode = "k" }) :: any

	self._spoofFps = false
	self._spoofPing = false
	self._fpsCurrent = nil :: number?
	self._pingCurrent = nil :: number?
	self._perfLabels = {} :: { [TextLabel]: string }
	self._perfReal = setmetatable({}, { __mode = "k" }) :: any
	self._perfWrite = setmetatable({}, { __mode = "k" }) :: any

	self._titleCatalog = nil :: any
	self._titleElement = nil :: any
	self._titleSelection = TITLE_NONE
	self._titleNameMap = {} :: { [string]: string }
	self._titleOwned = {} :: { [string]: boolean }
	self._titleEquipReal = nil :: any
	self._titleApplied = nil :: string?
	self._titleHooked = false

	self._constantsModule = nil :: any
	self._premiumUpgradeModule = nil :: any
	self._bpOwned = false
	self._claimHooked = false
	self._bpLabel = nil :: TextLabel?
	self._bpLabelInner = nil :: TextLabel?
	self._bpFakeFree = {} :: { number }
	self._bpFakePremium = {} :: { number }

	self._itemsModule = nil :: any
	self._mpElements = {} :: { [number]: any }
	self._mpNameMap = {} :: { [number]: { [string]: any } }
	self._mpSelection = {} :: { [number]: string }
	self._mpApplied = {} :: { [number]: any }

	for _, stat in next, STATS do
		local isBattlepass = stat.group == "Battlepasses"
		local categoryLink = isBattlepass and battlePassLink or statsLink
		local categoryKey = isBattlepass and "battlePass" or "stats"
		categoryLink:Textbox(stat.key, stat.label, stat.default, stat.label, true):SetTip({
			title = stat.label,
			body = STAT_TIP[stat.key]
				or `The {string.lower(stat.label)} value that will replace your actual {string.lower(stat.label)}.`,
		})
		self._values[stat.key] = parseStat(stat.default)

		self:Track(link:Watch(`statsSpoofer.opts.{categoryKey}.{stat.key}`, function(value: string)
			self._values[stat.key] = parseStat(value)
			if not self._enabled then
				return
			end
			local data = self:_data()
			if data then
				self:_applyStat(stat, data)
				self:_refreshGroup(stat.group, data)
			end
			self:_refreshGui()
		end))
	end

	battlePassLink:Toggle("bpOwned", "Owned", false):SetTip({
		title = "Owned",
		body = "Shows the premium battle pass as owned.",
	})
	self._bpOwned = link:Peek("statsSpoofer.opts.battlePass.bpOwned") == true
	self:Track(link:Watch("statsSpoofer.opts.battlePass.bpOwned", function(value: boolean): ()
		self._bpOwned = value == true
		if not self._enabled or not self._bound then
			return
		end
		local data = self:_data()
		if data then
			self:_applyBattlepass(data)
		end
	end))

	self._titleElement = profileLink:Dropdown("title", "Title", { TITLE_NONE }, TITLE_NONE)
	self._titleElement:SetTip({
		title = "Title",
		body = "The title shown under your name.",
	})
	self._titleSelection = link:Peek("statsSpoofer.opts.profile.title") or TITLE_NONE
	self:Track(link:Watch("statsSpoofer.opts.profile.title", function(value: string): ()
		self._titleSelection = value
		if not self._enabled then
			return
		end
		self:_applyTitleSelection()
	end))

	performanceLink:Toggle("spoofFps", "Spoof FPS", false):SetTip({
		title = "Spoof FPS",
		body = "Replace the displayed framerate with a value drifting between the slider bounds.",
	})
	local fpsLink = performanceLink:OnKey("spoofFps")
	fpsLink:Submenu("opts", "FPS")
	fpsLink:OnKey("opts"):RangeSlider("fps", "FPS", 200, 240, 1, 1000, 1, nil, nil):SetTip({
		title = "FPS",
		body = "Set both values equal for a fixed framerate, or apart for a varied one.",
	})

	performanceLink:Toggle("spoofPing", "Spoof Ping", false):SetTip({
		title = "Spoof Ping",
		body = "Replace the displayed ping with a value drifting between the slider bounds.",
	})
	local pingLink = performanceLink:OnKey("spoofPing")
	pingLink:Submenu("opts", "Ping")
	pingLink:OnKey("opts"):RangeSlider("ping", "Ping", 12, 24, 0, 999, 1, nil, "ms"):SetTip({
		title = "Ping",
		body = "Set both values equal for a fixed ping, or apart for a varied one.",
	})

	self._spoofFps = link:Peek("statsSpoofer.opts.performance.spoofFps") == true
	self._spoofPing = link:Peek("statsSpoofer.opts.performance.spoofPing") == true
	self._fpsElement = link:Get("statsSpoofer.opts.performance.spoofFps.opts.fps")
	self._pingElement = link:Get("statsSpoofer.opts.performance.spoofPing.opts.ping")

	self:Track(link:Watch("statsSpoofer.opts.performance.spoofFps", function(value: boolean): ()
		self._spoofFps = value == true
		self:_applyPerfAll()
	end))
	self:Track(link:Watch("statsSpoofer.opts.performance.spoofPing", function(value: boolean): ()
		self._spoofPing = value == true
		self:_applyPerfAll()
	end))

	profileLink:Submenu("mostPlayed", "Most Played Weapons")
	local mostPlayedLink = profileLink:OnKey("mostPlayed")
	for _, slotInfo in next, MP_SLOTS do
		local slotNum = slotInfo.slot
		local element = mostPlayedLink:Dropdown(slotInfo.key, slotInfo.label, { MP_NONE }, MP_NONE)
		element:SetTip({
			title = slotInfo.label,
			body = `The weapon shown as your most played {string.lower(slotInfo.label)} on your profile. Its icon uses your skin changer skin.`,
		})
		self._mpElements[slotNum] = element
		self._mpSelection[slotNum] = link:Peek(`statsSpoofer.opts.profile.mostPlayed.{slotInfo.key}`) or MP_NONE
		self:Track(link:Watch(`statsSpoofer.opts.profile.mostPlayed.{slotInfo.key}`, function(value: string): ()
			self._mpSelection[slotNum] = value
			if not self._enabled then
				return
			end
			self:_applyMostPlayedSlot(slotNum)
		end))
	end

	self:Track(Charm.subscribe(overkillInventoryState.weaponInventory, function(): ()
		if not self._enabled then
			return
		end
		self:_applyMostPlayedAll()
	end))

	local onAccountChange = function(): ()
		if not self._enabled or self._rescanQueued then
			return
		end
		self._rescanQueued = true
		task.defer(function(): ()
			self._rescanQueued = false
			self:_rescan()
		end)
	end
	self:Track(link:Watch("accountSpoofer", onAccountChange))
	self:Track(link:Watch("accountSpoofer.opts.displayName", onAccountChange))
	self:Track(link:Watch("accountSpoofer.opts.username", onAccountChange))

	self:Track(link:Get("statsSpoofer"):OnChange(function(value: boolean)
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	task.spawn(function(): ()
		for _ = 1, 60 do
			if self:_titles() then
				self:_buildTitles()
				return
			end
			task.wait(1)
		end
	end)

	return self
end

function StatsSpoofer._resolve(self: StatsSpoofer): boolean
	if not self._dataHandler then
		self._dataHandler = ModuleController.GetModule("dataHandler")
	end
	if not self._levelHelper then
		self._levelHelper = ModuleController.GetModule("levelHelper")
	end
	return self._dataHandler ~= nil and self._levelHelper ~= nil
end

function StatsSpoofer._data(self: StatsSpoofer): any
	local handler = self._dataHandler
	if not handler then
		return nil
	end
	local store = handler.Data
	return store and store[LocalPlayer]
end

function StatsSpoofer._items(self: StatsSpoofer): any
	if not self._itemsModule then
		self._itemsModule = ModuleController.GetModule("items")
	end
	return self._itemsModule
end

function StatsSpoofer._resolveSkin(self: StatsSpoofer, weaponId: string, entry: any): string?
	local items = self:_items()
	local all = items and items.all
	local def = all and all[weaponId]
	local skins = def and def.skins
	if type(skins) ~= "table" then
		return nil
	end

	local skin
	local inventory = peek(overkillInventoryState.weaponInventory)
	local override = inventory and inventory[weaponId]
	if override and type(override.skin) == "string" then
		skin = override.skin
	elseif entry and type(entry.skin) == "string" then
		skin = entry.skin
	end

	if type(skin) == "string" and skin ~= "random" and skins[skin] then
		return skin
	end
	return nil
end

function StatsSpoofer._changedSignal(self: StatsSpoofer, group: string): any
	local handler = self._dataHandler
	if not handler then
		return nil
	end
	local cached = self._signals[group]
	if cached then
		return cached
	end
	setthreadidentity(2)
	local signal = handler:GetDataChangedSignal(LocalPlayer, group)
	setthreadidentity(8)
	self._signals[group] = signal
	return signal
end

function StatsSpoofer._levelToXp(self: StatsSpoofer, level: number): number
	local helper = self._levelHelper
	if not helper then
		return 0
	end
	setthreadidentity(2)
	local xp = helper:GetXPByLevel(level)
	setthreadidentity(8)
	return xp or 0
end

function StatsSpoofer._xpToLevel(self: StatsSpoofer, xp: number): number
	local helper = self._levelHelper
	if not helper then
		return 0
	end
	setthreadidentity(2)
	local level = helper:GetLevelByXP(xp)
	setthreadidentity(8)
	return level or 0
end

function StatsSpoofer._constants(self: StatsSpoofer): any
	if not self._constantsModule then
		self._constantsModule = ModuleController.GetModule("constants")
	end
	return self._constantsModule
end

function StatsSpoofer._bp(self: StatsSpoofer, data: any): any
	local passes = data.Battlepasses
	if type(passes) ~= "table" then
		return nil
	end
	local constants = self:_constants()
	local active = constants and constants.ActiveBattlepass
	return active ~= nil and passes[active] or nil
end

function StatsSpoofer._bpXpPerLevel(self: StatsSpoofer): number?
	local constants = self:_constants()
	local perLevel = constants and tonumber(constants.BattlepassXPPerLevel)
	if perLevel and perLevel > 0 then
		return perLevel
	end
	return nil
end

function StatsSpoofer._bpLevelLabel(self: StatsSpoofer): TextLabel?
	local label = self._bpLabel
	if label and label.Parent then
		return label
	end
	self._bpLabel = nil
	self._bpLabelInner = nil
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local lobby = playerGui and playerGui:FindFirstChild("Lobby")
	local bpGui = lobby and lobby:FindFirstChild("Battlepass")
	local main = bpGui and bpGui:FindFirstChild("Main")
	local levelFrame = main and main:FindFirstChild("Level")
	local found = levelFrame and levelFrame:FindFirstChild("Level")
	if found and found:IsA("TextLabel") then
		self._bpLabel = found
		local inner = found:FindFirstChild("Level")
		if inner and inner:IsA("TextLabel") then
			self._bpLabelInner = inner
		end
		return found
	end
	return nil
end

function StatsSpoofer._writeBpLevelLabel(self: StatsSpoofer, xp: number): ()
	local perLevel = self:_bpXpPerLevel()
	if not perLevel then
		return
	end
	local label = self:_bpLevelLabel()
	if not label then
		return
	end
	local text = string.format("%02d", math.floor(xp / perLevel))
	if label.Text ~= text then
		label.Text = text
	end
	local inner = self._bpLabelInner
	if inner and inner.Text ~= text then
		inner.Text = text
	end
end

local function noop(): () end

function StatsSpoofer._fireBpDelta(self: StatsSpoofer, data: any, delta: any): ()
	local signal = self:_changedSignal("Battlepasses")
	if not signal then
		return
	end
	local constants = self:_constants()
	local active = constants and constants.ActiveBattlepass
	if active == nil then
		return
	end

	local premiumUpgrade
	local realPlay
	if delta.PremiumOwned ~= nil then
		if not self._premiumUpgradeModule then
			self._premiumUpgradeModule = ModuleController.GetModule("premiumUpgrade")
		end
		premiumUpgrade = self._premiumUpgradeModule
		if premiumUpgrade then
			realPlay = premiumUpgrade.Play
			premiumUpgrade.Play = noop
		end
	end

	self._writing = true
	setthreadidentity(2)
	signal:Fire(data.Battlepasses, { [active] = delta })
	setthreadidentity(8)
	self._writing = false

	if premiumUpgrade then
		premiumUpgrade.Play = realPlay
	end
end

function StatsSpoofer._applyBattlepass(self: StatsSpoofer, data: any): ()
	local bp = self:_bp(data)
	if not bp then
		return
	end

	local target
	local fakeLevel = self._values.bpLevel
	local perLevel = self:_bpXpPerLevel()
	if fakeLevel ~= nil and perLevel then
		target = fakeLevel * perLevel
	else
		target = self._real.bpLevel
	end
	if target ~= nil then
		if bp.XP ~= target then
			bp.XP = target
		end
		self:_writeBpLevelLabel(target)
	end

	local owned
	if self._bpOwned then
		owned = true
	else
		owned = self._real.bpOwned
	end
	if owned ~= nil and bp.PremiumOwned ~= owned then
		bp.PremiumOwned = owned
		if owned == true then
			self:_fireBpDelta(data, { PremiumOwned = true })
		end
	end
end

function StatsSpoofer._applyXp(self: StatsSpoofer, data: any): ()
	local fakeLevel = self._values.level
	local fakeProgress = self._values.xp
	local realXp = self._real.level

	if fakeLevel == nil and fakeProgress == nil then
		if realXp ~= nil and data.XP ~= realXp then
			data.XP = realXp
		end
		return
	end

	local level
	if fakeLevel ~= nil then
		level = fakeLevel
	else
		level = self:_xpToLevel(realXp or data.XP)
	end

	local base = self:_levelToXp(level)
	local target = base
	if fakeProgress ~= nil and fakeProgress > 0 then
		local req = self:_levelToXp(level + 1) - base
		local progress = fakeProgress
		if req > 0 and progress > req - 1 then
			progress = req - 1
		end
		target = base + progress
	end

	if data.XP ~= target then
		data.XP = target
	end
end

function StatsSpoofer._writeStat(self: StatsSpoofer, stat: StatEntry, data: any, target: any): ()
	if stat.group == "XP" then
		if data.XP == target then
			return
		end
		data.XP = target
	elseif stat.group == "Battlepasses" then
		local bp = self:_bp(data)
		if not bp or bp.XP == target then
			return
		end
		bp.XP = target
	elseif stat.nested then
		local container = data[stat.container]
		if not container or container[stat.field] == target then
			return
		end
		container[stat.field] = target
	else
		if data[stat.field] == target then
			return
		end
		data[stat.field] = target
	end
end

function StatsSpoofer._applyStat(self: StatsSpoofer, stat: StatEntry, data: any): ()
	if stat.group == "XP" then
		self:_applyXp(data)
		return
	end
	if stat.group == "Battlepasses" then
		self:_applyBattlepass(data)
		return
	end

	local fake = self._values[stat.key]
	local target
	if fake == nil then
		target = self._real[stat.key]
	else
		target = fake
	end

	if target == nil then
		return
	end
	self:_writeStat(stat, data, target)
end

function StatsSpoofer._refreshHud(self: StatsSpoofer, data: any): ()
	local signal = self:_changedSignal("XP")
	if not signal then
		return
	end
	self._writing = true
	setthreadidentity(2)
	signal:Fire(data.XP, data.XP)
	setthreadidentity(8)
	self._writing = false
end

function StatsSpoofer._refreshGroup(self: StatsSpoofer, group: string, data: any): ()
	if group == "XP" then
		self:_refreshHud(data)
	end
end

function StatsSpoofer._applyAll(self: StatsSpoofer): ()
	local data = self:_data()
	if not data then
		return
	end
	for _, stat in next, STATS do
		self:_applyStat(stat, data)
	end
	self:_refreshHud(data)
end

function StatsSpoofer._onServerUpdate(self: StatsSpoofer, group: string): ()
	local data = self:_data()
	if not data then
		return
	end
	local bp = group == "Battlepasses" and self:_bp(data) or nil
	if bp and not self._bpOwned then
		self._real.bpOwned = bp.PremiumOwned
	end
	for _, stat in next, STATS do
		if stat.group == group then
			self._real[stat.key] = readStat(data, stat, bp)
			self:_applyStat(stat, data)
		end
	end
	self:_refreshGroup(group, data)
end

function StatsSpoofer._bind(self: StatsSpoofer): ()
	local data = self:_data()
	if not data then
		return
	end

	local bp = self:_bp(data)
	if bp then
		self._real.bpOwned = bp.PremiumOwned
	end
	for _, stat in next, STATS do
		self._real[stat.key] = readStat(data, stat, bp)
	end

	for _, group in next, GROUPS do
		local signal = self:_changedSignal(group)
		if signal then
			self._janitor:Add(
				signal:Connect(function(): ()
					if self._writing then
						return
					end
					self:_onServerUpdate(group)
				end),
				"Disconnect"
			)
		end
	end

	self._bound = true
	self:_applyAll()
	self._titleEquipReal = data.EquippedTitle
	self:_buildTitles()
	self:_ownAllTitles()
	self:_installTitleHook()
	self:_installClaimHook()
	self:_applyTitleSelection()
	self:_buildMostPlayed()
	self:_applyMostPlayedAll()
end

function StatsSpoofer._startRetry(self: StatsSpoofer): ()
	if self._retry then
		return
	end
	self._retry = true
	task.spawn(function(): ()
		while self._enabled and not self._bound do
			if self:_resolve() and self:_data() then
				self:_bind()
				break
			end
			task.wait(1)
		end
		self._retry = false
	end)
end

function StatsSpoofer._applyGuiLabel(self: StatsSpoofer, label: TextLabel, kind: string): ()
	local scopeCheck = self._guiScopeChecks[label]
	if scopeCheck and not scopeCheck() then
		self._guiWrite[label] = nil
		return
	end
	local resolver = self._guiResolvers[label]
	if resolver then
		local resolved = resolver()
		if not resolved then
			return
		end
		kind = resolved
	end
	local key = KIND_KEY[kind]
	if not key then
		return
	end
	local value = self._values[key]
	if value == nil then
		return
	end

	if kind == "streak" then
		self:_forceStreakVisible(label)
	end

	local base = self._guiReal[label] or label.Text
	local valueStr = kind == "level" and tostring(value) or commaValue(value)
	local target = (string.gsub(base, "%d[%d,]*", valueStr, 1))
	if label.Text == target then
		self._guiWrite[label] = target ~= base and target or nil
		return
	end
	self._guiWrite[label] = target
	label.Text = target
end

function StatsSpoofer._forceStreakVisible(self: StatsSpoofer, label: TextLabel): ()
	local node = label.Parent
	local depth = 0
	while node and depth < 4 do
		if node:IsA("ImageLabel") and node.Name == "Streak" then
			local img = node :: ImageLabel
			if self._guiForceVisible[img] == nil then
				self._guiForceVisible[img] = img.Visible
				self._janitor:Add(
					img:GetPropertyChangedSignal("Visible"):Connect(function(): ()
						if img.Visible then
							return
						end
						local scopeCheck = self._guiScopeChecks[label]
						if scopeCheck and not scopeCheck() then
							return
						end
						img.Visible = true
					end),
					"Disconnect"
				)
			end
			if not img.Visible then
				img.Visible = true
			end
			return
		end
		node = node.Parent
		depth += 1
	end
end

function StatsSpoofer._titles(self: StatsSpoofer): any
	if not self._titleCatalog then
		self._titleCatalog = ModuleController.GetModule("titles")
	end
	return self._titleCatalog
end

function StatsSpoofer._buildTitles(self: StatsSpoofer): ()
	local catalog = self:_titles()
	if type(catalog) ~= "table" then
		return
	end

	local list: { { id: string, name: string, order: number } } = {}
	for id, def in next, catalog do
		if type(id) == "string" and type(def) == "table" and type(def.name) == "string" then
			list[#list + 1] = { id = id, name = def.name, order = tonumber(def.order) or 999 }
		end
	end
	table.sort(list, function(a, b): boolean
		return a.order < b.order
	end)

	local options = { TITLE_NONE }
	table.clear(self._titleNameMap)
	for _, entry in next, list do
		options[#options + 1] = entry.name
		self._titleNameMap[entry.name] = entry.id
	end

	if self._titleElement then
		self._titleElement:SetOptions(options)
	end
end

function StatsSpoofer._fireTitleData(self: StatsSpoofer, group: string, arg: any): ()
	local signal = self:_changedSignal(group)
	if not signal then
		return
	end
	setthreadidentity(2)
	signal:Fire(arg)
	setthreadidentity(8)
end

function StatsSpoofer._ownAllTitles(self: StatsSpoofer): ()
	local data = self:_data()
	local owned = data and data.Titles
	if type(owned) ~= "table" then
		return
	end
	local catalog = self:_titles()
	if type(catalog) ~= "table" then
		return
	end
	local changed = false
	for id in next, catalog do
		if owned[id] == nil then
			owned[id] = true
			self._titleOwned[id] = true
			changed = true
		end
	end
	if changed then
		self:_fireTitleData("Titles", nil)
	end
end

function StatsSpoofer._restoreTitles(self: StatsSpoofer): ()
	local data = self:_data()
	local owned = data and data.Titles
	if type(owned) == "table" then
		for id in next, self._titleOwned do
			owned[id] = nil
		end
		self:_fireTitleData("Titles", nil)
	end
	table.clear(self._titleOwned)

	if data and data.EquippedTitle ~= self._titleEquipReal then
		data.EquippedTitle = self._titleEquipReal
		self:_fireTitleData("EquippedTitle", self._titleEquipReal)
	end
	self._titleApplied = nil
end

function StatsSpoofer._equipTitle(self: StatsSpoofer, id: string?): ()
	local data = self:_data()
	if not data then
		return
	end
	local target = id ~= nil and id or self._titleEquipReal
	if data.EquippedTitle ~= target then
		data.EquippedTitle = target
	end
	self:_fireTitleData("EquippedTitle", target)
	self._titleApplied = id
end

function StatsSpoofer._applyTitleSelection(self: StatsSpoofer): ()
	local id = self._titleNameMap[self._titleSelection]
	self:_equipTitle(id)
end

function StatsSpoofer._installTitleHook(self: StatsSpoofer): ()
	if self._titleHooked then
		return
	end
	self._titleHooked = true
	NetworkController.HookPacket(
		"title_equip",
		LPH_NO_VIRTUALIZE(function(id: any): (boolean?, any?)
			if not self._enabled or type(id) ~= "string" then
				return true
			end
			if self._titleApplied == id then
				self._titleElement:SetSelected(TITLE_NONE)
			else
				local catalog = self:_titles()
				local def = catalog and catalog[id]
				if type(def) ~= "table" or type(def.name) ~= "string" then
					return true
				end
				self._titleElement:SetSelected(def.name)
			end
			return false
		end)
	)
end

function StatsSpoofer._installClaimHook(self: StatsSpoofer): ()
	if self._claimHooked then
		return
	end
	self._claimHooked = true
	NetworkController.HookPacket(
		"battlepass_claim_tier",
		LPH_NO_VIRTUALIZE(function(tier: any, premium: any): (boolean?, any?)
			if not self._enabled or not self._bound or type(tier) ~= "number" then
				return true
			end
			local data = self:_data()
			local bp = data and self:_bp(data)
			if not bp then
				return true
			end

			local premiumClaim = premium == true
			local overLevel = false
			local realXp = tonumber(self._real.bpLevel)
			local perLevel = self:_bpXpPerLevel()
			if realXp and perLevel then
				overLevel = tier > math.floor(realXp / perLevel)
			end
			local fakeOwned = premiumClaim and self._bpOwned and self._real.bpOwned ~= true

			if not overLevel and not fakeOwned then
				return true
			end

			local list = premiumClaim and bp.PremiumTiers or bp.FreeTiers
			if type(list) ~= "table" or table.find(list, tier) then
				return false
			end
			list[#list + 1] = tier
			local injected = premiumClaim and self._bpFakePremium or self._bpFakeFree
			injected[#injected + 1] = tier
			local delta
			if premiumClaim then
				delta = { PremiumTiers = { tier } }
			else
				delta = { FreeTiers = { tier } }
			end
			self:_fireBpDelta(data, delta)
			return false
		end)
	)
end

function StatsSpoofer._watchGuiLabel(self: StatsSpoofer, label: TextLabel, kind: string): ()
	self._guiLabels[label] = kind
	self._guiReal[label] = label.Text
	self._janitor:Add(
		label:GetPropertyChangedSignal("Text"):Connect(function(): ()
			if self._guiWrite[label] == label.Text then
				return
			end
			self._guiReal[label] = label.Text
			self:_applyGuiLabel(label, kind)
		end),
		"Disconnect"
	)
	self:_applyGuiLabel(label, kind)
end

function StatsSpoofer._bindGuiLabel(
	self: StatsSpoofer,
	label: TextLabel,
	kind: string,
	scopeCheck: (() -> boolean)?
): ()
	if self._guiLabels[label] then
		return
	end
	self._guiScopeChecks[label] = scopeCheck
	self:_watchGuiLabel(label, kind)
end

function StatsSpoofer._bindGuiCell(self: StatsSpoofer, label: TextLabel, leaderboard: Instance, statName: string): ()
	if self._guiLabels[label] then
		return
	end
	local resolver = function(): string?
		return resolveCellKind(leaderboard, statName)
	end
	local kind = resolver()
	if not kind then
		return
	end
	self._guiResolvers[label] = resolver
	self._guiScopeChecks[label] = function(): boolean
		local title = label.Parent
		local statFrame = title and title.Parent
		local row = statFrame and statFrame.Parent
		if not row then
			return false
		end
		return containsLocalName(row, self._localNames)
	end
	self:_watchGuiLabel(label, kind)
end

function StatsSpoofer._computePerf(self: StatsSpoofer, base: string, kind: string, advance: boolean): string
	if kind == "fps" and self._spoofFps then
		local low, high = getBounds(self._fpsElement)
		if low and high then
			self._fpsCurrent = drift(self._fpsCurrent, low, high, advance)
			return replaceNumber(base, tostring(math.floor(self._fpsCurrent + 0.5)))
		end
	elseif kind == "ping" and self._spoofPing then
		local low, high = getBounds(self._pingElement)
		if low and high then
			self._pingCurrent = drift(self._pingCurrent, low, high, advance)
			return replaceNumber(base, tostring(math.floor(self._pingCurrent + 0.5)))
		end
	end
	return base
end

function StatsSpoofer._applyPerfLabel(self: StatsSpoofer, label: TextLabel, kind: string, advance: boolean): ()
	local cur = label.Text
	local base = self._perfReal[label] or cur
	local nextText = self:_computePerf(base, kind, advance)
	if nextText == cur then
		self._perfWrite[label] = nextText ~= base and nextText or nil
		return
	end
	self._perfWrite[label] = nextText
	label.Text = nextText
end

function StatsSpoofer._applyPerfAll(self: StatsSpoofer): ()
	if not self._enabled then
		return
	end
	for label, kind in next, self._perfLabels do
		if label.Parent then
			self:_applyPerfLabel(label, kind, false)
		end
	end
end

function StatsSpoofer._bindPerfLabel(self: StatsSpoofer, label: TextLabel, kind: string): ()
	if self._perfLabels[label] then
		return
	end
	self._perfLabels[label] = kind
	self._perfReal[label] = label.Text
	self._janitor:Add(
		label:GetPropertyChangedSignal("Text"):Connect(function(): ()
			if self._perfWrite[label] == label.Text then
				return
			end
			self._perfReal[label] = label.Text
			self:_applyPerfLabel(label, kind, true)
		end),
		"Disconnect"
	)
	self:_applyPerfLabel(label, kind, false)
end

function StatsSpoofer._considerGui(self: StatsSpoofer, inst: Instance): ()
	local perfKind = classifyPerf(inst)
	if perfKind then
		self:_bindPerfLabel(inst :: TextLabel, perfKind)
		return
	end

	local currencyKind = classifyCurrency(inst)
	if currencyKind then
		self:_bindGuiLabel(inst :: TextLabel, currencyKind)
		return
	end

	local kind = classifyGui(inst)
	if kind then
		if not isLocalScope(inst, self._localNames) then
			return
		end
		self:_bindGuiLabel(inst :: TextLabel, kind, function(): boolean
			return isLocalScope(inst, self._localNames)
		end)
		return
	end

	local leaderboard, statName, row = leaderboardCell(inst)
	if leaderboard and row then
		if not containsLocalName(row, self._localNames) then
			return
		end
		self:_bindGuiCell(inst :: TextLabel, leaderboard, statName :: string)
		return
	end
end

function StatsSpoofer._connectGuiAdded(self: StatsSpoofer, container: Instance): ()
	self._janitor:Add(
		container.DescendantAdded:Connect(LPH_NO_VIRTUALIZE(function(descendant: Instance): ()
			self:_considerGui(descendant)
		end)),
		"Disconnect"
	)
end

function StatsSpoofer._scanChunked(self: StatsSpoofer): ()
	self._scanToken += 1
	local token = self._scanToken
	local containers = { CoreGui, Workspace }
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		containers[#containers + 1] = playerGui
	end
	spoofEngine.scanChunked(containers, SCAN_CLASSES, function(inst: Instance): ()
		self:_considerGui(inst)
	end, function(): boolean
		return self._enabled and self._scanToken == token
	end, nil, 60)
end

function StatsSpoofer._buildLocalNames(self: StatsSpoofer): { string }
	local name = LocalPlayer.Name
	local display = LocalPlayer.DisplayName
	local list = { name, "@" .. name, display, "@" .. display }

	local link = self._link
	if link and link:Peek("accountSpoofer") == true then
		local spoofedDisplay = cleanName(link:Peek("accountSpoofer.opts.displayName"))
		local spoofedName = cleanName(link:Peek("accountSpoofer.opts.username"))
		if spoofedDisplay ~= "" then
			list[#list + 1] = spoofedDisplay
		end
		if spoofedName ~= "" then
			list[#list + 1] = spoofedName
			list[#list + 1] = "@" .. spoofedName
		end
	end

	return list
end

function StatsSpoofer._startGuiPatch(self: StatsSpoofer): ()
	self._localNames = self:_buildLocalNames()

	self:_connectGuiAdded(CoreGui)
	self:_connectGuiAdded(Workspace)
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		self:_connectGuiAdded(playerGui)
	end
	self:_scanChunked()
end

function StatsSpoofer._rescan(self: StatsSpoofer): ()
	if not self._enabled then
		return
	end
	self._localNames = self:_buildLocalNames()
	self:_scanChunked()
end

function StatsSpoofer._buildMostPlayed(self: StatsSpoofer): ()
	local items = self:_items()
	local all = items and items.all
	if type(all) ~= "table" then
		return
	end

	local names: { { string } } = { {}, {}, {}, {} }
	local maps: { { [string]: any } } = { {}, {}, {}, {} }

	for weaponId, def in next, all do
		if type(weaponId) == "string" and type(def) == "table" then
			local slot = def.slot
			local nid = def.nID
			if type(slot) == "number" and slot >= 1 and slot <= 4 and nid ~= nil then
				local name = type(def.name) == "string" and def.name or weaponId
				if maps[slot][name] == nil then
					maps[slot][name] = { weaponId = weaponId, nid = nid }
					names[slot][#names[slot] + 1] = name
				end
			end
		end
	end

	for slot = 1, 4 do
		table.sort(names[slot])
		local options = { MP_NONE }
		for _, name in next, names[slot] do
			options[#options + 1] = name
		end
		self._mpNameMap[slot] = maps[slot]
		local element = self._mpElements[slot]
		if element then
			element:SetOptions(options)
		end
	end
end

function StatsSpoofer._restoreMostPlayedSlot(self: StatsSpoofer, slot: number, owned: any): ()
	local applied = self._mpApplied[slot]
	if not applied then
		return
	end
	self._mpApplied[slot] = nil
	if type(owned) ~= "table" then
		return
	end
	if applied.injected then
		owned[applied.nid] = nil
		return
	end
	local entry = owned[applied.nid]
	if type(entry) ~= "table" then
		return
	end
	entry.skin = applied.realSkin
	local stats = entry.stats
	if type(stats) == "table" then
		if applied.createdStats then
			entry.stats = nil
		else
			stats.playtime = applied.real
		end
	end
end

function StatsSpoofer._applyMostPlayedSlot(self: StatsSpoofer, slot: number): ()
	local data = self:_data()
	if not data then
		return
	end
	local owned = data.Items
	if type(owned) ~= "table" then
		return
	end

	self:_restoreMostPlayedSlot(slot, owned)

	local selection = self._mpSelection[slot]
	if not selection or selection == MP_NONE then
		return
	end
	local map = self._mpNameMap[slot]
	local target = map and map[selection]
	if not target then
		return
	end
	local nid = target.nid
	local weaponId = target.weaponId

	local maxReal = 0
	for _, info in next, map do
		local otherEntry = owned[info.nid]
		local otherStats = type(otherEntry) == "table" and otherEntry.stats
		local playtime = type(otherStats) == "table" and tonumber(otherStats.playtime) or 0
		if playtime > maxReal then
			maxReal = playtime
		end
	end

	local entry = owned[nid]
	local injected = false
	if type(entry) ~= "table" then
		entry = {}
		owned[nid] = entry
		injected = true
	end

	local realSkin = entry.skin
	local skin = self:_resolveSkin(weaponId, injected and nil or entry)

	local createdStats = false
	local stats = entry.stats
	if type(stats) ~= "table" then
		stats = {}
		entry.stats = stats
		createdStats = true
	end

	self._mpApplied[slot] = {
		nid = nid,
		injected = injected,
		real = tonumber(stats.playtime),
		realSkin = realSkin,
		createdStats = createdStats,
	}
	stats.playtime = maxReal + 1
	entry.skin = skin
end

function StatsSpoofer._applyMostPlayedAll(self: StatsSpoofer): ()
	for slot = 1, 4 do
		self:_applyMostPlayedSlot(slot)
	end
end

function StatsSpoofer._restoreMostPlayed(self: StatsSpoofer): ()
	local data = self:_data()
	local owned = data and data.Items
	for slot = 1, 4 do
		self:_restoreMostPlayedSlot(slot, owned)
	end
	table.clear(self._mpApplied)
end

function StatsSpoofer._refreshGui(self: StatsSpoofer): ()
	if not self._enabled then
		return
	end
	for label, kind in next, self._guiLabels do
		if label.Parent then
			self:_applyGuiLabel(label, kind)
		end
	end
end

function StatsSpoofer.Enable(self: StatsSpoofer): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._bound = false
	self._fpsCurrent = nil
	self._pingCurrent = nil

	self:_startGuiPatch()

	if self:_resolve() and self:_data() then
		self:_bind()
	else
		self:_startRetry()
	end
end

function StatsSpoofer.Disable(self: StatsSpoofer): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()

	if self._bound then
		local data = self:_data()
		if data then
			for _, stat in next, STATS do
				local real = self._real[stat.key]
				if real ~= nil then
					self:_writeStat(stat, data, real)
				end
			end
			local bp = self:_bp(data)
			if bp then
				if self._real.bpOwned ~= nil and bp.PremiumOwned ~= self._real.bpOwned then
					bp.PremiumOwned = self._real.bpOwned
				end
				local freeList = bp.FreeTiers
				if type(freeList) == "table" then
					for i = 1, #self._bpFakeFree do
						local at = table.find(freeList, self._bpFakeFree[i])
						if at then
							table.remove(freeList, at)
						end
					end
				end
				local premiumList = bp.PremiumTiers
				if type(premiumList) == "table" then
					for i = 1, #self._bpFakePremium do
						local at = table.find(premiumList, self._bpFakePremium[i])
						if at then
							table.remove(premiumList, at)
						end
					end
				end
			end
			table.clear(self._bpFakeFree)
			table.clear(self._bpFakePremium)
			local realBpXp = tonumber(self._real.bpLevel)
			if realBpXp then
				self:_writeBpLevelLabel(realBpXp)
			end
			self:_refreshHud(data)
		end
	end

	self:_restoreMostPlayed()

	NetworkController.UnhookPacket("title_equip")
	self._titleHooked = false
	NetworkController.UnhookPacket("battlepass_claim_tier")
	self._claimHooked = false
	if self._bound then
		self:_restoreTitles()
	end

	for label in next, self._guiLabels do
		local real = self._guiReal[label]
		local written = self._guiWrite[label]
		if type(real) == "string" and label.Parent and written and label.Text == written then
			label.Text = real
		end
	end

	for label in next, self._perfLabels do
		local real = self._perfReal[label]
		if type(real) == "string" and label.Parent and label.Text ~= real then
			self._perfWrite[label] = real
			label.Text = real
		end
	end

	for img, real in next, self._guiForceVisible do
		if type(real) == "boolean" and img.Parent and img.Visible ~= real then
			img.Visible = real
		end
	end

	self._bound = false
	table.clear(self._real)
	self._guiLabels = setmetatable({}, { __mode = "k" }) :: any
	self._guiReal = setmetatable({}, { __mode = "k" }) :: any
	self._guiWrite = setmetatable({}, { __mode = "k" }) :: any
	self._guiResolvers = setmetatable({}, { __mode = "k" }) :: any
	self._guiScopeChecks = setmetatable({}, { __mode = "k" }) :: any
	self._guiForceVisible = setmetatable({}, { __mode = "k" }) :: any
	self._perfLabels = {}
	self._perfReal = setmetatable({}, { __mode = "k" }) :: any
	self._perfWrite = setmetatable({}, { __mode = "k" }) :: any
end

function StatsSpoofer.Destroy(self: StatsSpoofer): ()
	self:Disable()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type StatsSpoofer =
	typeof(setmetatable(
		{} :: {
			_values: { [string]: number? },
			_real: { [string]: any },
			_signals: { [string]: any },
			_dataHandler: any,
			_levelHelper: any,
			_writing: boolean,
			_bound: boolean,
			_retry: boolean,
			_rescanQueued: boolean,
			_scanToken: number,
			_janitor: Janitor.Janitor,
			_link: any,
			_localNames: { string },
			_guiLabels: any,
			_guiReal: any,
			_guiWrite: any,
			_guiResolvers: any,
			_guiScopeChecks: any,
			_guiForceVisible: any,
			_spoofFps: boolean,
			_spoofPing: boolean,
			_fpsCurrent: number?,
			_pingCurrent: number?,
			_fpsElement: any,
			_pingElement: any,
			_perfLabels: { [TextLabel]: string },
			_perfReal: any,
			_perfWrite: any,
			_titleCatalog: any,
			_titleElement: any,
			_titleSelection: string,
			_titleNameMap: { [string]: string },
			_titleOwned: { [string]: boolean },
			_titleEquipReal: any,
			_titleApplied: string?,
			_titleHooked: boolean,
			_constantsModule: any,
			_premiumUpgradeModule: any,
			_bpOwned: boolean,
			_claimHooked: boolean,
			_bpLabel: TextLabel?,
			_bpLabelInner: TextLabel?,
			_bpFakeFree: { number },
			_bpFakePremium: { number },
			_itemsModule: any,
			_mpElements: { [number]: any },
			_mpNameMap: { [number]: { [string]: any } },
			_mpSelection: { [number]: string },
			_mpApplied: { [number]: any },
			_enabled: boolean,
			_resolve: (StatsSpoofer) -> boolean,
			_data: (StatsSpoofer) -> any,
			_items: (StatsSpoofer) -> any,
			_resolveSkin: (StatsSpoofer, string, any) -> string?,
			_changedSignal: (StatsSpoofer, string) -> any,
			_levelToXp: (StatsSpoofer, number) -> number,
			_xpToLevel: (StatsSpoofer, number) -> number,
			_constants: (StatsSpoofer) -> any,
			_bp: (StatsSpoofer, any) -> any,
			_bpXpPerLevel: (StatsSpoofer) -> number?,
			_bpLevelLabel: (StatsSpoofer) -> TextLabel?,
			_writeBpLevelLabel: (StatsSpoofer, number) -> (),
			_fireBpDelta: (StatsSpoofer, any, any) -> (),
			_applyBattlepass: (StatsSpoofer, any) -> (),
			_installClaimHook: (StatsSpoofer) -> (),
			_applyXp: (StatsSpoofer, any) -> (),
			_writeStat: (StatsSpoofer, StatEntry, any, any) -> (),
			_applyStat: (StatsSpoofer, StatEntry, any) -> (),
			_refreshHud: (StatsSpoofer, any) -> (),
			_refreshGroup: (StatsSpoofer, string, any) -> (),
			_applyAll: (StatsSpoofer) -> (),
			_onServerUpdate: (StatsSpoofer, string) -> (),
			_bind: (StatsSpoofer) -> (),
			_startRetry: (StatsSpoofer) -> (),
			_applyGuiLabel: (StatsSpoofer, TextLabel, string) -> (),
			_forceStreakVisible: (StatsSpoofer, TextLabel) -> (),
			_titles: (StatsSpoofer) -> any,
			_buildTitles: (StatsSpoofer) -> (),
			_fireTitleData: (StatsSpoofer, string, any) -> (),
			_ownAllTitles: (StatsSpoofer) -> (),
			_restoreTitles: (StatsSpoofer) -> (),
			_equipTitle: (StatsSpoofer, string?) -> (),
			_applyTitleSelection: (StatsSpoofer) -> (),
			_installTitleHook: (StatsSpoofer) -> (),
			_watchGuiLabel: (StatsSpoofer, TextLabel, string) -> (),
			_bindGuiLabel: (StatsSpoofer, TextLabel, string, (() -> boolean)?) -> (),
			_bindGuiCell: (StatsSpoofer, TextLabel, Instance, string) -> (),
			_computePerf: (StatsSpoofer, string, string, boolean) -> string,
			_applyPerfLabel: (StatsSpoofer, TextLabel, string, boolean) -> (),
			_applyPerfAll: (StatsSpoofer) -> (),
			_bindPerfLabel: (StatsSpoofer, TextLabel, string) -> (),
			_considerGui: (StatsSpoofer, Instance) -> (),
			_connectGuiAdded: (StatsSpoofer, Instance) -> (),
			_scanChunked: (StatsSpoofer) -> (),
			_buildLocalNames: (StatsSpoofer) -> { string },
			_startGuiPatch: (StatsSpoofer) -> (),
			_rescan: (StatsSpoofer) -> (),
			_refreshGui: (StatsSpoofer) -> (),
			_buildMostPlayed: (StatsSpoofer) -> (),
			_restoreMostPlayedSlot: (StatsSpoofer, number, any) -> (),
			_applyMostPlayedSlot: (StatsSpoofer, number) -> (),
			_applyMostPlayedAll: (StatsSpoofer) -> (),
			_restoreMostPlayed: (StatsSpoofer) -> (),
		},
		StatsSpoofer
	))
	& BaseFeature.BaseFeature

return StatsSpoofer
