local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local WeaponController = require("@game/ar2/weapon/WeaponController")
local AnimatorHook = require("@game/ar2/animator/AnimatorHook")
local Charm = require("@pkg/Charm")
local clientState = require("@game/ar2/client/clientState")
local hook = require("@share/hook")

local peek = Charm.peek

local Lighting = cloneref(game:GetService("Lighting")) :: Lighting
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local Players = cloneref(game:GetService("Players")) :: Players

local MENU_GUI = "MainMenu"
local MENU_BACKGROUND = "Background"
local MENU_BACKDROP = "ContentBackdrop"

local function findMenuBackground(): Frame?
	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	for _, descendant in next, playerGui:QueryDescendants("GuiObject") do
		if descendant.Name == MENU_BACKGROUND then
			local parent = descendant.Parent
			if parent and parent.Name == MENU_GUI then
				return descendant :: Frame
			end
		end
	end
	return nil
end

local NEUTRAL_TINT = Color3.fromRGB(255, 255, 255)
local DUST_EMITTERS = {
	{ "StaticDust", "Bigs" },
	{ "StaticDust", "Smalls" },
	{ "StormDust", "Clouds" },
	{ "StormDebris", "Debris" },
}

local function setModelHidden(model: Instance, hidden: boolean, touched: { [Instance]: true }?): ()
	for _, inst in next, model:QueryDescendants("BasePart") do
		local part = inst :: BasePart
		if hidden then
			part.LocalTransparencyModifier = 1
			if touched and part.CanCollide then
				part.CanCollide = false
				touched[part] = true
			end
		else
			part.LocalTransparencyModifier = 0
		end
	end
end

local function firstInstanceArg(...: any): Instance?
	for i = 1, select("#", ...) do
		local arg = select(i, ...)
		if typeof(arg) == "Instance" then
			return arg
		end
	end
	return nil
end

local Removals = {}
Removals.__index = Removals

setmetatable(Removals, { __index = BaseFeature })

