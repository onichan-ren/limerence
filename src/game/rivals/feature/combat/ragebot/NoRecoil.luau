local ModuleController = require("@game/rivals/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local Janitor = require("@pkg/Janitor")

local NoRecoil = {}
NoRecoil.__index = NoRecoil

setmetatable(NoRecoil, { __index = BaseFeature })

function NoRecoil.new(link: gameUi.Linker): NoRecoil
	local self = BaseFeature.new() :: any
	setmetatable(self, NoRecoil)

	link:Toggle("noRecoil", "Reduce Recoil", false):SetTip({
		title = "Reduce Recoil",
		body = "Reduces view and weapon kick while shooting. Tune vertical and horizontal separately.",
	})

	local masterLink = link:OnKey("noRecoil")
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
	self._enabledLink = link:Get("noRecoil")
	self._janitor = Janitor.new()
	self._vScale = 0
	self._hScale = 0

	self:Track(link:Watch("noRecoil.opts.vertical", function(v: any): ()
		self._vScale = 1 - (tonumber(v) or 100) / 100
	end))
	self:Track(link:Watch("noRecoil.opts.horizontal", function(v: any): ()
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

function NoRecoil.Enable(self: NoRecoil): ()
	if self._enabled then
		return
	end

	self._enabled = true

	local ClientViewModel = ModuleController.GetModule("ClientViewModel")
	if not ClientViewModel then
		return
	end

	local applyRecoil = rawget(ClientViewModel, "ApplyRecoil")
	if not applyRecoil then
		return
	end

	local original
	original = hook.add(
		applyRecoil,
		LPH_NO_VIRTUALIZE(function(viewModel: any, recoil: any, ...: any): ...any
			if typeof(recoil) == "Vector3" then
				recoil = Vector3.new(recoil.X * self._vScale, recoil.Y * self._hScale, recoil.Z * self._hScale)
			end
			return original(viewModel, recoil, ...)
		end)
	)

	self._janitor:Add(function()
		hook.restore(applyRecoil)
	end, true)
end

function NoRecoil.Disable(self: NoRecoil): ()
	if not self._enabled then
		return
	end

	self._enabled = false
	self._janitor:Cleanup()
end

function NoRecoil.Destroy(self: NoRecoil): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type NoRecoil =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_enabledLink: any,
			_enabled: boolean,
			_vScale: number,
			_hScale: number,
			_janitor: Janitor.Janitor,
		},
		NoRecoil
	))
	& BaseFeature.BaseFeature

return NoRecoil
