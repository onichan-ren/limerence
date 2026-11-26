local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")

local RunService = cloneref(game:GetService("RunService")) :: RunService

local NoJumpCooldown = {}
NoJumpCooldown.__index = NoJumpCooldown

setmetatable(NoJumpCooldown, { __index = BaseFeature })

local step = LPH_NO_VIRTUALIZE(function(arLocalPlayer: any): ()
	local character = arLocalPlayer.Character
	if character and character.JumpDebounce and character.JumpDebounce > 0 then
		character.JumpDebounce = 0
	end
end)

function NoJumpCooldown.new(link: gameUi.Linker): NoJumpCooldown
	local self = BaseFeature.new() :: any
	setmetatable(self, NoJumpCooldown)

	self._enabled = false
	self._conn = nil :: RBXScriptConnection?

	link:Toggle("noJumpCooldown", "No Jump Cooldown", false):SetTip({
		title = "No Jump Cooldown",
		body = "Jump again without waiting.",
	})

	self:Track(link:Get("noJumpCooldown"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("noJumpCooldown") then
		self:Enable()
	end

	return self
end

function NoJumpCooldown.Enable(self: NoJumpCooldown): ()
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
		step(arLocalPlayer)
	end)
end

function NoJumpCooldown.Disable(self: NoJumpCooldown): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
end

function NoJumpCooldown.Destroy(self: NoJumpCooldown): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type NoJumpCooldown =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_conn: RBXScriptConnection?,
		},
		NoJumpCooldown
	))
	& BaseFeature.BaseFeature

return NoJumpCooldown
