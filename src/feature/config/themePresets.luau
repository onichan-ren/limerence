local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function rgba(r: number, g: number, b: number, alpha: number): { any }
	return { Color3.fromRGB(r, g, b) :: any, alpha }
end

local flatten
flatten = LPH_NO_VIRTUALIZE(function(prefix: string, tbl: any, out: { [string]: any }): { [string]: any }
	for key, value in next, tbl do
		local path = prefix == "" and key or `{prefix}.{key}`
		if typeof(value) == "Color3" then
			out[path] = value
		elseif type(value) == "table" then
			if value[1] ~= nil and typeof(value[1]) == "Color3" then
				out[path] = value
			else
				flatten(path, value, out)
			end
		end
	end
	return out
end)

local RARITY = {
	common = rgb(176, 195, 217),
	uncommon = rgb(94, 152, 217),
	restricted = rgb(136, 71, 255),
	classified = rgb(211, 44, 230),
	covert = rgb(235, 75, 75),
	extraordinary = rgb(245, 197, 24),
	master = rgb(228, 174, 57),
}

local DEFAULT = {
	canvas = {
		background = rgba(5, 8, 11, 0.42),
	},

	hud = {
		background = rgba(16, 21, 25, 0.22),
		backgroundSecondary = rgba(20, 26, 31, 0.42),
		bar = rgb(34, 43, 50),
		bombFlash = rgb(255, 64, 64),
		danger = rgb(238, 92, 106),
		good = rgb(54, 222, 168),
		image = rgb(166, 179, 188),
		neutral = rgb(70, 220, 176),
		shadow = rgba(0, 0, 0, 0.46),
		stroke = rgba(42, 53, 61, 0.52),
		text = rgb(184, 195, 202),
		textMuted = rgb(104, 118, 128),
		title = rgb(232, 240, 244),
		warning = rgb(235, 184, 92),
	},

	inventory = {
		cardBackground = rgb(19, 25, 30),
		cardBackgroundHover = rgb(27, 35, 41),
		cardImageBg = rgb(10, 14, 17),
		cardSkinName = rgb(232, 240, 244),
		cardWeaponName = rgb(124, 138, 148),
		tabIndicator = rgb(70, 220, 176),
		customWrap = rgb(159, 111, 255),

		rarity = RARITY,
	},

	notify = {
		background = rgba(13, 18, 22, 0.1),
		backgroundSecondary = rgba(35, 46, 54, 0.18),
		image = rgb(188, 199, 206),
		progress = rgb(70, 220, 176),
		shadow = rgba(0, 0, 0, 0.46),
		stroke = rgba(58, 74, 84, 0.25),
		text = rgb(188, 198, 204),
		title = rgb(235, 242, 246),
	},

	toast = {
		background = rgba(13, 18, 22, 0.08),
		stroke = rgba(44, 94, 82, 0.62),
		shadow = rgba(0, 0, 0, 0.48),
		text = rgb(196, 206, 212),
		accent = rgb(70, 220, 176),
		highlight = rgb(124, 246, 202),
	},

	status = {
		danger = rgb(238, 92, 106),
		good = rgb(54, 222, 168),
		neutral = rgb(148, 162, 172),
		placeholder = rgb(94, 108, 118),
		warning = rgb(235, 184, 92),
	},

	subwindow = {
		background = rgb(19, 25, 30),
		divider = rgb(34, 43, 50),
		image = rgb(136, 150, 160),
		stroke = rgb(39, 49, 57),
		text = rgb(202, 212, 218),
		title = rgb(232, 240, 244),
		tipIcon = rgb(54, 222, 168),
	},

	window = {
		background = rgb(13, 18, 22),
		divider = rgb(28, 36, 42),
		logo = rgb(70, 220, 176),
		searchMuted = rgb(100, 114, 124),
		shadow = rgba(3, 5, 7, 0.54),
		sidebar = rgb(9, 13, 16),
		stroke = rgb(34, 43, 50),
		tabHeading = rgb(100, 114, 124),
		tabIcon = rgb(166, 179, 188),
		tabLabel = rgb(166, 179, 188),
		tabLabelSelected = rgb(226, 255, 246),
		tabStroke = rgb(39, 49, 57),
		tabSurface = rgb(22, 29, 35),
		title = rgb(232, 240, 244),
		toolbar = rgb(11, 16, 20),

		section = {
			background = rgb(22, 29, 35),
			stroke = rgb(36, 46, 54),
			text = rgb(100, 114, 124),
		},

		element = {
			accent = rgb(46, 180, 142),
			accentSoft = rgb(18, 62, 50),
			accentStrong = rgb(70, 220, 176),
			caption = rgb(122, 136, 146),
			captionActive = rgb(140, 238, 204),
			fieldBackground = rgb(30, 38, 45),
			fieldBackgroundActive = rgb(39, 52, 59),
			fieldStroke = rgb(46, 58, 66),
			fieldStrokeActive = rgb(70, 220, 176),
			filterIcon = rgb(88, 102, 112),
			icon = rgb(136, 150, 160),
			iconActive = rgb(140, 238, 204),
			panel = rgb(19, 25, 30),
			panelStroke = rgb(36, 46, 54),
			rowHover = rgb(255, 255, 255),
			scrollThumb = rgb(44, 138, 108),
			surface = rgb(30, 38, 45),
			surfaceStroke = rgb(42, 53, 61),
			text = rgb(174, 186, 194),
			textActive = rgb(228, 236, 240),
			thumb = rgb(54, 148, 116),
			thumbActive = rgb(224, 255, 244),
			thumbHighlight = rgb(255, 255, 255),
			thumbStroke = rgb(10, 14, 17),
		},
	},
}

