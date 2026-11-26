local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local Janitor = require("@pkg/Janitor")
local ModuleController = require("@game/rivals/module/ModuleController")
local ToastController = require("@ui/hud/toast/ToastController")

local LocalPlayer = Players.LocalPlayer

local DAMAGE_KEY = utf8.char(0)
local CRIT_KEY = utf8.char(1)
local SOURCE_KEY = utf8.char(2)

local HurtLog = {}
HurtLog.__index = HurtLog

setmetatable(HurtLog, { __index = BaseFeature })

local function resolvePlayer(source: any): Player?
	if typeof(source) ~= "Instance" then
		return nil
	end
	local model = source:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model) or nil
end

function HurtLog.new(link: gameUi.Linker): HurtLog
	local self = BaseFeature.new() :: any
	setmetatable(self, HurtLog)

	link:Toggle("hurtLogs", "Hurt Logs", false):SetTip({
		title = "Hurt Logs",
		body = "Shows a notification each time you take damage, including the attacker and amount.",
	})

	self._link = link
	self._enabledLink = link:Get("hurtLogs")
	self._janitor = Janitor.new()

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("hurtLogs") then
		self:Enable()
	end

	return self
end

function HurtLog.Enable(self: HurtLog): ()
	if self._enabled then
		return
	end

	local damageIndicators = ModuleController.GetModule("DamageIndicators")
	if not damageIndicators then
		return
	end
	local create = rawget(damageIndicators, "Create")
	if not create then
		return
	end

	local original
	original = hook.add(
		create,
		LPH_NO_VIRTUALIZE(function(self2: any, data: any, ...)
			if type(data) == "table" then
				local damage = data[DAMAGE_KEY]
				if type(damage) == "number" and damage > 0 then
					local amount = math.floor(damage + 0.5)
					local attacker = resolvePlayer(data[SOURCE_KEY])
					local text: string
					if attacker and attacker ~= LocalPlayer then
						local name = attacker.DisplayName ~= "" and attacker.DisplayName or attacker.Name
						text = "Hurt by <hl>" .. name .. "</hl> for <hl>" .. amount .. "</hl>"
					else
						text = "Hurt for <hl>" .. amount .. "</hl>"
					end
					ToastController.Push({ text = text })
				end
			end
			return original(self2, data, ...)
		end)
	)

	self._janitor:Add(function()
		hook.restore(create)
	end, true)
	self._enabled = true
end

function HurtLog.Disable(self: HurtLog): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function HurtLog.Destroy(self: HurtLog): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type HurtLog =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_enabledLink: any,
			_enabled: boolean,
			_janitor: Janitor.Janitor,
		},
		HurtLog
	))
	& BaseFeature.BaseFeature

return HurtLog
