local LightingService = cloneref(game:GetService("Lighting")) :: Lighting
local HttpService = cloneref(game:GetService("HttpService")) :: HttpService
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local FileController = require("@feature/file/FileController")

local SKY_DIR = "limerence.biz/assets/skies"

type SkyManifest = {
	name: string?,
	preview: string?,
	faces: {
		Up: string?,
		Dn: string?,
		Lf: string?,
		Rt: string?,
		Ft: string?,
		Bk: string?,
	}?,
	starCount: number?,
	sunAngularSize: number?,
	moonAngularSize: number?,
	sunTextureId: string?,
	moonTextureId: string?,
	celestialBodiesShown: boolean?,
}

local function readManifest(path: string): SkyManifest?
	if not isfile(path) then
		return nil
	end
	local raw = readfile(path)
	if type(raw) ~= "string" then
		return nil
	end
	local decoded: any = HttpService:JSONDecode(raw)
	if type(decoded) ~= "table" then
		return nil
	end
	return decoded
end

local function resolveImage(value: any): string?
	return FileController.ResolveImage(value)
end

local PICKER_CONFIG = {
	assetType = "skies",
	basePath = SKY_DIR,
	extensions = { "json" },
	assignmentTypes = {},
	creator = {
		title = "New sky",
		description = "Paste an asset ID or image URL for each side of the skybox.",
		fields = {
			{ key = "up", label = "Up", placeholder = "Asset ID or URL", required = true },
			{ key = "down", label = "Down", placeholder = "Asset ID or URL", required = true },
			{ key = "left", label = "Left", placeholder = "Asset ID or URL", required = true },
			{ key = "right", label = "Right", placeholder = "Asset ID or URL", required = true },
			{ key = "front", label = "Front", placeholder = "Asset ID or URL", required = true },
			{ key = "back", label = "Back", placeholder = "Asset ID or URL", required = true },
		},
		build = function(values, name)
			return {
				name = name,
				preview = values.front,
				faces = {
					Up = values.up,
					Dn = values.down,
					Lf = values.left,
					Rt = values.right,
					Ft = values.front,
					Bk = values.back,
				},
				starCount = 3000,
				sunAngularSize = 21,
				moonAngularSize = 11,
				sunTextureId = "rbxasset://sky/sun.jpg",
				moonTextureId = "rbxasset://sky/moon.jpg",
				celestialBodiesShown = false,
			}
		end,
		loadValues = function(manifest)
			local faces = manifest.faces or {}
			return {
				up = faces.Up,
				down = faces.Dn,
				left = faces.Lf,
				right = faces.Rt,
				front = faces.Ft,
				back = faces.Bk,
			}
		end,
	},
	bundle = {
		urlPrefix = "https://limerence.biz/get/",
		title = "Downloading Skies",
		icon = "download",
		files = {
			"Rainy.json",
			"Warped.json",
			"White-Mountain.json",
			"Space.json",
			"Spring.json",
			"Fantasy.json",
			"Gray.json",
			"Jungle.json",
		},
	},
	previewImage = function(_source, _name, path)
		local manifest = readManifest(path)
		if not manifest then
			return nil
		end
		local preview = resolveImage(manifest.preview)
		if preview then
			return preview
		end
		if manifest.faces then
			return resolveImage(manifest.faces.Ft)
				or resolveImage(manifest.faces.Bk)
				or resolveImage(manifest.faces.Lf)
				or resolveImage(manifest.faces.Rt)
				or resolveImage(manifest.faces.Up)
				or resolveImage(manifest.faces.Dn)
		end
		return nil
	end,
	previewBehavior = function() end,
}

local SkyboxChanger = {}
SkyboxChanger.__index = SkyboxChanger

setmetatable(SkyboxChanger, { __index = BaseFeature })

local FACE_PROP: { [string]: string } = {
	Up = "SkyboxUp",
	Dn = "SkyboxDn",
	Lf = "SkyboxLf",
	Rt = "SkyboxRt",
	Ft = "SkyboxFt",
	Bk = "SkyboxBk",
}

local BLOCKED_PROPS: { string } = {
	"SkyboxUp",
	"SkyboxDn",
	"SkyboxLf",
	"SkyboxRt",
	"SkyboxFt",
	"SkyboxBk",
	"SkyboxOrientation",
	"StarCount",
	"SunAngularSize",
	"MoonAngularSize",
	"SunTextureId",
	"MoonTextureId",
	"CelestialBodiesShown",
}

