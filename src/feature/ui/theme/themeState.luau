local Charm = require("@pkg/Charm")

local at = Charm.atom

local function number(value: number): Charm.Atom<number>
	return at(value)
end

local function rgba(r: number, g: number, b: number, alpha: number): Charm.Atom<{ any }>
	return at({
		Color3.fromRGB(r, g, b) :: any,
		alpha,
	})
end

local function rgb(r: number, g: number, b: number): Charm.Atom<Color3>
	return at(Color3.fromRGB(r, g, b))
end

local themeState = {
	colors = {
		canvas = {
			background = rgba(10, 10, 10, 0.4),
		},

		hud = {
			background = rgba(30, 30, 30, 0.2),
			backgroundSecondary = rgba(28, 28, 28, 0.4),
			bar = rgb(42, 42, 42),
			bombFlash = rgb(255, 64, 64),
			danger = rgb(220, 95, 95),
			good = rgb(120, 200, 130),
			image = rgb(177, 177, 177),
			neutral = rgb(200, 186, 160),
			shadow = rgba(0, 0, 0, 0.42),
			stroke = rgba(33, 33, 33, 0.5),
			text = rgb(178, 178, 178),
			textMuted = rgb(115, 115, 115),
			title = rgb(229, 229, 229),
			warning = rgb(220, 190, 110),
		},

		inventory = {
			cardBackground = rgb(26, 26, 26),
			cardBackgroundHover = rgb(32, 32, 32),
			cardImageBg = rgb(18, 18, 18),
			cardSkinName = rgb(228, 228, 228),
			cardWeaponName = rgb(130, 130, 130),
			tabIndicator = rgb(225, 225, 225),
			customWrap = rgb(150, 90, 255),

			rarity = {
				common = rgb(176, 195, 217),
				uncommon = rgb(75, 106, 255),
				restricted = rgb(136, 71, 255),
				classified = rgb(211, 44, 230),
				covert = rgb(235, 75, 75),
				extraordinary = rgb(255, 215, 0),
				master = rgb(228, 174, 57),
			},
		},

		notify = {
			background = rgba(30, 30, 30, 0.12),
			backgroundSecondary = rgba(28, 28, 28, 0.2),
			image = rgb(177, 177, 177),
			progress = rgb(229, 229, 229),
			shadow = rgba(0, 0, 0, 0.42),
			stroke = rgba(33, 33, 33, 0.5),
			text = rgb(178, 178, 178),
			title = rgb(229, 229, 229),
		},

		toast = {
			background = rgba(24, 24, 24, 0.08),
			stroke = rgba(48, 48, 48, 0.6),
			shadow = rgba(0, 0, 0, 0.45),
			text = rgb(196, 196, 196),
			accent = rgb(200, 186, 160),
			highlight = rgb(232, 214, 168),
		},

		status = {
			danger = rgb(220, 95, 95),
			good = rgb(120, 200, 130),
			neutral = rgb(160, 160, 160),
			placeholder = rgb(110, 110, 110),
			warning = rgb(220, 190, 110),
		},

		subwindow = {
			background = rgb(28, 28, 28),
			divider = rgb(40, 40, 40),
			image = rgb(140, 140, 140),
			stroke = rgb(44, 44, 44),
			text = rgb(200, 200, 200),
			title = rgb(228, 228, 228),
			tipIcon = rgb(228, 228, 228),
		},

		window = {
			background = rgb(22, 22, 22),
			divider = rgb(32, 32, 32),
			logo = rgb(150, 150, 150),
			searchMuted = rgb(108, 108, 108),
			shadow = rgba(8, 8, 8, 0.5),
			sidebar = rgb(18, 18, 18),
			stroke = rgb(38, 38, 38),
			tabHeading = rgb(108, 108, 108),
			tabIcon = rgb(176, 176, 176),
			tabLabel = rgb(176, 176, 176),
			tabLabelSelected = rgb(225, 225, 225),
			tabStroke = rgb(45, 45, 45),
			tabSurface = rgb(30, 30, 30),
			title = rgb(230, 230, 230),
			toolbar = rgb(20, 20, 20),

			section = {
				background = rgb(30, 30, 30),
				stroke = rgb(42, 42, 42),
				text = rgb(104, 104, 104),
			},

			element = {
				accent = rgb(70, 220, 176),
				accentSoft = rgb(20, 66, 54),
				accentStrong = rgb(116, 242, 204),
				caption = rgb(128, 128, 128),
				captionActive = rgb(156, 240, 208),
				fieldBackground = rgb(42, 42, 42),
				fieldBackgroundActive = rgb(56, 56, 56),
				fieldStroke = rgb(54, 54, 54),
				fieldStrokeActive = rgb(70, 220, 176),
				filterIcon = rgb(94, 94, 94),
				icon = rgb(140, 140, 140),
				iconActive = rgb(156, 240, 208),
				panel = rgb(26, 26, 26),
				panelStroke = rgb(42, 42, 42),
				rowHover = rgb(255, 255, 255),
				scrollThumb = rgb(44, 142, 112),
				surface = rgb(40, 40, 40),
				surfaceStroke = rgb(50, 50, 50),
				text = rgb(168, 168, 168),
				textActive = rgb(222, 222, 222),
				thumb = rgb(72, 148, 122),
				thumbActive = rgb(224, 255, 244),
				thumbHighlight = rgb(255, 255, 255),
				thumbStroke = rgb(22, 22, 22),
			},
		},
	},
	other = {
		animationSpeed = number(1),
		darkHoverTint = number(0.22),
		hoverTint = number(0.08),
	},
}

export type ThemeState = typeof(themeState)

return themeState
