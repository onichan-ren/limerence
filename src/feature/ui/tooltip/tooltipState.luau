local Charm = require("@pkg/Charm")

local at = Charm.atom

export type TipInfo = {
	title: string?,
	body: string,
	titleSize: Vector2?,
	bodySize: Vector2?,
}

export type TipAnchor = {
	position: Vector2,
	size: Vector2,
}

local tooltipState = {
	active = at(false) :: Charm.Atom<boolean>,
	info = at(nil :: TipInfo?) :: Charm.Atom<TipInfo?>,
	anchor = at(nil :: TipAnchor?) :: Charm.Atom<TipAnchor?>,
}

export type TooltipState = typeof(tooltipState)

return tooltipState
