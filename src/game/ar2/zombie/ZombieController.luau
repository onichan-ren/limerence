local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")
local Signal = require("@pkg/Signal")

local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local peek = Charm.peek

local BIN_NAME = "Zombies"

local ZombieController = {
	_janitor = nil :: Janitor.Janitor?,
	zombies = Charm.atom({}) :: Charm.Atom<{ [Model]: true }>,
	zombieAdded = Signal.new() :: Signal.Signal<Model>,
	zombieRemoved = Signal.new() :: Signal.Signal<Model>,
}

local function addZombie(child: Instance): ()
	if not child:IsA("Model") then
		return
	end
	local zombie = child :: Model
	if peek(ZombieController.zombies)[zombie] then
		return
	end
	ZombieController.zombies(Sift.Dictionary.set(peek(ZombieController.zombies), zombie, true))
	ZombieController.zombieAdded:Fire(zombie)
end

local function removeZombie(child: Instance): ()
	local zombie = child :: Model
	if not peek(ZombieController.zombies)[zombie] then
		return
	end
	ZombieController.zombies(Sift.Dictionary.removeKey(peek(ZombieController.zombies), zombie))
	ZombieController.zombieRemoved:Fire(zombie)
end

local function clearZombies(): ()
	for zombie in next, peek(ZombieController.zombies) do
		removeZombie(zombie)
	end
end

function ZombieController.new(): ZombieController
	local janitor = Janitor.new()
	ZombieController._janitor = janitor

	local function bindBin(bin: Instance): ()
		janitor:Add(bin.ChildAdded:Connect(addZombie), "Disconnect", "childAdded")
		janitor:Add(bin.ChildRemoved:Connect(removeZombie), "Disconnect", "childRemoved")

		local nextZombies = table.clone(peek(ZombieController.zombies))
		local added: { Model } = {}
		for _, child in next, bin:GetChildren() do
			if child:IsA("Model") then
				local zombie = child :: Model
				if not nextZombies[zombie] then
					nextZombies[zombie] = true
					added[#added + 1] = zombie
				end
			end
		end
		if #added > 0 then
			ZombieController.zombies(nextZombies)
			for i = 1, #added do
				ZombieController.zombieAdded:Fire(added[i])
			end
		end
	end

	janitor:Add(
		Workspace.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(child: Instance): ()
			if child.Name == BIN_NAME then
				clearZombies()
				bindBin(child)
			end
		end)),
		"Disconnect",
		"binWatch"
	)

	local bin = Workspace:FindFirstChild(BIN_NAME)
	if bin then
		bindBin(bin)
	end

	return ZombieController
end

function ZombieController.GetZombies(): { [Model]: true }
	return peek(ZombieController.zombies)
end

function ZombieController.Destroy(): ()
	clearZombies()

	local janitor = ZombieController._janitor
	if janitor then
		janitor:Destroy()
		ZombieController._janitor = nil
	end
end

export type ZombieController = typeof(ZombieController)
return ZombieController
