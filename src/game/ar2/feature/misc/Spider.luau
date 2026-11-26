local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService
local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local clientState = require("@game/ar2/client/clientState")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local WALL_DISTANCE = 4
local STICK_SPEED = 6
local WALL_NORMAL_LIMIT = 0.6
local WALL_SAMPLE_OFFSETS = { 0, 2.5, -2.5 }

local HEIGHT_STEP = 4
local HEIGHT_MAX_STEPS = 50
local HEIGHT_SPEED_SCALE = 0.5
local MAX_SPEED_MULT = 3
local ABS_MAX_SPEED = 150

local peek = Charm.peek
local sub = Charm.subscribe

local _parts: { [BasePart]: true } = {}
local _touched: { [BasePart]: true } = {}

local function rebuildParts(character: Instance): ()
	table.clear(_parts)
	for _, part in next, character:QueryDescendants("Instance") do
		if part:IsA("BasePart") then
			_parts[part] = true
		end
	end
end

local function applyNoclip(): ()
	for part in next, _parts do
		if part.CanCollide then
			part.CanCollide = false
			_touched[part] = true
		end
	end
end

local function restoreNoclip(): ()
	for part in next, _touched do
		if part.Parent then
			part.CanCollide = true
		end
		_touched[part] = nil
	end
end

local Spider = {}
Spider.__index = Spider

setmetatable(Spider, { __index = BaseFeature })

local computeWishDir = LPH_NO_VIRTUALIZE(function(): Vector3
	local camera = Workspace.CurrentCamera
	if not camera then
		return Vector3.zero
	end
	local cf = camera.CFrame
	local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local flatRight = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)

	if flatLook.Magnitude < 0.001 or flatRight.Magnitude < 0.001 then
		return Vector3.zero
	end

	flatLook = flatLook.Unit
	flatRight = flatRight.Unit

	local wish = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		wish += flatLook
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		wish -= flatLook
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		wish += flatRight
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		wish -= flatRight
	end

	return (wish.Magnitude > 0.001 and wish.Unit or Vector3.zero)
end)

local castWall = LPH_NO_VIRTUALIZE(function(origin: Vector3, dir: Vector3, params: RaycastParams): RaycastResult?
	for _, oy in next, WALL_SAMPLE_OFFSETS do
		local result = Workspace:Raycast(origin + Vector3.new(0, oy, 0), dir, params)
		if result and math.abs(result.Normal.Y) <= WALL_NORMAL_LIMIT then
			return result
		end
	end
	return nil
end)

local measureWallHeight = LPH_NO_VIRTUALIZE(function(basePos: Vector3, into: Vector3, params: RaycastParams): number
	local probe = into * (WALL_DISTANCE + 4)
	local height = 0
	for i = 1, HEIGHT_MAX_STEPS do
		local samplePos = basePos + Vector3.new(0, i * HEIGHT_STEP, 0)
		local result = Workspace:Raycast(samplePos, probe, params)
		if not result or math.abs(result.Normal.Y) > WALL_NORMAL_LIMIT then
			break
		end
		height = i * HEIGHT_STEP
	end
	return height
end)

function Spider.new(link: gameUi.Linker): Spider
	local self = BaseFeature.new() :: any
	setmetatable(self, Spider)

	link:Toggle("spider", "Spider", false):SetTip({
		title = "Spider",
		body = "Hold a movement key into any wall to climb it.",
	})
	local spiderLink = link:OnKey("spider")
	spiderLink:Submenu("opts", "Spider")
	local optionsLink = spiderLink:OnKey("opts")
	optionsLink:Slider("speed", "Climb Speed", 30, 5, 80, 1):SetTip({
		title = "Climb Speed",
		body = "Base climb speed. Taller walls scale faster.",
	})
	optionsLink:Toggle("noclip", "Climb Noclip", false):SetTip({
		title = "Climb Noclip",
		body = "Pass through ledges and overhangs while climbing.",
	})

	self._speed = 30
	self._noclip = false
	self._activeJanitor = nil :: Janitor.Janitor?
	self._descConn = nil :: RBXScriptConnection?
	self._charUnsub = nil :: (() -> ())?
	self._params = RaycastParams.new()
	self._params.FilterType = Enum.RaycastFilterType.Exclude
	self._params.RespectCanCollide = true
	self._filter = {} :: { Instance }

	self:Track(link:Get("spider"):OnChange(function(value: boolean)
		self:_setEnabled(value)
	end))

	self:Track(link:Watch("spider.opts.speed", function(value: number)
		self._speed = value
	end))

	self:Track(link:Watch("spider.opts.noclip", function(value: boolean)
		self._noclip = value
		if not value then
			restoreNoclip()
		end
	end))

	self._speed = tonumber(link:Peek("spider.opts.speed")) or 30
	self._noclip = link:Peek("spider.opts.noclip") == true

	if link:Peek("spider") then
		self:_setEnabled(true)
	end

	return self
