local UniversalTracer = require("@game/universal/feature/visual/tracer/Tracer")
local NetworkController = require("@game/pf/network/NetworkController")
local WeaponController = require("@game/pf/weapon/WeaponController")
local bulletSim = require("@game/pf/weapon/bulletSim")
local localThirdPerson = require("@game/pf/thirdperson/localThirdPerson")
local pathfind = require("@share/pathfind")
local Janitor = require("@pkg/Janitor")
local gameUi = require("@game/gameUi")

local Players = cloneref(game:GetService("Players")) :: Players

local LocalPlayer = Players.LocalPlayer

local ROUTE_THRESHOLD = 4

local routePather = pathfind.new({
	mode = "fly",
	gridSize = 2,
	maxRadius = 40,
	maxNodes = 400,
	agentHeight = 1,
	agentWidth = 1,
	yieldEvery = 32,
})

local function barrelPosition(): Vector3?
	local weapon = WeaponController.GetWeapon()
	if not weapon then
		return nil
	end
	local barrel = rawget(weapon, "_barrelPart")
	if typeof(barrel) == "Instance" and (barrel :: Instance):IsA("BasePart") then
		return (barrel :: BasePart).Position
	end
	return nil
end

local buildRoute = LPH_NO_VIRTUALIZE(function(barrelPos: Vector3, origin: Vector3, ignore: { Instance }): { Vector3 }
	local extra = table.clone(ignore)
	local character = LocalPlayer.Character
	if character then
		extra[#extra + 1] = character
	end
	local body = localThirdPerson.getCharacterModel()
	if body then
		extra[#extra + 1] = body
	end
	local weaponModel = localThirdPerson.getWeaponModel()
	if weaponModel then
		extra[#extra + 1] = weaponModel
	end
	local route = routePather:Compute(barrelPos, origin, extra)
	if route then
		local prefix = table.create(#route)
		for i = 1, #route do
			prefix[i] = route[i].position
		end
		return prefix
	end
	return { barrelPos }
end)

local DEFAULT_LOCAL_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 186, 210)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 108, 128)),
})

local DEFAULT_FRIENDLY_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(145, 200, 175)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(75, 130, 105)),
})

local DEFAULT_ENEMY_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 130, 130)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(165, 75, 75)),
})

local TRACER_TYPES = { "Line", "Beam", "Adorn" }

local function addTracerControls(
	optionsLink: gameUi.Linker,
	key: string,
	label: string,
	defaultColor: ColorSequence
): ()
	local toggle = optionsLink:Toggle(key, label, false):SetTip({
		title = label,
		body = (
			key == "localTracers" and "Draws tracers for your own shots."
			or key == "friendlyTracers" and "Draws tracers for teammates' shots."
			or "Draws tracers for enemy shots."
		),
	})
	local submenuKey = `{key}Options`
	optionsLink:Extra(toggle, submenuKey, "Submenu", `{label} Options`)
	local optsLink = optionsLink:OnKey(submenuKey)
	optsLink:Colorpicker("color", "Color", defaultColor, 0):SetTip({
		title = "Color",
		body = "Tracer color or gradient.",
	})
	optsLink:Dropdown("type", "Type", TRACER_TYPES, "Beam"):SetTip({
		title = "Type",
		body = "Beam uses a textured beam; Line uses a simple line segment.",
	})
	optsLink:Slider("thickness", "Thickness", 1, 1, 3, 1, nil, "px"):SetTip({
		title = "Thickness",
		body = "Line/beam width in pixels.",
	})
	optsLink:Slider("lifetime", "Lifetime", 2, 0.5, 5, 0.1, nil, "s"):SetTip({
		title = "Lifetime",
		body = "Seconds before the tracer starts fading out.",
	})
end

local Tracer = {}

