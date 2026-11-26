local RunService = cloneref(game:GetService("RunService")) :: RunService
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local uiState = require("@ui/uiState")

local peek = Charm.peek

local MOUSE_BUTTON_1 = Enum.UserInputType.MouseButton1

local AutoPistols = {}
AutoPistols.__index = AutoPistols

setmetatable(AutoPistols, { __index = BaseFeature })

function AutoPistols.new(link: gameUi.Linker): AutoPistols
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoPistols)

	link:Toggle("autoPistols", "Auto Pistols", false):SetTip({
		title = "Auto Pistols",
		body = "Hold fire to automatically shoot semi-automatic weapons.",
	})

	local masterLink = link:OnKey("autoPistols")
	masterLink:Submenu("opts", "Auto Pistols")
	local optsLink = masterLink:OnKey("opts")
	optsLink:Slider("delay", "Shot Delay", 50, 0, 500, 5, nil, "ms"):SetTip({
		title = "Shot Delay",
		body = "Minimum delay between shots. The weapon's own fire rate still applies.",
	})

	self._janitor = Janitor.new()
	self._enabled = false
	self._delay = 0.05
	self._lastShot = 0
	self._enabledLink = link:Get("autoPistols")

	self:Track(link:Watch("autoPistols.opts.delay", function(value: any): ()
		self._delay = (tonumber(value) or 50) / 1000
	end))

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	return self
end

function AutoPistols.Enable(self: AutoPistols): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._janitor:Add(
		RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
			if peek(uiState.isOpen) then
				return
			end
			if not UserInputService:IsMouseButtonPressed(MOUSE_BUTTON_1) then
				return
			end
			if os.clock() - self._lastShot < self._delay then
				return
			end
			if not WeaponController.IsGun() then
				return
			end
			if not WeaponController.CanFire() then
				return
			end
			if WeaponController.FireInput() then
				self._lastShot = os.clock()
			end
		end)),
		"Disconnect"
	)
end

function AutoPistols.Disable(self: AutoPistols): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function AutoPistols.Destroy(self: AutoPistols): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoPistols =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_enabledLink: any,
			_delay: number,
			_lastShot: number,
			_janitor: Janitor.Janitor,
		},
		AutoPistols
	))
	& BaseFeature.BaseFeature

return AutoPistols
