local evalWrapped = LPH_NO_VIRTUALIZE(function(kps: { ColorSequenceKeypoint }, t: number): Color3
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
end)

local scrollSequence = LPH_NO_VIRTUALIZE(function(seq: ColorSequence, offset: number): ColorSequence
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
end)

local animatedColor = LPH_NO_VIRTUALIZE(
	function(
		color: Color3 | ColorSequence,
		transparency: number?,
		rotation: number,
		animation: string,
		speed: number,
		now: number
	): (Color3 | ColorSequence, number, number)
		local activeColor: Color3 | ColorSequence = color
		local activeRotation = rotation
		local activeTransparency = transparency or 0

		if animation == "shimmer" and typeof(color) == "ColorSequence" then
			activeRotation = (rotation + now * speed * 60) % 360
		elseif animation == "flow" and typeof(color) == "ColorSequence" then
			activeColor = scrollSequence(color, (now * speed * 0.2) % 1)
		elseif animation == "rainbow" and typeof(color) == "ColorSequence" then
			local hueOffset = (now * speed * 0.2) % 1
			local kps = (color :: ColorSequence).Keypoints
			local newKps = table.create(#kps)
			for i, kp in kps do
				local h, s, v = kp.Value:ToHSV()
				newKps[i] = ColorSequenceKeypoint.new(kp.Time, Color3.fromHSV((h + hueOffset) % 1, s, v))
			end
			activeColor = ColorSequence.new(newKps)
		elseif animation == "blink" and transparency ~= nil then
			local phase = math.floor(now * speed * 2) % 2
			if phase == 1 then
				activeTransparency = 1
			end
		end

		return activeColor, activeRotation, activeTransparency
	end
)

return animatedColor
