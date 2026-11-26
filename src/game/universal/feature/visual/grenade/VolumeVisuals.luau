local Charm = require("@pkg/Charm")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local volumeRenderer = require("@game/universal/feature/visual/grenade/volumeRenderer")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local peek = Charm.peek

local DISPLAY_ORDER = 14
local VOLUME_TRANSPARENCY = 0.15
local GLOW_TRANSPARENCY = 0.2

export type VolumeVisualsOpts = {
	sources: { volumeRenderer.Adapter },
}

type Runtime = {
	adapter: volumeRenderer.Adapter,
	settings: volumeRenderer.Settings,
	views: { [string]: volumeRenderer.View },
}

local VolumeVisuals = {}
VolumeVisuals.__index = VolumeVisuals

setmetatable(VolumeVisuals, { __index = BaseFeature })

function VolumeVisuals.new(link: gameUi.Linker, opts: VolumeVisualsOpts): VolumeVisuals
	local self = BaseFeature.new() :: any
	setmetatable(self, VolumeVisuals)

	self._runtimes = {} :: { Runtime }
	self._renderConnection = nil :: RBXScriptConnection?

	self._screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = DISPLAY_ORDER,
	}, cloneref(gethui())) :: ScreenGui

	local sources = opts.sources
	for i = 1, #sources do
		local adapter = sources[i]

		link:Toggle(adapter.key, adapter.label, false):SetTip({
			title = adapter.label,
			body = adapter.tip or "Draws the volume in 3D through walls.",
		})

		local rootLink = link:OnKey(adapter.key)
		rootLink:Submenu("opts", adapter.label)
		local optsLink = rootLink:OnKey("opts")

		optsLink:Colorpicker("color", "Volume", adapter.defaultColor, VOLUME_TRANSPARENCY):SetTip({
			title = "Volume",
			body = "Color and opacity of the volume outline.",
		})
		optsLink:Colorpicker("glowColor", "Glow", adapter.defaultGlow or adapter.defaultColor, GLOW_TRANSPARENCY)
			:SetTip({
				title = "Glow",
				body = "Color and strength of the halo around the outline.",
			})

		local colorpicker = optsLink:Get("color")
		local glowPicker = optsLink:Get("glowColor")

		local runtime: Runtime = {
			adapter = adapter,
			settings = {
				enabled = link:Peek(adapter.key) == true,
				color = colorpicker:GetColor(),
				transparency = colorpicker:GetTransparency(),
				glowColor = glowPicker:GetColor(),
				glowTransparency = glowPicker:GetTransparency(),
			},
			views = {},
		}

		self:Track(link:Watch(adapter.key, function(value: any): ()
			runtime.settings.enabled = value == true
			if not runtime.settings.enabled then
				self:_clearViews(runtime)
			end
			self:_syncLoop()
		end))
		self:Track(colorpicker:OnUpdate(function(snapshot: any): ()
			runtime.settings.color = snapshot.color
			runtime.settings.transparency = snapshot.transparency
		end))
		self:Track(glowPicker:OnUpdate(function(snapshot: any): ()
			runtime.settings.glowColor = snapshot.color
			runtime.settings.glowTransparency = snapshot.transparency
		end))

		self._runtimes[#self._runtimes + 1] = runtime
	end

	self:_syncLoop()

	return self
end

function VolumeVisuals._clearViews(self: VolumeVisuals, runtime: Runtime): ()
	for key, view in next, runtime.views do
		volumeRenderer.destroyView(view)
		runtime.views[key] = nil
	end
end

function VolumeVisuals._syncLoop(self: VolumeVisuals): ()
	local runtimes = self._runtimes
	local active = false
	for i = 1, #runtimes do
		if runtimes[i].settings.enabled then
			active = true
			break
		end
	end

	if active then
		if self._renderConnection then
			return
		end
		self._renderConnection = RunService.PreRender:Connect(function(deltaTime: number): ()
			self:_step(deltaTime)
		end)
		return
	end

	if self._renderConnection then
		self._renderConnection:Disconnect()
		self._renderConnection = nil
	end
end

VolumeVisuals._step = LPH_NO_VIRTUALIZE(function(self: VolumeVisuals, deltaTime: number): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local runtimes = self._runtimes
	local anyActive = false
	local prepared = false

	for i = 1, #runtimes do
		local runtime = runtimes[i]
		local settings = runtime.settings
		if not settings.enabled then
			continue
		end

		anyActive = true

		local adapter = runtime.adapter
		local views = runtime.views
		local entries = peek(adapter.entries)

		if not prepared then
			prepared = true
			volumeRenderer.beginFrame(camera, camera.ViewportSize, deltaTime, os.clock())
		end

		for key, entry in next, entries do
			local view = views[key]
			if view then
				view.entry = entry
				view.leaving = false
			else
				views[key] = volumeRenderer.createView(self._screenGui, settings, entry)
			end
		end

		for key, view in next, views do
			if not entries[key] then
				view.leaving = true
			end

			volumeRenderer.applyColors(view, settings)

			local alive = volumeRenderer.updateView(view, adapter, settings)

			if not alive then
				volumeRenderer.destroyView(view)
				views[key] = nil
			end
		end
	end

	if not anyActive then
		self:_syncLoop()
	end
end)

function VolumeVisuals.Destroy(self: VolumeVisuals): ()
	if self._renderConnection then
		self._renderConnection:Disconnect()
		self._renderConnection = nil
	end

	local runtimes = self._runtimes
	for i = 1, #runtimes do
		self:_clearViews(runtimes[i])
	end

	volumeRenderer.clearPool()

	if self._screenGui then
		self._screenGui:Destroy()
		self._screenGui = nil
	end

	BaseFeature.Destroy(self)
end

export type VolumeVisuals = typeof(setmetatable(
	{} :: {
		_runtimes: { Runtime },
		_renderConnection: RBXScriptConnection?,
		_screenGui: ScreenGui?,
	},
	VolumeVisuals
)) & BaseFeature.BaseFeature

return VolumeVisuals
