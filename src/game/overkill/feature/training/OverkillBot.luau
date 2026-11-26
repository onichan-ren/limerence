local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local Signal = require("@pkg/Signal")
local ModuleController = require("@game/overkill/module/ModuleController")

local at = Charm.atom
local peek = Charm.peek

local nextBotId = -1

local OverkillBot = {}
OverkillBot.__index = OverkillBot

local function collectParts(model: Model): { [string]: Instance }
	local parts: { [string]: Instance } = {}
	local descendants = model:QueryDescendants("BasePart")
	for i = 1, #descendants do
		local descendant = descendants[i]
		if parts[descendant.Name] == nil then
			parts[descendant.Name] = descendant
		end
	end
	return parts
end

function OverkillBot.new(model: Model): OverkillBot
	local self = setmetatable({}, OverkillBot) :: any

	self._model = model
	self.isBot = true
	self._fakePlayer = { UserId = nextBotId, Name = model.Name }
	nextBotId -= 1

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hrp = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?

	self.character = at(model :: Model?)
	self.hrp = at(hrp)
	self.humanoid = at(humanoid)
	self.parts = at(collectParts(model))
	self.alive = at(model.Parent ~= nil)
	self.health = at(humanoid and humanoid.MaxHealth or 100)
	self.maxHealth = at(humanoid and humanoid.MaxHealth or 100)
	self.died = Signal.new()

	self._destroyed = false
	self._inWorkspace = model:IsDescendantOf(Workspace)

	self.team = at("")
	self.matchId = at(nil :: any)
	self.aiming = at(false)
	self.scoped = at(false)
	self.deflecting = at(false)
	self.tased = at(false)
	self.weaponId = at("")
	self.weaponName = at("")
	self.weaponIcon = at("")
	self.ammo = at(0)
	self.ammoReserve = at(0)
	self.magSize = at(0)

	self._janitor = Janitor.new()

	local function setAlive(value: boolean): ()
		setthreadidentity(8)
		local now = value and self._inWorkspace
		local was = peek(self.alive)
		if now == was then
			return
		end
		self.alive(now)
		if was and not now then
			self.died:Fire()
		end
	end

	local partsDirty = false
	local function refreshParts(): ()
		partsDirty = false
		if self._destroyed then
			return
		end
		self.parts(collectParts(model))
		local newHrp = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
		if newHrp ~= peek(self.hrp) then
			self.hrp(newHrp)
		end
	end
	local function queueRefresh(): ()
		if partsDirty then
			return
		end
		partsDirty = true
		task.defer(refreshParts)
	end
	self._janitor:Add(model.ChildAdded:Connect(queueRefresh), "Disconnect")
	self._janitor:Add(model.ChildRemoved:Connect(queueRefresh), "Disconnect")
	self._janitor:Add(
		model.AncestryChanged:Connect(function(): ()
			self._inWorkspace = model:IsDescendantOf(Workspace)
			if not self._inWorkspace then
				setAlive(false)
			end
		end),
		"Disconnect"
	)

	task.spawn(function(): ()
		local States = ModuleController.GetModule("states")
		if type(States) ~= "table" or self._destroyed then
			return
		end

		local signals = States.characterSignals[model]
		while not signals and not self._destroyed do
			task.wait(0.25)
			signals = States.characterSignals[model]
		end
		if self._destroyed or not signals then
			return
		end

		setthreadidentity(2)
		local maxHealth = States:GetStateValue(model, "MaxHealth", peek(self.maxHealth))
		local health = States:GetStateValue(model, "Health", 150)
		local deflecting = States:GetStateValue(model, "Deflecting")
		setthreadidentity(8)

		if type(maxHealth) == "number" then
			self.maxHealth(maxHealth)
		end
		if type(health) == "number" then
			self.health(health)
			setAlive(health > 0)
		end
		self.deflecting(deflecting ~= nil)

		self._janitor:Add(
			signals.OnStateChanged:Connect(function(name: string, value: any): ()
				setthreadidentity(8)
				if name == "Health" then
					if type(value) == "number" then
						self.health(value)
						setAlive(value > 0)
					end
				elseif name == "MaxHealth" then
					if type(value) == "number" then
						self.maxHealth(value)
					end
				elseif name == "Deflecting" then
					self.deflecting(value ~= nil)
				end
				setthreadidentity(2)
			end),
			"Disconnect"
		)
		setthreadidentity(8)
	end)

	return self
end

function OverkillBot.GetPlayer(self: OverkillBot): any
	return self._fakePlayer
end

function OverkillBot.IsAlive(self: OverkillBot): boolean
	return peek(self.alive)
end

function OverkillBot.GetCharacter(self: OverkillBot): Model?
	return peek(self.character)
end

function OverkillBot.GetParts(self: OverkillBot): { [string]: Instance }
	return peek(self.parts)
end

function OverkillBot.GetModel(self: OverkillBot): Model
	return self._model
end

function OverkillBot.Destroy(self: OverkillBot): ()
	self._destroyed = true
	self._janitor:Destroy()
	self.died:DisconnectAll()
end

export type OverkillBot = typeof(setmetatable(
	{} :: {
		_model: Model,
		_fakePlayer: any,
		_janitor: Janitor.Janitor,
		_destroyed: boolean,
		_inWorkspace: boolean,
		died: Signal.Signal<()>,
		isBot: boolean,
		character: Charm.Atom<Model?>,
		hrp: Charm.Atom<BasePart?>,
		humanoid: Charm.Atom<Humanoid?>,
		parts: Charm.Atom<{ [string]: Instance }>,
		alive: Charm.Atom<boolean>,
		health: Charm.Atom<number>,
		maxHealth: Charm.Atom<number>,
		team: Charm.Atom<string>,
		matchId: Charm.Atom<any>,
		aiming: Charm.Atom<boolean>,
		scoped: Charm.Atom<boolean>,
		deflecting: Charm.Atom<boolean>,
		tased: Charm.Atom<boolean>,
		weaponId: Charm.Atom<string>,
		weaponName: Charm.Atom<string>,
		weaponIcon: Charm.Atom<string>,
		ammo: Charm.Atom<number>,
		ammoReserve: Charm.Atom<number>,
		magSize: Charm.Atom<number>,
	},
	OverkillBot
))

return OverkillBot
