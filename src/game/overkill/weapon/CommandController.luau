local ModuleController = require("@game/overkill/module/ModuleController")
local hook = require("@share/hook")

local CommandController = {}

type TransformEntry = { fn: (command: any) -> (), priority: number }

local transforms: { TransformEntry } = {}
local commandLayout: any = nil
local hookedNormalise: any = nil
local originalNormalise: any = nil

local function applyTransforms(command: any): ()
	if type(command) ~= "table" then
		return
	end
	for i = 1, #transforms do
		transforms[i].fn(command)
	end
end

local function ensureInstalled(): ()
	if originalNormalise then
		return
	end
	commandLayout = ModuleController.GetModule("commandLayout")
	if not commandLayout or type(commandLayout.NormaliseForWire) ~= "function" then
		return
	end
	hookedNormalise = commandLayout.NormaliseForWire
	originalNormalise = hook.add(
		hookedNormalise,
		LPH_NO_VIRTUALIZE(function(self: any, command: any): ...any
			setthreadidentity(2)
			local result = originalNormalise(self, command)
			setthreadidentity(8)
			applyTransforms(command)
			setthreadidentity(2)
			return result
		end)
	)
end

function CommandController.Register(transform: (command: any) -> (), priority: number?): () -> ()
	local entry: TransformEntry = { fn = transform, priority = priority or 0 }
	local index = #transforms + 1
	for i = 1, #transforms do
		if transforms[i].priority > entry.priority then
			index = i
			break
		end
	end
	table.insert(transforms, index, entry)
	ensureInstalled()
	return function(): ()
		local found = table.find(transforms, entry)
		if found then
			table.remove(transforms, found)
		end
	end
end

function CommandController.new(): CommandController
	return CommandController
end

function CommandController.Destroy(): ()
	table.clear(transforms)
	if hookedNormalise then
		hook.restore(hookedNormalise)
	end
	hookedNormalise = nil
	originalNormalise = nil
	commandLayout = nil
end

export type CommandController = typeof(CommandController)

return CommandController
