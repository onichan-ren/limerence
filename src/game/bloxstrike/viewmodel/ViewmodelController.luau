local clientState = require("@game/bloxstrike/client/clientState")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local viewmodelState = require("@game/bloxstrike/viewmodel/viewmodelState")
local localLookController = require("@game/bloxstrike/client/localLookController")
local originState = require("@game/universal/feature/visual/crosshair/originState")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local Camera = workspace.CurrentCamera

local Players = cloneref(game:GetService("Players")) :: Players
local LocalPlayer = Players.LocalPlayer

local peek = Charm.peek
local sub = Charm.subscribe

local ViewmodelController = {
	_janitor = Janitor.new() :: Janitor.Janitor,
	_muzzlePart = nil :: BasePart?,
	_muzzleL = nil :: BasePart?,
	_muzzleR = nil :: BasePart?,
}

function ViewmodelController.new(): ViewmodelController
	originState.SetMuzzleProvider(ViewmodelController.GetMuzzlePart)
	originState.SetForceCenterProvider(function(): boolean
		if localLookController.IsThirdPerson() then
			return false
		end
		local vm = peek(viewmodelState._viewmodel)
		if not vm or vm.Hidden ~= true then
			return false
		end
		return (LocalPlayer:GetAttribute("ScopeIncrement") or 0) > 0
	end)

	ViewmodelController._janitor:Add(Camera.DescendantAdded:Connect(LPH_NO_VIRTUALIZE(function(child: Instance)
		if child.ClassName ~= "Part" then
			return
		end
		local name = child.Name
		if name == "MuzzlePart" then
			ViewmodelController._muzzlePart = child :: BasePart
		elseif name == "MuzzlePartL" then
			ViewmodelController._muzzleL = child :: BasePart
		elseif name == "MuzzlePartR" then
			ViewmodelController._muzzleR = child :: BasePart
		end
	end)))

	ViewmodelController._janitor:Add(Camera.DescendantRemoving:Connect(LPH_NO_VIRTUALIZE(function(child: Instance)
		if child.ClassName ~= "Part" then
			return
		end
		local name = child.Name
		if name == "MuzzlePart" then
			ViewmodelController._muzzlePart = nil
		elseif name == "MuzzlePartL" then
			ViewmodelController._muzzleL = nil
		elseif name == "MuzzlePartR" then
			ViewmodelController._muzzleR = nil
		end
	end)))

	ViewmodelController._janitor:Add(sub(
		loadoutState.currentEquipped,
		LPH_NO_VIRTUALIZE(function(data)
			if data then
				local Viewmodel = data.Viewmodel
				viewmodelState._viewmodel(Viewmodel)
			else
				viewmodelState._viewmodel(nil)
			end
		end)
	))

	local equippedItemData = peek(loadoutState.currentEquipped)
	if equippedItemData then
		local Viewmodel = equippedItemData.Viewmodel
		viewmodelState._viewmodel(Viewmodel)
	end

	return ViewmodelController
end

function ViewmodelController.GetMuzzlePart(): BasePart?
	local weapon = peek(loadoutState.currentEquipped) :: any
	if weapon then
		local props = weapon.Properties
		if props and props.ShootingOptions == "Dual" then
			if weapon.ShootingHand == "Left" then
				return ViewmodelController._muzzleL or ViewmodelController._muzzlePart
			end
			return ViewmodelController._muzzleR or ViewmodelController._muzzlePart
		end
	end
	return ViewmodelController._muzzlePart
end

function ViewmodelController.Destroy(): ()
	ViewmodelController._janitor:Destroy()
end

export type ViewmodelController = typeof(ViewmodelController) & {
	_janitor: Janitor.Janitor,
	_muzzlePart: BasePart?,
	_muzzleL: BasePart?,
	_muzzleR: BasePart?,
}
return ViewmodelController
