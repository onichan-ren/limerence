local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")
local worldEspState = require("@game/ar2/feature/visuals/world/worldEspState")

local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local peek = Charm.peek

local binTracker = {}

function binTracker.track(
	binName: string,
	entries: Charm.Atom<{ [Model]: worldEspState.WorldEntry }>,
	makeLabel: (model: Model) -> string,
	shouldInclude: ((model: Model) -> boolean)?
): Janitor.Janitor
	local janitor = Janitor.new()
	local attrConns: { [Model]: RBXScriptConnection } = {}

	local function setEntry(model: Model, present: boolean): ()
		local current = peek(entries)
		if present then
			if not current[model] then
				entries(Sift.Dictionary.set(current, model, {
					model = model,
					label = makeLabel(model),
				}))
			end
		elseif current[model] then
			entries(Sift.Dictionary.removeKey(current, model))
		end
	end

	local function evaluate(model: Model): ()
		setEntry(model, shouldInclude == nil or shouldInclude(model) == true)
	end

	local function add(child: Instance): ()
		if not child:IsA("Model") then
			return
		end
		local model = child :: Model
		if shouldInclude and not attrConns[model] then
			attrConns[model] = model.AttributeChanged:Connect(function(): ()
				evaluate(model)
			end)
		end
		evaluate(model)
	end

	local function remove(child: Instance): ()
		local model = child :: Model
		local conn = attrConns[model]
		if conn then
			conn:Disconnect()
			attrConns[model] = nil
		end
		if peek(entries)[model] then
			entries(Sift.Dictionary.removeKey(peek(entries), model))
		end
	end

	local function clearAttrConns(): ()
		for model, conn in next, attrConns do
			conn:Disconnect()
			attrConns[model] = nil
		end
	end

	local function bindBin(bin: Instance): ()
		janitor:Add(bin.ChildAdded:Connect(add), "Disconnect", "childAdded")
		janitor:Add(bin.ChildRemoved:Connect(remove), "Disconnect", "childRemoved")

		local nextEntries = table.clone(peek(entries))
		local changed = false
		for _, child in next, bin:GetChildren() do
			if child:IsA("Model") then
				local model = child :: Model
				if shouldInclude and not attrConns[model] then
					attrConns[model] = model.AttributeChanged:Connect(function(): ()
						evaluate(model)
					end)
				end
				if (shouldInclude == nil or shouldInclude(model) == true) and not nextEntries[model] then
					nextEntries[model] = {
						model = model,
						label = makeLabel(model),
					}
					changed = true
				end
			end
		end
		if changed then
			entries(nextEntries)
		end
	end

	janitor:Add(
		Workspace.ChildAdded:Connect(LPH_NO_VIRTUALIZE(function(child: Instance): ()
			if child.Name == binName then
				clearAttrConns()
				entries({})
				bindBin(child)
			end
		end)),
		"Disconnect",
		"binWatch"
	)

	local bin = Workspace:FindFirstChild(binName)
	if bin then
		bindBin(bin)
	end

	janitor:Add(function(): ()
		clearAttrConns()
		entries({})
	end)

	return janitor
end

return binTracker
