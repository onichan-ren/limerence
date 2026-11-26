local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local Players = cloneref(game:GetService("Players")) :: Players
local WeaponController = require("@game/bloxstrike/weapon/WeaponController")
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local grenadeState = require("@game/bloxstrike/grenade/grenadeState")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local hook = require("@share/hook")
local gameUi = require("@game/gameUi")

local observe = Charm.observe
local peek = Charm.peek

local LocalPlayer = Players.LocalPlayer

local SOUND_OPTIONS = {
	"Enemy Reload",
	"Enemy Shoot",
	"Enemy Equip",
	"Local Reload",
	"Local Shoot",
	"Local Equip",
	"Kill Sounds",
	"Hitmarkers",
	"Grenades",
	"Bomb",
}

local LABEL_TO_CAT: { [string]: string } = {
	["Local Reload"] = "localReload",
	["Enemy Reload"] = "enemyReload",
	["Local Shoot"] = "localShoot",
	["Enemy Shoot"] = "enemyShoot",
	["Local Equip"] = "localEquip",
	["Enemy Equip"] = "enemyEquip",
	["Kill Sounds"] = "kill",
	["Hitmarkers"] = "hit",
	["Grenades"] = "grenade",
	["Bomb"] = "bomb",
}

local SHOOT_NAMES: { [string]: boolean } = { Shoot = true }
local RELOAD_NAMES: { [string]: boolean } =
	{ MagIn = true, MagOut = true, Bolt = true, InsertShell = true, Pump = true, Lever = true }
local EQUIP_NAMES: { [string]: boolean } = { Equip = true, Draw = true, Switch = true }

local _blocked: { [string]: boolean } = {}
local _hooked = false
local _soundClass: any = nil
local _playOriginal: any = nil
local _posOriginal: any = nil
local _playerGui: Instance? = nil

local function classify(group: any, name: any, isLocal: boolean): string?
	if type(name) ~= "string" then
		return nil
	end
	if SHOOT_NAMES[name] then
		return isLocal and "localShoot" or "enemyShoot"
	end
	if RELOAD_NAMES[name] then
		return isLocal and "localReload" or "enemyReload"
	end
	if EQUIP_NAMES[name] then
		return isLocal and "localEquip" or "enemyEquip"
	end
	if group == "Grenade" then
		return "grenade"
	end
	if group == "Deathmatch" then
		return "kill"
	end
	if name == "Headshot" or name == "Helmet Headshot" then
		return "hit"
	end
	if string.find(name, "Bomb", 1, true) then
		return "bomb"
	end
	return nil
end

local function isLocalParent(parent: any): boolean
	if parent == nil or _playerGui == nil then
		return false
	end
	if parent == _playerGui then
		return true
	end
	return typeof(parent) == "Instance" and parent:IsDescendantOf(_playerGui)
end

local function installSoundHooks(): ()
	if _hooked then
		return
	end
	local SoundClass = ModuleController.GetModule("SoundClass")
	if not SoundClass or type(SoundClass.play) ~= "function" or type(SoundClass.PlaySoundAtPosition) ~= "function" then
		return
	end
	_soundClass = SoundClass

	_playOriginal = hook.add(SoundClass.play, function(self: any, params: any, vol: any): any
		if type(params) == "table" then
			local cat = classify(self.SoundGroupName, params.Name, isLocalParent(params.Parent))
			if cat and _blocked[cat] then
				return nil
			end
		end
		return _playOriginal(self, params, vol)
	end)

	_posOriginal = hook.add(SoundClass.PlaySoundAtPosition, function(self: any, params: any, ...: any): any
		if type(params) == "table" then
			local cat = classify(self.SoundGroupName, params.Name, false)
			if cat and _blocked[cat] then
				self.destroy(self)
				return
			end
		end
		return _posOriginal(self, params, ...)
	end)

	_hooked = true
end

local function removeSoundHooks(): ()
	if not _hooked then
		return
	end
	_hooked = false
	if _soundClass then
		hook.restore(_soundClass.play)
		hook.restore(_soundClass.PlaySoundAtPosition)
	end
	_soundClass = nil
	_playOriginal = nil
	_posOriginal = nil
end

