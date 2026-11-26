local Charm = require("@pkg/Charm")
local ReactCharm = require("@pkg/ReactCharm")
local ConfigController = require("@feature/config/ConfigController")
local playerState = require("@feature/record/module/playerState")
local legitbotState = require("@game/universal/feature/combat/legitbot/legitbotState")
local Colorpicker = require("@ui/window/element/colorpicker/Colorpicker")
local Toggle = require("@ui/window/element/toggle/Toggle")

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe
local useAt = ReactCharm.useAtom

local KEY_PREFIX = "esp.stateColors"

export type StateDef = {
	id: string,
	label: string,
	color: Color3,
	priority: number,
}

export type SlotDef = {
	id: string,
	label: string,
	default: Color3 | ColorSequence,
	transparency: number?,
	isSequence: boolean,
	basePicker: Colorpicker.Colorpicker?,
}

local STATES: { StateDef } = {
	{ id = "target", label = "Target", color = Color3.fromRGB(170, 120, 255), priority = 100 },
	{ id = "priority", label = "Priority", color = Color3.fromRGB(220, 190, 110), priority = 30 },
	{ id = "friendly", label = "Friendly", color = Color3.fromRGB(120, 200, 130), priority = 10 },
}

local EDITOR_STATES: { any } = {
	{ id = "base", label = "Default", color = Color3.fromRGB(168, 168, 168), priority = 0 },
}
for _, def in STATES do
	EDITOR_STATES[#EDITOR_STATES + 1] = def
end

local STATE_BY_ID: { [string]: StateDef } = {}
for _, def in next, STATES do
	STATE_BY_ID[def.id] = def
end

local espStateColors = {}

local _slots: { SlotDef } = {}
local _slotById: { [string]: SlotDef } = {}
local _pickers: { [string]: { [string]: Colorpicker.Colorpicker } } = {}
local _toggles: { [string]: any } = {}
local _overrideFlags = at({} :: { [string]: boolean })
local _selectedState = at("base")
local _targetUserId = at(nil :: number?)
local _previewUserId = at(nil :: number?)
local _targetSources: { Charm.Atom<Player?> } = { legitbotState.target }

local _visToggles: { [string]: { [string]: any } } = {}
local _visResolved: { [string]: { [string]: boolean } } = {}
local _visSignal = at(0)
local _anyVisHidden = false

espStateColors.selectedState = _selectedState
espStateColors.visSignal = _visSignal

local function recomputeTarget(): ()
	local found: Player? = nil
	for _, source in next, _targetSources do
		local player = peek(source)
		if player then
			found = player
			break
		end
	end
	local id = found and found.UserId or nil
	if peek(_targetUserId) ~= id then
		_targetUserId(id)
	end
end

local function recomputeAnyVisHidden(): ()
	local any = false
	for _, bucket in next, _visResolved do
		for _, shown in next, bucket do
			if shown == false then
				any = true
				break
			end
		end
		if any then
			break
		end
	end
	_anyVisHidden = any
end

local function ensureVisToggles(elementId: string): ()
	for _, stateDef in next, STATES do
		local bucket = _visToggles[stateDef.id]
		if not bucket then
			bucket = {}
			_visToggles[stateDef.id] = bucket
		end
		local resolved = _visResolved[stateDef.id]
		if not resolved then
			resolved = {}
			_visResolved[stateDef.id] = resolved
		end
		if bucket[elementId] then
			continue
		end
		local toggle = Toggle("Show", true)
		bucket[elementId] = toggle
		ConfigController.Link(`{KEY_PREFIX}.{stateDef.id}.{elementId}.show`, toggle)
		resolved[elementId] = peek(toggle._state) == true
		local sid = stateDef.id
		sub(toggle._state, function(v: boolean): ()
			local b = _visResolved[sid]
			local value = v == true
			if b[elementId] == value then
				return
			end
			b[elementId] = value
			recomputeAnyVisHidden()
			_visSignal(peek(_visSignal) + 1)
		end)
	end
	recomputeAnyVisHidden()
end

local function ensureToggles(): ()
	for _, def in next, STATES do
		if _toggles[def.id] then
			continue
		end
		local toggle = Toggle("Override", false)
		_toggles[def.id] = toggle
		ConfigController.Link(`{KEY_PREFIX}.{def.id}.override`, toggle)
		local stateId = def.id
		local function syncFlag(): ()
			local flags = peek(_overrideFlags)
			local value = peek(toggle._state) == true
			if flags[stateId] == value then
				return
			end
			local nextFlags = table.clone(flags)
			nextFlags[stateId] = value
			_overrideFlags(nextFlags)
		end
		sub(toggle._state, syncFlag)
		syncFlag()
	end
end

function espStateColors.Register(slot: { id: string, label: string, default: Color3 | ColorSequence, transparency: number? }): ()
	if _slotById[slot.id] then
		return
	end

	local def: SlotDef = {
		id = slot.id,
		label = slot.label,
		default = slot.default,
		transparency = slot.transparency,
		isSequence = typeof(slot.default) == "ColorSequence",
	}
	_slots[#_slots + 1] = def
	_slotById[slot.id] = def

	ensureToggles()

	for _, stateDef in next, STATES do
		local bucket = _pickers[stateDef.id]
		if not bucket then
			bucket = {}
			_pickers[stateDef.id] = bucket
		end
		if bucket[slot.id] then
			continue
		end
		local isOutline = string.sub(def.id, -7) == "Outline"
		local default: Color3 | ColorSequence
		if isOutline then
			default = def.default
		else
			default = def.isSequence and ColorSequence.new(stateDef.color) or stateDef.color
		end
		local picker = Colorpicker(slot.label, default, slot.transparency)
		bucket[slot.id] = picker
		ConfigController.Link(`{KEY_PREFIX}.{stateDef.id}.{slot.id}`, picker)
	end
end

function espStateColors.AddTargetSource(source: Charm.Atom<Player?>): ()
	for _, existing in next, _targetSources do
		if existing == source then
			return
		end
	end
	_targetSources[#_targetSources + 1] = source
	sub(source, recomputeTarget)
	recomputeTarget()
end

function espStateColors.GetStates(): { StateDef }
	return STATES
end

function espStateColors.GetEditorStates(): { any }
	return EDITOR_STATES
end

function espStateColors.GetSlots(): { SlotDef }
	return _slots
end

function espStateColors.GetOverridePicker(stateId: string, slotId: string): Colorpicker.Colorpicker?
	local bucket = _pickers[stateId]
	return bucket and bucket[slotId]
end

function espStateColors.GetOverrideToggle(stateId: string): any
	return _toggles[stateId]
end

function espStateColors.SetSelectedState(stateId: string): ()
	if (stateId == "base" or STATE_BY_ID[stateId]) and peek(_selectedState) ~= stateId then
		_selectedState(stateId)
	end
end

function espStateColors.SetPreviewUserId(userId: number?): ()
	if peek(_previewUserId) ~= userId then
		_previewUserId(userId)
	end
end

local SLOT_BY_ELEMENT = {
	visibleChams = "chams",
}

local function bindDisplay(picker: any, slotId: string): ()
	picker._displaySelection = _selectedState
	picker._displayResolver = function(): any
		local selected = peek(_selectedState)
		if selected == "base" then
			return picker
		end
		local bucket = _pickers[selected]
		return (bucket and bucket[slotId]) or picker
	end
end

function espStateColors.BindElement(elementId: string, settings: any): ()
	if not settings then
		return
	end
	local slotId = SLOT_BY_ELEMENT[elementId] or elementId
	local slot = _slotById[slotId]
	local basePicker = settings.color or settings.fillColor
	if slot and basePicker then
		slot.basePicker = basePicker
		bindDisplay(basePicker, slotId)
	end
	local outlineSlotId = slotId .. "Outline"
	local outlineSlot = _slotById[outlineSlotId]
	if outlineSlot and settings.outlineColor then
		outlineSlot.basePicker = settings.outlineColor
		bindDisplay(settings.outlineColor, outlineSlotId)
	end
	if settings.enabled then
		ensureToggles()
		ensureVisToggles(elementId)
		local enabledToggle = settings.enabled
		enabledToggle._displaySelection = _selectedState
		enabledToggle._displayResolver = function(): any
			local selected = peek(_selectedState)
			if selected == "base" then
				return enabledToggle
			end
			local bucket = _visToggles[selected]
			return (bucket and bucket[elementId]) or enabledToggle
		end
	end
end

local function resolveStateId(userId: number?): string?
	if userId == nil then
		return nil
	end
	if userId == peek(_previewUserId) then
		local selected = peek(_selectedState)
		if selected == "base" then
			return nil
		end
		return selected
	end
	if peek(_targetUserId) == userId then
		return "target"
	end
	local assigned = playerState.GetState(userId)
	if assigned and STATE_BY_ID[assigned] then
		return assigned
	end
	return nil
end

espStateColors.ResolveStateId = resolveStateId

function espStateColors.ResolvePicker(slotId: string, baseCp: any, userId: number?): any
	local stateId = resolveStateId(userId)
	if not stateId then
		return baseCp
	end
	if userId ~= peek(_previewUserId) and not peek(_overrideFlags)[stateId] then
		return baseCp
	end
	local bucket = _pickers[stateId]
	local picker = bucket and bucket[slotId]
	return picker or baseCp
end

function espStateColors.ResolveBucket(userId: number?): any
	local stateId = resolveStateId(userId)
	if not stateId then
		return nil
	end
	if userId ~= peek(_previewUserId) and not peek(_overrideFlags)[stateId] then
		return nil
	end
	return _pickers[stateId]
end

function espStateColors.ResolveStateData(userId: number?): (any, any)
	local stateId = resolveStateId(userId)
	if not stateId then
		return nil, nil
	end
	local bucket = nil
	if userId == peek(_previewUserId) or peek(_overrideFlags)[stateId] then
		bucket = _pickers[stateId]
	end
	return bucket, _visResolved[stateId]
end

function espStateColors.NeedsStateVis(): boolean
	return _anyVisHidden
end

function espStateColors.useResolved(slotId: string, baseCp: any, userId: number?): any
	useAt(playerState._assignments)
	useAt(_targetUserId)
	useAt(_overrideFlags)
	useAt(_selectedState)
	return espStateColors.ResolvePicker(slotId, baseCp, userId)
end

function espStateColors.RegisterTargetSource(source: Charm.Atom<Player?>): () -> ()
	table.insert(_targetSources, source)
	local unsub = sub(source, recomputeTarget)
	recomputeTarget()
	return function(): ()
		local idx = table.find(_targetSources, source)
		if idx then
			table.remove(_targetSources, idx)
		end
		unsub()
		recomputeTarget()
	end
end

sub(legitbotState.target, recomputeTarget)
recomputeTarget()

return espStateColors
