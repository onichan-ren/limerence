local hook = require("@share/hook")
local ModuleController = require("@game/overkill/module/ModuleController")

local counts: { [string]: number } = {}
local hooked: { [string]: any } = {}

local function resolve(method: string): any
	local module = ModuleController.GetModule("damage")
	if type(module) ~= "table" then
		return nil
	end
	local fn = rawget(module, method)
	if type(fn) ~= "function" then
		return nil
	end
	return fn
end

local hudSuppressor = {}

function hudSuppressor.Acquire(method: string): ()
	counts[method] = (counts[method] or 0) + 1
	if hooked[method] then
		return
	end
	local fn = resolve(method)
	if not fn then
		return
	end
	hooked[method] = fn
	hook.add(fn, function(): () end)
end

function hudSuppressor.Release(method: string): ()
	local count = counts[method]
	if not count or count <= 0 then
		return
	end
	count -= 1
	counts[method] = count
	if count > 0 then
		return
	end
	local fn = hooked[method]
	if fn then
		hook.restore(fn)
		hooked[method] = nil
	end
end

return hudSuppressor
