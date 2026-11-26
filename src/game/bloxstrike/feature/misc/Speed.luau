local RunService = cloneref(game:GetService("RunService")) :: RunService
local clientState = require("@game/bloxstrike/client/clientState")
local ClientController = require("@game/bloxstrike/client/ClientController")
local flightState = require("@game/bloxstrike/feature/misc/flightState")
local strafeShared = require("@game/bloxstrike/feature/misc/strafeShared")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local BOOST_STUDS_PER_SECOND = 30
local MAX_DT = 0.05
local MAX_DRIFT = 3

local peek = Charm.peek

local Speed = {}
Speed.__index = Speed

setmetatable(Speed, { __index = BaseFeature })

function Speed.new(link: gameUi.Linker): Speed
	local self = BaseFeature.new() :: any
	setmetatable(self, Speed)

	link:Toggle("speed", "Speed", false):SetTip({
		title = "Speed",
		body = "Moves you along your movement direction at extra speed and removes your velocity while moving.",
	})
	local speedLink = link:OnKey("speed")
	speedLink:Submenu("opts", "Speed")
	local optionsLink = speedLink:OnKey("opts")
	optionsLink:Slider("boost", "Speed Boost", 50, 0, 100, 1, nil, "%"):SetTip({
		title = "Speed Boost",
		body = "Extra speed applied each frame while moving. 0 disables the boost.",
	})

	self._boost = 50
	self._activeJanitor = nil :: Janitor.Janitor?
	self._movePos = nil :: Vector3?

	self:Track(link:Get("speed"):OnChange(function(value: boolean)
		self:_setEnabled(value)
	end))

	self:Track(link:Watch("speed.opts.boost", function(value: number)
		self._boost = value
	end))

	return self
end

function Speed._setEnabled(self: Speed, enabled: boolean): ()
	if enabled then
		if self._activeJanitor then
			return
		end
		self._movePos = nil
		local janitor = Janitor.new()
		self._activeJanitor = janitor

		janitor:Add(
			RunService.Heartbeat:Connect(LPH_JIT_MAX(function(dt: number): ()
				if peek(flightState.enabled) then
					self._movePos = nil
					return
				end

				local parts = peek(clientState.parts)
				local hrp = parts.HumanoidRootPart :: any
				if not hrp then
					self._movePos = nil
					return
				end

				if ClientController.IsClimbing() then
					self._movePos = nil
					return
				end

				local boostFactor = self._boost / 100
				if boostFactor <= 0 then
					self._movePos = nil
					return
				end

				local wishDir = strafeShared.computeWishDir()
				if wishDir.Magnitude < 0.001 then
					self._movePos = nil
					return
				end

				local character = ClientController.GetCharacterObject()
				if not character then
					self._movePos = nil
					return
				end

				local hrpPos = hrp.Position
				local pos = self._movePos
				if not pos then
					pos = hrpPos
				else
					local diff = pos - hrpPos
					if diff.Magnitude > MAX_DRIFT then
						pos = hrpPos + diff.Unit * MAX_DRIFT
					end
				end

				local clamped = math.min(dt, MAX_DT)
				local moveSpeed = boostFactor * BOOST_STUDS_PER_SECOND
				character.Humanoid.WalkSpeed = 0
				hrp.AssemblyLinearVelocity =
					Vector3.new(wishDir.X * moveSpeed, hrp.AssemblyLinearVelocity.Y, wishDir.Z * moveSpeed)
				pos = Vector3.new(
					pos.X + wishDir.X * moveSpeed * clamped,
					hrpPos.Y,
					pos.Z + wishDir.Z * moveSpeed * clamped
				)
				self._movePos = pos
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

function Speed.Destroy(self: Speed): ()
	self:_setEnabled(false)
	BaseFeature.Destroy(self)
end

export type Speed =
	typeof(setmetatable(
		{} :: {
			_boost: number,
			_activeJanitor: Janitor.Janitor?,
			_movePos: Vector3?,
			_setEnabled: (Speed, boolean) -> (),
		},
		Speed
	))
	& BaseFeature.BaseFeature

return Speed
