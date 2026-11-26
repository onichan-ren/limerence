local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local ClientState = require("@game/mvsd/client/clientState")
local UniversalLegitbot = require("@game/universal/feature/combat/legitbot/Legitbot")
local bulletRedirection = require("@game/mvsd/feature/legitbot/bulletRedirection")

local peek = Charm.peek
local sub = Charm.subscribe

local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local function isLocalInAir(): boolean
	local humanoid = peek(ClientState.humanoid)
	if not humanoid then
		return false
	end
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
end

local shouldFilter = LPH_NO_VIRTUALIZE(function(instance: BasePart): boolean
	return instance.Transparency == 1 and instance.CanCollide == false
end)

local sharedRaycastParams = RaycastParams.new()
sharedRaycastParams.FilterType = Enum.RaycastFilterType.Exclude

local recursiveRaycast
recursiveRaycast = LPH_NO_VIRTUALIZE(
	function(origin: Vector3, direction: Vector3, params: RaycastParams): RaycastResult?
		local result = Workspace:Raycast(origin, direction, params)

		if not result then
			return
		end

		local instance = result.Instance

		if instance and shouldFilter(instance) then
			local position = result.Position

			params:AddToFilter(instance)
			return recursiveRaycast(position + result.Normal * 0.01, direction - (position - origin), params)
		end

		return result
	end
)

local Legitbot = {}

function Legitbot.new(
	link: gameUi.Linker,
	opts: {
		targettingLink: gameUi.Linker,
		aimLink: gameUi.Linker,
		triggerLink: gameUi.Linker,
		visualsLink: gameUi.Linker,
		bulletRedirectionLink: gameUi.Linker,
	}
): UniversalLegitbot.Legitbot
	local lastShotAt = 0

	local game: UniversalLegitbot.GameOpts = {
		getLocalAlive = function(): boolean
			return peek(ClientState.alive)
		end,
		getLocalTeam = function(): string?
			return peek(ClientState.team)
		end,
		getEquippedWeapon = function(): any?
			return peek(ClientState.equippedTool)
		end,
		canShoot = LPH_NO_VIRTUALIZE(function(tool: any): boolean
			if peek(ClientState.weapon) ~= "gun" or not tool.Enabled then
				return false
			end
			local cooldown = tool:GetAttribute("Cooldown")
			return cooldown == nil or os.clock() - lastShotAt >= cooldown
		end),
		getLocalOnCooldown = LPH_NO_VIRTUALIZE(function(): boolean
			local tool = peek(ClientState.equippedTool)
			if not tool or peek(ClientState.weapon) ~= "gun" then
				return false
			end
			local cooldown = tool:GetAttribute("Cooldown")
			return cooldown ~= nil and os.clock() - lastShotAt < cooldown
		end),
		isPlayerBlocking = LPH_NO_VIRTUALIZE(function(player: any): boolean
			local localMatch = peek(ClientState.matchId)
			if localMatch == nil then
				return true
			end
			return peek(player.matchId) ~= localMatch
		end),
		getFlashVisibility = function(): number
			return peek(ClientState.blinded) and 0.4 or 0
		end,

		gameRaycast = LPH_NO_VIRTUALIZE(
			function(origin: Vector3, target: Vector3, ignore: { Instance }): RaycastResult?
				local raycastParams = sharedRaycastParams
				raycastParams.FilterDescendantsInstances = ignore

				return recursiveRaycast(origin, target - origin, raycastParams)
			end
		),

		getLocalInAir = isLocalInAir,

		getAimPoint2d = function(): Vector2
			return UserInputService:GetMouseLocation()
		end,

		setBulletRedirectionActive = bulletRedirection.setActive,
		setBulletRedirectionTarget = bulletRedirection.setTarget,
		setBulletRedirectionChance = bulletRedirection.setChance,

		uiOpts = {
			targettingConditions = { "While Blind", "While In Air", "While On Cooldown" },
			defaultTargettingConditions = { "While On Cooldown", "While In Air" },
			showBlindThreshold = false,
			showSmokeThreshold = false,
			showAutowall = false,
			showRcs = false,
			showTrigger = true,
			showHitChance = false,
			showMinDamage = false,
			showAimFirstBulletDelay = false,
			showTriggerFirstBulletDelay = false,
			showManipulation = false,
			showTriggerBullets = false,
		},
	}

	local instance = UniversalLegitbot.new(link, {
		targettingLink = opts.targettingLink,
		aimLink = opts.aimLink,
		triggerLink = opts.triggerLink,
		visualsLink = opts.visualsLink,
		bulletRedirectionLink = opts.bulletRedirectionLink,
		game = game,
	} :: any)

	local toolConn: RBXScriptConnection? = nil
	local function watchTool(tool: Tool?): ()
		if toolConn then
			toolConn:Disconnect()
			toolConn = nil
		end
		if tool then
			toolConn = tool.Activated:Connect(function(): ()
				lastShotAt = os.clock()
			end)
		end
	end
	instance:Track(sub(ClientState.equippedTool, watchTool))
	watchTool(peek(ClientState.equippedTool))
	instance:Track(function(): ()
		watchTool(nil)
	end)

	return instance
end

export type Legitbot = UniversalLegitbot.Legitbot

return Legitbot
