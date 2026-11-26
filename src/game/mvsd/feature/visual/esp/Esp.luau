local Charm = require("@pkg/Charm")
local UniversalEsp = require("@game/universal/feature/visual/esp/Esp")
local ClientState = require("@game/mvsd/client/clientState")
local gameUi = require("@game/gameUi")
local Flags = require("@game/universal/feature/visual/esp/element/Flags")
local WeaponText = require("@game/mvsd/feature/visual/esp/element/WeaponText")

local peek = Charm.peek
local sub = Charm.subscribe

Flags.Configure({
	{
		id = "reloading",
		menuLabel = "Reloading",
		badgeLabel = "RELOAD",
		default = true,
		color = Color3.fromRGB(235, 200, 120),
		atomKeys = { "isReloading" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
	{
		id = "shrouded",
		menuLabel = "Flashed",
		badgeLabel = "FLASH",
		default = true,
		color = Color3.fromRGB(120, 200, 235),
		atomKeys = { "shrouded" },
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
		id = "invulnerable",
		menuLabel = "Invulnerable",
		badgeLabel = "INVULN",
		default = true,
		color = Color3.fromRGB(120, 175, 220),
		atomKeys = { "invulnerable" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
})

local Esp = {}

function Esp.new(link: gameUi.Linker, mountOpts: { previewLink: gameUi.Linker? }?): UniversalEsp.Esp
	local cache = {
		lobbyEsp = false,
	}

	local opts: UniversalEsp.EspOpts = {
		excludeElements = {
			healthbar = true,
			healthText = true,
		},
		extraElements = { Flags, WeaponText },
		extraBoxLayoutIds = {
			flags = true,
			weaponText = true,
		},
		elementOpts = {
			offscreenArrow = { health = false },
		},
		filter = LPH_NO_VIRTUALIZE(function(basePlayer: any): boolean
			local theirMatch = peek(basePlayer.matchId)
			local localMatch = peek(ClientState.matchId)
			if localMatch ~= nil then
				if theirMatch ~= localMatch then
					return true
				end
				local localTeam = peek(ClientState.team)
				return localTeam ~= "" and peek(basePlayer.team) == localTeam
			end
			local spectateMatch = peek(ClientState.spectateMatchId)
			if spectateMatch ~= nil then
				return theirMatch ~= spectateMatch
			end
			if not cache.lobbyEsp then
				return true
			end
			return theirMatch ~= nil
		end),
		previewLink = mountOpts and mountOpts.previewLink,
		previewAtoms = {
			weapon = "Rifle",
			isReloading = true,
			sprinting = true,
		},
	}

	local instance = UniversalEsp.new(link, opts)

	local animLink = link:OnKey("enabled"):OnKey("animations")
	animLink:Toggle("lobbyEsp", "Lobby ESP", false):SetTip({
		title = "Lobby ESP",
		body = "Shows ESP on other players while you are in the lobby.",
	})
	local lobbyEl = link:Get("enabled.animations.lobbyEsp")
	cache.lobbyEsp = peek(lobbyEl._state) == true
	instance:Track(sub(lobbyEl._state, function(v: boolean): ()
		cache.lobbyEsp = v
	end))

	return instance
end

return Esp
