local React = require("@pkg/React")

local RivalsInventoryPage = require("@game/rivals/feature/inventory/components/RivalsInventoryPage")

local e = React.createElement

local RivalsInventoryController = {}

function RivalsInventoryController.Attach(tab: any): ()
	if not tab or not tab.SetRenderer then
		return
	end
	tab:SetRenderer(function(_tab: any): React.Element<any>
		return e(RivalsInventoryPage, {})
	end)
end

return RivalsInventoryController
