local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local StateReport = require("@game/ar2/network/stateReport")
local ModuleController = require("@game/ar2/module/ModuleController")

local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local RunService = cloneref(game:GetService("RunService")) :: RunService

local LOOK_RENDER_NAME = "Character Look Solve"
local LOOK_RENDER_PRIORITY = 21
local TAU = math.pi * 2
local PITCH_LIMIT = 0.999

local isBlocked = LPH_NO_VIRTUALIZE(function(character: any): boolean
	return character.Sitting or character.Vaulting or character.Climbing or character.Mounting or character.Dismounting
end)

local resolveYaw = LPH_NO_VIRTUALIZE(function(mode: string, cameraYaw: number): number
	if mode == "Back" then
		return cameraYaw + math.pi
	elseif mode == "Left" then
		return cameraYaw + math.pi / 2
	elseif mode == "Right" then
		return cameraYaw - math.pi / 2
	elseif mode == "Random" then
		return cameraYaw + (math.random() - 0.5) * TAU
	end
	return cameraYaw
end)

local resolvePitch = LPH_NO_VIRTUALIZE(function(mode: string, cameraPitch: number): number
	if mode == "Up" then
		return PITCH_LIMIT
	elseif mode == "Down" then
		return -PITCH_LIMIT
	elseif mode == "Random" then
		return (math.random() * 2 - 1) * PITCH_LIMIT
	end
	return cameraPitch
end)

local AntiAim = {}
AntiAim.__index = AntiAim

setmetatable(AntiAim, { __index = BaseFeature })

function AntiAim.new(link: gameUi.Linker): AntiAim
	local self = BaseFeature.new() :: any
	setmetatable(self, AntiAim)

	self._enabled = false
	self._registered = false
	self._renderBound = false
	self._charModule = nil :: any
	self._spoofer = function(overrides: { [number]: any }): ()
		overrides[StateReport.Field.LookDirection] = self:_lookDirection()
	end

	link:Toggle("antiAim", "Anti Aim", false):SetTip({
		title = "Anti Aim",
		body = "Makes your character face a different direction than you are actually looking.",
	})
	local antiAimLink = link:OnKey("antiAim")
	antiAimLink:Submenu("opts", "Anti Aim")
	local optsLink = antiAimLink:OnKey("opts")
	optsLink:Dropdown("yaw", "Yaw", { "View", "Back", "Left", "Right", "Random" }, "Back"):SetTip({
		title = "Yaw",
		body = "Left/right direction other players see, relative to where you look.",
	})
	optsLink:Dropdown("pitch", "Pitch", { "Up", "Down", "View", "Random" }, "Down"):SetTip({
		title = "Pitch",
		body = "Up/down direction other players see you looking.",
	})

	self._yaw = optsLink:Get("yaw"):Peek()
	self._pitch = optsLink:Get("pitch"):Peek()

	self:Track(link:Get("antiAim"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))
	self:Track(optsLink:Get("yaw"):OnChange(function(value: string): ()
		self._yaw = value
	end))
	self:Track(optsLink:Get("pitch"):OnChange(function(value: string): ()
		self._pitch = value
	end))

	if link:Peek("antiAim") then
		self:Enable()
	end

	return self
end

function AntiAim._localCharacter(self: AntiAim): any
	if not self._charModule then
		local m = ModuleController.GetModule("LocalPlayer")
		self._charModule = m and m.module
	end
	local module = self._charModule
	local arLocal = module and module.get()
	return arLocal and arLocal.Character
end

function AntiAim._lookDirection(self: AntiAim): Vector3
	local camera = Workspace.CurrentCamera
	local look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
	local cameraYaw = math.atan2(-look.X, -look.Z)

	local yaw = resolveYaw(self._yaw, cameraYaw)
	local pitch = math.clamp(resolvePitch(self._pitch, look.Y), -PITCH_LIMIT, PITCH_LIMIT)
	local horizontal = math.sqrt(math.max(0, 1 - pitch * pitch))

	return Vector3.new(-math.sin(yaw) * horizontal, pitch, -math.cos(yaw) * horizontal)
end

function AntiAim.Enable(self: AntiAim): ()
	if self._enabled then
		return
	end
	self._enabled = true

	if not self._registered then
		StateReport.register(self._spoofer)
		self._registered = true
	end

	if not self._renderBound then
		RunService:BindToRenderStep(
			LOOK_RENDER_NAME,
			LOOK_RENDER_PRIORITY,
			LPH_NO_VIRTUALIZE(function(): ()
				local character = self:_localCharacter()
				if not character then
					return
				end

				local look = self:_lookDirection()

				local spring = character.LookDirectionSpring
				if spring then
					spring:SetGoal(look)
				end

				if isBlocked(character) then
					return
				end

				local horizontal = Vector3.new(look.X, 0, look.Z)
				if horizontal.Magnitude < 1e-4 then
					return
				end
				horizontal = horizontal.Unit

				local rootSpring = character.RootTurnSpring
				if rootSpring then
					rootSpring:SnapTo(horizontal)
				end

				local rootPart = character.RootPart
				if rootPart and rootPart.Parent then
					local pos = rootPart.Position
					local cf = CFrame.new(pos, pos + horizontal)
					rootPart.CFrame = cf
					character.RenderCFrame = cf
				end
			end)
		)
		self._renderBound = true
	end
end

function AntiAim.Disable(self: AntiAim): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._registered then
		StateReport.unregister(self._spoofer)
		self._registered = false
	end

	if self._renderBound then
		RunService:UnbindFromRenderStep(LOOK_RENDER_NAME)
		self._renderBound = false
	end
end

function AntiAim.Destroy(self: AntiAim): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AntiAim =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_registered: boolean,
			_renderBound: boolean,
			_charModule: any,
			_spoofer: (overrides: { [number]: any }) -> (),
			_yaw: string,
			_pitch: string,
			_localCharacter: (AntiAim) -> any,
			_lookDirection: (AntiAim) -> Vector3,
		},
		AntiAim
	))
	& BaseFeature.BaseFeature

return AntiAim
