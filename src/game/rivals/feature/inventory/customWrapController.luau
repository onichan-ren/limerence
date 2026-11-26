local Players = cloneref(game:GetService("Players")) :: Players
local RunService = cloneref(game:GetService("RunService")) :: RunService
local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService

local logger = require("@share/logger").new("customWrapController")
local cosmeticLibraryAccess = require("@game/rivals/feature/inventory/cosmeticLibraryAccess")
local customWrapStore = require("@game/rivals/feature/inventory/customWrapStore")
local stateConverter = require("@src/feature/config/module/stateConverter")

local SCROLL_TAG = "LimerenceWrapScroll"
local RENDER_NAME = "LimerenceWrapScroll"
local FACES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
local TILE_STUDS = 2

local customWrapController = {
	_injected = {} :: { [string]: boolean },
	_wrapTextures = nil :: Instance?,
	_bound = false,
	_started = false,
}

local _scrollSpeeds: { [Texture]: Vector2 } = {}
local _tagAddedConn: RBXScriptConnection? = nil
local _tagRemovedConn: RBXScriptConnection? = nil

local trackScrollTexture = LPH_NO_VIRTUALIZE(function(texture: Instance): ()
	if not texture:IsA("Texture") then
		return
	end
	local speedU = texture:GetAttribute("SpeedU")
	local speedV = texture:GetAttribute("SpeedV")
	_scrollSpeeds[texture :: Texture] = Vector2.new(
		type(speedU) == "number" and speedU or 0,
		type(speedV) == "number" and speedV or 0
	)
end)

local runElevated = cosmeticLibraryAccess.runElevated

local function getWrapTexturesFolder(timeout: number?): Instance?
	local cached = customWrapController._wrapTextures
	if cached and cached.Parent then
		return cached
	end
	local localPlayer = Players.LocalPlayer
	local playerScripts = localPlayer and localPlayer:FindFirstChild("PlayerScripts")
	local assets = playerScripts and playerScripts:FindFirstChild("Assets")
	if not assets then
		return nil
	end
	local folder = timeout and assets:WaitForChild("WrapTextures", timeout) or assets:FindFirstChild("WrapTextures")
	customWrapController._wrapTextures = folder
	return folder
end

local ensureCustomRarity = cosmeticLibraryAccess.ensureCustomRarity

local function resolveMaterial(name: string): Enum.Material
	local material = (Enum.Material :: any)[name]
	if typeof(material) == "EnumItem" then
		return material :: Enum.Material
	end
	return Enum.Material.Plastic
end

local function buildTextureSet(def: customWrapStore.CustomWrap, assetId: string): Instance?
	local folder = getWrapTexturesFolder()
	if not folder then
		return nil
	end

	local existing = folder:FindFirstChild(def.id)
	if existing then
		existing:Destroy()
	end

	local set = Instance.new("Folder")
	set.Name = def.id

	for _, face in next, FACES do
		local texture = Instance.new("Texture")
		texture.Texture = assetId
		texture.Face = face
		texture.StudsPerTileU = TILE_STUDS
		texture.StudsPerTileV = TILE_STUDS
		if def.animated then
			texture:SetAttribute("SpeedU", def.speedU)
			texture:SetAttribute("SpeedV", def.speedV)
			texture:AddTag(SCROLL_TAG)
		end
		texture.Parent = set
	end

	set.Parent = folder
	return set
end

local function removeInjection(id: string): ()
	local lib = cosmeticLibraryAccess.getLibrary()
	if lib and type(lib.Cosmetics) == "table" then
		lib.Cosmetics[id] = nil
	end
	local folder = getWrapTexturesFolder()
	local set = folder and folder:FindFirstChild(id)
	if set then
		set:Destroy()
	end
	customWrapController._injected[id] = nil
end

