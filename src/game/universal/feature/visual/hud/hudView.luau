local RunService = cloneref(game:GetService("RunService")) :: RunService
local Players = cloneref(game:GetService("Players")) :: Players
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local FileController = require("@feature/file/FileController")
local SPRING = require("@ui/util/spring")
local sessionState = require("@feature/session/sessionState")
local themeState = require("@ui/theme/themeState")
local uiState = require("@ui/uiState")
local contextApi = require("@ui/subwindow/context/contextApi")
local cursor = require("@ui/util/cursor")
local useHudHover = require("@ui/hook/useHudHover")
local legitbotState = require("@game/universal/feature/combat/legitbot/legitbotState")
local originState = require("@game/universal/feature/visual/crosshair/originState")
local hudState = require("@game/universal/feature/visual/hud/hudState")

local e = React.createElement
local createBinding = React.createBinding
local useBinding = React.useBinding
local useRef = React.useRef
local useEffect = React.useEffect
local useCallback = React.useCallback
local useAt = ReactCharm.useAtom
local useSpring = ReactRipple.useSpring
local peek = Charm.peek

local mrandom = math.random
local msin = math.sin
local mmax = math.max

local LOGO_SIZE = 15
local TITLE_SIZE = 17
local LOGO_GAP = 4
local PETAL_SIZE = 7
local PETAL_POOL = 4
local BURST_COUNT = 2
local FALL_DISTANCE = 30
local FALL_TIME_MIN = 2.4
local FALL_TIME_MAX = 3.8
local DRIFT = 6
local SPIN_MIN = 40
local SPIN_MAX = 120
local FADE_IN = 0.22
local FADE_OUT = 0.5
local BURST_INIT = 0.3
local BURST_MIN = 0.35
local BURST_MAX = 0.8
local BURST_STAGGER = 0.18
local INFO_SIZE = TITLE_SIZE
local INFO_FADE = 12
local INFO_TOP = 2
local INFO_GAP = 5
local INFO_POOL = 8
local FLASH_DIM = 0.65
local FLASH_DECAY = 6
local RAGEBOT_FRESH = 0.3
local SNAP_PX = 12
local SNAP_POINTS = { 0, 0.5, 1 }
local GUIDE_THICKNESS = 2
local GUIDE_ALPHA = 0.7
local RESET_POSITION = UDim2.new(0.5, 0, 0.5, 0)
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

local function configure(p: any): ()
	p.life = FALL_TIME_MIN + mrandom() * (FALL_TIME_MAX - FALL_TIME_MIN)
	p.startX = (mrandom() * 2 - 1) * 3
	p.drift = (mrandom() * 2 - 1) * DRIFT
	p.spin = (SPIN_MIN + mrandom() * (SPIN_MAX - SPIN_MIN)) * (mrandom() < 0.5 and -1 or 1)
	p.startRot = mrandom() * 360
end

local function nameFromPart(part: BasePart): string?
	local model = part:FindFirstAncestorWhichIsA("Model")
	while model do
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			local display = player.DisplayName
			return (display ~= "" and display) or player.Name
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

local function lockText(): string?
	local part = originState.GetRagebotPart(RAGEBOT_FRESH)
	if part then
		return "ragebot: " .. (nameFromPart(part) or "locked")
	end
	local target = peek(legitbotState.target)
	if target then
		return "legitbot: " .. target.Name
	end
	return nil
end

local function applySlot(slot: any, raw: string, index: number): ()
	if slot.orderVal ~= index then
		slot.orderVal = index
		slot.setOrder(index)
	end
	local prefixed = index > 1
	if slot.prefixed ~= prefixed then
		slot.prefixed = prefixed
		slot.setSepVis(prefixed)
	end
	if slot.raw ~= raw then
		local wasSet = slot.raw ~= nil
		slot.raw = raw
		slot.setText(raw)
		if wasSet then
			slot.flash = 1
		end
	end
end

