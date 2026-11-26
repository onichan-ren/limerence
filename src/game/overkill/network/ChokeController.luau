local CommandController = require("@game/overkill/weapon/CommandController")
local NetworkController = require("@game/overkill/network/NetworkController")
local WeaponController = require("@game/overkill/weapon/WeaponController")
local clientState = require("@game/overkill/client/clientState")
local hudState = require("@game/universal/feature/visual/hud/hudState")
local Charm = require("@pkg/Charm")

local peek = Charm.peek

local BTN_PRIMARY = 1
local ACTION_MASK = 509
local MAX_DEPTH = 6
local MOVE_EPS = 0.05
local KEEPALIVE = 30

type Request = {
	active: boolean,
	breakMode: string,
	maxDepth: number,
}

local ChokeController = {}

local requests: { [string]: Request } = {}
local activeCount = 0
local holdActive = false
local holdCount = 0
local stillCount = 0
local actionBroad = false
local actionFire = false
local moved = false
local prevPos: Vector3? = nil
local installed = false
local cmdUnregister: (() -> ())? = nil

local lastChoke = 0

local function publishChoke(count: number): ()
	if count == lastChoke then
		return
	end
	lastChoke = count
	if count == 0 then
		hudState.SetInfo("choke", nil)
	else
		hudState.SetInfo("choke", "choking: " .. count, 30)
	end
end

local function reset(): ()
	holdActive = false
	holdCount = 0
	stillCount = 0
	publishChoke(0)
end

local function install(): ()
	if installed then
		return
	end
	installed = true

	cmdUnregister = CommandController.Register(LPH_NO_VIRTUALIZE(function(command: any): ()
		if activeCount == 0 or type(command) ~= "table" then
			actionBroad = false
			actionFire = false
			moved = false
			prevPos = nil
			return
		end
		local buttons = command.buttons or 0
		actionBroad = bit32.band(buttons, ACTION_MASK) ~= 0 or (command.slot or 0) ~= 0
		actionFire = bit32.band(buttons, BTN_PRIMARY) ~= 0 or WeaponController._firing == true

		local root = peek(clientState.hrp)
		local pos = root and root.Position or nil
		if pos and prevPos then
			moved = (pos - prevPos).Magnitude > MOVE_EPS
		else
			moved = false
		end
		prevPos = pos
	end), 50)

	NetworkController.HookPacket(
		"chickynoid_command",
		LPH_NO_VIRTUALIZE(function(): (boolean?, any?)
			if activeCount == 0 then
				reset()
				return nil
			end

			local wantSend = false
			local minCap = MAX_DEPTH
			for _, request in next, requests do
				if not request.active then
					continue
				end
				if request.maxDepth < minCap then
					minCap = request.maxDepth
				end
				local mode = request.breakMode
				if (mode == "action" and actionBroad) or (mode == "fire" and actionFire) then
					wantSend = true
				end
			end

			if wantSend then
				reset()
				return nil
			end

			if moved or holdActive then
				if not holdActive then
					holdActive = true
					holdCount = 0
				end
				if holdCount >= minCap then
					reset()
					return nil
				end
				holdCount += 1
				publishChoke(holdCount)
				return false
			end

			if stillCount >= KEEPALIVE then
				stillCount = 0
				return nil
			end
			stillCount += 1
			return false
		end)
	)
end

function ChokeController.SetRequest(id: string, active: boolean, breakMode: string, maxDepth: number): ()
	install()
	local depth = math.clamp(maxDepth, 1, MAX_DEPTH)
	local request = requests[id]
	if not request then
		if not active then
			return
		end
		requests[id] = {
			active = true,
			breakMode = breakMode,
			maxDepth = depth,
		}
		activeCount += 1
		return
	end
	if request.active ~= active then
		request.active = active
		activeCount += active and 1 or -1
	end
	request.breakMode = breakMode
	request.maxDepth = depth
end

function ChokeController.ClearRequest(id: string): ()
	local request = requests[id]
	if not request then
		return
	end
	if request.active then
		activeCount -= 1
	end
	requests[id] = nil
end

function ChokeController.Destroy(): ()
	table.clear(requests)
	activeCount = 0
	reset()
	actionBroad = false
	actionFire = false
	moved = false
	prevPos = nil
	if cmdUnregister then
		cmdUnregister()
		cmdUnregister = nil
	end
	if installed then
		installed = false
		NetworkController.UnhookPacket("chickynoid_command")
	end
end

export type ChokeController = typeof(ChokeController)

return ChokeController
