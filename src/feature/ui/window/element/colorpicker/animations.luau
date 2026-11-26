export type AnimationKey = string

export type AnimationContext = {
	color: Color3 | ColorSequence,
	rotation: number,
	transparency: number?,
	speed: number,
	time: number,
}

export type AnimationResult = {
	color: Color3 | ColorSequence,
	rotation: number,
	transparency: number,
}

export type Animation = {
	key: AnimationKey,
	label: string,
	appliesTo: (isSequence: boolean, hasTransparency: boolean) -> boolean,
	apply: (ctx: AnimationContext) -> AnimationResult,
}

local function shiftHue(c3: Color3, offset: number): Color3
	local h, s, v = c3:ToHSV()
	return Color3.fromHSV((h + offset) % 1, s, v)
end

local function evalWrapped(kps: { ColorSequenceKeypoint }, t: number): Color3
	local n = #kps
	local first = kps[1]
	local last = kps[n]
	if t <= first.Time or t >= last.Time then
		local span = first.Time + 1 - last.Time
		if span < 1e-6 then
			return first.Value
		end
		local dt = t - last.Time
		if dt < 0 then
			dt += 1
		end
		return last.Value:Lerp(first.Value, dt / span)
	end
	for i = 2, n do
		local kp = kps[i]
		if t <= kp.Time then
			local prev = kps[i - 1]
			local span = kp.Time - prev.Time
			if span < 1e-6 then
				return kp.Value
			end
			return prev.Value:Lerp(kp.Value, (t - prev.Time) / span)
		end
	end
	return last.Value
end

local function scrollSequence(seq: ColorSequence, offset: number): ColorSequence
	local kps = seq.Keypoints
	local n = #kps
	local edge = evalWrapped(kps, (1 - offset) % 1)
	local out = { ColorSequenceKeypoint.new(0, edge) }
	local count = 1
	local function push(time: number, value: Color3): ()
		if time <= 1e-4 or time >= 1 - 1e-4 then
			return
		end
		local prevTime = out[count].Time
		if time - prevTime < 1e-4 then
			time = prevTime + 1e-4
			if time >= 1 - 1e-4 then
				return
			end
		end
		count += 1
		out[count] = ColorSequenceKeypoint.new(time, value)
	end
	for i = 1, n do
		local t = kps[i].Time + offset
		if t >= 1 then
			push(t - 1, kps[i].Value)
		end
	end
	for i = 1, n do
		local t = kps[i].Time + offset
		if t < 1 then
			push(t, kps[i].Value)
		end
	end
	out[count + 1] = ColorSequenceKeypoint.new(1, edge)
	return ColorSequence.new(out)
end

local function staticApply(ctx: AnimationContext): AnimationResult
	return {
		color = ctx.color,
		rotation = ctx.rotation,
		transparency = ctx.transparency or 0,
	}
end

local function alwaysApplies(): boolean
	return true
end

local function sequenceOnly(isSequence: boolean): boolean
	return isSequence
end

local function transparencyOnly(_isSequence: boolean, hasTransparency: boolean): boolean
	return hasTransparency
end

local list: { Animation } = {
	{
		key = "none",
		label = "None",
		appliesTo = alwaysApplies,
		apply = staticApply,
	},
	{
		key = "shimmer",
		label = "Shimmer",
		appliesTo = sequenceOnly,
		apply = function(ctx: AnimationContext): AnimationResult
			return {
				color = ctx.color,
				rotation = (ctx.rotation + ctx.time * ctx.speed * 60) % 360,
				transparency = ctx.transparency or 0,
			}
		end,
	},
	{
		key = "flow",
		label = "Flow",
		appliesTo = sequenceOnly,
		apply = function(ctx: AnimationContext): AnimationResult
			local color = ctx.color
			if typeof(color) == "ColorSequence" then
				color = scrollSequence(color, (ctx.time * ctx.speed * 0.2) % 1)
			end
			return {
				color = color,
				rotation = ctx.rotation,
				transparency = ctx.transparency or 0,
			}
		end,
	},
	{
		key = "rainbow",
		label = "Rainbow",
		appliesTo = alwaysApplies,
		apply = function(ctx: AnimationContext): AnimationResult
			local offset = (ctx.time * ctx.speed * 0.2) % 1
			local color = ctx.color
			if typeof(color) == "ColorSequence" then
				local kps = color.Keypoints
				local newKps = table.create(#kps)
				for i = 1, #kps do
					local kp = kps[i]
					newKps[i] = ColorSequenceKeypoint.new(kp.Time, shiftHue(kp.Value, offset))
				end
				return {
					color = ColorSequence.new(newKps),
					rotation = ctx.rotation,
					transparency = ctx.transparency or 0,
				}
			end
			return {
				color = shiftHue(color :: Color3, offset),
				rotation = ctx.rotation,
				transparency = ctx.transparency or 0,
			}
		end,
	},
	{
		key = "blink",
		label = "Blink",
		appliesTo = transparencyOnly,
		apply = function(ctx: AnimationContext): AnimationResult
			local base = ctx.transparency or 0
			local phase = (ctx.time * ctx.speed) % 1
			local ease = (1 - math.cos(phase * math.pi * 2)) * 0.5
			return {
				color = ctx.color,
				rotation = ctx.rotation,
				transparency = base + (1 - base) * ease,
			}
		end,
	},
}

local byKey: { [string]: Animation } = {}
local byLabel: { [string]: Animation } = {}
for _, anim in next, list do
	byKey[anim.key] = anim
	byLabel[anim.label] = anim
end

local animations = {}

animations.list = list

function animations.getByKey(key: string): Animation?
	return byKey[key]
end

function animations.getKey(label: string): string?
	local anim = byLabel[label]
	return (anim and anim.key or nil)
end

function animations.getLabel(key: string): string
	local anim = byKey[key]
	return (anim and anim.label or "None")
end

function animations.hasMotion(key: string): boolean
	return key ~= "none" and byKey[key] ~= nil
end

function animations.getApplicable(isSequence: boolean, hasTransparency: boolean): { Animation }
	local result: { Animation } = {}
	for _, anim in next, list do
		if anim.appliesTo(isSequence, hasTransparency) then
			table.insert(result, anim)
		end
	end
	return result
end

function animations.getApplicableLabels(isSequence: boolean, hasTransparency: boolean): { string }
	local applicable = animations.getApplicable(isSequence, hasTransparency)
	local result: { string } = table.create(#applicable)
	for i, anim in next, applicable do
		result[i] = anim.label
	end
	return result
end

function animations.appliesTo(key: string, isSequence: boolean, hasTransparency: boolean): boolean
	local anim = byKey[key]
	if not anim then
		return false
	end
	return anim.appliesTo(isSequence, hasTransparency)
end

function animations.apply(ctx: AnimationContext, key: string): AnimationResult
	local anim = byKey[key]
	if not anim then
		return staticApply(ctx)
	end
	return anim.apply(ctx)
end

return animations
