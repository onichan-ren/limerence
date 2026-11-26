local Players = cloneref(game:GetService("Players")) :: Players

local NetworkController = require("@game/bloxstrike/network/NetworkController")
local BaseFeature = require("@game/BaseFeature")
local Janitor = require("@pkg/Janitor")
local gameUi = require("@game/gameUi")
local clientState = require("@game/bloxstrike/client/clientState")
local Charm = require("@pkg/Charm")

local sub = Charm.subscribe

local LocalPlayer = Players.LocalPlayer
local WALK_ATTRIBUTE = "IsWalking"
local PACKET_TYPE = "Character"
local PACKET_NAME = "UpdateWalkState"

local function ensureWalking(): ()
	if LocalPlayer:GetAttribute(WALK_ATTRIBUTE) ~= true then
		setthreadidentity(2)
		NetworkController.SendPacket(PACKET_TYPE, PACKET_NAME, true)
		setthreadidentity(8)
	end
end

local RemoveFootsteps = {}
RemoveFootsteps.__index = RemoveFootsteps

setmetatable(RemoveFootsteps, { __index = BaseFeature })

function RemoveFootsteps.new(link: gameUi.Linker): RemoveFootsteps
	local self = BaseFeature.new() :: any
	setmetatable(self, RemoveFootsteps)

	self._janitor = Janitor.new()

	link:Toggle("removeFootsteps", "Remove Footsteps", false):SetTip({
		title = "Remove Footsteps",
		body = "Stops enemies from hearing your footsteps. Your movement speed is unaffected.",
	})

	self:Track(link:Get("removeFootsteps"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("removeFootsteps") then
		self:Enable()
	end

	return self
end

function RemoveFootsteps.Enable(self: RemoveFootsteps): ()
	if self._enabled then
		return
	end
	self._enabled = true

	NetworkController.HookPacket(
		PACKET_TYPE,
		PACKET_NAME,
		LPH_NO_VIRTUALIZE(function(value: boolean): boolean
			return value == true
		end)
	)

	ensureWalking()

	self._janitor:Add(LocalPlayer:GetAttributeChangedSignal(WALK_ATTRIBUTE):Connect(ensureWalking))
	self._janitor:Add(
		sub(clientState.character, function(): ()
			task.defer(ensureWalking)
		end),
		true
	)
end

function RemoveFootsteps.Disable(self: RemoveFootsteps): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self._janitor:Cleanup()
	NetworkController.UnhookPacket(PACKET_TYPE, PACKET_NAME)
	setthreadidentity(2)
	NetworkController.SendPacket(PACKET_TYPE, PACKET_NAME, false)
	setthreadidentity(8)
end

function RemoveFootsteps.Destroy(self: RemoveFootsteps): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type RemoveFootsteps =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor,
		},
		RemoveFootsteps
	))
	& BaseFeature.BaseFeature

return RemoveFootsteps
