local Players = cloneref(game:GetService("Players")) :: Players
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local ModuleController = require("@game/pf/module/ModuleController")

local LocalPlayer = Players.LocalPlayer

local _ignoreFolder: Instance? = nil
local function ignoreFolder(): Instance?
	if not _ignoreFolder then
		_ignoreFolder = Workspace:FindFirstChild("Ignore")
	end
	return _ignoreFolder
end

local POS_STIFF_SMOOTH = 32
local POS_STIFF_SNAP = 2000

local function pinSpring(spring: any, velocity: number?): ()
	spring.p = spring.t
	spring.v = velocity or 0
end

local slotIndex = {
	Primary = 1,
	Secondary = 2,
	Knife = 3,
	Grenade = 4,
}

local CLASS_TO_INDEX = {
	["ASSAULT RIFLE"] = 1,
	["BATTLE RIFLE"] = 1,
	CARBINE = 1,
	DMR = 1,
	LMG = 1,
	PDW = 1,
	SHOTGUN = 1,
	["SNIPER RIFLE"] = 1,
	PISTOLS = 2,
	REVOLVERS = 2,
	["MACHINE PISTOLS"] = 2,
	OTHER = 2,
	["ONE HAND BLADE"] = 3,
	["ONE HAND BLUNT"] = 3,
	["TWO HAND BLADE"] = 3,
	["TWO HAND BLUNT"] = 3,
	FRAGMENTATION = 4,
	["HIGH EXPLOSIVE"] = 4,
	IMPACT = 4,
}

local _contentInterface: any = nil
local function contentInterface(): any
	if not _contentInterface then
		_contentInterface = ModuleController.GetModule("ContentInterface")
	end
	return _contentInterface
end

local function resolveSlotIndex(weaponName: string): number?
	local ci = contentInterface()
	if not ci then
		return nil
	end
	local entry = ci.getWeaponEntry(weaponName)
	local class = entry and entry.weaponClass
	return class and CLASS_TO_INDEX[class]
end

local _loadoutUtils: any = nil
local _playerData: any = nil
local function resolveModules(): ()
	if not _loadoutUtils then
		_loadoutUtils = ModuleController.GetModule("ActiveLoadoutUtils")
	end
	if not _playerData then
		_playerData = ModuleController.GetModule("PlayerDataClientInterface")
	end
end

local _replicationInterface: any = nil
local _playerStatusInterface: any = nil
local _gameClock: any = nil
local _cameraInterface: any = nil

local function replicationInterface(): any
	if not _replicationInterface then
		_replicationInterface = ModuleController.GetModule("ReplicationInterface")
	end
	return _replicationInterface
end

local function playerStatusInterface(): any
	if not _playerStatusInterface then
		_playerStatusInterface = ModuleController.GetModule("PlayerStatusInterface")
	end
	return _playerStatusInterface
end

local function getTime(): number
	if not _gameClock then
		_gameClock = ModuleController.GetModule("GameClock")
	end
	return _gameClock.getTime()
end

local function cameraAngles(): any
	if not _cameraInterface then
		_cameraInterface = ModuleController.GetModule("CameraInterface")
	end
	return _cameraInterface.getActiveCamera("MainCamera", true):getAngles()
end

local function buildPayload(): (any, any)
	resolveModules()
	local loadout = _loadoutUtils.getActiveLoadoutData(_playerData.getPlayerData())
	local payload = {}
	local nameToIndex = {}
	for slot, index in next, slotIndex do
		local data = loadout[slot]
		if data and data.Name then
			payload[slot] = data
			nameToIndex[data.Name] = index
		end
	end
	return payload, nameToIndex
end

local FakeCharacter = {}
FakeCharacter.__index = FakeCharacter

