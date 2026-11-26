local gameUi = require("@game/gameUi")
local selfChamsBase = require("@game/op1/feature/visual/self/selfChamsBase")
local chamsUtil = require("@game/op1/feature/visual/self/chamsUtil")

local BODY_PARTS: { [string]: boolean } = {
	head = true,
	torso = true,
	hip1 = true,
	hip2 = true,
	leg1 = true,
	leg2 = true,
}

local DEFAULT_COLOR = Color3.fromRGB(170, 200, 230)

local function collect(charObject: any): { BasePart }
	local viewmodels = charObject.values and charObject.values.viewmodels
	if not viewmodels then
		return {}
	end

	return chamsUtil.collectByRoots(viewmodels, BODY_PARTS)
end

local function watch(charObject: any, schedule: () -> ()): (() -> ())?
	local viewmodels = charObject.values and charObject.values.viewmodels
	if not viewmodels then
		return nil
	end
	local connection = viewmodels.DescendantAdded:Connect(function(desc: Instance): ()
		if desc:IsA("BasePart") then
			schedule()
		end
	end)
	return function(): ()
		connection:Disconnect()
	end
end

local function collectThirdPerson(clone: any): { BasePart }
	return clone:GetBodyParts()
end

local CharacterChams = {}

function CharacterChams.new(link: gameUi.Linker): selfChamsBase.SelfChams
	return selfChamsBase.new(link, {
		key = "characterChams",
		label = "Character Chams",
		tip = "Recolors your body.",
		defaultColor = DEFAULT_COLOR,
		defaultMaterial = "Neon",
		collect = collect,
		collectThirdPerson = collectThirdPerson,
		watch = watch,
	})
end

return CharacterChams
