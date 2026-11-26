local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage
local ModuleController = require("@game/rivals/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local hook = require("@share/hook")
local gameUi = require("@game/gameUi")
local viewmodelState = require("@game/rivals/viewmodel/viewmodelState")
local patchConstant = require("@game/rivals/util/patchConstant")

local peek = Charm.peek
local sub = Charm.subscribe

local SHAKE_NOISE_SCALE = 0.5
local _shakeInstanceClass: any = nil

local function shakeUpdateFn(): any
	if _shakeInstanceClass == nil then
		_shakeInstanceClass = filtergc("table", {
			Keys = { "UpdateShake", "SetScaleMagnitude", "GetScaleMagnitude", "CameraShakeState" },
		}, true) or false
	end
	local instance = _shakeInstanceClass
	if type(instance) ~= "table" then
		return nil
	end
	local fn = rawget(instance, "UpdateShake")
	return type(fn) == "function" and fn or nil
end

local SMOKE_TAG = "SmokeCloud"

local makeZeroSpring = LPH_NO_VIRTUALIZE(function(zero: any): any
	return setmetatable({}, {
		__index = function(_, key: string): any
			if
				key == "Value"
				or key == "Position"
				or key == "Target"
				or key == "Velocity"
				or key == "p"
				or key == "t"
				or key == "v"
			then
				return zero
			end
			return nil
		end,
		__newindex = function(): () end,
	})
end)

local ZERO_VECTOR_SPRING = makeZeroSpring(Vector2.zero)
local ZERO_SCALAR_SPRING = makeZeroSpring(0)

local SPRING_REMOVALS = {
	swaying = { field = "_sway_spring", zero = ZERO_VECTOR_SPRING },
	bobbing = { field = "_bobbing_value_spring", zero = ZERO_VECTOR_SPRING },
	tilting = { field = "_tilt_spring", zero = ZERO_VECTOR_SPRING },
	jump = { field = "_jump_spring", zero = ZERO_SCALAR_SPRING },
	slide = { field = "_sliding_spring", zero = ZERO_SCALAR_SPRING },
}

local VM_REMOVALS = {
	{ label = "Sprint Animation", apply = "sprint" },
	{ label = "Reload Animation", apply = "reload" },
	{ label = "Equip Animation", apply = "equip" },
	{ label = "Shoot Animation", apply = "shoot" },
	{ label = "Slide Animation", apply = "spring", name = "slide" },
	{ label = "Jump Animation", apply = "spring", name = "jump" },
	{ label = "Idle Animation", apply = "idle" },
	{ label = "Muzzle Flash", apply = "muzzle" },
	{ label = "Swaying", apply = "spring", name = "swaying" },
	{ label = "Bobbing", apply = "spring", name = "bobbing" },
	{ label = "Tilting", apply = "spring", name = "tilting" },
}

local VM_REMOVAL_LABELS: { string } = {}
for _, entry in next, VM_REMOVALS do
	table.insert(VM_REMOVAL_LABELS, entry.label)
end

local SOUND_REMOVALS = {
	{ label = "Double Jump", kind = "mechanics", name = "DoubleJump" },
	{ label = "Melee Attack", kind = "anim", matches = { "attack" } },
	{ label = "Shoot", kind = "anim", matches = { "shoot" } },
	{ label = "Reload", kind = "anim", matches = { "reload" } },
	{ label = "Charge", kind = "anim", matches = { "charge" } },
	{ label = "Throw", kind = "anim", matches = { "throw", "lob" } },
	{ label = "Place", kind = "place" },
	{ label = "Equip", kind = "anim", matches = { "equip" } },
	{ label = "Slide", kind = "mechanics", name = "Slide" },
	{ label = "Dash", kind = "anim", matches = { "dash" } },
}

local SOUND_REMOVAL_LABELS: { string } = {}
for _, entry in next, SOUND_REMOVALS do
	table.insert(SOUND_REMOVAL_LABELS, entry.label)
end

local PLACE_TAGS = { "JumpPadHitbox", "SubspaceTripmine" }

local requireUtility = LPH_NO_VIRTUALIZE(function(): any?
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local utility = modules and modules:FindFirstChild("Utility")
	if not utility then
		return nil
	end
	setthreadidentity(2)
	local instance = require(utility)
	setthreadidentity(8)
	return instance
end)

local function hasPlaceTag(inst: Instance?): boolean
	if typeof(inst) ~= "Instance" then
		return false
	end
	for _, tag in next, PLACE_TAGS do
		if CollectionService:HasTag(inst, tag) then
			return true
		end
	end
	return false
end

local isPlaceSoundParent = LPH_NO_VIRTUALIZE(function(parent: any): boolean
	if typeof(parent) ~= "Instance" then
		return false
	end
	return hasPlaceTag(parent) or hasPlaceTag(parent.Parent)
end)

local function findMethod(start: any, name: string): any
	local current = start
	for _ = 1, 8 do
		if type(current) ~= "table" then
			break
		end
		local fn = rawget(current, name)
		if type(fn) == "function" then
			return fn
		end
		local mt = getmetatable(current)
		if type(mt) ~= "table" then
			break
		end
		current = mt.__index
	end
	return nil
end

local Removals = {}
Removals.__index = Removals

setmetatable(Removals, { __index = BaseFeature })

function Removals.new(link: gameUi.Linker): Removals
	local self = BaseFeature.new() :: any
	setmetatable(self, Removals)

	link:Options("removals", "Removals")
	local removalsLink = link:OnKey("removals")
	removalsLink:Toggle("headshotParticles", "Headshot Particles", false):SetTip({
		title = "Headshot Particles",
		body = "Removes the burst shown when a headshot lands.",
	})
	removalsLink:Toggle("damageIndicators", "Damage Indicators", false):SetTip({
		title = "Damage Indicators",
		body = "Hides the direction indicators shown when you take damage.",
	})
	removalsLink:Toggle("damageNumbers", "Damage Numbers", false):SetTip({
		title = "Damage Numbers",
		body = "Hides the floating damage numbers over enemies you hit.",
	})
	removalsLink:Toggle("smokes", "Smoke Particles", false):SetTip({
		title = "Smoke Particles",
		body = "Hides smoke clouds so they do not block your view.",
	})
	removalsLink:Toggle("cameraShake", "Camera Shake", false):SetTip({
		title = "Camera Shake",
		body = "Stops the screen from shaking when firing or near blasts.",
	})
	removalsLink:Toggle("smokeBlind", "Smoke Screen", false):SetTip({
		title = "Smoke Screen",
		body = "Removes the close-range smoke blind overlay and depth of field from your screen.",
	})
	removalsLink:Toggle("tracers", "Bullet Tracers", false):SetTip({
		title = "Bullet Tracers",
		body = "Removes bullet tracer beams and their flyby sounds.",
	})
	removalsLink:Toggle("aimVignette", "Aim Vignette", false):SetTip({
		title = "Aim Vignette",
		body = "Removes the aiming vignette.",
	})
	removalsLink:Toggle("bulletImpact", "Bullet Impact", false):SetTip({
		title = "Bullet Impact",
		body = "Removes the marks where shots hit surfaces.",
	})
	removalsLink:Toggle("burnEffect", "Burn Effect", false):SetTip({
		title = "Burn Effect",
		body = "Removes the fire visual and sound while burning.",
	})
	removalsLink:Toggle("flashes", "Flash Effect", false):SetTip({
		title = "Flash Effect",
		body = "Shortens or removes flashbang blindness. Use Time Reduction to scale duration.",
	})
	local flashLink = removalsLink:OnKey("flashes")
	flashLink:Submenu("opts", "Flash Effect")
	local flashOptsLink = flashLink:OnKey("opts")
	flashOptsLink:Slider("timeReduction", "Time Reduction", 100, 1, 100, 1, nil, "%"):SetTip({
		title = "Time Reduction",
		body = "Percent of flash duration to remove. 100% removes the effect entirely.",
	})

	removalsLink
		:Dropdown("soundRemovals", "Sound Removals", SOUND_REMOVAL_LABELS, {})
		:SetMode("multi")
		:SetPlaceholder("None")
		:SetTip({
			title = "Sound Removals",
			body = "Mute selected in-game sounds.",
		})
	removalsLink
		:Dropdown("viewmodelRemovals", "Viewmodel", VM_REMOVAL_LABELS, {})
		:SetMode("multi")
		:SetPlaceholder("None")
		:SetTip({
			title = "Viewmodel",
			body = "Select viewmodel effects to remove. Animations are instantly finished instead of frozen.",
		})

	self._flashLink = flashOptsLink
	self._link = removalsLink
	self._hiddenSmokes = {} :: { [Model]: Instance }
	self._flashMultiplier = 1
	self._flashHookTarget = nil :: any
	self._originalFlash = nil :: any
	self._smokeBlindHookTarget = nil :: any
	self._smokeCloudsModule = nil :: any
	self._patchedViewmodels = setmetatable({}, { __mode = "k" }) :: any
	self._viewmodelWatch = nil :: any
	self._sprintHookTarget = nil :: any
	self._methodHooks = {} :: { [string]: any }
	self._springEnabled = {} :: any
	self._sprintEnabled = false
	self._blockedMechanicsSounds = {} :: { [string]: boolean }
	self._mechanicsSoundHookTarget = nil :: any
	self._animSoundPatches = {} :: { [string]: { [string]: any } }
	self._placeSoundHookTarget = nil :: any
	self._muzzleFlashEnabled = false
	self._idleEnabled = false
	self._equipEnabled = false
	self._shootEnabled = false
	self._reloadEnabled = false
	self._aimVignetteEnabled = false
	self._burnEffectEnabled = false
	self._headshotEnabled = false
	self._impactEnabled = false

	self:Track(removalsLink:Get("smokes"):OnChange(function(value: boolean): ()
		if value then
			self:EnableSmokes()
		else
			self:DisableSmokes()
		end
	end))

	self:Track(removalsLink:Get("smokeBlind"):OnChange(function(value: boolean): ()
		if value then
			self:EnableSmokeBlind()
		else
			self:DisableSmokeBlind()
		end
	end))

	self:Track(removalsLink:Get("aimVignette"):OnChange(function(value: boolean): ()
		if value then
			self:EnableAimVignette()
		else
			self:DisableAimVignette()
		end
	end))

	self:Track(removalsLink:Get("flashes"):OnChange(function(value: boolean): ()
		if value then
			self:EnableFlashes()
		else
			self:DisableFlashes()
		end
	end))

	self:Track(removalsLink:Get("cameraShake"):OnChange(function(value: boolean): ()
		if value then
			self:EnableCameraShake()
		else
			self:DisableCameraShake()
		end
	end))

	self:Track(removalsLink:Get("tracers"):OnChange(function(value: boolean): ()
		if value then
			self:EnableTracers()
		else
			self:DisableTracers()
		end
	end))

	self:Track(removalsLink:Get("burnEffect"):OnChange(function(value: boolean): ()
		if value then
			self:EnableBurnEffect()
		else
			self:DisableBurnEffect()
		end
	end))

	self:Track(removalsLink:Get("headshotParticles"):OnChange(function(value: boolean): ()
		if value then
			self:EnableHeadshotParticles()
		else
			self:DisableHeadshotParticles()
		end
	end))

	self:Track(removalsLink:Get("bulletImpact"):OnChange(function(value: boolean): ()
		if value then
			self:EnableBulletImpact()
		else
			self:DisableBulletImpact()
		end
	end))

	self:Track(removalsLink:Get("soundRemovals"):OnChange(function(selection: any): ()
		self:ApplySoundSelection(selection)
	end))
	self:ApplySoundSelection(removalsLink:Peek("soundRemovals"))

	self:Track(removalsLink:Get("damageIndicators"):OnChange(function(value: boolean): ()
		if value then
			self:EnableDamageIndicators()
		else
			self:DisableDamageIndicators()
		end
	end))

	self:Track(removalsLink:Get("damageNumbers"):OnChange(function(value: boolean): ()
		if value then
			self:EnableDamageNumbers()
		else
			self:DisableDamageNumbers()
		end
	end))

	self:Track(removalsLink:Get("viewmodelRemovals"):OnChange(function(selection: any): ()
		self:ApplySelection(selection)
	end))
	self:ApplySelection(removalsLink:Peek("viewmodelRemovals"))

	return self
end

function Removals.ApplySelection(self: Removals, selection: any): ()
	local set: { [string]: boolean } = {}
	if type(selection) == "table" then
		for _, label in next, selection do
			if type(label) == "string" then
				set[label] = true
			end
		end
	end

	for _, entry in next, VM_REMOVALS do
		local on = set[entry.label] == true
		local apply = entry.apply
		if apply == "spring" then
			if on then
				self:EnableSpring(entry.name)
			else
				self:DisableSpring(entry.name)
			end
		elseif apply == "sprint" then
			if on then
				self:EnableSprintAnimation()
			else
				self:DisableSprintAnimation()
			end
		elseif apply == "idle" then
			if on then
				self:EnableIdle()
			else
				self:DisableIdle()
			end
		elseif apply == "equip" then
			if on then
				self:EnableEquip()
			else
				self:DisableEquip()
			end
		elseif apply == "shoot" then
			if on then
				self:EnableShoot()
			else
				self:DisableShoot()
			end
		elseif apply == "reload" then
			if on then
				self:EnableReload()
			else
				self:DisableReload()
			end
		elseif apply == "muzzle" then
			if on then
				self:EnableMuzzleFlash()
			else
				self:DisableMuzzleFlash()
			end
		end
	end
end

local function hideSmokeModel(self: any, model: Instance?): ()
	if not model or not model:IsA("Model") then
		return
	end
	local hidden = self._hiddenSmokes
	if hidden[model] then
		return
	end
	local parent = model.Parent
	if not parent then
		return
	end
	hidden[model] = parent
	model.Parent = nil
end

local function installSmokeBlindHook(self: any): ()
	if self._smokeBlindHookTarget then
		return
	end

	local smokeScreen = ModuleController.GetModule("SmokeScreen")
	if not smokeScreen then
		return
	end

	local original = rawget(smokeScreen, "_GetSmokeCloud")
	if type(original) ~= "function" then
		return
	end

	self._smokeBlindHookTarget = original
	hook.add(original, function()
		return nil
	end)
end

local function restoreSmokeBlindHook(self: any): ()
	local target = self._smokeBlindHookTarget
	if target then
		hook.restore(target)
		self._smokeBlindHookTarget = nil
	end
end

local function getSmokeClouds(self: any): any
	local cached = self._smokeCloudsModule
	if cached then
		return cached
	end
	local SmokeClouds = ModuleController.GetModule("SmokeClouds")
	self._smokeCloudsModule = SmokeClouds
	return SmokeClouds
end

local function tryHideSmokeFromPart(self: any, part: Instance): ()
	if not part:IsA("BasePart") then
		return
	end
	task.defer(function(): ()
		local SmokeClouds = getSmokeClouds(self)
		if not SmokeClouds then
			return
		end
		local list = rawget(SmokeClouds, "_smoke_clouds")
		if type(list) ~= "table" then
			return
		end
		local smoke = list[part]
		if smoke then
			hideSmokeModel(self, smoke.Model)
		end
	end)
end

local function hideAllRegisteredSmokes(self: any): ()
	local SmokeClouds = getSmokeClouds(self)
	if not SmokeClouds then
		return
	end
	local registry = rawget(SmokeClouds, "_smoke_clouds")
	if type(registry) ~= "table" then
		return
	end
	for _, smoke in next, registry do
		hideSmokeModel(self, smoke.Model)
	end
end

function Removals.EnableSmokes(self: Removals): ()
	if self._smokesEnabled then
		return
	end
	self._smokesEnabled = true

	hideAllRegisteredSmokes(self)

	for _, inst in next, CollectionService:GetTagged(SMOKE_TAG) do
		tryHideSmokeFromPart(self, inst)
	end

	self._smokesJanitor = Janitor.new()
	self._smokesJanitor:Add(CollectionService:GetInstanceAddedSignal(SMOKE_TAG):Connect(function(inst: Instance): ()
		tryHideSmokeFromPart(self, inst)
	end))
	self:Track(function(): ()
		if self._smokesJanitor then
			self._smokesJanitor:Destroy()
			self._smokesJanitor = nil
		end
	end)
end

function Removals.DisableSmokes(self: Removals): ()
	if not self._smokesEnabled then
		return
	end
	self._smokesEnabled = false

	if self._smokesJanitor then
		self._smokesJanitor:Destroy()
		self._smokesJanitor = nil
	end

	local hidden = self._hiddenSmokes :: any
	for model, parent in next, hidden do
		if model and parent then
			model.Parent = parent
		end
		hidden[model] = nil
	end
end

function Removals.EnableAimVignette(self: Removals): ()
	if self._aimVignetteEnabled then
		return
	end
	self._aimVignetteEnabled = true

	local AimVignette = ModuleController.GetModule("AimVignette")
	if not AimVignette then
		return
	end
	local original = rawget(AimVignette, "Update")
	if type(original) ~= "function" then
		return
	end
	hook.add(original, function(): () end)

	self._aimVignetteJanitor = Janitor.new()
	self._aimVignetteJanitor:Add(function(): ()
		hook.restore(original)
	end)
end

function Removals.DisableAimVignette(self: Removals): ()
	if not self._aimVignetteEnabled then
		return
	end
	self._aimVignetteEnabled = false

	if self._aimVignetteJanitor then
		self._aimVignetteJanitor:Destroy()
		self._aimVignetteJanitor = nil
	end
end

function Removals.EnableSmokeBlind(self: Removals): ()
	if self._smokeBlindEnabled then
		return
	end
	self._smokeBlindEnabled = true
	installSmokeBlindHook(self)
end

function Removals.DisableSmokeBlind(self: Removals): ()
	if not self._smokeBlindEnabled then
		return
	end
	self._smokeBlindEnabled = false
	restoreSmokeBlindHook(self)
end

local function applyFlashReduction(self: any): ()
	local reduction = self._flashLink:Peek("timeReduction") or 100
	local factor = 1 - reduction / 100
	if factor < 0 then
		factor = 0
	elseif factor > 1 then
		factor = 1
	end
	self._flashMultiplier = factor
end

local function installFlashHook(self: any): ()
	if self._flashHookTarget then
		return
	end
	local flashed = ModuleController.GetModule("Flashed")
	if not flashed then
		return
	end
	local original = rawget(flashed, "AttemptToFlash")
	if type(original) ~= "function" then
		return
	end

	self._flashHookTarget = original
	self._originalFlash = hook.add(
		original,
		function(
			flashSelf: any,
			occlusion: any,
			position: Vector3,
			intensity: number,
			sourceId: any,
			flashType: any,
			ringingCallback: any
		): ()
			local multiplier = self._flashMultiplier
			if multiplier <= 0 then
				return
			end
			local adjustedIntensity = (multiplier ~= 1 and intensity * multiplier or intensity)
			return self._originalFlash(
				flashSelf,
				occlusion,
				position,
				adjustedIntensity,
				sourceId,
				flashType,
				ringingCallback
			)
		end
	)
end

local function restoreFlashHook(self: any): ()
	local target = self._flashHookTarget
	if target then
		hook.restore(target)
		self._flashHookTarget = nil
		self._originalFlash = nil
	end
end

function Removals.EnableFlashes(self: Removals): ()
	if self._flashesEnabled then
		return
	end
	self._flashesEnabled = true

	applyFlashReduction(self)
	installFlashHook(self)
	self._flashReductionWatch = self._flashLink:Watch("timeReduction", function(): ()
		applyFlashReduction(self)
	end)
end

function Removals.DisableFlashes(self: Removals): ()
	if not self._flashesEnabled then
		return
	end
	self._flashesEnabled = false

	if self._flashReductionWatch then
		self._flashReductionWatch()
		self._flashReductionWatch = nil
	end
	self._flashMultiplier = 1
	restoreFlashHook(self)
end

function Removals.EnableCameraShake(self: Removals): ()
	if self._cameraShakeEnabled then
		return
	end
	self._cameraShakeEnabled = true

	local fn = shakeUpdateFn()
	if not fn then
		self._cameraShakeEnabled = false
		return
	end

	self._shakeFn = fn
	self._shakeIndices = patchConstant.apply(fn, SHAKE_NOISE_SCALE, 0)
end

function Removals.DisableCameraShake(self: Removals): ()
	if not self._cameraShakeEnabled then
		return
	end
	self._cameraShakeEnabled = false

	if self._shakeFn then
		patchConstant.restore(self._shakeFn, self._shakeIndices, SHAKE_NOISE_SCALE)
		self._shakeFn = nil
		self._shakeIndices = {}
	end
end

function Removals.EnableTracers(self: Removals): ()
	if self._tracersEnabled then
		return
	end
	self._tracersEnabled = true

	local TracerEffect = ModuleController.GetModule("TracerEffect")
	if type(TracerEffect) ~= "table" then
		return
	end
	local original = rawget(TracerEffect, "Play")
	if type(original) ~= "function" then
		return
	end

	self._tracersHookTarget = original
	hook.add(original, function(): () end)
end

function Removals.DisableTracers(self: Removals): ()
	if not self._tracersEnabled then
		return
	end
	self._tracersEnabled = false

	if self._tracersHookTarget then
		hook.restore(self._tracersHookTarget)
		self._tracersHookTarget = nil
	end
end

function Removals.EnableBurnEffect(self: Removals): ()
	if self._burnEffectEnabled then
		return
	end
	self._burnEffectEnabled = true

	local ClientEntity = ModuleController.GetModule("ClientEntity")
	if type(ClientEntity) ~= "table" then
		return
	end
	local original = rawget(ClientEntity, "_BurnEffect")
	if type(original) ~= "function" then
		return
	end

	self._burnHookTarget = original
	hook.add(original, function(): () end)
end

function Removals.DisableBurnEffect(self: Removals): ()
	if not self._burnEffectEnabled then
		return
	end
	self._burnEffectEnabled = false

	if self._burnHookTarget then
		hook.restore(self._burnHookTarget)
		self._burnHookTarget = nil
	end
end

function Removals.EnableHeadshotParticles(self: Removals): ()
	if self._headshotEnabled then
		return
	end
	self._headshotEnabled = true

	local ClientEntity = ModuleController.GetModule("ClientEntity")
	if type(ClientEntity) ~= "table" then
		return
	end
	local original = rawget(ClientEntity, "_HurtEffect")
	if type(original) ~= "function" then
		return
	end

	self._headshotHookTarget = original
	local trampoline
	trampoline = hook.add(
		original,
		LPH_NO_VIRTUALIZE(function(entity: any, ...: any): ()
			local saved = entity._headshot_particles
			entity._headshot_particles = nil
			trampoline(entity, ...)
			entity._headshot_particles = saved
		end)
	)
end

function Removals.DisableHeadshotParticles(self: Removals): ()
	if not self._headshotEnabled then
		return
	end
	self._headshotEnabled = false

	if self._headshotHookTarget then
		hook.restore(self._headshotHookTarget)
		self._headshotHookTarget = nil
	end
end

function Removals.EnableBulletImpact(self: Removals): ()
	if self._impactEnabled then
		return
	end
	self._impactEnabled = true

	local Gun = ModuleController.GetModule("Gun")
	if type(Gun) ~= "table" then
		return
	end
	local original = findMethod(Gun, "_ImpactMarkers")
	if type(original) ~= "function" then
		return
	end

	self._impactHookTarget = original
	hook.add(original, function(): () end)
end

function Removals.DisableBulletImpact(self: Removals): ()
	if not self._impactEnabled then
		return
	end
	self._impactEnabled = false

	if self._impactHookTarget then
		hook.restore(self._impactHookTarget)
		self._impactHookTarget = nil
	end
end

local function installMechanicsSoundHook(self: any): ()
	if self._mechanicsSoundHookTarget then
		return
	end
	local MechanicsController = ModuleController.GetModule("MechanicsController")
	if not MechanicsController then
		return
	end
	local class = getmetatable(MechanicsController)
	local original = class and rawget(class, "PlayMechanicsSound")
	if type(original) ~= "function" then
		return
	end

	self._mechanicsSoundHookTarget = original
	local blocked = self._blockedMechanicsSounds
	local trampoline
	trampoline = hook.add(
		original,
		LPH_NO_VIRTUALIZE(function(mechSelf: any, soundName: any, ...: any): ...any
			if blocked[soundName] then
				return Instance.new("Sound")
			end
			return trampoline(mechSelf, soundName, ...)
		end)
	)
end

local function restoreMechanicsSoundHook(self: any): ()
	if self._mechanicsSoundHookTarget then
		hook.restore(self._mechanicsSoundHookTarget)
		self._mechanicsSoundHookTarget = nil
	end
end

local function nameMatchesAny(name: string, matches: { string }): boolean
	for _, match in next, matches do
		if string.find(name, match, 1, true) then
			return true
		end
	end
	return false
end

local function patchAnimSounds(self: any, label: string, matches: { string }): ()
	if self._animSoundPatches[label] then
		return
	end
	local AnimationLibrary = ModuleController.GetModule("AnimationLibrary")
	local info = AnimationLibrary and rawget(AnimationLibrary, "Info")
	if type(info) ~= "table" then
		return
	end
	local saved: { [string]: any } = {}
	self._animSoundPatches[label] = saved
	for name, entry in next, info do
		if
			type(name) == "string"
			and type(entry) == "table"
			and entry.SoundCallback ~= nil
			and nameMatchesAny(name, matches)
		then
			saved[name] = entry.SoundCallback
			entry.SoundCallback = nil
		end
	end
end

local function restoreAnimSounds(self: any, label: string): ()
	local saved = self._animSoundPatches[label]
	if not saved then
		return
	end
	local AnimationLibrary = ModuleController.GetModule("AnimationLibrary")
	local info = AnimationLibrary and rawget(AnimationLibrary, "Info")
	if type(info) == "table" then
		for name, callback in next, saved do
			local entry = info[name]
			if type(entry) == "table" then
				entry.SoundCallback = callback
			end
		end
	end
	self._animSoundPatches[label] = nil
end

function Removals.ApplySoundSelection(self: Removals, selection: any): ()
	local set: { [string]: boolean } = {}
	if type(selection) == "table" then
		for _, label in next, selection do
			if type(label) == "string" then
				set[label] = true
			end
		end
	end

	for _, entry in next, SOUND_REMOVALS do
		local on = set[entry.label] == true
		if entry.kind == "mechanics" then
			if on then
				self:EnableMechanicsSound(entry.name)
			else
				self:DisableMechanicsSound(entry.name)
			end
		elseif entry.kind == "anim" then
			if on then
				patchAnimSounds(self, entry.label, entry.matches)
			else
				restoreAnimSounds(self, entry.label)
			end
		elseif entry.kind == "place" then
			if on then
				self:EnablePlaceSound()
			else
				self:DisablePlaceSound()
			end
		end
	end
end

function Removals.EnablePlaceSound(self: Removals): ()
	if self._placeSoundHookTarget then
		return
	end
	local Utility = requireUtility()
	if not Utility then
		return
	end
	local original = rawget(Utility, "CreateSound")
	if type(original) ~= "function" then
		return
	end

	self._placeSoundHookTarget = original
	local trampoline
	trampoline = hook.add(
		original,
		LPH_NO_VIRTUALIZE(function(utilSelf: any, soundId: any, volume: any, pitch: any, parent: any, ...: any): ...any
			if isPlaceSoundParent(parent) then
				return
			end
			return trampoline(utilSelf, soundId, volume, pitch, parent, ...)
		end)
	)
end

function Removals.DisablePlaceSound(self: Removals): ()
	if self._placeSoundHookTarget then
		hook.restore(self._placeSoundHookTarget)
		self._placeSoundHookTarget = nil
	end
end

function Removals.EnableMechanicsSound(self: Removals, name: string): ()
	if self._blockedMechanicsSounds[name] then
		return
	end
	self._blockedMechanicsSounds[name] = true
	installMechanicsSoundHook(self)
end

function Removals.DisableMechanicsSound(self: Removals, name: string): ()
	if not self._blockedMechanicsSounds[name] then
		return
	end
	self._blockedMechanicsSounds[name] = nil
	if next(self._blockedMechanicsSounds) == nil then
		restoreMechanicsSoundHook(self)
	end
end

function Removals.EnableDamageIndicators(self: Removals): ()
	if self._damageIndicatorsEnabled then
		return
	end
	self._damageIndicatorsEnabled = true

	local damageIndicators = ModuleController.GetModule("DamageIndicators")
	if not damageIndicators then
		return
	end
	local frame = rawget(damageIndicators, "Frame")
	if typeof(frame) ~= "Instance" then
		return
	end

	local gui = frame :: GuiObject
	self._damageIndicatorsFrame = gui
	self._damageIndicatorsVisible = gui.Visible
	gui.Visible = false
end

function Removals.DisableDamageIndicators(self: Removals): ()
	if not self._damageIndicatorsEnabled then
		return
	end
	self._damageIndicatorsEnabled = false

	local frame = self._damageIndicatorsFrame
	if frame then
		frame.Visible = self._damageIndicatorsVisible
		self._damageIndicatorsFrame = nil
	end
end

function Removals.EnableDamageNumbers(self: Removals): ()
	if self._damageNumbersEnabled then
		return
	end
	self._damageNumbersEnabled = true

	self._damageNumbersJanitor = Janitor.new()
	self._damageNumbersJanitor:Add(Workspace.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(inst: Instance): ()
		if inst.Name ~= "Part" then
			return
		end
		task.delay(0, function(): ()
			if inst:FindFirstChild("DamageGui") then
				inst:Destroy()
			end
		end)
	end)))
