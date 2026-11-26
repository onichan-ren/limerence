local Charm = require("@pkg/Charm")
local CustomCharacterOverlay = require("@game/universal/feature/misc/CustomCharacterOverlay")
local gameUi = require("@game/gameUi")
local clientState = require("@game/bloxstrike/client/clientState")
local localLookController = require("@game/bloxstrike/client/localLookController")

local LOOK_SCALE = math.rad(60)

local EXCLUDED_REAL_ANCESTORS: { [string]: true } = {
	WeaponModel = true,
	WeaponAttachments = true,
}

local function lookModifier(factor: number): CustomCharacterOverlay.JointModifier
	return function(_joint: Motor6D | AnimationConstraint, base: CFrame): CFrame
		return CFrame.Angles(localLookController.verticalLook * LOOK_SCALE * factor, 0, 0) * base
	end
end

local JOINT_MODIFIERS: { [string]: CustomCharacterOverlay.JointModifier } = {
	Waist = lookModifier(0.6),
	Neck = lookModifier(1),
	LeftShoulder = lookModifier(0.5),
	RightShoulder = lookModifier(0.5),
}

local CustomCharacter = {}

CustomCharacter.model = Charm.atom(nil :: Model?) :: Charm.Atom<Model?>

function CustomCharacter.new(link: gameUi.Linker): CustomCharacterOverlay.CustomCharacterOverlay
	return CustomCharacterOverlay.new(link, {
		characterAtom = clientState.character,
		partsAtom = clientState.parts,
		aliveAtom = clientState.alive,
		modelAtom = CustomCharacter.model,
		excludedRealAncestors = EXCLUDED_REAL_ANCESTORS,
		isThirdPerson = localLookController.IsThirdPerson,
		rigType = Enum.HumanoidRigType.R15,
		rootOffset = CustomCharacterOverlay.r15RootOffset,
		jointModifiers = JOINT_MODIFIERS,
	})
end

return CustomCharacter
