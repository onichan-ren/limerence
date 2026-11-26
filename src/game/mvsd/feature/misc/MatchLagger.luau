local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage
local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService
local RunService = cloneref(game:GetService("RunService")) :: RunService
local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local clientState = require("@game/mvsd/client/clientState")
local Charm = require("@pkg/Charm")

local Event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ThrowStart")
local LocalPlayer = Players.LocalPlayer

local peek = Charm.peek

local LAG_DIRECTION = Vector3.new(0.87198334932327, -0.32144331932068, -0.36921432614326)

local findKnifeTool = LPH_NO_VIRTUALIZE(function(): Tool?
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not backpack then
		return nil
	end
	for _, child in next, backpack:GetChildren() do
		if child:IsA("Tool") and CollectionService:HasTag(child, "KnifeTool") then
			return child
		end
	end
	return nil
end)

local MatchLagger = {}
MatchLagger.__index = MatchLagger

setmetatable(MatchLagger, { __index = BaseFeature })

function MatchLagger.new(link: gameUi.Linker): MatchLagger
	local self = BaseFeature.new() :: any
	setmetatable(self, MatchLagger)

	link:Toggle("matchLagger", "Match Lagger", false):SetTip({
		title = "Match Lagger",
		body = "Lags every player in your server instantly, they will likely crash.",
	})

	self._janitor = Janitor.new()

	self:Track(link:Get("matchLagger"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("matchLagger") then
		self:Enable()
	end

	return self
end

MatchLagger._tick = LPH_JIT_MAX(function(self: MatchLagger): ()
	if not self._enabled then
		return
	end

	if not peek(clientState.alive) then
		return
	end

	local localMatch = peek(clientState.matchId)
	if localMatch == nil then
		return
	end

	if peek(clientState.weapon) ~= "knife" then
		local humanoid = peek(clientState.humanoid)
		local tool = findKnifeTool()
		if humanoid and tool then
			humanoid:EquipTool(tool)
		end
		return
	end

	local hrp = peek(clientState.parts).HumanoidRootPart
	if not hrp then
		return
	end

	Event:FireServer(hrp.Position, LAG_DIRECTION)
end)

function MatchLagger.Enable(self: MatchLagger): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._janitor:Add(RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
		self:_tick()
	end)))
end

function MatchLagger.Disable(self: MatchLagger): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function MatchLagger.Destroy(self: MatchLagger): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type MatchLagger =
	typeof(setmetatable(
		{} :: {
			_janitor: Janitor.Janitor,
			_enabled: boolean,
			_tick: (MatchLagger) -> (),
		},
		MatchLagger
	))
	& BaseFeature.BaseFeature

return MatchLagger
