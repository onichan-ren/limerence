local Charm = require("@pkg/Charm")
local PlayerController = require("@feature/player/PlayerController")
local shroudObserver = require("@game/mvsd/feature/visual/world/shroudObserver")

local peek = Charm.peek

local SHROUD_COOLDOWN = 9.5
local SHROUD_RADIUS = 14

local unsub: (() -> ())? = nil

local function attribute(model: Model): ()
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not part then
		return
	end

	local origin = part.Position
	local nearest: any = nil
	local bestSq = SHROUD_RADIUS * SHROUD_RADIUS
	for _, basePlayer in next, PlayerController.GetAll() do
		local hrp = peek((basePlayer :: any).hrp) :: BasePart?
		if hrp then
			local delta = hrp.Position - origin
			local sq = delta:Dot(delta)
			if sq < bestSq then
				bestSq = sq
				nearest = basePlayer
			end
		end
	end

	if nearest and nearest.StartAbilityCooldown then
		nearest:StartAbilityCooldown("Shroud", SHROUD_COOLDOWN)
	end
end

local shroudCooldownTracker = {}

function shroudCooldownTracker.start(): ()
	if unsub then
		return
	end
	unsub = shroudObserver.subscribe(attribute)
end

function shroudCooldownTracker.stop(): ()
	if unsub then
		unsub()
		unsub = nil
	end
end

return shroudCooldownTracker
