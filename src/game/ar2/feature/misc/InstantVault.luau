local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")

local FAST_TIME = 0.02

local InstantVault = {}
InstantVault.__index = InstantVault

setmetatable(InstantVault, { __index = BaseFeature })

function InstantVault.new(link: gameUi.Linker): InstantVault
	local self = BaseFeature.new() :: any
	setmetatable(self, InstantVault)

	self._enabled = false
	self._config = nil :: any
	self._origLow = nil :: number?
	self._origHigh = nil :: number?

	link:Toggle("instantVault", "Instant Vault", false):SetTip({
		title = "Instant Vault",
		body = "Vault over ledges and obstacles instantly.",
	})

	self:Track(link:Get("instantVault"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("instantVault") then
		self:Enable()
	end

	return self
end

function InstantVault.Enable(self: InstantVault): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local vaulting = ModuleController.FrameworkRequire("Libraries", "Vaulting")
	local config = vaulting and vaulting.Configs and vaulting.Configs.Character
	if not config then
		return
	end

	self._config = config
	self._origLow = config.LowPhysicsAnimationTime
	self._origHigh = config.HighPhysicsAnimationTime
	config.LowPhysicsAnimationTime = FAST_TIME
	config.HighPhysicsAnimationTime = FAST_TIME
end

function InstantVault.Disable(self: InstantVault): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	local config = self._config
	if config then
		if self._origLow ~= nil then
			config.LowPhysicsAnimationTime = self._origLow
		end
		if self._origHigh ~= nil then
			config.HighPhysicsAnimationTime = self._origHigh
		end
	end

	self._config = nil
	self._origLow = nil
	self._origHigh = nil
end

function InstantVault.Destroy(self: InstantVault): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type InstantVault =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_config: any,
			_origLow: number?,
			_origHigh: number?,
		},
		InstantVault
	))
	& BaseFeature.BaseFeature

return InstantVault
