local RunService = cloneref(game:GetService("RunService")) :: RunService
local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local BaseFeature = require("@game/BaseFeature")
local ModuleController = require("@game/ar2/module/ModuleController")
local customScope = require("@game/universal/feature/visual/removescope/customScope")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local hook = require("@share/hook")

local e = React.createElement
local peek = Charm.peek

local DEFAULT_CUSTOM_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(225, 225, 225)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
})
local DYNAMIC_GAP_MAX_PX = 140

local CustomScope = {}
CustomScope.__index = CustomScope

setmetatable(CustomScope, { __index = BaseFeature })

function CustomScope.new(link: gameUi.Linker): CustomScope
	local self = BaseFeature.new() :: any
	setmetatable(self, CustomScope)

	local toggle = link:Toggle("customScope", "Custom Scope Overlay", false):SetTip({
		title = "Custom Scope Overlay",
		body = "Replaces the aiming sight picture with your own crosshair.",
	})
	local scopeLink = link:OnKey("customScope")
	scopeLink:Extra(toggle, "opts", "Submenu", "Custom Scope Overlay")
	local optsLink = scopeLink:OnKey("opts")
	optsLink:Colorpicker("color", "Color", DEFAULT_CUSTOM_COLOR, 0):SetTip({
		title = "Color",
		body = "Color or gradient applied to the crosshair arms.",
	})
	optsLink:Slider("gap", "Gap", 8, 0, 80, 1, nil, "px"):SetTip({
		title = "Gap",
		body = "Pixel distance from the center to the inner edge of each arm.",
	})
	optsLink:Slider("length", "Length", 14, 1, 80, 1, nil, "px"):SetTip({
		title = "Length",
		body = "Pixel length of each arm.",
	})
	optsLink:Slider("thickness", "Thickness", 3, 1, 12, 1, nil, "px"):SetTip({
		title = "Thickness",
		body = "Pixel thickness of each arm.",
	})
	optsLink:Toggle("dynamicGap", "Dynamic Gap", false):SetTip({
		title = "Dynamic Gap",
		body = "Expands the gap when your weapon's spread grows (movement, jumping).",
	})

	self._enabled = false
	self._optsLink = optsLink
	self._dynamicGapLink = optsLink:Get("dynamicGap")
	self._sightGlass = nil
	self._sightPictures = nil
	self._sightGlassBlocked = false
	self._screenGui = nil
	self._root = nil
	self._visibleAtom = Charm.atom(false)
	self._spreadAtom = Charm.atom(0)
	self._renderConn = nil

	self:Track(link:Get("customScope"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("customScope") then
		self:Enable()
	end

	return self
end

function CustomScope._resolveSightPictures(self: CustomScope): Instance?
	if self._sightPictures then
		return self._sightPictures
	end
	local reticleModule = ModuleController.GetModule("Reticle")
	local sightGlass = reticleModule and rawget(reticleModule.module, "SightGlass")
	if not sightGlass then
		return nil
	end
	local master = sightGlass.Parent
	local source = master and master.Parent
	local folder = source and source:FindFirstChild("Sight Pictures")
	self._sightPictures = folder
	return folder
end

function CustomScope._hasScope(self: CustomScope, equippedItem: any): boolean
	local folder = self:_resolveSightPictures()
	if not folder then
		return false
	end
	local name = equippedItem.Name
	local attachments = equippedItem.Attachments
	local sight = attachments and attachments.Sight
	if sight and sight.Name then
		name = sight.Name
	end
	return name ~= nil and folder:FindFirstChild(name) ~= nil
end

function CustomScope._blockSightGlass(self: CustomScope): ()
	if self._sightGlassBlocked then
		return
	end

	local sightGlass = self._sightGlass
	if not sightGlass then
		local reticleModule = ModuleController.GetModule("Reticle")
		sightGlass = reticleModule and rawget(reticleModule.module, "SightGlass")
		self._sightGlass = sightGlass
	end
	if not sightGlass then
		return
	end

	hook.addInstance(sightGlass)
	hook.blockProperty(sightGlass, "Visible")
	sightGlass.Visible = false
	self._sightGlassBlocked = true
end

function CustomScope._unblockSightGlass(self: CustomScope): ()
	if not self._sightGlassBlocked then
		return
	end

	local sightGlass = self._sightGlass
	if sightGlass then
		hook.unblockProperty(sightGlass, "Visible")
	end
	self._sightGlassBlocked = false
end

function CustomScope._createOverlay(self: CustomScope): ()
	if self._screenGui then
		return
	end

	local screenGui = instances.new("ScreenGui", {
		Name = "CustomScopeOverlay",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 26,
		Enabled = true,
		Secure = true,
	}, cloneref(gethui())) :: ScreenGui

	local optsLink = self._optsLink
	local root = ReactRoblox.createRoot(screenGui)
	root:render(e(customScope, {
		enabledAtom = self._visibleAtom,
		gapLink = optsLink:Get("gap"),
		lengthLink = optsLink:Get("length"),
		thicknessLink = optsLink:Get("thickness"),
		colorLink = optsLink:Get("color"),
		spreadAtom = self._spreadAtom,
	}))

	self._screenGui = screenGui
	self._root = root
end

function CustomScope._destroyOverlay(self: CustomScope): ()
	if self._root then
		self._root:unmount()
		self._root = nil
	end
	if self._screenGui then
		self._screenGui:Destroy()
		self._screenGui = nil
	end
	self._visibleAtom(false)
	self._spreadAtom(0)
end

function CustomScope._bindRender(self: CustomScope): ()
	if self._renderConn then
		return
	end

	local playersModule = ModuleController.GetModule("LocalPlayer")
	local camerasModule = ModuleController.GetModule("Cameras")
	local bulletsModule = ModuleController.GetModule("Bullets")
	if not playersModule or not camerasModule or not bulletsModule then
		return
	end

	local arLocalPlayer = playersModule.module.get()
	local camera = camerasModule.module:GetCamera("Character")
	local bullets = bulletsModule.module
	local visibleAtom = self._visibleAtom
	local spreadAtom = self._spreadAtom
	local dynamicGapLink = self._dynamicGapLink

	self._renderConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
		local visible = false
		local character = arLocalPlayer.Character

		if character and camera.FirstPerson and character.Zooming then
			local equippedItem = character.EquippedItem
			if equippedItem and equippedItem.Type == "Firearm" and self:_hasScope(equippedItem) then
				visible = true
			end
		end

		if peek(visibleAtom) ~= visible then
			visibleAtom(visible)
		end

		if visible and dynamicGapLink:Peek() then
			local cameraInstance = camera.Instance
			local angle = bullets:GetSpreadAngle(character, camera)
			local px = math.deg(angle) * 2 / cameraInstance.FieldOfView * cameraInstance.ViewportSize.Y * 0.5
			px = math.min(px, DYNAMIC_GAP_MAX_PX)

			if peek(spreadAtom) ~= px then
				spreadAtom(px)
			end
		elseif peek(spreadAtom) ~= 0 then
			spreadAtom(0)
		end
	end))
end

function CustomScope._unbindRender(self: CustomScope): ()
	if self._renderConn then
		self._renderConn:Disconnect()
		self._renderConn = nil
	end
end

function CustomScope.Enable(self: CustomScope): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self:_blockSightGlass()
	self:_createOverlay()
	self:_bindRender()
end

function CustomScope.Disable(self: CustomScope): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self:_unbindRender()
	self:_unblockSightGlass()
	self:_destroyOverlay()
end

function CustomScope.Destroy(self: CustomScope): ()
	self:Disable()
	if self._sightGlass then
		hook.restoreInstance(self._sightGlass)
		self._sightGlass = nil
	end
	BaseFeature.Destroy(self)
end

export type CustomScope =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_optsLink: gameUi.Linker,
			_dynamicGapLink: any,
			_sightGlass: GuiObject?,
			_sightPictures: Instance?,
			_sightGlassBlocked: boolean,
			_screenGui: ScreenGui?,
			_root: ReactRoblox.RootType?,
			_visibleAtom: Charm.Atom<boolean>,
			_spreadAtom: Charm.Atom<number>,
			_renderConn: RBXScriptConnection?,
		},
		CustomScope
	))
	& BaseFeature.BaseFeature

return CustomScope
