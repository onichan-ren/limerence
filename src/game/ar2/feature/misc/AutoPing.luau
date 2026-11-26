local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local NetworkController = require("@game/ar2/network/NetworkController")
local PlayerController = require("@feature/player/PlayerController")
local playerState = require("@feature/record/module/playerState")
local clientState = require("@game/ar2/client/clientState")
local worldRaycast = require("@game/ar2/weapon/worldRaycast")
local legitbotApi = require("@game/universal/feature/combat/legitbot/legitbotApi")
local ragebotState = require("@game/ar2/feature/ragebot/ragebotState")

local Players = cloneref(game:GetService("Players")) :: Players
local LocalPlayer = Players.LocalPlayer

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local peek = Charm.peek

local AutoPing = {}
AutoPing.__index = AutoPing

setmetatable(AutoPing, { __index = BaseFeature })

local sendPing = LPH_NO_VIRTUALIZE(function(index: any, position: Vector3): ()
	local old = getthreadidentity()
	setthreadidentity(2)
	NetworkController.send("Set World Ping", index, position, nil)
	setthreadidentity(old)
end)

local clearPing = LPH_NO_VIRTUALIZE(function(): ()
	local old = getthreadidentity()
	setthreadidentity(2)
	NetworkController.send("Clear World Ping")
	setthreadidentity(old)
end)

local function getTargetPlayer(): Player?
	local player = peek(legitbotApi.state.activeTarget)
	if player then
		return player
	end
	player = peek(legitbotApi.state.triggerTarget)
	if player then
		return player
	end
	return peek(ragebotState.currentTarget)
end

local findHrp = LPH_NO_VIRTUALIZE(function(player: Player): BasePart?
	for _, playerData in next, PlayerController.GetAll() do
		if playerData:GetPlayer() == player and peek(playerData.alive) then
			return peek(playerData.hrp) :: BasePart?
		end
	end
	return nil
end)

local findNearest = LPH_NO_VIRTUALIZE(function(origin: Vector3, maxDistanceSq: number): BasePart?
	local best: BasePart? = nil
	local bestDistSq = math.huge
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
		local offset = hrp.Position - origin
		local distSq = offset:Dot(offset)
		if maxDistanceSq > 0 and distSq > maxDistanceSq then
			continue
		end
		if distSq < bestDistSq then
			bestDistSq = distSq
			best = hrp
		end
	end
	return best
end)

