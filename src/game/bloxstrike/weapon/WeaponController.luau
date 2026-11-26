local NetworkController = require("@game/bloxstrike/network/NetworkController")
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local PlayerController = require("@feature/player/PlayerController")
local ClientController = require("@game/bloxstrike/client/ClientController")
local ClientState = require("@game/bloxstrike/client/clientState")
local gamemodeState = require("@game/bloxstrike/gamemodeState")
local fakeShoot = require("@game/bloxstrike/weapon/fakeShoot")
local hook = require("@share/hook")
local Charm = require("@pkg/Charm")
local Players = cloneref(game:GetService("Players")) :: Players
local RunService = cloneref(game:GetService("RunService")) :: RunService
local Signal = require("@pkg/Signal")

local peek = Charm.peek

local WeaponController = {
	hitPlayer = Signal.new() :: Signal.Signal<Player, Instance>,
	killedPlayer = Signal.new() :: Signal.Signal<Player, Vector3?>,
	bulletCreated = Signal.new() :: Signal.Signal<BulletData>,
	shotFired = Signal.new() :: Signal.Signal<ShootData, Player?, Player?>,
	serverHitConfirmed = Signal.new() :: Signal.Signal<Player?, BasePart?>,
	_ragebotShotTarget = nil :: Player?,
	observedShot = Signal.new() :: Signal.Signal<Player, Vector3, Vector3, number>,
	_getWeaponProperties = nil :: ((any) -> any?)?,
	_impactCallbacks = {} :: { (BasePart) -> BasePart },
	_shootTransforms = {} :: { (any) -> () },
	_shoot = nil :: ((any, any?) -> ())?,
	_impactFn = nil :: ((...any) -> ())?,
	_suppressImpacts = false,
	_vfxDisconnects = {} :: { () -> () },
	_frameConn = nil :: RBXScriptConnection?,
	_killFeedUnsub = nil :: (() -> ())?,
}

local LocalPlayer = Players.LocalPlayer

local MUZZLE_QUEUE_TTL = 0.25

local hitFireFrames = setmetatable({}, { __mode = "k" }) :: { [Instance]: number }
local currentFrame = 0

type MuzzleEntry = { name: string, time: number }