local Removals = {}
Removals.__index = Removals

setmetatable(Removals, { __index = BaseFeature })

function Removals.new(link: gameUi.Linker): Removals
	local self = BaseFeature.new() :: any
	setmetatable(self, Removals)

	_playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")

	link:Options("removals", "Removals")
	local removalsLink = link:OnKey("removals")
	removalsLink:Toggle("smokes", "Smoke Particles", false):SetTip({
		title = "Smoke Particles",
		body = "Hides smoke clouds so they do not block your view.",
	})
	removalsLink:Toggle("weaponBobble", "Weapon Bobble", false):SetTip({
		title = "Weapon Bobble",
		body = "Stops viewmodel sway/bobble while moving.",
	})
	removalsLink:Toggle("bulletImpacts", "Bullet Impacts", false):SetTip({
		title = "Bullet Impacts",
		body = "Hides hit impact particles on surfaces and players.",
	})
	removalsLink:Toggle("weaponKick", "Weapon Kick", false):SetTip({
		title = "Weapon Kick",
		body = "Disables weapon kick.",
	})
	removalsLink:Toggle("flashes", "Flash Effect", false):SetTip({
		title = "Flash Effect",
		body = "Shortens or removes flashbang blindness. Use Time Reduction to scale duration.",
	})
	removalsLink:Toggle("bulletHoles", "Bullet Holes", false):SetTip({
		title = "Bullet Holes",
		body = "Hides bullet holes left on surfaces.",
	})
	removalsLink:Toggle("aimPunch", "Aim Punch", false):SetTip({
		title = "Aim Punch",
		body = "Disables camera kick when you take damage.",
	})

	removalsLink:Dropdown("soundRemovals", "Sound Removals", SOUND_OPTIONS, {} :: any):SetMode("multi"):SetTip({
		title = "Sound Removals",
		body = "Mute selected in-game sounds.",
	})

	local flashLink = removalsLink:OnKey("flashes")
	flashLink:Submenu("opts", "Flash Effect")
	local flashOptsLink = flashLink:OnKey("opts")
	flashOptsLink:Slider("timeReduction", "Time Reduction", 100, 1, 100, 1, nil, "%"):SetTip({
		title = "Time Reduction",
		body = "Percent of flash duration to remove. 100% removes the effect entirely.",
	})

	self._flashLink = flashOptsLink

	self:Track(removalsLink:Get("smokes"):OnChange(function(value: boolean): ()
		if value then
			self:EnableSmokes()
		else
			self:DisableSmokes()
		end
	end))

	self:Track(removalsLink:Get("flashes"):OnChange(function(value: boolean): ()
		if value then
			self:EnableFlashes()
		else
			self:DisableFlashes()
		end
	end))

	self:Track(removalsLink:Get("aimPunch"):OnChange(function(value: boolean): ()
		if value then
			self:EnableAimPunch()
		else
			self:DisableAimPunch()
		end
	end))

	self:Track(removalsLink:Get("weaponBobble"):OnChange(function(value: boolean): ()
		if value then
			self:EnableWeaponBobble()
		else
			self:DisableWeaponBobble()
		end
	end))

	self:Track(removalsLink:Get("weaponKick"):OnChange(function(value: boolean): ()
		if value then
			self:EnableWeaponKick()
		else
			self:DisableWeaponKick()
		end
	end))

	self:Track(removalsLink:Get("bulletHoles"):OnChange(function(value: boolean): ()
		if value then
			self:EnableBulletHoles()
		else
			self:DisableBulletHoles()
		end
	end))

	self:Track(removalsLink:Get("bulletImpacts"):OnChange(function(value: boolean): ()
		if value then
			self:EnableBulletImpacts()
		else
			self:DisableBulletImpacts()
		end
	end))

	local function applySounds(value: any): ()
		table.clear(_blocked)
		if type(value) == "table" then
			for _, label in next, value do
				local cat = LABEL_TO_CAT[label]
				if cat then
					_blocked[cat] = true
				end
			end
		end
		if next(_blocked) then
			installSoundHooks()
		else
			removeSoundHooks()
		end
	end

	self:Track(removalsLink:Get("soundRemovals"):OnChange(applySounds))
	applySounds(removalsLink:Peek("soundRemovals"))

	if removalsLink:Peek("smokes") then
		self:EnableSmokes()
	end
	if removalsLink:Peek("flashes") then
		self:EnableFlashes()
	end
	if removalsLink:Peek("aimPunch") then
		self:EnableAimPunch()
	end
	if removalsLink:Peek("weaponBobble") then
		self:EnableWeaponBobble()
	end
	if removalsLink:Peek("weaponKick") then
		self:EnableWeaponKick()
	end
	if removalsLink:Peek("bulletHoles") then
		self:EnableBulletHoles()
	end
	if removalsLink:Peek("bulletImpacts") then
		self:EnableBulletImpacts()
	end

	return self
