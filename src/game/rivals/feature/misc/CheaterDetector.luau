local RunService = cloneref(game:GetService("RunService")) :: RunService
local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local PlayerController = require("@feature/player/PlayerController")
local NotifyController = require("@ui/hud/notify/NotifyController")
local playerState = require("@feature/record/module/playerState")

local peek = Charm.peek

local LocalPlayer = Players.LocalPlayer

local SCAN_INTERVAL = 0.75
local VOID_COORD = 10000
local VOID_Y_MIN = -2000
local VOID_Y_MAX = 10000
local MAX_SPEED = 2000

local CheaterDetector = {}
CheaterDetector.__index = CheaterDetector

setmetatable(CheaterDetector, { __index = BaseFeature })

local function hasAction(list: any, name: string): boolean
	if type(list) ~= "table" then
		return false
	end
	for _, value in next, list do
		if value == name then
			return true
		end
	end
	return false
end

function CheaterDetector.new(link: gameUi.Linker): CheaterDetector
	local self = BaseFeature.new() :: any
	setmetatable(self, CheaterDetector)

	link:Toggle("enabled", "Cheater Detector", false):SetTip({
		title = "Cheater Detector",
		body = "Flags players doing physically impossible things: teleporting into the void or moving at impossible speed.",
	})
	local enabledLink = link:OnKey("enabled")
	enabledLink:Submenu("opts", "Cheater Detector")
	local optsLink = enabledLink:OnKey("opts")
	optsLink:Dropdown("actions", "On Detect", { "Notify", "Set Priority" }, { "Notify" }):SetMode("multi"):SetTip({
		title = "On Detect",
		body = "What happens when a cheater is detected. Notify pops a toast; Set Priority marks them as a ragebot/legitbot priority target.",
	})

	self._scanJanitor = Janitor.new()
	self._enabled = false
	self._actions = link:Get("enabled.opts.actions")
	self._flagged = {} :: { [number]: boolean }
	self._accum = 0

	self:Track(link:Get("enabled"):OnChange(function(value: boolean): ()
		self._enabled = value == true
		self:_syncScan()
	end))

	return self
end

function CheaterDetector._syncScan(self: CheaterDetector): ()
	self._scanJanitor:Cleanup()
	if not self._enabled then
		return
	end

	self._accum = 0
	table.clear(self._flagged)

	self._scanJanitor:Add(
		RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
			self._accum += dt
			if self._accum < SCAN_INTERVAL then
				return
			end
			self._accum = 0
			self:_scan()
		end)),
		"Disconnect"
	)

	self._scanJanitor:Add(
		PlayerController.playerRemoving:Connect(function(basePlayer: any): ()
			local rbxPlayer = basePlayer:GetPlayer()
			if rbxPlayer then
				self._flagged[rbxPlayer.UserId] = nil
			end
		end),
		"Disconnect"
	)
end

local detect = LPH_NO_VIRTUALIZE(function(basePlayer: any): string?
	if not peek(basePlayer.alive) then
		return nil
	end
	local hrp = peek(basePlayer.hrp) :: BasePart?
	if not hrp then
		return nil
	end
	local pos = hrp.Position
	if math.abs(pos.X) > VOID_COORD or math.abs(pos.Z) > VOID_COORD or pos.Y < VOID_Y_MIN or pos.Y > VOID_Y_MAX then
		return "void"
	end
	if hrp.AssemblyLinearVelocity.Magnitude > MAX_SPEED then
		return "speed"
	end
	return nil
end)

CheaterDetector._scan = function(self: CheaterDetector): ()
	local actions = peek(self._actions)
	local notify = hasAction(actions, "Notify")
	local setPriority = hasAction(actions, "Set Priority")
	if not notify and not setPriority then
		return
	end

	for _, basePlayer in next, PlayerController.GetAll() do
		local rbxPlayer = basePlayer:GetPlayer()
		if not rbxPlayer or rbxPlayer == LocalPlayer then
			continue
		end
		if self._flagged[rbxPlayer.UserId] then
			continue
		end
		local reason = detect(basePlayer)
		if not reason then
			continue
		end
		self._flagged[rbxPlayer.UserId] = true

		if setPriority then
			playerState.SetState(rbxPlayer.UserId, "priority")
		end
		if notify then
			NotifyController.Push({
				title = "Cheater Detected",
				subtext = `{rbxPlayer.DisplayName} — {reason}`,
				icon = "person",
				duration = 4,
			})
		end
	end
end

function CheaterDetector.Destroy(self: CheaterDetector): ()
	self._scanJanitor:Destroy()
	BaseFeature.Destroy(self)
end

export type CheaterDetector =
	typeof(setmetatable(
		{} :: {
			_scanJanitor: Janitor.Janitor,
			_enabled: boolean,
			_actions: any,
			_flagged: { [number]: boolean },
			_accum: number,
		},
		CheaterDetector
	))
	& BaseFeature.BaseFeature

return CheaterDetector
