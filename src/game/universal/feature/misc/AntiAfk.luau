local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")

local LocalPlayer = Players.LocalPlayer
local CLICK_POSITION = Vector2.zero

local virtualUser: any = nil

export type AntiAfkOpts = {
	body: string?,
	onEnable: (() -> ())?,
	onDisable: (() -> ())?,
}

local AntiAfk = {}
AntiAfk.__index = AntiAfk

setmetatable(AntiAfk, { __index = BaseFeature })

function AntiAfk.new(link: gameUi.Linker, opts: AntiAfkOpts?): AntiAfk
	local self = BaseFeature.new() :: any
	setmetatable(self, AntiAfk)

	self._opts = opts
	self._enabled = false
	self._idledConnection = nil :: RBXScriptConnection?

	link:Toggle("antiAfk", "Anti AFK", false):SetTip({
		title = "Anti AFK",
		body = opts and opts.body or "Keeps you in the server while idle instead of being moved away or disconnected.",
	})

	self:Track(link:Get("antiAfk"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("antiAfk") then
		self:Enable()
	end

	return self
end

function AntiAfk.Enable(self: AntiAfk): ()
	if self._enabled then
		return
	end
	self._enabled = true

	--[[self._idledConnection = LocalPlayer.Idled:Connect(function(): ()
		setthreadidentity(2)
		if not virtualUser then
			virtualUser = cloneref(game:GetService("VirtualUser"))
		end
		virtualUser:CaptureController()
		virtualUser:ClickButton2(CLICK_POSITION)
		setthreadidentity(8)
	end)]]

	local opts = self._opts
	if opts and opts.onEnable then
		opts.onEnable()
	end
end

function AntiAfk.Disable(self: AntiAfk): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	local connection = self._idledConnection
	if connection then
		connection:Disconnect()
		self._idledConnection = nil
	end

	local opts = self._opts
	if opts and opts.onDisable then
		opts.onDisable()
	end
end

function AntiAfk.Destroy(self: AntiAfk): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AntiAfk = typeof(setmetatable(
	{} :: {
		_opts: AntiAfkOpts?,
		_enabled: boolean,
		_idledConnection: RBXScriptConnection?,
	},
	AntiAfk
)) & BaseFeature.BaseFeature

return AntiAfk
