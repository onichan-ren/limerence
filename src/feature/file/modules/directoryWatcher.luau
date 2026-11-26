local Charm = require("@pkg/Charm")

local sub = Charm.subscribe
local peek = Charm.peek

type Atom<T> = Charm.Atom<T>

export type WatcherOptions = {
	path: string,
	extension: string?,
	interval: number?,
	activeWhile: Atom<boolean>?,
	pollOnActivate: boolean?,
	onAdded: ((name: string) -> ())?,
	onRemoved: ((name: string) -> ())?,
	onChange: ((names: { string }, added: { string }, removed: { string }) -> ())?,
}

export type Watcher = {
	Refresh: (self: Watcher) -> (),
	GetNames: (self: Watcher) -> { string },
	Stop: (self: Watcher) -> (),
}

local directoryWatcher = {}

local function listNames(path: string, extension: string?): { string }
	if not listfiles or not isfolder or not isfolder(path) then
		return {}
	end

	local pattern = extension and (`([^/\\]+)%.{extension}$`) or ("([^/\\]+)$")
	local names: { string } = {}

	local results = listfiles(path)
	if type(results) ~= "table" then
		return names
	end

	for _, full in next, results do
		local name = full:match(pattern)
		if name then
			table.insert(names, name)
		end
	end

	return names
end

function directoryWatcher.create(options: WatcherOptions): Watcher
	local interval = options.interval or 1
	local pollOnActivate = options.pollOnActivate ~= false

	local snapshot: { [string]: true } = {}
	local snapshotList: { string } = {}
	local stopped = false
	local pollThread: thread? = nil
	local unsubscribe: (() -> ())? = nil

	local function poll(): ()
		if stopped then
			return
		end

		local names = listNames(options.path, options.extension)
		local current: { [string]: true } = {}
		for _, name in next, names do
			current[name] = true
		end

		local added: { string } = {}
		local removed: { string } = {}
		for name in next, current do
			if not snapshot[name] then
				table.insert(added, name)
			end
		end
		for name in next, snapshot do
			if not current[name] then
				table.insert(removed, name)
			end
		end

		snapshot = current
		snapshotList = names

		if #added == 0 and #removed == 0 then
			return
		end

		local onAdded = options.onAdded
		if onAdded then
			for _, name in next, added do
				onAdded(name)
			end
		end

		local onRemoved = options.onRemoved
		if onRemoved then
			for _, name in next, removed do
				onRemoved(name)
			end
		end

		local onChange = options.onChange
		if onChange then
			onChange(names, added, removed)
		end
	end

	local function stopLoop(): ()
		local thread = pollThread
		pollThread = nil
		if thread and coroutine.status(thread) ~= "dead" then
			pcall(task.cancel, thread)
		end
	end

	local function startLoop(): ()
		if pollThread or stopped then
			return
		end
		pollThread = task.spawn(function()
			while not stopped do
				task.wait(interval)
				if stopped then
					return
				end
				if options.activeWhile and not peek(options.activeWhile) then
					pollThread = nil
					return
				end
				poll()
			end
			pollThread = nil
		end)
	end

	local watcher = {} :: Watcher

	function watcher:Refresh(): ()
		if stopped then
			return
		end
		poll()
	end

	function watcher:GetNames(): { string }
		return table.clone(snapshotList)
	end

	function watcher:Stop(): ()
		if stopped then
			return
		end
		stopped = true
		if unsubscribe then
			unsubscribe()
			unsubscribe = nil
		end
		stopLoop()
	end

	if options.activeWhile then
		if peek(options.activeWhile) then
			if pollOnActivate then
				poll()
			end
			startLoop()
		end
		unsubscribe = sub(options.activeWhile, function(value: boolean): ()
			if stopped then
				return
			end
			if value then
				if pollOnActivate then
					poll()
				end
				startLoop()
			else
				stopLoop()
			end
		end)
	else
		poll()
		startLoop()
	end

	return watcher
end

return directoryWatcher
