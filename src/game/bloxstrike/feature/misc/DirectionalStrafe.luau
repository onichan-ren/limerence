local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage
local ClientController = require("@game/bloxstrike/client/ClientController")
local flightState = require("@game/bloxstrike/feature/misc/flightState")
local strafeShared = require("@game/bloxstrike/feature/misc/strafeShared")
local BaseFeature = require("@game/BaseFeature")
local Hook = require("@share/hook")
local gameUi = require("@game/gameUi")
local Charm = require("@pkg/Charm")

local TAU = math.pi * 2
local ALIGN_EPSILON = 0.01
local MIN_SPEED_SQ = 1
local WISH_CAP = 2.5

local peek = Charm.peek

local function rateFromSmoothness(value: number): number
	return 8 - (value / 100) * 7
end

local function worldToCmdMove(worldDir: Vector3, yaw: number): Vector2
	local c = math.cos(yaw)
	local s = math.sin(yaw)
	return Vector2.new(c * worldDir.X - s * worldDir.Z, s * worldDir.X + c * worldDir.Z)
end

local DirectionalStrafe = {}
DirectionalStrafe.__index = DirectionalStrafe

setmetatable(DirectionalStrafe, { __index = BaseFeature })

function DirectionalStrafe.new(link: gameUi.Linker): DirectionalStrafe
	local self = BaseFeature.new() :: any
	setmetatable(self, DirectionalStrafe)

	link:Toggle("directionalStrafe", "Directional Strafe", false):SetTip({
		title = "Directional Strafe",
		body = "Steers your air movement toward your keys so turns carve smoothly without losing speed.",
	})
	local strafeLink = link:OnKey("directionalStrafe")
	strafeLink:Submenu("opts", "Directional Strafe")
	local optionsLink = strafeLink:OnKey("opts")
	optionsLink:Slider("smoothness", "Smoothness", 50, 0, 100, 1, nil, "%"):SetTip({
		title = "Smoothness",
		body = "Higher carves a wider, gentler arc and keeps more speed. Lower turns tighter.",
	})

	self._turnRate = rateFromSmoothness(50)
	self._sampleFn = nil :: any
	self._lastTime = os.clock()

	self:Track(link:Get("directionalStrafe"):OnChange(function(value: boolean)
		self:_setEnabled(value)
	end))

	self:Track(link:Watch("directionalStrafe.opts.smoothness", function(value: number)
		self._turnRate = rateFromSmoothness(value)
	end))

	return self
end

function DirectionalStrafe._setEnabled(self: DirectionalStrafe, enabled: boolean): ()
	if enabled then
		if self._sampleFn then
			return
		end
		local classesFolder = ReplicatedStorage:FindFirstChild("Classes")
		local charModule = classesFolder and classesFolder:FindFirstChild("Character")
		if not charModule then
			return
		end
		local ok, charClass = pcall(require, charModule :: ModuleScript)
		local sampleFn = ok and type(charClass) == "table" and rawget(charClass, "SampleInput")
		if type(sampleFn) ~= "function" then
			return
		end
		self._sampleFn = sampleFn
		self._lastTime = os.clock()

		local oldSample: any = nil
		oldSample = Hook.add(
			sampleFn,
			LPH_NO_VIRTUALIZE(function(charSelf: any, ...)
				local cmd = oldSample(charSelf, ...)
				local now = os.clock()
				local dt = math.clamp(now - self._lastTime, 0, 0.05)
				self._lastTime = now

				if type(cmd) ~= "table" or peek(flightState.enabled) or ClientController.IsClimbing() then
					return cmd
				end
				if not charSelf or charSelf.OnGround ~= false then
					return cmd
				end

				local vel = charSelf.GlobalVelocity
				if typeof(vel) ~= "Vector3" then
					return cmd
				end
				local vx = vel.X
				local vz = vel.Z
				local speedSq = vx * vx + vz * vz
				if speedSq < MIN_SPEED_SQ then
					return cmd
				end

				local wish = strafeShared.computeWishDir()
				if wish == Vector3.zero then
					return cmd
				end

				local speed = math.sqrt(speedSq)
				local angVel = math.atan2(vz, vx)
				local angWish = math.atan2(wish.Z, wish.X)
				local delta = ((angWish - angVel + math.pi) % TAU) - math.pi
				local absDelta = delta >= 0 and delta or -delta
				if absDelta < ALIGN_EPSILON then
					return cmd
				end

				local maxReach = WISH_CAP / speed
				if maxReach > 1 then
					maxReach = 1
				end
				local turn = self._turnRate * dt
				if turn > absDelta then
					turn = absDelta
				end
				local maxTurn = math.asin(maxReach)
				if turn > maxTurn then
					turn = maxTurn
				end

				local cosTheta = (WISH_CAP - speed * math.sin(turn)) / speed
				if cosTheta > 1 then
					cosTheta = 1
				elseif cosTheta < 0 then
					cosTheta = 0
				end
				local theta = math.acos(cosTheta)
				local ang = delta > 0 and angVel + theta or angVel - theta
				local steered = Vector3.new(math.cos(ang), 0, math.sin(ang))
				if type(cmd.LookYaw) == "number" then
					cmd.Move = worldToCmdMove(steered, cmd.LookYaw)
				end
				return cmd
			end)
		)
	else
		if self._sampleFn then
			Hook.restore(self._sampleFn)
			self._sampleFn = nil
		end
	end
end

function DirectionalStrafe.Destroy(self: DirectionalStrafe): ()
	self:_setEnabled(false)
	BaseFeature.Destroy(self)
end

export type DirectionalStrafe =
	typeof(setmetatable(
		{} :: {
			_turnRate: number,
			_sampleFn: any,
			_lastTime: number,
			_setEnabled: (DirectionalStrafe, boolean) -> (),
		},
		DirectionalStrafe
	))
	& BaseFeature.BaseFeature

return DirectionalStrafe
