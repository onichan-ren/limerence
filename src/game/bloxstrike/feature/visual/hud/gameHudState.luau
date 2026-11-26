local Charm = require("@pkg/Charm")

local at = Charm.atom

export type ColorSnapshot = {
	color: Color3,
	transparency: number,
}

export type HudSlot = {
	key: number,
	name: string,
	icon: string,
	active: boolean,
}

export type KillTag = {
	icon: string,
	wide: boolean?,
}

export type KillEntry = {
	id: number,
	killerName: string,
	killerEnemy: boolean,
	killerLocal: boolean,
	assistName: string?,
	assistEnemy: boolean,
	assistLocal: boolean,
	victimName: string,
	victimEnemy: boolean,
	victimLocal: boolean,
	tags: { KillTag },
	dead: boolean,
}

local function colorAt(r: number, g: number, b: number, transparency: number): Charm.Atom<ColorSnapshot>
	return at({
		color = Color3.fromRGB(r, g, b),
		transparency = transparency,
	})
end

local gameHudState = {
	enabled = at(false),

	health = at(0),
	maxHealth = at(100),

	weaponName = at(""),
	weaponIcon = at(""),
	isGun = at(false),
	rounds = at(0),
	capacity = at(0),
	magSize = at(0),

	slots = at({}) :: Charm.Atom<{ HudSlot }>,

	actionLabel = at(""),
	actionProgress = at(0),

	killFeedEnabled = at(false),
	kills = at({}) :: Charm.Atom<{ KillEntry }>,
	roundKills = at(0),
	pipIcon = at(""),
	money = at(0),

	colors = {
		accent = colorAt(225, 225, 225, 0),
		team = colorAt(135, 180, 235, 0),
		enemy = colorAt(220, 95, 95, 0),
		text = colorAt(229, 229, 229, 0),
		textSecondary = colorAt(150, 150, 150, 0),
		background = colorAt(24, 24, 24, 0.25),
		surface = colorAt(40, 40, 40, 0),
		border = colorAt(48, 48, 48, 0.5),
		shadow = colorAt(0, 0, 0, 0.55),
		killBackground = colorAt(24, 24, 24, 0.25),
		killStroke = colorAt(48, 48, 48, 0.5),
		killShadow = colorAt(0, 0, 0, 0.55),
		killIcon = colorAt(229, 229, 229, 0),
		teamLine = colorAt(225, 225, 225, 0),
		teamPip = colorAt(225, 225, 225, 0),
		teamLabel = colorAt(135, 180, 235, 0),
	},
}

export type GameHudState = typeof(gameHudState)

return gameHudState
