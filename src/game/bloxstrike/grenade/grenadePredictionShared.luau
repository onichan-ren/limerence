local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local simulator = require("@game/bloxstrike/grenade/simulator")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local clientState = require("@game/bloxstrike/client/clientState")

local peek = Charm.peek

local LocalPlayer = Players.LocalPlayer
local Debris = Workspace:WaitForChild("Debris")

local PROFILES = simulator.PROFILES

local shared = {}

export type Result = {
	points: { Vector3 },
	impactPos: Vector3,
	weapon: any,
	grenadeName: string,
	profile: simulator.GrenadeProfile,
	throwType: simulator.ThrowType,
	rootPart: BasePart,
}

local SIM_CAP_INTERVAL = 1 / 60 - 0.0001

local _lastTime = -math.huge
local _lastResult: Result? = nil
local _lastCharacter: Model? = nil
local _filterTable: { Instance } = {}
local _raycastParams = RaycastParams.new()
_raycastParams.FilterType = Enum.RaycastFilterType.Exclude
_raycastParams.RespectCanCollide = false
_raycastParams.IgnoreWater = true

local ORIGIN_EPS_SQ = 1e-4
local VELOCITY_EPS_SQ = 1e-3

local _memoOrigin: Vector3? = nil
local _memoVelocity: Vector3? = nil
local _memoJump: boolean? = nil
local _memoGrenade: string? = nil
local _memoCharacter: Model? = nil
local _memoPoints: { Vector3 }? = nil
local _memoImpact: Vector3? = nil

local function resolveGrenadeName(equipped: any): string?
	if not equipped then
		return nil
	end
	local name = equipped.Name
	local identifier = equipped.Identifier
	local weapon = equipped.Weapon
	if type(name) == "string" and PROFILES[name] then
		return name
	end
	if type(identifier) == "string" and PROFILES[identifier] then
		return identifier
	end
	if type(weapon) == "string" and PROFILES[weapon] then
		return weapon
	end
	local props = equipped.Properties
	if props and props.Class == "Grenade" then
		if type(name) == "string" then
			return name
		end
		if type(identifier) == "string" then
			return identifier
		end
		if type(weapon) == "string" then
			return weapon
		end
	end
	return nil
end

local simulate = LPH_NO_VIRTUALIZE(function(): Result?
	local character = LocalPlayer.Character
	if not character then
		return nil
	end

	local parts = peek(clientState.parts)
	local root = parts.HumanoidRootPart :: BasePart?
	if not root then
		return nil
	end

	local equipped = peek(loadoutState.currentEquipped)
	local grenadeName = resolveGrenadeName(equipped)
	if not grenadeName then
		return nil
	end

	local profile = PROFILES[grenadeName]
	if not profile then
		return nil
	end

	local lmb = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	local rmb = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	if not lmb and not rmb then
		return nil
	end

	local throwType: simulator.ThrowType = (rmb and "Near" or "Far")

	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local cameraCFrame = camera.CFrame
	local lookVec = cameraCFrame.LookVector
	local origin, dir = simulator.calcThrowParams(root.Position, lookVec, throwType)

	local playerVel = root.AssemblyLinearVelocity or Vector3.zero
	local velocity = simulator.calcInitialVelocity(dir, throwType, playerVel)
	local isJumpThrow = simulator.isJumpThrow(playerVel)

	if character ~= _lastCharacter then
		_lastCharacter = character
		_filterTable[1] = character
		_filterTable[2] = Debris
		_raycastParams.FilterDescendantsInstances = _filterTable
	end

	local points: { Vector3 }
	local impactPos: Vector3

	local reuse = false
	if
		_memoPoints
		and _memoCharacter == character
		and _memoGrenade == grenadeName
		and _memoJump == isJumpThrow
		and _memoOrigin
		and _memoVelocity
	then
		local od = origin - _memoOrigin
		local vd = velocity - _memoVelocity
		if od:Dot(od) <= ORIGIN_EPS_SQ and vd:Dot(vd) <= VELOCITY_EPS_SQ then
			reuse = true
		end
	end

	if reuse then
		points = _memoPoints :: { Vector3 }
		impactPos = _memoImpact :: Vector3
	else
		local res = simulator.simulate(
			origin,
			velocity,
			isJumpThrow,
			profile.radius,
			profile.fuse,
			profile.minFuse,
			profile.floorExplode,
			_raycastParams
		)

		points = res.points
		if #points < 2 then
			return nil
		end
		impactPos = points[#points]

		_memoOrigin = origin
		_memoVelocity = velocity
		_memoJump = isJumpThrow
		_memoGrenade = grenadeName
		_memoCharacter = character
		_memoPoints = points
		_memoImpact = impactPos
	end

	return {
		points = points,
		impactPos = impactPos,
		weapon = equipped,
		grenadeName = grenadeName,
		profile = profile,
		throwType = throwType,
		rootPart = root,
	}
end)

shared.resolveGrenadeName = resolveGrenadeName

function shared.getCurrent(): Result?
	local now = os.clock()
	if now - _lastTime < SIM_CAP_INTERVAL then
		return _lastResult
	end
	_lastTime = now
	_lastResult = simulate()
	return _lastResult
end

function shared.invalidate(): ()
	_lastTime = -math.huge
	_lastResult = nil
	_memoPoints = nil
	_memoImpact = nil
end

return shared
