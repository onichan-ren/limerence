local patchConstant = {}

function patchConstant.apply(fn: any, oldValue: any, newValue: any): { number }
	local indices: { number } = {}
	if type(fn) ~= "function" then
		return indices
	end
	local constants = debug.getconstants(fn)
	for i = 1, #constants do
		if constants[i] == oldValue then
			debug.setconstant(fn, i, newValue)
			indices[#indices + 1] = i
		end
	end
	return indices
end

function patchConstant.restore(fn: any, indices: { number }, value: any): ()
	if type(fn) ~= "function" then
		return
	end
	for i = 1, #indices do
		debug.setconstant(fn, indices[i], value)
	end
end

return patchConstant
