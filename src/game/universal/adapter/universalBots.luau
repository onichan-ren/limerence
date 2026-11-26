return LPH_JIT_MAX(function()
	local Charm = require("@pkg/Charm")
	local Janitor = require("@pkg/Janitor")
	local Signal = require("@pkg/Signal")
	
	local at = Charm.atom
	local peek = Charm.peek
	
	local nextBotId = -1
	
	local UniversalBot = {}
	UniversalBot.__index = UniversalBot
	
	local function collectParts(model: Model): { [string]: Instance }
		local parts: { [string]: Instance } = {}
		for _, child in next, model:GetChildren() do
			if child:IsA("BasePart") then
				parts[child.Name] = child
			end
		end
		return parts
	end
	
	export type BotOpts = {
		name: string?,
		team: string?,
		health: number?,
		maxHealth: number?,
	}
	
	function UniversalBot.new(model: Model, opts: BotOpts?): UniversalBot
		local self = setmetatable({}, UniversalBot) :: any
	
		self._model = model
		self.isBot = true
	
		local name = (opts and opts.name) or model.Name
		self._fakePlayer = { UserId = nextBotId, Name = name, DisplayName = name }
		nextBotId -= 1
	
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	
		local health = (opts and opts.health) or (humanoid and humanoid.Health) or 100
		local maxHealth = (opts and opts.maxHealth) or (humanoid and humanoid.MaxHealth) or 100
	
		self._manualHealth = (opts and opts.health) ~= nil
	
		self.character = at(model :: Model?)
		self.hrp = at(hrp)
		self.humanoid = at(humanoid)
		self.parts = at(collectParts(model))
		self.health = at(health)
		self.maxHealth = at(maxHealth)
		self.alive = at(health > 0)
		self.team = at((opts and opts.team) or "")
	
		self._janitor = Janitor.new()
	
		if humanoid then
			self._janitor:Add(
				humanoid.HealthChanged:Connect(function(hp: number): ()
					if self._manualHealth then
						return
					end
					self.health(hp)
					self.alive(hp > 0)
				end),
				"Disconnect"
			)
			self._janitor:Add(
				humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function(): ()
					if self._manualHealth then
						return
					end
					self.maxHealth(humanoid.MaxHealth)
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
	
	function UniversalBot.GetPlayer(self: UniversalBot): any
		return self._fakePlayer
	end
	
	function UniversalBot.IsAlive(self: UniversalBot): boolean
		return peek(self.alive)
	end
	
	function UniversalBot.GetHealthFraction(self: UniversalBot): number
		local maxHealth = peek(self.maxHealth)
		if maxHealth <= 0 then
			return 0
		end
		return math.clamp(peek(self.health) / maxHealth, 0, 1)
	end
	
	function UniversalBot.GetTeam(self: UniversalBot): string
		return peek(self.team)
	end
	
	function UniversalBot.GetCharacter(self: UniversalBot): Model?
		return peek(self.character)
	end
	
	function UniversalBot.GetParts(self: UniversalBot): { [string]: Instance }
		return peek(self.parts)
	end
	
	function UniversalBot.GetModel(self: UniversalBot): Model
		return self._model
	end
	
	function UniversalBot.SetHealth(self: UniversalBot, health: number, maxHealth: number?): ()
		self._manualHealth = true
		self.health(health)
		if maxHealth ~= nil then
			self.maxHealth(maxHealth)
		end
		self.alive(health > 0)
	end
	
	function UniversalBot.SetTeam(self: UniversalBot, team: string): ()
		self.team(team)
	end
	
	function UniversalBot.SetAlive(self: UniversalBot, alive: boolean): ()
		self.alive(alive)
	end
	
	function UniversalBot.Destroy(self: UniversalBot): ()
		self._janitor:Destroy()
	end
	
	export type UniversalBot = typeof(setmetatable(
		{} :: {
			_model: Model,
			_fakePlayer: any,
			_janitor: Janitor.Janitor,
			_manualHealth: boolean,
			isBot: boolean,
			character: Charm.Atom<Model?>,
			hrp: Charm.Atom<BasePart?>,
			humanoid: Charm.Atom<Humanoid?>,
			parts: Charm.Atom<{ [string]: Instance }>,
			health: Charm.Atom<number>,
			maxHealth: Charm.Atom<number>,
			alive: Charm.Atom<boolean>,
			team: Charm.Atom<string>,
		},
		UniversalBot
	))
	
	local universalBots = {
		added = Signal.new() :: Signal.Signal<UniversalBot>,
		removed = Signal.new() :: Signal.Signal<UniversalBot>,
	
		_bots = {} :: { [Model]: UniversalBot },
		_watchConns = {} :: { [Model]: RBXScriptConnection },
	}
	
	function universalBots.GetAll(): { [Model]: UniversalBot }
		return universalBots._bots
	end
	
	function universalBots.Get(model: Model): UniversalBot?
		return universalBots._bots[model]
	end
	
	function universalBots.Remove(model: Model): ()
		local bot = universalBots._bots[model]
		if not bot then
			return
		end
		local conn = universalBots._watchConns[model]
		if conn then
			conn:Disconnect()
			universalBots._watchConns[model] = nil
		end
		universalBots._bots[model] = nil
		universalBots.removed:Fire(bot)
		bot:Destroy()
	end
	
	function universalBots.Add(model: Model, opts: BotOpts?): UniversalBot
		local existing = universalBots._bots[model]
		if existing then
			return existing
		end
		local bot = UniversalBot.new(model, opts)
		universalBots._bots[model] = bot
		universalBots._watchConns[model] = model.AncestryChanged:Connect(function(): ()
			if not model:IsDescendantOf(game) then
				universalBots.Remove(model)
			end
		end)
		universalBots.added:Fire(bot)
		return bot
	end
	
	function universalBots.Clear(): ()
		for model in next, universalBots._bots do
			universalBots.Remove(model)
		end
	end
	
	export type universalBots = typeof(universalBots)
	
	return universalBots	
end)()