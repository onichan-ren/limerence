local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local React = require("@pkg/React")

local sharedRefs = require("@ui/subwindow/sharedRefs")

local useEffect = React.useEffect
local useRef = React.useRef

local isInside = LPH_NO_VIRTUALIZE(function(refTbl: { current: GuiObject? }?, x: number, y: number): boolean
	if not refTbl then
		return false
	end
	local instance = refTbl.current
	if not instance then
		return false
	end
	if not instance.Visible then
		return false
	end
	local current: any? = instance
	while current and current.ClassName == "GuiObject" do
		if not current.Visible then
			return false
		end
		current = current.Parent
	end
	local origin = instance.AbsolutePosition
	local size = instance.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return false
	end
	return x >= origin.X and x <= origin.X + size.X and y >= origin.Y and y <= origin.Y + size.Y
end)

local useClickOutside = LPH_NO_VIRTUALIZE(
	function(
		ref: { current: GuiObject? },
		active: boolean,
		onOutside: () -> (),
		extraInsideRefs: { { current: GuiObject? } }?
	): ()
		local callbackRef = useRef(onOutside)
		callbackRef.current = onOutside

		local extraRefsRef = useRef(extraInsideRefs)
		extraRefsRef.current = extraInsideRefs

		useEffect(function()
			if not active then
				return
			end

			local connection: RBXScriptConnection? = nil
			local cancelled = false

			task.defer(function()
				if cancelled then
					return
				end

				connection = UserInputService.InputBegan:Connect(function(input: InputObject)
					local inputType = input.UserInputType
					if
						inputType ~= Enum.UserInputType.MouseButton1
						and inputType ~= Enum.UserInputType.MouseButton2
						and inputType ~= Enum.UserInputType.Touch
					then
						return
					end

					local instance = ref.current
					if not instance then
						return
					end

					local x = input.Position.X
					local y = input.Position.Y

					if isInside(ref, x, y) then
						return
					end

					if sharedRefs.context ~= ref and isInside(sharedRefs.context, x, y) then
						return
					end

					local myZ = sharedRefs.subwindows[ref] or 0
					for otherRef, otherZ in next, sharedRefs.subwindows do
						if otherRef ~= ref and otherZ > myZ and isInside(otherRef, x, y) then
							return
						end
					end

					local extras = extraRefsRef.current
					if extras then
						for _, extraRef in next, extras do
							if isInside(extraRef, x, y) then
								return
							end
						end
					end

					callbackRef.current()
				end)
			end)

			return function()
				cancelled = true
				if connection then
					connection:Disconnect()
					connection = nil
				end
			end
		end, { active } :: { any })
	end
)

return useClickOutside
