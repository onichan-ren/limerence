local ModuleController = require("@game/rivals/module/ModuleController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

local DoubleJumpBoost = {}
DoubleJumpBoost.__index = DoubleJumpBoost

setmetatable(DoubleJumpBoost, { __index = BaseFeature })

function DoubleJumpBoost.new(link: gameUi.Linker): DoubleJumpBoost
	local self = BaseFeature.new() :: any
	setmetatable(self, DoubleJumpBoost)

	link:Toggle("doubleJumpBoost", "Double Jump Boost", false):SetTip({
		title = "Double Jump Boost",
		body = "Boost your double jump height.",
	})
	local doubleJumpBoostLink = link:OnKey("doubleJumpBoost")
	doubleJumpBoostLink:Submenu("opts", "Double Jump Boost")
	local optionsLink = doubleJumpBoostLink:OnKey("opts")
	optionsLink:Slider("speed", "Boost Amount", 50, 1, 500, 1, nil, "%"):SetTip({
		title = "Boost Amount",
		body = "How much to boost your double jump height.",
	})

	self._boostAmount = 50
	self._janitor = Janitor.new()

	self:Track(link:Get("doubleJumpBoost"):OnChange(function(value: boolean)
		if value then
			self:Enable(true)
		else
			self:Disable(false)
		end
	end))

	self:Track(link:Watch("doubleJumpBoost.opts.speed", function(value: number)
		self._boostAmount = value
	end))

	return self
end

function DoubleJumpBoost.Enable(self: DoubleJumpBoost): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local MechanicsController = ModuleController.GetModule("MechanicsController")
	if not MechanicsController then
		return
	end

	local mechanicsClass = getmetatable(MechanicsController)
	local doubleJump = mechanicsClass and rawget(mechanicsClass, "DoubleJump")
	if not doubleJump then
		return
	end

	local oldFenv = getfenv(doubleJump)
	setfenv(
		doubleJump,
		setmetatable({
			Vector3 = setmetatable({
				new = newcclosure(LPH_NO_VIRTUALIZE(function(x: number, y: number, z: number): Vector3
					setthreadidentity(2)
					return Vector3.new(x, y * (1 + (self._boostAmount / 100)), z)
				end)),
			}, { __index = Vector3 }),
		}, { __index = oldFenv })
	)

	self._janitor:Add(function()
		setfenv(doubleJump, oldFenv)
	end, true)
end

function DoubleJumpBoost.Disable(self: DoubleJumpBoost): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function DoubleJumpBoost.Destroy(self: DoubleJumpBoost): ()
	self:Disable()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type DoubleJumpBoost =
	typeof(setmetatable(
		{} :: {
			_boostAmount: number,
			_janitor: Janitor.Janitor?,
		},
		DoubleJumpBoost
	))
	& BaseFeature.BaseFeature

return DoubleJumpBoost