function Removals.new(link: gameUi.Linker): Removals
	local self = BaseFeature.new() :: any
	setmetatable(self, Removals)

	local removalsLink = link
	removalsLink:Toggle("lowHealthScreen", "Low Health Screen", false):SetTip({
		title = "Low Health Screen",
		body = "Removes the gray low health screen tint.",
	})
	removalsLink:Toggle("menuBackground", "Menu Background", false):SetTip({
		title = "Menu Background",
		body = "Removes the dark backdrop behind menus so you can see the game.",
	})
	removalsLink:Toggle("ambientParticles", "Ambient Particles", false):SetTip({
		title = "Ambient Particles",
		body = "Hides floating dust, leaves and storm debris.",
	})
	removalsLink:Toggle("weaponBobble", "Weapon Bobble", false):SetTip({
		title = "Weapon Bobble",
		body = "Stops viewmodel sway/bobble while moving.",
	})
	removalsLink:Toggle("bulletImpacts", "Bullet Impacts", false):SetTip({
		title = "Bullet Impacts",
		body = "Hides impact particles, bullet holes and impact sounds.",
	})
	removalsLink:Toggle("damageFlash", "Damage Flash", false):SetTip({
		title = "Damage Flash",
		body = "Removes the screen flash and blur when you take damage.",
	})
	removalsLink:Toggle("muzzleFlash", "Muzzle Flash", false):SetTip({
		title = "Muzzle Flash",
		body = "Hides the flash at the barrel when firing.",
	})
	removalsLink:Toggle("fireImpulse", "Fire Impulse", false):SetTip({
		title = "Fire Impulse",
		body = "Removes the visual impulse when firing a fire weapon.",
	})
	removalsLink:Toggle("menuBlur", "Menu Blur", false):SetTip({
		title = "Menu Blur",
		body = "Keeps the world sharp behind open menus.",
	})
	removalsLink:Toggle("tracers", "Tracers", false):SetTip({
		title = "Tracers",
		body = "Hides the streaks bullets leave in the air.",
	})
	removalsLink:Toggle("doors", "Doors", false):SetTip({
		title = "Doors",
		body = "Hides doors and lets you walk through them.",
	})
	removalsLink:Toggle("windows", "Windows", false):SetTip({
		title = "Windows",
		body = "Hides window glass and frames and lets you walk through them.",
	})

	self._muzzleTargets = nil
	self._updateTracer = nil
	self._damageFade = nil
	self._damageFadeBlocked = false
	self._damageFlashConn = nil
	self._dustEmitters = nil
	self._dustBlocked = false
	self._menuBlur = nil
	self._menuBlurBlocked = false
	self._menuBackground = nil
	self._menuBackdrop = nil
	self._menuBackgroundBlocked = false
	self._weaponBobble = false
	self._fireImpulseUnsub = nil
	self._fireImpulseWeapon = nil
	self._fireImpulseSaved = nil
	self._entityHidden = {}
	self._entityTouched = {}
	self._entityHookFns = {}

	self:Track(removalsLink:Get("fireImpulse"):OnChange(function(value: boolean): ()
		if value then
			self:EnableFireImpulse()
		else
			self:DisableFireImpulse()
		end
	end))

	self:Track(removalsLink:Get("muzzleFlash"):OnChange(function(value: boolean): ()
		if value then
			self:EnableMuzzleFlash()
		else
			self:DisableMuzzleFlash()
		end
	end))

	self:Track(removalsLink:Get("tracers"):OnChange(function(value: boolean): ()
		if value then
			self:EnableTracers()
		else
			self:DisableTracers()
		end
	end))

	self:Track(removalsLink:Get("bulletImpacts"):OnChange(function(value: boolean): ()
		WeaponController.SetImpactEffectsSuppressed(value)
	end))

	self:Track(removalsLink:Get("lowHealthScreen"):OnChange(function(value: boolean): ()
		if value then
			self:EnableLowHealthScreen()
		else
			self:DisableLowHealthScreen()
		end
	end))

	self:Track(removalsLink:Get("damageFlash"):OnChange(function(value: boolean): ()
		if value then
			self:EnableDamageFlash()
		else
			self:DisableDamageFlash()
		end
	end))

	self:Track(removalsLink:Get("menuBlur"):OnChange(function(value: boolean): ()
		if value then
			self:EnableMenuBlur()
		else
			self:DisableMenuBlur()
		end
	end))

	self:Track(removalsLink:Get("menuBackground"):OnChange(function(value: boolean): ()
		if value then
			self:EnableMenuBackground()
		else
			self:DisableMenuBackground()
		end
	end))

	self:Track(removalsLink:Get("ambientParticles"):OnChange(function(value: boolean): ()
		if value then
			self:EnableAmbientParticles()
		else
			self:DisableAmbientParticles()
		end
	end))

	self:Track(removalsLink:Get("weaponBobble"):OnChange(function(value: boolean): ()
		if value then
			self:EnableWeaponBobble()
		else
			self:DisableWeaponBobble()
		end
	end))

	self:Track(removalsLink:Get("doors"):OnChange(function(value: boolean): ()
		if value then
			self:_enableEntityRemoval("doors", "Doors", "Doors")
		else
			self:_disableEntityRemoval("doors")
		end
	end))

	self:Track(removalsLink:Get("windows"):OnChange(function(value: boolean): ()
		if value then
			self:_enableEntityRemoval("windows", "Windows", "Windows")
		else
			self:_disableEntityRemoval("windows")
		end
	end))

	if removalsLink:Peek("fireImpulse") then
		self:EnableFireImpulse()
	end
	if removalsLink:Peek("muzzleFlash") then
		self:EnableMuzzleFlash()
	end
	if removalsLink:Peek("tracers") then
		self:EnableTracers()
	end
	if removalsLink:Peek("bulletImpacts") then
		WeaponController.SetImpactEffectsSuppressed(true)
	end
	if removalsLink:Peek("lowHealthScreen") then
		self:EnableLowHealthScreen()
	end
	if removalsLink:Peek("damageFlash") then
		self:EnableDamageFlash()
	end
	if removalsLink:Peek("menuBlur") then
		self:EnableMenuBlur()
	end
	if removalsLink:Peek("menuBackground") then
		self:EnableMenuBackground()
	end
	if removalsLink:Peek("ambientParticles") then
		self:EnableAmbientParticles()
	end
	if removalsLink:Peek("weaponBobble") then
		self:EnableWeaponBobble()
	end
	if removalsLink:Peek("doors") then
		self:_enableEntityRemoval("doors", "Doors", "Doors")
	end
	if removalsLink:Peek("windows") then
		self:_enableEntityRemoval("windows", "Windows", "Windows")
	end

	return self
