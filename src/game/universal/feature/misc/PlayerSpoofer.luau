local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local spoofEngine = require("@game/universal/feature/misc/spoofEngine")

local LocalPlayer = Players.LocalPlayer

local ADJECTIVES = {
	"Shadow",
	"Crimson",
	"Frost",
	"Silent",
	"Rapid",
	"Toxic",
	"Golden",
	"Cyber",
	"Nova",
	"Iron",
	"Lunar",
	"Solar",
	"Phantom",
	"Royal",
	"Static",
	"Velvet",
	"Hollow",
	"Savage",
	"Mystic",
	"Neon",
	"Arctic",
	"Ember",
	"Cosmic",
	"Vivid",
	"Rogue",
	"Quiet",
	"Atomic",
	"Lucky",
	"Wild",
	"Dusk",
	"Echo",
	"Prime",
}

local NOUNS = {
	"Wolf",
	"Falcon",
	"Viper",
	"Ghost",
	"Raven",
	"Tiger",
	"Comet",
	"Reaper",
	"Hawk",
	"Cobra",
	"Drift",
	"Blaze",
	"Storm",
	"Saint",
	"Pulse",
	"Fox",
	"Knight",
	"Bear",
	"Shark",
	"Lynx",
	"Crow",
	"Dragon",
	"Specter",
	"Bolt",
	"Hunter",
	"Sniper",
	"Rider",
	"Warden",
	"Jester",
	"Nomad",
	"Titan",
	"Striker",
}

local function cleanInput(value: any): string
	if type(value) ~= "string" then
		return ""
	end
	return string.match(value, "^%s*(.-)%s*$") or ""
end

local generateIdentity = LPH_NO_VIRTUALIZE(function(userId: number, customName: string): (string, string, string)
	local rng = Random.new(userId)
	local adjective = ADJECTIVES[rng:NextInteger(1, #ADJECTIVES)]
	local noun = NOUNS[rng:NextInteger(1, #NOUNS)]
	local suffix = rng:NextInteger(0, 9999)
	local fakeId = tostring(rng:NextInteger(100000000, 2900000000))

	if customName ~= "" then
		local username = customName .. tostring(suffix)
		return username, username, fakeId
	end

	local username = adjective .. noun .. tostring(suffix)
	local displayName = adjective .. " " .. noun
	return username, displayName, fakeId
end)

local buildSet = LPH_NO_VIRTUALIZE(function(restore: boolean, customName: string): spoofEngine.ReplacementSet
	local set = spoofEngine.newSet()

	for _, player in next, Players:GetPlayers() do
		if player ~= LocalPlayer then
			local realName = player.Name
			local realDisplay = player.DisplayName
			local realId = tostring(player.UserId)
			local fakeName, fakeDisplay, fakeId = generateIdentity(player.UserId, customName)

			local fromName, toName = realName, fakeName
			local fromDisplay, toDisplay = realDisplay, fakeDisplay
			local fromId, toId = realId, fakeId
			if restore then
				fromName, toName = fakeName, realName
				fromDisplay, toDisplay = fakeDisplay, realDisplay
				fromId, toId = fakeId, realId
			end

			spoofEngine.addExactText(set, fromDisplay, toDisplay)
			if #fromDisplay >= 3 then
				spoofEngine.addFragment(set.textFragments, fromDisplay, toDisplay)
			end

			spoofEngine.addExactText(set, fromName, toName)
			spoofEngine.addExactText(set, "@" .. fromName, "@" .. toName)
			if #fromName >= 3 then
				spoofEngine.addFragment(set.textFragments, fromName, toName)
			end

			spoofEngine.addExactText(set, fromId, toId)
			spoofEngine.addFragment(set.idFragments, fromId, toId)
			spoofEngine.addFragment(set.imageIds, fromId, toId)
		end
	end

	spoofEngine.sortFragments(set.textFragments)
	spoofEngine.sortFragments(set.idFragments)
	spoofEngine.sortFragments(set.imageIds)
	return set
end)

local PlayerSpoofer = {}
PlayerSpoofer.__index = PlayerSpoofer

setmetatable(PlayerSpoofer, { __index = BaseFeature })

function PlayerSpoofer.new(link: gameUi.Linker): PlayerSpoofer
	local self = BaseFeature.new() :: any
	setmetatable(self, PlayerSpoofer)

	link:Toggle("playerSpoofer", "Player Spoofer", false):SetTip({
		title = "Player Spoofer",
		body = "Hides every other player's name and avatar.",
	})
	local playerSpooferLink = link:OnKey("playerSpoofer")
	playerSpooferLink:Submenu("opts", "Player Spoofer")
	local optionsLink = playerSpooferLink:OnKey("opts")
	optionsLink:Textbox("name", "Player Name", "", "Random"):SetTip({
		title = "Player Name",
		body = "Name to show for every other player. Leave empty for random names.",
	})

	self._binder = spoofEngine.new()
	self._janitor = Janitor.new()
	self._customName = ""
	self._appliedName = ""
	self._rebuildQueued = false
	self._refreshQueued = false

	self:Track(link:Get("playerSpoofer"):OnChange(function(value: boolean)
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(link:Watch("playerSpoofer.opts.name", function(value: string)
		self._customName = cleanInput(value)
		self:_queueRefresh()
	end))

	return self
end

function PlayerSpoofer._queueRebuild(self: PlayerSpoofer): ()
	if not self._enabled or self._rebuildQueued then
		return
	end
	self._rebuildQueued = true
	task.defer(function(): ()
		self._rebuildQueued = false
		if self._enabled then
			self._binder:SetReplacements(buildSet(false, self._appliedName))
		end
	end)
end

function PlayerSpoofer._queueRefresh(self: PlayerSpoofer): ()
	if self._refreshQueued then
		return
	end
	self._refreshQueued = true
	task.defer(function(): ()
		self._refreshQueued = false
		if not self._enabled or self._customName == self._appliedName then
			return
		end
		self._binder:SetReplacements(buildSet(true, self._appliedName))
		self._binder:Patch()
		self._appliedName = self._customName
		self._binder:SetReplacements(buildSet(false, self._appliedName))
		self._binder:Patch()
	end)
end

function PlayerSpoofer.Enable(self: PlayerSpoofer): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._janitor:Add(
		Players.PlayerAdded:Connect(function(): ()
			self:_queueRebuild()
		end),
		"Disconnect"
	)

	self._janitor:Add(
		Players.PlayerRemoving:Connect(function(): ()
			self:_queueRebuild()
		end),
		"Disconnect"
	)

	self._appliedName = self._customName
	self._binder:SetReplacements(buildSet(false, self._appliedName))
	self._binder:Start()
end

function PlayerSpoofer.Disable(self: PlayerSpoofer): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()

	self._binder:SetReplacements(buildSet(true, self._appliedName))
	self._binder:Patch()
	self._binder:Stop()
end

function PlayerSpoofer.Destroy(self: PlayerSpoofer): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type PlayerSpoofer =
	typeof(setmetatable(
		{} :: {
			_binder: spoofEngine.Binder,
			_janitor: Janitor.Janitor,
			_customName: string,
			_appliedName: string,
			_rebuildQueued: boolean,
			_refreshQueued: boolean,
			_enabled: boolean,
			_queueRebuild: (PlayerSpoofer) -> (),
			_queueRefresh: (PlayerSpoofer) -> (),
		},
		PlayerSpoofer
	))
	& BaseFeature.BaseFeature

return PlayerSpoofer
