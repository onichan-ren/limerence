local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local ModuleController = require("@game/ar2/module/ModuleController")

local SoundService = cloneref(game:GetService("SoundService")) :: SoundService

local SHOOT_SOUND_CONSTANT = "Couldn't load firearm sound:"

local SOUNDS = {
	{
		key = "players",
		label = "Footsteps & Bodies",
		kind = "group",
		group = "Characters",
		body = "Player footsteps, voices and body sounds.",
	},
	{
		key = "zombies",
		label = "Zombie Sounds",
		kind = "group",
		group = "Infected",
		body = "Zombie and infected sounds.",
	},
	{
		key = "weapons",
		label = "Weapon Effects",
		kind = "group",
		group = "Effects",
		body = "Gunfire, reloads and impacts.",
	},
	{ key = "enemyShoot", label = "Enemy Gunfire", kind = "shoot", side = "enemy", body = "Other players' gun shots." },
	{ key = "localShoot", label = "Local Gunfire", kind = "shoot", side = "local", body = "Your own gun shots." },
	{ key = "interface", label = "Interface", kind = "group", group = "Interface", body = "Menu and button sounds." },
	{
		key = "vehicles",
		label = "Vehicles",
		kind = "group",
		group = "Vehicles",
		body = "Engine and other vehicle sounds.",
	},
	{ key = "ambient", label = "Ambient", kind = "group", group = "Ambient", body = "World ambience and weather." },
	{ key = "music", label = "Music", kind = "group", group = "Music", body = "Background music." },
}

local SOUND_OPTIONS: { string } = {}
local LABEL_TO_ENTRY: { [string]: any } = {}
for _, entry in next, SOUNDS do
	table.insert(SOUND_OPTIONS, entry.label)
	LABEL_TO_ENTRY[entry.label] = entry
end

local locateShootSound = LPH_NO_VIRTUALIZE(function(fire: any): any
	local ups = debug.getupvalues(fire)
	if type(ups) ~= "table" then
		return nil
	end

	local lastFn = nil
	for i = 1, #ups do
		local uv = ups[i]
		if type(uv) == "function" then
			lastFn = uv
			local consts = debug.getconstants(uv)
			if type(consts) == "table" then
				for _, constant in next, consts do
					if constant == SHOOT_SOUND_CONSTANT then
						return uv
					end
				end
			end
		end
	end

	return lastFn
end)

local SoundRemovals = {}
SoundRemovals.__index = SoundRemovals

setmetatable(SoundRemovals, { __index = BaseFeature })

function SoundRemovals.new(link: gameUi.Linker): SoundRemovals
	local self = BaseFeature.new() :: any
	setmetatable(self, SoundRemovals)

	self._muted = {} :: { [string]: boolean }
	self._volumes = {} :: { [string]: number }
	self._blockLocalShoot = false
	self._blockEnemyShoot = false
	self._shootHookTarget = nil :: any

	local dropdown = link:Dropdown("sounds", "Sound Removals", SOUND_OPTIONS, {}):SetMode("multi")
	dropdown:SetTip({
		title = "Sound Removals",
		body = "Mute selected in-game sounds.",
	})

	self:Track(dropdown:OnChange(function(value: any): ()
		self:Reconcile(value)
	end))

	self:Reconcile(dropdown:Peek())

	return self
end

function SoundRemovals.Reconcile(self: SoundRemovals, selection: any): ()
	local selected: { [string]: boolean } = {}
	if type(selection) == "table" then
		for _, label in next, selection do
			local entry = LABEL_TO_ENTRY[label]
			if entry then
				selected[entry.key] = true
			end
		end
	end

	for _, entry in next, SOUNDS do
		local on = selected[entry.key] == true
		if entry.kind == "group" then
			if on then
				self:Mute(entry.group)
			else
				self:Unmute(entry.group)
			end
		elseif entry.kind == "shoot" then
			if entry.side == "local" then
				self._blockLocalShoot = on
			else
				self._blockEnemyShoot = on
			end
		end
	end

	if self._blockLocalShoot or self._blockEnemyShoot then
		self:EnableShootHook()
	else
		self:DisableShootHook()
	end
end

function SoundRemovals.EnableShootHook(self: SoundRemovals): ()
	if self._shootHookTarget then
		return
	end

	local Bullets = ModuleController.GetModule("Bullets")
	local fire = Bullets and Bullets.Fire
	if type(fire) ~= "function" then
		return
	end

	local target = locateShootSound(fire)
	if type(target) ~= "function" then
		return
	end

	self._shootHookTarget = target
	local original
	original = hook.add(
		target,
		LPH_NO_VIRTUALIZE(function(weaponName: any, position: any, suppressed: any, isLocal: any, ...): ...any
			if isLocal and self._blockLocalShoot then
				return
			end
			if not isLocal and self._blockEnemyShoot then
				return
			end
			return original(weaponName, position, suppressed, isLocal, ...)
		end)
	)
end

function SoundRemovals.DisableShootHook(self: SoundRemovals): ()
	if not self._shootHookTarget then
		return
	end
	hook.restore(self._shootHookTarget)
	self._shootHookTarget = nil
end

function SoundRemovals.Mute(self: SoundRemovals, groupName: string): ()
	if self._muted[groupName] then
		return
	end

	local group = SoundService:FindFirstChild(groupName) :: SoundGroup?
	if not group then
		return
	end

	local volume = group.Volume
	self._volumes[groupName] = volume > 0 and volume or 1

	hook.addInstance(group)
	group.Volume = 0
	hook.blockProperty(group, "Volume")
	self._muted[groupName] = true
end

function SoundRemovals.Unmute(self: SoundRemovals, groupName: string): ()
	if not self._muted[groupName] then
		return
	end
	self._muted[groupName] = false

	local group = SoundService:FindFirstChild(groupName) :: SoundGroup?
	if group then
		hook.unblockProperty(group, "Volume")
		group.Volume = self._volumes[groupName] or 1
	end
end

function SoundRemovals.Destroy(self: SoundRemovals): ()
	for _, entry in next, SOUNDS do
		if entry.kind == "group" then
			self:Unmute(entry.group)
		end
	end
	self:DisableShootHook()
	BaseFeature.Destroy(self)
end

export type SoundRemovals =
	typeof(setmetatable(
		{} :: {
			_muted: { [string]: boolean },
			_volumes: { [string]: number },
			_blockLocalShoot: boolean,
			_blockEnemyShoot: boolean,
			_shootHookTarget: any,
			Reconcile: (SoundRemovals, any) -> (),
			Mute: (SoundRemovals, string) -> (),
			Unmute: (SoundRemovals, string) -> (),
			EnableShootHook: (SoundRemovals) -> (),
			DisableShootHook: (SoundRemovals) -> (),
		},
		SoundRemovals
	))
	& BaseFeature.BaseFeature

return SoundRemovals
