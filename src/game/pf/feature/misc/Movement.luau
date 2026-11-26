local RunService = cloneref(game:GetService("RunService")) :: RunService

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/pf/module/ModuleController")
local NetworkController = require("@game/pf/network/NetworkController")
local repupdateBypass = require("@game/pf/network/repupdateBypass")

local FLY_ENABLED = false
local JUMP_HEIGHT = 3.3

local roundSystem: any = nil

local computeGameSpeed = LPH_NO_VIRTUALIZE(function(co: any, root: BasePart): number
	if not roundSystem then
		roundSystem = ModuleController.GetModule("RoundSystemClientInterface")
	end
	if roundSystem and rawget(roundSystem, "roundLock") then
		return 0
	end
	local base = co._walkSpeedMult * co._baseWalkSpeed
	local speed
	if co._sprinting then
		speed = 1.5 * base
	elseif co._movementMode == "prone" then
		speed = base / 4
	elseif co._movementMode == "crouch" then
		speed = base / 2
	else
		speed = base
	end
	local localDir = root.CFrame:VectorToObjectSpace(co:getMovementDirection())
	local mag = localDir.Magnitude
	if mag > 0.0001 then
		speed *= co._backSpeedMult + (1 - co._backSpeedMult) * (1 - localDir.Z / mag) / 2
	end
	return speed
end)

local Movement = {}
Movement.__index = Movement

setmetatable(Movement, { __index = BaseFeature })

function Movement.new(link: gameUi.Linker): Movement
	local self = BaseFeature.new() :: any
	setmetatable(self, Movement)

	self._fallUnhook = nil :: (() -> ())?
	self._tickConn = nil :: RBXScriptConnection?
	self._noJumpCooldown = false
	self._instantVelocity = false
	self._airControl = false
	self._bunnyhop = false
	self._fly = false
	self._flyMult = 5
	self._flyUp = false
	self._flyDown = false
	self._ci = nil :: any
	self._abi = nil :: any

	link:Toggle("noJumpCooldown", "No Jump Cooldown", false):SetTip({
		title = "No Jump Cooldown",
		body = "Jump again without waiting.",
	})
	link:Toggle("noFallDamage", "No Fall Damage", false):SetTip({
		title = "No Fall Damage",
		body = "Take no damage from falling.",
	})
	link:Toggle("instantVelocity", "Instant Velocity", false):SetTip({
		title = "Instant Velocity",
		body = "Reach full speed and stop instantly with no slide.",
	})
	link:Toggle("airControl", "Air Control", false):SetTip({
		title = "Air Control",
		body = "Steer your movement freely while in the air.",
	})
	link:Toggle("bunnyhop", "Bunnyhop", false):SetTip({
		title = "Bunnyhop",
		body = "Jump again the instant you land while holding jump.",
	})

	self:Track(link:Get("noFallDamage"):OnChange(function(value: boolean): ()
		self:_setNoFall(value == true)
	end))
	self:Track(link:Get("noJumpCooldown"):OnChange(function(value: boolean): ()
		self:_setNoJumpCooldown(value == true)
	end))
	self:Track(link:Get("instantVelocity"):OnChange(function(value: boolean): ()
		self:_setInstantVelocity(value == true)
	end))
	self:Track(link:Get("airControl"):OnChange(function(value: boolean): ()
		self:_setAirControl(value == true)
	end))
	self:Track(link:Get("bunnyhop"):OnChange(function(value: boolean): ()
		self:_setBunnyhop(value == true)
	end))

	self:_setNoFall(link:Peek("noFallDamage") == true)
	self:_setNoJumpCooldown(link:Peek("noJumpCooldown") == true)
	self:_setInstantVelocity(link:Peek("instantVelocity") == true)
	self:_setAirControl(link:Peek("airControl") == true)
	self:_setBunnyhop(link:Peek("bunnyhop") == true)

	if FLY_ENABLED then
		link:Toggle("fly", "Fly", false):SetTip({
			title = "Fly",
			body = "Move freely in any direction. Jump to rise, crouch to descend.",
		})
		local flyLink = link:OnKey("fly")
		flyLink:Submenu("opts", "Fly")
		local flyOpts = flyLink:OnKey("opts")
		flyOpts:Slider("speed", "Fly Speed", 5, 1, 25, 0.1, nil, "x"):SetTip({
			title = "Fly Speed",
			body = "How fast you move while flying.",
		})
		local flyUpKey = flyOpts:Key("upKey", "Fly Up", Enum.KeyCode.Space):SetMode("onHold"):SetTip({
			title = "Fly Up",
			body = "Key to fly up.",
		})
		local flyDownKey = flyOpts:Key("downKey", "Fly Down", Enum.KeyCode.LeftControl):SetMode("onHold"):SetTip({
			title = "Fly Down",
			body = "Key to fly down.",
		})

		self._flyMult = link:Peek("fly.opts.speed") or 5

		self:Track(link:Get("fly"):OnChange(function(value: boolean): ()
			self:_setFly(value == true)
		end))
		self:Track(link:Watch("fly.opts.speed", function(value: number): ()
			self._flyMult = type(value) == "number" and value or 5
		end))
		self:Track(flyUpKey:OnCallback(function(active: boolean): ()
			self._flyUp = active == true
		end))
		self:Track(flyDownKey:OnCallback(function(active: boolean): ()
			self._flyDown = active == true
		end))

		self:_setFly(link:Peek("fly") == true)

		--[[
		NetworkController.HookInbound("correctposition", function(newPosition)
			ToastController.Push({
				text = `correctposition {newPosition.X} {newPosition.Y} {newPosition.Z}`,
				duration = 2,
			})

			return false
		end)
		--]]
	end

	return self
