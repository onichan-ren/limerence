local hook = require("@share/hook")
local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local ModuleController = require("@game/pf/module/ModuleController")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local FileController = require("@feature/file/FileController")
local Ripple = require("@pkg/Ripple")

local Workspace = cloneref(workspace)
local hui = cloneref(gethui())

local sub = Charm.subscribe
local peek = Charm.peek

local RAY_UP = Vector3.new(0, 2, 0)
local RAY_DOWN = Vector3.new(0, -12, 0)

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local state = {
	enabled = false,
	hooked = false,
	playSound = nil :: any,
	janitor = Janitor.new(),
	color = Color3.fromRGB(144, 255, 158),
	transparency = 0,
	outlineColor = Color3.fromRGB(63, 202, 81),
	outlineTransparency = 1,
	playersFolder = nil :: Instance?,
}

local rayFilter: { Instance } = {}

local renderSound = LPH_NO_VIRTUALIZE(function(part: BasePart): ()
	local origin = part.Position
	local players = state.playersFolder
	if not players or not players.Parent then
		players = Workspace:FindFirstChild("Players")
		state.playersFolder = players
	end
	rayFilter[1] = players :: Instance
	rayFilter[2] = Workspace.CurrentCamera :: Instance
	raycastParams.FilterDescendantsInstances = rayFilter
	local result = Workspace:Raycast(origin + RAY_UP, RAY_DOWN, raycastParams)
	local groundY = (result and result.Position.Y) or (origin.Y - 3)
	local position = Vector3.new(origin.X, groundY, origin.Z)

	local outlineTransparency = state.outlineTransparency
	local transparency = state.transparency

	local ring = instances.newSimple("MeshPart", {
		MeshId = FileController.Get("mesh", "ring"),
		Material = Enum.Material.Glass,
		Reflectance = -99999999999999999,
		Color = state.color,
		Transparency = transparency,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Anchored = true,
		CFrame = CFrame.new(position) * CFrame.Angles(math.pi / 2, 0, 0),
		Size = Vector3.new(0.3, 0.3, 0.09),
		Parent = Workspace,
	}) :: MeshPart

	local highlight = instances.newSimple("Highlight", {
		Parent = hui,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		Adornee = ring,
		FillColor = state.color,
		FillTransparency = transparency,
		OutlineColor = state.outlineColor,
		OutlineTransparency = outlineTransparency,
	}) :: Highlight

	local spring = Ripple.createSpring(0, {
		tension = 52,
		friction = 18,
		mass = 1,
		start = true,
		precision = 0.01,
	})

	spring:onChange(function(value: number, dt): ()
		local newTransparency = transparency + (1 - transparency) * value
		local newOutlineTransparency = outlineTransparency + (1 - outlineTransparency) * value
		ring.Transparency = newTransparency
		highlight.OutlineTransparency = newOutlineTransparency
		highlight.FillTransparency = newTransparency
		highlight.OutlineColor = state.outlineColor
		highlight.FillColor = state.color
		ring.Size *= Vector3.new(1 + 1.38 * dt, 1 + 1.38 * dt, 1)
	end)
	spring:onComplete(function(): ()
		highlight.Enabled = false
		highlight.Adornee = nil
		highlight:Destroy()
		ring:Destroy()
	end)
	spring:setGoal(1)

	state.janitor:Add(function(): ()
		spring:destroy()
		highlight.Enabled = false
		highlight.Adornee = nil
		highlight:Destroy()
		ring:Destroy()
	end, true)
end)

local function enable(): ()
	if state.hooked then
		return
	end

	local AudioSystem = ModuleController.GetModule("AudioSystem")
	if not AudioSystem then
		return
	end
	local playSound = rawget(AudioSystem, "playSound")
	if type(playSound) ~= "function" then
		return
	end

	state.hooked = true
	state.playSound = playSound

	local old
	old = hook.add(playSound, LPH_NO_VIRTUALIZE(function(name: any, a2: any, a3: any, a4: any, a5: any, a6: any, a7: any, part: any, ...)
		if
			state.enabled
			and type(name) == "string"
			and string.sub(name, 1, 6) == "enemy_"
			and typeof(part) == "Instance"
			and part:IsA("BasePart")
		then
			setthreadidentity(8)
			renderSound(part)
			setthreadidentity(2)
		end
		return old(name, a2, a3, a4, a5, a6, a7, part, ...)
	end))
end

local function disable(): ()
	state.janitor:Cleanup()
	if state.hooked and state.playSound then
		hook.restore(state.playSound)
	end
	state.hooked = false
	state.playSound = nil
	state.playersFolder = nil
end

local function setup(link: gameUi.Linker): { enabled: any }
	local toggle = link:Toggle("sounds", "Sounds", false):SetTip({
		title = "Sounds",
		body = "Shows a ring on the ground when enemies take footsteps.",
	})
	link:Extra(toggle, "soundsColor", "Colorpicker", "Color", Color3.fromRGB(144, 255, 158), 0)
	local soundsLink = link:OnKey("sounds")
	soundsLink:Submenu("opts", "Options")
	local soundsOpts = soundsLink:OnKey("opts")
	soundsOpts:Colorpicker("outlineColor", "Outline Color", Color3.fromRGB(63, 202, 81), 1)

	local colorEl = link:Get("soundsColor")
	state.color = colorEl:GetColor()
	state.transparency = colorEl:GetTransparency()
	colorEl:OnColorChange(function(color: Color3): ()
		state.color = color
	end)
	colorEl:OnTransparencyChange(function(transparency: number): ()
		state.transparency = transparency
	end)

	local outlineEl = soundsOpts:Get("outlineColor")
	state.outlineColor = outlineEl:GetColor()
	state.outlineTransparency = outlineEl:GetTransparency()
	outlineEl:OnColorChange(function(color: Color3): ()
		state.outlineColor = color
	end)
	outlineEl:OnTransparencyChange(function(transparency: number): ()
		state.outlineTransparency = transparency
	end)

	local enabledEl = link:Get("sounds")
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
	id = "sounds",
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
