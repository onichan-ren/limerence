local NetworkController = require("@game/rivals/network/NetworkController")
local ModuleController = require("@game/rivals/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

local DeviceSpoofer = {}
DeviceSpoofer.__index = DeviceSpoofer

setmetatable(DeviceSpoofer, { __index = BaseFeature })

function DeviceSpoofer.new(link: gameUi.Linker): DeviceSpoofer
	local self = BaseFeature.new() :: any
	setmetatable(self, DeviceSpoofer)

	link:Toggle("deviceSpoofer", "Device Spoofer", false):SetTip({
		title = "Device Spoofer",
		body = "Spoofs the device other players see you on to the selected device.",
	})
	local deviceSpooferLink = link:OnKey("deviceSpoofer")
	deviceSpooferLink:Submenu("opts", "Device Spoofer")
	local optionsLink = deviceSpooferLink:OnKey("opts")
	optionsLink:Dropdown("device", "Device", { "Console", "Mobile", "PC", "VR" }, "PC"):SetMin(1):SetTip({
		title = "Device",
		body = "Device to show other players.",
	})

	self._device = "MouseKeyboard"
	self._janitor = Janitor.new()

	self:Track(link:Get("deviceSpoofer"):OnChange(function(value: boolean)
		local ControlsController = ModuleController.GetModule("ControlsController")
		if not ControlsController then
			return
		end
		self._originalDevice = rawget(ControlsController, "CurrentControls")
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(link:Watch("deviceSpoofer.opts.device", function(value: string)
		local newDevice = value == "Console" and "Gamepad"
			or value == "Mobile" and "Touch"
			or value == "VR" and "VR"
			or "MouseKeyboard"
		self._device = newDevice
		if self._enabled then
			NetworkController.SendRemote("Replication.Fighter.SetControls", self._device)
		end
	end))

	return self
end

function DeviceSpoofer.Enable(self: DeviceSpoofer): ()
	if self._enabled then
		return
	end
	self._enabled = true

	NetworkController.HookRemote("Replication.Fighter.SetControls", function(controls: string): boolean
		return false, self._device
	end)

	NetworkController.SendRemote("Replication.Fighter.SetControls", self._device)

	self._janitor:Add(function(): ()
		NetworkController.UnhookRemote("Replication.Fighter.SetControls")
		NetworkController.SendRemote("Replication.Fighter.SetControls", self._originalDevice)
	end, true)
end

function DeviceSpoofer.Disable(self: DeviceSpoofer): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function DeviceSpoofer.Destroy(self: DeviceSpoofer): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type DeviceSpoofer =
	typeof(setmetatable(
		{} :: {
			_device: string,
			_janitor: Janitor.Janitor,
			_enabled: boolean,
		},
		DeviceSpoofer
	))
	& BaseFeature.BaseFeature

return DeviceSpoofer
