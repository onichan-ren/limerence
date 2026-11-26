local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local AnimatorHook = require("@game/ar2/animator/AnimatorHook")
local ModuleController = require("@game/ar2/module/ModuleController")

local ViewmodelChanger = {}
ViewmodelChanger.__index = ViewmodelChanger

setmetatable(ViewmodelChanger, { __index = BaseFeature })

local localPlayerModule: any = nil
local function getCharacterObject(): any
	if not localPlayerModule then
		local module = ModuleController.GetModule("LocalPlayer")
		localPlayerModule = module and module.module
	end
	local getter = localPlayerModule and localPlayerModule.get
	local arLocalPlayer = getter and getter()
	return arLocalPlayer and arLocalPlayer.Character or nil
end

function ViewmodelChanger.new(link: gameUi.Linker): ViewmodelChanger
	local self = BaseFeature.new() :: any
	setmetatable(self, ViewmodelChanger)

	link:Toggle("viewmodelChanger", "Viewmodel Changer", false):SetTip({
		title = "Viewmodel Changer",
		body = "Lets you adjust the viewmodel position and roll.",
	})
	local viewmodelChangerLink = link:OnKey("viewmodelChanger")
	viewmodelChangerLink:Submenu("opts", "Viewmodel Changer")
	local optionsLink = viewmodelChangerLink:OnKey("opts")
	optionsLink:Slider("x", "Offset X", 0, -2, 2, 0.05, nil, "st"):SetTip({
		title = "Offset X",
		body = "Moves the viewmodel left or right.",
	})
	optionsLink:Slider("y", "Offset Y", 0, -2, 2, 0.05, nil, "st"):SetTip({
		title = "Offset Y",
		body = "Moves the viewmodel up or down.",
	})
	optionsLink:Slider("z", "Offset Z", 0, -2, 2, 0.05, nil, "st"):SetTip({
		title = "Offset Z",
		body = "Moves the viewmodel forward or backward. Positive values move it forward.",
	})
	optionsLink:Slider("roll", "Roll", 0, -180, 180, 1, nil, "°"):SetTip({
		title = "Roll",
		body = "Rotates the viewmodel around the camera axis.",
	})
	optionsLink:Toggle("resetOnAim", "Reset While Aiming", true):SetTip({
		title = "Reset While Aiming",
		body = "Fades the offset out as you aim in so sights line up properly.",
	})

	self._x = optionsLink:Peek("x") or 0
	self._y = optionsLink:Peek("y") or 0
	self._z = optionsLink:Peek("z") or 0
	self._roll = optionsLink:Peek("roll") or 0
	self._resetOnAim = optionsLink:Get("resetOnAim"):Peek()
	self._enabled = false
	self._unsub = nil :: (() -> ())?
	self._savedCFrame = nil :: CFrame?

	self:Track(link:Get("viewmodelChanger"):OnChange(function(state: boolean): ()
		if state then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optionsLink:Get("x"):OnChange(function(value: number): ()
		self._x = value
	end))
	self:Track(optionsLink:Get("y"):OnChange(function(value: number): ()
		self._y = value
	end))
	self:Track(optionsLink:Get("z"):OnChange(function(value: number): ()
		self._z = value
	end))
	self:Track(optionsLink:Get("roll"):OnChange(function(value: number): ()
		self._roll = value
	end))
	self:Track(optionsLink:Get("resetOnAim"):OnChange(function(value: boolean): ()
		self._resetOnAim = value
	end))

	if link:Peek("viewmodelChanger") then
		self:Enable()
	end

	return self
end

function ViewmodelChanger._getOffsetCFrame(self: ViewmodelChanger): CFrame
	return CFrame.new(self._x, self._y, -self._z) * CFrame.Angles(0, 0, math.rad(self._roll))
end

function ViewmodelChanger.Enable(self: ViewmodelChanger): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._unsub = AnimatorHook.subscribe({
		pre = function(): ()
			local camera = Workspace.CurrentCamera
			if not camera then
				return
			end
			if self._x == 0 and self._y == 0 and self._z == 0 and self._roll == 0 then
				self._savedCFrame = nil
				return
			end
			if self._resetOnAim then
				local character = getCharacterObject()
				if character and character.Zooming == true then
					self._savedCFrame = nil
					return
				end
			end
			local current = camera.CFrame
			self._savedCFrame = current
			camera.CFrame = current * self:_getOffsetCFrame()
		end,
		post = function(): ()
			local saved = self._savedCFrame
			if not saved then
				return
			end
			self._savedCFrame = nil
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame = saved
			end
		end,
	})
end

function ViewmodelChanger.Disable(self: ViewmodelChanger): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._unsub then
		self._unsub()
		self._unsub = nil
	end
	self._savedCFrame = nil
end

function ViewmodelChanger.Destroy(self: ViewmodelChanger): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type ViewmodelChanger =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_unsub: (() -> ())?,
			_x: number,
			_y: number,
			_z: number,
			_roll: number,
			_resetOnAim: boolean,
			_savedCFrame: CFrame?,
			_getOffsetCFrame: (ViewmodelChanger) -> CFrame,
		},
		ViewmodelChanger
	))
	& BaseFeature.BaseFeature

return ViewmodelChanger
