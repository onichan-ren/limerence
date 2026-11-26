local Players = cloneref(game:GetService("Players")) :: Players
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local clientState = require("@game/bloxstrike/client/clientState")
local Charm = require("@pkg/charm")
local Janitor = require("@pkg/janitor")
local RunService = cloneref(game:GetService("RunService")) :: RunService
local Random = Random.new()

local LocalPlayer = Players.LocalPlayer
local peek = Charm.peek
local sub = Charm.subscribe

local ZERO_PITCH_LAND_DURATION = 1

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
	optionsLink:Toggle("zeroPitchOnLand", "Zero Pitch On Land", false):SetTip({
		title = "Zero Pitch On Land",
		body = "Keeps your head level on screen for one second after you land. Only you see this.",
	})
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

	self._janitor = Janitor.new()
	self._landJanitor = nil
	self._zeroPitchUntil = 0
	self._kinematics = nil

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
	self:Track(optionsLink:Get("zeroPitchOnLand"):OnChange(function(value: boolean)
		self._zeroPitchOnLand = value
		if not value then
			self._zeroPitchUntil = 0
		end
	end))

	self._fakeLag = optionsLink:Get("fakeLag"):Peek()
	self._jitter = optionsLink:Get("jitter"):Peek()
	self._zeroPitchOnLand = optionsLink:Get("zeroPitchOnLand"):Peek()
	self._optionsLink = optionsLink

	return self
end

function AnimationChanger._bindZeroPitchLand(self: AnimationChanger, humanoid: Humanoid, janitor: Janitor.Janitor): ()
	local lastState = nil
	janitor:Add(humanoid.StateChanged:Connect(LPH_NO_VIRTUALIZE(function(_, new: Enum.HumanoidStateType): ()
		if not self._zeroPitchOnLand then
			lastState = new
			return
		end

		if new == Enum.HumanoidStateType.Running and lastState == Enum.HumanoidStateType.Freefall then
			task.spawn(function()
				RunService.PreRender:Wait()
				RunService.PreRender:Wait()
				RunService.PreRender:Wait()
				if lastState ~= new then
					return
				end
				self._zeroPitchUntil = os.clock() + ZERO_PITCH_LAND_DURATION
			end)
		end
		lastState = new
	end)))

	janitor:Add(humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function(): ()
		if humanoid.FloorMaterial == Enum.Material.Air then
			self._zeroPitchUntil = 0
		end
	end))
end

function AnimationChanger._applyZeroPitchLand(self: AnimationChanger): ()
	if os.clock() >= self._zeroPitchUntil then
		return
	end
	local humanoidInst = peek(clientState.parts).Humanoid :: Humanoid
	if not humanoidInst or humanoidInst.FloorMaterial == Enum.Material.Air then
		return
	end
	local kinematics = self._kinematics
	if not kinematics then
		kinematics = ModuleController.GetModule("CharacterKinematics")
		self._kinematics = kinematics
	end
	if kinematics then
		kinematics.setVerticalLook(LocalPlayer, 0)
	end
end

AnimationChanger.Enable = LPH_NO_VIRTUALIZE(function(self: AnimationChanger): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local parts = clientState.parts

	local lastFreeze = os.clock()
	local lastUpdate = os.clock()
	local doFreeze = false
	local animData = setmetatable({}, { __mode = "k" }) :: any

	local function bindHumanoid(parts: { [string]: Instance }): ()
		if self._landJanitor then
			self._landJanitor:Destroy()
			self._landJanitor = nil
		end
		local humanoid = parts.Humanoid
		if not humanoid then
			return
		end
		local landJanitor = Janitor.new()
		self._landJanitor = landJanitor
		self:_bindZeroPitchLand(humanoid :: Humanoid, landJanitor)
	end

	self._janitor:Add(sub(clientState.parts, bindHumanoid))
	bindHumanoid(peek(clientState.parts))

	local function bindZeroPitchLand(): ()
		self._janitor:Add(
			RunService.PreRender:Connect(function(): ()
				self:_applyZeroPitchLand()
			end),
			"Disconnect",
			"zeroPitch"
		)
	end

	self._janitor:Add(self._optionsLink:Get("zeroPitchOnLand"):OnChange(function(value: boolean): ()
		if value then
			bindZeroPitchLand()
		else
			self._janitor:Remove("zeroPitch")
		end
	end))

	if self._zeroPitchOnLand then
		bindZeroPitchLand()
	end

	self._janitor:Add(RunService.Heartbeat:Connect(function(dt: number): ()
		local humanoid = peek(parts).Humanoid :: any
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
			end

			if lag > 0 or jitter > 0 then
				for i = 1, #animations do
					local animation = animations[i]
					if lag > 0 then
						if not doFreeze then
							animData[animation] = animation.TimePosition + tick - lastFreeze
						else
							animation.TimePosition = (animData[animation] or 0)
						end
					end
					if jitter > 0 then
						animation.TimePosition *= -Random.NextNumber(Random, 1 + jitter / 4, 1.5 + jitter * 4)
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
		end
	end))
end)

function AnimationChanger.Disable(self: AnimationChanger): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._zeroPitchUntil = 0
	if self._landJanitor then
		self._landJanitor:Destroy()
		self._landJanitor = nil
	end
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
			_zeroPitchOnLand: boolean,
			_zeroPitchUntil: number,
			_landJanitor: Janitor.Janitor?,
			_optionsLink: gameUi.Linker,
			_kinematics: any?,
		},
		AnimationChanger
	))
	& BaseFeature.BaseFeature

return AnimationChanger
