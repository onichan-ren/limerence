local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local BasePlayer = require("@feature/player/BasePlayer")
local Sift = require("@pkg/Sift")
local WeaponController = require("@game/mvsd/weapon/WeaponController")

local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe

type Character = Model & {
	HumanoidRootPart: BasePart,
	Humanoid: Humanoid,
}

local SPRINT_COOLDOWN = 17.5
local SOULREAP_COOLDOWN = 3

local function readTeam(player: Player): string
	local team = player.Team
	if team then
		return team.Name
	end
	return ""
end

local function classifyTool(tool: Tool?): string
	if not tool then
		return ""
	end
	if CollectionService:HasTag(tool, "GunTool") then
		return "gun"
	elseif CollectionService:HasTag(tool, "KnifeTool") then
		return "knife"
	elseif tool.Name == "ShroudTool" then
		return "shroud"
	end
	return ""
end

local MvsdPlayer = {}
MvsdPlayer.__index = MvsdPlayer

setmetatable(MvsdPlayer, { __index = BasePlayer })

function MvsdPlayer.new(player: Player): MvsdPlayer
	local self = BasePlayer.new(player) :: any
	setmetatable(self, MvsdPlayer)

	self.character = at(nil :: Character?)
	self.hrp = at(nil :: BasePart?)
	self.humanoid = at(nil :: Humanoid?)
	self.alive = at(false)
	self.health = at(0)
	self.maxHealth = at(100)
	self.parts = at({})
	self.team = at(readTeam(player))
	self.matchId = at(player:GetAttribute("Match"))
	self.isReloading = at(false)
	self.weapon = at("")
	self.shrouded = at(false)
	self.sprinting = at(false)
	self.invulnerable = at(false)
	self.cooldowns = at({} :: { [string]: { started: number, duration: number } })

	self._cdTokens = {} :: { [string]: number }
	self._currentTool = nil :: Tool?
	self._janitor = Janitor.new()
	self._characterJanitor = Janitor.new()
	self._janitor:Add(self._characterJanitor, "Destroy")

	self._janitor:Add(player.CharacterAdded:Connect(function(character: Model): ()
		self:_onCharacterAdded(character :: Character)
	end))

	self._janitor:Add(player.CharacterRemoving:Connect(function(): ()
		self:_onCharacterRemoving()
	end))

	self._janitor:Add(player:GetPropertyChangedSignal("Team"):Connect(function(): ()
		self.team(readTeam(player))
	end))

	self._janitor:Add(player:GetAttributeChangedSignal("Match"):Connect(function(): ()
		self.matchId(player:GetAttribute("Match"))
	end))

	local function watchTag(tag: string, source: any, target: any): ()
		self._janitor:Add(CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance): ()
			if instance == peek(source) then
				target(true)
			end
		end))
		self._janitor:Add(CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance: Instance): ()
			if instance == peek(source) then
				target(false)
			end
		end))
		self._janitor:Add(sub(source, function(instance: Instance?): ()
			target(instance ~= nil and CollectionService:HasTag(instance, tag))
		end))
		local instance = peek(source)
		target(instance ~= nil and CollectionService:HasTag(instance, tag))
	end

	watchTag("Shrouded", self.character, self.shrouded)
	watchTag("Invulnerable", self.character, self.invulnerable)
	watchTag("SpeedTrail", self.hrp, self.sprinting)

	local lastSprint = peek(self.sprinting)
	self._janitor:Add(sub(self.sprinting, function(active: boolean): ()
		if active and not lastSprint then
			self:StartAbilityCooldown("Sprint", SPRINT_COOLDOWN)
		end
		lastSprint = active
	end))

	local lastInvuln = peek(self.invulnerable)
	self._janitor:Add(sub(self.invulnerable, function(active: boolean): ()
		if active and not lastInvuln then
			self:StartAbilityCooldown("SoulReap", SOULREAP_COOLDOWN)
		end
		lastInvuln = active
	end))

	local reloadToken = 0
	self._janitor:Add(WeaponController.observedShot:Connect(LPH_NO_VIRTUALIZE(function(shooter: Player): ()
		if shooter ~= player then
			return
		end
		local character = peek(self.character)
		if not character then
			return
		end
		local tool = self._currentTool
		local cooldown = tool and tool:GetAttribute("Cooldown")
		if type(cooldown) ~= "number" then
			return
		end
		self.isReloading(true)
		reloadToken += 1
		local token = reloadToken
		task.delay(cooldown, function(): ()
			if token == reloadToken then
				self.isReloading(false)
			end
		end)
	end)), "Disconnect")

	if player.Character then
		task.spawn(function()
			self:_onCharacterAdded(player.Character :: Character)
		end)
	end

	return self
end

