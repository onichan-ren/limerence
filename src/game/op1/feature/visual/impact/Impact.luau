local UniversalImpact = require("@game/universal/feature/visual/impact/Impact")
local WeaponController = require("@game/op1/weapon/WeaponController")
local gameUi = require("@game/gameUi")

local Workspace = cloneref(game:GetService("Workspace"))

local DEFAULT_LOCAL_COLOR = Color3.fromRGB(190, 186, 210)
local DEFAULT_ENEMY_COLOR = Color3.fromRGB(220, 130, 130)

local function collectPositions(pellets: { any }): { Vector3 }
	local positions: { Vector3 } = {}

	for _, pellet in next, pellets do
		if type(pellet) == "table" then
			for _, hit in next, pellet do
				local position = type(hit) == "table" and hit.Position
				if typeof(position) == "Vector3" then
					positions[#positions + 1] = position
				end
			end
		end
	end

	return positions
end

local function source(key: string, label: string, color: Color3, body: string, wantRelation: string): UniversalImpact.ImpactSource
	return {
		key = key,
		label = label,
		defaultColor = color,
		body = body,
		connect = function(ctx: UniversalImpact.ImpactCtx)
			return WeaponController.shotFired:Connect(LPH_NO_VIRTUALIZE(function(_origin: Vector3, pellets: { any }, relation: string): ()
				if relation ~= wantRelation then
					return
				end

				local positions = collectPositions(pellets)
				if #positions > 0 then
					ctx.spawn(positions)
				end
			end))
		end,
	}
end

local Impact = {}

function Impact.new(link: gameUi.Linker): UniversalImpact.Impact
	return UniversalImpact.new(link, {
		rootKey = "bulletImpacts",
		rootLabel = "Bullet Impacts",
		getIgnoreFolder = LPH_NO_VIRTUALIZE(function()
			return Workspace:FindFirstChild("Effects") or Workspace
		end),
		sources = {
			source("localImpacts", "Local Impacts", DEFAULT_LOCAL_COLOR, "Draws impacts for your own shots.", "local"),
			source("enemyImpacts", "Enemy Impacts", DEFAULT_ENEMY_COLOR, "Draws impacts for enemy shots.", "enemy"),
		},
	})
end

return Impact
