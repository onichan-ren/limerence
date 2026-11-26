local Players = cloneref(game:GetService("Players")) :: Players
local RunService = cloneref(game:GetService("RunService")) :: RunService
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local ContentProvider = cloneref(game:GetService("ContentProvider")) :: ContentProvider

local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local Charm = require("@pkg/Charm")
local instances = require("@share/instances")
local EspState = require("@game/universal/feature/visual/esp/EspState")
local espCanvas = require("@game/universal/feature/visual/esp/espCanvas")
local espStateColors = require("@game/universal/feature/visual/esp/espStateColors")
local espSkeletonLines = require("@game/universal/feature/visual/esp/espSkeletonLines")
local screenProject = require("@share/screenProject")
local uiState = require("@feature/ui/uiState")
local windowState = require("@ui/window/windowState")

local e = React.createElement
local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe
local subscribeToBinding = (React :: any).__subscribeToBinding

local PREVIEW_USER_ID = -2147483647
local IDLE_ANIMATION_ID = "rbxassetid://10921259953"
local ORBIT_TARGET = Vector3.new(0, 0, 0)
local MODEL_LIFT = Vector3.new(0.1, 0.3, 0)
local DEFAULT_YAW = 180
local DEFAULT_PITCH = 0
local DEFAULT_ROTATE_SPEED = 60
local CAMERA_DISTANCE = 10
local DRAG_SENSITIVITY = 0.0075
local PITCH_LIMIT = 1.2
local PART_NAMES = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftHand",
	"RightHand",
	"LeftLowerArm",
	"RightLowerArm",
	"LeftUpperArm",
	"RightUpperArm",
	"LeftFoot",
	"RightFoot",
	"LeftLowerLeg",
	"RightLowerLeg",
	"LeftUpperLeg",
	"RightUpperLeg",
	"HumanoidRootPart",
}
local EMPTY_ATOM = at(nil)

local espPreview = {}
espPreview.__index = espPreview
espPreview.PREVIEW_USER_ID = PREVIEW_USER_ID

local function makeFakeBasePlayer(previewAtoms: { [string]: any }?): any
	local fake = {
		hrp = at(nil :: BasePart?),
		parts = at({} :: { [string]: BasePart }),
		character = at(nil :: Model?),
		health = at(100),
		maxHealth = at(100),
		alive = at(true),
		team = at(nil),
		isBot = true,
	}
	if previewAtoms then
		for key, value in next, previewAtoms do
			fake[key] = at(value)
		end
	end
	return setmetatable(fake, {
		__index = function(): any
			return EMPTY_ATOM
		end,
	})
end

local function buildSeedAtoms(previewAtoms: { [string]: any }?, controls: { ControlSpec }?): { [string]: any }
	local seed: { [string]: any } = {}
	if previewAtoms then
		for key, value in next, previewAtoms do
			seed[key] = value
		end
	end
	if controls then
		for _, spec in next, controls do
			local atomKey = spec.atomKey or spec.key
			local value = spec.default
			if spec.map then
				value = spec.map(value)
			end
			seed[atomKey] = value
		end
	end
	return seed
end

local function partsCenter(parts: { [string]: BasePart }): Vector3?
	local minV: Vector3?, maxV: Vector3? = nil, nil
	for _, part in next, parts do
		local half = part.Size * 0.5
		local lo = part.Position - half
		local hi = part.Position + half
		if not minV then
			minV, maxV = lo, hi
		else
			minV = (minV :: Vector3):Min(lo)
			maxV = (maxV :: Vector3):Max(hi)
		end
	end
	if minV and maxV then
		return (minV + maxV) * 0.5
	end
	return nil
end

local function focusPoint(hrp: BasePart?, parts: { [string]: BasePart }): Vector3?
	if not hrp then
		return partsCenter(parts)
	end
	local pos = hrp.Position
	local center = partsCenter(parts)
	if center then
		return Vector3.new(pos.X, center.Y, pos.Z)
	end
	return pos
end