end

local HIDDEN_SEQUENCE = NumberSequence.new(1)

local hideSmoke = LPH_NO_VIRTUALIZE(function(smokeData: any): ()
	for _, voxel in next, smokeData.voxels do
		for _, emitter in next, voxel:QueryDescendants("ParticleEmitter") do
			emitter.Transparency = HIDDEN_SEQUENCE
		end
	end
end)

function Removals.EnableSmokes(self: Removals): ()
	if self._smokesCleanup then
		return
	end

	self._smokesCleanup = observe(
		grenadeState.activeSmokes,
		LPH_NO_VIRTUALIZE(function(smokeData: any, key: string): ()
			hideSmoke(smokeData)
		end)
	)

	for _, smokeData in next, peek(grenadeState.activeSmokes) do
		hideSmoke(smokeData)
	end
end

function Removals.DisableSmokes(self: Removals): ()
	if self._smokesCleanup then
		self._smokesCleanup()
		self._smokesCleanup = nil
	end
end

function Removals.EnableFlashes(self: Removals): ()
	if self._flashesEnabled then
		return
	end

	self._flashesEnabled = true

	local FlashClass = ModuleController.GetModule("FlashClass")

	local flashLink = self._flashLink

	local flashClosure = rawget(FlashClass, "Flash") :: any
	local internalCalc = debug.getupvalue(flashClosure, 4)

	if not hook.isFunctionHooked(internalCalc) then
		local oldInternalCalc
		oldInternalCalc = hook.add(
			internalCalc,
			LPH_NO_VIRTUALIZE(function(...)
				local duration: number, dot, strength, bucket, ratio = oldInternalCalc(...)

				local timeReduction = flashLink:Peek("timeReduction") :: number
				duration *= (1 - timeReduction / 100)

				return duration, dot, strength, bucket, ratio
			end)
		) :: any
	end
end

function Removals.DisableFlashes(self: Removals): ()
	if not self._flashesEnabled then
		return
	end

	self._flashesEnabled = false

	local FlashClass = ModuleController.GetModule("FlashClass")

	local flashClosure = rawget(FlashClass, "Flash") :: any
	local internalCalc = debug.getupvalue(flashClosure, 4)

	hook.restore(internalCalc)
end

function Removals.EnableAimPunch(self: Removals): ()
	if self._aimPunchEnabled then
		return
	end

	self._aimPunchEnabled = true

	local CameraController = ModuleController.GetModule("CameraController")
	local aimPunch = rawget(CameraController, "flinch") :: any

	if not aimPunch then
		return
	end
	debug.setconstant(aimPunch, 1, Vector3.new(0, 0, 0) :: any)
end

function Removals.DisableAimPunch(self: Removals): ()
	if not self._aimPunchEnabled then
		return
	end

	self._aimPunchEnabled = false

	local CameraController = ModuleController.GetModule("CameraController")
	local aimPunch = rawget(CameraController, "flinch") :: any

	if not aimPunch then
		return
	end

	debug.setconstant(aimPunch, 1, Vector3.new(30, 0, 0) :: any)
end

function Removals.EnableWeaponBobble(self: Removals): ()
	if self._weaponBobbleEnabled then
		return
	end

	self._weaponBobbleEnabled = true

	local Bobble = ModuleController.GetModule("Bobble")
	local getNextCFrame = rawget(Bobble, "getNextCFrame") :: any

	if not getNextCFrame then
		return
	end

	local identity, zero = CFrame.identity, Vector3.zero
	hook.add(
		getNextCFrame,
		LPH_NO_VIRTUALIZE(function(self: any, n1: number): ()
			return identity, zero, zero
		end)
	)
