local Players = cloneref(game:GetService("Players")) :: Players
local RunService = cloneref(game:GetService("RunService")) :: RunService

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local FileController = require("@feature/file/FileController")
local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local playerApi = require("@game/ar2/player/playerApi")
local playerState = require("@feature/record/module/playerState")
local clientState = require("@game/ar2/client/clientState")

local peek = Charm.peek
local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer

local MAP_CFRAME =
	CFrame.new(Vector3.new(-7349.5498046875, 0, -6187.35009765625), Vector3.new(-7349.5498046875, 0, -6186.35009765625))
local MAP_SCALE = Vector3.new(-13499.068359375, 0, -12386.18359375)

local DEFAULT_ENEMY = Color3.fromRGB(225, 65, 65)
local DEFAULT_FRIENDLY = Color3.fromRGB(120, 200, 130)
local OUTLINE = Color3.new(0, 0, 0)
local TEXT_SIZE = 8

local toColor3 = LPH_NO_VIRTUALIZE(function(v: any): Color3
	if typeof(v) == "ColorSequence" then
		local kp = v.Keypoints[1]
		return (kp and kp.Value) or Color3.new(1, 1, 1)
	end
	return v
end)

local getMapScale = LPH_NO_VIRTUALIZE(function(worldPos: Vector3): (number, number)
	local v = MAP_CFRAME:PointToObjectSpace(worldPos) / MAP_SCALE
	return v.X, v.Z
end)

type Marker = {
	root: Frame,
	dot: ImageLabel,
	nameLabel: TextLabel,
	distLabel: TextLabel,
	playerName: string,
	lastName: string,
	lastDist: number,
}

local SEEN_SCRATCH: { [Player]: boolean } = {}

local MapEsp = {}
MapEsp.__index = MapEsp

setmetatable(MapEsp, { __index = BaseFeature })

