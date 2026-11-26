local Charm = require("@pkg/Charm")

local grenadeState = require("@game/rivals/grenade/grenadeState")
local indicatorCore = require("@game/rivals/feature/visual/indicator/indicatorCore")

local peek = Charm.peek

local LABELS: { [string]: string } = {
	["Flashbang"] = "FLASHBANG",
	["Molotov"] = "MOLOTOV",
	["Smoke Grenade"] = "SMOKE GRENADE",
}

local function projectileToSource(entry: grenadeState.ProjectileEntry): indicatorCore.IndicatorSource?
	local kind: string?
	if entry.weapon == "Flashbang" then
		kind = "flash"
	elseif entry.weapon == "Molotov" then
		kind = "fire"
	elseif entry.weapon == "Smoke Grenade" then
		kind = "smoke"
	end
	if not kind then
		return nil
	end
	return {
		kind = kind,
		selectionKey = entry.weapon,
		label = LABELS[entry.weapon] or entry.weapon,
		startedAt = entry.startedAt,
		duration = math.max(0, entry.detonateAt - entry.startedAt),
		static = kind == "smoke",
		friendly = entry.isFriendly == true,
		fallbackPosition = entry.landingPosition,
		projectilePart = entry.projectilePart,
		visualModel = entry.visualModel,
	}
end

local function smokeToSource(smoke: grenadeState.SmokeEntry): indicatorCore.IndicatorSource?
	if not smoke.position or not smoke.startedAt or not smoke.duration then
		return nil
	end
	return {
		kind = "smoke",
		selectionKey = "Smoke Grenade",
		label = LABELS["Smoke Grenade"],
		startedAt = smoke.startedAt :: number,
		duration = smoke.duration :: number,
		static = false,
		friendly = smoke.isFriendly == true,
		fallbackPosition = smoke.position :: Vector3,
		projectilePart = nil,
		visualModel = smoke.model,
	}
end

local function collectSources(): { [string]: indicatorCore.IndicatorSource }
	local sources: { [string]: indicatorCore.IndicatorSource } = {}

	for id, entry in next, peek(grenadeState.activeProjectiles) do
		local source = projectileToSource(entry)
		if source then
			sources["proj:" .. id] = source
		end
	end

	for key, smoke in next, peek(grenadeState.activeSmokes) do
		local source = smokeToSource(smoke)
		if source then
			sources["smoke:" .. key] = source
		end
	end

	return sources
end

return indicatorCore.create({
	feeds = { grenadeState.activeProjectiles, grenadeState.activeSmokes },
	collect = collectSources,
	readColors = function(props: any): any
		return {
			enemyFlash = props.enemyFlashColorLink._currentColor,
			friendlyFlash = props.friendlyFlashColorLink._currentColor,
			enemySmoke = props.enemySmokeColorLink._currentColor,
			friendlySmoke = props.friendlySmokeColorLink._currentColor,
			barColor = props.barColorLink._currentColor,
		}
	end,
	resolveColor = function(source: indicatorCore.IndicatorSource, colors: any): any
		if source.kind == "flash" then
			return source.friendly and colors.friendlyFlash or colors.enemyFlash
		end
		return source.friendly and colors.friendlySmoke or colors.enemySmoke
	end,
	resolveBarColor = function(colors: any): any
		return colors.barColor
	end,
})
