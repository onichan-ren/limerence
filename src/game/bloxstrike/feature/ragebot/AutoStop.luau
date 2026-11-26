local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local clientState = require("@game/bloxstrike/client/clientState")
local ClientController = require("@game/bloxstrike/client/ClientController")
local moveController = require("@game/bloxstrike/client/moveController")
local flightState = require("@game/bloxstrike/feature/misc/flightState")

local peek = Charm.peek

local MODE_OPTIONS: { string } = { "Fair", "Instant" }

local REQUIRED_SPEED = 6
local REQUIRED_SPEED_SQ = REQUIRED_SPEED * REQUIRED_SPEED
local STOP_TTL = 0.15
local LEAD_TIME = 0.2

local cache = {
	enabled = false,
	fairMode = false,
	early = false,
}
local _stopUntil = 0
local _touchedController = false

local function isAirborne(humanoid: Humanoid?): boolean
	if not humanoid then
		return false
	end
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
end

local function stopBlocked(humanoid: Humanoid?): boolean
	if isAirborne(humanoid) then
		return true
	end
	if peek(flightState.enabled) then
		return true
	end
	return ClientController.IsClimbing()
end

local function restoreController(): ()
	if not _touchedController then
		return
	end
	_touchedController = false
	local controller = moveController.getActive()
	if controller then
		controller.moveVector = moveController.realMoveVector(controller)
	end
end

local AutoStop = {}
AutoStop.__index = AutoStop

setmetatable(AutoStop, { __index = BaseFeature })

function AutoStop.new(link: gameUi.Linker): AutoStop
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoStop)

	link:Toggle("autoStop", "Auto Stop", false):SetTip({
		title = "Auto Stop",
		body = "Slows you to an accurate speed so the Ragebot can hit while you move.",
	})
	local autoStopLink = link:OnKey("autoStop")
	autoStopLink:Submenu("opts", "Auto Stop")
	local optsLink = autoStopLink:OnKey("opts")
	optsLink:Dropdown("mode", "Mode", MODE_OPTIONS, MODE_OPTIONS[2]):SetTip({
		title = "Mode",
		body = "Fair counter-strafes like a real player. Instant directly sets your velocity.",
	})
	--[[optsLink:Toggle("early", "Early", false):SetTip({
		title = "Early",
		body = "Predictively stops the moment a target is in view.",
	})--]]

	self._activeJanitor = nil :: Janitor.Janitor?

	self:Track(link:Get("autoStop"):OnChange(function(value: boolean)
		cache.enabled = value == true
		self:_setActive(cache.enabled)
	end))
	self:Track(link:Watch("autoStop.opts.mode", function(value: string)
		cache.fairMode = value == "Fair"
	end))

	cache.fairMode = link:Peek("autoStop.opts.mode") == "Fair"
	if link:Peek("autoStop") == true then
		cache.enabled = true
		self:_setActive(true)
	end
	--[[self:Track(link:Watch("autoStop.opts.early", function(value: boolean)
		cache.early = value == true
	end))--]]

	return self
end

function AutoStop._setActive(self: AutoStop, active: boolean): ()
	if active then
		if self._activeJanitor then
			return
		end
		local janitor = Janitor.new()
		self._activeJanitor = janitor
		janitor:Add(function()
			restoreController()
		end, true)
		janitor:Add(
			RunService.Stepped:Connect(LPH_NO_VIRTUALIZE(function(): ()
				local parts = peek(clientState.parts)
				local hrp = parts.HumanoidRootPart :: any
				local humanoid = parts.Humanoid :: any
				if os.clock() >= _stopUntil or not hrp or stopBlocked(humanoid) then
					restoreController()
					return
				end

				local v = hrp.AssemblyLinearVelocity
				local speedSq = v.X * v.X + v.Z * v.Z

				local controller = moveController.getActive()
				if controller then
					_touchedController = true
					if cache.fairMode and speedSq > REQUIRED_SPEED_SQ then
						controller.moveVector = moveController.worldToMoveVector(Vector3.new(-v.X, 0, -v.Z))
					else
						controller.moveVector = Vector3.zero
					end
				end

				if not cache.fairMode and speedSq > REQUIRED_SPEED_SQ then
					local scale = REQUIRED_SPEED / math.sqrt(speedSq)
					hrp.AssemblyLinearVelocity = Vector3.new(v.X * scale, v.Y, v.Z * scale)
				end
			end)),
			"Disconnect"
		)
	else
		local janitor = self._activeJanitor
		if not janitor then
			return
		end
		self._activeJanitor = nil
		janitor:Destroy()
	end
end

function AutoStop.IsEnabled(): boolean
	return cache.enabled
end

function AutoStop.IsEarly(): boolean
	return cache.early
end

function AutoStop.IsMoving(): boolean
	local parts = peek(clientState.parts)
	local hrp = parts.HumanoidRootPart :: any
	if not hrp then
		return false
	end
	if stopBlocked(parts.Humanoid :: any) then
		return false
	end
	local v = hrp.AssemblyLinearVelocity
	return v.X * v.X + v.Z * v.Z > REQUIRED_SPEED_SQ
end

function AutoStop.PredictOrigin(origin: Vector3): Vector3
	local parts = peek(clientState.parts)
	local hrp = parts.HumanoidRootPart :: any
	if not hrp then
		return origin
	end
	local v = hrp.AssemblyLinearVelocity
	return origin + Vector3.new(v.X, 0, v.Z) * LEAD_TIME
end

function AutoStop.RequestStop(): ()
	_stopUntil = os.clock() + STOP_TTL
end

function AutoStop.Destroy(self: AutoStop): ()
	self:_setActive(false)
	cache.enabled = false
	BaseFeature.Destroy(self)
end

export type AutoStop =
	typeof(setmetatable(
		{} :: {
			_activeJanitor: Janitor.Janitor?,
		},
		AutoStop
	))
	& BaseFeature.BaseFeature

return AutoStop
