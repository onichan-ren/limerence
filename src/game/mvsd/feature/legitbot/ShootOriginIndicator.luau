local RunService = cloneref(game:GetService("RunService")) :: RunService

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ScopeController = require("@feature/ui/scope/ScopeController")
local aimIndicatorRenderer = require("@game/universal/feature/combat/legitbot/aimIndicatorRenderer")
local espSkeletonLines = require("@game/universal/feature/visual/esp/espSkeletonLines")
local shootRay = require("@game/mvsd/weapon/shootRay")

local DEFAULT_COLOR = Color3.fromRGB(255, 200, 90)
local DEFAULT_SIZE = 26
local DEFAULT_THICKNESS = 1

local ShootOriginIndicator = {}
ShootOriginIndicator.__index = ShootOriginIndicator

setmetatable(ShootOriginIndicator, { __index = BaseFeature })

function ShootOriginIndicator.new(link: gameUi.Linker): ShootOriginIndicator
	local self = BaseFeature.new() :: any
	setmetatable(self, ShootOriginIndicator)

	link:Toggle("shootOriginIndicator", "Shoot Origin Indicator", false):SetTip({
		title = "Shoot Origin Indicator",
		body = "Draws a circle where your shots actually start from, not the muzzle.",
	})
	local indicatorLink = link:OnKey("shootOriginIndicator")
	indicatorLink:Submenu("opts", "Shoot Origin Indicator")
	local root = indicatorLink:OnKey("opts")

	root:Colorpicker("color", "Color", DEFAULT_COLOR, 0)
	root:Slider("size", "Size", DEFAULT_SIZE, 8, 64, 1, nil, "px"):SetTip({
		title = "Size",
		body = "Indicator circle size in pixels.",
	})
	root:Toggle("line", "Line", false):SetTip({
		title = "Line",
		body = "Draws a line from the origin to where your shot will land.",
	})
	local lineLink = root:OnKey("line")
	lineLink:Submenu("opts", "Line")
	local lineOpts = lineLink:OnKey("opts")
	lineOpts:Colorpicker("color", "Color", DEFAULT_COLOR, 0)
	lineOpts:Slider("thickness", "Thickness", DEFAULT_THICKNESS, 1, 4, 1, nil, "px"):SetTip({
		title = "Thickness",
		body = "Line width.",
	})

	self._viz = aimIndicatorRenderer.new()
	self._line = nil :: espSkeletonLines.LineHandle?
	self._conn = nil

	local colorEl = root:Get("color")
	local lineColorEl = lineOpts:Get("color")
	local cache = { size = DEFAULT_SIZE, line = false, thickness = DEFAULT_THICKNESS }

	local updateLine = LPH_NO_VIRTUALIZE(function(origin: Vector3?, color: Color3?): ()
		local landing = (cache.line and origin and color) and shootRay.Landing(origin) or nil
		if not origin or not landing or not color then
			local hidden = self._line
			if hidden then
				espSkeletonLines.hide(hidden)
			end
			return
		end

		local handle = self._line
		if not handle then
			handle = espSkeletonLines.create(color)
			self._line = handle
		end
		espSkeletonLines.setColor(handle, color)
		local state = handle.state
		state.from = origin
		state.to = landing
		state.thickness = cache.thickness
		state.transparency = 0
		state.visible = true
		espSkeletonLines.applyStandalone(handle)
	end)

	local vizOpts = {
		enabled = true,
		position = nil :: Vector3?,
		color = DEFAULT_COLOR,
		size = DEFAULT_SIZE,
	}

	local tick = LPH_NO_VIRTUALIZE(function(): ()
		local origin = shootRay.Origin()
		vizOpts.position = origin
		vizOpts.color = colorEl:GetColor()
		vizOpts.size = cache.size
		self._viz:Update(vizOpts)
		updateLine(origin, cache.line and lineColorEl:GetColor() or nil)
	end)

	local function setActive(active: boolean): ()
		if active then
			if not self._conn then
				self._conn = RunService.PreRender:Connect(tick)
			end
		else
			if self._conn then
				self._conn:Disconnect()
				self._conn = nil
			end
			self._viz:Destroy()
			local line = self._line
			if line then
				espSkeletonLines.destroy(line)
				self._line = nil
			end
		end
	end

	self:Track(ScopeController.OnChange((root :: any)._prefix .. ".size", function(v: any): ()
		cache.size = tonumber(v) or DEFAULT_SIZE
	end))
	self:Track(ScopeController.OnChange((root :: any)._prefix .. ".line", function(v: any): ()
		cache.line = v == true
	end))
	self:Track(ScopeController.OnChange((lineOpts :: any)._prefix .. ".thickness", function(v: any): ()
		cache.thickness = tonumber(v) or DEFAULT_THICKNESS
	end))
	self:Track(ScopeController.OnChange((indicatorLink :: any)._prefix, function(v: any): ()
		setActive(v == true)
	end))
	self:Track(function(): ()
		setActive(false)
	end)

	return self
end

function ShootOriginIndicator.Destroy(self: ShootOriginIndicator): ()
	self._viz:Destroy()
	local line = self._line
	if line then
		espSkeletonLines.destroy(line)
		self._line = nil
	end
	BaseFeature.Destroy(self)
end

export type ShootOriginIndicator =
	typeof(setmetatable(
		{} :: {
			_viz: aimIndicatorRenderer.AimIndicatorRenderer,
			_line: espSkeletonLines.LineHandle?,
			_conn: RBXScriptConnection?,
		},
		ShootOriginIndicator
	))
	& BaseFeature.BaseFeature

return ShootOriginIndicator
