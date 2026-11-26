local AvatarEditorService = cloneref(game:GetService("AvatarEditorService")) :: AvatarEditorService

local catalog = {}

local PART_KEY: { [string]: string } = {
	Head = "Head",
	DynamicHead = "Head",
	Torso = "Torso",
	LeftArm = "LeftArm",
	RightArm = "RightArm",
	LeftLeg = "LeftLeg",
	RightLeg = "RightLeg",
	Face = "Face",
}

local SORT_TYPE_BY_NAME: { [string]: EnumItem } = {}
for _, item in next, Enum.CatalogSortType:GetEnumItems() do
	SORT_TYPE_BY_NAME[item.Name] = item
end

local SORT_AGGREGATION = (function(): EnumItem?
	local items = Enum.CatalogSortAggregation:GetEnumItems()
	for i = 1, #items do
		if items[i].Name == "AllTime" then
			return items[i]
		end
	end
	return nil
end)()

local function firstSort(candidates: { string }): EnumItem?
	for i = 1, #candidates do
		local resolved = SORT_TYPE_BY_NAME[candidates[i]]
		if resolved then
			return resolved
		end
	end
	return nil
end

local ACCESSORY_TYPE: { [string]: string } = {
	Hat = "Hat",
	HairAccessory = "Hair",
	FaceAccessory = "Face",
	NeckAccessory = "Neck",
	ShoulderAccessory = "Shoulder",
	FrontAccessory = "Front",
	BackAccessory = "Back",
	WaistAccessory = "Waist",
	TShirtAccessory = "TShirt",
	ShirtAccessory = "Shirt",
	PantsAccessory = "Pants",
	JacketAccessory = "Jacket",
	SweaterAccessory = "Sweater",
	ShortsAccessory = "Shorts",
	LeftShoeAccessory = "LeftShoe",
	RightShoeAccessory = "RightShoe",
	DressSkirtAccessory = "DressSkirt",
	EyebrowAccessory = "Eyebrow",
	EyelashAccessory = "Eyelash",
}

local LAYERED: { [string]: boolean } = {
	TShirtAccessory = true,
	ShirtAccessory = true,
	PantsAccessory = true,
	JacketAccessory = true,
	SweaterAccessory = true,
	ShortsAccessory = true,
	LeftShoeAccessory = true,
	RightShoeAccessory = true,
	DressSkirtAccessory = true,
}

local CLOTHING_KEY: { [string]: string } = {
	Shirt = "Shirt",
	Pants = "Pants",
	TShirt = "GraphicTShirt",
	Face = "Face",
	Head = "Head",
	DynamicHead = "Head",
	Torso = "Torso",
	LeftArm = "LeftArm",
	RightArm = "RightArm",
	LeftLeg = "LeftLeg",
	RightLeg = "RightLeg",
}

export type BundledPart = { id: number, assetTypeName: string }
export type CatalogResult = {
	id: number,
	name: string,
	assetTypeName: string,
	isBundle: boolean?,
	bundledItems: { BundledPart }?,
}
export type Classification = { kind: string, accessoryType: string?, isLayered: boolean?, clothingKey: string? }
export type CatalogTab = {
	id: string,
	label: string,
	assetTypes: { Enum.AvatarAssetType }?,
	bundleTypes: { Enum.BundleType }?,
	applyParts: { string }?,
	keyword: string?,
}
export type CatalogGroup = { id: string, label: string, tabs: { CatalogTab } }
export type SortOption = { id: string, label: string, sortType: EnumItem }

local SORT_SPECS: { { id: string, label: string, names: { string } } } = {
	{ id = "popular", label = "Popular", names = { "MostFavorited", "Favorited" } },
	{ id = "relevance", label = "Relevance", names = { "Relevance" } },
	{ id = "sales", label = "Bestselling", names = { "Bestselling", "Sales" } },
	{ id = "newest", label = "Newest", names = { "RecentlyCreated" } },
	{ id = "price_low", label = "Price ↑", names = { "PriceLowToHigh" } },
	{ id = "price_high", label = "Price ↓", names = { "PriceHighToLow" } },
}

