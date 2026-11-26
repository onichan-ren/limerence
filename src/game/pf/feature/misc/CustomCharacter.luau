local Charm = require("@pkg/Charm")
local CustomCharacterOverlay = require("@game/universal/feature/misc/CustomCharacterOverlay")
local gameUi = require("@game/gameUi")
local clientState = require("@game/pf/client/clientState")
local localThirdPerson = require("@game/pf/thirdperson/localThirdPerson")

local peek = Charm.peek

local CustomCharacter = {}

CustomCharacter.model = Charm.atom(nil :: Model?) :: Charm.Atom<Model?>
CustomCharacter.visibleModel = Charm.atom(nil :: Model?) :: Charm.Atom<Model?>

local function poseFrom(parentName: string, childName: string): CustomCharacterOverlay.JointModifier
	return function(joint: Motor6D | AnimationConstraint, base: CFrame): CFrame
		local motor = joint :: Motor6D
		local parts = peek(clientState.parts)
		local parent = parts[parentName] :: BasePart?
		local child = parts[childName] :: BasePart?
		if not parent or not child then
			return base
		end
		return (parent.CFrame * motor.C0):ToObjectSpace(child.CFrame * motor.C1)
	end
end

local JOINT_MODIFIERS: { [string]: CustomCharacterOverlay.JointModifier } = {
	["Left Hip"] = poseFrom("Torso", "Left Leg"),
	["Right Hip"] = poseFrom("Torso", "Right Leg"),
	["Left Shoulder"] = poseFrom("Torso", "Left Arm"),
	["Right Shoulder"] = poseFrom("Torso", "Right Arm"),
	Neck = poseFrom("Torso", "Head"),
}

local function excludeWeapon(instance: Instance): boolean
	local weapon = localThirdPerson.getWeaponModel()
	return weapon ~= nil and instance:IsDescendantOf(weapon)
end

function CustomCharacter.new(link: gameUi.Linker): CustomCharacterOverlay.CustomCharacterOverlay
	return CustomCharacterOverlay.new(link, {
		characterAtom = clientState.thirdPersonModel,
		partsAtom = clientState.parts,
		aliveAtom = clientState.alive,
		modelAtom = CustomCharacter.model,
		visibleModelAtom = CustomCharacter.visibleModel,
		rigType = Enum.HumanoidRigType.R6,
		rootOffset = CustomCharacterOverlay.r6RootOffset,
		isThirdPerson = function(): boolean
			return peek(clientState.thirdPerson)
		end,
		excludedRealPredicate = excludeWeapon,
		jointModifiers = JOINT_MODIFIERS,
	})
end

return CustomCharacter
