local Charm = require("@pkg/Charm")

local at = Charm.atom

local hudState = {
	position = at(UDim2.fromOffset(20, 500)),
	showBindList = at(false),
	bindSortMode = at("activated" :: "activated" | "longestFrame" | "type"),
}

export type HudState = typeof(hudState)

return hudState
