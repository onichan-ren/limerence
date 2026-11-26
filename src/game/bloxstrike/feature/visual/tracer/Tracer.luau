local UniversalTracer = require("@game/universal/feature/visual/tracer/Tracer")
local ViewmodelController = require("@game/bloxstrike/viewmodel/ViewmodelController")
local WeaponController = require("@game/bloxstrike/weapon/WeaponController")
local PlayerController = require("@feature/player/PlayerController")
local ClientController = require("@game/bloxstrike/client/ClientController")
local Janitor = require("@pkg/Janitor")
local gameUi = require("@game/gameUi")

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

local MISS_TRACER_RANGE = 5000

local getEndPosition = LPH_NO_VIRTUALIZE(function(bulletData: WeaponController.BulletData): Vector3?
	local endPosition: Vector3? = nil
	local furthest = 0
	for _, hit in next, bulletData.Hits do
		local d = hit.Distance
		if d > furthest then
			furthest = d
			endPosition = hit.Position
		end
	end
	if endPosition then
		return endPosition
	end
	local dir = bulletData.Direction
	if dir.Magnitude < 1e-4 then
		return nil
	end
	return bulletData.Origin + dir.Unit * MISS_TRACER_RANGE
end)

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
			or key == "friendlyTracers" and "Draws tracers for teammates' shots you observe."
			or "Draws tracers for enemy shots you observe."
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

			local function enableLocal(): ()
				if localJanitor then
					return
				end
				local janitor = Janitor.new()
				localJanitor = janitor
				janitor:Add(
					WeaponController.bulletCreated:Connect(LPH_NO_VIRTUALIZE(function(bulletData: WeaponController.BulletData): ()
						local endPosition = getEndPosition(bulletData)
						if not endPosition then
							return
						end
						local muzzle = ViewmodelController.GetMuzzlePart()
						local muzzlePos = muzzle and muzzle.CFrame.Position
						local origin = bulletData.Origin or muzzlePos
						if origin and muzzlePos and (origin - muzzlePos).Magnitude < 8 then
							origin = muzzlePos
						end
						api.spawnSegment(
							origin,
							endPosition,
							settingsFor("localTracersOptions", DEFAULT_LOCAL_COLOR),
							janitor
						)
					end)),
					"Disconnect"
				)
			end

			local function disableLocal(): ()
				if localJanitor then
					localJanitor:Destroy()
					localJanitor = nil
				end
			end

			self:Track(optionsLink:Get("localTracers"):OnChange(function(value: boolean): ()
				if value then
					enableLocal()
				else
					disableLocal()
				end
			end))

			local function refreshRemote(): ()
				local needsRemote = friendlyEnabled or enemyEnabled
				if needsRemote and not remoteJanitor then
					local janitor = Janitor.new()
					remoteJanitor = janitor
					janitor:Add(
						WeaponController.observedShot:Connect(
							LPH_NO_VIRTUALIZE(function(player: Player, origin: Vector3, target: Vector3): ()
								local data = PlayerController.Get(player)
								if not data then
									return
								end
								local isFriendly = data:GetTeam() == ClientController.GetTeam()
								if isFriendly then
									if not friendlyEnabled then
										return
									end
									api.spawnSegment(
										origin,
										target,
										settingsFor("friendlyTracersOptions", DEFAULT_FRIENDLY_COLOR),
										janitor
									)
								else
									if not enemyEnabled then
										return
									end
									api.spawnSegment(
										origin,
										target,
										settingsFor("enemyTracersOptions", DEFAULT_ENEMY_COLOR),
										janitor
									)
								end
							end)
						),
						"Disconnect"
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

			if optionsLink:Peek("localTracers") then
				enableLocal()
			end

			friendlyEnabled = optionsLink:Peek("friendlyTracers") == true
			enemyEnabled = optionsLink:Peek("enemyTracers") == true
			refreshRemote()

			self:Track(function(): ()
				disableLocal()
				if remoteJanitor then
					remoteJanitor:Destroy()
					remoteJanitor = nil
				end
			end)
		end,
	})
end

return Tracer
