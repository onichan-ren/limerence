local BaseFeature = require("@game/BaseFeature")
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local gameUi = require("@game/gameUi")

local Radar = {}
Radar.__index = Radar

setmetatable(Radar, { __index = BaseFeature })

function Radar.new(link: gameUi.Linker): Radar
	local self = BaseFeature.new() :: any
	setmetatable(self, Radar)

	self._enabled = false
	self._visibilityFn = nil :: any
	self._original = nil :: any

	link:Toggle("radarEsp", "Radar ESP", false):SetTip({
		title = "Radar ESP",
		body = "Shows enemies on the game's radar at all times, even before your team spots them.",
	})

	self:Track(link:Get("radarEsp"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	return self
end

function Radar._resolve(self: Radar): boolean
	if self._visibilityFn then
		return true
	end
	local module = ModuleController.GetModule("Radar")
	if not module then
		return false
	end
	local cand = debug.getupvalue(module.UpdatePlayerIcons, 10)
	if type(cand) ~= "function" then
		return false
	end
	self._visibilityFn = cand
	return true
end

function Radar.Enable(self: Radar): ()
	if self._enabled then
		return
	end
	if not self:_resolve() then
		return
	end
	self._enabled = true

	self._original = debug.getupvalue(self._visibilityFn, 1)
	debug.setupvalue(
		self._visibilityFn,
		1,
		LPH_NO_VIRTUALIZE(function(): boolean
			return true
		end)
	)
end

function Radar.Disable(self: Radar): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	debug.setupvalue(self._visibilityFn, 1, self._original)
	self._original = nil
end

function Radar.Destroy(self: Radar): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type Radar = typeof(setmetatable(
	{} :: {
		_enabled: boolean,
		_visibilityFn: any,
		_original: any,
	},
	Radar
)) & BaseFeature.BaseFeature

return Radar
