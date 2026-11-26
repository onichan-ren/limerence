local Charm = require("@pkg/Charm")

local at = Charm.atom

export type ToastIcon = {
	key: string,
	image: string,
	removing: boolean,
}

export type Toast = {
	id: string,
	text: string,
	icons: { ToastIcon }?,
	accent: Color3?,
	duration: number?,
	removing: boolean,
	createdAt: number,
}

export type ToastPosition = "top_left" | "top_right" | "bottom_center"

local POSITION_LABELS = { "Center Bottom", "Top Right", "Top Left" }

local LABEL_TO_POSITION: { [string]: ToastPosition } = {
	["Center Bottom"] = "bottom_center",
	["Top Right"] = "top_right",
	["Top Left"] = "top_left",
}

local POSITION_TO_LABEL: { [string]: string } = {}
for label, position in next, LABEL_TO_POSITION do
	POSITION_TO_LABEL[position] = label
end

local toastState = {
	toasts = at({} :: { Toast }) :: Charm.Atom<{ Toast }>,
	position = at("top_left" :: ToastPosition) :: Charm.Atom<ToastPosition>,

	POSITION_LABELS = POSITION_LABELS,
}

function toastState.labelFor(position: string): string
	return POSITION_TO_LABEL[position] or "Top Left"
end

function toastState.positionFor(label: string): ToastPosition
	return LABEL_TO_POSITION[label] or "top_left"
end

export type ToastState = typeof(toastState)

return toastState