end

function Spider._bindCharacter(self: Spider, character: Instance?): ()
	restoreNoclip()

	if self._descConn then
		self._descConn:Disconnect()
		self._descConn = nil
	end

	table.clear(_parts)

	if not character then
		return
	end

	rebuildParts(character)
	self._descConn = character.DescendantAdded:Connect(function(part: Instance): ()
		if part:IsA("BasePart") then
			_parts[part] = true
		end
	end)
end

function Spider._setEnabled(self: Spider, enabled: boolean): ()
	if enabled then
		if self._activeJanitor then
			return
		end
		local janitor = Janitor.new()
		self._activeJanitor = janitor

		self:_bindCharacter(peek(clientState.character))
		self._charUnsub = sub(clientState.character, function(character: Instance?): ()
			self:_bindCharacter(character)
		end)

		janitor:Add(
			RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
				if not peek(clientState.alive) then
					restoreNoclip()
					return
				end

				local hrp = peek(clientState.hrp)
				if not hrp then
					restoreNoclip()
					return
				end

				local wish = computeWishDir()
				if wish.Magnitude < 0.001 then
					restoreNoclip()
					return
				end

				local filter = self._filter
				filter[1] = peek(clientState.character) :: any
				filter[2] = Workspace.CurrentCamera
				self._params.FilterDescendantsInstances = filter

				local result = castWall(hrp.Position, wish * WALL_DISTANCE, self._params)
				if not result then
					restoreNoclip()
					return
				end

				local into = Vector3.new(-result.Normal.X, 0, -result.Normal.Z)
				into = into.Magnitude > 0.001 and into.Unit or wish

				local wallHeight = measureWallHeight(result.Position, into, self._params)
				local bonus = wallHeight * HEIGHT_SPEED_SCALE
				local ceiling = math.min(self._speed * MAX_SPEED_MULT, ABS_MAX_SPEED)
				local climbSpeed = math.clamp(self._speed + bonus, self._speed, ceiling)

				if self._noclip then
					applyNoclip()
					hrp.AssemblyLinearVelocity = Vector3.new(0, climbSpeed, 0)
				else
					restoreNoclip()
					hrp.AssemblyLinearVelocity = into * STICK_SPEED + Vector3.new(0, climbSpeed, 0)
				end
			end)),
			"Disconnect"
		)
	else
		local janitor = self._activeJanitor
		if not janitor then
			return
		end
		self._activeJanitor = nil

		local charUnsub = self._charUnsub
		if charUnsub then
			charUnsub()
			self._charUnsub = nil
		end

		if self._descConn then
			self._descConn:Disconnect()
			self._descConn = nil
		end

		restoreNoclip()
		table.clear(_parts)
		janitor:Destroy()
	end
end

function Spider.Destroy(self: Spider): ()
	self:_setEnabled(false)
	BaseFeature.Destroy(self)
end

export type Spider =
	typeof(setmetatable(
		{} :: {
			_speed: number,
			_noclip: boolean,
			_activeJanitor: Janitor.Janitor?,
			_descConn: RBXScriptConnection?,
			_charUnsub: (() -> ())?,
			_params: RaycastParams,
			_filter: { Instance },
		},
		Spider
	))
	& BaseFeature.BaseFeature

return Spider
