local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService
local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Charm = require("@pkg/Charm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local uiState = require("@ui/uiState")
local useDraggable = require("@ui/hook/useDraggable")
local useHudHover = require("@ui/hook/useHudHover")
local useShadow = require("@ui/hook/useShadow")
local SPRING = require("@ui/util/spring")
local bombState = require("@game/bloxstrike/bomb/bombState")
local clientState = require("@game/bloxstrike/client/clientState")
local clientApi = require("@game/bloxstrike/client/clientApi")

local peek = Charm.peek
local sub = Charm.subscribe

local useEffect = React.useEffect
local useMemo = React.useMemo
local useBinding = React.useBinding
local useRef = React.useRef
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local e = React.createElement

local BEEP_MIN_INTERVAL = 0.15
local ICON_FLASH_STRENGTH = 0.9
local FLASH_SPRING = { tension = 150, friction = 40 }

local colors = themeState.colors.hud

local _cachedGood: Color3 = peek(colors.good)
local _cachedDanger: Color3 = peek(colors.danger)
local _cachedWarning: Color3 = peek(colors.warning)
local _cachedNeutral: Color3 = peek(colors.neutral)

sub(colors.good, function(v: Color3): ()
	_cachedGood = v
end)
sub(colors.danger, function(v: Color3): ()
	_cachedDanger = v
end)
sub(colors.warning, function(v: Color3): ()
	_cachedWarning = v
end)
sub(colors.neutral, function(v: Color3): ()
	_cachedNeutral = v
end)

local FRAME_WIDTH = 168
local FRAME_HEIGHT = 56
local ICON_SIZE = 32
local PADDING_X = 10
local PADDING_Y = 12
local TEXT_GAP = 10
local CORNER = 8

local C4_MAX_DAMAGE = 1200
local C4_SIGMA = 44
local C4_ARMOR_FACTOR = 0.574

local nearestSite = LPH_NO_VIRTUALIZE(function(position: Vector3): string?
	local bestSite: string? = nil
	local bestDistance = math.huge
	for _, part in next, CollectionService:GetTagged("PlantArea") do
		if part:IsA("BasePart") then
			local site = part:GetAttribute("Site")
			if site == "A" or site == "B" then
				local distance = (part.Position - position).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					bestSite = site :: string
				end
			end
		end
	end
	return bestSite
end)

local estimateDamage = LPH_NO_VIRTUALIZE(function(bombPosition: Vector3): number
	local hrp = peek(clientState.parts).HumanoidRootPart :: any
	if not hrp then
		return 0
	end
	local distance = (hrp.Position - bombPosition).Magnitude
	local armor = peek(clientState.armor)
	local armorFactor = armor.kevlar and C4_ARMOR_FACTOR or 1.0
	local damage = C4_MAX_DAMAGE * math.exp(-distance / C4_SIGMA) * armorFactor
	if damage < 0.5 then
		return 0
	end
	return math.floor(damage + 0.5)
end)

local runTick = LPH_NO_VIRTUALIZE(
	function(
		plantedActive: boolean,
		plantingActive: boolean,
		previewActive: boolean,
		bomb: bombState.BombState?,
		planting: bombState.PlantingState?,
		setProgress: (number) -> (),
		setLabel: (string) -> (),
		setTime: (string) -> (),
		setSub: (string) -> (),
		setDamageColor: (Color3) -> ()
	): ()
		local goodColor = _cachedGood
		local dangerColor = _cachedDanger
		local warningColor = _cachedWarning
		local neutralColor = _cachedNeutral
		if plantedActive and bomb then
			local bombData = bomb :: bombState.BombState
			local now = Workspace:GetServerTimeNow()
			local remaining = math.max(0, bombData.explodeAt - now)
			local progress = (bombData.duration > 0 and remaining / bombData.duration or 0)
			setProgress(progress)

			local bombPos = bombData.model:GetPivot().Position
			local site = nearestSite(bombPos) or "?"
			setLabel("Planted " .. site)

			if bombData.isDefused then
				setProgress(0)
				setTime("DEFUSED")
				setSub("Safe")
				setDamageColor(goodColor)
				return
			end
			if bombData.isExploded then
				setTime("EXPLODED")
				setSub("")
				setDamageColor(dangerColor)
				return
			end

			setTime(string.format("%.1fs", remaining))

			local damage = estimateDamage(bombPos)
			if damage <= 0 then
				setSub("Safe")
				setDamageColor(goodColor)
			else
				local currentHp = clientApi.GetHealth()
				local lethal = damage >= currentHp
				if lethal then
					setSub(string.format("LETHAL (%d)", damage))
					setDamageColor(dangerColor)
				elseif damage >= 100 then
					setSub(string.format("%d dmg", damage))
					setDamageColor(dangerColor)
				elseif damage >= 40 then
					setSub(string.format("%d dmg", damage))
					setDamageColor(warningColor)
				else
					setSub(string.format("%d dmg", damage))
					setDamageColor(neutralColor)
				end
			end
			return
		end

		if plantingActive and planting then
			local plantState = planting :: bombState.PlantingState
			local elapsed = os.clock() - plantState.startedAt
			local remaining = math.max(0, plantState.duration - elapsed)
			local progress = (plantState.duration > 0 and 1 - remaining / plantState.duration or 1)
			setProgress(progress)
			setLabel("Planting " .. (plantState.site or "?"))
			setTime(string.format("%.1fs", remaining))
			setSub("")
			setDamageColor(warningColor)
			return
		end

		if previewActive then
			setProgress(1)
			setLabel("Bomb HUD")
			setTime("")
			setSub("Preview")
			setDamageColor(neutralColor)
		end
	end
)

return LPH_JIT_MAX(function(): React.Element<any>?
	local hudEnabled = useAt(bombState.hudEnabled)
	local bomb = useAt(bombState.bomb)
	local planting = useAt(bombState.planting)
	local menuOpen = useAt(uiState.isOpen)

	local plantedActive = bomb ~= nil
	local plantingActive = (not plantedActive) and planting ~= nil
	local previewActive = (not plantedActive) and not plantingActive and menuOpen
	local shown = hudEnabled and (plantedActive or plantingActive or previewActive)

	local appearBind, appearSpring = useSpring(0, SPRING.smoothPrecise)
	useEffect(function()
		appearSpring:setGoal(shown and 1 or 0)
	end, { shown })

	local timeBind, setTime = useBinding("")
	local subBind, setSub = useBinding("")
	local labelBind, setLabel = useBinding("")
	local damageColorBind, setDamageColor = useBinding(peek(colors.danger))
	local progressBind, setProgress = useBinding(0)
	local flashBind, flashSpring = useSpring(0, FLASH_SPRING)
	local nextBeepRef = useRef(nil :: number?)

	useEffect(function()
		nextBeepRef.current = nil
	end, { bomb } :: { any })

	useEffect(function()
		if not (shown and plantedActive) then
			return
		end
		local conn = RunService.Heartbeat:Connect(function()
			local bombData = bomb
			if not bombData or bombData.isDefused or bombData.isExploded then
				return
			end
			local now = Workspace:GetServerTimeNow()
			local remaining = math.max(bombData.explodeAt - now, 0)
			if remaining <= 0 then
				return
			end

			if nextBeepRef.current == nil then
				local cursor = bombData.startedAt
				while cursor <= now do
					local rem = math.max(bombData.explodeAt - cursor, 0)
					if rem <= 0 then
						break
					end
					cursor += math.max(rem / bombData.duration * 0.9 + 0.1, BEEP_MIN_INTERVAL)
				end
				nextBeepRef.current = cursor
			end

			if now >= nextBeepRef.current then
				nextBeepRef.current = now + math.max(remaining / bombData.duration * 0.9 + 0.1, BEEP_MIN_INTERVAL)
				flashSpring:setPosition(1)
				flashSpring:setGoal(0)
			end
		end)
		return function()
			conn:Disconnect()
		end
	end, { shown, plantedActive, bomb } :: { any })

	useEffect(function()
		if not shown then
			return
		end

		local function tick(): ()
			runTick(
				plantedActive,
				plantingActive,
				previewActive,
				bomb,
				planting,
				setProgress,
				setLabel,
				setTime,
				setSub,
				setDamageColor
			)
		end

		tick()
		local conn = RunService.Heartbeat:Connect(tick)
		return function()
			conn:Disconnect()
		end
	end, { shown, plantedActive, plantingActive, previewActive, bomb, planting } :: { any })

	local onDragInput, positionBind = useDraggable(bombState.hudPosition)
	local onHoverEnter, onHoverLeave, hoverGlow = useHudHover(menuOpen and hudEnabled)

	local bgPack = useAt(colors.background)
	local bgColor = bgPack[1] :: Color3
	local bgAlpha = bgPack[2] :: number

	local strokePack = useAt(colors.stroke)
	local strokeColor = strokePack[1] :: Color3
	local strokeAlpha = strokePack[2] :: number

	local shadowPack = useAt(colors.shadow)
	local shadowColor = shadowPack[1] :: Color3
	local shadowAlpha = shadowPack[2] :: number

	local imageColor = useAt(colors.image)
	local flashColor = useAt(colors.bombFlash)
	local titleColor = useAt(colors.title)
	local textColor = useAt(colors.text)
	local barColor = useAt(colors.bar)

	local outerPosition = useMemo(function()
		return React.joinBindings({ appearBind, positionBind }):map(function(values): UDim2
			local v: number = values[1] :: number
			local pos: UDim2 = values[2] :: UDim2
			local slide = (1 - v) * -10
			return UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset + slide)
		end)
	end, { appearBind, positionBind } :: { any })

	local visible = useMemo(function()
		return appearBind:map(function(v: number): boolean
			return v > 0.001
		end)
	end, { appearBind })

	local bgTransparency = useMemo(function()
		return appearBind:map(function(v: number): number
			return 1 - v * (1 - bgAlpha)
		end)
	end, { appearBind, bgAlpha } :: { any })

	local strokeTransparency = useMemo(function()
		return appearBind:map(function(v: number): number
			return 1 - v * (1 - strokeAlpha)
		end)
	end, { appearBind, strokeAlpha } :: { any })

	local shadowTransparency = useMemo(function()
		return appearBind:map(function(v: number): number
			return 1 - v * (1 - shadowAlpha)
		end)
	end, { appearBind, shadowAlpha } :: { any })

	local contentTransparency = useMemo(function()
		return appearBind:map(function(v: number): number
			return 1 - v
		end)
	end, { appearBind })

	local progressSizeBind = useMemo(function()
		return progressBind:map(function(p: number): UDim2
			return UDim2.fromScale(math.clamp(p, 0, 1), 1)
		end)
	end, { progressBind })

	local iconColorBind = useMemo(function()
		return flashBind:map(function(pulse: number): Color3
			return imageColor:Lerp(flashColor, math.clamp(pulse * ICON_FLASH_STRENGTH, 0, 1))
		end)
	end, { flashBind, imageColor, flashColor } :: { any })

	local function onInputBegan(_: any, input: InputObject): ()
		if not menuOpen or not hudEnabled then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onDragInput(input)
		end
	end

	local bombIcon = FileController.Get("image", "c4")
	local font = FileController.Get("font", "semi_bold")

	return e("Frame", {
		Active = false,
		AnchorPoint = Vector2.new(0, 0),
		Position = outerPosition,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(FRAME_WIDTH, FRAME_HEIGHT),
		Visible = visible,
		[React.Event.InputBegan] = onInputBegan,
		[React.Event.MouseEnter] = onHoverEnter,
		[React.Event.MouseLeave] = onHoverLeave,
	}, {
		Glow = hoverGlow,
		Shadow = useShadow({
			color = shadowColor,
			transparency = shadowTransparency,
			zIndex = 0,
			multiplier = Vector2.new(1.22, 1.42),
		}),
		Body = e("Frame", {
			BackgroundColor3 = bgColor,
			BackgroundTransparency = bgTransparency,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			ClipsDescendants = true,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, CORNER),
			}),
			UIStroke = e("UIStroke", {
				Color = strokeColor,
				Transparency = strokeTransparency,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, PADDING_X),
				PaddingRight = UDim.new(0, PADDING_X),
				PaddingTop = UDim.new(0, PADDING_Y),
				PaddingBottom = UDim.new(0, PADDING_Y),
			}),
			Icon = e("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = bombIcon,
				ImageColor3 = iconColorBind,
				ImageTransparency = contentTransparency,
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				ZIndex = 1,
			}),
			Right = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, ICON_SIZE + TEXT_GAP, 0.5, 0),
				Size = UDim2.new(1, -(ICON_SIZE + TEXT_GAP), 1, 0),
			}, {
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 2),
				}),
				Title = e("TextLabel", {
					LayoutOrder = 1,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = labelBind,
					TextColor3 = titleColor,
					TextTransparency = contentTransparency,
					FontFace = font,
					TextSize = 14,
					Size = UDim2.new(1, 0, 0, 14),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				Timer = e("TextLabel", {
					LayoutOrder = 2,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = timeBind,
					TextColor3 = textColor,
					TextTransparency = contentTransparency,
					FontFace = font,
					TextSize = 12,
					Size = UDim2.new(1, 0, 0, 12),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
				ProgressTrack = e("Frame", {
					LayoutOrder = 3,
					BackgroundColor3 = barColor,
					BackgroundTransparency = contentTransparency,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 3),
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(1, 0),
					}),
					Fill = e("Frame", {
						BackgroundColor3 = damageColorBind,
						BackgroundTransparency = contentTransparency,
						BorderSizePixel = 0,
						Size = progressSizeBind,
					}, {
						UICorner = e("UICorner", {
							CornerRadius = UDim.new(1, 0),
						}),
					}),
				}),
				Damage = e("TextLabel", {
					LayoutOrder = 4,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = subBind,
					TextColor3 = damageColorBind,
					TextTransparency = contentTransparency,
					FontFace = font,
					TextSize = 12,
					Size = UDim2.new(1, 0, 0, 12),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
			}),
		}),
	})
end)
