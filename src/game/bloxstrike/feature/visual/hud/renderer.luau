local React = require("@pkg/React")
local ReactRipple = require("@pkg/ReactRipple")
local ReactCharm = require("@pkg/ReactCharm")

local FileController = require("@src/feature/file/FileController")
local useShadow = require("@ui/hook/useShadow")
local SPRING = require("@ui/util/spring")
local gameHudState = require("@game/bloxstrike/feature/visual/hud/gameHudState")
local ClientState = require("@game/bloxstrike/client/clientState")

local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom
local useEffect = React.useEffect
local useMemo = React.useMemo
local useState = React.useState
local useCallback = React.useCallback
local useRef = React.useRef
local memo = React.memo
local e = React.createElement

local colors = gameHudState.colors

local CORNER = 6
local EDGE_PAD = 24
local CARD_PAD = 10
local OPEN_OFFSET = 6

local HEALTH_WIDTH = 240
local HEALTH_HEIGHT = 64
local ARMOR_BAR_WIDTH = 56

local WEAPON_WIDTH = 250
local WEAPON_HEIGHT = 64
local WEAPON_ICON_WIDTH = 76

local SLOT_WIDTH = 190
local SLOT_HEIGHT = 34
local SLOT_GAP = 6
local SLOT_KEY_SIZE = 18

local BAR_HEIGHT = 6
local ARMOR_BAR_HEIGHT = 4
local LOW_RATIO = 0.25

local KILL_ROW_HEIGHT = 26
local KILL_FEED_WIDTH = 440
local KILL_GAP = 6
local KILL_SLIDE = 24
local KILL_FEED_TOP = 0.12
local KILL_SHADOW_MULT = Vector2.new(1.35, 1.7)

local MONEY_WIDTH = 110
local MONEY_HEIGHT = 34

local TEAM_WIDTH = 340
local TEAM_CIRCLE = 42
local TEAM_LINE_GAP = 12
local PIP_SIZE = 14
local PIP_GAP = 6
local MAX_PIPS = 5

local TEAM_LABELS = {
	["Terrorists"] = "T",
	["Counter-Terrorists"] = "CT",
}

local function Bar(props: {
	Ratio: number,
	FillColor: Color3,
	Height: number,
	LayoutOrder: number?,
	Visible: boolean?,
	GhostColor: Color3?,
}): React.Element<any>
	local surface = useAt(colors.surface)

	local bind, spring = useSpring(props.Ratio, SPRING.smoothPrecise)
	local ghostBind, ghostSpring = useSpring(props.Ratio, SPRING.progress)

	useEffect(function()
		spring:setGoal(math.clamp(props.Ratio, 0, 1))
		ghostSpring:setGoal(math.clamp(props.Ratio, 0, 1))
	end, { props.Ratio })

	local fillSize = useMemo(function()
		return bind:map(function(v: number)
			return UDim2.fromScale(math.clamp(v, 0, 1), 1)
		end)
	end, { bind })

	local ghostSize = useMemo(function()
		return ghostBind:map(function(v: number)
			return UDim2.fromScale(math.clamp(v, 0, 1), 1)
		end)
	end, { ghostBind })

	return e("Frame", {
		BackgroundColor3 = surface.color,
		BackgroundTransparency = surface.transparency,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, props.Height),
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible ~= false,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		Ghost = props.GhostColor and e("Frame", {
			BackgroundColor3 = props.GhostColor,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Size = ghostSize,
			ZIndex = 1,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}) or nil,
		Fill = e("Frame", {
			BackgroundColor3 = props.FillColor,
			BorderSizePixel = 0,
			Size = fillSize,
			ZIndex = 2,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
	})
end

local function Card(props: {
	AnchorPoint: Vector2,
	Position: UDim2,
	Size: UDim2,
	AutomaticSize: Enum.AutomaticSize?,
	Visible: boolean?,
	Children: any,
}): React.Element<any>
	local background = useAt(colors.background)
	local border = useAt(colors.border)
	local shadow = useAt(colors.shadow)

	return e("Frame", {
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		AutomaticSize = props.AutomaticSize,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = props.Visible ~= false,
	}, {
		Shadow = useShadow({
			color = shadow.color,
			transparency = shadow.transparency,
			zIndex = 0,
			multiplier = Vector2.new(1.24, 1.46),
		}),
		Body = e("Frame", {
			BackgroundColor3 = background.color,
			BackgroundTransparency = background.transparency,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, CORNER),
			}),
			UIStroke = e("UIStroke", {
				Color = border.color,
				Transparency = border.transparency,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = e("UIPadding", {
				PaddingLeft = UDim.new(0, CARD_PAD),
				PaddingRight = UDim.new(0, CARD_PAD),
				PaddingTop = UDim.new(0, CARD_PAD),
				PaddingBottom = UDim.new(0, CARD_PAD),
			}),
			Content = e(React.Fragment, nil, props.Children),
		}),
	})
