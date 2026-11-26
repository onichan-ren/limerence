local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ClientState = require("@game/mvsd/client/clientState")

local peek = Charm.peek
local sub = Charm.subscribe

local function randComponent(): number
	return (math.random() * 4e5 + 1e5) * (math.random() < 0.5 and -1 or 1)
end

local voidCFrame = LPH_NO_VIRTUALIZE(function(): CFrame
	return CFrame.new(randComponent(), math.abs(randComponent()) + 1e5, randComponent())
end)

local Invisible = {}
Invisible.__index = Invisible

setmetatable(Invisible, { __index = BaseFeature })

function Invisible.new(link: gameUi.Linker): Invisible
	local self = BaseFeature.new() :: any
	setmetatable(self, Invisible)

	link:Toggle("invisible", "Invisible", false):SetTip({
		title = "Invisible",
		body = "Hides your character from everyone while you keep playing as normal.",
	})

	self._enabled = false
	self._hookedHrp = nil :: BasePart?
	self._originalMeta = nil :: any
	self._spoof = false
	self._spoofedCF = CFrame.identity
	self._displaced = false
	self._displacedHrp = nil :: BasePart?
	self._realCF = CFrame.identity
	self._hbConn = nil :: RBXScriptConnection?
	self._rsConn = nil :: RBXScriptConnection?
	self._hrpSub = nil :: (() -> ())?

	self:Track(link:Get("invisible"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("invisible") then
		self:Enable()
	end

	return self
end

function Invisible._installHook(self: Invisible, hrp: BasePart): ()
	if not hrp or self._hookedHrp == hrp then
		return
	end
	self:_uninstallHook()

	local original = getrawmetatable(hrp) :: any
	local oldIndex = original.__index

	local spoofedIndex = LPH_NO_VIRTUALIZE(function(target: any, key: any): any
		if self._spoof and not checkcaller() then
			if key == "CFrame" then
				return self._spoofedCF
			elseif key == "Position" then
				return self._spoofedCF.Position
			end
		end
		return oldIndex(target, key)
	end)

	local newMeta: { [string]: any } = {
		__index = spoofedIndex,
	}
	for k, v in next, original do
		if newMeta[k] == nil then
			newMeta[k] = v
		end
	end

	setrawmetatable(hrp, newMeta)
	self._hookedHrp = hrp
	self._originalMeta = original
end

function Invisible._uninstallHook(self: Invisible): ()
	if self._hookedHrp and self._originalMeta then
		setrawmetatable(self._hookedHrp :: any, self._originalMeta)
	end
	self._hookedHrp = nil
	self._originalMeta = nil
	self._spoof = false
end

Invisible._applyDisplace = LPH_NO_VIRTUALIZE(function(self: Invisible): ()
	if self._displaced then
		return
	end
	local hrp = peek(ClientState.hrp) :: BasePart?
	if not hrp then
		return
	end
	self._realCF = hrp.CFrame
	self._spoofedCF = self._realCF
	self._spoof = true
	hrp.CFrame = voidCFrame()
	self._displacedHrp = hrp
	self._displaced = true
end)

Invisible._restoreDisplace = LPH_NO_VIRTUALIZE(function(self: Invisible): ()
	if not self._displaced then
		return
	end
	local hrp = self._displacedHrp
	if hrp and hrp.Parent then
		hrp.CFrame = self._realCF
	end
	self._spoof = false
	self._displaced = false
	self._displacedHrp = nil
end)

function Invisible.Enable(self: Invisible): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local hrp = peek(ClientState.hrp) :: BasePart?
	if hrp then
		self:_installHook(hrp)
	end

	self._hrpSub = sub(ClientState.hrp, function(newHrp: BasePart?): ()
		self:_restoreDisplace()
		if newHrp then
			self:_installHook(newHrp)
		else
			self:_uninstallHook()
		end
	end)

	self._rsConn = RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
		self:_restoreDisplace()
	end))
	self._hbConn = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
		self:_applyDisplace()
	end))
end

function Invisible.Disable(self: Invisible): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._rsConn then
		self._rsConn:Disconnect()
		self._rsConn = nil
	end
	if self._hbConn then
		self._hbConn:Disconnect()
		self._hbConn = nil
	end
	if self._hrpSub then
		self._hrpSub()
		self._hrpSub = nil
	end

	self:_restoreDisplace()
	self:_uninstallHook()
end

function Invisible.Destroy(self: Invisible): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type Invisible =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_hookedHrp: BasePart?,
			_originalMeta: any,
			_spoof: boolean,
			_spoofedCF: CFrame,
			_displaced: boolean,
			_displacedHrp: BasePart?,
			_realCF: CFrame,
			_hbConn: RBXScriptConnection?,
			_rsConn: RBXScriptConnection?,
			_hrpSub: (() -> ())?,
			_installHook: (Invisible, BasePart) -> (),
			_uninstallHook: (Invisible) -> (),
			_applyDisplace: (Invisible) -> (),
			_restoreDisplace: (Invisible) -> (),
		},
		Invisible
	))
	& BaseFeature.BaseFeature

return Invisible
