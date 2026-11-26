local RunService = cloneref(game:GetService("RunService")) :: RunService
local clientState = require("@game/bloxstrike/client/clientState")
local ClientController = require("@game/bloxstrike/client/ClientController")
local moveController = require("@game/bloxstrike/client/moveController")
local flightState = require("@game/bloxstrike/feature/misc/flightState")
local strafeShared = require("@game/bloxstrike/feature/misc/strafeShared")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local TAU = math.pi * 2
local ALIGN_EPSILON = 0.01
local MIN_SPEED_SQ = 1
local WISH_CAP = 2.5

local peek = Charm.peek

local function rateFromSmoothness(value: number): number
	return 8 - (value / 100) * 7
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
	self._touched = false
	self._activeJanitor = nil :: Janitor.Janitor?

	self:Track(link:Get("directionalStrafe"):OnChange(function(value: boolean)
		self:_setEnabled(value)
	end))

	self:Track(link:Watch("directionalStrafe.opts.smoothness", function(value: number)
		self._turnRate = rateFromSmoothness(value)
	end))

	return self
end

function DirectionalStrafe._restore(self: DirectionalStrafe): ()
	if not self._touched then
		return
	end
	self._touched = false
	local controller = moveController.getActive()
	if controller then
		controller.moveVector = moveController.realMoveVector(controller)
	end
end

function DirectionalStrafe._setEnabled(self: DirectionalStrafe, enabled: boolean): ()
	if enabled then
		if self._activeJanitor then
			return
		end
		local janitor = Janitor.new()
		self._activeJanitor = janitor

		janitor:Add(
			RunService.Stepped:Connect(LPH_NO_VIRTUALIZE(function(_: number, dt: number): ()
				if peek(flightState.enabled) then
					self:_restore()
					return
				end

				local parts = peek(clientState.parts)
				local hrp = parts.HumanoidRootPart :: any
				local humanoid = parts.Humanoid :: any
				if not hrp or not strafeShared.isAirborne(humanoid) then
					self:_restore()
					return
				end

				if ClientController.IsClimbing() then
					self:_restore()
					return
				end

				local charObj = ClientController.GetCharacterObject()
				if not charObj or rawget(charObj, "IsJumping") ~= true then
					self:_restore()
					return
				end

				local vel = hrp.AssemblyLinearVelocity
				local vx = vel.X
				local vz = vel.Z
				local speedSq = vx * vx + vz * vz
				if speedSq < MIN_SPEED_SQ then
					self:_restore()
					return
				end

				local controller = moveController.getActive()
				if not controller then
					self:_restore()
					return
				end

				local wish = strafeShared.computeWishDir()
				if wish == Vector3.zero then
					self:_restore()
					return
				end

				local speed = math.sqrt(speedSq)
				local angVel = math.atan2(vz, vx)
				local angWish = math.atan2(wish.Z, wish.X)
				local delta = ((angWish - angVel + math.pi) % TAU) - math.pi
				local absDelta = delta >= 0 and delta or -delta
				if absDelta < ALIGN_EPSILON then
					self:_restore()
					return
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
				controller.moveVector = moveController.worldToMoveVector(steered)
				self._touched = true
			end)),
			"Disconnect"
		)
		janitor:Add(function(): ()
			self:_restore()
		end)
	else
		local janitor = self._activeJanitor
		if not janitor then
			return
		end
		self._activeJanitor = nil
		janitor:Destroy()
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
			_touched: boolean,
			_activeJanitor: Janitor.Janitor?,
			_restore: (DirectionalStrafe) -> (),
			_setEnabled: (DirectionalStrafe, boolean) -> (),
		},
		DirectionalStrafe
	))
	& BaseFeature.BaseFeature

return DirectionalStrafe
