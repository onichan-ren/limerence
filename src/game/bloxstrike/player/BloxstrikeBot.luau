local Players = cloneref(game:GetService("Players")) :: Players
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local Sift = require("@pkg/Sift")
local PlayerController = require("@feature/player/PlayerController")

local at = Charm.atom
local peek = Charm.peek

local CULLED_FOLDER_NAME = "_PVS_CulledCharacters"
local EMPTY_ARMOR = { kevlar = false, helmet = false, health = 0 }

local function isCulled(model: Model): boolean
	local parent = model.Parent
	if not parent or parent.Name == CULLED_FOLDER_NAME or parent == ReplicatedStorage then
		return true
	end
	return not model:IsDescendantOf(Workspace)
end

local function makeBotProxy(model: Model): any
	local id = -(tonumber(model:GetAttribute("CombatantId")) or tonumber(model:GetAttribute("ActorId")) or 1)
	return {
		Name = model.Name,
		DisplayName = model.Name,
		UserId = id,
		GetAttribute = function(_self: any, attr: string): any
			return model:GetAttribute(attr)
		end,
		GetAttributeChangedSignal = function(_self: any, attr: string): RBXScriptSignal
			return model:GetAttributeChangedSignal(attr)
		end,
	}
end

local BloxstrikeBot = {}
BloxstrikeBot.__index = BloxstrikeBot

function BloxstrikeBot.new(model: Model): any
	local self = setmetatable({}, BloxstrikeBot) :: any
	local proxy = makeBotProxy(model)

	self.isBot = true
	self._model = model
	self._proxy = proxy
	self._janitor = Janitor.new()

	self.character = at(model :: Model?)
	self.hrp = at(model:FindFirstChild("HumanoidRootPart") :: BasePart?)
	self.humanoid = at(nil :: Humanoid?)
	self.alive = at(false)
	self.health = at(100)
	self.maxHealth = at(100)
	self.parts = at({})
	self.team = at(model:GetAttribute("Team"))
	self.culled = at(isCulled(model))
	self.invincible = at(model:GetAttribute("Invincible") == true)
	self.armor = at(EMPTY_ARMOR)
	self.currentEquipped = at(nil)
	self.isPlanting = at(false)
	self.isDefusing = at(false)
	self.isRescuing = at(false)
	self.isCarrying = at(false)
	self.hasC4 = at(false)
	self.hasDefuseKit = at(false)
	self.isReloading = at(false)
	self.isBlind = at(false)
	self.isScoped = at(false)

	local parts: { [string]: Instance } = {}
	for _, part in next, model:GetChildren() do
		parts[part.Name] = part
	end
	self.parts(parts)

	local function syncState(): ()
		local maxHp = tonumber(model:GetAttribute("MaxHealth")) or 100
		local hp = tonumber(model:GetAttribute("Health"))
		if hp == nil then
			hp = maxHp
		end
		local dead = model:GetAttribute("Dead") == true
		local team = model:GetAttribute("Team")
		self.team(team)
		self.maxHealth(maxHp)
		self.health(hp :: number)
		self.alive(not dead and (hp :: number) > 0 and team ~= nil)
	end

	syncState()

	self._janitor:Add(model:GetAttributeChangedSignal("Health"):Connect(syncState))
	self._janitor:Add(model:GetAttributeChangedSignal("MaxHealth"):Connect(syncState))
	self._janitor:Add(model:GetAttributeChangedSignal("Dead"):Connect(syncState))
	self._janitor:Add(model:GetAttributeChangedSignal("Team"):Connect(syncState))
	self._janitor:Add(model:GetAttributeChangedSignal("Invincible"):Connect(function(): ()
		self.invincible(model:GetAttribute("Invincible") == true)
	end))
	self._janitor:Add(model:GetPropertyChangedSignal("Parent"):Connect(function(): ()
		if not model.Parent then
			PlayerController.RemoveEntity(model)
			return
		end
		self.culled(isCulled(model))
	end))
	self._janitor:Add(model.ChildAdded:Connect(function(part: Instance): ()
		if part.Name == "HumanoidRootPart" and part:IsA("BasePart") then
			self.hrp(part)
		end
		self.parts(Sift.Dictionary.set(peek(self.parts), part.Name, part))
	end))
	self._janitor:Add(model.ChildRemoved:Connect(function(part: Instance): ()
		if part == peek(self.hrp) then
			self.hrp(nil)
		end
		self.parts(Sift.Dictionary.removeKey(peek(self.parts), part.Name))
	end))

	return self
end

function BloxstrikeBot.GetPlayer(self: any): any
	return self._proxy
end

function BloxstrikeBot.GetTeam(self: any): any
	return peek(self.team)
end

function BloxstrikeBot.IsAlive(self: any): boolean
	return peek(self.alive)
end

function BloxstrikeBot.Destroy(self: any): ()
	if self._janitor then
		self._janitor:Destroy()
	end
	self.character(nil)
	self.hrp(nil)
	self.alive(false)
	self.parts({})
end

local watcherJanitor: Janitor.Janitor? = nil

local function tryTrackModel(inst: Instance): ()
	if not inst:IsA("Model") then
		return
	end
	if inst:GetAttribute("Bot") ~= true then
		return
	end
	if Players:GetPlayerFromCharacter(inst) then
		return
	end
	if PlayerController.Get(inst :: any) then
		return
	end
	if not inst:FindFirstChild("HumanoidRootPart") then
		inst:WaitForChild("HumanoidRootPart", 5)
	end
	if not inst.Parent or PlayerController.Get(inst :: any) then
		return
	end
	PlayerController.AddEntity(inst, BloxstrikeBot.new(inst))
end

local function watchFolder(janitor: Janitor.Janitor, folder: Instance): ()
	for _, child in next, folder:GetChildren() do
		task.spawn(tryTrackModel, child)
	end
	janitor:Add(folder.ChildAdded:Connect(function(child: Instance): ()
		task.spawn(tryTrackModel, child)
	end))
end

function BloxstrikeBot.Start(): ()
	if watcherJanitor then
		return
	end
	local janitor = Janitor.new()
	watcherJanitor = janitor

	local wsChars = Workspace:FindFirstChild("Characters")
	if wsChars then
		watchFolder(janitor, wsChars)
	else
		janitor:Add(Workspace.ChildAdded:Connect(function(child: Instance): ()
			if child.Name == "Characters" then
				watchFolder(janitor, child)
			end
		end))
	end

	local pvs = ReplicatedStorage:FindFirstChild(CULLED_FOLDER_NAME)
	if pvs then
		watchFolder(janitor, pvs)
	else
		janitor:Add(ReplicatedStorage.ChildAdded:Connect(function(child: Instance): ()
			if child.Name == CULLED_FOLDER_NAME then
				watchFolder(janitor, child)
			end
		end))
	end
end

function BloxstrikeBot.Stop(): ()
	if watcherJanitor then
		watcherJanitor:Destroy()
		watcherJanitor = nil
	end
end

return BloxstrikeBot
