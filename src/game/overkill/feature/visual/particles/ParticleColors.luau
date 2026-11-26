local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local UniversalParticleColors = require("@game/universal/feature/visual/particles/ParticleColors")
local gameUi = require("@game/gameUi")

local SYSTEMS: { UniversalParticleColors.System } = {
	{
		key = "explosion",
		label = "Explosion",
		watch = true,
		matchNames = { Explosion = true, RocketExplosion = true, RayExplosion = true },
		color = Color3.fromRGB(255, 150, 60),
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
			local world = Workspace:FindFirstChild("World")
			return world and world:FindFirstChild("FX") or Workspace
		end,
	})
end

return ParticleColors
