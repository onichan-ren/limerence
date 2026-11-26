local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local Charm = require("@pkg/Charm")
local CustomCharacterOverlay = require("@game/universal/feature/misc/CustomCharacterOverlay")
local gameUi = require("@game/gameUi")
local localState = require("@game/universal/client/localState")

local peek = Charm.peek

local FIRST_PERSON_DISTANCE = 1.5

local CustomCharacter = {}

CustomCharacter.model = Charm.atom(nil :: Model?) :: Charm.Atom<Model?>

local function isThirdPerson(): boolean
	local head = peek(localState.parts).Head :: BasePart?
	local camera = Workspace.CurrentCamera
	if not head or not camera then
		return false
	end
	return (camera.CFrame.Position - head.Position).Magnitude > FIRST_PERSON_DISTANCE
end

local function rootOffset(realHumanoid: Humanoid?, fakeHumanoid: Humanoid, _footPart: BasePart?): number
	if peek(localState.rigType) == Enum.HumanoidRigType.R6 then
		return CustomCharacterOverlay.r6RootOffset()
	end
	if realHumanoid then
		return realHumanoid.HipHeight - fakeHumanoid.HipHeight
	end
	return 0
end

function CustomCharacter.new(link: gameUi.Linker): CustomCharacterOverlay.CustomCharacterOverlay
	localState.setup()
	return CustomCharacterOverlay.new(link, {
		characterAtom = localState.character,
		partsAtom = localState.parts,
		aliveAtom = localState.alive,
		modelAtom = CustomCharacter.model,
		rigType = function(): Enum.HumanoidRigType
			return peek(localState.rigType)
		end,
		rootOffset = rootOffset,
		isThirdPerson = isThirdPerson,
	})
end

return CustomCharacter
