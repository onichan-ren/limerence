local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local RunService = cloneref(game:GetService("RunService")) :: RunService

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local ModuleController = require("@game/pf/module/ModuleController")
local WeaponController = require("@game/pf/weapon/WeaponController")
local NetworkController = require("@game/pf/network/NetworkController")

local targetScratch: { [Player]: Vector3 } = {}

local KnifeAura = {}
KnifeAura.__index = KnifeAura

setmetatable(KnifeAura, { __index = BaseFeature })

function KnifeAura.new(link: gameUi.Linker): KnifeAura
	local self = BaseFeature.new() :: any
	setmetatable(self, KnifeAura)

	link:Toggle("knifeAura", "Knife Aura", false):SetTip({
		title = "Knife Aura",
		body = "Auto melees nearby enemies while a knife is out.",
	})
	local auraLink = link:OnKey("knifeAura")
	auraLink:Submenu("opts", "Knife Aura")
	local optsLink = auraLink:OnKey("opts")
	optsLink:Slider("range", "Range", 14, 1, 20, 1, nil, "st"):SetTip({
		title = "Range",
		body = "Maximum distance an enemy can be hit from.",
	})
	optsLink:Toggle("backstab", "Always Backstab", true):SetTip({
		title = "Always Backstab",
		body = "Makes knife hits register as backstabs for bonus damage.",
	})

	self._enabled = false
	self._janitor = Janitor.new()
	self._repl = nil :: any
	self._entries = nil :: any
	self._clock = nil :: any
	self._backstab = true

	self._range = link:Peek("knifeAura.opts.range") or 14
	self._backstab = link:Peek("knifeAura.opts.backstab") ~= false

	self:Track(link:Get("knifeAura"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))
	self:Track(link:Watch("knifeAura.opts.range", function(value: number): ()
		self._range = type(value) == "number" and value or 14
	end))
	self:Track(link:Watch("knifeAura.opts.backstab", function(value: boolean): ()
		self._backstab = value ~= false
	end))

	if link:Peek("knifeAura") then
		self:Enable()
	end

	return self
end

KnifeAura._step = LPH_NO_VIRTUALIZE(function(self: KnifeAura): ()
	local repl = self._repl
	if not repl then
		return
	end
	local weapon = WeaponController.GetWeapon()

	if not weapon then
		return
	end

	if WeaponController.GetWeaponType() ~= "Melee" then
		return
	end

	if not weapon:canMelee() then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local camPos = camera.CFrame.Position
	local range = self._range

	local entries = self._entries
	if not entries then
		return
	end

	local targets = targetScratch
	table.clear(targets)
	for player, entry in next, entries do
		if not entry:isAlive() or not entry:isEnemy() then
			continue
		end
		local position = entry:getPosition()
		if typeof(position) ~= "Vector3" or (position - camPos).Magnitude > range then
			continue
		end
		local tpo = entry:getThirdPersonObject()
		local hash = tpo and tpo:getCharacterHash()
		local part = hash and (hash.Head or hash.Torso)
		if not part then
			continue
		end
		targets[player] = part.Position
	end

	if not next(targets) then
		return
	end

	local clock = self._clock
	local time = clock and clock.getTime() or os.clock()

	for player, partPos in next, targets do
		NetworkController.Send("knifehit", player, "Head", partPos, time)
	end
end)

KnifeAura._backstabYaw = LPH_NO_VIRTUALIZE(function(self: KnifeAura, fromPos: Vector3): number?
	local entries = self._entries
	if not entries then
		return nil
	end
	local range = self._range
	local bestDistSq = range * range
	local bestYaw: number? = nil
	for _, entry in next, entries do
		if not entry:isAlive() or not entry:isEnemy() then
			continue
		end
		local position = entry:getPosition()
		if typeof(position) ~= "Vector3" then
			continue
		end
		local dx = position.X - fromPos.X
		local dy = position.Y - fromPos.Y
		local dz = position.Z - fromPos.Z
		local distSq = dx * dx + dy * dy + dz * dz
		if distSq > bestDistSq then
			continue
		end
		local tpo = entry:getThirdPersonObject()
		local hash = tpo and tpo:getCharacterHash()
		local part = hash and (hash.Torso or hash.UpperTorso or hash.HumanoidRootPart or hash.Head)
		if not part then
			continue
		end
		local look = part.CFrame.LookVector
		bestDistSq = distSq
		bestYaw = math.atan2(-look.X, -look.Z)
	end
	return bestYaw
end)

function KnifeAura.Enable(self: KnifeAura): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._repl = ModuleController.GetModule("ReplicationInterface")
	self._clock = ModuleController.GetModule("GameClock")
	local entries = debug.getupvalue(self._repl.operateOnAllEntries, 1)
	self._entries = type(entries) == "table" and entries or nil

	self._janitor:Add(
		NetworkController.HookOutbound(
			"knifehit",
			LPH_NO_VIRTUALIZE(function(): boolean
				return false
			end)
		),
		true
	)

	self._janitor:Add(
		NetworkController.HookOutbound(
			"repupdate",
			LPH_NO_VIRTUALIZE(function(position: any, lookAngles: any, barrelAngles: any, time: any): (boolean?, { any }?)
				if not self._backstab then
					return
				end
				if typeof(lookAngles) ~= "Vector3" or typeof(position) ~= "Vector3" then
					return
				end
				if WeaponController.GetWeaponType() ~= "Melee" then
					return
				end
				local yaw = self:_backstabYaw(position)
				if not yaw then
					return
				end
				local newLook = Vector3.new(lookAngles.X, yaw, 0)
				local newBarrel = typeof(barrelAngles) == "Vector3" and Vector3.new(barrelAngles.X, yaw, 0) or newLook
				return false, { position, newLook, newBarrel, time }
			end)
		),
		true
	)

	self._janitor:Add(
		RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
			self:_step()
		end)),
		"Disconnect"
	)
end

function KnifeAura.Disable(self: KnifeAura): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
	self._repl = nil
	self._entries = nil
	self._clock = nil
end

function KnifeAura.Destroy(self: KnifeAura): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type KnifeAura =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_repl: any,
			_entries: any,
			_clock: any,
			_range: number,
			_backstab: boolean,
			_step: (KnifeAura) -> (),
			_backstabYaw: (KnifeAura, Vector3) -> number?,
		},
		KnifeAura
	))
	& BaseFeature.BaseFeature

return KnifeAura
