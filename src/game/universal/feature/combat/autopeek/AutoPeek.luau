local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local instances = require("@share/instances")
local Ripple = require("@pkg/Ripple")
local autoPeekState = require("@game/universal/feature/combat/autopeek/autoPeekState")
require("@game/universal/feature/combat/autopeek/autoPeekApi")

local MARKER_SIZE = 2.8
local MARKER_THICKNESS = 0.01
local MOVE_STOP_DISTANCE = 0.4
local SPRING_CONFIG = {
	tension = 1000,
	friction = 60,
	start = true,
	precision = 0.01,
}
local DEFAULT_MARKER_COLOR = Color3.fromRGB(133, 241, 114)
local DEFAULT_RETREAT_COLOR = Color3.fromRGB(220, 190, 110)

export type RetreatContext = {
	getHrp: () -> BasePart?,
	savedPosition: Vector3,
	stopDistance: number,
	shouldRun: () -> boolean,
	arrive: () -> (),
	flatDelta: () -> Vector3?,
	crossedCenter: () -> boolean,
}

export type AutoPeekOpts = {
	getHrp: () -> BasePart?,
	connectShot: (fire: () -> ()) -> () -> (),
	teleport: ((savedCFrame: CFrame) -> ())?,
	startMove: ((ctx: RetreatContext) -> () -> ())?,
}

local AutoPeek = {}
AutoPeek.__index = AutoPeek

setmetatable(AutoPeek, { __index = BaseFeature })

function AutoPeek.new(link: gameUi.Linker, opts: AutoPeekOpts): AutoPeek
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoPeek)

	self._getHrp = opts.getHrp
	self._connectShot = opts.connectShot
	self._teleport = opts.teleport
	self._startMove = opts.startMove
	self._hasTeleport = opts.teleport ~= nil
	self._hasMove = opts.startMove ~= nil

	link:Toggle("autoPeek", "Auto Peek", false):SetTip({
		title = "Auto Peek",
		body = "Saves your starting position and returns you there after you shoot.",
	})

	local masterLink = link:OnKey("autoPeek")
	masterLink:Submenu("opts", "Auto Peek")
	local optsLink = masterLink:OnKey("opts")
	if self._hasTeleport and self._hasMove then
		optsLink:Dropdown("method", "Retreat Method", { "Teleport", "Move" }, "Teleport"):SetTip({
			title = "Retreat Method",
			body = "Choose whether auto peek returns by teleporting or by walking.",
		})
	end
	optsLink:Slider("maxDistance", "Max Distance", 80, 10, 150, 1, nil, "st"):SetTip({
		title = "Max Distance",
		body = "Skip the return if you have moved further than this from the saved spot.",
	})
	optsLink:Toggle("onRelease", "On Release", false):SetTip({
		title = "On Release",
		body = "Return to the saved spot when you let go of the key.",
	})
	optsLink:Submenu("colors", "Colors")
	local colorsLink = optsLink:OnKey("colors")
	colorsLink:Colorpicker("outlineColor", "Outline Color", Color3.fromRGB(133, 241, 114), 0):SetTip({
		title = "Outline Color",
		body = "Color of the auto peek marker outline.",
	})
	colorsLink:Colorpicker("fillColor", "Fill Color", Color3.fromRGB(133, 241, 114), 0.5):SetTip({
		title = "Fill Color",
		body = "Color of the auto peek marker fill.",
	})
	colorsLink:Colorpicker("retreatColor", "Retreat Color", DEFAULT_RETREAT_COLOR, 0):SetTip({
		title = "Retreat Color",
		body = "Color the marker springs toward while retreating.",
	})

	self._janitor = Janitor.new()
	self._enabled = false
	self._armed = false
	self._retreating = false
	self._releaseRetreating = false
	self._destroying = false
	self._enabledLink = link:Get("autoPeek")
	self._optsLink = optsLink
	self._maxDistance = optsLink:Peek("maxDistance") or 80
	self._savedCFrame = nil
	self._savedGroundPosition = nil
	self._markerAlpha = 1
	self._retreatBlend = 0
	self._fillTransparency = colorsLink:PeekTransparency("fillColor") or 0.5
	self._outlineTransparency = colorsLink:PeekTransparency("outlineColor") or 0
	self._fillColor = colorsLink:Get("fillColor"):PeekColor() or DEFAULT_MARKER_COLOR
	self._outlineColor = colorsLink:Get("outlineColor"):PeekColor() or DEFAULT_MARKER_COLOR
	self._retreatColor = colorsLink:Get("retreatColor"):PeekColor() or DEFAULT_RETREAT_COLOR
	self._circle = instances.new("Part", {
		Secure = true,
		Size = Vector3.new(MARKER_SIZE, MARKER_THICKNESS, MARKER_SIZE),
		Material = Enum.Material.Glass,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Anchored = true,
	})

	instances.newSimple("CylinderMesh", {
		Parent = self._circle,
		Name = "",
	})

	self._highlight = instances.newSimple("Highlight", {
		Parent = self._circle,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		Adornee = self._circle,
		FillColor = self._fillColor,
		FillTransparency = 1,
		OutlineColor = self._outlineColor,
		OutlineTransparency = 1,
	})

	self._highlight.Parent = cloneref(gethui())

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optsLink:Get("maxDistance"):OnChange(function(value: number): ()
		self._maxDistance = value
	end))

	self:Track(colorsLink:Get("outlineColor"):OnTransparencyChange(function(value: number): ()
		self._outlineTransparency = value
		self:_applyMarkerAlpha(self._markerAlpha)
	end))
	self:Track(colorsLink:Get("fillColor"):OnTransparencyChange(function(value: number): ()
		self._fillTransparency = value
		self:_applyMarkerAlpha(self._markerAlpha)
	end))
	self:Track(colorsLink:Get("outlineColor"):OnColorChange(function(value: Color3): ()
		self._outlineColor = value
		self:_applyMarkerColorBlend(self._retreatBlend)
	end))
	self:Track(colorsLink:Get("fillColor"):OnColorChange(function(value: Color3): ()
		self._fillColor = value
		self:_applyMarkerColorBlend(self._retreatBlend)
	end))
	self:Track(colorsLink:Get("retreatColor"):OnColorChange(function(value: Color3): ()
		self._retreatColor = value
		self:_applyMarkerColorBlend(self._retreatBlend)
	end))

	autoPeekState.current = self

	return self
