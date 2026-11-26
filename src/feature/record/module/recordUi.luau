local React = require("@pkg/React")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local FileController = require("@feature/file/FileController")
local contextApi = require("@ui/subwindow/context/contextApi")
local SubwindowController = require("@ui/subwindow/SubwindowController")
local NotifyController = require("@ui/hud/notify/NotifyController")
local cursorUtil = require("@ui/util/cursor")

local Table = require("@ui/window/element/table/Table")
local Badge = require("@ui/window/element/badge")
local StatusPlaceholder = require("@ui/window/element/statusPlaceholder")

local playerState = require("@feature/record/module/playerState")
local recordsStore = require("@feature/record/module/recordsStore")

local e = React.createElement
local sub = Charm.subscribe

local function avatarThumbnail(userId: number): string
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

local function formatRelative(timestamp: number?): string
	if not timestamp or timestamp == 0 then
		return "—"
	end
	local diff = math.max(0, os.time() - timestamp)
	if diff < 60 then
		return "just now"
	elseif diff < 3600 then
		return string.format("%dm ago", math.floor(diff / 60))
	elseif diff < 86400 then
		return string.format("%dh ago", math.floor(diff / 3600))
	end
	return string.format("%dd ago", math.floor(diff / 86400))
end

return function(tab: any): ()
	if not tab then
		return
	end

	local section = tab:AddSection("RECORDS", 1)

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
			weight = 2,
			align = "left",
			sortable = true,
		},
		{
			id = "displayName",
			name = "Display Name",
			weight = 2,
			align = "left",
			sortable = true,
		},
		{
			id = "userId",
			name = "User ID",
			weight = 1.4,
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
		{
			id = "note",
			name = "Note",
			weight = 2.4,
			align = "left",
			formatter = function(value: any): string
				local note = tostring(value or "")
				if note == "" then
					return "—"
				end
				return note
			end,
			searchValue = function(row: { [string]: any }): string
				return tostring(row.note or "")
			end,
		},
		{
			id = "updatedAt",
			name = "Edited",
			weight = 1.2,
			align = "left",
			sortable = true,
			sortKey = function(row: { [string]: any }): number
				return tonumber(row.updatedAt) or 0
			end,
			formatter = function(value: any): string
				return formatRelative(tonumber(value))
			end,
		},
	}

	local recordsTable = section:AddElement("Table", "Saved records", columns) :: any
	recordsTable:SetRowKey("userId")
	recordsTable:SetEmptyText("No records saved")
	recordsTable:SetMaxHeight(400)
	recordsTable:SetShowPagination(false)
	recordsTable:SetShowSearch(true)
	recordsTable:SetSearchPlaceholder("Search records...")
	recordsTable:SetSort("updatedAt", "desc")

	local function refreshRows(): ()
		local rows: { { [string]: any } } = {}
		for _, record in next, recordsStore.GetAll() do
			rows[#rows + 1] = {
				userId = record.userId,
				username = record.username,
				displayName = record.displayName,
				state = playerState.GetState(record.userId),
				note = record.note,
				updatedAt = record.updatedAt,
			}
		end
		recordsTable:SetRows(rows)
	end

	local function getSelectedRecord(): { [string]: any }?
		return recordsTable:GetSelectedRow()
	end

	local setStateButton = section:AddElement("Button", "Set State") :: any
	setStateButton:SetIcon(FileController.Get("image", "set_state"))
	local editNoteButton = setStateButton:Combine("Edit Note", FileController.Get("image", "pencil"))
	local deleteButton = setStateButton:Combine("Delete", FileController.Get("image", "delete"))
	local copyProfileLinkButton = setStateButton:Combine("Copy Profile Link")
	copyProfileLinkButton:SetIcon(FileController.Get("image", "copy_link"))

	deleteButton:RequireConfirm("Confirm Delete?", 3)

	setStateButton:OnClick(function()
		local row = getSelectedRecord()
		if not row then
			return
		end
		local userId = tonumber(row.userId) or 0

		local items: { contextApi.ContextItem } = {}
		for _, def in next, playerState.GetAll() do
			local active = row.state == def.id
			table.insert(items, {
				Label = def.label,
				Icon = active and FileController.Get("image", "checkmark") or nil,
				Callback = function()
					local nextState: string? = (not active and def.id or nil)
					playerState.SetState(userId, nextState)
					refreshRows()
				end,
			})
		end

		table.insert(items, { Divider = true })
		table.insert(items, {
			Label = "Clear State",
			Callback = function()
				playerState.SetState(userId, nil)
				refreshRows()
			end,
		})

		contextApi.Open(items, cursorUtil.getPosition())
	end)

	editNoteButton:OnClick(function()
		local row = getSelectedRecord()
		if not row then
			return
		end
		local userId = tonumber(row.userId) or 0
		local username = tostring(row.username or "")
		local displayName = tostring(row.displayName or username)

		SubwindowController.OpenRecordEditor({
			title = displayName,
			subtitle = `@{username} · {userId}`,
			noteValue = tostring(row.note or ""),
			notePlaceholder = "Add a note about this player...",
			onSave = function(note: string): ()
				recordsStore.Update(userId, {
					note = note ~= "" and note or nil,
				})
				refreshRows()
			end,
		})
	end)

	deleteButton:OnClick(function()
		local row = getSelectedRecord()
		if not row then
			return
		end
		local userId = tonumber(row.userId) or 0
		local username = tostring(row.username or "")

		recordsStore.Delete(userId)
		refreshRows()

		NotifyController.Push({
			title = "Deleted record",
			subtext = `@{username} · {row.displayName}`,
			duration = 2,
		})
	end)

	copyProfileLinkButton:OnClick(function()
		local row = getSelectedRecord()
		if not row then
			return
		end
		setclipboard(`https://www.roblox.com/users/{row.userId}/profile`)
		NotifyController.Push({
			title = "Copied profile link",
			subtext = `@{row.username} · {row.displayName}`,
			icon = "copy",
			duration = 2,
		})
	end)

	local janitor = Janitor.new()
	janitor:Add(sub(recordsStore.GetAtom(), function()
		refreshRows()
	end))
	janitor:Add(playerState.SubscribeAssignments(function()
		refreshRows()
	end))

	refreshRows()
end
