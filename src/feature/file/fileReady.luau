local Charm = require("@pkg/Charm")

local fileReady = Charm.atom(0) :: Charm.Atom<number>

return fileReady