end

function Removals.EnableFireImpulse(self: Removals)
	if self._fireImpulseUnsub then
		return
	end

	self._fireImpulseUnsub = AnimatorHook.subscribe({
		pre = function(): ()
			local currentWeapon = WeaponController.GetEquippedWeapon()
			self._fireImpulseWeapon = nil
			if not currentWeapon or not currentWeapon.RecoilData then
				return
			end
			self._fireImpulseWeapon = currentWeapon

			local recoilData = currentWeapon.RecoilData
			self._fireImpulseSaved = {
				recoilData.SlideInfluence,
				recoilData.ShiftGunInfluence,
				recoilData.KickUpGunInfluence,
			}

			setreadonly(recoilData, false)
			recoilData.SlideInfluence = 0
			recoilData.ShiftGunInfluence = 0
			recoilData.KickUpGunInfluence = 0
			setreadonly(recoilData, true)
		end,
		post = function(): ()
			local currentWeapon = self._fireImpulseWeapon
			local saved = self._fireImpulseSaved
			self._fireImpulseWeapon = nil
			if not currentWeapon or not saved then
				return
			end

			local recoilData = currentWeapon.RecoilData

			setreadonly(recoilData, false)
			recoilData.SlideInfluence = saved[1]
			recoilData.ShiftGunInfluence = saved[2]
			recoilData.KickUpGunInfluence = saved[3]
			setreadonly(recoilData, true)
		end,
	})
end

function Removals.DisableFireImpulse(self: Removals)
	if not self._fireImpulseUnsub then
		return
	end

	self._fireImpulseUnsub()
	self._fireImpulseUnsub = nil
	self._fireImpulseWeapon = nil
end

function Removals.EnableWeaponBobble(self: Removals)
	if self._weaponBobble then
		return
	end

	self._weaponBobble = true

	local springs = ModuleController.GetModule("Springs")
	local arLocalPlayerModule = ModuleController.GetModule("LocalPlayer")

	if not arLocalPlayerModule then
		return
	end

	if not springs then
		return
	end

	local cachedCharacter
	local cachedSprings

	local old
	old = hook.add(
		springs.module.Update,
		LPH_NO_VIRTUALIZE(function(self, ...)
			local arLocalPlayer = arLocalPlayerModule.module.get()

			if not arLocalPlayer then
				cachedCharacter = nil
				cachedSprings = nil
				return
			end

			local character = arLocalPlayer.Character
			if character ~= cachedCharacter then
				cachedCharacter = character
				cachedSprings = character and character.Animator and character.Animator.Springs or nil
			end

			local springsTable = cachedSprings
			if springsTable then
				if
					self == springsTable.WobblePos.Spring
					or self == springsTable.WobbleRot.Spring
					or self == springsTable.RotationVelocity.Spring
					or self == springsTable.MoveVelocity.Spring
					or self == springsTable.StanceBounce.Spring
				then
					local zero = self.g * 0
					self.p = zero
					self.v = zero
					return zero, zero
				end
			end

			return old(self, ...)
		end)
	)
end

function Removals.DisableWeaponBobble(self: Removals)
	if not self._weaponBobble then
		return
	end

	self._weaponBobble = false

	local springs = ModuleController.GetModule("Springs")

	if not springs then
		return
	end

	hook.restore(springs.module.Update)
end

function Removals.EnableMuzzleFlash(self: Removals): ()
	if self._muzzleTargets then
		return
	end

	local targets = {}

	for _, fn in next, filtergc("function", { Name = "animateMuzzleFlash" }, false) do
		hook.add(fn, LPH_NO_VIRTUALIZE(function(): () end))
		table.insert(targets, fn)
	end

	self._muzzleTargets = targets
end

function Removals.DisableMuzzleFlash(self: Removals): ()
	if not self._muzzleTargets then
		return
	end

	for _, fn in next, self._muzzleTargets do
		hook.restore(fn)
	end

	self._muzzleTargets = nil
end

function Removals.EnableTracers(self: Removals): ()
	if self._updateTracer then
		return
	end

	local Bullets = ModuleController.GetModule("Bullets")
	local updateTracer = Bullets and Bullets.protos.updateTracer
	if not updateTracer then
		return
	end

	hook.add(updateTracer, LPH_NO_VIRTUALIZE(function(): () end))
	self._updateTracer = updateTracer
