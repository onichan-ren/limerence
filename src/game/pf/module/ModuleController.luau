local logger = require("@share/logger").new("ModuleController")

local ModuleController = {
	_modules = {},
}

local Modules = {
	ReplicationInterface = {
		"operateOnAllEntries",
		"getEntry",
		"getPlayerFromBodyPart",
	},
	ReplicationEvents = {
		"onEntryAdded",
		"onEntryRemoved",
	},
	HudSpottingInterface = {
		"spot",
		"goingLoud",
		"isSpotted",
	},
	HudScopeInterface = {
		"setScope",
		"updateScope",
		"setScopeSettings",
	},
	HudCrosshairsInterface = {
		"getCrossSize",
		"setCrossSize",
		"setCrossHairType",
	},
	HudScreenGui = {
		"getScreenGui",
		"getUIScaleInstance",
		"mount",
	},
	PlayerStatusInterface = {
		"getDeployStatus",
		"getAllowedState",
		"getDisableAllState",
	},
	CharacterInterface = {
		"getCharacterObject",
		"getTimeTillSpawn",
		"isSpawning",
	},
	NetworkClient = {
		"send",
		"receive",
		"fireReady",
		"getPing",
	},
	ContentInterface = {
		"getWeaponListFromClass",
		"getAllWeaponsList",
		"getWeaponData",
	},
	ActiveLoadoutUtils = {
		"getActiveLoadoutData",
		"changeWeapon",
		"getActiveClassSlot",
	},
	PlayerDataClientInterface = {
		"getPlayerData",
	},
	PlayerDataUtils = {
		"ownsWeapon",
		"ownsAttachment",
		"getUnlocksData",
	},
	PlayerDataClientEvents = {
		"onDataLoaded",
		"onDataUpdated",
		"onWeaponKillsUpdated",
	},
	ThirdPersonObject = {
		"setCharacterRender",
		"popCharacterModel",
		"getCharacterHash",
	},
	LeaderboardInterface = {
		"getEntry",
		"addEntry",
		"fillBoard",
	},
	LeaderboardObject = {
		"getStat",
		"updateName",
		"updateTeam",
		"updateStats",
	},
	BulletInterface = {
		"newBullet",
		"physicsStep",
		"cleanBullets",
	},
	HitDetectionInterface = {
		"playerHitDection",
		"hitDetection",
		"meleeHitPlayer",
	},
	WeaponUtils = {
		"interpolateDamageGraph",
		"getDistancesFromDamage",
		"generateHitboxes",
	},
	RoundSystemClientInterface = {
		"getMapName",
		"getMatchData",
		"getGameModeType",
	},
	GameClock = {
		"isReady",
		"getTime",
		"setReplayOffset",
	},
	RoundSystemClientEvents = {
		"onMatchChanged",
		"onRoundStarted",
		"onRoundEnded",
		"onVoteStarted",
		"onVoteListChanged",
		"onModeVoteUpdated",
		"onMapVoteUpdated",
		"onCountdownStarted",
	},
	EnvironmentInterfaceClient = {
		"getNearbyWeapons",
		"spawnWeapon",
		"removeDrop",
	},
	AudioSystem = {
		"playSound",
		"playSoundId",
		"createSoundGroup",
	},
	Sway = {
		"getSwayCFrame",
		"getBobCFrame",
		"getBreathCFrame",
	},
	Effects = {
		"muzzleflash",
		"ejectshell",
		"breakwindow",
	},
	FirearmObject = {
		"computeWalkSway",
		"computeGunSway",
		"canFire",
	},
	MeleeObject = {
		"walkSway",
		"meleeSway",
		"stepHitboxes",
	},
	GrenadeObject = {
		"walkSway",
		"modelSway",
		"throwInstance",
	},
	HudBloodArcInterface = {
		"addEntry",
		"operateOnAllEntries",
		"clearAllEntries",
	},
	Animation = {
		"player",
		"reset",
	},
	MainCameraObject = {
		"applyImpulse",
		"hit",
		"setSuppression",
	},
	CameraInterface = {
		"getActiveCamera",
		"getCameraType",
		"setCameraType",
	},
	ScreenCull = {
		"sphere",
		"localSegment",
		"point",
		"segment",
	},
	ActionBindInterface = {
		"isInputActionDown",
		"isInputAction",
		"getActiveDeviceBinds",
	},
	PublicSettings = {
		"bulletAcceleration",
		"bulletLifeTime",
	},
}

ModuleController.new = function(): ModuleController
	local modules = ModuleController._modules

	local missing = {}

	LPH_NO_VIRTUALIZE(function()
		for moduleName, strings in next, Modules do
			local keys = {}
			for key, value in next, strings do
				if key ~= "check" then
					keys[#keys + 1] = value
				end
			end

			local moduleData = filtergc("table", { Keys = keys }, true)
			if not moduleData or (strings.check and not strings.check(moduleData)) then
				missing[#missing + 1] = moduleName
				continue
			end

			modules[moduleName] = moduleData
		end
	end)()

	if #missing > 0 then
		logger:error("failed to find modules: " .. table.concat(missing, ", "))
	end

	return ModuleController
end

function ModuleController.GetModule(name: string): any
	return ModuleController._modules[name]
end

function ModuleController.Destroy(): ()
	table.clear(ModuleController._modules)
end

export type ModuleController = typeof(ModuleController)

return ModuleController
