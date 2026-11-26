local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local ScopeController = require("@feature/ui/scope/ScopeController")
local PlayerController = require("@feature/player/PlayerController")
local ClientState = require("@game/rivals/client/clientState")
local grenadeState = require("@game/rivals/grenade/grenadeState")
local flashVisibility = require("@game/rivals/feature/combat/legitbot/flashVisibility")
local ModuleController = require("@game/rivals/module/ModuleController")
local Registry = require("@game/rivals/registry/Registry")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local viewmodelState = require("@game/rivals/viewmodel/viewmodelState")
local smokeRay = require("@game/rivals/feature/combat/legitbot/smokeRay")
local chargeReader = require("@game/rivals/feature/combat/legitbot/chargeReader")
local UniversalLegitbot = require("@game/universal/feature/combat/legitbot/Legitbot")
local legitbotApi = require("@game/universal/feature/combat/legitbot/legitbotApi")
local bulletRedirection = require("@game/rivals/feature/combat/legitbot/bulletRedirection")
local Backtrack = require("@game/rivals/feature/combat/legitbot/Backtrack")
local mapWhitelist = require("@game/rivals/feature/combat/legitbot/mapWhitelist")
local botSource = require("@game/rivals/feature/training/botSource")

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe

local skipBlocking = at(false)
local trgBlocking = at(false)
local ignoreCrossbow = at(false)

local SHIELD_ITEM_NAMES: { [string]: true } = {
	["Riot Shield"] = true,
	["Door"] = true,
	["Sled"] = true,
	["Energy Shield"] = true,
	["Masterpiece"] = true,
	["Glorious Riot Shield"] = true,
	["Tombstone Shield"] = true,
}

local isPlayerCovered = LPH_NO_VIRTUALIZE(function(player: any, checkBlocking: boolean, checkShield: boolean): boolean
	if not checkBlocking and not checkShield then
		return false
	end
	local deflecting = checkBlocking and peek(player.isDeflecting) == true
	local shieldFront = false
	local shieldBack = false
	if checkShield then
		local equipped = peek(player.currentEquipped)
		if equipped ~= nil and SHIELD_ITEM_NAMES[equipped.Name] == true then
			shieldFront = true
		else
			local items = peek(player.items)
			for i = 1, #items do
				if SHIELD_ITEM_NAMES[items[i]] then
					shieldBack = true
					break
				end
			end
		end
	end
	if not deflecting and not shieldFront and not shieldBack then
		return false
	end
	local hrp = peek(player.hrp)
	if not hrp then
		return true
	end
	local cf = hrp.CFrame
	local toShooter = workspace.CurrentCamera.CFrame.Position - cf.Position
	if toShooter.Magnitude < 0.01 then
		return true
	end
	if cf.LookVector:Dot(toShooter.Unit) > 0 then
		return deflecting or shieldFront
	end
	return shieldBack
end)

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include
raycastParams.IgnoreWater = true
raycastParams.RespectCanCollide = false

local cachedSmokeClouds: any = nil
local voxelScratch: { [BasePart]: any } = {}

local getSmokeVoxels = LPH_NO_VIRTUALIZE(function(): { [BasePart]: any }
	local voxels = voxelScratch
	table.clear(voxels)

	for _, smoke in next, peek(grenadeState.activeSmokes) do
		local part = smoke.part
		if part and part.Parent then
			voxels[part] = smoke
		end
	end
	if next(voxels) ~= nil then
		return voxels
	end

	local smokeClouds = cachedSmokeClouds
	if not smokeClouds then
		smokeClouds = ModuleController.GetModule("SmokeClouds")
		cachedSmokeClouds = smokeClouds
	end
	if not smokeClouds then
		return voxels
	end

	local registry = rawget(smokeClouds, "_smoke_clouds")
	if type(registry) ~= "table" then
		return voxels
	end

	for part, smoke in next, registry do
		if typeof(part) == "Instance" and part:IsA("BasePart") and part.Parent then
			voxels[part] = smoke
		end
	end

	return voxels
end)

