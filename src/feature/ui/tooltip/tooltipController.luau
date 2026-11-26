local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local Charm = require("@pkg/Charm")
local tipMetrics = require("@ui/tooltip/tipMetrics")
local tooltipState = require("@ui/tooltip/tooltipState")
local floatingController = require("@ui/floating/floatingController")
local uiState = require("@ui/uiState")

local SHOW_DELAY = 0.4
local TOOLTIP_ID = "tooltip"

local tooltipController = {}

local pendingShow: thread? = nil
local moveConn: RBXScriptConnection? = nil
local sequence = 0
local registered = false

local function clearPending(): ()
	if pendingShow then
		task.cancel(pendingShow)
		pendingShow = nil
	end
end

local function clearMoveListener(): ()
	if moveConn then
		moveConn:Disconnect()
		moveConn = nil
	end
end

local function clearRegistration(): ()
	if registered then
		registered = false
		floatingController.Unregister(TOOLTIP_ID)
	end
end

function tooltipController.Show(info: tooltipState.TipInfo, anchor: tooltipState.TipAnchor, anchorFrame: GuiObject?): ()
	if not floatingController.IsAllowed(floatingController.PRIORITY.TOOLTIP, anchorFrame) then
		return
	end

	sequence += 1
	local mySeq = sequence
	clearPending()
	clearMoveListener()

	local function schedule(): ()
		clearPending()
		pendingShow = task.delay(SHOW_DELAY, function()
			pendingShow = nil
			if sequence ~= mySeq then
				return
			end
			if not floatingController.IsAllowed(floatingController.PRIORITY.TOOLTIP, anchorFrame) then
				return
			end
			info.bodySize = tipMetrics.measure(info.body, tipMetrics.BODY_TEXT_SIZE, tipMetrics.MAX_BODY_WIDTH)
			info.titleSize = tipMetrics.measure(info.title or "", tipMetrics.TITLE_TEXT_SIZE, tipMetrics.MAX_BODY_WIDTH)
			if sequence ~= mySeq then
				return
			end
			tooltipState.info(info)
			tooltipState.anchor(anchor)
			tooltipState.active(true)
			if not registered then
				registered = true
				floatingController.Register(TOOLTIP_ID, floatingController.PRIORITY.TOOLTIP, tooltipController.Hide)
			end
		end)
	end

	moveConn = UserInputService.InputChanged:Connect(LPH_NO_VIRTUALIZE(function(input: InputObject): ()
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		if sequence ~= mySeq then
			return
		end
		tooltipState.active(false)
		clearRegistration()
		schedule()
	end))

	schedule()
end

function tooltipController.UpdateAnchor(anchor: tooltipState.TipAnchor): ()
	tooltipState.anchor(anchor)
end

function tooltipController.Hide(): ()
	sequence += 1
	clearPending()
	clearMoveListener()
	clearRegistration()
	tooltipState.active(false)
end

Charm.subscribe(uiState.isOpen, function(open: boolean): ()
	if not open then
		tooltipController.Hide()
	end
end)

return tooltipController
