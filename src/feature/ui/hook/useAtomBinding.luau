local React = require("@pkg/React")
local Charm = require("@pkg/Charm")

local createBinding = React.createBinding
local useEffect = React.useEffect
local useRef = React.useRef
local peek = Charm.peek
local sub = Charm.subscribe

local useAtomBinding = LPH_NO_VIRTUALIZE(function<T>(atom: Charm.Atom<T>): React.Binding<T>
	local bindingRef = useRef(nil :: any)
	local setterRef = useRef(nil :: any)

	if bindingRef.current == nil then
		local binding, setter = createBinding(peek(atom))
		bindingRef.current = binding
		setterRef.current = setter
	end

	useEffect(function()
		setterRef.current(peek(atom))
		return sub(atom, function(value: T): ()
			setterRef.current(value)
		end)
	end, { atom })

	return bindingRef.current
end)

return useAtomBinding
