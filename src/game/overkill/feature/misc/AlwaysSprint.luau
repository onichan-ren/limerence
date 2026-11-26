local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local CommandBaseController = require("@game/overkill/weapon/CommandBaseController")

local AlwaysSprint = {}
AlwaysSprint.__index = AlwaysSprint

setmetatable(AlwaysSprint, { __index = BaseFeature })

function AlwaysSprint.new(link: gameUi.Linker): AlwaysSprint
	local self = BaseFeature.new() :: any
	setmetatable(self, AlwaysSprint)

	local toggle = link:Toggle("alwaysSprint", "Always Sprint", false):SetTip({
		title = "Always Sprint",
		body = "Keeps you at full run speed without holding the sprint key.",
	})

	self._enabled = false
	self._installed = false

	self:Track(toggle:OnChange(function(value: boolean): ()
		self._enabled = value
		if value then
			self:_install()
		end
	end))

	if link:Peek("alwaysSprint") then
		self._enabled = true
		self:_install()
	end

	return self
end

function AlwaysSprint._install(self: AlwaysSprint): ()
	if self._installed then
		return
	end
	self._installed = true

	self:Track(CommandBaseController.Register(LPH_NO_VIRTUALIZE(function(command: any): ()
		if self._enabled and type(command) == "table" then
			command.walk = 0
		end
	end)))
end

function AlwaysSprint.Destroy(self: AlwaysSprint): ()
	self._enabled = false
	BaseFeature.Destroy(self)
end

export type AlwaysSprint =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_installed: boolean,
			_install: (AlwaysSprint) -> (),
		},
		AlwaysSprint
	))
	& BaseFeature.BaseFeature

return AlwaysSprint
