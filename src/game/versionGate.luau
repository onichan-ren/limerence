local Charm = require("@pkg/Charm")
local instances = require("@share/instances")
local str = require("@share/strings")
local themeState = require("@ui/theme/themeState")

local HttpService = cloneref(game:GetService("HttpService")) :: HttpService
local TweenService = cloneref(game:GetService("TweenService")) :: TweenService

local peek = Charm.peek

local FONTS_DIR = "limerence.biz/assets/fonts"
local FONT_REGULAR = Font.fromEnum(Enum.Font.GothamMedium)
local FONT_BOLD = Font.fromEnum(Enum.Font.GothamBold)
local HOVER_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local WHITE = Color3.new(1, 1, 1)

local versionGate = {}

local fontsResolved = false

local function loadFontFromDisk(name: string): Font?
	local ttfPath = `{FONTS_DIR}/{name}.ttf`
	if not isfile(ttfPath) then
		return nil
	end
	local jsonName = str.randomSafe()
	local jsonPath = `{jsonName}.font.json`
	writefile(
		jsonPath,
		HttpService:JSONEncode({
			name = jsonName,
			faces = {
				{ name = "Bold", weight = 700, style = "normal", assetId = getcustomasset(ttfPath) },
			},
		})
	)
	local font = Font.new(getcustomasset(jsonPath), Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	delfile(jsonPath)
	return font
end

local function resolveFonts(): ()
	if fontsResolved then
		return
	end
	fontsResolved = true

	local semiBold = loadFontFromDisk("semi_bold")
	local bold = loadFontFromDisk("bold")
	if semiBold then
		FONT_REGULAR = semiBold
	end
	if bold then
		FONT_BOLD = bold
	elseif semiBold then
		FONT_BOLD = semiBold
	end
end

local function bindHoverBackground(button: GuiButton, baseColor: Color3): ()
	local hoverColor = baseColor:Lerp(WHITE, peek(themeState.other.hoverTint))
	button.MouseEnter:Connect(function(): ()
		TweenService:Create(button, HOVER_TWEEN, { BackgroundColor3 = hoverColor }):Play()
	end)
	button.MouseLeave:Connect(function(): ()
		TweenService:Create(button, HOVER_TWEEN, { BackgroundColor3 = baseColor }):Play()
	end)
end

local function promptChoice(supportedVersion: number, liveVersion: number): string
	resolveFonts()

	local canvasBackground = peek(themeState.colors.canvas.background)
	local windowColors = themeState.colors.window
	local elementColors = windowColors.element

	local windowBackground = peek(windowColors.background)
	local windowStroke = peek(windowColors.stroke)
	local windowTitle = peek(windowColors.title)
	local accent = peek(elementColors.accent)
	local fieldBackground = peek(elementColors.fieldBackground)
	local fieldStroke = peek(elementColors.fieldStroke)
	local text = peek(elementColors.text)

	local gui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		DisplayOrder = 10000,
	}, cloneref(gethui())) :: ScreenGui

	instances.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = canvasBackground[1],
		BackgroundTransparency = canvasBackground[2],
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = false,
		Text = "",
	}, gui)

	local panel = instances.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = windowBackground,
		BorderSizePixel = 0,
	}, gui)
	instances.new("UICorner", { CornerRadius = UDim.new(0, 8) }, panel)
	instances.new("UIStroke", { Color = windowStroke, Thickness = 1 }, panel)
	instances.new("UIPadding", {
		PaddingTop = UDim.new(0, 20),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 20),
		PaddingRight = UDim.new(0, 20),
	}, panel)
	instances.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
	}, panel)

	instances.new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		FontFace = FONT_BOLD,
		Text = "Game Updated",
		TextColor3 = windowTitle,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
	}, panel)

	instances.new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = FONT_REGULAR,
		Text = `This game updated to version {liveVersion}, but version {supportedVersion} is the latest supported one. Some features may not work correctly until support for the new version is confirmed.`,
		TextColor3 = text,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
	}, panel)

	local buttonRow = instances.new("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
	}, panel)
	instances.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, buttonRow)

	local cancelButton = instances.new("TextButton", {
		Size = UDim2.fromOffset(96, 32),
		BackgroundColor3 = fieldBackground,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		FontFace = FONT_REGULAR,
		Text = "Cancel",
		TextColor3 = text,
		Active = false,
		TextSize = 14,
		LayoutOrder = 1,
	}, buttonRow) :: TextButton
	instances.new("UICorner", { CornerRadius = UDim.new(0, 6) }, cancelButton)
	instances.new("UIStroke", { Color = fieldStroke, Thickness = 1 }, cancelButton)
	bindHoverBackground(cancelButton, fieldBackground)

	local loadButton = instances.new("TextButton", {
		Size = UDim2.fromOffset(120, 32),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		FontFace = FONT_BOLD,
		Text = "Load  Anyway",
		TextColor3 = windowBackground,
		Active = false,
		TextSize = 14,
		LayoutOrder = 2,
	}, buttonRow) :: TextButton
	instances.new("UICorner", { CornerRadius = UDim.new(0, 6) }, loadButton)
	bindHoverBackground(loadButton, accent)

	local choice: string? = nil
	cancelButton.MouseButton1Click:Connect(function(): ()
		choice = "cancel"
	end)
	loadButton.MouseButton1Click:Connect(function(): ()
		choice = "load"
	end)

	while not choice do
		task.wait()
	end

	gui:Destroy()

	return choice :: string
end

function versionGate.Check(placeVersions: { [number]: number }?): boolean
	if not placeVersions then
		return true
	end

	local supportedVersion = placeVersions[game.PlaceId]
	if not supportedVersion or supportedVersion <= 0 then
		return true
	end

	local liveVersion = game.PlaceVersion
	if liveVersion == 0 or liveVersion <= supportedVersion then
		return true
	end

	return promptChoice(supportedVersion, liveVersion) == "load"
end

return versionGate
