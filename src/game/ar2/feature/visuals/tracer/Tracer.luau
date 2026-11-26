local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local gameUi = require("@game/gameUi")
local UniversalTracer = require("@game/universal/feature/visual/tracer/Tracer")
local WeaponController = require("@game/ar2/weapon/WeaponController")
local ModuleController = require("@game/ar2/module/ModuleController")
local ClientState = require("@game/ar2/client/clientState")
local tracerTrajectory = require("@game/ar2/weapon/tracerTrajectory")
local playerState = require("@feature/record/module/playerState")

local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local peek = Charm.peek

local DEFAULT_LOCAL_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 186, 210)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 108, 128)),
})

local DEFAULT_ENEMY_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(245, 105, 105)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(155, 55, 70)),
})

local TRACER_TYPES = { "Beam", "Line", "Adorn" }

local _globals

local function getGlobals()
	if not _globals then
		local globals = ModuleController.GetModule("Globals")
		_globals = globals and globals.module
	end
	return _globals
end

local Tracer = {}

function Tracer.new(link: gameUi.Linker): UniversalTracer.Tracer
	return UniversalTracer.new(link, {
		setup = function(self: UniversalTracer.Tracer, _link: gameUi.Linker, api: UniversalTracer.TracerApi): ()
			local localJanitor: Janitor.Janitor? = nil
			local enemyJanitor: Janitor.Janitor? = nil

			link:Options("bulletTracers", "Bullet Tracers")
			local optionsLink = link:OnKey("bulletTracers")

			local localToggle = optionsLink:Toggle("tracers", "Local Tracers", false):SetTip({
				title = "Local Tracers",
				body = "Draws a tracer from your muzzle to where each shot lands.",
			})
			optionsLink:Extra(localToggle, "tracersOptions", "Submenu", "Local Tracer Options")
			local localOpts = optionsLink:OnKey("tracersOptions")
			localOpts:Colorpicker("color", "Color", DEFAULT_LOCAL_COLOR, 0):SetTip({
				title = "Color",
				body = "Tracer color or gradient.",
			})
			localOpts:Dropdown("type", "Type", TRACER_TYPES, "Beam"):SetTip({
				title = "Type",
				body = "Beam uses a textured beam; Line uses a simple line segment.",
			})
			localOpts:Toggle("curved", "Curved", true):SetTip({
				title = "Curved",
				body = "Follows the shot's bullet drop instead of a straight line.",
			})
			localOpts:Slider("thickness", "Thickness", 1, 1, 3, 1, nil, "px"):SetTip({
				title = "Thickness",
				body = "Line/beam width in pixels.",
			})
			localOpts:Slider("lifetime", "Lifetime", 2, 0.5, 5, 0.1, nil, "s"):SetTip({
				title = "Lifetime",
				body = "Seconds before the tracer starts fading out.",
			})

			local enemyToggle = optionsLink:Toggle("enemyTracers", "Enemy Tracers", false):SetTip({
				title = "Enemy Tracers",
				body = "Draws the paths of nearby enemy shots.",
			})
			optionsLink:Extra(enemyToggle, "enemyTracersOptions", "Submenu", "Enemy Tracer Options")
			local enemyOpts = optionsLink:OnKey("enemyTracersOptions")
			enemyOpts:Colorpicker("color", "Color", DEFAULT_ENEMY_COLOR, 0):SetTip({
				title = "Color",
				body = "Tracer color or gradient.",
			})
			enemyOpts:Dropdown("type", "Type", TRACER_TYPES, "Line"):SetTip({
				title = "Type",
				body = "Beam uses a textured beam; Line uses a simple line segment.",
			})
			enemyOpts:Toggle("curved", "Curved", true):SetTip({
				title = "Curved",
				body = "Follows each shot's bullet drop instead of a straight line.",
			})
			enemyOpts:Slider("distance", "Tracer Distance", 500, 100, 1500, 50, nil, "st"):SetTip({
				title = "Tracer Distance",
				body = "How long each drawn shot path is.",
			})
			enemyOpts:Slider("thickness", "Thickness", 1, 1, 3, 1, nil, "px"):SetTip({
				title = "Thickness",
				body = "Line/beam width in pixels.",
			})
			enemyOpts:Slider("lifetime", "Lifetime", 2, 0.5, 5, 0.1, nil, "s"):SetTip({
				title = "Lifetime",
				body = "Seconds before the tracer starts fading out.",
			})

			optionsLink:Toggle("friendlyTracers", "Friendly Tracers", false):SetTip({
				title = "Friendly Tracers",
				body = "Draws the paths of nearby teammate shots, using the enemy tracer settings.",
			})

			api.attachBeamPicker(optionsLink)

			local function spawnLocal(origin: Vector3, position: Vector3, janitor: Janitor.Janitor): ()
				local settings = api.peekSettings(localOpts, localOpts, DEFAULT_LOCAL_COLOR)

				if localOpts:Peek("curved") then
					local globals = getGlobals()
					local weapon = WeaponController.GetEquippedWeapon()
					local muzzleVelocity = weapon and weapon.FireConfig and weapon.FireConfig.MuzzleVelocity
					local direction = position - origin

					if globals and muzzleVelocity and direction.Magnitude > 1e-4 then
						local speed = muzzleVelocity * (globals.MuzzleVelocityMod or 1)
						if speed > 1 then
							local points = tracerTrajectory.compute(
								origin,
								direction.Unit,
								speed,
								globals.ProjectileGravity or 0,
								peek(ClientState.character)
							)
							if #points >= 2 then
								api.spawnCurve(points, settings, janitor)
								return
							end
						end
					end
				end

				api.spawnSegment(origin, position, settings, janitor)
			end

			local function enableLocal(): ()
				if localJanitor then
					return
				end
				local janitor = Janitor.new()
				localJanitor = janitor

				janitor:Add(
					WeaponController.pelletFired:Connect(LPH_NO_VIRTUALIZE(function(_itemId, origin, position): ()
						spawnLocal(origin, position, janitor)
					end)),
					"Disconnect"
				)
			end

			local function disableLocal(): ()
				if not localJanitor then
					return
				end
				localJanitor:Destroy()
				localJanitor = nil
			end

			local function enableEnemy(): ()
				if enemyJanitor then
					return
				end
				local janitor = Janitor.new()
				enemyJanitor = janitor

				janitor:Add(
					WeaponController.enemyPelletFired:Connect(
						LPH_NO_VIRTUALIZE(function(player: Player, itemName: string, origin: Vector3, direction: Vector3): ()
							local isFriendly = playerState.GetState(player.UserId) == "friendly"
							if isFriendly then
								if not optionsLink:Peek("friendlyTracers") then
									return
								end
							elseif not optionsLink:Peek("enemyTracers") then
								return
							end

							local camera = Workspace.CurrentCamera
							if camera and (origin - camera.CFrame.Position).Magnitude > 1500 then
								return
							end

							local distance = tonumber(enemyOpts:Peek("distance")) or 500
							local itemData = ModuleController.GetItemData()
							local weapon = itemData and itemData[itemName]
							local fireConfig = weapon and weapon.FireConfig
							local muzzleVelocity = fireConfig and fireConfig.MuzzleVelocity
							local globals = getGlobals()
							local settings = api.peekSettings(enemyOpts, enemyOpts, DEFAULT_ENEMY_COLOR)

							if muzzleVelocity and globals and direction.Magnitude > 1e-4 then
								local speed = muzzleVelocity * (globals.MuzzleVelocityMod or 1)
								local points = tracerTrajectory.compute(
									origin,
									direction.Unit,
									speed,
									globals.ProjectileGravity or 0,
									player.Character,
									distance
								)
								if enemyOpts:Peek("curved") and #points >= 2 then
									api.spawnCurve(points, settings, janitor)
								elseif #points >= 2 then
									api.spawnSegment(points[1], points[#points], settings, janitor)
								end
							elseif direction.Magnitude > 1e-4 then
								api.spawnSegment(origin, origin + direction.Unit * distance, settings, janitor)
							end
						end)
					),
					"Disconnect"
				)
			end

			local function disableEnemy(): ()
				if not enemyJanitor then
					return
				end
				enemyJanitor:Destroy()
				enemyJanitor = nil
			end

			local function syncEnemy(): ()
				if optionsLink:Peek("enemyTracers") or optionsLink:Peek("friendlyTracers") then
					enableEnemy()
				else
					disableEnemy()
				end
			end

			self:Track(optionsLink:Get("tracers"):OnChange(function(value: boolean): ()
				if value then
					enableLocal()
				else
					disableLocal()
				end
			end))

			self:Track(optionsLink:Get("enemyTracers"):OnChange(syncEnemy))
			self:Track(optionsLink:Get("friendlyTracers"):OnChange(syncEnemy))

			if optionsLink:Peek("tracers") then
				enableLocal()
			end
			syncEnemy()

			self:Track(function(): ()
				disableLocal()
				disableEnemy()
			end)
		end,
	})
end

return Tracer
