local Charm = require("@pkg/Charm")

local placeableState = require("@game/rivals/placeable/placeableState")
local indicatorCore = require("@game/rivals/feature/visual/indicator/indicatorCore")

local peek = Charm.peek

local SELECTION_KEYS: { [string]: string } = {
	jumppad = "Jump Pad",
	tripmine = "Tripmine",
}

local function collectSources(): { [string]: indicatorCore.IndicatorSource }
	local sources: { [string]: indicatorCore.IndicatorSource } = {}

	for id, entry in next, peek(placeableState.activePlaceables) do
		sources[id] = {
			kind = entry.kind,
			selectionKey = SELECTION_KEYS[entry.kind],
			label = entry.label,
			startedAt = 0,
			duration = 0,
			static = true,
			friendly = entry.friendly,
			fallbackPosition = entry.position,
			projectilePart = nil,
			visualModel = entry.instance,
		}
	end

	return sources
end

return indicatorCore.create({
	feeds = { placeableState.activePlaceables },
	collect = collectSources,
	readColors = function(props: any): any
		return {
			friendly = props.friendlyColorLink._currentColor,
			enemy = props.enemyColorLink._currentColor,
			barColor = props.barColorLink._currentColor,
		}
	end,
	resolveColor = function(source: indicatorCore.IndicatorSource, colors: any): any
		return source.friendly and colors.friendly or colors.enemy
	end,
	resolveBarColor = function(colors: any): any
		return colors.barColor
	end,
})
