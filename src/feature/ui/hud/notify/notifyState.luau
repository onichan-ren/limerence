local Charm = require("@pkg/Charm")

local at = Charm.atom

export type Notification = {
	id: string,
	title: string,
	subtext: string?,
	icon: string?,
	progress: number?,
	showProgress: boolean,
	timer: boolean,
	duration: number?,
	removing: boolean,
	createdAt: number,
}

local notifyState = {
	notifications = at({} :: { Notification }) :: Charm.Atom<{ Notification }>,
	heights = at({} :: { [string]: number }) :: Charm.Atom<{ [string]: number }>,
}

export type NotifyState = typeof(notifyState)

return notifyState
