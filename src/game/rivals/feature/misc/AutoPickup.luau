local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ClientState = require("@game/rivals/client/clientState")

local peek = Charm.peek

local DROP_NAME = "_drop"

local fireDrop = LPH_NO_VIRTUALIZE(function(drop: BasePart, part: BasePart): ()
	firetouchinterest(drop, part, 0)
	firetouchinterest(drop, part, 1)
end)

local AutoPickup = {}
AutoPickup.__index = AutoPickup

setmetatable(AutoPickup, { __index = BaseFeature })

function AutoPickup.new(link: gameUi.Linker): AutoPickup
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoPickup)

	link:Toggle("autoPickup", "Auto Pickup", false):SetTip({
		title = "Auto Pickup",
		body = "Automatically collects nearby health and ammo drops.",
	})

	self._enabled = false
	self._drops = {} :: { [Instance]: boolean }
	self._loopConn = nil :: RBXScriptConnection?
	self._addedConn = nil :: RBXScriptConnection?
	self._removingConn = nil :: RBXScriptConnection?

	self:Track(link:Get("autoPickup"):OnChange(function(value: boolean): ()
		self:_setActive(value == true)
	end))

	return self
end

function AutoPickup._track(self: AutoPickup, instance: Instance): ()
	if instance:IsA("BasePart") and instance.Name == DROP_NAME then
		self._drops[instance] = true
	end
end

function AutoPickup._scan(self: AutoPickup): ()
	for _, descendant in next, Workspace:QueryDescendants("#" .. DROP_NAME) do
		self:_track(descendant)
	end
end

AutoPickup._pump = LPH_NO_VIRTUALIZE(function(self: AutoPickup): ()
	if not peek(ClientState.alive) then
		return
	end
	local parts = peek(ClientState.parts)
	local ourPart = parts and parts.HumanoidRootPart :: BasePart?
	if not ourPart then
		return
	end
	for drop in next, self._drops do
		if drop.Parent and drop:IsDescendantOf(Workspace) then
			fireDrop(drop :: BasePart, ourPart)
		else
			self._drops[drop] = nil
		end
	end
end)

function AutoPickup._setActive(self: AutoPickup, active: boolean): ()
	if self._enabled == active then
		return
	end
	self._enabled = active

	if active then
		table.clear(self._drops)
		self:_scan()
		self._addedConn = Workspace.DescendantAdded:Connect(function(instance: Instance): ()
			self:_track(instance)
		end)
		self._removingConn = Workspace.DescendantRemoving:Connect(function(instance: Instance): ()
			self._drops[instance] = nil
		end)
		self._loopConn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
			self:_pump()
		end))
	else
		if self._loopConn then
			self._loopConn:Disconnect()
			self._loopConn = nil
		end
		if self._addedConn then
			self._addedConn:Disconnect()
			self._addedConn = nil
		end
		if self._removingConn then
			self._removingConn:Disconnect()
			self._removingConn = nil
		end
		table.clear(self._drops)
	end
end

function AutoPickup.Destroy(self: AutoPickup): ()
	self:_setActive(false)
	BaseFeature.Destroy(self)
end

export type AutoPickup = typeof(setmetatable(
	{} :: {
		_enabled: boolean,
		_drops: { [Instance]: boolean },
		_loopConn: RBXScriptConnection?,
		_addedConn: RBXScriptConnection?,
		_removingConn: RBXScriptConnection?,
	},
	AutoPickup
)) & BaseFeature.BaseFeature

return AutoPickup
