local Charm = require("@pkg/Charm")

local at = Charm.atom

local dpiState = {
	scale = at(1) :: Charm.Atom<number>,
}

dpiState.OPTIONS = { 1, 1.25, 1.5, 1.75, 2 } :: { number }
dpiState.LABELS = { "100%", "125%", "150%", "175%", "200%" } :: { string }

dpiState.labelFor = LPH_NO_VIRTUALIZE(function(scale: number): string
	for index, option in next, dpiState.OPTIONS do
		if option == scale then
			return dpiState.LABELS[index]
		end
	end
	return "100%"
end)

dpiState.scaleFor = LPH_NO_VIRTUALIZE(function(label: string): number
	for index, value in next, dpiState.LABELS do
		if value == label then
			return dpiState.OPTIONS[index]
		end
	end
	return 1
end)

return dpiState