local tick = LPH_NO_VIRTUALIZE(function(self: AutoPing): ()
	local now = os.clock()
	if now - self._lastPingAt < self._interval then
		return
	end

	local getter = self._localPlayer and self._localPlayer.get
	local arLocalPlayer = getter and getter()
	local character = arLocalPlayer and arLocalPlayer.Character
	self._pingIndex = (character and (character.DefaultPingIndex or character.LastPingIndex)) or 1

	local ourHrp = peek(clientState.hrp) :: BasePart?
	if not peek(clientState.alive) or not ourHrp then
		return
	end
	local origin = ourHrp.Position
	local maxDistanceSq = self._maxDistanceSq

	local targetHrp: BasePart? = nil
	if self._onlyTarget then
		local player = getTargetPlayer()
		if player and not playerState.ShouldSkip(player.UserId) then
			local hrp = findHrp(player)
			if hrp then
				local offset = hrp.Position - origin
				if maxDistanceSq <= 0 or offset:Dot(offset) <= maxDistanceSq then
					targetHrp = hrp
				end
			end
		end
	else
		targetHrp = findNearest(origin, maxDistanceSq)
	end

	if not targetHrp then
		if self._pinged then
			self._pinged = false
			clearPing()
		end
		return
	end

	if self._visibleOnly then
		local ignore = self._ignore
		table.clear(ignore)
		local localChar = peek(clientState.character)
		if localChar then
			ignore[#ignore + 1] = localChar
		end
		local targetChar = targetHrp.Parent
		if targetChar then
			ignore[#ignore + 1] = targetChar
		end
		if self._effects then
			ignore[#ignore + 1] = self._effects
		end
		if not worldRaycast.clearLineOfSight(origin, targetHrp.Position, ignore) then
			return
		end
	end

	self._lastPingAt = now
	self._pinged = true
	sendPing(self._pingIndex, targetHrp.Position)
end)

function AutoPing.new(link: gameUi.Linker): AutoPing
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoPing)

	self._enabled = false
	self._onlyTarget = false
	self._visibleOnly = false
	self._interval = 1.5
	self._maxDistanceSq = 500 * 500
	self._pingIndex = 1
	self._lastPingAt = 0
	self._pinged = false
	self._ignore = {} :: { Instance }
	self._effects = nil :: Instance?
	self._localPlayer = nil :: any
	self._conn = nil :: RBXScriptConnection?

	link:Toggle("autoPing", "Auto Ping Enemies", false):SetTip({
		title = "Auto Ping Enemies",
		body = "Automatically pings enemies so your team can see them.",
	})

	local masterLink = link:OnKey("autoPing")
	masterLink:Submenu("opts", "Auto Ping Enemies")
	local optsLink = masterLink:OnKey("opts")

	optsLink:Toggle("onlyTarget", "Only Aimbot Target", false):SetTip({
		title = "Only Aimbot Target",
		body = "Only pings the enemy your aimbot is locked onto, instead of the nearest one.",
	})
	optsLink:Toggle("visibleOnly", "Visible Only", false):SetTip({
		title = "Visible Only",
		body = "Only pings enemies you have line of sight to.",
	})
	optsLink:Slider("maxDistance", "Max Distance", 500, 0, 2000, 10, nil, "st"):SetTip({
		title = "Max Distance",
		body = "Ignores enemies farther away than this. 0 means no limit.",
	})
	optsLink:Slider("interval", "Ping Interval", 1.5, 0.2, 5, 0.1, nil, "s"):SetTip({
		title = "Ping Interval",
		body = "Time between pings.",
	})

	self:Track(link:Watch("autoPing.opts.onlyTarget", function(v: any): ()
		self._onlyTarget = v == true
	end))
	self._onlyTarget = link:Peek("autoPing.opts.onlyTarget") == true

	self:Track(link:Watch("autoPing.opts.visibleOnly", function(v: any): ()
		self._visibleOnly = v == true
	end))
	self._visibleOnly = link:Peek("autoPing.opts.visibleOnly") == true

	self:Track(link:Watch("autoPing.opts.maxDistance", function(v: any): ()
		local d = tonumber(v) or 0
		self._maxDistanceSq = d * d
	end))
	local initDistance = tonumber(link:Peek("autoPing.opts.maxDistance")) or 500
	self._maxDistanceSq = initDistance * initDistance

	self:Track(link:Watch("autoPing.opts.interval", function(v: any): ()
		self._interval = tonumber(v) or 1.5
	end))
	self._interval = tonumber(link:Peek("autoPing.opts.interval")) or 1.5

	self:Track(link:Get("autoPing"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("autoPing") then
		self:Enable()
	end

	return self
end

function AutoPing.Enable(self: AutoPing): ()
	if self._enabled then
		return
	end
	self._enabled = true

	if not self._localPlayer then
		local module = ModuleController.GetModule("LocalPlayer")
		self._localPlayer = module and module.module
	end
	self._effects = Workspace:FindFirstChild("Effects")
	self._lastPingAt = 0
	self._pinged = false

	self._conn = RunService.Heartbeat:Connect(function(): ()
		tick(self)
	end)
end

function AutoPing.Disable(self: AutoPing): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	if self._pinged then
		self._pinged = false
		clearPing()
	end
end

function AutoPing.Destroy(self: AutoPing): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoPing =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_onlyTarget: boolean,
			_visibleOnly: boolean,
			_interval: number,
			_maxDistanceSq: number,
			_pingIndex: any,
			_lastPingAt: number,
			_pinged: boolean,
			_ignore: { Instance },
			_effects: Instance?,
			_localPlayer: any,
			_conn: RBXScriptConnection?,
		},
		AutoPing
	))
	& BaseFeature.BaseFeature

return AutoPing
