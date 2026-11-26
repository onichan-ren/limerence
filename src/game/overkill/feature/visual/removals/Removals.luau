local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local ModuleController = require("@game/overkill/module/ModuleController")
local ClientState = require("@game/overkill/client/clientState")
local hudSuppressor = require("@game/overkill/feature/visual/removals/hudSuppressor")

type SoundMatch = { match: string, scope: string? }
type AnimMatch = { match: string, localOnly: boolean? }

local SOUND_REMOVALS = {
	{ label = "Enemy Hit Sound", matches = { "PlayerImpact" } },
	{ label = "Grenade Throw", matches = { "Throw" } },
	{ label = "Enemy Gunfire", matches = { "Fire" }, scope = "enemy" },
	{ label = "Local Gunfire", matches = { "Fire" }, scope = "local" },
	{ label = "Minigun Spin", matches = { "Spin" } },
	{ label = "Explosions", matches = { "Explosion" } },
	{ label = "Kill Sound", matches = { "HitMarkerKill" } },
	{ label = "Hit Sound", matches = { "HitMarkerBody", "HitMarkerHead" } },
	{ label = "Inspect", matches = { "Inspect" } },
	{ label = "Reload", matches = { "Reload" } },
	{ label = "Melee", matches = { "Swing" } },
	{ label = "Equip", matches = { "Deploy" } },
	{ label = "Aim", matches = { "Aim" } },
}

local SOUND_REMOVAL_LABELS: { string } = {}
for _, entry in next, SOUND_REMOVALS do
	table.insert(SOUND_REMOVAL_LABELS, entry.label)
end

local ANIM_REMOVALS = {
	{ label = "Reload", matches = { "Reload" }, localOnly = true },
	{ label = "Sprint", matches = { "Sprint" } },
}

local ANIM_REMOVAL_LABELS: { string } = {}
for _, entry in next, ANIM_REMOVALS do
	table.insert(ANIM_REMOVAL_LABELS, entry.label)
end

local mutedDummy: Sound? = nil

local function mutedSound(): Sound
	local dummy = mutedDummy
	if not dummy or dummy.Parent ~= nil then
		dummy = Instance.new("Sound")
		mutedDummy = dummy
	end
	return dummy
end

local function moduleFn(key: string, method: string): any
	local module = ModuleController.GetModule(key)
	if type(module) ~= "table" then
		return nil
	end
	local fn = rawget(module, method)
	if type(fn) ~= "function" then
		return nil
	end
	return fn
end

