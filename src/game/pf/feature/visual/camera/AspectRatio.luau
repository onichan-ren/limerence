local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Ripple = require("@pkg/Ripple")
local hook = require("@share/hook")

local SPRING_CONFIG = {
	tension = 450,
	friction = 32,
	start = true,
	precision = 0.0005,
}

local IDENTITY = CFrame.identity

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
	self._multiplier = IDENTITY
	self._camera = nil

	local spring = Ripple.createSpring(1, SPRING_CONFIG)
	self._spring = spring
	spring:onChange(function(value: number): ()
		self._multiplier = CFrame.new(0, 0, 0, 1, 0, 0, 0, value, 0, 0, 0, 1)
	end)
	spring:onComplete(function(): ()
		if not self._enabled then
			self:_unhook()
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

	local conn = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function(): ()
		if self._enabled then
			self:_hook()
		end
	end)
	self:Track(function(): ()
		conn:Disconnect()
	end)

	return self
end

function AspectRatio._hook(self: AspectRatio): ()
	local camera = Workspace.CurrentCamera
	if not camera or camera == self._camera then
		return
	end
	self:_unhook()
	self._camera = camera
	hook.addInstance(camera)
	hook.overrideProperty(
		camera,
		"CFrame",
		LPH_NO_VIRTUALIZE(function(value: any): any
			if typeof(value) ~= "CFrame" then
				return value
			end
			return value * self._multiplier
		end)
	)
end

function AspectRatio._unhook(self: AspectRatio): ()
	local camera = self._camera
	if camera then
		hook.restoreProperty(camera, "CFrame")
		hook.restoreInstance(camera)
		self._camera = nil
	end
	self._multiplier = IDENTITY
end

function AspectRatio.Enable(self: AspectRatio): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._spring:setGoal(self._ratio)
	self:_hook()
end

function AspectRatio.Disable(self: AspectRatio): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._spring:setGoal(1)
end

function AspectRatio.Destroy(self: AspectRatio): ()
	self:_unhook()
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
			_multiplier: CFrame,
			_camera: any,
			_spring: any,
		},
		AspectRatio
	))
	& BaseFeature.BaseFeature

return AspectRatio
