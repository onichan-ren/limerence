local LightingService = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local currentCamera = Workspace.CurrentCamera

local FileController = require("@feature/file/FileController")
local BaseFeature = require("@game/BaseFeature")
local Janitor = require("@pkg/Janitor")
local React = require("@pkg/React")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local instances = require("@share/instances")

local subscribeToBinding = (React :: any).__subscribeToBinding

local FLASH_NAMES: { [string]: boolean } = {
	FlashbangColorCorrection = true,
	WarmupColorCorrection = true,
}

local CC_PROPS: { string } = { "Brightness", "Saturation", "Contrast", "TintColor" }

local WEATHER_PROPERTIES = {
	Fireflies = {
		Rotation = NumberRange.new(-100, 100),
		Rate = 40,
		Lifetime = NumberRange.new(5, 10),
		Speed = NumberRange.new(0.2, 0.2),
		SpreadAngle = Vector2.new(100, 100),
		RotSpeed = NumberRange.new(0, 0),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NumberSequence.new(0.2),
		Brightness = 1,
		LightEmission = 1,
		LightInfluence = 0,
		Texture = "rbxassetid://75202463",
	},
	Stars = {
		Rotation = NumberRange.new(105, 105),
		Rate = 100,
		Lifetime = NumberRange.new(5, 5),
		Speed = NumberRange.new(1, 1.8),
		SpreadAngle = Vector2.new(0, 0),
		RotSpeed = NumberRange.new(-45, -45),
		EmissionDirection = Enum.NormalId.Bottom,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 0.3),
		}),
		Squash = NumberSequence.new(0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.1, 0.2),
			NumberSequenceKeypoint.new(0.928, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Drag = 0,
		Brightness = 1.925,
		LightEmission = 0.7,
		LightInfluence = 0.8,
		ZOffset = 4,
		Texture = "rbxassetid://83028699704702",
	},
	Rain = {
		Rotation = NumberRange.new(1, 1),
		Rate = 1000,
		Speed = NumberRange.new(110, 110),
		Lifetime = NumberRange.new(1.1, 1.1),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(),
		Size = NumberSequence.new(3),
		Texture = "rain",
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0.56),
		}),
		LightEmission = 1,
		LightInfluence = 0.5,
		RotSpeed = NumberRange.new(0, 0),
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		VelocityInheritance = 0,
	},
	Snow = {
		Rotation = NumberRange.new(0, 0),
		Rate = 1000,
		Lifetime = NumberRange.new(1, 1),
		Speed = NumberRange.new(100, 100),
		SpreadAngle = Vector2.new(9999, 9999),
		RotSpeed = NumberRange.new(-990, 990),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NumberSequence.new(1),
		LightEmission = 1,
		LightInfluence = 0.5,
		Texture = "snow",
	},
}
local WEATHER_CAMERA_POSITION_OFFSET = Vector3.new(0, 22, 0)

local Lighting = {}
Lighting.__index = Lighting

setmetatable(Lighting, { __index = BaseFeature })

local function blockProps(names: { string }, block: boolean): ()
	for _, name in next, names do
		if block then
			hook.blockProperty(LightingService, name)
		else
			hook.unblockProperty(LightingService, name)
		end
	end
end

local function bindColor(binding: any, setter: (Color3) -> ()): () -> ()
	local initial = (binding :: any):getValue()
	if initial ~= nil then
		setter(initial)
	end
	return subscribeToBinding(binding, function(value: Color3): ()
		if value ~= nil then
			setter(value)
		end
	end)
end

