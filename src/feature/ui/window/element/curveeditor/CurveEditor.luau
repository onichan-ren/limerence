local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Element = require("@ui/window/element/Element")
local renderer = require("@ui/window/element/curveeditor/renderer")

local peek = Charm.peek
local sub = Charm.subscribe
local at = Charm.atom
local e = React.createElement

local CurveEditor = {}
CurveEditor.__index = CurveEditor

setmetatable(CurveEditor, { __index = Element })

local LUT_SIZE = 256

export type Point = { x: number, y: number }

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function buildLut(points: { Point }): { number }
	local lut = table.create(LUT_SIZE)

	if #points == 0 then
		for i = 1, LUT_SIZE do
			lut[i] = 0
		end
		return lut
	end

	if #points == 1 then
		for i = 1, LUT_SIZE do
			lut[i] = points[1].y
		end
		return lut
	end

	for i = 0, LUT_SIZE - 1 do
		local x = i / (LUT_SIZE - 1)

		local segIdx = #points - 1
		for j = 1, #points - 1 do
			if x <= points[j + 1].x then
				segIdx = j
				break
			end
		end

		local p1 = points[segIdx]
		local p2 = points[segIdx + 1]
		local segLen = p2.x - p1.x
		local t = segLen > 0 and ((x - p1.x) / segLen) or (0)

		lut[i + 1] = math.clamp(lerp(p1.y, p2.y, t), 0, 1)
	end

	return lut
end

local function sortPoints(points: { Point }): { Point }
	local copy = table.clone(points)
	table.sort(copy, function(a, b)
		return a.x < b.x
	end)
	return copy
end

local function clampPoint(p: Point): Point
	return {
		x = math.clamp(p.x, 0, 1),
		y = math.clamp(p.y, 0, 1),
	}
end

local PRESETS: { [string]: { Point } } = {
	linear = {
		{ x = 0, y = 0 },
		{ x = 1, y = 1 },
	},
	easeIn = {
		{ x = 0, y = 0 },
		{ x = 0.7, y = 0.15 },
		{ x = 1, y = 1 },
	},
	easeOut = {
		{ x = 0, y = 0 },
		{ x = 0.3, y = 0.85 },
		{ x = 1, y = 1 },
	},
	sCurve = {
		{ x = 0, y = 0 },
		{ x = 0.3, y = 0.1 },
		{ x = 0.7, y = 0.9 },
		{ x = 1, y = 1 },
	},
}