function MapEsp.new(link: gameUi.Linker): MapEsp
	local self = BaseFeature.new() :: any
	setmetatable(self, MapEsp)

	link:Toggle("mapEsp", "Map ESP", false):SetTip({
		title = "Map ESP",
		body = "Marks players on the in game map.",
	})
	local rootLink = link:OnKey("mapEsp")
	rootLink:Submenu("opts", "Map ESP")
	local optsLink = rootLink:OnKey("opts")

	optsLink:Options("markers", "Markers")
	local markersLink = optsLink:OnKey("markers")
	markersLink:Toggle("showDot", "Dots", true):SetTip({
		title = "Dots",
		body = "Shows a marker dot for each player.",
	})
	markersLink:Toggle("showName", "Names", false):SetTip({
		title = "Names",
		body = "Shows the player name next to the marker.",
	})
	markersLink:Toggle("showDistance", "Distance", false):SetTip({
		title = "Distance",
		body = "Shows how far the player is from you in studs.",
	})
	markersLink:Slider("dotSize", "Dot Size", 8, 3, 16, 1, nil, "px")

	optsLink:Options("colors", "Colors")
	local colorsLink = optsLink:OnKey("colors")
	colorsLink:Colorpicker("enemyColor", "Enemy", DEFAULT_ENEMY)
	colorsLink:Colorpicker("friendlyColor", "Friendly", DEFAULT_FRIENDLY)

	self._enabled = false
	self._janitor = nil :: Janitor.Janitor?
	self._dragBin = nil :: Instance?
	self._mapGui = nil :: Instance?
	self._container = nil :: Frame?
	self._markers = {} :: { [Player]: Marker }
	self._cache = {
		showDot = true,
		showName = false,
		showDistance = false,
		dotSize = 8,
		enemyColor = DEFAULT_ENEMY,
		friendlyColor = DEFAULT_FRIENDLY,
	}

	self:Track(link:Get("mapEsp"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(link:Watch("mapEsp.opts.markers.showDot", function(v: boolean): ()
		self._cache.showDot = v
	end))
	self:Track(link:Watch("mapEsp.opts.markers.showName", function(v: boolean): ()
		self._cache.showName = v
	end))
	self:Track(link:Watch("mapEsp.opts.markers.showDistance", function(v: boolean): ()
		self._cache.showDistance = v
	end))
	self:Track(link:Watch("mapEsp.opts.markers.dotSize", function(v: number): ()
		self._cache.dotSize = v
	end))
	local enemyLink = colorsLink:Get("enemyColor")
	local friendlyLink = colorsLink:Get("friendlyColor")
	self._cache.enemyColor = toColor3(peek(enemyLink._state))
	self._cache.friendlyColor = toColor3(peek(friendlyLink._state))
	self:Track(sub(enemyLink._state, function(v: any): ()
		self._cache.enemyColor = toColor3(v)
	end))
	self:Track(sub(friendlyLink._state, function(v: any): ()
		self._cache.friendlyColor = toColor3(v)
	end))

	if link:Peek("mapEsp") then
		self:Enable()
	end

	return self
end

function MapEsp._resolveDragBin(self: MapEsp): Instance?
	if self._dragBin and self._dragBin.Parent then
		return self._dragBin
	end

	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end
	local mapGui = playerGui:FindFirstChild("Map")
	if not mapGui then
		local guiMain = playerGui:FindFirstChild("GuiMain")
		mapGui = guiMain and guiMain:FindFirstChild("Map")
	end
	if not mapGui then
		return nil
	end
	local clipBin = mapGui:FindFirstChild("ClipBin")
	local dragBin = clipBin and clipBin:FindFirstChild("DragBin")
	if not dragBin then
		return nil
	end

	self._mapGui = mapGui
	self._dragBin = dragBin
	return dragBin
end

function MapEsp._ensureContainer(self: MapEsp, dragBin: Instance): Frame
	local container = self._container
	if container and container.Parent == dragBin then
		return container
	end
	container = instances.new("Frame", {
		Name = "LimerenceMapEsp",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
	}, dragBin) :: Frame
	self._container = container
	return container
end

function MapEsp._createMarker(self: MapEsp, container: Frame, playerName: string): Marker
	local root = instances.new("Frame", {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(6, 6),
		ZIndex = 61,
	}, container) :: Frame

	local dot = instances.new("ImageLabel", {
		Name = "Dot",
		Image = FileController.Get("image", "circle_shadow"),
		ImageColor3 = DEFAULT_ENEMY,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1.1, 1.1),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 61,
	}, root) :: ImageLabel

	local nameLabel = instances.new("TextLabel", {
		Name = "Name",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		FontFace = FileController.Get("font", "pixel"),
		TextSize = TEXT_SIZE,
		TextColor3 = DEFAULT_ENEMY,
		Text = "",
		Visible = false,
		ZIndex = 62,
	}, root) :: TextLabel
	instances.new("UIStroke", {
		Color = OUTLINE,
		Thickness = 1,
		Transparency = 0.1,
	}, nameLabel)

	local distLabel = instances.new("TextLabel", {
		Name = "Distance",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		FontFace = FileController.Get("font", "pixel"),
		TextSize = TEXT_SIZE,
		TextColor3 = DEFAULT_ENEMY,
		Text = "",
		Visible = false,
		ZIndex = 62,
	}, root) :: TextLabel
	instances.new("UIStroke", {
		Color = OUTLINE,
		Thickness = 1,
		Transparency = 0.1,
	}, distLabel)

	return {
		root = root,
		dot = dot,
		nameLabel = nameLabel,
		distLabel = distLabel,
		playerName = playerName,
		lastName = "",
		lastDist = -1,
	}
end

MapEsp._tick = LPH_NO_VIRTUALIZE(function(self: MapEsp): ()
	local dragBin = self:_resolveDragBin()
	if not dragBin then
		return
	end
	local mapGui = self._mapGui :: any
	if mapGui and mapGui.Enabled == false then
		local container = self._container
		if container then
			container.Visible = false
		end
		return
	end

	local container = self:_ensureContainer(dragBin)
	container.Visible = true

	local cache = self._cache
	local markers = self._markers
	local seen = SEEN_SCRATCH
	table.clear(seen)

	local showDot = cache.showDot
	local showName = cache.showName
	local showDist = cache.showDistance
	local dotSize = cache.dotSize

	local localHrp = showDist and peek(clientState.hrp) or nil
	local localPos = localHrp and localHrp.Position or nil

	for _, player in next, playerApi.GetAll() do
		if player == LocalPlayer then
			continue
		end
		local handle = playerApi.Get(player)
		if not handle or not handle.isAlive() then
			continue
		end
		local pos = handle.getPosition()
		if not pos then
			continue
		end

		local friendly = playerState.ShouldSkip(player.UserId)

		seen[player] = true
		local marker = markers[player]
		if not marker then
			marker = self:_createMarker(container, player.DisplayName)
			markers[player] = marker
		end

		local x, y = getMapScale(pos)
		local root = marker.root
		root.Position = UDim2.fromScale(x, y)

		local color = friendly and cache.friendlyColor or cache.enemyColor
		root.Size = UDim2.fromOffset(dotSize, dotSize)
		local dot = marker.dot
		dot.ImageColor3 = color
		dot.Visible = showDot

		local nameLabel = marker.nameLabel
		nameLabel.Visible = showName
		if showName then
			if marker.playerName ~= marker.lastName then
				marker.lastName = marker.playerName
				nameLabel.Text = marker.playerName
			end
			nameLabel.TextColor3 = color
			nameLabel.Position = UDim2.new(0.5, 0, 0, -math.floor(dotSize / 2) - 5)
		end

		local distLabel = marker.distLabel
		distLabel.Visible = showDist
		if showDist then
			local dist = localPos and math.round((pos - localPos).Magnitude) or 0
			if dist ~= marker.lastDist then
				marker.lastDist = dist
				distLabel.Text = `{dist}m`
			end
			distLabel.TextColor3 = color
			distLabel.Position = UDim2.new(1, math.floor(dotSize / 2) - 1, 0.5, 0)
		end
	end

	for player, marker in next, markers do
		if not seen[player] then
			marker.root:Destroy()
			markers[player] = nil
		end
	end
end)

function MapEsp.Enable(self: MapEsp): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local janitor = Janitor.new()
	self._janitor = janitor

	janitor:Add(RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
		self:_tick()
	end)))
	janitor:Add(function(): ()
		for player, marker in next, self._markers do
			marker.root:Destroy()
			self._markers[player] = nil
		end
		if self._container then
			self._container:Destroy()
			self._container = nil
		end
		self._dragBin = nil
		self._mapGui = nil
	end)
end

function MapEsp.Disable(self: MapEsp): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	local janitor = self._janitor
	if janitor then
		self._janitor = nil
		janitor:Destroy()
	end
end

function MapEsp.Destroy(self: MapEsp): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type MapEsp =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor?,
			_dragBin: Instance?,
			_mapGui: Instance?,
			_container: Frame?,
			_markers: { [Player]: Marker },
			_cache: {
				showDot: boolean,
				showName: boolean,
				showDistance: boolean,
				dotSize: number,
				enemyColor: Color3,
				friendlyColor: Color3,
			},
		},
		MapEsp
	))
	& BaseFeature.BaseFeature

return MapEsp
