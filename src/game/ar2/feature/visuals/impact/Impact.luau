local UniversalImpact = require("@game/universal/feature/visual/impact/Impact")
local WeaponController = require("@game/ar2/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local DEFAULT_LOCAL_COLOR = Color3.fromRGB(190, 186, 210)

local Workspace = cloneref(game:GetService("Workspace"))
local effects = Workspace:FindFirstChild("Effects")

local Impact = {}

function Impact.new(link: gameUi.Linker): UniversalImpact.Impact
	return UniversalImpact.new(link, {
		rootKey = "bulletImpacts",
		rootLabel = "Bullet Impacts",
		getIgnoreFolder = LPH_NO_VIRTUALIZE(function()
			return effects
		end),
		sources = {
			{
				key = "localImpacts",
				label = "Local Impacts",
				defaultColor = DEFAULT_LOCAL_COLOR,
				body = "Draws impacts for your own shots.",
				connect = function(ctx: UniversalImpact.ImpactCtx)
					return WeaponController.onImpact:Connect(
						function(hitPart: BasePart, hitPosition: Vector3, isLocal: boolean): ()
							if isLocal then
								ctx.spawn({ hitPosition })
							end
						end
					)
				end,
			},
		},
	})
end

return Impact