local GRUVBOX = {
	canvas = {
		background = rgba(20, 21, 21, 0.42),
	},

	hud = {
		background = rgba(40, 40, 40, 0.24),
		backgroundSecondary = rgba(50, 48, 45, 0.42),
		bar = rgb(80, 73, 69),
		bombFlash = rgb(251, 73, 52),
		danger = rgb(251, 73, 52),
		good = rgb(184, 187, 38),
		image = rgb(189, 174, 147),
		neutral = rgb(214, 153, 33),
		shadow = rgba(0, 0, 0, 0.5),
		stroke = rgba(80, 73, 69, 0.54),
		text = rgb(235, 219, 178),
		textMuted = rgb(146, 131, 116),
		title = rgb(251, 241, 199),
		warning = rgb(250, 189, 47),
	},

	inventory = {
		cardBackground = rgb(50, 48, 45),
		cardBackgroundHover = rgb(60, 56, 54),
		cardImageBg = rgb(40, 40, 40),
		cardSkinName = rgb(251, 241, 199),
		cardWeaponName = rgb(168, 153, 132),
		tabIndicator = rgb(254, 128, 25),
		customWrap = rgb(131, 165, 152),

		rarity = RARITY,
	},

	notify = {
		background = rgba(40, 40, 40, 0.1),
		backgroundSecondary = rgba(60, 56, 54, 0.18),
		image = rgb(213, 196, 161),
		progress = rgb(254, 128, 25),
		shadow = rgba(0, 0, 0, 0.5),
		stroke = rgba(80, 73, 69, 0.26),
		text = rgb(213, 196, 161),
		title = rgb(251, 241, 199),
	},

	toast = {
		background = rgba(40, 40, 40, 0.08),
		stroke = rgba(124, 111, 100, 0.6),
		shadow = rgba(0, 0, 0, 0.5),
		text = rgb(213, 196, 161),
		accent = rgb(254, 128, 25),
		highlight = rgb(250, 189, 47),
	},

	status = {
		danger = rgb(251, 73, 52),
		good = rgb(184, 187, 38),
		neutral = rgb(168, 153, 132),
		placeholder = rgb(124, 111, 100),
		warning = rgb(250, 189, 47),
	},

	subwindow = {
		background = rgb(50, 48, 45),
		divider = rgb(80, 73, 69),
		image = rgb(168, 153, 132),
		stroke = rgb(60, 56, 54),
		text = rgb(213, 196, 161),
		title = rgb(251, 241, 199),
		tipIcon = rgb(250, 189, 47),
	},

	window = {
		background = rgb(40, 40, 40),
		divider = rgb(60, 56, 54),
		logo = rgb(254, 128, 25),
		searchMuted = rgb(146, 131, 116),
		shadow = rgba(20, 20, 20, 0.56),
		sidebar = rgb(29, 32, 33),
		stroke = rgb(60, 56, 54),
		tabHeading = rgb(146, 131, 116),
		tabIcon = rgb(189, 174, 147),
		tabLabel = rgb(189, 174, 147),
		tabLabelSelected = rgb(251, 241, 199),
		tabStroke = rgb(70, 65, 61),
		tabSurface = rgb(50, 48, 45),
		title = rgb(251, 241, 199),
		toolbar = rgb(35, 35, 35),

		section = {
			background = rgb(50, 48, 45),
			stroke = rgb(70, 65, 61),
			text = rgb(146, 131, 116),
		},

		element = {
			accent = rgb(214, 93, 14),
			accentSoft = rgb(82, 45, 18),
			accentStrong = rgb(254, 128, 25),
			caption = rgb(146, 131, 116),
			captionActive = rgb(250, 189, 47),
			fieldBackground = rgb(60, 56, 54),
			fieldBackgroundActive = rgb(72, 67, 63),
			fieldStroke = rgb(80, 73, 69),
			fieldStrokeActive = rgb(254, 128, 25),
			filterIcon = rgb(124, 111, 100),
			icon = rgb(168, 153, 132),
			iconActive = rgb(250, 189, 47),
			panel = rgb(45, 44, 42),
			panelStroke = rgb(70, 65, 61),
			rowHover = rgb(255, 255, 255),
			scrollThumb = rgb(177, 98, 36),
			surface = rgb(60, 56, 54),
			surfaceStroke = rgb(80, 73, 69),
			text = rgb(213, 196, 161),
			textActive = rgb(251, 241, 199),
			thumb = rgb(174, 122, 55),
			thumbActive = rgb(251, 241, 199),
			thumbHighlight = rgb(255, 255, 255),
			thumbStroke = rgb(29, 32, 33),
		},
	},
}

