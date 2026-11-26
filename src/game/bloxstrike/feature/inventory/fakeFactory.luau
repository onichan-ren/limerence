local Players = cloneref(game:GetService("Players")) :: Players
local HttpService = cloneref(game:GetService("HttpService")) :: HttpService

local inventoryGameState = require("@game/bloxstrike/feature/inventory/inventoryGameState")
local inventoryClassifier = require("@game/bloxstrike/feature/inventory/inventoryClassifier")

local LocalPlayer = Players.LocalPlayer

local fakeFactory = {}

local FAKE_PREFIX = "lim_"

export type FakeOptions = {
	skin: string?,
	float: number?,
	statTrack: (number | boolean)?,
	nameTag: (string | boolean)?,
	charm: any?,
	stickers: { any }?,
	seed: number?,
	rarity: string?,
}

local typeCache: { [string]: string } = {}

local function resolveType(weaponName: string): string
	if weaponName == "C4" then
		return "C4"
	end
	if weaponName == "Zeus x27" then
		return "Zeus x27"
	end
	local cached = typeCache[weaponName]
	if cached then
		return cached
	end
	local def = inventoryClassifier.getDefinition(weaponName)
	if not def then
		typeCache[weaponName] = "Weapon"
		return "Weapon"
	end
	local class = def.Class
	local resolved = (
		class == "Melee" and "Melee"
		or class == "Glove" and "Glove"
		or class == "Grenade" and "Grenade"
		or class == "C4" and "C4"
		or "Weapon"
	)
	typeCache[weaponName] = resolved
	return resolved
end

function fakeFactory.isFakeId(id: any): boolean
	if type(id) ~= "string" then
		return false
	end
	return string.sub(id, 1, #FAKE_PREFIX) == FAKE_PREFIX
end

local function normalizeStatTrack(value: any): number | boolean
	if type(value) == "number" and value >= 0 then
		return value
	end
	if value == true then
		return 0
	end
	return false
end

local function normalizeNameTag(value: any): string | boolean
	if type(value) == "string" and value ~= "" then
		return value
	end
	return false
end

function fakeFactory.generate(weaponName: string, options: FakeOptions?): inventoryGameState.FakeItem
	local opts = options or {}
	local id = FAKE_PREFIX .. HttpService:GenerateGUID(false)

	local fake: inventoryGameState.FakeItem = {
		_id = id,
		Name = weaponName,
		Skin = opts.skin or "Stock",
		Type = resolveType(weaponName),
		Float = (type(opts.float) == "number" and math.clamp(opts.float :: number, 0, 1) or 0),
		StatTrack = normalizeStatTrack(opts.statTrack),
		NameTag = normalizeNameTag(opts.nameTag),
		Charm = opts.charm or false,
		Stickers = opts.stickers or {},
		MetaData = {
			LastTradeAt = 0,
			CreatedAt = os.time(),
			OriginalOwner = (LocalPlayer and LocalPlayer.UserId or 0),
			Owner = (LocalPlayer and LocalPlayer.UserId or 0),
			Origin = "Limerence",
			TradeHistory = {},
			LimerenceRarity = opts.rarity,
		},
		__limerence = true,
	}

	return fake
end

return fakeFactory
