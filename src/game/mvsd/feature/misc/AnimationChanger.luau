local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local clientState = require("@game/mvsd/client/clientState")
local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local RunService = cloneref(game:GetService("RunService")) :: RunService
local Random = Random.new()

local peek = Charm.peek

local AnimationChanger = {}
AnimationChanger.__index = AnimationChanger

setmetatable(AnimationChanger, { __index = BaseFeature })

function AnimationChanger.new(link: gameUi.Linker): AnimationChanger
	local self = BaseFeature.new() :: any
	setmetatable(self, AnimationChanger)

	link:Toggle("AnimationChanger", "Animation Changer", false):SetTip({
		title = "Animation Changer",
		body = "Changes how your character animations look and play.",
	})
	local AnimationChangerLink = link:OnKey("AnimationChanger")
	AnimationChangerLink:Submenu("opts", "Animation Changer")
	local optionsLink = AnimationChangerLink:OnKey("opts")
	optionsLink
		:Slider("fakeLag", "Fake Lag", 35, 0, 100, 1, nil, "%")
		:SetValueTextOverrides({
			[0] = "Off",
		})
		:SetTip({
			title = "Fake Lag",
			body = "Stutters your animations for a choppy, high-ping look.",
		})
	optionsLink
		:Slider("jitter", "Jitter", 35, 0, 100, 1, nil, "%")
		:SetValueTextOverrides({
			[0] = "Off",
		})
		:SetTip({
			title = "Jitter",
			body = "Adds random timing variation to your movement animations.",
		})

	self._optsLink = optionsLink
	self._janitor = Janitor.new()

	self:Track(link:Get("AnimationChanger"):OnChange(function(value: boolean)
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optionsLink:Get("fakeLag"):OnChange(function(value: number)
		self._fakeLag = value
	end))
	self:Track(optionsLink:Get("jitter"):OnChange(function(value: number)
		self._jitter = value
	end))

	self._fakeLag = optionsLink:Get("fakeLag"):Peek()
	self._jitter = optionsLink:Get("jitter"):Peek()

	if link:Peek("AnimationChanger") then
		self:Enable()
	end

	return self
end

AnimationChanger.Enable = LPH_NO_VIRTUALIZE(function(self: AnimationChanger): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local lastFreeze = os.clock()
	local lastUpdate = os.clock()
	local doFreeze = false
	local animData = {}

	self._janitor:Add(RunService.Heartbeat:Connect(function(dt: number): ()
		local humanoid = peek(clientState.humanoid) :: any
		if not humanoid then
			return
		end

		local tick = os.clock()

		local jitter = self._jitter
		local lag = self._fakeLag

		if tick - lastUpdate > dt then
			lastUpdate = tick

			local animations = humanoid.GetPlayingAnimationTracks(humanoid)

			if lag > 0 then
				if tick - lastFreeze > lag / 100 then
					task.defer(function()
						lastFreeze = os.clock()
					end)
					doFreeze = false
				else
					doFreeze = true
				end

				for i = 1, #animations do
					local animation = animations[i]
					if not doFreeze then
						animData[animation] = animation.TimePosition + tick - lastFreeze
					else
						animation.TimePosition = (animData[animation] or 0)
					end
				end
			end

			for i = 1, #animations do
				local animation = animations[i]

				if animation.Looped then
					continue
				end

				local time = animData[animation]

				if not time then
					animData[animation] = tick
				else
					if tick - time > animation.Length then
						animation:Stop()
						animData[animation] = nil
					end
				end
			end

			if jitter > 0 then
				for i = 1, #animations do
					animations[i].TimePosition *= -Random.NextNumber(Random, 1 + jitter / 4, 1.5 + jitter * 4)
				end
			end
		end
	end))
end)

function AnimationChanger.Disable(self: AnimationChanger): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function AnimationChanger.Destroy(self: AnimationChanger): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AnimationChanger =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_fakeLag: number,
			_jitter: number,
			_optsLink: gameUi.Linker,
		},
		AnimationChanger
	))
	& BaseFeature.BaseFeature

return AnimationChanger
