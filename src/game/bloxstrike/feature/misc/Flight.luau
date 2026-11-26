local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local clientState = require("@game/bloxstrike/client/clientState")
local flightState = require("@game/bloxstrike/feature/misc/flightState")
local strafeShared = require("@game/bloxstrike/feature/misc/strafeShared")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local FLIGHT_STUDS_PER_SECOND = 30
local MAX_DT = 0.05
local MIN_UPWARD_SPEED = 2.5
local RESYNC_DISTANCE = 10

local peek = Charm.peek

local Flight = {}
Flight.__index = Flight

setmetatable(Flight, { __index = BaseFeature })

local computeWishDir = LPH_NO_VIRTUALIZE(function(goingDown: boolean): (Vector3, number)
	local vert = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		vert += 1
	end
	if goingDown then
		vert -= 1
	end

	return strafeShared.computeWishDir(), vert
end)

function Flight.new(link: gameUi.Linker): Flight
	local self = BaseFeature.new() :: any
	setmetatable(self, Flight)

	link:Toggle("flight", "Flight", false):SetTip({
		title = "Flight",
		body = "Fly through the air.",
	})
	local flightLink = link:OnKey("flight")
	flightLink:Submenu("opts", "Flight")
	local optionsLink = flightLink:OnKey("opts")
	optionsLink:Slider("speed", "Speed", 50, 1, 100, 1, nil, "%"):SetTip({
		title = "Speed",
		body = "Flight speed as a percentage of max.",
	})
	local downKey = optionsLink:Key("downKey", "Fly Down", Enum.KeyCode.LeftControl):SetMode("onHold"):SetTip({
		title = "Fly Down",
		body = "Key to fly down.",
	})

	self._speed = 50
	self._goingDown = false
	self._activeJanitor = nil :: Janitor.Janitor?
	self._flightPos = nil :: Vector3?

	self:Track(link:Get("flight"):OnChange(function(value: boolean)
		self:_setEnabled(value)
	end))

	self:Track(link:Watch("flight.opts.speed", function(value: number)
		self._speed = value
	end))

	self:Track(downKey:OnCallback(function(active: boolean)
		self._goingDown = active
	end))

	return self
end

function Flight._setEnabled(self: Flight, enabled: boolean): ()
	flightState.enabled(enabled)

	if enabled then
		if self._activeJanitor then
			return
		end
		self._flightPos = nil
		local janitor = Janitor.new()
		self._activeJanitor = janitor

		janitor:Add(
			RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
				local gameState = Workspace:GetAttribute("GameState")
				if gameState == "Buy Period" then
					self._flightPos = nil
					return
				end
				if peek(clientState.isSpectating) then
					self._flightPos = nil
					return
				end

				local parts = peek(clientState.parts)
				local hrp = parts.HumanoidRootPart :: any
				if not hrp then
					self._flightPos = nil
					return
				end

				local hrpPos = hrp.Position
				local pos = self._flightPos
				if not pos or (pos - hrpPos).Magnitude > RESYNC_DISTANCE then
					pos = hrpPos
				end

				local clamped = math.min(dt, MAX_DT)
				local moveSpeed = (self._speed / 100) * FLIGHT_STUDS_PER_SECOND
				local flatDir, vert = computeWishDir(self._goingDown)

				if flatDir.Magnitude < 0.001 and vert == 0 then
					hrp.AssemblyLinearVelocity = Vector3.zero
					self._flightPos = pos
					hrp.CFrame = hrp.CFrame.Rotation + pos
					return
				end

				local ySpeed = vert * moveSpeed
				if vert > 0 then
					ySpeed = math.max(ySpeed, MIN_UPWARD_SPEED)
				end

				local velocity = Vector3.new(flatDir.X * moveSpeed, ySpeed, flatDir.Z * moveSpeed)
				hrp.AssemblyLinearVelocity = velocity
				pos += velocity * clamped
				self._flightPos = pos
				hrp.CFrame = hrp.CFrame.Rotation + pos
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

function Flight.Destroy(self: Flight): ()
	self:_setEnabled(false)
	BaseFeature.Destroy(self)
end

export type Flight =
	typeof(setmetatable(
		{} :: {
			_speed: number,
			_goingDown: boolean,
			_activeJanitor: Janitor.Janitor?,
			_flightPos: Vector3?,
		},
		Flight
	))
	& BaseFeature.BaseFeature

return Flight