catalog.SORT_OPTIONS = (function(): { SortOption }
	local options: { SortOption } = {}
	for i = 1, #SORT_SPECS do
		local spec = SORT_SPECS[i]
		local sortType = firstSort(spec.names)
		if sortType then
			options[#options + 1] = { id = spec.id, label = spec.label, sortType = sortType }
		end
	end
	return options
end)()

function catalog.getSort(id: string): EnumItem?
	for i = 1, #catalog.SORT_OPTIONS do
		if catalog.SORT_OPTIONS[i].id == id then
			return catalog.SORT_OPTIONS[i].sortType
		end
	end
	return nil
end

local T = Enum.AvatarAssetType

catalog.GROUPS = {
	{
		id = "Accessories",
		label = "Accessories",
		tabs = {
			{
				id = "acc_all",
				label = "All",
				assetTypes = {
					T.Hat,
					T.HairAccessory,
					T.FaceAccessory,
					T.NeckAccessory,
					T.ShoulderAccessory,
					T.FrontAccessory,
					T.BackAccessory,
					T.WaistAccessory,
				},
			},
			{ id = "acc_hat", label = "Hat", assetTypes = { T.Hat } },
			{ id = "acc_face", label = "Face", assetTypes = { T.FaceAccessory } },
			{ id = "acc_neck", label = "Neck", assetTypes = { T.NeckAccessory } },
			{ id = "acc_shoulder", label = "Shoulder", assetTypes = { T.ShoulderAccessory } },
			{ id = "acc_front", label = "Front", assetTypes = { T.FrontAccessory } },
			{ id = "acc_back", label = "Back", assetTypes = { T.BackAccessory } },
			{ id = "acc_waist", label = "Waist", assetTypes = { T.WaistAccessory } },
		},
	},
	{
		id = "Hair",
		label = "Hair",
		tabs = {
			{ id = "hair_all", label = "All", assetTypes = { T.HairAccessory } },
		},
	},
	{
		id = "Body",
		label = "Body",
		tabs = {
			{ id = "body_head", label = "Head", bundleTypes = { Enum.BundleType.BodyParts }, applyParts = { "Head" } },
			{
				id = "body_face",
				label = "Face",
				bundleTypes = { Enum.BundleType.DynamicHead },
				applyParts = { "Head" },
			},
			{
				id = "body_torso",
				label = "Torso",
				bundleTypes = { Enum.BundleType.BodyParts },
				applyParts = { "Torso" },
			},
			{
				id = "body_arms",
				label = "Arms",
				bundleTypes = { Enum.BundleType.BodyParts },
				applyParts = { "LeftArm", "RightArm" },
			},
			{
				id = "body_legs",
				label = "Legs",
				bundleTypes = { Enum.BundleType.BodyParts },
				applyParts = { "LeftLeg", "RightLeg" },
			},
			{ id = "body_full", label = "Full Package", bundleTypes = { Enum.BundleType.BodyParts } },
		},
	},
	{
		id = "Makeup",
		label = "Makeup",
		tabs = {
			{ id = "makeup_all", label = "All", assetTypes = { T.FaceAccessory }, keyword = "makeup" },
			{ id = "makeup_eyebrow", label = "Eyebrow", assetTypes = { T.EyebrowAccessory } },
			{ id = "makeup_eyelash", label = "Eyelash", assetTypes = { T.EyelashAccessory } },
			{ id = "makeup_lipstick", label = "Lipstick", assetTypes = { T.FaceAccessory }, keyword = "lipstick" },
			{ id = "makeup_blush", label = "Blush", assetTypes = { T.FaceAccessory }, keyword = "blush" },
		},
	},
	{
		id = "Clothing",
		label = "Clothing",
		tabs = {
			{
				id = "cl_all",
				label = "All",
				assetTypes = {
					T.Shirt,
					T.Pants,
					T.TShirt,
					T.ShirtAccessory,
					T.PantsAccessory,
					T.TShirtAccessory,
					T.JacketAccessory,
					T.SweaterAccessory,
					T.ShortsAccessory,
					T.DressSkirtAccessory,
					T.LeftShoeAccessory,
					T.RightShoeAccessory,
				},
			},
			{ id = "cl_cshirt", label = "Classic Shirt", assetTypes = { T.Shirt } },
			{ id = "cl_cpants", label = "Classic Pants", assetTypes = { T.Pants } },
			{ id = "cl_ctshirt", label = "Classic T-Shirt", assetTypes = { T.TShirt } },
			{ id = "cl_shirt", label = "Shirt", assetTypes = { T.ShirtAccessory } },
			{ id = "cl_pants", label = "Pants", assetTypes = { T.PantsAccessory } },
			{ id = "cl_tshirt", label = "T-Shirt", assetTypes = { T.TShirtAccessory } },
			{ id = "cl_jacket", label = "Jacket", assetTypes = { T.JacketAccessory } },
			{ id = "cl_sweater", label = "Sweater", assetTypes = { T.SweaterAccessory } },
			{ id = "cl_shorts", label = "Shorts", assetTypes = { T.ShortsAccessory } },
			{ id = "cl_dress", label = "Dress", assetTypes = { T.DressSkirtAccessory } },
			{ id = "cl_shoes", label = "Shoes", assetTypes = { T.LeftShoeAccessory, T.RightShoeAccessory } },
		},
	},
} :: { CatalogGroup }

function catalog.getGroup(groupId: string): CatalogGroup?
	for i = 1, #catalog.GROUPS do
		if catalog.GROUPS[i].id == groupId then
			return catalog.GROUPS[i]
		end
	end
	return nil
end

function catalog.getTab(categoryId: string): CatalogTab?
	for g = 1, #catalog.GROUPS do
		local tabs = catalog.GROUPS[g].tabs
		for t = 1, #tabs do
			if tabs[t].id == categoryId then
				return tabs[t]
			end
		end
	end
	return nil
end

function catalog.classify(assetTypeName: string): Classification
	if assetTypeName == "" then
		return { kind = "unsupported" }
	end
	local accessory = ACCESSORY_TYPE[assetTypeName]
	if accessory then
		return { kind = "accessory", accessoryType = accessory, isLayered = LAYERED[assetTypeName] == true }
	end
	local clothing = CLOTHING_KEY[assetTypeName]
	if clothing then
		return { kind = "clothing", clothingKey = clothing }
	end
	return { kind = "unsupported" }
end

function catalog.bundleParts(bundledItems: { BundledPart }?): { [string]: number }
	local parts: { [string]: number } = {}
	if type(bundledItems) ~= "table" then
		return parts
	end
	for i = 1, #bundledItems do
		local part = bundledItems[i]
		local key = PART_KEY[part.assetTypeName]
		if key and not parts[key] then
			parts[key] = part.id
		end
	end
	return parts
end

local bundlePartCache: { [number]: { [string]: number } } = {}

function catalog.resolveBundleParts(item: CatalogResult): { [string]: number }?
	local parts = catalog.bundleParts(item.bundledItems)
	if next(parts) then
		return parts
	end
	return bundlePartCache[item.id]
end

function catalog.fetchBundleParts(item: CatalogResult): { [string]: number }
	local cached = catalog.resolveBundleParts(item)
	if cached then
		return cached
	end

	local ok, details = pcall(function(): any
		return AvatarEditorService:GetItemDetails(item.id, Enum.AvatarItemType.Bundle)
	end)
	local items = ok and type(details) == "table" and (details.Items or details.BundledItems)
	local list: { BundledPart } = {}
	if type(items) == "table" then
		for i = 1, #items do
			local entry = items[i]
			if type(entry) == "table" and type(entry.Id) == "number" and type(entry.AssetType) == "string" then
				list[#list + 1] = { id = entry.Id, assetTypeName = entry.AssetType }
			end
		end
	end

	local parts = catalog.bundleParts(list)
	bundlePartCache[item.id] = parts
	return parts
end

local function readPage(page: { any }): { CatalogResult }
	local results: { CatalogResult } = {}
	for i = 1, #page do
		local item = page[i]
		if type(item.Id) == "number" then
			local isBundle = item.ItemType == "Bundle" or item.BundleType ~= nil
			local assetTypeName = type(item.AssetType) == "string" and item.AssetType or ""
			local bundledItems: { BundledPart }? = nil
			if isBundle and type(item.BundledItems) == "table" then
				local list: { BundledPart } = {}
				for j = 1, #item.BundledItems do
					local bi = item.BundledItems[j]
					if bi.Type == "Asset" and type(bi.Id) == "number" and type(bi.AssetType) == "string" then
						list[#list + 1] = { id = bi.Id, assetTypeName = bi.AssetType }
					end
				end
				bundledItems = list
			end
			if isBundle or assetTypeName ~= "" then
				results[#results + 1] = {
					id = item.Id,
					name = tostring(item.Name),
					assetTypeName = assetTypeName,
					isBundle = isBundle,
					bundledItems = bundledItems,
				}
			end
		end
	end
	return results
end

function catalog.search(
	keyword: string,
	assetTypes: { Enum.AvatarAssetType }?,
	bundleTypes: { Enum.BundleType }?,
	sortType: EnumItem?
): ({ CatalogResult }, string?, CatalogPages?)
	local ok, pages = pcall(function(): CatalogPages
		local params = CatalogSearchParams.new()
		if keyword ~= "" then
			params.SearchKeyword = keyword
		end
		if bundleTypes and #bundleTypes > 0 then
			params.BundleTypes = bundleTypes
		elseif assetTypes and #assetTypes > 0 then
			params.AssetTypes = assetTypes
		end
		if sortType then
			(params :: any).SortType = sortType
			if SORT_AGGREGATION then
				(params :: any).SortAggregation = SORT_AGGREGATION
			end
		end
		return AvatarEditorService:SearchCatalogAsync(params)
	end)
	if not ok then
		return {}, `Catalog search failed: {tostring(pages)}`, nil
	end
	if not pages then
		return {}, "Catalog search returned nothing.", nil
	end

	local pageOk, page = pcall(function(): { any }
		return pages:GetCurrentPage()
	end)
	if not pageOk or type(page) ~= "table" then
		return {}, "Could not read results.", nil
	end

	return readPage(page), nil, pages
end

function catalog.loadMore(pages: CatalogPages): ({ CatalogResult }, boolean, string?)
	if pages.IsFinished then
		return {}, true, nil
	end
	local ok, err = pcall(function(): ()
		pages:AdvanceToNextPageAsync()
	end)
	if not ok then
		return {}, false, `Could not load more: {tostring(err)}`
	end
	local pageOk, page = pcall(function(): { any }
		return pages:GetCurrentPage()
	end)
	local finished = pages.IsFinished
	if not pageOk or type(page) ~= "table" then
		return {}, finished, nil
	end
	return readPage(page), finished, nil
end

return catalog
