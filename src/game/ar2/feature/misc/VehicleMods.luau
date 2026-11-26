local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")

local RunService = cloneref(game:GetService("RunService")) :: RunService

local robloxRequire = getrenv().require

local ACCEL_MAX = 5
local SPEED_MAX = 4
local GRIP_MAX = 3
local HANDLING_MAX = 3
local TURN_MAX = 1.5
local MAX_PITCH = math.rad(55)
local UPRIGHT_DOT = math.cos(math.rad(60))
local FULL_WHEEL_HEALTH = Vector2.new(1, 1)

local VehicleMods = {}
VehicleMods.__index = VehicleMods

setmetatable(VehicleMods, { __index = BaseFeature })

local function requireConfig(vehicle: Instance): any
	local config = vehicle:FindFirstChild("Config")
	if not config then
		return nil
	end
	local old = getthreadidentity()
	setthreadidentity(2)
	local result = robloxRequire(config)
	setthreadidentity(old)
	return result
end

local function snapshot(physics: any): any
	local orig = {
		DriveSpeed = physics.DriveSpeed,
		ReverseSpeed = physics.ReverseSpeed,
		ThrottleResponce = physics.ThrottleResponce,
		SteerResponce = physics.SteerResponce,
		NoSteeringAfter = physics.NoSteeringAfter,
		wheels = {},
		steerAngles = {},
	}
	if type(physics.Wheels) == "table" then
		for name, wheel in next, physics.Wheels do
			if type(wheel) == "table" then
				if type(wheel.Friction) == "number" then
					orig.wheels[name] = wheel.Friction
				end
				if type(wheel.SteerAngle) == "number" then
					orig.steerAngles[name] = wheel.SteerAngle
				end
			end
		end
	end
	return orig
end

