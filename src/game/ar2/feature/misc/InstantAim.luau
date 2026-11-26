local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")

local RunService = cloneref(game:GetService("RunService")) :: RunService

local InstantAim = {}
InstantAim.__index = InstantAim

setmetatable(InstantAim, { __index = BaseFeature })

local AIM_SPRINGS = {
	"AimOffset",
	"AimAngles",
	"AimRightHand",
	"AimLeftHand",
	"AimRightHandRoll",
	"AimLeftHandRoll",
	"ToolOffset",
	"ToolAngles",
	"RightHand",
	"LeftHand",
	"RightHandRoll",
	"LeftHandRoll",
}

local pinned = setmetatable({}, { __mode = "k" })

local function pin(spring: any): ()
	if type(spring) ~= "table" or pinned[spring] then
		return
	end
	local original = spring.GetPosition
	if type(original) ~= "function" or type(spring.GetGoal) ~= "function" then
		return
	end
	pinned[spring] = original
	spring.GetPosition = function(_): any
		return spring:GetGoal()
	end
end

local function restoreAll(): ()
	for spring, original in next, pinned do
		spring.GetPosition = original
	end
	table.clear(pinned)
end

local apply = LPH_NO_VIRTUALIZE(function(self: InstantAim): ()
	local arLocalPlayer = self._localPlayer
	local character = arLocalPlayer and arLocalPlayer.Character
	if character then
		local animator = character.Animator
		local springs = animator and animator.Springs
		if springs then
			for _, name in next, AIM_SPRINGS do
				pin(springs[name])
			end
		end
	end

	local camera = self._camera
	if camera then
		pin(rawget(camera, "FovSpring"))
	end
end)

function InstantAim.new(link: gameUi.Linker): InstantAim
	local self = BaseFeature.new() :: any
	setmetatable(self, InstantAim)

	self._enabled = false
	self._conn = nil :: RBXScriptConnection?
	self._localPlayer = nil :: any
	self._camera = nil :: any

	link:Toggle("instantAim", "Instant Aim", false):SetTip({
		title = "Instant Aim",
		body = "Aim down sights with no delay.",
	})

	self:Track(link:Get("instantAim"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("instantAim") then
		self:Enable()
	end

	return self
end

function InstantAim.Enable(self: InstantAim): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local playersModule = ModuleController.GetModule("LocalPlayer")
	if not playersModule then
		return
	end

	local camerasModule = ModuleController.GetModule("Cameras")

	self._localPlayer = playersModule.module.get()
	self._camera = camerasModule and camerasModule.module:GetCamera("Character")

	self._conn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
		apply(self)
	end))
end

function InstantAim.Disable(self: InstantAim): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end

	restoreAll()

	self._localPlayer = nil
	self._camera = nil
end

function InstantAim.Destroy(self: InstantAim): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type InstantAim =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_conn: RBXScriptConnection?,
			_localPlayer: any,
			_camera: any,
		},
		InstantAim
	))
	& BaseFeature.BaseFeature

return InstantAim
