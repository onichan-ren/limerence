local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Element = require("@ui/window/element/Element")
local renderer = require("@ui/window/element/slider/renderer")

local peek = Charm.peek
local sub = Charm.subscribe
local at = Charm.atom
local e = React.createElement

local Slider = {}
Slider.__index = Slider

setmetatable(Slider, { __index = Element })

local function trimTrailingZeros(text: string): string
	if not text:find("%.") then
		return text
	end
	text = text:gsub("0+$", "")
	text = text:gsub("%.$", "")
	return text
end

local function snapToStep(slider: Slider, value: number): number
	local step = slider._step
	if step and step > 0 then
		return slider._min + math.round((value - slider._min) / step) * step
	end
	return value
end

local function formatValue(slider: Slider): string
	local value = peek(slider._state) or 0
	local overrides = slider._valueTextOverrides
	if overrides then
		local snapped = snapToStep(slider, value)
		local label = overrides[snapped]
		if label ~= nil and label ~= "" then
			return label
		end
	end

	local rounded = math.round(value * 1000) / 1000
	local formattedValue = trimTrailingZeros(string.format("%.3f", rounded))

	local prefix = slider._prefix
	if prefix then
		formattedValue = prefix .. formattedValue
	end

	local suffix = slider._suffix
	if suffix then
		formattedValue = formattedValue .. suffix
	end

	return formattedValue
end

local function constructor(
	text: string,
	default: number,
	min: number,
	max: number,
	step: number,
	prefix: string?,
	suffix: string?
): Slider
	local self = Element.new(text) :: any

	setmetatable(self, Slider)

	self._bindable(true)

	self._min = min
	self._max = max
	self._step = step
	self._prefix = prefix
	self._suffix = suffix
	self._valueTextOverrides = nil :: { [number]: string }?
	self._formattedValue = at("")

	sub(self._state, function(state: number)
		self._active(state > self._min)
		self._formattedValue(formatValue(self))
	end)

	self._state(math.clamp(default, min, max))

	return self
end

function Slider.SetValue(self: Slider, value: number, snapToStep: boolean?): ()
	local clamped = math.clamp(value, self._min, self._max)

	if snapToStep and self._step and self._step > 0 then
		local stepped = self._min + math.round((clamped - self._min) / self._step) * self._step
		clamped = math.clamp(stepped, self._min, self._max)
	end

	self._state(clamped)
end

function Slider.SetValueTextOverrides(self: Slider, overrides: { [number]: string }): Slider
	self._valueTextOverrides = overrides
	self._formattedValue(formatValue(self))
	return self
end

function Slider.SetFromAlpha(self: Slider, alpha: number): ()
	local value = self._min + math.clamp(alpha, 0, 1) * (self._max - self._min)
	self:SetValue(value, true)
end

function Slider.Nudge(self: Slider, direction: number): ()
	local current = peek(self._state) or self._min
	local range = self._max - self._min
	local step = self._step
	local delta = step and step > 0 and (math.max(step, range * 0.05)) or (range * 0.05)

	self:SetValue(current + delta * direction, true)
end

function Slider.SetFromText(self: Slider, text: string): boolean
	local num = tonumber(text)
	if not num then
		return false
	end

	self:SetValue(num, false)
	return true
end

function Slider.GetAlpha(self: Slider): number
	local range = self._max - self._min
	if range == 0 then
		return 0
	end
	local value = peek(self._state) or self._min
	return math.clamp((value - self._min) / range, 0, 1)
end

function Slider.RenderInternal(self: Slider, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		Slider = self,
		TextRef = props and props.textRef,
		LayoutOrder = props and props.layoutOrder,
		TextOffsetY = props and props.textOffsetY,
	})
end

function Slider.CreateTargetProxy(self: Slider, initial: number?): Slider
	local start: number = initial or peek(self._state) or self._min
	local proxy = constructor("", start, self._min, self._max, self._step, self._prefix, self._suffix)
	proxy._valueTextOverrides = self._valueTextOverrides
	proxy._formattedValue(formatValue(proxy))
	return proxy
end

export type Slider =
	typeof(setmetatable(
		{} :: {
			_min: number,
			_max: number,
			_step: number,
			_prefix: string?,
			_suffix: string?,
			_valueTextOverrides: { [number]: string }?,
			_formattedValue: Charm.Atom<string>,
		},
		Slider
	))
	& Element.Element

return constructor
