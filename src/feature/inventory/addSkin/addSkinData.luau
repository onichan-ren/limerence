local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local ModuleController = require("@game/bloxstrike/module/ModuleController")
local Registry = require("@game/bloxstrike/registry/Registry")
local skinIcon = require("@feature/inventory/skinIcon")

export type WeaponEntry = {
	name: string,
	group: string,
	icon: string?,
}

export type SkinEntry = {
	weapon: string,
	skin: string,
	rarity: string,
	collection: string?,
	icon: string?,
}

local RARITY_BY_NAME: { [string]: string } = {
	["Stock"] = "common",
	["Blue"] = "uncommon",
	["Purple"] = "restricted",
	["Pink"] = "classified",
	["Red"] = "covert",
	["Special"] = "extraordinary",
	["Forbidden"] = "extraordinary",
	["Consumer Grade"] = "common",
	["Industrial Grade"] = "common",
	["Mil-Spec"] = "uncommon",
	["Mil-Spec Grade"] = "uncommon",
	["Restricted"] = "restricted",
	["Classified"] = "classified",
	["Covert"] = "covert",
	["Extraordinary"] = "extraordinary",
	["Contraband"] = "extraordinary",
	["Master"] = "master",
	["★ Master"] = "master",
}

local GROUP_ORDER: { [string]: number } = {
	Pistol = 1,
	["Heavy Pistol"] = 2,
	SMG = 3,
	Rifle = 4,
	Sniper = 5,
	Shotgun = 6,
	LMG = 7,
	Heavy = 7,
	Knife = 8,
	Melee = 8,
	Glove = 9,
}

local skinListCache: { [string]: { SkinEntry } } = {}

local function resolveWeaponIcon(weapon: string): string?
	return skinIcon.resolveWeaponFallback(weapon)
end

local function getRenderableSkinSet(weapon: string): { [string]: boolean }?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local skins = assets and assets:FindFirstChild("Skins")
	local weaponFolder = skins and skins:FindFirstChild(weapon)
	if not weaponFolder then
		return nil
	end
	local set: { [string]: boolean } = {}
	for _, child in next, weaponFolder:GetChildren() do
		if child:IsA("Folder") then
			set[child.Name] = true
		end
	end
	return set
end

local function resolveRarity(rarityName: string?): string
	if not rarityName then
		return "common"
	end
	return RARITY_BY_NAME[rarityName] or "common"
end

local MOCK_SKINS_FALLBACK: { [string]: { { skin: string, rarity: string, collection: string? } } } = {
	["AK-47"] = {
		{ skin = "Bloodsport", rarity = "covert", collection = "The Spectrum Collection" },
		{ skin = "Vulcan", rarity = "covert", collection = "The Huntsman Collection" },
		{ skin = "Fire Serpent", rarity = "covert", collection = "The Bravo Collection" },
		{ skin = "Neon Rider", rarity = "covert", collection = "The Horizon Collection" },
		{ skin = "Asiimov", rarity = "covert", collection = "The Phoenix Collection" },
		{ skin = "Redline", rarity = "classified", collection = "The Winter Offensive Collection" },
		{ skin = "Frontside Misty", rarity = "classified", collection = "The Glove Collection" },
		{ skin = "Point Disarray", rarity = "classified", collection = "The Revolver Case Collection" },
		{ skin = "Aquamarine Revenge", rarity = "covert", collection = "The Chroma 2 Collection" },
		{ skin = "Wasteland Rebel", rarity = "covert", collection = "The Rising Sun Collection" },
	},
	["M4A1-S"] = {
		{ skin = "Hyper Beast", rarity = "covert", collection = "The Falchion Collection" },
		{ skin = "Cyrex", rarity = "covert", collection = "The Breakout Collection" },
		{ skin = "Printstream", rarity = "covert", collection = "The Snakebite Collection" },
		{ skin = "Decimator", rarity = "classified", collection = "The Spectrum Collection" },
		{ skin = "Player Two", rarity = "covert", collection = "The Prisma 2 Collection" },
		{ skin = "Mecha Industries", rarity = "covert", collection = "The Gamma Collection" },
	},
	["AWP"] = {
		{ skin = "Dragon Lore", rarity = "covert", collection = "The Cobblestone Collection" },
		{ skin = "Asiimov", rarity = "covert", collection = "The Phoenix Collection" },
		{ skin = "Lightning Strike", rarity = "covert", collection = "The Arms Deal Collection" },
		{ skin = "Wildfire", rarity = "covert", collection = "The Wildfire Collection" },
		{ skin = "Neo-Noir", rarity = "covert", collection = "The Spectrum 2 Collection" },
		{ skin = "Hyper Beast", rarity = "covert", collection = "The Falchion Collection" },
	},
	["Desert Eagle"] = {
		{ skin = "Blaze", rarity = "extraordinary", collection = "The Arms Deal Collection" },
		{ skin = "Printstream", rarity = "covert", collection = "The Snakebite Collection" },
		{ skin = "Code Red", rarity = "covert", collection = "The Spectrum 2 Collection" },
		{ skin = "Kumicho Dragon", rarity = "classified", collection = "The Rising Sun Collection" },
		{ skin = "Heirloom", rarity = "covert", collection = "The Vanguard Collection" },
	},
	["Glock-18"] = {
		{ skin = "Fade", rarity = "covert", collection = "The Assault Collection" },
		{ skin = "Water Elemental", rarity = "covert", collection = "The Breakout Collection" },
		{ skin = "Wasteland Rebel", rarity = "classified", collection = "The Rising Sun Collection" },
		{ skin = "Bullet Queen", rarity = "covert", collection = "The Snakebite Collection" },
	},
	["USP-S"] = {
		{ skin = "Kill Confirmed", rarity = "covert", collection = "The Spectrum Collection" },
		{ skin = "Neo-Noir", rarity = "covert", collection = "The Clutch Collection" },
		{ skin = "Printstream", rarity = "covert", collection = "The Dreams & Nightmares Collection" },
		{ skin = "Orion", rarity = "classified", collection = "The Phoenix Collection" },
	},
}

