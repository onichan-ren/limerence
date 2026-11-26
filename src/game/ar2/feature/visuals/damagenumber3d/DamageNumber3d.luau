local UniversalDamageNumber3d = require("@game/universal/feature/visual/damagenumber3d/DamageNumber3d")
local WeaponController = require("@game/ar2/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local HIT_DEDUPE = 0.05

local DamageNumber3d = {}

function DamageNumber3d.new(link: gameUi.Linker): UniversalDamageNumber3d.DamageNumber3d
	return UniversalDamageNumber3d.new(link, {
		connect = function(emit: (position: Vector3, amount: number, headshot: boolean) -> ())
			local lastHit: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
			local connection = WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player, hitPart: Instance, hitPosition: Vector3, damage: number): ()
				if typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart") then
					return
				end
				if type(damage) ~= "number" or damage <= 0 then
					return
				end
				local now = os.clock()
				local last = lastHit[player]
				if last and now - last < HIT_DEDUPE then
					return
				end
				lastHit[player] = now
				emit(hitPosition, math.floor(damage + 0.5), hitPart.Name:find("Head") and true or false)
			end))
			return function()
				connection:Disconnect()
			end
		end,
	})
end

return DamageNumber3d
