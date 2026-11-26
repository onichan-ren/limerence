local Charm = require("@pkg/Charm")

local at = Charm.atom

export type Mode = "inventory" | "weapon" | "skin"

local addSkinState = {
	mode = at("inventory" :: Mode),
	selectedWeapon = at(nil :: string?),
	configWeapon = at(nil :: string?),
	configSkin = at(nil :: string?),
	configOpen = at(false),
}

function addSkinState.openFlow(): ()
	addSkinState.mode("weapon")
	addSkinState.selectedWeapon(nil)
end

function addSkinState.selectWeapon(weapon: string): ()
	addSkinState.selectedWeapon(weapon)
	addSkinState.mode("skin")
end

function addSkinState.backToWeapons(): ()
	addSkinState.selectedWeapon(nil)
	addSkinState.mode("weapon")
end

function addSkinState.close(): ()
	addSkinState.selectedWeapon(nil)
	addSkinState.mode("inventory")
end

function addSkinState.openConfig(weapon: string, skin: string): ()
	addSkinState.configWeapon(weapon)
	addSkinState.configSkin(skin)
	addSkinState.configOpen(true)
end

function addSkinState.closeConfig(): ()
	addSkinState.configOpen(false)
end

return addSkinState
