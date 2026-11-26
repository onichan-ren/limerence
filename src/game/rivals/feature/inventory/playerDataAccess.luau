local Players = cloneref(game:GetService("Players")) :: Players

local logger = require("@share/logger").new("playerDataAccess")

local LocalPlayer = Players.LocalPlayer

local playerDataAccess = {
	_controller = nil :: any,
}

local loadController = LPH_NO_VIRTUALIZE(function(): any?
	if playerDataAccess._controller then
		return playerDataAccess._controller
	end
	if not LocalPlayer then
		return nil
	end
	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local controllers = playerScripts and playerScripts:FindFirstChild("Controllers")
	local mod = controllers and controllers:FindFirstChild("PlayerDataController")
	if not mod then
		logger:warn("PlayerDataController not found")
		return nil
	end
	setthreadidentity(2)
	local controller = require(mod)
	setthreadidentity(8)
	if type(controller) ~= "table" then
		logger:warn("failed to require PlayerDataController")
		return nil
	end
	playerDataAccess._controller = controller
	return controller
end)

function playerDataAccess.getController(): any?
	return loadController()
end

function playerDataAccess.waitUntilLoaded(): ()
	local controller = loadController()
	if not controller then
		return
	end
	setthreadidentity(2)
	controller.WaitUntilLoaded(controller)
	setthreadidentity(8)
end

function playerDataAccess.get(key: string): any
	local controller = loadController()
	if not controller then
		return nil
	end
	setthreadidentity(2)
	local value = controller.Get(controller, key)
	setthreadidentity(8)
	return value
end

function playerDataAccess.getWeaponData(weaponName: string): any
	local controller = loadController()
	if not controller then
		return nil
	end
	setthreadidentity(2)
	local value = controller.GetWeaponData(controller, weaponName)
	setthreadidentity(8)
	return value
end

function playerDataAccess.subscribe(key: string, callback: () -> ()): () -> ()
	local controller = loadController()
	if not controller then
		return function() end
	end
	setthreadidentity(2)
	local signal = controller.GetDataChangedSignal(controller, key)
	setthreadidentity(8)
	if type(signal) ~= "table" or type(signal.Connect) ~= "function" then
		return function() end
	end
	local conn = signal:Connect(LPH_NO_VIRTUALIZE(function()
		setthreadidentity(8)
		local okCb, errCb = pcall(callback)
		setthreadidentity(2)
		if not okCb then
			logger:warn("subscribe callback error: " .. tostring(errCb))
		end
	end))
	return function()
		if conn and conn.Disconnect then
			conn:Disconnect()
		end
	end
end

return playerDataAccess
