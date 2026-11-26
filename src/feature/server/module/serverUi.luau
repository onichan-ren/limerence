local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")
local UIController = require("@ui/UIController")
local FileController = require("@feature/file/FileController")
local uiRegistry = require("@ui/uiRegistry")
local contextApi = require("@ui/subwindow/context/contextApi")
local Table = require("@ui/window/element/table/Table")
local themeState = require("@ui/theme/themeState")
local serverDataSource = require("@feature/server/module/serverDataSource")
local NotifyController = require("@ui/hud/notify/NotifyController")

local Players = cloneref(game:GetService("Players")) :: Players
local TeleportService = cloneref(game:GetService("TeleportService")) :: TeleportService

local e = React.createElement
local useAt = ReactCharm.useAtom

local PING_GOOD = 80
local PING_OKAY = 150

local function pingColorAtom(value: number?): any
	local status = themeState.colors.status
	if value == nil then
		return status.neutral
	end
	if value <= PING_GOOD then
		return status.good
	end
	if value <= PING_OKAY then
		return status.warning
	end
	return status.danger
end

local function formatPlayers(value: any, row: { [string]: any }): string
	local playing = tonumber(value) or 0
	local maxPlayers = tonumber(row.maxPlayers) or 0
	return string.format("%d / %d", playing, maxPlayers)
end

local function formatPing(value: any): string
	local ping = tonumber(value)
	if not ping then
		return "—"
	end
	return string.format("%d ms", math.floor(ping))
end

local function formatFps(value: any): string
	local fps = tonumber(value)
	if not fps then
		return "—"
	end
	return tostring(math.floor(fps))
end

local function formatServerId(value: any): string
	local id = tostring(value or "")
	if #id <= 12 then
		return id
	end
	return string.sub(id, 1, 8) .. "…"
end

local function PingText(props: { Value: any }): any
	local ping = tonumber(props.Value)
	local color = useAt(pingColorAtom(ping))
	return e("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = FileController.Get("font", "semi_bold"),
		TextColor3 = color,
		TextSize = 12,
		Text = formatPing(props.Value),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.fromScale(1, 1),
	})
end

local function renderPing(_row: { [string]: any }, value: any): any
	return e(PingText, { Value = value })
end

local function joinServer(serverId: string?): ()
	if not serverId or serverId == "" then
		return
	end
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return
	end
	pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, localPlayer)
	end)
end

return function(ServerController: any): ()
	local window = UIController.GetMainWindow()
	if not window then
		return
	end

	local group = window:GetTabGroup("COMMON")
	if not group then
		return
	end

	local tab = uiRegistry.add(
		group:AddTab("Servers", FileController.Get("image", "server") :: string, {
			containers = 1,
		}),
		{ kind = "tab" }
	)

	local serversSection = tab:AddSection("SERVERS", 1)

	local columns: { Table.Column } = {
		{
			id = "id",
			name = "Server",
			weight = 3,
			align = "left",
			formatter = function(value: any): string
				return formatServerId(value)
			end,
		},
		{
			id = "playing",
			name = "Players",
			weight = 2,
			align = "center",
			formatter = formatPlayers,
		},
		{
			id = "ping",
			name = "Ping",
			weight = 1.4,
			align = "center",
			renderer = renderPing,
		},
		{
			id = "fps",
			name = "FPS",
			weight = 1.4,
			align = "center",
			formatter = formatFps,
		},
	}

	local serverTable = serversSection:AddElement("Table", "Servers", columns) :: any
	serverTable:SetRowKey("id")
	serverTable:SetEmptyText("No servers found")
	serverTable:SetLoadingText("Fetching servers...")
	serverTable:SetMaxHeight(360)
	serverTable:SetDataSource(serverDataSource.makeSource(game.PlaceId))

	local joinButton = serversSection:AddElement("Button", "Join Server") :: any
	joinButton:SetIcon(FileController.Get("image", "join") :: string)
	local copyLinkButton = joinButton:Combine("Copy Join Link", FileController.Get("image", "copy_link"))
	local refreshButton = serversSection:AddElement("Button", "Refresh")
	refreshButton:SetIcon(FileController.Get("image", "refresh") :: string)

	local function joinSelected(): ()
		local row = serverTable:GetSelectedRow()
		if not row then
			return
		end
		joinServer(tostring(row.id))
	end

	joinButton:OnClick(joinSelected)

	copyLinkButton:OnClick(function()
		local row = serverTable:GetSelectedRow()
		if not row then
			return
		end
		local id = tostring(row.id)
		setclipboard(`roblox://placeId={game.PlaceId}&gameInstanceId={id}`)
		NotifyController.Push({
			title = "Copied join link",
			subtext = formatServerId(id),
			icon = "copy",
			duration = 2,
		})
	end)

	refreshButton:OnClick(function()
		serverTable:Refresh()
	end)

	serverTable:Reload()
end
