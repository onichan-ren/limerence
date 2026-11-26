type Source = any

local dropdownApi = {
	_open = nil :: ((source: Source, position: UDim2?) -> ())?,
	_close = nil :: ((source: Source?) -> ())?,
	_wasJustClosedFor = nil :: ((source: Source) -> boolean)?,
}

function dropdownApi.SetHandlers(
	open: (source: Source, position: UDim2?) -> (),
	close: (source: Source?) -> (),
	wasJustClosedFor: (source: Source) -> boolean
): ()
	dropdownApi._open = open
	dropdownApi._close = close
	dropdownApi._wasJustClosedFor = wasJustClosedFor
end

function dropdownApi.Open(source: Source, position: UDim2?): ()
	if dropdownApi._open then
		dropdownApi._open(source, position)
	end
end

function dropdownApi.Close(source: Source?): ()
	if dropdownApi._close then
		dropdownApi._close(source)
	end
end

function dropdownApi.WasJustClosedFor(source: Source): boolean
	if dropdownApi._wasJustClosedFor then
		return dropdownApi._wasJustClosedFor(source)
	end
	return false
end

return dropdownApi
