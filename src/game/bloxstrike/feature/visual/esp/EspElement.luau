local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage

local Charm = require("@pkg/Charm")
local UniversalEspElement = require("@game/universal/feature/visual/esp/EspElement")

local peek = Charm.peek
local sub = Charm.subscribe

local weaponAmmoLimitsCache: { [string]: { maxRounds: number, muzzleType: string? } } = {}
local weaponIconCache: { [string]: string | false } = {}

export type EspCtx = UniversalEspElement.EspCtx
export type Bindable<T> = UniversalEspElement.Bindable<T>
export type EspElement<State, Settings> = UniversalEspElement.EspElement<State, Settings>
export type AnyEspElement = UniversalEspElement.AnyEspElement
export type HealthCache = UniversalEspElement.HealthCache
export type CharacterCache = UniversalEspElement.CharacterCache

local EspElement = {}

EspElement.createBindable = UniversalEspElement.createBindable
EspElement.fadedTransparency = UniversalEspElement.fadedTransparency
EspElement.vector2ToUDim2Offset = UniversalEspElement.vector2ToUDim2Offset
EspElement.attachHealthCache = UniversalEspElement.attachHealthCache
EspElement.attachCharacterCache = UniversalEspElement.attachCharacterCache

local SWITCH_FADE_DURATION = 0.09

export type SwitchFade = {
	_switchKey: string?,
	_switchAlpha: number,
}

function EspElement.stepSwitchFade(state: SwitchFade, liveKey: string?, dt: number, animate: boolean): (number, boolean)
	if not animate or dt <= 0 then
		state._switchKey = liveKey
		state._switchAlpha = 1
		return 1, false
	end

	local step = dt / SWITCH_FADE_DURATION

	if state._switchKey == nil then
		state._switchKey = liveKey
		state._switchAlpha = math.min(state._switchAlpha + step, 1)
		return state._switchAlpha, false
	end

	if liveKey ~= state._switchKey then
		local alpha = state._switchAlpha - step
		if alpha <= 0 then
			state._switchAlpha = 0
			state._switchKey = liveKey
			return 0, true
		end
		state._switchAlpha = alpha
		return alpha, true
	end

	state._switchAlpha = math.min(state._switchAlpha + step, 1)
	return state._switchAlpha, false
end

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

	local sync = LPH_NO_VIRTUALIZE(function(item: any): ()
		cache._weaponName = item and item.Name or nil
	end)

	sync(peek(basePlayer.currentEquipped))
	cache._playerUnsub = sub(basePlayer.currentEquipped, sync)
end

local function resolveWeaponIcon(weaponName: string): string?
	local cached = weaponIconCache[weaponName]
	if cached ~= nil then
		return cached or nil
	end

	local defInst = ReplicatedStorage.Database.Custom.Weapons:FindFirstChild(weaponName)
	if not defInst then
		weaponIconCache[weaponName] = false
		return nil
	end

	setthreadidentity(2)
	local def = require(defInst)
	setthreadidentity(8)
	if type(def) ~= "table" then
		weaponIconCache[weaponName] = false
		return nil
	end

	local icon = (def :: any).Icon
	if type(icon) ~= "string" or icon == "" then
		weaponIconCache[weaponName] = false
		return nil
	end

	weaponIconCache[weaponName] = icon
	return icon
end

export type WeaponIconCache = {
	_weaponName: string?,
	_icon: string?,
	_playerUnsub: () -> (),
}

function EspElement.attachWeaponIconCache(basePlayer: any?, cache: WeaponIconCache): ()
	if not basePlayer then
		cache._weaponName = nil
		cache._icon = nil
		cache._playerUnsub = function() end
		return
	end

	local sync = LPH_NO_VIRTUALIZE(function(item: any): ()
		local name = item and item.Name or nil
		cache._weaponName = name
		cache._icon = name and resolveWeaponIcon(name) or nil
	end)

	sync(peek(basePlayer.currentEquipped))
	cache._playerUnsub = sub(basePlayer.currentEquipped, sync)
end

export type AmmoCache = {
	_showAmmo: boolean,
	_weaponName: string?,
	_rounds: number,
	_capacity: number,
	_maxRounds: number,
	_playerUnsub: () -> (),
}

local function resolveWeaponMaxRounds(weaponName: string): (number, boolean)
	local cached = weaponAmmoLimitsCache[weaponName]
	if cached then
		return cached.maxRounds, cached.maxRounds > 0
	end

	local defInst = ReplicatedStorage.Database.Custom.Weapons:FindFirstChild(weaponName)
	if not defInst then
		return 0, false
	end

	setthreadidentity(2)
	local def = require(defInst)
	setthreadidentity(8)
	if type(def) ~= "table" then
		return 0, false
	end

	if (def :: any).Class ~= "Weapon" or (def :: any).MuzzleType == "Zeus x27" then
		return 0, false
	end

	local maxRounds = (def :: any).Rounds
	if type(maxRounds) ~= "number" or maxRounds <= 0 then
		return 0, false
	end

	weaponAmmoLimitsCache[weaponName] = {
		maxRounds = maxRounds,
		muzzleType = (def :: any).MuzzleType,
	}
	return maxRounds, true
end

function EspElement.attachAmmoCache(basePlayer: any?, cache: AmmoCache): ()
	if not basePlayer then
		cache._showAmmo = false
		cache._weaponName = nil
		cache._rounds = 0
		cache._capacity = 0
		cache._maxRounds = 1
		cache._playerUnsub = function() end
		return
	end

	local sync = LPH_NO_VIRTUALIZE(function(item: any): ()
		if type(item) ~= "table" or type(item.Name) ~= "string" or item.Name == "" then
			cache._showAmmo = false
			cache._weaponName = nil
			cache._rounds = 0
			cache._capacity = 0
			return
		end

		local maxRounds, show = resolveWeaponMaxRounds(item.Name)
		if not show then
			cache._showAmmo = false
			cache._weaponName = nil
			cache._rounds = 0
			cache._capacity = 0
			return
		end

		cache._showAmmo = true
		cache._weaponName = item.Name
		cache._maxRounds = maxRounds
		cache._rounds = (type(item.Rounds) == "number" and math.max(item.Rounds, 0) or 0)
		cache._capacity = (type(item.Capacity) == "number" and math.max(item.Capacity, 0) or 0)
	end)

	sync(peek(basePlayer.currentEquipped))
	cache._playerUnsub = sub(basePlayer.currentEquipped, sync)
end

return EspElement
