local Players = cloneref(game:GetService("Players")) :: Players

local logger = require("@share/logger").new("customCharmController")
local cosmeticLibraryAccess = require("@game/rivals/feature/inventory/cosmeticLibraryAccess")
local customAssets = require("@game/rivals/feature/inventory/customAssets")
local customCharmStore = require("@game/rivals/feature/inventory/customCharmStore")
local stateConverter = require("@src/feature/config/module/stateConverter")

local runElevated = cosmeticLibraryAccess.runElevated
local ensureCustomRarity = cosmeticLibraryAccess.ensureCustomRarity

local DEFAULT_MESH_COLOR = Color3.fromRGB(230, 230, 230)

local customCharmController = {
	_injected = {} :: { [string]: boolean },
	_charmFolder = nil :: Instance?,
	_templateName = nil :: string?,
	_started = false,
}

local function collectCharmNames(): { [string]: boolean }
	local lib = cosmeticLibraryAccess.getLibrary()
	local out: { [string]: boolean } = {}
	if not lib or type(lib.Cosmetics) ~= "table" then
		return out
	end
	for name, info in next, lib.Cosmetics do
		if type(info) == "table" and info.Type == "Charm" and info.__customId == nil then
			out[name] = true
		end
	end
	return out
end

local function discoverCharmFolder(): ()
	if customCharmController._charmFolder and customCharmController._charmFolder.Parent then
		return
	end

	local charmNames = collectCharmNames()
	if next(charmNames) == nil then
		return
	end

	local localPlayer = Players.LocalPlayer
	local playerScripts = localPlayer and localPlayer:FindFirstChild("PlayerScripts")
	local assets = playerScripts and playerScripts:FindFirstChild("Assets")
	if not assets then
		return
	end

	local bestFolder: Instance? = nil
	local bestTemplate: string? = nil
	local bestScore = 1

	local candidates = assets:QueryDescendants("Folder")
	candidates[#candidates + 1] = assets

	for i = 1, #candidates do
		local folder = candidates[i]
		local score = 0
		local template: string? = nil
		for _, child in next, folder:GetChildren() do
			if charmNames[child.Name] then
				score += 1
				if not template and (child:IsA("Model") or child:IsA("BasePart")) then
					template = child.Name
				end
			end
		end
		if score > bestScore and template then
			bestScore = score
			bestFolder = folder
			bestTemplate = template
		end
	end

	if bestFolder then
		customCharmController._charmFolder = bestFolder
		customCharmController._templateName = bestTemplate
	else
		logger:warn("charm assets not found")
	end
end

function customCharmController.available(): boolean
	discoverCharmFolder()
	return customCharmController._charmFolder ~= nil
end

local function findAnchorPart(model: Instance): BasePart?
	if model:IsA("BasePart") then
		return model
	end
	if model:IsA("Model") and model.PrimaryPart then
		return model.PrimaryPart
	end
	local best: BasePart? = nil
	local bestVolume = -1
	for _, node in next, model:QueryDescendants("BasePart") do
		local part = node :: BasePart
		local size = part.Size
		local volume = size.X * size.Y * size.Z
		if volume > bestVolume then
			bestVolume = volume
			best = part
		end
	end
	return best
end

function customCharmController.resolveTexture(def: customCharmStore.CustomCharm): string?
	if type(def.texture) ~= "string" or def.texture == "" then
		return nil
	end
	return customAssets.resolve(def.texture)
end

function customCharmController.buildModel(def: customCharmStore.CustomCharm): Model?
	discoverCharmFolder()
	local folder = customCharmController._charmFolder
	local templateName = customCharmController._templateName
	if not folder or not templateName then
		return nil
	end
	local template = folder:FindFirstChild(templateName)
	if not template then
		return nil
	end

	local meshAsset = customAssets.resolve(def.mesh)
	if not meshAsset then
		logger:warn("mesh unavailable for " .. def.name)
		return nil
	end

	local clone = template:Clone()
	for _, script in next, clone:QueryDescendants("LocalScript") do
		script:Destroy()
	end
	for _, script in next, clone:QueryDescendants("Script") do
		script:Destroy()
	end

	local anchor = findAnchorPart(clone)
	if not anchor then
		clone:Destroy()
		return nil
	end

	local model: Model
	if clone:IsA("Model") then
		model = clone
	else
		model = Instance.new("Model")
		model.Name = clone.Name
		clone.Parent = model
	end

	for _, node in next, model:QueryDescendants("BasePart") do
		local part = node :: BasePart
		part.Transparency = 1
	end
	for _, decal in next, model:QueryDescendants("Decal") do
		(decal :: Decal).Transparency = 1
	end

	local tint = def.tint
	local meshPart = Instance.new("Part")
	meshPart.Name = "CustomMesh"
	meshPart.Size = Vector3.one * math.max(def.scale * 0.6, 0.2)
	meshPart.CFrame = anchor.CFrame
	meshPart.Color = tint or DEFAULT_MESH_COLOR
	meshPart.CanCollide = false
	meshPart.CanQuery = false
	meshPart.CanTouch = false
	meshPart.CastShadow = false
	meshPart.Massless = true

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = meshAsset
	mesh.Scale = Vector3.one * def.scale
	local texture = customCharmController.resolveTexture(def)
	if texture then
		mesh.TextureId = texture
	end
	if tint then
		mesh.VertexColor = Vector3.new(tint.R, tint.G, tint.B)
	end
	mesh.Parent = meshPart

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = meshPart
	weld.Part1 = anchor
	weld.Parent = meshPart
	meshPart.Parent = model

	return model
end

local function removeInjection(id: string): ()
	local lib = cosmeticLibraryAccess.getLibrary()
	if lib and type(lib.Cosmetics) == "table" then
		lib.Cosmetics[id] = nil
	end
	local folder = customCharmController._charmFolder
	local model = folder and folder:FindFirstChild(id)
	if model then
		model:Destroy()
	end
	customCharmController._injected[id] = nil
end

local function inject(def: customCharmStore.CustomCharm): boolean
	local lib = cosmeticLibraryAccess.getLibrary()
	if not lib or type(lib.Cosmetics) ~= "table" then
		return false
	end

	local model = customCharmController.buildModel(def)
	if not model then
		return false
	end
	model.Name = def.id

	local folder = customCharmController._charmFolder :: Instance
	local existing = folder:FindFirstChild(def.id)
	if existing then
		existing:Destroy()
	end

	local success = false
	runElevated(function()
		ensureCustomRarity(lib)
		model.Parent = folder

		local image = customCharmController.resolveTexture(def)
		lib.Cosmetics[def.id] = {
			Type = "Charm",
			Rarity = "Custom",
			Image = image or "",
			ImageScale = 1,
			Hidden = false,
			__customId = def.id,
			__customName = def.name,
			GetDescription = function(): string
				return def.name
			end,
		}
		customCharmController._injected[def.id] = true
		success = true
	end)

	if not success then
		model:Destroy()
	end
	return success
end

local function removeAll(): ()
	for id in next, table.clone(customCharmController._injected) do
		removeInjection(id)
	end
end

function customCharmController.registerAll(): ()
	removeAll()
	for _, def in next, customCharmStore.list() do
		inject(def)
	end
end

function customCharmController.save(def: customCharmStore.CustomCharm): boolean
	customCharmStore.set(def)
	removeInjection(def.id)
	return inject(def)
end

function customCharmController.delete(id: string): ()
	removeInjection(id)
	customCharmStore.remove(id)
end

local function applyConfig(data: any): ()
	customCharmStore.deserialize(data)
	customCharmController.registerAll()
end

function customCharmController.new(): typeof(customCharmController)
	if customCharmController._started then
		return customCharmController
	end
	customCharmController._started = true

	customAssets.ensureDir()
	discoverCharmFolder()
	customCharmController.registerAll()

	stateConverter.RegisterExtension("rivalsCustomCharms", customCharmStore.serialize, applyConfig, applyConfig)

	return customCharmController
end

function customCharmController.Destroy(): ()
	if not customCharmController._started then
		return
	end
	customCharmController._started = false
	removeAll()
	stateConverter.UnregisterExtension("rivalsCustomCharms")
end

return customCharmController
