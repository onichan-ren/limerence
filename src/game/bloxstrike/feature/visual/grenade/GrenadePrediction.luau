local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local grenadePredictionShared = require("@game/bloxstrike/grenade/grenadePredictionShared")
local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local clientState = require("@game/bloxstrike/client/clientState")
local clientApi = require("@game/bloxstrike/client/clientApi")
local PlayerController = require("@feature/player/PlayerController")
local React = require("@pkg/React")
local gamemodeState = require("@game/bloxstrike/gamemodeState")
local ReactRoblox = require("@pkg/ReactRoblox")
local predDamage = require("@game/bloxstrike/feature/visual/grenade/predictionDamageRenderer")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Terrain = Workspace.Terrain

local peek = Charm.peek
local e = React.createElement

local DEFAULT_PATH_COLOR = Color3.fromRGB(145, 190, 215)
local DEFAULT_IMPACT_COLOR = Color3.fromRGB(120, 200, 130)

local LINE_WIDTH = 0.06
local PATH_TRANSPARENCY = 0.15
local IMPACT_SIZE = 0.06

local HE_MAX_RANGE = 22.3
local HE_FALLOFF = 0.27
local HE_ARMOR_FACTOR = 0.574

local FIRE_INSIDE_RANGE = 8
local FIRE_EDGE_RANGE = 13
local FIRE_DISPLAY_RANGE = 20
local FIRE_EDGE_COLOR = Color3.fromRGB(245, 175, 80)

local function resolveColor(value: any, fallback: Color3): Color3
	local t = typeof(value)
	if t == "Color3" then
		return value :: Color3
	end
	if t == "ColorSequence" then
		return (value :: ColorSequence).Keypoints[1].Value
	end
	return fallback
end

local estimateHeSelfDamage = LPH_NO_VIRTUALIZE(function(dist: number, hasArmor: boolean): number
	local dmg = HE_FALLOFF * math.max(0, HE_MAX_RANGE - dist) ^ 2 * (hasArmor and HE_ARMOR_FACTOR or 1.0)
	return dmg < 0.5 and 0 or math.floor(dmg + 0.5)
end)

local GrenadePrediction = {}
GrenadePrediction.__index = GrenadePrediction

setmetatable(GrenadePrediction, { __index = BaseFeature })

function GrenadePrediction.new(link: gameUi.Linker): GrenadePrediction
	local self = BaseFeature.new() :: any
	setmetatable(self, GrenadePrediction)

	local prediction = link:Toggle("grenadePrediction", "Grenade Prediction", false):SetTip({
		title = "Grenade Prediction",
		body = "Draws the predicted arc and landing point of the grenade you are holding.",
	})
	local predictionLink = link:OnKey("grenadePrediction")
	predictionLink:Extra(prediction, "impactColor", "Colorpicker", "Impact Color", DEFAULT_IMPACT_COLOR)
	predictionLink:Extra(prediction, "pathColor", "Colorpicker", "Path Color", DEFAULT_PATH_COLOR)

	self._activeJanitor = nil :: Janitor.Janitor?

	self._holder = nil :: Part?
	self._attachments = {} :: { Attachment }
	self._beams = {} :: { Beam }
	self._impactSphere = nil :: Part?

	self._pathColor = DEFAULT_PATH_COLOR
	self._impactColor = DEFAULT_IMPACT_COLOR
	self._pathColorSeq = ColorSequence.new(DEFAULT_PATH_COLOR)

	self:Track(link:Watch("grenadePrediction", function(enabled: any)
		if enabled then
			self:enable()
		else
			self:disable()
		end
	end))

	self:Track(predictionLink:Watch("pathColor", function(value: any)
		self._pathColor = resolveColor(value, DEFAULT_PATH_COLOR)
		self:refreshBeamColors()
	end))
	self:Track(predictionLink:Watch("impactColor", function(value: any)
		self._impactColor = resolveColor(value, DEFAULT_IMPACT_COLOR)
		if self._impactSphere then
			self._impactSphere.Color = self._impactColor
		end
	end))

	self._pathColor = resolveColor(predictionLink:Peek("pathColor"), DEFAULT_PATH_COLOR)
	self._impactColor = resolveColor(predictionLink:Peek("impactColor"), DEFAULT_IMPACT_COLOR)
	self._pathColorSeq = ColorSequence.new(self._pathColor)

	local predGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Enabled = true,
		DisplayOrder = 15,
	}, cloneref(gethui()))
	self._predGui = predGui

	self._predRoot = ReactRoblox.createRoot(predGui)
	self._predRoot:render(e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, {
		Display = e(predDamage.render),
	}))

	if link:Peek("grenadePrediction") == true then
		self:enable()
	end

	return self