end

function Removals.DisableTracers(self: Removals): ()
	if not self._updateTracer then
		return
	end

	hook.restore(self._updateTracer)
	self._updateTracer = nil
end

function Removals.EnableLowHealthScreen(self: Removals): ()
	if self._damageFadeBlocked then
		return
	end

	local damageFade = self._damageFade
	if not damageFade then
		damageFade = Lighting:FindFirstChild("DamageFade")
		self._damageFade = damageFade
	end
	if not damageFade then
		return
	end

	hook.addInstance(damageFade)
	hook.blockProperty(damageFade, "TintColor")
	hook.blockProperty(damageFade, "Saturation")
	damageFade.TintColor = NEUTRAL_TINT
	damageFade.Saturation = 0
	self._damageFadeBlocked = true
end

function Removals.DisableLowHealthScreen(self: Removals): ()
	if not self._damageFadeBlocked then
		return
	end

	local damageFade = self._damageFade
	if damageFade then
		hook.unblockProperty(damageFade, "TintColor")
		hook.unblockProperty(damageFade, "Saturation")
	end
	self._damageFadeBlocked = false
end

function Removals.EnableDamageFlash(self: Removals): ()
	if self._damageFlashConn then
		return
	end

	self._damageFlashConn = Lighting.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(child: Instance): ()
		local className = child.ClassName
		if child.Name == className and (className == "ColorCorrectionEffect" or className == "BlurEffect") then
			(child :: any).Enabled = false
		end
	end))
end

function Removals.DisableDamageFlash(self: Removals): ()
	if self._damageFlashConn then
		self._damageFlashConn:Disconnect()
		self._damageFlashConn = nil
	end
end

function Removals.EnableMenuBlur(self: Removals): ()
	if self._menuBlurBlocked then
		return
	end

	local menuBlur = self._menuBlur
	if not menuBlur then
		menuBlur = Lighting:FindFirstChild("GameMenuBlur")
		self._menuBlur = menuBlur
	end
	if not menuBlur then
		return
	end

	hook.addInstance(menuBlur)
	hook.blockProperty(menuBlur, "Size")
	menuBlur.Size = 0
	self._menuBlurBlocked = true
end

function Removals.DisableMenuBlur(self: Removals): ()
	if not self._menuBlurBlocked then
		return
	end

	local menuBlur = self._menuBlur
	if menuBlur then
		hook.unblockProperty(menuBlur, "Size")
	end
	self._menuBlurBlocked = false
end

function Removals.EnableMenuBackground(self: Removals): ()
	if self._menuBackgroundBlocked then
		return
	end

	local background = self._menuBackground
	if not background then
		background = findMenuBackground()
		self._menuBackground = background
	end
	if not background then
		return
	end

	hook.addInstance(background)
	hook.blockProperty(background, "BackgroundTransparency")
	background.BackgroundTransparency = 1

	local backdrop = self._menuBackdrop
	if not backdrop then
		backdrop = background:FindFirstChild(MENU_BACKDROP)
		self._menuBackdrop = backdrop
	end
	if backdrop and backdrop:IsA("GuiObject") then
		hook.addInstance(backdrop)
		if backdrop:IsA("ImageLabel") or backdrop:IsA("ImageButton") then
			hook.blockProperty(backdrop, "ImageTransparency")
			backdrop.ImageTransparency = 1
		end
		hook.blockProperty(backdrop, "BackgroundTransparency")
		backdrop.BackgroundTransparency = 1
	end

	self._menuBackgroundBlocked = true
end

function Removals.DisableMenuBackground(self: Removals): ()
	if not self._menuBackgroundBlocked then
		return
	end

	local background = self._menuBackground
	if background then
		hook.unblockProperty(background, "BackgroundTransparency")
	end

	local backdrop = self._menuBackdrop
	if backdrop then
		if backdrop:IsA("ImageLabel") or backdrop:IsA("ImageButton") then
			hook.unblockProperty(backdrop, "ImageTransparency")
		end
		hook.unblockProperty(backdrop, "BackgroundTransparency")
	end

	self._menuBackgroundBlocked = false