local EVERFOREST = {
	canvas = {
		background = rgba(24, 29, 24, 0.42),
	},

	hud = {
		background = rgba(35, 42, 35, 0.22),
		backgroundSecondary = rgba(47, 56, 47, 0.42),
		bar = rgb(69, 82, 70),
		bombFlash = rgb(230, 80, 80),
		danger = rgb(230, 80, 80),
		good = rgb(167, 192, 128),
		image = rgb(126, 184, 171),
		neutral = rgb(230, 211, 142),
		shadow = rgba(0, 0, 0, 0.48),
		stroke = rgba(69, 82, 70, 0.52),
		text = rgb(211, 218, 189),
		textMuted = rgb(130, 146, 126),
		title = rgb(239, 242, 212),
		warning = rgb(230, 174, 92),
	},

	inventory = {
		cardBackground = rgb(39, 47, 39),
		cardBackgroundHover = rgb(51, 61, 51),
		cardImageBg = rgb(28, 34, 28),
		cardSkinName = rgb(239, 242, 212),
		cardWeaponName = rgb(138, 154, 134),
		tabIndicator = rgb(167, 192, 128),
		customWrap = rgb(126, 184, 171),

		rarity = RARITY,
	},

	notify = {
		background = rgba(35, 42, 35, 0.1),
		backgroundSecondary = rgba(55, 66, 55, 0.18),
		image = rgb(203, 209, 184),
		progress = rgb(167, 192, 128),
		shadow = rgba(0, 0, 0, 0.48),
		stroke = rgba(69, 82, 70, 0.25),
		text = rgb(205, 212, 187),
		title = rgb(239, 242, 212),
	},

	toast = {
		background = rgba(35, 42, 35, 0.08),
		stroke = rgba(89, 110, 82, 0.55),
		shadow = rgba(0, 0, 0, 0.5),
		text = rgb(211, 218, 189),
		accent = rgb(167, 192, 128),
		highlight = rgb(230, 211, 142),
	},

	status = {
		danger = rgb(230, 80, 80),
		good = rgb(167, 192, 128),
		neutral = rgb(150, 166, 146),
		placeholder = rgb(102, 116, 100),
		warning = rgb(230, 174, 92),
	},

	subwindow = {
		background = rgb(39, 47, 39),
		divider = rgb(69, 82, 70),
		image = rgb(150, 166, 146),
		stroke = rgb(55, 66, 55),
		text = rgb(211, 218, 189),
		title = rgb(239, 242, 212),
		tipIcon = rgb(167, 192, 128),
	},

	window = {
		background = rgb(31, 38, 31),
		divider = rgb(51, 61, 51),
		logo = rgb(167, 192, 128),
		searchMuted = rgb(112, 128, 110),
		shadow = rgba(12, 16, 12, 0.56),
		sidebar = rgb(25, 31, 25),
		stroke = rgb(55, 66, 55),
		tabHeading = rgb(112, 128, 110),
		tabIcon = rgb(196, 201, 176),
		tabLabel = rgb(196, 201, 176),
		tabLabelSelected = rgb(239, 242, 212),
		tabStroke = rgb(64, 76, 64),
		tabSurface = rgb(39, 47, 39),
		title = rgb(239, 242, 212),
		toolbar = rgb(28, 34, 28),

		section = {
			background = rgb(39, 47, 39),
			stroke = rgb(64, 76, 64),
			text = rgb(112, 128, 110),
		},

		element = {
			accent = rgb(126, 164, 104),
			accentSoft = rgb(42, 66, 43),
			accentStrong = rgb(184, 210, 132),
			caption = rgb(130, 146, 126),
			captionActive = rgb(218, 226, 168),
			fieldBackground = rgb(51, 61, 51),
			fieldBackgroundActive = rgb(63, 75, 63),
			fieldStroke = rgb(69, 82, 70),
			fieldStrokeActive = rgb(167, 192, 128),
			filterIcon = rgb(102, 116, 100),
			icon = rgb(150, 166, 146),
			iconActive = rgb(218, 226, 168),
			panel = rgb(39, 47, 39),
			panelStroke = rgb(64, 76, 64),
			rowHover = rgb(255, 255, 255),
			scrollThumb = rgb(106, 142, 92),
			surface = rgb(51, 61, 51),
			surfaceStroke = rgb(69, 82, 70),
			text = rgb(205, 212, 187),
			textActive = rgb(239, 242, 212),
			thumb = rgb(126, 158, 104),
			thumbActive = rgb(239, 242, 212),
			thumbHighlight = rgb(255, 255, 255),
			thumbStroke = rgb(25, 31, 25),
		},
	},
}

