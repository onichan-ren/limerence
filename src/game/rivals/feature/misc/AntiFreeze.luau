local RunService = cloneref(game:GetService("RunService")) :: RunService

local ModuleController = require("@game/rivals/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

local AntiFreeze = {}
AntiFreeze.__index = AntiFreeze

setmetatable(AntiFreeze, { __index = BaseFeature })

function AntiFreeze.new(link: gameUi.Linker): AntiFreeze
	local self = BaseFeature.new() :: any
	setmetatable(self, AntiFreeze)

	link:Toggle("antiFreeze", "Anti Freeze", false):SetTip({
		title = "Anti Freeze",
		body = "Ignores freeze effects so you can keep moving while frozen.",
	})

	self._janitor = Janitor.new()

	self:Track(link:Get("antiFreeze"):OnChange(function(value: boolean)
		if value then
			self:Enable(true)
		else
			self:Disable(false)
		end
	end))

	return self
end

local localFighterEntity = LPH_NO_VIRTUALIZE(function(): any
	local mechanics = ModuleController.GetModule("MechanicsController")
	local fighter = mechanics and rawget(mechanics, "LocalFighter")
	return fighter and rawget(fighter, "Entity") or nil
end)

function AntiFreeze.Enable(self: AntiFreeze): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._janitor:Add(RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
		local entity = localFighterEntity()
		if not entity then
			return
		end
		local data = rawget(entity, "Data")
		if type(data) ~= "table" or not data.IsFrozen then
			return
		end
		data.IsFrozen = false
		local humanoid = rawget(entity, "Humanoid")
		if humanoid then
			setthreadidentity(2)
			humanoid.PlatformStand = false
			setthreadidentity(8)
		end
	end)))
end

function AntiFreeze.Disable(self: AntiFreeze): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function AntiFreeze.Destroy(self: AntiFreeze): ()
	self:Disable()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type AntiFreeze =
	typeof(setmetatable(
		{} :: {
			_janitor: Janitor.Janitor?,
		},
		AntiFreeze
	))
	& BaseFeature.BaseFeature

return AntiFreeze
