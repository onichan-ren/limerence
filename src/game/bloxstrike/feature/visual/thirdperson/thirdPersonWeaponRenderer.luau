local ModuleController = require("@game/bloxstrike/module/ModuleController")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local originState = require("@game/universal/feature/visual/crosshair/originState")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local Players = cloneref(game:GetService("Players")) :: Players
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local LocalPlayer = Players.LocalPlayer

local peek = Charm.peek
local sub = Charm.subscribe

local thirdPersonWeaponRenderer = {}

local activeJanitor: Janitor.Janitor? = nil
local muzzleCache: BasePart? = nil

local findMuzzle = LPH_NO_VIRTUALIZE(function(): BasePart?
	local cached = muzzleCache
	if cached and cached.Parent then
		return cached
	end
	muzzleCache = nil
	local debris = Workspace:FindFirstChild("Debris")
	if not debris then
		return nil
	end
	local weapon = debris:FindFirstChild(LocalPlayer.Name .. "_Weapon")
	if not weapon then
		return nil
	end
	local interact = weapon:FindFirstChild("Interactables")
	if not interact then
		return nil
	end
	local muzzle = interact:FindFirstChild("MuzzlePart")
		or interact:FindFirstChild("MuzzlePartL")
		or interact:FindFirstChild("MuzzlePartR")
	muzzleCache = muzzle :: BasePart?
	return muzzleCache
end)

thirdPersonWeaponRenderer.GetMuzzlePart = findMuzzle

local buildInventorySlots = LPH_NO_VIRTUALIZE(function(): { [number]: any }
	local slots = {}
	local inventory = peek(loadoutState.inventory)
	if typeof(inventory) ~= "table" then
		return slots
	end
	for _, entry in next, inventory do
		if typeof(entry) ~= "table" then
			continue
		end
		local slot = entry.Slot
		if typeof(slot) == "number" and slot >= 1 and slot <= 3 then
			slots[slot] = entry
		end
	end
	return slots
end)

local clearVisuals = LPH_NO_VIRTUALIZE(function(): ()
	muzzleCache = nil
	local module = ModuleController.GetModule("CreateWeaponModel")
	if module then
		module.ClearPlayerCache(LocalPlayer)
	end

	local character = LocalPlayer.Character
	if character then
		local attachments = character:FindFirstChild("WeaponAttachments")
		if attachments then
			attachments:ClearAllChildren()
		end
		local weaponModel = character:FindFirstChild("WeaponModel")
		if weaponModel then
			weaponModel:ClearAllChildren()
		end
	end

	local debris = Workspace:FindFirstChild("Debris")
	if debris then
		local equipped = debris:FindFirstChild(LocalPlayer.Name .. "_Weapon")
		if equipped then
			equipped:Destroy()
		end
		local attFolder = debris:FindFirstChild(LocalPlayer.Name .. "_WeaponAttachments")
		if attFolder then
			attFolder:Destroy()
		end
	end
end)

local applyNoCollide = LPH_NO_VIRTUALIZE(function(root: Instance?): ()
	if not root then
		return
	end
	for _, descendant in next, root:QueryDescendants("BasePart") do
		descendant.CanCollide = false
		descendant.CanQuery = false
	end
end)

local ensureContainers = LPH_NO_VIRTUALIZE(function(character: Model): ()
	if not character:FindFirstChild("WeaponModel") then
		local folder = Instance.new("Folder")
		folder.Name = "WeaponModel"
		folder.Parent = character
	end
	if not character:FindFirstChild("WeaponAttachments") then
		local folder = Instance.new("Folder")
		folder.Name = "WeaponAttachments"
		folder.Parent = character
	end
end)

local refresh = LPH_NO_VIRTUALIZE(function(): ()
	local module = ModuleController.GetModule("CreateWeaponModel")
	if not module then
		return
	end
	local character = LocalPlayer.Character
	if not character then
		return
	end
	local parent = character.Parent
	if not parent then
		return
	end

	muzzleCache = nil

	local equipped = peek(loadoutState.currentEquipped)
	if typeof(equipped) ~= "table" or typeof(equipped.Name) ~= "string" or equipped.Name == "" then
		clearVisuals()
		return
	end

	ensureContainers(character)

	setthreadidentity(2)
	module(LocalPlayer, equipped, buildInventorySlots())
	setthreadidentity(8)

	applyNoCollide(character:FindFirstChild("WeaponModel"))
	applyNoCollide(character:FindFirstChild("WeaponAttachments"))
	local debris = Workspace:FindFirstChild("Debris")
	if debris then
		applyNoCollide(debris:FindFirstChild(LocalPlayer.Name .. "_Weapon"))
		applyNoCollide(debris:FindFirstChild(LocalPlayer.Name .. "_WeaponAttachments"))
	end
end)

thirdPersonWeaponRenderer.enable = LPH_NO_VIRTUALIZE(function(): ()
	if activeJanitor then
		return
	end
	local janitor = Janitor.new()
	activeJanitor = janitor

	janitor:Add(sub(loadoutState.currentEquipped, refresh))
	janitor:Add(sub(loadoutState.inventory, refresh))
	janitor:Add(
		LocalPlayer.CharacterAdded:Connect(function(): ()
			task.delay(0.15, refresh)
		end),
		"Disconnect"
	)
	janitor:Add(clearVisuals, true)

	originState.SetThirdPersonMuzzleProvider(findMuzzle)
	janitor:Add(function(): ()
		originState.SetThirdPersonMuzzleProvider(nil)
		muzzleCache = nil
	end)

	refresh()
end)

thirdPersonWeaponRenderer.disable = LPH_NO_VIRTUALIZE(function(): ()
	local janitor = activeJanitor
	if not janitor then
		return
	end
	activeJanitor = nil
	janitor:Destroy()
end)

return thirdPersonWeaponRenderer
