local UniversalTracer = require("@game/universal/feature/visual/tracer/Tracer")
local WeaponController = require("@game/mvsd/weapon/WeaponController")
local PlayerController = require("@feature/player/PlayerController")
local ClientController = require("@game/mvsd/client/ClientController")
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

			self:Track(optionsLink:Get("localTracers"):OnChange(function(value: boolean): ()
				WeaponController.SetLocalRenderSuppressed(value == true)
				if value then
					if localJanitor then
						return
					end
					local janitor = Janitor.new()
					localJanitor = janitor
					janitor:Add(
						WeaponController.shotFired:Connect(LPH_NO_VIRTUALIZE(function(origin: Vector3, target: Vector3): ()
							api.spawnSegment(
								origin,
								target,
								settingsFor("localTracersOptions", DEFAULT_LOCAL_COLOR),
								janitor
							)
						end)),
						"Disconnect"
					)
				elseif localJanitor then
					localJanitor:Destroy()
					localJanitor = nil
				end
			end))

			local isFriendlyShot = LPH_NO_VIRTUALIZE(function(player: Player): boolean
				local data = PlayerController.Get(player)
				return data ~= nil and data:GetTeam() == ClientController.GetTeam()
			end)

			local function refreshRemote(): ()
				local needsRemote = friendlyEnabled or enemyEnabled
				if needsRemote then
					WeaponController.SetObservedRenderFilter(function(player: Player): boolean
						if isFriendlyShot(player) then
							return friendlyEnabled
						end
						return enemyEnabled
					end)
				else
					WeaponController.SetObservedRenderFilter(nil)
				end
				if needsRemote and not remoteJanitor then
					local janitor = Janitor.new()
					remoteJanitor = janitor
					janitor:Add(
						WeaponController.observedShot:Connect(
							function(player: Player, origin: Vector3, target: Vector3): ()
								if isFriendlyShot(player) then
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
							end
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

			self:Track(function(): ()
				WeaponController.SetLocalRenderSuppressed(false)
				WeaponController.SetObservedRenderFilter(nil)
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
