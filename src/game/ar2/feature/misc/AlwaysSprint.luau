local RunService = cloneref(game:GetService("RunService")) :: RunService

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local StateReport = require("@game/ar2/network/stateReport")

local FORWARD = Vector3.new(0, 0, -1)

local AlwaysSprint = {}
AlwaysSprint.__index = AlwaysSprint

setmetatable(AlwaysSprint, { __index = BaseFeature })

function AlwaysSprint.new(link: gameUi.Linker): AlwaysSprint
	local self = BaseFeature.new() :: any
	setmetatable(self, AlwaysSprint)

	self._enabled = false
	self._character = nil :: any
	self._charConn = nil :: RBXScriptConnection?
	self._stepConn = nil :: RBXScriptConnection?
	self._touched = {} :: { [any]: boolean }

	self._spoofer = function(overrides: { [number]: any }): ()
		if not self._enabled then
			return
		end
		local mv = StateReport.get(StateReport.Field.MoveVector)
		if typeof(mv) == "Vector3" and mv.Magnitude > 0.01 and mv.Z > -0.707 then
			overrides[StateReport.Field.MoveVector] = FORWARD
		end
	end

	link:Toggle("alwaysSprint", "Always Sprint", false):SetTip({
		title = "Always Sprint",
		body = "Keep sprinting in any direction, even with a weapon out.",
	})

	self:Track(link:Get("alwaysSprint"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("alwaysSprint") then
		self:Enable()
	end

	return self
end

function AlwaysSprint.Enable(self: AlwaysSprint): ()
	if self._enabled then
		return
	end
	self._enabled = true

	StateReport.register(self._spoofer)

	local playersModule = ModuleController.GetModule("LocalPlayer")
	if not playersModule then
		return
	end

	local arLocalPlayer = playersModule.module.get()

	self._charConn = arLocalPlayer.CharacterAdded:Connect(function(character: any): ()
		self._character = character
	end)
	self._character = arLocalPlayer.Character

	self._stepConn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
		local character = self._character
		if not character then
			return
		end

		character.RunningInput = true

		local item = character.EquippedItem
		if item and item.CanTurnCharacter then
			self._touched[item] = true
			item.CanTurnCharacter = false
		end
	end))
end

function AlwaysSprint.Disable(self: AlwaysSprint): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	StateReport.unregister(self._spoofer)

	if self._stepConn then
		self._stepConn:Disconnect()
		self._stepConn = nil
	end

	if self._charConn then
		self._charConn:Disconnect()
		self._charConn = nil
	end

	for item in next, self._touched do
		item.CanTurnCharacter = true
	end
	table.clear(self._touched)

	local character = self._character
	if character then
		character.RunningInput = false
	end
	self._character = nil
end

function AlwaysSprint.Destroy(self: AlwaysSprint): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AlwaysSprint =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_character: any,
			_charConn: RBXScriptConnection?,
			_stepConn: RBXScriptConnection?,
			_touched: { [any]: boolean },
			_spoofer: (overrides: { [number]: any }) -> (),
		},
		AlwaysSprint
	))
	& BaseFeature.BaseFeature

return AlwaysSprint