end

local function HealthCard(): React.Element<any>
	local health = useAt(gameHudState.health)
	local maxHealth = useAt(gameHudState.maxHealth)
	local armor = useAt(ClientState.armor)

	local accent = useAt(colors.accent)
	local team = useAt(colors.team)
	local enemy = useAt(colors.enemy)
	local text = useAt(colors.text)
	local textSecondary = useAt(colors.textSecondary)

	local ratio = maxHealth > 0 and health / maxHealth or 0
	local low = ratio <= LOW_RATIO
	local hasArmor = armor.kevlar == true
	local healthValue = math.max(math.floor(health + 0.5), 0)
	local armorValue = math.max(math.floor((armor.health or 0) + 0.5), 0)

	return e(Card, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, EDGE_PAD, 1, -EDGE_PAD),
		Size = UDim2.fromOffset(HEALTH_WIDTH, HEALTH_HEIGHT),
		Children = {
			Label = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 14),
				Text = "HEALTH",
				TextSize = 10,
				TextColor3 = textSecondary.color,
				FontFace = FileController.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			ArmorText = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 14),
				Text = string.format(
					'<font color="#%s">%d</font><font color="#%s"> %s</font>',
					team.color:ToHex(),
					armorValue,
					textSecondary.color:ToHex(),
					armor.helmet and "ARMOR / HELMET" or "ARMOR"
				),
				RichText = true,
				TextSize = 10,
				TextColor3 = text.color,
				FontFace = FileController.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Top,
				Visible = hasArmor,
			}),
			Value = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 14),
				Size = UDim2.new(1, 0, 0, 22),
				Text = string.format(
					'<font color="#%s">%d</font><font color="#%s" size="13"> / %d</font>',
					(low and enemy.color or text.color):ToHex(),
					healthValue,
					textSecondary.color:ToHex(),
					math.floor(maxHealth + 0.5)
				),
				RichText = true,
				TextSize = 20,
				TextColor3 = text.color,
				FontFace = FileController.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
			HealthBar = e("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 1),
				Size = hasArmor and UDim2.new(1, -(ARMOR_BAR_WIDTH + 6), 0, BAR_HEIGHT)
					or UDim2.new(1, 0, 0, BAR_HEIGHT),
			}, {
				Bar = e(Bar, {
					Ratio = ratio,
					FillColor = low and enemy.color or accent.color,
					GhostColor = enemy.color,
					Height = BAR_HEIGHT,
				}),
			}),
			ArmorBar = e("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.fromOffset(ARMOR_BAR_WIDTH, BAR_HEIGHT),
				Visible = hasArmor,
			}, {
				Bar = e(Bar, {
					Ratio = (armor.health or 0) / 100,
					FillColor = team.color,
					GhostColor = enemy.color,
					Height = BAR_HEIGHT,
				}),
			}),
		},
	})
end

local function commaNumber(value: number): string
	local formatted = tostring(value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return formatted
end

local function MoneyCard(): React.Element<any>
	local money = useAt(gameHudState.money)

	local accent = useAt(colors.accent)
	local text = useAt(colors.text)

	local bind, spring = useSpring(money, SPRING.progress)

	useEffect(function()
		spring:setGoal(money)
	end, { money })

	local moneyText = useMemo(function()
		return bind:map(function(v: number)
			return string.format(
				'<font color="#%s">$</font> %s',
				accent.color:ToHex(),
				commaNumber(math.max(math.round(v), 0))
			)
		end)
	end, { bind, accent.color } :: { any })

	return e(Card, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, EDGE_PAD, 1, -(EDGE_PAD + HEALTH_HEIGHT + 10)),
		Size = UDim2.fromOffset(MONEY_WIDTH, MONEY_HEIGHT),
		Children = {
			Amount = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Text = moneyText,
				RichText = true,
				TextSize = 15,
				TextColor3 = text.color,
				FontFace = FileController.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})