end

function Removals.DisableWeaponBobble(self: Removals): ()
	if not self._weaponBobbleEnabled then
		return
	end

	self._weaponBobbleEnabled = false

	local Bobble = ModuleController.GetModule("Bobble")
	local getNextCFrame = rawget(Bobble, "getNextCFrame") :: any

	if not getNextCFrame then
		return
	end

	hook.restore(getNextCFrame)
end

function Removals.EnableWeaponKick(self: Removals): ()
	if self._weaponKickEnabled then
		return
	end
	self._weaponKickEnabled = true

	local WeaponClass = ModuleController.GetModule("WeaponClass")
	local shoot = rawget(WeaponClass, "shoot")
	if not shoot then
		return
	end

	local kickCamera = getupvalue(shoot, 23)
	local oldWeaponKick = getupvalue(kickCamera, 1)

	debug.setupvalue(kickCamera, 1, {
		weaponKick = function() end,
	})

	self._oldWeaponKick = oldWeaponKick
end

function Removals.DisableWeaponKick(self: Removals): ()
	if not self._weaponKickEnabled then
		return
	end
	self._weaponKickEnabled = false

	local WeaponClass = ModuleController.GetModule("WeaponClass")
	local shoot = rawget(WeaponClass, "shoot")
	if not shoot then
		return
	end

	local kickCamera = getupvalue(shoot, 23)
	debug.setupvalue(kickCamera, 1, self._oldWeaponKick)
end
function Removals.EnableBulletHoles(self: Removals): ()
	if self._bulletHolesEnabled then
		return
	end
	self._bulletHolesEnabled = true

	local WeaponClass = ModuleController.GetModule("WeaponClass")
	local shoot = rawget(WeaponClass, "shoot")
	if not shoot then
		return
	end

	local createMarker = debug.getupvalue(shoot, 22)

	if not hook.isFunctionHooked(createMarker) then
		hook.add(createMarker, LPH_NO_VIRTUALIZE(function(): () end))
	end

	local debris = Workspace:FindFirstChild("Debris")
	if debris then
		for _, child in next, debris:GetChildren() do
			if child.Name == "HitMarker" then
				child:Destroy()
			end
		end
	end
end

function Removals.DisableBulletHoles(self: Removals): ()
	if not self._bulletHolesEnabled then
		return
	end
	self._bulletHolesEnabled = false

	local WeaponClass = ModuleController.GetModule("WeaponClass")
	local shoot = rawget(WeaponClass, "shoot")
	if not shoot then
		return
	end

	hook.restore(debug.getupvalue(shoot, 22))
end

function Removals.EnableBulletImpacts(self: Removals): ()
	if self._bulletImpactsEnabled then
		return
	end
	self._bulletImpactsEnabled = true

	WeaponController.SetImpactsSuppressed(true)
end

function Removals.DisableBulletImpacts(self: Removals): ()
	if not self._bulletImpactsEnabled then
		return
	end
	self._bulletImpactsEnabled = false

	WeaponController.SetImpactsSuppressed(false)
end

function Removals.Destroy(self: Removals): ()
	self:DisableSmokes()
	self:DisableFlashes()
	self:DisableAimPunch()
	self:DisableWeaponBobble()
	self:DisableWeaponKick()
	self:DisableBulletHoles()
	self:DisableBulletImpacts()
	removeSoundHooks()
	table.clear(_blocked)
	BaseFeature.Destroy(self)
end

export type Removals =
	typeof(setmetatable(
		{} :: {
			_smokesCleanup: () -> ()?,
			_flashLink: gameUi.Linker,
			_flashesEnabled: boolean,
			_aimPunchEnabled: boolean,
			_weaponBobbleEnabled: boolean,
			_weaponKickEnabled: boolean,
			_oldWeaponKick: any,
			_bulletHolesEnabled: boolean,
			_bulletImpactsEnabled: boolean,
		},
		Removals
	))
	& BaseFeature.BaseFeature

return Removals
