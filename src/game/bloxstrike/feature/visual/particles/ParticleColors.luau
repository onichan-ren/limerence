local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local UniversalParticleColors = require("@game/universal/feature/visual/particles/ParticleColors")
local gameUi = require("@game/gameUi")

local SYSTEMS: { UniversalParticleColors.System } = {
	{
		key = "explosion",
		label = "HE Explosion",
		watch = true,
		matchNames = { ["HE Grenade"] = true },
		color = Color3.fromRGB(255, 150, 60),
		particles = true,
		lighting = true,
	},
	{
		key = "flashbang",
		label = "Flashbang",
		watch = true,
		matchNames = { Flashbang = true },
		color = Color3.fromRGB(255, 255, 255),
		particles = true,
		lighting = true,
	},
	{
		key = "smoke",
		label = "Smoke",
		watch = true,
		matchNames = { SmokeVoxel = true },
		color = Color3.fromRGB(200, 200, 200),
		particles = true,
		parts = true,
	},
	{
		key = "fire",
		label = "Fire",
		watch = true,
		matchNames = { InnerFireVoxel = true, OuterFireVoxel = true },
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
		watchRoot = function(): Instance?
			return Workspace:FindFirstChild("Debris") or Workspace
		end,
	})
end

return ParticleColors
