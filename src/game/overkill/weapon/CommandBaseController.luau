local ModuleController = require("@game/overkill/module/ModuleController")

local CommandBaseController = {}

type TransformEntry = { fn: (command: any, module: any) -> (), priority: number }

local transforms: { TransformEntry } = {}
local modArray: any = nil
local modEntry: any = nil
local clientModule: any = nil

local function ensureInstalled(): ()
	if modEntry then
		return
	end
	local clientMods = ModuleController.GetModule("clientMods")
	if not clientMods or type(clientMods.mods) ~= "table" then
		return
	end
	clientModule = ModuleController.GetModule("clientModule")

	local array = clientMods.mods.clientmods
	if type(array) ~= "table" then
		array = {}
		clientMods.mods.clientmods = array
	end
	modArray = array

	modEntry = {
		name = "z_overkill_command",
		priority = -math.huge,
		Setup = function(): () end,
		Step = LPH_NO_VIRTUALIZE(function(): () end),
		GenerateCommand = LPH_NO_VIRTUALIZE(function(_: any, command: any): any
			for i = 1, #transforms do
				transforms[i].fn(command, clientModule)
			end
			return command
		end),
	}
	table.insert(modArray, modEntry)
end

function CommandBaseController.Register(transform: (command: any, module: any) -> (), priority: number?): () -> ()
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

function CommandBaseController.new(): CommandBaseController
	return CommandBaseController
end

function CommandBaseController.Destroy(): ()
	table.clear(transforms)
	if modArray and modEntry then
		local index = table.find(modArray, modEntry)
		if index then
			table.remove(modArray, index)
		end
	end
	modArray = nil
	modEntry = nil
	clientModule = nil
end

export type CommandBaseController = typeof(CommandBaseController)

return CommandBaseController
