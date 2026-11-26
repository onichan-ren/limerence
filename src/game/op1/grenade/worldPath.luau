local instances = require("@share/instances")

local Workspace = cloneref(game:GetService("Workspace"))
local Terrain = Workspace.Terrain

local DEFAULT_WIDTH = 0.07
local IMPACT_SIZE = 0.55
local PATH_TRANSPARENCY = 0.15

local worldPath = {}
worldPath.__index = worldPath

export type worldPath = typeof(setmetatable(
	{} :: {
		_holder: Part,
		_impact: Part,
		_attachments: { Attachment },
		_beams: { Beam },
		_width: number,
		_pathColor: ColorSequence,
		_impactColor: Color3,
	},
	worldPath
))

function worldPath.new(width: number?): worldPath
	local self = setmetatable({}, worldPath) :: worldPath

	self._width = width or DEFAULT_WIDTH
	self._pathColor = ColorSequence.new(Color3.new(1, 1, 1))
	self._impactColor = Color3.new(1, 1, 1)

	self._holder = instances.new("Part", {
		Size = Vector3.new(0.05, 0.05, 0.05),
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Locked = true,
		Secure = true,
	}, Terrain) :: Part

	self._impact = instances.new("Part", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(IMPACT_SIZE, IMPACT_SIZE, IMPACT_SIZE),
		Material = Enum.Material.Neon,
		Color = self._impactColor,
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Locked = true,
		Secure = true,
	}, Terrain) :: Part

	self._attachments = {}
	self._beams = {}

	return self
end

function worldPath.ensure(self: worldPath, count: number): ()
	local attachments = self._attachments
	local beams = self._beams

	for index = #attachments + 1, count do
		attachments[index] = instances.new("Attachment", {}, self._holder) :: Attachment
	end

	for index = #beams + 1, count - 1 do
		beams[index] = instances.new("Beam", {
			Attachment0 = attachments[index],
			Attachment1 = attachments[index + 1],
			Width0 = self._width,
			Width1 = self._width,
			FaceCamera = true,
			LightEmission = 1,
			LightInfluence = 0,
			Segments = 1,
			TextureMode = Enum.TextureMode.Stretch,
			Transparency = NumberSequence.new(PATH_TRANSPARENCY),
			Color = self._pathColor,
			Secure = true,
		}, self._holder) :: Beam
	end
end

function worldPath.Update(self: worldPath, points: { Vector3 }, pathColor: ColorSequence, impactColor: Color3): ()
	local count = #points

	if count < 2 then
		self:Hide()
		return
	end

	self:ensure(count)

	local attachments = self._attachments
	local beams = self._beams

	for index = 1, count do
		attachments[index].WorldPosition = points[index]
	end

	for index = 1, count - 1 do
		local beam = beams[index]
		beam.Color = pathColor
		beam.Enabled = true
	end

	for index = count, #beams do
		beams[index].Enabled = false
	end

	self._impact.Color = impactColor
	self._impact.CFrame = CFrame.new(points[count])
	self._impact.Transparency = 0.25
end

function worldPath.Hide(self: worldPath): ()
	for index = 1, #self._beams do
		self._beams[index].Enabled = false
	end
	self._impact.Transparency = 1
end

function worldPath.Destroy(self: worldPath): ()
	self._holder:Destroy()
	self._impact:Destroy()
	table.clear(self._attachments)
	table.clear(self._beams)
end

return worldPath
