local Players = cloneref(game:GetService("Players")) :: Players
local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ClientState = require("@game/rivals/client/clientState")
local PlayerController = require("@feature/player/PlayerController")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local mapWhitelist = require("@game/rivals/feature/combat/legitbot/mapWhitelist")
local sessionState = require("@feature/session/sessionState")

local LocalPlayer = Players.LocalPlayer
local peek = Charm.peek
local sub = Charm.subscribe
local now = tick

local CHECK_INTERVAL = 0.05
local QUICK_MELEE_COOLDOWN = 0.35
local MODE_ON_HURT = "On Hurt"
local MODE_PREDICTIVE = "Predictive"
local MODES: { string } = { MODE_ON_HURT, MODE_PREDICTIVE }

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include

-- True when nothing on the map sits between the two points.
local function hasLineOfSight(from: Vector3, to: Vector3): boolean
	raycastParams.FilterDescendantsInstances = mapWhitelist.get()
	return workspace:Raycast(from, to - from, raycastParams) == nil
end

local AutoDeflect = {}
AutoDeflect.__index = AutoDeflect

setmetatable(AutoDeflect, { __index = BaseFeature })

function AutoDeflect.new(link: gameUi.Linker): AutoDeflect
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoDeflect)

	local toggle = link:Toggle("autoDeflect", "Auto Deflect", false):SetTip({
		title = "Auto Deflect",
		body = "Auto-blocks with a sword to stop incoming hits.",
	})
	local deflectLink = link:OnKey("autoDeflect")
	deflectLink:Submenu("opts", "Auto Deflect Options")
	local optsLink = deflectLink:OnKey("opts")

	optsLink:Dropdown("mode", "Mode", MODES, MODE_ON_HURT):SetTip({
		title = "Mode",
		body = "On Hurt blocks right after you take damage. Predictive blocks when an enemy lines up a shot on you.",
	})
	optsLink:Slider("hpThreshold", "HP Threshold", 100, 1, 150, 1, nil, "hp"):SetTip({
		title = "HP Threshold",
		body = "On Hurt only blocks when your health is at or below this.",
	})
	optsLink:Slider("range", "Range", 60, 5, 150, 1, nil, "st"):SetTip({
		title = "Range",
		body = "Predictive only reacts to enemies within this distance.",
	})
	optsLink:Slider("aimAngle", "Aim Angle", 12, 1, 60, 1, nil, "°"):SetTip({
		title = "Aim Angle",
		body = "Predictive blocks when an enemy aim is within this angle of you. Lower is stricter.",
	})
	optsLink
		:Slider("delay", "Reaction Delay", 0, 0, 500, 5, nil, "ms")
		:SetTip({
			title = "Reaction Delay",
			body = "Predictive waits this long before blocking. Auto matches your ping.",
		})
		:SetValueTextOverrides({ [0] = "Auto" })

	self._enabled = false
	self._mode = optsLink:Get("mode"):Peek() or MODE_ON_HURT
	self._hpThreshold = optsLink:Get("hpThreshold"):Peek()
	self._range = optsLink:Get("range"):Peek()
	self._aimAngleCos = math.cos(math.rad(optsLink:Get("aimAngle"):Peek()))
	self._delayMs = optsLink:Get("delay"):Peek()
	self._accum = 0
	self._threatSince = nil :: number?
	self._lastQuickMelee = 0
	self._lastHealth = peek(ClientState.health)
	self._conn = nil :: RBXScriptConnection?

	self:Track(toggle:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optsLink:Get("mode"):OnChange(function(value: string): ()
		self._mode = value or MODE_ON_HURT
	end))
	self:Track(optsLink:Get("hpThreshold"):OnChange(function(value: number): ()
		self._hpThreshold = value
	end))
	self:Track(optsLink:Get("range"):OnChange(function(value: number): ()
		self._range = value
	end))
	self:Track(optsLink:Get("aimAngle"):OnChange(function(value: number): ()
		self._aimAngleCos = math.cos(math.rad(value))
	end))
	self:Track(optsLink:Get("delay"):OnChange(function(value: number): ()
		self._delayMs = value
	end))

	self:Track(sub(ClientState.health, function(health: number): ()
		self:_onHealth(health)
	end))

	return self
