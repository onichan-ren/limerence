local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local clientState = require("@game/op1/client/clientState")
local grenadeSim = require("@game/op1/grenade/grenadeSim")
local worldPath = require("@game/op1/grenade/worldPath")

local RunService = cloneref(game:GetService("RunService"))
local Workspace = cloneref(game:GetService("Workspace"))
local Terrain = Workspace.Terrain

local peek = Charm.peek

local DEFAULT_PATH_COLOR = Color3.fromRGB(150, 200, 255)
local DEFAULT_IMPACT_COLOR = Color3.fromRGB(255, 235, 150)

local GrenadePrediction = {}
GrenadePrediction.__index = GrenadePrediction

setmetatable(GrenadePrediction, { __index = BaseFeature })

export type GrenadePrediction = typeof(setmetatable({} :: any, GrenadePrediction))

local function isThrowable(equipped: any): boolean
	if type(equipped) ~= "table" then
		return false
	end
	local states = equipped.states
	return states ~= nil and type(states.throw_speed) == "table" and type(states.aiming) == "table"
end

function GrenadePrediction.new(link: gameUi.Linker): GrenadePrediction
	local self = BaseFeature.new() :: any
	setmetatable(self, GrenadePrediction)

	self._pathColor = ColorSequence.new(DEFAULT_PATH_COLOR)
	self._impactColor = DEFAULT_IMPACT_COLOR
	self._path = nil :: worldPath.worldPath?
	self._activeJanitor = nil :: Janitor.Janitor?
	self._ignore = {} :: { Instance }
	self._rootModel = nil :: Instance?
	self._rootPart = nil :: BasePart?

	link:Toggle("grenadePrediction", "Grenade Prediction", false):SetTip({
		title = "Grenade Prediction",
		body = "Draws the predicted arc and landing point of the grenade you are holding.",
	})
	link:Extra(link:Get("grenadePrediction"), "grenadePredictionOpts", "Submenu", "Grenade Prediction")
	local optsLink = link:OnKey("grenadePredictionOpts")
	self._optsLink = optsLink

	optsLink:Colorpicker("pathColor", "Path", DEFAULT_PATH_COLOR, 0):SetTip({
		title = "Path",
		body = "Color of the predicted arc.",
	})
	optsLink:Colorpicker("impactColor", "Impact", DEFAULT_IMPACT_COLOR, 0):SetTip({
		title = "Impact",
		body = "Color of the landing marker.",
	})

	self._enabledLink = link:Get("grenadePrediction")

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if self._enabledLink:Peek() then
		self:Enable()
	end

	return self
end

function GrenadePrediction.refreshColors(self: GrenadePrediction): ()
	local opts = self._optsLink
	local pathPicker: any = opts:Get("pathColor")
	local impactPicker: any = opts:Get("impactColor")

	if pathPicker then
		self._pathColor = ColorSequence.new(pathPicker:GetColor())
	end
	if impactPicker then
		self._impactColor = impactPicker:GetColor()
	end
end

function GrenadePrediction.update(self: GrenadePrediction): ()
	local path = self._path
	if not path then
		return
	end

	local charObject = peek(clientState.charObject)
	if not charObject or not charObject.values then
		path:Hide()
		return
	end

	local equipped = charObject.values.equipped
	if not isThrowable(equipped) then
		path:Hide()
		return
	end

	local model = equipped.instance
	local root = self._rootPart
	if model ~= self._rootModel or not root or root.Parent ~= model then
		self._rootModel = model
		root = model and model:FindFirstChild("Root")
		self._rootPart = root
	end
	local cameraValue = charObject.values.camera and charObject.values.camera:get()

	if not root or not cameraValue then
		path:Hide()
		return
	end

	local speed = equipped.states.throw_speed:get()
	if type(speed) ~= "number" or speed <= 0 then
		speed = type(equipped.stats) == "table" and tonumber(equipped.stats.throw_speed) or 0
	end
	if speed <= 0 then
		path:Hide()
		return
	end

	local look = cameraValue.CFrame.LookVector
	local velocity = look * speed + Vector3.new(0, speed * 0.3, 0)
	local bounces = equipped.bounces or 1
	local origin = root.CFrame.Position

	local ignore = self._ignore
	table.clear(ignore)
	ignore[1] = Terrain
	local instance = charObject.instance
	if instance then
		ignore[#ignore + 1] = instance
	end
	local viewmodels = charObject.values.viewmodels
	if viewmodels then
		ignore[#ignore + 1] = viewmodels
	end
	local result = grenadeSim.simulate(root, origin, velocity, ignore, bounces)

	path:Update(result.points, self._pathColor, self._impactColor)
end

function GrenadePrediction.Enable(self: GrenadePrediction): ()
	if self._activeJanitor then
		return
	end

	local janitor = Janitor.new()
	self._activeJanitor = janitor

	local path = worldPath.new()
	self._path = path
	janitor:Add(function(): ()
		path:Destroy()
		self._path = nil
	end, true)

	self:refreshColors()

	local opts = self._optsLink
	local pathPicker: any = opts:Get("pathColor")
	local impactPicker: any = opts:Get("impactColor")
	if pathPicker then
		janitor:Add(pathPicker:OnUpdate(function(): ()
			self:refreshColors()
		end), true)
	end
	if impactPicker then
		janitor:Add(impactPicker:OnUpdate(function(): ()
			self:refreshColors()
		end), true)
	end

	janitor:Add(RunService.RenderStepped:Connect(LPH_NO_VIRTUALIZE(function(): ()
		self:update()
	end)), "Disconnect")
end

function GrenadePrediction.Disable(self: GrenadePrediction): ()
	local janitor = self._activeJanitor
	if janitor then
		janitor:Destroy()
		self._activeJanitor = nil
	end
end

function GrenadePrediction.Destroy(self: GrenadePrediction): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

return GrenadePrediction
