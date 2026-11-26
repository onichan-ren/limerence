local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")

local LocalPlayer = Players.LocalPlayer

local function getButtonsClass(): any?
	local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local modules = scripts and scripts:FindFirstChild("Modules")
	local classes = modules and modules:FindFirstChild("ClientReplicatedClasses")
	local duel = classes and classes:FindFirstChild("ClientDuel")
	local interface = duel and duel:FindFirstChild("DuelInterface")
	local buttons = interface and interface:FindFirstChild("Buttons")
	if not buttons then
		return nil
	end
	setthreadidentity(2)
	local instance = require(buttons)
	setthreadidentity(8)
	return instance
end

local AutoRespawn = {}
AutoRespawn.__index = AutoRespawn

setmetatable(AutoRespawn, { __index = BaseFeature })

function AutoRespawn.new(link: gameUi.Linker): AutoRespawn
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoRespawn)

	link:Toggle("autoRespawn", "Auto Respawn", false):SetTip({
		title = "Auto Respawn",
		body = "Respawns you the moment the respawn option appears.",
	})

	self._hookTarget = nil

	self:Track(link:Get("autoRespawn"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("autoRespawn") then
		self:Enable()
	end

	return self
end

function AutoRespawn.Enable(self: AutoRespawn): ()
	if self._hookTarget then
		return
	end
	local class = getButtonsClass()
	if type(class) ~= "table" then
		return
	end
	local original = rawget(class, "RespawnNowAnimation")
	if type(original) ~= "function" then
		return
	end

	self._hookTarget = original
	local trampoline
	trampoline = hook.add(
		original,
		LPH_NO_VIRTUALIZE(function(buttonsSelf: any, isTimerOnly: any, ...: any): ...any
			local result = trampoline(buttonsSelf, isTimerOnly, ...)
			if not isTimerOnly then
				task.defer(function(): ()
					buttonsSelf:RespawnNowRequest()
				end)
			end
			return result
		end)
	)
end

function AutoRespawn.Disable(self: AutoRespawn): ()
	if self._hookTarget then
		hook.restore(self._hookTarget)
		self._hookTarget = nil
	end
end

function AutoRespawn.Destroy(self: AutoRespawn): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoRespawn = typeof(setmetatable(
	{} :: {
		_hookTarget: any,
	},
	AutoRespawn
)) & BaseFeature.BaseFeature

return AutoRespawn
