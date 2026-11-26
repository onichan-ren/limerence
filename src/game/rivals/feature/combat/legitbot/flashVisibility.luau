local Players = cloneref(game:GetService("Players")) :: Players

local LocalPlayer = Players.LocalPlayer

local SAMPLE_INTERVAL = 1 / 30

local lastSampleAt = 0
local cachedPlayerGui: PlayerGui? = nil
local cachedBackgrounds = {} :: { GuiObject }

local function clearCache(): ()
	cachedPlayerGui = nil
	table.clear(cachedBackgrounds)
end

local function refreshBackgrounds(): ()
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		clearCache()
		return
	end

	cachedPlayerGui = playerGui
	table.clear(cachedBackgrounds)

	for _, child in next, playerGui:GetChildren() do
		if child.Name ~= "FlashbangGui" then
			continue
		end

		local background = child:FindFirstChild("Background", true)
		if background and background:IsA("GuiObject") then
			cachedBackgrounds[#cachedBackgrounds + 1] = background
		end
	end
end

local flashVisibility = {}

flashVisibility.sample = LPH_NO_VIRTUALIZE(function(): number
	local now = os.clock()
	if now - lastSampleAt >= SAMPLE_INTERVAL then
		lastSampleAt = now
		refreshBackgrounds()
	end

	local playerGui = cachedPlayerGui
	if not playerGui or not playerGui.Parent then
		clearCache()
		return 0
	end

	local strongest = 0
	local sawAny = false
	for index = #cachedBackgrounds, 1, -1 do
		local background = cachedBackgrounds[index]
		if not background.Parent then
			table.remove(cachedBackgrounds, index)
			continue
		end
		sawAny = true
		strongest = math.max(strongest, math.clamp(1 - background.BackgroundTransparency, 0, 1))
	end

	if not sawAny and now - lastSampleAt > SAMPLE_INTERVAL * 2 then
		refreshBackgrounds()
		for _, background in next, cachedBackgrounds do
			if background.Parent then
				strongest = math.max(strongest, math.clamp(1 - background.BackgroundTransparency, 0, 1))
				sawAny = true
			end
		end
	end

	return (sawAny and strongest or 0)
end)

function flashVisibility.reset(): ()
	lastSampleAt = 0
	clearCache()
end

return flashVisibility