end

-- Block with the equipped sword, or quick-swing the melee when it is not in hand.
function AutoDeflect._react(self: AutoDeflect): boolean
	if not peek(ClientState.alive) then
		return false
	end

	local fighter = WeaponController.GetLocalFighter()
	local item = fighter and fighter.EquippedItem
	local info = type(item) == "table" and item.Info or nil

	if type(info) == "table" and info.DeflectDuration ~= nil then
		if now() < (item._deflect_cooldown or 0) then
			return false
		end
		return WeaponController.Deflect()
	end

	if now() - self._lastQuickMelee < QUICK_MELEE_COOLDOWN then
		return false
	end
	self._lastQuickMelee = now()
	return WeaponController.QuickMelee()
end

function AutoDeflect._onHealth(self: AutoDeflect, health: number): ()
	local last = self._lastHealth
	self._lastHealth = health

	if not self._enabled or self._mode ~= MODE_ON_HURT then
		return
	end
	if health <= 0 or health >= last then
		return
	end
	if health > self._hpThreshold then
		return
	end
	self:_react()
end

function AutoDeflect._step(self: AutoDeflect, dt: number): ()
	self._accum += dt
	if self._accum < CHECK_INTERVAL then
		return
	end
	self._accum = 0

	if self._mode ~= MODE_PREDICTIVE then
		self._threatSince = nil
		return
	end
	if not peek(ClientState.alive) then
		self._threatSince = nil
		return
	end

	local hrp = peek(ClientState.hrp)
	if not hrp then
		self._threatSince = nil
		return
	end

	local origin = hrp.Position
	local team = peek(ClientState.team)
	local range = self._range
	local minCos = self._aimAngleCos

	local threat = false
	for player, basePlayer in next, PlayerController.GetAll() do
		if player == LocalPlayer or not peek(basePlayer.alive) then
			continue
		end
		if team ~= "" and peek(basePlayer.team) == team then
			continue
		end
		local enemyHrp = peek(basePlayer.hrp)
		if not enemyHrp then
			continue
		end

		local enemyPos = enemyHrp.Position
		local dx = origin.X - enemyPos.X
		local dz = origin.Z - enemyPos.Z
		local dist = math.sqrt(dx * dx + dz * dz)
		if dist > range or dist < 0.1 then
			continue
		end

		local look = enemyHrp.CFrame.LookVector
		local lx = look.X
		local lz = look.Z
		local lookMag = math.sqrt(lx * lx + lz * lz)
		if lookMag < 1e-4 then
			continue
		end
		if (lx * dx + lz * dz) / (lookMag * dist) < minCos then
			continue
		end

		-- Scoped weapons only threaten while the enemy is aimed in.
		local equipped = peek(basePlayer.currentEquipped)
		if equipped and equipped.hasScope and not peek(basePlayer.isAiming) then
			continue
		end

		-- Skip enemies that have no line of sight to us.
		if not hasLineOfSight(enemyPos, origin) then
			continue
		end

		threat = true
		break
	end

	if not threat then
		self._threatSince = nil
		return
	end

	local since = self._threatSince
	if not since then
		since = now()
		self._threatSince = since
	end

	local delaySec = self._delayMs > 0 and self._delayMs / 1000 or peek(sessionState.ping) / 2 / 1000
	if now() - since >= delaySec and self:_react() then
		self._threatSince = nil
	end
end

function AutoDeflect.Enable(self: AutoDeflect): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._accum = 0
	self._threatSince = nil
	self._lastHealth = peek(ClientState.health)
	self._conn = RunService.Heartbeat:Connect(function(dt: number): ()
		self:_step(dt)
	end)
end

function AutoDeflect.Disable(self: AutoDeflect): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._threatSince = nil
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
end

function AutoDeflect.Destroy(self: AutoDeflect): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoDeflect =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_mode: string,
			_hpThreshold: number,
			_range: number,
			_aimAngleCos: number,
			_delayMs: number,
			_accum: number,
			_threatSince: number?,
			_lastQuickMelee: number,
			_lastHealth: number,
			_conn: RBXScriptConnection?,
		},
		AutoDeflect
	))
	& BaseFeature.BaseFeature

return AutoDeflect