end

function GrenadePrediction.ensureHolder(self: GrenadePrediction): Part
	local holder = self._holder
	if holder then
		return holder
	end
	holder = instances.new("Part", {
		Name = "GrenadePredictionHolder",
		Size = Vector3.new(0.05, 0.05, 0.05),
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Secure = true,
	}, Terrain) :: Part
	self._holder = holder

	local impact = instances.new("Part", {
		Name = "GrenadePredictionImpact",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(IMPACT_SIZE, IMPACT_SIZE, IMPACT_SIZE),
		Material = Enum.Material.Neon,
		Color = self._impactColor,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 0.25,
		Secure = true,
	}, Terrain) :: Part
	self._impactSphere = impact

	return holder :: any
end

function GrenadePrediction.destroyHolder(self: GrenadePrediction): ()
	for _, beam in next, self._beams do
		beam:Destroy()
	end
	self._beams = {}
	for _, att in next, self._attachments do
		att:Destroy()
	end
	self._attachments = {}
	if self._impactSphere then
		self._impactSphere:Destroy()
		self._impactSphere = nil
	end
	predDamage.setPrediction(nil)
	if self._holder then
		self._holder:Destroy()
		self._holder = nil
	end
end

GrenadePrediction.ensureAttachments = LPH_NO_VIRTUALIZE(function(self: GrenadePrediction, count: number): ()
	local holder = self._holder
	if not holder then
		return
	end
	local existing = #self._attachments
	if count > existing then
		for i = existing + 1, count do
			local a = instances.new("Attachment", { Secure = true }, holder) :: Attachment
			self._attachments[i] = a
		end
	elseif count < existing then
		for i = existing, count + 1, -1 do
			self._attachments[i]:Destroy()
			self._attachments[i] = nil
		end
	end
end)

GrenadePrediction.ensureBeams = LPH_NO_VIRTUALIZE(function(self: GrenadePrediction, count: number): ()
	local holder = self._holder
	if not holder then
		return
	end
	local existing = #self._beams
	if count > existing then
		local colorSeq = self._pathColorSeq
		for i = existing + 1, count do
			local b = instances.new("Beam", {
				Attachment0 = self._attachments[i],
				Attachment1 = self._attachments[i + 1],
				Width0 = LINE_WIDTH,
				Width1 = LINE_WIDTH,
				FaceCamera = true,
				LightEmission = 1,
				LightInfluence = 0,
				Segments = 1,
				TextureMode = Enum.TextureMode.Stretch,
				Transparency = NumberSequence.new(PATH_TRANSPARENCY),
				Color = colorSeq,
				Secure = true,
			}, holder) :: Beam
			self._beams[i] = b
		end
	elseif count < existing then
		for i = existing, count + 1, -1 do
			self._beams[i]:Destroy()
			self._beams[i] = nil
		end
	end
end)

function GrenadePrediction.refreshBeamColors(self: GrenadePrediction): ()
	self._pathColorSeq = ColorSequence.new(self._pathColor)
	for _, b in next, self._beams do
		b.Color = self._pathColorSeq
	end
end

function GrenadePrediction.hide(self: GrenadePrediction): ()
	if self._holder then
		self:destroyHolder()
	end
end

