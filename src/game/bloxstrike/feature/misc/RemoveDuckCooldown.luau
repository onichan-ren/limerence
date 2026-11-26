local RunService = cloneref(game:GetService("RunService")) :: RunService

local ClientController = require("@game/bloxstrike/client/ClientController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

local RENDER_NAME = "RemoveDuckCooldownRender"

local RemoveDuckCooldown = {}
RemoveDuckCooldown.__index = RemoveDuckCooldown

setmetatable(RemoveDuckCooldown, { __index = BaseFeature })

function RemoveDuckCooldown.new(link: gameUi.Linker): RemoveDuckCooldown
	local self = BaseFeature.new() :: any
	setmetatable(self, RemoveDuckCooldown)

	link:Toggle("removeDuckCooldown", "Remove Duck Cooldown", false):SetTip({
		title = "Remove Duck Cooldown",
		body = "Removes the slowdown from crouching over and over, so ducking stays snappy.",
	})

	self._activeJanitor = nil :: Janitor.Janitor?

	self:Track(link:Get("removeDuckCooldown"):OnChange(function(value: boolean)
		self:_setEnabled(value)
	end))

	return self
end

function RemoveDuckCooldown._setEnabled(self: RemoveDuckCooldown, enabled: boolean): ()
	if enabled then
		if self._activeJanitor then
			return
		end
		local janitor = Janitor.new()
		self._activeJanitor = janitor

		RunService:BindToRenderStep(
			RENDER_NAME,
			Enum.RenderPriority.First.Value,
			LPH_NO_VIRTUALIZE(function(): ()
				local character = ClientController.GetCharacterObject()
				if not character then
					return
				end
				character.LastCrouchTick = 0
				character.CrouchCount = 0
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

function RemoveDuckCooldown.Destroy(self: RemoveDuckCooldown): ()
	self:_setEnabled(false)
	BaseFeature.Destroy(self)
end

export type RemoveDuckCooldown =
	typeof(setmetatable(
		{} :: {
			_activeJanitor: Janitor.Janitor?,
		},
		RemoveDuckCooldown
	))
	& BaseFeature.BaseFeature

return RemoveDuckCooldown
