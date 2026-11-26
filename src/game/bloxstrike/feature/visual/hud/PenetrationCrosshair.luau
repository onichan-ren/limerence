local RunService = cloneref(game:GetService("RunService")) :: RunService
local Players = cloneref(game:GetService("Players")) :: Players
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local bulletPenetrationRay = require("@game/bloxstrike/feature/legitbot/bulletPenetrationRay")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local ClientState = require("@game/bloxstrike/client/clientState")
local FileController = require("@src/feature/file/FileController")
local instances = require("@share/instances")
local Janitor = require("@pkg/Janitor")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Charm = require("@pkg/Charm")

local peek = Charm.peek

local LocalPlayer = Players.LocalPlayer
local HIDDEN_UI = cloneref(gethui())

local DEFAULT_CAN_COLOR = Color3.fromRGB(90, 230, 120)
local DEFAULT_CANT_COLOR = Color3.fromRGB(235, 95, 95)

local PenetrationCrosshair = {}
PenetrationCrosshair.__index = PenetrationCrosshair

setmetatable(PenetrationCrosshair, { __index = BaseFeature })

function PenetrationCrosshair.new(link: gameUi.Linker): PenetrationCrosshair
	local self = BaseFeature.new() :: any
	setmetatable(self, PenetrationCrosshair)

	self._enabled = false
	self._janitor = Janitor.new()
	self._size = 10
	self._lastColor = nil :: Color3?

	local toggle = link:Toggle("penetrationCrosshair", "Penetration Dot", false):SetTip({
		title = "Penetration Dot",
		body = "Dot at the center of your screen, green when your shot punches through the surface you are aiming at and red when it stops.",
	})
	link:Extra(toggle, "penetrationCrosshairOptions", "Submenu", "Penetration Dot")
	local optsLink = link:OnKey("penetrationCrosshairOptions")
	optsLink:Colorpicker("canColor", "Can Penetrate", DEFAULT_CAN_COLOR, 0):SetTip({
		title = "Can Penetrate",
		body = "Color when your shot passes through the surface.",
	})
	optsLink:Colorpicker("cantColor", "Cannot Penetrate", DEFAULT_CANT_COLOR, 0):SetTip({
		title = "Cannot Penetrate",
		body = "Color when the surface stops your shot.",
	})
	optsLink:Slider("dotSize", "Size", 10, 4, 32, 1, nil, "px"):SetTip({
		title = "Size",
		body = "Dot size in pixels.",
	})

	self._canEl = optsLink:Get("canColor")
	self._cantEl = optsLink:Get("cantColor")
	self._size = optsLink:Peek("dotSize") or 10

	self:Track(link:Watch("penetrationCrosshairOptions.dotSize", function(value: number): ()
		self._size = value or 10
		local dot = self._dot
		if dot then
			dot.Size = UDim2.fromOffset(self._size, self._size)
		end
	end))

	self:Track(link:Get("penetrationCrosshair"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	return self
end

PenetrationCrosshair._build = LPH_NO_VIRTUALIZE(function(self: PenetrationCrosshair): ()
	local gui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 9,
		Secure = true,
	}, HIDDEN_UI) :: ScreenGui

	local dot = instances.newSimple("ImageLabel", {
		Image = FileController.Get("image", "circle_shadow"),
		ImageColor3 = DEFAULT_CAN_COLOR,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(self._size, self._size),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
	}, gui) :: ImageLabel

	self._gui = gui
	self._dot = dot
	self._lastColor = nil
end)

PenetrationCrosshair._tick = LPH_NO_VIRTUALIZE(function(self: PenetrationCrosshair): ()
	local dot = self._dot
	if not dot then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		if dot.Visible then
			dot.Visible = false
		end
		return
	end

	if not peek(ClientState.alive) then
		if dot.Visible then
			dot.Visible = false
		end
		return
	end

	local weapon = peek(loadoutState.currentEquipped) :: any
	local props = weapon and weapon.Properties
	if not props then
		if dot.Visible then
			dot.Visible = false
		end
		return
	end

	local cf = camera.CFrame
	local origin = cf.Position
	local direction = cf.LookVector

	local ignore = self._ignore
	table.clear(ignore)
	ignore[#ignore + 1] = instances.ignore
	local character = LocalPlayer.Character
	if character then
		ignore[#ignore + 1] = character
	end
	local debris = self._debris
	if not debris or debris.Parent == nil then
		debris = Workspace:FindFirstChild("Debris")
		self._debris = debris
	end
	if debris then
		ignore[#ignore + 1] = debris
	end

	local instance, _, _, canPen =
		bulletPenetrationRay.probeForward(origin, direction, props.Penetration or 0, props.Range or 1200, ignore)

	if not instance then
		if dot.Visible then
			dot.Visible = false
		end
		return
	end

	if not dot.Visible then
		dot.Visible = true
	end

	local color = (canPen and self._canEl or self._cantEl):GetColor()
	if color ~= self._lastColor then
		self._lastColor = color
		dot.ImageColor3 = color
	end
end)

function PenetrationCrosshair.Enable(self: PenetrationCrosshair): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._ignore = { nil :: any }
	self._lastColor = nil
	self:_build()

	self._janitor:Add(
		RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
			self:_tick()
		end)),
		"Disconnect"
	)
	self._janitor:Add(function(): ()
		local gui = self._gui
		if gui then
			gui:Destroy()
		end
	end, true)
end

function PenetrationCrosshair.Disable(self: PenetrationCrosshair): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
	self._gui = nil :: any
	self._dot = nil :: any
end

function PenetrationCrosshair.Destroy(self: PenetrationCrosshair): ()
	BaseFeature.Destroy(self)
	self._janitor:Destroy()
end

export type PenetrationCrosshair =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_size: number,
			_canEl: any,
			_cantEl: any,
			_ignore: { Instance },
			_debris: Instance?,
			_lastColor: Color3?,
			_gui: ScreenGui,
			_dot: ImageLabel,
		},
		PenetrationCrosshair
	))
	& BaseFeature.BaseFeature

return PenetrationCrosshair