end

local function WeaponCard(): React.Element<any>
	local weaponName = useAt(gameHudState.weaponName)
	local weaponIcon = useAt(gameHudState.weaponIcon)
	local isGun = useAt(gameHudState.isGun)
	local rounds = useAt(gameHudState.rounds)
	local capacity = useAt(gameHudState.capacity)
	local magSize = useAt(gameHudState.magSize)
	local actionLabel = useAt(gameHudState.actionLabel)
	local actionProgress = useAt(gameHudState.actionProgress)

	local accent = useAt(colors.accent)
	local enemy = useAt(colors.enemy)
	local text = useAt(colors.text)
	local textSecondary = useAt(colors.textSecondary)

	local ratio = magSize > 0 and rounds / magSize or 0
	local low = isGun and ratio <= 0.2
	local actionActive = actionLabel ~= ""
	local barRatio = actionActive and actionProgress >= 0 and actionProgress or ratio

	local shownLabel, setShownLabel = useState("")

	useEffect(function()
		if actionLabel ~= "" then
			setShownLabel(actionLabel)
		end
	end, { actionLabel })

	local fadeBind, fadeSpring = useSpring(actionActive and 0 or 1, SPRING.quickPrecise)

	useEffect(function()
		fadeSpring:setGoal(actionActive and 0 or 1)
	end, { actionActive })

	local fadeVisible = useMemo(function()
		return fadeBind:map(function(v: number)
			return v < 0.995
		end)
	end, { fadeBind })

	return e(Card, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -EDGE_PAD, 1, -EDGE_PAD),
		Size = UDim2.fromOffset(WEAPON_WIDTH, WEAPON_HEIGHT),
		Visible = weaponName ~= "",
		Children = {
			Icon = e("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, WEAPON_ICON_WIDTH, 1, 0),
				Image = weaponIcon,
				ImageColor3 = text.color,
				ScaleType = Enum.ScaleType.Fit,
				Visible = weaponIcon ~= "",
			}),
			Info = e("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(WEAPON_ICON_WIDTH + CARD_PAD, 0),
				Size = UDim2.new(1, -(WEAPON_ICON_WIDTH + CARD_PAD), 1, 0),
			}, {
				Name = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 14),
					Text = weaponName,
					TextSize = 12,
					TextColor3 = textSecondary.color,
					FontFace = FileController.Get("font", "semi_bold"),
					TextXAlignment = Enum.TextXAlignment.Right,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				Action = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 14),
					Text = shownLabel,
					TextSize = 10,
					TextColor3 = accent.color,
					TextTransparency = fadeBind,
					FontFace = FileController.Get("font", "semi_bold"),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Visible = fadeVisible,
				}),
				Ammo = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, 14),
					Size = UDim2.new(1, 0, 0, 22),
					Text = string.format(
						'<font color="#%s">%d</font><font color="#%s" size="13"> / %d</font>',
						(low and enemy.color or text.color):ToHex(),
						rounds,
						textSecondary.color:ToHex(),
						capacity
					),
					RichText = true,
					TextSize = 20,
					TextColor3 = text.color,
					FontFace = FileController.Get("font", "semi_bold"),
					TextXAlignment = Enum.TextXAlignment.Right,
					TextYAlignment = Enum.TextYAlignment.Center,
					Visible = isGun,
				}),
				MagBar = e("Frame", {
					AnchorPoint = Vector2.new(0, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, ARMOR_BAR_HEIGHT),
					Visible = isGun or actionActive,
				}, {
					Bar = e(Bar, {
						Ratio = barRatio,
						FillColor = not actionActive and low and enemy.color or accent.color,
						Height = ARMOR_BAR_HEIGHT,
						LayoutOrder = 1,
					}),
				}),
			}),
		},
	})
end

local SLOT_STEP = SLOT_HEIGHT + SLOT_GAP

