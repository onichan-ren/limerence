local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local NetworkController = require("@game/bloxstrike/network/NetworkController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

local peek = Charm.peek

local InstantReload = {}
InstantReload.__index = InstantReload

setmetatable(InstantReload, { __index = BaseFeature })

local _instance: any = nil

local handledReload: any = nil
local handledReloadTick: number = -1
local lastMagazineSent: number = 0

local applyInstantReload = LPH_JIT_MAX(function(weapon: any): ()
	if not weapon then
		return
	end
	if weapon.IsEquipped ~= true then
		return
	end
	local props = weapon.Properties
	if not props then
		return
	end
	local maxRounds = props.Rounds
	if not maxRounds or maxRounds <= 0 then
		return
	end
	local currentRounds = weapon.Rounds or 0
	if currentRounds >= maxRounds then
		weapon.IsReloading = false
		return
	end
	local capacity = weapon.Capacity or 0
	local needed = maxRounds - currentRounds

	if type(weapon.Identifier) == "string" then
		local now = tick()
		if now - lastMagazineSent < 1.05 then
			return
		end
		lastMagazineSent = now
		setthreadidentity(2)
		NetworkController.SendPacket("Inventory", "CreateMagazine", weapon.Identifier)
		NetworkController.SendPacket("Inventory", "ReloadWeapon", {
			Identifier = weapon.Identifier,
			Capacity = capacity,
			Rounds = currentRounds,
		})
		setthreadidentity(8)
	end

	if Workspace:GetAttribute("Gamemode") == "Deathmatch" then
		weapon.Rounds = maxRounds
	else
		local available = math.min(needed, capacity)
		weapon.Rounds = currentRounds + available
		weapon.Capacity = capacity - available
	end

	if weapon.ReloadTrackFinishedConnection then
		weapon.ReloadTrackFinishedConnection:Disconnect()
		weapon.ReloadTrackFinishedConnection = nil
	end

	weapon.CurrentReloadIdentity = nil
	weapon.IsReloading = false

	local viewmodel = weapon.Viewmodel
	if viewmodel and viewmodel.Animation then
		viewmodel.Animation:stop("Reload", 0)
		viewmodel.Animation:stop("ReloadStart", 0)
		viewmodel.Animation:stop("ReloadAction", 0)
		viewmodel.Animation:stop("ReloadEnd", 0)
	end
	if weapon.CharacterAnimator then
		weapon.CharacterAnimator:stop("Reload", 0)
	end
end)

function InstantReload.new(link: gameUi.Linker): InstantReload
	local self = BaseFeature.new() :: any
	setmetatable(self, InstantReload)

	link:Toggle("instantReload", "Instant Reload", false):SetTip({
		title = "Instant Reload",
		body = "Reloads finish instantly with no animation.",
	})

	self._janitor = Janitor.new()
	self._enabled = false
	self._enabledLink = link:Get("instantReload")

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("instantReload") then
		self:Enable()
	end

	_instance = self
	return self
end

function InstantReload.Enable(self: InstantReload): ()
	if self._enabled then
		return
	end
	self._enabled = true
	handledReload = nil

	self._janitor:Add(
		RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
			local weapon = peek(loadoutState.currentEquipped) :: any
			if not weapon then
				handledReload = nil
				return
			end
			if not weapon.IsReloading then
				if handledReload == weapon then
					handledReload = nil
				end
				return
			end
			local reloadTick = weapon.ReloadStartTick or 0
			if handledReload == weapon and handledReloadTick == reloadTick then
				return
			end
			handledReload = weapon
			handledReloadTick = reloadTick
			applyInstantReload(weapon)
		end)),
		"Disconnect"
	)
end

function InstantReload.Disable(self: InstantReload): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	handledReload = nil
	self._janitor:Cleanup()
end

function InstantReload.Destroy(self: InstantReload): ()
	self:Disable()
	if (_instance :: any) == self then
		_instance = nil
	end
	BaseFeature.Destroy(self)
end

function InstantReload.IsEnabled(): boolean
	return _instance ~= nil and _instance._enabled == true
end

export type InstantReload =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_enabledLink: any,
			_janitor: Janitor.Janitor,
		},
		InstantReload
	))
	& BaseFeature.BaseFeature

return InstantReload
