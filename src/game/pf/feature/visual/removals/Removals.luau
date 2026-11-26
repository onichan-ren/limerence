local BaseFeature = require("@game/BaseFeature")
local ModuleController = require("@game/pf/module/ModuleController")
local hook = require("@share/hook")
local gameUi = require("@game/gameUi")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Players = cloneref(game:GetService("Players")) :: Players
local LocalPlayer = Players.LocalPlayer

local function isTeammate(object: any): boolean
	local player = rawget(object, "_player")
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	if player == LocalPlayer then
		return false
	end
	return player.TeamColor == LocalPlayer.TeamColor
end

local SOUND_OPTIONS = {
	"Hitmarker",
	"Footsteps",
	"Gunshots",
	"Impacts",
	"Melee",
}

local LABEL_TO_CAT: { [string]: string } = {
	["Hitmarker"] = "hit",
	["Footsteps"] = "footsteps",
	["Gunshots"] = "gunshot",
	["Impacts"] = "impact",
	["Melee"] = "melee",
}

local _blocked: { [string]: boolean } = {}
local _soundHooked = false
local _audio: any = nil

local function classifyPlay(name: any, group: any): string?
	if name == "hitmarker" then
		return "hit"
	end
	if group == "SelfFoley" then
		return "footsteps"
	end
	if type(name) == "string" then
		if string.sub(name, 1, 6) == "enemy_" or string.sub(name, 1, 9) == "friendly_" then
			return "footsteps"
		end
		if string.sub(name, 1, 4) == "imp_" then
			return "impact"
		end
	end
	return nil
end

local function isMeleeSound(name: any): boolean
	if type(name) ~= "string" then
		return false
	end
	local character = ModuleController.GetModule("CharacterInterface")
	if not character then
		return false
	end
	local co = character.getCharacterObject()
	local wc = co and co:getWeaponController()
	local weapon = wc and wc:getActiveWeapon()
	local class: any = nil
	if weapon and weapon.getWeaponType and weapon:getWeaponType() == "Melee" then
		class = weapon:getWeaponStat("soundClassification")
	end
	if type(class) ~= "string" or class == "" then
		return false
	end
	return name == class or name == class .. "Equip"
end

local function installSoundHooks(): ()
	if _soundHooked then
		return
	end
	local AudioSystem = ModuleController.GetModule("AudioSystem")
	if not AudioSystem or type(AudioSystem.playSound) ~= "function" or type(AudioSystem.playSoundId) ~= "function" then
		return
	end
	_audio = AudioSystem
	_soundHooked = true

	local playOriginal
	playOriginal = hook.add(
		AudioSystem.playSound,
		LPH_NO_VIRTUALIZE(function(name: any, group: any, ...): any
			local cat = classifyPlay(name, group)
			if cat and _blocked[cat] then
				return
			end
			if _blocked.melee and isMeleeSound(name) then
				return
			end
			return playOriginal(name, group, ...)
		end)
	)

	local idOriginal
	idOriginal = hook.add(
		AudioSystem.playSoundId,
		LPH_NO_VIRTUALIZE(function(id: any, category: any, ...): any
			if _blocked.gunshot and category == 2 then
				return
			end
			return idOriginal(id, category, ...)
		end)
	)
end

local function removeSoundHooks(): ()
	if not _soundHooked then
		return
	end
	_soundHooked = false
	if _audio then
		hook.restore(_audio.playSound)
		hook.restore(_audio.playSoundId)
	end
	_audio = nil
end

local _animBlock = { reload = false }
local _animHooked = false
local _animModule: any = nil

local function shouldBlockAnim(name: any): boolean
	if _animBlock.reload and type(name) == "string" and string.find(name, "reload", 1, true) then
		return true
	end
	return false
end

local function getActiveFirearm(): any?
	local character = ModuleController.GetModule("CharacterInterface")
	if not character then
		return nil
	end
	local co = character.getCharacterObject()
	local wc = co and co:getWeaponController()
	local active = wc and wc:getActiveWeapon()
	if active and active.getWeaponType and active:getWeaponType() == "Firearm" then
		return active
	end
	return nil
