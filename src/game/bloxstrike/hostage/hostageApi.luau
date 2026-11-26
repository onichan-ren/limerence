local Charm = require("@pkg/Charm")
local Signal = require("@pkg/Signal")
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local hostageState = require("@game/bloxstrike/hostage/hostageState")

local peek = Charm.peek
local sub = Charm.subscribe

local state = hostageState

local signals = {
	onHostageAdded = Signal.new(),
	onHostageRemoved = Signal.new(),
	onHostageChanged = Signal.new(),
}

local hostageApi = {
	state = state,
	signals = signals,
}

function hostageApi.GetHostages(): { [string]: hostageState.HostageEntry }
	local cur = peek(state.hostages)
	local out: { [string]: hostageState.HostageEntry } = {}
	for k, v in next, cur do
		out[k] = v
	end
	return out
end

function hostageApi.GetHostage(key: string): hostageState.HostageEntry?
	return peek(state.hostages)[key]
end

function hostageApi.GetRescueRemaining(entry: hostageState.HostageEntry): number?
	if not entry.rescuingPlayer or not entry.rescueStartedAt or not entry.rescueDuration then
		return nil
	end
	return math.max(entry.rescueDuration - (Workspace:GetServerTimeNow() - entry.rescueStartedAt), 0)
end

function hostageApi.GetRescueProgress(entry: hostageState.HostageEntry): number
	if not entry.rescuingPlayer or not entry.rescueStartedAt or not entry.rescueDuration or entry.rescueDuration <= 0 then
		return 0
	end
	local elapsed = Workspace:GetServerTimeNow() - entry.rescueStartedAt
	return math.clamp(elapsed / entry.rescueDuration, 0, 1)
end

local lastHostages: { [string]: hostageState.HostageEntry } = peek(state.hostages)
sub(state.hostages, function(hostages: { [string]: hostageState.HostageEntry }): ()
	local previous = lastHostages
	for key, entry in next, hostages do
		if previous[key] == nil then
			signals.onHostageAdded:Fire(key, entry)
		else
			signals.onHostageChanged:Fire(key, entry)
		end
	end
	for key, entry in next, previous do
		if hostages[key] == nil then
			signals.onHostageRemoved:Fire(key, entry)
		end
	end
	lastHostages = hostages
end)

return hostageApi