end

function AutoPeek._active(self: AutoPeek): boolean
	return self._enabled or self._armed
end

function AutoPeek._resolveMethod(self: AutoPeek): string
	if self._hasTeleport and self._hasMove then
		return self._optsLink:Peek("method") or "Teleport"
	elseif self._hasMove then
		return "Move"
	end
	return "Teleport"
end

function AutoPeek._applyMarkerColorBlend(self: AutoPeek, blend: number): ()
	self._retreatBlend = math.clamp(blend, 0, 1)
	self._highlight.FillColor = self._fillColor:Lerp(self._retreatColor, self._retreatBlend)
	self._highlight.OutlineColor = self._outlineColor:Lerp(self._retreatColor, self._retreatBlend)
end

function AutoPeek._applyMarkerAlpha(self: AutoPeek, alpha: number): ()
	self._markerAlpha = math.clamp(alpha, 0, 1)

	local scale = math.max(0.001, 1 - self._markerAlpha)
	local size = MARKER_SIZE * scale
	self._circle.Size = Vector3.new(size, MARKER_THICKNESS, size)
	self._highlight.FillTransparency = self._fillTransparency + (1 - self._fillTransparency) * self._markerAlpha
	self._highlight.OutlineTransparency = self._outlineTransparency
		+ (1 - self._outlineTransparency) * self._markerAlpha
	self._circle.Transparency = 1
end

function AutoPeek._stopSpring(self: AutoPeek): ()
	local markerSpring = self._spring
	if markerSpring then
		markerSpring:destroy()
		self._spring = nil
	end

	local colorSpring = self._colorSpring
	if colorSpring then
		colorSpring:destroy()
		self._colorSpring = nil
	end
end

function AutoPeek._animateMarker(self: AutoPeek, targetAlpha: number, onComplete: (() -> ())?): ()
	local spring = self._spring
	if spring then
		spring:destroy()
		self._spring = nil
	end

	spring = Ripple.createSpring(self._markerAlpha, SPRING_CONFIG)
	self._spring = spring
	spring:onChange(function(value: number): ()
		self:_applyMarkerAlpha(value)
	end)
	spring:onComplete(function(): ()
		if self._spring == spring then
			self._spring = nil
		end
		if onComplete then
			onComplete()
		end
	end)
	spring:setGoal(targetAlpha)
