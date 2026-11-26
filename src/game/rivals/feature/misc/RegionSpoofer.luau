local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local playerDataAccess = require("@game/rivals/feature/inventory/playerDataAccess")
local cosmeticLibraryAccess = require("@game/rivals/feature/inventory/cosmeticLibraryAccess")
local rivalsInventoryState = require("@game/rivals/feature/inventory/rivalsInventoryState")
local ModuleController = require("@game/rivals/module/ModuleController")

local peek = Charm.peek
local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer

local WINSTREAK_KEY = "StatisticDuelsWinStreak"
local LEVEL_KEY = "Level"
local KEYS_DATA_NAME = "WeaponKeys"

local LEADERSTAT_FOLDER = "CustomLeaderstats"
local LEADERSTAT_WINSTREAK = "Win Streak"
local LEADERSTAT_LEVEL = "Level"

local NONE = "None"

local WEAPON_SLOTS: { { class: string, key: string, label: string } } = {
	{ class = "Primary", key = "StatisticFavoriteWeaponPrimary", label = "Primary" },
	{ class = "Secondary", key = "StatisticFavoriteWeaponSecondary", label = "Secondary" },
	{ class = "Melee", key = "StatisticFavoriteWeaponMelee", label = "Melee" },
	{ class = "Utility", key = "StatisticFavoriteWeaponUtility", label = "Utility" },
}

local CARD_TEXT_TARGETS: { { frame: string, child: string, kind: string } } = {
	{ frame = "Casual", child = "Wins", kind = "wins" },
	{ frame = "Casual", child = "WinPercent", kind = "winrate" },
	{ frame = "Ranked", child = "Wins", kind = "wins" },
	{ frame = "Ranked", child = "WinPercent", kind = "winrate" },
}

local function equippedSkin(name: string): string?
	local inv = peek(rivalsInventoryState.weaponInventory)
	local entry = type(inv) == "table" and inv[name]
	local skin = type(entry) == "table" and entry.skin
	return type(skin) == "string" and skin or nil
end

local function weaponImage(name: string): string
	local image = cosmeticLibraryAccess.getWeaponSkinImage(name, equippedSkin(name))
	if image then
		return image
	end
	local il = ModuleController.GetModule("ItemLibrary")
	local items = il and rawget(il, "Items")
	local it = type(items) == "table" and items[name]
	return (type(it) == "table" and type(it.Image) == "string") and it.Image or ""
end