function FakeCharacter.new(opts: any?): FakeCharacter
	local self = setmetatable({}, FakeCharacter) :: any
	self._entry = nil
	self._fakePlayer = nil
	self._nameToIndex = nil
	self._lastIndex = nil
	self._lastTime = 0
	self._snapFrames = 0
	self._snapClock = 0
	self._snapPos = nil
	self._snapAng = nil
	self._reparented = false
	self._posStiffness = POS_STIFF_SMOOTH
	self._name = (opts and opts.name) or LocalPlayer.Name
	self._teamColor = (opts and opts.teamColor) or LocalPlayer.TeamColor
	self._currentWeapon = nil
	self._lookOverride = nil
	self._positionOverride = nil
	self._angleHold = false
	self._heldAngle = nil
	return self
end

FakeCharacter._build = LPH_NO_VIRTUALIZE(
	function(self: FakeCharacter, position: Vector3, angle: Vector3, weaponName: string?): boolean
		self:destroy()
		self._reparented = false

		local payload, nameToIndex = buildPayload()
		if not next(payload) then
			return false
		end
		local activeIndex = (weaponName and nameToIndex[weaponName]) or 1
		payload.activeWeaponIndex = activeIndex

		local fake = Instance.new("Player")
		fake.Name = self._name
		fake.TeamColor = self._teamColor
		fake.Neutral = LocalPlayer.Neutral
		self._fakePlayer = fake
		self._nameToIndex = nameToIndex
		self._lastIndex = activeIndex
		self._currentWeapon = (weaponName and nameToIndex[weaponName] ~= nil) and weaponName or nil

		local ri = replicationInterface()
		ri.addEntry(fake)
		local psi = playerStatusInterface()
		if psi then
			psi.addEntry(fake)
		end
		local entry = ri.getEntry(fake)
		self._entry = entry

		local realStep = entry.step
		if type(realStep) == "function" then
			rawset(entry :: any, "step", function(s: any, _render: any, ...: any): ...any
				local tpo = s:getThirdPersonObject()
				if tpo then
					tpo.canRenderWeapon = true
				end
				return realStep(s, true, ...)
			end)
		end

		entry:spawn(position, payload)

		entry._lookangles.p = angle
		entry._lookangles.t = angle
		entry._lookangles.v = Vector3.zero
		entry._barrelAngles.p = angle
		entry._barrelAngles.t = angle
		entry._barrelAngles.v = Vector3.zero

		entry._posspring._s = self._posStiffness
		entry._velspring._s = 120
		entry._lookangles._s = 120
		entry._barrelAngles._s = 120

		local tpo = entry:getThirdPersonObject()
		if tpo then
			local yaw = angle.Y
			tpo._baseAngleSpring.t = yaw
			tpo._baseAngleSpring.p = yaw
			tpo._baseAngleSpring.v = 0
			tpo._feetAngleSpring.t = yaw
			tpo._feetAngleSpring.p = yaw
			tpo._feetAngleSpring.v = 0
		end

		self._snapFrames = 10
		return true
	end
)

function FakeCharacter._syncWeapon(self: FakeCharacter, tpo: any, weaponName: string?): ()
	if not weaponName or weaponName == self._currentWeapon then
		return
	end
	local native = self._nameToIndex[weaponName]
	local index = native or resolveSlotIndex(weaponName)
	if not index then
		return
	end
	if not native and self._entry.swapWeapon then
		setthreadidentity(8)
		self._entry:swapWeapon(index, {
			weaponName = weaponName,
			weaponAttachments = {},
			weaponCamo = {},
		})
	end
	self._currentWeapon = weaponName
	self._lastIndex = index
	setthreadidentity(8)
	self._entry:setActiveIndex(index)
	setthreadidentity(8)
	if index > 2 then
		tpo:equipMelee(index)
	else
		tpo:equip(index)
	end
end

local function setCanQuery(root: Instance?, enabled: boolean): ()
	if not root then
		return
	end
	for _, d in next, (root :: any):QueryDescendants("BasePart") do
		d.CanQuery = enabled
	end
end

