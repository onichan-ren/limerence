local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")

local Players = cloneref(game:GetService("Players")) :: Players
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local RunService = cloneref(game:GetService("RunService")) :: RunService

local LocalPlayer = Players.LocalPlayer

local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)
local THIN_Y = 0.01
local GROUND_LIFT = 0.05
local DOWN_RAY = Vector3.new(0, -12, 0)
local PLANT_DOWN = 0.35
local PLANT_UP = 0.7
local STRIDE = 1.8
local STANCE_OFFSET = 0.55
local FOOT_SIZE_X = 0.9
local FOOT_SIZE_Z = 1.5
local FADE_IN = 0.12
local GROW_IN = 0.24
local SPAWN_SCALE = 0.55
local GLOW = 5
local MAX_PRINTS = 60
local FOOT_NAMES = { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }
local SHADING = Enum.AdornShading.XRay

export type FootstepsOpts = {
	getCharacter: () -> Instance?,
	isAlive: () -> boolean,
	getParts: (() -> { [string]: Instance })?,
	getRoot: (() -> BasePart?)?,
	isGrounded: (() -> boolean)?,
}

type Print = {
	part: Part,
	adorn: BoxHandleAdornment,
	spawn: number,
	sizeX: number,
	sizeZ: number,
	grown: boolean,
	color: Color3,
}

local function glowColor(color: Color3): Color3
	return Color3.new(color.R * GLOW, color.G * GLOW, color.B * GLOW)
end

local Footsteps = {}
Footsteps.__index = Footsteps

setmetatable(Footsteps, { __index = BaseFeature })

function Footsteps.new(link: gameUi.Linker, opts: FootstepsOpts): Footsteps
	local self = BaseFeature.new() :: any
	setmetatable(self, Footsteps)

	self._getCharacter = opts.getCharacter
	self._isAlive = opts.isAlive
	self._getParts = opts.getParts
	self._getRoot = opts.getRoot
	self._isGrounded = opts.isGrounded

	self._enabled = false
	self._renderConn = nil :: RBXScriptConnection?
	self._folder = nil :: Folder?
	self._prints = {} :: { Print }
	self._lastPos = nil :: Vector3?
	self._lastStance = nil :: string?
	self._footState = {} :: { [string]: boolean }
	self._footPrintPos = {} :: { [string]: Vector3 }
	self._lifetime = 2.5
	self._behindWalls = true
	self._rayChar = nil :: Instance?
	self._rayLocalChar = nil :: Instance?
	self._cacheChar = nil :: Instance?
	self._cacheMap = nil :: { [string]: Instance }?
	self._rayParams = RaycastParams.new()
	self._rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self._rayParams.RespectCanCollide = true

	local toggle = link:Toggle("footsteps", "Footsteps", false):SetTip({
		title = "Footsteps",
		body = "Leaves a fading glow on the ground with every step.",
	})
	local footLink = link:OnKey("footsteps")
	footLink:Extra(toggle, "color", "Colorpicker", "Color", DEFAULT_COLOR, 0)
	footLink:Extra(toggle, "opts", "Submenu", "Footsteps Options")
	local optsLink = footLink:OnKey("opts")
	optsLink:Slider("lifetime", "Lifetime", 2.5, 0.5, 8, 0.1, nil, "s"):SetTip({
		title = "Lifetime",
		body = "How long each footstep stays before fading.",
	})
	optsLink:Toggle("behindWalls", "Behind Walls", true):SetTip({
		title = "Behind Walls",
		body = "Keeps footsteps visible through solid geometry.",
	})

	self._colorLink = footLink:Get("color")
	self._lifetime = optsLink:Peek("lifetime") or 2.5
	self._behindWalls = optsLink:Peek("behindWalls") ~= false

	self:Track(link:Get("footsteps"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))
	self:Track(optsLink:Get("lifetime"):OnChange(function(value: number): ()
		self._lifetime = value
	end))
	self:Track(optsLink:Get("behindWalls"):OnChange(function(value: boolean): ()
		self._behindWalls = value
		local prints = self._prints
		for i = 1, #prints do
			prints[i].adorn.AlwaysOnTop = value
		end
	end))

	if link:Peek("footsteps") then
		self:Enable()
	end

	return self
end

function Footsteps._color(self: Footsteps): Color3
	return (self._colorLink._currentColor :: any):getValue()
end

function Footsteps._transparency(self: Footsteps): number
	return self._colorLink:GetTransparency()
end

function Footsteps._partsFor(self: Footsteps, character: Instance): { [string]: Instance }
	local getParts = self._getParts
	if getParts then
		return getParts()
	end

	if self._cacheChar == character and self._cacheMap then
		return self._cacheMap
	end

	local map = {}
	for _, child in next, character:GetChildren() do
		map[child.Name :: any] = child
	end

	if map.HumanoidRootPart then
		self._cacheChar = character
		self._cacheMap = map
	end

	return map
