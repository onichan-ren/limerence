local Players = cloneref(game:GetService("Players")) :: Players
local RunService = cloneref(game:GetService("RunService")) :: RunService
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local AvatarEditorService = cloneref(game:GetService("AvatarEditorService")) :: AvatarEditorService

local characterDescription = require("@game/universal/feature/misc/characterDescription")
local logger = require("@share/logger").new("charPreview")

local ANIMATION_PACK_ID = 356
local IDLE_ANIMATION = "rbxassetid://10921259953"

local resolvedPackIdle: string? = nil

local function resolvePlayableIdle(pieceId: number): string?
	local ok, objs = pcall(function(): { Instance }
		return (game :: any):GetObjects(`rbxassetid://{pieceId}`)
	end)
	if not ok or type(objs) ~= "table" then
		logger:warn("GetObjects failed for piece", pieceId, objs)
		return nil
	end
	local primary: string? = nil
	local fallback: string? = nil
	for i = 1, #objs do
		for _, node in objs[i]:QueryDescendants("Animation") do
			local anim = node :: Animation
			local id = string.match(anim.AnimationId, "%d+")
			if id then
				if anim.Name == "Animation1" then
					primary = `rbxassetid://{id}`
				elseif not fallback and not string.find(string.lower(anim.Name), "pose") then
					fallback = `rbxassetid://{id}`
				end
			end
		end
		objs[i]:Destroy()
	end
	return primary or fallback
end

local function packIdleAnimation(): string
	if ANIMATION_PACK_ID == 0 then
		return IDLE_ANIMATION
	end
	if resolvedPackIdle == nil then
		resolvedPackIdle = ""
		logger:log("resolving animation pack", ANIMATION_PACK_ID)
		local ok, details = pcall(function(): any
			return AvatarEditorService:GetItemDetails(ANIMATION_PACK_ID, Enum.AvatarItemType.Bundle)
		end)
		if not ok then
			logger:warn("GetItemDetails threw:", details)
		end
		local items = ok and type(details) == "table" and (details.Items or details.BundledItems)
		local pieceId: number? = nil
		if type(items) == "table" then
			for i = 1, #items do
				local item = items[i]
				if type(item) == "table" and type(item.Id) == "number" and item.AssetType == "IdleAnimation" then
					pieceId = item.Id
					break
				end
			end
		else
			logger:warn("no Items/BundledItems array on details")
		end
		if not pieceId then
			logger:warn("no IdleAnimation piece in pack", ANIMATION_PACK_ID)
		else
			local playable = resolvePlayableIdle(pieceId)
			if playable then
				resolvedPackIdle = playable
				logger:log("pack idle resolved", ANIMATION_PACK_ID, "->", playable)
			else
				logger:warn("could not unwrap idle piece", pieceId)
			end
		end
	end
	return if resolvedPackIdle ~= "" then resolvedPackIdle else IDLE_ANIMATION
end
local ORBIT_DISTANCE = 9
local MIN_DISTANCE = 4.5
local MAX_DISTANCE = 20
local ZOOM_STEP = 1.25
local ORBIT_TARGET = Vector3.new(0, 2.6, 0)
local MODEL_LIFT = Vector3.new(0, 0.1, 0)
local DRAG_SENSITIVITY = 0.0075
local PITCH_LIMIT = 1.2
local AUTO_ROTATE_SPEED = 0.6

local preview = {}
preview.__index = preview

function preview.new(): Preview
	return setmetatable({
		_viewport = nil :: ViewportFrame?,
		_camera = nil :: Camera?,
		_worldModel = nil :: WorldModel?,
		_input = nil :: GuiObject?,
		_model = nil :: Model?,
		_renderConn = nil :: RBXScriptConnection?,
		_downConn = nil :: RBXScriptConnection?,
		_upConn = nil :: RBXScriptConnection?,
		_scrollConn = nil :: RBXScriptConnection?,
		_tracks = {} :: { AnimationTrack },
		_yaw = math.rad(180),
		_pitch = 0,
		_distance = ORBIT_DISTANCE,
		_autoRotate = true,
		_dragging = false,
		_lastMouse = Vector2.zero,
		_gen = 0,
		_orbitTarget = ORBIT_TARGET,
		_pendingManifest = nil :: { [string]: any }?,
		_rigType = "R15",
	}, preview) :: any
end

