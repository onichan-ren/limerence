local AssetService = cloneref(game:GetService("AssetService"))

local v2 = Vector2.new

local COMBINE_TYPE = Enum.ImageCombineType.Overwrite
local CLEAR = Color3.new(0, 0, 0)
local HORIZONTAL_FACTOR = 0.75

local mfloor = math.floor
local mround = math.round
local mmax = math.max
local mmin = math.min
local mcos = math.cos
local msin = math.sin
local mrad = math.rad
local writeu8 = buffer.writeu8
local readu8 = buffer.readu8

export type CornerOpts = {
	length: number,
	thickness: number,
	gap: number,
	gradient: ColorSequence,
	rotation: number,
	lineTransparency: number,
	outline: boolean,
	outlineThickness: number,
	outlineColor: Color3,
	outlineTransparency: number,
}

export type CornerImage = {
	content: any,
	cell: number,
	len: number,
	image: any,
}

local buildLut = LPH_NO_VIRTUALIZE(function(gradient: ColorSequence): buffer
	local lut = buffer.create(256 * 3)
	local kps = gradient.Keypoints
	local n = #kps
	local first = kps[1].Value
	local last = kps[n].Value

	for i = 0, 255 do
		local t = i / 255
		local col: Color3

		if t <= kps[1].Time then
			col = first
		elseif t >= kps[n].Time then
			col = last
		else
			col = last
			for k = 1, n - 1 do
				local a = kps[k]
				local b = kps[k + 1]
				if t <= b.Time then
					local span = b.Time - a.Time
					local f = span > 0 and (t - a.Time) / span or 0
					col = a.Value:Lerp(b.Value, f)
					break
				end
			end
		end

		local li = i * 3
		writeu8(lut, li, mfloor(col.R * 255 + 0.5))
		writeu8(lut, li + 1, mfloor(col.G * 255 + 0.5))
		writeu8(lut, li + 2, mfloor(col.B * 255 + 0.5))
	end

	return lut
end)

local paintRect = LPH_NO_VIRTUALIZE(
	function(
		img: any,
		x: number,
		y: number,
		w: number,
		h: number,
		lut: buffer,
		alpha: number,
		dx: number,
		dy: number,
		minProj: number,
		range: number
	): ()
		local buf = buffer.create(w * h * 4)
		local o = 0

		for py = 0, h - 1 do
			local rowProj = (y + py + 0.5) * dy
			for px = 0, w - 1 do
				local proj = (x + px + 0.5) * dx + rowProj
				local t = (proj - minProj) / range

				local idx
				if t <= 0 then
					idx = 0
				elseif t >= 1 then
					idx = 765
				else
					idx = mfloor(t * 255 + 0.5) * 3
				end

				writeu8(buf, o, readu8(lut, idx))
				writeu8(buf, o + 1, readu8(lut, idx + 1))
				writeu8(buf, o + 2, readu8(lut, idx + 2))
				writeu8(buf, o + 3, alpha)
				o += 4
			end
		end

		img:WritePixelsBuffer(v2(x, y), v2(w, h), buf)
	end
)

local drawCorner = LPH_NO_VIRTUALIZE(
	function(
		img: any,
		elbowX: number,
		elbowY: number,
		dirX: number,
		dirY: number,
		opts: CornerOpts,
		lut: buffer,
		alpha: number,
		dx: number,
		dy: number,
		minProj: number,
		range: number
	): ()
		local L = opts.length
		local LH = mmax(1, mround(L * HORIZONTAL_FACTOR))
		local T = opts.thickness
		local O = opts.outline and opts.outlineThickness or 0

		local hx = dirX > 0 and elbowX or elbowX - LH
		local hy = dirY > 0 and elbowY or elbowY - T
		local vx = dirX > 0 and elbowX or elbowX - T
		local vy = dirY > 0 and elbowY or elbowY - L

		if O > 0 then
			img:DrawRectangle(
				v2(hx - O, hy - O),
				v2(LH + O * 2, T + O * 2),
				opts.outlineColor,
				opts.outlineTransparency,
				COMBINE_TYPE
			)
			img:DrawRectangle(
				v2(vx - O, vy - O),
				v2(T + O * 2, L + O * 2),
				opts.outlineColor,
				opts.outlineTransparency,
				COMBINE_TYPE
			)
		end

		paintRect(img, hx, hy, LH, T, lut, alpha, dx, dy, minProj, range)
		paintRect(img, vx, vy, T, L, lut, alpha, dx, dy, minProj, range)
	end
)

local generate = LPH_NO_VIRTUALIZE(function(opts: CornerOpts): CornerImage
	local O = opts.outline and opts.outlineThickness or 0
	local base = opts.gap + O
	local S = base + opts.length + O + 1
	local size = S * 2 + 2

	local img = AssetService:CreateEditableImage({ Size = v2(size, size) })
	img:DrawRectangle(v2(0, 0), v2(size, size), CLEAR, 1, COMBINE_TYPE)

	local rad = mrad(opts.rotation)
	local dx = mcos(rad)
	local dy = msin(rad)
	local minProj = size * (mmin(0, dx) + mmin(0, dy))
	local maxProj = size * (mmax(0, dx) + mmax(0, dy))
	local range = maxProj - minProj
	if range <= 0 then
		range = 1
	end

	local lut = buildLut(opts.gradient)
	local alpha = mfloor((1 - opts.lineTransparency) * 255 + 0.5)

	drawCorner(img, base, base, 1, 1, opts, lut, alpha, dx, dy, minProj, range)
	drawCorner(img, size - base, base, -1, 1, opts, lut, alpha, dx, dy, minProj, range)
	drawCorner(img, base, size - base, 1, -1, opts, lut, alpha, dx, dy, minProj, range)
	drawCorner(img, size - base, size - base, -1, -1, opts, lut, alpha, dx, dy, minProj, range)

	return {
		content = Content.fromObject(img),
		cell = S,
		len = opts.length,
		image = img,
	}
end)

return {
	generate = generate,
}
