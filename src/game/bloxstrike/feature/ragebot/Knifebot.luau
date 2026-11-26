local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local PlayerController = require("@feature/player/PlayerController")
local ClientState = require("@game/bloxstrike/client/clientState")
local ClientController = require("@game/bloxstrike/client/ClientController")
local LoadoutState = require("@game/bloxstrike/loadout/loadoutState")
local NetworkController = require("@game/bloxstrike/network/NetworkController")
local gamemodeState = require("@game/bloxstrike/gamemodeState")
local hitboxParts = require("@game/universal/feature/combat/legitbot/hitboxParts")

local peek = Charm.peek

local HITBOX_PARTS = hitboxParts.HITBOX_PARTS

local HITBOX_PRIORITY: { string } = { "Head", "Torso", "Arms", "Legs", "Feet" }
local COMBO_PATTERN: { boolean } = { false, false, true }
local COMBO_RESET_TIME = 2
local BACKSTAB_ANGLE = 100
local HEAVY_RATE_MULTIPLIER = 2.05
local SPHERECAST_RADIUS = 1.5
local AURA_RANGE = 14

local isBehind = LPH_NO_VIRTUALIZE(function(localHrp: BasePart, targetHrp: BasePart): boolean
	local toAttacker = localHrp.Position - targetHrp.Position
	local mag = toAttacker.Magnitude
	if mag < 1e-4 then
		return false
	end
	local dot = targetHrp.CFrame.LookVector:Dot(toAttacker / mag)
	return math.deg(math.acos(math.clamp(dot, -1, 1))) > BACKSTAB_ANGLE
end)

local closestPointOnPart = LPH_NO_VIRTUALIZE(function(part: BasePart, point: Vector3): Vector3
	local cf = part.CFrame
	local halfSize = part.Size * 0.5
	local localPoint = cf:PointToObjectSpace(point)
	return cf:PointToWorldSpace(
		Vector3.new(
			math.clamp(localPoint.X, -halfSize.X, halfSize.X),
			math.clamp(localPoint.Y, -halfSize.Y, halfSize.Y),
			math.clamp(localPoint.Z, -halfSize.Z, halfSize.Z)
		)
	)
end)

local Knifebot = {}
Knifebot.__index = Knifebot

setmetatable(Knifebot, { __index = BaseFeature })

function Knifebot.new(link: gameUi.Linker, opts: { auraLink: gameUi.Linker }): Knifebot
	local self = BaseFeature.new() :: any
	setmetatable(self, Knifebot)

	local auraLink = opts.auraLink

	link:Toggle("knifeBot", "Knife Bot", false):SetTip({
		title = "Knife Bot",
		body = "Automatically swings at enemies your crosshair can reach, with the best swing for the kill.",
	})
	auraLink:Toggle("knifeAura", "Knife Aura", false):SetTip({
		title = "Knife Aura",
		body = "Instantly attacks any enemy in range around you.",
	})

	self._botEnabled = false
	self._auraEnabled = false
	self._comboIndex = 1
	self._comboTarget = nil
	self._lastAttackAt = 0
	self._lastAttackDelay = 0
	self._tickConn = nil :: RBXScriptConnection?

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true
	self._raycastParams = raycastParams
	self._raycastFilter = {} :: { Instance }
	self._debris = Workspace:FindFirstChild("Debris")

	self:Track(link:Get("knifeBot"):OnChange(function(value: boolean): ()
		self._botEnabled = value == true
		self:_setActive(self._botEnabled or self._auraEnabled)
	end))

	self:Track(auraLink:Get("knifeAura"):OnChange(function(value: boolean): ()
		self._auraEnabled = value == true
		self:_setActive(self._botEnabled or self._auraEnabled)
	end))

	self._botEnabled = link:Peek("knifeBot") == true
	self._auraEnabled = auraLink:Peek("knifeAura") == true
	if self._botEnabled or self._auraEnabled then
		self:_setActive(true)
	end

	return self
end

function Knifebot._setActive(self: Knifebot, active: boolean): ()
	if active then
		if not self._tickConn then
			self._comboIndex = 1
			self._comboTarget = nil
			self._lastAttackAt = 0
			self._lastAttackDelay = 0
			self._tickConn = RunService.Heartbeat:Connect(function(): ()
				self:_tick()
			end)
		end
	else
		if self._tickConn then
			self._tickConn:Disconnect()
			self._tickConn = nil
		end
	end
