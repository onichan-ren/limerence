local Players = cloneref(game:GetService("Players")) :: Players

local ModuleController = require("@game/rivals/module/ModuleController")
local rivalsInventoryState = require("@game/rivals/feature/inventory/rivalsInventoryState")
local Charm = require("@pkg/Charm")

local peek = Charm.peek
local LocalPlayer = Players.LocalPlayer

local deployableSkins = {
	_jumpPadClass = nil :: any,
	_jumpPadOriginal = nil :: ((any, any) -> ())?,
}

local getEquippedSkin = LPH_NO_VIRTUALIZE(function(weaponName: string): string?
	local inv = peek(rivalsInventoryState.weaponInventory)
	if type(inv) ~= "table" then
		return nil
	end
	local entry = inv[weaponName]
	if type(entry) ~= "table" or type(entry.skin) ~= "string" then
		return nil
	end
	return entry.skin
end)

local isLocalObject = LPH_NO_VIRTUALIZE(function(objectId: any): boolean
	if objectId == nil then
		return false
	end
	local fighterController = ModuleController.GetModule("FighterController")
	if not fighterController then
		return false
	end
	local objects = rawget(fighterController, "Objects")
	if type(objects) ~= "table" then
		return false
	end
	setthreadidentity(2)
	local owned = false
	for _, fighter in next, objects do
		local item = fighter.GetItem(fighter, objectId)
		if item then
			owned = fighter.IsLocalPlayer == true
			break
		end
	end
	setthreadidentity(8)
	return owned
end)

local requireJumpPads = LPH_NO_VIRTUALIZE(function(): any?
	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local modules = playerScripts and playerScripts:FindFirstChild("Modules")
	local gameComponents = modules and modules:FindFirstChild("GameComponents")
	local jumpPads = gameComponents and gameComponents:FindFirstChild("JumpPads")
	if not jumpPads then
		return nil
	end
	setthreadidentity(2)
	local instance = require(jumpPads)
	setthreadidentity(8)
	return instance
end)

function deployableSkins.install(): ()
	if deployableSkins._jumpPadOriginal then
		return
	end
	local instance = requireJumpPads()
	if not instance then
		return
	end
	local mt = getmetatable(instance)
	if type(mt) ~= "table" then
		return
	end
	local original = rawget(mt, "_ObjectAdded")
	if type(original) ~= "function" then
		return
	end
	local hooked = function(self, part)
		if isLocalObject(part:GetAttribute("ObjectID")) then
			local skin = getEquippedSkin("Jump Pad")
			if skin then
				part:SetAttribute("ViewModelName", skin)
			end
		end
		return original(self, part)
	end
	local wasReadonly = isreadonly(mt)
	if wasReadonly then
		setreadonly(mt, false)
	end
	mt._ObjectAdded = hooked
	if wasReadonly then
		setreadonly(mt, true)
	end
	deployableSkins._jumpPadClass = mt
	deployableSkins._jumpPadOriginal = original
end

function deployableSkins.uninstall(): ()
	local mt = deployableSkins._jumpPadClass
	local original = deployableSkins._jumpPadOriginal
	if mt and original then
		local wasReadonly = isreadonly(mt)
		if wasReadonly then
			setreadonly(mt, false)
		end
		mt._ObjectAdded = original
		if wasReadonly then
			setreadonly(mt, true)
		end
	end
	deployableSkins._jumpPadClass = nil
	deployableSkins._jumpPadOriginal = nil
end

return deployableSkins
