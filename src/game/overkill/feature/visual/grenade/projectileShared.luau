local FileController = require("@src/feature/file/FileController")
local gameUi = require("@game/gameUi")
local projectileRenderer = require("@game/universal/feature/visual/grenade/projectileRenderer")
local grenadeState = require("@game/overkill/grenade/grenadeState")

local DEFAULT_GRENADE_COLOR = Color3.fromRGB(195, 110, 110)
local DEFAULT_RPG_COLOR = Color3.fromRGB(225, 150, 90)
local DEFAULT_SATCHEL_COLOR = Color3.fromRGB(220, 190, 110)
local DEFAULT_BG_COLOR = Color3.fromRGB(28, 28, 28)

local ICON_BY_WEAPON: { [string]: string } = {
	grenade = "he_grenade",
	satchel = "c4",
}

local function resolveColorKey(entry: grenadeState.ProjectileEntry): string?
	return entry.weaponId
end

local function resolveDuration(entry: grenadeState.ProjectileEntry): (number?, number?)
	local detonateAt = entry.detonateAt
	if not detonateAt then
		return nil, nil
	end
	return detonateAt - entry.startedAt, detonateAt - os.clock()
end

local function resolveIcon(entry: grenadeState.ProjectileEntry): string?
	local specific = ICON_BY_WEAPON[entry.weaponId]
	if specific and FileController.Get("image", specific) then
		return specific
	end
	return "he_grenade"
end

export type ColorProps = {
	color: any,
	bgColor: any,
	colorByKey: { [string]: any },
}

local projectileShared = {}

function projectileShared.buildAdapter(
	shouldShow: (grenadeState.ProjectileEntry) -> boolean,
	resolvePosition: (grenadeState.ProjectileEntry) -> Vector3
): projectileRenderer.Adapter
	return {
		shouldShow = function(entry: grenadeState.ProjectileEntry): boolean
			return entry.weaponId ~= "raygun" and shouldShow(entry)
		end,
		resolvePosition = resolvePosition,
		resolveColorKey = resolveColorKey,
		resolveDuration = resolveDuration,
		resolveIcon = resolveIcon,
	}
end

function projectileShared.buildColorOptions(optsLink: gameUi.Linker): ColorProps
	optsLink:Colorpicker("bgColor", "Background Color", DEFAULT_BG_COLOR)
	optsLink:Colorpicker("grenadeColor", "Grenade", DEFAULT_GRENADE_COLOR)
	optsLink:Colorpicker("rpgColor", "RPG", DEFAULT_RPG_COLOR)
	optsLink:Colorpicker("satchelColor", "Satchel", DEFAULT_SATCHEL_COLOR)

	local grenadeColor = optsLink:Get("grenadeColor")._currentColor
	return {
		color = grenadeColor,
		bgColor = optsLink:Get("bgColor")._currentColor,
		colorByKey = {
			grenade = grenadeColor,
			rpg = optsLink:Get("rpgColor")._currentColor,
			satchel = optsLink:Get("satchelColor")._currentColor,
		},
	}
end

return projectileShared
