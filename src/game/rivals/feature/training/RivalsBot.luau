local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")

local at = Charm.atom
local peek = Charm.peek

local nextBotId = -1

local RivalsBot = {}
RivalsBot.__index = RivalsBot

local function collectParts(model: Model): { [string]: Instance }
	local parts: { [string]: Instance } = {}
	for _, child in next, model:GetChildren() do
		if child:IsA("BasePart") then
			parts[child.Name] = child
		end
	end
	return parts
end

function RivalsBot.new(model: Model): RivalsBot
	local self = setmetatable({}, RivalsBot) :: any

	self._model = model
	self.isBot = true

	local fakeName = model.Name
	self._fakePlayer = { UserId = nextBotId, Name = fakeName }
	nextBotId -= 1

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?

	self.character = at(model :: Model?)
	self.hrp = at(hrp)
	self.humanoid = at(humanoid)
	self.parts = at(collectParts(model))
	self.health = at(humanoid and humanoid.Health or 0)
	self.maxHealth = at(humanoid and humanoid.MaxHealth or 100)
	self.alive = at(humanoid ~= nil and humanoid.Health > 0)

	self.team = at("")
	self.environmentId = at("")
	self.currentEquipped = at(nil :: any)
	self.isInDuel = at(false)
	self.isSpectating = at(false)
	self.isHidden = at(false)
	self.isCrouching = at(false)
	self.isSliding = at(false)
	self.isFirstPerson = at(false)
	self.isFrozen = at(false)
	self.controls = at("")
	self.aimCFrame = at(CFrame.identity)
	self.items = at({} :: { string })
	self.velocity = at(Vector3.zero)
	self.level = at(0)
	self.winStreak = at(0)
	self.displayElo = at(0)
	self.isReloading = at(false)
	self.isBlind = at(false)
	self.isScoped = at(false)
	self.isBlocking = at(false)
	self.isDeflecting = at(false)
	self.isHealing = at(false)

	self._janitor = Janitor.new()

	if humanoid then
		self._janitor:Add(
			humanoid.HealthChanged:Connect(function(health: number): ()
				setthreadidentity(8)
				self.health(health)
				self.alive(health > 0)
			end),
			"Disconnect"
		)
		self._janitor:Add(
			humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function(): ()
				setthreadidentity(8)
				self.maxHealth(humanoid.MaxHealth)
			end),
			"Disconnect"
		)
		self._janitor:Add(
			humanoid.Died:Connect(function(): ()
				setthreadidentity(8)
				self.alive(false)
			end),
			"Disconnect"
		)
	end

	local function refreshParts(): ()
		self.parts(collectParts(model))
		local newHrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if newHrp ~= peek(self.hrp) then
			self.hrp(newHrp)
		end
	end
	self._janitor:Add(model.ChildAdded:Connect(refreshParts), "Disconnect")
	self._janitor:Add(model.ChildRemoved:Connect(refreshParts), "Disconnect")

	return self
end

function RivalsBot.GetPlayer(self: RivalsBot): any
	return self._fakePlayer
end

function RivalsBot.IsAlive(self: RivalsBot): boolean
	return peek(self.alive)
end

function RivalsBot.GetHealthFraction(self: RivalsBot): number
	local maxHealth = peek(self.maxHealth)
	if maxHealth <= 0 then
		return 0
	end
	return math.clamp(peek(self.health) / maxHealth, 0, 1)
end

function RivalsBot.GetTeam(self: RivalsBot): string
	return peek(self.team)
end

function RivalsBot.GetCharacter(self: RivalsBot): Model?
	return peek(self.character)
end

function RivalsBot.GetParts(self: RivalsBot): { [string]: Instance }
	return peek(self.parts)
end

function RivalsBot.GetModel(self: RivalsBot): Model
	return self._model
end

function RivalsBot.Destroy(self: RivalsBot): ()
	self._janitor:Destroy()
end

export type RivalsBot = typeof(setmetatable(
	{} :: {
		_model: Model,
		_fakePlayer: any,
		_janitor: Janitor.Janitor,
		isBot: boolean,
		character: Charm.Atom<Model?>,
		hrp: Charm.Atom<BasePart?>,
		humanoid: Charm.Atom<Humanoid?>,
		parts: Charm.Atom<{ [string]: Instance }>,
		alive: Charm.Atom<boolean>,
		health: Charm.Atom<number>,
		maxHealth: Charm.Atom<number>,
		team: Charm.Atom<string>,
		environmentId: Charm.Atom<string>,
		currentEquipped: Charm.Atom<any>,
		isInDuel: Charm.Atom<boolean>,
		isSpectating: Charm.Atom<boolean>,
		isHidden: Charm.Atom<boolean>,
		isCrouching: Charm.Atom<boolean>,
		isSliding: Charm.Atom<boolean>,
		isFirstPerson: Charm.Atom<boolean>,
		isFrozen: Charm.Atom<boolean>,
		controls: Charm.Atom<string>,
		aimCFrame: Charm.Atom<CFrame>,
		items: Charm.Atom<{ string }>,
		velocity: Charm.Atom<Vector3>,
		level: Charm.Atom<number>,
		winStreak: Charm.Atom<number>,
		displayElo: Charm.Atom<number>,
		isReloading: Charm.Atom<boolean>,
		isBlind: Charm.Atom<boolean>,
		isScoped: Charm.Atom<boolean>,
		isBlocking: Charm.Atom<boolean>,
		isDeflecting: Charm.Atom<boolean>,
		isHealing: Charm.Atom<boolean>,
	},
	RivalsBot
))

return RivalsBot
