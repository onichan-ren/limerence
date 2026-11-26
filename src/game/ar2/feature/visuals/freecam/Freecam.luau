local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local GuiService = cloneref(game:GetService("GuiService")) :: GuiService

local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local uiState = require("@feature/ui/uiState")

local peek = Charm.peek

local RENDER_NAME = "limerence.freecam"
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1
local LOOK_SENSITIVITY = 0.003490658503988659
local PITCH_LIMIT = 1.55
local WORLD_SET_INTERVAL = 1
local MAX_SPEED = 200
local DEFAULT_SPEED = 30
local DEFAULT_SMOOTHING = 12
local DEFAULT_FAST = 3
local VEC_ZERO = Vector3.zero

local Freecam = {}
Freecam.__index = Freecam

setmetatable(Freecam, { __index = BaseFeature })

function Freecam.new(link: gameUi.Linker): Freecam
	local self = BaseFeature.new() :: any
	setmetatable(self, Freecam)

	self._enabled = false
	self._camera = nil :: Camera?
	self._gameCamera = nil :: Camera?
	self._abstract = nil :: any
	self._camerasModule = nil :: any
	self._localPlayerModule = nil :: any
	self._worldModule = nil :: any
	self._inputConn = nil :: RBXScriptConnection?
	self._yaw = 0
	self._pitch = 0
	self._position = VEC_ZERO
	self._velocity = VEC_ZERO
	self._lastWorldSet = 0

	link:Toggle("freecam", "Free Cam", false):SetTip({
		title = "Free Cam",
		body = "Detaches your camera so you can fly around freely while your character stays put. Bind a key to toggle it.",
	})
	local freecamLink = link:OnKey("freecam")
	freecamLink:Submenu("opts", "Free Cam Options")
	local optsLink = freecamLink:OnKey("opts")
	optsLink:Slider("fastMultiplier", "Sprint Multiplier", DEFAULT_FAST, 1, 10, 0.5, nil, "x"):SetTip({
		title = "Sprint Multiplier",
		body = "Speed boost while holding Shift.",
	})
	optsLink:Slider("smoothing", "Smoothing", DEFAULT_SMOOTHING, 1, 30, 1):SetTip({
		title = "Smoothing",
		body = "How quickly the camera eases in and out of movement. Lower is floatier.",
	})
	optsLink:Slider("speed", "Speed", DEFAULT_SPEED, 1, 100, 1, nil, "%"):SetTip({
		title = "Speed",
		body = "How fast the camera flies.",
	})

	self._toggleElement = link:Get("freecam")
	self._speedLink = optsLink:Get("speed")
	self._smoothingLink = optsLink:Get("smoothing")
	self._fastLink = optsLink:Get("fastMultiplier")

	self:Track(self._toggleElement:OnChange(function(state: boolean): ()
		if state then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("freecam") then
		self:Enable()
	end

	return self
end

function Freecam._getCharacter(self: Freecam): any
	if not self._localPlayerModule then
		local m = ModuleController.GetModule("LocalPlayer")
		self._localPlayerModule = m and m.module
	end
	local module = self._localPlayerModule
	local getter = module and module.get
	local arPlayer = getter and getter()
	return arPlayer and arPlayer.Character or nil
end

function Freecam._getWorld(self: Freecam): any
	if not self._worldModule then
		local m = ModuleController.GetModule("World")
		self._worldModule = m and m.module
	end
	return self._worldModule
end

function Freecam.Enable(self: Freecam): ()
	if self._enabled then
		return
	end

	if not self._camerasModule then
		local m = ModuleController.GetModule("Cameras")
		self._camerasModule = m and m.module
	end
	local camerasModule = self._camerasModule
	if not camerasModule then
		self._toggleElement._state(false)
		return
	end

	local gameCamera = Workspace.CurrentCamera
	if not gameCamera then
		self._toggleElement._state(false)
		return
	end

	self._enabled = true
	self._gameCamera = gameCamera

	local startCFrame = gameCamera.CFrame
	local look = startCFrame.LookVector
	self._pitch = math.asin(math.clamp(look.Y, -1, 1))
	self._yaw = math.atan2(-look.X, -look.Z)
	self._position = startCFrame.Position
	self._velocity = VEC_ZERO
	self._lastWorldSet = os.clock()

	local abstract = camerasModule:GetCurrent()
	self._abstract = abstract
	if abstract then
		abstract.Enabled = false
	end

	local camera = Instance.new("Camera")
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = gameCamera.FieldOfView
	camera.CFrame = startCFrame
	camera.Focus = gameCamera.Focus
	camera.Parent = Workspace
	self._camera = camera

	Workspace.CurrentCamera = camera

	self._inputConn = UserInputService.InputChanged:Connect(LPH_NO_VIRTUALIZE(function(input: InputObject): ()
		if not self._enabled then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		if UserInputService.MouseBehavior == Enum.MouseBehavior.Default then
			return
		end
		local delta = input.Delta
		self._yaw -= delta.X * LOOK_SENSITIVITY
		self._pitch = math.clamp(self._pitch - delta.Y * LOOK_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
	end))

	RunService:BindToRenderStep(
		RENDER_NAME,
		RENDER_PRIORITY,
		LPH_NO_VIRTUALIZE(function(dt: number): ()
			local cam = self._camera
			if not cam then
				return
			end

			if Workspace.CurrentCamera ~= cam then
				self._toggleElement._state(false)
				return
			end

			local menuOpen = peek(uiState.isOpen) or GuiService.MenuIsOpen
			UserInputService.MouseBehavior = menuOpen and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter

			local cf = CFrame.fromEulerAnglesYXZ(self._pitch, self._yaw, 0)

			local wish = VEC_ZERO
			if not menuOpen and not UserInputService:GetFocusedTextBox() then
				local forward = (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
					- (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
				local strafe = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
					- (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
				local rise = (UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0)
					- (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and 1 or 0)

				wish = cf.LookVector * forward + cf.RightVector * strafe + Vector3.yAxis * rise
				if wish.Magnitude > 1 then
					wish = wish.Unit
				end

				local speed = (self._speedLink:Peek() or DEFAULT_SPEED) / 100 * MAX_SPEED
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
					speed *= self._fastLink:Peek() or DEFAULT_FAST
				end
				wish *= speed
			end

			local smoothing = self._smoothingLink:Peek() or DEFAULT_SMOOTHING
			local alpha = 1 - math.exp(-dt * smoothing)
			self._velocity = self._velocity:Lerp(wish, alpha)
			self._position += self._velocity * dt

			local final = cf + self._position
			cam.CFrame = final
			cam.Focus = final * CFrame.new(0, 0, -4)

			local character = self:_getCharacter()
			if character then
				character.MoveVector = VEC_ZERO
			end

			local now = os.clock()
			if now - self._lastWorldSet > WORLD_SET_INTERVAL then
				self._lastWorldSet = now
				local world = self:_getWorld()
				if world then
					world:Set(self._position, "Camera", 1)
				end
			end
		end)
	)
end

function Freecam.Disable(self: Freecam): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	RunService:UnbindFromRenderStep(RENDER_NAME)

	if self._inputConn then
		self._inputConn:Disconnect()
		self._inputConn = nil
	end

	local camera = self._camera
	self._camera = nil

	local gameCamera = self._gameCamera
	self._gameCamera = nil

	if camera and Workspace.CurrentCamera == camera and gameCamera then
		gameCamera.Parent = Workspace
		Workspace.CurrentCamera = gameCamera
	end

	local abstract = self._abstract
	self._abstract = nil
	if abstract and self._camerasModule and self._camerasModule:GetCurrent() == abstract then
		abstract.Enabled = true
	end

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	if camera then
		camera:Destroy()
	end
end

function Freecam.Destroy(self: Freecam): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type Freecam =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_camera: Camera?,
			_gameCamera: Camera?,
			_abstract: any,
			_camerasModule: any,
			_localPlayerModule: any,
			_worldModule: any,
			_inputConn: RBXScriptConnection?,
			_yaw: number,
			_pitch: number,
			_position: Vector3,
			_velocity: Vector3,
			_lastWorldSet: number,
			_toggleElement: any,
			_speedLink: any,
			_smoothingLink: any,
			_fastLink: any,
			_getCharacter: (Freecam) -> any,
			_getWorld: (Freecam) -> any,
			Enable: (Freecam) -> (),
			Disable: (Freecam) -> (),
		},
		Freecam
	))
	& BaseFeature.BaseFeature

return Freecam
