local Charm = require("@pkg/Charm")
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local weaponSpreadState = require("@game/bloxstrike/client/weaponSpreadState")

local peek = Charm.peek

local NoSpread = {}
NoSpread.__index = NoSpread

setmetatable(NoSpread, { __index = BaseFeature })

local function reductionToScale(value: any): number
	local reduction = math.clamp(tonumber(value) or 100, 0, 100)
	return 1 - reduction / 100
end

function NoSpread.new(link: gameUi.Linker): NoSpread
	local self = BaseFeature.new() :: any
	setmetatable(self, NoSpread)

	link:Toggle("noSpread", "Reduce Spread", false):SetTip({
		title = "Reduce Spread",
		body = "Reduces random bullet spread so shots land closer to where you aim.",
	})

	local noSpreadLink = link:OnKey("noSpread")
	noSpreadLink:Submenu("opts", "Reduce Spread")
	local optsLink = noSpreadLink:OnKey("opts")
	optsLink:Slider("amount", "Reduction", 100, 0, 100, 1, nil, "%"):SetTip({
		title = "Reduction",
		body = "How much bullet spread to remove. 100% removes all spread; 0% leaves spread untouched.",
	})

	self._link = link
	self._enabledLink = link:Get("noSpread")
	self._scale = reductionToScale(link:Peek("noSpread.opts.amount"))

	self:Track(link:Watch("noSpread.opts.amount", function(v: any): ()
		self._scale = reductionToScale(v)
		if self._enabled then
			weaponSpreadState.setReductionScale(self._scale)
		end
	end))

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		self:_setEnabled(value)
	end))

	if link:Peek("noSpread") then
		self:_setEnabled(true)
	end

	return self
end

function NoSpread._setEnabled(self: NoSpread, enabled: boolean): ()
	if enabled == self._enabled then
		return
	end

	local bulletClass = ModuleController.GetModule("BulletClass")
	if not bulletClass then
		return
	end

	local getTrueSpread = rawget(bulletClass, "getTrueSpread")
	if type(getTrueSpread) ~= "function" then
		return
	end

	if enabled then
		local original
		local replacement = LPH_NO_VIRTUALIZE(function(...: any): any
			return original(...) * self._scale
		end)
		setstackhidden(replacement, true)
		original = hook.add(getTrueSpread, replacement)
		self._enabled = true
		weaponSpreadState.setReductionScale(self._scale)
	else
		hook.restore(getTrueSpread)
		self._enabled = false
		weaponSpreadState.setReductionScale(1)
	end
end

function NoSpread.Destroy(self: NoSpread): ()
	if peek(self._enabledLink._state) then
		self:_setEnabled(false)
	end
	BaseFeature.Destroy(self)
end

export type NoSpread =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_enabledLink: any,
			_enabled: boolean,
			_scale: number,
		},
		NoSpread
	))
	& BaseFeature.BaseFeature

return NoSpread
