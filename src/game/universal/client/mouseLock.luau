local CONTROLLER_KEYS = { "isMouseLocked", "boundKeys", "mouseLockToggledEvent" }

local mouseLock = {}

local controller: any = nil

local function resolve(): any?
	local cached = controller
	if cached ~= nil then
		return cached
	end

	local found = filtergc("table", { Keys = CONTROLLER_KEYS }, true)
	controller = found
	return found
end

function mouseLock.Available(): boolean
	local instance = resolve()
	return instance ~= nil and instance.enabled == true
end

function mouseLock.IsLocked(): boolean
	local instance = resolve()
	return instance ~= nil and instance.isMouseLocked == true
end

function mouseLock.Set(locked: boolean): boolean
	local instance = resolve()
	if instance == nil or instance.enabled ~= true then
		return false
	end
	if instance.isMouseLocked == locked then
		return true
	end

	setthreadidentity(2)
	instance:OnMouseLockToggled()
	setthreadidentity(8)

	return instance.isMouseLocked == locked
end

return mouseLock
