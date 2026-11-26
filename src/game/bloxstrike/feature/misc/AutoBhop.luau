local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local Hook = require("@share/hook")
local gameUi = require("@game/gameUi")

local AutoBhop = {}
AutoBhop.__index = AutoBhop

setmetatable(AutoBhop, { __index = BaseFeature })

function AutoBhop.new(link: gameUi.Linker): AutoBhop
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoBhop)

	link:Toggle("autoBhop", "Automatic Bunnyhop", false):SetTip({
		title = "Automatic Bunnyhop",
		body = "Automatically times your jumps to bunnyhop.",
	})
	local autoBhopLink = link:OnKey("autoBhop")
	autoBhopLink:Submenu("opts", "Automatic Bunnyhop")
	local optionsLink = autoBhopLink:OnKey("opts")
	optionsLink:Slider("chance", "Chance", 100, 1, 100, 1, nil, "%"):SetTip({
		title = "Chance",
		body = "Percent chance each landing triggers a jump. Lower values look less consistent.",
	})

	self._chance = 100
	self._wasGrounded = false
	self._pendingDecision = nil :: boolean?

	self:Track(link:Get("autoBhop"):OnChange(function(value: boolean)
		self:_setEnabled(value)
	end))

	self:Track(link:Watch("autoBhop.opts.chance", function(value: number)
		self._chance = value
	end))

	return self
end

function AutoBhop._setEnabled(self: AutoBhop, enabled: boolean): ()
	local movement = ModuleController.GetModule("Movement")
	local moveFunc = rawget(movement, "MoveFunction") :: (...any) -> any

	if enabled then
		local oldMove
		oldMove = Hook.add(
			moveFunc,
			LPH_NO_VIRTUALIZE(function(self2: any, input, worldSpace, ...)
				local result = oldMove(self2, input, worldSpace, ...)

				if not UserInputService:IsKeyDown(Enum.KeyCode.Space) then
					self._pendingDecision = nil
					self._wasGrounded = false
					return result
				end

				local grounded = self2:CheckGroundContact()
				if grounded then
					if not self._wasGrounded then
						self._pendingDecision = math.random(1, 100) <= self._chance
					end
					if self._pendingDecision then
						rawset(self2, "IsJumpRequested", true)
						self2:Jump()
					end
				else
					self._pendingDecision = nil
				end
				self._wasGrounded = grounded

				return result
			end)
		)
	else
		Hook.restore(moveFunc)
		self._pendingDecision = nil
		self._wasGrounded = false
	end
end

function AutoBhop.Destroy(self: AutoBhop): ()
	BaseFeature.Destroy(self)
end

export type AutoBhop =
	typeof(setmetatable(
		{} :: {
			_chance: number,
			_wasGrounded: boolean,
			_pendingDecision: boolean?,
		},
		AutoBhop
	))
	& BaseFeature.BaseFeature

return AutoBhop
