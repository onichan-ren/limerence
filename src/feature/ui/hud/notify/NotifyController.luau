local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")

local notifyState = require("@ui/hud/notify/notifyState")

local peek = Charm.peek

local DISMISS_FADE_TIME = 0.4

export type PushSpec = {
	title: string,
	subtext: string?,
	icon: string?,
	duration: number?,
	showProgress: boolean?,
	timer: boolean?,
	progress: number?,
}

export type UpdatePatch = {
	title: string?,
	subtext: string?,
	icon: string?,
	progress: number?,
}

local NotifyController = {}

local nextId = 0

local function findIndex(list: { notifyState.Notification }, id: string): number?
	for i, n in next, list do
		if n.id == id then
			return i
		end
	end
	return nil
end

function NotifyController.Push(spec: PushSpec): string
	nextId += 1
	local id = `notif_{nextId}`

	local showProgress = spec.showProgress == true or spec.timer == true

	local notification: notifyState.Notification = {
		id = id,
		title = spec.title,
		subtext = spec.subtext,
		icon = spec.icon,
		showProgress = showProgress,
		timer = spec.timer == true,
		progress = showProgress and (spec.progress or 0) or nil,
		duration = spec.duration,
		removing = false,
		createdAt = os.clock(),
	}

	local current = peek(notifyState.notifications)
	notifyState.notifications(Sift.Array.push(current, notification))

	if spec.duration and spec.duration > 0 then
		task.delay(spec.duration, function()
			NotifyController.Dismiss(id)
		end)
	end

	return id
end

function NotifyController.Update(id: string, patch: UpdatePatch): ()
	local current = peek(notifyState.notifications)
	local idx = findIndex(current, id)
	if not idx then
		return
	end

	local entry = current[idx]
	if entry.removing then
		return
	end

	notifyState.notifications(Sift.Array.set(current, idx, Sift.Dictionary.merge(entry, patch)))
end

function NotifyController.Dismiss(id: string): ()
	local current = peek(notifyState.notifications)
	local idx = findIndex(current, id)
	if not idx then
		return
	end

	local entry = current[idx]
	if entry.removing then
		return
	end

	notifyState.notifications(Sift.Array.set(current, idx, Sift.Dictionary.merge(entry, { removing = true })))

	task.delay(DISMISS_FADE_TIME, function()
		local list = peek(notifyState.notifications)
		notifyState.notifications(Sift.Array.filter(list, function(n: notifyState.Notification)
			return n.id ~= id
		end))

		local heights = peek(notifyState.heights)
		if heights[id] ~= nil then
			notifyState.heights((Sift.Dictionary.removeKey :: any)(heights, id))
		end
	end)
end

function NotifyController.Clear(): ()
	local current = peek(notifyState.notifications)
	for _, n in next, current do
		NotifyController.Dismiss(n.id)
	end
end

return NotifyController
