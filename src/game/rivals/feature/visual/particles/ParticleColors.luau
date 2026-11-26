local Players = cloneref(game:GetService("Players")) :: Players

local UniversalParticleColors = require("@game/universal/feature/visual/particles/ParticleColors")
local ModuleController = require("@game/rivals/module/ModuleController")
local gameUi = require("@game/gameUi")

local SYSTEMS: { UniversalParticleColors.System } = {
	{
		key = "tripmine",
		label = "Tripmine Explosion",
		staticPath = { "PlayerScripts", "Assets", "Misc", "SubspaceTripmineExplosion" },
		color = Color3.fromRGB(70, 220, 176),
		particles = true,
		lighting = true,
	},
	{
		key = "explosion",
		label = "Explosion",
		staticPath = { "PlayerScripts", "Assets", "Misc", "ExplosionEffect", "Attachment" },
		color = Color3.fromRGB(255, 150, 60),
		particles = true,
		lighting = true,
	},
	{
		key = "smoke",
		label = "Smoke",
		tag = "SmokeCloud",
		module = "SmokeClouds",
		registry = "_smoke_clouds",
		field = "Model",
		color = Color3.fromRGB(200, 200, 200),
		parts = true,
	},
	{
		key = "fire",
		label = "Fire",
		tag = "FireHitbox",
		module = "FireHitboxes",
		registry = "_fire_hitboxes",
		field = "Visual",
		color = Color3.fromRGB(255, 120, 40),
		particles = true,
		lighting = true,
	},
}

local ParticleColors = {}

function ParticleColors.new(link: gameUi.Linker): UniversalParticleColors.ParticleColors
	return UniversalParticleColors.new(link, {
		rootKey = "particleColors",
		rootLabel = "Particle Colors",
		systems = SYSTEMS,
		resolveStaticRoot = function(): Instance?
			return Players.LocalPlayer
		end,
		watchRoot = function(): Instance?
			return Players.LocalPlayer:FindFirstChild("PlayerGui")
		end,
		resolveModule = function(name: string): any
			return ModuleController.GetModule(name)
		end,
	})
end

return ParticleColors
