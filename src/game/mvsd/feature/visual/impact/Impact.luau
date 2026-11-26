local UniversalImpact = require("@game/universal/feature/visual/impact/Impact")
local WeaponController = require("@game/mvsd/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local DEFAULT_LOCAL_COLOR = Color3.fromRGB(190, 186, 210)
local DEFAULT_ENEMY_COLOR = Color3.fromRGB(220, 130, 130)

local Impact = {}

function Impact.new(link: gameUi.Linker): UniversalImpact.Impact
	return UniversalImpact.new(link, {
		rootKey = "bulletImpacts",
		rootLabel = "Bullet Impacts",
		sources = {
			{
				key = "localImpacts",
				label = "Local Impacts",
				defaultColor = DEFAULT_LOCAL_COLOR,
				body = "Draws impacts for your own shots.",
				connect = function(ctx: UniversalImpact.ImpactCtx)
					return WeaponController.shotFired:Connect(
						LPH_NO_VIRTUALIZE(function(_origin: Vector3, position: Vector3): ()
							ctx.spawn({ position })
						end)
					)
				end,
			},
			{
				key = "enemyImpacts",
				label = "Enemy Impacts",
				defaultColor = DEFAULT_ENEMY_COLOR,
				body = "Draws impacts for shots fired by other players.",
				connect = function(ctx: UniversalImpact.ImpactCtx)
					return WeaponController.observedShot:Connect(
						LPH_NO_VIRTUALIZE(function(_player: Player, _origin: Vector3, position: Vector3): ()
							ctx.spawn({ position })
						end)
					)
				end,
			},
		},
	})
end

return Impact
