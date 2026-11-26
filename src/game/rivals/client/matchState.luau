local Players = cloneref(game:GetService("Players")) :: Players
local Charm = require("@pkg/Charm")

local at = Charm.atom

local LocalPlayer = Players.LocalPlayer

local MatchState = {
	inGame = at(false) :: Charm.Atom<boolean>,
	teamId = at("") :: Charm.Atom<string>,
	environmentId = at("") :: Charm.Atom<string>,
}

local readStringAttribute = LPH_NO_VIRTUALIZE(function(inst: Instance, name: string): string
	local value = inst:GetAttribute(name)
	if type(value) == "string" then
		return value
	end
	return ""
end)

local readEnvironmentFromInstance = LPH_NO_VIRTUALIZE(function(inst: Instance?): string
	local current = inst
	while current and current:IsDescendantOf(workspace) do
		local value = readStringAttribute(current, "EnvironmentID")
		if value ~= "" then
			return value
		end
		current = current.Parent
	end
	return ""
end)

local function refresh()
	local team = readStringAttribute(LocalPlayer, "TeamID")
	local env = readStringAttribute(LocalPlayer, "EnvironmentID")
	if env == "" then
		env = readEnvironmentFromInstance(LocalPlayer.Character)
	end
	MatchState.teamId(team)
	MatchState.environmentId(env)
	MatchState.inGame(team ~= "" or env ~= "")
end

LocalPlayer:GetAttributeChangedSignal("TeamID"):Connect(refresh)
LocalPlayer:GetAttributeChangedSignal("EnvironmentID"):Connect(refresh)
LocalPlayer.CharacterAdded:Connect(LPH_NO_VIRTUALIZE(function(character: Model): ()
	refresh()
	character:GetAttributeChangedSignal("EnvironmentID"):Connect(refresh)
	character.AncestryChanged:Connect(refresh)
end))
LocalPlayer.CharacterRemoving:Connect(refresh)

refresh()

return MatchState
