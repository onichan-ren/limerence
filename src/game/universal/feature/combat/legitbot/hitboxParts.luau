local HITBOX_PARTS: { [string]: { string } } = {
	Head = { "Head", "HitboxHead" },
	Torso = {
		"UpperTorso",
		"Torso",
		"LowerTorso",
		"HitboxBody",
		"HitboxTorso",
		"HitboxUpperTorso",
		"HitboxLowerTorso",
	},
	Arms = {
		"LeftUpperArm",
		"RightUpperArm",
		"LeftLowerArm",
		"RightLowerArm",
		"LeftHand",
		"RightHand",
		"Left Arm",
		"Right Arm",
		"HitboxLeftArm",
		"HitboxRightArm",
		"HitboxArm",
	},
	Legs = {
		"LeftUpperLeg",
		"RightUpperLeg",
		"LeftLowerLeg",
		"RightLowerLeg",
		"Left Leg",
		"Right Leg",
		"HitboxLeftLeg",
		"HitboxRightLeg",
		"HitboxLeg",
	},
	Feet = { "LeftFoot", "RightFoot", "HitboxLeftFoot", "HitboxRightFoot", "HitboxFoot" },
}

local PART_TO_HITBOX: { [string]: string } = {}
for hitboxName, partNames in next, HITBOX_PARTS do
	for _, partName in next, partNames do
		PART_TO_HITBOX[partName] = hitboxName
	end
end

PART_TO_HITBOX.HeadCollider = "Head"

local DAMAGE_PART_KEY: { [string]: string } = {
	Head = "Head",
	Torso = "Torso",
	Arms = "Arms",
	Legs = "Legs",
	Feet = "Legs",
}

return {
	HITBOX_PARTS = HITBOX_PARTS,
	PART_TO_HITBOX = PART_TO_HITBOX,
	DAMAGE_PART_KEY = DAMAGE_PART_KEY,
}
