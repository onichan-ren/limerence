type Item = {
	Label: string?,
	Icon: string?,
	Callback: (() -> ())?,
	Divider: boolean?,
}

local OPEN_GRACE_PERIOD = 0.1

local contextApi = {
	_open = nil :: ((items: { Item }, position: UDim2?) -> ())?,
	_close = nil :: (() -> ())?,
	_lastOpenedAt = 0,
}

function contextApi.SetHandlers(open: (items: { Item }, position: UDim2?) -> (), close: () -> ()): ()
	contextApi._open = open
	contextApi._close = close
end

function contextApi.Open(items: { Item }, position: UDim2?): ()
	contextApi._lastOpenedAt = os.clock()
	if contextApi._open then
		contextApi._open(items, position)
	end
end

function contextApi.Close(): ()
	if contextApi._close then
		contextApi._close()
	end
end

function contextApi.WasJustOpened(): boolean
	return os.clock() - contextApi._lastOpenedAt < OPEN_GRACE_PERIOD
end

export type ContextItem = Item

return contextApi
