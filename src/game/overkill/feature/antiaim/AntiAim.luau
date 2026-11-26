return LPH_JIT_MAX(function()
	local RunService = cloneref(game:GetService("RunService")) :: RunService

	local BaseFeature = require("@game/BaseFeature")
	local gameUi = require("@game/gameUi")
	local Charm = require("@pkg/Charm")
	local ModuleController = require("@game/overkill/module/ModuleController")
	local CommandController = require("@game/overkill/weapon/CommandController")
	local firePredict = require("@game/overkill/weapon/firePredict")
	local clientState = require("@game/overkill/client/clientState")
	local antiAimState = require("@game/overkill/feature/antiaim/antiAimState")
	local PlayerController = require("@feature/player/PlayerController")
	local botSource = require("@game/overkill/feature/training/botSource")
	local targeting = require("@game/overkill/player/targeting")
	local worldRaycast = require("@game/overkill/weapon/worldRaycast")
	local freestand = require("@game/universal/feature/combat/antiaim/freestand")

	local peek = Charm.peek
	local isEnemy = targeting.isEnemy

	local TAU = math.pi * 2
	local PITCH_LIMIT = 1.4
	local EYE_OFFSET = Vector3.new(0, 1.5, 0)

	local FREESTAND_POSITIONS: { Vector3 } = table.create(16)

	local collectEnemies = LPH_NO_VIRTUALIZE(function(buffer: { Vector3 }, count: number, list: { [any]: any }): number
		for _, bp in next, list do
			if not isEnemy(bp) then
				continue
			end
			local enemyParts = peek(bp.parts)
			local enemyHead = (enemyParts.Head or enemyParts.HumanoidRootPart) :: BasePart?
			if enemyHead then
				count += 1
				buffer[count] = enemyHead.Position
			end
		end
		return count
	end)

	local SPOOF_NAME = "limerenceAntiAimSpoof"
	local RESTORE_NAME = "limerenceAntiAimRestore"
	local SPOOF_PRIORITY = Enum.RenderPriority.Input.Value - 3
	local RESTORE_PRIORITY = Enum.RenderPriority.Input.Value + 2

	local AntiAim = {}
	AntiAim.__index = AntiAim

	setmetatable(AntiAim, { __index = BaseFeature })

	function AntiAim.new(link: gameUi.Linker): AntiAim
		local self = BaseFeature.new() :: any
		setmetatable(self, AntiAim)

		self._enabled = false
		self._spin = 0
		self._yawJitter = 1
		self._pitchJitter = 1
		self._predict = firePredict.new()
		self._spoofed = false
		self._origRotation = nil
		self._appliedOffset = 0
		self._correctPending = false
		self._bound = false
		self._unregister = nil :: (() -> ())?
		self._cameraHandler = nil :: any
		self._clientModule = nil :: any
		self._freestand = freestand.new(worldRaycast.clearLineOfSight)

		link:Toggle("antiAim", "Anti Aim", false):SetTip({
			title = "Anti Aim",
			body = "Makes your character face a different direction than you are actually looking.",
		})
		local antiAimLink = link:OnKey("antiAim")
		antiAimLink:Submenu("opts", "Anti Aim")
		local optsLink = antiAimLink:OnKey("opts")
		optsLink
			:Dropdown("yaw", "Yaw", { "View", "Backwards", "Left", "Right", "Spin", "Jitter" }, "Backwards")
			:SetTip({
				title = "Yaw",
				body = "Left/right direction other players see, relative to where you look.",
			})
		optsLink:Dropdown("pitch", "Pitch", { "View", "Up", "Down", "Zero", "Jitter" }, "Down"):SetTip({
			title = "Pitch",
			body = "Up/down direction other players see you looking.",
		})
		optsLink:Toggle("freestanding", "Freestanding", false):SetTip({
			title = "Freestanding",
			body = "Automatically faces the left or right side with the most cover from nearby enemies. Falls back to your Yaw setting when neither side is safer.",
		})
		optsLink:Slider("spinSpeed", "Spin Speed", 720, 90, 2000, 10, nil, "°/s"):SetTip({
			title = "Spin Speed",
			body = "How fast you spin when Yaw is set to Spin.",
		})
		optsLink:Slider("jitter", "Jitter", 45, 0, 180, 1, nil, "°"):SetTip({
			title = "Jitter",
			body = "Angle you snap between when Yaw is set to Jitter.",
		})

		self._yaw = optsLink:Get("yaw"):Peek()
		self._pitch = optsLink:Get("pitch"):Peek()
		self._spinSpeed = optsLink:Get("spinSpeed"):Peek()
		self._jitter = optsLink:Get("jitter"):Peek()
		self._freestanding = optsLink:Get("freestanding"):Peek() == true

		self:Track(link:Get("antiAim"):OnChange(function(value: boolean): ()
			if value then
				self:Enable()
			else
				self:Disable()
			end
		end))
		self:Track(optsLink:Get("yaw"):OnChange(function(value: string): ()
			self._yaw = value
		end))
		self:Track(optsLink:Get("pitch"):OnChange(function(value: string): ()
			self._pitch = value
		end))
		self:Track(optsLink:Get("spinSpeed"):OnChange(function(value: number): ()
			self._spinSpeed = value
		end))
		self:Track(optsLink:Get("jitter"):OnChange(function(value: number): ()
			self._jitter = value
		end))
		self:Track(optsLink:Get("freestanding"):OnChange(function(value: boolean): ()
			self._freestanding = value
			if not value then
				self._freestand:Reset()
			end
		end))

		if link:Peek("antiAim") then
			self:Enable()
		end

		return self
	end

	function AntiAim._ensureRefs(self: AntiAim): ()
		if not self._cameraHandler then
			self._cameraHandler = ModuleController.GetModule("cameraHandler")
		end
		if not self._clientModule then
			self._clientModule = ModuleController.GetModule("clientModule")
		end
	end

	function AntiAim._freestandSide(self: AntiAim, realYaw: number): freestand.Side?
		local solver = self._freestand
		local parts = peek(clientState.parts)
		local head = parts.Head :: BasePart?
		local hrp = parts.HumanoidRootPart :: BasePart?
		local eye: Vector3
		if head then
			eye = head.Position
		elseif hrp then
			eye = hrp.Position + EYE_OFFSET
		else
			solver:Reset()
			return nil
		end
		local now = os.clock()
		if solver:ShouldRecompute(now, eye) then
			local count = collectEnemies(FREESTAND_POSITIONS, 0, PlayerController.GetAll())
			count = collectEnemies(FREESTAND_POSITIONS, count, botSource.GetAll())
			local right = CFrame.fromEulerAnglesYXZ(0, realYaw, 0).RightVector
			solver:Compute(now, eye, right, FREESTAND_POSITIONS, nil, count)
		end
		return solver:GetSide()
	end

	function AntiAim._resolveYaw(self: AntiAim, realYaw: number, dt: number): number
		if self._freestanding then
			local side = self:_freestandSide(realYaw)
			if side == "Left" then
				return realYaw + math.pi / 2
			elseif side == "Right" then
				return realYaw - math.pi / 2
			end
		end
		local mode = self._yaw
		if mode == "Backwards" then
			return realYaw + math.pi
		elseif mode == "Left" then
			return realYaw + math.pi / 2
		elseif mode == "Right" then
			return realYaw - math.pi / 2
		elseif mode == "Spin" then
			self._spin = (self._spin + math.rad(self._spinSpeed) * dt) % TAU
			return self._spin
		elseif mode == "Jitter" then
			self._yawJitter = -self._yawJitter
			return realYaw + self._yawJitter * math.rad(self._jitter) * 0.5
		end
		return realYaw
	end

	function AntiAim._resolvePitch(self: AntiAim, realPitch: number): number
		local mode = self._pitch
		if mode == "Up" then
			return PITCH_LIMIT
		elseif mode == "Down" then
			return -PITCH_LIMIT
		elseif mode == "Zero" then
			return 0
		elseif mode == "Jitter" then
			self._pitchJitter = -self._pitchJitter
			return self._pitchJitter * PITCH_LIMIT
		end
		return realPitch
	end

	function AntiAim._clearAngles(self: AntiAim): ()
		antiAimState.lookAngles(nil)
		antiAimState.yawOffset(0)
	end

	function AntiAim._spoof(self: AntiAim, dt: number): ()
		self._spoofed = false
		self._correctPending = false
		if not self._enabled then
			self:_clearAngles()
			return
		end
		self:_ensureRefs()
		if not peek(clientState.alive) then
			self:_clearAngles()
			return
		end
		if peek(clientState.matchId) == nil then
			self:_clearAngles()
			return
		end
		local cameraHandler = self._cameraHandler
		if not cameraHandler then
			self:_clearAngles()
			return
		end
		local clientModule = self._clientModule
		local simulation = clientModule and clientModule.localChickynoid and clientModule.localChickynoid.simulation
		local state = simulation and simulation.state
		if type(state) == "table" and self._predict:willFire(state) then
			self:_clearAngles()
			return
		end
		local rotation = cameraHandler.currentRotation
		if rotation == nil then
			self:_clearAngles()
			return
		end
		local realYaw = rotation.Y
		local realPitch = rotation.X
		local fakeYaw = self:_resolveYaw(realYaw, dt)
		local fakePitch = math.clamp(self:_resolvePitch(realPitch), -PITCH_LIMIT, PITCH_LIMIT)
		self._appliedOffset = fakeYaw - realYaw
		self._origRotation = rotation
		local fakeRotation = Vector3.new(fakePitch, fakeYaw, rotation.Z)
		cameraHandler.currentRotation = fakeRotation
		antiAimState.lookAngles(fakeRotation)
		antiAimState.yawOffset(self._appliedOffset)
		self._spoofed = true
		self._correctPending = true
	end

	function AntiAim._restore(self: AntiAim): ()
		if not self._spoofed then
			return
		end
		local cameraHandler = self._cameraHandler
		if cameraHandler and self._origRotation ~= nil then
			cameraHandler.currentRotation = self._origRotation
		end
		self._spoofed = false
		self._origRotation = nil
	end

	function AntiAim.Enable(self: AntiAim): ()
		if self._enabled then
			return
		end
		self._enabled = true

		self._unregister = CommandController.Register(
			LPH_NO_VIRTUALIZE(function(command: any): ()
				if not self._correctPending then
					return
				end
				if type(command) ~= "table" then
					return
				end
				local offset = self._appliedOffset
				if offset == 0 then
					return
				end
				local x = command.x or 0
				local z = command.z or 0
				if x == 0 and z == 0 then
					return
				end
				local corrected = CFrame.fromEulerAnglesYXZ(0, -offset, 0) * Vector3.new(x, 0, z)
				command.x = corrected.X
				command.z = corrected.Z
			end),
			40
		)

		RunService:BindToRenderStep(
			SPOOF_NAME,
			SPOOF_PRIORITY,
			LPH_NO_VIRTUALIZE(function(dt: number): ()
				self:_spoof(dt)
			end)
		)
		RunService:BindToRenderStep(
			RESTORE_NAME,
			RESTORE_PRIORITY,
			LPH_NO_VIRTUALIZE(function(): ()
				self:_restore()
			end)
		)
		self._bound = true
	end

	function AntiAim.Disable(self: AntiAim): ()
		if not self._enabled then
			return
		end
		self._enabled = false

		if self._bound then
			RunService:UnbindFromRenderStep(SPOOF_NAME)
			RunService:UnbindFromRenderStep(RESTORE_NAME)
			self._bound = false
			self:_restore()
		end

		if self._unregister then
			self._unregister()
			self._unregister = nil
		end

		self._correctPending = false
		self:_clearAngles()
		self._freestand:Reset()
		self._cameraHandler = nil
		self._clientModule = nil
	end

	function AntiAim.Destroy(self: AntiAim): ()
		self:Disable()
		BaseFeature.Destroy(self)
	end

	export type AntiAim =
		typeof(setmetatable(
			{} :: {
				_enabled: boolean,
				_spin: number,
				_yawJitter: number,
				_pitchJitter: number,
				_predict: firePredict.FirePredict,
				_spoofed: boolean,
				_origRotation: any,
				_appliedOffset: number,
				_correctPending: boolean,
				_bound: boolean,
				_unregister: (() -> ())?,
				_cameraHandler: any,
				_clientModule: any,
				_yaw: string,
				_pitch: string,
				_spinSpeed: number,
				_jitter: number,
				_freestanding: boolean,
				_freestand: freestand.Freestand,
				_freestandSide: (AntiAim, number) -> freestand.Side?,
				_ensureRefs: (AntiAim) -> (),
				_clearAngles: (AntiAim) -> (),
				_resolveYaw: (AntiAim, number, number) -> number,
				_resolvePitch: (AntiAim, number) -> number,
				_spoof: (AntiAim, number) -> (),
				_restore: (AntiAim) -> (),
			},
			AntiAim
		))
		& BaseFeature.BaseFeature

	return AntiAim
end)()
