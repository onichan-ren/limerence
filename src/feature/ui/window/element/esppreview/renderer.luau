local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local themeState = require("@ui/theme/themeState")
local FileController = require("@feature/file/FileController")
local cursor = require("@ui/util/cursor")
local useAdvColor = require("@ui/hook/useAdvColor")

local e = React.createElement
local useRef = React.useRef
local useEffect = React.useEffect
local useMemo = React.useMemo
local useCallback = React.useCallback
local useAt = ReactCharm.useAtom

local colors = themeState.colors.window.element

local PREVIEW_HEIGHT = 214
local GRID_CELL = 24
local GRID_LINE = 1
local GRID_TRANSPARENCY = 0.6
local GRID_COLUMNS = 30
local GRID_ROWS = math.ceil(PREVIEW_HEIGHT / GRID_CELL)

local function buildGrid(color: Color3): { [string]: React.Element<any> }
	local children: { [string]: React.Element<any> } = {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
	}
	for i = 1, GRID_COLUMNS do
		children[`VLine_{i}`] = e("Frame", {
			Size = UDim2.new(0, GRID_LINE, 1, 0),
			Position = UDim2.fromOffset(i * GRID_CELL, 0),
			BackgroundColor3 = color,
			BackgroundTransparency = GRID_TRANSPARENCY,
			BorderSizePixel = 0,
		})
	end
	for i = 1, GRID_ROWS do
		children[`HLine_{i}`] = e("Frame", {
			Size = UDim2.new(1, 0, 0, GRID_LINE),
			Position = UDim2.fromOffset(0, i * GRID_CELL),
			BackgroundColor3 = color,
			BackgroundTransparency = GRID_TRANSPARENCY,
			BorderSizePixel = 0,
		})
	end
	return children
end

export type EspPreviewRendererProperties = {
	EspPreview: any,
	LayoutOrder: number?,
}

return function(properties: EspPreviewRendererProperties): React.Element<any>
	local element = properties.EspPreview
	local config = element._config

	local surface = useAt(colors.surface)
	local surfaceStroke = useAt(colors.surfaceStroke)

	local hasSettings = config.hasSettings == true
	local cogBg = useAdvColor(colors.surface, colors.accent, config.settingsOpen)
	local cogStroke = useAdvColor(colors.surfaceStroke, colors.accentStrong, config.settingsOpen)
	local cogIcon = useAdvColor(colors.caption, colors.textActive, config.settingsOpen)

	local openSettings = useCallback(function(): ()
		local fn = config.openSettings
		if fn then
			fn(cursor.getPosition())
		end
	end, {})

	local cogEnter = useCallback(function(): ()
		cogBg.onMouseEnter()
		cogStroke.onMouseEnter()
		cogIcon.onMouseEnter()
	end, { cogBg, cogStroke, cogIcon } :: { any })

	local cogLeave = useCallback(function(): ()
		cogBg.onMouseLeave()
		cogStroke.onMouseLeave()
		cogIcon.onMouseLeave()
	end, { cogBg, cogStroke, cogIcon } :: { any })

	local gridChildren = useMemo(function()
		return buildGrid(surfaceStroke)
	end, { surfaceStroke })

	local viewportRef = useRef(nil :: ViewportFrame?)
	local cameraRef = useRef(nil :: Camera?)
	local worldModelRef = useRef(nil :: WorldModel?)
	local overlayRef = useRef(nil :: Frame?)
	local inputRef = useRef(nil :: TextButton?)

	useEffect(function()
		local viewport = viewportRef.current
		local camera = cameraRef.current
		local worldModel = worldModelRef.current
		local overlay = overlayRef.current
		local input = inputRef.current
		if not viewport or not camera or not worldModel or not overlay or not input then
			return
		end
		viewport.CurrentCamera = camera
		config.onMount({
			viewport = viewport,
			camera = camera,
			worldModel = worldModel,
			overlay = overlay,
			input = input,
		})
		return function(): ()
			config.onUnmount()
		end
	end, {})

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, PREVIEW_HEIGHT),
		BackgroundColor3 = surface,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		LayoutOrder = properties.LayoutOrder,
		Active = false,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = e("UIStroke", {
			Color = surfaceStroke,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		Grid = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 0,
		}, gridChildren),
		Viewport = e("ViewportFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Ambient = Color3.fromRGB(170, 170, 170),
			LightColor = Color3.fromRGB(255, 255, 255),
			LightDirection = Vector3.new(-0.4, -1, -0.5),
			Active = false,
			ZIndex = 1,
			ref = viewportRef,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Camera = e("Camera", {
				FieldOfView = 50,
				ref = cameraRef,
			}),
			World = e("WorldModel", {
				ref = worldModelRef,
			}),
		}),
		Overlay = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 3,
			ref = overlayRef,
		}),
		Input = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			ZIndex = 50,
			Active = false,
			ref = inputRef,
		}),
		Settings = hasSettings and e("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = cogBg.binding,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Active = false,
			Text = "",
			ZIndex = 60,
			[React.Event.MouseEnter] = cogEnter,
			[React.Event.MouseLeave] = cogLeave,
			[React.Event.MouseButton1Click] = openSettings,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
			UIStroke = e("UIStroke", {
				Color = cogStroke.binding,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			Icon = e("ImageLabel", {
				BackgroundTransparency = 1,
				Image = FileController.Get("image", "options"),
				ImageColor3 = cogIcon.binding,
				Size = UDim2.fromOffset(12, 12),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			}),
		}) or nil,
	})
end
