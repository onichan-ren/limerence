local React = require("@pkg/React")

local contextApi = require("@ui/subwindow/context/contextApi")
local cursor = require("@ui/util/cursor")
local UserController = require("@feature/config/UserController")
local configState = require("@feature/config/configState")
local NotifyController = require("@ui/hud/notify/NotifyController")
local FileController = require("@feature/file/FileController")

local Charm = require("@pkg/Charm")
local peek = Charm.peek

local useCallback = React.useCallback
local useRef = React.useRef

type ContextItem = contextApi.ContextItem
type ItemsProvider = { ContextItem } | (rbx: any, input: InputObject) -> { ContextItem }?

local function findElementId(element: any): string?
	if not element then
		return nil
	end
	for key, value in next, configState.elements do
		if value == element then
			return key
		end
	end
	return nil
end

local function appendDevItems(items: { ContextItem }, element: any): ()
	if not peek(UserController.developerMode) then
		return
	end

	local id = findElementId(element)
	if not id then
		return
	end

	if #items > 0 then
		table.insert(items, { Divider = true })
	end

	table.insert(items, {
		Label = "Copy ID",
		Icon = FileController.Get("image", "pencil"),
		Callback = function(): ()
			if setclipboard then
				setclipboard(id)
			end
			NotifyController.Push({
				title = "Copied Id",
				subtext = `Copied {id} to clipboard`,
				duration = 2,
			})
		end,
	})
end

local function useContext(itemsProvider: ItemsProvider, element: any?): (rbx: any, input: InputObject) -> ()
	local providerRef = useRef(itemsProvider)
	providerRef.current = itemsProvider

	local elementRef = useRef(element)
	elementRef.current = element

	return useCallback(function(rbx: any, input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton2 then
			return
		end

		local provider = providerRef.current
		local items: { ContextItem }?
		if type(provider) == "function" then
			items = provider(rbx, input)
		else
			items = provider :: { ContextItem }
		end

		items = items or {}
		appendDevItems(items, elementRef.current)

		if #items == 0 then
			return
		end

		contextApi.Open(items, cursor.getPosition(input))
	end, {})
end

return useContext
