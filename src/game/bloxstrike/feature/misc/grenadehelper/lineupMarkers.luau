local instances = require("@share/instances")
local screenProject = require("@share/screenProject")
local FileController = require("@feature/file/FileController")
local lineupStore = require("@game/bloxstrike/feature/misc/grenadehelper/lineupStore")

local BG_COLOR = Color3.fromRGB(14, 14, 16)
local TITLE_COLOR = Color3.fromRGB(235, 235, 235)
local SUB_COLOR = Color3.fromRGB(160, 160, 160)
local TEXT_SIZE = 8
local MARKER_LIFT = Vector3.new(0, 0.4, 0)

type Marker = {
	frame: Frame,
	title: TextLabel,
	sub: TextLabel,
	prompt: TextLabel,
	stroke: UIStroke,
	aimFrame: Frame,
	aimLabel: TextLabel,
	aimStroke: UIStroke,
	lineup: lineupStore.Lineup?,
	lastTitle: string,
	lastSub: string,
	lastPrompt: string,
	lastDist: number,
	lastActive: boolean,
	lastHover: boolean,
}

local Markers = {}
Markers.__index = Markers

local function makeMarker(parent: Instance, font: Font, color: Color3): Marker
	local frame = instances.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = BG_COLOR,
		BackgroundTransparency = 0.25,
		Visible = false,
	}, parent) :: Frame

	instances.new("UICorner", { CornerRadius = UDim.new(0, 4) }, frame)
	instances.new("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	}, frame)
	instances.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
	}, frame)

	local stroke = instances.new("UIStroke", {
		Color = color,
		Thickness = 1,
		Transparency = 0.4,
	}, frame) :: UIStroke

	local title = instances.new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		FontFace = font,
		Text = "",
		TextColor3 = TITLE_COLOR,
		TextSize = TEXT_SIZE,
		LayoutOrder = 1,
	}, frame) :: TextLabel

	local sub = instances.new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		FontFace = font,
		Text = "",
		TextColor3 = SUB_COLOR,
		TextSize = TEXT_SIZE,
		LayoutOrder = 2,
	}, frame) :: TextLabel

	local prompt = instances.new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		FontFace = font,
		Text = "",
		TextColor3 = color,
		TextSize = TEXT_SIZE,
		LayoutOrder = 3,
		Visible = false,
	}, frame) :: TextLabel

	local aimFrame = instances.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.15,
		Visible = false,
	}, parent) :: Frame
	instances.new("UICorner", { CornerRadius = UDim.new(1, 0) }, aimFrame)
	local aimStroke = instances.new("UIStroke", {
		Color = BG_COLOR,
		Thickness = 1,
		Transparency = 0.2,
	}, aimFrame) :: UIStroke
	local aimLabel = instances.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 3),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		FontFace = font,
		Text = "",
		TextColor3 = TITLE_COLOR,
		TextSize = TEXT_SIZE,
	}, aimFrame) :: TextLabel

	return {
		frame = frame,
		title = title,
		sub = sub,
		prompt = prompt,
		stroke = stroke,
		aimFrame = aimFrame,
		aimLabel = aimLabel,
		aimStroke = aimStroke,
		lineup = nil,
		lastTitle = "",
		lastSub = "",
		lastPrompt = "",
		lastDist = -1,
		lastActive = false,
		lastHover = false,
	}
end

function Markers.new(parent: Instance): Markers
	local self = setmetatable({}, Markers) :: any
	self._parent = parent
	self._font = FileController.Get("font", "pixel2") :: Font
	self._color = Color3.fromRGB(140, 255, 140)
	self._pool = {} :: { Marker }
	self._count = 0
	return self
end

function Markers.SetColor(self: Markers, color: Color3): ()
	if self._color == color then
		return
	end
	self._color = color
	local pool = self._pool
	for i = 1, #pool do
		local marker = pool[i]
		marker.stroke.Color = color
		marker.prompt.TextColor3 = color
		marker.aimFrame.BackgroundColor3 = color
	end
end

function Markers.SetLineups(self: Markers, lineups: { lineupStore.Lineup }): ()
	local pool = self._pool
	local count = #lineups
	self._count = count

	for i = #pool + 1, count do
		pool[i] = makeMarker(self._parent, self._font, self._color)
	end

	for i = 1, #pool do
		local marker = pool[i]
		local lineup = lineups[i]
		marker.lineup = lineup
		marker.lastDist = -1
		if lineup then
			if marker.lastTitle ~= lineup.name then
				marker.lastTitle = lineup.name
				marker.title.Text = lineup.name
				marker.aimLabel.Text = lineup.name
			end
		else
			marker.frame.Visible = false
			marker.aimFrame.Visible = false
		end
	end
