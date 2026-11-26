local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ScopeController = require("@feature/ui/scope/ScopeController")
local legitbotApi = require("@game/universal/feature/combat/legitbot/legitbotApi")
local aimIndicatorRenderer = require("@game/universal/feature/combat/legitbot/aimIndicatorRenderer")

local peek = Charm.peek

local AIM_COLOR = Color3.fromRGB(0, 255, 195)
local TRIGGER_COLOR = Color3.fromRGB(255, 150, 152)
local REDIRECTION_COLOR = Color3.fromRGB(207, 152, 255)
local DEFAULT_SIZE = 26

local AimIndicator = {}
AimIndicator.__index = AimIndicator

setmetatable(AimIndicator, { __index = BaseFeature })

function AimIndicator.new(link: gameUi.Linker): AimIndicator
	local self = BaseFeature.new() :: any
	setmetatable(self, AimIndicator)

	link:Toggle("targetIndicator", "Target Indicator", false):SetTip({
		title = "Target Indicator",
		body = "Draws a circle on the hitbox each legitbot subsystem is currently targeting.",
	})
	local indicatorLink = link:OnKey("targetIndicator")
	indicatorLink:Submenu("opts", "Target Indicator")
	local root = indicatorLink:OnKey("opts")

	local aimToggle = root:Toggle("aim", "Aimbot", true):SetTip({
		title = "Aimbot",
		body = "Show the indicator on the aimbot target.",
	})
	root:Extra(aimToggle, "aimColor", "Colorpicker", "Color", AIM_COLOR, 0)

	local triggerToggle = root:Toggle("trigger", "Triggerbot", true):SetTip({
		title = "Triggerbot",
		body = "Show the indicator on the triggerbot target.",
	})
	root:Extra(triggerToggle, "triggerColor", "Colorpicker", "Color", TRIGGER_COLOR, 0)

	local redirectionToggle = root:Toggle("redirection", "Bullet Redirection", true):SetTip({
		title = "Bullet Redirection",
		body = "Show the indicator on the bullet redirection target.",
	})
	root:Extra(redirectionToggle, "redirectionColor", "Colorpicker", "Color", REDIRECTION_COLOR, 0)

	root:Slider("size", "Size", DEFAULT_SIZE, 8, 64, 1, nil, "px"):SetTip({
		title = "Size",
		body = "Indicator circle size in pixels.",
	})

	self._aimViz = aimIndicatorRenderer.new()
	self._triggerViz = aimIndicatorRenderer.new()
	self._redirectionViz = aimIndicatorRenderer.new()
	self._conn = nil

	local state = legitbotApi.state
	local aimColorEl = root:Get("aimColor")
	local triggerColorEl = root:Get("triggerColor")
	local redirectionColorEl = root:Get("redirectionColor")

	local cache = { aim = true, trigger = true, redirection = true, size = DEFAULT_SIZE }

	local aimOpts = { enabled = true, part = nil, color = aimColorEl:GetColor(), size = DEFAULT_SIZE }
	local triggerOpts = { enabled = true, part = nil, color = triggerColorEl:GetColor(), size = DEFAULT_SIZE }
	local redirectionOpts = { enabled = true, part = nil, color = redirectionColorEl:GetColor(), size = DEFAULT_SIZE }

	self:Track(aimColorEl:OnUpdate(function(snapshot: any): ()
		aimOpts.color = snapshot.color
	end))
	self:Track(triggerColorEl:OnUpdate(function(snapshot: any): ()
		triggerOpts.color = snapshot.color
	end))
	self:Track(redirectionColorEl:OnUpdate(function(snapshot: any): ()
		redirectionOpts.color = snapshot.color
	end))

	local tick = LPH_NO_VIRTUALIZE(function(): ()
		aimOpts.enabled = cache.aim
		aimOpts.part = peek(state.activeTargetPart)
		aimOpts.size = cache.size
		self._aimViz:Update(aimOpts)

		triggerOpts.enabled = cache.trigger
		triggerOpts.part = peek(state.triggerTargetPart)
		triggerOpts.size = cache.size
		self._triggerViz:Update(triggerOpts)

		redirectionOpts.enabled = cache.redirection
		redirectionOpts.part = peek(state.redirectionTargetPart)
		redirectionOpts.size = cache.size
		self._redirectionViz:Update(redirectionOpts)
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
			self._aimViz:Destroy()
			self._triggerViz:Destroy()
			self._redirectionViz:Destroy()
		end
	end

	local optsPrefix = (root :: any)._prefix
	self:Track(ScopeController.OnChange(optsPrefix .. ".aim", function(v: any): ()
		cache.aim = v == true
	end))
	self:Track(ScopeController.OnChange(optsPrefix .. ".trigger", function(v: any): ()
		cache.trigger = v == true
	end))
	self:Track(ScopeController.OnChange(optsPrefix .. ".redirection", function(v: any): ()
		cache.redirection = v == true
	end))
	self:Track(ScopeController.OnChange(optsPrefix .. ".size", function(v: any): ()
		cache.size = tonumber(v) or DEFAULT_SIZE
	end))
	self:Track(ScopeController.OnChange((indicatorLink :: any)._prefix, function(v: any): ()
		setActive(v == true)
	end))
	self:Track(function(): ()
		setActive(false)
	end)

	return self
end

function AimIndicator.Destroy(self: AimIndicator): ()
	self._aimViz:Destroy()
	self._triggerViz:Destroy()
	self._redirectionViz:Destroy()
	BaseFeature.Destroy(self)
end

export type AimIndicator =
	typeof(setmetatable(
		{} :: {
			_aimViz: aimIndicatorRenderer.AimIndicatorRenderer,
			_triggerViz: aimIndicatorRenderer.AimIndicatorRenderer,
			_redirectionViz: aimIndicatorRenderer.AimIndicatorRenderer,
			_conn: RBXScriptConnection?,
		},
		AimIndicator
	))
	& BaseFeature.BaseFeature

return AimIndicator
