local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local BindListRenderer = require("@src/feature/ui/hud/bindlist/renderer")
local WatermarkRenderer = require("@src/feature/ui/hud/watermark/renderer")
local SpeedometerRenderer = require("@src/feature/ui/hud/speedometer/renderer")
local SpectatorsRenderer = require("@src/feature/ui/hud/spectators/renderer")
local NotifyRenderer = require("@src/feature/ui/hud/notify/renderer")
local ToastRenderer = require("@src/feature/ui/hud/toast/renderer")
local dpiState = require("@src/feature/ui/util/dpiState")

local useAt = ReactCharm.useAtom
local e = React.createElement

local HUD_ZINDEX = 2
local HUD_CONTENT_ZINDEX = 1
local HUD_NOTIFY_ZINDEX = 10

return function(): React.Element<any>
	local scale = useAt(dpiState.scale)

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = HUD_ZINDEX,
	}, {
		UIScale = e("UIScale", { Scale = scale }),
		Content = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = HUD_CONTENT_ZINDEX,
		}, {
			BindList = e(BindListRenderer),
			Watermark = e(WatermarkRenderer),
			Speedometer = e(SpeedometerRenderer),
			Spectators = e(SpectatorsRenderer),
		}),
		NotifyLayer = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = HUD_NOTIFY_ZINDEX,
		}, {
			Notify = e(NotifyRenderer),
			Toast = e(ToastRenderer),
		}),
	})
end
