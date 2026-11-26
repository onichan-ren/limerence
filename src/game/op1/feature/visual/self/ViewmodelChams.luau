local gameUi = require("@game/gameUi")
local selfChamsBase = require("@game/op1/feature/visual/self/selfChamsBase")
local chamsUtil = require("@game/op1/feature/visual/self/chamsUtil")

local ARM_PARTS: { [string]: boolean } = {
	arm1 = true,
	arm2 = true,
	shoulder1 = true,
	shoulder2 = true,
}

local DEFAULT_COLOR = Color3.fromRGB(200, 120, 120)

local function collect(charObject: any): { BasePart }
	local viewmodels = charObject.values and charObject.values.viewmodels
	if not viewmodels then
		return {}
	end

	return chamsUtil.collectByRoots(viewmodels, ARM_PARTS)
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

local ViewmodelChams = {}

function ViewmodelChams.new(link: gameUi.Linker): selfChamsBase.SelfChams
	return selfChamsBase.new(link, {
		key = "viewmodelChams",
		label = "Viewmodel Chams",
		tip = "Recolors your first person arms.",
		defaultColor = DEFAULT_COLOR,
		defaultMaterial = "Neon",
		collect = collect,
		watch = watch,
		suppressInThirdPerson = true,
	})
end

return ViewmodelChams
