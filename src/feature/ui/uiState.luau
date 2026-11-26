local Charm = require("@pkg/Charm")

local at = Charm.atom

local uiState = {
    isOpen = at(false),
}

export type UIState = typeof(uiState)

return uiState