local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Element = require("@ui/window/element/Element")
local renderer = require("@ui/window/element/colorpicker/renderer")
local animator = require("@ui/window/element/colorpicker/animator")
local animations = require("@ui/window/element/colorpicker/animations")

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement
local createBinding = React.createBinding
local subscribeToBinding = (React :: any).__subscribeToBinding

local Colorpicker = {}
Colorpicker.__index = Colorpicker

setmetatable(Colorpicker, { __index = Element })

export type GradientAnimation = string
export type CurrentValue = animator.CurrentValue

local function colorFromCurrent(v: CurrentValue): Color3
	local c = v.color
	if typeof(c) == "ColorSequence" then
		local kp = c.Keypoints[1]
		return (kp and kp.Value or Color3.fromRGB(255, 255, 255))
	end
	return c
end

local function gradientFromCurrent(v: CurrentValue): ColorSequence
	local c = v.color
	if typeof(c) == "ColorSequence" then
		return c
	end
	return ColorSequence.new(c :: Color3)
end

local function rotationFromCurrent(v: CurrentValue): number
	return v.rotation
end

local function transparencyFromCurrent(v: CurrentValue): number
	return v.transparency
end

local function constructor(text: string, default: Color3 | ColorSequence, transparency: number?): Colorpicker
	local self = Element.new(text) :: any

	setmetatable(self, Colorpicker)

	self._transparency = at(transparency)
	self._supportsTransparency = transparency ~= nil
	self._isSequence = default and typeof(default) == "ColorSequence" or false
	self._state = at(default or Color3.fromRGB(255, 255, 255))
	self._rotation = at(0)
	self._animation = at("none" :: GradientAnimation)
	self._speed = at(1)

	local currentBinding, setCurrent = createBinding(animator.computeStatic(self))
	self._current = currentBinding
	self._setCurrent = setCurrent

	self._currentColor = currentBinding:map(colorFromCurrent)
	self._currentGradient = currentBinding:map(gradientFromCurrent)
	self._currentRotation = currentBinding:map(rotationFromCurrent)
	self._currentTransparency = currentBinding:map(transparencyFromCurrent)

	local function syncStatic(): ()
		self._setCurrent(animator.computeStatic(self))
	end

	sub(self._state, function(): ()
		if peek(self._animation) == "none" then
			syncStatic()
		end
	end)
	sub(self._transparency, function(): ()
		if peek(self._animation) == "none" then
			syncStatic()
		end
	end)
	sub(self._rotation, function(): ()
		if peek(self._animation) == "none" then
			syncStatic()
		end
	end)
	sub(self._animation, function(anim: GradientAnimation): ()
		if anim == "none" then
			animator.unregister(self)
			syncStatic()
		else
			animator.register(self)
		end
	end)

	if peek(self._animation) ~= "none" then
		animator.register(self)
	end

	return self
end

function Colorpicker.SetState(self: Colorpicker, color: Color3 | ColorSequence): ()
	self._state(color)
end

function Colorpicker.SetTransparency(self: Colorpicker, transparency: number): ()
	self._transparency(transparency)
end

function Colorpicker.SetRotation(self: Colorpicker, rotation: number): ()
	self._rotation(rotation)
end

function Colorpicker.SetAnimation(self: Colorpicker, animation: GradientAnimation): ()
	if not animations.appliesTo(animation, self._isSequence, self._supportsTransparency) then
		return
	end
	self._animation(animation)
end

function Colorpicker.SetSpeed(self: Colorpicker, speed: number): ()
	self._speed(speed)
end

function Colorpicker.OnColorChange(self: Colorpicker, callback: (color: Color3 | ColorSequence) -> ()): () -> ()
	return sub(self._state, callback)
end

function Colorpicker.OnTransparencyChange(self: Colorpicker, callback: (transparency: number?) -> ()): () -> ()
	return sub(self._transparency, callback)
end

function Colorpicker.PeekColor(self: Colorpicker): Color3 | ColorSequence
	return peek(self._state)
end

function Colorpicker.PeekTransparency(self: Colorpicker): number?
	return peek(self._transparency)
end

function Colorpicker.GetColor(self: Colorpicker): Color3
	return (self._currentColor :: any):getValue()
end

function Colorpicker.GetGradient(self: Colorpicker): ColorSequence
	return (self._currentGradient :: any):getValue()
end

function Colorpicker.GetTransparency(self: Colorpicker): number
	return (self._currentTransparency :: any):getValue()
end

function Colorpicker.GetRotation(self: Colorpicker): number
	return (self._currentRotation :: any):getValue()
end

export type CurrentSnapshot = {
	color: Color3,
	gradient: ColorSequence,
	transparency: number,
	rotation: number,
}

function Colorpicker.GetSnapshot(self: Colorpicker): CurrentSnapshot
	return {
		color = self:GetColor(),
		gradient = self:GetGradient(),
		transparency = self:GetTransparency(),
		rotation = self:GetRotation(),
	}
end

function Colorpicker.OnUpdate(self: Colorpicker, callback: (snapshot: CurrentSnapshot) -> ()): () -> ()
	return subscribeToBinding(self._current, function(): ()
		callback(self:GetSnapshot())
	end)
end

function Colorpicker.RenderInternal(self: Colorpicker, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		Colorpicker = self,
		TextRef = props and props.textRef,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type Colorpicker =
	typeof(setmetatable(
		{} :: {
			_transparency: Charm.Atom<number?>,
			_supportsTransparency: boolean,
			_isSequence: boolean,
			_state: Charm.Atom<Color3 | ColorSequence>,
			_rotation: Charm.Atom<number>,
			_animation: Charm.Atom<GradientAnimation>,
			_speed: Charm.Atom<number>,
			_current: any,
			_setCurrent: (CurrentValue) -> (),
			_currentColor: any,
			_currentGradient: any,
			_currentRotation: any,
			_currentTransparency: any,
		},
		Colorpicker
	))
	& Element.Element

return constructor
