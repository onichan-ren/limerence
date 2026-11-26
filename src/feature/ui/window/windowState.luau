local Charm = require("@pkg/Charm")

local at = Charm.atom

local windowState = {
	openTab = at(nil),
	searchQuery = at(""),
}

export type WindowState = typeof(windowState)

return windowState
