local Janitor = require("@pkg/Janitor")
local gameUi = require("@game/gameUi")
local UniversalTracer = require("@game/universal/feature/visual/tracer/Tracer")
local WeaponController = require("@game/rivals/weapon/WeaponController")

local DEFAULT_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 186, 210)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 108, 128)),
})

local TRACER_TYPES = { "Beam", "Line", "Adorn" }

local Tracer = {}

function Tracer.new(link: gameUi.Linker): UniversalTracer.Tracer
	return UniversalTracer.new(link, {
		setup = function(self: UniversalTracer.Tracer, _link: gameUi.Linker, api: UniversalTracer.TracerApi): ()
			local localJanitor: Janitor.Janitor? = nil

			local tracersToggle = link:Toggle("tracers", "Bullet Tracers", false):SetTip({
				title = "Bullet Tracers",
				body = "Draws a tracer from your muzzle to where each shot lands.",
			})
			local tracerLink = link:OnKey("tracers")
			tracerLink:Extra(tracersToggle, "color", "Colorpicker", "Color", DEFAULT_COLOR, 0):SetTip({
				title = "Color",
				body = "Tracer color or gradient.",
			})
			tracerLink:Extra(tracersToggle, "opts", "Submenu", "Bullet Tracer Options")
			local optsLink = tracerLink:OnKey("opts")
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

			api.attachBeamPicker(optsLink)

			local function enable(): ()
				if localJanitor then
					return
				end

				local janitor = Janitor.new()
				localJanitor = janitor

				janitor:Add(
					WeaponController.gunTracer:Connect(LPH_NO_VIRTUALIZE(function(segments: { { Vector3 } }): ()
						local settings = api.peekSettings(tracerLink, optsLink, DEFAULT_COLOR)
						for i = 1, #segments do
							local segment = segments[i]
							api.spawnSegment(segment[1], segment[2], settings, janitor)
						end
					end)),
					"Disconnect"
				)
			end

			local function disable(): ()
				if not localJanitor then
					return
				end
				localJanitor:Destroy()
				localJanitor = nil
			end

			self:Track(link:Get("tracers"):OnChange(function(value: boolean): ()
				if value then
					enable()
				else
					disable()
				end
			end))

			if link:Peek("tracers") then
				enable()
			end

			self:Track(function(): ()
				disable()
			end)
		end,
	})
end

return Tracer
