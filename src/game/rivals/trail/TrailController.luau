local Players = cloneref(game:GetService("Players")) :: Players

local hook = require("@share/hook")

local LocalPlayer = Players.LocalPlayer

local TrailController = {}

local KINDS = {
	own = true,
	other = true,
	grenade = true,
}

local config = {
	own = { removed = false, color = nil :: any },
	other = { removed = false, color = nil :: any },
	grenade = { removed = false, color = nil :: any },
}

local requireAirborneClass = LPH_NO_VIRTUALIZE(function(): any?
	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local modules = playerScripts and playerScripts:FindFirstChild("Modules")
	local classes = modules and modules:FindFirstChild("ClientReplicatedClasses")
	local fighter = classes and classes:FindFirstChild("ClientFighter")
	local character = fighter and fighter:FindFirstChild("ClientFighterCharacter")
	local airborne = character and character:FindFirstChild("Airborne")
	if not airborne then
		return nil
	end
	setthreadidentity(2)
	local instance = require(airborne) :: any
	setthreadidentity(8)
	return instance
end)

local function resolveThrowables(): Instance?
	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local assets = playerScripts and playerScripts:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Throwables")
end

local applyTrail = LPH_NO_VIRTUALIZE(function(trail: Trail, cfg: any): ()
	if cfg.removed then
		trail.Enabled = false
	elseif cfg.color then
		trail.Color = ColorSequence.new(cfg.color.color)
		trail.Transparency = NumberSequence.new(cfg.color.transparency)
	end
end)

local _airborneHookTarget: any = nil

local function airborneActive(): boolean
	return config.own.removed
		or config.own.color ~= nil
		or config.other.removed
		or config.other.color ~= nil
end

local function installAirborne(): ()
	if _airborneHookTarget then
		return
	end
	local class = requireAirborneClass()
	if type(class) ~= "table" then
		return
	end
	local original = rawget(class, "_UpdateEffect")
	if type(original) ~= "function" then
		return
	end

	_airborneHookTarget = original
	local trampoline
	trampoline = hook.add(
		original,
		LPH_NO_VIRTUALIZE(function(airborneSelf: any, ...: any): ...any
			local result = trampoline(airborneSelf, ...)
			local character = airborneSelf.ClientFighterCharacter
			local fighter = character and character.ClientFighter
			if fighter then
				local cfg = fighter.IsLocalPlayer and config.own or config.other
				if cfg.removed or cfg.color then
					local objects = airborneSelf._effect_objects
					if type(objects) == "table" then
						for _, object in next, objects do
							if typeof(object) == "Instance" and object:IsA("Trail") then
								applyTrail(object, cfg)
							end
						end
					end
				end
			end
			return result
		end)
	)
end

local function uninstallAirborne(): ()
	if _airborneHookTarget then
		hook.restore(_airborneHookTarget)
		_airborneHookTarget = nil
	end
end

local function syncAirborne(): ()
	if airborneActive() then
		installAirborne()
	else
		uninstallAirborne()
	end
end

local _grenadeOriginals: { [Trail]: any } = {}
local _grenadePatched = false

local function grenadeActive(): boolean
	return config.grenade.removed or config.grenade.color ~= nil
end

local applyGrenade = LPH_NO_VIRTUALIZE(function(): ()
	local root = resolveThrowables()
	if not root then
		return
	end
	local cfg = config.grenade
	for _, descendant in next, root:QueryDescendants("Trail") do
		local original = _grenadeOriginals[descendant]
		if original == nil then
			original = {
				Color = descendant.Color,
				Transparency = descendant.Transparency,
				Enabled = descendant.Enabled,
			}
			_grenadeOriginals[descendant] = original
		end
		descendant.Enabled = original.Enabled
		descendant.Color = original.Color
		descendant.Transparency = original.Transparency
		applyTrail(descendant, cfg)
	end
	_grenadePatched = true
end)

local restoreGrenade = LPH_NO_VIRTUALIZE(function(): ()
	for trail, original in next, _grenadeOriginals do
		if typeof(trail) == "Instance" then
			trail.Color = original.Color
			trail.Transparency = original.Transparency
			trail.Enabled = original.Enabled
		end
		_grenadeOriginals[trail] = nil
	end
	_grenadePatched = false
end)

local function syncGrenade(): ()
	if grenadeActive() then
		applyGrenade()
	elseif _grenadePatched then
		restoreGrenade()
	end
end

local function sync(kind: string): ()
	if kind == "grenade" then
		syncGrenade()
	else
		syncAirborne()
	end
end

function TrailController.setRemoved(kind: string, value: boolean): ()
	if not KINDS[kind] then
		return
	end
	value = value == true
	if config[kind].removed == value then
		return
	end
	config[kind].removed = value
	sync(kind)
end

function TrailController.setColor(kind: string, color: any): ()
	if not KINDS[kind] then
		return
	end
	config[kind].color = color
	sync(kind)
end

return TrailController
