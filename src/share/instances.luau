local str = require("@share/strings")

local Workspace = cloneref(game:GetService("Workspace"))

local instances = {}

local ignoredProps: { [string]: boolean } = {
	Secure = true,
}

instances.newSimple = LPH_NO_VIRTUALIZE(function(class: string, props: { [string]: any }, parent: Instance?): Instance
	local instance = Instance.new(class) :: any

	for key, value in next, props do
		instance[key] = value
	end

	if parent then
		instance.Parent = parent
	end

	return instance
end)

instances.new = function(class: string, props: { [string]: any }, parent: Instance?): Instance
	local instance = Instance.new(class) :: any

	for key, value in next, props do
		if ignoredProps[key] then
			continue
		end

		instance[key] = value
	end

	if parent then
		instance.Parent = parent
	end

	instance.Name = str.random()

	return instance
end

local ownedIgnore = instances.new("Folder", {
	Name = str.randomSafe(16),
})
instances.ignore = ownedIgnore

instances.setIgnore = function(name: string): ()
	local found = Workspace:FindFirstChild(name)
	if not found or found == instances.ignore then
		return
	end
	instances.ignore = found
	if ownedIgnore and ownedIgnore:IsDescendantOf(Workspace) then
		ownedIgnore:Destroy()
		ownedIgnore = nil
	end
end

return instances