local function clonePreset(name: string): { Point }
	local source = PRESETS[name] or PRESETS.linear
	local copy = table.create(#source)
	for i, p in source do
		copy[i] = { x = p.x, y = p.y }
	end
	return copy
end

local function constructor(text: string, min: number, max: number, default: { Point }?): CurveEditor
	local self = Element.new(text) :: any

	setmetatable(self, CurveEditor)

	self._bindable(true)

	self._min = min
	self._max = max
	self._xMin = 0
	self._xMax = 1
	self._xSuffix = ""
	self._ySuffix = ""
	self._height = 100
	self._lut = at({} :: { number })
	self._activeIdx = at(nil :: number?)

	sub(self._state, function(points: { Point }?)
		if points then
			self._lut(buildLut(points))
		end
	end)

	self._state(default or clonePreset("linear"))

	return self
end

function CurveEditor.SetXRange(self: CurveEditor, xMin: number, xMax: number, suffix: string?): CurveEditor
	self._xMin = xMin
	self._xMax = xMax
	self._xSuffix = suffix or ""
	return self
end

function CurveEditor.SetYSuffix(self: CurveEditor, suffix: string): CurveEditor
	self._ySuffix = suffix
	return self
end

function CurveEditor.SetHeight(self: CurveEditor, height: number): CurveEditor
	self._height = math.max(40, height)
	return self
end

function CurveEditor.SetPoints(self: CurveEditor, points: { Point }): ()
	local cleaned: { Point } = {}
	for _, p in points do
		table.insert(cleaned, clampPoint(p))
	end
	cleaned = sortPoints(cleaned)

	if #cleaned >= 2 then
		cleaned[1] = { x = 0, y = cleaned[1].y }
		cleaned[#cleaned] = { x = 1, y = cleaned[#cleaned].y }
	end

	self._state(cleaned)
end

function CurveEditor.AddPoint(self: CurveEditor, x: number, y: number): number?
	local current = peek(self._state)
	if not current then
		return nil
	end

	local clampedX = math.clamp(x, 0.001, 0.999)
	local clampedY = math.clamp(y, 0, 1)

	local newPoints = table.clone(current)
	table.insert(newPoints, { x = clampedX, y = clampedY })

	local sorted = sortPoints(newPoints)
	self._state(sorted)

	for i, p in sorted do
		if p.x == clampedX and p.y == clampedY then
			return i
		end
	end
	return nil
end

function CurveEditor.RemovePoint(self: CurveEditor, idx: number): ()
	local current = peek(self._state)
	if not current then
		return
	end
	if idx <= 1 or idx >= #current then
		return
	end

	local newPoints = table.clone(current)
	table.remove(newPoints, idx)
	self._state(newPoints)

	local activeIdx = peek(self._activeIdx)
	if activeIdx == idx then
		self._activeIdx(nil)
	elseif activeIdx and activeIdx > idx then
		self._activeIdx(activeIdx - 1)
	end
end

function CurveEditor.MovePoint(self: CurveEditor, idx: number, x: number, y: number): ()
	local current = peek(self._state)
	if not current then
		return
	end
	local point = current[idx]
	if not point then
		return
	end

	local newY = math.clamp(y, 0, 1)
	local newX
	if idx == 1 then
		newX = 0
	elseif idx == #current then
		newX = 1
	else
		local left = current[idx - 1].x + 0.001
		local right = current[idx + 1].x - 0.001
		newX = math.clamp(x, left, right)
	end

	local newPoints = table.clone(current)
	newPoints[idx] = { x = newX, y = newY }
	self._state(newPoints)
end

function CurveEditor.SetActivePoint(self: CurveEditor, idx: number?): ()
	self._activeIdx(idx)
end

function CurveEditor.Reset(self: CurveEditor, preset: string?): ()
	self:SetPoints(clonePreset(preset or "linear"))
	self._activeIdx(nil)
end

function CurveEditor.Sample(self: CurveEditor, x: number): number
	local lut = peek(self._lut)
	if #lut == 0 then
		return self._min
	end

	local xRange = self._xMax - self._xMin
	local normalizedX = xRange > 0 and (math.clamp((x - self._xMin) / xRange, 0, 1)) or (0)

	local idx = normalizedX * (LUT_SIZE - 1)
	local lo = math.floor(idx) + 1
	local hi = math.min(lo + 1, LUT_SIZE)
	local t = idx - math.floor(idx)

	local y = lerp(lut[lo], lut[hi], t)
	return self._min + y * (self._max - self._min)
end

function CurveEditor.SampleNormalized(self: CurveEditor, normalizedX: number): number
	local lut = peek(self._lut)
	if #lut == 0 then
		return 0
	end

	local clamped = math.clamp(normalizedX, 0, 1)
	local idx = clamped * (LUT_SIZE - 1)
	local lo = math.floor(idx) + 1
	local hi = math.min(lo + 1, LUT_SIZE)
	local t = idx - math.floor(idx)

	return lerp(lut[lo], lut[hi], t)
end

function CurveEditor.Render(self: CurveEditor, layoutOrder: number?): React.Element<any>
	return e(renderer, {
		CurveEditor = self,
		LayoutOrder = layoutOrder,
	})
end

function CurveEditor.RenderInternal(self: CurveEditor, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		CurveEditor = self,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type CurveEditor =
	typeof(setmetatable(
		{} :: {
			_min: number,
			_max: number,
			_xMin: number,
			_xMax: number,
			_xSuffix: string,
			_ySuffix: string,
			_height: number,
			_lut: Charm.Atom<{ number }>,
			_activeIdx: Charm.Atom<number?>,
		},
		CurveEditor
	))
	& Element.Element

return constructor