local function createUi(self: Lighting, link: gameUi.Linker): ()
	local colorCorrectionToggle = link:Toggle("colorCorrectionEnabled", "Color Correction", false):SetTip({
		title = "Color Correction",
		body = "Changes post-processing color, brightness, and contrast for you.",
	})
	link:Extra(colorCorrectionToggle, "colorCorrectionOptions", "Submenu", "Color Correction Options")
	local colorCorrectionOptsLink = link:OnKey("colorCorrectionOptions")
	colorCorrectionOptsLink:Slider("brightness", "Brightness", 0, -1, 1, 0.05, nil, nil):SetTip({
		title = "Brightness",
		body = "Color correction brightness (-1 to 1).",
	})
	colorCorrectionOptsLink:Slider("saturation", "Saturation", 0, -1, 1, 0.05, nil, nil):SetTip({
		title = "Saturation",
		body = "Color saturation (-1 = grayscale, 1 = vivid).",
	})
	colorCorrectionOptsLink:Slider("contrast", "Contrast", 0, -1, 1, 0.05, nil, nil):SetTip({
		title = "Contrast",
		body = "Image contrast adjustment.",
	})
	colorCorrectionOptsLink:Colorpicker("tint", "Tint", Color3.fromRGB(72, 70, 88), 0):SetTip({
		title = "Tint",
		body = "Color tint applied over the scene.",
	})

	local worldColorToggle = link:Toggle("worldColorEnabled", "World Color", false):SetTip({
		title = "World Color",
		body = "Changes ambient and outdoor light colors for you.",
	})
	link:Extra(worldColorToggle, "ambientColor", "Colorpicker", "Ambient Color", Color3.fromRGB(100, 98, 118))
	link:Extra(worldColorToggle, "outsideColor", "Colorpicker", "Outside Color", Color3.fromRGB(88, 86, 105))

	local brightnessToggle = link:Toggle("brightnessEnabled", "Brightness", false):SetTip({
		title = "Brightness",
		body = "Changes how bright the world looks for you.",
	})
	link:Extra(brightnessToggle, "brightnessOptions", "Submenu", "Brightness Options")
	local brightnessOptsLink = link:OnKey("brightnessOptions")
	brightnessOptsLink:Slider("brightness", "Brightness", 1, 0, 10, 0.1, nil, nil):SetTip({
		title = "Brightness",
		body = "Lighting brightness multiplier.",
	})

	local timeToggle = link:Toggle("timeEnabled", "Time", false):SetTip({
		title = "Time",
		body = "Keeps the sun at a fixed time of day for you (hours 0–24).",
	})
	link:Extra(timeToggle, "timeOptions", "Submenu", "Time Options")
	local timeOptsLink = link:OnKey("timeOptions")
	timeOptsLink:Slider("time", "Time", 4, 0, 24, 0.1, nil, "h"):SetTip({
		title = "Time",
		body = "Time of day in hours when time lock is enabled.",
	})

	local weatherToggle = link:Toggle("weatherEnabled", "Weather", false):SetTip({
		title = "Weather Color",
		body = "Adds weather to the world.",
	})
	link:Extra(weatherToggle, "weatherOptions", "Submenu", "Weather Options")
	local weatherOptsLink = link:OnKey("weatherOptions")
	weatherOptsLink:Dropdown("type", "Type", { "Fireflies", "Stars", "Rain", "Snow" }, "Rain"):SetTip({
		title = "Type",
		body = "Type of weather to add to the world.",
	})
	link:Extra(
		weatherToggle,
		"weatherColor",
		"Colorpicker",
		"Weather Color",
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(91, 104, 124)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(121, 141, 177)),
		})
	)

	self:Track(weatherToggle:OnChange(function(value: boolean): ()
		self:toggleWeather(value)
	end))

	self:Track(link:Get("weatherColor"):OnUpdate(function(value): ()
		self._weatherColor = value.gradient
		self:_updateWeatherColor()
	end))

	self:Track(weatherOptsLink:Get("type"):OnChange(function(value: string): ()
		self._weatherType = value
		if self._weatherEnabled then
			self:toggleWeather(false)
			self:toggleWeather(true)
		end
	end))

	self:Track(worldColorToggle:OnChange(function(value: boolean): ()
		self:toggleWorldColor(value)
	end))

	self:Track(bindColor(link:Get("ambientColor")._currentColor, function(value: Color3): ()
		self._ambientColor = value
		self:applyWorldColors()
	end))

	self:Track(bindColor(link:Get("outsideColor")._currentColor, function(value: Color3): ()
		self._outsideColor = value
		self:applyWorldColors()
	end))

	self:Track(brightnessToggle:OnChange(function(value: boolean): ()
		self:toggleBrightness(value)
	end))

	self:Track(brightnessOptsLink:Get("brightness"):OnChange(function(value: number): ()
		self._brightness = value
		self:applyBrightness()
	end))

	self:Track(timeToggle:OnChange(function(value: boolean): ()
		self:toggleTime(value)
	end))

	self:Track(timeOptsLink:Get("time"):OnChange(function(value: number): ()
		self._time = value
		self:applyTime()
	end))

	self:Track(colorCorrectionToggle:OnChange(function(value: boolean): ()
		self:toggleColorCorrection(value)
	end))

	self:Track(colorCorrectionOptsLink:Get("brightness"):OnChange(function(value: number): ()
		self._colorBrightness = value
		self:applyColorCorrection()
	end))

	self:Track(colorCorrectionOptsLink:Get("saturation"):OnChange(function(value: number): ()
		self._saturation = value
		self:applyColorCorrection()
	end))

	self:Track(colorCorrectionOptsLink:Get("contrast"):OnChange(function(value: number): ()
		self._contrast = value
		self:applyColorCorrection()
	end))

	self:Track(bindColor(colorCorrectionOptsLink:Get("tint")._currentColor, function(value: Color3): ()
		self._tint = value
		self:applyColorCorrection()
	end))
