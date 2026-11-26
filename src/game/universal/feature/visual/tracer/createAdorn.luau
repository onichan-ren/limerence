local instances = require("@share/instances")

local HIDDEN_UI = cloneref(gethui())

local GLOW_SCALE = 10
local THICKNESS_STUDS = 0.02

local _folder: Folder? = nil

local function ensureFolder(): Folder
	local folder = _folder
	if folder and folder.Parent then
		return folder
	end
	folder = instances.new("Folder", {
		Name = "TracerAdorns",
		Secure = true,
	}, HIDDEN_UI) :: Folder
	_folder = folder
	return folder :: Folder
end

export type AdornHandle = {
	part: BasePart,
	adorn: BoxHandleAdornment,
	setColor: (color: Color3) -> (),
	setThickness: (thickness: number) -> (),
	setTransparency: (transparency: number) -> (),
	destroy: () -> (),
}

local glowColor = LPH_NO_VIRTUALIZE(function(color: Color3): Color3
	return Color3.new(color.R * GLOW_SCALE, color.G * GLOW_SCALE, color.B * GLOW_SCALE)
end)

local createAdorn = function(origin: Vector3, target: Vector3): AdornHandle
	local folder = ensureFolder()

	local offset = target - origin
	local length = offset.Magnitude
	local midpoint = origin + offset * 0.5

	local part = instances.new("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one,
		CFrame = length > 1e-4 and CFrame.lookAt(midpoint, target) or CFrame.new(midpoint),
		Secure = true,
	}, folder) :: BasePart

	local thickness = THICKNESS_STUDS

	local adorn = instances.new("BoxHandleAdornment", {
		Adornee = part,
		AlwaysOnTop = true,
		ZIndex = 9,
		Size = Vector3.new(thickness, thickness, length),
		Transparency = 0,
		Color3 = Color3.new(1, 1, 1),
		Secure = true,
	}, folder) :: BoxHandleAdornment
	(adorn :: any).Shading = Enum.AdornShading.XRayShaded

	local destroyed = false
	return {
		part = part,
		adorn = adorn,
		setColor = function(color: Color3): ()
			adorn.Color3 = glowColor(color)
		end,
		setThickness = function(value: number): ()
			thickness = value * THICKNESS_STUDS
			adorn.Size = Vector3.new(thickness, thickness, length)
		end,
		setTransparency = function(transparency: number): ()
			adorn.Transparency = transparency
		end,
		destroy = function(): ()
			if destroyed then
				return
			end
			destroyed = true
			adorn:Destroy()
			part:Destroy()
		end,
	}
end

return createAdorn
