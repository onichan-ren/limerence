local BaseFeature = require("@game/BaseFeature")
local ModuleController = require("@game/pf/module/ModuleController")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")

local UnlockAll = {}
UnlockAll.__index = UnlockAll

setmetatable(UnlockAll, { __index = BaseFeature })

local ALWAYS_OWNED = LPH_NO_VIRTUALIZE(function(): boolean
	return true
end)

function UnlockAll.new(link: gameUi.Linker): UnlockAll
	local self = BaseFeature.new() :: any
	setmetatable(self, UnlockAll)

	self._enabled = false
	self._targets = {} :: { any }

	link:Toggle("unlockAll", "Unlock All", false):SetTip({
		title = "Unlock All",
		body = "Unlock every attachment in the menu.",
	})

	self:Track(link:Get("unlockAll"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("unlockAll") then
		self:Enable()
	end

	return self
end

local function hookFn(self: UnlockAll, moduleName: string, fnName: string, replacement: any): ()
	local module = ModuleController.GetModule(moduleName)
	local fn = module and rawget(module, fnName)
	if type(fn) ~= "function" then
		return
	end
	hook.add(fn, replacement)
	table.insert(self._targets, fn)
end

function UnlockAll.Enable(self: UnlockAll): ()
	if self._enabled then
		return
	end
	self._enabled = true

	hookFn(self, "PlayerDataUtils", "ownsAttachment", ALWAYS_OWNED)
end

function UnlockAll.Disable(self: UnlockAll): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	for _, fn in next, self._targets do
		hook.restore(fn)
	end
	table.clear(self._targets)
end

function UnlockAll.Destroy(self: UnlockAll): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type UnlockAll =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_targets: { any },
			Enable: (UnlockAll) -> (),
			Disable: (UnlockAll) -> (),
		},
		UnlockAll
	))
	& BaseFeature.BaseFeature

return UnlockAll
