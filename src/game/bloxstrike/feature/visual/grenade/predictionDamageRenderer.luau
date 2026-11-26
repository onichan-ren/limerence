local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local ReactRipple = require("@pkg/ReactRipple")
local Charm = require("@pkg/Charm")

local FileController = require("@feature/file/FileController")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local e = React.createElement
local useEffect = React.useEffect
local useSpring = ReactRipple.useSpring
local useAt = ReactCharm.useAtom

local at = Charm.atom
local peek = Charm.peek


local LETHAL_COLOR = Color3.fromRGB(228, 70, 70)
local SELF_COLOR = Color3.fromRGB(210, 165, 85)
local OUTLINE_COLOR = Color3.fromRGB(18, 18, 18)
local SPHERE_Y_OFFSET = -8
local _impactPos: Vector3? = nil

local APPEAR_SPRING = { dampingRatio = 0.65, frequency = 3.5, precision = 0.005 }
local FOLLOW_SPRING = { dampingRatio = 1.2, frequency = 12, precision = 0.5 }

export type EnemyEntry = {
	dmg: number,
	lethal: boolean,
	text: string?,
	color: Color3?,
}

export type PredEntry = {
	impactPos: Vector3,
	selfDmg: number,
	selfLethal: boolean,
	selfText: string?,
	selfColor: Color3?,
	enemies: { EnemyEntry },
	color: Color3,
}

local predAtom = at(nil :: PredEntry?)

local makeLabel = LPH_NO_VIRTUALIZE(function(order: number, text: string, color: Color3, transparency: any)
	return e("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 9),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = color,
		TextTransparency = transparency,
		FontFace = FileController.Get("font", "pixel2"),
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, {
		Stroke = e("UIStroke", {
			Color = OUTLINE_COLOR,
			Thickness = 1,
			Transparency = transparency,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}),
	})
end)

local PredDisplay = LPH_NO_VIRTUALIZE(function(): React.Element<any>?
	local pred = useAt(predAtom) :: PredEntry?

	local xBind, xSpring = useSpring(0, FOLLOW_SPRING)
	local yBind, ySpring = useSpring(0, FOLLOW_SPRING)
	local appearBind, appearSpring = useSpring(0, APPEAR_SPRING)

	useEffect(function()
		appearSpring:setGoal(pred ~= nil and 1 or 0)
	end, { pred ~= nil })

	useEffect(function()
		local firstStep = true
		local conn = RunService.PreRender:Connect(function()
			if not _impactPos then
				return
			end
			local camera = Workspace.CurrentCamera
			if not camera then
				return
			end
			local sv = camera:WorldToViewportPoint(_impactPos)
			if firstStep then
				firstStep = false
				xSpring:setPosition(sv.X)
				ySpring:setPosition(sv.Y)
			end
			xSpring:setGoal(sv.X)
			ySpring:setGoal(sv.Y)
		end)
		return function()
			conn:Disconnect()
		end
	end, {})

	local positionBind = React.joinBindings({ xBind, yBind }):map(function(values): UDim2
		return UDim2.fromOffset(math.floor(values[1]), math.floor(values[2]) + SPHERE_Y_OFFSET)
	end)

	local visibleBind = appearBind:map(function(v: number): boolean
		return v > 0.001
	end)

	local transparencyBind = appearBind:map(function(v: number): number
		return math.clamp(1 - v, 0, 1)
	end)

	local children: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	}

	if pred then
		local sorted = table.clone(pred.enemies)
		table.sort(sorted, function(a, b)
			return a.dmg > b.dmg
		end)

		local order = 1
		for _, enemy in next, sorted do
			local color = enemy.color or (enemy.lethal and LETHAL_COLOR or pred.color)
			local text = enemy.text or (enemy.lethal and "LETHAL" or string.format("%d dmg", enemy.dmg))
			children["e" .. order] = makeLabel(order, text, color, transparencyBind)
			order += 1
		end

		if pred.selfDmg > 0 then
			local selfColor = pred.selfColor or (pred.selfLethal and LETHAL_COLOR or SELF_COLOR)
			local selfText = pred.selfText or (pred.selfLethal and "LETHAL" or string.format("%d dmg", pred.selfDmg))
			children["self"] = makeLabel(order, selfText, selfColor, transparencyBind)
		end
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = positionBind,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = visibleBind,
	}, children)
end)

local setPrediction = LPH_NO_VIRTUALIZE(function(entry: PredEntry?)
	if not entry then
		_impactPos = nil
		if peek(predAtom) ~= nil then
			predAtom(nil)
		end
		return
	end
	_impactPos = entry.impactPos
	local prev = peek(predAtom)
	if
		prev ~= nil
		and entry.selfDmg == prev.selfDmg
		and entry.selfLethal == prev.selfLethal
		and entry.color == prev.color
		and #entry.enemies == #prev.enemies
	then
		local same = true
		for i = 1, #entry.enemies do
			local a, b = entry.enemies[i], prev.enemies[i]
			if a.dmg ~= b.dmg or a.lethal ~= b.lethal then
				same = false
				break
			end
		end
		if same then
			return
		end
	end
	predAtom(entry)
end)

return {
	render = PredDisplay,
	setPrediction = setPrediction,
}