end

function Removals.DisableDamageNumbers(self: Removals): ()
	if not self._damageNumbersEnabled then
		return
	end
	self._damageNumbersEnabled = false

	if self._damageNumbersJanitor then
		self._damageNumbersJanitor:Destroy()
		self._damageNumbersJanitor = nil
	end
end

local function getEntry(self: any, vm: any): any
	local entry = self._patchedViewmodels[vm]
	if not entry then
		entry = {}
		self._patchedViewmodels[vm] = entry
	end
	return entry
end

local function installSprintHook(self: any, animator: any): ()
	if self._sprintHookTarget then
		return
	end
	local class = getmetatable(animator)
	if type(class) ~= "table" then
		return
	end
	local original = rawget(class, "PlaySprintAnimation")
	if type(original) ~= "function" then
		return
	end
	self._sprintHookTarget = original
	hook.add(original, function(): () end)
end

local function installMuzzleFlashHook(self: any): ()
	if self._methodHooks.muzzleFlash then
		return
	end
	local clientViewModel = ModuleController.GetModule("ClientViewModel")
	if type(clientViewModel) ~= "table" then
		return
	end
	local original = rawget(clientViewModel, "MuzzleFlash")
	if type(original) ~= "function" then
		return
	end
	self._methodHooks.muzzleFlash = original
	hook.add(original, function(): () end)