end

function AutoPeek._animateRetreatColor(self: AutoPeek, targetBlend: number): ()
	local spring = self._colorSpring
	if spring then
		spring:destroy()
		self._colorSpring = nil
	end

	spring = Ripple.createSpring(self._retreatBlend, SPRING_CONFIG)
	self._colorSpring = spring
	spring:onChange(function(value: number): ()
		self:_applyMarkerColorBlend(value)
	end)
	spring:onComplete(function(): ()
		if self._colorSpring == spring then
			self._colorSpring = nil
		end
	end)
	spring:setGoal(targetBlend)
end

function AutoPeek._resolveGroundPosition(self: AutoPeek, hrp: BasePart): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { hrp.Parent, workspace.CurrentCamera }

	local result = workspace:Raycast(hrp.Position, Vector3.new(0, -500, 0), params)
	if result then
		return result.Position
	end

	return hrp.Position - Vector3.new(0, hrp.Size.Y * 0.5, 0)
end

function AutoPeek._showMarker(self: AutoPeek): ()
	local groundPosition = self._savedGroundPosition
	if not groundPosition then
		return
	end

	self:_stopSpring()
	self._circle.CFrame = CFrame.new(groundPosition)
	self._circle.Parent = workspace
	self:_applyMarkerColorBlend(0)
	self:_applyMarkerAlpha(1)
	self:_animateMarker(0)
end

function AutoPeek._hideMarker(self: AutoPeek): ()
	if self._circle.Parent == nil then
		return
	end

	self:_animateMarker(1, function(): ()
		if not self:_active() then
			self._circle.Parent = nil
		end
	end)
end

function AutoPeek._unbindMove(self: AutoPeek): ()
	local stop = self._moveStop
	if stop then
		self._moveStop = nil
		stop()
	end
end

function AutoPeek._stopRetreat(self: AutoPeek): ()
	self._retreating = false
	self:_unbindMove()
	self:_animateRetreatColor(0)

	local onDone = self._retreatDone
	if onDone then
		self._retreatDone = nil
		onDone()
	end
end

function AutoPeek._teleportRetreat(self: AutoPeek): ()
	local teleport = self._teleport
	local hrp = self._getHrp()
	local savedCFrame = self._savedCFrame
	if not teleport or not hrp or not savedCFrame then
		return
	end

	self:_animateRetreatColor(1)
	teleport(savedCFrame)
	task.defer(function(): ()
		if self:_active() then
			self:_animateRetreatColor(0)
		end
	end)
end

function AutoPeek._moveRetreat(self: AutoPeek): ()
	local startMove = self._startMove
	local savedCFrame = self._savedCFrame
	local savedPosition = savedCFrame and savedCFrame.Position
	if not startMove or not savedPosition then
		return
	end

	self:_stopRetreat()
	self._retreating = true
	self:_animateRetreatColor(1)

	local startFlat: Vector3? = nil
	local startHrp = self._getHrp()
	if startHrp then
		local d = savedPosition - startHrp.Position
		local flat = Vector3.new(d.X, 0, d.Z)
		if flat.Magnitude > 1e-3 then
			startFlat = flat.Unit
		end
	end

	local context: RetreatContext = {
		getHrp = self._getHrp,
		savedPosition = savedPosition,
		stopDistance = MOVE_STOP_DISTANCE,
		shouldRun = function(): boolean
			return self:_active() and self._retreating
		end,
		arrive = function(): ()
			self:_stopRetreat()
		end,
		flatDelta = function(): Vector3?
			local hrp = self._getHrp()
			if not hrp then
				return nil
			end
			local delta = savedPosition - hrp.Position
			return Vector3.new(delta.X, 0, delta.Z)
		end,
		crossedCenter = LPH_NO_VIRTUALIZE(function(): boolean
			if not startFlat then
				return true
			end
			local hrp = self._getHrp()
			if not hrp then
				return true
			end
			local d = savedPosition - hrp.Position
			return Vector3.new(d.X, 0, d.Z):Dot(startFlat) <= 0
		end),
	}

	self._moveStop = startMove(context)
end

