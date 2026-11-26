local Charm = require("@pkg/Charm")

export type ElementBindMode = "toggle" | "onHold" | "offHold"

export type ElementBind = {
	id: number,
	name: string,
	mode: Charm.Atom<ElementBindMode>,
	inputs: Charm.Atom<{ Enum.KeyCode | Enum.UserInputType }>,
	targetValue: Charm.Atom<any>,
	showInList: Charm.Atom<boolean>,
	active: Charm.Atom<boolean>,
	savedValue: Charm.Atom<any>,
}

export type BindListEntry = {
	element: any,
	label: string,
	bind: ElementBind,
}

return {}
