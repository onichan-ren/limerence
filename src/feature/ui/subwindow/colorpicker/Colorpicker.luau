local Charm = require("@pkg/Charm")
local React = require("@pkg/React")

local Subwindow = require("@ui/subwindow/Subwindow")
local renderer = require("@ui/subwindow/colorpicker/renderer")
local dropdownApi = require("@ui/subwindow/dropdown/dropdownApi")
local animations = require("@ui/window/element/colorpicker/animations")

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement

local Colorpicker = {}
Colorpicker.__index = Colorpicker

setmetatable(Colorpicker, { __index = Subwindow })

local function constructor(): Colorpicker
	local self = Subwindow.new() :: any

	setmetatable(self, Colorpicker)

	self._title = at("")
	self._color = at(Color3.fromRGB(255, 255, 255) :: Color3 | ColorSequence)
	self._transparency = at(nil :: number?)
	self._source = at(nil :: any)

	self._activeKeypoint = at(1)
	self._keypointIds = at({} :: { number })
	self._nextKeypointId = 0
	self._hue = at(0)
	self._saturation = at(0)
	self._value = at(1)

	self._rotation = at(0)
	self._animation = at("none" :: string)
	self._speed = at(1)
	self._advancedOpen = at(false)
	self._sliderSnapEpoch = at(0)

	local animSource: any = {}
	animSource._options = at({} :: { string })
	animSource._state = at(animations.getLabel(peek(self._animation)))
	animSource._mode = at("single" :: "single" | "multi")
	animSource._open = at(false)
	animSource.Toggle = function(src: any, option: string): ()
		local key = animations.getKey(option)
		if not key then
			return
		end
		if peek(self._animation) ~= key then
			self:SetAnimation(key)
		end
		dropdownApi.Close(src)
	end
	animSource.OpenPicker = function(options: { string }, position: UDim2?): ()
		animSource._options(options)
		dropdownApi.Open(animSource, position)
	end
	animSource.ClosePicker = function(): ()
		dropdownApi.Close(animSource)
	end
	self._animationSource = animSource

	sub(self._animation, function(key: string): ()
		local label = animations.getLabel(key)
		if peek(animSource._state) ~= label then
			animSource._state(label)
		end
	end)

	return self
end

function Colorpicker._assignIds(self: Colorpicker, count: number): { number }
	local ids = table.create(count)
	for i = 1, count do
		self._nextKeypointId += 1
		ids[i] = self._nextKeypointId
	end
	return ids
end

local function getKeypointColor(color: Color3 | ColorSequence, idx: number?): Color3
	if typeof(color) == "ColorSequence" then
		local kp = color.Keypoints[idx or 1]
		return kp and kp.Value or Color3.fromRGB(255, 255, 255)
	end
	return color
end

function Colorpicker._loadHsvFromCurrent(self: Colorpicker): ()
	local color = peek(self._color)
	local idx = peek(self._activeKeypoint)
	local c3 = getKeypointColor(color, idx)

	local h, s, v = c3:ToHSV()
	if s > 0 then
		self._hue(h)
	end
	self._saturation(s)
	self._value(v)
	self._sliderSnapEpoch(peek(self._sliderSnapEpoch) + 1)
end

function Colorpicker._pushColor(self: Colorpicker, value: Color3 | ColorSequence): ()
	local source = peek(self._source)
	if not source then
		return
	end
	source._state(value)
end

function Colorpicker._pushTransparency(self: Colorpicker, value: number): ()
	local source = peek(self._source)
	if not source or source._transparency == nil then
		return
	end
	source._transparency(value)
end

