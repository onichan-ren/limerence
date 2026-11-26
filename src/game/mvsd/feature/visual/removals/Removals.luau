local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Charm = require("@pkg/Charm")
local ClientState = require("@game/mvsd/client/clientState")
local ModuleController = require("@game/mvsd/module/ModuleController")

local peek = Charm.peek

local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService

local SHROUDED_TAG = "Shrouded"
local FOG_PART_NAME = "ShroudStatePart"
local DEFAULT_SHROUD_TIME = 2.5

local shroudTime: number? = nil

local function getShroudTime(): number
	if shroudTime then
		return shroudTime
	end

	local config = ModuleController.GetModule("AbilityConfig")
	if type(config) ~= "table" then
		return DEFAULT_SHROUD_TIME
	end

	local value = tonumber(config.ShroudTime) or DEFAULT_SHROUD_TIME
	shroudTime = value
	return value
end

local Removals = {}
Removals.__index = Removals

setmetatable(Removals, { __index = BaseFeature })

function Removals.new(link: gameUi.Linker): Removals
	local self = BaseFeature.new() :: any
	setmetatable(self, Removals)

	link:Options("removals", "Removals")
	local removalsLink = link:OnKey("removals")
	removalsLink:Toggle("flashes", "Flash Effect", false):SetTip({
		title = "Flash Effect",
		body = "Shortens or removes vision-blocking blindness. Use Time Reduction to scale duration.",
	})
	local flashLink = removalsLink:OnKey("flashes")
	flashLink:Submenu("opts", "Flash Effect")
	local flashOptsLink = flashLink:OnKey("opts")
	flashOptsLink:Slider("timeReduction", "Time Reduction", 100, 1, 100, 1, nil, "%"):SetTip({
		title = "Time Reduction",
		body = "Percent of blind duration to remove. 100% removes the effect entirely.",
	})
	removalsLink:Toggle("shroudFog", "Blind Fog", false):SetTip({
		title = "Blind Fog",
		body = "Hides the dark fog orb around blinded players.",
	})

	self._flashLink = flashOptsLink
	self._flashConn = nil :: RBXScriptConnection?
	self._flashThread = nil :: thread?
	self._fogAddedConn = nil :: RBXScriptConnection?
	self._fogRemovedConn = nil :: RBXScriptConnection?
	self._fogWatch = {} :: { [Instance]: RBXScriptConnection }
	self._fogHidden = {} :: { [BasePart]: number }

	self:Track(removalsLink:Get("flashes"):OnChange(function(value: boolean): ()
		if value then
			self:EnableFlashes()
		else
			self:DisableFlashes()
		end
	end))

	self:Track(removalsLink:Get("shroudFog"):OnChange(function(value: boolean): ()
		if value then
			self:EnableShroudFog()
		else
			self:DisableShroudFog()
		end
	end))

	if removalsLink:Peek("flashes") then
		self:EnableFlashes()
	end
	if removalsLink:Peek("shroudFog") then
		self:EnableShroudFog()
	end

	return self
end

local function cancelFlashThread(self: any): ()
	if self._flashThread then
		task.cancel(self._flashThread)
		self._flashThread = nil
	end
end

local function onLocalShrouded(self: any, character: Instance): ()
	cancelFlashThread(self)

	local reduction = self._flashLink:Peek("timeReduction") or 100
	local factor = 1 - reduction / 100
	if factor < 0 then
		factor = 0
	elseif factor > 1 then
		factor = 1
	end

	self._flashThread = task.delay(getShroudTime() * factor, function(): ()
		self._flashThread = nil
		if CollectionService:HasTag(character, SHROUDED_TAG) then
			CollectionService:RemoveTag(character, SHROUDED_TAG)
		end
	end)
end

function Removals.EnableFlashes(self: Removals): ()
	if self._flashConn then
		return
	end

	self._flashConn = CollectionService:GetInstanceAddedSignal(SHROUDED_TAG):Connect(function(instance: Instance): ()
		if instance == peek(ClientState.character) then
			onLocalShrouded(self, instance)
		end
	end)

	local character = peek(ClientState.character)
	if character and CollectionService:HasTag(character, SHROUDED_TAG) then
		onLocalShrouded(self, character)
	end
end

function Removals.DisableFlashes(self: Removals): ()
	if not self._flashConn then
		return
	end

	self._flashConn:Disconnect()
	self._flashConn = nil
	cancelFlashThread(self)
end

local function hideFogPart(self: any, part: BasePart): ()
	if self._fogHidden[part] ~= nil then
		return
	end

	self._fogHidden[part] = part.Transparency
	part.Transparency = 1
end

local function watchShroudedCharacter(self: any, character: Instance): ()
	if self._fogWatch[character] then
		return
	end

	local existing = character:FindFirstChild(FOG_PART_NAME)
	if existing and existing:IsA("BasePart") then
		hideFogPart(self, existing)
	end

	self._fogWatch[character] = character.ChildAdded:Connect(function(child: Instance): ()
		if child.Name == FOG_PART_NAME and child:IsA("BasePart") then
			hideFogPart(self, child)
		end
	end)
end

local function unwatchShroudedCharacter(self: any, character: Instance): ()
	local connection = self._fogWatch[character]
	if connection then
		connection:Disconnect()
		self._fogWatch[character] = nil
	end
end

function Removals.EnableShroudFog(self: Removals): ()
	if self._fogAddedConn then
		return
	end

	self._fogAddedConn = CollectionService:GetInstanceAddedSignal(SHROUDED_TAG):Connect(function(instance: Instance): ()
		watchShroudedCharacter(self, instance)
	end)
	self._fogRemovedConn = CollectionService:GetInstanceRemovedSignal(SHROUDED_TAG)
		:Connect(function(instance: Instance): ()
			unwatchShroudedCharacter(self, instance)
		end)

	for _, character in next, CollectionService:GetTagged(SHROUDED_TAG) do
		watchShroudedCharacter(self, character)
	end
end

function Removals.DisableShroudFog(self: Removals): ()
	if not self._fogAddedConn then
		return
	end

	self._fogAddedConn:Disconnect()
	self._fogAddedConn = nil
	if self._fogRemovedConn then
		self._fogRemovedConn:Disconnect()
		self._fogRemovedConn = nil
	end

	for character, connection in next, self._fogWatch do
		connection:Disconnect()
		self._fogWatch[character] = nil
	end

	for part, transparency in next, self._fogHidden do
		if part.Parent then
			part.Transparency = transparency
		end
		self._fogHidden[part] = nil
	end
end

function Removals.Destroy(self: Removals): ()
	self:DisableFlashes()
	self:DisableShroudFog()
	BaseFeature.Destroy(self)
end

export type Removals =
	typeof(setmetatable(
		{} :: {
			_flashLink: gameUi.Linker,
			_flashConn: RBXScriptConnection?,
			_flashThread: thread?,
			_fogAddedConn: RBXScriptConnection?,
			_fogRemovedConn: RBXScriptConnection?,
			_fogWatch: { [Instance]: RBXScriptConnection },
			_fogHidden: { [BasePart]: number },
		},
		Removals
	))
	& BaseFeature.BaseFeature

return Removals
