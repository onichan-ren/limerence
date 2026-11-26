local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local WeaponController = require("@game/bloxstrike/weapon/WeaponController")

local peek = Charm.peek
local sub = Charm.subscribe

local stripWalls = LPH_NO_VIRTUALIZE(function(data: any): ()
	local bullets = rawget(data, "Bullets")
	if type(bullets) ~= "table" then
		return
	end
	for _, bullet in next, bullets do
		local hits = bullet.Hits
		if type(hits) ~= "table" then
			continue
		end
		local kept = nil
		local count = 0
		for _, hit in next, hits do
			local instance = hit.Instance
			if instance then
				local ancestor = instance:FindFirstAncestorOfClass("Model")
				if ancestor and Players:GetPlayerFromCharacter(ancestor) then
					kept = kept or {}
					count += 1
					kept[count] = hit
				end
			end
		end
		if kept then
			bullet.Hits = kept
		end
	end
end)

local InfinitePenetration = {}
InfinitePenetration.__index = InfinitePenetration

setmetatable(InfinitePenetration, { __index = BaseFeature })

local _instance: any = nil

function InfinitePenetration.new(link: gameUi.Linker): InfinitePenetration
	local self = BaseFeature.new() :: any
	setmetatable(self, InfinitePenetration)

	link:Toggle("infinitePenetration", "Infinite Penetration", false):SetTip({
		title = "Infinite Penetration",
		body = "Bullets pass through walls without losing penetration.",
	})

	local penLink = link:OnKey("infinitePenetration")
	penLink:Submenu("opts", "Infinite Penetration")
	local optsLink = penLink:OnKey("opts")
	optsLink:Toggle("maxDamage", "Max Damage", false):SetTip({
		title = "Max Damage",
		body = "Deals full damage through walls with no penetration falloff.",
	})

	self._janitor = Janitor.new()
	self._enabled = false
	self._enabledLink = link:Get("infinitePenetration")
	self._maxDamageLink = optsLink:Get("maxDamage")
	self._maxDamage = optsLink:Peek("maxDamage") == true
	self._removeTransform = nil
	self._lastEquipped = nil
	self._oldPenetration = 0

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(self._maxDamageLink:OnChange(function(value: boolean): ()
		self._maxDamage = value == true
		self:_applyMaxDamage()
	end))

	if link:Peek("infinitePenetration") then
		self:Enable()
	end

	_instance = self
	return self
end

function InfinitePenetration._restoreWeapon(self: InfinitePenetration): ()
	local props = self._lastEquipped
	if not props then
		return
	end
	self._lastEquipped = nil

	setreadonly(props, false)
	setmetatable(props, nil)
	props.Penetration = self._oldPenetration
	setreadonly(props, true)
end

function InfinitePenetration._applyMaxDamage(self: InfinitePenetration): ()
	if self._enabled and self._maxDamage then
		if not self._removeTransform then
			self._removeTransform = WeaponController.AddShootTransform(stripWalls)
		end
	elseif self._removeTransform then
		self._removeTransform()
		self._removeTransform = nil
	end
end

function InfinitePenetration.Enable(self: InfinitePenetration): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local newIndex = LPH_NO_VIRTUALIZE(function(props, key)
		if not checkcaller() then
			if not (getcallingscript() :: any).Name:find("Weapon") then
				if key == "Penetration" then
					return 999
				end
			end
			if key == "Penetration" then
				return self._oldPenetration
			end
		end
		return rawget(props, key)
	end)

	local function updateWeapon(data: loadoutState.LoadoutEntry): ()
		self:_restoreWeapon()
		if not data then
			return
		end
		local props = data.Properties
		if not props then
			return
		end
		local penetration = props.Penetration
		if not penetration then
			return
		end
		self._lastEquipped = props
		self._oldPenetration = penetration
		setreadonly(props, false)
		props.Penetration = nil
		setmetatable(props, { __index = newIndex })
		setreadonly(props, true)
	end

	self._janitor:Add(sub(loadoutState.currentEquipped, updateWeapon), true)

	local currentEquipped = peek(loadoutState.currentEquipped)
	if currentEquipped then
		updateWeapon(currentEquipped)
	end

	self:_applyMaxDamage()
end

function InfinitePenetration.Disable(self: InfinitePenetration): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self._janitor:Cleanup()
	self:_restoreWeapon()
	self:_applyMaxDamage()
end

function InfinitePenetration.Destroy(self: InfinitePenetration): ()
	self:Disable()
	if (_instance :: any) == self then
		_instance = nil
	end
	BaseFeature.Destroy(self)
end

function InfinitePenetration.IsEnabled(): boolean
	return _instance ~= nil and _instance._enabled == true
end

function InfinitePenetration.IsMaxDamageEnabled(): boolean
	return _instance ~= nil and _instance._enabled == true and _instance._maxDamage == true
end

export type InfinitePenetration =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_maxDamage: boolean,
			_removeTransform: (() -> ())?,
			_lastEquipped: any,
			_oldPenetration: number,
		},
		InfinitePenetration
	))
	& BaseFeature.BaseFeature

return InfinitePenetration
