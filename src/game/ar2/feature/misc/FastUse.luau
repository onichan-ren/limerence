local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")

local RunService = cloneref(game:GetService("RunService")) :: RunService

local FastUse = {}
FastUse.__index = FastUse

setmetatable(FastUse, { __index = BaseFeature })

local advance = LPH_NO_VIRTUALIZE(function(self: FastUse, arLocalPlayer: any): ()
	local character = arLocalPlayer.Character
	if not character or not character.UsingItem then
		self._set = false
		return
	end

	local item = character.EquippedItem
	local config = item and item.ConsumeConfig
	local animation = config and config.Animation
	if not animation then
		self._set = false
		return
	end

	local animator = character.Animator
	if not animator or type(animator.GetTrack) ~= "function" then
		return
	end

	local track = animator:GetTrack(animation)
	if not track or not track.IsPlaying then
		self._set = false
		return
	end

	if self._set then
		return
	end
	self._set = true

	if track.Length > 0.3 then
		track.TimePosition = 0.4
	end
end)

function FastUse.new(link: gameUi.Linker): FastUse
	local self = BaseFeature.new() :: any
	setmetatable(self, FastUse)

	self._enabled = false
	self._conn = nil :: RBXScriptConnection?
	self._set = false

	link:Toggle("fastUse", "Fast Use", false):SetTip({
		title = "Fast Use",
		body = "Consumables and medical finish slightly faster.",
	})

	self:Track(link:Get("fastUse"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("fastUse") then
		self:Enable()
	end

	return self
end

function FastUse.Enable(self: FastUse): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local playersModule = ModuleController.GetModule("LocalPlayer")
	if not playersModule then
		return
	end

	local arLocalPlayer = playersModule.module.get()

	self._set = false
	self._conn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
		advance(self, arLocalPlayer)
	end))
end

function FastUse.Disable(self: FastUse): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
end

function FastUse.Destroy(self: FastUse): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type FastUse =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_conn: RBXScriptConnection?,
			_set: boolean,
		},
		FastUse
	))
	& BaseFeature.BaseFeature

return FastUse