local KANAGAWA = {
	canvas = {
		background = rgba(15, 18, 24, 0.44),
	},

	hud = {
		background = rgba(27, 31, 38, 0.24),
		backgroundSecondary = rgba(36, 42, 52, 0.42),
		bar = rgb(54, 63, 75),
		bombFlash = rgb(230, 111, 111),
		danger = rgb(230, 111, 111),
		good = rgb(152, 187, 108),
		image = rgb(126, 156, 216),
		neutral = rgb(126, 156, 216),
		shadow = rgba(3, 5, 8, 0.56),
		stroke = rgba(54, 63, 75, 0.54),
		text = rgb(220, 215, 186),
		textMuted = rgb(128, 138, 152),
		title = rgb(246, 241, 210),
		warning = rgb(223, 168, 96),
	},

	inventory = {
		cardBackground = rgb(27, 31, 38),
		cardBackgroundHover = rgb(39, 46, 57),
		cardImageBg = rgb(15, 18, 24),
		cardSkinName = rgb(246, 241, 210),
		cardWeaponName = rgb(140, 146, 156),
		tabIndicator = rgb(126, 156, 216),
		customWrap = rgb(210, 126, 153),

		rarity = RARITY,
	},

	notify = {
		background = rgba(27, 31, 38, 0.1),
		backgroundSecondary = rgba(46, 54, 66, 0.18),
		image = rgb(126, 156, 216),
		progress = rgb(126, 156, 216),
		shadow = rgba(3, 5, 8, 0.56),
		stroke = rgba(54, 63, 75, 0.26),
		text = rgb(220, 215, 186),
		title = rgb(246, 241, 210),
	},

	toast = {
		background = rgba(27, 31, 38, 0.08),
		stroke = rgba(84, 101, 126, 0.62),
		shadow = rgba(3, 5, 8, 0.58),
		text = rgb(220, 215, 186),
		accent = rgb(126, 156, 216),
		highlight = rgb(223, 168, 96),
	},

	status = {
		danger = rgb(230, 111, 111),
		good = rgb(152, 187, 108),
		neutral = rgb(140, 150, 164),
		placeholder = rgb(92, 102, 116),
		warning = rgb(223, 168, 96),
	},

	subwindow = {
		background = rgb(27, 31, 38),
		divider = rgb(54, 63, 75),
		image = rgb(140, 150, 164),
		stroke = rgb(46, 54, 66),
		text = rgb(220, 215, 186),
		title = rgb(246, 241, 210),
		tipIcon = rgb(126, 156, 216),
	},

	window = {
		background = rgb(20, 23, 30),
		divider = rgb(39, 46, 57),
		logo = rgb(126, 156, 216),
		searchMuted = rgb(112, 122, 136),
		shadow = rgba(3, 5, 8, 0.58),
		sidebar = rgb(15, 18, 24),
		stroke = rgb(46, 54, 66),
		tabHeading = rgb(112, 122, 136),
		tabIcon = rgb(178, 186, 198),
		tabLabel = rgb(178, 186, 198),
		tabLabelSelected = rgb(246, 241, 210),
		tabStroke = rgb(54, 63, 75),
		tabSurface = rgb(27, 31, 38),
		title = rgb(246, 241, 210),
		toolbar = rgb(18, 21, 27),

		section = {
			background = rgb(27, 31, 38),
			stroke = rgb(54, 63, 75),
			text = rgb(112, 122, 136),
		},

		element = {
			accent = rgb(80, 122, 176),
			accentSoft = rgb(30, 48, 72),
			accentStrong = rgb(126, 156, 216),
			caption = rgb(132, 142, 156),
			captionActive = rgb(182, 200, 238),
			fieldBackground = rgb(39, 46, 57),
			fieldBackgroundActive = rgb(51, 60, 73),
			fieldStroke = rgb(54, 63, 75),
			fieldStrokeActive = rgb(126, 156, 216),
			filterIcon = rgb(98, 108, 122),
			icon = rgb(140, 150, 164),
			iconActive = rgb(182, 200, 238),
			panel = rgb(27, 31, 38),
			panelStroke = rgb(54, 63, 75),
			rowHover = rgb(255, 255, 255),
			scrollThumb = rgb(72, 108, 154),
			surface = rgb(39, 46, 57),
			surfaceStroke = rgb(54, 63, 75),
			text = rgb(220, 215, 186),
			textActive = rgb(246, 241, 210),
			thumb = rgb(86, 124, 170),
			thumbActive = rgb(246, 241, 210),
			thumbHighlight = rgb(255, 255, 255),
			thumbStroke = rgb(15, 18, 24),
		},
	},
}