function SkyboxChanger.new(link: gameUi.Linker): SkyboxChanger
	local self = BaseFeature.new() :: any
	setmetatable(self, SkyboxChanger)

	if isfolder and makefolder and not isfolder(SKY_DIR) then
		makefolder(SKY_DIR)
	end

	local toggle = link:Toggle("skyEnabled", "Sky", false):SetTip({
		title = "Sky",
		body = "Swaps the sky texture for a custom look.",
	})
	local picker = link:Extra(toggle, "sky", "AssetPicker", "Sky", PICKER_CONFIG)

	self._enabled = false
	self._toggle = toggle
	self._picker = picker
	self._hookedSkies = {} :: { [Sky]: boolean }
	self._createdSky = nil :: Sky?
	self._childAddedConn = nil :: RBXScriptConnection?
	self._currentManifest = nil :: SkyManifest?

	self:Track(toggle:OnChange(function(value: boolean): ()
		if value then
			self:_enable()
		else
			self:_disable()
		end
	end))

	self:Track(picker:OnChange(function(): ()
		if self._enabled then
			self:_apply()
		end
	end))

	return self
end

function SkyboxChanger._loadActiveManifest(self: SkyboxChanger): SkyManifest?
	local name = self._picker:GetSelected()
	if not name then
		return nil
	end
	local path = self._picker:GetSelectedPath()
	if not path then
		return nil
	end
	return readManifest(path)
end

function SkyboxChanger._writeManifest(self: SkyboxChanger, sky: Sky, manifest: SkyManifest): ()
	if manifest.faces then
		for key, prop in next, FACE_PROP do
			local resolved = resolveImage((manifest.faces :: any)[key])
			if resolved then
				hook.setProperty(sky, prop, resolved)
			end
		end
	end
	if type(manifest.starCount) == "number" then
		hook.setProperty(sky, "StarCount", manifest.starCount)
	end
	if type(manifest.sunAngularSize) == "number" then
		hook.setProperty(sky, "SunAngularSize", manifest.sunAngularSize)
	end
	if type(manifest.moonAngularSize) == "number" then
		hook.setProperty(sky, "MoonAngularSize", manifest.moonAngularSize)
	end
	if type(manifest.sunTextureId) == "string" then
		local resolved = resolveImage(manifest.sunTextureId)
		if resolved then
			hook.setProperty(sky, "SunTextureId", resolved)
		end
	end
	if type(manifest.moonTextureId) == "string" then
		local resolved = resolveImage(manifest.moonTextureId)
		if resolved then
			hook.setProperty(sky, "MoonTextureId", resolved)
		end
	end
	if type(manifest.celestialBodiesShown) == "boolean" then
		hook.setProperty(sky, "CelestialBodiesShown", manifest.celestialBodiesShown)
	end
end

function SkyboxChanger._hookSky(self: SkyboxChanger, sky: Sky): ()
	if self._hookedSkies[sky] then
		return
	end
	hook.addInstance(sky)
	for _, prop in next, BLOCKED_PROPS do
		hook.blockProperty(sky, prop)
	end
	self._hookedSkies[sky] = true
end

function SkyboxChanger._unhookSky(self: SkyboxChanger, sky: Sky): ()
	if not self._hookedSkies[sky] then
		return
	end
	hook.restoreInstance(sky)
	self._hookedSkies[sky] = nil
end

function SkyboxChanger._enable(self: SkyboxChanger): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._childAddedConn = LightingService.ChildAdded:Connect(function(child: Instance): ()
		if not self._enabled then
			return
		end
		if child.ClassName ~= "Sky" then
			return
		end
		self:_hookSky(child :: Sky)
		local manifest = self._currentManifest
		if manifest then
			self:_writeManifest(child :: Sky, manifest)
		end
	end)

	self:_apply()
end

function SkyboxChanger._apply(self: SkyboxChanger): ()
	if not self._enabled then
		return
	end

	local manifest = self:_loadActiveManifest()
	if not manifest then
		return
	end
	self._currentManifest = manifest

	local hadSky = false
	for _, child in next, LightingService:GetChildren() do
		if child.ClassName == "Sky" then
			hadSky = true
			self:_hookSky(child :: Sky)
			self:_writeManifest(child :: Sky, manifest)
		end
	end

	if not hadSky and not self._createdSky then
		local sky = Instance.new("Sky") :: Sky
		sky.Name = "Sky"
		self._createdSky = sky
		sky.Parent = LightingService
	end
end

function SkyboxChanger._disable(self: SkyboxChanger): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._childAddedConn then
		self._childAddedConn:Disconnect()
		self._childAddedConn = nil
	end

	for sky in next, self._hookedSkies do
		self:_unhookSky(sky)
	end

	if self._createdSky then
		(self._createdSky :: Sky):Destroy()
		self._createdSky = nil
	end

	self._currentManifest = nil
end

function SkyboxChanger.Destroy(self: SkyboxChanger): ()
	self:_disable()
	BaseFeature.Destroy(self)
end

export type SkyboxChanger =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_toggle: any,
			_picker: any,
			_hookedSkies: { [Sky]: boolean },
			_createdSky: Sky?,
			_childAddedConn: RBXScriptConnection?,
			_currentManifest: SkyManifest?,
		},
		SkyboxChanger
	))
	& BaseFeature.BaseFeature

return SkyboxChanger
