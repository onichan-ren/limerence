local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService
local HttpService = cloneref(game:GetService("HttpService")) :: HttpService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")

local bombState = require("@game/bloxstrike/bomb/bombState")
local clientState = require("@game/bloxstrike/client/clientState")
local NetworkController = require("@game/bloxstrike/network/NetworkController")
local PlayerController = require("@feature/player/PlayerController")
local stateConverter = require("@src/feature/config/module/stateConverter")

local peek = Charm.peek
local sub = Charm.subscribe

local PLANT_DURATION = 3.2
local LEAVE_DURATION = 0.4

type PlanterEntry = { startedAt: number, site: string?, duration: number }

local BombController = {
	_janitor = Janitor.new() :: Janitor.Janitor,
	_modelJanitor = Janitor.new() :: Janitor.Janitor,
	_leaveThread = nil :: thread?,
	_playerJanitors = {} :: { [Player]: Janitor.Janitor },
	_planters = {} :: { [Player]: PlanterEntry },
	_localPlanter = nil :: PlanterEntry?,
}

local function decodeBombData(model: Model): (number, number)
	local raw = model:GetAttribute("BombPlanted")
	local startedAt = Workspace:GetServerTimeNow()
	local duration = 40
	if type(raw) == "string" then
		local decoded = HttpService:JSONDecode(raw)
		if type(decoded) == "table" then
			if type(decoded.Time) == "number" then
				startedAt = decoded.Time
			end
			if type(decoded.TimeUntilExplode) == "number" then
				duration = math.max(decoded.TimeUntilExplode, 0.1)
			end
		end
	end
	return startedAt, duration
end

local function findSiteForPosition(position: Vector3): string?
	local bestSite: string? = nil
	local bestDistance = math.huge
	for _, part: any in next, CollectionService:GetTagged("PlantArea") do
		if part:IsA("BasePart") then
			local site = part:GetAttribute("Site")
			if site == "A" or site == "B" then
				local distance = (part.Position - position).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					bestSite = site :: string
				end
			end
		end
	end
	return bestSite
end

function BombController._patchBomb(patch: { [string]: any }): ()
	local cur = peek(bombState.bomb)
	if not cur then
		return
	end
	local nextState = table.clone(cur :: any) :: any
	for k, v in next, patch do
		nextState[k] = v
	end
	bombState.bomb(nextState)
end

function BombController._clearBomb(): ()
	if BombController._leaveThread then
		task.cancel(BombController._leaveThread)
		BombController._leaveThread = nil
	end
	BombController._modelJanitor:Cleanup()
	bombState.bomb(nil)
	bombState.leaving(false)
end

function BombController._startLeave(): ()
	if peek(bombState.leaving) then
		return
	end
	bombState.leaving(true)
	if BombController._leaveThread then
		task.cancel(BombController._leaveThread)
	end
	BombController._leaveThread = task.delay(LEAVE_DURATION, function()
		BombController._leaveThread = nil
		BombController._clearBomb()
	end)
end

function BombController._attachBomb(model: Model): ()
	BombController._clearBomb()

	local startedAt, duration = decodeBombData(model)
	bombState.bomb({
		model = model,
		startedAt = startedAt,
		duration = duration,
		explodeAt = startedAt + duration,
		isDefusing = model:GetAttribute("IsGettingDefused") == true,
		isDefused = model:GetAttribute("Defused") == true,
		isExploded = model:GetAttribute("Exploded") == true,
	})
	bombState.leaving(false)
	BombController._localPlanter = nil
	table.clear(BombController._planters)
	bombState.planting(nil)

	BombController._modelJanitor:Add(
		model:GetAttributeChangedSignal("IsGettingDefused"):Connect(function()
			BombController._patchBomb({ isDefusing = model:GetAttribute("IsGettingDefused") == true })
		end),
		"Disconnect"
	)
	BombController._modelJanitor:Add(
		model:GetAttributeChangedSignal("Defused"):Connect(function()
			local defused = model:GetAttribute("Defused") == true
			BombController._patchBomb({ isDefused = defused })
			if defused then
				BombController._startLeave()
			end
		end),
		"Disconnect"
	)
	BombController._modelJanitor:Add(
		model:GetAttributeChangedSignal("Exploded"):Connect(function()
			BombController._patchBomb({ isExploded = model:GetAttribute("Exploded") == true })
		end),
		"Disconnect"
	)
	BombController._modelJanitor:Add(
		model.AncestryChanged:Connect(function(_, newParent: Instance?): ()
			if newParent == nil then
				BombController._startLeave()
			end
		end),
		"Disconnect"
	)
end

function BombController._publishPlanting(): ()
	local mostRecent: PlanterEntry? = BombController._localPlanter
	for _, entry in next, BombController._planters do
		if not mostRecent or entry.startedAt > mostRecent.startedAt then
			mostRecent = entry
		end
	end
	if mostRecent then
		bombState.planting({
			site = mostRecent.site,
			startedAt = mostRecent.startedAt,
			duration = mostRecent.duration,
		})
	else
		bombState.planting(nil)
	end
end

function BombController._startLocalPlanting(): ()
	local parts = peek(clientState.parts)
	local hrp = parts.HumanoidRootPart :: any
	local position = hrp and hrp.Position or Vector3.zero
	BombController._localPlanter = {
		site = findSiteForPosition(position),
		startedAt = os.clock(),
		duration = PLANT_DURATION,
	}
	BombController._publishPlanting()
