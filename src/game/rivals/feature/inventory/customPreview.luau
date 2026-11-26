local Players = cloneref(game:GetService("Players")) :: Players

local customAssets = require("@game/rivals/feature/inventory/customAssets")
local customCharmController = require("@game/rivals/feature/inventory/customCharmController")
local customCharmStore = require("@game/rivals/feature/inventory/customCharmStore")

local SCROLL_TAG = "LimerenceWrapScroll"
local FACES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
local TILE_STUDS = 2

export type WrapPreviewSettings = {
	image: string?,
	animated: boolean,
	speedU: number,
	speedV: number,
	tint: Color3?,
	material: string,
}

local customPreview = {
	_viewModels = nil :: Instance?,
}

local function getViewModelsFolder(): Instance?
	local cached = customPreview._viewModels
	if cached and cached.Parent then
		return cached
	end
	local localPlayer = Players.LocalPlayer
	local playerScripts = localPlayer and localPlayer:FindFirstChild("PlayerScripts")
	local assets = playerScripts and playerScripts:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("ViewModels")
	customPreview._viewModels = folder
	return folder
end

local function stripScripts(model: Instance): ()
	for _, script in next, model:QueryDescendants("LocalScript") do
		script:Destroy()
	end
	for _, script in next, model:QueryDescendants("Script") do
		script:Destroy()
	end
end

function customPreview.buildWeaponModel(weaponName: string): Model?
	local folder = getViewModelsFolder()
	if not folder then
		return nil
	end
	local weapons = folder:FindFirstChild("Weapons")
	local template = (weapons and weapons:FindFirstChild(weaponName)) or folder:FindFirstChild(weaponName)
	if not template or not template:IsA("Model") then
		return nil
	end
	local clone = template:Clone()
	stripScripts(clone)
	return clone
end

local function resolveMaterial(name: string): Enum.Material
	local material = (Enum.Material :: any)[name]
	if typeof(material) == "EnumItem" then
		return material :: Enum.Material
	end
	return Enum.Material.Plastic
end

function customPreview.applyWrap(model: Model, settings: WrapPreviewSettings): ()
	local assetId: string? = nil
	if settings.image then
		assetId = customAssets.resolve(settings.image)
	end

	local material = resolveMaterial(settings.material)
	local tint = settings.tint

	for _, node in next, model:QueryDescendants("BasePart") do
		local part = node :: BasePart
		if not part:HasTag("Wrappable") then
			continue
		end
		part.Material = material
		if tint then
			part.Color = tint
		end
		for _, child in next, part:GetChildren() do
			if child:IsA("SurfaceAppearance") or child:IsA("Texture") then
				child:Destroy()
			end
		end
		if not assetId then
			continue
		end
		for _, face in next, FACES do
			local texture = Instance.new("Texture")
			texture.Texture = assetId
			texture.Face = face
			texture.StudsPerTileU = TILE_STUDS
			texture.StudsPerTileV = TILE_STUDS
			if settings.animated then
				texture:SetAttribute("SpeedU", settings.speedU)
				texture:SetAttribute("SpeedV", settings.speedV)
				texture:AddTag(SCROLL_TAG)
			end
			texture.Parent = part
		end
	end
end

function customPreview.buildWrapModel(weaponName: string?, settings: WrapPreviewSettings): Model?
	if not weaponName then
		return nil
	end
	local model = customPreview.buildWeaponModel(weaponName)
	if not model then
		return nil
	end
	customPreview.applyWrap(model, settings)
	return model
end

function customPreview.buildCharmModel(def: customCharmStore.CustomCharm): Model?
	return customCharmController.buildModel(def)
end

return customPreview