end

local function installIdleHook(self: any, animatorClass: any): ()
	if self._methodHooks.idle then
		return
	end
	if type(animatorClass) ~= "table" then
		return
	end
	local original = rawget(animatorClass, "PlayIdleAnimation")
	if type(original) ~= "function" then
		return
	end
	self._methodHooks.idle = original
	local trampoline
	trampoline = hook.add(original, function(animatorSelf: any, ...: any): ...any
		local result = trampoline(animatorSelf, ...)
		local track = animatorSelf:GetAnimationTrack(animatorSelf:GetIdleAnimationKey())
		if track then
			track:AdjustSpeed(0)
		end
		return result
	end)
end

local function installEquipHook(self: any, animatorClass: any): ()
	if self._methodHooks.equip then
		return
	end
	if type(animatorClass) ~= "table" then
		return
	end
	local original = rawget(animatorClass, "PlayEquipAnimation")
	if type(original) ~= "function" then
		return
	end
	self._methodHooks.equip = original
	local trampoline
	trampoline = hook.add(original, function(animatorSelf: any, ...: any): ...any
		local result = trampoline(animatorSelf, ...)
		local track = animatorSelf:GetAnimationTrack(animatorSelf:GetEquipAnimationKey())
		if track then
			track.TimePosition = track.Length
		end
		return result
	end)
