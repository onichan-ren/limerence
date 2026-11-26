local RunService = cloneref(game:GetService("RunService")) :: RunService
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local MIN_DISTANCE = 1.5
local MAX_DISTANCE = 40
local ZOOM_STEP = 0.6
local DRAG_SENSITIVITY = 0.0075
local PITCH_LIMIT = 1.2
local AUTO_ROTATE_SPEED = 0.6
local FIT_FACTOR = 1.55

local modelPreview = {}
modelPreview.__index = modelPreview

export type MountParts = {
	viewport: ViewportFrame,
	camera: Camera,
	worldModel: WorldModel,
	input: GuiObject,
}

export type ModelPreview = typeof(setmetatable(
	{} :: {
		_camera: Camera?,
		_worldModel: WorldModel?,
		_model: Model?,
		_renderConn: RBXScriptConnection?,
		_downConn: RBXScriptConnection?,
		_upConn: RBXScriptConnection?,
		_scrollConn: RBXScriptConnection?,
		_yaw: number,
		_pitch: number,
		_distance: number,
		_minDistance: number,
		_maxDistance: number,
		_autoRotate: boolean,
		_dragging: boolean,
		_lastMouse: Vector2,
		_orbitTarget: Vector3,
		_pendingModel: Model?,
		_render: (ModelPreview, number) -> (),
	},
	modelPreview
))

function modelPreview.new(): ModelPreview
	return setmetatable({
		_camera = nil :: Camera?,
		_worldModel = nil :: WorldModel?,
		_model = nil :: Model?,
		_renderConn = nil :: RBXScriptConnection?,
		_downConn = nil :: RBXScriptConnection?,
		_upConn = nil :: RBXScriptConnection?,
		_scrollConn = nil :: RBXScriptConnection?,
		_yaw = math.rad(200),
		_pitch = -0.15,
		_distance = 6,
		_minDistance = MIN_DISTANCE,
		_maxDistance = MAX_DISTANCE,
		_autoRotate = true,
		_dragging = false,
		_lastMouse = Vector2.zero,
		_orbitTarget = Vector3.zero,
		_pendingModel = nil :: Model?,
	}, modelPreview) :: any
end

function modelPreview.mount(self: ModelPreview, parts: MountParts): ()
	self._camera = parts.camera
	self._worldModel = parts.worldModel
	parts.viewport.CurrentCamera = parts.camera

	self._downConn = parts.input.InputBegan:Connect(function(io: InputObject): ()
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			self._dragging = true
			self._autoRotate = false
			self._lastMouse = UserInputService:GetMouseLocation()
		end
	end)
	self._upConn = UserInputService.InputEnded:Connect(function(io: InputObject): ()
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			self._dragging = false
		end
	end)
	self._scrollConn = parts.input.InputChanged:Connect(function(io: InputObject): ()
		if io.UserInputType == Enum.UserInputType.MouseWheel then
			self._distance =
				math.clamp(self._distance - io.Position.Z * ZOOM_STEP, self._minDistance, self._maxDistance)
		end
	end)
	self._renderConn = RunService.PreRender:Connect(function(dt: number): ()
		self:_render(dt)
	end)

	if self._pendingModel then
		local pending = self._pendingModel
		self._pendingModel = nil
		self:setModel(pending)
	end
end

modelPreview._render = LPH_NO_VIRTUALIZE(function(self: ModelPreview, dt: number): ()
	local camera = self._camera
	if not camera then
		return
	end
	if self._dragging then
		local current = UserInputService:GetMouseLocation()
		local last = self._lastMouse
		self._lastMouse = current
		self._yaw += (current.X - last.X) * DRAG_SENSITIVITY
		self._pitch = math.clamp(self._pitch + (current.Y - last.Y) * DRAG_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
	elseif self._autoRotate then
		self._yaw += dt * AUTO_ROTATE_SPEED
	end
	local rot = CFrame.fromEulerAnglesYXZ(self._pitch, self._yaw, 0)
	camera.CFrame = CFrame.lookAt(self._orbitTarget + rot * Vector3.new(0, 0, self._distance), self._orbitTarget)
end)

function modelPreview.setModel(self: ModelPreview, model: Model?): ()
	if not self._worldModel then
		if self._pendingModel then
			self._pendingModel:Destroy()
		end
		self._pendingModel = model
		return
	end

	local previous = self._model
	self._model = model

	if model then
		for _, part in next, model:QueryDescendants("BasePart") do
			(part :: BasePart).Anchored = true
		end
		model.Parent = self._worldModel

		local boundsCFrame, boundsSize = model:GetBoundingBox()
		self._orbitTarget = boundsCFrame.Position
		local extent = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z, 0.5)
		local fit = extent * FIT_FACTOR
		self._minDistance = math.max(extent * 0.45, MIN_DISTANCE * 0.25)
		self._maxDistance = math.max(fit * 3, MAX_DISTANCE)
		self._distance = math.clamp(fit, self._minDistance, self._maxDistance)
	end

	if previous then
		previous:Destroy()
	end
end

function modelPreview.unmount(self: ModelPreview): ()
	if self._renderConn then
		self._renderConn:Disconnect()
		self._renderConn = nil
	end
	if self._downConn then
		self._downConn:Disconnect()
		self._downConn = nil
	end
	if self._upConn then
		self._upConn:Disconnect()
		self._upConn = nil
	end
	if self._scrollConn then
		self._scrollConn:Disconnect()
		self._scrollConn = nil
	end
	if self._model then
		self._model:Destroy()
		self._model = nil
	end
	if self._pendingModel then
		self._pendingModel:Destroy()
		self._pendingModel = nil
	end
	self._camera = nil
	self._worldModel = nil
end

return modelPreview
