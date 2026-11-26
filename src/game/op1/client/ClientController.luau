local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local clientState = require("@game/op1/client/clientState")
local CharacterController = require("@game/op1/character/CharacterController")

local Players = cloneref(game:GetService("Players"))
local LocalPlayer = Players.LocalPlayer

local peek = Charm.peek

local ClientController = {
	_janitor = nil :: Janitor.Janitor?,
	_characterJanitor = nil :: Janitor.Janitor?,
	_token = 0,
}

local function updateTeam(): ()
	clientState.team(tostring(LocalPlayer:GetAttribute("Team") or ""))
end

local function bind(object: any, characterJanitor: Janitor.Janitor): ()
	local model = object.instance
	local humanoid = model:FindFirstChildOfClass("Humanoid")

	clientState.charObject(object)
	clientState.character(model)
	clientState.hrp(object.values.rootpart)
	clientState.humanoid(humanoid)

	local function updateAlive(): ()
		clientState.alive(not (object.clean and object.clean:get()))
	end

	if humanoid then
		clientState.health(humanoid.Health)
		clientState.maxHealth(humanoid.MaxHealth)

		characterJanitor:Add(
			humanoid:GetPropertyChangedSignal("Health"):Connect(function(): ()
				clientState.health(humanoid.Health)
			end),
			"Disconnect"
		)
		characterJanitor:Add(
			humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function(): ()
				clientState.maxHealth(humanoid.MaxHealth)
			end),
			"Disconnect"
		)
	end

	if object.clean then
		characterJanitor:Add(object.clean:hook(updateAlive).unhook, true)
	end

	updateAlive()
end

local function onObjectAdded(object: any): ()
	local characterJanitor = ClientController._characterJanitor :: Janitor.Janitor
	characterJanitor:Cleanup()
	ClientController._token += 1
	local token = ClientController._token

	task.spawn(function(): ()
		for _ = 1, 50 do
			if ClientController._token ~= token then
				return
			end

			if object.values and object.values.rootpart then
				break
			end

			task.wait(0.1)
		end

		if ClientController._token ~= token or not (object.values and object.values.rootpart) then
			return
		end

		bind(object, characterJanitor)
	end)
end

local function onObjectRemoving(): ()
	ClientController._token += 1

	local characterJanitor = ClientController._characterJanitor
	if characterJanitor then
		characterJanitor:Cleanup()
	end

	clientState.alive(false)
	clientState.health(0)
	clientState.charObject(nil)
	clientState.character(nil)
	clientState.hrp(nil)
	clientState.humanoid(nil)
end

function ClientController.new(): ClientController
	local janitor = Janitor.new()
	ClientController._janitor = janitor
	ClientController._characterJanitor = janitor:Add(Janitor.new(), "Destroy")

	janitor:Add(LocalPlayer:GetAttributeChangedSignal("Team"):Connect(updateTeam), "Disconnect")

	janitor:Add(
		CharacterController.objectAdded:Connect(function(owner: Player, object: any)
			if owner == LocalPlayer then
				onObjectAdded(object)
			end
		end),
		"Disconnect"
	)
	janitor:Add(
		CharacterController.objectRemoving:Connect(function(owner: Player, object: any)
			if owner == LocalPlayer and peek(clientState.charObject) == object then
				onObjectRemoving()
			end
		end),
		"Disconnect"
	)

	updateTeam()

	local existing = CharacterController.GetObject(LocalPlayer)
	if existing then
		onObjectAdded(existing)
	end

	return ClientController
end

function ClientController.Destroy(): ()
	local janitor = ClientController._janitor
	if janitor then
		janitor:Destroy()
		ClientController._janitor = nil
		ClientController._characterJanitor = nil
	end
end

export type ClientController = typeof(ClientController)

return ClientController