local function SlotPill(props: {
	Slot: gameHudState.HudSlot,
	Offset: number,
	Dead: boolean,
	OnGone: (id: string) -> (),
	Id: string,
}): React.Element<any>
	local slot = props.Slot

	local offsetBind, offsetSpring = useSpring(props.Offset, SPRING.smoothPrecise)

	useEffect(function()
		offsetSpring:setGoal(props.Offset)
	end, { props.Offset })

	local alphaBind, alphaSpring = useSpring(1, SPRING.quickPrecise)

	useEffect(function()
		alphaSpring:setGoal(props.Dead and 1 or 0)
	end, { props.Dead })

	useEffect(function()
		if not props.Dead then
			return
		end
		local thread = task.delay(0.3, props.OnGone, props.Id)
		return function()
			task.cancel(thread)
		end
	end, { props.Dead })

	local pillPosition = useMemo(function()
		return offsetBind:map(function(v: number)
			return UDim2.new(1, 2, 1, -math.round(v) + 2)
		end)
	end, { offsetBind })

	local accent = useAt(colors.accent)
	local text = useAt(colors.text)
	local textSecondary = useAt(colors.textSecondary)
	local background = useAt(colors.background)
	local surface = useAt(colors.surface)
	local border = useAt(colors.border)

	local bind, spring = useSpring(slot.active and 1 or 0, SPRING.quick)

	useEffect(function()
		spring:setGoal(slot.active and 1 or 0)
	end, { slot.active })

	local bgColor = useMemo(function()
		return bind:map(function(v: number)
			return background.color:Lerp(surface.color, v)
		end)
	end, { bind, background.color, surface.color } :: { any })

	local bgTransparency = useMemo(function()
		return React.joinBindings({ bind, alphaBind }):map(function(values)
			local v = values[1]
			local alpha = values[2]
			local base = background.transparency + (surface.transparency - background.transparency) * v
			return 1 - (1 - base) * (1 - alpha)
		end)
	end, { bind, alphaBind, background.transparency, surface.transparency } :: { any })

	local strokeTransparency = useMemo(function()
		return alphaBind:map(function(alpha: number)
			return 1 - (1 - border.transparency) * (1 - alpha)
		end)
	end, { alphaBind, border.transparency } :: { any })

	local keyTransparency = useMemo(function()
		return alphaBind:map(function(alpha: number)
			return 1 - (1 - surface.transparency) * (1 - alpha)
		end)
	end, { alphaBind, surface.transparency } :: { any })

	local pillVisible = useMemo(function()
		return alphaBind:map(function(alpha: number)
			return alpha < 0.995
		end)
	end, { alphaBind })

	local nameColor = useMemo(function()
		return bind:map(function(v: number)
			return textSecondary.color:Lerp(text.color, v)
		end)
	end, { bind, textSecondary.color, text.color } :: { any })

	local indicatorSize = useMemo(function()
		return bind:map(function(v: number)
			return UDim2.fromOffset(4, math.round(18 * v))
		end)
	end, { bind })

	return e("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = pillPosition,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(SLOT_WIDTH + 4, SLOT_HEIGHT + 4),
		Visible = pillVisible,
	}, {
		Body = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(SLOT_WIDTH, SLOT_HEIGHT),
			BackgroundColor3 = bgColor,
			BackgroundTransparency = bgTransparency,
			BorderSizePixel = 0,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, CORNER),
			}),
			UIStroke = e("UIStroke", {
				Color = border.color,
				Transparency = strokeTransparency,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Indicator = e("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = indicatorSize,
				BackgroundColor3 = accent.color,
				BackgroundTransparency = alphaBind,
				BorderSizePixel = 0,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			}),
			Key = e("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(SLOT_KEY_SIZE, SLOT_KEY_SIZE),
				BackgroundColor3 = surface.color,
				BackgroundTransparency = keyTransparency,
				BorderSizePixel = 0,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(0, 4),
				}),
				Text = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					Text = tostring(slot.key),
					TextSize = 12,
					TextColor3 = slot.active and accent.color or textSecondary.color,
					TextTransparency = alphaBind,
					FontFace = FileController.Get("font", "semi_bold"),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
			}),
			Name = e("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(8 + SLOT_KEY_SIZE + 8, 0),
				Size = UDim2.new(1, -(8 + SLOT_KEY_SIZE + 8 + 58), 1, 0),
				Text = slot.name,
				TextSize = 12,
				TextColor3 = nameColor,
				TextTransparency = alphaBind,
				FontFace = FileController.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Icon = e("ImageLabel", {
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(44, 22),
				Image = slot.icon,
				ImageColor3 = nameColor,
				ImageTransparency = alphaBind,
				ScaleType = Enum.ScaleType.Fit,
				Visible = slot.icon ~= "",
			}),
		}),
	})
