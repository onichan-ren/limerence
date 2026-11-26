local clientState = require("@game/rivals/client/clientState")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local peek = Charm.peek
local observe = Charm.observe

local SlideBoost = {}
SlideBoost.__index = SlideBoost

setmetatable(SlideBoost, { __index = BaseFeature })

function SlideBoost.new(link: gameUi.Linker): SlideBoost
	local self = BaseFeature.new() :: any
	setmetatable(self, SlideBoost)

	link:Toggle("slideBoost", "Slide Boost", false):SetTip({
		title = "Slide Boost",
		body = "Boost your slide speed.",
	})
	local slideBoostLink = link:OnKey("slideBoost")
	slideBoostLink:Submenu("opts", "Slide Boost")
	local optionsLink = slideBoostLink:OnKey("opts")
	optionsLink:Slider("speed", "Boost Amount", 50, 1, 500, 1, nil, "%"):SetTip({
		title = "Boost Amount",
		body = "How much to boost your slide speed.",
	})

	self._speed = 50
	self._janitor = Janitor.new()

	self:Track(link:Get("slideBoost"):OnChange(function(value: boolean)
		if value then
			self:Enable(true)
		else
			self:Disable(false)
		end
	end))

	self:Track(link:Watch("slideBoost.opts.speed", function(value: number)
		self._speed = value
	end))

	return self
end

function SlideBoost.Enable(self: SlideBoost): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local currentVelocity = nil :: Vector3?
	local mechanicsScript = nil :: Instance?
	local function onChildAdded(child: Instance): ()
		if child.ClassName ~= "BodyVelocity" then
			return
		end
		currentVelocity = child

		local bodyVelocity = child :: BodyVelocity

		bodyVelocity.Velocity *= (1 + (self._speed / 100))

		local originalMetatable = getrawmetatable(bodyVelocity) :: any
		local originalNewIndex = originalMetatable.__newindex

		local newMetatable = {
			__newindex = newcclosure(LPH_NO_VIRTUALIZE(function(child: any, key: string, value: number): ()
				if key == "Velocity" then
					local callingScript = getcallingscript()
					if not callingScript or checkcaller() then
						return originalNewIndex(child, key, value)
					end

					local isMechanics = callingScript == mechanicsScript
					if not isMechanics and not mechanicsScript and callingScript:GetFullName():find("MechanicsController") then
						mechanicsScript = callingScript
						isMechanics = true
					end
					if isMechanics and peek(clientState.isSliding) then
						value *= (1 + (self._speed / 100))
					end
				end
				return originalNewIndex(child, key, value)
			end)),
		}

		for idx, meta in next, originalMetatable do
			if not newMetatable[idx] then
				newMetatable[idx] = meta
			end
		end

		setrawmetatable(bodyVelocity, newMetatable)
	end

	self._janitor:Add(
		observe(clientState.parts, function(part: BasePart)
			if part.Name ~= "HumanoidRootPart" then
				return
			end

			self._janitor:Add(part.ChildAdded:Connect(onChildAdded), "Disconnect")
		end),
		true
	)

	self._janitor:Add(function()
		if currentVelocity then
			setrawmetatable(currentVelocity, getrawmetatable(workspace) :: any)
		end
	end)

	local humanoidRootPart = peek(clientState.parts).HumanoidRootPart
	if not humanoidRootPart then
		return
	end

	self._janitor:Add(humanoidRootPart.ChildAdded:Connect(onChildAdded), "Disconnect")
end

function SlideBoost.Disable(self: SlideBoost): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function SlideBoost.Destroy(self: SlideBoost): ()
	self:Disable()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type SlideBoost =
	typeof(setmetatable(
		{} :: {
			_speed: number,
			_janitor: Janitor.Janitor?,
		},
		SlideBoost
	))
	& BaseFeature.BaseFeature

return SlideBoost
