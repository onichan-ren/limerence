local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local PlayerController = require("@feature/player/PlayerController")
local Ripple = require("@pkg/Ripple")
local Signal = require("@pkg/Signal")
local React = require("@pkg/React")
local BaseFeature = require("@game/BaseFeature")
local instances = require("@share/instances")
local screenProject = require("@share/screenProject")
local skeletonBones = require("@game/universal/feature/visual/skeletonBones")
local gameUi = require("@game/gameUi")

local subscribeToBinding = (React :: any).__subscribeToBinding

local HIDDEN_UI = cloneref(gethui())

local mdeg = math.deg
local matan2 = math.atan2
local msqrt = math.sqrt

local NEAR_PLANE = 0.2
local DEFAULT_COLOR = Color3.fromRGB(195, 110, 110)

local POP_SPRING = {
	dampingRatio = 0.45,
	frequency = 3.5,
	precision = 0.01,
}

local FADE_SPRING = {
	tension = 950,
	friction = 55,
}

export type ConnectHit = (handler: (player: Player) -> ()) -> Signal.Connection

export type HitSkeletonsOpts = {
	connectHit: ConnectHit,
	body: string?,
	lastShotBody: string?,
	colorBody: string?,
	resolve: ((player: Player) -> any?)?,
}

type Line = {
	frame: Frame,
	from: Vector3,
	to: Vector3,
	thickness: number,
}

type Effect = {
	lines: { Line },
	spring: any,
	alpha: number,
	baseTransparency: number,
	unsubChange: () -> (),
	unsubColor: () -> (),
	decayThread: thread?,
	dying: boolean,
}

local DEFAULT_BODY = "Briefly draws the skeleton of a player at the point where you hit them."
local DEFAULT_LAST_SHOT_BODY = "Only show the skeleton for your most recent hit instead of stacking every hit."
local DEFAULT_COLOR_BODY = "Color of the hit skeleton lines."

local Hitskeletons = {}
Hitskeletons.__index = Hitskeletons

setmetatable(Hitskeletons, { __index = BaseFeature })

function Hitskeletons.new(link: gameUi.Linker, opts: HitSkeletonsOpts): Hitskeletons
	local self = BaseFeature.new() :: any
	setmetatable(self, Hitskeletons)

	self._effects = {} :: { [Effect]: true }
	self._connection = nil
	self._connectHit = opts.connectHit
	self._resolve = opts.resolve or PlayerController.Get
	self._gui = nil
	self._renderConn = nil

	link:Toggle("hitSkeletons", "Hit Skeletons", false):SetTip({
		title = "Hit Skeletons",
		body = opts.body or DEFAULT_BODY,
	})
	local hitSkeletonsLink = link:OnKey("hitSkeletons")
	hitSkeletonsLink:Submenu("opts", "Hit Skeletons Options")
	local optsLink = hitSkeletonsLink:OnKey("opts")
	optsLink:Toggle("lastShotOnly", "Last Shot Only", false):SetTip({
		title = "Last Shot Only",
		body = opts.lastShotBody or DEFAULT_LAST_SHOT_BODY,
	})
	optsLink:Slider("lifetime", "Lifetime", 1, 0.5, 5, 0.1, nil, "s"):SetTip({
		title = "Lifetime",
		body = "How long each hit skeleton stays on screen before fading.",
	})
	optsLink:Slider("thickness", "Thickness", 2, 1, 5, 1, nil, "px"):SetTip({
		title = "Thickness",
		body = "Line width in pixels.",
	})
	optsLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0):SetTip({
		title = "Color",
		body = opts.colorBody or DEFAULT_COLOR_BODY,
	})

	self:Track(link:Get("hitSkeletons"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self._optsLink = optsLink

	if link:Peek("hitSkeletons") then
		self:Enable()
	end

	return self
end

function Hitskeletons._ensureGui(self: Hitskeletons): ScreenGui
	local gui = self._gui
	if gui and gui.Parent then
		return gui
	end
	gui = instances.new("ScreenGui", {
		Name = "HitSkeletons",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 4,
		Secure = true,
	}, HIDDEN_UI) :: ScreenGui
	self._gui = gui
	return gui :: ScreenGui
end

local applyEffect = LPH_NO_VIRTUALIZE(function(project: screenProject.Projector, invX: number, invY: number, effect: Effect): ()
	local alpha = effect.alpha
	local transparency = effect.baseTransparency + (1 - alpha) * (1 - effect.baseTransparency)
	local lines = effect.lines
	for i = 1, #lines do
		local line = lines[i]
		local frame = line.frame

		local fromS = project(line.from)
		local toS = project(line.to)
		local fromDepth = fromS.Z
		local toDepth = toS.Z
		if fromDepth <= NEAR_PLANE and toDepth <= NEAR_PLANE then
			frame.Visible = false
			continue
		end

		if fromDepth <= NEAR_PLANE then
			local t = (toDepth - NEAR_PLANE) / (toDepth - fromDepth)
			fromS = project(line.to:Lerp(line.from, t))
		elseif toDepth <= NEAR_PLANE then
			local t = (fromDepth - NEAR_PLANE) / (fromDepth - toDepth)
			toS = project(line.from:Lerp(line.to, t))
		end

		local dx = toS.X - fromS.X
		local dy = toS.Y - fromS.Y
		local distance = msqrt(dx * dx + dy * dy)
		local thickness = line.thickness
		frame.Position = UDim2.new((fromS.X + toS.X) * 0.5 * invX, 0, (fromS.Y + toS.Y) * 0.5 * invY, 0)
		frame.Size = UDim2.new((distance + thickness) * invX, 0, 0, thickness)
		frame.Rotation = mdeg(matan2(dy, dx))
		frame.BackgroundTransparency = transparency
		frame.Visible = true
	end
end)

function Hitskeletons._updateRenderLoop(self: Hitskeletons): ()
	if next(self._effects) then
		if not self._renderConn then
			self._renderConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
				local camera = Workspace.CurrentCamera
				if not camera then
					return
				end
				local viewport = camera.ViewportSize
				local project = screenProject.make(camera, viewport)
				local invX = 1 / viewport.X
				local invY = 1 / viewport.Y
				for effect in next, self._effects do
					applyEffect(project, invX, invY, effect)
				end
			end))
		end
	elseif self._renderConn then
		self._renderConn:Disconnect()
		self._renderConn = nil
	end
