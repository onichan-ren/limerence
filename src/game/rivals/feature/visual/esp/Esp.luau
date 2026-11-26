local Charm = require("@pkg/Charm")
local UniversalEsp = require("@game/universal/feature/visual/esp/Esp")
local VisibleChams = require("@game/universal/feature/visual/esp/element/VisibleChams")
local MatchState = require("@game/rivals/client/matchState")
local clientApi = require("@game/rivals/client/clientApi")
local clientState = require("@game/rivals/client/clientState")
local spectateState = require("@game/rivals/client/spectateState")
local gameUi = require("@game/gameUi")

local Flags = require("@game/universal/feature/visual/esp/element/Flags")
local WeaponText = require("@game/rivals/feature/visual/esp/element/WeaponText")
local botSource = require("@game/rivals/feature/training/botSource")

local peek = Charm.peek

Flags.Configure({
	{
		id = "winstreak",
		menuLabel = "Win Streak",
		badgeLabel = "WS",
		default = false,
		color = Color3.fromRGB(235, 200, 120),
		atomKeys = { "winStreak" },
		compute = function(v: { any }): (boolean, string?)
			return true, `{v[1]} WS`
		end,
	},
	{
		id = "level",
		menuLabel = "Level",
		badgeLabel = "LVL",
		default = false,
		color = Color3.fromRGB(150, 205, 150),
		atomKeys = { "level" },
		compute = function(v: { any }): (boolean, string?)
			return true, `LVL {v[1]}`
		end,
	},
	{
		id = "rank",
		menuLabel = "Rank",
		badgeLabel = "R",
		default = false,
		color = Color3.fromRGB(152, 188, 255),
		atomKeys = { "displayElo" },
		compute = function(v: { any }): (boolean, string?)
			return true, `R {v[1]}`
		end,
	},
	{
		id = "deflecting",
		menuLabel = "Deflecting",
		badgeLabel = "DEFLECT",
		default = true,
		color = Color3.fromRGB(120, 175, 200),
		atomKeys = { "isDeflecting" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
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
	{
		id = "crouching",
		menuLabel = "Crouching",
		badgeLabel = "CROUCH",
		default = true,
		color = Color3.fromRGB(168, 168, 168),
		atomKeys = { "isCrouching" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
	{
		id = "frozen",
		menuLabel = "Frozen",
		badgeLabel = "FROZEN",
		default = true,
		color = Color3.fromRGB(120, 175, 220),
		atomKeys = { "isFrozen" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
})

VisibleChams.Configure({
	isSpectating = clientApi.IsSpectating,
	spectatePlayer = spectateState.player,
	spectateInstance = spectateState.instance,
	isSpectatingAtom = clientState.isSpectating,
	excludedAncestors = {
		WeaponModel = true,
		WeaponAttachments = true,
	},
})

local Esp = {}

function Esp.new(link: gameUi.Linker, mountOpts: { previewLink: gameUi.Linker? }?): UniversalEsp.Esp
	local lobbyEspLink: any = nil

	local opts: UniversalEsp.EspOpts = {
		extraElements = { Flags, WeaponText },
		extraBoxLayoutIds = {
			weaponText = true,
			flags = true,
		},
		filter = LPH_NO_VIRTUALIZE(function(basePlayer: any): boolean
			if not peek(MatchState.inGame) then
				return not (lobbyEspLink ~= nil and peek(lobbyEspLink._state) == true)
			end

			local localEnv = peek(MatchState.environmentId)
			if localEnv ~= "" then
				local playerEnv = peek(basePlayer.environmentId)
				if playerEnv == "" or playerEnv ~= localEnv then
					return true
				end
			end
			local localTeam = peek(MatchState.teamId)
			if localTeam ~= "" and peek(basePlayer.team) == localTeam then
				return true
			end
			return false
		end),
		targetSource = botSource,
		previewLink = mountOpts and mountOpts.previewLink,
		previewAtoms = {
			currentEquipped = { Name = "Revolver" },
			winStreak = 12,
			level = 80,
			displayElo = 2400,
			isHealing = true,
			isReloading = true,
		},
	}

	local esp = UniversalEsp.new(link, opts)

	link:OnKey("enabled"):OnKey("animations"):Toggle("lobbyEsp", "Lobby ESP", false):SetTip({
		title = "Lobby ESP",
		body = "Show ESP on players while in the lobby (when you are not in a game).",
	})
	lobbyEspLink = link:Get("enabled.animations.lobbyEsp")

	return esp
end

return Esp
