local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local GuiService = cloneref(game:GetService("GuiService")) :: GuiService
local tooltipController = require("@ui/tooltip/tooltipController")
local tooltipState = require("@ui/tooltip/tooltipState")
local dpiState = require("@ui/util/dpiState")
local windowState = require("@ui/window/windowState")

local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef

export type TipInput = string | { title: string?, body: string }

export type TooltipHandlers = {
	onMouseEnter: () -> (),
	onMouseLeave: () -> (),
}

local function normalize(tip: TipInput?): tooltipState.TipInfo?
	if tip == nil then
		return nil
	end
	if type(tip) == "string" then
		if tip == "" then
			return nil
		end
		return { body = tip }
	end
	if not tip.body or tip.body == "" then
		return nil
	end
	return { title = tip.title, body = tip.body }
end

local function useTooltip(tip: TipInput?, frameRef: { current: GuiObject? }): TooltipHandlers
	local tipRef = useRef(normalize(tip))
	tipRef.current = normalize(tip)

	local frameRefRef = useRef(frameRef)
	frameRefRef.current = frameRef

	local activeRef = useRef(false)

	useEffect(function()
		return function()
			if activeRef.current then
				tooltipController.Hide()
				activeRef.current = false
			end
		end
	end, {})

	useEffect(function()
		if not tipRef.current and activeRef.current then
			tooltipController.Hide()
			activeRef.current = false
		end
	end, { tip })

	return useMemo(function()
		return {
			onMouseEnter = function()
				local info = tipRef.current
				local fr = frameRefRef.current
				local frame = fr and fr.current
				if not info or not frame then
					return
				end
				if Charm.peek(windowState.searchQuery) ~= "" then
					return
				end
				activeRef.current = true
				local scale = Charm.peek(dpiState.scale)
				if scale <= 0 then
					scale = 1
				end
				local screenPos = frame.AbsolutePosition + Vector2.new(0, GuiService:GetGuiInset().Y :: number)
				tooltipController.Show(info, {
					position = screenPos / scale,
					size = frame.AbsoluteSize / scale,
				}, frame)
			end,
			onMouseLeave = function()
				if activeRef.current then
					tooltipController.Hide()
					activeRef.current = false
				end
			end,
		}
	end, {})
end

return useTooltip
