local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local Charm = require("@pkg/Charm")
local logger = require("@share/logger").new("rankCharms")
local rivalsInventoryState = require("@game/rivals/feature/inventory/rivalsInventoryState")

local peek = Charm.peek

export type CosmeticEntry = {
	name: string,
	displayName: string,
	type: string,
	rarity: string,
	rarityValue: number,
	rarityColor: Color3,
	image: string,
	imageScale: number,
	weapon: string?,
	hidden: boolean,
	description: string?,
	isRankCharm: boolean?,
	isArchnemesis: boolean?,
}

export type RankCharmDef = {
	charmName: string,
	elo: number,
	leaderboardRank: number?,
}

local rankCharms = {
	_built = false,
	_entries = {} :: { CosmeticEntry },
	_defs = {} :: { [string]: { elo: number, isArchnemesis: boolean } },
	_seasons = {} :: { number },
	_latestSeason = nil :: number?,
}

local requireModule = LPH_NO_VIRTUALIZE(function(name: string): any?
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local mod = modules and modules:FindFirstChild(name)
	if not mod then
		return nil
	end
	setthreadidentity(2)
	local value = require(mod)
	setthreadidentity(8)
	if type(value) ~= "table" then
		return nil
	end
	return value
end)

local collectSeasons = LPH_NO_VIRTUALIZE(function(cosmeticLibrary: any): { number }
	local out: { number } = {}
	if type(cosmeticLibrary) ~= "table" or type(cosmeticLibrary.Cosmetics) ~= "table" then
		return out
	end
	for name, info in next, cosmeticLibrary.Cosmetics do
		if type(name) ~= "string" or type(info) ~= "table" or info.Type ~= "Charm" then
			continue
		end
		local num = string.match(name, "^Season (%d+)$")
		local value = num and tonumber(num) or nil
		if value then
			out[#out + 1] = value
		end
	end
	table.sort(out)
	return out
end)

local resolveRankProfile = LPH_NO_VIRTUALIZE(function(seasonLibrary: any, seasonNum: number?): any?
	local profile: any = nil
	if seasonNum then
		local byVersion = seasonLibrary.SeasonsByVersion
		local seasonName = byVersion and byVersion[seasonNum] and byVersion[seasonNum].Name
		profile = seasonName and seasonLibrary.Seasons[seasonName].RankProfile
	end
	if type(profile) ~= "table" or type(profile.RanksOrder) ~= "table" then
		profile = seasonLibrary.RankProfiles and seasonLibrary.RankProfiles.ranks_version1
	end
	if type(profile) == "table" and type(profile.RanksOrder) == "table" then
		return profile
	end
	return nil
end)

local function build(): ()
	if rankCharms._built then
		return
	end
	rankCharms._built = true

	local cosmeticLibrary = requireModule("CosmeticLibrary")
	local seasonLibrary = requireModule("SeasonLibrary")
	if not cosmeticLibrary or not seasonLibrary then
		logger:warn("missing CosmeticLibrary/SeasonLibrary")
		return
	end

	local seasons = collectSeasons(cosmeticLibrary)
	if #seasons == 0 then
		logger:warn("no Season charm found")
		return
	end
	rankCharms._seasons = seasons
	rankCharms._latestSeason = seasons[#seasons]

	local profile = resolveRankProfile(seasonLibrary, rankCharms._latestSeason)
	if not profile then
		logger:warn("no rank profile found")
		return
	end

	local baseInfo = cosmeticLibrary.Cosmetics["Season " .. rankCharms._latestSeason]
	local rarity = type(baseInfo) == "table" and type(baseInfo.Rarity) == "string" and baseInfo.Rarity or "Unique"
	local rarityInfo = cosmeticLibrary.Rarities and cosmeticLibrary.Rarities[rarity]
	local rarityValue = rarityInfo and type(rarityInfo.Value) == "number" and rarityInfo.Value or 0
	local rarityColor = rarityInfo and typeof(rarityInfo.Color) == "Color3" and rarityInfo.Color or Color3.new(1, 1, 1)

	for _, displayName in next, profile.RanksOrder do
		if type(displayName) ~= "string" or displayName == "Unranked" then
			continue
		end
		local rank = profile.Ranks[displayName]
		if type(rank) ~= "table" or type(rank.RequiredELO) ~= "number" then
			continue
		end
		local isArchnemesis = rank.RequiredELOLeaderboardRanking ~= nil
		rankCharms._defs[displayName] = {
			elo = rank.RequiredELO,
			isArchnemesis = isArchnemesis,
		}
		rankCharms._entries[#rankCharms._entries + 1] = {
			name = displayName,
			displayName = displayName,
			type = "Charm",
			rarity = rarity,
			rarityValue = rarityValue,
			rarityColor = rarityColor,
			image = type(rank.Image) == "string" and rank.Image or "",
			imageScale = 1,
			weapon = nil,
			hidden = false,
			description = "Rank charm — " .. displayName,
			isRankCharm = true,
			isArchnemesis = isArchnemesis,
		}
	end
end

function rankCharms.listEntries(): { CosmeticEntry }
	build()
	return rankCharms._entries
end

function rankCharms.getSeasons(): { number }
	build()
	return rankCharms._seasons
end

function rankCharms.getLatestSeason(): number?
	build()
	return rankCharms._latestSeason
end

rankCharms.getSelectedSeason = LPH_NO_VIRTUALIZE(function(name: string): number?
	build()
	local map = peek(rivalsInventoryState.rankCharmSeasons)
	local selected = type(map) == "table" and map[name] or nil
	if type(selected) == "number" then
		return selected
	end
	return rankCharms._latestSeason
end)

rankCharms.resolve = LPH_NO_VIRTUALIZE(function(name: string): RankCharmDef?
	build()
	local def = rankCharms._defs[name]
	if not def then
		return nil
	end
	local season = rankCharms.getSelectedSeason(name)
	if not season then
		return nil
	end
	local leaderboardRank: number? = nil
	if def.isArchnemesis then
		local archRank = peek(rivalsInventoryState.rankCharmArchRank)
		leaderboardRank = (type(archRank) == "number" and math.clamp(math.floor(archRank), 1, 200) or 1)
	end
	return {
		charmName = "Season " .. season,
		elo = def.elo,
		leaderboardRank = leaderboardRank,
	}
end)

return rankCharms
