local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local instances = require("@share/instances")
local grenadeSim = require("@game/op1/grenade/grenadeSim")
local worldPath = require("@game/op1/grenade/worldPath")
local warningRenderer = require("@game/op1/feature/visual/grenade/warningRenderer")
local GrenadeController = require("@game/op1/grenade/GrenadeController")

local RunService = cloneref(game:GetService("RunService"))
local Workspace = cloneref(game:GetService("Workspace"))
local Terrain = Workspace.Terrain

local e = React.createElement

local DEFAULT_ENEMY_COLOR = Color3.fromRGB(235, 110, 110)
local DEFAULT_FRIENDLY_COLOR = Color3.fromRGB(120, 180, 230)
local DEFAULT_LOCAL_COLOR = Color3.fromRGB(130, 220, 150)
local DEFAULT_BG_COLOR = Color3.fromRGB(28, 28, 28)

local GrenadeWarning = {}
GrenadeWarning.__index = GrenadeWarning

setmetatable(GrenadeWarning, { __index = BaseFeature })

export type GrenadeWarning = typeof(setmetatable({} :: any, GrenadeWarning))

function GrenadeWarning.new(link: gameUi.Linker): GrenadeWarning
	local self = BaseFeature.new() :: any
	setmetatable(self, GrenadeWarning)

	self._renderers = {}
	self._arcJanitor = nil :: Janitor.Janitor?
	self._seen = {} :: { [any]: boolean }
	self._activeScratch = {} :: { any }
	self._ignore = {} :: { Instance }
	self._enemyColor = DEFAULT_ENEMY_COLOR
	self._friendlyColor = DEFAULT_FRIENDLY_COLOR
	self._localColor = DEFAULT_LOCAL_COLOR
	self._enemySeq = ColorSequence.new(DEFAULT_ENEMY_COLOR)
	self._friendlySeq = ColorSequence.new(DEFAULT_FRIENDLY_COLOR)
	self._localSeq = ColorSequence.new(DEFAULT_LOCAL_COLOR)

	link:Toggle("grenadeWarning", "Grenade Warning", false):SetTip({
		title = "Grenade Warning",
		body = "Marks where incoming grenades will land and can draw their flight path.",
	})
	link:Extra(link:Get("grenadeWarning"), "grenadeWarningOpts", "Submenu", "Grenade Warning")
	local optsLink = link:OnKey("grenadeWarningOpts")

	optsLink:Toggle("showPath", "Show Path", true):SetTip({
		title = "Show Path",
		body = "Draws the predicted flight path of incoming grenades in the world.",
	})
	optsLink:Colorpicker("enemyColor", "Enemy", DEFAULT_ENEMY_COLOR, 0):SetTip({
		title = "Enemy",
		body = "Color for enemy grenades.",
	})
	optsLink:Colorpicker("friendlyColor", "Friendly", DEFAULT_FRIENDLY_COLOR, 0):SetTip({
		title = "Friendly",
		body = "Color for teammate grenades.",
	})
	optsLink:Colorpicker("localColor", "Local", DEFAULT_LOCAL_COLOR, 0):SetTip({
		title = "Local",
		body = "Color for your own grenades.",
	})
	optsLink:Colorpicker("bgColor", "Background", DEFAULT_BG_COLOR, 0):SetTip({
		title = "Background",
		body = "Marker background color.",
	})

	self._enabledLink = link:Get("grenadeWarning")

	local function refreshArcs(): ()
		local on = self._enabledLink:Peek() == true and optsLink:Peek("showPath") == true
		if on then
			self:startArcs()
		else
			self:stopArcs()
		end
	end

	self:Track(self._enabledLink:OnChange(refreshArcs))
	self:Track(optsLink:Get("showPath"):OnChange(refreshArcs))

	local function refreshColors(): ()
		local enemy: any = optsLink:Get("enemyColor")
		local friendly: any = optsLink:Get("friendlyColor")
		local localPicker: any = optsLink:Get("localColor")
		if enemy then
			self._enemyColor = enemy:GetColor()
			self._enemySeq = ColorSequence.new(self._enemyColor)
		end
		if friendly then
			self._friendlyColor = friendly:GetColor()
			self._friendlySeq = ColorSequence.new(self._friendlyColor)
		end
		if localPicker then
			self._localColor = localPicker:GetColor()
			self._localSeq = ColorSequence.new(self._localColor)
		end
	end
	refreshColors()
	for _, key in next, { "enemyColor", "friendlyColor", "localColor" } do
		local picker: any = optsLink:Get(key)
		if picker then
			self:Track(picker:OnUpdate(refreshColors))
		end
	end

	self._screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 15,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Secure = true,
	}, cloneref(gethui())) :: ScreenGui

	self._root = ReactRoblox.createRoot(self._screenGui)
	self._root:render(e(warningRenderer, {
		enabledLink = self._enabledLink,
		enemyColorLink = optsLink:Get("enemyColor"),
		friendlyColorLink = optsLink:Get("friendlyColor"),
		localColorLink = optsLink:Get("localColor"),
		bgColorLink = optsLink:Get("bgColor"),
	}))

	refreshArcs()

	return self
end

function GrenadeWarning.updateArcs(self: GrenadeWarning): ()
	local active = GrenadeController.GetActive(self._activeScratch)

	local seen = self._seen
	table.clear(seen)
	local ignore = self._ignore

	for index = 1, #active do
		local entry = active[index]
		if not GrenadeController.isThrown(entry) then
			continue
		end
		seen[entry.object] = true

		local renderer = self._renderers[entry.object]
		if not renderer then
			renderer = worldPath.new()
			self._renderers[entry.object] = renderer
		end

		local root = entry.root
		local velocity = root.AssemblyLinearVelocity
		table.clear(ignore)
		ignore[1] = Terrain
		ignore[2] = entry.instance
		local result = grenadeSim.simulate(root, root.Position, velocity, ignore, entry.profile.bounces)

		local relation = GrenadeController.GetRelation(entry)
		local seq, color
		if relation == "local" then
			seq, color = self._localSeq, self._localColor
		elseif relation == "friendly" then
			seq, color = self._friendlySeq, self._friendlyColor
		else
			seq, color = self._enemySeq, self._enemyColor
		end
		renderer:Update(result.points, seq, color)
	end

	for object, renderer in next, self._renderers do
		if not seen[object] then
			renderer:Destroy()
			self._renderers[object] = nil
		end
	end
end

function GrenadeWarning.startArcs(self: GrenadeWarning): ()
	if self._arcJanitor then
		return
	end

	local janitor = Janitor.new()
	self._arcJanitor = janitor

	janitor:Add(function(): ()
		for object, renderer in next, self._renderers do
			renderer:Destroy()
			self._renderers[object] = nil
		end
	end, true)

	janitor:Add(RunService.RenderStepped:Connect(LPH_NO_VIRTUALIZE(function(): ()
		self:updateArcs()
	end)), "Disconnect")
end

function GrenadeWarning.stopArcs(self: GrenadeWarning): ()
	local janitor = self._arcJanitor
	if janitor then
		janitor:Destroy()
		self._arcJanitor = nil
	end
end

function GrenadeWarning.Destroy(self: GrenadeWarning): ()
	self:stopArcs()
	if self._root then
		self._root:unmount()
		self._root = nil
	end
	if self._screenGui then
		self._screenGui:Destroy()
		self._screenGui = nil
	end
	BaseFeature.Destroy(self)
end

return GrenadeWarning
