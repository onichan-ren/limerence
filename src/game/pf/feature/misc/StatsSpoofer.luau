local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local hook = require("@share/hook")
local ModuleController = require("@game/pf/module/ModuleController")

local LocalPlayer = Players.LocalPlayer

local CARD_NAME = "DisplayPlayerCard"

local function resolveBoardModules(self: any): boolean
	if not self._lbInterface then
		self._lbInterface = ModuleController.GetModule("LeaderboardInterface")
	end
	if not self._lbObject then
		self._lbObject = ModuleController.GetModule("LeaderboardObject")
	end
	return self._lbInterface ~= nil and self._lbObject ~= nil
end

local TARGETS: { { container: string, frame: string, kind: string } } = {
	{ container = "ContainerLeft", frame = "DisplayRank", kind = "rank" },
	{ container = "ContainerLeft", frame = "DisplayExperience", kind = "exp" },
	{ container = "ContainerRight", frame = "DisplayTotalExperience", kind = "totalexp" },
	{ container = "ContainerRight", frame = "DisplayRankReward", kind = "reward" },
	{ container = "ContainerRight", frame = "DisplayKills", kind = "kills" },
	{ container = "ContainerRight", frame = "DisplayDeaths", kind = "deaths" },
	{ container = "ContainerRight", frame = "DisplayKDR", kind = "kdr" },
}

local SLIDER_TARGET = UDim2.fromScale(0, 1)

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

local function twoDecimal(value: number): string
	return string.format("%0.2f", math.round(value * 100) / 100)
end

local function expCalculator(rank: number): number
	return math.floor(500 * ((rank + 0.5) ^ 2 - 0.25))
end

local function rankReward(rank: number): number
	return 5 * (41 + rank)
end

local StatsSpoofer = {}
StatsSpoofer.__index = StatsSpoofer

setmetatable(StatsSpoofer, { __index = BaseFeature })

