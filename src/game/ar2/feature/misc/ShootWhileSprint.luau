local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local StateReport = require("@game/ar2/network/stateReport")

local ShootWhileSprint = {}
ShootWhileSprint.__index = ShootWhileSprint

setmetatable(ShootWhileSprint, { __index = BaseFeature })

function ShootWhileSprint.new(link: gameUi.Linker): ShootWhileSprint
	local self = BaseFeature.new() :: any
	setmetatable(self, ShootWhileSprint)

	self._enabled = false
	self._character = nil :: any
	self._originalUseItem = nil :: any
	self._charConn = nil :: RBXScriptConnection?

	self._spoofer = function(overrides: { [number]: any }): ()
		if not self._enabled then
			return
		end
		local character = self._character
		if not character or character.RunningInput ~= true or not character.UseItemInput then
			return
		end
		overrides[StateReport.Field.RunningInput] = false
	end

	link:Toggle("shootWhileSprint", "Shoot While Sprinting", false):SetTip({
		title = "Shoot While Sprinting",
		body = "Keep sprinting while you fire.",
	})

	self:Track(link:Get("shootWhileSprint"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("shootWhileSprint") then
		self:Enable()
	end

	return self
end

function ShootWhileSprint.Enable(self: ShootWhileSprint): ()
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
		self:_apply(character)
	end)

	if arLocalPlayer.Character then
		self:_apply(arLocalPlayer.Character)
	end
end

function ShootWhileSprint.Disable(self: ShootWhileSprint): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	StateReport.unregister(self._spoofer)

	if self._charConn then
		self._charConn:Disconnect()
		self._charConn = nil
	end

	self:_restoreCharacter()
end

function ShootWhileSprint._apply(self: ShootWhileSprint, character: any): ()
	if not character or not character.Actions then
		return
	end

	self:_restoreCharacter()
	self._character = character

	local original = character.Actions.UseItem
	if type(original) ~= "function" then
		return
	end

	self._originalUseItem = original
	character.Actions.UseItem = function(actionSelf: any, ...): ...any
		local wasRunning = actionSelf.RunningInput == true
		local results = table.pack(original(actionSelf, ...))
		if self._enabled and wasRunning then
			actionSelf.RunningInput = true
		end
		return table.unpack(results, 1, results.n)
	end
end

function ShootWhileSprint._restoreCharacter(self: ShootWhileSprint): ()
	local character = self._character
	if not character then
		return
	end

	if self._originalUseItem and character.Actions then
		character.Actions.UseItem = self._originalUseItem
	end

	self._originalUseItem = nil
	self._character = nil
end

function ShootWhileSprint.Destroy(self: ShootWhileSprint): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type ShootWhileSprint =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_character: any,
			_originalUseItem: any,
			_charConn: RBXScriptConnection?,
			_spoofer: (overrides: { [number]: any }) -> (),
		},
		ShootWhileSprint
	))
	& BaseFeature.BaseFeature

return ShootWhileSprint