function AutoPeek._retreat(self: AutoPeek): ()
	if not self:_active() then
		return
	end

	local savedCFrame = self._savedCFrame
	local hrp = self._getHrp()
	if savedCFrame and hrp and (savedCFrame.Position - hrp.Position).Magnitude > self._maxDistance then
		return
	end

	if self:_resolveMethod() == "Move" then
		self:_moveRetreat()
	else
		self:_teleportRetreat()
	end
end

function AutoPeek.Enable(self: AutoPeek): ()
	if self._enabled then
		return
	end

	local hrp = self._getHrp()
	if not hrp then
		return
	end

	self._enabled = true
	self._savedCFrame = hrp.CFrame
	self._savedGroundPosition = self:_resolveGroundPosition(hrp)
	self:_showMarker()

	self._janitor:Add(
		self._connectShot(function(): ()
			if not self._enabled then
				return
			end
			task.defer(function(): ()
				self:_retreat()
			end)
		end),
		true
	)
end

function AutoPeek._disableNow(self: AutoPeek): ()
	self._enabled = false
	self._releaseRetreating = false
	self._janitor:Cleanup()
	self:_stopRetreat()
	if not self._armed then
		self:_hideMarker()
	end
end

function AutoPeek.SavePosition(self: AutoPeek): boolean
	local hrp = self._getHrp()
	if not hrp then
		return false
	end
	self._armed = true
	self._savedCFrame = hrp.CFrame
	self._savedGroundPosition = self:_resolveGroundPosition(hrp)
	self:_showMarker()
	return true
end

function AutoPeek.Retreat(self: AutoPeek): ()
	self:_retreat()
end

function AutoPeek.ClearPosition(self: AutoPeek): ()
	if not self._armed then
		return
	end
	self._armed = false
	self:_stopRetreat()
	if not self._enabled then
		self._savedCFrame = nil
		self._savedGroundPosition = nil
		self:_hideMarker()
	end
end

function AutoPeek.IsArmed(self: AutoPeek): boolean
	return self:_active()
end

function AutoPeek.IsRetreating(self: AutoPeek): boolean
	return self._retreating
end

function AutoPeek.Disable(self: AutoPeek): ()
	if not self._enabled then
		return
	end

	local savedCFrame = self._savedCFrame
	if not self._destroying and not self._releaseRetreating and savedCFrame and self._optsLink:Peek("onRelease") then
		local hrp = self._getHrp()
		if hrp and (savedCFrame.Position - hrp.Position).Magnitude <= self._maxDistance then
			self._releaseRetreating = true
			if self:_resolveMethod() == "Move" then
				self:_moveRetreat()
				self._retreatDone = function(): ()
					self:_disableNow()
				end
				return
			end
			self:_teleportRetreat()
		end
	end

	self:_disableNow()
end

function AutoPeek.Destroy(self: AutoPeek): ()
	self._destroying = true
	self._armed = false
	if autoPeekState.current == self then
		autoPeekState.current = nil
	end
	self:Disable()
	self:_stopSpring()
	self._highlight.Enabled = false
	self._highlight.Adornee = nil
	self._highlight:Destroy()
	self._circle:Destroy()
	BaseFeature.Destroy(self)
end

export type AutoPeek =
	typeof(setmetatable(
		{} :: {
			_getHrp: () -> BasePart?,
			_connectShot: (fire: () -> ()) -> () -> (),
			_teleport: ((savedCFrame: CFrame) -> ())?,
			_startMove: ((ctx: RetreatContext) -> () -> ())?,
			_hasTeleport: boolean,
			_hasMove: boolean,
			_enabled: boolean,
			_armed: boolean,
			_retreating: boolean,
			_releaseRetreating: boolean,
			_destroying: boolean,
			_retreatDone: (() -> ())?,
			_enabledLink: any,
			_optsLink: gameUi.Linker,
			_maxDistance: number,
			_janitor: Janitor.Janitor,
			_circle: Part,
			_highlight: Highlight,
			_savedCFrame: CFrame?,
			_savedGroundPosition: Vector3?,
			_fillTransparency: number,
			_outlineTransparency: number,
			_markerAlpha: number,
			_retreatBlend: number,
			_fillColor: Color3,
			_outlineColor: Color3,
			_retreatColor: Color3,
			_spring: any,
			_colorSpring: any,
			_moveStop: (() -> ())?,
		},
		AutoPeek
	))
	& BaseFeature.BaseFeature

return AutoPeek
