local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Charm = require("@pkg/Charm")
local CommandBaseController = require("@game/overkill/weapon/CommandBaseController")
local antiAimState = require("@game/overkill/feature/antiaim/antiAimState")

local peek = Charm.peek

local TAU = math.pi * 2

local StrafeAssist = {}
StrafeAssist.__index = StrafeAssist

setmetatable(StrafeAssist, { __index = BaseFeature })

function StrafeAssist.new(link: gameUi.Linker): StrafeAssist
	local self = BaseFeature.new() :: any
	setmetatable(self, StrafeAssist)

	local toggle = link:Toggle("strafeAssist", "Strafe Assist", false):SetTip({
		title = "Strafe Assist",
		body = "Curves your air movement toward where you are already going so you keep more speed.",
	})
	local assistLink = link:OnKey("strafeAssist")
	assistLink:Submenu("opts", "Strafe Assist")
	local optsLink = assistLink:OnKey("opts")
	local smoothness = optsLink:Slider("smoothness", "Smoothness", 50, 0, 100, 1, nil, "%"):SetTip({
		title = "Smoothness",
		body = "Higher carves a wider, gentler arc and keeps more speed. Lower turns tighter.",
	})

	self._enabled = false
	self._installed = false
	self._leadRad = math.rad((1 - optsLink:Get("smoothness"):Peek() / 100) * 85 + 5)

	self:Track(toggle:OnChange(function(value: boolean): ()
		self._enabled = value
		if value then
			self:_install()
		end
	end))
	self:Track(smoothness:OnChange(function(value: number): ()
		self._leadRad = math.rad((1 - value / 100) * 85 + 5)
	end))

	if link:Peek("strafeAssist") then
		self._enabled = true
		self:_install()
	end

	return self
end

function StrafeAssist._install(self: StrafeAssist): ()
	if self._installed then
		return
	end
	self._installed = true

	self:Track(CommandBaseController.Register(LPH_NO_VIRTUALIZE(function(command: any, module: any): ()
		if type(command) ~= "table" or not self._enabled then
			return
		end

		local ix = command.x or 0
		local iz = command.z or 0
		if ix == 0 and iz == 0 then
			return
		end

		local localChickynoid = module and module.localChickynoid
		local simulation = localChickynoid and localChickynoid.simulation
		local state = simulation and simulation.state
		if type(state) ~= "table" then
			return
		end
		if simulation:HasCoyoteFloor() then
			return
		end

		local vel = state.vel
		local vx = vel.x
		local vz = vel.z
		if vx * vx + vz * vz < 1 then
			return
		end

		local offset = peek(antiAimState.yawOffset)
		if offset ~= 0 then
			local world = CFrame.fromEulerAnglesYXZ(0, -offset, 0) * Vector3.new(ix, 0, iz)
			ix = world.X
			iz = world.Z
		end

		local angVel = math.atan2(vz, vx)
		local angIn = math.atan2(iz, ix)
		local delta = ((angIn - angVel + math.pi) % TAU) - math.pi
		local lead = self._leadRad
		if delta > lead then
			delta = lead
		elseif delta < -lead then
			delta = -lead
		end

		local ang = angVel + delta
		local mag = math.sqrt(ix * ix + iz * iz)
		local ox = math.cos(ang) * mag
		local oz = math.sin(ang) * mag
		if offset ~= 0 then
			local fake = CFrame.fromEulerAnglesYXZ(0, offset, 0) * Vector3.new(ox, 0, oz)
			ox = fake.X
			oz = fake.Z
		end
		command.x = ox
		command.z = oz
	end)))
end

function StrafeAssist.Destroy(self: StrafeAssist): ()
	self._enabled = false
	BaseFeature.Destroy(self)
end

export type StrafeAssist =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_installed: boolean,
			_leadRad: number,
			_install: (StrafeAssist) -> (),
		},
		StrafeAssist
	))
	& BaseFeature.BaseFeature

return StrafeAssist