local function patchConstants(fn: any, oldValue: any, newValue: any): { number }
	local indices: { number } = {}
	if type(fn) ~= "function" then
		return indices
	end
	local constants = debug.getconstants(fn)
	for i = 1, #constants do
		if constants[i] == oldValue then
			debug.setconstant(fn, i, newValue)
			indices[#indices + 1] = i
		end
	end
	return indices
end

local function restoreConstants(fn: any, indices: { number }, value: any): ()
	if type(fn) ~= "function" then
		return
	end
	for i = 1, #indices do
		debug.setconstant(fn, indices[i], value)
	end
end

local _cameraShakeInstance: any = nil

local function shakeUpdateFn(): any
	if _cameraShakeInstance == nil then
		_cameraShakeInstance = filtergc("table", {
			Keys = { "UpdateShake", "SetScaleMagnitude", "GetScaleMagnitude", "CameraShakeState" },
		}, true) or false
	end
	local instance = _cameraShakeInstance
	if type(instance) ~= "table" then
		return nil
	end
	local fn = rawget(instance, "UpdateShake")
	return type(fn) == "function" and fn or nil
end

local Removals = {}
Removals.__index = Removals

setmetatable(Removals, { __index = BaseFeature })

function Removals.new(link: gameUi.Linker): Removals
	local self = BaseFeature.new() :: any
	setmetatable(self, Removals)

	link:Options("removals", "Removals")
	local removalsLink = link:OnKey("removals")

	removalsLink:Toggle("damageIndicators", "Damage Indicators", false):SetTip({
		title = "Damage Indicators",
		body = "Hides the direction indicators shown when you take damage.",
	})
	removalsLink:Toggle("damageNumbers", "Damage Numbers", false):SetTip({
		title = "Damage Numbers",
		body = "Hides the floating damage numbers over enemies you hit.",
	})
	removalsLink:Toggle("footsteps", "Footstep Sounds", false):SetTip({
		title = "Footstep Sounds",
		body = "Mutes footstep sounds from you and other players.",
	})
	removalsLink:Toggle("cameraShake", "Camera Shake", false):SetTip({
		title = "Camera Shake",
		body = "Stops the screen from shaking when firing or near blasts.",
	})
	removalsLink:Toggle("hitFovPunch", "Hit FOV Punch", false):SetTip({
		title = "Hit FOV Punch",
		body = "Stops the zoom kick when you land a hit.",
	})
	removalsLink:Toggle("tracers", "Bullet Tracers", false):SetTip({
		title = "Bullet Tracers",
		body = "Removes bullet tracer beams and their flyby sounds.",
	})
	removalsLink:Toggle("muzzleFlash", "Muzzle Flash", false):SetTip({
		title = "Muzzle Flash",
		body = "Hides the flash at the barrel when firing.",
	})
	removalsLink:Toggle("bulletImpact", "Bullet Impact", false):SetTip({
		title = "Bullet Impact",
		body = "Removes the marks where shots hit surfaces.",
	})
	removalsLink:Toggle("damageHighlight", "Hit Highlight", false):SetTip({
		title = "Hit Highlight",
		body = "Removes the glow on enemies you damage.",
	})
	removalsLink:Toggle("slideTilt", "Slide Tilt", false):SetTip({
		title = "Slide Tilt",
		body = "Stops the crosshair and hitmarker from tilting while you slide.",
	})
	removalsLink:Toggle("hitmarker", "Hitmarker", false):SetTip({
		title = "Hitmarker",
		body = "Removes the hitmarker shown when your shots land.",
	})
	removalsLink
		:Dropdown("animations", "Animations", ANIM_REMOVAL_LABELS, {})
		:SetMode("multi")
		:SetPlaceholder("None")
		:SetTip({
			title = "Animation Removals",
			body = "Select weapon animations to hide.",
		})
	removalsLink:Dropdown("sounds", "Sounds", SOUND_REMOVAL_LABELS, {}):SetMode("multi"):SetPlaceholder("None"):SetTip({
		title = "Sound Removals",
		body = "Mute selected in-game sounds.",
	})

	self._link = removalsLink
	self._cameraShakeEnabled = false
	self._shakeFn = nil :: any
	self._shakeIndices = {} :: { number }
	self._methodHooks = {} :: { [string]: any }
	self._mutedMatches = {} :: { string }
	self._soundHookTarget = nil :: any
	self._mutedAnims = {} :: { string }
	self._animHookTarget = nil :: any
	self._footstepGroups = nil :: any
	self._footstepWalk = nil :: any
	self._footstepRun = nil :: any
	self._footstepActive = false
	self._slideTiltActive = false
	self._slideTiltSetFn = nil :: any
	self._slideTiltGetFn = nil :: any
	self._slideTiltSetIndices = {} :: { number }
	self._slideTiltGetIndices = {} :: { number }
	self._hitFovActive = false
	self._hitFovFn = nil :: any
	self._hitFovIndices = {} :: { number }
	self._suppressHeld = {} :: { [string]: boolean }

	self:Track(removalsLink:Get("cameraShake"):OnChange(function(value: boolean): ()
		if value then
			self:EnableCameraShake()
		else
			self:DisableCameraShake()
		end
	end))

	self:Track(removalsLink:Get("muzzleFlash"):OnChange(function(value: boolean): ()
		if value then
			self:HookNoop("muzzleFlash", "gunEffects", "MuzzleFlash")
		else
			self:UnhookNoop("muzzleFlash")
		end
	end))

	self:Track(removalsLink:Get("tracers"):OnChange(function(value: boolean): ()
		if value then
			self:HookNoop("tracers", "gunEffects", "BulletTrail")
		else
			self:UnhookNoop("tracers")
		end
	end))

	self:Track(removalsLink:Get("bulletImpact"):OnChange(function(value: boolean): ()
		if value then
			self:HookNoop("bulletImpact", "gunEffects", "WallHit")
		else
			self:UnhookNoop("bulletImpact")
		end
	end))

	self:Track(removalsLink:Get("hitFovPunch"):OnChange(function(value: boolean): ()
		if value then
			self:InstallHitFovHook()
		else
			self:RemoveHitFovHook()
		end
	end))

	self:Track(removalsLink:Get("damageNumbers"):OnChange(function(value: boolean): ()
		self:SetSuppressed("Text", value)
	end))

	self:Track(removalsLink:Get("damageHighlight"):OnChange(function(value: boolean): ()
		if value then
			self:HookNoop("damageHighlight", "damage", "Highlight")
		else
			self:UnhookNoop("damageHighlight")
		end
	end))

	self:Track(removalsLink:Get("damageIndicators"):OnChange(function(value: boolean): ()
		if value then
			self:HookNoop("damageIndicators", "damage", "Indicator")
		else
			self:UnhookNoop("damageIndicators")
		end
	end))

	self:Track(removalsLink:Get("hitmarker"):OnChange(function(value: boolean): ()
		self:SetSuppressed("HitMarker", value)
	end))

	self:Track(removalsLink:Get("slideTilt"):OnChange(function(value: boolean): ()
		if value then
			self:InstallSlideTiltHook()
		else
			self:RemoveSlideTiltHook()
		end
	end))

	self:Track(removalsLink:Get("footsteps"):OnChange(function(value: boolean): ()
		if value then
			self:InstallFootstepHook()
		else
			self:RemoveFootstepHook()
		end
	end))

	self:Track(removalsLink:Get("sounds"):OnChange(function(selection: any): ()
		self:ApplySoundSelection(selection)
	end))
	self:ApplySoundSelection(removalsLink:Peek("sounds"))

	self:Track(removalsLink:Get("animations"):OnChange(function(selection: any): ()
		self:ApplyAnimSelection(selection)
	end))
	self:ApplyAnimSelection(removalsLink:Peek("animations"))

	return self
end

function Removals.SetSuppressed(self: Removals, method: string, value: boolean): ()
	local held = self._suppressHeld
	if (held[method] == true) == value then
		return
	end
	held[method] = value
	if value then
		hudSuppressor.Acquire(method)
	else
		hudSuppressor.Release(method)
	end
end

function Removals.HookNoop(self: Removals, name: string, key: string, method: string): ()
	if self._methodHooks[name] then
		return
	end
	local fn = moduleFn(key, method)
	if not fn then
		return
	end
	self._methodHooks[name] = fn
	hook.add(fn, function(): () end)
end

function Removals.UnhookNoop(self: Removals, name: string): ()
	local fn = self._methodHooks[name]
	if fn then
		hook.restore(fn)
		self._methodHooks[name] = nil
	end
end

function Removals.EnableCameraShake(self: Removals): ()
	if self._cameraShakeEnabled then
		return
	end

	local fn = shakeUpdateFn()
	if not fn then
		return
	end

	self._cameraShakeEnabled = true
	self._shakeFn = fn
	self._shakeIndices = patchConstants(fn, 0.5, 0)
end

function Removals.DisableCameraShake(self: Removals): ()
	if not self._cameraShakeEnabled then
		return
	end
	self._cameraShakeEnabled = false

	if self._shakeFn then
		restoreConstants(self._shakeFn, self._shakeIndices, 0.5)
	end
	self._shakeFn = nil
	self._shakeIndices = {}
end

function Removals.InstallHitFovHook(self: Removals): ()
	if self._hitFovActive then
		return
	end

	local fn = moduleFn("cameraHandler", "HitFOVPunch")
	if not fn then
		return
	end

	self._hitFovActive = true
	self._hitFovFn = fn
	self._hitFovIndices = patchConstants(fn, 0.1, 0)
end

function Removals.RemoveHitFovHook(self: Removals): ()
	if not self._hitFovActive then
		return
	end
	self._hitFovActive = false

	if self._hitFovFn then
		restoreConstants(self._hitFovFn, self._hitFovIndices, 0.1)
	end
	self._hitFovFn = nil
	self._hitFovIndices = {}
end

function Removals.ApplySoundSelection(self: Removals, selection: any): ()
	local matches: { SoundMatch } = {}
	if type(selection) == "table" then
		local set: { [string]: boolean } = {}
		for _, label in next, selection do
			if type(label) == "string" then
				set[label] = true
			end
		end
		for _, entry in next, SOUND_REMOVALS do
			if set[entry.label] then
				for _, m in next, entry.matches do
					table.insert(matches, { match = m, scope = entry.scope })
				end
			end
		end
	end

	self._mutedMatches = matches
	if #matches > 0 then
		self:InstallSoundHook()
	else
		self:RemoveSoundHook()
	end
end

function Removals.InstallSoundHook(self: Removals): ()
	if self._soundHookTarget then
		return
	end
	local fn = moduleFn("soundManager", "PlayInstance")
	if not fn then
		return
	end

	self._soundHookTarget = fn
	local trampoline
	trampoline = hook.add(
		fn,
		LPH_NO_VIRTUALIZE(function(smSelf: any, sound: any, location: any, ...: any): any
			if typeof(sound) == "Instance" then
				local name = sound.Name
				local isLocal = location == nil
				local matches = self._mutedMatches
				for index = 1, #matches do
					local entry = matches[index]
					local scope = entry.scope
					if (scope == nil or (scope == "local") == isLocal) and string.find(name, entry.match, 1, true) then
						return mutedSound()
					end
				end
			end
			return trampoline(smSelf, sound, location, ...)
		end)
	)
end

function Removals.RemoveSoundHook(self: Removals): ()
	if self._soundHookTarget then
		hook.restore(self._soundHookTarget)
		self._soundHookTarget = nil
	end
end

function Removals.InstallFootstepHook(self: Removals): ()
	if self._footstepActive then
		return
	end
	local module = ModuleController.GetModule("soundManager")
	local groups = type(module) == "table" and rawget(module, "specifiersInGroup") or nil
	if type(groups) ~= "table" then
		return
	end

	self._footstepGroups = groups
	self._footstepWalk = groups.Walk
	self._footstepRun = groups.Run
	groups.Walk = nil
	groups.Run = nil
	self._footstepActive = true
end

function Removals.RemoveFootstepHook(self: Removals): ()
	if not self._footstepActive then
		return
	end
	self._footstepActive = false

	local groups = self._footstepGroups
	if type(groups) == "table" then
		groups.Walk = self._footstepWalk
		groups.Run = self._footstepRun
	end
	self._footstepGroups = nil
	self._footstepWalk = nil
	self._footstepRun = nil
end

function Removals.InstallSlideTiltHook(self: Removals): ()
	if self._slideTiltActive then
		return
	end
	local setFn = moduleFn("crosshairRender", "SetSlideTilt")
	local getFn = moduleFn("crosshairRender", "GetSlideTilt")
	if not setFn and not getFn then
		return
	end

	self._slideTiltActive = true
	self._slideTiltSetFn = setFn
	self._slideTiltGetFn = getFn
	self._slideTiltSetIndices = setFn and patchConstants(setFn, 20, 0) or {}
	self._slideTiltGetIndices = getFn and patchConstants(getFn, 20, 0) or {}
end

function Removals.RemoveSlideTiltHook(self: Removals): ()
	if not self._slideTiltActive then
		return
	end
	self._slideTiltActive = false

	if self._slideTiltSetFn then
		restoreConstants(self._slideTiltSetFn, self._slideTiltSetIndices, 20)
	end
	if self._slideTiltGetFn then
		restoreConstants(self._slideTiltGetFn, self._slideTiltGetIndices, 20)
	end
	self._slideTiltSetFn = nil
	self._slideTiltGetFn = nil
	self._slideTiltSetIndices = {}
	self._slideTiltGetIndices = {}
end

function Removals.ApplyAnimSelection(self: Removals, selection: any): ()
	local matches: { AnimMatch } = {}
	if type(selection) == "table" then
		local set: { [string]: boolean } = {}
		for _, label in next, selection do
			if type(label) == "string" then
				set[label] = true
			end
		end
		for _, entry in next, ANIM_REMOVALS do
			if set[entry.label] then
				for _, m in next, entry.matches do
					table.insert(matches, { match = m, localOnly = entry.localOnly })
				end
			end
		end
	end

	self._mutedAnims = matches
	if #matches > 0 then
		self:InstallAnimHook()
	else
		self:RemoveAnimHook()
	end
end

function Removals.IsLocalViewModel(self: Removals, viewModel: any): boolean
	local character = ClientState.character()
	if not character then
		return false
	end
	local module = ModuleController.GetModule("viewModel")
	if type(module) ~= "table" then
		return false
	end
	local getControllers = rawget(module, "getControllers")
	if type(getControllers) ~= "function" then
		return false
	end
	local controllers = getControllers(character, true)
	if type(controllers) ~= "table" then
		return false
	end
	for _, controller in next, controllers do
		if type(controller) == "table" and controller.viewModel == viewModel then
			return true
		end
	end
	return false
end

function Removals.InstallAnimHook(self: Removals): ()
	if self._animHookTarget then
		return
	end
	local fn = moduleFn("animationInterface", "Find")
	if not fn then
		return
	end

	self._animHookTarget = fn
	local trampoline
	trampoline = hook.add(
		fn,
		LPH_NO_VIRTUALIZE(function(ifaceSelf: any, character: any, name: any, ...: any): any
			if type(name) == "string" then
				local matches = self._mutedAnims
				for index = 1, #matches do
					local entry = matches[index]
					if string.find(name, entry.match, 1, true) then
						if not entry.localOnly or self:IsLocalViewModel(character) then
							return nil
						end
					end
				end
			end
			return trampoline(ifaceSelf, character, name, ...)
		end)
	)
end

function Removals.RemoveAnimHook(self: Removals): ()
	if self._animHookTarget then
		hook.restore(self._animHookTarget)
		self._animHookTarget = nil
	end
end

function Removals.Destroy(self: Removals): ()
	self:DisableCameraShake()
	self:RemoveHitFovHook()
	self:UnhookNoop("muzzleFlash")
	self:UnhookNoop("tracers")
	self:UnhookNoop("bulletImpact")
	self:SetSuppressed("Text", false)
	self:UnhookNoop("damageHighlight")
	self:UnhookNoop("damageIndicators")
	self:SetSuppressed("HitMarker", false)
	self:RemoveSoundHook()
	self:RemoveAnimHook()
	self:RemoveFootstepHook()
	self:RemoveSlideTiltHook()
	BaseFeature.Destroy(self)
end

export type Removals =
	typeof(setmetatable(
		{} :: {
			_link: any,
			_cameraShakeEnabled: boolean,
			_shakeFn: any,
			_shakeIndices: { number },
			_methodHooks: { [string]: any },
			_mutedMatches: { SoundMatch },
			_soundHookTarget: any,
			_mutedAnims: { AnimMatch },
			_animHookTarget: any,
			_footstepGroups: any,
			_footstepWalk: any,
			_footstepRun: any,
			_footstepActive: boolean,
			_slideTiltActive: boolean,
			_slideTiltSetFn: any,
			_slideTiltGetFn: any,
			_slideTiltSetIndices: { number },
			_slideTiltGetIndices: { number },
			_hitFovActive: boolean,
			_hitFovFn: any,
			_hitFovIndices: { number },
			_suppressHeld: { [string]: boolean },
			SetSuppressed: (Removals, string, boolean) -> (),
			HookNoop: (Removals, string, string, string) -> (),
			UnhookNoop: (Removals, string) -> (),
			EnableCameraShake: (Removals) -> (),
			DisableCameraShake: (Removals) -> (),
			InstallHitFovHook: (Removals) -> (),
			RemoveHitFovHook: (Removals) -> (),
			ApplySoundSelection: (Removals, any) -> (),
			InstallSoundHook: (Removals) -> (),
			RemoveSoundHook: (Removals) -> (),
			InstallFootstepHook: (Removals) -> (),
			RemoveFootstepHook: (Removals) -> (),
			InstallSlideTiltHook: (Removals) -> (),
			RemoveSlideTiltHook: (Removals) -> (),
			ApplyAnimSelection: (Removals, any) -> (),
			IsLocalViewModel: (Removals, any) -> boolean,
			InstallAnimHook: (Removals) -> (),
			RemoveAnimHook: (Removals) -> (),
		},
		Removals
	))
	& BaseFeature.BaseFeature

return Removals
