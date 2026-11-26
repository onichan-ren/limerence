local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Ripple = require("@pkg/Ripple")

local BIND_NAME = "limerence_aspectRatio"
local BIND_PRIORITY = Enum.RenderPriority.Camera.Value + 1
local SPRING_CONFIG = {
	tension = 450,
	friction = 32,
	start = true,
	precision = 0.0005,
}

local cfnew = CFrame.new
local IDENTITY = cfnew(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)

local AspectRatio = {}
AspectRatio.__index = AspectRatio

setmetatable(AspectRatio, { __index = BaseFeature })

function AspectRatio.new(link: gameUi.Linker): AspectRatio
	local self = BaseFeature.new() :: any
	setmetatable(self, AspectRatio)

	local toggle = link:Toggle("aspectRatio", "Aspect Ratio", false):SetTip({
		title = "Aspect Ratio",
		body = "Stretches your view like it would on your monitor.",
	})
	local aspectLink = link:OnKey("aspectRatio")
	aspectLink:Submenu("opts", "Aspect Ratio Options")
	local optsLink = aspectLink:OnKey("opts")
	optsLink:Slider("ratio", "Stretch", 70, 30, 120, 1, nil, "%"):SetTip({
		title = "Stretch",
		body = "How much the view is stretched. 100% is off.",
	})

	self._enabled = false
	self._ratio = optsLink:Get("ratio"):Peek() / 100
	self._current = 1
	self._multiplier = IDENTITY
	self._bound = false

	local spring = Ripple.createSpring(1, SPRING_CONFIG)
	self._spring = spring
	spring:onChange(function(value: number): ()
		self._current = value
		self._multiplier = cfnew(0, 0, 0, 1, 0, 0, 0, value, 0, 0, 0, 1)
	end)
	spring:onComplete(function(): ()
		if not self._enabled then
			self:_disconnect()
		end
	end)

	self:Track(toggle:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optsLink:Get("ratio"):OnChange(function(value: number): ()
		self._ratio = value / 100
		if self._enabled then
			self._spring:setGoal(self._ratio)
		end
	end))

	return self
end

AspectRatio._step = LPH_NO_VIRTUALIZE(function(self: AspectRatio): ()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CFrame = camera.CFrame * self._multiplier
	end
end)

function AspectRatio._connect(self: AspectRatio): ()
	if self._bound then
		return
	end
	self._bound = true
	RunService:BindToRenderStep(
		BIND_NAME,
		BIND_PRIORITY,
		LPH_NO_VIRTUALIZE(function(): ()
			self:_step()
		end)
	)
end

function AspectRatio._disconnect(self: AspectRatio): ()
	if self._bound then
		RunService:UnbindFromRenderStep(BIND_NAME)
		self._bound = false
	end
	self._current = 1
	self._multiplier = IDENTITY
end

function AspectRatio.Enable(self: AspectRatio): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._spring:setGoal(self._ratio)
	self:_connect()
end

function AspectRatio.Disable(self: AspectRatio): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._spring:setGoal(1)
end

function AspectRatio.Destroy(self: AspectRatio): ()
	self:_disconnect()
	if self._spring then
		self._spring:destroy()
		self._spring = nil
	end
	BaseFeature.Destroy(self)
end

export type AspectRatio =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_ratio: number,
			_current: number,
			_multiplier: CFrame,
			_spring: any,
			_bound: boolean,
		},
		AspectRatio
	))
	& BaseFeature.BaseFeature

return AspectRatio
