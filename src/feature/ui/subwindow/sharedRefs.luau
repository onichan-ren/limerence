type Ref = { current: GuiObject? }

local nextOrder = 0

local sharedRefs = {
	context = nil :: Ref?,
	subwindows = {} :: { [Ref]: number },
}

function sharedRefs.containsScreenPoint(ref: Ref?, x: number, y: number): boolean
	if not ref then
		return false
	end
	local instance = ref.current
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
end

local function isDescendantOf(root: Instance?, elementFrame: GuiObject?): boolean
	if not root or not elementFrame then
		return false
	end
	local cur: Instance? = elementFrame
	while cur do
		if cur == root then
			return true
		end
		cur = cur.Parent
	end
	return false
end

function sharedRefs.topmostFloatingRootAt(x: number, y: number): GuiObject?
	if sharedRefs.containsScreenPoint(sharedRefs.context, x, y) then
		local inst = sharedRefs.context.current
		if inst then
			return inst
		end
	end
	local best: GuiObject? = nil
	local bestZ = -1
	for ref, z in next, sharedRefs.subwindows do
		if sharedRefs.containsScreenPoint(ref, x, y) and z > bestZ then
			bestZ = z
			best = ref.current
		end
	end
	return best
end

function sharedRefs.floatingOccludesElementAt(elementFrame: GuiObject, x: number, y: number): boolean
	local root = sharedRefs.topmostFloatingRootAt(x, y)
	if not root then
		return false
	end
	return not isDescendantOf(root, elementFrame)
end

function sharedRefs.add(ref: Ref, zIndex: number): ()
	sharedRefs.subwindows[ref] = zIndex
end

function sharedRefs.remove(ref: Ref): ()
	sharedRefs.subwindows[ref] = nil
end

function sharedRefs.getNextOrder(): number
	nextOrder += 1
	return nextOrder
end

return sharedRefs