function FakeCharacter._applyQuery(self: FakeCharacter, enabled: boolean): ()
	setCanQuery(self:getCharacterModel(), enabled)
	setCanQuery(self:getWeaponModel(), enabled)
end

function FakeCharacter._ensureIgnore(self: FakeCharacter): ()
	local ignore = ignoreFolder()
	if not ignore then
		return
	end
	local model = self:getCharacterModel()
	if not model then
		return
	end
	setthreadidentity(8)
	model.Parent = ignore
	local weapon = self:getWeaponModel()
	if weapon and not weapon:IsDescendantOf(model) then
		setthreadidentity(8)
		weapon.Parent = ignore
	end
	self._reparented = true
end

function FakeCharacter.update(self: FakeCharacter, position: Vector3, angle: any?, opts: any?): boolean
	local built = self._entry ~= nil
	position = self._positionOverride or position
	local a = angle or cameraAngles()
	local ov = self._lookOverride
	if ov then
		a = ov(a) or a
	end
	if self._angleHold then
		local held = self._heldAngle
		if held then
			a = held
		else
			self._heldAngle = a
		end
	end
	if not built then
		self:_build(position, a, opts and opts.weaponName)
		self._snapClock = os.clock()
		self._snapPos = position
		self._snapAng = a
	else
		local time = getTime()
		if time > self._lastTime then
			self._lastTime = time
			setthreadidentity(8)
			self._entry:updateReplication(nil, time, position, a, a)
		end
		local tpo = self._entry:getThirdPersonObject()
		if tpo and opts then
			if opts.stance ~= nil then
				setthreadidentity(8)
				tpo:setStance(opts.stance)
			end
			if opts.sprint ~= nil then
				setthreadidentity(8)
				tpo:setSprint(opts.sprint)
			end
			if opts.aim ~= nil then
				setthreadidentity(8)
				tpo:setAim(opts.aim)
			end
			if opts.weaponName then
				setthreadidentity(8)
				self:_syncWeapon(tpo, opts.weaponName)
			end
		end
		if self._snapFrames > 0 then
			local now = os.clock()
			local dt = now - self._snapClock
			local vel = Vector3.zero
			local angVel = Vector3.zero
			if self._snapPos and dt > 0 then
				vel = (position - self._snapPos) / dt
				angVel = (a - self._snapAng) / dt
			end
			self._snapClock = now
			self._snapPos = position
			self._snapAng = a
			local pos = self._entry._posspring
			pos.p = position
			pos.t = position
			pos.v = vel
			local velSpring = self._entry._velspring
			velSpring.p = vel
			velSpring.t = vel
			velSpring.v = Vector3.zero
			local look = self._entry._lookangles
			look.p = a
			look.t = a
			look.v = angVel
			local barrel = self._entry._barrelAngles
			barrel.p = a
			barrel.t = a
			barrel.v = angVel
			if tpo then
				local yawRate = angVel.Y
				pinSpring(tpo._baseAngleSpring, yawRate)
				pinSpring(tpo._feetAngleSpring, yawRate)
				pinSpring(tpo._stanceSpring)
				pinSpring(tpo._sprintSpring)
				pinSpring(tpo._aimSpring)
				pinSpring(tpo._equipSpring)
				pinSpring(tpo._torsoLookProportionSpring)
				pinSpring(tpo._speedSpring)
			end
			local smooth = self._entry._smoothReplication
			if smooth and smooth:isReady() then
				self._snapFrames -= 1
			end
		end
	end
	if self._entry and not self._reparented then
		self:_ensureIgnore()
	end
	if opts and opts.queryable == false then
		self:_applyQuery(false)
	end
	return not built
end

function FakeCharacter.isBuilt(self: FakeCharacter): boolean
	return self._entry ~= nil
end

function FakeCharacter.step(self: FakeCharacter, dt: number): ()
	if self._entry then
		setthreadidentity(8)
		self._entry:step(true, dt)
	end
end

