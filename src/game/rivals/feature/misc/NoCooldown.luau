local RunService = cloneref(game:GetService("RunService")) :: RunService
local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local WeaponController = require("@game/rivals/weapon/WeaponController")

local LocalPlayer = Players.LocalPlayer
local peek = Charm.peek

local ABILITY_FIELDS = { "_dash_cooldown", "_spin_cooldown" }
local ABILITY_UI_NAMES = { Dash = true, Spin = true }

local function getCooldownsClass(): any?
	local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local modules = scripts and scripts:FindFirstChild("Modules")
	local classes = modules and modules:FindFirstChild("ClientReplicatedClasses")
	local fighter = classes and classes:FindFirstChild("ClientFighter")
	local item = fighter and fighter:FindFirstChild("ClientItem")
	local cooldowns = item and item:FindFirstChild("Cooldowns")
	if not cooldowns then
		return nil
	end
	setthreadidentity(2)
	local instance = require(cooldowns)
	setthreadidentity(8)
	return instance
end

local NoCooldown = {}
NoCooldown.__index = NoCooldown

setmetatable(NoCooldown, { __index = BaseFeature })

function NoCooldown.new(link: gameUi.Linker): NoCooldown
	local self = BaseFeature.new() :: any
	setmetatable(self, NoCooldown)

	link:Toggle("noAbilityCooldown", "No Ability Cooldown", false):SetTip({
		title = "No Ability Cooldown",
		body = "Removes the cooldown on weapon abilities like the Scythe dash and Battle Axe spin.",
	})
	link:Toggle("noMeleeCooldown", "No Melee Cooldown", false):SetTip({
		title = "No Melee Cooldown",
		body = "Lets you swing melee weapons without the delay between hits.",
	})

	self._melee = false
	self._ability = false
	self._connection = nil
	self._uiHookTarget = nil

	self:Track(link:Get("noAbilityCooldown"):OnChange(function(value: boolean): ()
		self._ability = value == true
		self:_sync()
	end))
	self:Track(link:Get("noMeleeCooldown"):OnChange(function(value: boolean): ()
		self._melee = value == true
		self:_sync()
	end))

	return self
end

NoCooldown._apply = LPH_NO_VIRTUALIZE(function(self: NoCooldown): ()
	local item = peek(WeaponController.item)
	if type(item) ~= "table" then
		return
	end
	if self._melee and rawget(item, "_attack_cooldown") ~= nil then
		item._attack_cooldown = 0
	end
	if self._ability then
		for _, field in next, ABILITY_FIELDS do
			if rawget(item, field) ~= nil then
				item[field] = 0
			end
		end
	end
end)

function NoCooldown._syncUi(self: NoCooldown): ()
	if self._ability then
		if self._uiHookTarget then
			return
		end
		local class = getCooldownsClass()
		local original = class and rawget(class, "Create")
		if type(original) ~= "function" then
			return
		end
		self._uiHookTarget = original
		local trampoline
		trampoline = hook.add(
			original,
			LPH_NO_VIRTUALIZE(function(cooldownsSelf: any, image: any, duration: any, name: any, ...: any): ...any
				if self._ability and ABILITY_UI_NAMES[name] then
					return
				end
				return trampoline(cooldownsSelf, image, duration, name, ...)
			end)
		)
	elseif self._uiHookTarget then
		hook.restore(self._uiHookTarget)
		self._uiHookTarget = nil
	end
end

function NoCooldown._sync(self: NoCooldown): ()
	local active = self._melee or self._ability
	if active then
		if not self._connection then
			self._connection = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
				self:_apply()
			end))
		end
	elseif self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	self:_syncUi()
end

function NoCooldown.Destroy(self: NoCooldown): ()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	if self._uiHookTarget then
		hook.restore(self._uiHookTarget)
		self._uiHookTarget = nil
	end
	BaseFeature.Destroy(self)
end

export type NoCooldown = typeof(setmetatable(
	{} :: {
		_melee: boolean,
		_ability: boolean,
		_connection: RBXScriptConnection?,
		_uiHookTarget: any,
	},
	NoCooldown
)) & BaseFeature.BaseFeature

return NoCooldown
