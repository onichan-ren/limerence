local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")

local LOOT_PAGE = "Loot"
local VIEWPORT_NAME = "ViewportFrame"

local HideInventoryCharacter = {}
HideInventoryCharacter.__index = HideInventoryCharacter

setmetatable(HideInventoryCharacter, { __index = BaseFeature })

local function getPlayerGui(): PlayerGui?
	local localPlayer = Players.LocalPlayer
	return localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
end

local function isTarget(instance: Instance): boolean
	if instance.Name ~= VIEWPORT_NAME or not instance:IsA("ViewportFrame") then
		return false
	end
	local parent = instance.Parent
	return parent ~= nil and parent.Name == LOOT_PAGE
end

local function findViewport(): ViewportFrame?
	local playerGui = getPlayerGui()
	if not playerGui then
		return nil
	end
	for _, descendant in next, playerGui:QueryDescendants("ViewportFrame") do
		if isTarget(descendant) then
			return descendant :: ViewportFrame
		end
	end
	return nil
end

function HideInventoryCharacter.new(link: gameUi.Linker): HideInventoryCharacter
	local self = BaseFeature.new() :: any
	setmetatable(self, HideInventoryCharacter)

	link:Toggle("hideInventoryCharacter", "Inventory Character", false):SetTip({
		title = "Inventory Character",
		body = "Hides your character shown in the middle of the inventory screen.",
	})

	self._enabled = false
	self._blocked = false
	self._viewport = nil :: ViewportFrame?
	self._watchConn = nil :: RBXScriptConnection?

	self:Track(link:Get("hideInventoryCharacter"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("hideInventoryCharacter") then
		self:Enable()
	end

	return self
end

function HideInventoryCharacter._apply(self: HideInventoryCharacter): boolean
	if self._blocked then
		return true
	end

	local viewport = self._viewport
	if not viewport then
		viewport = findViewport()
		self._viewport = viewport
	end
	if not viewport then
		return false
	end

	hook.addInstance(viewport)
	hook.blockProperty(viewport, "Visible")
	viewport.Visible = false
	self._blocked = true
	return true
end

function HideInventoryCharacter._startWatch(self: HideInventoryCharacter): ()
	if self._watchConn then
		return
	end

	local playerGui = getPlayerGui()
	if not playerGui then
		return
	end

	self._watchConn = playerGui.DescendantAdded:Connect(function(descendant: Instance): ()
		if isTarget(descendant) then
			self._viewport = descendant :: ViewportFrame
			self:_apply()
			self:_stopWatch()
		end
	end)
end

function HideInventoryCharacter._stopWatch(self: HideInventoryCharacter): ()
	if self._watchConn then
		self._watchConn:Disconnect()
		self._watchConn = nil
	end
end

function HideInventoryCharacter.Enable(self: HideInventoryCharacter): ()
	if self._enabled then
		return
	end
	self._enabled = true

	if not self:_apply() then
		self:_startWatch()
	end
end

function HideInventoryCharacter.Disable(self: HideInventoryCharacter): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	self:_stopWatch()

	if self._blocked and self._viewport then
		hook.unblockProperty(self._viewport, "Visible")
		self._blocked = false
	end
end

function HideInventoryCharacter.Destroy(self: HideInventoryCharacter): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type HideInventoryCharacter =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_blocked: boolean,
			_viewport: ViewportFrame?,
			_watchConn: RBXScriptConnection?,
			_apply: (HideInventoryCharacter) -> boolean,
			_startWatch: (HideInventoryCharacter) -> (),
			_stopWatch: (HideInventoryCharacter) -> (),
			Enable: (HideInventoryCharacter) -> (),
			Disable: (HideInventoryCharacter) -> (),
		},
		HideInventoryCharacter
	))
		& BaseFeature.BaseFeature

return HideInventoryCharacter
