local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")

local NoSwimLimits = {}
NoSwimLimits.__index = NoSwimLimits

setmetatable(NoSwimLimits, { __index = BaseFeature })

local WRAPPED_ACTIONS = { "UseItem", "Aim", "AtEase", "Crouch", "Shove" }
local SWIM_REPLACEMENT: { [string]: string } = {
	Swimming = "Walking",
	SprintSwimming = "Running",
}

local function isSwimming(moveState: any): boolean
	return moveState == "Swimming" or moveState == "SprintSwimming"
end

local function isEnteringWater(character: any): boolean
	local groundPart = character.GroundPart
	return groundPart ~= nil and groundPart:HasTag("Swim Surface")
end

local function callDeswum(character: any, original: any, ...): ...any
	local moveState = character.MoveState
	if not isSwimming(moveState) then
		return original(character, ...)
	end

	local spoof = SWIM_REPLACEMENT[moveState] or "Walking"
	character.MoveState = spoof

	local results = table.pack(original(character, ...))

	if character.MoveState == spoof then
		character.MoveState = moveState
	end

	return table.unpack(results, 1, results.n)
end

function NoSwimLimits.new(link: gameUi.Linker): NoSwimLimits
	local self = BaseFeature.new() :: any
	setmetatable(self, NoSwimLimits)

	self._enabled = false
	self._character = nil :: any
	self._originalActions = nil :: { [string]: any }?
	self._hasUnequipShadow = false
	self._hasEquipShadow = false
	self._hasSignalShadow = false
	self._charConn = nil :: RBXScriptConnection?

	link:Toggle("noSwimLimits", "No Swim Limits", false):SetTip({
		title = "No Swim Limits",
		body = "Lets you shoot, aim and use items while swimming.",
	})

	self:Track(link:Get("noSwimLimits"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("noSwimLimits") then
		self:Enable()
	end

	return self
end

function NoSwimLimits.Enable(self: NoSwimLimits): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local playersModule = ModuleController.GetModule("LocalPlayer")
	if not playersModule then
		return
	end

	local arLocalPlayer = playersModule.module.get()

	self._charConn = arLocalPlayer.CharacterAdded:Connect(function(character: any): ()
		self:_apply(character)
	end)

	if arLocalPlayer.Character then
		self:_apply(arLocalPlayer.Character)
	end
end

function NoSwimLimits.Disable(self: NoSwimLimits): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._charConn then
		self._charConn:Disconnect()
		self._charConn = nil
	end

	self:_restoreCharacter()
end

function NoSwimLimits._apply(self: NoSwimLimits, character: any): ()
	if not character or not character.Actions then
		return
	end

	self:_restoreCharacter()
	self._character = character

	local originals: { [string]: any } = {}
	for _, name in next, WRAPPED_ACTIONS do
		local original = character.Actions[name]
		if type(original) == "function" then
			originals[name] = original
			character.Actions[name] = function(actionSelf: any, ...): ...any
				if not self._enabled then
					return original(actionSelf, ...)
				end
				return callDeswum(actionSelf, original, ...)
			end
		end
	end
	self._originalActions = originals

	local realUnequip = character.Unequip
	if type(realUnequip) == "function" then
		character.Unequip = function(unequipSelf: any, ...): ...any
			if self._enabled and (isSwimming(unequipSelf.MoveState) or isEnteringWater(unequipSelf)) then
				return
			end
			return realUnequip(unequipSelf, ...)
		end
		self._hasUnequipShadow = true
	end

	local realEquip = character.Equip
	if type(realEquip) == "function" then
		character.Equip = function(equipSelf: any, ...): ...any
			if not self._enabled then
				return realEquip(equipSelf, ...)
			end
			return callDeswum(equipSelf, realEquip, ...)
		end
		self._hasEquipShadow = true
	end

	local signal = character.MoveStateChanged
	local realFire = signal and signal.Fire
	if type(realFire) == "function" then
		signal.Fire = function(signalSelf: any, newState: any, ...): ...any
			if self._enabled and isSwimming(newState) then
				return
			end
			return realFire(signalSelf, newState, ...)
		end
		self._hasSignalShadow = true
	end
end

function NoSwimLimits._restoreCharacter(self: NoSwimLimits): ()
	local character = self._character
	if not character then
		return
	end

	if self._originalActions and character.Actions then
		for name, original in next, self._originalActions do
			character.Actions[name] = original
		end
	end

	if self._hasUnequipShadow then
		character.Unequip = nil
	end

	if self._hasEquipShadow then
		character.Equip = nil
	end

	if self._hasSignalShadow then
		local signal = character.MoveStateChanged
		if signal then
			signal.Fire = nil
		end
	end

	self._originalActions = nil
	self._hasUnequipShadow = false
	self._hasEquipShadow = false
	self._hasSignalShadow = false
	self._character = nil
end

function NoSwimLimits.Destroy(self: NoSwimLimits): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type NoSwimLimits =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_character: any,
			_originalActions: { [string]: any }?,
			_hasUnequipShadow: boolean,
			_hasEquipShadow: boolean,
			_hasSignalShadow: boolean,
			_charConn: RBXScriptConnection?,
		},
		NoSwimLimits
	))
	& BaseFeature.BaseFeature

return NoSwimLimits
