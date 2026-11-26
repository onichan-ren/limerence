local ModuleController = require("@game/op1/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")

local ReduceSpread = {}
ReduceSpread.__index = ReduceSpread

setmetatable(ReduceSpread, { __index = BaseFeature })

local function resolveSpread(): any?
	local gun = ModuleController.GetModule("Gun")
	if not gun then
		return nil
	end

	local env = getfenv(gun.send_shoot)
	return env and rawget(env, "get_circular_spread") or nil
end

function ReduceSpread.new(link: gameUi.Linker): ReduceSpread
	local self = BaseFeature.new() :: any
	setmetatable(self, ReduceSpread)

	link:Toggle("reduceSpread", "Reduce Spread", false):SetTip({
		title = "Reduce Spread",
		body = "Tightens your shots toward the center of your aim.",
	})

	local masterLink = link:OnKey("reduceSpread")
	masterLink:Submenu("opts", "Reduce Spread")
	local optsLink = masterLink:OnKey("opts")

	optsLink:Slider("amount", "Amount", 100, 0, 100, 1, nil, "%"):SetTip({
		title = "Amount",
		body = "How much spread to remove. 100% fires perfectly straight.",
	})

	self._link = link
	self._enabledLink = link:Get("reduceSpread")
	self._scale = 0
	self._spreadFn = nil :: any

	self:Track(link:Watch("reduceSpread.opts.amount", function(v: any): ()
		self._scale = 1 - (tonumber(v) or 100) / 100
	end))

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	return self
end

function ReduceSpread.Enable(self: ReduceSpread): ()
	if self._enabled then
		return
	end

	self._enabled = true

	local spreadFn = resolveSpread()
	if not spreadFn then
		self._enabled = false
		return
	end

	self._spreadFn = spreadFn

	local old
	old = hook.add(spreadFn, function(cframe: CFrame, amount: number)
		return old(cframe, amount) * self._scale
	end)
end

function ReduceSpread.Disable(self: ReduceSpread): ()
	if not self._enabled then
		return
	end

	self._enabled = false

	if self._spreadFn then
		hook.restore(self._spreadFn)
		self._spreadFn = nil
	end
end

function ReduceSpread.Destroy(self: ReduceSpread): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type ReduceSpread =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_enabledLink: any,
			_enabled: boolean,
			_scale: number,
			_spreadFn: any,
		},
		ReduceSpread
	))
	& BaseFeature.BaseFeature

return ReduceSpread
