return LPH_JIT(function()
	local Players = cloneref(game:GetService("Players")) :: Players
	local RunService = cloneref(game:GetService("RunService")) :: RunService

	local Charm = require("@pkg/Charm")
	local BaseFeature = require("@game/BaseFeature")
	local gameUi = require("@game/gameUi")
	local ClientState = require("@game/overkill/client/clientState")
	local PlayerController = require("@feature/player/PlayerController")
	local CommandController = require("@game/overkill/weapon/CommandController")
	local ModuleController = require("@game/overkill/module/ModuleController")
	local worldRaycast = require("@game/overkill/weapon/worldRaycast")
	local sessionState = require("@feature/session/sessionState")

	local LocalPlayer = Players.LocalPlayer
	local peek = Charm.peek
	local sub = Charm.subscribe
	local now = tick

	local BTN_ABILITY = 8
	local BTN_QUICK_MELEE = 64

	local CHECK_INTERVAL = 0.05
	local MIN_REACT_COOLDOWN = 0.3
	local MODE_ON_HURT = "On Hurt"
	local MODE_PREDICTIVE = "Predictive"
	local MODES: { string } = { MODE_ON_HURT, MODE_PREDICTIVE }

	local clientModule: any = nil
	local items: any = nil

	local function equippedInfo(): (any, any, number)
		if not clientModule then
			clientModule = ModuleController.GetModule("clientModule")
		end
		local localChickynoid = clientModule and clientModule.localChickynoid
		local simulation = localChickynoid and localChickynoid.simulation
		local state = simulation and simulation.state
		if type(state) ~= "table" then
			return nil, nil, 1
		end
		local slot = state.equippedSlot or 1
		if not items then
			items = ModuleController.GetModule("items")
		end
		local weaponId = state["slot" .. slot .. "_weaponID"]
		local item = (items and type(weaponId) == "string" and weaponId ~= "") and items.all[weaponId] or nil
		return state, item, slot
	end

	local function lookupCategory(weaponId: any): string?
		if not items then
			items = ModuleController.GetModule("items")
		end
		if not items or type(weaponId) ~= "string" or weaponId == "" then
			return nil
		end
		local item = items.all[weaponId]
		return item and item.category or nil
	end

	local function findDeflectSlot(state: any): (number?, any)
		if not items then
			items = ModuleController.GetModule("items")
		end
		if not items then
			return nil, nil
		end
		for slot = 1, 4 do
			local weaponId = state["slot" .. slot .. "_weaponID"]
			local item = (type(weaponId) == "string" and weaponId ~= "") and items.all[weaponId] or nil
			if item and item.category == "melee" then
				local ability = item.stats and item.stats.melee and item.stats.melee.ability
				if ability and ability.type == "deflect" then
					return slot, ability
				end
			end
		end
		return nil, nil
	end

	local AutoDeflect = {}
	AutoDeflect.__index = AutoDeflect

	setmetatable(AutoDeflect, { __index = BaseFeature })

	function AutoDeflect.new(link: gameUi.Linker): AutoDeflect
		local self = BaseFeature.new() :: any
		setmetatable(self, AutoDeflect)

		local toggle = link:Toggle("autoDeflect", "Auto Deflect", false):SetTip({
			title = "Auto Deflect",
			body = "Auto-blocks with a sword to stop incoming hits.",
		})
		local deflectLink = link:OnKey("autoDeflect")
		deflectLink:Submenu("opts", "Auto Deflect Options")
		local optsLink = deflectLink:OnKey("opts")

		optsLink:Dropdown("mode", "Mode", MODES, MODE_ON_HURT):SetTip({
			title = "Mode",
			body = "On Hurt blocks right after you take damage. Predictive blocks when an enemy lines up a shot on you.",
		})
		optsLink:Slider("hpThreshold", "HP Threshold", 150, 1, 150, 1, nil, "hp"):SetTip({
			title = "HP Threshold",
			body = "On Hurt only blocks when your health is at or below this.",
		})
		optsLink:Slider("range", "Range", 60, 5, 150, 1, nil, "st"):SetTip({
			title = "Range",
			body = "Predictive only reacts to enemies within this distance.",
		})
		optsLink:Slider("aimAngle", "Aim Angle", 12, 1, 60, 1, nil, "°"):SetTip({
			title = "Aim Angle",
			body = "Predictive blocks when an enemy aim is within this angle of you. Lower is stricter.",
		})
		optsLink
			:Slider("delay", "Reaction Delay", 0, 0, 500, 5, nil, "ms")
			:SetTip({
				title = "Reaction Delay",
				body = "Predictive waits this long before blocking. Auto matches your ping.",
			})
			:SetValueTextOverrides({ [0] = "Auto" })

		self._enabled = false
		self._mode = optsLink:Get("mode"):Peek() or MODE_ON_HURT
		self._hpThreshold = optsLink:Get("hpThreshold"):Peek()
		self._range = optsLink:Get("range"):Peek()
		self._aimAngleCos = math.cos(math.rad(optsLink:Get("aimAngle"):Peek()))
		self._delayMs = optsLink:Get("delay"):Peek()
		self._accum = 0
		self._threatSince = nil :: number?
		self._lastReact = 0
		self._reactCooldown = MIN_REACT_COOLDOWN
		self._lastHealth = peek(ClientState.health)
		self._pulse = false
		self._pulseButton = BTN_QUICK_MELEE
		self._conn = nil :: RBXScriptConnection?
		self._unregister = nil :: (() -> ())?

		self:Track(toggle:OnChange(function(value: boolean): ()
			if value then
				self:Enable()
			else
				self:Disable()
			end
		end))

		self:Track(optsLink:Get("mode"):OnChange(function(value: string): ()
			self._mode = value or MODE_ON_HURT
		end))
		self:Track(optsLink:Get("hpThreshold"):OnChange(function(value: number): ()
			self._hpThreshold = value
		end))
		self:Track(optsLink:Get("range"):OnChange(function(value: number): ()
			self._range = value
		end))
		self:Track(optsLink:Get("aimAngle"):OnChange(function(value: number): ()
			self._aimAngleCos = math.cos(math.rad(value))
		end))
		self:Track(optsLink:Get("delay"):OnChange(function(value: number): ()
			self._delayMs = value
		end))

		self:Track(sub(ClientState.health, function(health: number): ()
			self:_onHealth(health)
		end))

		return self
	end

	function AutoDeflect._react(self: AutoDeflect): boolean
		if not peek(ClientState.alive) then
			return false
		end
		if now() - self._lastReact < self._reactCooldown then
			return false
		end

		local state, _, equippedSlot = equippedInfo()
		if not state then
			return false
		end

		local slot, ability = findDeflectSlot(state)
		if not slot then
			return false
		end

		self._reactCooldown = math.max(ability.cooldown or 0, ability.linger or 0, MIN_REACT_COOLDOWN)
		self._lastReact = now()
		self._pulseButton = slot == equippedSlot and BTN_ABILITY or BTN_QUICK_MELEE
		self._pulse = true
		return true
	end

	function AutoDeflect._onHealth(self: AutoDeflect, health: number): ()
		local last = self._lastHealth
		self._lastHealth = health

		if not self._enabled or self._mode ~= MODE_ON_HURT then
			return
		end
		if health <= 0 or health >= last then
			return
		end
		if health > self._hpThreshold then
			return
		end
		self:_react()
	end

	function AutoDeflect._step(self: AutoDeflect, dt: number): ()
		self._accum += dt
		if self._accum < CHECK_INTERVAL then
			return
		end
		self._accum = 0

		if self._mode ~= MODE_PREDICTIVE then
			self._threatSince = nil
			return
		end
		if not peek(ClientState.alive) then
			self._threatSince = nil
			return
		end

		local hrp = peek(ClientState.hrp)
		if not hrp then
			self._threatSince = nil
			return
		end

		local origin = hrp.Position
		local team = peek(ClientState.team)
		local range = self._range
		local minCos = self._aimAngleCos

		local threat = false
		for player, basePlayer in next, PlayerController.GetAll() do
			if player == LocalPlayer or not peek(basePlayer.alive) then
				continue
			end
			if team ~= "" and peek(basePlayer.team) == team then
				continue
			end
			local enemyHrp = peek(basePlayer.hrp)
			if not enemyHrp then
				continue
			end

			local enemyPos = enemyHrp.Position
			local dx = origin.X - enemyPos.X
			local dz = origin.Z - enemyPos.Z
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist > range or dist < 0.1 then
				continue
			end

			local look = enemyHrp.CFrame.LookVector
			local lx = look.X
			local lz = look.Z
			local lookMag = math.sqrt(lx * lx + lz * lz)
			if lookMag < 1e-4 then
				continue
			end
			if (lx * dx + lz * dz) / (lookMag * dist) < minCos then
				continue
			end

			if lookupCategory(peek(basePlayer.weaponId)) == "sniper_rifle" and not peek(basePlayer.aiming) then
				continue
			end

			if not worldRaycast.clearLineOfSight(enemyPos, origin) then
				continue
			end

			threat = true
			break
		end

		if not threat then
			self._threatSince = nil
			return
		end

		local since = self._threatSince
		if not since then
			since = now()
			self._threatSince = since
		end

		local delaySec = self._delayMs > 0 and self._delayMs / 1000 or peek(sessionState.ping) / 2 / 1000
		if now() - since >= delaySec and self:_react() then
			self._threatSince = nil
		end
	end

	function AutoDeflect.Enable(self: AutoDeflect): ()
		if self._enabled then
			return
		end
		self._enabled = true
		self._accum = 0
		self._threatSince = nil
		self._lastHealth = peek(ClientState.health)
		self._pulse = false
		self._unregister = CommandController.Register(
			LPH_NO_VIRTUALIZE(function(command: any): ()
				if not self._pulse or type(command) ~= "table" then
					return
				end
				self._pulse = false
				command.buttons = bit32.bor(command.buttons or 0, self._pulseButton)
			end),
			10
		)
		self._conn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
			self:_step(dt)
		end))
	end

	function AutoDeflect.Disable(self: AutoDeflect): ()
		if not self._enabled then
			return
		end
		self._enabled = false
		self._threatSince = nil
		self._pulse = false
		if self._conn then
			self._conn:Disconnect()
			self._conn = nil
		end
		if self._unregister then
			self._unregister()
			self._unregister = nil
		end
	end

	function AutoDeflect.Destroy(self: AutoDeflect): ()
		self:Disable()
		BaseFeature.Destroy(self)
	end

	export type AutoDeflect =
		typeof(setmetatable(
			{} :: {
				_enabled: boolean,
				_mode: string,
				_hpThreshold: number,
				_range: number,
				_aimAngleCos: number,
				_delayMs: number,
				_accum: number,
				_threatSince: number?,
				_lastReact: number,
				_reactCooldown: number,
				_lastHealth: number,
				_pulse: boolean,
				_pulseButton: number,
				_conn: RBXScriptConnection?,
				_unregister: (() -> ())?,
			},
			AutoDeflect
		))
		& BaseFeature.BaseFeature

	return AutoDeflect
end)()
