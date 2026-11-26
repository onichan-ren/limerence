local Charm = require("@pkg/Charm")
local CustomCharacterOverlay = require("@game/universal/feature/misc/CustomCharacterOverlay")
local gameUi = require("@game/gameUi")
local clientState = require("@game/rivals/client/clientState")
local ModuleController = require("@game/rivals/module/ModuleController")

local isCameraFirstPerson = LPH_NO_VIRTUALIZE(function(): boolean
	local cameraController = ModuleController.GetModule("CameraController")
	if not cameraController then
		return true
	end
	local cameraState = cameraController.CameraState
	if not cameraState then
		return true
	end
	local getPublicState = cameraState.GetPublicState
	local states = cameraState.States
	if type(getPublicState) ~= "function" or type(states) ~= "table" then
		return true
	end
	local firstPersonState = states.FirstPerson
	if type(firstPersonState) ~= "string" then
		return true
	end
	return getPublicState(cameraState) == firstPersonState
end)

local CustomCharacter = {}

CustomCharacter.model = Charm.atom(nil :: Model?) :: Charm.Atom<Model?>

function CustomCharacter.new(link: gameUi.Linker): CustomCharacterOverlay.CustomCharacterOverlay
	return CustomCharacterOverlay.new(link, {
		characterAtom = clientState.character,
		partsAtom = clientState.parts,
		aliveAtom = clientState.alive,
		modelAtom = CustomCharacter.model,
		rigType = Enum.HumanoidRigType.R15,
		rootOffset = CustomCharacterOverlay.r15RootOffset,
		isThirdPerson = function(): boolean
			return not isCameraFirstPerson()
		end,
	})
end

return CustomCharacter
