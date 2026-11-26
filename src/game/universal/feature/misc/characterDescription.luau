local Players = cloneref(game:GetService("Players")) :: Players
local MarketplaceService = cloneref(game:GetService("MarketplaceService")) :: MarketplaceService

local characterDescription = {}

local NUMBER_PROPS: { string } = {
	"Face",
	"Head",
	"Torso",
	"LeftArm",
	"RightArm",
	"LeftLeg",
	"RightLeg",
	"Shirt",
	"Pants",
	"GraphicTShirt",
	"BodyTypeScale",
	"DepthScale",
	"HeadScale",
	"HeightScale",
	"ProportionScale",
	"WidthScale",
	"ClimbAnimation",
	"FallAnimation",
	"IdleAnimation",
	"JumpAnimation",
	"MoodAnimation",
	"RunAnimation",
	"SwimAnimation",
	"WalkAnimation",
}

local BOOL_PROPS: { string } = {
	"StaticFacialAnimation",
	"UseAvatarSettings",
}

local STRING_PROPS: { string } = {
	"HatAccessory",
	"HairAccessory",
	"FaceAccessory",
	"NeckAccessory",
	"ShouldersAccessory",
	"FrontAccessory",
	"BackAccessory",
	"WaistAccessory",
}

local COLOR_PROPS: { string } = {
	"HeadColor",
	"TorsoColor",
	"LeftArmColor",
	"RightArmColor",
	"LeftLegColor",
	"RightLegColor",
}

local ACCESSORY_TYPE_BY_NAME: { [string]: EnumItem } = {}
local ACCESSORY_TYPE_ITEMS = Enum.AccessoryType:GetEnumItems()
for i = 1, #ACCESSORY_TYPE_ITEMS do
	ACCESSORY_TYPE_BY_NAME[ACCESSORY_TYPE_ITEMS[i].Name] = ACCESSORY_TYPE_ITEMS[i]
end

function characterDescription.serialize(desc: HumanoidDescription): { [string]: any }
	local out: { [string]: any } = { version = 1 }
	for i = 1, #NUMBER_PROPS do
		local key = NUMBER_PROPS[i]
		out[key] = (desc :: any)[key]
	end
	for i = 1, #STRING_PROPS do
		local key = STRING_PROPS[i]
		out[key] = (desc :: any)[key]
	end
	for i = 1, #BOOL_PROPS do
		local key = BOOL_PROPS[i]
		out[key] = (desc :: any)[key]
	end
	for i = 1, #COLOR_PROPS do
		local key = COLOR_PROPS[i]
		local color = (desc :: any)[key] :: Color3
		out[key] = { math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255) }
	end

	local accOk, accessories = pcall(function(): { any }
		return desc:GetAccessories(true)
	end)
	if accOk and type(accessories) == "table" then
		local list: { any } = {}
		for i = 1, #accessories do
			local acc = accessories[i]
			list[i] = {
				AccessoryType = acc.AccessoryType.Name,
				AssetId = acc.AssetId,
				IsLayered = acc.IsLayered,
				Order = acc.Order,
				Puffiness = acc.Puffiness,
			}
		end
		out.accessories = list
	end

	local emotesOk, emotes = pcall(function(): any
		return desc:GetEmotes()
	end)
	if emotesOk and type(emotes) == "table" then
		out.emotes = emotes
	end

	local equippedOk, equipped = pcall(function(): any
		return desc:GetEquippedEmotes()
	end)
	if equippedOk and type(equipped) == "table" then
		out.equippedEmotes = equipped
	end

	return out
end

function characterDescription.deserialize(manifest: { [string]: any }): HumanoidDescription
	local desc = Instance.new("HumanoidDescription")
	for i = 1, #NUMBER_PROPS do
		local key = NUMBER_PROPS[i]
		local value = manifest[key]
		if type(value) == "number" then
			(desc :: any)[key] = value
		end
	end
	for i = 1, #STRING_PROPS do
		local key = STRING_PROPS[i]
		local value = manifest[key]
		if type(value) == "string" then
			(desc :: any)[key] = value
		end
	end
	for i = 1, #BOOL_PROPS do
		local key = BOOL_PROPS[i]
		local value = manifest[key]
		if type(value) == "boolean" then
			(desc :: any)[key] = value
		end
	end
	for i = 1, #COLOR_PROPS do
		local key = COLOR_PROPS[i]
		local value = manifest[key]
		if type(value) == "table" and #value >= 3 then
			(desc :: any)[key] = Color3.fromRGB(value[1], value[2], value[3])
		end
	end

	local accessories = manifest.accessories
	if type(accessories) == "table" then
		local list: { any } = {}
		for i = 1, #accessories do
			local acc = accessories[i]
			local accType = type(acc.AccessoryType) == "string" and ACCESSORY_TYPE_BY_NAME[acc.AccessoryType] or nil
			if accType and type(acc.AssetId) == "number" then
				local entry: any = {
					AccessoryType = accType,
					AssetId = acc.AssetId,
					IsLayered = acc.IsLayered == true,
				}
				if type(acc.Order) == "number" then
					entry.Order = acc.Order
				end
				if type(acc.Puffiness) == "number" then
					entry.Puffiness = acc.Puffiness
				end
				list[#list + 1] = entry
			end
		end
		if #list > 0 then
			pcall(function(): ()
				desc:SetAccessories(list, true)
			end)
		end
	end

	local emotes = manifest.emotes
	if type(emotes) == "table" then
		pcall(function(): ()
			desc:SetEmotes(emotes)
		end)
	end

	local equipped = manifest.equippedEmotes
	if type(equipped) == "table" then
		pcall(function(): ()
			desc:SetEquippedEmotes(equipped)
		end)
	end

	return desc
end

function characterDescription.fromUserId(userId: number): HumanoidDescription?
	for attempt = 1, 3 do
		local ok, desc = pcall(function(): HumanoidDescription
			return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
		end)
		if ok and typeof(desc) == "Instance" then
			return desc :: HumanoidDescription
		end
		if attempt < 3 then
			task.wait(0.35)
		end
	end
	return nil
end

function characterDescription.getAssetName(assetId: number): string?
	local ok, info = pcall(function(): any
		return MarketplaceService:GetProductInfoAsync(assetId)
	end)
	if ok and type(info) == "table" and type(info.Name) == "string" and info.Name ~= "" then
		return info.Name
	end
	return nil
end

function characterDescription.resolveUser(input: string): (number?, string?)
	local trimmed = string.match(input, "^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return nil, "Enter a user id or username."
	end

	local asNumber = tonumber(trimmed)
	if asNumber and asNumber > 0 and math.floor(asNumber) == asNumber then
		local ok = pcall(function(): string
			return Players:GetNameFromUserIdAsync(asNumber)
		end)
		if ok then
			return asNumber, nil
		end
	end

	local ok, id = pcall(function(): number
		return Players:GetUserIdFromNameAsync(trimmed)
	end)
	if ok and type(id) == "number" then
		return id, nil
	end

	return nil, "No Roblox user found for that id or username."
end

return characterDescription