local function readScopedIn(vm: any): boolean
	local item = rawget(vm, "ClientItem")
	local info = item and item.Info
	local scopePercent = info and info.AimScopePercent
	if scopePercent == nil then
		return true
	end
	local aimSpring = rawget(vm, "_aim_spring")
	return aimSpring ~= nil and aimSpring.Value >= scopePercent
end

local isScopedIn = LPH_NO_VIRTUALIZE(function(): boolean
	if peek(ignoreCrossbow) then
		local equipped = peek(ClientState.currentEquipped)
		if equipped and equipped.Name == "Crossbow" then
			return true
		end
	end
	local vm = peek(viewmodelState._viewmodel)
	if type(vm) ~= "table" then
		return false
	end
	return readScopedIn(vm)
end)

local gameRaycast = LPH_NO_VIRTUALIZE(function(origin: Vector3, target: Vector3, _ignore: { Instance }): RaycastResult?
	local direction = target - origin
	raycastParams.FilterDescendantsInstances = mapWhitelist.get()
	return workspace:Raycast(origin, direction, raycastParams)
end)

local function setupScopes(): ()
	Registry.Rescan()
	local weapons = Registry.Weapons
	local groups: { string } = {}
	local groupSet: { [string]: true } = {}
	for _, entry in next, weapons do
		local group = entry.class
		if not groupSet[group] then
			groupSet[group] = true
			groups[#groups + 1] = group
		end
	end
	for _, group in next, groups do
		ScopeController.RegisterGroup(group:lower(), group)
	end
	for name, entry in next, weapons do
		ScopeController.RegisterWeapon(name:lower(), name, entry.class:lower())
	end
end

local Legitbot = {}

function Legitbot.new(
	link: gameUi.Linker,
	opts: {
		targettingLink: gameUi.Linker,
		aimLink: gameUi.Linker,
		triggerLink: gameUi.Linker,
		rcsLink: gameUi.Linker,
		visualsLink: gameUi.Linker,
		bulletRedirectionLink: gameUi.Linker,
	}
): UniversalLegitbot.Legitbot
	local game: UniversalLegitbot.GameOpts = {
		getLocalAlive = function(): boolean
			return peek(ClientState.alive)
		end,
		getLocalTeam = function(): string?
			return peek(ClientState.team)
		end,
		getEquippedWeapon = function(): any?
			return peek(ClientState.currentEquipped)
		end,
		canShoot = function(_weapon: any): boolean
			return WeaponController.CanShoot()
		end,
		canFire = function(_weapon: any): boolean
			return WeaponController.CanFire()
		end,
		getLocalReloading = function(): boolean
			return peek(WeaponController.reloading)
		end,
		getLocalOutOfAmmo = function(): boolean
			return peek(WeaponController.maxAmmo) > 0 and peek(WeaponController.ammo) <= 0
		end,
		getLocalOnCooldown = function(): boolean
			if peek(WeaponController.reloading) then
				return false
			end
			if peek(WeaponController.maxAmmo) > 0 and peek(WeaponController.ammo) <= 0 then
				return false
			end
			return peek(WeaponController.isBusy)
		end,
		getTargetingDisabled = function(): boolean
			return not WeaponController.IsGun()
		end,
		getFlashVisibility = flashVisibility.sample,
		isScopedIn = isScopedIn,
		getChargePercent = chargeReader.sample,
		getExtraTargets = botSource.GetAll,
		getSmokeVoxels = getSmokeVoxels,
		lengthThroughSmoke = smokeRay.lengthThroughSmoke,

		getBacktrackPosition = Backtrack.GetHistoricalPosition,
		getBacktrackFolder = Backtrack.GetFolder,

		setBulletRedirectionActive = bulletRedirection.setActive,
		setBulletRedirectionTarget = bulletRedirection.setTarget,
		setBulletRedirectionChance = bulletRedirection.setChance,

		setupScopes = setupScopes,
		subscribeWeaponChange = function(cb: (weapon: any?) -> ()): (() -> ())?
			cb(peek(ClientState.currentEquipped))
			return sub(ClientState.currentEquipped, cb)
		end,

		gameRaycast = gameRaycast,
		fire = function(_weapon: any): ()
			if chargeReader.sample() ~= nil then
				WeaponController.ReleaseCharge()
			else
				WeaponController.Fire()
			end
		end,
		stopFire = WeaponController.StopFire,

		isPlayerBlocking = LPH_NO_VIRTUALIZE(function(player: any): boolean
			if not player then
				return false
			end
			local check = peek(skipBlocking)
			return isPlayerCovered(player, check, check)
		end),

		isPlayerTriggerBlocked = LPH_NO_VIRTUALIZE(function(player: any): boolean
			if not player then
				return false
			end
			local check = peek(trgBlocking)
			return isPlayerCovered(player, check, check)
		end),

		uiOpts = {
			targettingConditions = {
				"While Reloading",
				"While Out Of Ammo",
				"While On Cooldown",
				"Target Not Blocking",
				"Through Smokes",
				"While Blind",
				"Wait For Scope",
			},
			defaultTargettingConditions = { "While On Cooldown", "Target Not Blocking", "Wait For Scope" },
			showBlindThreshold = true,
			showSmokeThreshold = true,
			showAutowall = false,
			showRcs = false,
			showTrigger = true,
			showTriggerWaitForScope = true,
			showTriggerWaitForScopeIgnoreCrossbow = true,
			showTriggerWaitForCharge = true,
			showHitChance = false,
			showMinDamage = false,
			showAimFirstBulletDelay = false,
			showTriggerFirstBulletDelay = false,
			showBulletRedirection = true,
			showManipulation = true,
			extraTriggerFilters = function(filtersLink: gameUi.Linker): ()
				filtersLink:Toggle("notBlocking", "Target Not Blocking", true):SetTip({
					title = "Target Not Blocking",
					body = "Holds fire while the target is protected from your side, by blocking with their weapon or by a riot shield. A held shield covers the front, a stowed shield covers the back.",
				})
			end,
		},
	}

	local legitbot = UniversalLegitbot.new(link, {
		targettingLink = opts.targettingLink,
		aimLink = opts.aimLink,
		triggerLink = opts.triggerLink,
		rcsLink = opts.rcsLink,
		visualsLink = opts.visualsLink,
		bulletRedirectionLink = opts.bulletRedirectionLink,
		game = game,
	})

	legitbot:Track(ScopeController.OnChange("targetting.conditions", function(v: any): ()
		skipBlocking(type(v) == "table" and table.find(v, "Target Not Blocking") ~= nil)
	end))

	legitbot:Track(ScopeController.OnChange("trigger.filters.notBlocking", function(v: any): ()
		trgBlocking(v == true)
	end))

	legitbot:Track(ScopeController.OnChange("trigger.filters.waitForScope.opts.ignoreCrossbow", function(v: any): ()
		ignoreCrossbow(v == true)
	end))

	legitbot:Track(ScopeController.OnChange("bulletRedirection.manipulation", function(v: any): ()
		bulletRedirection.setManipulationActive(v == true)
	end))

	local envFilterId = legitbotApi.AddTargetFilter(LPH_NO_VIRTUALIZE(function(player: Player): boolean
		local localEnv = peek(ClientState.environmentId)
		if localEnv == "" then
			return false
		end
		local basePlayer = PlayerController.Get(player)
		if not basePlayer then
			return false
		end
		local playerEnv = peek((basePlayer :: any).environmentId)
		return playerEnv ~= "" and playerEnv == localEnv
	end))
	legitbot:Track(function(): ()
		legitbotApi.RemoveTargetFilter(envFilterId)
	end)

	return legitbot
end

export type Legitbot = UniversalLegitbot.Legitbot

return Legitbot
