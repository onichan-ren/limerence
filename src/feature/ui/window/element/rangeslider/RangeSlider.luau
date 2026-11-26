local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Element = require("@ui/window/element/Element")
local renderer = require("@ui/window/element/rangeslider/renderer")

local peek = Charm.peek
local sub = Charm.subscribe
local at = Charm.atom
local e = React.createElement

local RangeSlider = {}
RangeSlider.__index = RangeSlider

setmetatable(RangeSlider, { __index = Element })

local function trimTrailingZeros(text: string): string
	if not text:find("%.") then
		return text
	end
	text = text:gsub("0+$", "")
	text = text:gsub("%.$", "")
	return text
end

local function snapToStep(self: RangeSlider, value: number): number
	local step = self._step
	if step and step > 0 then
		return self._min + math.round((value - self._min) / step) * step
	end
	return value
end

local function formatNumber(self: RangeSlider, value: number): string
	local rounded = math.round(value * 1000) / 1000
	local formatted = trimTrailingZeros(string.format("%.3f", rounded))

	local prefix = self._prefix
	if prefix then
		formatted = prefix .. formatted
	end

	local suffix = self._suffix
	if suffix then
		formatted = formatted .. suffix
	end

	return formatted
end

local function getPair(self: RangeSlider): (number, number)
	local state = peek(self._state)
	if type(state) ~= "table" then
		return self._min, self._max
	end
	local low = state[1] or self._min
	local high = state[2] or self._max
	if high < low then
		low, high = high, low
	end
	return math.clamp(low, self._min, self._max), math.clamp(high, self._min, self._max)
end

local function alphaOf(self: RangeSlider, value: number): number
	local range = self._max - self._min
	if range == 0 then
		return 0
	end
	return math.clamp((value - self._min) / range, 0, 1)
end

local function formatValue(self: RangeSlider): string
	local low, high = getPair(self)
	return formatNumber(self, low) .. " - " .. formatNumber(self, high)
end

local function constructor(
	text: string,
	defaultLow: number,
	defaultHigh: number,
	min: number,
	max: number,
	step: number,
	prefix: string?,
	suffix: string?
): RangeSlider
	local self = Element.new(text) :: any

	setmetatable(self, RangeSlider)

	self._min = min
	self._max = max
	self._step = step
	self._prefix = prefix
	self._suffix = suffix
	self._formattedValue = at("")
	self._formattedLow = at("")
	self._formattedHigh = at("")

	sub(self._state, function()
		local low, high = getPair(self)
		self._active(low > self._min or high < self._max)
		self._formattedValue(formatValue(self))
		self._formattedLow(formatNumber(self, low))
		self._formattedHigh(formatNumber(self, high))
	end)

	local lo = math.clamp(math.min(defaultLow, defaultHigh), min, max)
	local hi = math.clamp(math.max(defaultLow, defaultHigh), min, max)
	self._state({ lo, hi })

	return self
end

function RangeSlider.SetValues(self: RangeSlider, low: number, high: number, snap: boolean?): ()
	low = math.clamp(low, self._min, self._max)
	high = math.clamp(high, self._min, self._max)
	if high < low then
		low, high = high, low
	end

	if snap and self._step and self._step > 0 then
		low = math.clamp(snapToStep(self, low), self._min, self._max)
		high = math.clamp(snapToStep(self, high), self._min, self._max)
		if high < low then
			low, high = high, low
		end
	end

	self._state({ low, high })
end

function RangeSlider.SetLow(self: RangeSlider, value: number, snap: boolean?): ()
	local _, high = getPair(self)
	if snap then
		value = snapToStep(self, value)
	end
	value = math.clamp(value, self._min, high)
	self._state({ value, high })
end

function RangeSlider.SetHigh(self: RangeSlider, value: number, snap: boolean?): ()
	local low = getPair(self)
	if snap then
		value = snapToStep(self, value)
	end
	value = math.clamp(value, low, self._max)
	self._state({ low, value })
end

function RangeSlider.SetLowFromAlpha(self: RangeSlider, alpha: number): ()
	local value = self._min + math.clamp(alpha, 0, 1) * (self._max - self._min)
	self:SetLow(value, true)
end

function RangeSlider.SetHighFromAlpha(self: RangeSlider, alpha: number): ()
	local value = self._min + math.clamp(alpha, 0, 1) * (self._max - self._min)
	self:SetHigh(value, true)
end

function RangeSlider.SetFromText(self: RangeSlider, text: string): boolean
	local nums: { number } = {}
	for token in string.gmatch(text, "-?%d*%.?%d+") do
		nums[#nums + 1] = tonumber(token) :: number
	end
	if #nums >= 2 then
		self:SetValues(nums[1], nums[2], false)
		return true
	end
	return false
end

function RangeSlider.SetLowFromText(self: RangeSlider, text: string): boolean
	local num = tonumber(string.match(text, "-?%d*%.?%d+"))
	if not num then
		return false
	end
	self:SetLow(num, false)
	return true
end

function RangeSlider.SetHighFromText(self: RangeSlider, text: string): boolean
	local num = tonumber(string.match(text, "-?%d*%.?%d+"))
	if not num then
		return false
	end
	self:SetHigh(num, false)
	return true
end

function RangeSlider.GetValues(self: RangeSlider): (number, number)
	return getPair(self)
end

function RangeSlider.GetAlphas(self: RangeSlider): (number, number)
	local low, high = getPair(self)
	return alphaOf(self, low), alphaOf(self, high)
end

function RangeSlider.GetRandomValue(self: RangeSlider): number
	local low, high = getPair(self)
	if high <= low then
		return low
	end
	return snapToStep(self, low + math.random() * (high - low))
end

function RangeSlider.RenderInternal(self: RangeSlider, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		Slider = self,
		TextRef = props and props.textRef,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type RangeSlider = typeof(setmetatable(
	{} :: {
		_min: number,
		_max: number,
		_step: number,
		_prefix: string?,
		_suffix: string?,
		_formattedValue: Charm.Atom<string>,
		_formattedLow: Charm.Atom<string>,
		_formattedHigh: Charm.Atom<string>,
	},
	RangeSlider
)) & Element.Element

return constructor