end

local NOOP_HANDLE = LPH_NO_VIRTUALIZE(function(): () end)

local function installAnimHook(): ()
	if _animHooked then
		return
	end
	local Animation = ModuleController.GetModule("Animation")
	if not Animation or type(Animation.player) ~= "function" then
		return
	end
	_animModule = Animation
	_animHooked = true

	local original
	original = hook.add(
		Animation.player,
		LPH_NO_VIRTUALIZE(function(animData: any, animTable: any, weapon: any, name: any): any
			if shouldBlockAnim(name) then
				return NOOP_HANDLE
			end
			return original(animData, animTable, weapon, name)
		end)
	)
end

local function removeAnimHook(): ()
	if not _animHooked then
		return
	end
	_animHooked = false
	if _animModule then
		hook.restore(_animModule.player)
	end
	_animModule = nil
end

local function applyAnimHooks(): ()
	if _animBlock.reload then
		installAnimHook()
	else
		removeAnimHook()
	end
end

local Removals = {}
Removals.__index = Removals

setmetatable(Removals, { __index = BaseFeature })

local IDENTITY = LPH_NO_VIRTUALIZE(function(): CFrame
	return CFrame.identity
end)

local NOOP = LPH_NO_VIRTUALIZE(function(): () end)

local ZERO_SWAY = LPH_NO_VIRTUALIZE(function(camera: any): ()
	local spring = camera and camera._swaySpring
	if spring then
		spring.t = 0
		spring.v = 0
		spring.p = 0
	end
end)

function Removals.hookTargets(self: Removals, key: string, targets: { any }, replacement: any): ()
	local stored = {}
	for _, target in next, targets do
		if type(target) == "function" then
			hook.add(target, replacement)
			table.insert(stored, target)
		end
	end
	self._hooks[key] = stored
end

function Removals.unhookTargets(self: Removals, key: string): ()
	local stored = self._hooks[key]
	if not stored then
		return
	end
	for _, target in next, stored do
		hook.restore(target)
	end
	self._hooks[key] = nil
end

function Removals.EnableSway(self: Removals): ()
	local Sway = ModuleController.GetModule("Sway")
	local Firearm = ModuleController.GetModule("FirearmObject")
	local Melee = ModuleController.GetModule("MeleeObject")
	local Grenade = ModuleController.GetModule("GrenadeObject")
	self:hookTargets("sway", {
		Sway and Sway.getSwayCFrame,
		Sway and Sway.getBobCFrame,
		Sway and Sway.getBreathCFrame,
		Firearm and Firearm.computeWalkSway,
		Firearm and Firearm.computeGunSway,
		Melee and Melee.walkSway,
		Melee and Melee.meleeSway,
		Grenade and Grenade.walkSway,
		Grenade and Grenade.modelSway,
	}, IDENTITY)
end

function Removals.EnableScopeSway(self: Removals): ()
	local camera = ModuleController.GetModule("MainCameraObject")
	self:hookTargets("scopeSway", { camera and camera.setSway }, ZERO_SWAY)
end

function Removals.EnableMuzzle(self: Removals): ()
	local Effects = ModuleController.GetModule("Effects")
	self:hookTargets("muzzle", { Effects and Effects.muzzleflash }, NOOP)
end

function Removals.EnableShells(self: Removals): ()
	local Effects = ModuleController.GetModule("Effects")
	self:hookTargets("shells", { Effects and Effects.ejectshell }, NOOP)
end

function Removals.EnableFlinch(self: Removals): ()
	local camera = ModuleController.GetModule("MainCameraObject")
	self:hookTargets("flinch", { camera and camera.hit }, NOOP)
end

