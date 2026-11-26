local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local clientState = require("@game/mvsd/client/clientState")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local Camera = Workspace.CurrentCamera

local MAX_DT = 0.05

local peek = Charm.peek

local Speed = {}
Speed.__index = Speed

setmetatable(Speed, { __index = BaseFeature })

local computeWishDir = LPH_NO_VIRTUALIZE(function(): Vector3
	local cf = Camera.CFrame
	local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local flatRight = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)

	if flatLook.Magnitude < 0.001 or flatRight.Magnitude < 0.001 then
		return Vector3.zero
	end

	flatLook = flatLook.Unit
	flatRight = flatRight.Unit

	local wish = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		wish += flatLook
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		wish -= flatLook
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		wish += flatRight
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		wish -= flatRight
	end

	return (wish.Magnitude > 0.001 and wish.Unit or Vector3.zero)
end)

function Speed.new(link: gameUi.Linker): Speed
	local self = BaseFeature.new() :: any
	setmetatable(self, Speed)

	link:Toggle("speed", "Speed", false):SetTip({
		title = "Speed",
		body = "Move faster across the ground.",
	})
	local speedLink = link:OnKey("speed")
	speedLink:Submenu("opts", "Speed")
	local optionsLink = speedLink:OnKey("opts")
	optionsLink:Slider("amount", "Speed", 50, 1, 200, 1, nil, " st/s"):SetTip({
		title = "Speed",
		body = "Extra studs per second added in your movement direction.",
	})

	self._amount = 50
	self._activeJanitor = nil :: Janitor.Janitor?

	self:Track(link:Get("speed"):OnChange(function(value: boolean)
		self:_setEnabled(value)
	end))

	self:Track(link:Watch("speed.opts.amount", function(value: number)
		self._amount = value
	end))

	if link:Peek("speed") then
		self:_setEnabled(true)
	end

	return self
end

function Speed._setEnabled(self: Speed, enabled: boolean): ()
	if enabled then
		if self._activeJanitor then
			return
		end
		local janitor = Janitor.new()
		self._activeJanitor = janitor

		janitor:Add(
			RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
				if not peek(clientState.alive) then
					return
				end

				local hrp = peek(clientState.hrp)
				if not hrp then
					return
				end

				local flatDir = computeWishDir()
				if flatDir.Magnitude < 0.001 then
					return
				end

				local step = self._amount * math.min(dt, MAX_DT)
				hrp.CFrame = hrp.CFrame + flatDir * step
			end)),
			"Disconnect"
		)
	else
		local janitor = self._activeJanitor
		if not janitor then
			return
		end
		self._activeJanitor = nil
		janitor:Destroy()
	end
end

function Speed.Destroy(self: Speed): ()
	self:_setEnabled(false)
	BaseFeature.Destroy(self)
end

export type Speed =
	typeof(setmetatable(
		{} :: {
			_amount: number,
			_activeJanitor: Janitor.Janitor?,
		},
		Speed
	))
	& BaseFeature.BaseFeature

return Speed
