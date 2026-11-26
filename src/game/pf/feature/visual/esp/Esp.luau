local Charm = require("@pkg/Charm")
local UniversalEsp = require("@game/universal/feature/visual/esp/Esp")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/pf/module/ModuleController")
local Flags = require("@game/universal/feature/visual/esp/element/Flags")
local WeaponText = require("@game/pf/feature/visual/esp/element/WeaponText")
local AmmoBar = require("@game/pf/feature/visual/esp/element/AmmoBar")
local AmmoText = require("@game/pf/feature/visual/esp/element/AmmoText")
local previewFake = require("@game/pf/feature/visual/esp/previewFake")

local STANCE_MAP = { Standing = "stand", Crouch = "crouch", Prone = "prone" }

local function buildPreviewControls(): { any }
	return {
		{
			type = "Dropdown",
			key = "weapon",
			label = "Weapon",
			options = previewFake.WEAPON_SLOTS,
			default = previewFake.WEAPON_SLOTS[1],
			atomKey = "weapon",
			map = previewFake.resolveLoadoutWeapon,
		},
		{
			type = "Dropdown",
			key = "state",
			label = "State",
			options = { "Standing", "Crouch", "Prone" },
			default = "Standing",
			atomKey = "stance",
			map = function(value: any): any
				return STANCE_MAP[value] or "stand"
			end,
		},
		{
			type = "Toggle",
			key = "aiming",
			label = "Aiming",
			default = false,
			atomKey = "aiming",
		},
		{
			type = "Toggle",
			key = "spotted",
			label = "Spotted",
			default = false,
			atomKey = "spotted",
		},
		{
			type = "Dropdown",
			key = "team",
			label = "Team",
			options = previewFake.TEAM_OPTIONS,
			default = previewFake.DEFAULT_TEAM,
			atomKey = "isEnemy",
			map = previewFake.isEnemyForTeam,
		},
	}
end

local peek = Charm.peek
local sub = Charm.subscribe

