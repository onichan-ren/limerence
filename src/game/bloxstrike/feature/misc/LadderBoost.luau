local RunService = cloneref(game:GetService("RunService")) :: RunService

local ClientController = require("@game/bloxstrike/client/ClientController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local clientState = require("@game/bloxstrike/client/clientState")

local RENDER_NAME = "LadderBoostRender"
local peek = Charm.peek

local LadderBoost = {}
LadderBoost.__index = LadderBoost

setmetatable(LadderBoost, { __index = BaseFeature })

function LadderBoost.new(link: gameUi.Linker): LadderBoost
	local self = BaseFeature.new() :: any
	setmetatable(self, LadderBoost)

	link:Toggle("ladderBoost", "Ladder Boost", false):SetTip({
		title = "Ladder Boost",
		body = "Climb ladders faster.",
	})
	local ladderBoostLink = link:OnKey("ladderBoost")
	ladderBoostLink:Submenu("opts", "Ladder Boost")
	local optionsLink = ladderBoostLink:OnKey("opts")
	optionsLink:Slider("speed", "Speed", 100, 0, 500, 10, nil, "%"):SetTip({
		title = "Speed",
		body = "Extra climb speed added on top of normal.",
	})

	self._multiplier = 2
	self._activeJanitor = nil :: Janitor.Janitor?

	self:Track(link:Get("ladderBoost"):OnChange(function(value: boolean)
		self:_setEnabled(value)
	end))

	self:Track(link:Watch("ladderBoost.opts.speed", function(value: number)
		self._multiplier = 1 + value / 100
	end))

	return self
end

function LadderBoost._setEnabled(self: LadderBoost, enabled: boolean): ()
	if enabled then
		if self._activeJanitor then
			return
		end
		local janitor = Janitor.new()
		self._activeJanitor = janitor

		RunService:BindToRenderStep(
			RENDER_NAME,
			Enum.RenderPriority.Last.Value,
			LPH_NO_VIRTUALIZE(function(): ()
				local multiplier = self._multiplier
				if multiplier <= 1 then
					return
				end

				if not ClientController.IsClimbing() then
					return
				end

				local hrp = peek(clientState.parts).HumanoidRootPart
				if not hrp or not hrp.Parent then
					return
				end

				local velocity = hrp.AssemblyLinearVelocity
				if math.abs(velocity.Y) < 0.05 then
					return
				end

				hrp.AssemblyLinearVelocity = Vector3.new(velocity.X, velocity.Y * multiplier, velocity.Z)
			end)
		)
		janitor:Add(function(): ()
			RunService:UnbindFromRenderStep(RENDER_NAME)
		end, true)
	else
		local janitor = self._activeJanitor
		if not janitor then
			return
		end
		self._activeJanitor = nil
		janitor:Destroy()
	end
end

function LadderBoost.Destroy(self: LadderBoost): ()
	self:_setEnabled(false)
	BaseFeature.Destroy(self)
end

export type LadderBoost =
	typeof(setmetatable(
		{} :: {
			_multiplier: number,
			_activeJanitor: Janitor.Janitor?,
		},
		LadderBoost
	))
	& BaseFeature.BaseFeature

return LadderBoost
