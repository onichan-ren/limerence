local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")

local grenadeState = require("@game/rivals/grenade/grenadeState")

local peek = Charm.peek
local sub = Charm.subscribe

export type Grenade = {
	id: string,
	name: string,
	position: Vector3,
	detonateAt: number,
	friendly: boolean,
}

local signals = {
	onGrenadeAdded = Signal.new(),
	onGrenadeRemoved = Signal.new(),
}

local grenadeApi = {
	signals = signals,
}

local function toPublic(entry: grenadeState.ProjectileEntry): Grenade
	return {
		id = entry.id,
		name = entry.weapon,
		position = entry.landingPosition,
		detonateAt = entry.detonateAt,
		friendly = entry.isFriendly == true,
	}
end

function grenadeApi.GetGrenades(): { Grenade }
	local out: { Grenade } = {}
	for _, entry in next, peek(grenadeState.activeProjectiles) do
		out[#out + 1] = toPublic(entry)
	end
	return out
end

local lastEntries = peek(grenadeState.activeProjectiles)
sub(grenadeState.activeProjectiles, function(entries: { [string]: grenadeState.ProjectileEntry }): ()
	local previous = lastEntries
	lastEntries = entries
	for id, entry in next, entries do
		if not previous[id] then
			signals.onGrenadeAdded:Fire(toPublic(entry))
		end
	end
	for id, entry in next, previous do
		if not entries[id] then
			signals.onGrenadeRemoved:Fire(toPublic(entry))
		end
	end
end)

return grenadeApi