function Colorpicker._applyHsv(self: Colorpicker): ()
	local h = peek(self._hue)
	local s = peek(self._saturation)
	local v = peek(self._value)
	local newColor = Color3.fromHSV(h, s, v)

	local current = peek(self._color)
	if typeof(current) == "ColorSequence" then
		local idx = peek(self._activeKeypoint) or 1
		local kps = current.Keypoints
		if not kps[idx] then
			return
		end

		local newKps = table.create(#kps)
		for i, kp in kps do
			if i == idx then
				table.insert(newKps, ColorSequenceKeypoint.new(kp.Time, newColor))
			else
				table.insert(newKps, kp)
			end
		end

		local seq = ColorSequence.new(newKps)
		self._color(seq)
		self:_pushColor(seq)
	else
		self._color(newColor)
		self:_pushColor(newColor)
	end
end

function Colorpicker.SetHue(self: Colorpicker, h: number): ()
	self._hue(math.clamp(h, 0, 1))
	self:_applyHsv()
end

function Colorpicker.SetSaturationValue(self: Colorpicker, s: number, v: number): ()
	self._saturation(math.clamp(s, 0, 1))
	self._value(math.clamp(v, 0, 1))
	self:_applyHsv()
end

function Colorpicker.SetTransparency(self: Colorpicker, t: number): ()
	local clamped = math.clamp(t, 0, 1)
	self._transparency(clamped)
	self:_pushTransparency(clamped)
end

function Colorpicker.SetRotation(self: Colorpicker, rotation: number): ()
	local clamped = math.clamp(rotation, 0, 360)
	self._rotation(clamped)
	local source = peek(self._source)
	if source and source._rotation then
		source._rotation(clamped)
	end
end

function Colorpicker.SetAnimation(self: Colorpicker, animation: string): ()
	self._animation(animation)
	local source = peek(self._source)
	if source and source._animation then
		source._animation(animation)
	end
end

function Colorpicker.SetSpeed(self: Colorpicker, speed: number): ()
	local clamped = math.clamp(speed, 0.1, 5)
	self._speed(clamped)
	local source = peek(self._source)
	if source and source._speed then
		source._speed(clamped)
	end
end

function Colorpicker.ToggleAdvanced(self: Colorpicker): ()
	self._advancedOpen(not peek(self._advancedOpen))
end

function Colorpicker.SetColor3(self: Colorpicker, c3: Color3): ()
	local h, s, v = c3:ToHSV()
	if s > 0 then
		self._hue(h)
	end
	self._saturation(s)
	self._value(v)
	self:_applyHsv()
	self._sliderSnapEpoch(peek(self._sliderSnapEpoch) + 1)
end

function Colorpicker.SetColorFromRGB(self: Colorpicker, r: number, g: number, b: number): ()
	local rr = math.clamp(math.floor(r + 0.5), 0, 255)
	local gg = math.clamp(math.floor(g + 0.5), 0, 255)
	local bb = math.clamp(math.floor(b + 0.5), 0, 255)
	self:SetColor3(Color3.fromRGB(rr, gg, bb))
end

function Colorpicker.SetColorFromHex(self: Colorpicker, hex: string): boolean
	local cleaned = (hex:gsub("^#", ""):gsub("%s", ""))
	if #cleaned == 3 then
		cleaned = cleaned:sub(1, 1):rep(2) .. cleaned:sub(2, 2):rep(2) .. cleaned:sub(3, 3):rep(2)
	end
	if #cleaned ~= 6 then
		return false
	end
	if not cleaned:match("^[0-9a-fA-F]+$") then
		return false
	end
	local r = tonumber(cleaned:sub(1, 2), 16)
	local g = tonumber(cleaned:sub(3, 4), 16)
	local b = tonumber(cleaned:sub(5, 6), 16)
	if not (r and g and b) then
		return false
	end
	self:SetColor3(Color3.fromRGB(r, g, b))
	return true
end

function Colorpicker.SetActiveKeypoint(self: Colorpicker, idx: number): ()
	local current = peek(self._color)
	if typeof(current) ~= "ColorSequence" then
		return
	end
	if not current.Keypoints[idx] then
		return
	end
	self._activeKeypoint(idx)
	self:_loadHsvFromCurrent()
end

function Colorpicker.RemoveKeypoint(self: Colorpicker, idx: number): ()
	local current = peek(self._color)
	if typeof(current) ~= "ColorSequence" then
		return
	end

	local kps = current.Keypoints
	if idx <= 1 or idx >= #kps then
		return
	end

	local newKps = {}
	local newIds = {}
	local oldIds = peek(self._keypointIds)
	for i, kp in kps do
		if i ~= idx then
			table.insert(newKps, kp)
			table.insert(newIds, oldIds[i])
		end
	end

	local seq = ColorSequence.new(newKps)
	self._color(seq)
	self._keypointIds(newIds)
	self:_pushColor(seq)

	local activeIdx = peek(self._activeKeypoint)
	if activeIdx == idx then
		self._activeKeypoint(1)
		self:_loadHsvFromCurrent()
	elseif activeIdx > idx then
		self._activeKeypoint(activeIdx - 1)
	end
end

function Colorpicker.AddKeypoint(self: Colorpicker, time: number): ()
	local current = peek(self._color)
	if typeof(current) ~= "ColorSequence" then
		return
	end

	local clampedTime = math.clamp(time, 0.001, 0.999)
	local h = peek(self._hue)
	local s = peek(self._saturation)
	local v = peek(self._value)
	local newColor = Color3.fromHSV(h, s, v)
	local newId = self:_assignIds(1)[1]

	local newKps = {}
	local newIds = {}
	local oldIds = peek(self._keypointIds)
	local insertIdx = nil
	for i, kp in current.Keypoints do
		if not insertIdx and kp.Time > clampedTime then
			insertIdx = i
			table.insert(newKps, ColorSequenceKeypoint.new(clampedTime, newColor))
			table.insert(newIds, newId)
		end
		table.insert(newKps, kp)
		table.insert(newIds, oldIds[i])
	end
	if not insertIdx then
		insertIdx = #newKps + 1
		table.insert(newKps, ColorSequenceKeypoint.new(clampedTime, newColor))
		table.insert(newIds, newId)
	end

	local seq = ColorSequence.new(newKps)
	self._color(seq)
	self._keypointIds(newIds)
	self:_pushColor(seq)
	self._activeKeypoint(insertIdx)
end

function Colorpicker.Open(self: Colorpicker, source: any, position: UDim2?): ()
	local selfSource = peek(self._source)

	if selfSource == source and peek(self._isOpen) then
		return
	end

	local color = peek(source._state)
	local transparency = source._transparency and peek(source._transparency) or nil

	self._title(peek(source._text))
	self._color(color)
	self._transparency(transparency)
	self._source(source)
	self._activeKeypoint(1)

	if typeof(color) == "ColorSequence" then
		self._keypointIds(self:_assignIds(#color.Keypoints))
	else
		self._keypointIds({})
	end

	self._rotation(source._rotation and peek(source._rotation) or 0)
	self._animation(source._animation and peek(source._animation) or "none")
	self._speed(source._speed and peek(source._speed) or 1)

	self:_loadHsvFromCurrent()

	self:SetPosition(position or UDim2.new(0, 10, 0, 10))
	self:SetOpen(true)
end

function Colorpicker.Close(self: Colorpicker): ()
	self:SetOpen(false)
end

function Colorpicker.Render(self: Colorpicker): React.Element<any>
	return e(renderer, {
		Colorpicker = self,
	})
end

export type Subwindow = Subwindow.Subwindow
export type Colorpicker =
	typeof(setmetatable(
		{} :: {
			_title: Charm.Atom<string>,
			_color: Charm.Atom<Color3 | ColorSequence>,
			_transparency: Charm.Atom<number?>,
			_source: Charm.Atom<any>,
			_activeKeypoint: Charm.Atom<number>,
			_keypointIds: Charm.Atom<{ number }>,
			_nextKeypointId: number,
			_hue: Charm.Atom<number>,
			_saturation: Charm.Atom<number>,
			_value: Charm.Atom<number>,
			_rotation: Charm.Atom<number>,
			_animation: Charm.Atom<string>,
			_speed: Charm.Atom<number>,
			_advancedOpen: Charm.Atom<boolean>,
			_sliderSnapEpoch: Charm.Atom<number>,
			_animationSource: any,
		},
		Colorpicker
	))
	& Subwindow

return constructor
