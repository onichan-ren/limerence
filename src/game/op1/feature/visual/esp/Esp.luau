local UniversalEsp = require("@game/universal/feature/visual/esp/Esp")
local gameUi = require("@game/gameUi")
local AmmoBar = require("@game/op1/feature/visual/esp/element/AmmoBar")
local AmmoText = require("@game/op1/feature/visual/esp/element/AmmoText")
local WeaponIcon = require("@game/op1/feature/visual/esp/element/WeaponIcon")
local WeaponText = require("@game/op1/feature/visual/esp/element/WeaponText")
local Flags = require("@game/universal/feature/visual/esp/element/Flags")

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
		id = "stunned",
		menuLabel = "Stunned",
		badgeLabel = "STUN",
		default = false,
		color = Color3.fromRGB(235, 225, 130),
		atomKeys = { "stunned" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
	{
		id = "planting",
		menuLabel = "Planting",
		badgeLabel = "PLANT",
		default = false,
		color = Color3.fromRGB(235, 160, 90),
		atomKeys = { "planting" },
		compute = function(v: { any }): (boolean, string?)
			return v[1] == true
		end,
	},
})

local Esp = {}

local function prepareCtx(ctx: any, _entry: any, _elementActive: any, _settings: any): ()
	local extra = ctx.extra
	extra.op1AmmoBarBelow = 0
	extra.op1AmmoTextBelow = 0
	extra.op1WeaponIconBelow = 0
end

local function fakeState(value: any): any
	return {
		get = function(): any
			return value
		end,
	}
end

local PREVIEW_ATOMS = {
	object = {
		values = {
			equipped = {
				display_name = "AK-12",
				icon = "rbxassetid://117191587917011",
				states = {
					mag = fakeState(18),
					mag_size = fakeState(30),
					bullets = fakeState(60),
				},
			},
		},
	},
	stance = "stand",
	aiming = false,
	sprinting = false,
	stunned = false,
	planting = false,
}

function Esp.new(link: gameUi.Linker, mountOpts: { previewLink: gameUi.Linker? }?): any
	return UniversalEsp.new(link, {
		filter = function(basePlayer: any): boolean
			return not basePlayer:IsEnemy()
		end,
		offset = Vector2.new(0, -1.5),
		prepareCtx = prepareCtx,
		extraElements = { AmmoBar, AmmoText, WeaponIcon, WeaponText, Flags },
		extraBoxLayoutIds = {
			ammoBar = true,
			ammoText = true,
			weaponIcon = true,
			weaponText = true,
			flags = true,
		},
		previewLink = mountOpts and mountOpts.previewLink,
		previewAtoms = PREVIEW_ATOMS,
	})
end

return Esp