end

function Removals.EnableAmbientParticles(self: Removals): ()
	if self._dustBlocked then
		return
	end

	local emitters = self._dustEmitters
	if not emitters then
		emitters = {}

		local effects = Workspace:FindFirstChild("Effects")
		if effects then
			for _, path in next, DUST_EMITTERS do
				local holder = effects:FindFirstChild(path[1])
				local emitter = holder and holder:FindFirstChild(path[2])
				if emitter then
					table.insert(emitters, emitter)
				end
			end
		end

		self._dustEmitters = emitters
	end

	for _, emitter in next, emitters do
		hook.addInstance(emitter)
		hook.blockProperty(emitter, "Enabled")
		emitter.Enabled = false
		emitter:Clear()
	end

	self._dustBlocked = true
end

function Removals.DisableAmbientParticles(self: Removals): ()
	if not self._dustBlocked then
		return
	end

	for _, emitter in next, self._dustEmitters do
		hook.unblockProperty(emitter, "Enabled")
	end

	self._dustBlocked = false
end

function Removals._enableEntityRemoval(self: Removals, key: string, moduleName: string, folderName: string): ()
	if self._entityHidden[key] then
		return
	end

	local set: { [Instance]: true } = {}
	local touched: { [Instance]: true } = {}
	self._entityHidden[key] = set
	self._entityTouched[key] = touched

	local map = Workspace:FindFirstChild("Map")
	if map then
		for _, model in next, map:QueryDescendants("Model") do
			local parent = model.Parent
			if parent and parent.Name == folderName then
				setModelHidden(model, true, touched)
				set[model] = true
			end
		end
	end

	local module = ModuleController.FrameworkRequire("Entities", moduleName)
	if module and module.new then
		local old
		old = hook.add(
			module.new,
			LPH_NO_VIRTUALIZE(function(...): any
				local entity = old(...)
				local model = firstInstanceArg(...)
				if model then
					setModelHidden(model, true, touched)
					set[model] = true
				end
				return entity
			end)
		)
		self._entityHookFns[key] = module.new
	end
end

function Removals._disableEntityRemoval(self: Removals, key: string): ()
	local set = self._entityHidden[key]
	if not set then
		return
	end

	local fn = self._entityHookFns[key]
	if fn then
		hook.restore(fn)
		self._entityHookFns[key] = nil
	end

	for model in next, set do
		if model.Parent then
			setModelHidden(model, false)
		end
	end

	local touched = self._entityTouched[key]
	if touched then
		for part in next, touched do
			if (part :: Instance).Parent then
				(part :: BasePart).CanCollide = true
			end
		end
	end

	self._entityHidden[key] = nil
	self._entityTouched[key] = nil
end

function Removals.Destroy(self: Removals): ()
	self:DisableMuzzleFlash()
	self:DisableTracers()
	WeaponController.SetImpactEffectsSuppressed(false)
	self:DisableLowHealthScreen()
	self:DisableDamageFlash()
	self:DisableMenuBlur()
	self:DisableMenuBackground()
	self:DisableAmbientParticles()
	self:DisableFireImpulse()
	self:DisableWeaponBobble()
	self:_disableEntityRemoval("doors")
	self:_disableEntityRemoval("windows")
	BaseFeature.Destroy(self)
end

export type Removals =
	typeof(setmetatable(
		{} :: {
			_muzzleTargets: { (...any) -> any }?,
			_updateTracer: any,
			_damageFade: ColorCorrectionEffect?,
			_damageFadeBlocked: boolean,
			_damageFlashConn: RBXScriptConnection?,
			_dustEmitters: { ParticleEmitter }?,
			_dustBlocked: boolean,
			_menuBlur: BlurEffect?,
			_menuBlurBlocked: boolean,
			_menuBackground: Frame?,
			_menuBackdrop: Instance?,
			_menuBackgroundBlocked: boolean,
			_weaponBobble: boolean,
			_fireImpulseUnsub: (() -> ())?,
			_fireImpulseWeapon: any,
			_fireImpulseSaved: { number }?,
			_entityHidden: { [string]: { [Instance]: true } },
			_entityTouched: { [string]: { [Instance]: true } },
			_entityHookFns: { [string]: any },
		},
		Removals
	))
	& BaseFeature.BaseFeature

return Removals
