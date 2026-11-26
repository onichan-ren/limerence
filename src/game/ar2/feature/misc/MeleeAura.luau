local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local NetworkController = require("@game/ar2/network/NetworkController")
local PlayerController = require("@feature/player/PlayerController")
local playerState = require("@feature/record/module/playerState")
local ZombieController = require("@game/ar2/zombie/ZombieController")
local clientState = require("@game/ar2/client/clientState")

local Players = cloneref(game:GetService("Players")) :: Players
local LocalPlayer = Players.LocalPlayer

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local peek = Charm.peek

local MeleeAura = {}
MeleeAura.__index = MeleeAura

setmetatable(MeleeAura, { __index = BaseFeature })

local sendPacket = LPH_NO_VIRTUALIZE(function(name: string, ...): ()
	local old = getthreadidentity()
	setthreadidentity(2)
	NetworkController.send(name, ...)
	setthreadidentity(old)
end)

local sendHit = LPH_NO_VIRTUALIZE(function(itemId: any, serverTime: number, origin: Vector3, part: BasePart): ()
	local hitPosition = part.Position
	local ray = Ray.new(origin, hitPosition - origin)
	local encoded = hitPosition * serverTime * part.Size
	sendPacket("Melee Hit Register", itemId, serverTime, ray, part, encoded)
end)

local _targetParts: { BasePart } = {}
local _targetDists: { number } = {}

local gatherTargets = LPH_NO_VIRTUALIZE(function(origin: Vector3, range: number): number
	local parts = _targetParts
	local dists = _targetDists
	table.clear(parts)
	table.clear(dists)
	local count = 0

	for _, playerData in next, PlayerController.GetAll() do
		if not peek(playerData.alive) then
			continue
		end
		local rbxPlayer = playerData:GetPlayer()
		if rbxPlayer == LocalPlayer or (rbxPlayer and playerState.ShouldSkip(rbxPlayer.UserId)) then
			continue
		end
		local hrp = peek(playerData.hrp) :: BasePart?
		if not hrp then
			continue
		end
		local distance = (hrp.Position - origin).Magnitude
		if distance <= range then
			count += 1
			parts[count] = hrp
			dists[count] = distance
		end
	end

	for zombie in next, ZombieController.GetZombies() do
		local hrp = zombie:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			continue
		end
		local humanoid = zombie:FindFirstChildWhichIsA("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			continue
		end
		local distance = (hrp.Position - origin).Magnitude
		if distance <= range then
			count += 1
			parts[count] = hrp
			dists[count] = distance
		end
	end

	return count
end)

local tick = LPH_NO_VIRTUALIZE(function(self: MeleeAura, arLocalPlayer: any): ()
	if not peek(clientState.alive) then
		return
	end

	local character = arLocalPlayer.Character
	if not character then
		return
	end

	local item = character.EquippedItem
	if not item or item.Type ~= "Melee" then
		return
	end

	local attackConfig = item.AttackConfig
	if not attackConfig or #attackConfig == 0 then
		return
	end

	local now = os.clock()
	if now - self._lastAttackAt < self._delay then
		return
	end

	local ourHrp = peek(clientState.hrp) :: BasePart?
	if not ourHrp then
		return
	end

	local origin = ourHrp.Position
	local count = gatherTargets(origin, self._range)
	if count == 0 then
		return
	end

	self._lastAttackAt = now

	local combo = self._comboIndex
	self._comboIndex = combo >= #attackConfig and 1 or combo + 1

	local attack = attackConfig[combo]
	local serverTime = Workspace:GetServerTimeNow()

	local old = getthreadidentity()
	setthreadidentity(2)

	NetworkController.send("Melee Swing", serverTime, item.Id, combo)

	if character.Animator then
		character.Animator:RunAction("Play Melee Animation", item.Name, combo)
	end

	if attack and attack.CanHitMultipleTargets then
		for index = 1, count do
			sendHit(item.Id, serverTime, origin, _targetParts[index])
		end
	else
		local nearestIndex = 1
		local nearestDist = _targetDists[1]
		for index = 2, count do
			if _targetDists[index] < nearestDist then
				nearestIndex = index
				nearestDist = _targetDists[index]
			end
		end
		sendHit(item.Id, serverTime, origin, _targetParts[nearestIndex])
	end

	setthreadidentity(old)
end)

function MeleeAura.new(link: gameUi.Linker): MeleeAura
	local self = BaseFeature.new() :: any
	setmetatable(self, MeleeAura)

	self._enabled = false
	self._range = 14
	self._delay = 0.4
	self._comboIndex = 1
	self._lastAttackAt = 0
	self._conn = nil :: RBXScriptConnection?

	link:Toggle("meleeAura", "Melee Aura", false):SetTip({
		title = "Melee Aura",
		body = "Automatically hits nearby players and zombies with your melee weapon.",
	})

	local masterLink = link:OnKey("meleeAura")
	masterLink:Submenu("opts", "Melee Aura")
	local optsLink = masterLink:OnKey("opts")

	optsLink:Slider("range", "Range", 14, 5, 20, 1, nil, "st"):SetTip({
		title = "Range",
		body = "How far around you targets get hit.",
	})
	optsLink:Slider("delay", "Hit Delay", 0.4, 0.2, 1, 0.05):SetTip({
		title = "Hit Delay",
		body = "Time between swings.",
	})

	self:Track(link:Watch("meleeAura.opts.range", function(v: any): ()
		self._range = tonumber(v) or 14
	end))
	self._range = tonumber(link:Peek("meleeAura.opts.range")) or 14

	self:Track(link:Watch("meleeAura.opts.delay", function(v: any): ()
		self._delay = tonumber(v) or 0.4
	end))
	self._delay = tonumber(link:Peek("meleeAura.opts.delay")) or 0.4

	self:Track(link:Get("meleeAura"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("meleeAura") then
		self:Enable()
	end

	return self
end

function MeleeAura.Enable(self: MeleeAura): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local playersModule = ModuleController.GetModule("LocalPlayer")
	if not playersModule then
		return
	end

	local arLocalPlayer = playersModule.module.get()

	self._comboIndex = 1
	self._lastAttackAt = 0

	self._conn = RunService.Heartbeat:Connect(function(): ()
		tick(self, arLocalPlayer)
	end)
end

function MeleeAura.Disable(self: MeleeAura): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
end

function MeleeAura.Destroy(self: MeleeAura): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type MeleeAura =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_range: number,
			_delay: number,
			_comboIndex: number,
			_lastAttackAt: number,
			_conn: RBXScriptConnection?,
		},
		MeleeAura
	))
	& BaseFeature.BaseFeature

return MeleeAura