WeaponController.new = LPH_JIT_MAX(function(): WeaponController
	local weaponClass = ModuleController.GetModule("WeaponClass")

	local shoot = rawget(weaponClass, "shoot")

	if not shoot or type(shoot) ~= "function" then
		error("failed to find shoot function")
	end

	WeaponController._shoot = shoot
	fakeShoot.bind(shoot)

	WeaponController._frameConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
		currentFrame += 1
	end))

	local impact: any = nil
	for _, value in next, debug.getupvalues(shoot) do
		if type(value) == "function" then
			local info = debug.getinfo(value)
			if info and info.name == "CreateImpact" then
				impact = value
				break
			end
		end
	end
	if not impact then
		impact = debug.getupvalue(shoot, 22)
	end
	if not impact or type(impact) ~= "function" then
		error("failed to find impact function")
	end

	local oldImpact = nil
	oldImpact = hook.add(
		impact,
		LPH_NO_VIRTUALIZE(function(...)
			local isClient = (select(7, ...))
			if not isClient and not WeaponController._suppressImpacts then
				setthreadidentity(2)
				return oldImpact(...)
			end
			local data = { ... }
			local n = select("#", ...)
			if isClient then
				local instance = data[1] :: BasePart?
				if not instance then
					return oldImpact(...)
				end
				for _, cb in next, WeaponController._impactCallbacks do
					local resolved = cb(instance)
					if resolved ~= instance then
						data[1] = resolved
						instance = resolved
						break
					end
				end
				local parent = instance.Parent :: Model?

				if parent and parent.ClassName == "Model" then
					local player = Players:GetPlayerFromCharacter(parent)
					if player then
						local playerData = PlayerController.Get(player)
						if
							playerData
							and (playerData:GetTeam() ~= ClientController.GetTeam() or gamemodeState.isDeathmatch())
						then
							if hitFireFrames[instance] ~= currentFrame then
								hitFireFrames[instance] = currentFrame
								setthreadidentity(8)
								WeaponController.hitPlayer:Fire(player, instance)
							end
						end
					end
				end
			end
			if WeaponController._suppressImpacts then
				data[11] = true
				n = math.max(n, 11)
			end
			setthreadidentity(2)
			return oldImpact(table.unpack(data, 1, n))
		end)
	)
	WeaponController._impactFn = impact

	NetworkController.HookPacket(
		"Inventory",
		"ShootWeapon",
		LPH_NO_VIRTUALIZE(function(data)
			local bullets = rawget(data, "Bullets")

			if bullets then
				setthreadidentity(8)
				if next(WeaponController._shootTransforms) then
					for _, transform in next, WeaponController._shootTransforms do
						transform(data)
					end
					bullets = rawget(data, "Bullets") or bullets
				end
				for _, bullet in next, bullets do
					WeaponController.bulletCreated:Fire(bullet)
				end
				if next(WeaponController._impactCallbacks) then
					for _, bullet in next, bullets do
						local hits = bullet.Hits
						if not hits then
							continue
						end
						for _, hit in next, hits do
							local instance = hit.Instance
							if not instance or not instance:IsA("BasePart") then
								continue
							end
							for _, cb in next, WeaponController._impactCallbacks do
								local resolved = cb(instance)
								if resolved ~= instance then
									hit.Instance = resolved
									break
								end
							end
						end
					end
				end
				local hitPlayer: Player? = nil
				for _, bullet in next, bullets do
					local hits = bullet.Hits
					if not hits then
						continue
					end
					for _, hit in next, hits do
						local instance = hit.Instance
						if not instance or not instance:IsA("BasePart") then
							continue
						end
						local parent = instance.Parent
						if not parent or parent.ClassName ~= "Model" then
							continue
						end
						local player = Players:GetPlayerFromCharacter(parent :: Model)
						if not player then
							continue
						end
						local playerData = PlayerController.Get(player)
						if
							playerData
							and (playerData:GetTeam() ~= ClientController.GetTeam() or gamemodeState.isDeathmatch())
						then
							hitPlayer = player
							break
						end
					end
					if hitPlayer then
						break
					end
				end
				local ragebotTarget = WeaponController._ragebotShotTarget
				WeaponController._ragebotShotTarget = nil
				WeaponController.shotFired:Fire(data, hitPlayer, ragebotTarget)
				setthreadidentity(2)
			end

			return true
		end)
	)

	local vfx = NetworkController.GetPacketGroup("VFX")
	if vfx then
		local muzzleQueue: { MuzzleEntry } = {}
		local muzzleHead = 1
		local muzzleTail = 0

		local pruneQueue = LPH_NO_VIRTUALIZE(function(now: number): ()
			while muzzleHead <= muzzleTail and now - muzzleQueue[muzzleHead].time > MUZZLE_QUEUE_TTL do
				muzzleQueue[muzzleHead] = nil
				muzzleHead += 1
			end
			if muzzleHead > muzzleTail then
				muzzleHead = 1
				muzzleTail = 0
			end
		end)

		local muzzlePacket = vfx.CreateCharacterMuzzleFlash
		if muzzlePacket and type(muzzlePacket.Listen) == "function" then
			local disconnect = muzzlePacket.Listen(LPH_NO_VIRTUALIZE(function(data: any)
				if typeof(data) ~= "table" then
					return
				end
				local name = data.PlayerName
				if type(name) ~= "string" then
					return
				end
				local localPlayer = Players.LocalPlayer
				if localPlayer and name == localPlayer.Name then
					return
				end
				local now = os.clock()
				pruneQueue(now)
				muzzleTail += 1
				muzzleQueue[muzzleTail] = { name = name, time = now }
			end))
			if type(disconnect) == "function" then
				WeaponController._vfxDisconnects[#WeaponController._vfxDisconnects + 1] = disconnect
			end
		end

		local tracerPacket = vfx.CreateTracer
		if tracerPacket and type(tracerPacket.Listen) == "function" then
			local disconnect = tracerPacket.Listen(LPH_NO_VIRTUALIZE(function(data: any)
				if typeof(data) ~= "table" then
					return
				end
				local origin = data.Origin
				local target = data.Target
				if typeof(origin) ~= "Vector3" or typeof(target) ~= "Vector3" then
					return
				end
				local distance = tonumber(data.Distance) or (target - origin).Magnitude
				local now = os.clock()
				pruneQueue(now)
				local entry = muzzleQueue[muzzleHead]
				if not entry then
					return
				end
				muzzleQueue[muzzleHead] = nil
				muzzleHead += 1
				if muzzleHead > muzzleTail then
					muzzleHead = 1
					muzzleTail = 0
				end
				local player = Players:FindFirstChild(entry.name) :: Player?
				if not player or not player:IsA("Player") then
					return
				end
				setthreadidentity(8)
				WeaponController.observedShot:Fire(player, origin, target, distance)
				setthreadidentity(2)
			end))
			if type(disconnect) == "function" then
				WeaponController._vfxDisconnects[#WeaponController._vfxDisconnects + 1] = disconnect
			end
		end

		local impactPacket = vfx.CreateImpact
		if impactPacket and type(impactPacket.Listen) == "function" then
			local disconnect = impactPacket.Listen(LPH_NO_VIRTUALIZE(function(data: any)
				if typeof(data) ~= "table" or data.Material ~= "Blood Splatter" or data.Exit == true then
					return
				end
				local attacker = data.AttackerUserId
				if type(attacker) ~= "string" or attacker ~= tostring(LocalPlayer.UserId) then
					return
				end
				local victim: Player? = nil
				local part: BasePart? = nil
				local instance = data.Instance
				if typeof(instance) == "Instance" and instance:IsA("BasePart") then
					part = instance
					local model = instance:FindFirstAncestorOfClass("Model")
					if model then
						victim = Players:GetPlayerFromCharacter(model)
					end
				end
				setthreadidentity(8)
				WeaponController.serverHitConfirmed:Fire(victim, part)
				setthreadidentity(2)
			end))
			if type(disconnect) == "function" then
				WeaponController._vfxDisconnects[#WeaponController._vfxDisconnects + 1] = disconnect
			end
		end
	end

	local killedPacket = NetworkController.GetPacket("UI", "UIPlayerKilled")
	local killedListen = killedPacket and rawget(killedPacket, "Listen")
	if type(killedListen) == "function" then
		setthreadidentity(2)
		local unsub = killedListen(LPH_NO_VIRTUALIZE(function(data: any): ()
			task.spawn(function(): ()
				if typeof(data) ~= "table" then
					return
				end
				setthreadidentity(8)
				if tonumber(data.Killer) ~= LocalPlayer.UserId then
					return
				end
				local victim = Players:GetPlayerByUserId(tonumber(data.Victim) or -1)
				if victim and victim ~= LocalPlayer then
					local deathPosition = typeof(data.DeathPosition) == "Vector3" and data.DeathPosition or nil
					WeaponController.killedPlayer:Fire(victim, deathPosition)
				end
			end)
		end))
		setthreadidentity(8)
		if type(unsub) == "function" then
			WeaponController._killFeedUnsub = unsub
		end
	end

	return WeaponController
end)

WeaponController.CanEngage = LPH_NO_VIRTUALIZE(function(weapon: any): boolean
	if not peek(ClientState.alive) then
		return false
	end

	local properties = weapon.Properties
	if not properties or properties.Class ~= "Weapon" then
		return false
	end

	local animation = weapon.Viewmodel.Animation:getAnimation("Equip")
	setthreadidentity(8)
	if tick() - weapon.WeaponEquippedTick <= animation.Length * 0.925 then
		return false
	elseif weapon.IsAdjustingSuppressor or weapon.IsReloading or weapon.Rounds <= 0 then
		return false
	end
	return true
end)

WeaponController.CanShoot = LPH_NO_VIRTUALIZE(function(weapon: any): boolean
	if not WeaponController.CanEngage(weapon) then
		return false
	end
	return not weapon.IsShooting and not weapon.IsChargeFiring
end)

function WeaponController.GetWeaponProperties(weapon: any): any
	local getWeaponProperties = WeaponController._getWeaponProperties

	if not getWeaponProperties then
		local CharacterAnimator = ModuleController.GetModule("CharacterAnimator")
		getWeaponProperties = debug.getupvalue(CharacterAnimator.construct, 1)
		WeaponController._getWeaponProperties = getWeaponProperties
	end

	return (getWeaponProperties :: any)(weapon)
end

function WeaponController.SetImpactsSuppressed(value: boolean): ()
	WeaponController._suppressImpacts = value
end

function WeaponController.NoteRagebotShot(target: Player?): ()
	WeaponController._ragebotShotTarget = target
end

function WeaponController.AddImpactCallback(fn: (BasePart) -> BasePart): ()
	table.insert(WeaponController._impactCallbacks, fn)
end

function WeaponController.RemoveImpactCallback(fn: (BasePart) -> BasePart): ()
	local callbacks = WeaponController._impactCallbacks
	for i = #callbacks, 1, -1 do
		if callbacks[i] == fn then
			table.remove(callbacks, i)
			return
		end
	end
end

function WeaponController.AddShootTransform(fn: (any) -> ()): () -> ()
	table.insert(WeaponController._shootTransforms, fn)
	return function(): ()
		WeaponController.RemoveShootTransform(fn)
	end
end

function WeaponController.RemoveShootTransform(fn: (any) -> ()): ()
	local list = WeaponController._shootTransforms
	for i = #list, 1, -1 do
		if list[i] == fn then
			table.remove(list, i)
			return
		end
	end
end

function WeaponController.Destroy(): ()
	if WeaponController._frameConn then
		WeaponController._frameConn:Disconnect()
		WeaponController._frameConn = nil
	end

	local impactFn = WeaponController._impactFn
	if impactFn then
		hook.restore(impactFn)
		WeaponController._impactFn = nil
	end

	NetworkController.UnhookPacket("Inventory", "ShootWeapon")

	for i, disconnect in next, WeaponController._vfxDisconnects do
		disconnect()
		WeaponController._vfxDisconnects[i] = nil
	end

	if WeaponController._killFeedUnsub then
		WeaponController._killFeedUnsub()
		WeaponController._killFeedUnsub = nil
	end

	table.clear(WeaponController._impactCallbacks)
	table.clear(WeaponController._shootTransforms)

	WeaponController._shoot = nil
	WeaponController._getWeaponProperties = nil
	WeaponController._suppressImpacts = false
	WeaponController._ragebotShotTarget = nil
end

export type WeaponController = typeof(WeaponController)
export type ShootData = {
	IsSniperScoped: boolean,
	ShootingHand: "Left" | "Right",
	Identifier: string,
	Capacity: number,
	Bullets: {
		[number]: BulletData,
	},
	Rounds: number,
}
export type BulletData = {
	Direction: Vector3,
	Origin: Vector3,
	Hits: {
		[number]: {
			Distance: number,
			Instance: Instance?,
			Position: Vector3,
			Normal: Vector3,
			Material: Enum.Material,
			Exit: Vector3,
		},
	},
}

return WeaponController