end

type StripEntry = {
	id: string,
	slot: gameHudState.HudSlot,
	offset: number,
	dead: boolean,
}

local function SlotStrip(): React.Element<any>
	local slots = useAt(gameHudState.slots)

	local entries, setEntries = useState({} :: { StripEntry })

	useEffect(function()
		setEntries(function(prev: { StripEntry }): { StripEntry }
			local counts: { [string]: number } = {}
			local result = {}
			local aliveIds: { [string]: true } = {}
			local total = #slots

			for index, slot in next, slots do
				local base = `{slot.key}_{slot.name}`
				local count = (counts[base] or 0) + 1
				counts[base] = count
				local id = `{base}_{count}`
				aliveIds[id] = true
				table.insert(result, {
					id = id,
					slot = slot,
					offset = (total - index) * SLOT_STEP,
					dead = false,
				})
			end

			for _, old in next, prev do
				if not aliveIds[old.id] then
					table.insert(result, {
						id = old.id,
						slot = old.slot,
						offset = old.offset,
						dead = true,
					})
				end
			end

			return result
		end)
	end, { slots })

	local onGone = useCallback(function(id: string): ()
		setEntries(function(prev: { StripEntry }): { StripEntry }
			local result = {}
			for _, entry in next, prev do
				if entry.id ~= id then
					table.insert(result, entry)
				end
			end
			return result
		end)
	end, {})

	local children: { [string]: any } = {}
	for _, entry in next, entries do
		children[entry.id] = e(SlotPill, {
			Slot = entry.slot,
			Offset = entry.offset,
			Dead = entry.dead,
			OnGone = onGone,
			Id = entry.id,
		})
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -EDGE_PAD, 1, -(EDGE_PAD + WEAPON_HEIGHT + 10)),
		Size = UDim2.fromOffset(SLOT_WIDTH, SLOT_HEIGHT),
	}, children)
end

local function TeamPip(props: {
	LayoutOrder: number,
}): React.Element<any>
	local pipColor = useAt(colors.teamPip)
	local icon = useAt(gameHudState.pipIcon)

	local bind, spring = useSpring(0, SPRING.quick)

	useEffect(function()
		spring:setGoal(1)
	end, {})

	local transparency = useMemo(function()
		return bind:map(function(v: number)
			return 1 - (1 - pipColor.transparency) * v
		end)
	end, { bind, pipColor.transparency } :: { any })

	local size = useMemo(function()
		return bind:map(function(v: number)
			local pixels = math.round(PIP_SIZE * v)
			return UDim2.fromOffset(pixels, pixels)
		end)
	end, { bind })

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(PIP_SIZE, PIP_SIZE),
		LayoutOrder = props.LayoutOrder,
	}, {
		Icon = icon ~= "" and e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = size,
			Image = icon,
			ImageColor3 = pipColor.color,
			ImageTransparency = transparency,
			ScaleType = Enum.ScaleType.Fit,
		}) or e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = pipColor.color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = size,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
	})
end

