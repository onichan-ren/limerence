local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local folderChams = require("@game/pf/feature/visual/chams/folderChams")

local sub = Charm.subscribe
local peek = Charm.peek

local DEFAULT_COLOR = Color3.fromRGB(255, 80, 80)

local function visiblePart(part: BasePart): boolean
	return part.Transparency < 0.99
end

local state = {
	enabled = false,
	chams = nil :: any,
	colorLink = nil :: any,
	material = Enum.Material.Neon :: Enum.Material,
}

local function enable(): ()
	if state.chams and state.colorLink then
		state.chams:enable(state.colorLink:GetColor(), state.material)
	end
end

local function disable(): ()
	if state.chams then
		state.chams:disable()
	end
end

local function setup(link: gameUi.Linker): { enabled: any }
	link:Toggle("ragdollChams", "Ragdoll Chams", false):SetTip({
		title = "Ragdoll Chams",
		body = "Recolors the bodies of dead players.",
	})
	local chamsLink = link:OnKey("ragdollChams")
	chamsLink:Submenu("opts", "Ragdoll Chams")
	local optsLink = chamsLink:OnKey("opts")
	optsLink:Dropdown("material", "Material", folderChams.MATERIALS, "Neon")
	optsLink:Colorpicker("color", "Color", DEFAULT_COLOR)

	state.chams = state.chams or folderChams.new("DeadBody", visiblePart)
	state.colorLink = link:Get("ragdollChams.opts.color")
	state.material = folderChams.material(link:Peek("ragdollChams.opts.material"))

	link:Watch("ragdollChams.opts.material", function(value: string): ()
		state.material = folderChams.material(value)
		if state.chams then
			state.chams:setStyle(state.colorLink:GetColor(), state.material)
		end
	end)
	state.colorLink:OnColorChange(function(color: Color3): ()
		if state.chams then
			state.chams:setStyle(color, state.material)
		end
	end)

	local enabledEl = link:Get("ragdollChams")
	state.enabled = peek(enabledEl._state) == true
	if state.enabled then
		enable()
	end
	sub(enabledEl._state, function(value: boolean): ()
		state.enabled = value == true
		if value then
			enable()
		else
			disable()
		end
	end)

	return { enabled = enabledEl }
end

return {
	id = "ragdollChams",
	container = false,
	setup = setup,
	createState = function(): any
		return {}
	end,
	update = function(): () end,
	render = function(): any
		return nil
	end,
} :: any
