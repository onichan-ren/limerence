local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")

local SKIP_DURATION = 0.001

local FastRespawn = {}
FastRespawn.__index = FastRespawn

setmetatable(FastRespawn, { __index = BaseFeature })

local function findUpvalue(target: any, predicate: (any) -> boolean): (number?, any)
	for index, value in next, debug.getupvalues(target) do
		if predicate(value) then
			return index, value
		end
	end
	return nil, nil
end

local function findCorpseStep(): any
	local corpse = ModuleController.GetModule("CorpseCamera")
	local factory = corpse and corpse.module
	if type(factory) ~= "function" then
		return nil
	end

	local _, step = findUpvalue(factory, function(value: any): boolean
		if type(value) ~= "function" then
			return false
		end
		local info = debug.getinfo(value)
		return info ~= nil and info.name == "step"
	end)

	return step
end

function FastRespawn.new(link: gameUi.Linker): FastRespawn
	local self = BaseFeature.new() :: any
	setmetatable(self, FastRespawn)

	self._enabled = false
	self._globals = nil :: any
	self._previous = nil :: boolean?
	self._corpseStep = nil :: any
	self._corpseIndex = nil :: number?
	self._corpseDuration = nil :: number?

	link:Toggle("fastRespawn", "Fast Respawn", false):SetTip({
		title = "Fast Respawn",
		body = "Skips the death camera and gets you back in instantly.",
	})

	self:Track(link:Get("fastRespawn"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("fastRespawn") then
		self:Enable()
	end

	return self
end

function FastRespawn.Enable(self: FastRespawn): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local globals = ModuleController.GetModule("Globals")
	if globals and globals.module then
		self._globals = globals.module
		self._previous = rawget(self._globals, "QuickRespawn") == true
		self._globals.QuickRespawn = true
	end

	local step = findCorpseStep()
	if type(step) == "function" then
		local index, original = findUpvalue(step, function(value: any): boolean
			return type(value) == "number"
		end)
		if index then
			self._corpseStep = step
			self._corpseIndex = index
			self._corpseDuration = original
			debug.setupvalue(step, index, SKIP_DURATION)
		end
	end
end

function FastRespawn.Disable(self: FastRespawn): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._globals then
		self._globals.QuickRespawn = self._previous
		self._globals = nil
		self._previous = nil
	end

	if self._corpseStep and self._corpseIndex and self._corpseDuration then
		debug.setupvalue(self._corpseStep, self._corpseIndex, self._corpseDuration)
	end
	self._corpseStep = nil
	self._corpseIndex = nil
	self._corpseDuration = nil
end

function FastRespawn.Destroy(self: FastRespawn): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type FastRespawn =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_globals: any,
			_previous: boolean?,
			_corpseStep: any,
			_corpseIndex: number?,
			_corpseDuration: number?,
		},
		FastRespawn
	))
	& BaseFeature.BaseFeature

return FastRespawn
