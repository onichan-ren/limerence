local Signal = require("@pkg/Signal")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")

local PITCH_LIMIT = 0.999

export type AntiAimAngles = {
	yaw: number,
	pitch: number,
}

local _yawOverride: number? = nil
local _pitchOverride: number? = nil
local _yawOwner: any = nil
local _pitchOwner: any = nil
local _desiredYaw = 0
local _desiredPitch = 0
local _enabled = false
local _active = false

local signals = {
	onOverrideChanged = Signal.new() :: Signal.Signal<()>,
}

local antiAimApi = {
	signals = signals,
}

function antiAimApi.HasOverride(): boolean
	return _yawOverride ~= nil or _pitchOverride ~= nil
end

function antiAimApi.GetYawOverride(): number?
	return _yawOverride
end

function antiAimApi.GetPitchOverride(): number?
	return _pitchOverride
end

function antiAimApi.SetYawOverride(yaw: number?, owner: any): ()
	local had = antiAimApi.HasOverride()
	_yawOverride = yaw
	if yaw ~= nil then
		_yawOwner = owner
	else
		_yawOwner = nil
	end
	if antiAimApi.HasOverride() ~= had then
		signals.onOverrideChanged:Fire()
	end
end

function antiAimApi.SetPitchOverride(pitch: number?, owner: any): ()
	local had = antiAimApi.HasOverride()
	if pitch ~= nil then
		_pitchOverride = math.clamp(pitch, -PITCH_LIMIT, PITCH_LIMIT)
		_pitchOwner = owner
	else
		_pitchOverride = nil
		_pitchOwner = nil
	end
	if antiAimApi.HasOverride() ~= had then
		signals.onOverrideChanged:Fire()
	end
end

function antiAimApi.ClearOwner(owner: any): ()
	local had = antiAimApi.HasOverride()
	if _yawOwner == owner then
		_yawOverride = nil
		_yawOwner = nil
	end
	if _pitchOwner == owner then
		_pitchOverride = nil
		_pitchOwner = nil
	end
	if antiAimApi.HasOverride() ~= had then
		signals.onOverrideChanged:Fire()
	end
end

function antiAimApi.SetEnabled(value: boolean): ()
	_enabled = value
end

function antiAimApi.IsEnabled(): boolean
	return _enabled
end

function antiAimApi.SetActive(value: boolean): ()
	_active = value
end

function antiAimApi.IsActive(): boolean
	return _active
end

function antiAimApi.NotifyAngles(yaw: number, pitch: number): ()
	_desiredYaw = yaw
	_desiredPitch = pitch
end

function antiAimApi.GetAngles(): AntiAimAngles?
	if not _active then
		return nil
	end
	return { yaw = _desiredYaw, pitch = _desiredPitch }
end

luauApiRegistry.RegisterFeature("antiaim", function(ctx)
	local owner = {}

	ctx.onUnload:Connect(function(): ()
		antiAimApi.ClearOwner(owner)
	end)

	local api = {}

	api.isEnabled = antiAimApi.IsEnabled
	api.isActive = antiAimApi.IsActive
	api.getAngles = antiAimApi.GetAngles

	function api.setYaw(yaw: number?): ()
		if yaw ~= nil and (type(yaw) ~= "number" or yaw ~= yaw or math.abs(yaw) == math.huge) then
			error("api.feature.antiaim.setYaw: yaw must be a finite number or nil", 2)
		end
		antiAimApi.SetYawOverride(yaw, owner)
	end

	function api.setPitch(pitch: number?): ()
		if pitch ~= nil and (type(pitch) ~= "number" or pitch ~= pitch) then
			error("api.feature.antiaim.setPitch: pitch must be a number between -1 and 1 or nil", 2)
		end
		antiAimApi.SetPitchOverride(pitch, owner)
	end

	function api.getYaw(): number?
		return antiAimApi.GetYawOverride()
	end

	function api.getPitch(): number?
		return antiAimApi.GetPitchOverride()
	end

	function api.clear(): ()
		antiAimApi.ClearOwner(owner)
	end

	return api
end)

return antiAimApi
