local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local projectileRenderer = require("@game/universal/feature/visual/grenade/projectileRenderer")
local projectileShared = require("@game/overkill/feature/visual/grenade/projectileShared")
local grenadeState = require("@game/overkill/grenade/grenadeState")

local e = React.createElement

local MAX_DISTANCE = 250

local function resolvePosition(entry: grenadeState.ProjectileEntry): Vector3
	local model = entry.model
	if model and model.Parent then
		return model:GetPivot().Position
	end
	return entry.spawnPosition
end

local adapter: projectileRenderer.Adapter = projectileShared.buildAdapter(function(entry: grenadeState.ProjectileEntry): boolean
	return entry.isExplosive
end, resolvePosition)

local ProjectileEsp = {}
ProjectileEsp.__index = ProjectileEsp

setmetatable(ProjectileEsp, { __index = BaseFeature })

function ProjectileEsp.new(link: gameUi.Linker): ProjectileEsp
	local self = BaseFeature.new() :: any
	setmetatable(self, ProjectileEsp)

	link:Toggle("projectileEsp", "Projectile ESP", false):SetTip({
		title = "Projectile ESP",
		body = "Tracks grenades and rockets through walls.",
	})
	local espLink = link:OnKey("projectileEsp")
	espLink:Submenu("opts", "Projectile ESP Options")
	local optsLink = espLink:OnKey("opts")
	local colorProps = projectileShared.buildColorOptions(optsLink)

	local screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = 14,
	}, cloneref(gethui()))
	self._screenGui = screenGui
	self._root = ReactRoblox.createRoot(screenGui)

	self._root:render(e(projectileRenderer, {
		enabledAtom = link:Get("projectileEsp")._state,
		entriesAtom = grenadeState.activeProjectiles,
		adapter = adapter,
		clampOffscreen = false,
		showBar = true,
		maxDistance = MAX_DISTANCE,
		markerScale = 0.6,
		color = colorProps.color,
		bgColor = colorProps.bgColor,
		colorByKey = colorProps.colorByKey,
	}))

	return self
end

function ProjectileEsp.Destroy(self: ProjectileEsp): ()
	if self._root then
		self._root:unmount()
	end
	if self._screenGui then
		self._screenGui:Destroy()
	end
	BaseFeature.Destroy(self)
end

export type ProjectileEsp = typeof(setmetatable(
	{} :: {
		_screenGui: Instance,
		_root: ReactRoblox.RootType,
	},
	ProjectileEsp
)) & BaseFeature.BaseFeature

return ProjectileEsp
