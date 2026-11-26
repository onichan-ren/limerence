local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local NotifyController = require("@ui/hud/notify/NotifyController")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local Players = cloneref(game:GetService("Players")) :: Players
local GroupService = cloneref(game:GetService("GroupService")) :: GroupService

local LocalPlayer = Players.LocalPlayer
local peek = Charm.peek

local GROUP_ID = 95076810
local ROLE_RANKS: { [number]: string } = {
	[4] = "Content Creator",
	[5] = "Star Creator",
	[6] = "Tester",
	[9] = "Contributor",
	[11] = "Staff",
	[12] = "Staff",
	[253] = "Developer",
	[254] = "Owner",
	[255] = "Owner",
}
local ROLES = {
	"Content Creator",
	"Star Creator",
	"Contributor",
	"Developer",
	"Tester",
	"Staff",
	"Owner",
}

local StaffDetector = {}
StaffDetector.__index = StaffDetector

setmetatable(StaffDetector, { __index = BaseFeature })

local function hasRole(roles: any, role: string): boolean
	if type(roles) ~= "table" then
		return false
	end
	for _, value in next, roles do
		if value == role then
			return true
		end
	end
	return false
end

function StaffDetector.new(link: gameUi.Linker): StaffDetector
	local self = BaseFeature.new() :: any
	setmetatable(self, StaffDetector)

	self._enabled = false
	self._janitor = Janitor.new()
	self._checked = {} :: { [number]: boolean }
	self._generation = 0

	link:Toggle("staffDetector", "Staff Detector", true):SetTip({
		title = "Staff Detector",
		body = "Responds when an Overkill staff member joins.",
	})

	local root = link:OnKey("staffDetector")
	root:Submenu("settings", "Staff Detector")
	local settings = root:OnKey("settings")
	settings:Dropdown("notifyRoles", "Notify Roles", ROLES, table.clone(ROLES)):SetMode("multi"):SetTip({
		title = "Notify Roles",
		body = "Roles that trigger a notification when detected.",
	})
	settings:Dropdown("kickRoles", "Kick Roles", ROLES, { "Developer", "Staff" }):SetMode("multi"):SetTip({
		title = "Kick Roles",
		body = "Roles that kick you from the game when detected.",
	})

	self._notifyRoles = settings:Get("notifyRoles")
	self._kickRoles = settings:Get("kickRoles")

	self:Track(link:Get("staffDetector"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("staffDetector") then
		self:Enable()
	end

	return self
end

function StaffDetector._check(self: StaffDetector, player: Player): ()
	if not self._enabled then
		return
	end

	local checked = self._checked :: { [number]: boolean }
	if player == LocalPlayer or checked[player.UserId] then
		return
	end
	checked[player.UserId] = true

	local generation = self._generation
	task.spawn(function(): ()
		local role: string? = nil
		local groups = GroupService:GetGroupsAsync(player.UserId)
		for i = 1, #groups do
			local group = groups[i]
			if group.Id == GROUP_ID then
				role = ROLE_RANKS[group.Rank]
				break
			end
		end
		if not role then
			return
		end
		if not self._enabled or generation ~= self._generation then
			return
		end

		if hasRole(peek(self._notifyRoles), role) then
			NotifyController.Push({
				title = "Staff Detected",
				subtext = `{player.DisplayName} ({role})`,
				icon = "person",
				duration = 5,
			})
		end
		if hasRole(peek(self._kickRoles), role) then
			LocalPlayer:Kick(`[limerence.biz]\n\nStaff detected: {player.Name} ({role})`)
		end
	end)
end

function StaffDetector.Enable(self: StaffDetector): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._generation += 1
	local checked = self._checked :: { [number]: boolean }
	table.clear(checked)

	self._janitor:Add(
		Players.PlayerAdded:Connect(function(player: Player): ()
			self:_check(player)
		end),
		"Disconnect",
		"playerAdded"
	)
	self._janitor:Add(
		Players.PlayerRemoving:Connect(function(player: Player): ()
			checked[player.UserId] = nil
		end),
		"Disconnect",
		"playerRemoving"
	)

	for _, player in next, Players:GetPlayers() do
		self:_check(player)
	end
end

function StaffDetector.Disable(self: StaffDetector): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._generation += 1
	self._janitor:Cleanup()
	local checked = self._checked :: { [number]: boolean }
	table.clear(checked)
end

function StaffDetector.Destroy(self: StaffDetector): ()
	self:Disable()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type StaffDetector =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor,
			_checked: { [number]: boolean },
			_generation: number,
			_notifyRoles: any,
			_kickRoles: any,
		},
		StaffDetector
	))
	& BaseFeature.BaseFeature

return StaffDetector
