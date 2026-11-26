local React = require("@pkg/React")

local InventoryPage = require("@feature/inventory/components/InventoryPage")

local e = React.createElement

local InventoryController = {}

function InventoryController.Attach(tab: any): ()
	if not tab or not tab.SetRenderer then
		return
	end
	tab:SetRenderer(function(_tab: any): React.Element<any>
		return e(InventoryPage, {})
	end)
end

return InventoryController
