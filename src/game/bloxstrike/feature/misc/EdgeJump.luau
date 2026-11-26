local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local ClientController = require("@game/bloxstrike/client/ClientController")
local flightState = require("@game/bloxstrike/feature/misc/flightState")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local peek = Charm.peek

local MIN_SPEED = 2
local LEAD_FRAMES = 1
local MIN_AHEAD = 1
local EDGE_DROP_VECTOR = Vector3.new(0, -4, 0)
local MIN_GROUND_NORMAL_Y = 0.5
local WALL_NORMAL_Y = 0.5
local WALL_PAD = 2

local EdgeJump = {}
EdgeJump.__index = EdgeJump

setmetatable(EdgeJump, { __index = BaseFeature })

function EdgeJump.new(link: gameUi.Linker): EdgeJump
	local self = BaseFeature.new() :: any
	setmetatable(self, EdgeJump)

	link:Toggle("edgeJump", "Edge Jump", false):SetTip({
		title = "Edge Jump",
		body = "Jumps automatically right before you walk off a ledge.",
	})

	self._activeJanitor = nil :: Janitor.Janitor?
	self._rayParams = RaycastParams.new()
	self._rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self._filterChar = nil :: Instance?

	self:Track(link:Get("edgeJump"):OnChange(function(value: boolean)
		self:_setEnabled(value)
	end))

	return self
end

EdgeJump._tryJump = LPH_NO_VIRTUALIZE(function(self: EdgeJump, deltaTime: number): ()
	if peek(flightState.enabled) then
		return
	end

	local character = ClientController.GetCharacterObject()
	if not character then
		return
	end
	if ClientController.IsClimbing() then
		return
	end

	local hrp = character.HumanoidRootPart :: BasePart?
	if not hrp then
		return
	end

	local velocity = character.GlobalVelocity :: Vector3?
	if not velocity then
		return
	end
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = flat.Magnitude
	if speed < MIN_SPEED then
		return
	end

	if not character:CheckGroundContact() then
		return
	end

	local dir = flat / speed
	local aheadDist = math.max(MIN_AHEAD, speed * deltaTime * LEAD_FRAMES)

	local charModel = character.Character
	if charModel ~= self._filterChar then
		self._filterChar = charModel
		self._rayParams.FilterDescendantsInstances = { charModel }
	end

	local wall = Workspace:Raycast(hrp.Position, dir * (aheadDist + WALL_PAD), self._rayParams)
	if wall and math.abs(wall.Normal.Y) < WALL_NORMAL_Y then
		return
	end

	local origin = hrp.Position + dir * aheadDist
	local hit = Workspace:Raycast(origin, EDGE_DROP_VECTOR, self._rayParams)
	if not hit or hit.Normal.Y < MIN_GROUND_NORMAL_Y then
		rawset(character, "IsJumpRequested", true)
		character:Jump()
	end
end)

function EdgeJump._setEnabled(self: EdgeJump, enabled: boolean): ()
	if enabled then
		if self._activeJanitor then
			return
		end
		local janitor = Janitor.new()
		self._activeJanitor = janitor

		janitor:Add(
			RunService.Stepped:Connect(LPH_NO_VIRTUALIZE(function(_, deltaTime: number): ()
				self:_tryJump(deltaTime)
			end)),
			"Disconnect"
		)
	else
		local janitor = self._activeJanitor
		if not janitor then
			return
		end
		self._activeJanitor = nil
		janitor:Destroy()
	end
end

function EdgeJump.Destroy(self: EdgeJump): ()
	self:_setEnabled(false)
	BaseFeature.Destroy(self)
end

export type EdgeJump =
	typeof(setmetatable(
		{} :: {
			_activeJanitor: Janitor.Janitor?,
			_rayParams: RaycastParams,
			_filterChar: Instance?,
		},
		EdgeJump
	))
	& BaseFeature.BaseFeature

return EdgeJump
