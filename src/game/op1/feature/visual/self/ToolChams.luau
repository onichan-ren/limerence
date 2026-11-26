local gameUi = require("@game/gameUi")
local selfChamsBase = require("@game/op1/feature/visual/self/selfChamsBase")
local StateController = require("@game/op1/state/StateController")

local DEFAULT_COLOR = Color3.fromRGB(180, 180, 180)

local SKIP_PARTS: { [string]: boolean } = {
	RedDot = true,
	ReticuleSight = true,
	ScopeTint = true,
}

local function collect(charObject: any): { BasePart }
	local parts: { BasePart } = {}
	local values = charObject.values
	if not values then
		return parts
	end

	local seen: { [Instance]: boolean } = {}

	for _, holder in next, { values.equipped, values.holding } do
		local model = type(holder) == "table" and holder.instance or nil
		if typeof(model) == "Instance" and not seen[model] then
			seen[model] = true
			for _, descendant in next, model:QueryDescendants("BasePart") do
				if descendant.Transparency < 1 and not SKIP_PARTS[descendant.Name] then
					parts[#parts + 1] = descendant
				end
			end
		end
	end

	return parts
end

local function watch(charObject: any, schedule: () -> ()): (() -> ())?
	local cleanups: { () -> () } = {}

	local states = charObject.states
	if states and states.equipped then
		cleanups[#cleanups + 1] = StateController.HookState(states.equipped, function(): ()
			schedule()
		end)
	end
	if states and states.holding then
		cleanups[#cleanups + 1] = StateController.HookState(states.holding, function(): ()
			schedule()
		end)
	end

	local viewmodels = charObject.values and charObject.values.viewmodels
	if viewmodels then
		local connection = viewmodels.DescendantAdded:Connect(function(desc: Instance): ()
			if desc:IsA("BasePart") then
				schedule()
			end
		end)
		cleanups[#cleanups + 1] = function(): ()
			connection:Disconnect()
		end
	end

	return function(): ()
		for _, cleanup in next, cleanups do
			cleanup()
		end
	end
end

local function collectThirdPerson(clone: any): { BasePart }
	local parts: { BasePart } = {}
	local weapon = clone:GetWeaponModel()
	if typeof(weapon) == "Instance" then
		for _, descendant in next, weapon:QueryDescendants("BasePart") do
			if descendant.Transparency < 1 and not SKIP_PARTS[descendant.Name] then
				parts[#parts + 1] = descendant
			end
		end
	end
	return parts
end

local ToolChams = {}

function ToolChams.new(link: gameUi.Linker): selfChamsBase.SelfChams
	return selfChamsBase.new(link, {
		key = "toolChams",
		label = "Tool Chams",
		tip = "Recolors your held weapon.",
		defaultColor = DEFAULT_COLOR,
		defaultMaterial = "Neon",
		collect = collect,
		collectThirdPerson = collectThirdPerson,
		watch = watch,
	})
end

return ToolChams