local function weaponsByClass(): { [string]: { string } }
	local out: { [string]: { string } } = { Primary = {}, Secondary = {}, Melee = {}, Utility = {} }
	local il = ModuleController.GetModule("ItemLibrary")
	local items = il and rawget(il, "Items")
	if type(items) == "table" then
		for name, it in next, items do
			local class = type(it) == "table" and it.Class
			if type(class) == "string" and out[class] and name ~= "MISSING_WEAPON" then
				local list = out[class]
				list[#list + 1] = name
			end
		end
		for _, list in next, out do
			table.sort(list)
		end
	end
	return out
end

local StatsSpoofer = {}
StatsSpoofer.__index = StatsSpoofer

setmetatable(StatsSpoofer, { __index = BaseFeature })

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

local function cleanInput(value: any): string
	if type(value) ~= "string" then
		return ""
	end
	return string.match(value, "^%s*(.-)%s*$") or ""
end

local function currentSeason(): any?
	local sl = ModuleController.GetModule("SeasonLibrary")
	local season = sl and rawget(sl, "CurrentSeason")
	return type(season) == "table" and season or nil
end

local function getCurrencyUi(): any?
	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local modules = playerScripts and playerScripts:FindFirstChild("Modules")
	local userInterface = modules and modules:FindFirstChild("UserInterface")
	local lobby = userInterface and userInterface:FindFirstChild("Lobby")
	local currency = lobby and lobby:FindFirstChild("Currency")
	if not currency then
		return nil
	end
	setthreadidentity(2)
	local instance = require(currency)
	setthreadidentity(8)
	if type(instance) ~= "table" then
		return nil
	end
	return instance
end

function StatsSpoofer.new(link: gameUi.Linker): StatsSpoofer
	local self = BaseFeature.new() :: any
	setmetatable(self, StatsSpoofer)

	link:Toggle("statsSpoofer", "Stats Spoofer", false):SetTip({
		title = "Stats Spoofer",
		body = "Replaces the top-right stats with custom values.",
	})
	local spooferLink = link:OnKey("statsSpoofer")
	spooferLink:Submenu("opts", "Region Spoofer")
	local optsLink = spooferLink:OnKey("opts")

	optsLink:Toggle("spoofWeapons", "Spoof Most Played Weapons", false):SetTip({
		title = "Spoof Most Played Weapons",
		body = "Replace the most played weapon shown for each slot on your profile card.",
	})
	local weaponsLink = optsLink:OnKey("spoofWeapons")
	weaponsLink:Submenu("opts", "Most Played Weapons")
	local weaponsOptsLink = weaponsLink:OnKey("opts")
	local byClass = weaponsByClass()
	for _, slot in next, WEAPON_SLOTS do
		local options = { NONE }
		for _, name in next, (byClass[slot.class] or {}) do
			options[#options + 1] = name
		end
		weaponsOptsLink:Dropdown(slot.class, slot.label, options, NONE):SetTip({
			title = slot.label,
			body = `Weapon shown as your most played {string.lower(slot.label)}. "None" leaves the real value.`,
		})
	end

	optsLink:Toggle("spoofPrime", "Spoof Prime Season Pass", false):SetTip({
		title = "Spoof Prime Season Pass",
		body = "Shows the prime season pass as owned.",
	})

	optsLink:Toggle("spoofSeasonLevel", "Spoof Season Pass Level", false):SetTip({
		title = "Spoof Season Pass Level",
		body = "Replace your displayed season pass level.",
	})
	local seasonLevelLink = optsLink:OnKey("spoofSeasonLevel")
	seasonLevelLink:Submenu("opts", "Season Pass Level")
	local seasonLevelOptsLink = seasonLevelLink:OnKey("opts")
	seasonLevelOptsLink:Slider("level", "Level", 100, 0, 999, 1, nil, nil):SetTip({
		title = "Level",
		body = "Season pass level shown in place of your real one.",
	})
	seasonLevelOptsLink:Toggle("claimRewards", "Show Rewards As Claimed", false):SetTip({
		title = "Show Rewards As Claimed",
		body = "Marks every reward up to your shown level as already claimed.",
	})

	optsLink:Toggle("spoofUgc", "Spoof UGC Rewards", false):SetTip({
		title = "Spoof UGC Rewards",
		body = "Shows every UGC shop item as owned and all milestone rewards as reached.",
	})

	optsLink:Toggle("spoofWinstreak", "Spoof Winstreak", false):SetTip({
		title = "Spoof Winstreak",
		body = "Replace your displayed duel winstreak. Keeps your device icon in the dueler row.",
	})
	local winstreakLink = optsLink:OnKey("spoofWinstreak")
	winstreakLink:Submenu("opts", "Winstreak")
	winstreakLink:OnKey("opts"):Slider("winstreak", "Winstreak", 67, 0, 999, 1, nil, nil):SetTip({
		title = "Winstreak",
		body = "Winstreak value shown in place of your real one.",
	})

	optsLink:Toggle("spoofWinrate", "Spoof Win Rate", false):SetTip({
		title = "Spoof Win Rate",
		body = "Replace the win rate shown on your profile card.",
	})
	local winrateLink = optsLink:OnKey("spoofWinrate")
	winrateLink:Submenu("opts", "Win Rate")
	winrateLink:OnKey("opts"):Slider("winrate", "Win Rate", 100, 0, 100, 1, nil, "%"):SetTip({
		title = "Win Rate",
		body = "Win rate percentage shown in place of your real one.",
	})

	optsLink:Toggle("spoofRegion", "Spoof Region", false):SetTip({
		title = "Spoof Region",
		body = "Replace the displayed server region with custom text.",
	})
	local regionLink = optsLink:OnKey("spoofRegion")
	regionLink:Submenu("opts", "Region")
	regionLink:OnKey("opts"):Textbox("region", "Region", "limerence.biz", "United States"):SetTip({
		title = "Region",
		body = "Text shown in place of the real server region.",
	})

	optsLink:Toggle("spoofLevel", "Spoof Level", false):SetTip({
		title = "Spoof Level",
		body = "Replace your displayed account level.",
	})
	local levelLink = optsLink:OnKey("spoofLevel")
	levelLink:Submenu("opts", "Level")
	levelLink:OnKey("opts"):Slider("level", "Level", 67, 1, 999, 1, nil, nil):SetTip({
		title = "Level",
		body = "Account level shown in place of your real one.",
	})

	optsLink:Toggle("spoofPing", "Spoof Ping", false):SetTip({
		title = "Spoof Ping",
		body = "Replace the displayed ping with a value picked between the slider bounds, re-rolled each refresh.",
	})
	local pingLink = optsLink:OnKey("spoofPing")
	pingLink:Submenu("opts", "Ping")
	pingLink:OnKey("opts"):RangeSlider("ping", "Ping", 12, 24, 0, 999, 1, nil, "ms"):SetTip({
		title = "Ping",
		body = "Set both values equal for a fixed ping, or apart for a varied one.",
	})

	optsLink:Toggle("spoofWins", "Spoof Wins", false):SetTip({
		title = "Spoof Wins",
		body = "Replace the win count shown on your profile card.",
	})
	local winsLink = optsLink:OnKey("spoofWins")
	winsLink:Submenu("opts", "Wins")
	winsLink:OnKey("opts"):Slider("wins", "Wins", 67, 0, 99999, 1, nil, nil):SetTip({
		title = "Wins",
		body = "Win count shown in place of your real one.",
	})

	optsLink:Toggle("spoofKeys", "Spoof Keys", false):SetTip({
		title = "Spoof Keys",
		body = "Replace your displayed key balance.",
	})
	local keysLink = optsLink:OnKey("spoofKeys")
	keysLink:Submenu("opts", "Keys")
	keysLink:OnKey("opts"):Slider("keys", "Keys", 99999, 0, 999999, 1, nil, nil):SetTip({
		title = "Keys",
		body = "Key balance shown in place of your real one.",
	})

	optsLink:Toggle("spoofFps", "Spoof FPS", false):SetTip({
		title = "Spoof FPS",
		body = "Replace the displayed framerate with a value picked between the slider bounds, re-rolled each refresh.",
	})
	local fpsLink = optsLink:OnKey("spoofFps")
	fpsLink:Submenu("opts", "FPS")
	fpsLink:OnKey("opts"):RangeSlider("fps", "FPS", 200, 240, 1, 1000, 1, nil, nil):SetTip({
		title = "FPS",
		body = "Set both values equal for a fixed framerate, or apart for a varied one.",
	})

	self._janitor = Janitor.new()
	self._enabled = false
	self._spoofRegion = false
	self._spoofFps = false
	self._spoofPing = false
	self._regionText = ""
	self._fpsCurrent = nil
	self._pingCurrent = nil
	self._fpsElement = link:Get("statsSpoofer.opts.spoofFps.opts.fps")
	self._pingElement = link:Get("statsSpoofer.opts.spoofPing.opts.ping")
	self._labels = {} :: { [TextLabel]: string }
	self._lastWrite = setmetatable({}, { __mode = "k" }) :: any
	self._realText = setmetatable({}, { __mode = "k" }) :: any

	self._spoofWinstreak = false
	self._spoofLevel = false
	self._winstreak = 0
	self._level = 1
	self._spoofWins = false
	self._spoofWinrate = false
	self._wins = 0
	self._winrate = 100
	self._spoofKeys = false
	self._keys = 0
	self._spoofPrime = false
	self._spoofSeasonLevel = false
	self._seasonLevel = 0
	self._spoofClaimedRewards = false
	self._spoofUgc = false
	self._origGet = nil :: any
	self._dataController = nil :: any
	self._origDuelerAdded = nil :: any
	self._duelerModule = nil :: any
	self._statWriting = false
	self._origStat = {} :: { [string]: any }
	self._spoofWeapons = false
	self._weapons = {} :: { [string]: string }
	self._cardLabels = setmetatable({}, { __mode = "k" }) :: any
	self._cardFrames = setmetatable({}, { __mode = "k" }) :: any

	self:Track(link:Get("statsSpoofer"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(link:Watch("statsSpoofer.opts.spoofRegion", function(value: boolean): ()
		self._spoofRegion = value == true
		self:_applyAll()
	end))
	self:Track(link:Watch("statsSpoofer.opts.spoofRegion.opts.region", function(value: string): ()
		self._regionText = cleanInput(value)
		self:_applyAll()
	end))
	self:Track(link:Watch("statsSpoofer.opts.spoofFps", function(value: boolean): ()
		self._spoofFps = value == true
		self:_applyAll()
	end))
	self:Track(link:Watch("statsSpoofer.opts.spoofPing", function(value: boolean): ()
		self._spoofPing = value == true
		self:_applyAll()
	end))

	self:Track(link:Watch("statsSpoofer.opts.spoofWinstreak", function(value: boolean): ()
		self._spoofWinstreak = value == true
		self:_applyData()
		self:_refreshCards()
	end))
	self:Track(link:Watch("statsSpoofer.opts.spoofWinstreak.opts.winstreak", function(value: number): ()
		self._winstreak = type(value) == "number" and value or 0
		self:_applyData()
		self:_refreshCards()
	end))
	self:Track(link:Watch("statsSpoofer.opts.spoofLevel", function(value: boolean): ()
		self._spoofLevel = value == true
		self:_applyData()
		self:_refreshCards()
	end))
	self:Track(link:Watch("statsSpoofer.opts.spoofLevel.opts.level", function(value: number): ()
		self._level = type(value) == "number" and value or 1
		self:_applyData()
		self:_refreshCards()
	end))

	self:Track(link:Watch("statsSpoofer.opts.spoofWins", function(value: boolean): ()
		self._spoofWins = value == true
		self:_refreshCards()
	end))
	self:Track(link:Watch("statsSpoofer.opts.spoofWins.opts.wins", function(value: number): ()
		self._wins = type(value) == "number" and value or 0
		self:_refreshCards()
	end))
	self:Track(link:Watch("statsSpoofer.opts.spoofWinrate", function(value: boolean): ()
		self._spoofWinrate = value == true
		self:_refreshCards()
	end))
	self:Track(link:Watch("statsSpoofer.opts.spoofWinrate.opts.winrate", function(value: number): ()
		self._winrate = type(value) == "number" and value or 0
		self:_refreshCards()
	end))

	self:Track(link:Watch("statsSpoofer.opts.spoofKeys", function(value: boolean): ()
		self._spoofKeys = value == true
		self:_refreshCurrency()
	end))
	self:Track(link:Watch("statsSpoofer.opts.spoofKeys.opts.keys", function(value: number): ()
		self._keys = type(value) == "number" and value or 0
		self:_refreshCurrency()
	end))

	self:Track(link:Watch("statsSpoofer.opts.spoofPrime", function(value: boolean): ()
		self._spoofPrime = value == true
		self:_refreshSeasons()
	end))
	self:Track(link:Watch("statsSpoofer.opts.spoofSeasonLevel", function(value: boolean): ()
		self._spoofSeasonLevel = value == true
		self:_refreshSeasons()
	end))
	self:Track(link:Watch("statsSpoofer.opts.spoofSeasonLevel.opts.level", function(value: number): ()
		self._seasonLevel = type(value) == "number" and value or 0
		self:_refreshSeasons()
	end))
	self:Track(link:Watch("statsSpoofer.opts.spoofSeasonLevel.opts.claimRewards", function(value: boolean): ()
		self._spoofClaimedRewards = value == true
		self:_refreshSeasons()
	end))
	self:Track(link:Watch("statsSpoofer.opts.spoofUgc", function(value: boolean): ()
		self._spoofUgc = value == true
		self:_refreshUgc()
	end))

	self:Track(link:Watch("statsSpoofer.opts.spoofWeapons", function(value: boolean): ()
		self._spoofWeapons = value == true
		self:_refreshCards()
	end))
	for _, slot in next, WEAPON_SLOTS do
		self._weapons[slot.key] = nil
		self:Track(link:Watch(`statsSpoofer.opts.spoofWeapons.opts.{slot.class}`, function(value: string): ()
			self._weapons[slot.key] = (type(value) == "string" and value ~= NONE) and value or nil
			self:_refreshCards()
		end))
	end

	self._spoofRegion = link:Peek("statsSpoofer.opts.spoofRegion") == true
	self._spoofFps = link:Peek("statsSpoofer.opts.spoofFps") == true
	self._spoofPing = link:Peek("statsSpoofer.opts.spoofPing") == true
	self._regionText = cleanInput(link:Peek("statsSpoofer.opts.spoofRegion.opts.region"))
	self._spoofWinstreak = link:Peek("statsSpoofer.opts.spoofWinstreak") == true
	self._spoofLevel = link:Peek("statsSpoofer.opts.spoofLevel") == true
	local pw = link:Peek("statsSpoofer.opts.spoofWinstreak.opts.winstreak")
	self._winstreak = type(pw) == "number" and pw or 0
	local pl = link:Peek("statsSpoofer.opts.spoofLevel.opts.level")
	self._level = type(pl) == "number" and pl or 1
	self._spoofWins = link:Peek("statsSpoofer.opts.spoofWins") == true
	self._spoofWinrate = link:Peek("statsSpoofer.opts.spoofWinrate") == true
	local pwins = link:Peek("statsSpoofer.opts.spoofWins.opts.wins")
	self._wins = type(pwins) == "number" and pwins or 0
	local pwr = link:Peek("statsSpoofer.opts.spoofWinrate.opts.winrate")
	self._winrate = type(pwr) == "number" and pwr or 0
	self._spoofKeys = link:Peek("statsSpoofer.opts.spoofKeys") == true
	local pkeys = link:Peek("statsSpoofer.opts.spoofKeys.opts.keys")
	self._keys = type(pkeys) == "number" and pkeys or 0
	self._spoofPrime = link:Peek("statsSpoofer.opts.spoofPrime") == true
	self._spoofSeasonLevel = link:Peek("statsSpoofer.opts.spoofSeasonLevel") == true
	local psl = link:Peek("statsSpoofer.opts.spoofSeasonLevel.opts.level")
	self._seasonLevel = type(psl) == "number" and psl or 0
	self._spoofClaimedRewards = link:Peek("statsSpoofer.opts.spoofSeasonLevel.opts.claimRewards") == true
	self._spoofUgc = link:Peek("statsSpoofer.opts.spoofUgc") == true
	self._spoofWeapons = link:Peek("statsSpoofer.opts.spoofWeapons") == true
	for _, slot in next, WEAPON_SLOTS do
		local pv = link:Peek(`statsSpoofer.opts.spoofWeapons.opts.{slot.class}`)
		self._weapons[slot.key] = (type(pv) == "string" and pv ~= NONE) and pv or nil
	end

	return self
end

function StatsSpoofer._compute(self: StatsSpoofer, base: string, kind: string, advance: boolean): string
	if kind == "region" then
		if self._spoofRegion and self._regionText ~= "" then
			return self._regionText
		end
		return base
	end

	local out = base
	if self._spoofFps then
		local low, high = getBounds(self._fpsElement)
		if low and high then
			self._fpsCurrent = drift(self._fpsCurrent, low, high, advance)
			out = (string.gsub(out, "%d+fps", tostring(math.floor(self._fpsCurrent + 0.5)) .. "fps", 1))
		end
	end
	if self._spoofPing then
		local low, high = getBounds(self._pingElement)
		if low and high then
			self._pingCurrent = drift(self._pingCurrent, low, high, advance)
			out = (string.gsub(out, "%d+ms", tostring(math.floor(self._pingCurrent + 0.5)) .. "ms", 1))
		end
	end
	return out
end

function StatsSpoofer._applyLabel(self: StatsSpoofer, label: TextLabel, kind: string, advance: boolean): ()
	local cur = label.Text
	local base = self._realText[label] or cur
	local nextText = self:_compute(base, kind, advance)
	if nextText == cur then
		self._lastWrite[label] = nextText ~= base and nextText or nil
		return
	end
	self._lastWrite[label] = nextText
	label.Text = nextText
end

function StatsSpoofer._applyAll(self: StatsSpoofer): ()
	if not self._enabled then
		return
	end
	for label, kind in next, self._labels do
		if label.Parent then
			self:_applyLabel(label, kind, false)
		end
	end
end

function StatsSpoofer._bindLabel(self: StatsSpoofer, label: TextLabel, kind: string): ()
	if self._labels[label] then
		return
	end
	self._labels[label] = kind
	self._realText[label] = label.Text
	self._janitor:Add(
		label:GetPropertyChangedSignal("Text"):Connect(function(): ()
			if self._lastWrite[label] == label.Text then
				return
			end
			self._realText[label] = label.Text
			self:_applyLabel(label, kind, true)
		end),
		"Disconnect"
	)
	self:_applyLabel(label, kind, false)
end

StatsSpoofer._classify = LPH_NO_VIRTUALIZE(function(inst: Instance): string?
	if not inst:IsA("TextLabel") or inst.Name ~= "Title" then
		return nil
	end
	local parent = inst.Parent
	local parentName = parent and parent.Name
	if parentName == "ServerRegion" then
		return "region"
	elseif parentName == "Connection" then
		return "connection"
	end
	return nil
end)

function StatsSpoofer._scan(self: StatsSpoofer, container: Instance): ()
	for _, descendant in next, container:QueryDescendants("TextLabel") do
		local kind = self._classify(descendant)
		if kind then
			self:_bindLabel(descendant :: TextLabel, kind)
		end
	end
	self._janitor:Add(
		container.DescendantAdded:Connect(LPH_NO_VIRTUALIZE(function(descendant: Instance): ()
			local kind = self._classify(descendant)
			if kind then
				self:_bindLabel(descendant :: TextLabel, kind)
			end
		end)),
		"Disconnect"
	)
end

function StatsSpoofer._installDataHook(self: StatsSpoofer): ()
	if self._origGet then
		return
	end
	local controller = playerDataAccess.getController()
	if not controller or type(controller.Get) ~= "function" then
		return
	end
	local original = controller.Get
	self._dataController = controller
	self._origGet = original
	controller.Get = function(c: any, key: any, ...): any
		if self._enabled then
			if self._spoofWinstreak and key == WINSTREAK_KEY then
				return self._winstreak
			end
			if self._spoofLevel and key == LEVEL_KEY then
				return self._level
			end
			if self._spoofKeys and key == KEYS_DATA_NAME then
				return self._keys
			end
			if (self._spoofPrime or self._spoofSeasonLevel or self._spoofClaimedRewards) and key == "Seasons" then
				return self:_patchSeasons(original(c, key, ...))
			end
			if self._spoofUgc and key == "UGCPurchased" then
				return self:_allUgc(original(c, key, ...))
			end
			if self._spoofWeapons and type(key) == "string" then
				local weapon = self._weapons[key]
				if weapon ~= nil then
					return weapon
				end
			end
		end
		return original(c, key, ...)
	end
end

function StatsSpoofer._buildClaimed(_self: StatsSpoofer, season: any, bp: any): any
	local claimed = {}
	if type(bp.RewardsClaimed) == "table" then
		for tier, tracks in next, bp.RewardsClaimed do
			if type(tracks) == "table" then
				local row = {}
				for k, v in next, tracks do
					row[k] = v
				end
				claimed[tier] = row
			else
				claimed[tier] = tracks
			end
		end
	end
	local maxTier = tonumber(season.NumBattlePassTiers) or 0
	local maxTrack = tonumber(season.NumBattlePassTracks) or 0
	local level = math.min(tonumber(bp.PassLevel) or 0, maxTier)
	local trackCount = math.min(tonumber(bp.MaxPassTrackNum) or 0, maxTrack)
	for tier = 1, level do
		local key = tostring(tier)
		local row = claimed[key]
		if type(row) ~= "table" then
			row = {}
			claimed[key] = row
		end
		for track = 1, trackCount do
			row[tostring(track)] = true
		end
	end
	return claimed
end

function StatsSpoofer._patchSeasons(self: StatsSpoofer, seasons: any): any
	if type(seasons) ~= "table" then
		return seasons
	end
	local season = currentSeason()
	local name = season and season.Name
	if type(name) ~= "string" then
		return seasons
	end
	local entry = seasons[name]
	local newEntry = {}
	if type(entry) == "table" then
		for k, v in next, entry do
			newEntry[k] = v
		end
	end
	local bp = {}
	if type(newEntry.BattlePass) == "table" then
		for k, v in next, newEntry.BattlePass do
			bp[k] = v
		end
	end
	if self._spoofSeasonLevel then
		bp.PassLevel = self._seasonLevel
	end
	if self._spoofPrime and (type(bp.MaxPassTrackNum) ~= "number" or bp.MaxPassTrackNum < 2) then
		bp.MaxPassTrackNum = 2
	end
	if self._spoofClaimedRewards then
		bp.RewardsClaimed = self:_buildClaimed(season, bp)
	end
	newEntry.BattlePass = bp
	local newSeasons = {}
	for k, v in next, seasons do
		newSeasons[k] = v
	end
	newSeasons[name] = newEntry
	return newSeasons
end

function StatsSpoofer._removeDataHook(self: StatsSpoofer): ()
	if self._origGet and self._dataController then
		self._dataController.Get = self._origGet
	end
	self._origGet = nil
	self._dataController = nil
end

function StatsSpoofer._refreshCurrency(_self: StatsSpoofer): ()
	local ui = getCurrencyUi()
	if not ui or type(ui._UpdateSlots) ~= "function" then
		return
	end
	setthreadidentity(2)
	ui:_UpdateSlots()
	setthreadidentity(8)
end

function StatsSpoofer._refreshSeasons(self: StatsSpoofer): ()
	local controller = self._dataController or playerDataAccess.getController()
	if not controller then
		return
	end
	setthreadidentity(2)
	local signal = controller:GetDataChangedSignal("Seasons")
	if signal and type(signal.Fire) == "function" then
		signal:Fire(controller:Get("Seasons"), "Seasons")
	end
	setthreadidentity(8)
end

function StatsSpoofer._allUgc(_self: StatsSpoofer, real: any): any
	local ml = ModuleController.GetModule("MonetizationLibrary")
	local order = ml and rawget(ml, "UGCOrder")
	if type(order) ~= "table" then
		return real
	end
	local out = {}
	local seen = {}
	if type(real) == "table" then
		for _, name in next, real do
			if not seen[name] then
				seen[name] = true
				out[#out + 1] = name
			end
		end
	end
	for _, name in next, order do
		if not seen[name] then
			seen[name] = true
			out[#out + 1] = name
		end
	end
	return out
end

function StatsSpoofer._refreshUgc(self: StatsSpoofer): ()
	local controller = self._dataController or playerDataAccess.getController()
	if not controller then
		return
	end
	setthreadidentity(2)
	local signal = controller:GetDataChangedSignal("UGCPurchased")
	if signal and type(signal.Fire) == "function" then
		signal:Fire(controller:Get("UGCPurchased"), "UGCPurchased")
	end
	setthreadidentity(8)
end

function StatsSpoofer._getLeaderstatFolder(_self: StatsSpoofer): Instance?
	return LocalPlayer:FindFirstChild(LEADERSTAT_FOLDER)
end

function StatsSpoofer._applyOneStat(self: StatsSpoofer, name: string, spoof: boolean, value: number): ()
	local folder = self:_getLeaderstatFolder()
	local stat = folder and folder:FindFirstChild(name)
	if not (stat and stat:IsA("ValueBase")) then
		return
	end
	self._statWriting = true
	if spoof then
		if self._origStat[name] == nil then
			self._origStat[name] = (stat :: any).Value
		end
		(stat :: any).Value = value
	else
		local orig = self._origStat[name]
		if orig ~= nil then
			(stat :: any).Value = orig
		end
		self._origStat[name] = nil
	end
	self._statWriting = false
end

function StatsSpoofer._applyLeaderstats(self: StatsSpoofer): ()
	self:_applyOneStat(LEADERSTAT_WINSTREAK, self._spoofWinstreak, self._winstreak)
	self:_applyOneStat(LEADERSTAT_LEVEL, self._spoofLevel, self._level)
end

function StatsSpoofer._statSpoofState(self: StatsSpoofer, name: string): (boolean, number)
	if name == LEADERSTAT_WINSTREAK then
		return self._spoofWinstreak, self._winstreak
	end
	return self._spoofLevel, self._level
end

function StatsSpoofer._bindStat(self: StatsSpoofer, stat: Instance): ()
	if stat.Name ~= LEADERSTAT_WINSTREAK and stat.Name ~= LEADERSTAT_LEVEL then
		return
	end
	if not stat:IsA("ValueBase") then
		return
	end
	self._janitor:Add(
		stat:GetPropertyChangedSignal("Value"):Connect(function(): ()
			if self._statWriting then
				return
			end
			local spoof, value = self:_statSpoofState(stat.Name)
			if not spoof then
				return
			end
			self._origStat[stat.Name] = (stat :: any).Value
			self:_applyOneStat(stat.Name, true, value)
		end),
		"Disconnect"
	)
end

function StatsSpoofer._bindLeaderstats(self: StatsSpoofer): ()
	local function bindFolder(folder: Instance): ()
		for _, child in next, folder:GetChildren() do
			self:_bindStat(child)
		end
		self._janitor:Add(
			folder.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(child: Instance): ()
				self:_bindStat(child)
				self:_applyLeaderstats()
			end)),
			"Disconnect"
		)
	end
	local folder = self:_getLeaderstatFolder()
	if folder then
		bindFolder(folder)
	else
		self._janitor:Add(
			LocalPlayer.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(child: Instance): ()
				if child.Name == LEADERSTAT_FOLDER then
					bindFolder(child)
					self:_applyLeaderstats()
				end
			end)),
			"Disconnect"
		)
	end
end

function StatsSpoofer._applyLevelAttribute(self: StatsSpoofer, forceReal: boolean?): ()
	self._statWriting = true
	if self._spoofLevel and not forceReal then
		LocalPlayer:SetAttribute(LEVEL_KEY, self._level)
	else
		local real = playerDataAccess.get(LEVEL_KEY)
		if real ~= nil then
			LocalPlayer:SetAttribute(LEVEL_KEY, real)
		end
	end
	self._statWriting = false
end

function StatsSpoofer._applyWinstreakAttribute(self: StatsSpoofer, forceReal: boolean?): ()
	self._statWriting = true
	if self._spoofWinstreak and not forceReal then
		LocalPlayer:SetAttribute(WINSTREAK_KEY, self._winstreak)
	else
		local real = playerDataAccess.get(WINSTREAK_KEY)
		if real ~= nil then
			LocalPlayer:SetAttribute(WINSTREAK_KEY, real)
		end
	end
	self._statWriting = false
end

function StatsSpoofer._installDuelerGuard(self: StatsSpoofer): ()
	if self._origDuelerAdded then
		return
	end
	local module = ModuleController.GetModule("DuelDisplay")
	if type(module) ~= "table" then
		return
	end
	local original = rawget(module, "_DuelerAdded")
	if type(original) ~= "function" then
		return
	end
	local replacement = function(display: any, dueler: any, ...): ...any
		local result = table.pack(original(display, dueler, ...))
		if
			self._enabled
			and self._spoofWinstreak
			and type(dueler) == "table"
			and rawget(dueler, "Player") == LocalPlayer
		then
			local slots = rawget(display, "_dueler_slots")
			local slot = type(slots) == "table" and slots[dueler]
			if type(slot) == "table" then
				slot._win_streak = nil
				slot:_UpdateDetails()
			end
		end
		return table.unpack(result, 1, result.n)
	end
	module._DuelerAdded = replacement
	self._duelerModule = module
	self._origDuelerAdded = original
end

function StatsSpoofer._removeDuelerGuard(self: StatsSpoofer): ()
	if self._origDuelerAdded and self._duelerModule then
		self._duelerModule._DuelerAdded = self._origDuelerAdded
	end
	self._origDuelerAdded = nil
	self._duelerModule = nil
end

function StatsSpoofer._applyData(self: StatsSpoofer): ()
	if not self._enabled then
		return
	end
	self:_installDataHook()
	self:_installDuelerGuard()
	self:_applyLeaderstats()
	self:_applyLevelAttribute()
	self:_applyWinstreakAttribute()
	self:_refreshCurrency()
end

function StatsSpoofer._overwriteSlot(self: StatsSpoofer, slotFrame: Instance): ()
	if not self._spoofWeapons or not slotFrame:IsA("GuiObject") then
		return
	end
	local slot = WEAPON_SLOTS[(slotFrame :: GuiObject).LayoutOrder]
	if not slot then
		return
	end
	local weapon = self._weapons[slot.key]
	if not weapon then
		return
	end
	local button = slotFrame:FindFirstChild("Button")
	if not button then
		return
	end
	local title = button:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.Text = weapon
	end
	local icon = button:FindFirstChild("Icon")
	local picture = icon and icon:FindFirstChild("Picture")
	if picture and picture:IsA("ImageLabel") then
		picture.Image = weaponImage(weapon)
	end
end

function StatsSpoofer._cardTarget(self: StatsSpoofer, kind: string): string?
	if kind == "level" then
		return self._spoofLevel and tostring(self._level) or nil
	elseif kind == "wins" then
		return self._spoofWins and tostring(self._wins) or nil
	elseif kind == "winrate" then
		return self._spoofWinrate and tostring(self._winrate) .. "%" or nil
	end
	return nil
end

function StatsSpoofer._overwriteCardLabel(self: StatsSpoofer, label: TextLabel, kind: string): ()
	local target = self:_cardTarget(kind)
	if target == nil or label.Text == target then
		return
	end
	self._lastWrite[label] = target
	label.Text = target
end

function StatsSpoofer._bindCardLabel(self: StatsSpoofer, label: TextLabel, kind: string): ()
	if self._cardLabels[label] then
		return
	end
	self._cardLabels[label] = { real = label.Text, kind = kind }
	self._janitor:Add(
		label:GetPropertyChangedSignal("Text"):Connect(function(): ()
			if self._lastWrite[label] == label.Text then
				return
			end
			local entry = self._cardLabels[label]
			if entry then
				entry.real = label.Text
			end
			self:_overwriteCardLabel(label, kind)
		end),
		"Disconnect"
	)
	self:_overwriteCardLabel(label, kind)
end

function StatsSpoofer._bindCard(self: StatsSpoofer, mostPlayed: Instance): ()
	local player = mostPlayed.Parent
	if player then
		local bragging = player:FindFirstChild("Bragging")
		local levelFrame = bragging and bragging:FindFirstChild("Level")
		local value = levelFrame and levelFrame:FindFirstChild("Value")
		if value and value:IsA("TextLabel") then
			self:_bindCardLabel(value :: TextLabel, "level")
		end
		for _, target in next, CARD_TEXT_TARGETS do
			local frame = player:FindFirstChild(target.frame)
			local child = frame and frame:FindFirstChild(target.child)
			if child and child:IsA("TextLabel") then
				self:_bindCardLabel(child :: TextLabel, target.kind)
			end
		end
	end

	self._cardFrames[mostPlayed] = true
	for _, child in next, mostPlayed:GetChildren() do
		self:_overwriteSlot(child)
	end
	self._janitor:Add(
		mostPlayed.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(child: Instance): ()
			task.defer(function(): ()
				self:_overwriteSlot(child)
			end)
		end)),
		"Disconnect"
	)