function espPreview.new(opts: PreviewOpts): Preview
	local self = setmetatable({}, espPreview) :: any

	self._elements = opts.elements
	self._settings = opts.settings
	self._elementActive = opts.elementActive
	self._enabledAtom = opts.enabledAtom
	self._buildEntry = opts.buildEntry
	self._computeBounds = opts.computeBounds
	self._needsBoxLayout = opts.needsBoxLayout
	self._boundingActive = opts.boundingActive
	self._prepareCtx = opts.prepareCtx
	self._healthTextExtraLeft = opts.healthTextExtraLeft
	self._skelLines = nil :: { any }?
	self._skelLayer = nil :: Frame?
	self._previewLink = opts.previewLink
	self._modelProvider = opts.modelProvider
	self._applyState = opts.applyState
	self._onFrame = opts.onFrame
	self._onDestroy = opts.onDestroy
	self._resolveHrp = opts.resolveHrp
	self._resolveParts = opts.resolveParts
	self._managedModel = opts.managedModel == true
	self._despawnOnHide = opts.despawnOnHide == true
	self._offset = opts.offset
	self._cameraDistanceScale = opts.cameraDistanceScale ~= nil and opts.cameraDistanceScale or 1.35
	self._idleAnimationId = opts.idleAnimationId ~= nil and opts.idleAnimationId or IDLE_ANIMATION_ID
	self._controls = opts.previewControls
	self._controlValues = {} :: { [string]: any }
	self._controlElements = {} :: { [string]: any }
	self._controlUnsubs = {} :: { () -> () }

	self._basePlayer = makeFakeBasePlayer(buildSeedAtoms(opts.previewAtoms, opts.previewControls))
	local localName = "limerence.biz"
	self._player = {
		UserId = PREVIEW_USER_ID,
		Name = localName,
		DisplayName = localName,
	}
	self._player.GetPlayer = function(): any
		return self._player
	end

	self._state = EspState.new()
	self._entry = self._buildEntry(self._player, self._basePlayer, self._settings, self._elements)
	self._state:Set(self._player, self._entry)

	self._viewport = nil :: ViewportFrame?
	self._camera = nil :: Camera?
	self._worldModel = nil :: WorldModel?
	self._overlay = nil :: Frame?
	self._input = nil :: Frame?
	self._model = nil :: Model?
	self._root = nil :: any
	self._renderConn = nil :: RBXScriptConnection?
	self._yaw = math.rad(DEFAULT_YAW)
	self._pitch = DEFAULT_PITCH
	self._orbitTarget = ORBIT_TARGET
	self._orbitDistance = CAMERA_DISTANCE
	self._autoRotate = false
	self._rotateSpeedRad = math.rad(DEFAULT_ROTATE_SPEED)
	self._dragging = false
	self._lastMouse = Vector2.zero
	self._inputConns = {}
	self._generating = false
	self._modelGen = 0
	self._tracks = {}
	self._open = peek(uiState.isOpen)
	self._enabled = self._enabledAtom ~= nil and peek(self._enabledAtom) or false
	self._canvasShown = false

	self._previewTab = nil
	self._previewSubmenu = nil :: any
	local previewHost = self._previewLink and self._previewLink:Raw()
	if previewHost then
		self._previewTab = (previewHost :: any)._tab
	end

	espStateColors.SetPreviewUserId(PREVIEW_USER_ID)

	self:_buildControls()

	opts.previewLink:EspPreview("Preview", {
		onMount = function(parts: any): ()
			self:_onMount(parts)
		end,
		onUnmount = function(): ()
			self:_onUnmount()
		end,
		hasSettings = self._previewSubmenu ~= nil,
		settingsOpen = self._previewSubmenu and self._previewSubmenu._open,
		openSettings = function(position: UDim2?): ()
			if self._previewSubmenu then
				self._previewSubmenu:Open(position)
			end
		end,
	})

	self._openUnsub = sub(uiState.isOpen, function(open: boolean): ()
		self._open = open
		self:_apply()
	end)
	self._tabUnsub = sub(windowState.openTab, function(): ()
		self:_apply()
	end)
	if self._enabledAtom then
		self._enabledUnsub = sub(self._enabledAtom, function(enabled: boolean): ()
			self._enabled = enabled
			self:_apply()
		end)
	end

	return self
