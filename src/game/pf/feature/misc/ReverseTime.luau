local RunService = cloneref(game:GetService("RunService")) :: RunService

local BaseFeature = require("@game/BaseFeature")
local NetworkController = require("@game/pf/network/NetworkController")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

local STEP = 1 / 60

local ReverseTime = {}
ReverseTime.__index = ReverseTime

setmetatable(ReverseTime, { __index = BaseFeature })

function ReverseTime.new(link: gameUi.Linker): ReverseTime
	local self = BaseFeature.new() :: any
	setmetatable(self, ReverseTime)

	self._activeJanitor = nil :: Janitor.Janitor?
	self._offset = 0
	self._acc = 0

	link:Toggle("reverseTime", "Reverse Time", false):SetTip({
		title = "Reverse Time",
		body = "Reverses outgoing network timestamps by 1/60s every 1/60s.",
	})

	self:Track(link:Get("reverseTime"):OnChange(function(enabled: boolean)
		self:_setEnabled(enabled)
	end))

	return self
end

function ReverseTime._setEnabled(self: ReverseTime, enabled: boolean): ()
	if enabled then
		if self._activeJanitor then
			return
		end
		local janitor = Janitor.new()
		self._activeJanitor = janitor
		self._offset = 0
		self._acc = 0

		janitor:Add(
			RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
				self._acc += dt
				if self._acc < STEP then
					return
				end
				while self._acc >= STEP do
					self._acc -= STEP
					self._offset -= STEP
				end
				NetworkController.SetCurrentAddition(self._offset)
			end)),
			"Disconnect"
		)
		janitor:Add(function(): ()
			self._offset = 0
			self._acc = 0
			NetworkController.SetCurrentAddition(0)
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

function ReverseTime.Destroy(self: ReverseTime): ()
	self:_setEnabled(false)
	BaseFeature.Destroy(self)
end

export type ReverseTime =
	typeof(setmetatable(
		{} :: {
			_activeJanitor: Janitor.Janitor?,
			_offset: number,
			_acc: number,
			_setEnabled: (ReverseTime, boolean) -> (),
		},
		ReverseTime
	))
	& BaseFeature.BaseFeature

return ReverseTime
