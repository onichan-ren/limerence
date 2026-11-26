local ModuleController = require("@game/op1/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")

local ReduceRecoil = {}
ReduceRecoil.__index = ReduceRecoil

setmetatable(ReduceRecoil, { __index = BaseFeature })

local function resolveDeps(fn: any): (any, any)
	local util, input
	local ups = debug.getupvalues(fn)

	for _, value in next, ups do
		if type(value) == "table" then
			if rawget(value, "tween") and rawget(value, "rand") then
				util = value
			elseif rawget(value, "current_device") then
				input = value
			end
		end
	end

	return util, input
end

function ReduceRecoil.new(link: gameUi.Linker): ReduceRecoil
	local self = BaseFeature.new() :: any
	setmetatable(self, ReduceRecoil)

	link:Toggle("reduceRecoil", "Reduce Recoil", false):SetTip({
		title = "Reduce Recoil",
		body = "Reduces view and weapon kick while shooting. Tune vertical and horizontal separately.",
	})

	local masterLink = link:OnKey("reduceRecoil")
	masterLink:Submenu("opts", "Reduce Recoil")
	local optsLink = masterLink:OnKey("opts")

	optsLink:Slider("vertical", "Vertical", 100, 0, 100, 1, nil, "%"):SetTip({
		title = "Vertical",
		body = "How much vertical (up/down) recoil to remove. 100% removes all vertical kick.",
	})
	optsLink:Slider("horizontal", "Horizontal", 100, 0, 100, 1, nil, "%"):SetTip({
		title = "Horizontal",
		body = "How much horizontal (left/right) recoil to remove. 100% removes all horizontal kick.",
	})

	self._link = link
	self._enabledLink = link:Get("reduceRecoil")
	self._vScale = 0
	self._hScale = 0
	self._recoilFn = nil :: any

	self:Track(link:Watch("reduceRecoil.opts.vertical", function(v: any): ()
		self._vScale = 1 - (tonumber(v) or 100) / 100
	end))
	self:Track(link:Watch("reduceRecoil.opts.horizontal", function(v: any): ()
		self._hScale = 1 - (tonumber(v) or 100) / 100
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

function ReduceRecoil.Enable(self: ReduceRecoil): ()
	if self._enabled then
		return
	end

	self._enabled = true

	local gun = ModuleController.GetModule("Gun")
	local recoilFn = gun and gun.recoil_function

	if not recoilFn then
		self._enabled = false
		return
	end

	local Util, Input = resolveDeps(recoilFn)
	if not Util then
		self._enabled = false
		return
	end

	self._recoilFn = recoilFn

	hook.add(recoilFn, function(gunSelf: any, owner: any)
		owner.values.cframes:get("camera"):remove_offset("shoot")

		local offset = owner.values.cframes:get("camera"):set_offset("shoot")
		local value = offset.Value

		if owner.values.camera:get() then
			local values = owner.values
			values.old_cam_render = values.old_cam_render * value:Inverse()
		end

		local up = gunSelf.states.recoil_up:get()
		local side = gunSelf.states.recoil_side:get()

		if Input and Input.current_device:get() ~= "pc" then
			up *= 0.7
			side *= 0.7
		end

		if gunSelf.prone_recoil and owner.states.walk_state:get() == "prone" then
			up *= gunSelf.prone_recoil
			side *= gunSelf.prone_recoil
		end

		Util.tween(offset, TweenInfo.new(0), {
			Value = CFrame.new(),
		})
		offset.Value = CFrame.new()

		if owner.values.cframes:get("arm2"):current_pivot() == "equipped" then
			up *= 0.8
		else
			side *= 1.2
		end

		up *= self._vScale
		side *= self._hScale

		local cFrame = CFrame.Angles(math.rad(Util.rand(up * 1, up * 2)), math.rad(Util.rand(-side * 1, side * 1)), 0)
		local recovery = math.exp((up + side) / 30)
		local kickTime = math.max(math.min(0.1, 60 / gunSelf.states.firerate:get()), recovery * 0.06)
		local settleTime = recovery * 0.24

		Util.tween(offset, TweenInfo.new(kickTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Value = cFrame,
		}).Completed:Wait()
		Util.tween(offset, TweenInfo.new(settleTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Value = CFrame.new(),
		}).Completed:Wait()
	end)
end

function ReduceRecoil.Disable(self: ReduceRecoil): ()
	if not self._enabled then
		return
	end

	self._enabled = false

	if self._recoilFn then
		hook.restore(self._recoilFn)
		self._recoilFn = nil
	end
end

function ReduceRecoil.Destroy(self: ReduceRecoil): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type ReduceRecoil =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_enabledLink: any,
			_enabled: boolean,
			_vScale: number,
			_hScale: number,
			_recoilFn: any,
		},
		ReduceRecoil
	))
	& BaseFeature.BaseFeature

return ReduceRecoil
