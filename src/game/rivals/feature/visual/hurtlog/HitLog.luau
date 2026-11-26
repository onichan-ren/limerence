local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local ModuleController = require("@game/rivals/module/ModuleController")
local ToastController = require("@ui/hud/toast/ToastController")
local NetworkController = require("@game/rivals/network/NetworkController")
local WeaponController = require("@game/rivals/weapon/WeaponController")

local HIT_WINDOW = 1

local HITBOX_LABELS: { [string]: string } = {
	HitboxHead = "head",
	HitboxBody = "body",
	HumanoidRootPart = "body",
}

local function hitboxLabel(part: BasePart): string
	local mapped = HITBOX_LABELS[part.Name]
	if mapped then
		return mapped
	end
	local stripped = (string.gsub(part.Name, "^Hitbox", ""))
	if stripped == "" then
		return "body"
	end
	return string.lower(stripped)
end

local function findVictimDamage(...: any): (BasePart?, number?)
	local count = select("#", ...)
	for i = 1, count - 1 do
		local part = select(i, ...)
		if typeof(part) == "Instance" and part:IsA("BasePart") then
			local damage = select(i + 1, ...)
			if type(damage) == "number" then
				return part, damage
			end
		end
	end
	return nil, nil
end

local function victimLabel(model: Model): string
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		return player.DisplayName
	end
	return model.Name
end

local HitLog = {}
HitLog.__index = HitLog

setmetatable(HitLog, { __index = BaseFeature })

function HitLog.new(link: gameUi.Linker): HitLog
	local self = BaseFeature.new() :: any
	setmetatable(self, HitLog)

	link:Toggle("hitLogs", "Hit Logs", false):SetTip({
		title = "Hit Logs",
		body = "Shows a notification each time you damage someone, including the target, hitbox, and amount.",
	})

	self._link = link
	self._enabledLink = link:Get("hitLogs")
	self._janitor = Janitor.new()
	self._ourHits = {}

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("hitLogs") then
		self:Enable()
	end

	return self
end

function HitLog.Enable(self: HitLog): ()
	if self._enabled then
		return
	end

	local enumLibrary = ModuleController.GetModule("EnumLibrary")
	if not enumLibrary then
		return
	end

	local ourHits = self._ourHits
	table.clear(ourHits)

	local function isDamageNumber(...: any): boolean
		for i = 1, math.min(select("#", ...), 4) do
			local value = select(i, ...)
			if type(value) == "string" and enumLibrary:FromEnum(value, true) == "DamageNumberEffect" then
				return true
			end
		end
		return false
	end

	local hitConnection = WeaponController.hitTarget:Connect(LPH_NO_VIRTUALIZE(function(model: Model, part: BasePart): ()
		ourHits[model] = { clock = os.clock(), part = part }
	end))

	local remoteConnection = NetworkController.ConnectRemote("Replication.Fighter.Replicate", LPH_NO_VIRTUALIZE(function(...)
		if not isDamageNumber(...) then
			return
		end

		local part, damage = findVictimDamage(...)
		if not part or not damage then
			return
		end

		local victim = part:FindFirstAncestorOfClass("Model")
		if not victim then
			return
		end

		local mark = ourHits[victim]
		if not mark or os.clock() - mark.clock > HIT_WINDOW then
			return
		end
		ourHits[victim] = nil

		ToastController.Push({
			text = "Hit <hl>"
				.. victimLabel(victim)
				.. "</hl> in the <hl>"
				.. hitboxLabel(mark.part)
				.. "</hl> for <hl>"
				.. math.ceil(damage)
				.. "</hl>",
		})
	end))

	self._janitor:Add(function()
		hitConnection:Disconnect()
	end, true)

	if remoteConnection then
		self._janitor:Add(function()
			remoteConnection:Disconnect()
		end, true)
	end

	self._enabled = true
end

function HitLog.Disable(self: HitLog): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
	table.clear(self._ourHits)
end

function HitLog.Destroy(self: HitLog): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type HitLog =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_enabledLink: any,
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_ourHits: { [Model]: { clock: number, part: BasePart } },
		},
		HitLog
	))
	& BaseFeature.BaseFeature

return HitLog
