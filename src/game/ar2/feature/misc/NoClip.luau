local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local clientState = require("@game/ar2/client/clientState")

local RunService = cloneref(game:GetService("RunService")) :: RunService

local peek = Charm.peek
local sub = Charm.subscribe

local NoClip = {}
NoClip.__index = NoClip

setmetatable(NoClip, { __index = BaseFeature })

local touched = {}
local _parts = {}

local function rebuildParts(character: Instance): ()
	table.clear(_parts)
	for _, part in next, character:QueryDescendants("Instance") do
		if part:IsA("BasePart") then
			_parts[part] = true
		end
	end
end

local function bindCharacter(self: NoClip, character: Instance?): ()
	if self._descConn then
		self._descConn:Disconnect()
		self._descConn = nil
	end

	table.clear(_parts)

	if not character then
		return
	end

	rebuildParts(character)

	self._descConn = character.DescendantAdded:Connect(function(part: Instance): ()
		if part:IsA("BasePart") then
			_parts[part] = true
		end
	end)
end

local step = LPH_NO_VIRTUALIZE(function(): ()
	local character = peek(clientState.character)
	if not character then
		return
	end

	for part in next, _parts do
		if part.CanCollide then
			part.CanCollide = false
			touched[part] = true
		end
	end
end)

local function restore(): ()
	for part in next, touched do
		if part.Parent then
			part.CanCollide = true
		end
		touched[part] = nil
	end
end

function NoClip.new(link: gameUi.Linker): NoClip
	local self = BaseFeature.new() :: any
	setmetatable(self, NoClip)

	self._enabled = false
	self._conn = nil :: RBXScriptConnection?
	self._descConn = nil :: RBXScriptConnection?

	link:Toggle("noClip", "No Clip", false):SetTip({
		title = "No Clip",
		body = "Lets you walk through walls and objects.",
	})

	self:Track(link:Get("noClip"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("noClip") then
		self:Enable()
	end

	return self
end

function NoClip.Enable(self: NoClip): ()
	if self._enabled then
		return
	end
	self._enabled = true

	bindCharacter(self, peek(clientState.character))
	self._charUnsub = sub(clientState.character, function(character: Instance?): ()
		bindCharacter(self, character)
	end)

	self._conn = RunService.PreSimulation:Connect(step)
end

function NoClip.Disable(self: NoClip): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end

	if self._charUnsub then
		self._charUnsub()
		self._charUnsub = nil
	end

	if self._descConn then
		self._descConn:Disconnect()
		self._descConn = nil
	end

	table.clear(_parts)

	restore()
end

function NoClip.Destroy(self: NoClip): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type NoClip =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_conn: RBXScriptConnection?,
			_descConn: RBXScriptConnection?,
			_charUnsub: (() -> ())?,
		},
		NoClip
	))
	& BaseFeature.BaseFeature

return NoClip