end

function Knifebot._refreshFilter(self: Knifebot, character: Model?): ()
	local filter = self._raycastFilter
	table.clear(filter)
	local localCharacter = peek(ClientState.character)
	if localCharacter then
		filter[#filter + 1] = localCharacter
	end
	local camera = Workspace.CurrentCamera
	if camera then
		filter[#filter + 1] = camera
	end
	local debris = self._debris
	if debris then
		filter[#filter + 1] = debris
	end
	if character then
		filter[#filter + 1] = character
	end
	self._raycastParams.FilterDescendantsInstances = filter
end

Knifebot._isEnemy = LPH_NO_VIRTUALIZE(function(self: Knifebot, playerData: any, isDeathmatch: boolean, localTeam: any): boolean
	if not peek(playerData.alive) then
		return false
	end
	if peek(playerData.invincible) then
		return false
	end
	if not isDeathmatch then
		local playerTeam = peek(playerData.team)
		if localTeam and localTeam ~= "" and playerTeam == localTeam then
			return false
		end
	end
	return true
end)

Knifebot._resolveEnemy = LPH_NO_VIRTUALIZE(function(self: Knifebot, instance: Instance): any?
	local parent = instance.Parent
	if not parent then
		return nil
	end
	local isDeathmatch = gamemodeState.isDeathmatch()
	local localTeam = ClientController.GetTeam()
	for _, playerData in next, PlayerController.GetAll() do
		local character = peek(playerData.character)
		if not character then
			continue
		end
		if character ~= parent and not instance:IsDescendantOf(character) then
			continue
		end
		if self:_isEnemy(playerData, isDeathmatch, localTeam) then
			return playerData
		end
		return nil
	end
	return nil
end)

function Knifebot._isBehindTarget(self: Knifebot, target: any): boolean
	local localHrp = peek(ClientState.parts).HumanoidRootPart :: BasePart?
	local targetHrp = peek(target.hrp) :: BasePart?
	if not localHrp or not targetHrp then
		return false
	end
	return isBehind(localHrp, targetHrp)
end

function Knifebot._nextAttack(self: Knifebot, target: any, behind: boolean): boolean
	local now = tick()
	if target ~= self._comboTarget or now - self._lastAttackAt > COMBO_RESET_TIME then
		self._comboIndex = 1
		self._comboTarget = target
	end
	if behind then
		return true
	end
	return COMBO_PATTERN[self._comboIndex] == true
end

function Knifebot._advanceCombo(self: Knifebot, heavy: boolean, fireRate: number): ()
	self._lastAttackAt = tick()
	self._lastAttackDelay = fireRate * (heavy and HEAVY_RATE_MULTIPLIER or 1)
	if heavy or self._comboIndex >= #COMBO_PATTERN then
		self._comboIndex = 1
	else
		self._comboIndex += 1
	end
end

function Knifebot._playAttackVisuals(self: Knifebot, weapon: any, attackName: string): ()
	local viewmodel = weapon.Viewmodel
	if viewmodel and viewmodel.Animation then
		viewmodel.Animation:play(attackName)
	end
	local animator = weapon.CharacterAnimator
	if animator then
		animator:play((attackName == "Swing1" or attackName == "Swing") and "Swing" or attackName)
	end
end

Knifebot._legitTick = LPH_NO_VIRTUALIZE(function(self: Knifebot, weapon: any): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local range = weapon.Properties.Range or 3
	local cameraCF = camera.CFrame
	local origin = cameraCF.Position
	local direction = cameraCF.LookVector * range

	self:_refreshFilter(nil)
	local result = Workspace:Raycast(origin, direction, self._raycastParams)
	if not result then
		result = Workspace:Spherecast(origin, SPHERECAST_RADIUS, direction, self._raycastParams)
	end
	if not result then
		return
	end

	local target = self:_resolveEnemy(result.Instance)
	if not target then
		return
	end

	local behind = self:_isBehindTarget(target)
	local heavy = self:_nextAttack(target, behind)
	local shoot = weapon.shoot
	if type(shoot) ~= "function" then
		return
	end

	setthreadidentity(2)
	shoot(weapon, heavy)
	setthreadidentity(8)

	self:_advanceCombo(heavy, weapon.Properties.FireRate)
end)

Knifebot._rageTick = LPH_NO_VIRTUALIZE(function(self: Knifebot, weapon: any): ()
	local now = tick()
	if now - self._lastAttackAt < self._lastAttackDelay then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local props = weapon.Properties
	local weaponRange = props.Range or 3
	local range = AURA_RANGE
	local camCF = camera.CFrame
	local origin = camCF.Position
	local roughRange = range + 8

	local bestTarget: any? = nil
	local bestPart: BasePart? = nil
	local bestPoint = Vector3.zero
	local bestDistance = math.huge

	local isDeathmatch = gamemodeState.isDeathmatch()
	local localTeam = ClientController.GetTeam()

	for _, playerData in next, PlayerController.GetAll() do
		if not self:_isEnemy(playerData, isDeathmatch, localTeam) then
			continue
		end
		local character = peek(playerData.character)
		if not character then
			continue
		end
		local hrp = peek(playerData.hrp) :: BasePart?
		if not hrp or (hrp.Position - origin).Magnitude > roughRange then
			continue
		end

		local parts = peek(playerData.parts)
		for _, hitboxName in next, HITBOX_PRIORITY do
			local found = false
			for _, partName in next, HITBOX_PARTS[hitboxName] do
				local part = parts[partName] :: BasePart?
				if not part then
					continue
				end
				local point = closestPointOnPart(part, origin)
				local distance = (point - origin).Magnitude
				if distance > range or distance >= bestDistance then
					continue
				end
				bestTarget = playerData
				bestPart = part
				bestPoint = point
				bestDistance = distance
				found = true
			end
			if found then
				break
			end
		end
	end

	if not bestTarget or not bestPart then
		return
	end

	local behind = self:_isBehindTarget(bestTarget)
	local heavy = self:_nextAttack(bestTarget, behind)

	local delta = bestPoint - origin
	local mag = delta.Magnitude
	local unit = mag > 1e-4 and delta / mag or camCF.LookVector

	local swingBase = heavy and "Heavy Swing" or "Swing" .. math.random(1, 2)
	local attackName = (heavy and behind) and "BackStab" or swingBase

	self:_playAttackVisuals(weapon, attackName)

	setthreadidentity(2)
	NetworkController.SendPacket("Spectate", "ReplicateSpectateEvent", swingBase)
	NetworkController.SendPacket("Melee", "MeleeAttack", {
		Direction = unit * weaponRange,
		Material = bestPart.Material.Name,
		Distance = mag,
		Instance = bestPart,
		Position = bestPoint,
		Normal = -unit,
		MeleeAttack = attackName,
		Identifier = weapon.Identifier,
	})
	setthreadidentity(8)

	self:_advanceCombo(heavy, props.FireRate)
end)

Knifebot._tick = LPH_NO_VIRTUALIZE(function(self: Knifebot): ()
	if not peek(ClientState.alive) then
		return
	end

	local weapon = peek(LoadoutState.currentEquipped) :: any
	if not weapon then
		return
	end
	local props = weapon.Properties
	if not props or props.Class ~= "Melee" or not props.FireRate then
		return
	end
	if weapon.IsShooting then
		return
	end
	if tick() - (weapon.WeaponEquippedTick or 0) <= 1 then
		return
	end

	if self._auraEnabled then
		self:_rageTick(weapon)
	elseif self._botEnabled then
		self:_legitTick(weapon)
	end
end)

function Knifebot.Destroy(self: Knifebot): ()
	self:_setActive(false)
	BaseFeature.Destroy(self)
end

export type Knifebot =
	typeof(setmetatable(
		{} :: {
			_botEnabled: boolean,
			_auraEnabled: boolean,
			_comboIndex: number,
			_comboTarget: any?,
			_lastAttackAt: number,
			_lastAttackDelay: number,
			_tickConn: RBXScriptConnection?,
			_raycastParams: RaycastParams,
			_raycastFilter: { Instance },
			_debris: Instance?,
		},
		Knifebot
	))
	& BaseFeature.BaseFeature

return Knifebot
