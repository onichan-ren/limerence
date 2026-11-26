local grenadeState = require("@game/bloxstrike/grenade/grenadeState")
local volumeRenderer = require("@game/universal/feature/visual/grenade/volumeRenderer")

local SMOKE_COLOR = Color3.fromRGB(176, 198, 224)
local SMOKE_GLOW = Color3.fromRGB(126, 168, 220)
local FIRE_COLOR = Color3.fromRGB(232, 146, 72)
local FIRE_GLOW = Color3.fromRGB(236, 108, 44)

local resolveSamples = LPH_JIT_MAX(
	function(entry: any, positions: { Vector3 }, extents: { Vector3 }, limit: number): number
		local voxels = entry.voxels
		if not voxels then
			return 0
		end

		local count = 0
		for i = 1, #voxels do
			if count >= limit then
				break
			end

			local part = voxels[i] :: BasePart
			if part.Parent then
				local px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.CFrame:GetComponents()
				local size = part.Size
				local hx, hy, hz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5

				count += 1
				positions[count] = Vector3.new(px, py, pz)
				extents[count] = Vector3.new(
					math.abs(r00) * hx + math.abs(r01) * hy + math.abs(r02) * hz,
					math.abs(r10) * hx + math.abs(r11) * hy + math.abs(r12) * hz,
					math.abs(r20) * hx + math.abs(r21) * hy + math.abs(r22) * hz
				)
			end
		end

		return count
	end
)

local function resolveTiming(entry: any): (number?, number?)
	local duration = entry.duration
	local startedAt = entry.startedAt
	if not duration or duration <= 0 or not startedAt then
		return nil, nil
	end

	local remaining = duration - (os.clock() - startedAt)
	if remaining < 0 then
		remaining = 0
	end

	return remaining, duration
end

local smoke: volumeRenderer.Adapter = {
	id = "smoke",
	key = "smokeVolumes",
	label = "Smoke Volumes",
	tip = "Outlines every smoke cloud through walls.",
	entries = grenadeState.activeSmokes,
	defaultColor = SMOKE_COLOR,
	defaultGlow = SMOKE_GLOW,
	resolveSamples = resolveSamples,
	resolveTiming = resolveTiming,
}

local fire: volumeRenderer.Adapter = {
	id = "fire",
	key = "fireVolumes",
	label = "Fire Volumes",
	tip = "Outlines burning ground through walls.",
	entries = grenadeState.activeFires,
	defaultColor = FIRE_COLOR,
	defaultGlow = FIRE_GLOW,
	resolveSamples = resolveSamples,
	resolveTiming = resolveTiming,
}

return {
	smoke = smoke,
	fire = fire,
}
