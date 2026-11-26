local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local React = require("@pkg/React")

local viewportThumb = require("@feature/inventory/skinUi/viewportThumb")

local useRef = React.useRef
local useEffect = React.useEffect
local memo = React.memo
local e = React.createElement

local SPIN_SPEED = 0.9
local RETURN_RATE = 9
local SETTLE_EPSILON = 0.002
local TAU = math.pi * 2

local AMBIENT = Color3.fromRGB(150, 150, 150)
local LIGHT_COLOR = Color3.fromRGB(255, 255, 255)
local LIGHT_DIRECTION = Vector3.new(-0.35, -1, -0.6)

export type CardViewportProps = {
	Thumb: viewportThumb.Thumb,
	HoverAtom: Charm.Atom<boolean>?,
	Size: UDim2?,
	Corner: number?,
	ZIndex: number?,
}

local function CardViewportComponent(props: CardViewportProps): React.Element<any>
	local viewportRef = useRef(nil :: ViewportFrame?)
	local cameraRef = useRef(nil :: Camera?)

	local thumb = props.Thumb
	local hoverAtom = props.HoverAtom

	useEffect(function(): (() -> ())?
		local viewport = viewportRef.current
		local camera = cameraRef.current
		if not viewport or not camera then
			return nil
		end

		local model = thumb.model:Clone()
		model.Parent = viewport
		viewport.CurrentCamera = camera
		camera.CFrame = viewportThumb.cameraCFrame(thumb, 0)

		local connection: RBXScriptConnection? = nil
		local spin = 0
		local hovered = false

		local tick = LPH_NO_VIRTUALIZE(function(delta: number): ()
			if hovered then
				spin += delta * SPIN_SPEED
				if spin > TAU then
					spin -= TAU
				end
			else
				spin += (0 - spin) * math.min(1, delta * RETURN_RATE)
				if math.abs(spin) < SETTLE_EPSILON then
					spin = 0
					camera.CFrame = viewportThumb.cameraCFrame(thumb, 0)
					if connection then
						connection:Disconnect()
						connection = nil
					end
					return
				end
			end
			camera.CFrame = viewportThumb.cameraCFrame(thumb, spin)
		end)

		local unsubscribe: (() -> ())? = nil
		if hoverAtom then
			unsubscribe = Charm.subscribe(hoverAtom, function(state: boolean): ()
				hovered = state
				if state then
					if not connection then
						connection = RunService.PreRender:Connect(tick)
					end
				elseif spin > math.pi then
					spin -= TAU
				end
			end)
		end

		return function()
			if unsubscribe then
				unsubscribe()
			end
			if connection then
				connection:Disconnect()
			end
			model:Destroy()
		end
	end, { thumb, hoverAtom } :: { any })

	return e("ViewportFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		Ambient = AMBIENT,
		LightColor = LIGHT_COLOR,
		LightDirection = LIGHT_DIRECTION,
		Active = false,
		Selectable = false,
		ZIndex = props.ZIndex or 2,
		ref = viewportRef,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, props.Corner or 6),
		}),
		Camera = e("Camera", {
			FieldOfView = viewportThumb.FIELD_OF_VIEW,
			ref = cameraRef,
		}),
	})
end

local CardViewport = memo(CardViewportComponent, function(prev, nextProps)
	return prev.Thumb == nextProps.Thumb
		and prev.HoverAtom == nextProps.HoverAtom
		and prev.Size == nextProps.Size
		and prev.Corner == nextProps.Corner
		and prev.ZIndex == nextProps.ZIndex
end)

return CardViewport
