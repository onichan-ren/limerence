local RunService = cloneref(game:GetService("RunService")) :: RunService

local BaseFeature = require("@game/BaseFeature")
local ModuleController = require("@game/pf/module/ModuleController")
local gameUi = require("@game/gameUi")

local AutoSpot = {}
AutoSpot.__index = AutoSpot

setmetatable(AutoSpot, { __index = BaseFeature })

function AutoSpot.new(link: gameUi.Linker): AutoSpot
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoSpot)

	self._enabled = false
	self._conn = nil :: RBXScriptConnection?
	self._spotting = nil :: any
	self._accum = 0
	self._interval = 0.3

	link:Toggle("autoSpot", "Auto Spot", false):SetTip({
		title = "Auto Spot",
		body = "Automatically mark enemies you look at.",
	})

	self:Track(link:Get("autoSpot"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("autoSpot") then
		self:Enable()
	end

	return self
end

function AutoSpot.Enable(self: AutoSpot): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._accum = 0
	self._spotting = ModuleController.GetModule("HudSpottingInterface")
	self._conn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
		self._accum += dt
		if self._accum < self._interval then
			return
		end
		self._accum = 0

		local spotting = self._spotting
		if not spotting then
			return
		end
		setthreadidentity(8)
		spotting.spot()
	end))
end

function AutoSpot.Disable(self: AutoSpot): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
end

function AutoSpot.Destroy(self: AutoSpot): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoSpot =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_conn: RBXScriptConnection?,
			_spotting: any,
			_accum: number,
			_interval: number,
			Enable: (AutoSpot) -> (),
			Disable: (AutoSpot) -> (),
		},
		AutoSpot
	))
	& BaseFeature.BaseFeature

return AutoSpot
