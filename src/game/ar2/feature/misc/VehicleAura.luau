local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local PlayerController = require("@feature/player/PlayerController")
local clientState = require("@game/ar2/client/clientState")

local RunService = cloneref(game:GetService("RunService")) :: RunService

local peek = Charm.peek

local TORSO_PARTS = { "HumanoidRootPart", "UpperTorso", "LowerTorso" }
local AURA_INTERVAL = 0.3

local VehicleAura = {}
VehicleAura.__index = VehicleAura

setmetatable(VehicleAura, { __index = BaseFeature })

local gatherTouchParts = LPH_NO_VIRTUALIZE(function(vehicle: Instance, out: { BasePart }): ()
	table.clear(out)
	local count = 0
	for _, desc in next, vehicle:QueryDescendants("BasePart") do
		if desc:FindFirstChildOfClass("TouchTransmitter") then
			count += 1
			out[count] = desc
		end
	end
	if count == 0 then
		local base = vehicle:FindFirstChild("Base")
		if base and base:IsA("BasePart") then
			out[1] = base
		end
	end
end)

local step = LPH_NO_VIRTUALIZE(function(self: VehicleAura): ()
	if not peek(clientState.alive) then
		return
	end

	local module = self._lpModule
	local arLocalPlayer = module and module.module.get()
	local character = arLocalPlayer and arLocalPlayer.Character
	if not character or not character.Sitting or not character.IsVehicleDriver then
		self._vehicle = nil
		self._base = nil
		return
	end

	local vehicle = character.Vehicle
	if not vehicle then
		self._vehicle = nil
		self._base = nil
		return
	end

	if vehicle ~= self._vehicle then
		self._vehicle = vehicle
		self._base = vehicle:FindFirstChild("Base") :: BasePart?
		gatherTouchParts(vehicle, self._touchParts)
	end

	local touchParts = self._touchParts
	local touchCount = #touchParts
	if touchCount == 0 then
		return
	end

	local base = self._base
	if not base then
		return
	end

	local origin = base.Position
	local range = self._range

	for _, playerData in next, PlayerController.GetAll() do
		if not peek(playerData.alive) then
			continue
		end
		local hrp = peek(playerData.hrp) :: BasePart?
		if not hrp then
			continue
		end
		if (hrp.Position - origin).Magnitude > range then
			continue
		end

		local parts = peek(playerData.parts)
		for _, name in next, TORSO_PARTS do
			local torso = parts[name] :: BasePart?
			if not torso then
				continue
			end
			for index = 1, touchCount do
				local vehiclePart = touchParts[index]
				firetouchinterest(torso, vehiclePart, 0)
				firetouchinterest(torso, vehiclePart, 1)
			end
		end
	end
end)

function VehicleAura.new(link: gameUi.Linker): VehicleAura
	local self = BaseFeature.new() :: any
	setmetatable(self, VehicleAura)

	self._enabled = false
	self._range = 30
	self._lpModule = nil :: any
	self._vehicle = nil :: Instance?
	self._base = nil :: BasePart?
	self._touchParts = {} :: { BasePart }
	self._accum = 0
	self._conn = nil :: RBXScriptConnection?

	link:Toggle("vehicleAura", "Vehicle Aura", false):SetTip({
		title = "Vehicle Aura",
		body = "Hits nearby players while you drive.",
	})

	local masterLink = link:OnKey("vehicleAura")
	masterLink:Submenu("opts", "Vehicle Aura")
	local optsLink = masterLink:OnKey("opts")

	optsLink:Slider("range", "Range", 30, 10, 30, 5, nil, "st"):SetTip({
		title = "Range",
		body = "How far around the vehicle players get hit.",
	})

	self:Track(link:Watch("vehicleAura.opts.range", function(v: any): ()
		self._range = tonumber(v) or 30
	end))
	self._range = tonumber(link:Peek("vehicleAura.opts.range")) or 30

	self:Track(link:Get("vehicleAura"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("vehicleAura") then
		self:Enable()
	end

	return self
end

function VehicleAura.Enable(self: VehicleAura): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._lpModule = ModuleController.GetModule("LocalPlayer")
	self._vehicle = nil
	self._base = nil
	self._accum = 0
	table.clear(self._touchParts)

	self._conn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
		self._accum += dt
		if self._accum < AURA_INTERVAL then
			return
		end
		self._accum -= AURA_INTERVAL
		step(self)
	end))
end

function VehicleAura.Disable(self: VehicleAura): ()
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
	table.clear(self._touchParts)
end

function VehicleAura.Destroy(self: VehicleAura): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type VehicleAura =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_range: number,
			_lpModule: any,
			_vehicle: Instance?,
			_base: BasePart?,
			_touchParts: { BasePart },
			_accum: number,
			_conn: RBXScriptConnection?,
		},
		VehicleAura
	))
	& BaseFeature.BaseFeature

return VehicleAura
