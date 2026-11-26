local viewportThumb = {}

export type Thumb = {
	model: Model,
	center: Vector3,
	distance: number,
	pitch: number,
	yaw: number,
}

local FIELD_OF_VIEW = 40
local FIT_FACTOR = 1.08
local VIEW_PITCH = -0.22
local VIEW_YAW = 2.4
local MIN_DISTANCE = 1

local STRIP_SELECTOR = "ParticleEmitter, Beam, Trail, Smoke, Fire, Sparkles, Light, Sound, BaseScript, ModuleScript, LayerCollector, Attachment, JointInstance, Constraint"

viewportThumb.FIELD_OF_VIEW = FIELD_OF_VIEW

local function prepare(model: Model): number
	local strip = model:QueryDescendants(STRIP_SELECTOR)
	for index = 1, #strip do
		strip[index]:Destroy()
	end

	local parts = model:QueryDescendants("BasePart")
	for index = 1, #parts do
		local part = parts[index] :: BasePart
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Massless = true
	end
	return #parts
end

function viewportThumb.build(source: Instance): Thumb?
	local model = Instance.new("Model")
	local clone = source:Clone()
	clone.Parent = model

	if prepare(model) == 0 then
		model:Destroy()
		return nil
	end

	local bounds, size = model:GetBoundingBox()
	local radius = size.Magnitude * 0.5
	local distance = math.max(radius / math.tan(math.rad(FIELD_OF_VIEW * 0.5)) * FIT_FACTOR, MIN_DISTANCE)

	return {
		model = model,
		center = bounds.Position,
		distance = distance,
		pitch = VIEW_PITCH,
		yaw = VIEW_YAW,
	}
end

viewportThumb.cameraCFrame = LPH_NO_VIRTUALIZE(function(thumb: Thumb, yawOffset: number): CFrame
	local rotation = CFrame.fromEulerAnglesYXZ(thumb.pitch, thumb.yaw + yawOffset, 0)
	return CFrame.lookAt(thumb.center + rotation * Vector3.new(0, 0, thumb.distance), thumb.center)
end)

function viewportThumb.applyTexture(thumb: Thumb, textureId: string): ()
	local meshes = thumb.model:QueryDescendants("MeshPart")
	for index = 1, #meshes do
		(meshes[index] :: MeshPart).TextureID = textureId
	end
end

function viewportThumb.destroy(thumb: Thumb): ()
	thumb.model:Destroy()
end

return viewportThumb
