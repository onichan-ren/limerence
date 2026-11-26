local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local GuiService = cloneref(game:GetService("GuiService")) :: GuiService

local sharedRefs = require("@ui/subwindow/sharedRefs")

type FrameRef = { current: GuiObject? }
type Entry = {
	frameRef: FrameRef,
	handler: (mouse: Vector2) -> (),
}

local entries: { [Entry]: true } = {}
local listenerConn: RBXScriptConnection? = nil

local function ensureListener(): ()
	if listenerConn then
		return
	end
	listenerConn = UserInputService.InputBegan:Connect(LPH_NO_VIRTUALIZE(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton2 then
			return
		end
		if next(entries) == nil then
			return
		end

		local mouse = UserInputService:GetMouseLocation() - Vector2.new(0, GuiService:GetGuiInset().Y :: number)
		local mx = mouse.X
		local my = mouse.Y

		for entry in next, entries do
			local frame = entry.frameRef.current
			if not frame then
				continue
			end

			local size = frame.AbsoluteSize
			if size.X <= 0 or size.Y <= 0 then
				continue
			end

			local pos = frame.AbsolutePosition
			if mx < pos.X or mx > pos.X + size.X then
				continue
			end
			if my < pos.Y or my > pos.Y + size.Y then
				continue
			end

			local cur: any? = frame
			local visible = true
			while cur and cur:IsA("GuiObject") do
				if not cur.Visible then
					visible = false
					break
				end
				cur = cur.Parent
			end
			if not visible then
				continue
			end

			if sharedRefs.floatingOccludesElementAt(frame, mx, my) then
				continue
			end

			local consumed = false
			for _, desc: any in next, frame:QueryDescendants("Instance") do
				if not desc:IsA("GuiObject") then
					continue
				end
				if not desc:GetAttribute("ConsumesRightClick") then
					continue
				end
				local descPos = desc.AbsolutePosition
				local descSize = desc.AbsoluteSize
				if
					mx >= descPos.X
					and mx <= descPos.X + descSize.X
					and my >= descPos.Y
					and my <= descPos.Y + descSize.Y
				then
					consumed = true
					break
				end
			end
			if consumed then
				continue
			end

			entry.handler(mouse)
		end
	end))
end

local function register(frameRef: FrameRef, handler: (mouse: Vector2) -> ()): () -> ()
	local entry: Entry = { frameRef = frameRef, handler = handler }
	entries[entry] = true
	ensureListener()
	return function()
		entries[entry] = nil
	end
end

return {
	register = register,
}
