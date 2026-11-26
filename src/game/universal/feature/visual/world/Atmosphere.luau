local LightingService = cloneref(game:GetService("Lighting")) :: Lighting
local BaseFeature = require("@game/BaseFeature")
local React = require("@pkg/React")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")

local subscribeToBinding = (React :: any).__subscribeToBinding

local BLOCKED_PROPS: { string } = {
	"Density",
	"Offset",
	"Color",
	"Decay",
	"Glare",
	"Haze",
}

local Atmosphere = {}
Atmosphere.__index = Atmosphere

setmetatable(Atmosphere, { __index = BaseFeature })

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

local function createUi(self: Atmosphere, link: gameUi.Linker): ()
	local toggle = link:Toggle("atmosphereEnabled", "Atmosphere", false):SetTip({
		title = "Atmosphere",
		body = "Changes fog, haze, and sky tint for you.",
	})
	link:Extra(toggle, "atmosphereOptions", "Submenu", "Atmosphere Options")
	local optsLink = link:OnKey("atmosphereOptions")

	optsLink:Slider("density", "Density", 0.3, 0, 1, 0.01, nil, nil):SetTip({
		title = "Density",
		body = "Thickness of the atmosphere (0 = clear, 1 = thick).",
	})
	optsLink:Slider("offset", "Offset", 0.25, 0, 1, 0.01, nil, nil):SetTip({
		title = "Offset",
		body = "Shifts the atmosphere's blend point.",
	})
	optsLink:Slider("haze", "Haze", 0, 0, 10, 0.1, nil, nil):SetTip({
		title = "Haze",
		body = "Amount of distance haze added to the scene.",
	})
	optsLink:Slider("glare", "Glare", 0, 0, 12, 0.1, nil, nil):SetTip({
		title = "Glare",
		body = "Intensity of sun glare through the atmosphere.",
	})
	optsLink:Colorpicker("color", "Color", Color3.fromRGB(160, 150, 130), 0):SetTip({
		title = "Color",
		body = "Tint applied to the atmosphere haze.",
	})
	optsLink:Colorpicker("decay", "Decay", Color3.fromRGB(72, 76, 88), 0):SetTip({
		title = "Decay",
		body = "Color the haze decays toward at distance.",
	})

	self:Track(toggle:OnChange(function(value: boolean): ()
		self:_toggle(value)
	end))

	self:Track(optsLink:Get("density"):OnChange(function(value: number): ()
		self._density = value
		self:_apply()
	end))
	self:Track(optsLink:Get("offset"):OnChange(function(value: number): ()
		self._offset = value
		self:_apply()
	end))
	self:Track(optsLink:Get("haze"):OnChange(function(value: number): ()
		self._haze = value
		self:_apply()
	end))
	self:Track(optsLink:Get("glare"):OnChange(function(value: number): ()
		self._glare = value
		self:_apply()
	end))

	self:Track(bindColor(optsLink:Get("color")._currentColor, function(value: Color3): ()
		self._color = value
		self:_apply()
	end))
	self:Track(bindColor(optsLink:Get("decay")._currentColor, function(value: Color3): ()
		self._decay = value
		self:_apply()
	end))
end

function Atmosphere.new(link: gameUi.Linker): Atmosphere
	local self = BaseFeature.new() :: any
	setmetatable(self, Atmosphere)

	self._enabled = false
	self._hookedAtmospheres = {} :: { [Atmosphere]: boolean }
	self._createdAtmosphere = nil :: Atmosphere?
	self._childAddedConn = nil :: RBXScriptConnection?

	self._density = 0.3
	self._offset = 0.25
	self._haze = 0
	self._glare = 0
	self._color = Color3.fromRGB(160, 150, 130)
	self._decay = Color3.fromRGB(72, 76, 88)

	createUi(self, link)

	return self
end

function Atmosphere._hookAtmosphere(self: Atmosphere, atmosphere: Atmosphere): ()
	if self._hookedAtmospheres[atmosphere] then
		return
	end
	hook.addInstance(atmosphere)
	for _, prop in next, BLOCKED_PROPS do
		hook.blockProperty(atmosphere, prop)
	end
	self._hookedAtmospheres[atmosphere] = true
end

function Atmosphere._unhookAtmosphere(self: Atmosphere, atmosphere: Atmosphere): ()
	if not self._hookedAtmospheres[atmosphere] then
		return
	end
	hook.restoreInstance(atmosphere)
	self._hookedAtmospheres[atmosphere] = nil
end

function Atmosphere._writeAtmosphere(self: Atmosphere, atmosphere: Atmosphere): ()
	hook.setProperty(atmosphere, "Density", self._density)
	hook.setProperty(atmosphere, "Offset", self._offset)
	hook.setProperty(atmosphere, "Haze", self._haze)
	hook.setProperty(atmosphere, "Glare", self._glare)
	hook.setProperty(atmosphere, "Color", self._color)
	hook.setProperty(atmosphere, "Decay", self._decay)
end

function Atmosphere._toggle(self: Atmosphere, enabled: boolean): ()
	if enabled == self._enabled then
		return
	end
	self._enabled = enabled

	if enabled then
		self._childAddedConn = LightingService.ChildAdded:Connect(function(child: Instance): ()
			if not self._enabled then
				return
			end
			if child.ClassName ~= "Atmosphere" then
				return
			end
			self:_hookAtmosphere(child :: Atmosphere)
			self:_writeAtmosphere(child :: Atmosphere)
		end)
		self:_apply()
	else
		if self._childAddedConn then
			self._childAddedConn:Disconnect()
			self._childAddedConn = nil
		end
		for atmosphere in next, self._hookedAtmospheres do
			self:_unhookAtmosphere(atmosphere)
		end
		if self._createdAtmosphere then
			(self._createdAtmosphere :: Atmosphere):Destroy()
			self._createdAtmosphere = nil
		end
	end
end

function Atmosphere._apply(self: Atmosphere): ()
	if not self._enabled then
		return
	end

	local had = false
	for _, child in next, LightingService:GetChildren() do
		if child.ClassName == "Atmosphere" then
			had = true
			self:_hookAtmosphere(child :: Atmosphere)
			self:_writeAtmosphere(child :: Atmosphere)
		end
	end

	if not had and not self._createdAtmosphere then
		local atmosphere = Instance.new("Atmosphere")
		self._createdAtmosphere = atmosphere
		atmosphere.Parent = LightingService
	end
end

function Atmosphere.Destroy(self: Atmosphere): ()
	self:_toggle(false)
	BaseFeature.Destroy(self)
end

export type Atmosphere =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_hookedAtmospheres: { [Atmosphere]: boolean },
			_createdAtmosphere: Atmosphere?,
			_childAddedConn: RBXScriptConnection?,
			_density: number,
			_offset: number,
			_haze: number,
			_glare: number,
			_color: Color3,
			_decay: Color3,
		},
		Atmosphere
	))
	& BaseFeature.BaseFeature

return Atmosphere