end

function espPreview._buildRotationControls(self: Preview, stateLink: any): ()
	local toggle = stateLink:Toggle("autoRotate", "Auto Rotate", false):SetTip({
		title = "Auto Rotate",
		body = "Spins the preview character on its own.",
	})
	local rotateLink = stateLink:OnKey("autoRotate")
	local speed = rotateLink:Slider("rotateSpeed", "Speed", DEFAULT_ROTATE_SPEED, 10, 360, 5, nil, "°/s"):SetTip({
		title = "Speed",
		body = "How fast the preview spins.",
	})

	self._autoRotate = peek(toggle._state) == true
	self._rotateSpeedRad = math.rad(peek(speed._state) :: number)

	self._controlUnsubs[#self._controlUnsubs + 1] = sub(toggle._state, function(value: boolean): ()
		self._autoRotate = value == true
	end)
	self._controlUnsubs[#self._controlUnsubs + 1] = sub(speed._state, function(value: number): ()
		self._rotateSpeedRad = math.rad(value)
	end)
end

function espPreview._buildControls(self: Preview): ()
	local previewLink = self._previewLink
	if not previewLink then
		return
	end

	local submenuElement = previewLink:Submenu("previewState", "Preview State")
	submenuElement:SetVisible(false)
	self._previewSubmenu = submenuElement
	local stateLink = previewLink:OnKey("previewState")

	self:_buildRotationControls(stateLink)

	local controls = self._controls
	if not controls then
		return
	end

	for _, spec in next, controls do
		local element
		if spec.type == "Dropdown" then
			element = stateLink:Dropdown(spec.key, spec.label, spec.options, spec.default)
		elseif spec.type == "Colorpicker" then
			element = stateLink:Colorpicker(spec.key, spec.label, spec.default)
		else
			element = stateLink:Toggle(spec.key, spec.label, spec.default == true)
		end
		if spec.tip then
			element:SetTip(spec.tip)
		end

		local atomKey = spec.atomKey or spec.key
		local map = spec.map
		self._controlElements[spec.key] = element

		local function handle(newValue: any): ()
			self._controlValues[spec.key] = newValue
			local mapped = newValue
			if map then
				mapped = map(newValue)
			end
			self:SetAtom(atomKey, mapped)
			self:_applyModelState()
		end

		local function seed(value: any): ()
			self._controlValues[spec.key] = value
			local mapped = value
			if map then
				mapped = map(value)
			end
			self:SetAtom(atomKey, mapped)
		end

		if spec.type == "Colorpicker" then
			local binding = element._currentColor
			seed((binding :: any):getValue())
			self._controlUnsubs[#self._controlUnsubs + 1] = subscribeToBinding(binding, handle)
		else
			seed(peek(element._state))
			self._controlUnsubs[#self._controlUnsubs + 1] = sub(element._state, handle)
		end
	end
end

function espPreview.SetAtom(self: Preview, key: string, value: any): ()
	local atom = rawget(self._basePlayer, key)
	if atom then
		atom(value)
	else
		self._basePlayer[key] = at(value)
	end
end

function espPreview._applyModelState(self: Preview): ()
	local applyState = self._applyState
	local model = self._model
	if applyState and model then
		applyState(model, self._controlValues)
	end
end

function espPreview._onMount(self: Preview, parts: any): ()
	self._viewport = parts.viewport
	self._camera = parts.camera
	self._worldModel = parts.worldModel
	self._overlay = parts.overlay
	self._input = parts.input

	self._root = ReactRoblox.createRoot(self._overlay :: Frame)
	self._canvasShown = false

	local skelState = self._entry and self._entry.skeleton
	if type(skelState) == "table" and skelState.lines and self._overlay and not self._skelLines then
		local layer = instances.new("Frame", {
			Name = "SkeletonLayer",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 2,
		}, self._overlay.Parent)
		self._skelLayer = layer
		local lines = skelState.lines
		for i = 1, #lines do
			espSkeletonLines.detach(lines[i], layer)
		end
		self._skelLines = lines
	end

	self:_bindInput()
	self:_apply()
end

function espPreview._bindInput(self: Preview): ()
	local input = self._input
	if not input then
		return
	end
	local conns = self._inputConns
	conns[#conns + 1] = input.MouseButton1Down:Connect(function(): ()
		if not self._open then
			return
		end
		self._dragging = true
		self._lastMouse = UserInputService:GetMouseLocation()
	end)
	conns[#conns + 1] = input.MouseButton1Up:Connect(function(): ()
		self._dragging = false
	end)
	conns[#conns + 1] = UserInputService.InputEnded:Connect(function(io: InputObject): ()
		if io.UserInputType == Enum.UserInputType.MouseButton1 then
			self._dragging = false
		end
	end)
end

function espPreview._unbindInput(self: Preview): ()
	for _, conn in next, self._inputConns do
		conn:Disconnect()
	end
	table.clear(self._inputConns)
	self._dragging = false
end

function espPreview._onUnmount(self: Preview): ()
	if self._renderConn then
		self._renderConn:Disconnect()
		self._renderConn = nil
	end
	self:_unbindInput()
	self:_despawnModel()
	if self._root then
		self._root:unmount()
		self._root = nil
	end
	if self._skelLayer then
		self._skelLayer:Destroy()
		self._skelLayer = nil
	end
	self._skelLines = nil
	self._canvasShown = false
	self._model = nil
	self._viewport = nil
	self._camera = nil
	self._worldModel = nil
	self._overlay = nil
	self._input = nil
end

function espPreview._ensureModel(self: Preview): ()
	if self._model or self._generating then
		return
	end
	self._generating = true
	local gen = self._modelGen
	task.spawn(function(): ()
		local model: any = nil

		local provider = self._modelProvider
		if provider then
			model = provider()
		else
			model = Players:CreateHumanoidModelFromUserId(Players.LocalPlayer.UserId)
		end

		if typeof(model) ~= "Instance" then
			self._generating = false
			return
		end
		if not self._worldModel or gen ~= self._modelGen then
			model:Destroy()
			self._generating = false
			if gen ~= self._modelGen and self._onDestroy then
				self._onDestroy()
			end
			return
		end
		if not self._managedModel then
			ContentProvider:PreloadAsync({ model })
		end
		self._generating = false
		if not self._worldModel or gen ~= self._modelGen then
			model:Destroy()
			if gen ~= self._modelGen and self._onDestroy then
				self._onDestroy()
			end
			return
		end
		self:_setupModel(model)
	end)
end

function espPreview._setupModel(self: Preview, model: Model): ()
	setthreadidentity(8)
	if self._model == model then
		return
	end
	local previous = self._model
	self._model = model
	model.Parent = self._worldModel
	if previous and previous ~= model and typeof(previous) == "Instance" then
		previous:Destroy()
	end

	local hrp = (self._resolveHrp and self._resolveHrp(model)) or model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not self._managedModel then
		if hrp then
			hrp.Anchored = true
			model.PrimaryPart = hrp
		end
		local faceYaw = math.rad(DEFAULT_YAW)
		model:PivotTo(CFrame.lookAt(MODEL_LIFT, MODEL_LIFT + Vector3.new(math.sin(faceYaw), 0, math.cos(faceYaw))))
	end

	local parts: { [string]: BasePart } = {}
	if self._managedModel and self._resolveParts then
		parts = self._resolveParts(model) or parts
	else
		for _, name in next, PART_NAMES do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				parts[name] = part
			end
		end
	end

	self._orbitTarget = focusPoint(hrp, parts) or self._orbitTarget

	self._basePlayer.character(model)
	self._basePlayer.hrp(hrp)
	self._basePlayer.parts(parts)

	if self._managedModel then
		self:_applyModelState()
		return
	end

	for _, desc in next, model:QueryDescendants("Motor6D") do
		desc.Transform = CFrame.identity
	end

	local animId = self._idleAnimationId
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and animId ~= "" then
		local animator = humanoid:FindFirstChildOfClass("Animator") or instances.new("Animator", {}, humanoid)
		local anim = instances.new("Animation", { AnimationId = animId })
		local track = (animator :: Animator):LoadAnimation(anim)
		if track then
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Idle
			track:Play()
			self._tracks[#self._tracks + 1] = track
		end
	end

	self:_applyModelState()
end

function espPreview._apply(self: Preview): ()
	setthreadidentity(8)
	local root = self._root
	if not root then
		return
	end

	if self._enabled and not self._canvasShown then
		root:render(e(espCanvas, {
			state = self._state,
			settings = self._settings,
			elements = self._elements,
			elementActive = self._elementActive,
		}))
		self._canvasShown = true
	elseif not self._enabled and self._canvasShown then
		root:render(nil)
		self._canvasShown = false
	end

	local shouldRun = self._open and self._overlay ~= nil and self._camera ~= nil and self:_tabActive()
	if shouldRun then
		self:_ensureModel()
		if not self._renderConn then
			self._renderConn = self:_startLoop()
		end
	else
		if self._renderConn then
			self._renderConn:Disconnect()
			self._renderConn = nil
		end
		if self._despawnOnHide then
			self:_despawnModel()
		end
	end
end

function espPreview._despawnModel(self: Preview): ()
	setthreadidentity(8)
	if not self._model and not self._generating then
		return
	end
	self._modelGen += 1
	if self._onDestroy then
		self._onDestroy()
	end
	if self._model then
		(self._model :: Model):Destroy()
		self._model = nil
	end
	self._generating = false
	self._basePlayer.character(nil)
	self._basePlayer.hrp(nil)
	self._basePlayer.parts({})
end

function espPreview._tabActive(self: Preview): boolean
	return self._previewTab == nil or peek(windowState.openTab) == self._previewTab
end

function espPreview._startLoop(self: Preview): RBXScriptConnection
	local entry = self._entry
	local elements = self._elements
	local settings = self._settings
	local elementActive = self._elementActive
	local basePlayer = self._basePlayer
	local offset = self._offset

	local render = LPH_NO_VIRTUALIZE(function(dt: number): ()
		local camera = self._camera
		local overlay = self._overlay
		if not camera or not overlay then
			return
		end

		if self._dragging then
			local cursor = UserInputService:GetMouseLocation()
			local last = self._lastMouse
			self._lastMouse = cursor
			self._yaw += (cursor.X - last.X) * DRAG_SENSITIVITY
			self._pitch = math.clamp(self._pitch + (cursor.Y - last.Y) * DRAG_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
		elseif self._autoRotate then
			self._yaw += self._rotateSpeedRad * dt
		end

		local target = self._orbitTarget
		local rot = CFrame.fromEulerAnglesYXZ(self._pitch, self._yaw, 0)
		camera.CFrame = CFrame.lookAt(target + rot * Vector3.new(0, 0, self._orbitDistance), target)

		local model = self._model
		if not model then
			return
		end

		if self._onFrame then
			local returned = self._onFrame(model, dt, self._controlValues)
			if typeof(returned) == "Instance" and returned ~= model then
				self:_setupModel(returned)
				return
			end
		end

		if self._managedModel then
			if self._worldModel and model.Parent ~= self._worldModel then
				model.Parent = self._worldModel
			end
			self._orbitTarget = focusPoint(peek(self._basePlayer.hrp), peek(self._basePlayer.parts))
				or self._orbitTarget
		end

		if not self._enabled then
			return
		end

		local viewport = overlay.AbsoluteSize
		if viewport.X <= 0 or viewport.Y <= 0 then
			return
		end

		local hrp = peek(basePlayer.hrp) :: BasePart?
		if not hrp then
			return
		end

		local project, pixelsPerStudUnit = screenProject.make(camera, viewport)
		local active = peek(elementActive)
		local needsBox = self._needsBoxLayout ~= nil and self._needsBoxLayout()
		local useBounding = needsBox and self._boundingActive ~= nil and self._boundingActive()

		local rootScreen = project(hrp.Position)
		local depth = rootScreen.Z
		local onScreen = depth > 0
		local hbExtraLeft = (needsBox and self._healthTextExtraLeft and self._healthTextExtraLeft()) or 0

		local stateBucket, stateVis = espStateColors.ResolveStateData(PREVIEW_USER_ID)

		local ctx = {
			basePlayer = basePlayer,
			hrp = hrp,
			camera = camera,
			camPos = camera.CFrame.Position,
			screen = rootScreen,
			depth = depth,
			pps = onScreen and pixelsPerStudUnit / depth or 0,
			visible = false,
			shouldShow = true,
			boxPosition = Vector2.zero,
			boxSize = Vector2.zero,
			alpha = 1,
			deathFading = false,
			dt = dt,
			elementAnimations = false,
			healthTextExtraLeft = 0,
			viewport = viewport,
			onScreen = onScreen,
			offscreenReady = false,
			userId = PREVIEW_USER_ID,
			stateBucket = stateBucket,
			dist = -1,
			extra = {},
		}

		if onScreen then
			ctx.visible = true
			if needsBox and self._computeBounds then
				local parts = peek(basePlayer.parts)
				local bounds = self._computeBounds(project, hrp, parts, pixelsPerStudUnit, useBounding)
				if bounds then
					ctx.screen = bounds.screen
					ctx.depth = bounds.depth
					ctx.pps = bounds.pps
					ctx.boxPosition = bounds.boxPosition
					ctx.boxSize = bounds.boxSize
					ctx.healthTextExtraLeft = hbExtraLeft
				end
			end
		end

		if offset and not useBounding and ctx.visible and ctx.pps > 0 then
			local dx = offset.X * ctx.pps
			local dy = offset.Y * ctx.pps
			ctx.boxPosition = ctx.boxPosition + Vector2.new(dx, dy)
			ctx.screen = ctx.screen + Vector3.new(dx, dy, 0)
		end

		local container = entry.__box
		if container and needsBox then
			if ctx.visible then
				container.position.set(ctx.boxPosition)
				container.size.set(ctx.boxSize)
				container.visible.set(true)
			else
				container.visible.set(false)
			end
		end

		if self._prepareCtx then
			self._prepareCtx(ctx, entry, active, settings)
		end

		for _, def in next, elements do
			if active[def.id] then
				if stateVis ~= nil and stateVis[def.id] == false then
					local v, o, r, a = ctx.visible, ctx.onScreen, ctx.offscreenReady, ctx.alpha
					ctx.visible, ctx.onScreen, ctx.offscreenReady, ctx.alpha = false, false, false, 0
					def.update(entry[def.id], ctx, settings[def.id])
					ctx.visible, ctx.onScreen, ctx.offscreenReady, ctx.alpha = v, o, r, a
				else
					def.update(entry[def.id], ctx, settings[def.id])
				end
			end
		end

		local skelLines = self._skelLines
		if skelLines then
			local invX = 1 / viewport.X
			local invY = 1 / viewport.Y
			for i = 1, #skelLines do
				espSkeletonLines.applyDetached(skelLines[i], project, invX, invY)
			end
		end
	end)

	return RunService.PreRender:Connect(render)
end

function espPreview.Destroy(self: Preview): ()
	if self._openUnsub then
		self._openUnsub()
		self._openUnsub = nil
	end
	if self._enabledUnsub then
		self._enabledUnsub()
		self._enabledUnsub = nil
	end
	if self._tabUnsub then
		self._tabUnsub()
		self._tabUnsub = nil
	end
	for _, unsub in next, self._controlUnsubs do
		unsub()
	end
	table.clear(self._controlUnsubs)
	if self._renderConn then
		self._renderConn:Disconnect()
		self._renderConn = nil
	end
	self:_unbindInput()
	if self._root then
		self._root:unmount()
		self._root = nil
	end
	for _, track in next, self._tracks do
		track:Stop()
	end
	if self._onDestroy then
		self._onDestroy()
	end
	if self._model then
		self._model:Destroy()
		self._model = nil
	end
	espStateColors.SetPreviewUserId(nil)
end

export type ControlSpec = {
	type: string,
	key: string,
	label: string,
	default: any,
	options: { string }?,
	atomKey: string?,
	map: ((value: any) -> any)?,
	tip: { title: string, body: string }?,
}

export type PreviewOpts = {
	elements: { any },
	settings: { [string]: any },
	elementActive: Charm.Atom<{ [string]: boolean }>,
	enabledAtom: Charm.Atom<boolean>?,
	previewAtoms: { [string]: any }?,
	previewControls: { ControlSpec }?,
	modelProvider: (() -> Model?)?,
	applyState: ((model: Model, states: { [string]: any }) -> ())?,
	onFrame: ((model: Model, dt: number, states: { [string]: any }) -> Model?)?,
	onDestroy: (() -> ())?,
	resolveHrp: ((model: Model) -> BasePart?)?,
	resolveParts: ((model: Model) -> { [string]: BasePart })?,
	managedModel: boolean?,
	despawnOnHide: boolean?,
	offset: Vector2?,
	cameraDistanceScale: number?,
	idleAnimationId: string?,
	previewLink: any,
	buildEntry: (player: any, basePlayer: any, settings: { [string]: any }, elements: { any }) -> any,
	computeBounds: ((
		project: (Vector3) -> Vector3,
		hrp: BasePart,
		parts: { [string]: BasePart },
		pps: number,
		useBounding: boolean
	) -> any)?,
	needsBoxLayout: (() -> boolean)?,
	boundingActive: (() -> boolean)?,
	prepareCtx: ((ctx: any, entry: any, elementActive: { [string]: boolean }, settings: { [string]: any }) -> ())?,
	healthTextExtraLeft: (() -> number)?,
}

export type Preview = typeof(setmetatable(
	{} :: {
		_elements: { any },
		_settings: { [string]: any },
		_elementActive: Charm.Atom<{ [string]: boolean }>,
		_enabledAtom: Charm.Atom<boolean>?,
		_buildEntry: any,
		_computeBounds: any,
		_needsBoxLayout: (() -> boolean)?,
		_boundingActive: (() -> boolean)?,
		_skelLines: { any }?,
		_skelLayer: Frame?,
		_prepareCtx: any,
		_healthTextExtraLeft: (() -> number)?,
		_previewLink: any,
		_modelProvider: (() -> Model?)?,
		_applyState: ((model: Model, states: { [string]: any }) -> ())?,
		_onFrame: ((model: Model, dt: number, states: { [string]: any }) -> Model?)?,
		_onDestroy: (() -> ())?,
		_resolveHrp: ((model: Model) -> BasePart?)?,
		_resolveParts: ((model: Model) -> { [string]: BasePart })?,
		_managedModel: boolean,
		_despawnOnHide: boolean,
		_offset: Vector2?,
		_modelGen: number,
		_idleAnimationId: string,
		_controls: { ControlSpec }?,
		_controlValues: { [string]: any },
		_controlElements: { [string]: any },
		_controlUnsubs: { () -> () },
		_basePlayer: any,
		_player: any,
		_state: EspState.EspState,
		_entry: any,
		_viewport: ViewportFrame?,
		_camera: Camera?,
		_worldModel: WorldModel?,
		_overlay: Frame?,
		_input: TextButton?,
		_model: Model?,
		_root: any,
		_renderConn: RBXScriptConnection?,
		_yaw: number,
		_pitch: number,
		_orbitTarget: Vector3,
		_orbitDistance: number,
		_cameraDistanceScale: number,
		_autoRotate: boolean,
		_rotateSpeedRad: number,
		_dragging: boolean,
		_lastMouse: Vector2,
		_inputConns: { RBXScriptConnection },
		_generating: boolean,
		_tracks: { any },
		_open: boolean,
		_enabled: boolean,
		_canvasShown: boolean,
		_openUnsub: (() -> ())?,
		_enabledUnsub: (() -> ())?,
		_tabUnsub: (() -> ())?,
		_previewTab: any,
		_previewSubmenu: any,
	},
	espPreview
))

return espPreview
