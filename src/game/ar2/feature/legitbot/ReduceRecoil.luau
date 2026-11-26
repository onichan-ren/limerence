local ModuleController = require("@game/ar2/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local WeaponController = require("@game/ar2/weapon/WeaponController")

local ReduceRecoil = {}
ReduceRecoil.__index = ReduceRecoil

setmetatable(ReduceRecoil, { __index = BaseFeature })

function ReduceRecoil.new(link: gameUi.Linker): ReduceRecoil
	local self = BaseFeature.new() :: any
	setmetatable(self, ReduceRecoil)

	link:Toggle("reduceRecoil", "Reduce Recoil", false):SetTip({
		title = "Reduce Recoil",
		body = "Reduces view and weapon kick while shooting. Tune vertical and horizontal separately.",
	})

	local masterLink = link:OnKey("reduceRecoil")
	masterLink:Submenu("opts", "Reduce Recoil")
	local optsLink = masterLink:OnKey("opts")

	optsLink:Slider("vertical", "Vertical", 100, 0, 100, 1, nil, "%"):SetTip({
		title = "Vertical",
		body = "How much vertical (up/down) recoil to remove. 100% removes all vertical kick.",
	})
	optsLink:Slider("horizontal", "Horizontal", 100, 0, 100, 1, nil, "%"):SetTip({
		title = "Horizontal",
		body = "How much horizontal (left/right) recoil to remove. 100% removes all horizontal kick.",
	})

	self._link = link
	self._enabledLink = link:Get("reduceRecoil")
	self._vScale = 0
	self._hScale = 0

	self:Track(link:Watch("reduceRecoil.opts.vertical", function(v: any): ()
		self._vScale = 1 - (tonumber(v) or 100) / 100
	end))
	self:Track(link:Watch("reduceRecoil.opts.horizontal", function(v: any): ()
		self._hScale = 1 - (tonumber(v) or 100) / 100
	end))

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("reduceRecoil") then
		self:Enable()
	end

	return self
end

function ReduceRecoil.Enable(self: ReduceRecoil): ()
	if self._enabled then
		return
	end

	self._enabled = true

	local CharacterCamera = ModuleController.GetModule("CharacterCamera")

	if not CharacterCamera then
		return
	end

	local firearmRecoilProcess = CharacterCamera.protos.firearmRecoilProcess
	local cameraData = (debug.getupvalues(firearmRecoilProcess) :: any)[1]

	if not cameraData then
		return
	end

	if type(cameraData) ~= "table" then
		return
	end

	local old
	old = hook.add(
		firearmRecoilProcess,
		LPH_NO_VIRTUALIZE(function(camera, ...)
			local currentWeapon = WeaponController.GetEquippedWeapon()

			if currentWeapon then
				local character = camera.Character
				local springs = character.Animator.Springs
				local recoilData = currentWeapon.RecoilData

				local raise = springs.RaiseSpring:GetPosition() * recoilData.RaiseInfluence
				local shift = springs.ShiftSpring:GetPosition() * recoilData.ShiftCameraInfluence
				local multiplier = 1

				if not camera.FirstPerson then
					raise *= 0.5
					shift *= 0.4
				end

				if currentWeapon.AttachmentStatMods then
					local cameraInfluence = currentWeapon.AttachmentStatMods.CameraInfluence

					if cameraInfluence then
						multiplier = cameraInfluence.Multiplier or multiplier
					end
				end

				raise *= multiplier
				shift *= multiplier

				local processQueue = springs.KickVelocity.ProcessQueue

				local impulse = 0

				for i = #processQueue, 1, -1 do
					impulse += table.remove(processQueue, i)
				end

				local kick = recoilData.KickUpCameraInfluence * impulse * math.rad(0.6)

				if currentWeapon.Attachments and currentWeapon.Attachments.Underbarrel then
					local Underbarrel = currentWeapon.Attachments.Underbarrel

					if Underbarrel.StatModifiers then
						kick *= Underbarrel.StatModifiers.Kick.Velocity
					end
				end

				raise *= self._vScale
				shift *= self._hScale
				kick *= self._vScale

				cameraData.Pitch += kick

				return CFrame.Angles(raise + shift.Y, shift.X, 0)
			end

			return old(camera, ...)
		end)
	)
end

function ReduceRecoil.Disable(self: ReduceRecoil): ()
	if not self._enabled then
		return
	end

	self._enabled = false

	local CharacterCamera = ModuleController.GetModule("CharacterCamera")

	if not CharacterCamera then
		return
	end

	hook.restore(CharacterCamera.protos.firearmRecoilProcess)
end

function ReduceRecoil.Destroy(self: ReduceRecoil): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type ReduceRecoil =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_enabledLink: any,
			_enabled: boolean,
			_vScale: number,
			_hScale: number,
		},
		ReduceRecoil
	))
	& BaseFeature.BaseFeature

return ReduceRecoil
