local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BasePlayer = require("@feature/player/BasePlayer")
local ModuleController = require("@game/op1/module/ModuleController")
local charObjectUtil = require("@game/op1/character/charObjectUtil")
local CharacterController = require("@game/op1/character/CharacterController")
local StateController = require("@game/op1/state/StateController")

local at = Charm.atom
local peek = Charm.peek

local PART_MAP = charObjectUtil.PART_MAP

local Util: any

local OWNERSHIP_ENEMY = 0
local STUN_DURATION = 5

local Op1Player = {}
Op1Player.__index = Op1Player

setmetatable(Op1Player, { __index = BasePlayer })

function Op1Player.new(player: Player): Op1Player
	local self = BasePlayer.new(player) :: any
	setmetatable(self, Op1Player)

	if not Util then
		Util = ModuleController.GetModule("Util")
	end

	self.parts = at({})
	self.character = at(nil)
	self.hrp = at(nil)
	self.humanoid = at(nil)
	self.object = at(nil)
	self.alive = at(false)
	self.health = at(0)
	self.maxHealth = at(100)
	self.team = at("")
	self.stance = at("stand")
	self.sprinting = at(false)
	self.aiming = at(false)
	self.spectating = at(false)
	self.planting = at(false)
	self._token = 0
	self._sightsToken = 0
	self.stunned = at(false)
	self._stunToken = 0

	self._janitor = Janitor.new()
	self._characterJanitor = self._janitor:Add(Janitor.new(), "Destroy")

	self._janitor:Add(
		player:GetAttributeChangedSignal("Team"):Connect(function()
			self:_updateTeam()
		end),
		"Disconnect"
	)

	self._janitor:Add(
		player:GetAttributeChangedSignal("Spectator"):Connect(function()
			self:_updateSpectating()
		end),
		"Disconnect"
	)

	self._janitor:Add(
		CharacterController.objectAdded:Connect(function(owner: Player, object: any)
			if owner == player then
				self:_onObjectAdded(object)
			end
		end),
		"Disconnect"
	)
	self._janitor:Add(
		CharacterController.objectRemoving:Connect(function(owner: Player, object: any)
			if owner == player and peek(self.object) == object then
				self:_onObjectRemoving()
			end
		end),
		"Disconnect"
	)

	self:_updateTeam()
	self:_updateSpectating()

	local existing = CharacterController.GetObject(player)
	if existing then
		self:_onObjectAdded(existing)
	end

	return self
end

function Op1Player._updateTeam(self: Op1Player): ()
	self.team(tostring(self._player:GetAttribute("Team") or ""))
end

function Op1Player._updateSpectating(self: Op1Player): ()
	self.spectating(self._player:GetAttribute("Spectator") == true)
end

function Op1Player._onObjectAdded(self: Op1Player, object: any): ()
	self._characterJanitor:Cleanup()
	self._token += 1
	local token = self._token

	task.spawn(function(): ()
		for _ = 1, 50 do
			if self._token ~= token then
				return
			end

			if object.values and object.values.rootpart and object.values.viewmodels then
				break
			end

			task.wait(0.1)
		end

		if self._token ~= token or not (object.values and object.values.rootpart) then
			return
		end

		self:_bind(object)
	end)
end

local function fillPart(current: { [string]: Instance }, part: Instance): ()
	current[part.Name] = part

	local mapped = PART_MAP[part.Name]
	if mapped then
		for i = 1, #mapped do
			current[mapped[i]] = part
		end
	end
end

function Op1Player._bind(self: Op1Player, object: any): ()
	local characterJanitor = self._characterJanitor
	local model = object.instance
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local viewmodels = object.values.viewmodels

	self.object(object)
	self.character(model)
	self.hrp(object.values.rootpart)
	self.humanoid(humanoid)

	if not viewmodels then
		self.parts({})
	else
		local initial: { [string]: Instance } = {}
		for _, part in next, viewmodels:GetChildren() do
			fillPart(initial, part)
		end
		self.parts(initial)

		characterJanitor:Add(
			viewmodels.ChildAdded:Connect(function(part: Instance): ()
				self:_onPartAdded(part)
			end),
			"Disconnect"
		)
		characterJanitor:Add(
			viewmodels.ChildRemoved:Connect(function(part: Instance): ()
				self:_onPartRemoved(part)
			end),
			"Disconnect"
		)
	end

	local function updateAlive(): ()
		self.alive(not (object.clean and object.clean:get()))
	end

	if humanoid then
		self.maxHealth(humanoid.MaxHealth)
		self.health(humanoid.Health)

		characterJanitor:Add(
			humanoid:GetPropertyChangedSignal("Health"):Connect(function(): ()
				self.health(humanoid.Health)
			end),
			"Disconnect"
		)
		characterJanitor:Add(
			humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function(): ()
				self.maxHealth(humanoid.MaxHealth)
			end),
			"Disconnect"
		)
	else
		self.health(peek(self.maxHealth))
	end

	if object.clean then
		characterJanitor:Add(object.clean:hook(updateAlive).unhook, true)
	end

	self:_bindStates(object)

	updateAlive()
	self:_updateTeam()