GrenadePrediction.update = LPH_NO_VIRTUALIZE(function(self: GrenadePrediction): ()
	local result = grenadePredictionShared.getCurrent()
	if not result then
		self:hide()
		return
	end

	local points = result.points
	local n = #points
	local grenadeName = result.grenadeName
	local profile = result.profile
	local root = result.rootPart

	self:ensureHolder()
	self:ensureAttachments(n)
	for i = 1, n do
		self._attachments[i].WorldPosition = points[i]
	end

	self:ensureBeams(n - 1)

	if self._impactSphere then
		self._impactSphere.CFrame = CFrame.new(points[n])
	end

	if grenadeName == "HE Grenade" then
		local impactPos = points[n]
		local armor = peek(clientState.armor)
		local selfDmg = estimateHeSelfDamage((root.Position - impactPos).Magnitude, armor.kevlar)
		local hp = clientApi.GetHealth()
		local selfLethal = selfDmg > 0 and selfDmg >= hp
		local myTeam = peek(clientState.team)
		local enemies: { predDamage.EnemyEntry } = {}

		for _, basePlayer in next, PlayerController.GetAll() do
			if peek(basePlayer.team) == myTeam and not gamemodeState.isDeathmatch() then
				continue
			end
			local hrp = peek(basePlayer.hrp) :: BasePart?
			if not hrp then
				continue
			end
			local dist = (hrp.Position - impactPos).Magnitude
			if dist > HE_MAX_RANGE then
				continue
			end
			local dmg = estimateHeSelfDamage(dist, false)
			if dmg <= 0 then
				continue
			end
			local enemyHp = peek(basePlayer.health)
			table.insert(enemies, {
				dmg = dmg,
				lethal = enemyHp ~= nil and dmg >= enemyHp,
			})
		end

		if selfDmg > 0 or #enemies > 0 then
			predDamage.setPrediction({
				impactPos = impactPos,
				selfDmg = selfDmg,
				selfLethal = selfLethal,
				enemies = enemies,
				color = self._impactColor,
			})
		else
			predDamage.setPrediction(nil)
		end
	elseif profile.leavesFire then
		local impactPos = points[n]
		local myTeam = peek(clientState.team)
		local enemies: { predDamage.EnemyEntry } = {}

		for _, basePlayer in next, PlayerController.GetAll() do
			if peek(basePlayer.team) == myTeam and not gamemodeState.isDeathmatch() then
				continue
			end
			local hrp = peek(basePlayer.hrp) :: BasePart?
			if not hrp then
				continue
			end
			local dist = (hrp.Position - impactPos).Magnitude
			if dist > FIRE_DISPLAY_RANGE then
				continue
			end
			local distRounded = math.floor(dist + 0.5)
			local inFire = dist <= FIRE_INSIDE_RANGE
			local onEdge = not inFire and dist <= FIRE_EDGE_RANGE
			table.insert(enemies, {
				dmg = math.floor(FIRE_DISPLAY_RANGE - dist + 0.5),
				lethal = inFire,
				text = string.format("%ds", distRounded),
				color = (onEdge and FIRE_EDGE_COLOR or nil),
			})
		end

		local selfDist = (root.Position - impactPos).Magnitude
		local selfInFire = selfDist <= FIRE_INSIDE_RANGE
		local selfOnEdge = not selfInFire and selfDist <= FIRE_EDGE_RANGE
		local selfShow = selfDist <= FIRE_DISPLAY_RANGE

		if selfShow or #enemies > 0 then
			predDamage.setPrediction({
				impactPos = impactPos,
				selfDmg = (selfShow and math.max(1, math.floor(FIRE_DISPLAY_RANGE - selfDist + 0.5)) or 0),
				selfLethal = selfInFire,
				selfText = (selfShow and string.format("self %ds", math.floor(selfDist + 0.5)) or nil),
				selfColor = (selfOnEdge and FIRE_EDGE_COLOR or nil),
				enemies = enemies,
				color = self._impactColor,
			})
		else
			predDamage.setPrediction(nil)
		end
	else
		predDamage.setPrediction(nil)
	end
end)

function GrenadePrediction.enable(self: GrenadePrediction): ()
	if self._activeJanitor then
		return
	end
	local activeJanitor = Janitor.new()
	self._activeJanitor = activeJanitor

	RunService:BindToRenderStep(
		"GrenadePredictionRender",
		Enum.RenderPriority.Camera.Value + 1,
		LPH_NO_VIRTUALIZE(function()
			self:update()
		end)
	)
	activeJanitor:Add(function()
		RunService:UnbindFromRenderStep("GrenadePredictionRender")
	end, true)

	activeJanitor:Add(function()
		self:destroyHolder()
	end, true)
end

function GrenadePrediction.disable(self: GrenadePrediction): ()
	local activeJanitor = self._activeJanitor
	if not activeJanitor then
		return
	end
	self._activeJanitor = nil
	activeJanitor:Destroy()
end

function GrenadePrediction.Destroy(self: GrenadePrediction): ()
	self:disable()
	if self._predRoot then
		self._predRoot:unmount()
		self._predRoot = nil
	end
	if self._predGui then
		self._predGui:Destroy()
		self._predGui = nil
	end
	BaseFeature.Destroy(self)
end

export type GrenadePrediction =
	typeof(setmetatable(
		{} :: {
			_activeJanitor: Janitor.Janitor?,
			_holder: Part?,
			_attachments: { Attachment },
			_beams: { Beam },
			_impactSphere: Part?,
			_predGui: Instance?,
			_predRoot: ReactRoblox.RootType?,
			_pathColor: Color3,
			_impactColor: Color3,
			_pathColorSeq: ColorSequence,
		},
		GrenadePrediction
	))
	& BaseFeature.BaseFeature

return GrenadePrediction
