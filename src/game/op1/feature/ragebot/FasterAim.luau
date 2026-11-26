local ModuleController = require("@game/op1/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")

local FasterAim = {}
FasterAim.__index = FasterAim

setmetatable(FasterAim, { __index = BaseFeature })

function FasterAim.new(link: gameUi.Linker): FasterAim
	local self = BaseFeature.new() :: any
	setmetatable(self, FasterAim)

	link:Toggle("fasterAim", "Faster Aim", false):SetTip({
		title = "Faster Aim",
		body = "Speeds up how quickly you aim down sights. 100% aims instantly.",
	})

	local masterLink = link:OnKey("fasterAim")
	masterLink:Submenu("opts", "Faster Aim")
	local optsLink = masterLink:OnKey("opts")

	optsLink:Slider("amount", "Amount", 100, 0, 100, 1, nil, "%"):SetTip({
		title = "Amount",
		body = "How much faster to aim. 100% is instant.",
	})

	self._link = link
	self._enabledLink = link:Get("fasterAim")
	self._factor = 0
	self._bases = setmetatable({}, { __mode = "k" }) :: any
	self._sightsFn = nil :: any
	self._lensFn = nil :: any

	self:Track(link:Watch("fasterAim.opts.amount", function(v: any): ()
		self:_setFactor(1 - (tonumber(v) or 100) / 100)
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

function FasterAim._apply(self: FasterAim, gunSelf: any): ()
	local states = gunSelf and gunSelf.states
	local ads = states and states.ads
	if not ads then
		return
	end

	local value = ads.value
	if type(value) ~= "number" then
		return
	end

	local factor = self._factor
	local bases = self._bases
	local base = bases[ads]

	if base == nil or value ~= base * factor then
		base = value
		bases[ads] = base
	end

	ads.value = base * factor
end

function FasterAim._restoreBases(self: FasterAim): ()
	local factor = self._factor
	local bases = self._bases

	for ads, base in next, bases do
		if ads.value == base * factor then
			ads.value = base
		end
	end

	table.clear(bases)
end

function FasterAim._setFactor(self: FasterAim, factor: number): ()
	self:_restoreBases()
	self._factor = factor
end

function FasterAim.Enable(self: FasterAim): ()
	if self._enabled then
		return
	end

	self._enabled = true

	local gun = ModuleController.GetModule("Gun")
	if not gun then
		self._enabled = false
		return
	end

	local sightsFn = gun.sights
	if sightsFn then
		self._sightsFn = sightsFn

		local original
		original = hook.add(sightsFn, function(gunSelf: any, ...)
			self:_apply(gunSelf)
			return original(gunSelf, ...)
		end)
	end

	local lensFn = gun.update_sight_lens
	if lensFn then
		self._lensFn = lensFn

		local original
		original = hook.add(lensFn, function(gunSelf: any, ...)
			self:_apply(gunSelf)
			return original(gunSelf, ...)
		end)
	end
end

function FasterAim.Disable(self: FasterAim): ()
	if not self._enabled then
		return
	end

	self._enabled = false

	if self._sightsFn then
		hook.restore(self._sightsFn)
		self._sightsFn = nil
	end

	if self._lensFn then
		hook.restore(self._lensFn)
		self._lensFn = nil
	end

	self:_restoreBases()
end

function FasterAim.Destroy(self: FasterAim): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type FasterAim =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_enabledLink: any,
			_enabled: boolean,
			_factor: number,
			_bases: any,
			_sightsFn: any,
			_lensFn: any,
		},
		FasterAim
	))
	& BaseFeature.BaseFeature

return FasterAim
