local Charm = require("@pkg/Charm")
local ModuleController = require("@game/op1/module/ModuleController")
local clientState = require("@game/op1/client/clientState")
local hook = require("@share/hook")

local peek = Charm.peek

local bulletRedirection = {}

local _active = false
local _chance = 100
local _target: any

local _gun: any

local function aimPosition(): Vector3?
	local target = _target

	if not target then
		return nil
	end

	local part = target.part
	if part and part.Parent then
		return part.Position
	end

	return target.position
end

local function ensureHook(): ()
	if not _gun then
		_gun = ModuleController.GetModule("Gun")
	end

	if not _gun then
		return
	end

	local oldLook
	oldLook = hook.add(_gun.get_shoot_look, function(self: any)
		if _active and _target and self.owner == peek(clientState.charObject) then
			if _chance >= 100 or math.random(1, 100) <= _chance then
				local position = aimPosition()
				if position then
					return CFrame.lookAt(self.shot.CFrame.Position, position)
				end
			end
		end

		return oldLook(self)
	end)
end

local function restoreHook(): ()
	if _gun then
		hook.restore(_gun.get_shoot_look)
	end
end

function bulletRedirection.setActive(state: boolean): ()
	if _active == state then
		return
	end

	_active = state

	if state then
		ensureHook()
	else
		_target = nil
		restoreHook()
	end
end

function bulletRedirection.setChance(chance: number): ()
	_chance = math.clamp(chance, 0, 100)
end

function bulletRedirection.setTarget(target: any): ()
	_target = target
end

return bulletRedirection