function Removals.EnableCameraBob(self: Removals): ()
	local camera = ModuleController.GetModule("MainCameraObject")
	local character = ModuleController.GetModule("CharacterInterface")
	local step = camera and camera.step
	if type(step) ~= "function" or not character then
		return
	end
	local original
	original = hook.add(
		step,
		LPH_NO_VIRTUALIZE(function(cam: any, dt: any): ()
			local co = character.getCharacterObject()
			local realSpeed
			if co then
				realSpeed = co._speed
				co._speed = 0
			end
			local sway = cam._swaySpring
			if sway then
				sway.t = 0
				sway.v = 0
				sway.p = 0
			end
			original(cam, dt)
			if co then
				co._speed = realSpeed
			end
		end)
	)
	self._hooks["cameraBob"] = { step }
end

function Removals.EnableTeammateRender(self: Removals): ()
	local thirdPerson = ModuleController.GetModule("ThirdPersonObject")
	local setCharacterRender = thirdPerson and rawget(thirdPerson, "setCharacterRender")
	if type(setCharacterRender) ~= "function" then
		return
	end
	local original
	original = hook.add(
		setCharacterRender,
		LPH_NO_VIRTUALIZE(function(object: any, value: any, ...: any): ...any
			if not checkcaller() and value and isTeammate(object) then
				value = false
			end
			return original(object, value, ...)
		end)
	)
	self._hooks["teammateRender"] = { setCharacterRender }
end

function Removals.EnableIndicators(self: Removals): ()
	local blood = ModuleController.GetModule("HudBloodArcInterface")
	if blood and blood.clearAllEntries then
		blood.clearAllEntries()
	end
	self:hookTargets("indicators", { blood and blood.addEntry }, NOOP)
end

local patchSprintPose = LPH_NO_VIRTUALIZE(function(self: Removals): ()
	local weapon = getActiveFirearm()
	if not weapon then
		return
	end
	local current = weapon._sprintPoseSpring
	if current == nil or current == self._sprintProxy then
		return
	end
	current.t = 0
	current.p = 0
	local proxy = setmetatable({}, {
		__index = function(_, key: any): any
			return current[key]
		end,
		__newindex = function(_, key: any, value: any): ()
			if key ~= "t" then
				current[key] = value
			end
		end,
	})
	weapon._sprintPoseSpring = proxy
	self._sprintProxy = proxy
	self._sprintReal = current
	self._sprintWeapon = weapon
end)

function Removals.EnableSprintPose(self: Removals): ()
	if self._sprintConn then
		return
	end
	self._sprintConn = RunService.PreRender:Connect(function(): ()
		patchSprintPose(self)
	end)
end

function Removals.DisableSprintPose(self: Removals): ()
	if self._sprintConn then
		self._sprintConn:Disconnect()
		self._sprintConn = nil
	end
	if self._sprintWeapon and self._sprintReal and self._sprintWeapon._sprintPoseSpring == self._sprintProxy then
		self._sprintWeapon._sprintPoseSpring = self._sprintReal
	end
	self._sprintProxy = nil
	self._sprintReal = nil
	self._sprintWeapon = nil
end

