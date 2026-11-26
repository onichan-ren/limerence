local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local Players = cloneref(game:GetService("Players")) :: Players
local RunService = cloneref(game:GetService("RunService")) :: RunService

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local instances = require("@share/instances")
local hook = require("@share/hook")
local ModuleController = require("@game/rivals/module/ModuleController")
local FileController = require("@feature/file/FileController")
local Ripple = require("@pkg/Ripple")

local FILL_COLOR = Color3.fromRGB(144, 255, 158)
local OUTLINE_COLOR = Color3.fromRGB(63, 202, 81)
local DOWN_RAY = Vector3.new(0, -14, 0)
local PENDING_LIMIT = 24

local LocalPlayer = Players.LocalPlayer
local hui = cloneref(gethui())

local FootstepEsp = {}
FootstepEsp.__index = FootstepEsp

setmetatable(FootstepEsp, { __index = BaseFeature })

function FootstepEsp.new(link: gameUi.Linker): FootstepEsp
	local self = BaseFeature.new() :: any
	setmetatable(self, FootstepEsp)

	local toggle = link:Toggle("footstepEsp", "Footstep ESP", false):SetTip({
		title = "Footstep ESP",
		body = "Shows a ring on the ground where enemy footsteps come from.",
	})
	link:Extra(toggle, "footstepColor", "Colorpicker", "Color", FILL_COLOR, 0)
	local espLink = link:OnKey("footstepEsp")
	espLink:Submenu("opts", "Footstep ESP Options")
	local optsLink = espLink:OnKey("opts")
	optsLink:Colorpicker("outlineColor", "Outline Color", OUTLINE_COLOR, 1)

	self._enabled = false
	self._janitor = Janitor.new()
	self._pending = {} :: { { pos: Vector3, model: Instance? } }
	self._hookTarget = nil :: any
	self._folder = nil :: Folder?
	self._renderConn = nil :: RBXScriptConnection?
	self._rayParams = RaycastParams.new()
	self._rayParams.FilterType = Enum.RaycastFilterType.Exclude

	self:Track(toggle:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(link:Get("footstepColor"):OnColorChange(function(color: Color3): ()
		self._color = color
	end))
	self:Track(link:Get("footstepColor"):OnTransparencyChange(function(transparency: number): ()
		self._transparency = transparency
	end))
	self:Track(optsLink:Get("outlineColor"):OnColorChange(function(color: Color3): ()
		self._outlineColor = color
	end))
	self:Track(optsLink:Get("outlineColor"):OnTransparencyChange(function(transparency: number): ()
		self._outlineTransparency = transparency
	end))

	self._color = link:Get("footstepColor"):GetColor()
	self._transparency = link:Get("footstepColor"):GetTransparency()
	self._outlineColor = optsLink:Get("outlineColor"):GetColor()
	self._outlineTransparency = optsLink:Get("outlineColor"):GetTransparency()

	return self
end

function FootstepEsp._spawnRing(self: FootstepEsp, origin: Vector3, model: Instance?): ()
	local folder = self._folder
	if not folder then
		return
	end

	local filter: { Instance } = { folder }
	if model then
		filter[#filter + 1] = model
	end
	local localChar = LocalPlayer.Character
	if localChar then
		filter[#filter + 1] = localChar
	end
	self._rayParams.FilterDescendantsInstances = filter

	local result = Workspace:Raycast(origin, DOWN_RAY, self._rayParams)
	local groundY = result and result.Position.Y or (origin.Y - 3)
	local position = Vector3.new(origin.X, groundY, origin.Z)

	local transparency = self._transparency
	local outlineTransparency = self._outlineTransparency

	local ring = instances.newSimple("MeshPart", {
		MeshId = FileController.Get("mesh", "ring"),
		Material = Enum.Material.Glass,
		Reflectance = -99999999999999999,
		Color = self._color,
		Transparency = transparency,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Anchored = true,
		CFrame = CFrame.new(position) * CFrame.Angles(math.pi / 2, 0, 0),
		Size = Vector3.new(0.3, 0.3, 0.09),
		Parent = folder,
	}) :: MeshPart

	local highlight = instances.newSimple("Highlight", {
		Parent = hui,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		Adornee = ring,
		FillColor = self._color,
		FillTransparency = transparency,
		OutlineColor = self._outlineColor,
		OutlineTransparency = outlineTransparency,
	}) :: Highlight

	local spring = Ripple.createSpring(0, {
		tension = 52,
		friction = 18,
		mass = 1,
		start = true,
		precision = 0.01,
	})

	spring:onChange(LPH_NO_VIRTUALIZE(function(value: number, dt): ()
		local newTransparency = transparency + (1 - transparency) * value
		local newOutlineTransparency = outlineTransparency + (1 - outlineTransparency) * value
		ring.Transparency = newTransparency
		highlight.OutlineTransparency = newOutlineTransparency
		highlight.FillTransparency = newTransparency
		highlight.OutlineColor = self._outlineColor
		highlight.FillColor = self._color
		ring.Size *= Vector3.new(1 + 1.38 * dt, 1 + 1.38 * dt, 1)
	end))
	spring:onComplete(function(): ()
		highlight.Enabled = false
		highlight.Adornee = nil
		highlight:Destroy()
		ring:Destroy()
	end)
	spring:setGoal(1)

	self._janitor:Add(function(): ()
		spring:destroy()
		highlight.Enabled = false
		highlight.Adornee = nil
		highlight:Destroy()
		ring:Destroy()
	end, true)
end

function FootstepEsp._drain(self: FootstepEsp): ()
	local pending = self._pending
	local count = #pending
	if count == 0 then
		return
	end
	for i = 1, count do
		local entry = pending[i]
		self:_spawnRing(entry.pos, entry.model)
	end
	table.clear(pending)
end

function FootstepEsp.Enable(self: FootstepEsp): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._folder = instances.new("Folder", {}, Workspace) :: Folder

	local Sounds = ModuleController.GetModule("FootstepSounds")
	if type(Sounds) == "table" then
		local original = rawget(Sounds, "_UpdateFootstep")
		if type(original) == "function" then
			self._hookTarget = original
			local pending = self._pending
			local trampoline
			trampoline = hook.add(
				original,
				LPH_NO_VIRTUALIZE(function(sounds: any, ...: any): ...any
					local before = sounds._last_footstep
					local results = table.pack(trampoline(sounds, ...))
					if sounds._last_footstep ~= before then
						local character = sounds.ClientFighterCharacter
						local fighter = character and character.ClientFighter
						if fighter and not fighter.IsLocalPlayer then
							local root = character.RootPart
							if root and #pending < PENDING_LIMIT then
								pending[#pending + 1] = { pos = root.Position, model = root.Parent }
							end
						end
					end
					return table.unpack(results, 1, results.n)
				end)
			)
		end
	end

	self._renderConn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
		self:_drain()
	end))
end

function FootstepEsp.Disable(self: FootstepEsp): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._renderConn then
		self._renderConn:Disconnect()
		self._renderConn = nil
	end
	if self._hookTarget then
		hook.restore(self._hookTarget)
		self._hookTarget = nil
	end

	table.clear(self._pending)
	self._janitor:Cleanup()

	if self._folder then
		self._folder:Destroy()
		self._folder = nil
	end
end

function FootstepEsp.Destroy(self: FootstepEsp): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type FootstepEsp =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_pending: { { pos: Vector3, model: Instance? } },
			_hookTarget: any,
			_folder: Folder?,
			_renderConn: RBXScriptConnection?,
			_rayParams: RaycastParams,
			_color: Color3,
			_transparency: number,
			_outlineColor: Color3,
			_outlineTransparency: number,
			_spawnRing: (FootstepEsp, Vector3, Instance?) -> (),
			_drain: (FootstepEsp) -> (),
		},
		FootstepEsp
	))
	& BaseFeature.BaseFeature

return FootstepEsp
