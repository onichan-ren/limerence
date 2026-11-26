local RunService = cloneref(game:GetService("RunService")) :: RunService

local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local uiState = require("@ui/uiState")
local contextApi = require("@ui/subwindow/context/contextApi")
local cursor = require("@ui/util/cursor")
local dpiState = require("@ui/util/dpiState")
local useDraggable = require("@ui/hook/useDraggable")
local useHudHover = require("@ui/hook/useHudHover")
local useShadow = require("@ui/hook/useShadow")
local SPRING = require("@ui/util/spring")

local e = React.createElement
local createBinding = React.createBinding
local joinBindings = React.joinBindings
local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useState = React.useState
local useCallback = React.useCallback
local useAt = ReactCharm.useAtom
local useSpring = ReactRipple.useSpring

local colors = themeState.colors.hud

local CARD_W = 348
local CARD_H = 76
local LYRIC_H = 44
local CORNER = 8
local PAD = 10
local COVER = 56
local TEXT_X = PAD + COVER + 10
local EQ_W = 13
local EQ_MAX = 16
local TITLE_W = CARD_W - TEXT_X - PAD - EQ_W - 6
local ARTIST_W = CARD_W - TEXT_X - PAD
local TIME_W = 34
local BAR_X = TEXT_X + TIME_W + 4
local BAR_W = CARD_W - PAD - TIME_W - 4 - BAR_X
local MARQUEE_HOLD = 1.5
local LYRIC_LEAD = 0.15

local EQ_MIN = 0.14
local EQ_SPRING = { tension = 480, friction = 22, precision = 0.01 }

local formatTime = LPH_NO_VIRTUALIZE(function(seconds: number): string
	if seconds < 0 then
		seconds = 0
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end)

local pickerGradient = LPH_NO_VIRTUALIZE(function(el: any): React.Element<any>
	return e("UIGradient", {
		Color = el._currentGradient,
		Rotation = el._currentRotation,
	})
end)

local marqueeOffset = LPH_NO_VIRTUALIZE(function(bounds: number, width: number, t: number): number
	local overflow = bounds - width
	if overflow <= 2 then
		return 0
	end
	if t < 0 then
		return 0
	end
	local period = math.max(3, overflow / 25)
	local phase = (t % (period * 2)) / period
	if phase > 1 then
		phase = 2 - phase
	end
	local smooth = phase * phase * (3 - 2 * phase)
	return -overflow * smooth
end)

local step = LPH_NO_VIRTUALIZE(function(state: any, fade: number, dt: number): ()
	if fade <= 0.005 then
		return
	end

	local now = os.clock()
	local pb = state.playback

	local elapsed = pb.elapsed
	if not pb.paused then
		elapsed += now - pb.at
	end
	if pb.duration > 0 and elapsed > pb.duration then
		elapsed = pb.duration
	end

	local frac = 0
	if pb.duration > 0 then
		frac = elapsed / pb.duration
	end
	if math.abs(frac - state.frac) > 0.002 then
		state.frac = frac
		state.setFill(UDim2.fromScale(frac, 1))
		state.setDotPos(UDim2.fromScale(frac, 0.5))
	end

	local secs = math.floor(elapsed)
	if secs ~= state.secs then
		state.secs = secs
		state.setElapsedText(formatTime(secs))
	end

	local eqSprings = state.eqSprings
	local eqNext = state.eqNext
	if pb.paused then
		if not state.eqPaused then
			state.eqPaused = true
			for i = 1, 3 do
				eqSprings[i]:setGoal(EQ_MIN)
				eqNext[i] = 0
			end
		end
	else
		state.eqPaused = false
		for i = 1, 3 do
			if now >= eqNext[i] then
				eqNext[i] = now + 0.2 * math.random()
				eqSprings[i]:setGoal(0.2 + 0.8 * math.random() ^ 1.4)
			end
		end
	end

	local t = now - state.trackAt - MARQUEE_HOLD
	local titleLabel = state.titleRef.current :: TextLabel?
	if titleLabel then
		local offset = marqueeOffset(titleLabel.TextBounds.X, TITLE_W, t)
		if math.abs(offset - state.titleOffset) > 0.25 then
			state.titleOffset = offset
			state.setTitlePos(UDim2.new(0, offset, 0.5, 0))
		end
	end
	local artistLabel = state.artistRef.current :: TextLabel?
	if artistLabel then
		local offset = marqueeOffset(artistLabel.TextBounds.X, ARTIST_W, t)
		if math.abs(offset - state.artistOffset) > 0.25 then
			state.artistOffset = offset
			state.setArtistPos(UDim2.new(0, offset, 0.5, 0))
		end
	end

	local lines = state.lyrics
	if lines then
		local lyricElapsed = elapsed + LYRIC_LEAD
		local n = #lines
		local idx = state.lyricIdx
		if idx > n then
			idx = n
		end
		if idx > 0 and lyricElapsed < lines[idx].time - 0.3 then
			idx = 0
		end
		while idx < n and lines[idx + 1].time <= lyricElapsed do
			idx += 1
		end
		if idx ~= state.lyricIdx then
			state.lyricIdx = idx
			state.setLyricIdx(idx)
		end
	end
end)

