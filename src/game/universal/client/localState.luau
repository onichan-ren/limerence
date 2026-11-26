local Players = cloneref(game:GetService("Players")) :: Players
local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local Sift = require("@pkg/Sift")

local at = Charm.atom
local peek = Charm.peek

local LocalPlayer = Players.LocalPlayer

local function readTeam(): string
	local team = LocalPlayer.Team
	if team then
		return team.Name
	end
	return ""
end

local localState = {
	character = at(nil :: Model?) :: Charm.Atom<Model?>,
	humanoid = at(nil :: Humanoid?) :: Charm.Atom<Humanoid?>,
	hrp = at(nil :: BasePart?) :: Charm.Atom<BasePart?>,
	alive = at(false) :: Charm.Atom<boolean>,
	health = at(0) :: Charm.Atom<number>,
	maxHealth = at(100) :: Charm.Atom<number>,
	team = at("") :: Charm.Atom<string>,
	parts = at({}) :: Charm.Atom<{ [string]: Instance }>,
	rigType = at(Enum.HumanoidRigType.R15) :: Charm.Atom<Enum.HumanoidRigType>,
	_janitor = nil :: Janitor.Janitor?,
	_charJanitor = nil :: Janitor.Janitor?,
	_token = nil :: any,
}

local function clearCharacter(): ()
	if localState._charJanitor then
		localState._charJanitor:Cleanup()
	end
	localState.character(nil)
	localState.humanoid(nil)
	localState.hrp(nil)
	localState.alive(false)
	localState.health(0)
	localState.parts({})
end

local function initCharacter(character: Model): ()
	local token = {}
	localState._token = token

	local janitor = localState._charJanitor
	if janitor then
		janitor:Cleanup()
	else
		janitor = Janitor.new()
		localState._charJanitor = janitor
	end

	local function tryInit(): boolean
		if localState._token ~= token then
			return true
		end
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not hrp or not humanoid then
			return false
		end

		local parts = {}
		for _, child in next, character:GetChildren() do
			parts[child.Name] = child
		end
		localState.parts(parts)
		localState.character(character)
		localState.humanoid(humanoid)
		localState.hrp(hrp)
		localState.rigType(humanoid.RigType)
		localState.alive(humanoid.Health > 0)
		localState.health(humanoid.Health)
		localState.maxHealth(humanoid.MaxHealth)

		janitor:Add(
			character.ChildAdded:Connect(function(part: Instance): ()
				localState.parts(Sift.Dictionary.set(peek(localState.parts), part.Name :: any, part))
			end),
			"Disconnect"
		)
		janitor:Add(
			character.ChildRemoved:Connect(function(part: Instance): ()
				localState.parts(Sift.Dictionary.removeKey(peek(localState.parts), part.Name :: any))
			end),
			"Disconnect"
		)
		janitor:Add(
			humanoid.HealthChanged:Connect(function(health: number): ()
				localState.alive(health > 0)
				localState.health(health)
			end),
			"Disconnect"
		)
		janitor:Add(
			humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function(): ()
				localState.maxHealth(humanoid.MaxHealth)
			end),
			"Disconnect"
		)
		janitor:Add(
			humanoid.Died:Connect(function(): ()
				localState.alive(false)
			end),
			"Disconnect"
		)
		return true
	end

	if tryInit() then
		return
	end

	local conn: RBXScriptConnection
	conn = character.ChildAdded:Connect(function(): ()
		if tryInit() then
			conn:Disconnect()
		end
	end)
	janitor:Add(conn, "Disconnect")
end

function localState.setup(): ()
	if localState._janitor then
		return
	end
	local janitor = Janitor.new()
	localState._janitor = janitor

	janitor:Add(
		LocalPlayer.CharacterAdded:Connect(function(character: Model): ()
			initCharacter(character)
		end),
		"Disconnect"
	)
	janitor:Add(
		LocalPlayer.CharacterRemoving:Connect(function(): ()
			localState._token = nil
			clearCharacter()
		end),
		"Disconnect"
	)
	janitor:Add(
		LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function(): ()
			localState.team(readTeam())
		end),
		"Disconnect"
	)
	localState.team(readTeam())
	janitor:Add(function(): ()
		clearCharacter()
		if localState._charJanitor then
			localState._charJanitor:Destroy()
			localState._charJanitor = nil
		end
	end, true)

	local character = LocalPlayer.Character
	if character then
		task.spawn(function(): ()
			initCharacter(character)
		end)
	end
end

function localState.Destroy(): ()
	local janitor = localState._janitor
	if janitor then
		janitor:Destroy()
		localState._janitor = nil
	end
end

export type localState = typeof(localState)

return localState