end

local function installPlayAnimationHook(self: any, animatorClass: any): ()
	if self._methodHooks.playAnimation then
		return
	end
	if type(animatorClass) ~= "table" then
		return
	end
	local original = rawget(animatorClass, "PlayAnimation")
	if type(original) ~= "function" then
		return
	end
	self._methodHooks.playAnimation = original
	local trampoline
	trampoline = hook.add(original, function(animatorSelf: any, key: any, ...: any): ...any
		local result = trampoline(animatorSelf, key, ...)
		if type(key) == "string" then
			local finish = (self._shootEnabled and string.find(key, "Shoot", 1, true))
				or (self._reloadEnabled and string.find(key, "Reload", 1, true))
			if finish then
				local track = animatorSelf:GetAnimationTrack(key)
				if track then
					track.TimePosition = track.Length
				end
			end
		end
		return result
	end)
end

local function restoreMethodHook(self: any, name: string): ()
	local target = self._methodHooks[name]
	if target then
		hook.restore(target)
		self._methodHooks[name] = nil
	end
end

local function patchSprings(self: any, vm: any): ()
	local entry = getEntry(self, vm)
	for name, cfg in next, SPRING_REMOVALS do
		if self._springEnabled[name] then
			if entry[cfg.field] == nil then
				entry[cfg.field] = vm[cfg.field]
			end
			vm[cfg.field] = cfg.zero
		end
	end