end

function Lighting.new(link: gameUi.Linker): Lighting
	local self = BaseFeature.new() :: any
	setmetatable(self, Lighting)

	self._janitor = Janitor.new()
	self._link = link
	self._hookedCCs = {} :: { [ColorCorrectionEffect]: string }
	self._ccJanitors = {} :: { [ColorCorrectionEffect]: Janitor.Janitor }
	self._ambientColor = Color3.fromRGB(100, 98, 118)
	self._outsideColor = Color3.fromRGB(88, 86, 105)
	self._weatherColor = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(91, 104, 124)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(121, 141, 177)),
	})
	self._brightness = 1
	self._time = 4
	self._weatherType = "Rain"

	self._worldColorEnabled = false
	self._brightnessEnabled = false
	self._timeEnabled = false
	self._weatherEnabled = false
	self._colorCorrectionEnabled = false
	self._saturation = 0
	self._contrast = 0
	self._tint = Color3.fromRGB(72, 70, 88)
	self._colorBrightness = 0

	createUi(self, link)
	hook.addInstance(LightingService)

	self:_enforce("Ambient", function(): any
		return self._worldColorEnabled and self._ambientColor or nil
	end)
	self:_enforce("OutdoorAmbient", function(): any
		return self._worldColorEnabled and self._outsideColor or nil
	end)
	self:_enforce("Brightness", function(): any
		return self._brightnessEnabled and self._brightness or nil
	end)
	self:_enforce("ClockTime", function(): any
		return self._timeEnabled and self._time or nil
	end)

	return self
end

function Lighting._enforce(self: Lighting, prop: string, get: () -> any): ()
	self._janitor:Add(
		LightingService:GetPropertyChangedSignal(prop):Connect(LPH_NO_VIRTUALIZE(function(): ()
			local target = get()
			if target ~= nil and hook.getProperty(LightingService, prop) ~= target then
				hook.setProperty(LightingService, prop, target)
			end
		end)),
		"Disconnect"
	)
end

function Lighting._anyVisualOverride(self: Lighting): boolean
	return self._worldColorEnabled or self._colorCorrectionEnabled or self._brightnessEnabled or self._timeEnabled
end

local WEATHER_PART_SIZES: { Vector3 } = {
	Vector3.new(90, 1, 90),
	Vector3.new(250, 1, 250),
}

local WEATHER_LAYOUT: { [string]: { sizes: { Vector3 }, offset: Vector3 } } = {
	Rain = { sizes = WEATHER_PART_SIZES, offset = WEATHER_CAMERA_POSITION_OFFSET },
	Snow = { sizes = WEATHER_PART_SIZES, offset = WEATHER_CAMERA_POSITION_OFFSET },
	Stars = { sizes = { Vector3.new(140, 30, 140) }, offset = Vector3.new(0, 0, 0) },
	Fireflies = { sizes = { Vector3.new(140, 30, 140) }, offset = Vector3.new(0, 0, 0) },
}

local function resolveTexture(value: string): string
	if string.find(value, "^rbxasset") or string.find(value, "^http") then
		return value
	end
	return FileController.Get("image", value) :: string
end

local function makeWeatherPart(size: Vector3, props: { [string]: any }): (Part, ParticleEmitter)
	local part = instances.new("Part", {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Anchored = true,
		Size = size,
	}, Workspace) :: Part
	local emitter = instances.new("ParticleEmitter", props, part) :: ParticleEmitter
	emitter.Texture = resolveTexture(props.Texture)
	return part, emitter
end

function Lighting.toggleWeather(self: Lighting, state: boolean)
	self._weatherEnabled = state

	local parts = self._weatherParts

	if not state and parts then
		self._weatherConnection:Disconnect()
		for _, part in next, parts do
			part:Destroy()
		end
		self._weatherParts = nil
		self._weatherEmitters = nil
		self._weatherConnection = nil
	end

	if state and not parts then
		local props = WEATHER_PROPERTIES[self._weatherType]
		local layout = WEATHER_LAYOUT[self._weatherType] or WEATHER_LAYOUT.Rain
		self._weatherOffset = layout.offset
		local newParts: { Part } = {}
		local newEmitters: { ParticleEmitter } = {}
		for i, size in next, layout.sizes do
			local part, emitter = makeWeatherPart(size, props)
			newParts[i] = part
			newEmitters[i] = emitter
		end

		self._weatherParts = newParts
		self._weatherEmitters = newEmitters

		self._weatherConnection = currentCamera:GetPropertyChangedSignal("CFrame"):Connect(LPH_NO_VIRTUALIZE(function()
			self:_updateWeather()
		end))

		self:_updateWeather()
		self:_updateWeatherColor()
	end
