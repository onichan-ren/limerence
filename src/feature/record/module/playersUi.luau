local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")
local Janitor = require("@pkg/Janitor")

local Players = cloneref(game:GetService("Players")) :: Players

local Table = require("@ui/window/element/table/Table")
local Badge = require("@ui/window/element/badge")
local StatusPlaceholder = require("@ui/window/element/statusPlaceholder")

local playerState = require("@feature/record/module/playerState")
local recordsStore = require("@feature/record/module/recordsStore")
local playerDetailPanel = require("@feature/record/module/playerDetailPanel")

local e = React.createElement
local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe

type LivePlayer = {
	player: Player,
	userId: number,
	username: string,
	displayName: string,
}

local function buildLiveRow(live: LivePlayer): { [string]: any }
	local record = recordsStore.Get(live.userId)
	return {
		userId = live.userId,
		username = live.username,
		displayName = live.displayName,
		state = playerState.GetState(live.userId),
		note = record and record.note or nil,
	}
end

local function avatarThumbnail(userId: number): string
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

return function(tab: any): ()
	if not tab then
		return
	end

	local section = tab:AddSection("PLAYERS", 1)

	local livePlayers: Charm.Atom<{ [number]: LivePlayer }> = at({})

	local columns: { Table.Column } = {
		{
			id = "avatar",
			name = "",
			weight = 0.6,
			align = "center",
			renderer = function(row: { [string]: any }): any
				return e("ImageLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Image = avatarThumbnail(tonumber(row.userId) or 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(20, 20),
				}, {
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(1, 0),
					}),
				})
			end,
		},
		{
			id = "username",
			name = "Username",
			weight = 2.4,
			align = "left",
			sortable = true,
			searchValue = function(row: { [string]: any }): string
				return tostring(row.username or "")
			end,
		},
		{
			id = "displayName",
			name = "Display Name",
			weight = 2.4,
			align = "left",
			sortable = true,
			searchValue = function(row: { [string]: any }): string
				return tostring(row.displayName or "")
			end,
		},
		{
			id = "userId",
			name = "User ID",
			weight = 1.6,
			align = "left",
			sortable = true,
			sortKey = function(row: { [string]: any }): number
				return tonumber(row.userId) or 0
			end,
		},
		{
			id = "state",
			name = "State",
			weight = 2,
			align = "left",
			sortable = true,
			sortKey = function(row: { [string]: any }): string
				local def = playerState.Get(row.state)
				return def and def.label or "zzzz"
			end,
			searchValue = function(row: { [string]: any }): string
				local def = playerState.Get(row.state)
				return def and def.label or ""
			end,
			renderer = function(row: { [string]: any }): any
				local def = playerState.Get(row.state)
				if not def then
					return e(StatusPlaceholder, { Align = "left" })
				end
				return e(Badge, {
					Label = def.label,
					Color = def.color,
					Icon = def.icon,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
				})
			end,
		},
	}

	local playersTable = section:AddElement("Table", "Live players", columns) :: any
	playersTable:SetRowKey("userId")
	playersTable:SetEmptyText("No players in server")
	playersTable:SetMaxHeight(280)
	playersTable:SetShowPagination(false)
	playersTable:SetShowSearch(true)
	playersTable:SetSearchPlaceholder("Search players...")
	playersTable:SetSort("username", "asc")

	local function refreshRows(): ()
		local rows: { { [string]: any } } = {}
		for _, live in next, peek(livePlayers) do
			table.insert(rows, buildLiveRow(live))
		end
		playersTable:SetRows(rows)
	end

	playersTable:SetRowDetail(function(row: { [string]: any }): any
		local live = peek(livePlayers)[tonumber(row.userId) or 0]
		if not live then
			return nil
		end
		return e(playerDetailPanel.Panel, {
			Player = live.player,
			UserId = live.userId,
		})
	end)

	playersTable:SetRowDetailHeight(function(row: { [string]: any }): number
		local live = peek(livePlayers)[tonumber(row.userId) or 0]
		if not live then
			return 0
		end
		return playerDetailPanel.ComputeHeight(live.player, live.userId)
	end)

	local janitor = Janitor.new()

	local function addPlayer(player: Player): ()
		if player == Players.LocalPlayer then
			return
		end
		local current = peek(livePlayers)
		if current[player.UserId] then
			return
		end
		local live: LivePlayer = {
			player = player,
			userId = player.UserId,
			username = player.Name,
			displayName = player.DisplayName,
		}
		livePlayers(Sift.Dictionary.set(current, player.UserId, live))
		refreshRows()
	end

	local function removePlayer(player: Player): ()
		local current = peek(livePlayers)
		if not current[player.UserId] then
			return
		end
		livePlayers(Sift.Dictionary.removeKey(current, player.UserId))
		refreshRows()
	end

	janitor:Add(Players.PlayerAdded:Connect(addPlayer), "Disconnect")
	janitor:Add(Players.PlayerRemoving:Connect(removePlayer), "Disconnect")
	janitor:Add(sub(recordsStore.GetAtom(), function()
		refreshRows()
	end))
	janitor:Add(playerState.SubscribeAssignments(function()
		refreshRows()
	end))

	for _, player in next, Players:GetPlayers() do
		addPlayer(player)
	end
end
