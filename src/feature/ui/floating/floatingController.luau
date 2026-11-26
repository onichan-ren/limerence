local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local GuiService = cloneref(game:GetService("GuiService")) :: GuiService

local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")
local sharedRefs = require("@ui/subwindow/sharedRefs")
local uiState = require("@ui/uiState")

local at = Charm.atom
local peek = Charm.peek

export type FloatingPriority = number

local PRIORITY: { [string]: FloatingPriority } = {
	TOOLTIP = 1,
	DROPDOWN = 2,
	MENU = 3,
	MODAL = 4,
}

type Entry = {
	id: string,
	priority: FloatingPriority,
	dismiss: () -> (),
}

local entries: { [string]: Entry } = {}
local quietUntil = 0
local subwindowLockoutUntil = 0
local SUBWINDOW_TRANSITION_TIME = 0.2

local FloatingController = {
	PRIORITY = PRIORITY,
	activePriority = at(0) :: Charm.Atom<FloatingPriority>,
	activeIds = at({} :: { [string]: FloatingPriority }) :: Charm.Atom<{ [string]: FloatingPriority }>,
}

local function recomputeActive(): ()
	local highest = 0
	local snapshot: { [string]: FloatingPriority } = {}
	for id, entry in next, entries do
		snapshot[id] = entry.priority
		if entry.priority > highest then
			highest = entry.priority
		end
	end
	FloatingController.activePriority(highest)
	FloatingController.activeIds(snapshot)
end

function FloatingController.Register(id: string, priority: FloatingPriority, dismiss: () -> ()): ()
	if type(id) ~= "string" or id == "" then
		return
	end

	local toDismiss: { Entry } = {}
	for otherId, entry in next, entries do
		if otherId ~= id and entry.priority < priority then
			table.insert(toDismiss, entry)
		end
	end

	entries[id] = { id = id, priority = priority, dismiss = dismiss }
	recomputeActive()

	for _, entry in next, toDismiss do
		entry.dismiss()
	end
end

function FloatingController.Unregister(id: string): ()
	local entry = entries[id]
	if not entry then
		return
	end

	entries[id] = nil

	if entry.priority > PRIORITY.TOOLTIP then
		quietUntil = os.clock() + 0.075
		subwindowLockoutUntil = math.max(subwindowLockoutUntil, os.clock() + SUBWINDOW_TRANSITION_TIME)
	end

	recomputeActive()
end

function FloatingController.IsSubwindowOpenAllowed(): boolean
	if not peek(uiState.isOpen) then
		return false
	end
	return os.clock() >= subwindowLockoutUntil
end

function FloatingController.IsAllowed(priority: FloatingPriority, anchorFrame: GuiObject?): boolean
	if priority <= PRIORITY.TOOLTIP and os.clock() < quietUntil then
		return false
	end
	if priority == PRIORITY.TOOLTIP then
		if not peek(uiState.isOpen) then
			return false
		end
		if peek(FloatingController.activePriority) <= PRIORITY.TOOLTIP then
			return true
		end
		if not anchorFrame then
			return false
		end
		local mouse = UserInputService:GetMouseLocation() - Vector2.new(0, GuiService:GetGuiInset().Y :: number)
		return not sharedRefs.floatingOccludesElementAt(anchorFrame, mouse.X, mouse.Y)
	end
	return peek(FloatingController.activePriority) <= priority
end

function FloatingController.GetHighestActive(): FloatingPriority
	return peek(FloatingController.activePriority)
end

function FloatingController.GetActive(): { [string]: FloatingPriority }
	return Sift.Dictionary.copy(peek(FloatingController.activeIds))
end

function FloatingController.IsActive(id: string): boolean
	return entries[id] ~= nil
end

function FloatingController.DismissBelow(priority: FloatingPriority): ()
	local toDismiss: { Entry } = {}
	for _, entry in next, entries do
		if entry.priority < priority then
			table.insert(toDismiss, entry)
		end
	end
	for _, entry in next, toDismiss do
		entry.dismiss()
	end
end

return FloatingController
