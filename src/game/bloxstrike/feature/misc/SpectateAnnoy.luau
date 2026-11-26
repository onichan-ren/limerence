local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local NetworkController = require("@game/bloxstrike/network/NetworkController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")

local SpectateAnnoy = {}
SpectateAnnoy.__index = SpectateAnnoy

setmetatable(SpectateAnnoy, { __index = BaseFeature })

function SpectateAnnoy.new(link: gameUi.Linker): SpectateAnnoy
	local self = BaseFeature.new() :: any
	setmetatable(self, SpectateAnnoy)

	link:Toggle("spectateAnnoy", "Spectate Annoy", false):SetTip({
		title = "Spectate Annoy",
		body = "Makes your camera jump around for people spectating you.",
	})

	self._janitor = Janitor.new()

	self:Track(link:Get("spectateAnnoy"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	return self
end

function SpectateAnnoy.Enable(self: SpectateAnnoy): ()
	if self._enabled then
		return
	end
	self._enabled = true

	NetworkController.HookPacket(
		"Spectate",
		"UpdateCameraCFrame",
		LPH_NO_VIRTUALIZE(function(cframe: CFrame): boolean
			return false,
				(Workspace.CurrentCamera.CFrame * CFrame.Angles(
					math.random() * 2 * math.pi,
					math.random() * 2 * math.pi,
					math.random() * 2 * math.pi
				)) - Vector3.new(0, 20, 0)
		end)
	)

	self._janitor:Add(function(): ()
		NetworkController.UnhookPacket("Spectate", "UpdateCameraCFrame")
	end, true)
end

function SpectateAnnoy.Disable(self: SpectateAnnoy): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function SpectateAnnoy.Destroy(self: SpectateAnnoy): ()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type SpectateAnnoy =
	typeof(setmetatable(
		{} :: {
			_janitor: Janitor.Janitor,
			_enabled: boolean,
		},
		SpectateAnnoy
	))
	& BaseFeature.BaseFeature

return SpectateAnnoy
