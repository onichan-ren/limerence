local Charm = require("@pkg/Charm")
local UniversalEsp = require("@game/universal/feature/visual/esp/Esp")
local VisibleChams = require("@game/universal/feature/visual/esp/element/VisibleChams")
local ClientState = require("@game/bloxstrike/client/clientState")
local clientApi = require("@game/bloxstrike/client/clientApi")
local spectateState = require("@game/bloxstrike/client/spectateState")
local gameUi = require("@game/gameUi")
local gamemodeState = require("@game/bloxstrike/gamemodeState")

local Flags = require("@game/universal/feature/visual/esp/element/Flags")
local WeaponText = require("@game/bloxstrike/feature/visual/esp/element/WeaponText")
local WeaponIcon = require("@game/bloxstrike/feature/visual/esp/element/WeaponIcon")
local AmmoBar = require("@game/bloxstrike/feature/visual/esp/element/AmmoBar")
local AmmoText = require("@game/bloxstrike/feature/visual/esp/element/AmmoText")

local peek = Charm.peek
local sub = Charm.subscribe

Flags.Configure({
	{
		id = "defusing",
		menuLabel = "Defusing",
		badgeLabel = "DEFUSING",
		default = true,
		color = Color3.fromRGB(120, 175, 200),
		atomKeys = { "isDefusing" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
	{
		id = "rescuing",
		menuLabel = "Rescuing",
		badgeLabel = "RESCUE",
		default = true,
		color = Color3.fromRGB(120, 200, 145),
		atomKeys = { "isRescuing" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
	{
		id = "carrying",
		menuLabel = "Carrying",
		badgeLabel = "CARRY",
		default = true,
		color = Color3.fromRGB(145, 200, 200),
		atomKeys = { "isCarrying" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
	{
		id = "c4",
		menuLabel = "C4",
		badgeLabel = "C4",
		default = true,
		color = Color3.fromRGB(220, 190, 110),
		atomKeys = { "hasC4", "isPlanting" },
		compute = function(v: { any }): (boolean, string?)
			return (v[1] == true or v[2] == true), v[2] == true and "PLANTING" or "C4"
		end,
	},
	{
		id = "defuseKit",
		menuLabel = "Defuse Kit",
		badgeLabel = "KIT",
		default = true,
		color = Color3.fromRGB(255, 255, 255),
		icon = "rbxassetid://116726858713748",
		priority = 1,
		atomKeys = { "hasDefuseKit" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
	{
		id = "armor",
		menuLabel = "Armor",
		badgeLabel = "K",
		default = true,
		color = Color3.fromRGB(190, 190, 190),
		atomKeys = { "armor" },
		compute = function(v: { any }): (boolean, string?)
			local armor = v[1]
			if type(armor) ~= "table" or not armor.kevlar then
				return false
			end
			return true, armor.helmet and "HK" or "K"
		end,
	},
	{
		id = "reloading",
		menuLabel = "Reloading",
		badgeLabel = "RELOAD",
		default = true,
		color = Color3.fromRGB(220, 190, 110),
		atomKeys = { "isReloading" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
	{
		id = "blind",
		menuLabel = "Blind",
		badgeLabel = "BLIND",
		default = false,
		color = Color3.fromRGB(200, 186, 160),
		atomKeys = { "isBlind" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
	{
		id = "scoped",
		menuLabel = "Scoped",
		badgeLabel = "SCOPED",
		default = false,
		color = Color3.fromRGB(168, 168, 168),
		atomKeys = { "isScoped" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
})

local BELOW_STACK_GAP = 2
local AMMO_TEXT_LINE_HEIGHT = 10

VisibleChams.Configure({
	isSpectating = clientApi.IsSpectating,
	spectatePlayer = spectateState.player,
	spectateInstance = spectateState.instance,
	isSpectatingAtom = ClientState.isSpectating,
	excludedAncestors = {
		WeaponModel = true,
		WeaponAttachments = true,
	},
})

local Esp = {}

function Esp.new(link: gameUi.Linker, mountOpts: { previewLink: gameUi.Linker? }?): UniversalEsp.Esp
	local cache = {
		ammoBarEnabled = false,
		ammoBarThickness = 2,
		ammoTextEnabled = false,
		weaponIconEnabled = false,
		weaponIconSize = 12,
	}

	local opts: UniversalEsp.EspOpts = {
		extraElements = { Flags, WeaponText, WeaponIcon, AmmoBar, AmmoText },
		extraBoxLayoutIds = {
			weaponText = true,
			weaponIcon = true,
			ammoBar = true,
			ammoText = true,
			flags = true,
		},
		filter = LPH_NO_VIRTUALIZE(function(basePlayer: any): boolean
			local localTeam = peek(ClientState.team)
			if localTeam == nil then
				return false
			end
			return peek(basePlayer.team) == localTeam and not gamemodeState.isDeathmatch()
		end),
		prepareCtx = LPH_NO_VIRTUALIZE(function(ctx, entry, elementActive, _settings)
			local ammoState = entry.ammoBar
			local hasAmmo = ammoState and ammoState._showAmmo and ammoState._maxRounds > 0
			local barBelow = 0
			local textBelow = 0
			if hasAmmo then
				if elementActive.ammoBar and cache.ammoBarEnabled then
					barBelow = cache.ammoBarThickness + BELOW_STACK_GAP
				end
				if elementActive.ammoText and cache.ammoTextEnabled then
					textBelow = AMMO_TEXT_LINE_HEIGHT + BELOW_STACK_GAP
				end
			end
			local iconBelow = 0
			local iconState = entry.weaponIcon
			if elementActive.weaponIcon and cache.weaponIconEnabled and iconState and iconState._icon then
				iconBelow = cache.weaponIconSize + BELOW_STACK_GAP
			end
			ctx.extra.ammoBarExtraBelow = barBelow
			ctx.extra.ammoTextExtraBelow = textBelow
			ctx.extra.weaponIconExtraBelow = iconBelow
		end),
		previewLink = mountOpts and mountOpts.previewLink,
		previewAtoms = {
			currentEquipped = { Name = "AK47", Rounds = 18, Capacity = 90 },
			armor = { kevlar = true, helmet = true },
			isReloading = true,
			isScoped = true,
		},
	}

	local instance = UniversalEsp.new(link, opts)
	local settings = (instance :: any)._settings

	local ammoBarSettings = settings.ammoBar
	local ammoTextSettings = settings.ammoText
	local weaponIconSettings = settings.weaponIcon
	cache.ammoBarEnabled = peek(ammoBarSettings.enabled._state)
	cache.ammoBarThickness = ammoBarSettings.cache.thickness
	cache.ammoTextEnabled = peek(ammoTextSettings.enabled._state)
	cache.weaponIconEnabled = peek(weaponIconSettings.enabled._state)
	cache.weaponIconSize = weaponIconSettings.cache.size

	instance:Track(sub(ammoBarSettings.enabled._state, function(v: boolean): ()
		cache.ammoBarEnabled = v
	end))
	instance:Track(sub(ammoBarSettings.thickness._state, function(v: number): ()
		cache.ammoBarThickness = v
	end))
	instance:Track(sub(ammoTextSettings.enabled._state, function(v: boolean): ()
		cache.ammoTextEnabled = v
	end))
	instance:Track(sub(weaponIconSettings.enabled._state, function(v: boolean): ()
		cache.weaponIconEnabled = v
	end))
	instance:Track(sub(weaponIconSettings.size._state, function(v: number): ()
		cache.weaponIconSize = v
	end))

	return instance
end

return Esp
