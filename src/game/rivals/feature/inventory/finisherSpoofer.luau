local Players = cloneref(game:GetService("Players")) :: Players
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage
local Charm = require("@pkg/Charm")
local hook = require("@share/hook")
local logger = require("@share/logger").new("finisherSpoofer")
local ModuleController = require("@game/rivals/module/ModuleController")
local ClientState = require("@game/rivals/client/clientState")
local rivalsInventoryState = require("@game/rivals/feature/inventory/rivalsInventoryState")
local WeaponController = require("@game/rivals/weapon/WeaponController")

local peek = Charm.peek
local LocalPlayer = Players.LocalPlayer

local CLAIM_WINDOW = 1

local finisherSpoofer = {
	_installed = false,
	_ready = false,
	_entityClass = nil :: any,
	_finishersFolder = nil :: Instance?,
	_originalReplicate = nil :: ((any, any, ...any) -> ...any)?,
	_killedConn = nil :: any,
	_claims = setmetatable({}, { __mode = "k" }) :: any,
}

local function entityPlayer(entity: any): Player?
	if type(entity) ~= "table" then
		return nil
	end
	local fighter = rawget(entity, "ClientFighter")
	if type(fighter) ~= "table" then
		return nil
	end
	local player = fighter.Player
	if typeof(player) == "Instance" and player:IsA("Player") then
		return player
	end
	return nil
end

local function resolveFinisher(): string?
	local equipped = peek(ClientState.currentEquipped)
	if type(equipped) ~= "table" then
		return nil
	end
	local weaponName = equipped.Name
	if type(weaponName) ~= "string" then
		return nil
	end
	local inventory = peek(rivalsInventoryState.weaponInventory)
	local entry = inventory and inventory[weaponName]
	if type(entry) ~= "table" then
		return nil
	end
	local finisher = entry.finisher
	if type(finisher) ~= "string" or finisher == "" then
		return nil
	end
	return finisher
end

local function isValidFinisher(name: string): boolean
	local folder = finisherSpoofer._finishersFolder
	return folder ~= nil and folder:FindFirstChild(name) ~= nil
end

local function killerInArgs(...: any): boolean
	for i = 1, select("#", ...) do
		if (select(i, ...)) == LocalPlayer then
			return true
		end
	end
	return false
end

local function isOurKill(self: any, ...: any): boolean
	if killerInArgs(...) then
		return true
	end
	local player = entityPlayer(self)
	if player then
		local expiry = finisherSpoofer._claims[player]
		if expiry and expiry >= os.clock() then
			finisherSpoofer._claims[player] = nil
			return true
		end
	end
	return false
end

local function installHooks(): ()
	local entityClass = finisherSpoofer._entityClass

	local originalReplicate
	originalReplicate = hook.add(
		entityClass.ReplicateFromServer,
		LPH_NO_VIRTUALIZE(function(self: any, key: any, ...: any): ...any
			if key == "FinisherEffect" and isOurKill(self, ...) then
				local ourName = resolveFinisher()
				if ourName and isValidFinisher(ourName) then
					local enum, a, b, serial = ...
					local realName: any = self:FromEnum(enum)
					if realName ~= ourName then
						self:_PlayFinisher(ourName, a, b, serial)
						return
					end
				end
			end
			return originalReplicate(self, key, ...)
		end)
	)
	finisherSpoofer._originalReplicate = originalReplicate

	finisherSpoofer._killedConn = WeaponController.killedPlayer:Connect(LPH_NO_VIRTUALIZE(function(victim: any): ()
		if typeof(victim) == "Instance" then
			finisherSpoofer._claims[victim] = os.clock() + CLAIM_WINDOW
		end
	end))

	finisherSpoofer._installed = true
end

local function uninstallHooks(): ()
	if finisherSpoofer._originalReplicate and finisherSpoofer._entityClass then
		hook.restore(finisherSpoofer._entityClass.ReplicateFromServer)
	end
	if finisherSpoofer._killedConn then
		finisherSpoofer._killedConn:Disconnect()
		finisherSpoofer._killedConn = nil
	end
	finisherSpoofer._installed = false
	finisherSpoofer._originalReplicate = nil
	table.clear(finisherSpoofer._claims)
end

function finisherSpoofer.new(): typeof(finisherSpoofer)
	if finisherSpoofer._installed then
		return finisherSpoofer
	end

	task.spawn(function()
		local attempts = 0
		while attempts < 60 do
			local entityClass = ModuleController.GetModule("ClientEntity")
			if
				entityClass
				and type(rawget(entityClass, "ReplicateFromServer")) == "function"
				and type(rawget(entityClass, "_PlayFinisher")) == "function"
			then
				finisherSpoofer._entityClass = entityClass
				break
			end
			attempts += 1
			task.wait(0.5)
		end

		if not finisherSpoofer._entityClass then
			logger:warn("ClientEntity not found")
			return
		end

		local modules = ReplicatedStorage:FindFirstChild("Modules")
		finisherSpoofer._finishersFolder = modules and modules:FindFirstChild("Finishers")

		installHooks()
		finisherSpoofer._ready = true
	end)

	return finisherSpoofer
end

function finisherSpoofer.Destroy(): ()
	if finisherSpoofer._installed then
		uninstallHooks()
	end
	finisherSpoofer._ready = false
	finisherSpoofer._entityClass = nil
	finisherSpoofer._finishersFolder = nil
end

export type FinisherSpoofer = typeof(finisherSpoofer)
return finisherSpoofer
