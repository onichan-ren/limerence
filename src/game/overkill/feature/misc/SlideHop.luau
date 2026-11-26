local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local CommandBaseController = require("@game/overkill/weapon/CommandBaseController")

local JUMP_BUFFER = 0.02

local SlideHop = {}
SlideHop.__index = SlideHop

setmetatable(SlideHop, { __index = BaseFeature })

function SlideHop.new(link: gameUi.Linker): SlideHop
	local self = BaseFeature.new() :: any
	setmetatable(self, SlideHop)

	local toggle = link:Toggle("slideHop", "Slide Hop", false):SetTip({
		title = "Slide Hop",
		body = "Chains slides while you move to keep your speed high.",
	})

	self._enabled = false
	self._installed = false

	self:Track(toggle:OnChange(function(value: boolean): ()
		self._enabled = value
		if value then
			self:_install()
		end
	end))

	if link:Peek("slideHop") then
		self._enabled = true
		self:_install()
	end

	return self
end

function SlideHop._install(self: SlideHop): ()
	if self._installed then
		return
	end
	self._installed = true

	self:Track(CommandBaseController.Register(LPH_NO_VIRTUALIZE(function(command: any, module: any): ()
		if type(command) ~= "table" or not self._enabled then
			return
		end

		local localChickynoid = module and module.localChickynoid
		local simulation = localChickynoid and localChickynoid.simulation
		local state = simulation and simulation.state
		local constants = simulation and simulation.constants
		if type(state) ~= "table" or type(constants) ~= "table" then
			return
		end

		local moveState = simulation:GetMoveState()
		local name = moveState and moveState.name

		if name == "Sliding" then
			command.slide = 0
			local minHold = constants.slideMinHold or 0.185
			local elapsed = (command.serverTime or 0) - (state.slideStartServerTime or 0)
			if elapsed >= minHold + JUMP_BUFFER and simulation:HasCoyoteFloor() then
				command.y = 1
			end
			return
		end

		if name ~= "Walking" then
			return
		end
		if command.x == 0 and command.z == 0 then
			return
		end
		if state.crouching or state.slideLatch or (state.slideCooldown or 0) > 0 then
			return
		end
		if not simulation:HasCoyoteFloor() then
			return
		end

		command.slide = 1
		if type(command.serverTime) == "number" then
			command.serverTime -= (constants.slideMinHold or 0.185) + JUMP_BUFFER
		end
	end)))
end

function SlideHop.Destroy(self: SlideHop): ()
	self._enabled = false
	BaseFeature.Destroy(self)
end

export type SlideHop =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_installed: boolean,
			_install: (SlideHop) -> (),
		},
		SlideHop
	))
	& BaseFeature.BaseFeature

return SlideHop
