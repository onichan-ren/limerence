local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local viewmodelState = require("@game/bloxstrike/viewmodel/viewmodelState")
local ClientController = require("@game/bloxstrike/client/ClientController")
local clientState = require("@game/bloxstrike/client/clientState")

local peek = Charm.peek
local sub = Charm.subscribe

local safeUnhide = LPH_NO_VIRTUALIZE(function(viewmodel: any): ()
	if not viewmodel or type(viewmodel.unhide) ~= "function" then
		return
	end
	if not viewmodel.Hidden then
		return
	end
	if viewmodel.Model == nil then
		viewmodel.Hidden = false
		return
	end
	viewmodel.unhide(viewmodel)
end)

local ForceViewmodel = {}
ForceViewmodel.__index = ForceViewmodel

setmetatable(ForceViewmodel, { __index = BaseFeature })

function ForceViewmodel.new(link: gameUi.Linker): ForceViewmodel
	local self = BaseFeature.new() :: any
	setmetatable(self, ForceViewmodel)

	self._enabled = false
	self._janitor = Janitor.new()
	self._transparencyFn = nil
	self._origTransparency = nil
	self._viewmodel = nil
	self._hadOwnHide = false
	self._origHide = nil

	link:Toggle("forceViewmodel", "Force Viewmodel", false):SetTip({
		title = "Force Viewmodel",
		body = "Keeps your gun on screen while scoped in.",
	})

	self:Track(link:Get("forceViewmodel"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Get("forceViewmodel"):Peek() then
		self:Enable()
	end

	return self
end

ForceViewmodel._detachViewmodel = LPH_NO_VIRTUALIZE(function(self: ForceViewmodel): ()
	local vm = self._viewmodel
	if not vm then
		return
	end
	self._viewmodel = nil
	if self._hadOwnHide then
		vm.hide = self._origHide
	else
		rawset(vm, "hide", nil)
	end
	self._hadOwnHide = false
	self._origHide = nil
end)

ForceViewmodel._attachViewmodel = LPH_NO_VIRTUALIZE(function(self: ForceViewmodel, vm: any): ()
	if vm == self._viewmodel then
		safeUnhide(vm)
		return
	end
	self:_detachViewmodel()
	if not vm then
		return
	end

	local existing = rawget(vm, "hide")
	self._viewmodel = vm
	self._hadOwnHide = existing ~= nil
	self._origHide = existing

	vm.hide = function(_self: any): () end
	safeUnhide(vm)
end)

ForceViewmodel._installTransparencyHook = function(self: ForceViewmodel): ()
	if self._transparencyFn then
		return
	end
	local character = ClientController.GetCharacterObject()
	if not character then
		return
	end
	local mt = getmetatable(character)
	if not mt then
		return
	end
	local fn = rawget(mt, "SetWeaponViewmodelTransparency")
	if type(fn) ~= "function" then
		return
	end

	self._transparencyFn = fn
	local original
	original = hook.add(
		fn,
		LPH_NO_VIRTUALIZE(function(fighter: any, _makeTransparent: boolean?): ()
			return original(fighter, false)
		end)
	)
	self._origTransparency = original
end

function ForceViewmodel.Enable(self: ForceViewmodel): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self:_installTransparencyHook()

	self._janitor:Add(sub(clientState.character, function(): ()
		self:_installTransparencyHook()
	end))

	self._janitor:Add(sub(viewmodelState._viewmodel, function(vm: any): ()
		self:_attachViewmodel(vm)
	end))
	self:_attachViewmodel(peek(viewmodelState._viewmodel))

	self._janitor:Add(function(): ()
		self:_detachViewmodel()
	end)
	self._janitor:Add(function(): ()
		if self._transparencyFn then
			hook.restore(self._transparencyFn)
			self._transparencyFn = nil
			self._origTransparency = nil
		end
	end)
end

function ForceViewmodel.Disable(self: ForceViewmodel): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function ForceViewmodel.Destroy(self: ForceViewmodel): ()
	self:Disable()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type ForceViewmodel =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_transparencyFn: any,
			_origTransparency: any,
			_viewmodel: any,
			_hadOwnHide: boolean,
			_origHide: any,
		},
		ForceViewmodel
	))
	& BaseFeature.BaseFeature

return ForceViewmodel
