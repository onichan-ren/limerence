local hook = require("@share/hook")
local ModuleController = require("@game/mvsd/module/ModuleController")

local bulletRedirection = {}

local _active = false
local _chance = 100
local _target: { position: Vector3?, player: any, part: BasePart? }? = nil
local _installed = false
local _weaponRaycast: any = nil
local _originalConvert: ((...any) -> any)? = nil

local _sourceCache: { [string]: boolean } = {}

local isGunCaller = LPH_NO_VIRTUALIZE(function(): boolean
	for level = 2, 24 do
		local source = debug.info(level, "s")
		if not source then
			break
		end
		local cached = _sourceCache[source]
		if cached == nil then
			cached = string.find(source, "GunController", 1, true) ~= nil
			_sourceCache[source] = cached
		end
		if cached then
			return true
		end
	end
	return false
end)

local function install(): ()
	if _installed then
		return
	end

	local module = ModuleController.GetModule("WeaponRaycast")
	if type(module) ~= "table" then
		return
	end

	local convert = rawget(module, "convertScreenPointToVector3")
	if type(convert) ~= "function" then
		return
	end

	_weaponRaycast = module

	local replacement = LPH_NO_VIRTUALIZE(function(...: any): any
		local original = _originalConvert :: any
		local current = _target
		if _active and current and current.position and not checkcaller() and isGunCaller() then
			local part = current.part
			if part and part.Parent and (_chance >= 100 or math.random(1, 100) <= _chance) then
				return current.position
			end
		end
		return original(...)
	end)

	_originalConvert = hook.add(convert, replacement)
	_installed = true
end

local function uninstall(): ()
	if not _installed then
		return
	end
	if _weaponRaycast then
		local convert = rawget(_weaponRaycast, "convertScreenPointToVector3")
		if type(convert) == "function" then
			hook.restore(convert)
		end
	end
	_weaponRaycast = nil
	_originalConvert = nil
	_installed = false
end

function bulletRedirection.setActive(state: boolean): ()
	if _active == state then
		return
	end

	_active = state
	if state then
		install()
	else
		_target = nil
		uninstall()
	end
end

function bulletRedirection.setTarget(newTarget: any?): ()
	_target = newTarget
	if _active and not _installed then
		install()
	end
end

function bulletRedirection.setChance(chance: number): ()
	_chance = math.clamp(chance, 0, 100)
end

return bulletRedirection