end

function Footsteps._spawnPrint(self: Footsteps, footCF: CFrame, groundPos: Vector3, normal: Vector3, sizeX: number, sizeZ: number, glow: Color3): ()
	local folder = self._folder
	if not folder then
		return
	end

	local up = normal.Magnitude > 1e-4 and normal.Unit or Vector3.yAxis
	local fwd = footCF.LookVector
	fwd = fwd - up * fwd:Dot(up)
	if fwd.Magnitude < 1e-3 then
		fwd = footCF.RightVector - up * footCF.RightVector:Dot(up)
	end
	if fwd.Magnitude < 1e-3 then
		fwd = Vector3.new(up.Y, up.Z, up.X)
		fwd = fwd - up * fwd:Dot(up)
	end
	fwd = fwd.Unit
	local right = up:Cross(fwd).Unit

	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = CFrame.fromMatrix(groundPos + up * GROUND_LIFT, right, up)
	part.Parent = folder

	local adorn = Instance.new("BoxHandleAdornment")
	adorn.Adornee = part
	adorn.AlwaysOnTop = self._behindWalls
	adorn.ZIndex = 0
	adorn.Shading = SHADING
	adorn.Size = Vector3.new(sizeX * SPAWN_SCALE, THIN_Y, sizeZ * SPAWN_SCALE)
	adorn.Color3 = glow
	adorn.Transparency = 1
	adorn.Parent = part

	local prints = self._prints
	prints[#prints + 1] =
		{ part = part, adorn = adorn, spawn = os.clock(), sizeX = sizeX, sizeZ = sizeZ, grown = false, color = glow }

	if #prints > MAX_PRINTS then
		local oldest = table.remove(prints, 1)
		if oldest then
			oldest.part:Destroy()
		end
	end
end

Footsteps._tryStep = LPH_NO_VIRTUALIZE(function(self: Footsteps, character: Instance, glow: Color3): ()
	local localChar = LocalPlayer.Character
	if self._rayChar ~= character or self._rayLocalChar ~= localChar then
		self._rayChar = character
		self._rayLocalChar = localChar
		local filter = { character, self._folder :: any }
		if localChar and localChar ~= character then
			filter[#filter + 1] = localChar :: any
		end
		self._rayParams.FilterDescendantsInstances = filter
	end

	local parts = self:_partsFor(character)
	local hrp = parts.HumanoidRootPart :: BasePart?
	if not hrp then
		self._lastPos = nil
		table.clear(self._footState)
		return
	end

	local grounded = not (self._isGrounded ~= nil and not self._isGrounded())
	local footState = self._footState
	local footPrintPos = self._footPrintPos

	for _, name in next, FOOT_NAMES do
		local foot = parts[name] :: BasePart?
		if foot and foot.Parent then
			local footCF = foot.CFrame
			local result = Workspace:Raycast(footCF.Position, DOWN_RAY, self._rayParams)
			local gap = result and (result.Distance - foot.Size.Y * 0.5) or math.huge

			if gap <= PLANT_DOWN then
				if not footState[name] then
					footState[name] = true
					if grounded and result then
						self:_spawnPrint(footCF, result.Position, result.Normal, foot.Size.X, foot.Size.Z, glow)
						footPrintPos[name] = footCF.Position
					end
				elseif grounded and result then
					local lastPrint = footPrintPos[name]
					if lastPrint then
						local dx = footCF.Position.X - lastPrint.X
						local dz = footCF.Position.Z - lastPrint.Z
						if dx * dx + dz * dz >= STRIDE * STRIDE then
							self:_spawnPrint(footCF, result.Position, result.Normal, foot.Size.X, foot.Size.Z, glow)
							footPrintPos[name] = footCF.Position
						end
					else
						footPrintPos[name] = footCF.Position
					end
				end
			elseif gap >= PLANT_UP then
				footState[name] = false
			end
		else
			footState[name] = nil
			footPrintPos[name] = nil
		end
	end
end)

Footsteps._tryStepRoot = LPH_NO_VIRTUALIZE(function(self: Footsteps, character: Instance, glow: Color3): ()
	local getRoot = self._getRoot
	local root = getRoot and getRoot()
	if not root then
		self._lastPos = nil
		self._lastStance = nil
		return
	end

	local localChar = LocalPlayer.Character
	if self._rayChar ~= character or self._rayLocalChar ~= localChar then
		self._rayChar = character
		self._rayLocalChar = localChar
		local filter = { character, self._folder :: any }
		if localChar and localChar ~= character then
			filter[#filter + 1] = localChar :: any
		end
		self._rayParams.FilterDescendantsInstances = filter
	end

	local cf = root.CFrame
	local pos = cf.Position
	local last = self._lastPos
	if not last then
		self._lastPos = pos
		self._lastStance = "Right"
		return
	end

	local dx = pos.X - last.X
	local dz = pos.Z - last.Z
	if dx * dx + dz * dz < STRIDE * STRIDE then
		return
	end

	if self._isGrounded and not self._isGrounded() then
		self._lastPos = pos
		return
	end

	local side = self._lastStance == "Left" and "Right" or "Left"
	local sign = side == "Left" and -1 or 1
	local footPos = pos + cf.RightVector * (sign * STANCE_OFFSET)
	local result = Workspace:Raycast(footPos, DOWN_RAY, self._rayParams)
	self._lastPos = pos
	self._lastStance = side
	if not result then
		return
	end

	self:_spawnPrint(cf, result.Position, result.Normal, FOOT_SIZE_X, FOOT_SIZE_Z, glow)
end)

Footsteps._render = LPH_NO_VIRTUALIZE(function(self: Footsteps): ()
	local now = os.clock()
	local lifetime = self._lifetime
	local baseTransparency = self:_transparency()
	local glow = glowColor(self:_color())

	local character = self._getCharacter()
	if character ~= nil and self._isAlive() then
		if self._getRoot then
			self:_tryStepRoot(character, glow)
		else
			self:_tryStep(character, glow)
		end
	else
		self._lastPos = nil
		self._lastStance = nil
		self._rayChar = nil
		self._rayLocalChar = nil
		table.clear(self._footState)
	end

	local prints = self._prints
	for i = #prints, 1, -1 do
		local entry = prints[i]
		local age = now - entry.spawn

		if age >= lifetime then
			entry.part:Destroy()
			table.remove(prints, i)
			continue
		end

		local vis: number
		if age < FADE_IN then
			local t = age / FADE_IN
			vis = t * t * (3 - 2 * t)
		else
			local frac = math.clamp(1 - (age - FADE_IN) / math.max(lifetime - FADE_IN, 0.01), 0, 1)
			vis = frac * frac * (3 - 2 * frac)
		end

		if not entry.grown then
			if age < GROW_IN then
				local g = age / GROW_IN
				local inv = 1 - g
				local scale = SPAWN_SCALE + (1 - SPAWN_SCALE) * (1 - inv * inv * inv)
				entry.adorn.Size = Vector3.new(entry.sizeX * scale, THIN_Y, entry.sizeZ * scale)
			else
				entry.adorn.Size = Vector3.new(entry.sizeX, THIN_Y, entry.sizeZ)
				entry.grown = true
			end
		end

		if entry.color ~= glow then
			entry.color = glow
			entry.adorn.Color3 = glow
		end
		entry.adorn.Transparency = baseTransparency + (1 - vis) * (1 - baseTransparency)
	end
end)

function Footsteps.Enable(self: Footsteps): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local folder = Instance.new("Folder")
	folder.Parent = Workspace
	self._folder = folder
	self._lastPos = nil
	self._lastStance = nil
	self._rayChar = nil
	self._rayLocalChar = nil
	table.clear(self._footState)

	self._renderConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
		self:_render()
	end))
end

function Footsteps.Disable(self: Footsteps): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._renderConn then
		self._renderConn:Disconnect()
		self._renderConn = nil
	end

	if self._folder then
		self._folder:Destroy()
		self._folder = nil
	end

	table.clear(self._prints)
	table.clear(self._footState)
	self._lastPos = nil
	self._lastStance = nil
	self._rayChar = nil
	self._rayLocalChar = nil
	self._cacheChar = nil
	self._cacheMap = nil
end

function Footsteps.Destroy(self: Footsteps): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type Footsteps =
	typeof(setmetatable(
		{} :: {
			_getCharacter: () -> Instance?,
			_isAlive: () -> boolean,
			_getParts: (() -> { [string]: Instance })?,
			_getRoot: (() -> BasePart?)?,
			_isGrounded: (() -> boolean)?,
			_enabled: boolean,
			_renderConn: RBXScriptConnection?,
			_folder: Folder?,
			_prints: { Print },
			_lastPos: Vector3?,
			_lastStance: string?,
			_footState: { [string]: boolean },
			_lifetime: number,
			_behindWalls: boolean,
			_rayChar: Instance?,
			_rayLocalChar: Instance?,
			_cacheChar: Instance?,
			_cacheMap: { [string]: Instance }?,
			_rayParams: RaycastParams,
			_colorLink: any,
			_color: (Footsteps) -> Color3,
			_transparency: (Footsteps) -> number,
			_partsFor: (Footsteps, Instance) -> { [string]: Instance },
			_spawnPrint: (Footsteps, CFrame, Vector3, Vector3, number, number, Color3) -> (),
			_tryStep: (Footsteps, Instance, Color3) -> (),
			_tryStepRoot: (Footsteps, Instance, Color3) -> (),
			_render: (Footsteps) -> (),
		},
		Footsteps
	))
	& BaseFeature.BaseFeature

return Footsteps
