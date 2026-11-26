local skinIcon = require("@feature/inventory/skinIcon")

local CATEGORY_BY_TYPE: { [string]: string } = {
	Weapon = "weapons",
	Melee = "knives",
	Glove = "skins",
	Grenade = "misc",
	C4 = "misc",
	["Zeus x27"] = "misc",
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

export type UIItem = {
	id: string,
	weapon: string,
	skin: string,
	rarity: string,
	category: string,
	float: number,
	statTrack: number | boolean,
	nameTag: string | boolean,
	icon: string?,
	isFake: boolean,
	raw: any,
}

local skinInfoCache: { [string]: any } = {}

local ModuleController = require("@game/bloxstrike/module/ModuleController")

local function getSkinInfo(weapon: string, skin: string): any?
	local key = weapon .. "|" .. skin
	local cached = skinInfoCache[key]
	if cached ~= nil then
		return cached or nil
	end
	local Skins = ModuleController.GetModule("Skins")
	if not Skins or not Skins.GetSkinInformation then
		skinInfoCache[key] = false
		return nil
	end
	setthreadidentity(2)
	local ok, info = pcall(Skins.GetSkinInformation, weapon, skin)
	setthreadidentity(8)
	if not ok or not info then
		skinInfoCache[key] = false
		return nil
	end
	skinInfoCache[key] = info
	return info
end

local function resolveRarity(rarityName: string?): string
	if not rarityName then
		return "common"
	end
	return RARITY_BY_NAME[rarityName] or "common"
end

local function resolveIcon(weapon: string, skin: string, float: number?): string?
	return skinIcon.resolve(weapon, skin, float)
end

local function adapt(item: any): UIItem?
	if type(item) ~= "table" then
		return nil
	end
	local weapon = item.Name
	local skin = item.Skin or "Stock"
	if type(weapon) ~= "string" then
		return nil
	end
	local isFake = rawget(item, "__limerence") == true
	if not isFake and (skin == "Stock" or skin == "Default" or skin == "") then
		return nil
	end
	local skinInfo = getSkinInfo(weapon, skin)
	local lookupRarity: string? = nil
	if skinInfo and type(skinInfo.rarity) == "string" then
		lookupRarity = RARITY_BY_NAME[skinInfo.rarity]
	end
	local rarity = lookupRarity
		or (item.MetaData and type(item.MetaData.LimerenceRarity) == "string" and item.MetaData.LimerenceRarity)
		or "common"
	local category = CATEGORY_BY_TYPE[item.Type or ""] or "misc"

	return {
		id = item._id,
		weapon = weapon,
		skin = skin,
		rarity = rarity,
		category = category,
		float = item.Float or 0,
		statTrack = item.StatTrack or false,
		nameTag = item.NameTag or false,
		icon = resolveIcon(weapon, skin, item.Float),
		isFake = isFake,
		raw = item,
	}
end

local function adaptAll(items: { any }): { UIItem }
	local out: { UIItem } = {}
	for _, item in next, items do
		local adapted = adapt(item)
		if adapted then
			out[#out + 1] = adapted
		end
	end
	return out
end

return {
	adapt = adapt,
	adaptAll = adaptAll,
	CATEGORY_BY_TYPE = CATEGORY_BY_TYPE,
}
