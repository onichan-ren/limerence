local Janitor = require("@pkg/Janitor")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ZombieController = require("@game/ar2/zombie/ZombieController")

type FreezeEntry = {
	root: BasePart?,
	anchored: boolean,
	conn: RBXScriptConnection?,
	pending: RBXScriptConnection?,
}

local FreezeZombies = {}
FreezeZombies.__index = FreezeZombies

setmetatable(FreezeZombies, { __index = BaseFeature })

function FreezeZombies.new(link: gameUi.Linker): FreezeZombies
	local self = BaseFeature.new() :: any
	setmetatable(self, FreezeZombies)

	self._enabled = false
	self._janitor = nil :: Janitor.Janitor?
	self._frozen = {} :: { [Model]: FreezeEntry }

	link:Toggle("freezeZombies", "Freeze Zombies", false):SetTip({
		title = "Freeze Zombies",
		body = "Holds zombies in place so they can't move.",
	})

	self:Track(link:Get("freezeZombies"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("freezeZombies") then
		self:Enable()
	end

	return self
end

local function anchorRoot(entry: FreezeEntry, root: BasePart): ()
	if entry.pending then
		entry.pending:Disconnect()
		entry.pending = nil
	end

	entry.root = root
	entry.anchored = root.Anchored
	entry.conn = root:GetPropertyChangedSignal("Anchored"):Connect(function(): ()
		if not root.Anchored then
			root.Anchored = true
		end
	end)

	root.Anchored = true
end

function FreezeZombies._freezeZombie(self: FreezeZombies, zombie: Model): ()
	if self._frozen[zombie] then
		return
	end

	local entry: FreezeEntry = {
		root = nil,
		anchored = false,
		conn = nil,
		pending = nil,
	}
	self._frozen[zombie] = entry

	local root = zombie.PrimaryPart or zombie:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		anchorRoot(entry, root)
		return
	end

	entry.pending = zombie.ChildAdded:Connect(function(child: Instance): ()
		if child.Name == "HumanoidRootPart" and child:IsA("BasePart") then
			anchorRoot(entry, child)
		end
	end)
end

function FreezeZombies._unfreezeZombie(self: FreezeZombies, zombie: Model): ()
	local entry = self._frozen[zombie]
	if not entry then
		return
	end
	self._frozen[zombie] = nil

	if entry.pending then
		entry.pending:Disconnect()
	end
	if entry.conn then
		entry.conn:Disconnect()
	end

	local root = entry.root
	if root and root.Parent then
		root.Anchored = entry.anchored
	end
end

function FreezeZombies.Enable(self: FreezeZombies): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local janitor = Janitor.new()
	self._janitor = janitor

	janitor:Add(
		ZombieController.zombieAdded:Connect(function(zombie: Model): ()
			self:_freezeZombie(zombie)
		end),
		"Disconnect"
	)
	janitor:Add(
		ZombieController.zombieRemoved:Connect(function(zombie: Model): ()
			self:_unfreezeZombie(zombie)
		end),
		"Disconnect"
	)

	for zombie in next, ZombieController.GetZombies() do
		self:_freezeZombie(zombie)
	end
end

function FreezeZombies.Disable(self: FreezeZombies): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	local zombies: { Model } = {}
	for zombie in next, self._frozen do
		zombies[#zombies + 1] = zombie
	end
	for _, zombie in next, zombies do
		self:_unfreezeZombie(zombie)
	end

	if self._janitor then
		self._janitor:Destroy()
		self._janitor = nil
	end
end

function FreezeZombies.Destroy(self: FreezeZombies): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type FreezeZombies =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor?,
			_frozen: { [Model]: FreezeEntry },
		},
		FreezeZombies
	))
	& BaseFeature.BaseFeature

return FreezeZombies