local function syncSlots(state: any): ()
	local entries = hudState.GetInfoEntries()
	local slots = state.slots
	for i = 1, #slots do
		slots[i].live = false
	end
	local pending = state.pending
	table.clear(pending)
	for i = 1, #entries do
		local entry = entries[i]
		local matched = false
		for j = 1, #slots do
			local slot = slots[j]
			if slot.key == entry.key then
				slot.live = true
				applySlot(slot, entry.text, i)
				matched = true
				break
			end
		end
		if not matched then
			pending[#pending + 1] = i
		end
	end
	for i = 1, #pending do
		local index = pending[i]
		local entry = entries[index]
		local slot: any = nil
		for j = 1, #slots do
			local candidate = slots[j]
			if candidate.key == nil then
				slot = candidate
				break
			end
			if not candidate.live and (slot == nil or candidate.alpha < slot.alpha) then
				slot = candidate
			end
		end
		if slot == nil then
			continue
		end
		slot.key = entry.key
		slot.raw = nil
		slot.alpha = 0
		slot.flash = 0
		slot.live = true
		applySlot(slot, entry.text, index)
	end
end

local step = LPH_NO_VIRTUALIZE(function(state: any, fade: number, dt: number): ()
	if fade <= 0.005 then
		return
	end
	local petals = state.petals
	state.timer += dt
	if state.timer >= state.next then
		state.timer = 0
		state.next = BURST_MIN + mrandom() * (BURST_MAX - BURST_MIN)
		local count = mrandom(1, BURST_COUNT)
		local stagger = 0
		for i = 1, #petals do
			if count <= 0 then
				break
			end
			local p = petals[i]
			if not p.active then
				p.active = true
				p.t = 0
				p.delay = stagger
				stagger += BURST_STAGGER
				configure(p)
				count -= 1
			end
		end
	end

	for i = 1, #petals do
		local p = petals[i]
		if not p.active then
			p.setTrans(1)
			continue
		end
		if p.delay > 0 then
			p.delay -= dt
			p.setTrans(1)
			continue
		end
		p.t += dt / p.life
		if p.t >= 1 then
			p.active = false
			p.setTrans(1)
			continue
		end
		local t = p.t
		local x = p.startX + p.drift * msin(t * math.pi)
		p.setPos(UDim2.fromOffset(x, FALL_DISTANCE * t))
		p.setRot(p.startRot + p.spin * t)

		local own
		if t < FADE_IN then
			local k = t / FADE_IN
			own = k * k * (3 - 2 * k)
		elseif t > FADE_OUT then
			local k = mmax(0, 1 - (t - FADE_OUT) / (1 - FADE_OUT))
			own = k * k * (3 - 2 * k)
		else
			own = 1
		end
		p.setTrans(1 - own * fade)
	end

	if hudState.HasInfo("ragebotTarget") then
		hudState.SetInfo("lock", nil)
	else
		hudState.SetInfo("lock", lockText(), 10)
	end

	local version = hudState.InfoVersion()
	if version ~= state.infoVersion then
		state.infoVersion = version
		syncSlots(state)
	end

	local gate = state.showInfo and fade or 0
	local ease = 1 - math.exp(-dt * INFO_FADE)
	local decay = math.exp(-dt * FLASH_DECAY)
	local animate = state.infoAnim
	local slots = state.slots
	for i = 1, #slots do
		local slot = slots[i]
		if slot.key == nil and slot.alpha <= 0 then
			continue
		end
		local target = slot.live and 1 or 0
		if animate then
			slot.alpha += (target - slot.alpha) * ease
			if slot.flash > 0.005 then
				slot.flash *= decay
			elseif slot.flash ~= 0 then
				slot.flash = 0
			end
		else
			slot.alpha = target
			slot.flash = 0
		end
		if not slot.live and slot.key ~= nil and slot.alpha < 0.01 then
			slot.key = nil
			slot.raw = nil
			slot.alpha = 0
			slot.setText("")
			if slot.prefixed then
				slot.prefixed = false
				slot.setSepVis(false)
			end
		end
		slot.setTrans(1 - slot.alpha * gate * (1 - FLASH_DIM * slot.flash))
	end
end)

return function(props: {
	open: any,
	logoColor: any,
	titleColor: any,
	showInfo: any,
	animations: any,
	infoColor: any,
	position: any,
}): React.Element<any>
	local open = useAt(props.open) :: boolean
	local menuOpen = useAt(uiState.isOpen) :: boolean
	local title = useAt(sessionState.cheat) :: string
	local accentColor = useAt(themeState.colors.window.element.accent) :: Color3

	local positionAtom = props.position._state
	local posBind, setPosBind = useBinding(peek(positionAtom) :: UDim2)
	local sizeBind, setSizeBind = useBinding(UDim2.fromOffset(0, 0))
	local infoPosBind, setInfoPosBind = useBinding(UDim2.new(0.5, 0, 0, INFO_TOP))
	local guideXBind, setGuideXBind = useBinding(0.5)
	local guideYBind, setGuideYBind = useBinding(0.5)

	local guideVBind, guideVSpring = useSpring(0, SPRING.smooth)
	local guideHBind, guideHSpring = useSpring(0, SPRING.smooth)

	local fadeBind, fadeSpring = useSpring(0, SPRING.smooth)
	useEffect(function(): ()
		fadeSpring:setGoal(open and 1 or 0)
	end, { open })

	local canDrag = menuOpen and open
	local onHoverEnter, onHoverLeave, hoverGlow = useHudHover(canDrag)

	local screenRef = useRef(nil :: Frame?)
	local rootRef = useRef(nil :: Frame?)
	local headerRef = useRef(nil :: Frame?)
	local infoRef = useRef(nil :: Frame?)

	local draggingRef = useRef(false)
	local dragStart = useRef(Vector2.zero)
	local startPos = useRef(Vector2.zero)
	local denomRef = useRef(Vector2.one)
	local pendingRef = useRef(nil :: any)
	local scratchRef = useRef({ x = 0.5, y = 0.5, sx = false, sy = false } :: any)

	useEffect(function(): () -> ()
		local unsub = Charm.subscribe(positionAtom, function(p: UDim2): ()
			if not draggingRef.current then
				setPosBind(p)
			end
		end)
		return unsub
	end, {})

	useEffect(function(): () -> ()
		local function measure(): ()
			local header = headerRef.current
			if not header then
				return
			end
			local headerSize = header.AbsoluteSize
			local info = infoRef.current
			local infoWidth = info and info.AbsoluteSize.X or 0
			local halfHeader = headerSize.Y / 2
			local width = mmax(headerSize.X, infoWidth)
			local height = mmax(headerSize.Y, halfHeader + INFO_TOP + INFO_SIZE)
			setSizeBind(UDim2.fromOffset(width, height))
			setInfoPosBind(UDim2.new(0.5, 0, 0, halfHeader + INFO_TOP))
		end
		measure()
		local conns: { RBXScriptConnection } = {}
		local header = headerRef.current
		if header then
			conns[#conns + 1] = header:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		end
		local info = infoRef.current
		if info then
			conns[#conns + 1] = info:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		end
		return function(): ()
			for i = 1, #conns do
				conns[i]:Disconnect()
			end
		end
	end, {})

	useEffect(function(): () -> ()
		local flushPending = LPH_NO_VIRTUALIZE(function(): ()
			local pending = pendingRef.current
			if not pending then
				return
			end
			pendingRef.current = nil
			local newPos = UDim2.new(pending.x, 0, pending.y, 0)
			setPosBind(newPos)
			if peek(positionAtom) ~= newPos then
				positionAtom(newPos)
			end
			local sx = pending.sx
			if sx then
				setGuideXBind(sx)
			end
			guideVSpring:setGoal((sx and 1) or 0)
			local sy = pending.sy
			if sy then
				setGuideYBind(sy)
			end
			guideHSpring:setGoal((sy and 1) or 0)
		end)

		local moveConn = UserInputService.InputChanged:Connect(LPH_NO_VIRTUALIZE(function(input: InputObject): ()
			if not draggingRef.current then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			local denom = denomRef.current
			local start = startPos.current
			local origin = dragStart.current
			local nx = math.clamp(start.X + (input.Position.X - origin.X) / denom.X, 0, 1)
			local ny = math.clamp(start.Y + (input.Position.Y - origin.Y) / denom.Y, 0, 1)
			local tx = SNAP_PX / denom.X
			local ty = SNAP_PX / denom.Y
			local sx: any = false
			local sy: any = false
			for i = 1, #SNAP_POINTS do
				local point = SNAP_POINTS[i]
				if sx == false and math.abs(nx - point) <= tx then
					nx = point
					sx = point
				end
				if sy == false and math.abs(ny - point) <= ty then
					ny = point
					sy = point
				end
			end
			local pending = scratchRef.current
			pending.x = nx
			pending.y = ny
			pending.sx = sx
			pending.sy = sy
			pendingRef.current = pending
		end))

		local flushConn = RunService.Heartbeat:Connect(flushPending)

		local endConn = UserInputService.InputEnded:Connect(function(input: InputObject): ()
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			if not draggingRef.current then
				return
			end
			draggingRef.current = false
			flushPending()
			guideVSpring:setGoal(0)
			guideHSpring:setGoal(0)
		end)

		return function(): ()
			moveConn:Disconnect()
			flushConn:Disconnect()
			endConn:Disconnect()
			draggingRef.current = false
		end
	end, {})

	local onRootInputBegan = useCallback(function(_: any, input: InputObject): ()
		if not canDrag then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local root = rootRef.current
			local screen = screenRef.current
			if not root or not screen or draggingRef.current then
				return
			end
			draggingRef.current = true
			dragStart.current = Vector2.new(input.Position.X, input.Position.Y)
			local current = peek(positionAtom) :: UDim2
			startPos.current = Vector2.new(current.X.Scale, current.Y.Scale)
			local screenSize = screen.AbsoluteSize
			local rootSize = root.AbsoluteSize
			denomRef.current = Vector2.new(mmax(1, screenSize.X - rootSize.X), mmax(1, screenSize.Y - rootSize.Y))
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			contextApi.Open({
				{
					Label = "Reset Position",
					Callback = function(): ()
						positionAtom(RESET_POSITION)
					end,
				},
			}, cursor.getPosition(input))
		end
	end, { canDrag })

	local stateRef = useRef(nil :: any)
	if not stateRef.current then
		local petals: { any } = {}
		for _ = 1, PETAL_POOL do
			local posB, setPos = createBinding(UDim2.fromOffset(0, 0))
			local rotBind, setRot = createBinding(0)
			local transBind, setTrans = createBinding(1)
			petals[#petals + 1] = {
				posBind = posB,
				setPos = setPos,
				rotBind = rotBind,
				setRot = setRot,
				transBind = transBind,
				setTrans = setTrans,
				active = false,
				t = 0,
				delay = 0,
			}
		end
		local slots: { any } = {}
		for i = 1, INFO_POOL do
			local textBind, setText = createBinding("")
			local transBind, setTrans = createBinding(1)
			local orderBind, setOrder = createBinding(i)
			local sepVisBind, setSepVis = createBinding(false)
			slots[i] = {
				textBind = textBind,
				setText = setText,
				transBind = transBind,
				setTrans = setTrans,
				orderBind = orderBind,
				setOrder = setOrder,
				sepVisBind = sepVisBind,
				setSepVis = setSepVis,
				key = nil,
				raw = nil,
				prefixed = false,
				alpha = 0,
				flash = 0,
				live = false,
				orderVal = i,
			}
		end
		stateRef.current = {
			petals = petals,
			timer = 0,
			next = BURST_INIT,
			slots = slots,
			pending = {},
			infoVersion = -1,
			showInfo = false,
			infoAnim = true,
		}
	end
	local state = stateRef.current
	state.showInfo = useAt(props.showInfo._state) :: boolean
	state.infoAnim = useAt(props.animations._state) :: boolean
	local petals = state.petals :: { any }
	local slots = state.slots :: { any }

	useEffect(function(): () -> ()
		local conn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
			step(state, fadeBind:getValue(), dt)
		end))
		return function(): ()
			conn:Disconnect()
		end
	end, {})

	local flower = FileController.Get("image", "logo_small")
	local particle = FileController.Get("image", "logo_small")
	local infoFont = FileController.Get("font", "pixel3")
	local logoColor = props.logoColor
	local titleColor = props.titleColor
	local infoColor = props.infoColor

	local logoTrans = React.joinBindings({ fadeBind, logoColor._currentTransparency })
		:map(function(v: { number }): number
			return 1 - (1 - v[2]) * v[1]
		end)
	local titleTrans = React.joinBindings({ fadeBind, titleColor._currentTransparency })
		:map(function(v: { number }): number
			return 1 - (1 - v[2]) * v[1]
		end)
	local strokeTrans = fadeBind:map(function(f: number): number
		return 1 - f
	end)

	local anchorBind = posBind:map(function(p: UDim2): Vector2
		return Vector2.new(p.X.Scale, p.Y.Scale)
	end)

	local petalChildren: { [string]: any } = {}
	for i = 1, #petals do
		local p = petals[i]
		petalChildren["petal" .. i] = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = p.posBind,
			Rotation = p.rotBind,
			Size = UDim2.fromOffset(PETAL_SIZE, PETAL_SIZE),
			BackgroundTransparency = 1,
			Image = particle,
			ImageColor3 = WHITE,
			ImageTransparency = p.transBind,
			ZIndex = 1,
		}, {
			Gradient = e("UIGradient", {
				Color = logoColor._currentGradient,
				Rotation = logoColor._currentRotation,
			}),
		})
	end

	local infoChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, INFO_GAP),
		}),
	}
	for i = 1, #slots do
		local slot = slots[i]
		local slotTrans = React.joinBindings({ slot.transBind, infoColor._currentTransparency })
			:map(function(v: { number }): number
				return 1 - (1 - v[2]) * (1 - v[1])
			end)
		infoChildren["sep" .. i] = e("TextLabel", {
			Size = UDim2.fromOffset(0, INFO_SIZE),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = React.joinBindings({ slot.sepVisBind, slot.transBind }):map(function(v: { any }): boolean
				return v[1] and v[2] < 0.995
			end),
			Text = "|",
			FontFace = infoFont,
			TextSize = INFO_SIZE,
			TextColor3 = WHITE,
			TextTransparency = slotTrans,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = slot.orderBind:map(function(o: number): number
				return o * 2 - 1
			end),
			ZIndex = 2,
		}, {
			Gradient = e("UIGradient", {
				Color = infoColor._currentGradient,
				Rotation = infoColor._currentRotation,
			}),
			Stroke = e("UIStroke", {
				Color = BLACK,
				Thickness = 1,
				Transparency = slot.transBind,
			}),
		})
		infoChildren["slot" .. i] = e("TextLabel", {
			Size = UDim2.fromOffset(0, INFO_SIZE),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = slot.transBind:map(function(t: number): boolean
				return t < 0.995
			end),
			Text = slot.textBind,
			FontFace = infoFont,
			TextSize = INFO_SIZE,
			TextColor3 = WHITE,
			TextTransparency = slotTrans,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = slot.orderBind:map(function(o: number): number
				return o * 2
			end),
			ZIndex = 2,
		}, {
			Gradient = e("UIGradient", {
				Color = infoColor._currentGradient,
				Rotation = infoColor._currentRotation,
			}),
			Stroke = e("UIStroke", {
				Color = BLACK,
				Thickness = 1,
				Transparency = slot.transBind,
			}),
		})
	end

	return e("Frame", {
		ref = screenRef,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = fadeBind:map(function(f: number): boolean
			return f > 0.005
		end),
		Active = false,
		ZIndex = 2,
	}, {
		GuideV = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = guideXBind:map(function(x: number): UDim2
				return UDim2.fromScale(x, 0)
			end),
			Size = UDim2.new(0, GUIDE_THICKNESS, 1, 0),
			BackgroundColor3 = accentColor,
			BackgroundTransparency = guideVBind:map(function(v: number): number
				return 1 - v * GUIDE_ALPHA
			end),
			Visible = guideVBind:map(function(v: number): boolean
				return v > 0.01
			end),
			BorderSizePixel = 0,
			ZIndex = 1,
		}),
		GuideH = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = guideYBind:map(function(y: number): UDim2
				return UDim2.fromScale(0, y)
			end),
			Size = UDim2.new(1, 0, 0, GUIDE_THICKNESS),
			BackgroundColor3 = accentColor,
			BackgroundTransparency = guideHBind:map(function(v: number): number
				return 1 - v * GUIDE_ALPHA
			end),
			Visible = guideHBind:map(function(v: number): boolean
				return v > 0.01
			end),
			BorderSizePixel = 0,
			ZIndex = 1,
		}),
		Root = e("Frame", {
			ref = rootRef,
			AnchorPoint = anchorBind,
			Position = posBind,
			Size = sizeBind,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = false,
			ZIndex = 2,
			[React.Event.InputBegan] = onRootInputBegan,
			[React.Event.MouseEnter] = onHoverEnter,
			[React.Event.MouseLeave] = onHoverLeave,
		}, {
			Glow = hoverGlow,
			Header = e("Frame", {
				ref = headerRef,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, LOGO_GAP),
				}),
				LogoWrapper = e("Frame", {
					Size = UDim2.fromOffset(LOGO_SIZE, LOGO_SIZE),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					LayoutOrder = 0,
				}, {
					Particles = e("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(0, 0),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ZIndex = 1,
					}, petalChildren),
					Logo = e("ImageLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Image = flower,
						ImageColor3 = WHITE,
						ImageTransparency = logoTrans,
						ZIndex = 2,
					}, {
						Gradient = e("UIGradient", {
							Color = logoColor._currentGradient,
							Rotation = logoColor._currentRotation,
						}),
					}),
				}),
				Title = e("TextLabel", {
					Size = UDim2.fromOffset(0, 0),
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = title,
					FontFace = infoFont,
					TextSize = TITLE_SIZE,
					TextColor3 = WHITE,
					TextTransparency = titleTrans,
					TextYAlignment = Enum.TextYAlignment.Center,
					LayoutOrder = 1,
					ZIndex = 2,
				}, {
					Padding = e("UIPadding", { PaddingBottom = UDim.new(0, 2) }),
					Gradient = e("UIGradient", {
						Color = titleColor._currentGradient,
						Rotation = titleColor._currentRotation,
					}),
					Stroke = e("UIStroke", {
						Color = BLACK,
						Thickness = 1,
						Transparency = strokeTrans,
					}),
				}),
			}),
			Info = e("Frame", {
				ref = infoRef,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = infoPosBind,
				Size = UDim2.fromOffset(0, INFO_SIZE),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, infoChildren),
		}),
	})
end
