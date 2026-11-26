local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")
local Janitor = require("@pkg/Janitor")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local shroudObserver = require("@game/mvsd/feature/visual/world/shroudObserver")
local flashEspRenderer = require("@game/mvsd/feature/visual/world/flashEspRenderer")

local at = Charm.atom
local peek = Charm.peek
local e = React.createElement

local DEFAULT_COLOR = Color3.fromRGB(120, 200, 235)
local DISPLAY_ORDER = 16

local FlashEsp = {}
FlashEsp.__index = FlashEsp

setmetatable(FlashEsp, { __index = BaseFeature })

function FlashEsp.new(link: gameUi.Linker): FlashEsp
	local self = BaseFeature.new() :: any
	setmetatable(self, FlashEsp)

	link:Toggle("flashEsp", "Flash ESP", false):SetTip({
		title = "Flash ESP",
		body = "On-screen markers tracking shroud projectiles and how long until they fade.",
	})
	local flashLink = link:OnKey("flashEsp")
	flashLink:Colorpicker("color", "Color", DEFAULT_COLOR, 0)
	flashLink:Submenu("opts", "Flash ESP Options")
	local optsLink = flashLink:OnKey("opts")
	optsLink:Toggle("showTimer", "Show Timer", true):SetTip({
		title = "Show Timer",
		body = "Draws the seconds left before the flash fades.",
	})

	self._enabledLink = link:Get("flashEsp")
	self._entries = at({} :: { [Model]: { id: number, model: Model, started: number } })
	self._modelJanitors = {} :: { [Model]: Janitor.Janitor }
	self._observerUnsub = nil :: (() -> ())?
	self._enabled = false
	self._nextId = 0

	local screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = DISPLAY_ORDER,
	}, cloneref(gethui()))
	self._screenGui = screenGui

	self._root = ReactRoblox.createRoot(screenGui)
	self._root:render(e(flashEspRenderer, {
		enabledLink = self._enabledLink,
		colorLink = flashLink:Get("color"),
		showTimerLink = optsLink:Get("showTimer"),
		entries = self._entries,
	}))

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if peek(self._enabledLink._state) then
		self:Enable()
	end

	return self
end

function FlashEsp._onSpawn(self: FlashEsp, model: Model): ()
	if not self._enabled or self._modelJanitors[model] then
		return
	end

	self._nextId += 1
	self._entries(Sift.Dictionary.set(peek(self._entries), model, {
		id = self._nextId,
		model = model,
		started = os.clock(),
	}))

	local modelJanitor = Janitor.new()
	modelJanitor:Add(model.Destroying:Connect(function(): ()
		self:_remove(model)
	end), "Disconnect")
	modelJanitor:Add(model.AncestryChanged:Connect(function(_: Instance, parent: Instance?): ()
		if not parent then
			self:_remove(model)
		end
	end), "Disconnect")
	self._modelJanitors[model] = modelJanitor
end

function FlashEsp._remove(self: FlashEsp, model: Model): ()
	local janitor = self._modelJanitors[model]
	if janitor then
		self._modelJanitors[model] = nil
		janitor:Destroy()
	end

	local entries = peek(self._entries)
	if entries[model] then
		self._entries(Sift.Dictionary.removeKey(entries, model))
	end
end

function FlashEsp.Enable(self: FlashEsp): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._observerUnsub = shroudObserver.subscribe(function(model: Model): ()
		self:_onSpawn(model)
	end)
end

function FlashEsp.Disable(self: FlashEsp): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._observerUnsub then
		self._observerUnsub()
		self._observerUnsub = nil
	end

	for _, janitor in next, self._modelJanitors do
		janitor:Destroy()
	end
	table.clear(self._modelJanitors)
	self._entries({})
end

function FlashEsp.Destroy(self: FlashEsp): ()
	self:Disable()
	self._root:unmount()
	self._screenGui:Destroy()
	BaseFeature.Destroy(self)
end

export type FlashEsp = typeof(setmetatable(
	{} :: {
		_enabledLink: any,
		_entries: Charm.Atom<{ [Model]: { id: number, model: Model, started: number } }>,
		_modelJanitors: { [Model]: Janitor.Janitor },
		_observerUnsub: (() -> ())?,
		_enabled: boolean,
		_nextId: number,
		_screenGui: Instance,
		_root: ReactRoblox.RootType,
		_onSpawn: (FlashEsp, Model) -> (),
		_remove: (FlashEsp, Model) -> (),
	},
	FlashEsp
)) & BaseFeature.BaseFeature

return FlashEsp
