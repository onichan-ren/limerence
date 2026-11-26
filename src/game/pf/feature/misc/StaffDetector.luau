local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local NotifyController = require("@ui/hud/notify/NotifyController")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local Players = cloneref(game:GetService("Players")) :: Players

local LocalPlayer = Players.LocalPlayer
local peek = Charm.peek

local GROUP_ID = 1103278
local NON_STAFF_RANKS: { [string]: boolean } = {
	Guest = true,
	Supporters = true,
	Contributors = true,
}

local StaffDetector = {}
StaffDetector.__index = StaffDetector

setmetatable(StaffDetector, { __index = BaseFeature })

local function hasAction(actions: any, action: string): boolean
	if type(actions) ~= "table" then
		return false
	end
	for _, value in next, actions do
		if value == action then
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
		body = "Responds when a Phantom Forces staff member joins.",
	})

	local root = link:OnKey("staffDetector")
	root:Submenu("settings", "Staff Detector")
	local settings = root:OnKey("settings")
	settings:Dropdown("actions", "Action", { "Notify", "Kick" }, { "Notify" }):SetMode("multi"):SetTip({
		title = "Action",
		body = "Choose what happens when a staff member is detected.",
	})

	self._actions = settings:Get("actions")

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
		local rank = player:GetRoleInGroup(GROUP_ID)
		if type(rank) ~= "string" or NON_STAFF_RANKS[rank] then
			return
		end
		if not self._enabled or generation ~= self._generation then
			return
		end

		local actions = peek(self._actions)
		if hasAction(actions, "Notify") then
			NotifyController.Push({
				title = "Staff Detected",
				subtext = `{player.DisplayName} ({rank})`,
				icon = "person",
				duration = 5,
			})
		end
		if hasAction(actions, "Kick") then
			LocalPlayer:Kick(`[limerence.biz]\n\nStaff detected: {player.Name} ({rank})`)
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
			_actions: any,
		},
		StaffDetector
	))
	& BaseFeature.BaseFeature

return StaffDetector
