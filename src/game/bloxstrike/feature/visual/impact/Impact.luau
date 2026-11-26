local UniversalImpact = require("@game/universal/feature/visual/impact/Impact")
local WeaponController = require("@game/bloxstrike/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local Workspace = cloneref(game:GetService("Workspace"))

local DEFAULT_LOCAL_COLOR = Color3.fromRGB(190, 186, 210)

local Impact = {}

function Impact.new(link: gameUi.Linker): UniversalImpact.Impact
	return UniversalImpact.new(link, {
		rootKey = "bulletImpacts",
		rootLabel = "Bullet Impacts",
		getIgnoreFolder = LPH_NO_VIRTUALIZE(function()
			return Workspace:FindFirstChild("Debris")
		end),
		sources = {
			{
				key = "localImpacts",
				label = "Local Impacts",
				defaultColor = DEFAULT_LOCAL_COLOR,
				body = "Draws impacts for your own shots.",
				connect = function(ctx: UniversalImpact.ImpactCtx)
					return WeaponController.bulletCreated:Connect(LPH_NO_VIRTUALIZE(function(bulletData: WeaponController.BulletData): ()
						local positions: { Vector3 } = {}
						for _, hit in bulletData.Hits do
							positions[#positions + 1] = hit.Position
						end
						ctx.spawn(positions)
					end))
				end,
			},
		},
	})
end

return Impact
