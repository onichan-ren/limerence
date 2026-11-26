local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")

local Window = require("@ui/window/Window")
local uiState = require("@ui/uiState")

local peek = Charm.peek
local at = Charm.atom

local WindowController = {
	windows = at({} :: { Window }),
}

function WindowController.Add(window: Window): Window
	local raw = peek(WindowController.windows)
	WindowController.windows(Sift.Array.insert(raw, #raw + 1, window))

	window:SetOpen(peek(uiState.isOpen))

	return window
end

function WindowController.SetAllOpen(open: boolean): ()
	for _, window in next, peek(WindowController.windows) do
		window:SetOpen(open)
	end
end

export type WindowController = typeof(WindowController)
export type Window = typeof(Window(""))

return WindowController
