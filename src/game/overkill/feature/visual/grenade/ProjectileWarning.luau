local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local projectileRenderer = require("@game/universal/feature/visual/grenade/projectileRenderer")
local projectileShared = require("@game/overkill/feature/visual/grenade/projectileShared")
local grenadeState = require("@game/overkill/grenade/grenadeState")

local e = React.createElement

local MAX_DISTANCE = 80

local function resolvePosition(entry: grenadeState.ProjectileEntry): Vector3
	if entry.predictedPosition then
		return entry.predictedPosition
	end
	local model = entry.model
	if model and model.Parent then
		return model:GetPivot().Position
	end
	return entry.spawnPosition
end

local adapter: projectileRenderer.Adapter = projectileShared.buildAdapter(function(entry: grenadeState.ProjectileEntry): boolean
	return entry.isExplosive and not entry.isFriendly
end, resolvePosition)

local ProjectileWarning = {}
ProjectileWarning.__index = ProjectileWarning

setmetatable(ProjectileWarning, { __index = BaseFeature })

function ProjectileWarning.new(link: gameUi.Linker): ProjectileWarning
	local self = BaseFeature.new() :: any
	setmetatable(self, ProjectileWarning)

	link:Toggle("projectileWarning", "Projectile Warning", false):SetTip({
		title = "Projectile Warning",
		body = "Warns when an enemy explosive is heading toward you.",
	})
	local warningLink = link:OnKey("projectileWarning")
	warningLink:Submenu("opts", "Projectile Warning Options")
	local optsLink = warningLink:OnKey("opts")
	local colorProps = projectileShared.buildColorOptions(optsLink)

	local screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = 15,
	}, cloneref(gethui()))
	self._screenGui = screenGui

	self._root = ReactRoblox.createRoot(screenGui)
	self._root:render(e(projectileRenderer, {
		enabledAtom = link:Get("projectileWarning")._state,
		entriesAtom = grenadeState.activeProjectiles,
		adapter = adapter,
		clampOffscreen = true,
		showBar = true,
		maxDistance = MAX_DISTANCE,
		markerScale = 1,
		color = colorProps.color,
		bgColor = colorProps.bgColor,
		colorByKey = colorProps.colorByKey,
	}))

	return self
end

function ProjectileWarning.Destroy(self: ProjectileWarning): ()
	if self._root then
		self._root:unmount()
	end
	if self._screenGui then
		self._screenGui:Destroy()
	end
	BaseFeature.Destroy(self)
end

export type ProjectileWarning = typeof(setmetatable(
	{} :: {
		_screenGui: Instance,
		_root: ReactRoblox.RootType,
	},
	ProjectileWarning
)) & BaseFeature.BaseFeature

return ProjectileWarning