end

function Movement._setNoFall(self: Movement, on: boolean): ()
	local unhook = self._fallUnhook
	if on then
		if unhook then
			return
		end
		self._fallUnhook = NetworkController.HookOutbound(
			"falldamage",
			LPH_NO_VIRTUALIZE(function(): boolean
				return false
			end)
		)
	elseif unhook then
		unhook()
		self._fallUnhook = nil
	end
end

Movement._tick = LPH_NO_VIRTUALIZE(function(self: Movement): ()
	local ci = self._ci or ModuleController.GetModule("CharacterInterface")
	if not ci then
		return
	end
	self._ci = ci
	local co = ci.getCharacterObject()
	if not co then
		return
	end

	if self._noJumpCooldown then
		co._lastJumpTime = 0
	end

	local instantVelocity = self._instantVelocity
	local airControl = self._airControl
	local bunnyhop = self._bunnyhop
	local fly = self._fly

	local grounded = (instantVelocity or airControl or bunnyhop) and co:isGrounded() or false
	local vaulting = (instantVelocity or airControl or fly) and co:isVaulting() or false

	if instantVelocity and grounded and not vaulting and not co._sliding then
		local root = co:getRealRootPart()
		if root then
			local dir = co:getMovementDirection()
			local speed = computeGameSpeed(co, root)
			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, velocity.Y, dir.Z * speed)
		end
	end

	if airControl and not grounded and not vaulting then
		local root = co:getRealRootPart()
		if root then
			local dir = co:getMovementDirection()
			local speed = computeGameSpeed(co, root)
			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, velocity.Y, dir.Z * speed)
		end
	end

	if bunnyhop and grounded then
		local abi = self._abi or ModuleController.GetModule("ActionBindInterface")
		if abi then
			self._abi = abi
			if abi.isInputActionDown("Jump") then
				co:jump(JUMP_HEIGHT)
			end
		end
	end

	if fly and not vaulting then
		co._walkSpeedMult = self._flyMult
		co:updateWalkSpeed()
		local root = co:getRealRootPart()
		if root then
			local humanoid = co._humanoid
			local speed = (humanoid and humanoid.WalkSpeed) or (14 * self._flyMult)
			local vertical = 0
			if self._flyUp then
				vertical += 1
			end
			if self._flyDown then
				vertical -= 1
			end
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, vertical * speed, v.Z)
		end
	end
end)

function Movement._syncTick(self: Movement): ()
	local needed = self._noJumpCooldown
		or self._instantVelocity
		or self._airControl
		or self._bunnyhop
		or self._fly
	if needed then
		if not self._tickConn then
			self._tickConn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
				self:_tick()
			end))
		end
	elseif self._tickConn then
		self._tickConn:Disconnect()
		self._tickConn = nil
	end
end

function Movement._setNoJumpCooldown(self: Movement, on: boolean): ()
	self._noJumpCooldown = on
	self:_syncTick()
end

function Movement._setInstantVelocity(self: Movement, on: boolean): ()
	self._instantVelocity = on
	self:_syncTick()
end

function Movement._setAirControl(self: Movement, on: boolean): ()
	self._airControl = on
	self:_syncTick()
end

function Movement._setBunnyhop(self: Movement, on: boolean): ()
	self._bunnyhop = on
	self:_syncTick()
end

function Movement._setFly(self: Movement, on: boolean): ()
	if not FLY_ENABLED then
		return
	end
	if on then
		if self._fly then
			return
		end
		self._fly = true
		self:_syncTick()
		repupdateBypass.acquire()
	else
		self._fly = false
		self:_syncTick()
		repupdateBypass.release()
		local ci = self._ci or ModuleController.GetModule("CharacterInterface")
		if ci then
			local co = ci.getCharacterObject()
			if co then
				co._walkSpeedMult = 1
				co:updateWalkSpeed()
			end
		end
	end
end

function Movement.Destroy(self: Movement): ()
	self:_setNoFall(false)
	self:_setNoJumpCooldown(false)
	self:_setInstantVelocity(false)
	self:_setAirControl(false)
	self:_setBunnyhop(false)
	self:_setFly(false)
	self._ci = nil
	self._abi = nil
	BaseFeature.Destroy(self)
end

export type Movement =
	typeof(setmetatable(
		{} :: {
			_fallUnhook: (() -> ())?,
			_tickConn: RBXScriptConnection?,
			_noJumpCooldown: boolean,
			_instantVelocity: boolean,
			_airControl: boolean,
			_bunnyhop: boolean,
			_fly: boolean,
			_flyMult: number,
			_flyUp: boolean,
			_flyDown: boolean,
			_ci: any,
			_abi: any,
			_tick: (Movement) -> (),
			_syncTick: (Movement) -> (),
			_setNoFall: (Movement, boolean) -> (),
			_setNoJumpCooldown: (Movement, boolean) -> (),
			_setInstantVelocity: (Movement, boolean) -> (),
			_setAirControl: (Movement, boolean) -> (),
			_setBunnyhop: (Movement, boolean) -> (),
			_setFly: (Movement, boolean) -> (),
		},
		Movement
	))
	& BaseFeature.BaseFeature

return Movement
