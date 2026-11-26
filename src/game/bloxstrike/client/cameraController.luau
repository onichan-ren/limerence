local hook = require("@share/hook")

type Transform = {
	name: string,
	priority: number,
	fn: (value: CFrame, caller: LocalScript?) -> CFrame,
}

local transforms: { [string]: Transform } = {}
local sorted: { Transform } = {}
local hookedCamera: Camera? = nil

local CameraController = {}

local rebuild = LPH_NO_VIRTUALIZE(function(): ()
	local list: { Transform } = {}
	for _, transform in next, transforms do
		list[#list + 1] = transform
	end
	table.sort(list, function(a: Transform, b: Transform): boolean
		return a.priority > b.priority
	end)
	sorted = list
end)

local ensureHook = function(): ()
	if hookedCamera then
		return
	end
	local camera = workspace.CurrentCamera
	hook.addInstance(camera)
	hook.overrideProperty(
		camera,
		"CFrame",
		LPH_NO_VIRTUALIZE(function(value: CFrame, caller: LocalScript?): CFrame
			local result = value
			for i = 1, #sorted do
				result = sorted[i].fn(result, caller) or result
			end
			return result
		end)
	)
	hookedCamera = camera
end

local teardownHook = LPH_NO_VIRTUALIZE(function(): ()
	if not hookedCamera then
		return
	end
	hook.restoreProperty(hookedCamera, "CFrame")
	hook.restoreInstance(hookedCamera)
	hookedCamera = nil
end)

function CameraController.Register(
	name: string,
	priority: number,
	fn: (value: CFrame, caller: LocalScript?) -> CFrame
): () -> ()
	transforms[name] = { name = name, priority = priority, fn = fn }
	rebuild()
	ensureHook()
	return function(): ()
		if not transforms[name] then
			return
		end
		transforms[name] = nil
		rebuild()
		if next(transforms) == nil then
			teardownHook()
		end
	end
end

return CameraController