end

function Lighting._updateWeather(self: Lighting)
	local offset = self._weatherOffset or WEATHER_CAMERA_POSITION_OFFSET
	local cf = CFrame.new(currentCamera.CFrame.Position + offset)
	for _, part in next, self._weatherParts do
		part.CFrame = cf
	end
end

function Lighting._updateWeatherColor(self: Lighting)
	local emitters = self._weatherEmitters
	if emitters then
		for _, emitter in next, emitters do
			emitter.Color = self._weatherColor
		end
	end
end

function Lighting._targetFor(self: Lighting, prop: string): any
	if prop == "Brightness" then
		return self._colorBrightness
	elseif prop == "Saturation" then
		return self._saturation
	elseif prop == "Contrast" then
		return self._contrast
	elseif prop == "TintColor" then
		return self._tint
	end
	return nil
end

function Lighting._hookMapCC(self: Lighting, cc: ColorCorrectionEffect): ()
	if self._hookedCCs[cc] then
		return
	end
	hook.addInstance(cc)
	for _, p in next, CC_PROPS do
		hook.blockProperty(cc, p)
	end
	self._hookedCCs[cc] = "map"

	local janitor = Janitor.new()
	self._ccJanitors[cc] = janitor
	for _, p in next, CC_PROPS do
		local prop = p
		janitor:Add(
			cc:GetPropertyChangedSignal(prop):Connect(LPH_NO_VIRTUALIZE(function(): ()
				if not self._colorCorrectionEnabled then
					return
				end
				local target = self:_targetFor(prop)
				if (cc :: any)[prop] ~= target then
					hook.setProperty(cc, prop, target)
				end
			end)),
			"Disconnect"
		)
	end
end

function Lighting._hookFlashCC(self: Lighting, cc: ColorCorrectionEffect): ()
	if self._hookedCCs[cc] then
		return
	end
	hook.addInstance(cc)
	for _, p in next, CC_PROPS do
		hook.blockProperty(cc, p)
	end
	hook.blockProperty(cc, "Enabled")
	hook.setProperty(cc, "Brightness", 0)
	hook.setProperty(cc, "Saturation", 0)
	hook.setProperty(cc, "Contrast", 0)
	hook.setProperty(cc, "TintColor", Color3.new(1, 1, 1))
	hook.setProperty(cc, "Enabled", false)
	self._hookedCCs[cc] = "flash"
end

function Lighting._unhookCC(self: Lighting, cc: ColorCorrectionEffect): ()
	if not self._hookedCCs[cc] then
		return
	end
	local janitor = self._ccJanitors[cc]
	if janitor then
		janitor:Destroy()
		self._ccJanitors[cc] = nil
	end
	hook.restoreInstance(cc)
	self._hookedCCs[cc] = nil
end

function Lighting._reconcile(self: Lighting): ()
	local needFlashBlock = self:_anyVisualOverride()
	local needMapHook = self._colorCorrectionEnabled

	for _, child in next, LightingService:GetChildren() do
		if child.ClassName ~= "ColorCorrectionEffect" then
			continue
		end
		local cc = child :: ColorCorrectionEffect
		local current = self._hookedCCs[cc]
		local isFlash = FLASH_NAMES[cc.Name] == true

		if isFlash then
			if needFlashBlock then
				if current ~= "flash" then
					if current then
						self:_unhookCC(cc)
					end
					self:_hookFlashCC(cc)
				end
			elseif current then
				self:_unhookCC(cc)
			end
		else
			if needMapHook then
				if current ~= "map" then
					if current then
						self:_unhookCC(cc)
					end
					self:_hookMapCC(cc)
				end
			elseif current then
				self:_unhookCC(cc)
			end
		end
	end

	if needFlashBlock or needMapHook then
		if not self._childAddedConn then
			self._childAddedConn = LightingService.ChildAdded:Connect(function(child: Instance): ()
				if child.ClassName == "ColorCorrectionEffect" then
					self:_handleNewCC(child :: ColorCorrectionEffect)
				end
			end)
		end
	elseif self._childAddedConn then
		self._childAddedConn:Disconnect()
		self._childAddedConn = nil
	end

	self:applyColorCorrection()
