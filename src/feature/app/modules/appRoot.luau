local ReactRoblox = require("@pkg/ReactRoblox")

local instances = require("@share/instances")

local function appRoot(): (ReactRoblox.RootType, ScreenGui)
	local screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = 100,
	}, cloneref(gethui())) :: ScreenGui

	return ReactRoblox.createRoot(screenGui), screenGui
end

return appRoot
