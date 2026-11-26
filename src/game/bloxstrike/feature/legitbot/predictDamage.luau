local Charm = require("@pkg/Charm")
local hitboxParts = require("@game/universal/feature/combat/legitbot/hitboxParts")

local peek = Charm.peek

local PART_TO_HITBOX = hitboxParts.PART_TO_HITBOX
local DAMAGE_PART_KEY = hitboxParts.DAMAGE_PART_KEY

local DISTANCE_REFERENCE = 500

return LPH_NO_VIRTUALIZE(
	function(origin: Vector3, part: BasePart, weapon: any, walls: number | boolean, bp: any?): number
		local props = weapon and weapon.Properties
		if not props then
			return 0
		end
		local damageTable = props.DamagePerPart
		if not damageTable then
			return 0
		end
		local hitbox = PART_TO_HITBOX[part.Name]
		if not hitbox then
			return 0
		end
		local base = damageTable[DAMAGE_PART_KEY[hitbox]]
		if not base then
			return 0
		end

		local distance = (part.Position - origin).Magnitude
		local rangeMod = props.RangeModifier or 1
		local damage = base * (rangeMod ^ (distance / DISTANCE_REFERENCE))

		local wallCount = 0
		if walls == true then
			wallCount = 1
		elseif type(walls) == "number" and walls > 0 then
			wallCount = walls
		end
		if wallCount > 0 then
			damage *= (props.WallbangMultiplier or 1) ^ wallCount
		end

		local armorAtom = bp and type(bp) == "table" and peek(bp.armor)
		local hasArmor = armorAtom and armorAtom.kevlar or false
		local hasHelmet = armorAtom and armorAtom.helmet or false
		local armorPen = props.ArmorPenetration or 1
		if hitbox == "Head" then
			if hasHelmet then
				damage *= armorPen
			end
		elseif hasArmor then
			damage *= armorPen
		end

		return damage
	end
)