end

function Lighting._handleNewCC(self: Lighting, cc: ColorCorrectionEffect): ()
	local isFlash = FLASH_NAMES[cc.Name] == true
	if isFlash then
		if self:_anyVisualOverride() then
			self:_hookFlashCC(cc)
		end
	else
		if self._colorCorrectionEnabled then
			self:_hookMapCC(cc)
			self:applyColorCorrection()
		end
	end
end

function Lighting.toggleWorldColor(self: Lighting, enabled: boolean): ()
	self._worldColorEnabled = enabled
	blockProps({ "Ambient", "OutdoorAmbient" }, enabled)
	if enabled then
		self:applyWorldColors()
	end
	self:_reconcile()
end

function Lighting.applyWorldColors(self: Lighting): ()
	if not self._worldColorEnabled then
		return
	end
	hook.setProperty(LightingService, "Ambient", self._ambientColor)
	hook.setProperty(LightingService, "OutdoorAmbient", self._outsideColor)
end

function Lighting.toggleBrightness(self: Lighting, enabled: boolean): ()
	self._brightnessEnabled = enabled
	blockProps({ "Brightness" }, enabled)
	if enabled then
		self:applyBrightness()
	end
	self:_reconcile()
end

function Lighting.applyBrightness(self: Lighting): ()
	if self._brightnessEnabled then
		hook.setProperty(LightingService, "Brightness", self._brightness)
	end
end

function Lighting.toggleTime(self: Lighting, enabled: boolean): ()
	self._timeEnabled = enabled
	blockProps({ "ClockTime" }, enabled)
	if enabled then
		hook.overrideMethod(LightingService, "SetMinutesAfterMidnight", function(): number
			return self._time * 60
		end)
		self:applyTime()
	else
		hook.restoreMethod(LightingService, "SetMinutesAfterMidnight")
	end
	self:_reconcile()
end

function Lighting.applyTime(self: Lighting): ()
	if self._timeEnabled then
		hook.setProperty(LightingService, "ClockTime", self._time)
	end
end

function Lighting.toggleColorCorrection(self: Lighting, enabled: boolean): ()
	self._colorCorrectionEnabled = enabled
	self:_reconcile()
end

function Lighting.applyColorCorrection(self: Lighting): ()
	if not self._colorCorrectionEnabled then
		return
	end
	for cc, kind in next, self._hookedCCs do
		if kind == "map" then
			hook.setProperty(cc, "Brightness", self._colorBrightness)
			hook.setProperty(cc, "Saturation", self._saturation)
			hook.setProperty(cc, "Contrast", self._contrast)
			hook.setProperty(cc, "TintColor", self._tint)
		end
	end
end

function Lighting.Destroy(self: Lighting): ()
	self._janitor:Destroy()

	if self._childAddedConn then
		self._childAddedConn:Disconnect()
		self._childAddedConn = nil
	end

	local hooked: { ColorCorrectionEffect } = {}
	for cc in next, self._hookedCCs do
		hooked[#hooked + 1] = cc
	end
	for _, cc in next, hooked do
		self:_unhookCC(cc)
	end
	if self._weatherConnection then
		self._weatherConnection:Disconnect()
		self._weatherConnection = nil
	end
	if self._weatherParts then
		for _, part in next, self._weatherParts do
			part:Destroy()
		end
		self._weatherParts = nil
		self._weatherEmitters = nil
	end

	hook.restoreInstance(LightingService)
	BaseFeature.Destroy(self)
end

export type Lighting =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_hookedCCs: { [ColorCorrectionEffect]: string },
			_ccJanitors: { [ColorCorrectionEffect]: Janitor.Janitor },
			_childAddedConn: RBXScriptConnection?,
			_ambientColor: Color3,
			_outsideColor: Color3,
			_brightness: number,
			_brightnessEnabled: boolean,
			_worldColorEnabled: boolean,
			_time: number,
			_timeEnabled: boolean,
			_colorCorrectionEnabled: boolean,
			_weatherEnabled: boolean,
			_weatherColor: ColorSequence,
			_saturation: number,
			_contrast: number,
			_tint: Color3,
			_colorBrightness: number,
			_janitor: Janitor.Janitor,
			_enforce: (Lighting, string, () -> any) -> (),
			_weatherParts: { Part }?,
			_weatherEmitters: { ParticleEmitter }?,
			_weatherType: string,
			_weatherOffset: Vector3?,
			_weatherConnection: RBXScriptConnection?,
		},
		Lighting
	))
	& BaseFeature.BaseFeature

return Lighting
