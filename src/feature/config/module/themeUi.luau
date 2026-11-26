local Charm = require("@pkg/Charm")

local ThemeController = require("@src/feature/config/ThemeController")
local subwindowPosition = require("@ui/util/subwindowPosition")
local UserController = require("@src/feature/config/UserController")
local FileController = require("@src/feature/file/FileController")
local SubwindowController = require("@ui/subwindow/SubwindowController")
local Section = require("@ui/window/section/Section")
local themeState = require("@ui/theme/themeState")
local Tab = require("@ui/window/tab/Tab")

local peek = Charm.peek
local sub = Charm.subscribe

local DEFAULT_NAME = "Unnamed"

local function uniqueName(existing: { string }, base: string): string
	local taken: { [string]: true } = {}
	for _, name in next, existing do
		taken[name] = true
	end

	if not taken[base] then
		return base
	end

	local index = 2
	while taken[`{base} {index}`] do
		index += 1
	end
	return `{base} {index}`
end

local function toItems(names: { string }, current: string?): { { id: string, name: string, icon: string?, locked: boolean } }
	local curved_right_arrow = FileController.Get("image", "curved_right_arrow")
	local items = {}
	for index, name in next, names do
		items[index] = {
			id = name,
			name = name,
			icon = name == current and curved_right_arrow or nil,
			locked = ThemeController.IsBuiltin(name),
		}
	end
	return items
end

local function camelToTitle(s: string): string
	local result = s:gsub("(%l)(%u)", "%1 %2")
	return (result:gsub("^.", string.upper))
end

local function bindColorpicker(cp: any, atom: any, isRgba: boolean): ()
	local syncing = false

	sub(cp._state, function(color: any)
		if syncing then
			return
		end
		syncing = true
		if isRgba then
			atom({ color, peek(cp._transparency) })
		else
			atom(color)
		end
		syncing = false
	end)

	if isRgba then
		sub(cp._transparency, function(alpha: number?)
			if syncing then
				return
			end
			syncing = true
			atom({ peek(cp._state), alpha })
			syncing = false
		end)
	end

	sub(atom, function(value: any)
		if syncing then
			return
		end
		syncing = true
		if isRgba then
			cp:SetState(value[1])
			cp:SetTransparency(value[2])
		else
			cp:SetState(value)
		end
		syncing = false
	end)
end

local function buildSection(title: string, dict: any): any
	local section = Section(title)

	local keys: { string } = {}
	for key in next, dict do
		table.insert(keys, key)
	end
	table.sort(keys)

	for _, key in next, keys do
		local atom = dict[key]
		if type(atom) ~= "function" then
			continue
		end

		local current = peek(atom)
		local label = camelToTitle(key)

		if typeof(current) == "Color3" then
			local cp = section:AddElement("Colorpicker", label, current)
			bindColorpicker(cp, atom, false)
		elseif type(current) == "table" and typeof(current[1]) == "Color3" then
			local cp = section:AddElement("Colorpicker", label, current[1], current[2])
			bindColorpicker(cp, atom, true)
		end
	end

	return section
end

local sectionsBuilt = false
local function ensureSections(): ()
	if sectionsBuilt then
		return
	end
	sectionsBuilt = true

	local editor: any = SubwindowController.Get("ThemeEditor")
	if not editor then
		return
	end

	editor:SetSections({
		buildSection("CANVAS", themeState.colors.canvas),
		buildSection("ELEMENT", themeState.colors.window.element),
		buildSection("HUD", themeState.colors.hud),
		buildSection("NOTIFICATION", themeState.colors.notify),
		buildSection("SECTION", themeState.colors.window.section),
		buildSection("STATUS", themeState.colors.status),
		buildSection("SUBWINDOW", themeState.colors.subwindow),
		buildSection("TOAST", themeState.colors.toast),
		buildSection("WINDOW", themeState.colors.window),
	})
end

return function(tab: Tab.Tab): ()
	local section = tab:AddSection("THEMES", 2)

	local list = section:AddElement("List", "Theme") :: any
	list:SetRenamable(true)
	list:SetEmptyText("No themes")
	list:SetMaxHeight(180)

	local function currentTheme(): string
		return UserController.GetTheme() or ThemeController.DEFAULT_NAME
	end

	local function refresh(): ()
		list:SetItems(toItems(ThemeController.ListThemes(), currentTheme()))
	end

	sub(UserController.theme, refresh)
	sub(ThemeController.revision, refresh)

	list:OnRename(function(oldName: string, newName: string): ()
		if not ThemeController.RenameTheme(oldName, newName) then
			refresh()
			return
		end
		if UserController.GetTheme() == oldName then
			UserController.SetTheme(newName)
		end
	end)

	local createButton = section:AddElement("Button", "Create", FileController.Get("image", "write")) :: any
	createButton:OnClick(function(): ()
		ensureSections()

		local name = uniqueName(ThemeController.ListThemes(), DEFAULT_NAME)
		local snapshot = ThemeController.Snapshot()

		SubwindowController.OpenThemeEditor({
			title = `Create Theme — {name}`,
			name = name,
			position = subwindowPosition.menuCenter(),
			snapshot = snapshot,
			onSave = function()
				ThemeController.SaveToFile(name)
				UserController.SetTheme(name)
				refresh()
				list:SetSelected(name)
			end,
			onCancel = function()
				ThemeController.Restore(snapshot)
			end,
		})
	end)

	local deleteButton = createButton:Combine("Delete")
	deleteButton:SetIcon(FileController.Get("image", "delete"))
	deleteButton:RequireConfirm()
	deleteButton:OnClick(function(): ()
		local selected = list:GetSelected()
		if not selected then
			return
		end
		ThemeController.DeleteTheme(selected)
		if UserController.GetTheme() == selected then
			UserController.SetTheme(nil)
		end
		refresh()
	end)

	local editButton = section:AddElement("Button", "Edit", FileController.Get("image", "pencil")) :: any
	editButton:OnClick(function(): ()
		local selected = list:GetSelected()
		if not selected or ThemeController.IsDefault(selected) then
			return
		end

		ensureSections()

		local previousTheme = UserController.GetTheme()
		local snapshot = ThemeController.Snapshot()
		ThemeController.LoadFromFile(selected, true)
		UserController.SetTheme(selected)

		SubwindowController.OpenThemeEditor({
			title = `Edit Theme — {selected}`,
			name = selected,
			position = subwindowPosition.menuCenter(),
			snapshot = snapshot,
			onSave = function()
				ThemeController.SaveToFile(selected)
			end,
			onCancel = function()
				ThemeController.Restore(snapshot)
				UserController.SetTheme(previousTheme)
			end,
		})
	end)

	local loadButton = editButton:Combine("Load")
	loadButton:SetIcon(FileController.Get("image", "load"))
	loadButton:OnClick(function(): ()
		local selected = list:GetSelected()
		if not selected then
			return
		end
		ThemeController.LoadFromFile(selected)
		UserController.SetTheme(selected)
	end)

	refresh()
end
