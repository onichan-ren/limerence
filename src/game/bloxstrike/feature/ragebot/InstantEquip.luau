local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

local peek = Charm.peek

local BACKDATE_SECONDS = 10

local InstantEquip = {}
InstantEquip.__index = InstantEquip

setmetatable(InstantEquip, { __index = BaseFeature })

local _instance: any = nil

local applyInstantEquip = LPH_JIT_MAX(function(weapon: any): ()
	if not weapon then
		return
	end
	if type(weapon.WeaponEquippedTick) ~= "number" then
		return
	end
	weapon.WeaponEquippedTick = tick() - BACKDATE_SECONDS

	local viewmodel = weapon.Viewmodel
	if viewmodel and viewmodel.Animation then
		viewmodel.Animation:stop("Equip", 0)
	end
	if weapon.CharacterAnimator then
		weapon.CharacterAnimator:stop("Equip", 0)
	end
end)

function InstantEquip.new(link: gameUi.Linker): InstantEquip
	local self = BaseFeature.new() :: any
	setmetatable(self, InstantEquip)

	link:Toggle("instantEquip", "Instant Equip", false):SetTip({
		title = "Instant Equip",
		body = "Lets you shoot, reload, and inspect instantly after switching weapons.",
	})

	self._janitor = Janitor.new()
	self._enabled = false
	self._enabledLink = link:Get("instantEquip")

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("instantEquip") then
		self:Enable()
	end

	_instance = self
	return self
end

function InstantEquip.Enable(self: InstantEquip): ()
	if self._enabled then
		return
	end
	self._enabled = true

	applyInstantEquip(peek(loadoutState.currentEquipped))

	self._janitor:Add(
		RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
			applyInstantEquip(peek(loadoutState.currentEquipped))
		end)),
		"Disconnect"
	)
end

function InstantEquip.Disable(self: InstantEquip): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function InstantEquip.Destroy(self: InstantEquip): ()
	self:Disable()
	if (_instance :: any) == self then
		_instance = nil
	end
	BaseFeature.Destroy(self)
end

function InstantEquip.IsEnabled(): boolean
	return _instance ~= nil and _instance._enabled == true
end

export type InstantEquip =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_enabledLink: any,
			_janitor: Janitor.Janitor,
		},
		InstantEquip
	))
	& BaseFeature.BaseFeature

return InstantEquip
