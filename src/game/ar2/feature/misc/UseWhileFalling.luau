local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")

local RunService = cloneref(game:GetService("RunService")) :: RunService

local UseWhileFalling = {}
UseWhileFalling.__index = UseWhileFalling

setmetatable(UseWhileFalling, { __index = BaseFeature })

local reset = LPH_NO_VIRTUALIZE(function(arLocalPlayer: any): ()
	local character = arLocalPlayer.Character
	if character then
		character.FallingTime = 0
	end
end)

function UseWhileFalling.new(link: gameUi.Linker): UseWhileFalling
	local self = BaseFeature.new() :: any
	setmetatable(self, UseWhileFalling)

	self._enabled = false
	self._conn = nil :: RBXScriptConnection?

	link:Toggle("useWhileFalling", "Use While Falling", false):SetTip({
		title = "Use While Falling",
		body = "Consumables and reloads keep going while falling.",
	})

	self:Track(link:Get("useWhileFalling"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("useWhileFalling") then
		self:Enable()
	end

	return self
end

function UseWhileFalling.Enable(self: UseWhileFalling): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local playersModule = ModuleController.GetModule("LocalPlayer")
	if not playersModule then
		return
	end

	local arLocalPlayer = playersModule.module.get()

	self._conn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
		reset(arLocalPlayer)
	end))
end

function UseWhileFalling.Disable(self: UseWhileFalling): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
end

function UseWhileFalling.Destroy(self: UseWhileFalling): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type UseWhileFalling =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_conn: RBXScriptConnection?,
		},
		UseWhileFalling
	))
	& BaseFeature.BaseFeature

return UseWhileFalling
