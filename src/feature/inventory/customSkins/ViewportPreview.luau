local React = require("@pkg/React")

local modelPreview = require("@feature/inventory/customSkins/modelPreview")

local useRef = React.useRef
local useEffect = React.useEffect
local e = React.createElement

export type ViewportPreviewProps = {
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
	Corner: number?,
	OnMount: (parts: modelPreview.MountParts) -> (() -> ())?,
}

return function(props: ViewportPreviewProps): React.Element<any>
	local viewportRef = useRef(nil :: ViewportFrame?)
	local cameraRef = useRef(nil :: Camera?)
	local worldModelRef = useRef(nil :: WorldModel?)
	local inputRef = useRef(nil :: TextButton?)

	local zIndex = props.ZIndex or 62
	local corner = props.Corner or 6

	useEffect(function(): (() -> ())?
		local viewport = viewportRef.current
		local camera = cameraRef.current
		local worldModel = worldModelRef.current
		local input = inputRef.current
		if not viewport or not camera or not worldModel or not input then
			return nil
		end
		return props.OnMount({
			viewport = viewport,
			camera = camera,
			worldModel = worldModel,
			input = input,
		})
	end, {})

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		ZIndex = zIndex,
	}, {
		Viewport = e("ViewportFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Ambient = Color3.fromRGB(170, 170, 170),
			LightColor = Color3.fromRGB(255, 255, 255),
			LightDirection = Vector3.new(-0.4, -1, -0.5),
			Active = false,
			ZIndex = zIndex,
			ref = viewportRef,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0, corner) }),
			Camera = e("Camera", { FieldOfView = 50, ref = cameraRef }),
			World = e("WorldModel", { ref = worldModelRef }),
		}),
		Input = e("TextButton", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			Size = UDim2.fromScale(1, 1),
			ZIndex = zIndex + 2,
			ref = inputRef,
		}),
	})
end