end

function Hitskeletons.Enable(self: Hitskeletons): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._connection = self._connectHit(LPH_NO_VIRTUALIZE(function(player: Player): ()
		local playerData = self._resolve(player)
		if not playerData or not playerData:IsAlive() then
			return
		end

		local model = playerData:GetCharacter()
		if not model then
			return
		end

		if self._optsLink:Peek("lastShotOnly") then
			self:_clearEffects()
		end

		local sizes = (playerData :: any).GetPartSizes and (playerData :: any):GetPartSizes() or nil
		self:_spawnEffect(playerData:GetParts(), sizes)
	end)) :: any
end

function Hitskeletons.Disable(self: Hitskeletons): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end

	self:_clearEffects()
end

Hitskeletons._spawnEffect = LPH_NO_VIRTUALIZE(function(
	self: Hitskeletons,
	parts: { [string]: Instance },
	sizes: { [string]: Vector3 }?
): ()
	local edges = skeletonBones.pickEdges(parts)
	if not edges then
		return
	end

	local opts = self._optsLink
	local colorpicker: any = opts:Get("color")
	local colorBinding = colorpicker._currentColor
	local initialColor = (colorBinding :: any):getValue() :: Color3
	local baseTransparency = opts:PeekTransparency("color") or 0
	local lifetime = opts:Peek("lifetime") or 1
	local thickness = opts:Peek("thickness") or 2

	local gui = self:_ensureGui()
	local lines: { Line } = {}

	for _, edge in next, edges do
		local fromPos = skeletonBones.endpoint(parts, sizes, edge.a)
		local toPos = skeletonBones.endpoint(parts, sizes, edge.b)
		if not fromPos or not toPos then
			continue
		end

		local frame = instances.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = initialColor,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
			Size = UDim2.fromOffset(0, thickness),
			Secure = true,
		}, gui) :: Frame

		lines[#lines + 1] = {
			frame = frame,
			from = fromPos,
			to = toPos,
			thickness = thickness,
		}
	end

	if #lines == 0 then
		return
	end

	local spring = Ripple.createSpring(0, POP_SPRING)
	local effect: Effect = {
		lines = lines,
		spring = spring,
		alpha = 0,
		baseTransparency = baseTransparency,
		unsubChange = function() end,
		unsubColor = function() end,
		decayThread = nil,
		dying = false,
	}

	effect.unsubChange = spring:onChange(function(alpha: number): ()
		effect.alpha = math.clamp(alpha, 0, 1)
	end)

	effect.unsubColor = subscribeToBinding(colorBinding, function(value: Color3): ()
		for i = 1, #lines do
			lines[i].frame.BackgroundColor3 = value
		end
	end)

	self._effects[effect] = true
	self:_updateRenderLoop()

	spring:start()
	spring:setGoal(1)

	effect.decayThread = task.delay(lifetime, function(): ()
		effect.decayThread = nil
		self:_destroyEffect(effect)
	end)
end)

Hitskeletons._destroyEffect = LPH_NO_VIRTUALIZE(function(self: Hitskeletons, effect: Effect): ()
	if effect.dying then
		return
	end
	effect.dying = true

	local thread = effect.decayThread
	if thread then
		effect.decayThread = nil
		task.cancel(thread)
	end

	local spring = effect.spring
	spring:setGoal(0, FADE_SPRING)

	local disconnect: (() -> ())?
	disconnect = spring:onComplete(function(): ()
		if disconnect then
			disconnect()
			disconnect = nil
		end
		effect.unsubChange()
		effect.unsubColor()
		spring:destroy()
		for i = 1, #effect.lines do
			effect.lines[i].frame:Destroy()
		end
		self._effects[effect] = nil
		self:_updateRenderLoop()
	end)
end)

function Hitskeletons._clearEffects(self: Hitskeletons): ()
	for effect in next, self._effects do
		self:_destroyEffect(effect)
	end
end

function Hitskeletons.Destroy(self: Hitskeletons): ()
	self:Disable()
	if self._renderConn then
		self._renderConn:Disconnect()
		self._renderConn = nil
	end
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	BaseFeature.Destroy(self)
end

export type Hitskeletons =
	typeof(setmetatable(
		{} :: {
			_optsLink: gameUi.Linker,
			_connectHit: ConnectHit,
			_resolve: (player: Player) -> any?,
			_enabled: boolean,
			_connection: Signal.Connection?,
			_effects: { [Effect]: true },
			_gui: ScreenGui?,
			_renderConn: RBXScriptConnection?,
		},
		Hitskeletons
	))
	& BaseFeature.BaseFeature

return Hitskeletons