local function getMockSkinsFor(weapon: string): { { skin: string, rarity: string, collection: string? } }
	local exact = MOCK_SKINS_FALLBACK[weapon]
	if exact then
		return exact
	end
	return {
		{ skin = "Stock", rarity = "common", collection = "Default" },
		{ skin = "Forest DDPAT", rarity = "common", collection = "The Vertigo Collection" },
		{ skin = "Urban Hazard", rarity = "uncommon", collection = "The Assault Collection" },
		{ skin = "Brass", rarity = "uncommon", collection = "The Bravo Collection" },
		{ skin = "Cyrex", rarity = "classified", collection = "The Operation Phoenix Collection" },
		{ skin = "Hyper Beast", rarity = "covert", collection = "The Falchion Collection" },
	}
end

local function getWeapons(): { WeaponEntry }
	local out: { WeaponEntry } = {}
	for name, info in next, Registry.All do
		out[#out + 1] = {
			name = name,
			group = info.group,
			icon = resolveWeaponIcon(name),
		}
	end

	table.sort(out, function(a, b): boolean
		local ga = GROUP_ORDER[a.group] or 999
		local gb = GROUP_ORDER[b.group] or 999
		if ga ~= gb then
			return ga < gb
		end
		return a.name < b.name
	end)

	return out
end

local function getSkinsForWeapon(weapon: string): { SkinEntry }
	local cached = skinListCache[weapon]
	if cached then
		return cached
	end

	local out: { SkinEntry } = {}

	local renderable = getRenderableSkinSet(weapon)

	local Skins = ModuleController.GetModule("Skins")
	if Skins and Skins.GetAllSkinsForWeapon then
		setthreadidentity(2)
		local ok, list = pcall(Skins.GetAllSkinsForWeapon, weapon)
		setthreadidentity(8)
		if ok and type(list) == "table" then
			for _, entry in next, list do
				local skinName = (entry :: any).skin
				if
					type(skinName) == "string"
					and skinName ~= ""
					and skinName ~= "Stock"
					and skinName ~= "Default"
					and (not renderable or renderable[skinName])
				then
					out[#out + 1] = {
						weapon = weapon,
						skin = skinName,
						rarity = resolveRarity((entry :: any).rarity),
						collection = (entry :: any).collection,
						icon = skinIcon.resolve(weapon, skinName, 0.9999),
					}
				end
			end
		end
	end

	if #out == 0 then
		for _, entry in next, getMockSkinsFor(weapon) do
			if entry.skin ~= "Stock" and entry.skin ~= "Default" then
				out[#out + 1] = {
					weapon = weapon,
					skin = entry.skin,
					rarity = entry.rarity,
					collection = entry.collection,
					icon = resolveWeaponIcon(weapon),
				}
			end
		end
	end

	table.sort(out, function(a, b): boolean
		return a.skin < b.skin
	end)

	skinListCache[weapon] = out
	return out
end

return {
	getWeapons = getWeapons,
	getSkinsForWeapon = getSkinsForWeapon,
	resolveWeaponIcon = resolveWeaponIcon,
}
