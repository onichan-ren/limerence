local RunService = cloneref(game:GetService("RunService")) :: RunService

local React = require("@pkg/React")
local fovVisualization = require("@game/universal/feature/combat/legitbot/fovVisualization")

local subscribeToBinding = (React :: any).__subscribeToBinding

local FOV_COLOR = ColorSequence.new(Color3.fromRGB(196, 184, 255))
local FOV_OUTLINE_COLOR = ColorSequence.new(Color3.fromRGB(255, 255, 255))
local FOV_TRANSPARENCY = 0.5
local FOV_OUTLINE_TRANSPARENCY = 0

export type AttachOpts = {
	getEnabled: () -> boolean,
	getFovLimit: () -> number,
}

local ragebotFov = {}

function ragebotFov.attach(feature: any, link: any, opts: AttachOpts): ()
	link:Toggle("fieldOfView", "Field of View", false):SetTip({
		title = "Field of View",
		body = "Draws a circle on screen showing the FOV Limit range. Does not change how targeting works.",
	})
	local fovLink = link:OnKey("fieldOfView")
	fovLink:Submenu("opts", "Field of View")
	local fovOptsLink = fovLink:OnKey("opts")
	fovOptsLink:Colorpicker("outlineColor", "Outline Color", FOV_OUTLINE_COLOR, FOV_OUTLINE_TRANSPARENCY):SetTip({
		title = "Outline Color",
		body = "Border color of the Ragebot FOV circle.",
	})
	fovOptsLink:Colorpicker("color", "Fill Color", FOV_COLOR, FOV_TRANSPARENCY):SetTip({
		title = "Fill Color",
		body = "Fill color of the Ragebot FOV circle.",
	})

	local cache = {
		color = FOV_COLOR,
		transparency = FOV_TRANSPARENCY,
		rotation = 0,
		outlineColor = FOV_OUTLINE_COLOR,
		outlineTransparency = FOV_OUTLINE_TRANSPARENCY,
		outlineRotation = 0,
	}

	local viz = fovVisualization.new()
	local renderOpts = {
		enabled = false,
		fov = 0,
		color = FOV_COLOR,
		outlineColor = FOV_OUTLINE_COLOR,
		transparency = 1,
		outlineTransparency = 1,
		rotation = 0,
		outlineRotation = 0,
	} :: fovVisualization.FovOpts

	local getEnabled = opts.getEnabled
	local getFovLimit = opts.getFovLimit
	local conn: RBXScriptConnection? = nil

	local renderTick = LPH_NO_VIRTUALIZE(function(): ()
		if not getEnabled() then
			renderOpts.enabled = false
			viz:Update(renderOpts)
			return
		end
		renderOpts.enabled = true
		renderOpts.fov = getFovLimit()
		renderOpts.color = cache.color
		renderOpts.outlineColor = cache.outlineColor
		renderOpts.transparency = cache.transparency
		renderOpts.outlineTransparency = cache.outlineTransparency
		renderOpts.rotation = cache.rotation
		renderOpts.outlineRotation = cache.outlineRotation
		viz:Update(renderOpts)
	end)

	local function setActive(active: boolean): ()
		if active then
			if not conn then
				conn = RunService.PreRender:Connect(renderTick)
			end
		else
			if conn then
				conn:Disconnect()
				conn = nil
			end
			renderOpts.enabled = false
			viz:Update(renderOpts)
		end
	end

	setActive(link:Peek("fieldOfView") == true)
	feature:Track(link:Get("fieldOfView"):OnChange(function(v: boolean): ()
		setActive(v == true)
	end))

	local function trackColor(relKey: string, assign: (ColorSequence) -> ()): ()
		local el = link:Get(relKey)
		if not el or not el._currentGradient then
			return
		end
		local binding = el._currentGradient
		assign((binding :: any):getValue())
		feature:Track(subscribeToBinding(binding, assign))
	end
	local function trackTransparency(relKey: string, assign: (number) -> ()): ()
		local el = link:Get(relKey)
		if not el or not el._currentTransparency then
			return
		end
		local binding = el._currentTransparency
		assign((binding :: any):getValue())
		feature:Track(subscribeToBinding(binding, assign))
	end
	local function trackRotation(relKey: string, assign: (number) -> ()): ()
		local el = link:Get(relKey)
		if not el or not el._currentRotation then
			return
		end
		local binding = el._currentRotation
		assign((binding :: any):getValue())
		feature:Track(subscribeToBinding(binding, assign))
	end

	trackColor("fieldOfView.opts.color", function(c: ColorSequence): ()
		cache.color = c
	end)
	trackColor("fieldOfView.opts.outlineColor", function(c: ColorSequence): ()
		cache.outlineColor = c
	end)
	trackTransparency("fieldOfView.opts.color", function(n: number): ()
		cache.transparency = n
	end)
	trackTransparency("fieldOfView.opts.outlineColor", function(n: number): ()
		cache.outlineTransparency = n
	end)
	trackRotation("fieldOfView.opts.color", function(n: number): ()
		cache.rotation = n
	end)
	trackRotation("fieldOfView.opts.outlineColor", function(n: number): ()
		cache.outlineRotation = n
	end)

	feature:Track(function(): ()
		setActive(false)
		viz:Destroy()
	end)
end

return ragebotFov
