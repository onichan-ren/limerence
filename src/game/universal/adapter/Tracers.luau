local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local gameUi = require("@game/gameUi")
local UniversalTracer = require("@game/universal/feature/visual/tracer/Tracer")
local PlayerController = require("@feature/player/PlayerController")
local localState = require("@game/universal/client/localState")
local universalEvents = require("@game/universal/adapter/universalEvents")

local peek = Charm.peek

local LocalPlayer = Players.LocalPlayer

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

local Tracers = {}

function Tracers.new(link: gameUi.Linker): UniversalTracer.Tracer
	return UniversalTracer.new(link, {
		setup = function(self: UniversalTracer.Tracer, _link: gameUi.Linker, api: UniversalTracer.TracerApi): ()
			local shotJanitor: Janitor.Janitor? = nil
			local localEnabled = false
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

			local isFriendlyShot = LPH_NO_VIRTUALIZE(function(player: Player): boolean
				local data = PlayerController.Get(player)
				if not data then
					return false
				end
				local localTeam = peek(localState.team)
				return localTeam ~= "" and data:GetTeam() == localTeam
			end)

			local function refresh(): ()
				local needsShots = localEnabled or friendlyEnabled or enemyEnabled
				if needsShots and not shotJanitor then
					local janitor = Janitor.new()
					shotJanitor = janitor
					janitor:Add(
						universalEvents.shot:Connect(LPH_NO_VIRTUALIZE(function(event: universalEvents.ShotEvent): ()
							local player = event.player
							if player == nil or player == LocalPlayer then
								if not localEnabled then
									return
								end
								api.spawnSegment(
									event.origin,
									event.target,
									settingsFor("localTracersOptions", DEFAULT_LOCAL_COLOR),
									janitor
								)
							elseif isFriendlyShot(player) then
								if not friendlyEnabled then
									return
								end
								api.spawnSegment(
									event.origin,
									event.target,
									settingsFor("friendlyTracersOptions", DEFAULT_FRIENDLY_COLOR),
									janitor
								)
							else
								if not enemyEnabled then
									return
								end
								api.spawnSegment(
									event.origin,
									event.target,
									settingsFor("enemyTracersOptions", DEFAULT_ENEMY_COLOR),
									janitor
								)
							end
						end)),
						"Disconnect"
					)
				elseif not needsShots and shotJanitor then
					shotJanitor:Destroy()
					shotJanitor = nil
				end
			end

			self:Track(optionsLink:Get("localTracers"):OnChange(function(value: boolean): ()
				localEnabled = value == true
				refresh()
			end))

			self:Track(optionsLink:Get("friendlyTracers"):OnChange(function(value: boolean): ()
				friendlyEnabled = value == true
				refresh()
			end))

			self:Track(optionsLink:Get("enemyTracers"):OnChange(function(value: boolean): ()
				enemyEnabled = value == true
				refresh()
			end))

			self:Track(function(): ()
				if shotJanitor then
					shotJanitor:Destroy()
					shotJanitor = nil
				end
			end)
		end,
	})
end

return Tracers