end

function Op1Player._bindStates(self: Op1Player, object: any): ()
	local characterJanitor = self._characterJanitor
	local states = object.states
	if not states then
		return
	end

	if states.walk_state then
		characterJanitor:Add(StateController.HookState(states.walk_state, function(value: any): ()
			self.stance(tostring(value))
		end), true)
	end

	if states.running then
		characterJanitor:Add(StateController.HookState(states.running, function(value: any): ()
			self.sprinting(value == true)
		end), true)
	end

	if states.equipped then
		local equipJanitor = characterJanitor:Add(Janitor.new(), "Destroy")
		characterJanitor:Add(StateController.HookState(states.equipped, function(): ()
			self:_rebindSights(object, equipJanitor)
		end), true)
	end

	if states.effect then
		characterJanitor:Add(StateController.HookState(states.effect, function(value: any, duration: any): ()
			if value ~= "flash" and value ~= "ringing" then
				return
			end
			self._stunToken += 1
			local token = self._stunToken
			self.stunned(true)
			local secs = tonumber(duration) or STUN_DURATION
			task.delay(secs, function(): ()
				if self._stunToken == token then
					self.stunned(false)
				end
			end)
		end), true)
	end
end

function Op1Player._rebindSights(self: Op1Player, object: any, equipJanitor: Janitor.Janitor): ()
	equipJanitor:Cleanup()
	self._sightsToken += 1
	local token = self._sightsToken
	local target = object.states.equipped:get()

	task.spawn(function(): ()
		for _ = 1, 30 do
			if self._sightsToken ~= token or peek(self.object) ~= object then
				return
			end

			local equipped = object.values and object.values.equipped

			if (equipped and equipped.instance or nil) == target then
				local sights = equipped and equipped.states and equipped.states.sights
				if sights then
					equipJanitor:Add(StateController.HookState(sights, function(value: any): ()
						if self._sightsToken == token then
							self.aiming(value == true)
						end
					end), true)
				else
					self.aiming(false)
				end
				return
			end

			self.aiming(false)
			task.wait(0.1)
		end
	end)
end

function Op1Player._onPartAdded(self: Op1Player, part: Instance): ()
	local current = table.clone(peek(self.parts))
	fillPart(current, part)
	self.parts(current)
end

function Op1Player._onPartRemoved(self: Op1Player, part: Instance): ()
	local current = table.clone(peek(self.parts))
	current[part.Name] = nil

	local mapped = PART_MAP[part.Name]
	if mapped then
		for _, name in next, mapped do
			current[name] = nil
		end
	end

	self.parts(current)
end

function Op1Player._onObjectRemoving(self: Op1Player): ()
	self._token += 1
	self._characterJanitor:Cleanup()
	self.object(nil)
	self.character(nil)
	self.hrp(nil)
	self.humanoid(nil)
	self.alive(false)
	self.health(0)
	self.parts({})
	self.stance("stand")
	self.sprinting(false)
	self.aiming(false)
	self.stunned(false)
	self._sightsToken += 1
	self._stunToken += 1
end

function Op1Player.IsEnemy(self: Op1Player): boolean
	if not Util then
		return true
	end

	setthreadidentity(2)
	local value = Util.ownership(self._player)
	setthreadidentity(8)

	return value == OWNERSHIP_ENEMY
end

function Op1Player.IsAlive(self: Op1Player): boolean
	return peek(self.alive)
end

function Op1Player.GetCharacter(self: Op1Player): Model?
	return peek(self.character)
end

function Op1Player.GetParts(self: Op1Player): { [string]: Instance }
	return peek(self.parts)
end

function Op1Player.GetVelocity(self: Op1Player): Vector3
	local hrp = peek(self.hrp)
	return hrp and hrp.AssemblyLinearVelocity or Vector3.zero
end

function Op1Player.Destroy(self: Op1Player): ()
	self._janitor:Destroy()
end

export type Op1Player =
	typeof(setmetatable(
		{} :: {
			_janitor: Janitor.Janitor,
			_characterJanitor: Janitor.Janitor,
			_token: number,
			_sightsToken: number,
			_stunToken: number,
			parts: Charm.Atom<{ [string]: Instance }>,
			character: Charm.Atom<Model?>,
			hrp: Charm.Atom<BasePart?>,
			humanoid: Charm.Atom<Humanoid?>,
			object: Charm.Atom<any>,
			alive: Charm.Atom<boolean>,
			health: Charm.Atom<number>,
			maxHealth: Charm.Atom<number>,
			team: Charm.Atom<string>,
			stance: Charm.Atom<string>,
			sprinting: Charm.Atom<boolean>,
			aiming: Charm.Atom<boolean>,
			spectating: Charm.Atom<boolean>,
			planting: Charm.Atom<boolean>,
			stunned: Charm.Atom<boolean>,
		},
		Op1Player
	))
	& BasePlayer.BasePlayer

return Op1Player
