local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local EspState = require("@game/universal/feature/visual/esp/EspState")
local EspElement = require("@game/universal/feature/visual/esp/EspElement")

local e = React.createElement
local useAt = ReactCharm.useAtom
local vector2ToUDim2Offset = EspElement.vector2ToUDim2Offset

return LPH_NO_VIRTUALIZE(function(props: {
	state: EspState.EspState,
	settings: { [string]: any },
	elements: { EspElement.AnyEspElement },
	elementActive: Charm.Atom<{ [string]: boolean }>,
}): React.Element<any>
	local entries = useAt(props.state.entries)
	local elementActive = useAt(props.elementActive)
	local children = {}

	for player, entry in next, entries do
		local boxChildren: { [string]: any }? = nil
		for _, def in next, props.elements do
			if not def.render or not elementActive[def.id] then
				continue
			end
			local el = e(def.render, {
				state = entry[def.id],
				settings = props.settings[def.id],
				userId = player.UserId,
			})
			if def.container then
				if not boxChildren then
					boxChildren = {}
				end
				;(boxChildren :: any)[def.id] = el
			else
				children[`{def.id}_{player.UserId}`] = el
			end
		end
		if boxChildren then
			local container = entry.__box
			children[`espbox_{player.UserId}`] = e("Frame", {
				Position = container.position.binding:map(vector2ToUDim2Offset),
				Size = container.size.binding:map(vector2ToUDim2Offset),
				Visible = container.visible.binding,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, boxChildren)
		end
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, children)
end)
