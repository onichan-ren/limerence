local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local BaseFeature = require("@game/BaseFeature")
local Hook = require("@share/hook")
local gameUi = require("@game/gameUi")

local AutoBhop = {}
AutoBhop.__index = AutoBhop

setmetatable(AutoBhop, { __index = BaseFeature })

local function resolveMovementModules(): (any?, any?)
	local classesFolder = ReplicatedStorage:FindFirstChild("Classes")
	local movementFolder = ReplicatedStorage:FindFirstChild("MovementV2")
	local charModule = classesFolder and classesFolder:FindFirstChild("Character")
	local buttonsModule = movementFolder and movementFolder:FindFirstChild("Buttons")
	if not charModule or not buttonsModule then
		return nil, nil
	end
	local ok1, charClass = pcall(require, charModule :: ModuleScript)
	local ok2, buttons = pcall(require, buttonsModule :: ModuleScript)
	if not ok1 or not ok2 then
		return nil, nil
	end
	return charClass, buttons
end

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
	self._onGround = false
	self._pendingDecision = nil :: boolean?
	self._sampleFn = nil :: any
	self._presentFn = nil :: any

	self:Track(link:Get("autoBhop"):OnChange(function(value: boolean)
		self:_setEnabled(value)
	end))

	self:Track(link:Watch("autoBhop.opts.chance", function(value: number)
		self._chance = value
	end))

	return self
end

function AutoBhop._setEnabled(self: AutoBhop, enabled: boolean): ()
	if enabled then
		local charClass, buttons = resolveMovementModules()
		if not charClass or not buttons then
			return
		end
		local sampleFn = rawget(charClass, "SampleInput")
		local presentFn = rawget(charClass, "Present")
		if type(sampleFn) ~= "function" or type(presentFn) ~= "function" then
			return
		end
		self._sampleFn = sampleFn
		self._presentFn = presentFn

		local oldPresent: any = nil
		oldPresent = Hook.add(
			presentFn,
			LPH_NO_VIRTUALIZE(function(charSelf: any, state: any, ...)
				if type(state) == "table" then
					self._onGround = state.OnGround == true
				end
				return oldPresent(charSelf, state, ...)
			end)
		)

		local oldSample: any = nil
		oldSample = Hook.add(
			sampleFn,
			LPH_NO_VIRTUALIZE(function(charSelf: any, ...)
				local cmd = oldSample(charSelf, ...)
				if type(cmd) ~= "table" then
					return cmd
				end
				if not UserInputService:IsKeyDown(Enum.KeyCode.Space) then
					self._pendingDecision = nil
					self._wasGrounded = false
					return cmd
				end
				if self._onGround then
					if not self._wasGrounded then
						self._pendingDecision = math.random(1, 100) <= self._chance
					end
					cmd.Buttons = buttons.with(cmd.Buttons, buttons.Jump, self._pendingDecision == true)
				else
					self._pendingDecision = nil
					cmd.Buttons = buttons.with(cmd.Buttons, buttons.Jump, false)
				end
				self._wasGrounded = self._onGround
				return cmd
			end)
		)
	else
		if self._sampleFn then
			Hook.restore(self._sampleFn)
			self._sampleFn = nil
		end
		if self._presentFn then
			Hook.restore(self._presentFn)
			self._presentFn = nil
		end
		self._pendingDecision = nil
		self._wasGrounded = false
		self._onGround = false
	end
end

function AutoBhop.Destroy(self: AutoBhop): ()
	self:_setEnabled(false)
	BaseFeature.Destroy(self)
end

export type AutoBhop =
	typeof(setmetatable(
		{} :: {
			_chance: number,
			_wasGrounded: boolean,
			_onGround: boolean,
			_pendingDecision: boolean?,
			_sampleFn: any,
			_presentFn: any,
		},
		AutoBhop
	))
	& BaseFeature.BaseFeature

return AutoBhop
