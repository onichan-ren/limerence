local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local hook = require("@share/hook")

local InstantSearch = {}
InstantSearch.__index = InstantSearch

setmetatable(InstantSearch, { __index = BaseFeature })

function InstantSearch.new(link: gameUi.Linker): InstantSearch
	local self = BaseFeature.new() :: any
	setmetatable(self, InstantSearch)

	self._enabled = false
	self._target = nil :: any

	link:Toggle("instantSearch", "Instant Search", false):SetTip({
		title = "Instant Search",
		body = "Loots containers and bodies the instant you interact.",
	})

	self:Track(link:Get("instantSearch"):OnChange(function(value: boolean): ()
		self._enabled = value
		if value then
			self:_ensureHook()
		end
	end))

	self._enabled = link:Peek("instantSearch") == true
	if self._enabled then
		self:_ensureHook()
	end

	return self
end

function InstantSearch._ensureHook(self: InstantSearch): ()
	if self._target then
		return
	end

	local interactables = ModuleController.GetModule("Interactables")
	local module = interactables and interactables.module
	local inputPrompt = module and rawget(module, "inputPrompt")
	if type(inputPrompt) ~= "function" then
		return
	end

	self._target = inputPrompt

	local old
	old = hook.add(
		inputPrompt,
		LPH_NO_VIRTUALIZE(function(...)
			local result = old(...)
			if self._enabled and type(result) == "table" then
				result.Time = 0
			end
			return result
		end)
	)
end

function InstantSearch.Destroy(self: InstantSearch): ()
	if self._target then
		hook.restore(self._target)
		self._target = nil
	end
	BaseFeature.Destroy(self)
end

export type InstantSearch =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_target: any,
		},
		InstantSearch
	))
	& BaseFeature.BaseFeature

return InstantSearch