function MvsdPlayer._onCharacterAdded(self: MvsdPlayer, character: Character): ()
	self._characterJanitor:Cleanup()

	local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local humanoid = (character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)) :: Humanoid?

	if not hrp or not humanoid then
		return
	end

	if self._player.Character ~= character then
		return
	end

	local parts = {}
	local currentTool: Tool? = nil
	for _, child in next, character:GetChildren() do
		parts[child.Name] = child
		if not currentTool and child:IsA("Tool") then
			currentTool = child
		end
	end
	self.parts(parts)
	self._currentTool = currentTool
	self.weapon(classifyTool(currentTool))

	self.character(character)
	self.hrp(hrp)
	self.humanoid(humanoid)
	self.health(humanoid.Health)
	self.maxHealth(humanoid.MaxHealth)
	self.alive(humanoid.Health > 0)

	self._characterJanitor:Add(character.ChildAdded:Connect(function(part: Instance): ()
		self.parts(Sift.Dictionary.set(peek(self.parts), part.Name :: any, part))
		if part:IsA("Tool") then
			self._currentTool = part :: Tool
			self.weapon(classifyTool(part :: Tool))
		end
	end))

	self._characterJanitor:Add(character.ChildRemoved:Connect(function(part: Instance): ()
		self.parts(Sift.Dictionary.removeKey(peek(self.parts), part.Name :: any))
		if part == (self._currentTool :: Instance?) then
			self._currentTool = nil
		end
		if part:IsA("Tool") and classifyTool(part :: Tool) == peek(self.weapon) then
			self.weapon("")
		end
	end))

	self._characterJanitor:Add(humanoid.HealthChanged:Connect(function(health: number): ()
		self.health(health)
		self.alive(health > 0)
	end))

	self._characterJanitor:Add(humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function(): ()
		self.maxHealth(humanoid.MaxHealth)
	end))

	self._characterJanitor:Add(humanoid.Died:Connect(function(): ()
		self.alive(false)
	end))
end

function MvsdPlayer._onCharacterRemoving(self: MvsdPlayer): ()
	self._characterJanitor:Cleanup()
	self._currentTool = nil
	self.character(nil)
	self.hrp(nil)
	self.humanoid(nil)
	self.alive(false)
	self.parts({})
	self.weapon("")
	self.isReloading(false)
	self.cooldowns({})
end

function MvsdPlayer.StartAbilityCooldown(self: MvsdPlayer, id: string, duration: number): ()
	local now = os.clock()
	self.cooldowns(Sift.Dictionary.set(peek(self.cooldowns), id, { started = now, duration = duration }))

	local token = (self._cdTokens[id] or 0) + 1
	self._cdTokens[id] = token
	task.delay(duration, function(): ()
		if self._cdTokens[id] ~= token then
			return
		end
		self.cooldowns(Sift.Dictionary.removeKey(peek(self.cooldowns), id))
	end)
end

function MvsdPlayer.IsAlive(self: MvsdPlayer): boolean
	return peek(self.alive)
end

function MvsdPlayer.GetHealthFraction(self: MvsdPlayer): number
	local maxHealth = peek(self.maxHealth)
	if maxHealth <= 0 then
		return 0
	end
	return math.clamp(peek(self.health) / maxHealth, 0, 1)
end

function MvsdPlayer.GetTeam(self: MvsdPlayer): string
	return peek(self.team)
end

function MvsdPlayer.GetMatchId(self: MvsdPlayer): any
	return peek(self.matchId)
end

function MvsdPlayer.GetCharacter(self: MvsdPlayer): Character?
	return peek(self.character)
end

function MvsdPlayer.GetParts(self: MvsdPlayer): { [string]: Instance }
	return peek(self.parts)
end

function MvsdPlayer.Destroy(self: MvsdPlayer): ()
	self._janitor:Destroy()
end

export type MvsdPlayer =
	typeof(setmetatable(
		{} :: {
			_janitor: Janitor.Janitor,
			_characterJanitor: Janitor.Janitor,
			character: Charm.Atom<Character?>,
			hrp: Charm.Atom<BasePart?>,
			humanoid: Charm.Atom<Humanoid?>,
			alive: Charm.Atom<boolean>,
			health: Charm.Atom<number>,
			maxHealth: Charm.Atom<number>,
			parts: Charm.Atom<{ [string]: Instance }>,
			team: Charm.Atom<string>,
			matchId: Charm.Atom<any>,
			isReloading: Charm.Atom<boolean>,
			weapon: Charm.Atom<string>,
			shrouded: Charm.Atom<boolean>,
			sprinting: Charm.Atom<boolean>,
			invulnerable: Charm.Atom<boolean>,
			cooldowns: Charm.Atom<{ [string]: { started: number, duration: number } }>,
			_cdTokens: { [string]: number },
			_currentTool: Tool?,
			StartAbilityCooldown: (MvsdPlayer, string, number) -> (),
		},
		MvsdPlayer
	))
	& BasePlayer.BasePlayer

return MvsdPlayer