end

local function restoreSpring(self: any, name: string): ()
	local cfg = SPRING_REMOVALS[name]
	if not cfg then
		return
	end
	for vm, entry in next, self._patchedViewmodels do
		if entry[cfg.field] ~= nil then
			vm[cfg.field] = entry[cfg.field]
			entry[cfg.field] = nil
		end
	end
end

local function patchSprint(self: any, vm: any): ()
	local entry = getEntry(self, vm)
	if entry._sprinting_spring == nil then
		entry._sprinting_spring = vm._sprinting_spring
	end
	vm._sprinting_spring = ZERO_SCALAR_SPRING

	local animator = vm.Animator
	if animator then
		installSprintHook(self, animator)
		animator.StopSprintAnimation(animator)
	end
end

local function restoreSprint(self: any): ()
	for vm, entry in next, self._patchedViewmodels do
		if entry._sprinting_spring ~= nil then
			vm._sprinting_spring = entry._sprinting_spring
			entry._sprinting_spring = nil
		end
	end
	if self._sprintHookTarget then
		hook.restore(self._sprintHookTarget)
		self._sprintHookTarget = nil
	end
end

local function ensureMethodHooks(self: any, vm: any): ()
	local animator = vm.Animator
	local animatorClass = type(animator) == "table" and getmetatable(animator) or nil
	if self._muzzleFlashEnabled then
		installMuzzleFlashHook(self)
	end
	if self._idleEnabled then
		installIdleHook(self, animatorClass)
	end
	if self._equipEnabled then
		installEquipHook(self, animatorClass)
	end
	if self._shootEnabled or self._reloadEnabled then
		installPlayAnimationHook(self, animatorClass)
	end
