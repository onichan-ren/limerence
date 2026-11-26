local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local NetworkController = require("@game/ar2/network/NetworkController")
local clientState = require("@game/ar2/client/clientState")

local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local peek = Charm.peek

local DEFAULT_JUMP_POWER = 50

local InfiniteJump = {}
InfiniteJump.__index = InfiniteJump

setmetatable(InfiniteJump, { __index = BaseFeature })

local doJump = LPH_NO_VIRTUALIZE(function(self: InfiniteJump): ()
	if not peek(clientState.alive) then
		return
	end

	local hrp = peek(clientState.hrp) :: BasePart?
	if not hrp then
		return
	end

	local velocity = hrp.AssemblyLinearVelocity
	hrp.AssemblyLinearVelocity = Vector3.new(velocity.X, self._jumpPower, velocity.Z)

	local character = self._arLocalPlayer and self._arLocalPlayer.Character
	if not character then
		return
	end

	local old = getthreadidentity()
	setthreadidentity(2)

	if character.Animator then
		character.Animator:RunAction("Jump", character.MoveState)
	end
	NetworkController.send("Character Jumped", character.MoveState)
	if character.Jumped then
		character.Jumped:Fire()
	end

	setthreadidentity(old)
end)

function InfiniteJump.new(link: gameUi.Linker): InfiniteJump
	local self = BaseFeature.new() :: any
	setmetatable(self, InfiniteJump)

	self._enabled = false
	self._jumpPower = DEFAULT_JUMP_POWER
	self._jumpKey = Enum.KeyCode.Space
	self._arLocalPlayer = nil :: any
	self._conn = nil :: RBXScriptConnection?

	link:Toggle("infiniteJump", "Infinite Jump", false):SetTip({
		title = "Infinite Jump",
		body = "Jump again any time you press jump, even in the air.",
	})

	self:Track(link:Get("infiniteJump"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("infiniteJump") then
		self:Enable()
	end

	return self
end

function InfiniteJump.Enable(self: InfiniteJump): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local playersModule = ModuleController.GetModule("LocalPlayer")
	if playersModule then
		self._arLocalPlayer = playersModule.module.get()
	end

	local character = ModuleController.FrameworkRequire("Configs", "Character")
	local jump = character and character.Jump
	self._jumpPower = (jump and tonumber(jump.JumpPower)) or DEFAULT_JUMP_POWER

	local keybinds = ModuleController.FrameworkRequire("Configs", "Keybinds")
	local jumpBind = keybinds and keybinds.Character and keybinds.Character.Jump
	local key = jumpBind and jumpBind.Key
	if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
		self._jumpKey = key
	end

	self._conn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean): ()
		if gameProcessed then
			return
		end
		if input.KeyCode == self._jumpKey or input.KeyCode == Enum.KeyCode.Space then
			doJump(self)
		end
	end)
end

function InfiniteJump.Disable(self: InfiniteJump): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
end

function InfiniteJump.Destroy(self: InfiniteJump): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type InfiniteJump =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_jumpPower: number,
			_jumpKey: Enum.KeyCode,
			_arLocalPlayer: any,
			_conn: RBXScriptConnection?,
		},
		InfiniteJump
	))
	& BaseFeature.BaseFeature

return InfiniteJump