function StatsSpoofer.new(link: gameUi.Linker): StatsSpoofer
	local self = BaseFeature.new() :: any
	setmetatable(self, StatsSpoofer)

	link:Toggle("statsSpoofer", "Stats Spoofer", false):SetTip({
		title = "Stats Spoofer",
		body = "Replaces the rank, experience, and kill stats on your profile card.",
	})
	local spooferLink = link:OnKey("statsSpoofer")
	spooferLink:Submenu("opts", "Stats Spoofer")
	local optsLink = spooferLink:OnKey("opts")

	optsLink:Slider("rank", "Rank", 100, 0, 255, 1, nil, nil):SetTip({
		title = "Rank",
		body = "Rank shown in place of your real one.",
	})
	optsLink:Slider("kills", "Kills", 50000, 0, 1000000, 1, nil, nil):SetTip({
		title = "Kills",
		body = "Total kill count shown on your profile.",
	})
	optsLink:Slider("deaths", "Deaths", 1000, 0, 1000000, 1, nil, nil):SetTip({
		title = "Deaths",
		body = "Total death count shown on your profile.",
	})

	self._janitor = Janitor.new()
	self._enabled = false
	self._labels = setmetatable({}, { __mode = "k" }) :: any
	self._lastWrite = setmetatable({}, { __mode = "k" }) :: any
	self._slider = nil :: GuiObject?
	self._sliderReal = nil :: UDim2?
	self._lastSizeWrite = nil :: UDim2?
	self._bound = false

	self._rank = link:Peek("statsSpoofer.opts.rank") or 0
	self._kills = link:Peek("statsSpoofer.opts.kills") or 0
	self._deaths = link:Peek("statsSpoofer.opts.deaths") or 0

	self._lbInterface = nil :: any
	self._lbObject = nil :: any
	self._boardHookTarget = nil :: any
	self._boardRetry = false

	self:Track(link:Get("statsSpoofer"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(link:Watch("statsSpoofer.opts.rank", function(value: number): ()
		self._rank = type(value) == "number" and value or 0
		self:_refresh()
	end))
	self:Track(link:Watch("statsSpoofer.opts.kills", function(value: number): ()
		self._kills = type(value) == "number" and value or 0
		self:_refresh()
	end))
	self:Track(link:Watch("statsSpoofer.opts.deaths", function(value: number): ()
		self._deaths = type(value) == "number" and value or 0
		self:_refresh()
	end))

	if link:Peek("statsSpoofer") then
		self:Enable()
	end

	return self
end

function StatsSpoofer._targetText(self: StatsSpoofer, kind: string): string
	local rank = self._rank
	local kills = self._kills
	local deaths = self._deaths

	if kind == "rank" then
		return commaValue(rank)
	elseif kind == "totalexp" then
		return commaValue(expCalculator(rank))
	elseif kind == "exp" then
		local span = expCalculator(rank + 1) - expCalculator(rank)
		return commaValue(0) .. " / " .. commaValue(span)
	elseif kind == "reward" then
		return "$" .. commaValue(rankReward(rank))
	elseif kind == "kills" then
		return commaValue(kills)
	elseif kind == "deaths" then
		return commaValue(deaths)
	elseif kind == "kdr" then
		local kdr = deaths == 0 and kills or twoDecimal(kills / deaths)
		return commaValue(kdr)
	end
	return ""
end

function StatsSpoofer._applyLabel(self: StatsSpoofer, label: TextLabel, kind: string): ()
	local target = self:_targetText(kind)
	if label.Text == target then
		return
	end
	self._lastWrite[label] = target
	label.Text = target
end

function StatsSpoofer._applySlider(self: StatsSpoofer): ()
	local slider = self._slider
	if not slider or slider.Size == SLIDER_TARGET then
		return
	end
	self._lastSizeWrite = SLIDER_TARGET
	slider.Size = SLIDER_TARGET
end

function StatsSpoofer._bindLabel(self: StatsSpoofer, label: TextLabel, kind: string): ()
	if self._labels[label] then
		return
	end
	self._labels[label] = { kind = kind, real = label.Text }
	self._janitor:Add(
		label:GetPropertyChangedSignal("Text"):Connect(function(): ()
			if self._lastWrite[label] == label.Text then
				return
			end
			local entry = self._labels[label]
			if entry then
				entry.real = label.Text
			end
			self:_applyLabel(label, kind)
		end),
		"Disconnect"
	)
	self:_applyLabel(label, kind)
end

function StatsSpoofer._bindSlider(self: StatsSpoofer, slider: GuiObject): ()
	if self._slider then
		return
	end
	self._slider = slider
	self._sliderReal = slider.Size
	self._janitor:Add(
		slider:GetPropertyChangedSignal("Size"):Connect(function(): ()
			if self._lastSizeWrite == slider.Size then
				return
			end
			self._sliderReal = slider.Size
			self:_applySlider()
		end),
		"Disconnect"
	)
	self:_applySlider()
end

function StatsSpoofer._bindCard(self: StatsSpoofer, card: Instance): ()
	if self._bound then
		return
	end
	self._bound = true

	for _, target in next, TARGETS do
		local container = card:FindFirstChild(target.container)
		local frame = container and container:FindFirstChild(target.frame)
		local label = frame and frame:FindFirstChild("TextRight")
		if label and label:IsA("TextLabel") then
			self:_bindLabel(label :: TextLabel, target.kind)
		end
		if target.kind == "exp" and frame then
			local sliderHolder = frame:FindFirstChild("DisplaySlider")
			local value = sliderHolder and sliderHolder:FindFirstChild("FrameValue")
			if value and value:IsA("GuiObject") then
				self:_bindSlider(value :: GuiObject)
			end
		end
	end
end

function StatsSpoofer._installBoardHook(self: StatsSpoofer): ()
	if self._boardHookTarget then
		return
	end
	local updateStats = rawget(self._lbObject, "updateStats")
	if type(updateStats) ~= "function" then
		return
	end
	local original
	original = hook.add(updateStats, LPH_NO_VIRTUALIZE(function(obj: any, ...): ...any
		if self._enabled and rawget(obj, "_player") == LocalPlayer then
			local override = rawget(obj, "_overrideStats")
			if type(override) == "table" then
				override.Rank = tostring(self._rank)
			end
		end
		return original(obj, ...)
	end))
	self._boardHookTarget = updateStats
end

function StatsSpoofer._applyBoard(self: StatsSpoofer): ()
	local interface = self._lbInterface
	if not interface then
		return
	end
	local entry = interface.getEntry(LocalPlayer)
	if not entry then
		return
	end
	local override = rawget(entry, "_overrideStats")
	if type(override) == "table" then
		override.Rank = tostring(self._rank)
	end
	local mapping = rawget(entry, "_textMapping")
	local rankLabel = type(mapping) == "table" and mapping.Rank
	if rankLabel then
		rankLabel.Text = tostring(self._rank)
	end
end

function StatsSpoofer._ensureBoard(self: StatsSpoofer): boolean
	if self._boardHookTarget then
		return true
	end
	if not resolveBoardModules(self) then
		return false
	end
	self:_installBoardHook()
	self:_applyBoard()
	return self._boardHookTarget ~= nil
end

function StatsSpoofer._startBoardRetry(self: StatsSpoofer): ()
	if self._boardRetry then
		return
	end
	self._boardRetry = true
	task.spawn(function(): ()
		while self._enabled and not self._boardHookTarget do
			if self:_ensureBoard() then
				break
			end
			task.wait(1)
		end
		self._boardRetry = false
	end)
end

function StatsSpoofer._removeBoardHook(self: StatsSpoofer): ()
	if self._boardHookTarget then
		hook.restore(self._boardHookTarget)
		self._boardHookTarget = nil
	end
	local interface = self._lbInterface
	if interface then
		local entry = interface.getEntry(LocalPlayer)
		if entry then
			local override = rawget(entry, "_overrideStats")
			if type(override) == "table" then
				override.Rank = nil
			end
		end
	end
end

function StatsSpoofer._refresh(self: StatsSpoofer): ()
	if not self._enabled then
		return
	end
	for label, entry in next, self._labels do
		if label.Parent then
			self:_applyLabel(label, entry.kind)
		end
	end
	self:_applySlider()
	self:_applyBoard()
end

function StatsSpoofer.Enable(self: StatsSpoofer): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self:_startBoardRetry()

	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local menu = playerGui and playerGui:FindFirstChild("MenuScreenGui")
	if not menu then
		return
	end

	local card = menu:FindFirstChild(CARD_NAME, true)
	if card then
		self:_bindCard(card)
	end

	self._janitor:Add(
		menu.DescendantAdded:Connect(LPH_NO_VIRTUALIZE(function(descendant: Instance): ()
			if descendant.Name == CARD_NAME and not self._bound then
				self:_bindCard(descendant)
			end
		end)),
		"Disconnect"
	)
end

function StatsSpoofer.Disable(self: StatsSpoofer): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self:_removeBoardHook()

	for label, entry in next, self._labels do
		local real = type(entry) == "table" and entry.real
		if type(real) == "string" and label.Parent and label.Text ~= real then
			self._lastWrite[label] = real
			label.Text = real
		end
	end

	local slider = self._slider
	local sliderReal = self._sliderReal
	if slider and sliderReal and slider.Parent and slider.Size ~= sliderReal then
		self._lastSizeWrite = sliderReal
		slider.Size = sliderReal
	end

	self._labels = setmetatable({}, { __mode = "k" }) :: any
	self._lastWrite = setmetatable({}, { __mode = "k" }) :: any
	self._slider = nil
	self._sliderReal = nil
	self._lastSizeWrite = nil
	self._bound = false
	self._janitor:Cleanup()
end

function StatsSpoofer.Destroy(self: StatsSpoofer): ()
	self:Disable()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type StatsSpoofer = typeof(setmetatable(
	{} :: {
		_janitor: Janitor.Janitor,
		_enabled: boolean,
		_labels: any,
		_lastWrite: any,
		_slider: GuiObject?,
		_sliderReal: UDim2?,
		_lastSizeWrite: UDim2?,
		_bound: boolean,
		_rank: number,
		_kills: number,
		_deaths: number,
		_lbInterface: any,
		_lbObject: any,
		_boardHookTarget: any,
		_boardRetry: boolean,
		_installBoardHook: (StatsSpoofer) -> (),
		_applyBoard: (StatsSpoofer) -> (),
		_ensureBoard: (StatsSpoofer) -> boolean,
		_startBoardRetry: (StatsSpoofer) -> (),
		_removeBoardHook: (StatsSpoofer) -> (),
		_targetText: (StatsSpoofer, string) -> string,
		_applyLabel: (StatsSpoofer, TextLabel, string) -> (),
		_applySlider: (StatsSpoofer) -> (),
		_bindLabel: (StatsSpoofer, TextLabel, string) -> (),
		_bindSlider: (StatsSpoofer, GuiObject) -> (),
		_bindCard: (StatsSpoofer, Instance) -> (),
		_refresh: (StatsSpoofer) -> (),
	},
	StatsSpoofer
)) & BaseFeature.BaseFeature

return StatsSpoofer