Flags.Configure({
	{
		id = "crouching",
		menuLabel = "Crouching",
		badgeLabel = "CROUCH",
		default = true,
		color = Color3.fromRGB(235, 200, 120),
		atomKeys = { "stance" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == "crouch"
		end,
	},
	{
		id = "prone",
		menuLabel = "Prone",
		badgeLabel = "PRONE",
		default = true,
		color = Color3.fromRGB(235, 165, 110),
		atomKeys = { "stance" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == "prone"
		end,
	},
	{
		id = "aiming",
		menuLabel = "Aiming",
		badgeLabel = "AIM",
		default = false,
		color = Color3.fromRGB(220, 120, 120),
		atomKeys = { "aiming" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
	{
		id = "sprinting",
		menuLabel = "Sprinting",
		badgeLabel = "SPRINT",
		default = false,
		color = Color3.fromRGB(150, 205, 150),
		atomKeys = { "sprinting" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
	{
		id = "reloading",
		menuLabel = "Reloading",
		badgeLabel = "RELOAD",
		default = true,
		color = Color3.fromRGB(230, 190, 110),
		atomKeys = { "isReloading" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
	{
		id = "spotted",
		menuLabel = "Spotted",
		badgeLabel = "SPOT",
		default = true,
		color = Color3.fromRGB(240, 150, 70),
		atomKeys = { "spotted" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
})

local Esp = {}

function Esp.new(link: gameUi.Linker, mountOpts: { previewLink: gameUi.Linker? }?): UniversalEsp.Esp
	local cache = {
		teamCheck = true,
		onlySpotted = false,
		inGame = true,
		ammoBarEnabled = false,
		ammoBarThickness = 2,
		ammoTextEnabled = false,
	}

	local roundSystem = ModuleController.GetModule("RoundSystemClientInterface")
	local refreshInGame = function(): ()
		if not roundSystem then
			return
		end
		cache.inGame = roundSystem.getMatchData() ~= nil
	end
	refreshInGame()

	local opts: UniversalEsp.EspOpts = {
		extraElements = { Flags, WeaponText, AmmoBar, AmmoText },
		extraBoxLayoutIds = {
			flags = true,
			weaponText = true,
			ammoBar = true,
			ammoText = true,
		},
		prepareCtx = LPH_NO_VIRTUALIZE(function(ctx, entry, elementActive, _settings)
			local ammoState = entry.ammoBar
			local ammoAtom = ammoState and ammoState.basePlayer and ammoState.basePlayer.ammo
			local capacityAtom = ammoState and ammoState.basePlayer and ammoState.basePlayer.ammoCapacity
			local hasAmmo = ammoAtom and capacityAtom and peek(ammoAtom) ~= nil and (peek(capacityAtom) or 0) > 0
			local barBelow = 0
			local textBelow = 0
			if hasAmmo then
				if elementActive.ammoBar and cache.ammoBarEnabled then
					barBelow = cache.ammoBarThickness + 2
				end
				if elementActive.ammoText and cache.ammoTextEnabled then
					textBelow = 12
				end
			end
			ctx.extra.ammoBarExtraBelow = barBelow
			ctx.extra.ammoTextExtraBelow = textBelow
		end),
		elementOpts = {
			adornChams = {
				sizes = {
					Head = Vector3.new(1.6, 1.6, 1.6),
					Torso = Vector3.new(2, 2.8, 1.2),
					["Left Arm"] = Vector3.new(1, 2.8, 1),
					["Right Arm"] = Vector3.new(1, 2.8, 1),
					["Left Leg"] = Vector3.new(1, 2.8, 1),
					["Right Leg"] = Vector3.new(1, 2.8, 1),
				},
			},
		},
		filter = LPH_NO_VIRTUALIZE(function(basePlayer: any): boolean
			if not cache.inGame then
				return true
			end
			if cache.onlySpotted and peek(basePlayer.spotted) ~= true then
				return true
			end
			if not cache.teamCheck then
				return false
			end
			return peek(basePlayer.isEnemy) ~= true
		end),
		previewLink = mountOpts and mountOpts.previewLink,
		previewAtoms = {
			ammo = 18,
			ammoCapacity = 30,
			isReloading = false,
			spotted = false,
		},
		previewControls = buildPreviewControls(),
		previewModelProvider = previewFake.modelProvider,
		previewOnFrame = previewFake.onFrame,
		previewOnDestroy = previewFake.onDestroy,
		previewResolveHrp = previewFake.resolveHrp,
		previewResolveParts = previewFake.resolveParts,
		previewManagedModel = true,
		previewDespawnOnHide = true,
		previewCameraDistanceScale = 1.7,
		offset = Vector2.new(0, -0.3),
	}

	local instance = UniversalEsp.new(link, opts)

	local settings = (instance :: any)._settings
	local ammoBarSettings = settings.ammoBar
	local ammoTextSettings = settings.ammoText
	cache.ammoBarEnabled = peek(ammoBarSettings.enabled._state)
	cache.ammoBarThickness = ammoBarSettings.cache.thickness
	cache.ammoTextEnabled = peek(ammoTextSettings.enabled._state)
	instance:Track(sub(ammoBarSettings.enabled._state, function(v: boolean): ()
		cache.ammoBarEnabled = v
	end))
	instance:Track(sub(ammoBarSettings.thickness._state, function(v: number): ()
		cache.ammoBarThickness = v
	end))
	instance:Track(sub(ammoTextSettings.enabled._state, function(v: boolean): ()
		cache.ammoTextEnabled = v
	end))

	local roundEvents = ModuleController.GetModule("RoundSystemClientEvents")
	if roundEvents then
		local onChanged = function(): ()
			refreshInGame()
		end
		for _, eventName in next, { "onMatchChanged", "onRoundStarted", "onRoundEnded", "onRoundClose" } do
			local event = roundEvents[eventName]
			if event and type(event) == "table" then
				local conn = event:connect(onChanged)
				instance:Track(function(): ()
					conn:disconnect()
				end)
			end
		end
	end

	local animLink = link:OnKey("enabled"):OnKey("animations")
	animLink:Toggle("onlySpotted", "Only Spotted", false):SetTip({
		title = "Only Spotted",
		body = "Only shows players that are spotted.",
	})
	local onlySpottedEl = link:Get("enabled.animations.onlySpotted")
	cache.onlySpotted = peek(onlySpottedEl._state) == true
	instance:Track(sub(onlySpottedEl._state, function(v: boolean): ()
		cache.onlySpotted = v
	end))
	animLink:Toggle("teamCheck", "Team Check", true):SetTip({
		title = "Team Check",
		body = "Hides players on your team.",
	})
	local teamEl = link:Get("enabled.animations.teamCheck")
	cache.teamCheck = peek(teamEl._state) == true
	instance:Track(sub(teamEl._state, function(v: boolean): ()
		cache.teamCheck = v
	end))

	return instance
end

return Esp
