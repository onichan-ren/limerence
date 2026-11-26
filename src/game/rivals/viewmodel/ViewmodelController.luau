local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local viewmodelState = require("@game/rivals/viewmodel/viewmodelState")

local peek = Charm.peek
local sub = Charm.subscribe

local ViewmodelController = {
	_janitor = Janitor.new() :: Janitor.Janitor,
}

local publish = LPH_NO_VIRTUALIZE(function(item: any): ()
	if item then
		viewmodelState._viewmodel(item.ViewModel)
	else
		viewmodelState._viewmodel(nil)
	end
end)

function ViewmodelController.new(): ViewmodelController
	ViewmodelController._janitor:Add(sub(WeaponController.item, publish))
	publish(peek(WeaponController.item))
	return ViewmodelController
end

function ViewmodelController.Destroy(): ()
	ViewmodelController._janitor:Destroy()
	viewmodelState._viewmodel(nil)
end

export type ViewmodelController = typeof(ViewmodelController) & {
	_janitor: Janitor.Janitor,
}

return ViewmodelController