local function TeamCard(): React.Element<any>
	local team = useAt(ClientState.team)
	local roundKills = useAt(gameHudState.roundKills)

	local lineColor = useAt(colors.teamLine)
	local labelColor = useAt(colors.teamLabel)
	local background = useAt(colors.background)
	local border = useAt(colors.border)
	local shadow = useAt(colors.shadow)

	local lineGradient = useMemo(function()
		return NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0.2),
		})
	end, {})

	local pips = useMemo(function()
		local rendered: { [string]: any } = {}
		for index = 1, math.min(roundKills, MAX_PIPS) do
			rendered["Pip" .. index] = e(TeamPip, {
				LayoutOrder = index,
			})
		end
		return rendered
	end, { roundKills })

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 1, -EDGE_PAD),
		Size = UDim2.fromOffset(TEAM_WIDTH, TEAM_CIRCLE),
		Visible = team ~= nil,
	}, {
		LineLeft = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = lineColor.color,
			BackgroundTransparency = lineColor.transparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(0.5, -(TEAM_CIRCLE / 2 + TEAM_LINE_GAP), 0, 1),
		}, {
			UIGradient = e("UIGradient", {
				Transparency = lineGradient,
			}),
		}),
		LineRight = e("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = lineColor.color,
			BackgroundTransparency = lineColor.transparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.new(0.5, -(TEAM_CIRCLE / 2 + TEAM_LINE_GAP), 0, 1),
		}, {
			UIGradient = e("UIGradient", {
				Transparency = lineGradient,
				Rotation = 180,
			}),
		}),
		Badge = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(TEAM_CIRCLE, TEAM_CIRCLE),
		}, {
			Shadow = e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1.4, 1.4),
				Image = FileController.Get("image", "circle_shadow"),
				ImageColor3 = shadow.color,
				ImageTransparency = shadow.transparency,
				ScaleType = Enum.ScaleType.Stretch,
				ZIndex = 0,
			}),
			Circle = e("Frame", {
				BackgroundColor3 = background.color,
				BackgroundTransparency = background.transparency,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
			}, {
				UICorner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
				UIStroke = e("UIStroke", {
					Color = border.color,
					Transparency = border.transparency,
					Thickness = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				Label = e("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					Text = team and TEAM_LABELS[team] or "",
					TextSize = 14,
					TextColor3 = labelColor.color,
					TextTransparency = labelColor.transparency,
					FontFace = FileController.Get("font", "semi_bold"),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
			}),
		}),
		Pips = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 0, -8),
			Size = UDim2.new(0, TEAM_WIDTH, 0, PIP_SIZE),
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, PIP_GAP),
			}),
			Content = e(React.Fragment, nil, pips),
		}),
	})
end

