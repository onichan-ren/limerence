local Element = require("@ui/window/element/Element")

local registry = {} :: { [string]: (...any) -> Element.Element }

return registry