end

Markers.Draw = LPH_NO_VIRTUALIZE(function(
	self: Markers,
	project: screenProject.Projector,
	origin: Vector3,
	showDist: number,
	nearDist: number,
	activeLineup: lineupStore.Lineup?,
	promptFor: (lineup: lineupStore.Lineup, dist: number) -> string,
	fovPx: number,
	centerX: number,
	centerY: number
): lineupStore.Lineup?
	local pool = self._pool
	local bestHover: lineupStore.Lineup? = nil
	local bestHoverD2 = fovPx * fovPx

	for i = 1, self._count do
		local marker = pool[i]
		local lineup = marker.lineup :: lineupStore.Lineup
		local anchor = lineup.anchor or lineup.position
		local delta = anchor - origin
		local dist = delta.Magnitude
		if dist > showDist then
			if marker.frame.Visible then
				marker.frame.Visible = false
			end
			if marker.aimFrame.Visible then
				marker.aimFrame.Visible = false
			end
			continue
		end

		local aimVisible = false
		if dist <= nearDist then
			local aimPos = lineup.aimPos
			if aimPos then
				local aimScreen = project(aimPos)
				if aimScreen.Z > 0 then
					marker.aimFrame.Position = UDim2.fromOffset(aimScreen.X, aimScreen.Y)
					aimVisible = true
					local dxp = aimScreen.X - centerX
					local dyp = aimScreen.Y - centerY
					local d2 = dxp * dxp + dyp * dyp
					if d2 <= bestHoverD2 then
						bestHoverD2 = d2
						bestHover = lineup
					end
				end
			end
		end
		if marker.aimFrame.Visible ~= aimVisible then
			marker.aimFrame.Visible = aimVisible
		end

		local screenPos = project((lineup.markerPos or anchor) + MARKER_LIFT)
		if screenPos.Z <= 0 then
			if marker.frame.Visible then
				marker.frame.Visible = false
			end
			continue
		end

		marker.frame.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)

		local roundedDist = dist // 1
		if roundedDist ~= marker.lastDist then
			marker.lastDist = roundedDist
			local sub = `{lineup.grenade} · {roundedDist}st`
			if marker.lastSub ~= sub then
				marker.lastSub = sub
				marker.sub.Text = sub
			end
		end

		local prompt = promptFor(lineup, dist)
		if marker.lastPrompt ~= prompt then
			marker.lastPrompt = prompt
			marker.prompt.Text = prompt
			marker.prompt.Visible = prompt ~= ""
		end

		local active = lineup == activeLineup
		if active ~= marker.lastActive then
			marker.lastActive = active
			marker.stroke.Transparency = active and 0 or 0.4
			marker.stroke.Thickness = active and 2 or 1
		end

		if not marker.frame.Visible then
			marker.frame.Visible = true
		end
	end

	for i = 1, self._count do
		local marker = pool[i]
		local hover = bestHover ~= nil and marker.lineup == bestHover
		if hover ~= marker.lastHover then
			marker.lastHover = hover
			marker.aimFrame.Size = hover and UDim2.fromOffset(10, 10) or UDim2.fromOffset(6, 6)
			marker.aimFrame.BackgroundTransparency = hover and 0 or 0.15
			marker.aimStroke.Transparency = hover and 0 or 0.2
		end
	end

	return bestHover
end)

function Markers.HideAll(self: Markers): ()
	local pool = self._pool
	for i = 1, #pool do
		local marker = pool[i]
		if marker.frame.Visible then
			marker.frame.Visible = false
		end
		if marker.aimFrame.Visible then
			marker.aimFrame.Visible = false
		end
	end
end

function Markers.Destroy(self: Markers): ()
	local pool = self._pool
	for i = 1, #pool do
		pool[i].frame:Destroy()
		pool[i].aimFrame:Destroy()
	end
	table.clear(pool)
	self._count = 0
end

export type Markers = typeof(setmetatable(
	{} :: {
		_parent: Instance,
		_font: Font,
		_color: Color3,
		_pool: { Marker },
		_count: number,
	},
	Markers
))

return Markers
