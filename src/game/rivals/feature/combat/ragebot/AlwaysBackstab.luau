local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local NetworkController = require("@game/rivals/network/NetworkController")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local ClientState = require("@game/rivals/client/clientState")
local PlayerController = require("@feature/player/PlayerController")

local peek = Charm.peek

local CAMERA_ROTATION_PATH = "Replication.Fighter.UpdateCameraRotation"

local AlwaysBackstab = {}
AlwaysBackstab.__index = AlwaysBackstab

setmetatable(AlwaysBackstab, { __index = BaseFeature })

local TAU = math.pi * 2
local FALLBACK_OFFSET = 128

local function headingBytes(look: Vector3): number
	return math.atan2(look.X, look.Z) / TAU * 256
end

function AlwaysBackstab.new(link: gameUi.Linker): AlwaysBackstab
	local self = BaseFeature.new() :: any
	setmetatable(self, AlwaysBackstab)

	link:Toggle("alwaysBackstab", "Always Backstab", false):SetTip({
		title = "Always Backstab",
		body = "Knife hits always register as backstabs. Your body looks turned to others while a knife is held.",
	})

	self._link = link
	self._enabledLink = link:Get("alwaysBackstab")
	self._janitor = Janitor.new()

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("alwaysBackstab") then
		self:Enable()
	end

	return self
end

function AlwaysBackstab._closestEnemyLook(self: AlwaysBackstab, origin: Vector3): Vector3?
	local localTeam = peek(ClientState.team)
	local bestLook: Vector3? = nil
	local bestDistSq = math.huge

	for _, playerData in next, PlayerController.GetAll() do
		if not peek(playerData.alive) then
			continue
		end
		local team = peek(playerData.team)
		if localTeam and localTeam ~= "" and team == localTeam then
			continue
		end
		local hrp = peek(playerData.hrp) :: BasePart?
		if not hrp then
			continue
		end
		local delta = hrp.Position - origin
		local distSq = delta:Dot(delta)
		if distSq < bestDistSq then
			bestDistSq = distSq
			bestLook = hrp.CFrame.LookVector
		end
	end

	return bestLook
end

function AlwaysBackstab._computeOffsetBytes(self: AlwaysBackstab): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return FALLBACK_OFFSET
	end
	local ourCF = camera.CFrame
	local targetLook = self:_closestEnemyLook(ourCF.Position)
	if not targetLook then
		return FALLBACK_OFFSET
	end
	return headingBytes(targetLook) - headingBytes(ourCF.LookVector)
end

function AlwaysBackstab._spoof(self: AlwaysBackstab, encoded: any): (boolean, any?)
	if type(encoded) ~= "string" or #encoded == 0 then
		return true
	end
	if not WeaponController.IsMelee() then
		return true
	end

	local b1, b2 = utf8.codepoint(encoded, 1, #encoded)
	if type(b1) ~= "number" or type(b2) ~= "number" then
		return true
	end

	local newB1 = math.floor(b1 + self:_computeOffsetBytes() + 0.5) % 256
	return false, utf8.char(newB1) .. utf8.char(b2), nil
end

function AlwaysBackstab.Enable(self: AlwaysBackstab): ()
	if self._enabled then
		return
	end
	NetworkController.HookRemote(CAMERA_ROTATION_PATH, function(encoded: any): (boolean, any?)
		return self:_spoof(encoded)
	end, "FireServer")
	self._janitor:Add(function()
		NetworkController.UnhookRemote(CAMERA_ROTATION_PATH)
	end, true)
	self._enabled = true
end

function AlwaysBackstab.Disable(self: AlwaysBackstab): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function AlwaysBackstab.Destroy(self: AlwaysBackstab): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AlwaysBackstab =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_enabledLink: any,
			_enabled: boolean,
			_janitor: Janitor.Janitor,
		},
		AlwaysBackstab
	))
	& BaseFeature.BaseFeature

return AlwaysBackstab