function FakeCharacter.getThirdPersonObject(self: FakeCharacter): any
	return self._entry and self._entry:getThirdPersonObject()
end

function FakeCharacter.getCharacterModel(self: FakeCharacter): Model?
	local tpo = self:getThirdPersonObject()
	setthreadidentity(8)
	return tpo and tpo:getCharacterModel()
end

function FakeCharacter.getWeaponModel(self: FakeCharacter): Instance?
	local tpo = self:getThirdPersonObject()
	setthreadidentity(8)
	return tpo and tpo:getWeaponModel()
end

function FakeCharacter.getActiveIndex(self: FakeCharacter): number?
	return self._lastIndex
end

function FakeCharacter.setPositionSmoothing(self: FakeCharacter, smooth: number): ()
	local p = math.clamp(smooth, 0, 1)
	local stiff = POS_STIFF_SNAP * (POS_STIFF_SMOOTH / POS_STIFF_SNAP) ^ p
	self._posStiffness = stiff
	if self._entry and self._entry._posspring then
		self._entry._posspring._s = stiff
	end
end

function FakeCharacter.setLookOverride(self: FakeCharacter, fn: any?): ()
	self._lookOverride = fn
end

function FakeCharacter.setPositionOverride(self: FakeCharacter, position: Vector3?): ()
	self._positionOverride = position
end

function FakeCharacter.getPositionOverride(self: FakeCharacter): Vector3?
	return self._positionOverride
end

function FakeCharacter.setAngleHold(self: FakeCharacter, hold: boolean): ()
	self._angleHold = hold
	if not hold then
		self._heldAngle = nil
	end
end

function FakeCharacter.destroy(self: FakeCharacter): ()
	local fake = self._fakePlayer
	if fake then
		local psi = playerStatusInterface()
		if psi then
			psi.removeEntry(fake)
		end
		replicationInterface().removeEntry(fake)
		fake:Destroy()
	end
	self._entry = nil
	self._fakePlayer = nil
	self._nameToIndex = nil
	self._lastIndex = nil
	self._currentWeapon = nil
	self._lastTime = 0
	self._snapClock = 0
	self._snapPos = nil
	self._snapAng = nil
	self._heldAngle = nil
end

export type FakeCharacter = typeof(setmetatable(
	{} :: {
		_entry: any,
		_fakePlayer: Player?,
		_nameToIndex: any,
		_lastIndex: number?,
		_currentWeapon: string?,
		_lastTime: number,
		_snapFrames: number,
		_snapClock: number,
		_snapPos: Vector3?,
		_snapAng: Vector3?,
		_reparented: boolean,
		_posStiffness: number,
		_name: string,
		_teamColor: any,
		_lookOverride: any,
		_positionOverride: Vector3?,
		_angleHold: boolean,
		_heldAngle: Vector3?,
		_build: (FakeCharacter, Vector3, Vector3, string?) -> boolean,
		_syncWeapon: (FakeCharacter, any, string?) -> (),
		_applyQuery: (FakeCharacter, boolean) -> (),
		_ensureIgnore: (FakeCharacter) -> (),
		update: (FakeCharacter, Vector3, any?, any?) -> boolean,
		step: (FakeCharacter, number) -> (),
		isBuilt: (FakeCharacter) -> boolean,
		getThirdPersonObject: (FakeCharacter) -> any,
		getCharacterModel: (FakeCharacter) -> Model?,
		getWeaponModel: (FakeCharacter) -> Instance?,
		getActiveIndex: (FakeCharacter) -> number?,
		setPositionSmoothing: (FakeCharacter, number) -> (),
		setLookOverride: (FakeCharacter, any?) -> (),
		setPositionOverride: (FakeCharacter, Vector3?) -> (),
		getPositionOverride: (FakeCharacter) -> Vector3?,
		setAngleHold: (FakeCharacter, boolean) -> (),
		destroy: (FakeCharacter) -> (),
	},
	FakeCharacter
))

return FakeCharacter
