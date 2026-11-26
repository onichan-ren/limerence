return LPH_JIT_MAX(function()
	local Charm = require("@pkg/Charm")
	local Janitor = require("@pkg/Janitor")
	local BasePlayer = require("@feature/player/BasePlayer")
	local Sift = require("@pkg/Sift")
	local NetworkController = require("@game/overkill/network/NetworkController")

	local at = Charm.atom
	local peek = Charm.peek

	type Character = Model & {
		HumanoidRootPart: BasePart,
		Humanoid: Humanoid,
	}

	local OverkillPlayer = {}
	OverkillPlayer.__index = OverkillPlayer

	setmetatable(OverkillPlayer, { __index = BasePlayer })

	function OverkillPlayer.new(player: Player): OverkillPlayer
		local self = BasePlayer.new(player) :: any
		setmetatable(self, OverkillPlayer)

		self.character = at(nil :: Character?)
		self.hrp = at(nil :: BasePart?)
		self.humanoid = at(nil :: Humanoid?)
		self.alive = at(false)
		self.health = at(0)
		self.maxHealth = at(100)
		self.parts = at({})
		self.team = at("")
		self.matchId = at(nil :: any)
		self.weaponId = at("")
		self.weaponName = at("")
		self.weaponIcon = at("")
		self.ammo = at(0)
		self.ammoReserve = at(0)
		self.magSize = at(0)
		self.aiming = at(false)
		self.scoped = at(false)
		self.deflecting = at(false)
		self.tased = at(false)

		self._deflectLast = -1
		self._deflectToken = 0

		self._janitor = Janitor.new()
		self._characterJanitor = Janitor.new()
		self._janitor:Add(self._characterJanitor, "Destroy")

		local neuron = NetworkController.GetNeuron()

		setthreadidentity(2)

		local signals = neuron and neuron.signals and neuron.signals[player]

		if signals then
			self._janitor:Add(
				signals.CharacterAdded:Connect(function(character: Model): ()
					self:_onCharacterAdded(character :: Character)
				end),
				"Disconnect"
			)
			self._janitor:Add(
				signals.CharacterRemoving:Connect(function(): ()
					self:_onCharacterRemoving()
				end),
				"Disconnect"
			)
		end

		local current = neuron and neuron:get_character(player)
		if current then
			self:_onCharacterAdded(current :: Character)
		end

		setthreadidentity(8)

		return self
	end

	function OverkillPlayer._onCharacterAdded(self: OverkillPlayer, character: Character): ()
		self._characterJanitor:Cleanup()

		local token = {}
		self._characterToken = token

		local function tryInit(): boolean
			if self._characterToken ~= token then
				return true
			end
			local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not hrp or not humanoid then
				return false
			end
			self:_initCharacter(character, hrp, humanoid)
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

	function OverkillPlayer._initCharacter(
		self: OverkillPlayer,
		character: Character,
		hrp: BasePart,
		humanoid: Humanoid
	): ()
		local parts = {}
		for _, child in next, character:GetChildren() do
			parts[child.Name] = child
		end
		self.parts(parts)

		self.character(character)
		self.hrp(hrp)
		self.humanoid(humanoid)
		self.health(humanoid.Health)
		self.maxHealth(humanoid.MaxHealth)
		self.alive(humanoid.Health > 0)

		self._characterJanitor:Add(character.ChildAdded:Connect(function(part: Instance): ()
			self.parts(Sift.Dictionary.set(peek(self.parts), part.Name :: any, part))
		end))

		self._characterJanitor:Add(character.ChildRemoved:Connect(function(part: Instance): ()
			self.parts(Sift.Dictionary.removeKey(peek(self.parts), part.Name :: any))
		end))

		self._characterJanitor:Add(humanoid.HealthChanged:Connect(function(health: number): ()
			self.health(health)
			self.alive(health > 0)
		end))

		self._characterJanitor:Add(humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function(): ()
			self.maxHealth(humanoid.MaxHealth)
		end))
	end

	function OverkillPlayer._onCharacterRemoving(self: OverkillPlayer): ()
		self._characterJanitor:Cleanup()
		self._characterToken = nil
		self.character(nil)
		self.hrp(nil)
		self.humanoid(nil)
		self.alive(false)
		self.parts({})
		self.scoped(false)
		self.deflecting(false)
		self.tased(false)
	end

	function OverkillPlayer.IsAlive(self: OverkillPlayer): boolean
		return peek(self.alive)
	end

	function OverkillPlayer.GetHealthFraction(self: OverkillPlayer): number
		local maxHealth = peek(self.maxHealth)
		if maxHealth <= 0 then
			return 0
		end
		return math.clamp(peek(self.health) / maxHealth, 0, 1)
	end

	function OverkillPlayer.GetTeam(self: OverkillPlayer): string
		return peek(self.team)
	end

	function OverkillPlayer.GetMatchId(self: OverkillPlayer): any
		return peek(self.matchId)
	end

	function OverkillPlayer.GetCharacter(self: OverkillPlayer): Character?
		return peek(self.character)
	end

	function OverkillPlayer.GetParts(self: OverkillPlayer): { [string]: Instance }
		return peek(self.parts)
	end

	function OverkillPlayer.Destroy(self: OverkillPlayer): ()
		self._janitor:Destroy()
	end

	export type OverkillPlayer =
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
				matchId: Charm.Atom<any>,
				weaponId: Charm.Atom<string>,
				weaponName: Charm.Atom<string>,
				weaponIcon: Charm.Atom<string>,
				ammo: Charm.Atom<number>,
				ammoReserve: Charm.Atom<number>,
				magSize: Charm.Atom<number>,
				aiming: Charm.Atom<boolean>,
				scoped: Charm.Atom<boolean>,
				deflecting: Charm.Atom<boolean>,
				tased: Charm.Atom<boolean>,
				_deflectLast: number,
				_deflectToken: number,
			},
			OverkillPlayer
		))
		& BasePlayer.BasePlayer

	return OverkillPlayer
end)()