local KillRow = memo(function(props: {
	Entry: gameHudState.KillEntry,
	SlotY: number?,
}): React.Element<any>
	local entry = props.Entry

	local accent = useAt(colors.accent)
	local team = useAt(colors.team)
	local enemy = useAt(colors.enemy)
	local textSecondary = useAt(colors.textSecondary)
	local background = useAt(colors.killBackground)
	local stroke = useAt(colors.killStroke)
	local shadow = useAt(colors.killShadow)
	local icon = useAt(colors.killIcon)

	local visible = props.SlotY ~= nil
	local lastSlotRef = useRef(props.SlotY or 0)
	if props.SlotY ~= nil then
		lastSlotRef.current = props.SlotY
	end
	local targetY = lastSlotRef.current

	local yBind, ySpring = useSpring(targetY, SPRING.smoothPrecise)
	useEffect(function()
		ySpring:setGoal(targetY)
	end, { targetY })

	local bind, spring = useSpring(0, SPRING.smoothPrecise)
	useEffect(function()
		spring:setGoal(visible and 1 or 0)
	end, { visible })

	local position = useMemo(function()
		return React.joinBindings({ yBind, bind }):map(function(values)
			local y = values[1]
			local v = values[2]
			return UDim2.new(1, math.floor((1 - v) * KILL_SLIDE + 0.5), 0, y)
		end)
	end, { yBind, bind } :: { any })

	local outerVisible = useMemo(function()
		return bind:map(function(v: number)
			return v > 0.001
		end)
	end, { bind })

	local fade = useMemo(function()
		return bind:map(function(v: number)
			return 1 - v
		end)
	end, { bind })

	local bgTransparency = useMemo(function()
		return bind:map(function(v: number)
			return 1 - (1 - background.transparency) * v
		end)
	end, { bind, background.transparency } :: { any })

	local strokeTransparency = useMemo(function()
		return bind:map(function(v: number)
			return 1 - (1 - stroke.transparency) * v
		end)
	end, { bind, stroke.transparency } :: { any })

	local shadowTransparency = useMemo(function()
		return bind:map(function(v: number)
			return 1 - (1 - shadow.transparency) * v
		end)
	end, { bind, shadow.transparency } :: { any })

	local function nameColor(enemyFlag: boolean, localFlag: boolean): Color3
		if localFlag then
			return accent.color
		end
		if enemyFlag then
			return enemy.color
		end
		return team.color
	end

	local children: { [string]: any } = {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, CORNER),
		}),
		UIStroke = e("UIStroke", {
			Color = stroke.color,
			Transparency = strokeTransparency,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 3),
			PaddingRight = UDim.new(0, 11),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		Accent = e("Frame", {
			BackgroundColor3 = nameColor(entry.killerEnemy, entry.killerLocal),
			BackgroundTransparency = fade,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 4, 1, 0),
			LayoutOrder = 0,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
		Killer = e("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0),
			Text = entry.killerName,
			TextSize = 14,
			TextColor3 = nameColor(entry.killerEnemy, entry.killerLocal),
			TextTransparency = fade,
			FontFace = FileController.Get("font", "semi_bold"),
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 1,
		}),
		Victim = e("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0),
			Text = entry.victimName,
			TextSize = 14,
			TextColor3 = nameColor(entry.victimEnemy, entry.victimLocal),
			TextTransparency = fade,
			FontFace = FileController.Get("font", "semi_bold"),
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 40,
		}),
	}

	if entry.assistName then
		children.Assist = e("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0),
			Text = `+ {entry.assistName}`,
			TextSize = 12,
			TextColor3 = textSecondary.color,
			TextTransparency = fade,
			FontFace = FileController.Get("font", "semi_bold"),
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 2,
		})
	end

	for index, tag in next, entry.tags do
		children["Tag" .. index] = e("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = tag.wide and UDim2.fromOffset(38, 16) or UDim2.fromOffset(15, 15),
			Image = tag.icon,
			ImageColor3 = icon.color,
			ImageTransparency = fade,
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = 10 + index,
		})
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = UDim2.fromOffset(0, KILL_ROW_HEIGHT),
		Visible = outerVisible,
	}, {
		Shadow = useShadow({
			color = shadow.color,
			transparency = shadowTransparency,
			multiplier = KILL_SHADOW_MULT,
			zIndex = 0,
		}),
		Pill = e("Frame", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = background.color,
			BackgroundTransparency = bgTransparency,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0),
			ZIndex = 1,
		}, children),
	})
end)

local function KillFeed(): React.Element<any>
	local enabled = useAt(gameHudState.killFeedEnabled)
	local spectating = useAt(ClientState.isSpectating)
	local kills = useAt(gameHudState.kills)

	local children = useMemo(function()
		local rendered: { [string]: any } = {}
		local slotY = 0
		for _, entry in next, kills do
			local slot: number? = nil
			if not entry.dead then
				slot = slotY
				slotY = slotY + KILL_ROW_HEIGHT + KILL_GAP
			end
			rendered["Kill" .. entry.id] = e(KillRow, {
				Entry = entry,
				SlotY = slot,
			})
		end
		return rendered
	end, { kills } :: { any })

	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -EDGE_PAD, KILL_FEED_TOP, 0),
		Size = UDim2.fromOffset(KILL_FEED_WIDTH, 0),
		Visible = enabled and not spectating,
	}, children)
end

return function(): React.Element<any>
	local enabled = useAt(gameHudState.enabled)
	local alive = useAt(ClientState.alive)
	local spectating = useAt(ClientState.isSpectating)

	local shown = enabled and alive and not spectating

	local bind, spring = useSpring(shown and 1 or 0, SPRING.smoothPrecise)

	useEffect(function()
		spring:setGoal(shown and 1 or 0)
	end, { shown })

	local position = useMemo(function()
		return bind:map(function(v: number)
			return UDim2.fromOffset(0, math.floor((1 - v) * OPEN_OFFSET))
		end)
	end, { bind })

	local visible = useMemo(function()
		return bind:map(function(v: number)
			return v > 0.005
		end)
	end, { bind })

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, {
		Main = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Position = position,
			Visible = visible,
		}, {
			Health = e(HealthCard),
			Money = e(MoneyCard),
			Weapon = e(WeaponCard),
			Slots = e(SlotStrip),
			Team = e(TeamCard),
		}),
		KillFeed = e(KillFeed),
	})
end
