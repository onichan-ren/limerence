local Players = cloneref(game:GetService("Players")) :: Players

local LocalPlayer = Players.LocalPlayer

local SAMPLE_INTERVAL = 1 / 30
local lastSampleAt = 0

local cachedPlayerGui: PlayerGui? = nil
local cachedOverlay: Frame? = nil

local function clearGuiCache(): ()
	cachedPlayerGui = nil
	cachedOverlay = nil
end

local function resolveOverlay(): Frame?
	local playerGui = cachedPlayerGui
	if playerGui and playerGui.Parent then
		local overlay = cachedOverlay
		if overlay and overlay.Parent then
			return overlay
		end
	end

	playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		clearGuiCache()
		return nil
	end

	cachedPlayerGui = playerGui
	local effect = playerGui:FindFirstChild("FlashbangEffect")
	if not effect then
		cachedOverlay = nil
		return nil
	end

	local overlay = effect:FindFirstChild("FlashOverlay") :: Frame?
	if not overlay or overlay.ClassName ~= "Frame" then
		cachedOverlay = nil
		return nil
	end

	cachedOverlay = overlay
	return overlay
end

local flashVisibility = {}

function flashVisibility.sample(): number
	local now = os.clock()
	if now - lastSampleAt < SAMPLE_INTERVAL then
		local overlay = cachedOverlay
		if overlay and overlay.Parent then
			return math.clamp(1 - overlay.BackgroundTransparency, 0, 1)
		end
	end
	lastSampleAt = now

	local overlay = resolveOverlay()
	if not overlay then
		return 1
	end

	return math.clamp(1 - overlay.BackgroundTransparency, 0, 1)
end

function flashVisibility.reset(): ()
	lastSampleAt = 0
	clearGuiCache()
end

return flashVisibility
