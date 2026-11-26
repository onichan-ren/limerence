local RunService = cloneref(game:GetService("RunService")) :: RunService

local FileController = require("@feature/file/FileController")
local instances = require("@share/instances")

local tipMetrics = {}

tipMetrics.MAX_BODY_WIDTH = 250
tipMetrics.TITLE_TEXT_SIZE = 14
tipMetrics.BODY_TEXT_SIZE = 12

local MAX_MEASURE_FRAMES = 4

local cache: { [string]: Vector2 } = {}
local _label: TextLabel? = nil

local function ensureLabel(): TextLabel
	local label = _label
	if label and label.Parent then
		return label
	end
	local gui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = -100,
		Secure = true,
	}, cloneref(gethui())) :: ScreenGui
	label = instances.new("TextLabel", {
		BackgroundTransparency = 1,
		TextTransparency = 1,
		BorderSizePixel = 0,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Position = UDim2.fromOffset(-8192, -8192),
		Text = "",
	}, gui) :: TextLabel
	_label = label
	return label
end

function tipMetrics.estimate(text: string, textSize: number, maxWidth: number): Vector2
	local chars = utf8.len(text) or #text
	local estimated = chars * textSize * 0.53
	local lines = math.max(1, math.ceil(estimated / maxWidth))
	return Vector2.new(math.min(estimated, maxWidth), lines * textSize)
end

function tipMetrics.measure(text: string, textSize: number, maxWidth: number): Vector2
	if text == "" then
		return Vector2.zero
	end
	local key = `{textSize}\0{text}`
	local cached = cache[key]
	if cached then
		return cached
	end
	local ok, bounds = pcall(function(): Vector2?
		local label = ensureLabel()
		label.FontFace = FileController.Get("font", "semi_bold")
		label.TextSize = textSize
		label.Size = UDim2.fromOffset(maxWidth, 4096)
		label.Text = text
		local measured = label.TextBounds
		local frames = 0
		while measured.Y <= 0 and frames < MAX_MEASURE_FRAMES do
			RunService.RenderStepped:Wait()
			measured = label.TextBounds
			frames += 1
		end
		if measured.Y <= 0 then
			return nil
		end
		return Vector2.new(math.min(measured.X, maxWidth), measured.Y)
	end)
	if ok and typeof(bounds) == "Vector2" then
		cache[key] = bounds
		return bounds
	end
	return tipMetrics.estimate(text, textSize, maxWidth)
end

return tipMetrics