function preview.mount(
	self: Preview,
	parts: { viewport: ViewportFrame, camera: Camera, worldModel: WorldModel, input: GuiObject }
): ()
	self._viewport = parts.viewport
	self._camera = parts.camera
	self._worldModel = parts.worldModel
	self._input = parts.input
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
			self._distance = math.clamp(self._distance - io.Position.Z * ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)
		end
	end)
	self._renderConn = RunService.PreRender:Connect(function(dt: number): ()
		self:_render(dt)
	end)

	if self._pendingManifest then
		self:setManifest(self._pendingManifest)
	end
end

preview._render = LPH_NO_VIRTUALIZE(function(self: Preview, dt: number): ()
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
	local target = self._orbitTarget
	local rot = CFrame.fromEulerAnglesYXZ(self._pitch, self._yaw, 0)
	camera.CFrame = CFrame.lookAt(target + rot * Vector3.new(0, 0, self._distance), target)
end)

function preview.setManifest(self: Preview, manifest: { [string]: any }, rigType: string?): ()
	self._pendingManifest = manifest
	if rigType then
		self._rigType = rigType
	end
	if not self._worldModel then
		return
	end
	self._gen += 1
	local gen = self._gen
	local rig = if self._rigType == "R6" then Enum.HumanoidRigType.R6 else Enum.HumanoidRigType.R15
	logger:log("setManifest rig:", self._rigType, "gen:", gen)
	task.spawn(function(): ()
		setthreadidentity(8)
		local desc = characterDescription.deserialize(manifest)
		local ok, model = pcall(function(): Model
			return Players:CreateHumanoidModelFromDescriptionAsync(desc, rig)
		end)
		if not ok then
			logger:warn("CreateHumanoidModelFromDescriptionAsync failed:", model)
			return
		end
		if not model or gen ~= self._gen or not self._worldModel then
			logger:debug("model stale/missing, gen:", gen, "current:", self._gen)
			if model then
				model:Destroy()
			end
			return
		end
		self:_swapModel(model)
	end)
end

function preview._swapModel(self: Preview, model: Model): ()
	local previous = self._model
	self._model = model

	for i = 1, #self._tracks do
		pcall(function(): ()
			self._tracks[i]:Stop()
		end)
	end
	table.clear(self._tracks)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.Anchored = true
		model.PrimaryPart = hrp
	end
	model:PivotTo(CFrame.new(MODEL_LIFT) * CFrame.Angles(0, math.rad(180), 0))
	model.Parent = self._worldModel

	local minY, maxY = math.huge, -math.huge
	for _, part in next, model:QueryDescendants("BasePart") do
		local y = part.Position.Y
		if y < minY then
			minY = y
		end
		if y > maxY then
			maxY = y
		end
	end
	if minY <= maxY then
		local pivot = model:GetPivot().Position
		self._orbitTarget = Vector3.new(pivot.X, (minY + maxY) * 0.5, pivot.Z)
	end

	if previous then
		previous:Destroy()
	end

	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = packIdleAnimation()
		logger:log("loading idle animation", anim.AnimationId)
		local trackOk, track = pcall(function(): AnimationTrack
			return (animator :: Animator):LoadAnimation(anim)
		end)
		if not trackOk then
			logger:warn("LoadAnimation failed:", track)
		end
		if trackOk and track then
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Idle
			track:Play()
			logger:debug("idle track playing", anim.AnimationId)
			self._tracks[#self._tracks + 1] = track
		end
	else
		logger:warn("swapped model has no Humanoid, cannot animate")
	end
end

function preview.unmount(self: Preview): ()
	self._gen += 1
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
	table.clear(self._tracks)
	self._viewport = nil
	self._camera = nil
	self._worldModel = nil
	self._input = nil
end

export type Preview = typeof(setmetatable(
	{} :: {
		_viewport: ViewportFrame?,
		_camera: Camera?,
		_worldModel: WorldModel?,
		_input: GuiObject?,
		_model: Model?,
		_renderConn: RBXScriptConnection?,
		_downConn: RBXScriptConnection?,
		_upConn: RBXScriptConnection?,
		_scrollConn: RBXScriptConnection?,
		_tracks: { AnimationTrack },
		_yaw: number,
		_pitch: number,
		_distance: number,
		_autoRotate: boolean,
		_dragging: boolean,
		_lastMouse: Vector2,
		_gen: number,
		_orbitTarget: Vector3,
		_pendingManifest: { [string]: any }?,
		_rigType: string,
		_render: (Preview, number) -> (),
		_swapModel: (Preview, Model) -> (),
	},
	preview
))

return preview
