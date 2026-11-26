local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local clientState = require("@game/bloxstrike/client/clientState")
local ClientController = require("@game/bloxstrike/client/ClientController")
local moveController = require("@game/bloxstrike/client/moveController")
local flightState = require("@game/bloxstrike/feature/misc/flightState")
local strafeShared = require("@game/bloxstrike/feature/misc/strafeShared")

local peek = Charm.peek

local INPUT_EPSILON = 1e-3
local SPEED_EPSILON_SQ = 1

local function blocked(humanoid: Humanoid?): boolean
	if strafeShared.isAirborne(humanoid) then
		return true
	end
	if peek(flightState.enabled) then
		return true
	end
	return ClientController.IsClimbing()
end

local QuickStop = {}
QuickStop.__index = QuickStop

setmetatable(QuickStop, { __index = BaseFeature })

function QuickStop.new(link: gameUi.Linker): QuickStop
	local self = BaseFeature.new() :: any
	setmetatable(self, QuickStop)

	link:Toggle("quickStop", "Quick Stop", false):SetTip({
		title = "Quick Stop",
		body = "Stops you instantly when you release movement keys instead of sliding to a halt.",
	})

	self._activeJanitor = nil :: Janitor.Janitor?

	self:Track(link:Get("quickStop"):OnChange(function(value: boolean): ()
		self:_setEnabled(value)
	end))

	return self
end

function QuickStop._setEnabled(self: QuickStop, enabled: boolean): ()
	if enabled then
		if self._activeJanitor then
			return
		end
		local janitor = Janitor.new()
		self._activeJanitor = janitor

		janitor:Add(
			RunService.Stepped:Connect(LPH_JIT_MAX(function(): ()
				local parts = peek(clientState.parts)
				local hrp = parts.HumanoidRootPart :: any
				if not hrp or blocked(parts.Humanoid :: any) then
					return
				end

				local controller = moveController.getActive()
				if not controller then
					return
				end
				if moveController.realMoveVector(controller).Magnitude > INPUT_EPSILON then
					return
				end

				local v = hrp.AssemblyLinearVelocity
				if v.X * v.X + v.Z * v.Z <= SPEED_EPSILON_SQ then
					return
				end

				hrp.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)

				local character = ClientController.GetCharacterObject()
				if character then
					rawset(character, "GlobalVelocity", Vector3.zero)
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

function QuickStop.Destroy(self: QuickStop): ()
	self:_setEnabled(false)
	BaseFeature.Destroy(self)
end

export type QuickStop =
	typeof(setmetatable(
		{} :: {
			_activeJanitor: Janitor.Janitor?,
		},
		QuickStop
	))
	& BaseFeature.BaseFeature

return QuickStop
