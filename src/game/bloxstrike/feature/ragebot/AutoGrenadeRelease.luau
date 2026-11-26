local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local PlayerController = require("@feature/player/PlayerController")
local clientState = require("@game/bloxstrike/client/clientState")
local grenadePredictionShared = require("@game/bloxstrike/grenade/grenadePredictionShared")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

local peek = Charm.peek

local HE_MAX_RANGE = 22.3
local HE_FALLOFF = 0.27
local THROTTLE_SECONDS = 0.2

local AutoGrenadeRelease = {}
AutoGrenadeRelease.__index = AutoGrenadeRelease
setmetatable(AutoGrenadeRelease, { __index = BaseFeature })

local _instance: any = nil

local estimateHeDamage = LPH_NO_VIRTUALIZE(function(dist: number): number
	local d = HE_FALLOFF * math.max(0, HE_MAX_RANGE - dist) ^ 2
	return d < 0.5 and 0 or math.floor(d + 0.5)
end)

function AutoGrenadeRelease.new(link: gameUi.Linker): AutoGrenadeRelease
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoGrenadeRelease)

	local mainToggle = link:Toggle("autoGrenadeRelease", "Auto Grenade Release", false):SetTip({
		title = "Auto Grenade Release",
		body = "Releases your grenade automatically when its predicted landing point would hit an enemy.",
	})
	link:Extra(mainToggle, "autoGrenadeReleaseOpts", "Submenu", "Auto Release Options")
	local opts = link:OnKey("autoGrenadeReleaseOpts")
	self._opts = opts

	opts:Slider("heMinDamage", "HE Min Damage", 30, 1, 50, 1):SetTip({
		title = "HE Min Damage",
		body = "Release the HE Grenade as soon as the predicted impact would deal at least this much damage to any enemy.",
	})
	opts:Slider("fireMaxDist", "Max Distance", 8, 1, 20, 1, nil, "s"):SetTip({
		title = "Fire Max Distance",
		body = "Release the Molotov/Incendiary as soon as an enemy is within this many studs of the predicted landing point.",
	})

	self._janitor = Janitor.new()
	self._enabled = false
	self._lastReleaseTime = -math.huge
	self._lastReleasedWeapon = nil :: any

	self:Track(link:Get("autoGrenadeRelease"):OnChange(function(v: boolean): ()
		if v then
			self:_enable()
		else
			self:_disable()
		end
	end))

	if link:Peek("autoGrenadeRelease") == true then
		self:_enable()
	end

	_instance = self
	return self
end

AutoGrenadeRelease._tick = LPH_JIT_MAX(function(self: AutoGrenadeRelease): ()
	local now = os.clock()
	if now - self._lastReleaseTime < THROTTLE_SECONDS then
		return
	end

	local result = grenadePredictionShared.getCurrent()
	if not result then
		self._lastReleasedWeapon = nil
		return
	end

	local weapon = result.weapon
	if not weapon then
		return
	end
	if weapon.ThrowFinished then
		if self._lastReleasedWeapon == weapon then
			self._lastReleasedWeapon = nil
		end
		return
	end
	if not weapon.ThrowStarted then
		return
	end
	if self._lastReleasedWeapon == weapon then
		return
	end

	local impactPos = result.impactPos
	local myTeam = peek(clientState.team)
	local shouldRelease = false

	if result.grenadeName == "HE Grenade" then
		local minDmg = self._opts:Peek("heMinDamage") or 50
		for _, basePlayer in next, PlayerController.GetAll() do
			if peek(basePlayer.team) == myTeam then
				continue
			end
			local hrp = peek(basePlayer.hrp) :: BasePart?
			if not hrp then
				continue
			end
			local dist = (hrp.Position - impactPos).Magnitude
			if dist > HE_MAX_RANGE then
				continue
			end
			local dmg = estimateHeDamage(dist)
			if dmg >= minDmg then
				shouldRelease = true
				break
			end
		end
	elseif result.profile.leavesFire then
		local maxDist = self._opts:Peek("fireMaxDist") or 8
		for _, basePlayer in next, PlayerController.GetAll() do
			if peek(basePlayer.team) == myTeam then
				continue
			end
			local hrp = peek(basePlayer.hrp) :: BasePart?
			if not hrp then
				continue
			end
			local dist = (hrp.Position - impactPos).Magnitude
			if dist <= maxDist then
				shouldRelease = true
				break
			end
		end
	end

	if not shouldRelease then
		return
	end

	self._lastReleaseTime = now
	self._lastReleasedWeapon = weapon
	local throwType = result.throwType
	task.spawn(function(): ()
		setthreadidentity(8)
		weapon:Throw(throwType)
	end)
end)

function AutoGrenadeRelease._enable(self: AutoGrenadeRelease): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._lastReleasedWeapon = nil

	RunService:BindToRenderStep(
		"AutoGrenadeReleaseRender",
		Enum.RenderPriority.Camera.Value + 2,
		LPH_NO_VIRTUALIZE(function(): ()
			self:_tick()
		end)
	)
	self._janitor:Add(function(): ()
		RunService:UnbindFromRenderStep("AutoGrenadeReleaseRender")
	end, true)
end

function AutoGrenadeRelease._disable(self: AutoGrenadeRelease): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._lastReleasedWeapon = nil
	self._janitor:Cleanup()
end

function AutoGrenadeRelease.Destroy(self: AutoGrenadeRelease): ()
	self:_disable()
	if (_instance :: any) == self then
		_instance = nil
	end
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type AutoGrenadeRelease =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_opts: gameUi.Linker,
			_janitor: Janitor.Janitor,
			_lastReleaseTime: number,
			_lastReleasedWeapon: any,
		},
		AutoGrenadeRelease
	))
	& BaseFeature.BaseFeature

return AutoGrenadeRelease
