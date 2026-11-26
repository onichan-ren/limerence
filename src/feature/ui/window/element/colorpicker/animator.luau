local RunService = cloneref(game:GetService("RunService")) :: RunService
local Charm = require("@pkg/Charm")
local animations = require("@ui/window/element/colorpicker/animations")

local peek = Charm.peek

local animator = {}

export type CurrentValue = animations.AnimationResult

local registered: { [any]: true } = setmetatable({}, { __mode = "k" }) :: any
local connection: RBXScriptConnection? = nil

local tick = LPH_NO_VIRTUALIZE(function(): ()
	local now = os.clock()
	for cp in next, registered do
		local scratch = cp._animScratch
		if not scratch then
			scratch = {}
			cp._animScratch = scratch
		end
		scratch.color = peek(cp._state)
		scratch.rotation = peek(cp._rotation)
		scratch.transparency = peek(cp._transparency)
		scratch.speed = peek(cp._speed)
		scratch.time = now
		cp._setCurrent(animations.apply(scratch, peek(cp._animation)))
	end
end)

local function ensureLoop(): ()
	if connection then
		return
	end
	if not next(registered) then
		return
	end
	connection = RunService.PreRender:Connect(tick)
end

local function teardownLoop(): ()
	if not connection then
		return
	end
	if next(registered) then
		return
	end
	connection:Disconnect()
	connection = nil
end

function animator.computeStatic(cp: any): CurrentValue
	return {
		color = peek(cp._state),
		rotation = peek(cp._rotation),
		transparency = peek(cp._transparency) or 0,
	}
end

function animator.register(cp: any): ()
	registered[cp] = true
	ensureLoop()
end

function animator.unregister(cp: any): ()
	registered[cp] = nil
	teardownLoop()
end

return animator
