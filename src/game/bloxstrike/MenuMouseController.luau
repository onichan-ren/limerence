local Players = cloneref(game:GetService("Players")) :: Players
local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local uiState = require("@ui/uiState")

local sub = Charm.subscribe
local peek = Charm.peek

local LocalPlayer = Players.LocalPlayer
local Mouse = cloneref(LocalPlayer:GetMouse()) :: Mouse

local MenuMouseController = {
	_connection = nil :: RBXScriptConnection?,
	_unsubscribe = nil :: (() -> ())?,
}

local function apply(open: boolean): ()
	local conn = MenuMouseController._connection
	if conn then
		conn:Disconnect()
		MenuMouseController._connection = nil
	end
	if not open then
		return
	end
	MenuMouseController._connection = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
		Mouse.Icon = ""
	end))
end

function MenuMouseController.new(): MenuMouseController
	MenuMouseController._unsubscribe = sub(uiState.isOpen, apply)
	apply(peek(uiState.isOpen))
	return MenuMouseController
end

function MenuMouseController.Destroy(): ()
	local unsub = MenuMouseController._unsubscribe
	if unsub then
		unsub()
		MenuMouseController._unsubscribe = nil
	end
	local conn = MenuMouseController._connection
	if conn then
		conn:Disconnect()
		MenuMouseController._connection = nil
	end
end

export type MenuMouseController = typeof(MenuMouseController)

return MenuMouseController