local CATPPUCCIN_MOCHA = {
	canvas = {
		background = rgba(17, 17, 27, 0.44),
	},

	hud = {
		background = rgba(30, 30, 46, 0.24),
		backgroundSecondary = rgba(49, 50, 68, 0.42),
		bar = rgb(69, 71, 90),
		bombFlash = rgb(243, 139, 168),
		danger = rgb(243, 139, 168),
		good = rgb(166, 227, 161),
		image = rgb(137, 220, 235),
		neutral = rgb(245, 194, 231),
		shadow = rgba(6, 6, 12, 0.54),
		stroke = rgba(69, 71, 90, 0.54),
		text = rgb(205, 214, 244),
		textMuted = rgb(127, 132, 156),
		title = rgb(245, 246, 255),
		warning = rgb(249, 226, 175),
	},

	inventory = {
		cardBackground = rgb(30, 30, 46),
		cardBackgroundHover = rgb(49, 50, 68),
		cardImageBg = rgb(17, 17, 27),
		cardSkinName = rgb(245, 246, 255),
		cardWeaponName = rgb(147, 153, 178),
		tabIndicator = rgb(245, 194, 231),
		customWrap = rgb(250, 179, 135),

		rarity = RARITY,
	},

	notify = {
		background = rgba(30, 30, 46, 0.1),
		backgroundSecondary = rgba(49, 50, 68, 0.18),
		image = rgb(205, 214, 244),
		progress = rgb(245, 194, 231),
		shadow = rgba(6, 6, 12, 0.54),
		stroke = rgba(69, 71, 90, 0.26),
		text = rgb(205, 214, 244),
		title = rgb(245, 246, 255),
	},

	toast = {
		background = rgba(30, 30, 46, 0.08),
		stroke = rgba(108, 112, 134, 0.62),
		shadow = rgba(6, 6, 12, 0.56),
		text = rgb(205, 214, 244),
		accent = rgb(245, 194, 231),
		highlight = rgb(250, 179, 135),
	},

	status = {
		danger = rgb(243, 139, 168),
		good = rgb(166, 227, 161),
		neutral = rgb(166, 173, 200),
		placeholder = rgb(108, 112, 134),
		warning = rgb(249, 226, 175),
	},

	subwindow = {
		background = rgb(30, 30, 46),
		divider = rgb(69, 71, 90),
		image = rgb(166, 173, 200),
		stroke = rgb(49, 50, 68),
		text = rgb(205, 214, 244),
		title = rgb(245, 246, 255),
		tipIcon = rgb(245, 194, 231),
	},

	window = {
		background = rgb(24, 24, 37),
		divider = rgb(49, 50, 68),
		logo = rgb(245, 194, 231),
		searchMuted = rgb(127, 132, 156),
		shadow = rgba(6, 6, 12, 0.58),
		sidebar = rgb(17, 17, 27),
		stroke = rgb(49, 50, 68),
		tabHeading = rgb(127, 132, 156),
		tabIcon = rgb(186, 194, 222),
		tabLabel = rgb(186, 194, 222),
		tabLabelSelected = rgb(245, 246, 255),
		tabStroke = rgb(69, 71, 90),
		tabSurface = rgb(30, 30, 46),
		title = rgb(245, 246, 255),
		toolbar = rgb(20, 20, 31),

		section = {
			background = rgb(30, 30, 46),
			stroke = rgb(69, 71, 90),
			text = rgb(127, 132, 156),
		},

		element = {
			accent = rgb(220, 138, 202),
			accentSoft = rgb(76, 46, 78),
			accentStrong = rgb(245, 194, 231),
			caption = rgb(147, 153, 178),
			captionActive = rgb(249, 210, 244),
			fieldBackground = rgb(49, 50, 68),
			fieldBackgroundActive = rgb(60, 62, 82),
			fieldStroke = rgb(69, 71, 90),
			fieldStrokeActive = rgb(245, 194, 231),
			filterIcon = rgb(108, 112, 134),
			icon = rgb(166, 173, 200),
			iconActive = rgb(249, 210, 244),
			panel = rgb(30, 30, 46),
			panelStroke = rgb(69, 71, 90),
			rowHover = rgb(255, 255, 255),
			scrollThumb = rgb(178, 104, 176),
			surface = rgb(49, 50, 68),
			surfaceStroke = rgb(69, 71, 90),
			text = rgb(205, 214, 244),
			textActive = rgb(245, 246, 255),
			thumb = rgb(210, 132, 198),
			thumbActive = rgb(245, 246, 255),
			thumbHighlight = rgb(255, 255, 255),
			thumbStroke = rgb(17, 17, 27),
		},
	},
}