end

local function applyViewmodelPatches(self: any, vm: any): ()
	if type(vm) ~= "table" then
		return
	end
	patchSprings(self, vm)
	if self._sprintEnabled then
		patchSprint(self, vm)
	end
	ensureMethodHooks(self, vm)
end

local function anyViewmodelActive(self: any): boolean
	if
		self._sprintEnabled
		or self._muzzleFlashEnabled
		or self._idleEnabled
		or self._equipEnabled
		or self._shootEnabled
		or self._reloadEnabled
	then
		return true
	end
	for _, on in next, self._springEnabled do
		if on then
			return true
		end
	end
	return false
end

local function ensureViewmodelWatch(self: any): ()
	if self._viewmodelWatch then
		return
	end
	self._viewmodelWatch = sub(viewmodelState._viewmodel, function(vm: any): ()
		applyViewmodelPatches(self, vm)
	end)
end

local function releaseViewmodelWatch(self: any): ()
	if anyViewmodelActive(self) then
		return
	end
	if self._viewmodelWatch then
		self._viewmodelWatch()
		self._viewmodelWatch = nil
	end
end

function Removals.EnableSpring(self: Removals, name: string): ()
	if self._springEnabled[name] then
		return
	end
	self._springEnabled[name] = true
	ensureViewmodelWatch(self)
	local vm = peek(viewmodelState._viewmodel)
	if type(vm) == "table" then
		patchSprings(self, vm)
	end
