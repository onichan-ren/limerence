return LPH_JIT_MAX(function()
	local Players = cloneref(game:GetService("Players")) :: Players
	local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
	local Signal = require("@pkg/Signal")
	local NetworkController = require("@game/overkill/network/NetworkController")
	local ModuleController = require("@game/overkill/module/ModuleController")
	local CommandBaseController = require("@game/overkill/weapon/CommandBaseController")
	local botSource = require("@game/overkill/feature/training/botSource")

	local LocalPlayer = Players.LocalPlayer

	local FIRE_MAX_HOLD = 0.25
	local FIRE_ACTION = "Shoot"
	local AIM_ACTION = "Aim"
	local BTN_PRIMARY = 1

	local inputHandler: any = nil

	local fireInputs: { [any]: boolean } = {}
	local userHoldingFire = false

	local function refreshFireBinds(): ()
		if not inputHandler then
			return
		end
		local bindings = inputHandler.Bindings
		local list = bindings and bindings[FIRE_ACTION]
		table.clear(fireInputs)
		if type(list) == "table" then
			for _, enumItem in next, list do
				if enumItem ~= Enum.KeyCode.Unknown then
					fireInputs[enumItem] = true
				end
			end
		end
	end

	local function inputIsFire(input: InputObject): boolean
		return fireInputs[input.KeyCode] == true or fireInputs[input.UserInputType] == true
	end

	local function press(action: string, state: boolean): ()
		if action == FIRE_ACTION and userHoldingFire then
			return
		end
		if not inputHandler then
			return
		end
		setthreadidentity(2)
		if state then
			inputHandler:beginAction(action)
		else
			inputHandler:stopAction(action)
		end
		setthreadidentity(8)
	end

	local WeaponController = {
		hitPlayer = Signal.new(),
		killedPlayer = Signal.new(),
		shotFired = Signal.new(),
		observedShot = Signal.new(),
		weaponUsed = Signal.new(),
		weaponFiredLocal = Signal.new(),
		_firing = false,
		_aiming = false,
		_fireToken = 0,
	}

	local unhooks: { () -> () } = {}

	local resolveVictim = LPH_NO_VIRTUALIZE(function(hitObject: any): Player?
		if typeof(hitObject) ~= "Instance" then
			return nil
		end
		if hitObject:IsA("Player") then
			return hitObject
		end
		local model = (hitObject:IsA("Model") and hitObject) or hitObject:FindFirstAncestorOfClass("Model")
		if not model then
			return nil
		end
		return Players:GetPlayerFromCharacter(model)
	end)

	local function resolveEnd(shotData: any): Vector3
		local hitPos = shotData.hitPos
		if typeof(hitPos) == "Vector3" then
			return hitPos
		end
		local origin = shotData.origin
		local direction = shotData.direction
		if typeof(direction) == "Vector3" then
			return origin + direction
		end
		return origin
	end

	local fireHit = LPH_NO_VIRTUALIZE(function(shotData: any): ()
		local position = resolveEnd(shotData)
		local partName = type(shotData.limbHit) == "string" and shotData.limbHit or ""
		local damage = type(shotData.damage) == "number" and shotData.damage or 0
		local headshot = partName == "head"

		local victim = resolveVictim(shotData.hitObject)
		if victim and victim ~= LocalPlayer then
			WeaponController.hitPlayer:Fire(victim, victim.Character, partName, position, damage, headshot)
			return
		end

		local dummyUserId = shotData.hitDummyUserId
		if type(dummyUserId) == "number" then
			local bot = botSource.GetByDummyUserId(dummyUserId)
			if bot then
				WeaponController.hitPlayer:Fire(bot:GetPlayer(), bot:GetModel(), partName, position, damage, headshot)
			end
		end
	end)

	local onShot = function(payload: any): ()
		if type(payload) ~= "table" then
			return
		end

		local player = payload.player
		local shotData = payload.shotData
		if type(shotData) ~= "table" or typeof(shotData.origin) ~= "Vector3" then
			return
		end

		local origin = shotData.origin
		local endPosition = resolveEnd(shotData)

		if player ~= LocalPlayer then
			WeaponController.observedShot:Fire(player, origin, endPosition)
			return
		end

		WeaponController.shotFired:Fire(origin, endPosition)
		WeaponController.weaponUsed:Fire()
		setthreadidentity(8)
		fireHit(shotData)
	end

	local onShotMulti = function(payload: any): ()
		if type(payload) ~= "table" then
			return
		end

		local shots = payload.shots
		if type(shots) ~= "table" then
			return
		end

		local first = shots[1]
		if type(first) ~= "table" or typeof(first.origin) ~= "Vector3" then
			return
		end

		local player = payload.player
		if player ~= LocalPlayer then
			for _, shotData in next, shots do
				if type(shotData) == "table" and typeof(shotData.origin) == "Vector3" then
					WeaponController.observedShot:Fire(player, shotData.origin, resolveEnd(shotData))
				end
			end
			return
		end

		WeaponController.shotFired:Fire(first.origin, resolveEnd(shots[#shots]))
		WeaponController.weaponUsed:Fire()

		for _, shotData in next, shots do
			if type(shotData) == "table" then
				fireHit(shotData)
			end
		end
	end

	local onBotDied = function(bot: any): ()
		WeaponController.killedPlayer:Fire(bot:GetPlayer(), false, "")
	end

	local onRoundDied = function(payload: any): ()
		if type(payload) ~= "table" or payload.isLeaving then
			return
		end

		local victim = payload.player
		if typeof(victim) ~= "Instance" or not victim:IsA("Player") then
			return
		end

		if payload.killer ~= LocalPlayer then
			return
		end

		WeaponController.killedPlayer:Fire(victim, payload.headShot == true, payload.weaponID)
	end

	function WeaponController.Fire(): ()
		if WeaponController._firing then
			return
		end
		WeaponController._firing = true
		WeaponController._fireToken += 1
		local token = WeaponController._fireToken
		press(FIRE_ACTION, true)
		local conn: any = nil
		local function release(): ()
			if conn then
				conn:Disconnect()
				conn = nil
			end
			if WeaponController._fireToken ~= token or not WeaponController._firing then
				return
			end
			WeaponController._firing = false
			press(FIRE_ACTION, false)
		end
		conn = WeaponController.weaponFiredLocal:Connect(release)
		task.delay(FIRE_MAX_HOLD, release)
	end

	function WeaponController.StopFire(): ()
		if not WeaponController._firing then
			return
		end
		WeaponController._firing = false
		WeaponController._fireToken += 1
		press(FIRE_ACTION, false)
	end

	function WeaponController.SetShooting(state: boolean): ()
		state = state == true
		if state == WeaponController._firing then
			return
		end
		WeaponController._firing = state
		WeaponController._fireToken += 1
		press(FIRE_ACTION, state)
	end

	function WeaponController.SetAiming(state: boolean): ()
		state = state == true
		if state == WeaponController._aiming then
			return
		end
		WeaponController._aiming = state
		press(AIM_ACTION, state)
	end

	function WeaponController.new(): WeaponController
		table.insert(
			unhooks,
			CommandBaseController.Register(
				LPH_NO_VIRTUALIZE(function(command: any): ()
					if WeaponController._firing and type(command) == "table" then
						command.buttons = bit32.bor(command.buttons or 0, BTN_PRIMARY)
					end
				end),
				20
			)
		)
		table.insert(unhooks, NetworkController.HookInbound("shot", onShot))
		table.insert(unhooks, NetworkController.HookInbound("shot_multi", onShotMulti))
		table.insert(unhooks, NetworkController.HookInbound("round_died", onRoundDied))
		local diedConn = botSource.died:Connect(onBotDied)
		table.insert(unhooks, function(): ()
			diedConn:Disconnect()
		end)

		if not inputHandler then
			inputHandler = ModuleController.GetModule("inputHandler")
		end
		refreshFireBinds()
		if inputHandler and inputHandler.KeybindsChanged then
			local keybindConn = inputHandler.KeybindsChanged:Connect(refreshFireBinds)
			table.insert(unhooks, function(): ()
				keybindConn:Disconnect()
			end)
		end

		userHoldingFire = false
		local inputBeganConn = UserInputService.InputBegan:Connect(function(input: InputObject): ()
			if inputIsFire(input) then
				userHoldingFire = true
			end
		end)
		local inputEndedConn = UserInputService.InputEnded:Connect(function(input: InputObject): ()
			if inputIsFire(input) then
				userHoldingFire = false
			end
		end)
		local focusConn = UserInputService.WindowFocusReleased:Connect(function(): ()
			userHoldingFire = false
		end)
		table.insert(unhooks, function(): ()
			inputBeganConn:Disconnect()
			inputEndedConn:Disconnect()
			focusConn:Disconnect()
		end)

		return WeaponController
	end

	function WeaponController.Destroy(): ()
		for _, unhook in next, unhooks do
			unhook()
		end
		table.clear(unhooks)
		if WeaponController._firing then
			WeaponController._firing = false
			press(FIRE_ACTION, false)
		end
		if WeaponController._aiming then
			WeaponController._aiming = false
			press(AIM_ACTION, false)
		end
	end

	export type WeaponController = typeof(WeaponController)

	return WeaponController
end)()
