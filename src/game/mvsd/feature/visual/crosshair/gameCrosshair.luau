local Players = cloneref(game:GetService("Players")) :: Players
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local Charm = require("@pkg/Charm")
local hook = require("@share/hook")
local uiState = require("@ui/uiState")

local peek = Charm.peek
local sub = Charm.subscribe

local mouse = Players.LocalPlayer:GetMouse()

local hidden = false
local menuOpen = false
local savedEnabled = true
local disconnect: (() -> ())? = nil

local function apply(): ()
	UserInputService.MouseIconEnabled = not hidden or menuOpen
end

local gameCrosshair = {}

function gameCrosshair.SetHidden(value: boolean): ()
	if value == hidden then
		return
	end
	hidden = value

	if value then
		savedEnabled = UserInputService.MouseIconEnabled
		menuOpen = peek(uiState.isOpen)

		hook.addInstance(mouse)
		hook.blockProperty(mouse, "Icon")
		hook.setProperty(mouse, "Icon", "")

		disconnect = sub(uiState.isOpen, function(open: boolean): ()
			menuOpen = open
			apply()
			task.defer(apply)
		end)
		apply()
		return
	end

	local stop = disconnect
	if stop then
		stop()
		disconnect = nil
	end

	hook.unblockProperty(mouse, "Icon")
	UserInputService.MouseIconEnabled = savedEnabled
end

function gameCrosshair.Destroy(): ()
	gameCrosshair.SetHidden(false)
end

return gameCrosshair
