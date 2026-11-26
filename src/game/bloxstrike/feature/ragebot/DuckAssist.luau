local RunService = cloneref(game:GetService("RunService")) :: RunService
local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local hook = require("@share/hook")
local ClientController = require("@game/bloxstrike/client/ClientController")
local ClientState = require("@game/bloxstrike/client/clientState")
local localLookController = require("@game/bloxstrike/client/localLookController")
local LoadoutState = require("@game/bloxstrike/loadout/loadoutState")
local WeaponController = require("@game/bloxstrike/weapon/WeaponController")
local ragebotApi = require("@game/bloxstrike/feature/ragebot/ragebotApi")
local Ragebot = require("@game/bloxstrike/feature/ragebot/Ragebot")

local peek = Charm.peek

local LocalPlayer = Players.LocalPlayer

local RENDER_NAME = "DuckAssistRender"
local KEEPVIEW_RENDER_NAME = "DuckAssistKeepView"
local ASSIST_COOLDOWN = 0.3
local MAX_PEEK_TIME = 0.6
local DEFAULT_CAMERA_OFFSET = Vector3.new(0, -0.15, 0)
local VIEW_RELEASE_TAU = 0.05

local DuckAssist = {}
DuckAssist.__index = DuckAssist

setmetatable(DuckAssist, { __index = BaseFeature })

function DuckAssist.new(link: gameUi.Linker): DuckAssist
	local self = BaseFeature.new() :: any
	setmetatable(self, DuckAssist)

	local mainToggle = link:Toggle("duckAssist", "Duck Assist", false):SetTip({
		title = "Duck Assist",
		body = "Keeps you crouched and pops up just enough to take a shot when standing would clear cover.",
	})
	link:Extra(mainToggle, "duckAssistOpts", "Submenu", "Duck Assist Options")
	local opts = link:OnKey("duckAssistOpts")
	opts:Toggle("keepView", "Keep View Up", true):SetTip({
		title = "Keep View Up",
		body = "Stops the screen from dropping while crouched without changing how you move.",
	})
	opts:Toggle("fakeDuck", "Fake Duck", false):SetTip({
		title = "Fake Duck",
		body = "Stay crouched but fire as if you were standing up.",
	})

	self._assisting = false
	self._lastAssistEndedAt = 0
	self._assistStartedAt = 0
	self._fakeDuck = opts:Get("fakeDuck"):Peek() == true
	self._keepView = opts:Get("keepView"):Peek() == true
	self._enabled = false
	self._hookedHumanoid = nil :: Humanoid?
	self._spoofY = nil :: number?
	self._keepViewBound = false
	self._activeJanitor = nil :: Janitor.Janitor?

	self:Track(link:Get("duckAssist"):OnChange(function(value: boolean)
		self:_setEnabled(value)
	end))

	self:Track(opts:Get("fakeDuck"):OnChange(function(value: boolean)
		self._fakeDuck = value
		if not value then
			Ragebot.SetOriginOffset(nil)
		end
	end))

	self:Track(opts:Get("keepView"):OnChange(function(value: boolean)
		self._keepView = value
		if value and self._enabled then
			self:_ensureKeepViewBind()
		end
	end))

	self:Track(ragebotApi.signals.onShotFired:Connect(function(): ()
		if self._assisting then
			self:_endAssist()
		end
	end))

	if link:Peek("duckAssist") == true then
		self:_setEnabled(true)
	end

	return self
end

function DuckAssist._endAssist(self: DuckAssist): ()
	if self._assisting then
		self._assisting = false
		self._lastAssistEndedAt = tick()
	end
	local character = ClientController.GetCharacterObject()
	if character then
		character.CrouchInputDown = true
	end
end

function DuckAssist._clearKeepView(self: DuckAssist): ()
	self._spoofY = nil
	localLookController.SetViewOffset(nil)
	local humanoid = self._hookedHumanoid
	if humanoid then
		self._hookedHumanoid = nil
		hook.unspoofProperty(humanoid, "CameraOffset")
	end
end

function DuckAssist._ensureKeepViewBind(self: DuckAssist): ()
	if self._keepViewBound then
		return
	end
	self._keepViewBound = true
	RunService:BindToRenderStep(
		KEEPVIEW_RENDER_NAME,
		Enum.RenderPriority.First.Value + 1,
		LPH_NO_VIRTUALIZE(function(dt: number): ()
			self:_keepViewStep(dt)
		end)
	)
end

function DuckAssist._unbindKeepView(self: DuckAssist): ()
	if not self._keepViewBound then
		return
	end
	self._keepViewBound = false
	RunService:UnbindFromRenderStep(KEEPVIEW_RENDER_NAME)
end