end

function Removals.DisableSpring(self: Removals, name: string): ()
	if not self._springEnabled[name] then
		return
	end
	self._springEnabled[name] = false
	restoreSpring(self, name)
	releaseViewmodelWatch(self)
end

function Removals.EnableSprintAnimation(self: Removals): ()
	if self._sprintEnabled then
		return
	end
	self._sprintEnabled = true
	ensureViewmodelWatch(self)
	local vm = peek(viewmodelState._viewmodel)
	if type(vm) == "table" then
		patchSprint(self, vm)
	end
end

function Removals.DisableSprintAnimation(self: Removals): ()
	if not self._sprintEnabled then
		return
	end
	self._sprintEnabled = false
	restoreSprint(self)
	releaseViewmodelWatch(self)
end

function Removals.EnableMuzzleFlash(self: Removals): ()
	if self._muzzleFlashEnabled then
		return
	end
	self._muzzleFlashEnabled = true
	ensureViewmodelWatch(self)
	installMuzzleFlashHook(self)
end

function Removals.DisableMuzzleFlash(self: Removals): ()
	if not self._muzzleFlashEnabled then
		return
	end
	self._muzzleFlashEnabled = false
	restoreMethodHook(self, "muzzleFlash")
	releaseViewmodelWatch(self)
end

