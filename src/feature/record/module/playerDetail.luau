local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")

local FileController = require("@feature/file/FileController")
local contextApi = require("@ui/subwindow/context/contextApi")
local SubwindowController = require("@ui/subwindow/SubwindowController")
local NotifyController = require("@ui/hud/notify/NotifyController")

local playerState = require("@feature/record/module/playerState")
local recordsStore = require("@feature/record/module/recordsStore")

local at = Charm.atom
local peek = Charm.peek

export type InfoField = {
	id: string,
	label: string,
	value: (player: Player, userId: number) -> string?,
	color: Charm.Atom<Color3>?,
	order: number?,
}

export type ActionTone = "default" | "accent" | "danger"

export type Action = {
	id: string,
	label: string,
	icon: string?,
	tone: ActionTone?,
	order: number?,
	callback: (player: Player, userId: number, position: UDim2) -> (),
	visible: ((player: Player, userId: number) -> boolean)?,
}

export type Provider = {
	id: string,
	info: { InfoField }?,
	actions: { Action }?,
}

local playerDetail = {
	_providers = at({} :: { Provider }),
}

local function indexOf(list: { Provider }, id: string): number?
	for index = 1, #list do
		if list[index].id == id then
			return index
		end
	end
	return nil
end

function playerDetail.Register(provider: Provider): ()
	local current = peek(playerDetail._providers)
	local existing = indexOf(current, provider.id)
	if existing then
		playerDetail._providers(Sift.Array.set(current, existing, provider))
	else
		playerDetail._providers(Sift.Array.push(current, provider))
	end
end

function playerDetail.Unregister(id: string): ()
	local current = peek(playerDetail._providers)
	local existing = indexOf(current, id)
	if existing then
		playerDetail._providers(Sift.Array.removeIndex(current, existing))
	end
end

local function sortByOrder(a: { order: number? }, b: { order: number? }): boolean
	return (a.order or 100) < (b.order or 100)
end

function playerDetail.GetInfo(): { InfoField }
	local list: { InfoField } = {}
	for _, provider in next, peek(playerDetail._providers) do
		if provider.info then
			for _, field in next, provider.info do
				table.insert(list, field)
			end
		end
	end
	table.sort(list, sortByOrder)
	return list
end

function playerDetail.GetActions(): { Action }
	local list: { Action } = {}
	for _, provider in next, peek(playerDetail._providers) do
		if provider.actions then
			for _, action in next, provider.actions do
				table.insert(list, action)
			end
		end
	end
	table.sort(list, sortByOrder)
	return list
end

function playerDetail.Subscribe(callback: () -> ()): () -> ()
	return Charm.subscribe(playerDetail._providers, callback)
end

playerDetail.Register({
	id = "core",
	actions = {
		{
			id = "setState",
			label = "Set State",
			icon = FileController.Get("image", "set_state"),
			order = 1,
			callback = function(_player: Player, userId: number, position: UDim2): ()
				local currentState = playerState.GetState(userId)
				local items: { contextApi.ContextItem } = {}
				for _, def in next, playerState.GetAll() do
					local active = currentState == def.id
					table.insert(items, {
						Label = def.label,
						Icon = active and FileController.Get("image", "checkmark") or nil,
						Callback = function()
							playerState.SetState(userId, not active and def.id or nil)
						end,
					})
				end
				table.insert(items, { Divider = true })
				table.insert(items, {
					Label = "Clear State",
					Callback = function()
						playerState.SetState(userId, nil)
					end,
				})
				contextApi.Open(items, position)
			end,
		},
		{
			id = "editNote",
			label = "Edit Note",
			icon = FileController.Get("image", "pencil"),
			order = 2,
			callback = function(player: Player, userId: number): ()
				local current = recordsStore.Get(userId)
				SubwindowController.OpenRecordEditor({
					title = player.DisplayName,
					subtitle = `@{player.Name} · {userId}`,
					noteValue = current and current.note or "",
					notePlaceholder = "Add a note about this player...",
					onSave = function(note: string): ()
						recordsStore.Upsert(userId, player.Name, player.DisplayName, {
							note = note ~= "" and note or nil,
						})
					end,
				})
			end,
		},
		{
			id = "copyProfile",
			label = "Copy Link",
			icon = FileController.Get("image", "copy_link"),
			order = 3,
			callback = function(player: Player, userId: number): ()
				setclipboard(`https://www.roblox.com/users/{userId}/profile`)
				NotifyController.Push({
					title = "Copied profile link",
					subtext = `@{player.DisplayName} · {player.Name}`,
					icon = "copy",
					duration = 2,
				})
			end,
		},
	},
})

return playerDetail
