local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local clientState = require("@game/mvsd/client/clientState")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local Camera = Workspace.CurrentCamera

local MAX_DT = 0.05
local MIN_UPWARD_SPEED = 2.5

local peek = Charm.peek

local Flight = {}
Flight.__index = Flight

setmetatable(Flight, { __index = BaseFeature })

local computeWishDir = LPH_NO_VIRTUALIZE(function(goingDown: boolean): (Vector3, number)
	local cf = Camera.CFrame
	local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local flatRight = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)

	local wish = Vector3.zero
	if flatLook.Magnitude > 0.001 and flatRight.Magnitude > 0.001 then
		flatLook = flatLook.Unit
		flatRight = flatRight.Unit

		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			wish += flatLook
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			wish -= flatLook
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			wish += flatRight
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			wish -= flatRight
		end
	end

	local vert = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		vert += 1
	end
	if goingDown then
		vert -= 1
	end

	local flat = (wish.Magnitude > 0.001 and wish.Unit or Vector3.zero)
	return flat, vert
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
	optionsLink:Slider("speed", "Speed", 50, 1, 200, 1, nil, " st/s"):SetTip({
		title = "Speed",
		body = "Flight speed in studs per second.",
	})
	local downKey = optionsLink:Key("downKey", "Fly Down", Enum.KeyCode.LeftControl):SetMode("onHold"):SetTip({
		title = "Fly Down",
		body = "Key to fly down.",
	})

	self._speed = 50
	self._goingDown = false
	self._activeJanitor = nil :: Janitor.Janitor?

	self:Track(link:Get("flight"):OnChange(function(value: boolean)
		self:_setEnabled(value)
	end))

	self:Track(link:Watch("flight.opts.speed", function(value: number)
		self._speed = value
	end))

	self:Track(downKey:OnCallback(function(active: boolean)
		self._goingDown = active
	end))

	if link:Peek("flight") then
		self:_setEnabled(true)
	end

	return self
end

function Flight._setEnabled(self: Flight, enabled: boolean): ()
	if enabled then
		if self._activeJanitor then
			return
		end
		local janitor = Janitor.new()
		self._activeJanitor = janitor

		janitor:Add(
			RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
				if not peek(clientState.alive) then
					return
				end

				local hrp = peek(clientState.hrp)
				if not hrp then
					return
				end

				local clamped = math.min(dt, MAX_DT)
				local moveSpeed = self._speed
				local step = moveSpeed * clamped
				local flatDir, vert = computeWishDir(self._goingDown)

				if flatDir.Magnitude < 0.001 and vert == 0 then
					hrp.AssemblyLinearVelocity = Vector3.zero
					return
				end

				local ySpeed = vert * moveSpeed
				if vert > 0 then
					ySpeed = math.max(ySpeed, MIN_UPWARD_SPEED)
				end

				hrp.AssemblyLinearVelocity = Vector3.new(flatDir.X * moveSpeed, ySpeed, flatDir.Z * moveSpeed)

				local offset = flatDir * step + Vector3.new(0, vert * step, 0)
				if offset.Magnitude > 0.001 then
					hrp.CFrame = hrp.CFrame + offset
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
		},
		Flight
	))
	& BaseFeature.BaseFeature

return Flight
