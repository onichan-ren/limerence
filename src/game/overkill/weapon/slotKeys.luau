export type SlotKeys = {
	weaponID: string,
	magCount: string,
	reserveCount: string,
	mode: string,
	lastFireServerTime: string,
	reloadStartServerTime: string,
	lastAbilityServerTime: string,
	weakNextAllowedServerTime: string,
	strongNextAllowedServerTime: string,
}

local slotKeys: { SlotKeys } = table.create(4)
for i = 1, 4 do
	slotKeys[i] = {
		weaponID = `slot{i}_weaponID`,
		magCount = `slot{i}_magCount`,
		reserveCount = `slot{i}_reserveCount`,
		mode = `slot{i}_mode`,
		lastFireServerTime = `slot{i}_lastFireServerTime`,
		reloadStartServerTime = `slot{i}_reloadStartServerTime`,
		lastAbilityServerTime = `slot{i}_lastAbilityServerTime`,
		weakNextAllowedServerTime = `slot{i}_weakNextAllowedServerTime`,
		strongNextAllowedServerTime = `slot{i}_strongNextAllowedServerTime`,
	}
end

return slotKeys
