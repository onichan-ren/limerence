local UniversalImpact = require("@game/universal/feature/visual/impact/Impact")
local NetworkController = require("@game/pf/network/NetworkController")
local WeaponController = require("@game/pf/weapon/WeaponController")
local bulletSim = require("@game/pf/weapon/bulletSim")
local gameUi = require("@game/gameUi")

local Players = cloneref(game:GetService("Players")) :: Players
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local LocalPlayer = Players.LocalPlayer

local DEFAULT_LOCAL_COLOR = Color3.fromRGB(190, 186, 210)
local DEFAULT_ENEMY_COLOR = Color3.fromRGB(220, 130, 130)

local Impact = {}

function Impact.new(link: gameUi.Linker): UniversalImpact.Impact
	return UniversalImpact.new(link, {
		rootKey = "bulletImpacts",
		rootLabel = "Bullet Impacts",
		getIgnoreFolder = LPH_NO_VIRTUALIZE(function()
			return Workspace:FindFirstChild("Debris") or Workspace
		end),
		sources = {
			{
				key = "localImpacts",
				label = "Local Impacts",
				defaultColor = DEFAULT_LOCAL_COLOR,
				body = "Draws impacts for your own shots.",
				connect = function(ctx: UniversalImpact.ImpactCtx)
					local ignore = bulletSim.defaultIgnore()
					local unhook = NetworkController.HookOutbound("newbullets", LPH_NO_VIRTUALIZE(function(_uniqueId: any, payload: any): (boolean?)
						if type(payload) ~= "table" then
							return true
						end
						local origin = payload.firepos
						local bullets = payload.bullets
						if typeof(origin) ~= "Vector3" or type(bullets) ~= "table" then
							return true
						end
						local stats = WeaponController.GetLocalFireStats()
						if not stats then
							return true
						end
						local gravity = WeaponController.GetGravity()
						local positions: { Vector3 } = {}
						for _, bullet in next, bullets do
							local dir = type(bullet) == "table" and bullet[1]
							if typeof(dir) == "Vector3" then
								local velocity = stats.speed * dir
								local acceleration = stats.accel * dir + gravity
								local traj = bulletSim.simulate(origin, velocity, acceleration, stats.penetration, ignore)
								for _, position in next, traj.impacts do
									positions[#positions + 1] = position
								end
							end
						end
						if #positions > 0 then
							ctx.spawn(positions)
						end
						return true
					end))
					return { Disconnect = unhook }
				end,
			},
			{
				key = "enemyImpacts",
				label = "Enemy Impacts",
				defaultColor = DEFAULT_ENEMY_COLOR,
				body = "Draws impacts for enemy shots.",
				connect = function(ctx: UniversalImpact.ImpactCtx)
					local ignore = bulletSim.defaultIgnore()
					local unhook = NetworkController.HookInbound("newbullets", LPH_NO_VIRTUALIZE(function(payload: any): ()
						if type(payload) ~= "table" then
							return
						end
						local player = payload.player
						if typeof(player) ~= "Instance" or player == LocalPlayer then
							return
						end
						if player.TeamColor == LocalPlayer.TeamColor then
							return
						end
						local origin = payload.firepos
						local bullets = payload.bullets
						if typeof(origin) ~= "Vector3" or type(bullets) ~= "table" then
							return
						end
						local penetration = WeaponController.GetPlayerPenetration(player, payload.index) or 0
						local positions: { Vector3 } = {}
						for _, bullet in next, bullets do
							local velocity = type(bullet) == "table" and bullet.velocity
							if typeof(velocity) == "Vector3" then
								local acceleration = type(bullet) == "table" and bullet.acceleration
								local accel = typeof(acceleration) == "Vector3" and acceleration or Vector3.zero
								local traj = bulletSim.simulate(origin, velocity, accel, penetration, ignore)
								for _, position in next, traj.impacts do
									positions[#positions + 1] = position
								end
							end
						end
						if #positions > 0 then
							ctx.spawn(positions)
						end
					end))
					return { Disconnect = unhook }
				end,
			},
		},
	})
end

return Impact
