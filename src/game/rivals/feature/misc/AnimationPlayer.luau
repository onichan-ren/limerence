local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local clientState = require("@game/rivals/client/clientState")
local Charm = require("@pkg/Charm")

local peek = Charm.peek
local sub = Charm.subscribe

local PRESETS: { [string]: string } = {
	Orbit = "80627968348042",
	Underground = "75065228741970",
	["Take The L"] = "104549129405552",
	["Kicking Feet"] = "140609475920100",
}
local PRESET_OPTIONS = { "Underground", "Kicking Feet", "Take The L", "Orbit", "Custom" }

local function resolveAnimationId(raw: string): string?
	local trimmed = string.gsub(raw, "%s", "")
	if trimmed == "" then
		return nil
	end
	if tonumber(trimmed) then
		return "rbxassetid://" .. trimmed
	end
	return trimmed
end

local AnimationPlayer = {}
AnimationPlayer.__index = AnimationPlayer

setmetatable(AnimationPlayer, { __index = BaseFeature })

function AnimationPlayer.new(link: gameUi.Linker): AnimationPlayer
	local self = BaseFeature.new() :: any
	setmetatable(self, AnimationPlayer)

	link:Toggle("animationPlayer", "Animation Player", false):SetTip({
		title = "Animation Player",
		body = "Plays an animation on loop on your character.",
	})
	local playerLink = link:OnKey("animationPlayer")
	playerLink:Submenu("opts", "Animation Player")
	local optionsLink = playerLink:OnKey("opts")
	optionsLink:Dropdown("preset", "Preset", PRESET_OPTIONS, "Orbit"):SetTip({
		title = "Preset",
		body = "Pick a built-in animation, or Custom to use your own ID.",
	})
	optionsLink:Textbox("animationId", "Animation ID", "", "Animation id"):SetTip({
		title = "Animation ID",
		body = "Used when Preset is set to Custom.",
	})
	optionsLink:Slider("speed", "Speed", 100, 0, 500, 1, nil, "%"):SetTip({
		title = "Speed",
		body = "Playback speed of the animation.",
	})

	self._optsLink = optionsLink
	self._janitor = Janitor.new()
	self._animJanitor = Janitor.new()
	self._track = nil :: AnimationTrack?

	self._preset = optionsLink:Peek("preset") or "Orbit"
	self._animationId = optionsLink:Peek("animationId") or ""
	self._speed = (optionsLink:Peek("speed") or 100) / 100

	self:Track(link:Get("animationPlayer"):OnChange(function(value: boolean)
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optionsLink:Get("preset"):OnChange(function(value: string)
		self._preset = value
		if self._enabled then
			self:_reload()
		end
	end))

	self:Track(optionsLink:Get("animationId"):OnChange(function(value: string)
		self._animationId = value
		if self._enabled and self._preset == "Custom" then
			self:_reload()
		end
	end))

	self:Track(optionsLink:Get("speed"):OnChange(function(value: number)
		self._speed = value / 100
		local track = self._track
		if track then
			track:AdjustSpeed(self._speed)
		end
	end))

	if link:Peek("animationPlayer") then
		self:Enable()
	end

	return self
end

function AnimationPlayer._currentId(self: AnimationPlayer): string?
	if self._preset == "Custom" then
		return resolveAnimationId(self._animationId)
	end
	return resolveAnimationId(PRESETS[self._preset] or "")
end

function AnimationPlayer._reload(self: AnimationPlayer): ()
	self._animJanitor:Cleanup()
	self._track = nil

	local id = self:_currentId()
	if not id then
		return
	end

	local humanoid = peek(clientState.humanoid)
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	for _, other in next, animator:GetPlayingAnimationTracks() do
		other:Stop(0)
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = id
	self._animJanitor:Add(animation, "Destroy")

	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action4
	track:Play(0)
	track:AdjustSpeed(self._speed)
	self._track = track
	self._animJanitor:Add(function(): ()
		track:Stop(0)
		track:Destroy()
	end, true)

	self._animJanitor:Add(
		animator.AnimationPlayed:Connect(LPH_NO_VIRTUALIZE(function(played: AnimationTrack): ()
			if played ~= self._track then
				played:Stop(0)
			end
		end)),
		"Disconnect"
	)
end

function AnimationPlayer.Enable(self: AnimationPlayer): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._janitor:Add(sub(clientState.humanoid, function(): ()
		task.defer(function(): ()
			if self._enabled then
				self:_reload()
			end
		end)
	end))

	self:_reload()
end

function AnimationPlayer.Disable(self: AnimationPlayer): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	local track = self._track
	self._track = nil
	if track then
		track:Stop(0)
	end

	self._janitor:Cleanup()
	self._animJanitor:Cleanup()
end

function AnimationPlayer.Destroy(self: AnimationPlayer): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AnimationPlayer =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_animJanitor: Janitor.Janitor,
			_optsLink: gameUi.Linker,
			_preset: string,
			_animationId: string,
			_speed: number,
			_track: AnimationTrack?,
		},
		AnimationPlayer
	))
	& BaseFeature.BaseFeature

return AnimationPlayer