local OXOCARBON = {
	canvas = {
		background = rgba(10, 10, 12, 0.46),
	},

	hud = {
		background = rgba(22, 22, 26, 0.24),
		backgroundSecondary = rgba(34, 34, 40, 0.42),
		bar = rgb(57, 57, 66),
		bombFlash = rgb(255, 126, 182),
		danger = rgb(255, 126, 182),
		good = rgb(66, 190, 101),
		image = rgb(61, 219, 217),
		neutral = rgb(61, 219, 217),
		shadow = rgba(0, 0, 0, 0.6),
		stroke = rgba(57, 57, 66, 0.56),
		text = rgb(220, 220, 230),
		textMuted = rgb(118, 118, 132),
		title = rgb(245, 245, 250),
		warning = rgb(255, 200, 87),
	},

	inventory = {
		cardBackground = rgb(22, 22, 26),
		cardBackgroundHover = rgb(34, 34, 40),
		cardImageBg = rgb(12, 12, 15),
		cardSkinName = rgb(245, 245, 250),
		cardWeaponName = rgb(138, 138, 150),
		tabIndicator = rgb(61, 219, 217),
		customWrap = rgb(190, 149, 255),

		rarity = RARITY,
	},

	notify = {
		background = rgba(22, 22, 26, 0.1),
		backgroundSecondary = rgba(40, 40, 48, 0.18),
		image = rgb(206, 206, 216),
		progress = rgb(61, 219, 217),
		shadow = rgba(0, 0, 0, 0.6),
		stroke = rgba(57, 57, 66, 0.28),
		text = rgb(214, 214, 224),
		title = rgb(245, 245, 250),
	},

	toast = {
		background = rgba(22, 22, 26, 0.08),
		stroke = rgba(82, 82, 96, 0.62),
		shadow = rgba(0, 0, 0, 0.62),
		text = rgb(220, 220, 230),
		accent = rgb(61, 219, 217),
		highlight = rgb(190, 149, 255),
	},

	status = {
		danger = rgb(255, 126, 182),
		good = rgb(66, 190, 101),
		neutral = rgb(160, 160, 174),
		placeholder = rgb(94, 94, 108),
		warning = rgb(255, 200, 87),
	},

	subwindow = {
		background = rgb(22, 22, 26),
		divider = rgb(57, 57, 66),
		image = rgb(160, 160, 174),
		stroke = rgb(40, 40, 48),
		text = rgb(220, 220, 230),
		title = rgb(245, 245, 250),
		tipIcon = rgb(61, 219, 217),
	},

	window = {
		background = rgb(16, 16, 20),
		divider = rgb(34, 34, 40),
		logo = rgb(61, 219, 217),
		searchMuted = rgb(112, 112, 126),
		shadow = rgba(0, 0, 0, 0.62),
		sidebar = rgb(10, 10, 12),
		stroke = rgb(40, 40, 48),
		tabHeading = rgb(112, 112, 126),
		tabIcon = rgb(190, 190, 202),
		tabLabel = rgb(190, 190, 202),
		tabLabelSelected = rgb(245, 245, 250),
		tabStroke = rgb(50, 50, 58),
		tabSurface = rgb(22, 22, 26),
		title = rgb(245, 245, 250),
		toolbar = rgb(13, 13, 16),

		section = {
			background = rgb(22, 22, 26),
			stroke = rgb(50, 50, 58),
			text = rgb(112, 112, 126),
		},

		element = {
			accent = rgb(25, 180, 178),
			accentSoft = rgb(20, 65, 70),
			accentStrong = rgb(61, 219, 217),
			caption = rgb(138, 138, 150),
			captionActive = rgb(145, 240, 238),
			fieldBackground = rgb(34, 34, 40),
			fieldBackgroundActive = rgb(46, 46, 54),
			fieldStroke = rgb(57, 57, 66),
			fieldStrokeActive = rgb(61, 219, 217),
			filterIcon = rgb(94, 94, 108),
			icon = rgb(160, 160, 174),
			iconActive = rgb(145, 240, 238),
			panel = rgb(22, 22, 26),
			panelStroke = rgb(50, 50, 58),
			rowHover = rgb(255, 255, 255),
			scrollThumb = rgb(28, 132, 136),
			surface = rgb(34, 34, 40),
			surfaceStroke = rgb(57, 57, 66),
			text = rgb(214, 214, 224),
			textActive = rgb(245, 245, 250),
			thumb = rgb(42, 162, 166),
			thumbActive = rgb(230, 255, 255),
			thumbHighlight = rgb(255, 255, 255),
			thumbStroke = rgb(10, 10, 12),
		},
	},
}

local themePresets = {}

themePresets.NAMES = { "Default", "Gruvbox", "Everforest", "Kanagawa", "Catppuccin Mocha", "Oxocarbon" }

themePresets.SNAPSHOTS = {
	Default = flatten("", DEFAULT, {}),
	Gruvbox = flatten("", GRUVBOX, {}),
	Everforest = flatten("", EVERFOREST, {}),
	Kanagawa = flatten("", KANAGAWA, {}),
	["Catppuccin Mocha"] = flatten("", CATPPUCCIN_MOCHA, {}),
	Oxocarbon = flatten("", OXOCARBON, {}),
}

function themePresets.IsBuiltin(name: string): boolean
	return themePresets.SNAPSHOTS[name] ~= nil
end

function themePresets.GetSnapshot(name: string): { [string]: any }?
	return themePresets.SNAPSHOTS[name]
end

return themePresets
