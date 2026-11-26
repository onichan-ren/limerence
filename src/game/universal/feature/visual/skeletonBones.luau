local function joint(part: string, ox: number, oy: number, oz: number)
	return { part = part, ox = ox, oy = oy, oz = oz }
end

local function bone(a: any, b: any)
	return { a = a, b = b }
end

local R15_EDGES = {
	bone(joint("Head", 0, 0, 0), joint("UpperTorso", 0, 0, 0)),
	bone(joint("UpperTorso", 0, 0, 0), joint("LowerTorso", 0, 0, 0)),
	bone(joint("UpperTorso", 0, 0, 0), joint("LeftUpperArm", 0, 0, 0)),
	bone(joint("LeftUpperArm", 0, 0, 0), joint("LeftHand", 0, 0, 0)),
	bone(joint("UpperTorso", 0, 0, 0), joint("RightUpperArm", 0, 0, 0)),
	bone(joint("RightUpperArm", 0, 0, 0), joint("RightHand", 0, 0, 0)),
	bone(joint("LowerTorso", 0, 0, 0), joint("LeftUpperLeg", 0, 0, 0)),
	bone(joint("LeftUpperLeg", 0, 0, 0), joint("LeftFoot", 0, 0, 0)),
	bone(joint("LowerTorso", 0, 0, 0), joint("RightUpperLeg", 0, 0, 0)),
	bone(joint("RightUpperLeg", 0, 0, 0), joint("RightFoot", 0, 0, 0)),
}

local R6_EDGES = {
	bone(joint("Torso", 0, 1, 0), joint("Head", 0, 0, 0)),
	bone(joint("Torso", 0, 1, 0), joint("Torso", 0, -1, 0)),
	bone(joint("Torso", 0, 0.5, 0), joint("Left Arm", 0, 0.5, 0)),
	bone(joint("Left Arm", 0, 0.5, 0), joint("Left Arm", 0, -1, 0)),
	bone(joint("Torso", 0, 0.5, 0), joint("Right Arm", 0, 0.5, 0)),
	bone(joint("Right Arm", 0, 0.5, 0), joint("Right Arm", 0, -1, 0)),
	bone(joint("Torso", 0, -1, 0), joint("Left Leg", 0, 1, 0)),
	bone(joint("Left Leg", 0, 1, 0), joint("Left Leg", 0, -1, 0)),
	bone(joint("Torso", 0, -1, 0), joint("Right Leg", 0, 1, 0)),
	bone(joint("Right Leg", 0, 1, 0), joint("Right Leg", 0, -1, 0)),
}

local MAX_EDGES = math.max(#R15_EDGES, #R6_EDGES)

local function pickEdges(parts: { [string]: Instance }): { any }?
	if parts.UpperTorso then
		return R15_EDGES
	end
	if parts.Torso then
		return R6_EDGES
	end
	return nil
end

local endpoint = LPH_NO_VIRTUALIZE(function(
	parts: { [string]: Instance },
	sizes: { [string]: Vector3 }?,
	ep: any
): Vector3?
	local part = parts[ep.part] :: BasePart
	if not part then
		return nil
	end
	if ep.ox == 0 and ep.oy == 0 and ep.oz == 0 then
		return part.Position
	end
	local size = (sizes and sizes[ep.part]) or part.Size
	return part.CFrame * Vector3.new(ep.ox * size.X * 0.5, ep.oy * size.Y * 0.5, ep.oz * size.Z * 0.5)
end)

return {
	R15_EDGES = R15_EDGES,
	R6_EDGES = R6_EDGES,
	MAX_EDGES = MAX_EDGES,
	pickEdges = pickEdges,
	endpoint = endpoint,
}
