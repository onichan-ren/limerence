local Charm = require("@pkg/Charm")
local UniversalEspElement = require("@game/universal/feature/visual/esp/EspElement")

local peek = Charm.peek
local sub = Charm.subscribe

export type EspCtx = UniversalEspElement.EspCtx
export type Bindable<T> = UniversalEspElement.Bindable<T>
export type EspElement<State, Settings> = UniversalEspElement.EspElement<State, Settings>
export type AnyEspElement = UniversalEspElement.AnyEspElement
export type HealthCache = UniversalEspElement.HealthCache
export type CharacterCache = UniversalEspElement.CharacterCache
export type SwitchFade = UniversalEspElement.SwitchFade

local EspElement = {}

EspElement.createBindable = UniversalEspElement.createBindable
EspElement.fadedTransparency = UniversalEspElement.fadedTransparency
EspElement.stepSwitchFade = UniversalEspElement.stepSwitchFade
EspElement.vector2ToUDim2Offset = UniversalEspElement.vector2ToUDim2Offset
EspElement.attachHealthCache = UniversalEspElement.attachHealthCache
EspElement.attachCharacterCache = UniversalEspElement.attachCharacterCache

export type WeaponCache = {
	_weaponName: string?,
	_playerUnsub: () -> (),
}

function EspElement.attachWeaponCache(basePlayer: any?, cache: WeaponCache): ()
	if not basePlayer then
		cache._weaponName = nil
		cache._playerUnsub = function() end
		return
	end

	local function sync(item: any): ()
		cache._weaponName = item and item.Name or nil
	end

	sync(peek(basePlayer.currentEquipped))
	cache._playerUnsub = sub(basePlayer.currentEquipped, sync)
end

return EspElement
