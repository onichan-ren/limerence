local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local BaseFeature = require("@game/BaseFeature")
local ModuleController = require("@game/pf/module/ModuleController")
local repupdateBypass = require("@game/pf/network/repupdateBypass")
local gameUi = require("@game/gameUi")

local SWEEP_MIN = 0.5
local SWEEP_MAX = 30
local SWEEP_GAP = 1
local WALKABLE_NORMAL_Y = 0.45

local SWEEP_OFFSETS = {
	Vector3.new(0, 1.6, 0),
	Vector3.new(0, 0.5, 0),
	Vector3.new(0, -0.5, 0),
}

local sweepParams = RaycastParams.new()
sweepParams.FilterType = Enum.RaycastFilterType.Include
sweepParams.IgnoreWater = true
sweepParams.RespectCanCollide = true

local sweepMap: Instance? = nil

local function mapFolder(): Instance?
	if not sweepMap or not sweepMap.Parent then
		sweepMap = Workspace:FindFirstChild("Map")
		if sweepMap then
			sweepParams.FilterDescendantsInstances = { sweepMap }
		end
	end
	return sweepMap
end

local sweepCast = LPH_NO_VIRTUALIZE(function(origin: Vector3, move: Vector3): (number?, Vector3?)
	local blocked, normal
	for i = 1, #SWEEP_OFFSETS do
		local result = Workspace:Raycast(origin + SWEEP_OFFSETS[i], move, sweepParams)
		if result then
			local n = result.Normal
			if n.Y <= WALKABLE_NORMAL_Y then
				local d = result.Distance
				if not blocked or d < blocked then
					blocked = d
					normal = n
				end
			end
		end
	end
	return blocked, normal
end)

local sweepClamp = LPH_NO_VIRTUALIZE(function(co: any, root: BasePart, prev: Vector3, pos: Vector3): Vector3
	if (pos - prev).Magnitude > SWEEP_MAX then
		return pos
	end
	local delta = Vector3.new(pos.X - prev.X, 0, pos.Z - prev.Z)
	local dist = delta.Magnitude
	if dist < SWEEP_MIN then
		return pos
	end
	if co:isVaulting() then
		return pos
	end
	if not mapFolder() then
		return pos
	end
	local dir = delta / dist
	local blocked, normal = sweepCast(prev, delta)
	if not (blocked and normal) then
		return pos
	end
	local crossed = sweepCast(pos, -delta)
	if not crossed then
		return pos
	end
	local back = blocked - SWEEP_GAP
	if back < 0 then
		back = 0
	end
	local stop = prev + dir * back
	local newPos = Vector3.new(stop.X, pos.Y, stop.Z)
	local remaining = dist - back
	local tangent = dir - normal * dir:Dot(normal)
	tangent = Vector3.new(tangent.X, 0, tangent.Z)
	local tmag = tangent.Magnitude
	if tmag > 1e-3 and remaining > 1e-3 then
		local slideLen = remaining * tmag
		tangent /= tmag
		local slideBlocked = sweepCast(Vector3.new(stop.X, prev.Y, stop.Z), tangent * slideLen)
		local allowed = slideLen
		if slideBlocked then
			allowed = slideBlocked - SWEEP_GAP
			if allowed < 0 then
				allowed = 0
			end
		end
		newPos += tangent * allowed
	end
	root.CFrame = root.CFrame.Rotation + newPos
	local velocity = root.AssemblyLinearVelocity
	local vn = velocity:Dot(normal)
	if vn < 0 then
		root.AssemblyLinearVelocity = velocity - normal * vn
	end
	return newPos
end)

local Speed = {}
Speed.__index = Speed

setmetatable(Speed, { __index = BaseFeature })

function Speed.new(link: gameUi.Linker): Speed
	local self = BaseFeature.new() :: any
	setmetatable(self, Speed)

	self._enabled = false
	self._mult = 2
	self._conn = nil :: RBXScriptConnection?
	self._ci = nil :: any
	self._prevPos = nil :: Vector3?

	link:Toggle("speed", "Speed", false):SetTip({
		title = "Speed",
		body = "Move faster than normal.",
	})
	local speedLink = link:OnKey("speed")
	speedLink:Submenu("opts", "Speed")
	local optsLink = speedLink:OnKey("opts")

	optsLink:Slider("multiplier", "Multiplier", 5, 1, 25, 0.1, nil, "x"):SetTip({
		title = "Multiplier",
		body = "How much faster you move.",
	})

	self._mult = link:Peek("speed.opts.multiplier") or 2

	self:Track(link:Get("speed"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))
	self:Track(link:Watch("speed.opts.multiplier", function(value: number): ()
		self._mult = type(value) == "number" and value or 1
	end))

	if link:Peek("speed") then
		self:Enable()
	end

	return self
end

function Speed.Enable(self: Speed): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._conn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
		local ci = self._ci or ModuleController.GetModule("CharacterInterface")
		if not ci then
			return
		end
		self._ci = ci
		local co = ci.getCharacterObject()
		if not co then
			self._prevPos = nil
			return
		end
		co._walkSpeedMult = self._mult
		co:updateWalkSpeed()
		local root = co:getRealRootPart()
		if not root then
			self._prevPos = nil
			return
		end
		local pos = root.Position
		local prev = self._prevPos
		if prev then
			pos = sweepClamp(co, root, prev, pos)
		end
		self._prevPos = pos
	end))

	repupdateBypass.acquire()
end

function Speed.Disable(self: Speed): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	self._prevPos = nil
	repupdateBypass.release()

	local ci = self._ci or ModuleController.GetModule("CharacterInterface")
	if ci then
		local co = ci.getCharacterObject()
		if co then
			co._walkSpeedMult = 1
			co:updateWalkSpeed()
		end
	end
end

function Speed.Destroy(self: Speed): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type Speed =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_mult: number,
			_conn: RBXScriptConnection?,
			_ci: any,
			_prevPos: Vector3?,
			Enable: (Speed) -> (),
			Disable: (Speed) -> (),
		},
		Speed
	))
	& BaseFeature.BaseFeature

return Speed
