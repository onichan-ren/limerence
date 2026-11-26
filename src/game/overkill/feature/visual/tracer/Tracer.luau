local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local gameUi = require("@game/gameUi")
local UniversalTracer = require("@game/universal/feature/visual/tracer/Tracer")
local WeaponController = require("@game/overkill/weapon/WeaponController")
local ModuleController = require("@game/overkill/module/ModuleController")
local ClientState = require("@game/overkill/client/clientState")
local PlayerController = require("@feature/player/PlayerController")

local peek = Charm.peek

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

local TRACER_TYPES = { "Beam", "Line", "Adorn" }

local _viewModel: any = nil

local resolveMuzzle = LPH_NO_VIRTUALIZE(function(fallback: Vector3): Vector3
	local viewModel = _viewModel
	if type(viewModel) ~= "table" then
		viewModel = ModuleController.GetModule("viewModel")
		_viewModel = viewModel
	end
	if type(viewModel) ~= "table" or type(viewModel.getEquipped) ~= "function" then
		return fallback
	end

	local character = peek(ClientState.character)
	if not character then
		return fallback
	end

	local vmc = viewModel.getEquipped(character)
	if type(vmc) ~= "table" or not vmc.muzzle then
		return fallback
	end

	local worldCFrame = vmc.muzzle.WorldCFrame
	if typeof(worldCFrame) ~= "CFrame" then
		return fallback
	end
	local position = worldCFrame.Position
	if (position - fallback).Magnitude > 1000000 then
		return fallback
	end
	return position
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
			key == "localTracers" and "Draws a tracer from your muzzle to where each shot lands."
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

			local function makeSettingsReader(submenuKey: string, fallback: ColorSequence): () -> UniversalTracer.TracerSettings
				local optsLink = optionsLink:OnKey(submenuKey)
				local colorEl: any = optsLink:Get("color")
				local settings: UniversalTracer.TracerSettings = {
					Color = fallback,
					Transparency = 0,
					Type = "Beam",
					Lifetime = 2,
					Thickness = 1,
					Beam = nil,
				}
				return LPH_NO_VIRTUALIZE(function(): UniversalTracer.TracerSettings
					settings.Color = (colorEl._currentGradient :: any):getValue() or fallback
					settings.Transparency = (colorEl._currentTransparency :: any):getValue() or 0
					settings.Type = optsLink:Peek("type") or "Beam"
					settings.Lifetime = optsLink:Peek("lifetime") or 2
					settings.Thickness = optsLink:Peek("thickness") or 1
					settings.Beam = (self :: any)._beamManifest
					return settings
				end)
			end

			local localSettings = makeSettingsReader("localTracersOptions", DEFAULT_LOCAL_COLOR)
			local friendlySettings = makeSettingsReader("friendlyTracersOptions", DEFAULT_FRIENDLY_COLOR)
			local enemySettings = makeSettingsReader("enemyTracersOptions", DEFAULT_ENEMY_COLOR)

			local function enableLocal(): ()
				if localJanitor then
					return
				end
				local janitor = Janitor.new()
				localJanitor = janitor
				janitor:Add(
					WeaponController.shotFired:Connect(LPH_NO_VIRTUALIZE(function(origin: Vector3, target: Vector3): ()
						if typeof(origin) ~= "Vector3" or typeof(target) ~= "Vector3" then
							return
						end
						local muzzle = resolveMuzzle(origin)
						if (target - muzzle).Magnitude < 1e-3 then
							return
						end
						api.spawnSegment(muzzle, target, localSettings(), janitor)
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

			self:Track(optionsLink:Get("localTracers"):OnChange(function(value: boolean): ()
				if value then
					enableLocal()
				else
					disableLocal()
				end
			end))

			local isFriendlyShot = LPH_NO_VIRTUALIZE(function(player: Player): boolean
				local data = PlayerController.Get(player)
				if not data then
					return false
				end
				local localTeam = peek(ClientState.team)
				return localTeam ~= "" and peek((data :: any).team) == localTeam
			end)

			local function refreshRemote(): ()
				local needsRemote = friendlyEnabled or enemyEnabled
				if needsRemote and not remoteJanitor then
					local janitor = Janitor.new()
					remoteJanitor = janitor
					janitor:Add(
						WeaponController.observedShot:Connect(
							LPH_NO_VIRTUALIZE(function(player: Player, origin: Vector3, target: Vector3): ()
								if typeof(origin) ~= "Vector3" or typeof(target) ~= "Vector3" then
									return
								end
								if (target - origin).Magnitude < 1e-3 then
									return
								end
								if isFriendlyShot(player) then
									if not friendlyEnabled then
										return
									end
									api.spawnSegment(origin, target, friendlySettings(), janitor)
								else
									if not enemyEnabled then
										return
									end
									api.spawnSegment(origin, target, enemySettings(), janitor)
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
