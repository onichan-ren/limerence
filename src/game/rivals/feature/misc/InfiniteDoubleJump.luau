local WeaponController = require("@game/rivals/weapon/WeaponController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")

local peek = Charm.peek
local sub = Charm.subscribe

local InfiniteDoubleJump = {}
InfiniteDoubleJump.__index = InfiniteDoubleJump

setmetatable(InfiniteDoubleJump, { __index = BaseFeature })

function InfiniteDoubleJump.new(link: gameUi.Linker): InfiniteDoubleJump
	local self = BaseFeature.new() :: any
	setmetatable(self, InfiniteDoubleJump)

	local toggle = link:Toggle("infiniteDoubleJump", "Infinite Double Jump", false):SetTip({
		title = "Infinite Double Jump",
		body = "Allows you to jump infinitely.",
	})

	local djLink = link:OnKey("infiniteDoubleJump")
	djLink:Extra(toggle, "opts", "Submenu", "Infinite Double Jump")
	local optsLink = djLink:OnKey("opts")
	optsLink:Toggle("force", "Force", false):SetTip({
		title = "Force",
		body = "Lets you double jump even with weapons that normally can't.",
	})

	self._optsLink = optsLink
	self._janitor = Janitor.new()

	self:Track(link:Get("infiniteDoubleJump"):OnChange(function(value: boolean)
		if value then
			self:Enable(true)
		else
			self:Disable(false)
		end
	end))

	return self
end

function InfiniteDoubleJump._restore(self: InfiniteDoubleJump): ()
	local info = self._patchedInfo
	if info then
		info.MaxDoubleJumps = self._originalMax
		self._patchedInfo = nil
		self._originalMax = nil
	end
end

function InfiniteDoubleJump._apply(self: InfiniteDoubleJump): ()
	self:_restore()
	if not self._enabled then
		return
	end

	local item = peek(WeaponController.item)
	local info = item and item.Info
	if type(info) ~= "table" then
		return
	end

	local original = info.MaxDoubleJumps
	local force = self._optsLink:Peek("force") == true
	if force or (type(original) == "number" and original > 0) then
		self._patchedInfo = info
		self._originalMax = original
		info.MaxDoubleJumps = math.huge
	end
end

function InfiniteDoubleJump.Enable(self: InfiniteDoubleJump): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._janitor:Add(sub(WeaponController.item, function(): ()
		self:_apply()
	end))
	self._janitor:Add(self._optsLink:Get("force"):OnChange(function(): ()
		self:_apply()
	end))
	self:_apply()
end

function InfiniteDoubleJump.Disable(self: InfiniteDoubleJump): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
	self:_restore()
end

function InfiniteDoubleJump.Destroy(self: InfiniteDoubleJump): ()
	self:Disable()
	self._janitor:Destroy()
	BaseFeature.Destroy(self)
end

export type InfiniteDoubleJump =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_optsLink: gameUi.Linker,
			_janitor: Janitor.Janitor,
			_patchedInfo: any,
			_originalMax: any,
		},
		InfiniteDoubleJump
	))
	& BaseFeature.BaseFeature

return InfiniteDoubleJump
