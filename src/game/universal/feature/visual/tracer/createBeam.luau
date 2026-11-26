local Workspace = game:GetService("Workspace")
local Terrain = Workspace.Terrain
local instances = require("@share/instances")
local FileController = require("@feature/file/FileController")

export type BeamManifest = {
	name: string?,
	preview: string?,
	texture: string?,
	width0: number?,
	width1: number?,
	curveSize0: number?,
	curveSize1: number?,
	textureMode: string?,
	textureLength: number?,
	textureSpeed: number?,
	lightInfluence: number?,
	lightEmission: number?,
	faceCamera: boolean?,
	zOffset: number?,
}

local TEXTURE_MODES: { [string]: Enum.TextureMode } = {
	Stretch = Enum.TextureMode.Stretch,
	Wrap = Enum.TextureMode.Wrap,
	Static = Enum.TextureMode.Static,
}

local DEFAULTS = {
	width0 = 0.25,
	width1 = 0.55,
	curveSize0 = 0,
	curveSize1 = 0,
	textureMode = Enum.TextureMode.Stretch,
	textureLength = 1,
	textureSpeed = 1,
	lightInfluence = 5,
	lightEmission = 5,
	zOffset = 0,
}

local function num(value: any, fallback: number): number
	return (type(value) == "number") and value or fallback
end

return LPH_NO_VIRTUALIZE(
	function(origin: Vector3, target: Vector3, manifest: BeamManifest?): (Beam, Attachment, Attachment)
		local m = manifest or {}

		local attachment1 = instances.new("Attachment", {
			Secure = true,
			CFrame = CFrame.new(origin),
		}, Terrain) :: Attachment

		local attachment2 = instances.new("Attachment", {
			Secure = true,
			CFrame = CFrame.new(target),
		}, Terrain) :: Attachment

		local texture = FileController.ResolveImage(m.texture) or FileController.Get("image", "beam")
		local textureMode = (type(m.textureMode) == "string" and TEXTURE_MODES[m.textureMode]) or DEFAULTS.textureMode

		local beam = instances.new("Beam", {
			Secure = true,
			Width0 = num(m.width0, DEFAULTS.width0),
			Width1 = num(m.width1, DEFAULTS.width1),
			CurveSize0 = num(m.curveSize0, DEFAULTS.curveSize0),
			CurveSize1 = num(m.curveSize1, DEFAULTS.curveSize1),
			TextureMode = textureMode,
			TextureLength = num(m.textureLength, DEFAULTS.textureLength),
			TextureSpeed = num(m.textureSpeed, DEFAULTS.textureSpeed),
			LightInfluence = num(m.lightInfluence, DEFAULTS.lightInfluence),
			LightEmission = num(m.lightEmission, DEFAULTS.lightEmission),
			FaceCamera = (type(m.faceCamera) ~= "boolean") and true or m.faceCamera,
			ZOffset = num(m.zOffset, DEFAULTS.zOffset),
			Texture = texture,
			Attachment0 = attachment1,
			Attachment1 = attachment2,
		}, Terrain) :: Beam

		return beam, attachment1, attachment2
	end
)