function Removals.new(link: gameUi.Linker): Removals
	local self = BaseFeature.new() :: any
	setmetatable(self, Removals)

	self._hooks = {}

	link:Options("removals", "Removals")
	local removalsLink = link:OnKey("removals")

	removalsLink:Toggle("teammateRendering", "Teammate Rendering", false):SetTip({
		title = "Teammate Rendering",
		body = "Stops drawing your teammates' characters.",
	})
	removalsLink:Toggle("damageIndicators", "Damage Indicators", false):SetTip({
		title = "Damage Indicators",
		body = "Hides the direction indicators shown when you take damage.",
	})
	removalsLink:Toggle("reloadAnimation", "Reload Animation", false):SetTip({
		title = "Reload Animation",
		body = "Hides the reload animation while still reloading.",
	})
	removalsLink:Toggle("viewmodelSway", "Viewmodel Sway", false):SetTip({
		title = "Viewmodel Sway",
		body = "Locks the weapon still, removing sway, bob, and idle movement.",
	})
	removalsLink:Toggle("sprintAnimation", "Sprint Animation", false):SetTip({
		title = "Sprint Animation",
		body = "Keeps the weapon up while sprinting instead of lowering it.",
	})
	removalsLink:Toggle("damageFlinch", "Damage Flinch", false):SetTip({
		title = "Damage Flinch",
		body = "Removes the camera jolt when you take damage.",
	})
	removalsLink:Toggle("shellCasings", "Shell Casings", false):SetTip({
		title = "Shell Casings",
		body = "Stops ejected shell casings from spawning.",
	})
	removalsLink:Toggle("muzzleFlash", "Muzzle Flash", false):SetTip({
		title = "Muzzle Flash",
		body = "Hides the flash at the barrel when firing.",
	})
	removalsLink:Toggle("scopeSway", "Scope Sway", false):SetTip({
		title = "Scope Sway",
		body = "Holds your scope steady, removing the idle drift while aimed.",
	})
	removalsLink:Toggle("cameraBob", "Camera Bob", false):SetTip({
		title = "Camera Bob",
		body = "Stops the camera from swaying as you move.",
	})
	removalsLink:Dropdown("soundRemovals", "Sound Removals", SOUND_OPTIONS, {} :: any):SetMode("multi"):SetTip({
		title = "Sound Removals",
		body = "Mute selected in-game sounds.",
	})

	self._link = removalsLink

	local function bind(key: string, enable: (Removals) -> (), unhookKey: string): ()
		self:Track(removalsLink:Get(key):OnChange(function(value: boolean): ()
			if value then
				enable(self)
			else
				self:unhookTargets(unhookKey)
			end
		end))
	end

	bind("viewmodelSway", Removals.EnableSway, "sway")
	bind("scopeSway", Removals.EnableScopeSway, "scopeSway")
	bind("muzzleFlash", Removals.EnableMuzzle, "muzzle")
	bind("shellCasings", Removals.EnableShells, "shells")
	bind("damageFlinch", Removals.EnableFlinch, "flinch")
	bind("damageIndicators", Removals.EnableIndicators, "indicators")
	bind("cameraBob", Removals.EnableCameraBob, "cameraBob")
	bind("teammateRendering", Removals.EnableTeammateRender, "teammateRender")

	self:Track(removalsLink:Get("sprintAnimation"):OnChange(function(value: boolean): ()
		if value then
			self:EnableSprintPose()
		else
			self:DisableSprintPose()
		end
	end))

	self:Track(removalsLink:Get("reloadAnimation"):OnChange(function(value: boolean): ()
		_animBlock.reload = value == true
		applyAnimHooks()
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

	if removalsLink:Peek("viewmodelSway") then
		self:EnableSway()
	end
	if removalsLink:Peek("scopeSway") then
		self:EnableScopeSway()
	end
	if removalsLink:Peek("muzzleFlash") then
		self:EnableMuzzle()
	end
	if removalsLink:Peek("shellCasings") then
		self:EnableShells()
	end
	if removalsLink:Peek("damageFlinch") then
		self:EnableFlinch()
	end
	if removalsLink:Peek("cameraBob") then
		self:EnableCameraBob()
	end
	if removalsLink:Peek("damageIndicators") then
		self:EnableIndicators()
	end
	if removalsLink:Peek("teammateRendering") then
		self:EnableTeammateRender()
	end
	if removalsLink:Peek("sprintAnimation") then
		self:EnableSprintPose()
	end
	_animBlock.reload = removalsLink:Peek("reloadAnimation") == true
	applyAnimHooks()

	return self
end

function Removals.Destroy(self: Removals): ()
	for key in next, self._hooks do
		self:unhookTargets(key)
	end
	self:DisableSprintPose()
	removeSoundHooks()
	_animBlock.reload = false
	removeAnimHook()
	table.clear(_blocked)
	BaseFeature.Destroy(self)
end

export type Removals =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_hooks: { [string]: { any } },
			_sprintConn: RBXScriptConnection?,
			_sprintProxy: any,
			_sprintReal: any,
			_sprintWeapon: any,
		},
		Removals
	))
	& BaseFeature.BaseFeature

return Removals
