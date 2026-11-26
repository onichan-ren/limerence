local UniversalDamageNumber3d = require("@game/universal/feature/visual/damagenumber3d/DamageNumber3d")
local WeaponController = require("@game/overkill/weapon/WeaponController")
local hudSuppressor = require("@game/overkill/feature/visual/removals/hudSuppressor")
local gameUi = require("@game/gameUi")

local HIT_DEDUPE = 0.05

local DamageNumber3d = {}

function DamageNumber3d.new(link: gameUi.Linker): UniversalDamageNumber3d.DamageNumber3d
	return UniversalDamageNumber3d.new(link, {
		body = "Floats the damage you deal above the spot you hit. Replaces the game's damage numbers.",
		connect = function(emit: (position: Vector3, amount: number, headshot: boolean) -> ())
			hudSuppressor.Acquire("Text")
			local lastHit: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
			local connection = WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player, _part: Instance, _partName: string, position: Vector3, damage: number, headshot: boolean): ()
				if damage <= 0 then
					return
				end
				local now = os.clock()
				local last = lastHit[player]
				if last and now - last < HIT_DEDUPE then
					return
				end
				lastHit[player] = now
				emit(position, math.floor(damage + 0.5), headshot)
			end))
			return function()
				hudSuppressor.Release("Text")
				connection:Disconnect()
			end
		end,
	})
end

return DamageNumber3d
