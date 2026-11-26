local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local NetworkController = require("@game/pf/network/NetworkController")

local FORWARD_TRACK = 0.5

local DIRECTIONS = {
	Vector3.new(0, 1.6, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, 0.5, 0),
	Vector3.new(0, 0, 0),
	Vector3.new(0, -0.5, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, -1.9, 0),
}

local repupdateBypass = {
	_refs = 0,
	_unhook = nil :: (() -> ())?,
	_last = nil :: Vector3?,
	_debt = 0,
	_sent = nil :: Vector3?,
	_map = nil :: Instance?,
}

local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Include
wallParams.IgnoreWater = true

local function mapFolder(): Instance?
	local map = repupdateBypass._map
	if not map or not map.Parent then
		map = Workspace:FindFirstChild("Map")
		repupdateBypass._map = map
		if map then
			wallParams.FilterDescendantsInstances = { map }
		end
	end
	return map
end

local WALL_GAP = 1.5

local avoidWalls = LPH_NO_VIRTUALIZE(function(origin: Vector3, moveBy: Vector3): Vector3
	local map = mapFolder()
	local dist = moveBy.Magnitude
	if not map or dist < 1e-4 then
		return moveBy
	end
	local dir = moveBy / dist
	local scan = dir * (dist + WALL_GAP)
	local allowed = dist
	for i = 1, #DIRECTIONS do
		local result = Workspace:Raycast(origin + DIRECTIONS[i], scan, wallParams)
		if result then
			local reach = result.Distance - WALL_GAP
			if reach < allowed then
				allowed = reach
			end
		end
	end
	if allowed >= dist then
		return moveBy
	end
	if allowed < 0 then
		allowed = 0
	end
	return dir * allowed
end)

local onRepupdate = LPH_NO_VIRTUALIZE(function(position: any, angles: any, angles2: any, time: any): boolean?
	local debt = repupdateBypass._debt
	if debt > 0 then
		repupdateBypass._debt = debt - 1
		return false
	end
	local last = repupdateBypass._last
	if last then
		local moveBy = avoidWalls(last, (position - last) * FORWARD_TRACK)
		local sent = last + moveBy
		NetworkController.Send("repupdate", sent, angles, angles2, time)
		repupdateBypass._debt += 1
		repupdateBypass._sent = sent
	else
		repupdateBypass._sent = nil
	end
	repupdateBypass._last = position
	return
end)

function repupdateBypass.getSentPosition(): Vector3?
	if repupdateBypass._refs > 0 then
		return repupdateBypass._sent
	end
	return nil
end

function repupdateBypass.acquire(): ()
	repupdateBypass._refs += 1
	if repupdateBypass._refs == 1 then
		repupdateBypass._last = nil
		repupdateBypass._debt = 0
		repupdateBypass._sent = nil
		repupdateBypass._unhook = NetworkController.HookOutbound("repupdate", onRepupdate)
	end
end

function repupdateBypass.release(): ()
	if repupdateBypass._refs <= 0 then
		return
	end
	repupdateBypass._refs -= 1
	if repupdateBypass._refs == 0 then
		local unhook = repupdateBypass._unhook
		if unhook then
			unhook()
			repupdateBypass._unhook = nil
		end
		repupdateBypass._last = nil
		repupdateBypass._debt = 0
		repupdateBypass._sent = nil
	end
end

return repupdateBypass
