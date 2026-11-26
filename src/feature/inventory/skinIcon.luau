local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local ModuleController = require("@game/bloxstrike/module/ModuleController")
local Registry = require("@game/bloxstrike/registry/Registry")

local weaponPropsCache: { [string]: any } = {}
local weaponDropShadowsCache: { [string]: string }? = nil
local weaponDropShadowsMissing = false

local DEFAULT_GLOVE_SHADOW = "rbxassetid://93849480884386"

local function getWeaponProperties(weapon: string): any?
	local cached = weaponPropsCache[weapon]
	if cached ~= nil then
		return cached or nil
	end
	local def = ReplicatedStorage.Database.Custom.Weapons:FindFirstChild(weapon)
	if not def then
		weaponPropsCache[weapon] = false
		return nil
	end
	setthreadidentity(2)
	local ok, mod = pcall(require, def)
	setthreadidentity(8)
	if not ok or type(mod) ~= "table" then
		weaponPropsCache[weapon] = false
		return nil
	end
	weaponPropsCache[weapon] = mod
	return mod
end

local function getWeaponDropShadows(): { [string]: string }?
	if weaponDropShadowsMissing then
		return nil
	end
	if weaponDropShadowsCache then
		return weaponDropShadowsCache
	end

	local uiRoot = ReplicatedStorage:FindFirstChild("Database")
		and (ReplicatedStorage.Database :: any).Custom
		and (ReplicatedStorage.Database.Custom :: any).GameStats
		and (ReplicatedStorage.Database.Custom.GameStats :: any).UI
		and (ReplicatedStorage.Database.Custom.GameStats.UI :: any).Inventory
	local mod = uiRoot and uiRoot:FindFirstChild("WeaponDropShadows")
	if not mod then
		weaponDropShadowsMissing = true
		return nil
	end

	setthreadidentity(2)
	local ok, shadows = pcall(require, mod)
	setthreadidentity(8)
	if not ok or type(shadows) ~= "table" then
		weaponDropShadowsMissing = true
		return nil
	end

	weaponDropShadowsCache = shadows
	return shadows
end

local function isGloveWeapon(weapon: string, props: any?): boolean
	if props and (props :: any).Class == "Glove" then
		return true
	end
	local entry = Registry.All[weapon]
	return entry ~= nil and entry.class == "Glove"
end

local function resolveGloveDropShadow(weapon: string): string
	local shadows = getWeaponDropShadows()
	if shadows then
		local icon = shadows[weapon]
		if type(icon) == "string" and icon ~= "" then
			return icon
		end
	end
	return DEFAULT_GLOVE_SHADOW
end

local function resolveWeaponFallbackIcon(weapon: string): string?
	local props = getWeaponProperties(weapon)
	if props then
		local icon = (props :: any).Icon or (props :: any).ReverseIcon
		if type(icon) == "string" and icon ~= "" then
			return icon
		end
		if isGloveWeapon(weapon, props) then
			return resolveGloveDropShadow(weapon)
		end
	end

	local shadows = getWeaponDropShadows()
	if shadows then
		local shadow = shadows[weapon]
		if type(shadow) == "string" and shadow ~= "" then
			return shadow
		end
	end

	if isGloveWeapon(weapon, props) then
		return resolveGloveDropShadow(weapon)
	end

	return nil
end

local function resolveSkinIcon(weapon: string, skin: string, float: number?): string?
	local Skins = ModuleController.GetModule("Skins")
	if not Skins or not Skins.GetSkinInformation then
		return resolveWeaponFallbackIcon(weapon)
	end

	setthreadidentity(2)
	local ok, info = pcall(Skins.GetSkinInformation, weapon, skin)
	setthreadidentity(8)

	if not ok or not info then
		if isGloveWeapon(weapon, getWeaponProperties(weapon)) then
			return resolveGloveDropShadow(weapon)
		end
		return resolveWeaponFallbackIcon(weapon)
	end

	local wearFloat = float or 0.9999
	if Skins.GetWearImageForFloat then
		setthreadidentity(2)
		local okWear, wearIcon = pcall(Skins.GetWearImageForFloat, info, wearFloat)
		setthreadidentity(8)
		if okWear and type(wearIcon) == "string" and wearIcon ~= "" then
			return wearIcon
		end
	else
		setthreadidentity(8)
	end

	if info.imageAssetId and info.imageAssetId ~= "" then
		return info.imageAssetId
	end

	return resolveWeaponFallbackIcon(weapon)
end

return {
	resolve = resolveSkinIcon,
	resolveWeaponFallback = resolveWeaponFallbackIcon,
}
