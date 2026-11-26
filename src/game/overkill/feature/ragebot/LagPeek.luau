return LPH_JIT_MAX(function()
	local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
	local RunService = cloneref(game:GetService("RunService")) :: RunService

	local Charm = require("@pkg/Charm")
	local BaseFeature = require("@game/BaseFeature")
	local gameUi = require("@game/gameUi")
	local ModuleController = require("@game/overkill/module/ModuleController")
	local PlayerController = require("@feature/player/PlayerController")
	local ClientState = require("@game/overkill/client/clientState")
	local botSource = require("@game/overkill/feature/training/botSource")
	local bulletRedirection = require("@game/overkill/feature/legitbot/bulletRedirection")
	local ChokeController = require("@game/overkill/network/ChokeController")
	local worldRaycast = require("@game/overkill/weapon/worldRaycast")
	local gunCategories = require("@game/overkill/weapon/gunCategories")
	local targeting = require("@game/overkill/player/targeting")
	local playerState = require("@feature/record/module/playerState")

	local peek = Charm.peek

	local SERVER_HZ = 60
	local MAX_DEPTH = 6
	local CONE_DOT = 0.5
	local LEAD_TICKS = 2
	local MIN_SPEED_SQ = 4
	local CHECK_PARTS = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" }

	local clientModule: any = nil

	local toDepth = LPH_NO_VIRTUALIZE(function(ms: number): number
		return math.clamp(math.floor(ms / 1000 * SERVER_HZ + 0.5), 1, MAX_DEPTH)
	end)

	local function localVelocity(): Vector3?
		if not clientModule then
			clientModule = ModuleController.GetModule("clientModule")
		end
		local localChickynoid = clientModule and clientModule.localChickynoid
		local simulation = localChickynoid and localChickynoid.simulation
		local state = simulation and simulation.state
		if type(state) ~= "table" then
			return nil
		end
		return state.vel
	end

	local isEnemy = targeting.isEnemy

	local willExpose = LPH_NO_VIRTUALIZE(
		function(
			bp: any,
			origin: Vector3,
			predicted: Vector3,
			look: Vector3,
			ourChar: Instance?,
			ignore: { Instance }
		): boolean
			if not isEnemy(bp) then
				return false
			end
			local rbxPlayer = bp:GetPlayer()
			if not bp.isBot and rbxPlayer and playerState.ShouldSkip(rbxPlayer.UserId) then
				return false
			end
			local parts = peek(bp.parts)
			if next(parts) == nil then
				return false
			end

			local anchor: Vector3? = nil
			for i = 1, #CHECK_PARTS do
				local part = parts[CHECK_PARTS[i]]
				if part and part:IsA("BasePart") then
					anchor = part.CFrame.Position
					break
				end
			end
			if not anchor then
				return false
			end

			local delta = anchor - origin
			local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
			if distSq < 1e-4 then
				return false
			end
			if delta.Unit:Dot(look) < CONE_DOT then
				return false
			end

			local exposes = false
			for i = 1, #CHECK_PARTS do
				local part = parts[CHECK_PARTS[i]]
				if not part or not part:IsA("BasePart") then
					continue
				end
				table.clear(ignore)
				if ourChar then
					ignore[#ignore + 1] = ourChar
				end
				local model = (part :: Instance).Parent
				if model then
					ignore[#ignore + 1] = model
				end
				local target = part.CFrame.Position
				if worldRaycast.clearLineOfSight(origin, target, ignore) then
					return false
				end
				if not exposes and worldRaycast.clearLineOfSight(predicted, target, ignore) then
					exposes = true
				end
			end
			return exposes
		end
	)

	local LagPeek = {}
	LagPeek.__index = LagPeek

	setmetatable(LagPeek, { __index = BaseFeature })

	function LagPeek.new(link: gameUi.Linker): LagPeek
		local self = BaseFeature.new() :: any
		setmetatable(self, LagPeek)

		local toggle = link:Toggle("lagPeek", "Lag Peek", false):SetTip({
			title = "Lag Peek",
			body = "When an enemy is behind cover ahead of you, holds back your step out until you fire, so you appear already shooting.",
		})

		self._enabled = false
		self._armed = false
		self._depth = toDepth(1500)
		self._ignore = table.create(2)
		self._conn = nil :: RBXScriptConnection?

		self:Track(toggle:OnChange(function(value: boolean): ()
			self._enabled = value
			if value then
				self:_install()
			else
				self:_uninstall()
			end
		end))

		if link:Peek("lagPeek") then
			self._enabled = true
			self:_install()
		end

		return self
	end

	function LagPeek._aboutToPeek(self: LagPeek): boolean
		local camera = Workspace.CurrentCamera
		if not camera then
			return false
		end
		local vel = localVelocity()
		if not vel then
			return false
		end
		local speedSq = vel.X * vel.X + vel.Y * vel.Y + vel.Z * vel.Z
		if speedSq < MIN_SPEED_SQ then
			return false
		end
		local head = peek(ClientState.parts).Head
		if not head then
			return false
		end
		local origin = (head :: BasePart).Position
		local predicted = origin + vel * ((self._depth + LEAD_TICKS) / SERVER_HZ)
		local look = camera.CFrame.LookVector
		local ourChar = peek(ClientState.character)
		local ignore = self._ignore

		for _, bp in next, PlayerController.GetAll() do
			if willExpose(bp, origin, predicted, look, ourChar, ignore) then
				return true
			end
		end
		for _, bot in next, botSource.GetAll() do
			if willExpose(bot, origin, predicted, look, ourChar, ignore) then
				return true
			end
		end
		return false
	end

	function LagPeek._setArmed(self: LagPeek, armed: boolean): ()
		if self._armed == armed then
			return
		end
		self._armed = armed
		ChokeController.SetRequest("lagPeek", armed, "fire", self._depth)
	end

	function LagPeek._disarm(self: LagPeek): ()
		self._armed = false
		ChokeController.ClearRequest("lagPeek")
	end

	function LagPeek._install(self: LagPeek): ()
		if self._conn then
			return
		end

		self._conn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
			if not self._enabled then
				return
			end
			if
				not bulletRedirection.isRagebotActive()
				or not peek(ClientState.alive)
				or not gunCategories[peek(ClientState.weaponCategory)]
			then
				self:_setArmed(false)
				return
			end
			self:_setArmed(self:_aboutToPeek())
		end))
	end

	function LagPeek._uninstall(self: LagPeek): ()
		local conn = self._conn
		if conn then
			conn:Disconnect()
			self._conn = nil
		end
		self:_disarm()
	end

	function LagPeek.Destroy(self: LagPeek): ()
		self._enabled = false
		self:_uninstall()
		BaseFeature.Destroy(self)
	end

	export type LagPeek =
		typeof(setmetatable(
			{} :: {
				_enabled: boolean,
				_armed: boolean,
				_depth: number,
				_ignore: { Instance },
				_conn: RBXScriptConnection?,
				_install: (LagPeek) -> (),
				_uninstall: (LagPeek) -> (),
				_aboutToPeek: (LagPeek) -> boolean,
				_setArmed: (LagPeek, boolean) -> (),
				_disarm: (LagPeek) -> (),
			},
			LagPeek
		))
		& BaseFeature.BaseFeature

	return LagPeek
end)()