end

function StatsSpoofer._refreshCards(self: StatsSpoofer): ()
	if not self._enabled then
		return
	end
	for label, entry in next, self._cardLabels do
		if label.Parent then
			self:_overwriteCardLabel(label, entry.kind)
		end
	end
	for frame in next, self._cardFrames do
		if frame.Parent then
			for _, child in next, frame:GetChildren() do
				self:_overwriteSlot(child)
			end
		end
	end
end

function StatsSpoofer._scanCards(self: StatsSpoofer, container: Instance): ()
	for _, d in next, container:QueryDescendants("#MostPlayedWeapons") do
		self:_bindCard(d)
	end
	self._janitor:Add(
		container.DescendantAdded:Connect(LPH_NO_VIRTUALIZE(function(d: Instance): ()
			if d.Name == "MostPlayedWeapons" then
				self:_bindCard(d)
			end
		end)),
		"Disconnect"
	)
end

function StatsSpoofer.Enable(self: StatsSpoofer): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._fpsCurrent = nil
	self._pingCurrent = nil

	self:_bindLeaderstats()
	self:_applyData()
	self:_refreshSeasons()
	self:_refreshUgc()
	self._janitor:Add(
		LocalPlayer:GetAttributeChangedSignal(LEVEL_KEY):Connect(function(): ()
			if self._statWriting or not self._spoofLevel then
				return
			end
			if LocalPlayer:GetAttribute(LEVEL_KEY) ~= self._level then
				self:_applyLevelAttribute()
			end
		end),
		"Disconnect"
	)
	self._janitor:Add(
		LocalPlayer:GetAttributeChangedSignal(WINSTREAK_KEY):Connect(function(): ()
			if self._statWriting or not self._spoofWinstreak then
				return
			end
			if LocalPlayer:GetAttribute(WINSTREAK_KEY) ~= self._winstreak then
				self:_applyWinstreakAttribute()
			end
		end),
		"Disconnect"
	)

	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		local insetGui = playerGui:FindFirstChild("InsetGui")
		if insetGui then
			self:_scan(insetGui)
		else
			self._janitor:Add(
				playerGui.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(child: Instance): ()
					if child.Name == "InsetGui" then
						self:_scan(child)
					end
				end)),
				"Disconnect"
			)
		end
		self:_scanCards(playerGui)
	end

	self._janitor:Add(sub(rivalsInventoryState.weaponInventory, function(): ()
		if self._spoofWeapons then
			self:_refreshCards()
		end
	end))
