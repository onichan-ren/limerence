local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local BasePlayer = require("@feature/player/BasePlayer")
local Sift = require("@pkg/Sift")
local universalAdapter = require("@game/universal/adapter/universalAdapter")

local at = Charm.atom
local peek = Charm.peek

type Character = Model & {
	HumanoidRootPart: BasePart,
	Humanoid: Humanoid,
}

local ROOT_PRIORITY = { "HumanoidRootPart", "Root", "Torso", "UpperTorso", "Head" }

local function readTeam(player: Player): string
	local resolver = universalAdapter.overrides.resolveTeam
	if resolver then
		local team = resolver(player)
		if team ~= nil then
			return team
		end
	end
	local team = player.Team
	if team then
		return team.Name
	end
	return ""
end

local function resolveRoot(character: Model, parts: { [string]: Instance }): BasePart?
	for i = 1, #ROOT_PRIORITY do
		local part = parts[ROOT_PRIORITY[i]]
		if part and part:IsA("BasePart") then
			return part
		end
	end
	local primary = character.PrimaryPart
	if primary then
		return primary
	end
	for _, part in next, parts do
		if part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local UniversalPlayer = {}
UniversalPlayer.__index = UniversalPlayer

setmetatable(UniversalPlayer, { __index = BasePlayer })

function UniversalPlayer.new(player: Player): UniversalPlayer
	local self = BasePlayer.new(player) :: any
	setmetatable(self, UniversalPlayer)

	self.character = at(nil :: Character?)
	self.hrp = at(nil :: BasePart?)
	self.humanoid = at(nil :: Humanoid?)
	self.alive = at(false)
	self.health = at(0)
	self.maxHealth = at(100)
	self.parts = at({})
	self.team = at(readTeam(player))

	self._janitor = Janitor.new()
	self._characterJanitor = Janitor.new()
	self._janitor:Add(self._characterJanitor, "Destroy")

	self._janitor:Add(player.CharacterAdded:Connect(function(character: Model): ()
		if universalAdapter.overrides.resolveCharacter then
			self:Refresh()
		else
			self:_onCharacterAdded(character :: Character)
		end
	end))

	self._janitor:Add(player.CharacterRemoving:Connect(function(): ()
		if universalAdapter.overrides.resolveCharacter then
			self:Refresh()
		else
			self:_onCharacterRemoving()
		end
	end))

	self._janitor:Add(player:GetPropertyChangedSignal("Team"):Connect(function(): ()
		self.team(readTeam(player))
	end))

	self._janitor:Add(
		universalAdapter.playersChanged:Connect(function(target: Player?): ()
			if target == nil or target == player then
				self:Refresh()
			end
		end),
		"Disconnect"
	)

	task.spawn(function()
		self:Refresh()
	end)

	return self
end

function UniversalPlayer.Refresh(self: UniversalPlayer): ()
	local player = self:GetPlayer()
	self.team(readTeam(player))

	local resolver = universalAdapter.overrides.resolveCharacter
	local character: Model?
	if resolver then
		character = resolver(player)
	else
		character = player.Character
	end

	if not character then
		self:_onCharacterRemoving()
		return
	end
	if character == peek(self.character) then
		self:_refreshState()
		return
	end
	self:_onCharacterAdded(character :: Character)
end

function UniversalPlayer._refreshState(self: UniversalPlayer): ()
	local player = self:GetPlayer()
	local overrides = universalAdapter.overrides

	local partsResolver = overrides.resolveParts
	if partsResolver then
		local character = peek(self.character)
		if character then
			local resolved = partsResolver(character, player)
			if resolved then
				self.parts(resolved)
				local hrp = resolveRoot(character, resolved)
				if hrp then
					self.hrp(hrp)
				end
			end
		end
	end

	local healthResolver = overrides.resolveHealth
	if healthResolver then
		local health, maxHealth = healthResolver(player)
		if health ~= nil then
			self.health(health)
		end
		if maxHealth ~= nil then
			self.maxHealth(maxHealth)
		end
	end

	local aliveResolver = overrides.resolveAlive
	if aliveResolver then
		local alive = aliveResolver(player)
		if alive ~= nil then
			self.alive(alive)
		elseif healthResolver then
			self.alive(peek(self.health) > 0)
		end
	elseif healthResolver then
		self.alive(peek(self.health) > 0)
	end
end

