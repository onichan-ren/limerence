local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")

local toastState = require("@ui/hud/toast/toastState")

local peek = Charm.peek

local DISMISS_FADE_TIME = 0.35
local DEFAULT_DURATION = 4
local MAX_VISIBLE = 10

export type PushSpec = {
	text: string,
	icons: { toastState.ToastIcon }?,
	accent: Color3?,
	duration: number?,
}

export type UpdatePatch = {
	text: string?,
	icons: { toastState.ToastIcon }?,
	accent: Color3?,
}

local ToastController = {}

local nextId = 0

function ToastController.Push(spec: PushSpec): string
	nextId += 1
	local id = `toast_{nextId}`

	local toast: toastState.Toast = {
		id = id,
		text = spec.text,
		icons = spec.icons,
		accent = spec.accent,
		duration = spec.duration or DEFAULT_DURATION,
		removing = false,
		createdAt = os.clock(),
	}

	local current = peek(toastState.toasts)
	toastState.toasts(Sift.Array.push(current, toast))

	local active = 0
	for _, t in next, peek(toastState.toasts) do
		if not t.removing then
			active += 1
		end
	end
	if active > MAX_VISIBLE then
		local toDismiss = active - MAX_VISIBLE
		for _, t in next, peek(toastState.toasts) do
			if toDismiss <= 0 then
				break
			end
			if not t.removing then
				ToastController.Dismiss(t.id)
				toDismiss -= 1
			end
		end
	end

	if toast.duration and toast.duration > 0 then
		task.delay(toast.duration, function(): ()
			ToastController.Dismiss(id)
		end)
	end

	return id
end

function ToastController.Update(id: string, patch: UpdatePatch): ()
	local current = peek(toastState.toasts)
	for index, entry in next, current do
		if entry.id == id then
			if entry.removing then
				return
			end
			toastState.toasts(Sift.Array.set(current, index, Sift.Dictionary.merge(entry, patch)))
			return
		end
	end
end

function ToastController.Dismiss(id: string): ()
	local current = peek(toastState.toasts)
	local idx: number? = nil
	for i, t in next, current do
		if t.id == id then
			idx = i
			break
		end
	end
	if not idx then
		return
	end

	local entry = current[idx]
	if entry.removing then
		return
	end

	toastState.toasts(Sift.Array.set(current, idx, Sift.Dictionary.merge(entry, { removing = true })))

	task.delay(DISMISS_FADE_TIME, function(): ()
		local list = peek(toastState.toasts)
		toastState.toasts(Sift.Array.filter(list, function(t: toastState.Toast): boolean
			return t.id ~= id
		end))
	end)
end

function ToastController.Clear(): ()
	for _, t in next, peek(toastState.toasts) do
		ToastController.Dismiss(t.id)
	end
end

return ToastController