local function inject(def: customWrapStore.CustomWrap): boolean
	if not customWrapStore.imageExists(def.image) then
		return false
	end

	local lib = cosmeticLibraryAccess.getLibrary()
	if not lib or type(lib.Cosmetics) ~= "table" then
		return false
	end

	local assetId = getcustomasset(customWrapStore.getAssetPath(def.image))
	if type(assetId) ~= "string" then
		logger:warn("getcustomasset failed for " .. def.image)
		return false
	end

	local success = false
	runElevated(function()
		ensureCustomRarity(lib)

		if not buildTextureSet(def, assetId) then
			return
		end

		local function makeGroup(): { [string]: any }
			return {
				Material = resolveMaterial(def.material),
				MaterialVariant = "",
				Color = def.tint,
				Textures = def.id,
			}
		end

		lib.Cosmetics[def.id] = {
			Type = "Wrap",
			Rarity = "Custom",
			Image = assetId,
			ImageScale = 1,
			Hidden = false,
			__customId = def.id,
			__customName = def.name,
			WrapGroups = { makeGroup(), makeGroup(), makeGroup() },
			GetDescription = function(): string
				return def.name
			end,
		}
		customWrapController._injected[def.id] = true
		success = true
	end)

	return success
end

local function removeAll(): ()
	for id in next, table.clone(customWrapController._injected) do
		removeInjection(id)
	end
end

function customWrapController.registerAll(): ()
	removeAll()
	for _, def in next, customWrapStore.list() do
		inject(def)
	end
end

function customWrapController.save(def: customWrapStore.CustomWrap): boolean
	customWrapStore.set(def)
	removeInjection(def.id)
	return inject(def)
end

function customWrapController.delete(id: string): ()
	removeInjection(id)
	customWrapStore.remove(id)
end

local function startLoop(): ()
	if customWrapController._bound then
		return
	end
	customWrapController._bound = true
	for _, texture in next, CollectionService:GetTagged(SCROLL_TAG) do
		trackScrollTexture(texture)
	end
	_tagAddedConn = CollectionService:GetInstanceAddedSignal(SCROLL_TAG):Connect(trackScrollTexture)
	_tagRemovedConn = CollectionService:GetInstanceRemovedSignal(SCROLL_TAG):Connect(function(texture: Instance): ()
		_scrollSpeeds[texture :: Texture] = nil
	end)
	RunService:BindToRenderStep(
		RENDER_NAME,
		Enum.RenderPriority.Last.Value,
		LPH_NO_VIRTUALIZE(function(dt: number): ()
			for texture, speed in next, _scrollSpeeds do
				local speedU = speed.X
				local speedV = speed.Y
				if speedU ~= 0 then
					texture.OffsetStudsU += dt * speedU
				end
				if speedV ~= 0 then
					texture.OffsetStudsV += dt * speedV
				end
			end
		end)
	)
end

local function stopLoop(): ()
	if not customWrapController._bound then
		return
	end
	customWrapController._bound = false
	RunService:UnbindFromRenderStep(RENDER_NAME)
	if _tagAddedConn then
		_tagAddedConn:Disconnect()
		_tagAddedConn = nil
	end
	if _tagRemovedConn then
		_tagRemovedConn:Disconnect()
		_tagRemovedConn = nil
	end
	table.clear(_scrollSpeeds)
end

local function applyConfig(data: any): ()
	customWrapStore.deserialize(data)
	customWrapController.registerAll()
end

function customWrapController.new(): typeof(customWrapController)
	if customWrapController._started then
		return customWrapController
	end
	customWrapController._started = true

	customWrapStore.ensureDir()
	getWrapTexturesFolder(10)
	startLoop()
	customWrapController.registerAll()

	stateConverter.RegisterExtension("rivalsCustomWraps", customWrapStore.serialize, applyConfig, applyConfig)

	return customWrapController
end

function customWrapController.Destroy(): ()
	if not customWrapController._started then
		return
	end
	customWrapController._started = false
	stopLoop()
	removeAll()
	stateConverter.UnregisterExtension("rivalsCustomWraps")
end

return customWrapController
