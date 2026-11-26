local Charm = require("@pkg/Charm")
local clientState = require("@game/overkill/client/clientState")
local antiAimState = require("@game/overkill/feature/antiaim/antiAimState")
local ModuleController = require("@game/overkill/module/ModuleController")
local CustomCharacterOverlay = require("@game/universal/feature/misc/CustomCharacterOverlay")

local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local peek = Charm.peek

local LOOK_SCALE = math.rad(60)

local cameraHandler: any = nil

local function getPitch(): number
	local look = peek(antiAimState.lookAngles)
	if look then
		return math.sin(look.X)
	end
	local cf = peek(clientState.fpCamera) or Workspace.CurrentCamera.CFrame
	return cf.LookVector.Y
end

local function lookModifier(factor: number): CustomCharacterOverlay.JointModifier
	return function(_joint: Motor6D | AnimationConstraint, base: CFrame): CFrame
		return CFrame.Angles(getPitch() * LOOK_SCALE * factor, 0, 0) * base
	end
end

local JOINT_MODIFIERS: { [string]: CustomCharacterOverlay.JointModifier } = {
	Waist = lookModifier(0.6),
	Neck = lookModifier(1),
	LeftShoulder = lookModifier(0.5),
	RightShoulder = lookModifier(0.5),
}

local customCharacterOpts = {
	characterAtom = clientState.character,
	partsAtom = clientState.parts,
	aliveAtom = clientState.alive,
	modelAtom = Charm.atom(nil :: Model?) :: Charm.Atom<Model?>,
	visibleModelAtom = Charm.atom(nil :: Model?) :: Charm.Atom<Model?>,
	rigType = Enum.HumanoidRigType.R15,
	rootOffset = CustomCharacterOverlay.r15RootOffset,
	isThirdPerson = function(): boolean
		if not cameraHandler then
			cameraHandler = ModuleController.GetModule("cameraHandler")
		end
		if not cameraHandler then
			return false
		end
		return cameraHandler.thirdPersonDebug == true or cameraHandler.firstPerson == false
	end,
	jointModifiers = JOINT_MODIFIERS,
}

return customCharacterOpts
