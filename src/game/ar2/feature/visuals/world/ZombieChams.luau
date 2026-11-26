local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ZombieController = require("@game/ar2/zombie/ZombieController")
local chamsSession = require("@game/universal/feature/visual/chams/chamsSession")

local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local peek = Charm.peek

local MATERIALS: { string } = {
	"ForceField",
	"Neon",
}

local DEFAULT_COLOR = Color3.fromRGB(120, 200, 130)
local DEFAULT_MATERIAL = "ForceField"
local DEFAULT_MAX_DISTANCE = 300
local DISTANCE_STEP = 0.2

local function shouldPatchPart(inst: Instance): boolean
	if not inst:IsA("BasePart") then
		return false
	end
	return (inst :: BasePart).Transparency < 1
end

local function zombiePosition(zombie: Model): Vector3?
	local primary = zombie.PrimaryPart
	if primary then
		return primary.Position
	end
	local pivot = zombie:GetPivot()
	if typeof(pivot) == "CFrame" then
		return pivot.Position
	end
	return nil
end

local ZombieChams = {}
ZombieChams.__index = ZombieChams

setmetatable(ZombieChams, { __index = BaseFeature })

function ZombieChams.new(link: gameUi.Linker): ZombieChams
	local self = BaseFeature.new() :: any
	setmetatable(self, ZombieChams)

	self._enabled = false
	self._activeJanitor = nil :: Janitor.Janitor?
	self._active = {} :: { [Model]: Janitor.Janitor }
	self._activeParts = {} :: { [Model]: { [BasePart]: true } }
	self._ltm = {} :: { [BasePart]: number }
	self._session = chamsSession.new({
		overlayMeshParts = false,
		skipTransparency = false,
		lockAppearance = false,
		lockTransparency = false,
	})

	local chamsToggle = link:Toggle("zombieChams", "Zombie Chams", false):SetTip({
		title = "Zombie Chams",
		body = "Recolors zombies so they stand out.",
	})
	local chamsLink = link:OnKey("zombieChams")
	chamsLink:Extra(chamsToggle, "color", "Colorpicker", "Color", DEFAULT_COLOR, 0)
	chamsLink:Extra(chamsToggle, "opts", "Submenu", "Zombie Chams Options")
	local optsLink = chamsLink:OnKey("opts")
	optsLink:Dropdown("material", "Material", MATERIALS, DEFAULT_MATERIAL):SetTip({
		title = "Material",
		body = "Material applied to zombies.",
	})
	optsLink:Slider("maxDistance", "Max Distance", DEFAULT_MAX_DISTANCE, 50, 1500, 25, nil, "st"):SetTip({
		title = "Max Distance",
		body = "Only recolors zombies within this distance.",
	})

	self._colorLink = chamsLink:Get("color")
	self._materialLink = optsLink:Get("material")
	self._maxDistanceLink = optsLink:Get("maxDistance")

	self:Track(link:Get("zombieChams"):OnChange(function(state: boolean): ()
		if state then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("zombieChams") then
		self:Enable()
	end

	return self
end

function ZombieChams._material(self: ZombieChams): Enum.Material
	local name = self._materialLink:Peek() or DEFAULT_MATERIAL
	return (Enum.Material :: any)[name] or Enum.Material.ForceField
end

function ZombieChams._color(self: ZombieChams): Color3
	return (self._colorLink :: any):GetColor()
end

function ZombieChams._transparency(self: ZombieChams): number
	return (self._colorLink :: any):GetTransparency()
end

function ZombieChams._style(self: ZombieChams): chamsSession.Style
	return {
		material = self:_material(),
		color = self:_color(),
		transparency = self:_transparency(),
		reflectance = 0,
	}
end

function ZombieChams._applyPart(self: ZombieChams, zombie: Model, part: BasePart): ()
	if self._ltm[part] ~= nil or not shouldPatchPart(part) then
		return
	end

	self._ltm[part] = part.LocalTransparencyModifier
	self._session.apply(part, self:_style())
	part.LocalTransparencyModifier = 0

	local parts = self._activeParts[zombie]
	if parts then
		parts[part] = true
	end
end

function ZombieChams._restorePart(self: ZombieChams, part: BasePart): ()
	local ltm = self._ltm[part]
	if ltm == nil then
		return
	end
	self._ltm[part] = nil

	self._session.restore(part)
	if part.Parent then
		part.LocalTransparencyModifier = ltm
	end
end

function ZombieChams._refreshStyle(self: ZombieChams): ()
	local style = self:_style()
	for part in next, self._ltm do
		self._session.apply(part, style)
	end
end

function ZombieChams._activateZombie(self: ZombieChams, zombie: Model): ()
	if self._active[zombie] then
		return
	end

	local janitor = Janitor.new()
	self._active[zombie] = janitor
	self._activeParts[zombie] = {}

	for _, desc in next, zombie:QueryDescendants("BasePart") do
		self:_applyPart(zombie, desc :: BasePart)
	end

	janitor:Add(
		zombie.DescendantAdded:Connect(function(desc: Instance): ()
			if desc:IsA("BasePart") then
				self:_applyPart(zombie, desc :: BasePart)
			else
				self._session.onDescendantAdded(desc)
			end
		end),
		"Disconnect"
	)

	janitor:Add(
		zombie.DescendantRemoving:Connect(function(desc: Instance): ()
			if desc:IsA("BasePart") and self._ltm[desc] ~= nil then
				self._ltm[desc :: BasePart] = nil
				self._session.restore(desc :: BasePart)
				local parts = self._activeParts[zombie]
				if parts then
					parts[desc :: BasePart] = nil
				end
			end
		end),
		"Disconnect"
	)
end

function ZombieChams._deactivateZombie(self: ZombieChams, zombie: Model): ()
	local janitor = self._active[zombie]
	if not janitor then
		return
	end
	self._active[zombie] = nil
	janitor:Destroy()

	local parts = self._activeParts[zombie]
	self._activeParts[zombie] = nil
	if parts then
		for part in next, parts do
			self:_restorePart(part)
		end
	end
end

local stepDistance = LPH_NO_VIRTUALIZE(function(self: ZombieChams): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local maxDistance = peek(self._maxDistanceLink._state) :: number
	local maxDistSq = maxDistance * maxDistance
	local camPos = camera.CFrame.Position

	for zombie in next, ZombieController.GetZombies() do
		local pos = zombiePosition(zombie)
		local within = false
		if pos then
			local dx = pos.X - camPos.X
			local dy = pos.Y - camPos.Y
			local dz = pos.Z - camPos.Z
			within = dx * dx + dy * dy + dz * dz <= maxDistSq
		end

		if within then
			self:_activateZombie(zombie)
		else
			self:_deactivateZombie(zombie)
		end
	end
end)

function ZombieChams.Enable(self: ZombieChams): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local janitor = Janitor.new()
	self._activeJanitor = janitor

	janitor:Add(
		ZombieController.zombieRemoved:Connect(function(zombie: Model): ()
			self:_deactivateZombie(zombie)
		end),
		"Disconnect"
	)

	local accumulator = DISTANCE_STEP
	janitor:Add(
		RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(dt: number): ()
			accumulator += dt
			if accumulator < DISTANCE_STEP then
				return
			end
			accumulator = 0
			stepDistance(self)
		end)),
		"Disconnect"
	)

	janitor:Add(self._colorLink:OnUpdate(function(): ()
		self:_refreshStyle()
	end))

	janitor:Add(self._materialLink:OnChange(function(): ()
		self:_refreshStyle()
	end))
end

function ZombieChams.Disable(self: ZombieChams): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	for zombie in next, self._active do
		self:_deactivateZombie(zombie)
	end

	for part in next, self._ltm do
		self:_restorePart(part)
	end

	if self._activeJanitor then
		self._activeJanitor:Destroy()
		self._activeJanitor = nil
	end
end

function ZombieChams.Destroy(self: ZombieChams): ()
	self:Disable()
	self._session.destroy()
	BaseFeature.Destroy(self)
end

export type ZombieChams =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_activeJanitor: Janitor.Janitor?,
			_active: { [Model]: Janitor.Janitor },
			_activeParts: { [Model]: { [BasePart]: true } },
			_ltm: { [BasePart]: number },
			_session: chamsSession.Session,
			_colorLink: any,
			_materialLink: any,
			_maxDistanceLink: any,
		},
		ZombieChams
	))
	& BaseFeature.BaseFeature

return ZombieChams
