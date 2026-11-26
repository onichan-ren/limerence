local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local Players = cloneref(game:GetService("Players")) :: Players

local peek = Charm.peek
local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer

local ClientState = require("@game/ar2/client/clientState")
local ModuleController = require("@game/ar2/module/ModuleController")
local NetworkController = require("@game/ar2/network/NetworkController")

local MAX_HEALTH = 100

local state = {
	alive = ClientState.alive,
	parts = ClientState.parts,
	character = ClientState.character,
	health = ClientState.health,
	hydration = ClientState.hydration,
	energy = ClientState.energy,
	hrp = ClientState.hrp,
	humanoid = ClientState.humanoid,
	team = ClientState.team,
	thirdPerson = ClientState.thirdPerson,
	vehicle = ClientState.vehicle,
}

local signals = {
	onCharacterAdded = Signal.new(),
	onCharacterRemoving = Signal.new(),
	onSpawn = Signal.new(),
	onDeath = Signal.new(),
	onTeamChanged = Signal.new(),
	onHealthChanged = Signal.new(),
	onHit = Signal.new(),
}

local lastCharacter: Model?

local clientApi = {
	state = state,
	signals = signals,
}

function clientApi.GetHealth(): number
	return peek(state.health) or 0
end

function clientApi.GetMaxHealth(): number
	return MAX_HEALTH
end

function clientApi.GetHealthFraction(): number
	return math.clamp((peek(state.health) or 0) / MAX_HEALTH, 0, 1)
end

function clientApi.GetHydration(): number
	return peek(state.hydration) or 0
end
function clientApi.GetEnergy(): number
	return peek(state.energy) or 0
end

function clientApi.GetLocalPlayer(): Player
	return LocalPlayer
end

function clientApi.GetCharacter(): Model?
	return peek(state.character)
end

function clientApi.GetRootPart(): BasePart?
	return peek(state.hrp)
end

function clientApi.GetHumanoid(): Humanoid?
	return peek(state.humanoid)
end

function clientApi.GetTeam(): string?
	return peek(state.team)
end

function clientApi.GetParts(): { [string]: Instance }
	local snap = peek(state.parts)
	local out: { [string]: Instance } = {}
	for k, v in next, snap do
		out[k] = v
	end
	return out
end

function clientApi.IsAlive(): boolean
	return peek(state.alive)
end

function clientApi.GetPosition(): Vector3?
	local hrp = peek(state.hrp) :: BasePart?
	return hrp and hrp.Position or nil
end

function clientApi.GetCFrame(): CFrame?
	local hrp = peek(state.hrp) :: BasePart?
	return hrp and hrp.CFrame or nil
end

function clientApi.GetVelocity(): Vector3
	local hrp = peek(state.hrp) :: BasePart?
	return hrp and hrp.AssemblyLinearVelocity or Vector3.zero
end

function clientApi.IsSpectating(): boolean
	return false
end

function clientApi.IsThirdPerson(): boolean
	return peek(state.thirdPerson)
end

function clientApi.GetVehicle(): Model?
	return peek(state.vehicle)
end

local function getArCharacter(): any
	local module = ModuleController.GetModule("LocalPlayer")
	local getter = module and module.module and module.module.get
	local player = getter and getter()
	return player and player.Character or nil
end

function clientApi.GetItemName(): string?
	local character = getArCharacter()
	local item = character and character.EquippedItem
	local name = item and (item.DisplayName or item.Name)
	return type(name) == "string" and name ~= "" and name or nil
end

function clientApi.GetItem(): string?
	return clientApi.GetItemName()
end

local invSend = function(...): ()
	local old = getthreadidentity()
	setthreadidentity(2)
	NetworkController.send(...)
	setthreadidentity(old)
end

local function getInventory(): any
	local character = getArCharacter()
	return character and character.Inventory or nil
end

local function itemInfo(item: any): any
	return {
		id = item.Id,
		name = item.DisplayName or item.Name,
		rawName = item.Name,
		type = item.Type,
		subType = item.SubType,
		amount = tonumber(item.Amount),
		capacity = tonumber(item.Capacity),
		caliber = item.Caliber,
		slot = item.EquipSlot,
		rotated = item.Rotated == true,
	}
end

local function findItem(id: any): (any, any)
	local inventory = getInventory()
	if not inventory then
		return nil, nil
	end
	for _, container in next, inventory.Containers do
		local item = container.Occupants and container.Occupants[id]
		if item then
			return item, container
		end
	end
	return nil, nil
end

