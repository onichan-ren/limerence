local ModuleController = require("@game/pf/module/ModuleController")
local NetworkController = require("@game/pf/network/NetworkController")
local grenadeState = require("@game/pf/grenade/grenadeState")

local LocalPlayer = (cloneref(game:GetService("Players")) :: Players).LocalPlayer

local GrenadeController = {
	_unhook = nil :: (() -> ())?,
	_active = {} :: { [any]: grenadeState.IncomingGrenade },
	_counter = 0,
}

local function getPing(): number
	local client = NetworkController.GetClient()
	if not client or not client.getPing then
		return 0
	end
	local ping = client.getPing()
	if type(ping) == "number" then
		return ping
	end
	return 0
end

local function push(): ()
	local snapshot = table.clone(GrenadeController._active)
	task.defer(function(): ()
		grenadeState.incoming(snapshot)
	end)
end

local function remove(key: any): ()
	if GrenadeController._active[key] == nil then
		return
	end
	GrenadeController._active[key] = nil
	push()
end

local function addEntry(
	name: string,
	landing: Vector3,
	path: { Vector3 },
	fuse: number,
	data: any,
	isFriendly: boolean,
	isSelf: boolean
): ()
	GrenadeController._counter += 1
	local key = GrenadeController._counter
	GrenadeController._active[key] = {
		name = name,
		landing = landing,
		path = path,
		detonateAt = os.clock() + fuse,
		fuse = fuse,
		blastRadius = data.blastradius or 0,
		damageGraph = data.damageGraph,
		isFriendly = isFriendly,
		isSelf = isSelf,
	}
	push()
	task.delay(fuse, remove, key)
end

local positionAtTime = LPH_NO_VIRTUALIZE(function(nodes: any, t: number): Vector3?
	local first = nodes[1]
	if not first or typeof(first.p) ~= "Vector3" then
		return nil
	end
	if t <= first.t then
		return first.p
	end
	local prev = first
	for i = 2, #nodes do
		local node = nodes[i]
		if typeof(node.p) ~= "Vector3" then
			break
		end
		if node.t >= t then
			local span = node.t - prev.t
			local alpha = span > 1e-6 and (t - prev.t) / span or 0
			return prev.p:Lerp(node.p, alpha)
		end
		prev = node
	end
	return prev.p
end)

local buildPath = LPH_NO_VIRTUALIZE(function(nodes: any, untilT: number, landing: Vector3): { Vector3 }
	local cutoff = 0
	for i = 1, #nodes do
		local node = nodes[i]
		if type(node.t) == "number" and node.t <= untilT then
			cutoff = i
		else
			break
		end
	end
	local path: { Vector3 } = {}
	if cutoff > 0 then
		local step = math.max(1, math.floor(cutoff / 40))
		for i = 1, cutoff, step do
			local p = nodes[i].p
			if typeof(p) == "Vector3" then
				path[#path + 1] = p
			end
		end
	end
	path[#path + 1] = landing
	return path
end)

local onNewGrenade = LPH_NO_VIRTUALIZE(
	function(thrower: any, grenadeName: any, points: any, _windows: any, detonation: any): ()
		if typeof(thrower) ~= "Instance" or type(points) ~= "table" or #points == 0 then
			return
		end

		local content = ModuleController.GetModule("ContentInterface")
		local data = content and content.getWeaponData and content.getWeaponData(grenadeName)
		if not data then
			return
		end

		local remaining = 3
		if type(detonation) == "number" then
			remaining = detonation - getPing() / 2
		end
		if remaining <= 0 then
			return
		end

		local landing = positionAtTime(points, remaining)
		if typeof(landing) ~= "Vector3" then
			return
		end

		addEntry(
			data.displayname or data.name or tostring(grenadeName),
			landing,
			buildPath(points, remaining, landing),
			remaining,
			data,
			thrower.TeamColor == LocalPlayer.TeamColor,
			thrower == LocalPlayer
		)
	end
)

function GrenadeController.new(): GrenadeController
	GrenadeController._unhook = NetworkController.HookInbound("newgrenade", onNewGrenade)
	return GrenadeController
end

function GrenadeController.Destroy(): ()
	if GrenadeController._unhook then
		GrenadeController._unhook()
		GrenadeController._unhook = nil
	end
	table.clear(GrenadeController._active)
	grenadeState.incoming({})
end

export type GrenadeController = typeof(GrenadeController)

return GrenadeController
