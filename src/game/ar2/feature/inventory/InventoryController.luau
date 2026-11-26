local React = require("@pkg/React")

local Ar2InventoryPage = require("@game/ar2/feature/inventory/components/Ar2InventoryPage")

local e = React.createElement

local InventoryController = {}

function InventoryController.Attach(tab: any): ()
	if not tab or not tab.SetRenderer then
		return
	end
	tab:SetRenderer(function(_tab: any): React.Element<any>
		return e(Ar2InventoryPage, {})
	end)
end

return InventoryController