function Tracer.new(link: gameUi.Linker): UniversalTracer.Tracer
	return UniversalTracer.new(link, {
		setup = function(self: UniversalTracer.Tracer, _link: gameUi.Linker, api: UniversalTracer.TracerApi): ()
			local localJanitor: Janitor.Janitor? = nil
			local remoteJanitor: Janitor.Janitor? = nil
			local friendlyEnabled = false
			local enemyEnabled = false

			link:Options("bulletTracers", "Bullet Tracers")
			local optionsLink = link:OnKey("bulletTracers")

			addTracerControls(optionsLink, "friendlyTracers", "Friendly Tracers", DEFAULT_FRIENDLY_COLOR)
			addTracerControls(optionsLink, "localTracers", "Local Tracers", DEFAULT_LOCAL_COLOR)
			addTracerControls(optionsLink, "enemyTracers", "Enemy Tracers", DEFAULT_ENEMY_COLOR)

			api.attachBeamPicker(optionsLink)

			local function settingsFor(submenuKey: string, fallback: ColorSequence): UniversalTracer.TracerSettings
				local optsLink = optionsLink:OnKey(submenuKey)
				return api.peekSettings(optsLink, optsLink, fallback)
			end

			self:Track(optionsLink:Get("localTracers"):OnChange(function(value: boolean): ()
				if value then
					if localJanitor then
						return
					end
					local janitor = Janitor.new()
					localJanitor = janitor
					local ignore = bulletSim.defaultIgnore()
					janitor:Add(
						NetworkController.HookOutbound(
							"newbullets",
							LPH_NO_VIRTUALIZE(function(_uniqueId: any, payload: any): boolean?
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
								local settings = settingsFor("localTracersOptions", DEFAULT_LOCAL_COLOR)
								local barrelPos = barrelPosition()
								if barrelPos and (barrelPos - origin).Magnitude > ROUTE_THRESHOLD then
									local speed = stats.speed
									local accel = stats.accel
									local penetration = stats.penetration
									task.spawn(function(): ()
										local prefix = buildRoute(barrelPos, origin, ignore)
										if localJanitor ~= janitor then
											return
										end
										for _, bullet in next, bullets do
											local dir = type(bullet) == "table" and bullet[1]
											if typeof(dir) == "Vector3" then
												local traj = bulletSim.simulate(
													origin,
													speed * dir,
													accel * dir + gravity,
													penetration,
													ignore
												)
												local points = table.clone(prefix)
												local trajPoints = traj.points
												local first = points[#points] == trajPoints[1] and 2 or 1
												for i = first, #trajPoints do
													points[#points + 1] = trajPoints[i]
												end
												if #points >= 2 then
													api.spawnCurve(points, settings, janitor)
												end
											end
										end
									end)
									return true
								end
								for _, bullet in next, bullets do
									local dir = type(bullet) == "table" and bullet[1]
									if typeof(dir) == "Vector3" then
										local velocity = stats.speed * dir
										local acceleration = stats.accel * dir + gravity
										local traj = bulletSim.simulate(
											origin,
											velocity,
											acceleration,
											stats.penetration,
											ignore
										)
										if #traj.points >= 2 then
											api.spawnCurve(traj.points, settings, janitor)
										end
									end
								end
								return true
							end)
						),
						true
					)
				elseif localJanitor then
					localJanitor:Destroy()
					localJanitor = nil
				end
			end))

			local function refreshRemote(): ()
				local needsRemote = friendlyEnabled or enemyEnabled
				if needsRemote and not remoteJanitor then
					local janitor = Janitor.new()
					remoteJanitor = janitor
					local ignore = bulletSim.defaultIgnore()
					janitor:Add(
						NetworkController.HookInbound(
							"newbullets",
							LPH_NO_VIRTUALIZE(function(payload: any): ()
								if type(payload) ~= "table" then
									return
								end
								local player = payload.player
								if typeof(player) ~= "Instance" or player == LocalPlayer then
									return
								end
								local origin = payload.firepos
								local bullets = payload.bullets
								if typeof(origin) ~= "Vector3" or type(bullets) ~= "table" then
									return
								end
								local isFriendly = (player :: Player).TeamColor == LocalPlayer.TeamColor
								if isFriendly and not friendlyEnabled then
									return
								end
								if not isFriendly and not enemyEnabled then
									return
								end
								local submenuKey = isFriendly and "friendlyTracersOptions" or "enemyTracersOptions"
								local fallback = isFriendly and DEFAULT_FRIENDLY_COLOR or DEFAULT_ENEMY_COLOR
								local settings = settingsFor(submenuKey, fallback)
								local penetration = WeaponController.GetPlayerPenetration(player, payload.index)
									or 0
								for _, bullet in next, bullets do
									local velocity = type(bullet) == "table" and bullet.velocity
									if typeof(velocity) == "Vector3" then
										local acceleration = type(bullet) == "table" and bullet.acceleration
										local accel = typeof(acceleration) == "Vector3" and acceleration
											or Vector3.zero
										local traj =
											bulletSim.simulate(origin, velocity, accel, penetration, ignore)
										if #traj.points >= 2 then
											api.spawnCurve(traj.points, settings, janitor)
										end
									end
								end
							end)
						),
						true
					)
				elseif not needsRemote and remoteJanitor then
					remoteJanitor:Destroy()
					remoteJanitor = nil
				end
			end

			self:Track(optionsLink:Get("friendlyTracers"):OnChange(function(value: boolean): ()
				friendlyEnabled = value == true
				refreshRemote()
			end))

			self:Track(optionsLink:Get("enemyTracers"):OnChange(function(value: boolean): ()
				enemyEnabled = value == true
				refreshRemote()
			end))

			self:Track(function(): ()
				if localJanitor then
					localJanitor:Destroy()
					localJanitor = nil
				end
				if remoteJanitor then
					remoteJanitor:Destroy()
					remoteJanitor = nil
				end
			end)
		end,
	})
end

return Tracer