end

function BombController._endLocalPlanting(): ()
	BombController._localPlanter = nil
	BombController._publishPlanting()
end

function BombController._startPlayerPlanting(basePlayer: any): ()
	local player = basePlayer:GetPlayer() :: Player
	local hrp = peek(basePlayer.hrp) :: BasePart?
	local position = (hrp and hrp.Position) or Vector3.zero
	BombController._planters[player] = {
		site = findSiteForPosition(position),
		startedAt = os.clock(),
		duration = PLANT_DURATION,
	}
	BombController._publishPlanting()
end

function BombController._endPlayerPlanting(basePlayer: any): ()
	local player = basePlayer:GetPlayer() :: Player
	BombController._planters[player] = nil
	BombController._publishPlanting()
end

function BombController._watchPlayer(basePlayer: any): ()
	if not basePlayer or not basePlayer.isPlanting then
		return
	end
	local player = basePlayer:GetPlayer() :: Player

	local existing = BombController._playerJanitors[player]
	if existing then
		existing:Destroy()
	end

	local janitor = Janitor.new()
	BombController._playerJanitors[player] = janitor

	janitor:Add(sub(basePlayer.isPlanting, function(planting: boolean): ()
		if planting then
			BombController._startPlayerPlanting(basePlayer)
		else
			BombController._endPlayerPlanting(basePlayer)
		end
	end))

	janitor:Add(function(): ()
		BombController._planters[player] = nil
		BombController._publishPlanting()
	end, true)

	if peek(basePlayer.isPlanting) then
		BombController._startPlayerPlanting(basePlayer)
	end
end

function BombController._unwatchPlayer(basePlayer: any): ()
	local player = basePlayer:GetPlayer() :: Player
	local janitor = BombController._playerJanitors[player]
	if janitor then
		janitor:Destroy()
		BombController._playerJanitors[player] = nil
	end
end

function BombController.new(): typeof(BombController)
	BombController._janitor:Add(
		CollectionService:GetInstanceAddedSignal("Bomb"):Connect(function(inst: Instance): ()
			if inst.ClassName == "Model" then
				BombController._attachBomb(inst :: Model)
			end
		end),
		"Disconnect"
	)
	BombController._janitor:Add(
		CollectionService:GetInstanceRemovedSignal("Bomb"):Connect(function(inst: Instance): ()
			local cur = peek(bombState.bomb)
			if cur and cur.model == inst then
				BombController._startLeave()
			end
		end),
		"Disconnect"
	)

	BombController._janitor:Add(
		sub(clientState.alive, function(alive: boolean): ()
			if not alive then
				BombController._endLocalPlanting()
			end
		end)
	)

	for _, inst in next, CollectionService:GetTagged("Bomb") do
		if inst.ClassName == "Model" then
			BombController._attachBomb(inst :: Model)
			break
		end
	end

	NetworkController.HookPacket("C4", "Start", function(_)
		BombController._startLocalPlanting()
		return true
	end)
	NetworkController.HookPacket("C4", "Cancel", function(_)
		BombController._endLocalPlanting()
		return true
	end)
	NetworkController.HookPacket("C4", "Planted", function(_)
		BombController._endLocalPlanting()
		return true
	end)

	for _, basePlayer in next, PlayerController.GetAll() do
		BombController._watchPlayer(basePlayer)
	end

	BombController._janitor:Add(
		PlayerController.playerAdded:Connect(function(basePlayer: any): ()
			BombController._watchPlayer(basePlayer)
		end),
		"Disconnect"
	)
	BombController._janitor:Add(
		PlayerController.playerRemoving:Connect(function(basePlayer: any): ()
			BombController._unwatchPlayer(basePlayer)
		end),
		"Disconnect"
	)

	stateConverter.RegisterExtension(
		"limerence.bombHud",
		function(): any
			local pos = peek(bombState.hudPosition)
			return {
				position = {
					xs = pos.X.Scale,
					xo = pos.X.Offset,
					ys = pos.Y.Scale,
					yo = pos.Y.Offset,
				},
			}
		end,
		function(data: any): ()
			if type(data) ~= "table" then
				return
			end
			local pos = data.position
			if type(pos) ~= "table" then
				return
			end
			bombState.hudPosition(
				UDim2.new(
					tonumber(pos.xs) or 0,
					tonumber(pos.xo) or 0,
					tonumber(pos.ys) or 0,
					tonumber(pos.yo) or 0
				)
			)
		end
	)

	return BombController
end

function BombController.Destroy(): ()
	for _, janitor in next, BombController._playerJanitors do
		janitor:Destroy()
	end
	BombController._playerJanitors = {}
	table.clear(BombController._planters)
	BombController._localPlanter = nil

	BombController._janitor:Cleanup()
	BombController._modelJanitor:Cleanup()
	if BombController._leaveThread then
		task.cancel(BombController._leaveThread)
		BombController._leaveThread = nil
	end
	bombState.bomb(nil)
	bombState.leaving(false)
	bombState.planting(nil)

	NetworkController.UnhookPacket("C4", "Start")
	NetworkController.UnhookPacket("C4", "Cancel")
	NetworkController.UnhookPacket("C4", "Planted")

	stateConverter.UnregisterExtension("limerence.bombHud")
end

export type BombController = typeof(BombController)

return BombController
