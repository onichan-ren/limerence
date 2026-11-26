local REG_KEY = game.JobId

local loader = {
	_destroyers = {} :: { [number]: () -> () },
	_modules = {} :: { [number]: moduleType },
}

local destroyers = loader._destroyers
local modules = loader._modules

function loader.init(): ()
	local reg = getreg() :: { [number | string]: any }

	local unload = reg[REG_KEY]
	if unload then
		if LPH_OBFUSCATED then
			game:GetService("Players").LocalPlayer
				:Kick("[limerence.biz]\n\nYou are not allowed to execute the script multiple times.")
			while true do
				task.wait()
			end
			return
		end
		pcall(unload)
		task.wait()
	end

	reg[REG_KEY] = loader.unload

	for idx, module in next, modules do
		local moduleInstance = module.new()
		destroyers[#destroyers + 1] = moduleInstance.Destroy

		modules[idx] = nil
		setthreadidentity(8)
	end
end

function loader.add(module: moduleType): ()
	modules[#modules + 1] = module
end

function loader.addDestroyer(destroy: () -> ()): ()
	destroyers[#destroyers + 1] = destroy
end

function loader.mount(module: { new: (...any) -> any, Destroy: ((...any) -> ())? }, ...: any): any
	setthreadidentity(8)
	local instance = module.new(...)
	setthreadidentity(8)
	local target: any = instance or module
	local destroy = target.Destroy

	if type(destroy) == "function" then
		destroyers[#destroyers + 1] = function(): ()
			pcall(destroy, target)
		end
	end

	return instance
end

function loader.unload(): ()
	for _, destroy in next, destroyers do
		pcall(destroy)
		setthreadidentity(8)
	end
	table.clear(destroyers)
end

type moduleType = { new: () -> any, Destroy: () -> any }

return loader
