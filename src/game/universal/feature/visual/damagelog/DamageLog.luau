local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ToastController = require("@ui/hud/toast/ToastController")

export type DamageLogOpts = {
	key: string,
	label: string,
	tip: { title: string, body: string },
	connect: (emit: (text: string, accent: Color3?) -> ()) -> (() -> ())?,
}

local function emit(text: string, accent: Color3?): ()
	ToastController.Push({ text = text, accent = accent })
end

local DamageLog = {}
DamageLog.__index = DamageLog

setmetatable(DamageLog, { __index = BaseFeature })

function DamageLog.new(link: gameUi.Linker, opts: DamageLogOpts): DamageLog
	local self = BaseFeature.new() :: any
	setmetatable(self, DamageLog)

	self._opts = opts
	self._cleanup = nil

	link:Toggle(opts.key, opts.label, false):SetTip(opts.tip)
	self._enabledLink = link:Get(opts.key)

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek(opts.key) then
		self:Enable()
	end

	return self
end

function DamageLog.Enable(self: DamageLog): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._cleanup = self._opts.connect(emit)
end

function DamageLog.Disable(self: DamageLog): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	if self._cleanup then
		self._cleanup()
		self._cleanup = nil
	end
end

function DamageLog.Destroy(self: DamageLog): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type DamageLog =
	typeof(setmetatable(
		{} :: {
			_opts: DamageLogOpts,
			_enabledLink: any,
			_enabled: boolean,
			_cleanup: (() -> ())?,
		},
		DamageLog
	))
	& BaseFeature.BaseFeature

return DamageLog
