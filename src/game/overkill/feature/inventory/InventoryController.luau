local React = require("@pkg/React")

local OverkillInventoryPage = require("@game/overkill/feature/inventory/components/OverkillInventoryPage")

local e = React.createElement

local InventoryController = {}

function InventoryController.Attach(tab: any): ()
	if not tab or not tab.SetRenderer then
		return
	end
	tab:SetRenderer(function(_tab: any): React.Element<any>
		return e(OverkillInventoryPage, {})
	end)
end

return InventoryController