function VehicleMods.new(link: gameUi.Linker): VehicleMods
	local self = BaseFeature.new() :: any
	setmetatable(self, VehicleMods)

	self._enabled = false
	self._conn = nil :: RBXScriptConnection?
	self._lpModule = nil :: any
	self._vehicle = nil :: Instance?
	self._base = nil :: BasePart?
	self._config = nil :: any
	self._orig = nil :: any
	self._wheelSpoofs = {} :: { any }

	link:Toggle("vehicleMods", "Vehicle Mods", false):SetTip({
		title = "Vehicle Mods",
		body = "Tunes the vehicle you are driving. Pick which mods to apply below.",
	})

	local masterLink = link:OnKey("vehicleMods")
	masterLink:Submenu("opts", "Vehicle Mods")
	local opts = masterLink:OnKey("opts")

	opts:Slider("accelAmt", "Acceleration", 50, 0, 100, 5, nil, "%"):SetTip({
		title = "Acceleration",
		body = "Throttle punch off the line. 0 turns it off.",
	})
	opts:Slider("topSpeedAmt", "Top Speed", 50, 0, 100, 5, nil, "%"):SetTip({
		title = "Top Speed",
		body = "Top speed, forward and reverse. 0 turns it off.",
	})
	opts:Slider("gripAmt", "Grip", 50, 0, 100, 5, nil, "%"):SetTip({
		title = "Grip",
		body = "Tyre grip for less sliding. 0 turns it off.",
	})
	opts:Slider("handlingAmt", "Handling", 50, 0, 100, 5, nil, "%"):SetTip({
		title = "Handling",
		body = "Sharper steering and full control at speed. 0 turns it off.",
	})
	opts:Slider("turnAmt", "Turn Speed", 50, 0, 100, 5, nil, "%"):SetTip({
		title = "Turn Speed",
		body = "Turns the wheels harder for tighter corners. 0 turns it off.",
	})
	opts:Toggle("ignoreTireDamage", "Ignore Tire Damage", true):SetTip({
		title = "Ignore Tire Damage",
		body = "Drives the same even with broken or shot-out tyres.",
	})
	opts:Toggle("antiFlip", "Anti Flip", true):SetTip({
		title = "Anti Flip",
		body = "Keeps the vehicle upright and rights it if it rolls over.",
	})

	self._accelMult = tonumber(opts:Peek("accelAmt")) or 50
	self._topSpeedMult = tonumber(opts:Peek("topSpeedAmt")) or 50
	self._gripMult = tonumber(opts:Peek("gripAmt")) or 50
	self._handlingMult = tonumber(opts:Peek("handlingAmt")) or 50
	self._turnMult = tonumber(opts:Peek("turnAmt")) or 50
	self._ignoreTireDamage = opts:Peek("ignoreTireDamage") == true
	self._antiFlip = opts:Peek("antiFlip") == true

	self:Track(opts:Get("accelAmt"):OnChange(function(value: number): ()
		self._accelMult = tonumber(value) or 0
	end))
	self:Track(opts:Get("topSpeedAmt"):OnChange(function(value: number): ()
		self._topSpeedMult = tonumber(value) or 0
	end))
	self:Track(opts:Get("gripAmt"):OnChange(function(value: number): ()
		self._gripMult = tonumber(value) or 0
	end))
	self:Track(opts:Get("handlingAmt"):OnChange(function(value: number): ()
		self._handlingMult = tonumber(value) or 0
	end))
	self:Track(opts:Get("turnAmt"):OnChange(function(value: number): ()
		self._turnMult = tonumber(value) or 0
	end))
	self:Track(opts:Get("ignoreTireDamage"):OnChange(function(value: boolean): ()
		self._ignoreTireDamage = value == true
	end))
	self:Track(opts:Get("antiFlip"):OnChange(function(value: boolean): ()
		self._antiFlip = value == true
	end))

	self:Track(link:Get("vehicleMods"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("vehicleMods") then
		self:Enable()
	end

	return self
end

VehicleMods._apply = LPH_NO_VIRTUALIZE(function(self: VehicleMods): ()
	local physics = self._config and self._config.Physics
	local orig = self._orig
	if type(physics) ~= "table" or type(orig) ~= "table" then
		return
	end

	local accelMult: number = self._accelMult
	local topSpeedMult: number = self._topSpeedMult
	local gripMult: number = self._gripMult
	local handlingMult: number = self._handlingMult
	local turnMult: number = self._turnMult

	local topSpeed = 1 + topSpeedMult / 100 * SPEED_MAX
	if type(orig.DriveSpeed) == "number" then
		physics.DriveSpeed = orig.DriveSpeed * topSpeed
	end
	if type(orig.ReverseSpeed) == "number" then
		physics.ReverseSpeed = orig.ReverseSpeed * topSpeed
	end

	if type(orig.ThrottleResponce) == "number" then
		physics.ThrottleResponce = orig.ThrottleResponce * (1 + accelMult / 100 * ACCEL_MAX)
	end

	if type(orig.SteerResponce) == "number" then
		physics.SteerResponce = orig.SteerResponce * (1 + handlingMult / 100 * HANDLING_MAX)
	end
	if type(orig.NoSteeringAfter) == "number" then
		physics.NoSteeringAfter = handlingMult > 0 and math.max(orig.NoSteeringAfter, 1e6) or orig.NoSteeringAfter
	end

	local grip = 1 + gripMult / 100 * GRIP_MAX
	local turn = 1 + turnMult / 100 * TURN_MAX
	if type(physics.Wheels) == "table" then
		for name, wheel in next, physics.Wheels do
			if type(wheel) == "table" then
				local friction = orig.wheels[name]
				if friction then
					wheel.Friction = friction * grip
				end
				local steer = orig.steerAngles[name]
				if steer then
					wheel.SteerAngle = steer * turn
				end
			end
		end
	end
end)

function VehicleMods._restore(self: VehicleMods): ()
	local physics = self._config and self._config.Physics
	local orig = self._orig
	if type(physics) == "table" and type(orig) == "table" then
		physics.DriveSpeed = orig.DriveSpeed
		physics.ReverseSpeed = orig.ReverseSpeed
		physics.ThrottleResponce = orig.ThrottleResponce
		physics.SteerResponce = orig.SteerResponce
		physics.NoSteeringAfter = orig.NoSteeringAfter
		if type(physics.Wheels) == "table" then
			for name, wheel in next, physics.Wheels do
				if type(wheel) == "table" then
					if orig.wheels[name] then
						wheel.Friction = orig.wheels[name]
					end
					if orig.steerAngles[name] then
						wheel.SteerAngle = orig.steerAngles[name]
					end
				end
			end
		end
	end
	self._vehicle = nil
	self._base = nil
	self._config = nil
	self._orig = nil
	table.clear(self._wheelSpoofs)
end

VehicleMods._step = LPH_NO_VIRTUALIZE(function(self: VehicleMods): ()
	local module = self._lpModule
	local arLocalPlayer = module and module.module.get()
	local character = arLocalPlayer and arLocalPlayer.Character
	if not character or not character.Sitting or not character.IsVehicleDriver then
		if self._vehicle then
			self:_restore()
		end
		return
	end

	local vehicle = character.Vehicle
	if not vehicle then
		if self._vehicle then
			self:_restore()
		end
		return
	end

	if vehicle ~= self._vehicle then
		self:_restore()
		local config = requireConfig(vehicle)
		if type(config) ~= "table" or type(config.Physics) ~= "table" then
			return
		end
		self._vehicle = vehicle
		self._base = vehicle:FindFirstChild("Base") :: BasePart?
		self._config = config
		self._orig = snapshot(config.Physics)
		self:_cacheWheels(vehicle)
	end

	self:_apply()

	if self._ignoreTireDamage then
		self:_spoofWheels()
	end

	if self._antiFlip then
		self:_antiFlipStep()
	end
end)

function VehicleMods._cacheWheels(self: VehicleMods, vehicle: Instance): ()
	local spoofs = self._wheelSpoofs
	table.clear(spoofs)
	local wheels = vehicle:FindFirstChild("Wheels")
	if not wheels then
		return
	end
	local count = 0
	for _, wheel in next, wheels:GetChildren() do
		local part = (wheel :: any).PrimaryPart
		if part then
			local attachment = part:FindFirstChild("Attachment")
			count += 1
			spoofs[count] = {
				part = part,
				attachment = attachment and attachment:IsA("Attachment") and attachment or nil,
			}
		end
	end
end

VehicleMods._antiFlipStep = LPH_NO_VIRTUALIZE(function(self: VehicleMods): ()
	local base = self._base
	if not base or not base.Parent then
		return
	end
	local cframe = base.CFrame
	if cframe.UpVector.Y >= UPRIGHT_DOT then
		return
	end
	local pitch, yaw = cframe:ToEulerAnglesYXZ()
	pitch = math.clamp(pitch, -MAX_PITCH, MAX_PITCH)
	base.CFrame = CFrame.new(cframe.Position) * CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
	local angular = base.AssemblyAngularVelocity
	base.AssemblyAngularVelocity = Vector3.new(0, angular.Y, 0)
end)

VehicleMods._spoofWheels = LPH_NO_VIRTUALIZE(function(self: VehicleMods): ()
	local spoofs = self._wheelSpoofs
	for i = 1, #spoofs do
		local entry = spoofs[i]
		entry.part:SetAttribute("Health", FULL_WHEEL_HEALTH)
		local attachment = entry.attachment
		if attachment then
			attachment.Orientation = Vector3.zero
		end
	end
end)

function VehicleMods.Enable(self: VehicleMods): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._lpModule = ModuleController.GetModule("LocalPlayer")

	self._conn = RunService.Heartbeat:Connect(function(): ()
		self:_step()
	end)
end

function VehicleMods.Disable(self: VehicleMods): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	self:_restore()
end

function VehicleMods.Destroy(self: VehicleMods): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type VehicleMods =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_conn: RBXScriptConnection?,
			_lpModule: any,
			_vehicle: Instance?,
			_base: BasePart?,
			_config: any,
			_orig: any,
			_wheelSpoofs: { any },
			_accelMult: number,
			_topSpeedMult: number,
			_gripMult: number,
			_handlingMult: number,
			_turnMult: number,
			_ignoreTireDamage: boolean,
			_antiFlip: boolean,
		},
		VehicleMods
	))
	& BaseFeature.BaseFeature

return VehicleMods