function UniversalPlayer._onCharacterAdded(self: UniversalPlayer, character: Character): ()
	self._characterJanitor:Cleanup()

	local token = {}
	self._characterToken = token

	local function tryInit(): boolean
		if self._characterToken ~= token then
			return true
		end
		local player = self:GetPlayer()

		local parts: { [string]: Instance }
		local partsResolver = universalAdapter.overrides.resolveParts
		if partsResolver then
			local resolved = partsResolver(character, player)
			if not resolved then
				return false
			end
			parts = resolved
		else
			parts = {}
			for _, child in next, character:GetChildren() do
				parts[child.Name] = child
			end
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local hrp = resolveRoot(character, parts)
		if not hrp then
			return false
		end
		if not humanoid and not universalAdapter.overrides.resolveCharacter then
			return false
		end
		self:_initCharacter(character, hrp, humanoid, parts)
		return true
	end

	if tryInit() then
		return
	end

	local conn: RBXScriptConnection
	conn = character.ChildAdded:Connect(function(): ()
		if tryInit() then
			conn:Disconnect()
		end
	end)
	self._characterJanitor:Add(conn)
end

function UniversalPlayer._initCharacter(
	self: UniversalPlayer,
	character: Character,
	hrp: BasePart,
	humanoid: Humanoid?,
	parts: { [string]: Instance }
): ()
	local player = self:GetPlayer()
	local overrides = universalAdapter.overrides

	self.parts(parts)
	self.character(character)
	self.hrp(hrp)
	self.humanoid(humanoid)

	local healthResolver = overrides.resolveHealth
	if healthResolver then
		local health, maxHealth = healthResolver(player)
		self.health(health or 0)
		self.maxHealth(maxHealth or 100)
	elseif humanoid then
		self.health(humanoid.Health)
		self.maxHealth(humanoid.MaxHealth)
	else
		self.health(100)
		self.maxHealth(100)
	end

	local aliveResolver = overrides.resolveAlive
	if aliveResolver then
		local alive = aliveResolver(player)
		if alive == nil then
			alive = peek(self.health) > 0
		end
		self.alive(alive)
	elseif humanoid then
		self.alive(humanoid.Health > 0)
	else
		self.alive(peek(self.health) > 0)
	end

	if not overrides.resolveParts then
		self._characterJanitor:Add(character.ChildAdded:Connect(function(part: Instance): ()
			self.parts(Sift.Dictionary.set(peek(self.parts), part.Name :: any, part))
		end))

		self._characterJanitor:Add(character.ChildRemoved:Connect(function(part: Instance): ()
			self.parts(Sift.Dictionary.removeKey(peek(self.parts), part.Name :: any))
		end))
	end

	if humanoid then
		self._characterJanitor:Add(humanoid.HealthChanged:Connect(function(health: number): ()
			if universalAdapter.overrides.resolveHealth then
				return
			end
			self.health(health)
			if not universalAdapter.overrides.resolveAlive then
				self.alive(health > 0)
			end
		end))

		self._characterJanitor:Add(humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function(): ()
			if universalAdapter.overrides.resolveHealth then
				return
			end
			self.maxHealth(humanoid.MaxHealth)
		end))

		self._characterJanitor:Add(humanoid.Died:Connect(function(): ()
			if universalAdapter.overrides.resolveAlive then
				return
			end
			self.alive(false)
		end))
	end

	if overrides.resolveCharacter then
		self._characterJanitor:Add(character.AncestryChanged:Connect(function(): ()
			if not character:IsDescendantOf(game) then
				self:Refresh()
			end
		end))
	end
end

function UniversalPlayer._onCharacterRemoving(self: UniversalPlayer): ()
	self._characterJanitor:Cleanup()
	self._characterToken = nil
	self.character(nil)
	self.hrp(nil)
	self.humanoid(nil)
	self.alive(false)
	self.parts({})
end

function UniversalPlayer.IsAlive(self: UniversalPlayer): boolean
	return peek(self.alive)
end

function UniversalPlayer.GetHealthFraction(self: UniversalPlayer): number
	local maxHealth = peek(self.maxHealth)
	if maxHealth <= 0 then
		return 0
	end
	return math.clamp(peek(self.health) / maxHealth, 0, 1)
end

function UniversalPlayer.GetTeam(self: UniversalPlayer): string
	return peek(self.team)
end

function UniversalPlayer.GetCharacter(self: UniversalPlayer): Character?
	return peek(self.character)
end

function UniversalPlayer.GetParts(self: UniversalPlayer): { [string]: Instance }
	return peek(self.parts)
end

function UniversalPlayer.Destroy(self: UniversalPlayer): ()
	self._janitor:Destroy()
end

export type UniversalPlayer =
	typeof(setmetatable(
		{} :: {
			_janitor: Janitor.Janitor,
			_characterJanitor: Janitor.Janitor,
			_characterToken: any,
			character: Charm.Atom<Character?>,
			hrp: Charm.Atom<BasePart?>,
			humanoid: Charm.Atom<Humanoid?>,
			alive: Charm.Atom<boolean>,
			health: Charm.Atom<number>,
			maxHealth: Charm.Atom<number>,
			parts: Charm.Atom<{ [string]: Instance }>,
			team: Charm.Atom<string>,
		},
		UniversalPlayer
	))
	& BasePlayer.BasePlayer

return UniversalPlayer
