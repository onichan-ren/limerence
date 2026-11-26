local elementApi = {
	_openBindEditor = nil :: ((element: any, position: UDim2?) -> ())?,
	_openContext = nil :: ((items: { any }, position: UDim2?) -> ())?,
}

function elementApi.SetHandlers(
	openBindEditor: (element: any, position: UDim2?) -> (),
	openContext: (items: { any }, position: UDim2?) -> ()
): ()
	elementApi._openBindEditor = openBindEditor
	elementApi._openContext = openContext
end

function elementApi.OpenBindEditor(element: any, position: UDim2?): ()
	if elementApi._openBindEditor then
		elementApi._openBindEditor(element, position)
	end
end

function elementApi.OpenContext(items: { any }, position: UDim2?): ()
	if elementApi._openContext then
		elementApi._openContext(items, position)
	end
end

return elementApi
