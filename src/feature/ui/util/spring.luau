export type SpringPreset = {
	tension: number,
	friction: number,
	precision: number?,
	mass: number?,
}

local SPRING: { [string]: SpringPreset } = {
	snap = {
		tension = 1700,
		friction = 84,
		precision = 0.01,
	},
	snapPrecise = {
		tension = 1400,
		friction = 84,
		precision = 0.08,
	},
	quick = {
		tension = 950,
		friction = 63,
		precision = 0.01,
	},
	quickPrecise = {
		tension = 1000,
		friction = 65,
		precision = 0.015,
	},
	smooth = {
		tension = 1000,
		friction = 65,
		precision = 0.005,
	},
	smoothPrecise = {
		tension = 1350,
		friction = 75,
		precision = 0.01,
	},
	smoothPreciser = {
		tension = 1350,
		friction = 74,
		precision = 0.09,
	},
	subtle = {
		tension = 650,
		friction = 55,
	},
	progress = {
		tension = 320,
		friction = 42,
	},
}

return SPRING
