local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")

local RENDER_NAME = "limerence.zoom"
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1
local ZOOM_MIN_FOV = 10
local DEFAULT_AMOUNT = 60
local DEFAULT_SPEED = 16
local SETTLE_EPS = 0.05
local FOV_FALLBACK = 70

local Zoom = {}
Zoom.__index = Zoom

setmetatable(Zoom, { __index = BaseFeature })

function Zoom.new(link: gameUi.Linker): Zoom
	local self = BaseFeature.new() :: any
	setmetatable(self, Zoom)

	self._active = false
	self._running = false
	self._applied = FOV_FALLBACK

	local toggle = link:Toggle("zoom", "Zoom", false):SetTip({
		title = "Zoom",
		body = "Narrows your view to see further. Bind a key to hold or toggle it.",
	})
	local zoomLink = link:OnKey("zoom")
	zoomLink:Extra(toggle, "opts", "Submenu", "Zoom")
	local optsLink = zoomLink:OnKey("opts")
	optsLink:Toggle("smooth", "Smooth", true):SetTip({
		title = "Smooth",
		body = "Eases the zoom in and out instead of snapping.",
	})
	optsLink:Slider("speed", "Zoom Speed", DEFAULT_SPEED, 1, 30, 1):SetTip({
		title = "Zoom Speed",
		body = "How quickly the zoom eases in and out. Lower is smoother.",
	})
	optsLink:Slider("amount", "Amount", DEFAULT_AMOUNT, 0, 100, 1, nil, "%"):SetTip({
		title = "Amount",
		body = "How far to zoom in. Higher zooms in more.",
	})

	self._amountLink = optsLink:Get("amount")
	self._smoothLink = optsLink:Get("smooth")
	self._speedLink = optsLink:Get("speed")

	self:Track(link:Get("zoom"):OnChange(function(state: boolean): ()
		if state then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("zoom") then
		self:Enable()
	end

	return self
end

function Zoom._unbind(self: Zoom): ()
	if self._running then
		RunService:UnbindFromRenderStep(RENDER_NAME)
		self._running = false
	end
end

function Zoom._bind(self: Zoom): ()
	if self._running then
		return
	end
	self._running = true
	RunService:BindToRenderStep(
		RENDER_NAME,
		RENDER_PRIORITY,
		LPH_NO_VIRTUALIZE(function(dt: number): ()
			local cam = Workspace.CurrentCamera
			if not cam then
				if not self._active then
					self:_unbind()
				end
				return
			end

			local base = cam.FieldOfView
			local target = base
			if self._active then
				local amount = (self._amountLink:Peek() or 0) / 100
				target = base + (ZOOM_MIN_FOV - base) * amount
			end

			local smooth = self._smoothLink:Peek()
			local speed = self._speedLink:Peek() or DEFAULT_SPEED
			local alpha = (smooth and speed > 0) and (1 - math.exp(-dt * speed)) or 1
			self._applied += (target - self._applied) * alpha

			if not self._active and math.abs(self._applied - base) < SETTLE_EPS then
				self:_unbind()
				return
			end

			cam.FieldOfView = self._applied
		end)
	)
end

function Zoom.Enable(self: Zoom): ()
	if self._active then
		return
	end
	self._active = true

	if not self._running then
		local camera = Workspace.CurrentCamera
		self._applied = (camera and camera.FieldOfView) or FOV_FALLBACK
	end
	self:_bind()
end

function Zoom.Disable(self: Zoom): ()
	if not self._active then
		return
	end
	self._active = false
end

function Zoom.Destroy(self: Zoom): ()
	self._active = false
	self:_unbind()
	BaseFeature.Destroy(self)
end

export type Zoom =
	typeof(setmetatable(
		{} :: {
			_active: boolean,
			_running: boolean,
			_applied: number,
			_amountLink: any,
			_smoothLink: any,
			_speedLink: any,
			_bind: (Zoom) -> (),
			_unbind: (Zoom) -> (),
			Enable: (Zoom) -> (),
			Disable: (Zoom) -> (),
		},
		Zoom
	))
	& BaseFeature.BaseFeature

return Zoom
