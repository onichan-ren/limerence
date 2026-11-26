local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local WALK_SPEED = 16
local RUN_SPEED = 24

local FORWARD = Vector3.new(0, 0, -1)

local InventoryMove = {}
InventoryMove.__index = InventoryMove

setmetatable(InventoryMove, { __index = BaseFeature })

local function isDown(entry: any): boolean
	local key = entry and entry.Key
	if not key then
		return false
	end
	if key.EnumType == Enum.KeyCode then
		return UserInputService:IsKeyDown(key)
	end
	if key.EnumType == Enum.UserInputType then
		return UserInputService:IsMouseButtonPressed(key)
	end
	return false
end

local readMoveVector = LPH_NO_VIRTUALIZE(function(binds: any): (Vector3, boolean)
	local forward, backward, right, left, sprint = false, false, false, false, false
	if binds then
		forward = isDown(binds.MoveForwards)
		backward = isDown(binds.MoveBackwards)
		right = isDown(binds.MoveRight)
		left = isDown(binds.MoveLeft)
		sprint = isDown(binds.Sprint)
	end

	forward = forward or UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)
	backward = backward or UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)
	right = right or UserInputService:IsKeyDown(Enum.KeyCode.D)
	left = left or UserInputService:IsKeyDown(Enum.KeyCode.A)
	sprint = sprint or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)

	local z = (backward and 1 or 0) - (forward and 1 or 0)
	local x = (right and 1 or 0) - (left and 1 or 0)

	return Vector3.new(x, 0, z), sprint
end)

local clearShadow = LPH_NO_VIRTUALIZE(function(self: InventoryMove): ()
	local spring = self._spring
	if spring then
		spring.GetPosition = nil
		self._spring = nil
	end
end)

local applyShadow = LPH_NO_VIRTUALIZE(function(self: InventoryMove, spring: any): ()
	if self._spring == spring then
		return
	end
	clearShadow(self)
	self._spring = spring
	spring.GetPosition = function(): number
		return self._speed
	end
end)

local runUngated = LPH_NO_VIRTUALIZE(function(self: InventoryMove, action: () -> ()): ()
	local interface = self._interface
	local real = interface.IsVisible
	local hadRaw = rawget(interface, "IsVisible")

	interface.IsVisible = function(target: any, name: any, ...): any
		if name == "MainMenu" then
			return false
		end
		return real(target, name, ...)
	end

	action()

	if hadRaw == nil then
		interface.IsVisible = nil
	else
		interface.IsVisible = hadRaw
	end
end)

local step = LPH_JIT_MAX(function(self: InventoryMove, arLocalPlayer: any): ()
	local character = arLocalPlayer.Character
	if not character or character.Sitting or character.Vehicle or character.Climbing then
		clearShadow(self)
		self._jumpHeld = false
		return
	end

	local interface = self._interface
	if not interface or not interface:IsVisible("MainMenu") then
		self._autoRun = character.AutoRunInput == true
		clearShadow(self)
		self._jumpHeld = false
		return
	end

	if self._autoRun then
		character.AutoRunInput = true
	end

	local spring = character.MoveSpeedSpring
	if not spring then
		clearShadow(self)
		return
	end

	local binds = self._binds
	local move, sprint = readMoveVector(binds)

	if move.Magnitude < 0.05 then
		if self._autoRun then
			move = FORWARD
			sprint = true
		end
	else
		self._autoRun = false
		character.AutoRunInput = false
	end

	local speeds = self._speeds
	self._speed = sprint and (speeds and speeds.Running or RUN_SPEED) or (speeds and speeds.Walking or WALK_SPEED)

	applyShadow(self, spring)

	if move.Magnitude < 0.05 then
		character.MoveVector = Vector3.zero
	else
		character.MoveVector = move.Unit
	end

	local jump = isDown(binds and binds.Jump) or UserInputService:IsKeyDown(Enum.KeyCode.Space)
	if jump and not self._jumpHeld then
		local actions = character.Actions
		local jumpAction = actions and actions.Jump
		if jumpAction then
			runUngated(self, function(): ()
				jumpAction(character, "Begin")
			end)
		end
	end
	self._jumpHeld = jump
end)

function InventoryMove.new(link: gameUi.Linker): InventoryMove
	local self = BaseFeature.new() :: any
	setmetatable(self, InventoryMove)

	self._enabled = false
	self._interface = nil :: any
	self._binds = nil :: any
	self._speeds = nil :: any
	self._spring = nil :: any
	self._speed = WALK_SPEED
	self._jumpHeld = false
	self._autoRun = false
	self._localPlayer = nil :: any
	self._conn = nil :: RBXScriptConnection?

	link:Toggle("inventoryMove", "Inventory Move", false):SetTip({
		title = "Inventory Move",
		body = "Lets you walk, run and jump while your inventory is open.",
	})

	self:Track(link:Get("inventoryMove"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("inventoryMove") then
		self:Enable()
	end

	return self
end

function InventoryMove.Enable(self: InventoryMove): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local playersModule = ModuleController.GetModule("LocalPlayer")
	if not playersModule then
		return
	end

	self._interface = ModuleController.FrameworkRequire("Libraries", "Interface")

	local keybinds = ModuleController.FrameworkRequire("Configs", "Keybinds")
	self._binds = keybinds and keybinds.Character

	local character = ModuleController.FrameworkRequire("Configs", "Character")
	self._speeds = character and character.MoveSpeeds

	local arLocalPlayer = playersModule.module.get()
	self._localPlayer = arLocalPlayer

	self._conn = RunService.Heartbeat:Connect(function(): ()
		step(self, arLocalPlayer)
	end)
end

function InventoryMove.Disable(self: InventoryMove): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end

	clearShadow(self)
	self._jumpHeld = false

	local arLocalPlayer = self._localPlayer
	local character = arLocalPlayer and arLocalPlayer.Character
	if character then
		character.MoveVector = Vector3.zero
	end
end

function InventoryMove.Destroy(self: InventoryMove): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type InventoryMove =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_interface: any,
			_binds: any,
			_speeds: any,
			_spring: any,
			_speed: number,
			_jumpHeld: boolean,
			_autoRun: boolean,
			_localPlayer: any,
			_conn: RBXScriptConnection?,
		},
		InventoryMove
	))
	& BaseFeature.BaseFeature

return InventoryMove