DuckAssist._keepViewStep = LPH_NO_VIRTUALIZE(function(self: DuckAssist, dt: number): ()
	local want = self._enabled and self._keepView

	local humanoid = peek(ClientState.parts).Humanoid :: Humanoid?
	if not humanoid then
		self:_clearKeepView()
		if not want then
			self:_unbindKeepView()
		end
		return
	end

	if self._hookedHumanoid ~= humanoid then
		self:_clearKeepView()
		if not want then
			self:_unbindKeepView()
			return
		end
		hook.addInstance(humanoid)
		self._hookedHumanoid = humanoid
	end

	local defaultOffset = (LocalPlayer:GetAttribute("DefaultCameraOffset") :: Vector3?) or DEFAULT_CAMERA_OFFSET
	local real = humanoid.CameraOffset
	local targetY = (want and defaultOffset.Y) or real.Y
	local currentY = self._spoofY or real.Y
	local alpha = 1 - math.exp(-dt / VIEW_RELEASE_TAU)
	local newY = currentY + (targetY - currentY) * alpha

	if not want and math.abs(newY - real.Y) < 0.02 then
		self:_clearKeepView()
		self:_unbindKeepView()
		return
	end

	self._spoofY = newY
	hook.spoofProperty(humanoid, "CameraOffset", Vector3.new(real.X, newY, real.Z))

	local lift = newY - real.Y
	localLookController.SetViewOffset((lift > 0.05 and Vector3.new(0, lift, 0)) or nil)
end)

DuckAssist._step = LPH_NO_VIRTUALIZE(function(self: DuckAssist): ()
	local character = ClientController.GetCharacterObject()
	if not character or not peek(ClientState.alive) then
		self:_endAssist()
		return
	end

	if not ragebotApi.IsEnabled() then
		self:_endAssist()
		return
	end

	local weapon = peek(LoadoutState.currentEquipped) :: any
	if not weapon or not WeaponController.CanShoot(weapon) then
		self:_endAssist()
		return
	end

	local humanoid = peek(ClientState.parts).Humanoid :: Humanoid?
	if not humanoid then
		self:_endAssist()
		return
	end

	local realPos = localLookController.GetRealCameraPosition()
	local defaultOffset = (LocalPlayer:GetAttribute("DefaultCameraOffset") :: Vector3?) or DEFAULT_CAMERA_OFFSET
	local lift = defaultOffset.Y - humanoid.CameraOffset.Y
	local standingEyeY = realPos.Y + lift
	local standingOrigin = Vector3.new(realPos.X, standingEyeY, realPos.Z)

	if self._fakeDuck then
		Ragebot.SetOriginOffset((lift > 0.05 and Vector3.new(0, lift, 0)) or nil)
		character.CrouchInputDown = true
		return
	end

	local reachableNow = Ragebot.HasReachableTarget(realPos)

	if self._assisting then
		if tick() - self._assistStartedAt > MAX_PEEK_TIME then
			self:_endAssist()
			return
		end
		if not reachableNow and not Ragebot.HasReachableTarget(standingOrigin) then
			self:_endAssist()
			return
		end
		character.CrouchInputDown = false
		return
	end

	if reachableNow or tick() - self._lastAssistEndedAt < ASSIST_COOLDOWN then
		character.CrouchInputDown = true
		return
	end

	if Ragebot.HasReachableTarget(standingOrigin) then
		self._assisting = true
		self._assistStartedAt = tick()
		character.CrouchInputDown = false
	else
		character.CrouchInputDown = true
	end
end)

function DuckAssist._setEnabled(self: DuckAssist, enabled: boolean): ()
	if enabled then
		if self._activeJanitor then
			return
		end
		self._enabled = true
		local janitor = Janitor.new()
		self._activeJanitor = janitor

		RunService:BindToRenderStep(
			RENDER_NAME,
			Enum.RenderPriority.First.Value,
			LPH_NO_VIRTUALIZE(function(): ()
				self:_step()
			end)
		)
		janitor:Add(function(): ()
			RunService:UnbindFromRenderStep(RENDER_NAME)
			self._assisting = false
			Ragebot.SetOriginOffset(nil)
			local character = ClientController.GetCharacterObject()
			if character then
				character.CrouchInputDown = false
			end
		end, true)

		if self._keepView then
			self:_ensureKeepViewBind()
		end
	else
		self._enabled = false
		self:_ensureKeepViewBind()
		local janitor = self._activeJanitor
		if not janitor then
			return
		end
		self._activeJanitor = nil
		janitor:Destroy()
	end
end

function DuckAssist.Destroy(self: DuckAssist): ()
	self:_setEnabled(false)
	self:_unbindKeepView()
	self:_clearKeepView()
	BaseFeature.Destroy(self)
end

export type DuckAssist =
	typeof(setmetatable(
		{} :: {
			_assisting: boolean,
			_lastAssistEndedAt: number,
			_assistStartedAt: number,
			_fakeDuck: boolean,
			_keepView: boolean,
			_enabled: boolean,
			_hookedHumanoid: Humanoid?,
			_spoofY: number?,
			_keepViewBound: boolean,
			_activeJanitor: Janitor.Janitor?,
		},
		DuckAssist
	))
	& BaseFeature.BaseFeature

return DuckAssist
