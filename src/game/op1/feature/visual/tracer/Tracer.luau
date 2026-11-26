local UniversalTracer = require("@game/universal/feature/visual/tracer/Tracer")
local WeaponController = require("@game/op1/weapon/WeaponController")
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
	defaultColor: ColorSequence,
	body: string
): ()
	local toggle = optionsLink:Toggle(key, label, false):SetTip({
		title = label,
		body = body,
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

local SOURCES = {
	{ relation = "local", key = "localTracers", label = "Local Tracers", color = DEFAULT_LOCAL_COLOR, body = "Draws tracers for your own shots." },
	{ relation = "friendly", key = "friendlyTracers", label = "Friendly Tracers", color = DEFAULT_FRIENDLY_COLOR, body = "Draws tracers for teammates' shots." },
	{ relation = "enemy", key = "enemyTracers", label = "Enemy Tracers", color = DEFAULT_ENEMY_COLOR, body = "Draws tracers for enemy shots." },
}

local Tracer = {}

function Tracer.new(link: gameUi.Linker): UniversalTracer.Tracer
	return UniversalTracer.new(link, {
		setup = function(self: UniversalTracer.Tracer, _link: gameUi.Linker, api: UniversalTracer.TracerApi): ()
			local janitor: Janitor.Janitor? = nil
			local enabled: { [string]: boolean } = {}
			local byRelation: { [string]: any } = {}
			local settingsLinks: { [string]: gameUi.Linker } = {}

			link:Options("bulletTracers", "Bullet Tracers")
			local optionsLink = link:OnKey("bulletTracers")

			for _, source in next, SOURCES do
				byRelation[source.relation] = source
				addTracerControls(optionsLink, source.key, source.label, source.color, source.body)
				settingsLinks[source.key] = optionsLink:OnKey(`{source.key}Options`)
			end

			api.attachBeamPicker(optionsLink)

			local function settingsFor(source: any): UniversalTracer.TracerSettings
				local optsLink = settingsLinks[source.key]
				return api.peekSettings(optsLink, optsLink, source.color)
			end

			local function refresh(): ()
				local needed = enabled["local"] or enabled.friendly or enabled.enemy

				if needed and not janitor then
					local newJanitor = Janitor.new()
					janitor = newJanitor

					newJanitor:Add(
						WeaponController.shotFired:Connect(LPH_NO_VIRTUALIZE(function(origin: Vector3, pellets: { any }, relation: string): ()
							if not enabled[relation] then
								return
							end

							local source = byRelation[relation]
							if not source then
								return
							end

							local settings = settingsFor(source)

							local oldIdentity = getthreadidentity()
							setthreadidentity(8)

							for _, pellet in next, pellets do
								if type(pellet) == "table" and #pellet > 0 then
									local last = pellet[#pellet]
									local endpoint = type(last) == "table" and last.Position
									if typeof(endpoint) == "Vector3" then
										api.spawnSegment(origin, endpoint, settings, newJanitor)
									end
								end
							end

							setthreadidentity(oldIdentity)
						end)),
						"Disconnect"
					)
				elseif not needed and janitor then
					janitor:Destroy()
					janitor = nil
				end
			end

			for _, source in next, SOURCES do
				self:Track(optionsLink:Get(source.key):OnChange(function(value: boolean): ()
					enabled[source.relation] = value == true
					refresh()
				end))
			end

			self:Track(function(): ()
				if janitor then
					janitor:Destroy()
					janitor = nil
				end
			end)
		end,
	})
end

return Tracer
