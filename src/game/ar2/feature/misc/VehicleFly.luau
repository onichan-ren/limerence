local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local VehicleFly = {}
VehicleFly.__index = VehicleFly

setmetatable(VehicleFly, { __index = BaseFeature })

local step = LPH_NO_VIRTUALIZE(function(self: VehicleFly, arLocalPlayer: any): ()
	local character = arLocalPlayer.Character
	if not character or not (character.Sitting and character.IsVehicleDriver) then
		return
	end

	local vehicle = character.Vehicle
	if not vehicle then
		return
	end

	if vehicle ~= self._vehicle then
		self._vehicle = vehicle
		self._base = vehicle:FindFirstChild("Base")
		if self._base then
			local _, yaw = self._base.CFrame:ToEulerAnglesYXZ()
			self._lockedYaw = yaw
		end
	end

	local base = self._base
	if not base then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local camCF = camera.CFrame
	local move = character.MoveVector
	local dir = camCF.LookVector * -move.Z + camCF.RightVector * move.X

	local vertical = (self._ascending and 1 or 0) - (self._descending and 1 or 0)
	if vertical ~= 0 then
		dir += Vector3.new(0, vertical, 0)
	end

	base.CFrame = CFrame.new(base.Position) * CFrame.fromEulerAnglesYXZ(0, self._lockedYaw, 0)

	if dir.Magnitude > 0.05 then
		base.AssemblyLinearVelocity = dir.Unit * self._speed
	else
		base.AssemblyLinearVelocity = Vector3.zero
	end
	base.AssemblyAngularVelocity = Vector3.zero
end)

function VehicleFly.new(link: gameUi.Linker): VehicleFly
	local self = BaseFeature.new() :: any
	setmetatable(self, VehicleFly)

	self._enabled = false
	self._conn = nil :: RBXScriptConnection?
	self._vehicle = nil :: Instance?
	self._base = nil :: BasePart?
	self._lockedYaw = 0
	self._speed = 90
	self._ascending = false
	self._descending = false

	link:Toggle("vehicleFly", "Vehicle Fly", false):SetTip({
		title = "Vehicle Fly",
		body = "Lets your vehicle fly. Steer with your movement keys, rise and fall with the bound keys.",
	})

	local masterLink = link:OnKey("vehicleFly")
	masterLink:Submenu("opts", "Vehicle Fly")
	local optsLink = masterLink:OnKey("opts")

	optsLink:Slider("speed", "Speed", 90, 20, 90, 5):SetTip({
		title = "Speed",
		body = "How fast the vehicle moves while flying.",
	})

	local ascendKey = optsLink:Key("ascend", "Ascend", Enum.KeyCode.E, "onHold")
	local descendKey = optsLink:Key("descend", "Descend", Enum.KeyCode.Q, "onHold")

	self:Track(link:Watch("vehicleFly.opts.speed", function(v: any): ()
		self._speed = tonumber(v) or 90
	end))
	self._speed = tonumber(link:Peek("vehicleFly.opts.speed")) or 90

	self:Track(ascendKey:OnCallback(function(active: boolean): ()
		self._ascending = active
	end))
	self:Track(descendKey:OnCallback(function(active: boolean): ()
		self._descending = active
	end))

	self:Track(link:Get("vehicleFly"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("vehicleFly") then
		self:Enable()
	end

	return self
end

function VehicleFly.Enable(self: VehicleFly): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local playersModule = ModuleController.GetModule("LocalPlayer")
	if not playersModule then
		return
	end

	local arLocalPlayer = playersModule.module.get()

	self._conn = RunService.Heartbeat:Connect(function(): ()
		step(self, arLocalPlayer)
	end)
end

function VehicleFly.Disable(self: VehicleFly): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end

	self._vehicle = nil
	self._base = nil
end

function VehicleFly.Destroy(self: VehicleFly): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type VehicleFly =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_conn: RBXScriptConnection?,
			_vehicle: Instance?,
			_base: BasePart?,
			_lockedYaw: number,
			_speed: number,
			_ascending: boolean,
			_descending: boolean,
		},
		VehicleFly
	))
	& BaseFeature.BaseFeature

return VehicleFly