function Removals.EnableIdle(self: Removals): ()
	if self._idleEnabled then
		return
	end
	self._idleEnabled = true
	ensureViewmodelWatch(self)
	local vm = peek(viewmodelState._viewmodel)
	if type(vm) == "table" then
		local animator = vm.Animator
		if type(animator) == "table" then
			installIdleHook(self, getmetatable(animator))
			animator.PlayIdleAnimation(animator)
		end
	end
end

function Removals.DisableIdle(self: Removals): ()
	if not self._idleEnabled then
		return
	end
	self._idleEnabled = false
	restoreMethodHook(self, "idle")
	releaseViewmodelWatch(self)
	local vm = peek(viewmodelState._viewmodel)
	if type(vm) == "table" then
		vm.Animator.PlayIdleAnimation(vm.Animator)
	end
end

function Removals.EnableEquip(self: Removals): ()
	if self._equipEnabled then
		return
	end
	self._equipEnabled = true
	ensureViewmodelWatch(self)
	local vm = peek(viewmodelState._viewmodel)
	if type(vm) == "table" and type(vm.Animator) == "table" then
		installEquipHook(self, getmetatable(vm.Animator))
	end
end

function Removals.DisableEquip(self: Removals): ()
	if not self._equipEnabled then
		return
	end
	self._equipEnabled = false
	restoreMethodHook(self, "equip")
	releaseViewmodelWatch(self)
end

function Removals.EnableShoot(self: Removals): ()
	if self._shootEnabled then
		return
	end
	self._shootEnabled = true
	ensureViewmodelWatch(self)
	local vm = peek(viewmodelState._viewmodel)
	if type(vm) == "table" and type(vm.Animator) == "table" then
		installPlayAnimationHook(self, getmetatable(vm.Animator))
	end
end

function Removals.DisableShoot(self: Removals): ()
	if not self._shootEnabled then
		return
	end
	self._shootEnabled = false
	if not self._reloadEnabled then
		restoreMethodHook(self, "playAnimation")
	end
	releaseViewmodelWatch(self)
end

function Removals.EnableReload(self: Removals): ()
	if self._reloadEnabled then
		return
	end
	self._reloadEnabled = true
	ensureViewmodelWatch(self)
	local vm = peek(viewmodelState._viewmodel)
	if type(vm) == "table" and type(vm.Animator) == "table" then
		installPlayAnimationHook(self, getmetatable(vm.Animator))
	end
end

function Removals.DisableReload(self: Removals): ()
	if not self._reloadEnabled then
		return
	end
	self._reloadEnabled = false
	if not self._shootEnabled then
		restoreMethodHook(self, "playAnimation")
	end
	releaseViewmodelWatch(self)
end

function Removals.Destroy(self: Removals): ()
	self:DisableSmokes()
	self:DisableSmokeBlind()
	self:DisableFlashes()
	self:DisableCameraShake()
	self:DisableTracers()
	self:DisableBurnEffect()
	self:DisableHeadshotParticles()
	self:DisableBulletImpact()
	self:ApplySoundSelection({})
	self:DisableDamageIndicators()
	self:DisableDamageNumbers()
	self:DisableSprintAnimation()
	self:DisableMuzzleFlash()
	self:DisableIdle()
	self:DisableEquip()
	self:DisableShoot()
	self:DisableReload()
	for name in next, SPRING_REMOVALS do
		self:DisableSpring(name)
	end
	BaseFeature.Destroy(self)
end

export type Removals =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_flashLink: gameUi.Linker,
			_hiddenSmokes: { [Model]: Instance },
			_smokesEnabled: boolean,
			_smokesJanitor: Janitor.Janitor?,
			_smokeBlindEnabled: boolean,
			_flashesEnabled: boolean,
			_flashReductionWatch: any,
			_flashMultiplier: number,
			_flashHookTarget: any?,
			_originalFlash: any?,
			_smokeBlindHookTarget: any?,
			_smokeCloudsModule: any?,
			_cameraShakeEnabled: boolean,
			_shakeFn: any,
			_shakeIndices: { number },
			_tracersEnabled: boolean,
			_tracersHookTarget: any?,
			_blockedMechanicsSounds: { [string]: boolean },
			_mechanicsSoundHookTarget: any?,
			_animSoundPatches: { [string]: { [string]: any } },
			_placeSoundHookTarget: any?,
			_damageIndicatorsEnabled: boolean,
			_damageIndicatorsFrame: GuiObject?,
			_damageIndicatorsVisible: boolean,
			_damageNumbersEnabled: boolean,
			_damageNumbersJanitor: Janitor.Janitor?,
			_patchedViewmodels: any,
			_viewmodelWatch: any,
			_sprintHookTarget: any,
			_methodHooks: { [string]: any },
			_springEnabled: any,
			_sprintEnabled: boolean,
			_muzzleFlashEnabled: boolean,
			_idleEnabled: boolean,
			_equipEnabled: boolean,
			_shootEnabled: boolean,
			_aimVignetteEnabled: boolean,
			_aimVignetteJanitor: Janitor.Janitor?,
			_reloadEnabled: boolean,
			_burnEffectEnabled: boolean,
			_burnHookTarget: any?,
			_headshotEnabled: boolean,
			_headshotHookTarget: any?,
			_impactEnabled: boolean,
			_impactHookTarget: any?,
		},
		Removals
	))
	& BaseFeature.BaseFeature

return Removals