end

function StatsSpoofer.Disable(self: StatsSpoofer): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self:_removeDataHook()
	self:_removeDuelerGuard()
	self:_refreshSeasons()
	self:_refreshUgc()
	self:_refreshCurrency()
	self:_applyOneStat(LEADERSTAT_WINSTREAK, false, 0)
	self:_applyOneStat(LEADERSTAT_LEVEL, false, 0)
	self:_applyLevelAttribute(true)
	self:_applyWinstreakAttribute(true)

	for label in next, self._labels do
		local real = self._realText[label]
		if real and label.Parent and label.Text ~= real then
			self._lastWrite[label] = real
			label.Text = real
		end
	end
	for label, entry in next, self._cardLabels do
		local real = type(entry) == "table" and entry.real
		if type(real) == "string" and label.Parent and label.Text ~= real then
			label.Text = real
		end
	end
	self._labels = {}
	self._lastWrite = setmetatable({}, { __mode = "k" }) :: any
	self._realText = setmetatable({}, { __mode = "k" }) :: any
	self._cardLabels = setmetatable({}, { __mode = "k" }) :: any
	self._cardFrames = setmetatable({}, { __mode = "k" }) :: any
	self._origStat = {}
	self._janitor:Cleanup()
end

function StatsSpoofer.Destroy(self: StatsSpoofer): ()
	self:Disable()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type StatsSpoofer =
	typeof(setmetatable(
		{} :: {
			_janitor: Janitor.Janitor,
			_enabled: boolean,
			_spoofRegion: boolean,
			_spoofFps: boolean,
			_spoofPing: boolean,
			_regionText: string,
			_fpsCurrent: number?,
			_pingCurrent: number?,
			_fpsElement: any,
			_pingElement: any,
			_labels: { [TextLabel]: string },
			_lastWrite: any,
			_realText: any,
			_spoofWinstreak: boolean,
			_spoofLevel: boolean,
			_winstreak: number,
			_level: number,
			_spoofWins: boolean,
			_spoofWinrate: boolean,
			_wins: number,
			_winrate: number,
			_spoofKeys: boolean,
			_keys: number,
			_spoofPrime: boolean,
			_spoofSeasonLevel: boolean,
			_seasonLevel: number,
			_spoofClaimedRewards: boolean,
			_spoofUgc: boolean,
			_origGet: any,
			_dataController: any,
			_origDuelerAdded: any,
			_duelerModule: any,
			_statWriting: boolean,
			_origStat: { [string]: any },
			_spoofWeapons: boolean,
			_weapons: { [string]: string },
			_cardLabels: any,
			_cardFrames: any,
			_compute: (StatsSpoofer, string, string, boolean) -> string,
			_applyLabel: (StatsSpoofer, TextLabel, string, boolean) -> (),
			_applyAll: (StatsSpoofer) -> (),
			_bindLabel: (StatsSpoofer, TextLabel, string) -> (),
			_classify: (Instance) -> string?,
			_scan: (StatsSpoofer, Instance) -> (),
			_installDataHook: (StatsSpoofer) -> (),
			_buildClaimed: (StatsSpoofer, any, any) -> any,
			_patchSeasons: (StatsSpoofer, any) -> any,
			_removeDataHook: (StatsSpoofer) -> (),
			_refreshCurrency: (StatsSpoofer) -> (),
			_refreshSeasons: (StatsSpoofer) -> (),
			_allUgc: (StatsSpoofer, any) -> any,
			_refreshUgc: (StatsSpoofer) -> (),
			_getLeaderstatFolder: (StatsSpoofer) -> Instance?,
			_applyOneStat: (StatsSpoofer, string, boolean, number) -> (),
			_applyLeaderstats: (StatsSpoofer) -> (),
			_statSpoofState: (StatsSpoofer, string) -> (boolean, number),
			_bindStat: (StatsSpoofer, Instance) -> (),
			_bindLeaderstats: (StatsSpoofer) -> (),
			_applyLevelAttribute: (StatsSpoofer, boolean?) -> (),
			_applyWinstreakAttribute: (StatsSpoofer, boolean?) -> (),
			_installDuelerGuard: (StatsSpoofer) -> (),
			_removeDuelerGuard: (StatsSpoofer) -> (),
			_applyData: (StatsSpoofer) -> (),
			_overwriteSlot: (StatsSpoofer, Instance) -> (),
			_cardTarget: (StatsSpoofer, string) -> string?,
			_overwriteCardLabel: (StatsSpoofer, TextLabel, string) -> (),
			_bindCardLabel: (StatsSpoofer, TextLabel, string) -> (),
			_bindCard: (StatsSpoofer, Instance) -> (),
			_scanCards: (StatsSpoofer, Instance) -> (),
			_refreshCards: (StatsSpoofer) -> (),
		},
		StatsSpoofer
	))
	& BaseFeature.BaseFeature

return StatsSpoofer
