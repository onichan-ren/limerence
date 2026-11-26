local Charm = require("@pkg/Charm")

local UIController = require("@ui/UIController")
local FileController = require("@feature/file/FileController")
local UserController = require("@feature/config/UserController")
local uiRegistry = require("@ui/uiRegistry")
local luauState = require("@feature/luau/luauState")

local sub = Charm.subscribe
local peek = Charm.peek

local function statusLabel(info: luauState.ScriptInfo): string
	if info.status == "error" then
		return `{info.name} — error`
	end
	return info.name
end

return function(LuauController: any): ()
	local window = UIController.GetMainWindow()
	if not window then
		return
	end

	local group = window:GetTabGroup("COMMON")
	if not group then
		return
	end

	local tab = uiRegistry.add(
		group:AddTab("Luau", FileController.Get("image", "file") :: string, {
			containers = 1,
		}),
		{ kind = "tab" }
	)

	local listSection = tab:AddSection("SCRIPTS", 1)
	local list = listSection:AddElement("List", "Script") :: any
	list:SetEmptyText("No scripts found")
	list:SetMaxHeight(260)

	local function toItems(): { { id: string, name: string, icon: string? } }
		local items: { { id: string, name: string, icon: string? } } = {}
		for name, info in next, peek(luauState.scripts) do
			local iconKey
			if info.status == "error" then
				iconKey = "trash"
			elseif info.status == "discovered" then
				iconKey = "file"
			else
				iconKey = "checkmark"
			end
			items[#items + 1] = {
				id = name,
				name = statusLabel(info),
				icon = FileController.Get("image", iconKey),
			}
		end
		table.sort(items, function(a, b)
			return a.id < b.id
		end)
		return items
	end

	local function refresh(): ()
		list:SetItems(toItems())
	end

	sub(luauState.scripts, refresh)
	refresh()

	local loadButton = listSection:AddElement("Button", "Load", FileController.Get("image", "load")) :: any
	loadButton:OnClick(function(): ()
		local selected = list:GetSelected()
		if not selected then
			return
		end
		LuauController.LoadByName(selected)
	end)

	local unloadButton = loadButton:Combine("Unload") :: any
	unloadButton:SetIcon(FileController.Get("image", "unload"))
	unloadButton:OnClick(function(): ()
		local selected = list:GetSelected()
		if not selected then
			return
		end
		LuauController.Unload(selected)
	end)

	local settingsSection = tab:AddSection("SETTINGS", 1)

	local developerModeToggle =
		settingsSection:AddElement("Toggle", "Developer Mode", peek(UserController.developerMode)) :: any
	developerModeToggle:SetBindable(false)
	developerModeToggle:SetTip({
		title = "Developer Mode",
		body = "Enables extra features for debugging and Luau development. Right-click any element to copy its ID.",
	})

	sub(developerModeToggle._state, function(state: boolean): ()
		UserController.SetDeveloperMode(state)
	end)

	sub(UserController.developerMode, function(state: boolean): ()
		if peek(developerModeToggle._state) ~= state then
			developerModeToggle._state(state)
		end
	end)
end
