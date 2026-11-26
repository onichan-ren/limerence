local UIController = require("@ui/UIController")
local FileController = require("@feature/file/FileController")
local uiRegistry = require("@ui/uiRegistry")

local recordsStore = require("@feature/record/module/recordsStore")
local recordUi = require("@feature/record/module/recordUi")
local playersUi = require("@feature/record/module/playersUi")

local RecordController = {}

function RecordController.new(): RecordController
	recordsStore.Load()

	local window = UIController.GetMainWindow()
	if not window then
		return RecordController
	end

	local group = window:GetTabGroup("COMMON")
	if not group then
		return RecordController
	end

	local tab = uiRegistry.add(
		group:AddTab("Players", FileController.Get("image", "person") :: string, {
			containers = 1,
		}),
		{ kind = "tab" }
	)

	playersUi(tab)
	recordUi(tab)

	return RecordController
end

function RecordController.Destroy(): () end

export type RecordController = typeof(RecordController)

return RecordController
