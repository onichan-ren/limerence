local Charm = require("@pkg/Charm")
local UniversalEsp = require("@game/universal/feature/visual/esp/Esp")
local ClientState = require("@game/overkill/client/clientState")
local botSource = require("@game/overkill/feature/training/botSource")
local gameUi = require("@game/gameUi")
local Flags = require("@game/universal/feature/visual/esp/element/Flags")
local AmmoBar = require("@game/overkill/feature/visual/esp/element/AmmoBar")
local AmmoText = require("@game/overkill/feature/visual/esp/element/AmmoText")
local WeaponText = require("@game/overkill/feature/visual/esp/element/WeaponText")

local peek = Charm.peek

Flags.Configure({
	{
		id = "scoped",
		menuLabel = "Scoped",
		badgeLabel = "SCOPED",
		default = false,
		color = Color3.fromRGB(150, 200, 235),
		atomKeys = { "scoped" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
	{
		id = "deflecting",
		menuLabel = "Deflecting",
		badgeLabel = "DEFLECT",
		default = true,
		color = Color3.fromRGB(235, 200, 120),
		atomKeys = { "deflecting" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
	{
		id = "tased",
		menuLabel = "Tased",
		badgeLabel = "TASED",
		default = true,
		color = Color3.fromRGB(120, 200, 235),
		atomKeys = { "tased" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
})

local Esp = {}

local function prepareCtx(ctx: any, _entry: any, _elementActive: any, _settings: any): ()
	ctx.extra.overkillAmmoBarBelow = 0
	ctx.extra.overkillAmmoTextBelow = 0
end

local PREVIEW_ATOMS = {
	weaponName = "Handgun",
	ammo = 15,
	ammoReserve = 80,
	magSize = 15,
}

function Esp.new(link: gameUi.Linker, mountOpts: { previewLink: gameUi.Linker? }?): UniversalEsp.Esp
	local opts: UniversalEsp.EspOpts = {
		filter = LPH_NO_VIRTUALIZE(function(basePlayer: any): boolean
			if basePlayer.isBot then
				return peek(ClientState.matchId) ~= nil and not peek(ClientState.inRange)
			end
			local localMatch = peek(ClientState.matchId)
			if localMatch == nil then
				return true
			end
			if peek(basePlayer.matchId) ~= localMatch then
				return true
			end
			local localTeam = peek(ClientState.team)
			return localTeam ~= "" and peek(basePlayer.team) == localTeam
		end),
		filterBots = true,
		prepareCtx = prepareCtx,
		targetSource = botSource,
		extraElements = { Flags, AmmoBar, AmmoText, WeaponText },
		extraBoxLayoutIds = {
			flags = true,
			ammoBar = true,
			ammoText = true,
			weaponText = true,
		},
		previewLink = mountOpts and mountOpts.previewLink,
		previewAtoms = PREVIEW_ATOMS,
	}

	return UniversalEsp.new(link, opts)
end

return Esp
