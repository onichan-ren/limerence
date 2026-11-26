local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Charm = require("@pkg/Charm")
local CommandBaseController = require("@game/overkill/weapon/CommandBaseController")
local ModuleController = require("@game/overkill/module/ModuleController")
local clientState = require("@game/overkill/client/clientState")

local peek = Charm.peek

local BTN_PRIMARY = 1
local PITCH_DOWN = 1.4
local MAX_FUSE = 60
local JUMP_LEAD = 0.12
local COOLDOWN = 0.5
local MAX_WAIT = 4

local items: any = nil

local function statsOf(weaponId: any): any
	if type(weaponId) ~= "string" or weaponId == "" then
		return nil
	end
	if not items then
		items = ModuleController.GetModule("items")
	end
	local item = items and items.all and items.all[weaponId]
	local stats = type(item) == "table" and item.stats
	return type(stats) == "table" and stats or nil
end

local function resolveGrenade(state: any, now: number): any?
	for slot = 1, 4 do
		local weaponId = state["slot" .. slot .. "_weaponID"]
		local stats = statsOf(weaponId)
		local firing = stats and stats.firing
		if firing and firing.isExplosive == true and firing.cookable == true then
			local fuse = firing.projectileFuseTime
			if type(fuse) == "number" and fuse > 0 and fuse < MAX_FUSE then
				local hasAmmo = stats.ammo ~= nil
				local magCount = state["slot" .. slot .. "_magCount"] or 0
				local rate = firing.rate or 0
				local lastFire = state["slot" .. slot .. "_lastFireServerTime"] or 0
				local ready = rate <= 0 or (now - lastFire) >= rate
				if (not hasAmmo or magCount > 0) and ready then
					return { slot = slot, fuse = fuse }
				end
			end
		end
	end
	return nil
end

local AutoGrenadeJump = {}
AutoGrenadeJump.__index = AutoGrenadeJump

setmetatable(AutoGrenadeJump, { __index = BaseFeature })

function AutoGrenadeJump.new(link: gameUi.Linker): AutoGrenadeJump
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoGrenadeJump)

	self._active = false
	self._burstArmed = false
	self._phase = "idle"
	self._grenade = nil :: any
	self._start = 0
	self._cooking = false
	self._cooldownUntil = 0
	self._installed = false

	local toggle = link:Toggle("autoGrenadeJump", "Grenade Jump", false):SetTip({
		title = "Grenade Jump",
		body = "Cooks a grenade in your hand to launch yourself.",
	})

	self:Track(toggle:OnChange(function(value: boolean): ()
		self._active = value
		if value then
			self._burstArmed = true
			self:Enable()
		end
	end))

	if link:Peek("autoGrenadeJump") then
		self._active = true
		self:Enable()
	end

	return self
end

function AutoGrenadeJump._reset(self: AutoGrenadeJump): ()
	self._phase = "idle"
	self._grenade = nil
	self._cooking = false
end

function AutoGrenadeJump._grounded(self: AutoGrenadeJump, state: any, constants: any): boolean
	if type(constants) ~= "table" then
		return false
	end
	return (state.inAir or 0) <= (constants.coyoteTime or 0) and (state.jump or 0) <= 0 and state.vel.y <= 0
end

function AutoGrenadeJump._step(self: AutoGrenadeJump, command: any, simulation: any): ()
	if type(command) ~= "table" or type(simulation) ~= "table" then
		return
	end
	local state = simulation.state
	local constants = simulation.constants
	if type(state) ~= "table" then
		return
	end
	local now = command.serverTime or 0

	if not peek(clientState.alive) or peek(clientState.matchId) == nil then
		if self._phase ~= "idle" then
			self:_reset()
		end
		return
	end

	if self._phase == "idle" then
		local start = false
		if self._burstArmed then
			self._burstArmed = false
			start = true
		elseif self._active and now >= self._cooldownUntil and self:_grounded(state, constants) then
			start = true
		end
		if not start then
			return
		end
		local grenade = resolveGrenade(state, now)
		if not grenade then
			return
		end
		self._grenade = grenade
		self._start = now
		self._cooking = false
		self._phase = "cook"
	end

	if self._phase == "cooldown" then
		if now >= self._cooldownUntil then
			self:_reset()
		end
		return
	end

	local grenade = self._grenade
	if self._phase ~= "cook" or not grenade then
		return
	end

	if now - self._start > MAX_WAIT then
		self._cooldownUntil = now + COOLDOWN
		self._phase = "cooldown"
		return
	end

	command.pitch = -PITCH_DOWN

	if (state.equippedSlot or 1) ~= grenade.slot then
		command.slot = grenade.slot
		return
	end

	command.buttons = bit32.bor(command.buttons or 0, BTN_PRIMARY)

	local cookStart = state["slot" .. grenade.slot .. "_cookStartServerTime"] or 0
	if cookStart > 0 then
		self._cooking = true
		local elapsed = now - cookStart
		if elapsed >= grenade.fuse - JUMP_LEAD and self:_grounded(state, constants) then
			command.y = 1
		end
	elseif self._cooking then
		self._cooldownUntil = now + COOLDOWN
		self._phase = "cooldown"
	end
end

function AutoGrenadeJump.Enable(self: AutoGrenadeJump): ()
	if self._installed then
		return
	end
	self._installed = true

	self:Track(CommandBaseController.Register(LPH_NO_VIRTUALIZE(function(command: any, module: any): ()
		local localChickynoid = module and module.localChickynoid
		local simulation = localChickynoid and localChickynoid.simulation
		if simulation then
			self:_step(command, simulation)
		end
	end)))
end

function AutoGrenadeJump.Disable(self: AutoGrenadeJump): ()
	self:_reset()
end

function AutoGrenadeJump.Destroy(self: AutoGrenadeJump): ()
	self._active = false
	self._burstArmed = false
	self:_reset()
	BaseFeature.Destroy(self)
end

export type AutoGrenadeJump =
	typeof(setmetatable(
		{} :: {
			_active: boolean,
			_burstArmed: boolean,
			_phase: string,
			_grenade: any,
			_start: number,
			_cooking: boolean,
			_cooldownUntil: number,
			_installed: boolean,
			_reset: (AutoGrenadeJump) -> (),
			_grounded: (AutoGrenadeJump, any, any) -> boolean,
			_step: (AutoGrenadeJump, any, any) -> (),
		},
		AutoGrenadeJump
	))
	& BaseFeature.BaseFeature

return AutoGrenadeJump