function clientApi.GetItems(): { any }
	local out = {}
	local inventory = getInventory()
	if not inventory then
		return out
	end
	for _, container in next, inventory.Containers do
		if not container.IsCarried then
			continue
		end
		for _, item in next, container.Occupants do
			out[#out + 1] = itemInfo(item)
		end
	end
	return out
end

function clientApi.GetNearbyLoot(): { any }
	local out = {}
	local inventory = getInventory()
	if not inventory then
		return out
	end
	for _, container in next, inventory.Containers do
		if container.IsCarried then
			continue
		end
		for _, item in next, container.Occupants do
			local info = itemInfo(item)
			info.container = container.Id
			info.source = container.Name
			out[#out + 1] = info
		end
	end
	return out
end

function clientApi.GetEquipment(): { any }
	local out = {}
	local inventory = getInventory()
	if not inventory then
		return out
	end
	local equipment = inventory.Equipment
	if type(equipment) ~= "table" then
		return out
	end
	for slot, entry in next, equipment do
		if type(entry) ~= "table" then
			continue
		end
		if inventory:IsEquipSlotList(slot) then
			for _, item in next, entry.Items do
				local info = itemInfo(item)
				info.equipSlot = slot
				out[#out + 1] = info
			end
		elseif entry.Id then
			local info = itemInfo(entry)
			info.equipSlot = slot
			out[#out + 1] = info
		end
	end
	return out
end

clientApi.actions = {
	equipItem = function(id: any, slot: any?): ()
		if id == nil then
			error("api.client.equipItem: id is required", 2)
		end
		if slot ~= nil then
			invSend("Inventory Equip Item", id, slot)
		else
			invSend("Inventory Equip Item", id)
		end
	end,
	useItem = function(id: any): ()
		if id == nil then
			error("api.client.useItem: id is required", 2)
		end
		invSend("Inventory Use Item", id)
	end,
	dropItem = function(id: any, rotated: boolean?): ()
		if id == nil then
			error("api.client.dropItem: id is required", 2)
		end
		invSend("Inventory Drop Item", id, rotated == true)
	end,
	pickupItem = function(id: any, containerId: any?): ()
		if id == nil then
			error("api.client.pickupItem: id is required", 2)
		end
		local resolved = containerId
		if resolved == nil then
			local _, container = findItem(id)
			resolved = container and container.Id or nil
		end
		if resolved == nil then
			return
		end
		invSend("Inventory Pickup Item", id, resolved)
	end,
	craftItem = function(id: any, sourceId: any): ()
		if id == nil or sourceId == nil then
			error("api.client.craftItem: id and sourceId are required", 2)
		end
		invSend("Inventory Craft Item", id, sourceId)
	end,
	fillAmmo = function(id: any): ()
		if id == nil then
			error("api.client.fillAmmo: id is required", 2)
		end
		invSend("Inventory Fill Ammo", id)
	end,
	unloadAmmo = function(id: any): ()
		if id == nil then
			error("api.client.unloadAmmo: id is required", 2)
		end
		invSend("Inventory Unload Ammo", id)
	end,
	slotUtility = function(id: any): ()
		if id == nil then
			error("api.client.slotUtility: id is required", 2)
		end
		invSend("Inventory Slot Utility", id)
	end,
	removeAttachment = function(id: any, parentId: any?): ()
		if id == nil then
			error("api.client.removeAttachment: id is required", 2)
		end
		local resolved = parentId
		if resolved == nil then
			local item = findItem(id)
			resolved = item and item.Parent and item.Parent.Id or nil
		end
		if resolved == nil then
			return
		end
		invSend("Inventory Remove Attachment", id, resolved)
	end,
}

sub(state.character, function(character: Model?): ()
	if character == lastCharacter then
		return
	end
	local previous = lastCharacter
	if previous then
		state.hrp(nil)
		state.humanoid(nil)
		signals.onCharacterRemoving:Fire(previous)
	end
	lastCharacter = character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChildWhichIsA("Humanoid") :: Humanoid?

		state.hrp(hrp)
		state.humanoid(humanoid)
		signals.onCharacterAdded:Fire(character)
	end
end)

local lastAlive = peek(state.alive)
sub(state.alive, function(alive: boolean): ()
	if alive == lastAlive then
		return
	end
	lastAlive = alive
	if alive then
		signals.onSpawn:Fire()
	else
		signals.onDeath:Fire()
	end
end)

local lastTeam = peek(state.team)
sub(state.team, function(team: string?): ()
	if team == lastTeam then
		return
	end
	lastTeam = team
	signals.onTeamChanged:Fire(team)
end)

sub(state.health, function(health: number): ()
	signals.onHealthChanged:Fire(health, MAX_HEALTH)
end)

if peek(state.character) then
	local character = peek(state.character) :: Model
	lastCharacter = character
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildWhichIsA("Humanoid") :: Humanoid?

	state.humanoid(humanoid)
	state.hrp(hrp)
end

return clientApi
