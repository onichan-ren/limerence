local React = require("@pkg/React")

local PfInventoryPage = require("@game/pf/feature/inventory/components/PfInventoryPage")

local e = React.createElement

local InventoryController = {}

function InventoryController.Attach(tab: any): ()
	if not tab or not tab.SetRenderer then
		return
	end
	tab:SetRenderer(function(_tab: any): React.Element<any>
		return e(PfInventoryPage, {})
	end)
end

return InventoryController
