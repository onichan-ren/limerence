local UniversalEsp = require("@game/universal/feature/visual/esp/Esp")
local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")
local ragebotState = require("@game/ar2/feature/ragebot/ragebotState")

local Flags = require("@game/universal/feature/visual/esp/element/Flags")
local WeaponText = require("@game/ar2/feature/visuals/esp/element/WeaponText")
local AmmoBar = require("@game/ar2/feature/visuals/esp/element/AmmoBar")
local AmmoText = require("@game/ar2/feature/visuals/esp/element/AmmoText")

local peek = Charm.peek
local sub = Charm.subscribe

Flags.Configure({
	{
		id = "healing",
		menuLabel = "Healing",
		badgeLabel = "HEAL",
		default = true,
		color = Color3.fromRGB(135, 215, 150),
		atomKeys = { "isHealing" },
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
})

local Esp = {}

function Esp.new(link: gameUi.Linker, mountOpts: { previewLink: gameUi.Linker? }?): UniversalEsp.Esp
	local cache = {
		ammoBarEnabled = false,
		ammoBarThickness = 2,
		ammoTextEnabled = false,
	}
	local opts: UniversalEsp.EspOpts = {
		extraElements = { Flags, WeaponText, AmmoBar, AmmoText },
		extraBoxLayoutIds = {
			flags = true,
			weaponText = true,
			ammoBar = true,
			ammoText = true,
		},
		elementOpts = {
			flags = { distanceSuffix = "st" },
			offscreenArrow = { distanceSuffix = "st" },
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
		previewLink = mountOpts and mountOpts.previewLink,
		previewAtoms = {
			weapon = "Combat Rifle",
			ammo = 18,
			ammoCapacity = 30,
			ammoExact = true,
			isHealing = true,
			isReloading = true,
		},
	}

	espStateColors.AddTargetSource(ragebotState.currentTarget)

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

	return instance
end

return Esp
