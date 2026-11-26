local hook = require("@share/hook")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local clientState = require("@game/bloxstrike/client/clientState")
local gameUi = require("@game/gameUi")
local gamemodeState = require("@game/bloxstrike/gamemodeState")
local PlayerController = require("@feature/player/PlayerController")
local instances = require("@share/instances")
local FileController = require("@feature/file/FileController")
local Ripple = require("@pkg/Ripple")

local Workspace = cloneref(workspace)
local hui = cloneref(gethui())

local peek = Charm.peek

local SoundESP = {}
SoundESP.__index = SoundESP

setmetatable(SoundESP, { __index = BaseFeature })

function SoundESP.new(link: gameUi.Linker): SoundESP
	local self = BaseFeature.new() :: any
	setmetatable(self, SoundESP)

	self._janitor = Janitor.new()

	local toggle = link:Toggle("sounds", "Sounds", false):SetTip({
		title = "Sounds",
		body = "Shows a ring on the ground when enemies take footsteps.",
	})
	link:Extra(toggle, "soundsColor", "Colorpicker", "Color", Color3.fromRGB(144, 255, 158), 0)
	local soundsLink = link:OnKey("sounds")
	soundsLink:Submenu("opts", "Options")
	local soundsOpts = soundsLink:OnKey("opts")
	soundsOpts:Colorpicker("outlineColor", "Outline Color", Color3.fromRGB(63, 202, 81), 1)

	self:Track(toggle:OnChange(function(enabled: boolean): ()
		if enabled then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(link:Get("soundsColor"):OnColorChange(function(color: Color3): ()
		self._color = color
	end))

	self:Track(link:Get("soundsColor"):OnTransparencyChange(function(transparency: number): ()
		self._transparency = transparency
	end))

	self:Track(soundsOpts:Get("outlineColor"):OnColorChange(function(color: Color3): ()
		self._outlineColor = color
	end))

	self:Track(soundsOpts:Get("outlineColor"):OnTransparencyChange(function(transparency: number): ()
		self._outlineTransparency = transparency
	end))

	self._transparency = link:Get("soundsColor"):GetTransparency()
	self._color = link:Get("soundsColor"):GetColor()
	self._outlineColor = soundsOpts:Get("outlineColor"):GetColor()
	self._outlineTransparency = soundsOpts:Get("outlineColor"):GetTransparency()

	if toggle:Peek() then
		self:Enable()
	end

	return self
end

function SoundESP.Enable(self: SoundESP): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local SoundController = ModuleController.GetModule("SoundController")
	local onStateChanged = rawget(SoundController, "OnStateChanged") :: any

	local playFootstepSound = getupvalue(onStateChanged, 4)

	local oldPlayFootstepSound = nil
	oldPlayFootstepSound = hook.add(playFootstepSound, LPH_NO_VIRTUALIZE(function(hrp, _, ...)
		setthreadidentity(8)
		local clientHrp = peek(clientState.parts).HumanoidRootPart

		if hrp == clientHrp then
			setthreadidentity(2)
			return oldPlayFootstepSound(hrp, _, ...)
		end

		local localTeam = peek(clientState.team)
		local isDm = gamemodeState.isDeathmatch()
		for _, player in next, PlayerController.GetAll() do
			if peek(player.team) == localTeam and not isDm then
				continue
			end
			local parts = peek(player.parts)
			if parts.HumanoidRootPart == hrp then
				self:_renderSound(player, parts)
			end
		end

		setthreadidentity(2)
		return oldPlayFootstepSound(hrp, _, ...)
	end))

	self._janitor:Add(function()
		hook.restore(playFootstepSound)
	end, true)
end

function SoundESP._renderSound(self: SoundESP, player: Player, parts: { [string]: Instance }): ()
	local hrp = parts.HumanoidRootPart :: BasePart
	local foot = parts.LeftFoot :: BasePart or parts.RightFoot :: BasePart

	local position = Vector3.new(hrp.Position.X, foot.Position.Y, hrp.Position.Z)

	local outlineTransparency = self._outlineTransparency
	local transparency = self._transparency

	local ring = instances.newSimple("MeshPart", {
		MeshId = FileController.Get("mesh", "ring"),
		Material = Enum.Material.Glass,
		Reflectance = -99999999999999999,
		Color = self._color,
		Transparency = self._transparency,
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
	self._janitor:Add(function()
		spring:destroy()
		highlight.Enabled = false
		highlight.Adornee = nil
		highlight:Destroy()
		ring:Destroy()
	end, true, ring)

	spring:onComplete(function(): ()
		self._janitor:Remove(ring)
	end)
	spring:setGoal(1)
end

function SoundESP.Disable(self: SoundESP): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self._janitor:Cleanup()
end

function SoundESP.Destroy(self: SoundESP): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type SoundESP =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_color: Color3,
			_transparency: number,
			_outlineColor: Color3,
			_outlineTransparency: number,
		},
		SoundESP
	))
	& BaseFeature.BaseFeature

return SoundESP
