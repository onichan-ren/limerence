local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local worldMapSource = require("@game/rivals/feature/visual/world/worldMapSource")

local LocalPlayer = Players.LocalPlayer

local function getDuelController(): any?
	local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
	local controllers = scripts and scripts:FindFirstChild("Controllers")
	local module = controllers and controllers:FindFirstChild("DuelController")
	if not module then
		return nil
	end
	setthreadidentity(2)
	local controller = require(module :: ModuleScript)
	setthreadidentity(8)
	return controller
end

local function resolveMapModel(): Instance?
	local controller = getDuelController()
	if not controller or type(controller.GetDuel) ~= "function" then
		return nil
	end
	setthreadidentity(2)
	local duel = controller.GetDuel(controller, LocalPlayer)
	setthreadidentity(8)
	if type(duel) ~= "table" then
		return nil
	end
	local map = duel.Map
	local model = map and map.Model
	if typeof(model) == "Instance" then
		return model
	end
	return nil
end

local TransparentWalls = {}
TransparentWalls.__index = TransparentWalls

setmetatable(TransparentWalls, { __index = BaseFeature })

function TransparentWalls.new(link: gameUi.Linker): TransparentWalls
	local self = BaseFeature.new() :: any
	setmetatable(self, TransparentWalls)

	local toggle = link:Toggle("transparentWalls", "Transparent Walls", false):SetTip({
		title = "Transparent Walls",
		body = "Makes the map see-through so you can spot enemies behind cover.",
	})
	local wallsLink = link:OnKey("transparentWalls")
	wallsLink:Submenu("opts", "Transparent Walls Options")
	local optsLink = wallsLink:OnKey("opts")
	optsLink:Slider("amount", "Transparency", 70, 1, 100, 1, nil, "%"):SetTip({
		title = "Transparency",
		body = "How see-through the map is. 100% is fully invisible.",
	})

	self._enabled = false
	self._amountLink = optsLink:Get("amount")
	self._value = self._amountLink:Peek() / 100
	self._tracked = setmetatable({}, { __mode = "k" }) :: any
	self._janitor = Janitor.new()
	self._mapJanitor = Janitor.new()

	self:Track(toggle:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(self._amountLink:OnChange(function(value: number): ()
		self._value = value / 100
		self:_reapply()
	end))

	return self
end

function TransparentWalls._apply(self: TransparentWalls): ()
	self._mapJanitor:Cleanup()

	local model = resolveMapModel()
	if not model then
		return
	end

	local tracked = self._tracked
	local value = self._value
	for _, part in next, model:QueryDescendants("BasePart") do
		tracked[part] = true
		part.LocalTransparencyModifier = value
	end

	self._mapJanitor:Add(
		model.DescendantAdded:Connect(LPH_NO_VIRTUALIZE(function(descendant: Instance): ()
			if self._enabled and descendant:IsA("BasePart") then
				tracked[descendant] = true
				descendant.LocalTransparencyModifier = self._value
			end
		end)),
		"Disconnect"
	)
end

function TransparentWalls._reapply(self: TransparentWalls): ()
	if not self._enabled then
		return
	end
	local value = self._value
	for part in next, self._tracked do
		if part.Parent then
			part.LocalTransparencyModifier = value
		end
	end
end

function TransparentWalls._restore(self: TransparentWalls): ()
	for part in next, self._tracked do
		if part.Parent then
			part.LocalTransparencyModifier = 0
		end
		self._tracked[part] = nil
	end
end

function TransparentWalls.Enable(self: TransparentWalls): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self:_apply()
	self._janitor:Add(worldMapSource.Changed(function(): ()
		task.defer(function(): ()
			if self._enabled then
				self:_apply()
			end
		end)
	end))
end

function TransparentWalls.Disable(self: TransparentWalls): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self._janitor:Cleanup()
	self._mapJanitor:Cleanup()
	self:_restore()
end

function TransparentWalls.Destroy(self: TransparentWalls): ()
	self:Disable()
	self._janitor:Destroy()
	self._mapJanitor:Destroy()
	BaseFeature.Destroy(self)
end

export type TransparentWalls =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_amountLink: any,
			_value: number,
			_tracked: any,
			_janitor: Janitor.Janitor,
			_mapJanitor: Janitor.Janitor,
		},
		TransparentWalls
	))
	& BaseFeature.BaseFeature

return TransparentWalls
