local logger = require("@share/logger").new("ModuleController")

local TweenService = game:GetService("TweenService")

local ModuleController = {
	_modules = {},
}

local Modules = {
	BulletClass = {
		"setSpreadConfig",
	},
	SpectateController = {
		"GetCurrentSpectateInstance",
		"SetNextPlayer",
	},
	WeaponClass = {
		"setupRecoil",
		"drop",
	},
	SoundClass = {
		"PlaySoundAtPosition",
	},
	Movement = {
		"CheckGroundContact",
	},
	Inventory = {
		"newInventoryItem",
		"Initialize",
	},
	SmokeClass = {
		"GetActiveVoxelCount",
		"Disrupt",
	},
	FireClass = {
		"Create",
		"Update",
		"Destroy",
		"DestroyAll",
	},
	FlashClass = {
		"IsFlashed",
		"GetAudioFadeMultiplier",
	},
	Viewmodel = {
		"setupCharmPhysics",
		"construct",
		"attachSleeves",
	},
	CharacterKinematics = {
		"setTargetRotation",
		"setVerticalLook",
	},
	CharacterController = {
		"getCurrentCharacter",
	},
	DataController = {
		"WaitForDataLoaded",
		"CreateListener",
		"RemoveListener",
	},
	CharacterAnimator = {
		"unregisterGroup",
	},
	Skins = {
		"GetAllSkinsForWeapon",
		"GetSkinInformation",
		"GetWearImageForFloat",
		"GetGloves",
	},
	CreateWeaponModel = {
		"ClearPlayerCache",
		"RefreshObjectiveKitHolster",
		"RefreshBombHolster",
	},
	CameraController = {
		"updateCameraFOV",
		"setWeaponRecoil",
	},
	SniperScope = {
		"updateMovementSharpness",
		"updateScope",
	},
	Bobble = {
		"getNextCFrame",
		"setIsAiming",
	},
	LoadoutMenu = {
		"HandleDrop",
		"UpdateLoadoutContainer",
		"UpdateSidebarFrames",
		"CreateLoadoutTemplate",
	},
	KillFeed = {
		"createTemplate",
		"Initialize",
		check = function(moduleData: any): boolean
			return getupvalue(rawget(moduleData, "createTemplate") :: any, 4) == TweenService
		end,
	},
	SoundController = {
		"SetCharacter",
		"OnStateChanged",
	},
	Radar = {
		"UpdatePlayerIcons",
		"WorldToRadar",
	},
}

ModuleController.new = function(): ModuleController
	local modules = ModuleController._modules

	LPH_NO_VIRTUALIZE(function()
		for _, module in next, getloadedmodules(true) do
			if next(Modules) == nil then
				break
			end

			local moduleData = (require :: any)(module)

			if not moduleData or typeof(moduleData) ~= "table" then
				continue
			end

			for moduleName, strings in next, Modules do
				local found = true
				for _, string in next, strings do
					if _ == "check" then
						continue
					end
					if not rawget(moduleData, string) then
						found = false
						break
					end
				end
				if found then
					if strings.check and not strings.check(moduleData) then
						continue
					end
					modules[moduleName] = moduleData
					Modules[moduleName] = nil
					break
				end
			end
		end
	end)()

	if next(Modules) then
		logger:error("failed to find modules")
	end

	return ModuleController
end

function ModuleController.GetModule(name: string): any
	return ModuleController._modules[name]
end

function ModuleController.Destroy(): ()
	for key in next, ModuleController._modules do
		ModuleController._modules[key] = nil
	end
end

export type ModuleController = typeof(ModuleController)
return ModuleController