return function(props: {
	open: any,
	track: any,
	lyrics: any,
	paused: any,
	playback: any,
	position: any,
	resetPosition: UDim2,
	showLyricsEl: any,
	hideWhenPausedEl: any,
	accentEl: any,
	customColorsEl: any,
	bgEl: any,
	strokeEl: any,
	titleEl: any,
	textEl: any,
	lyricEl: any,
	trackEl: any,
}): React.Element<any>
	local open = useAt(props.open) :: boolean
	local menuOpen = useAt(uiState.isOpen) :: boolean
	local track = useAt(props.track) :: any
	local lyrics = useAt(props.lyrics) :: any
	local paused = useAt(props.paused) :: boolean
	local showLyrics = useAt(props.showLyricsEl._state) :: boolean
	local hideWhenPaused = useAt(props.hideWhenPausedEl._state) :: boolean
	local scale = useAt(dpiState.scale) :: number

	local titleColor = useAt(colors.title) :: Color3
	local mutedColor = useAt(colors.textMuted) :: Color3
	local barColor = useAt(colors.bar) :: Color3

	local bgPack = useAt(colors.background)
	local bgColor = bgPack[1] :: Color3
	local bgAlpha = bgPack[2] :: number

	local bgSecondaryPack = useAt(colors.backgroundSecondary)
	local bgSecondaryColor = bgSecondaryPack[1] :: Color3
	local bgSecondaryAlpha = bgSecondaryPack[2] :: number

	local strokePack = useAt(colors.stroke)
	local strokeColor = strokePack[1] :: Color3
	local strokeAlpha = strokePack[2] :: number

	local shadowPack = useAt(colors.shadow)
	local shadowColor = shadowPack[1] :: Color3
	local shadowAlpha = shadowPack[2] :: number

	local customColors = useAt(props.customColorsEl._state) :: boolean

	local white = Color3.new(1, 1, 1)
	local titleEff = customColors and white or titleColor
	local mutedEff = customColors and white or mutedColor
	local barEff = customColors and white or barColor
	local strokeEff = customColors and white or strokeColor

	local lyricIdx, setLyricIdx = useState(0)

	local shown = open and track ~= nil and (not hideWhenPaused or not paused)
	local lines = lyrics :: { any }?
	local lyricsVisible = showLyrics and lines ~= nil and #lines > 0

	local fadeBind, fadeSpring = useSpring(0, SPRING.smooth)
	useEffect(function(): ()
		fadeSpring:setGoal(shown and 1 or 0)
	end, { shown })

	local heightBind, heightSpring = useSpring(CARD_H, SPRING.smoothPreciser)
	useEffect(function(): ()
		heightSpring:setGoal(lyricsVisible and CARD_H + LYRIC_H or CARD_H)
	end, { lyricsVisible })

	local contentBind, contentSpring = useSpring(1, SPRING.quick)
	local coverBind, coverSpring = useSpring(1, SPRING.quick)
	local pauseBind, pauseSpring = useSpring(0, SPRING.quick)
	local lyricBind, lyricSpring = useSpring(1, SPRING.smooth)

	useEffect(function(): ()
		pauseSpring:setGoal(paused and 1 or 0)
	end, { paused })

	local eqBind1, eqSpring1 = useSpring(EQ_MIN, EQ_SPRING)
	local eqBind2, eqSpring2 = useSpring(EQ_MIN, EQ_SPRING)
	local eqBind3, eqSpring3 = useSpring(EQ_MIN, EQ_SPRING)

	local eqSprings = useMemo(function(): { any }
		return { eqSpring1, eqSpring2, eqSpring3 }
	end, {})

	local eqSizes = useMemo(function(): { any }
		local binds = { eqBind1, eqBind2, eqBind3 }
		local sizes: { any } = {}
		for i = 1, 3 do
			sizes[i] = joinBindings({ binds[i], fadeBind }):map(function(values: { number }): UDim2
				return UDim2.fromOffset(3, EQ_MAX * math.clamp(values[1], 0.05, 1) * values[2])
			end)
		end
		return sizes
	end, {})

	local stateRef = useRef(nil :: any)
	if not stateRef.current then
		local fillBind, setFill = createBinding(UDim2.fromScale(0, 1))
		local dotPosBind, setDotPos = createBinding(UDim2.fromScale(0, 0.5))
		local elapsedBind, setElapsedText = createBinding("0:00")
		local titlePosBind, setTitlePos = createBinding(UDim2.new(0, 0, 0.5, 0))
		local artistPosBind, setArtistPos = createBinding(UDim2.new(0, 0, 0.5, 0))
		stateRef.current = {
			fillBind = fillBind,
			setFill = setFill,
			dotPosBind = dotPosBind,
			setDotPos = setDotPos,
			frac = -1,
			elapsedBind = elapsedBind,
			setElapsedText = setElapsedText,
			secs = -1,
			titlePosBind = titlePosBind,
			setTitlePos = setTitlePos,
			titleOffset = 0,
			artistPosBind = artistPosBind,
			setArtistPos = setArtistPos,
			artistOffset = 0,
			eqNext = { 0, 0, 0 },
			eqPaused = false,
			titleRef = React.createRef(),
			artistRef = React.createRef(),
			trackAt = 0,
			lyricIdx = 0,
		}
	end
	local state = stateRef.current
	state.playback = props.playback
	state.eqSprings = eqSprings
	state.lyrics = lines
	state.setLyricIdx = setLyricIdx

	local trackId = track and track.id or nil
	useEffect(function(): ()
		state.trackAt = os.clock()
		state.secs = -1
		state.frac = -1
		state.titleOffset = 0
		state.setTitlePos(UDim2.new(0, 0, 0.5, 0))
		state.artistOffset = 0
		state.setArtistPos(UDim2.new(0, 0, 0.5, 0))
		if trackId then
			contentSpring:setPosition(0)
			contentSpring:setGoal(1)
			coverSpring:setPosition(0.72)
			coverSpring:setGoal(1)
		end
	end, { trackId })

	useEffect(function(): ()
		state.lyricIdx = 0
		setLyricIdx(0)
	end, { lyrics })

	local currentLyric = ""
	local nextLyric = ""
	if lines then
		local current = lines[lyricIdx]
		if current then
			currentLyric = current.text
		end
		local nextLine = lines[lyricIdx + 1]
		if nextLine then
			nextLyric = nextLine.text
		end
	end

	local lineRef = useRef("")
	local idxRef = useRef(-1)
	local curLine, setCurLine = useState("")
	local prevLine, setPrevLine = useState(nil :: string?)

	useEffect(function()
		return lyricSpring:onComplete(function(): ()
			setPrevLine(nil)
		end)
	end, {})

	useEffect(function(): ()
		if lyricIdx == idxRef.current and currentLyric == lineRef.current then
			return
		end
		idxRef.current = lyricIdx
		setPrevLine(lineRef.current)
		lineRef.current = currentLyric
		setCurLine(currentLyric)
		lyricSpring:setPosition(0)
		lyricSpring:setGoal(1)
	end, { lyricIdx, currentLyric } :: { any })

	local layoutBind, layoutSpring = useSpring(0, SPRING.smooth)
	local twoLines = curLine ~= "" and nextLyric ~= ""
	useEffect(function(): ()
		layoutSpring:setGoal(twoLines and 1 or 0)
	end, { twoLines })

	useEffect(function(): () -> ()
		local conn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
			step(state, fadeBind:getValue(), dt)
		end))
		return function(): ()
			conn:Disconnect()
		end
	end, {})

	local positionAtom = props.position._state
	local onDragInput, positionBind = useDraggable(positionAtom)
	local onHoverEnter, onHoverLeave, hoverGlow = useHudHover(menuOpen and shown)

	local onInputBegan = useCallback(
		LPH_NO_VIRTUALIZE(function(_: any, input: InputObject): ()
			if not menuOpen or not shown then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				onDragInput(input)
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				contextApi.Open({
					{
						Label = "Reset Position",
						Callback = function(): ()
							positionAtom(props.resetPosition)
						end,
					},
				}, cursor.getPosition(input))
			end
		end),
		{ menuOpen, shown } :: { any }
	)

	local visible = useMemo(function()
		return fadeBind:map(function(v: number): boolean
			return v > 0.005
		end)
	end, { fadeBind })

	local cardSize = useMemo(function()
		return heightBind:map(function(h: number): UDim2
			return UDim2.fromOffset(CARD_W, h)
		end)
	end, { heightBind })

	local bgTransparency = useMemo(function()
		if customColors then
			return joinBindings({ fadeBind, props.bgEl._currentTransparency }):map(function(values: { number }): number
				return 1 - values[1] * (1 - values[2])
			end)
		end
		return fadeBind:map(function(v: number): number
			return 1 - v * (1 - bgAlpha)
		end)
	end, { fadeBind, bgAlpha, customColors } :: { any })

	local strokeTransparency = useMemo(function()
		if customColors then
			return joinBindings({ fadeBind, props.strokeEl._currentTransparency }):map(
				function(values: { number }): number
					return 1 - values[1] * (1 - values[2])
				end
			)
		end
		return fadeBind:map(function(v: number): number
			return 1 - v * (1 - strokeAlpha)
		end)
	end, { fadeBind, strokeAlpha, customColors } :: { any })

	local shadowTransparency = useMemo(function()
		return fadeBind:map(function(v: number): number
			return 1 - v * (1 - shadowAlpha)
		end)
	end, { fadeBind, shadowAlpha } :: { any })

	local contentTrans = useMemo(function()
		return joinBindings({ fadeBind, contentBind }):map(function(values: { number }): number
			return 1 - values[1] * values[2]
		end)
	end, { fadeBind, contentBind } :: { any })

	local mutedTrans = useMemo(function()
		return joinBindings({ fadeBind, contentBind }):map(function(values: { number }): number
			return 1 - values[1] * values[2] * 0.85
		end)
	end, { fadeBind, contentBind } :: { any })

	local barTransparency = useMemo(function()
		return fadeBind:map(function(v: number): number
			return 1 - v * 0.55
		end)
	end, { fadeBind })

	local coverBgTransparency = useMemo(function()
		return joinBindings({ fadeBind, contentBind }):map(function(values: { number }): number
			return 1 - values[1] * values[2] * (1 - bgSecondaryAlpha)
		end)
	end, { fadeBind, contentBind, bgSecondaryAlpha } :: { any })

	local pauseOverlayTrans = useMemo(function()
		return joinBindings({ fadeBind, pauseBind }):map(function(values: { number }): number
			return 1 - values[1] * values[2] * 0.45
		end)
	end, { fadeBind, pauseBind } :: { any })

	local pauseIconTrans = useMemo(function()
		return joinBindings({ fadeBind, pauseBind }):map(function(values: { number }): number
			return 1 - values[1] * values[2]
		end)
	end, { fadeBind, pauseBind } :: { any })

	local expandFrac = useCallback(function(h: number): number
		return math.clamp((h - CARD_H) / LYRIC_H, 0, 1)
	end, {})

	local dividerTrans = useMemo(function()
		if customColors then
			return joinBindings({ fadeBind, heightBind, props.strokeEl._currentTransparency }):map(
				function(values: { number }): number
					return 1 - values[1] * expandFrac(values[2]) * (1 - values[3])
				end
			)
		end
		return joinBindings({ fadeBind, heightBind }):map(function(values: { number }): number
			return 1 - values[1] * expandFrac(values[2]) * (1 - strokeAlpha)
		end)
	end, { fadeBind, heightBind, strokeAlpha, customColors } :: { any })

	local lyricTrans = useMemo(function()
		return joinBindings({ fadeBind, heightBind, lyricBind }):map(function(values: { number }): number
			return 1 - values[1] * expandFrac(values[2]) * values[3]
		end)
	end, { fadeBind, heightBind, lyricBind } :: { any })

	local nextLyricTrans = useMemo(function()
		return joinBindings({ fadeBind, heightBind }):map(function(values: { number }): number
			return 1 - values[1] * expandFrac(values[2]) * 0.45
		end)
	end, { fadeBind, heightBind } :: { any })

	local incomingLyricPos = useMemo(function()
		return joinBindings({ lyricBind, layoutBind }):map(function(values: { number }): UDim2
			return UDim2.new(0.5, 0, 0, CARD_H + 14 - 8 * values[2] + 12 * (1 - values[1]))
		end)
	end, { lyricBind, layoutBind } :: { any })

	local outgoingLyricPos = useMemo(function()
		return joinBindings({ lyricBind, layoutBind }):map(function(values: { number }): UDim2
			return UDim2.new(0.5, 0, 0, CARD_H + 14 - 8 * values[2] - 12 * values[1])
		end)
	end, { lyricBind, layoutBind } :: { any })

	local nextLyricPos = useMemo(function()
		return layoutBind:map(function(l: number): UDim2
			return UDim2.new(0.5, 0, 0, CARD_H + 16 + 9 * l)
		end)
	end, { layoutBind })

	local outgoingLyricTrans = useMemo(function()
		return joinBindings({ fadeBind, heightBind, lyricBind }):map(function(values: { number }): number
			return 1 - values[1] * expandFrac(values[2]) * (1 - values[3])
		end)
	end, { fadeBind, heightBind, lyricBind } :: { any })

	local font = FileController.Get("font", "semi_bold")
	local fallbackIcon = FileController.Get("image", "logo_small")
	local dotImage = FileController.Get("image", "circle_shadow")

	local eqChildren: { [string]: any } = {}
	for i = 1, 3 do
		eqChildren["bar" .. i] = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, (i - 1) * 5, 1, 0),
			Size = eqSizes[i],
			BackgroundColor3 = white,
			BackgroundTransparency = contentTrans,
			BorderSizePixel = 0,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			UIGradient = pickerGradient(props.accentEl),
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = visible,
		Active = false,
		ZIndex = 2,
	}, {
		Root = e("Frame", {
			Active = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = positionBind,
			Size = cardSize,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 2,
			[React.Event.MouseEnter] = onHoverEnter,
			[React.Event.MouseLeave] = onHoverLeave,
		}, {
			UIScale = e("UIScale", {
				Scale = scale,
			}),
			Glow = hoverGlow,
			Shadow = useShadow({
				color = shadowColor,
				transparency = shadowTransparency,
				zIndex = 0,
				multiplier = Vector2.new(1.09, 1.32),
			}),
			Card = e("Frame", {
				BackgroundColor3 = customColors and Color3.new(1, 1, 1) or bgColor,
				BackgroundTransparency = bgTransparency,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ClipsDescendants = true,
				ZIndex = 1,
				[React.Event.InputBegan] = onInputBegan,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, CORNER),
				}),
				UIStroke = e("UIStroke", {
					Color = strokeEff,
					Transparency = strokeTransparency,
					Thickness = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}, {
					UIGradient = customColors and pickerGradient(props.strokeEl) or nil,
				}),
				UIGradient = customColors and pickerGradient(props.bgEl) or e("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.82, 0.82, 0.82)),
				}),
				Cover = e("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(PAD + COVER / 2, CARD_H / 2),
					Size = UDim2.fromOffset(COVER, COVER),
					BackgroundColor3 = bgSecondaryColor,
					BackgroundTransparency = coverBgTransparency,
					BorderSizePixel = 0,
					Image = track and track.coverImage or "",
					ImageTransparency = contentTrans,
					ZIndex = 2,
				}, {
					UIScale = e("UIScale", {
						Scale = coverBind,
					}),
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, CORNER - 2),
					}),
					Fallback = (not (track and track.coverImage)) and e("ImageLabel", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(22, 22),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Image = fallbackIcon,
						ImageColor3 = mutedEff,
						ImageTransparency = mutedTrans,
						ZIndex = 3,
					}, {
						UIGradient = customColors and pickerGradient(props.textEl) or nil,
					}) or nil,
					PauseOverlay = e("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = shadowColor,
						BackgroundTransparency = pauseOverlayTrans,
						BorderSizePixel = 0,
						ZIndex = 4,
					}, {
						UICorner = e("UICorner", {
							CornerRadius = UDim.new(0, CORNER - 2),
						}),
						LeftBar = e("Frame", {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(0.5, -2, 0.5, 0),
							Size = UDim2.fromOffset(4, 14),
							BackgroundColor3 = titleEff,
							BackgroundTransparency = pauseIconTrans,
							BorderSizePixel = 0,
						}, {
							UICorner = e("UICorner", {
								CornerRadius = UDim.new(0, 1),
							}),
							UIGradient = customColors and pickerGradient(props.titleEl) or nil,
						}),
						RightBar = e("Frame", {
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.new(0.5, 2, 0.5, 0),
							Size = UDim2.fromOffset(4, 14),
							BackgroundColor3 = titleEff,
							BackgroundTransparency = pauseIconTrans,
							BorderSizePixel = 0,
						}, {
							UICorner = e("UICorner", {
								CornerRadius = UDim.new(0, 1),
							}),
							UIGradient = customColors and pickerGradient(props.titleEl) or nil,
						}),
					}),
				}),
				TitleClip = e("Frame", {
					Position = UDim2.fromOffset(TEXT_X, 10),
					Size = UDim2.fromOffset(TITLE_W, 16),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = true,
					ZIndex = 2,
				}, {
					Title = e("TextLabel", {
						ref = state.titleRef,
						AnchorPoint = Vector2.new(0, 0.5),
						Position = state.titlePosBind,
						Size = UDim2.fromOffset(0, 16),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Text = track and track.title or "",
						TextSize = 14,
						TextColor3 = customColors and Color3.new(1, 1, 1) or titleColor,
						TextTransparency = contentTrans,
						FontFace = font,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
					}, {
						UIGradient = customColors and pickerGradient(props.titleEl) or nil,
					}),
				}),
				ArtistClip = e("Frame", {
					Position = UDim2.fromOffset(TEXT_X, 29),
					Size = UDim2.fromOffset(ARTIST_W, 13),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = true,
					ZIndex = 2,
				}, {
					Artist = e("TextLabel", {
						ref = state.artistRef,
						AnchorPoint = Vector2.new(0, 0.5),
						Position = state.artistPosBind,
						Size = UDim2.fromOffset(0, 13),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Text = track and track.artist or "",
						TextSize = 11,
						TextColor3 = mutedEff,
						TextTransparency = mutedTrans,
						FontFace = font,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
					}, {
						UIGradient = customColors and pickerGradient(props.textEl) or nil,
					}),
				}),
				Equalizer = e("Frame", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -PAD, 0, 11),
					Size = UDim2.fromOffset(EQ_W, EQ_MAX),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 2,
				}, eqChildren),
				Elapsed = e("TextLabel", {
					Position = UDim2.fromOffset(TEXT_X, 50),
					Size = UDim2.fromOffset(TIME_W, 12),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = state.elapsedBind,
					TextSize = 10,
					TextColor3 = mutedEff,
					TextTransparency = mutedTrans,
					FontFace = font,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					ZIndex = 2,
				}, {
					UIGradient = customColors and pickerGradient(props.textEl) or nil,
				}),
				Total = e("TextLabel", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -PAD, 0, 50),
					Size = UDim2.fromOffset(TIME_W, 12),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = track and formatTime(math.floor(track.duration)) or "0:00",
					TextSize = 10,
					TextColor3 = mutedEff,
					TextTransparency = mutedTrans,
					FontFace = font,
					TextXAlignment = Enum.TextXAlignment.Right,
					TextYAlignment = Enum.TextYAlignment.Center,
					ZIndex = 2,
				}, {
					UIGradient = customColors and pickerGradient(props.textEl) or nil,
				}),
				BarBack = e("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromOffset(BAR_X, 56),
					Size = UDim2.fromOffset(BAR_W, 3),
					BackgroundColor3 = barEff,
					BackgroundTransparency = barTransparency,
					BorderSizePixel = 0,
					ZIndex = 2,
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(1, 0),
					}),
					UIGradient = customColors and pickerGradient(props.trackEl) or nil,
					Fill = e("Frame", {
						Size = state.fillBind,
						BackgroundColor3 = white,
						BackgroundTransparency = contentTrans,
						BorderSizePixel = 0,
						ZIndex = 3,
					}, {
						UICorner = e("UICorner", {
							CornerRadius = UDim.new(1, 0),
						}),
						UIGradient = pickerGradient(props.accentEl),
					}),
					Dot = e("ImageLabel", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = state.dotPosBind,
						Size = UDim2.fromOffset(8, 8),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Image = dotImage,
						ImageColor3 = white,
						ImageTransparency = contentTrans,
						ZIndex = 4,
					}, {
						UIGradient = pickerGradient(props.accentEl),
					}),
				}),
				Divider = e("Frame", {
					Position = UDim2.fromOffset(PAD, CARD_H),
					Size = UDim2.fromOffset(CARD_W - PAD * 2, 1),
					BackgroundColor3 = strokeEff,
					BackgroundTransparency = dividerTrans,
					BorderSizePixel = 0,
					ZIndex = 2,
				}, {
					UIGradient = customColors and pickerGradient(props.strokeEl) or nil,
				}),
				CurrentLyric = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = incomingLyricPos,
					Size = UDim2.fromOffset(CARD_W - PAD * 2, 16),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = curLine,
					TextSize = 13,
					TextColor3 = customColors and Color3.new(1, 1, 1) or titleColor,
					TextTransparency = lyricTrans,
					TextTruncate = Enum.TextTruncate.AtEnd,
					FontFace = font,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
					ZIndex = 2,
				}, {
					UIGradient = customColors and pickerGradient(props.lyricEl) or nil,
				}),
				PrevLyric = prevLine and e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = outgoingLyricPos,
					Size = UDim2.fromOffset(CARD_W - PAD * 2, 16),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = prevLine,
					TextSize = 13,
					TextColor3 = customColors and Color3.new(1, 1, 1) or titleColor,
					TextTransparency = outgoingLyricTrans,
					TextTruncate = Enum.TextTruncate.AtEnd,
					FontFace = font,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
					ZIndex = 2,
				}, {
					UIGradient = customColors and pickerGradient(props.lyricEl) or nil,
				}) or nil,
				NextLyric = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = nextLyricPos,
					Size = UDim2.fromOffset(CARD_W - PAD * 2, 12),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = nextLyric,
					TextSize = 10,
					TextColor3 = mutedEff,
					TextTransparency = nextLyricTrans,
					TextTruncate = Enum.TextTruncate.AtEnd,
					FontFace = font,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
					ZIndex = 2,
				}, {
					UIGradient = customColors and pickerGradient(props.textEl) or nil,
				}),
			}),
		}),
	})
end
