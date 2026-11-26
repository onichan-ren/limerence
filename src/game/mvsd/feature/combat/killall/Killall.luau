local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Charm = require("@pkg/Charm")
local ClientState = require("@game/mvsd/client/clientState")
local PlayerController = require("@feature/player/PlayerController")
local WeaponController = require("@game/mvsd/weapon/WeaponController")

local peek = Charm.peek

local Players = cloneref(game:GetService("Players")) :: Players
local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService
local RunService = cloneref(game:GetService("RunService")) :: RunService

local LocalPlayer = Players.LocalPlayer

local RETRY_WINDOW = 0.03
local EQUIP_INTERVAL = 0.25
local CLOSE_ORIGIN_DISTANCE = 2

local getShootOrigin = LPH_NO_VIRTUALIZE(function(): Vector3?
	local head = peek(ClientState.parts).Head
	if not head or not head:IsA("BasePart") then
		return nil
	end
	return (head.CFrame * CFrame.new(0, head.Size.Y / 2, head.Size.Z / 2)).Position
end)

local findGunTool = LPH_NO_VIRTUALIZE(function(): Tool?
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not backpack then
		return nil
	end
	for _, child in next, backpack:GetChildren() do
		if child:IsA("Tool") and CollectionService:HasTag(child, "GunTool") then
			return child
		end
	end
	return nil
end)

local Killall = {}
Killall.__index = Killall

setmetatable(Killall, { __index = BaseFeature })

function Killall.new(link: gameUi.Linker): Killall
	local self = BaseFeature.new() :: any
	setmetatable(self, Killall)

	link:Toggle("killAll", "Kill All", false):SetTip({
		title = "Kill All",
		body = "Eliminates every enemy in your match instantly.",
	})

	self._connection = nil :: RBXScriptConnection?
	self._firedAt = {} :: { [Player]: number }
	self._attempts = {} :: { [Player]: number }
	self._equippedAt = 0

	self:Track(link:Get("killAll"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(function(): ()
		self:Disable()
	end)

	if link:Peek("killAll") then
		self:Enable()
	end

	return self
end

local step = LPH_NO_VIRTUALIZE(function(self: any): ()
	if not peek(ClientState.alive) then
		return
	end

	local localMatch = peek(ClientState.matchId)
	if localMatch == nil then
		return
	end

	local now = os.clock()

	if peek(ClientState.weapon) ~= "gun" then
		if now - self._equippedAt < EQUIP_INTERVAL then
			return
		end
		local humanoid = peek(ClientState.humanoid)
		local tool = findGunTool()
		if humanoid and tool then
			self._equippedAt = now
			humanoid:EquipTool(tool)
		end
		return
	end

	if not peek(ClientState.roundActive) then
		return
	end

	local origin = getShootOrigin()
	if not origin then
		return
	end

	local localTeam = peek(ClientState.team)

	for player, data in next, PlayerController.GetAll() do
		local target = data :: any
		if not target:IsAlive() then
			self._firedAt[player] = nil
			self._attempts[player] = nil
			continue
		end

		if peek(target.matchId) ~= localMatch or target:GetTeam() == localTeam then
			continue
		end

		local lastFired = self._firedAt[player]
		if lastFired and now - lastFired < RETRY_WINDOW then
			continue
		end

		local part = target:GetParts().Head or peek(target.hrp)
		if not part or not part:IsA("BasePart") then
			continue
		end

		local position = part.Position
		local attempts = (self._attempts[player] or 0) + 1
		self._firedAt[player] = now
		self._attempts[player] = attempts

		local shotOrigin = origin
		if attempts > 1 then
			local offset = origin - position
			local distance = offset.Magnitude
			if distance > CLOSE_ORIGIN_DISTANCE then
				shotOrigin = position + offset * (CLOSE_ORIGIN_DISTANCE / distance)
			end
		end

		WeaponController.FireShot(shotOrigin, position, part, position)
	end
end)

function Killall.Enable(self: Killall): ()
	if self._connection then
		return
	end

	self._connection = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
		step(self)
	end))
end

function Killall.Disable(self: Killall): ()
	if not self._connection then
		return
	end

	self._connection:Disconnect()
	self._connection = nil
	self._equippedAt = 0
	table.clear(self._firedAt)
	table.clear(self._attempts)
end

export type Killall =
	typeof(setmetatable(
		{} :: {
			_connection: RBXScriptConnection?,
			_firedAt: { [Player]: number },
			_attempts: { [Player]: number },
			_equippedAt: number,
		},
		Killall
	))
	& BaseFeature.BaseFeature

return Killall
