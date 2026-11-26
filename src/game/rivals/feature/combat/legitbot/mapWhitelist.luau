local Players = cloneref(game:GetService("Players")) :: Players
local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService

local LocalPlayer = Players.LocalPlayer

local REFRESH_INTERVAL = 1

local cachedWhitelist: { Instance } = {}
local lastFetch = -math.huge
local lastEnvId: any = nil

local mapWhitelist = {}

mapWhitelist.get = LPH_NO_VIRTUALIZE(function(): { Instance }
	local now = os.clock()
	local envId = LocalPlayer:GetAttribute("EnvironmentID")
	if envId ~= lastEnvId or now - lastFetch > REFRESH_INTERVAL then
		lastFetch = now
		lastEnvId = envId
		cachedWhitelist = CollectionService:GetTagged("RaycastWhitelist" .. (envId or ""))
	end
	return cachedWhitelist
end)

return mapWhitelist
