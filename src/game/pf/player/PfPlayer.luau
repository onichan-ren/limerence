return LPH_JIT_MAX(function()
	local Charm = require("@pkg/Charm")
	local Janitor = require("@pkg/Janitor")
	local BasePlayer = require("@feature/player/BasePlayer")

	local at = Charm.atom
	local peek = Charm.peek

	local RELOAD_TIME = 2.5

	local function readTeam(player: Player): string
		local team = player.Team
		if team then
			return team.Name
		end
		return ""
	end

	local PfPlayer = {}
	PfPlayer.__index = PfPlayer

	setmetatable(PfPlayer, { __index = BasePlayer })

	function PfPlayer.new(player: Player): PfPlayer
		local self = BasePlayer.new(player) :: any
		setmetatable(self, PfPlayer)

		self.character = at(nil :: Model?)
		self.hrp = at(nil :: BasePart?)
		self.humanoid = at(nil :: Humanoid?)
		self.alive = at(false)
		self.health = at(0)
		self.maxHealth = at(100)
		self.parts = at({} :: { [string]: Instance })
		self.partSizes = at({} :: { [string]: Vector3 })
		self.team = at(readTeam(player))
		self.isEnemy = at(false)
		self.weapon = at("")
		self.stance = at("stand")
		self.aiming = at(false)
		self.sprinting = at(false)
		self.spotted = at(false)
		self.ammo = at(nil :: number?)
		self.ammoCapacity = at(nil :: number?)
		self.isReloading = at(false)

		self._dead = false
		self._magSize = 0
		self._reloadToken = 0

		self._janitor = Janitor.new()
		self._janitor:Add(player:GetPropertyChangedSignal("Team"):Connect(function(): ()
			self.team(readTeam(player))
		end))

		local proxy = Instance.new("Part")
		proxy.Anchored = true
		proxy.CanCollide = false
		proxy.CanQuery = false
		proxy.CanTouch = false
		proxy.Transparency = 1
		proxy.Size = Vector3.one
		self._proxy = proxy

		return self
	end

	function PfPlayer.SyncFromEntry(self: PfPlayer, entry: any): ()
		if self._dead then
			return
		end
		if not entry:isAlive() then
			self:MarkDead()
			return
		end

		local tpo = entry:getThirdPersonObject()
		local hash = tpo and tpo:getCharacterHash()
		local torso = hash and hash.Torso
		local rendering = tpo and tpo._isRendering == true and torso ~= nil and torso.Parent ~= nil

		if rendering then
			local model = tpo:getCharacterModel()
			if peek(self.character) ~= model then
				self.character(model)
			end
			if peek(self.hrp) ~= torso then
				self.hrp(torso)
			end
			if peek(self.parts) ~= hash then
				self.parts(hash)
				local sizeSource = tpo._partSizes
				local sizes = {}
				if sizeSource then
					for name, part in next, hash do
						sizes[name] = sizeSource[part] or part.Size
					end
				end
				self.partSizes(sizes)
			end
		else
			if peek(self.character) ~= nil then
				self.character(nil)
			end
			if next(peek(self.parts)) ~= nil then
				self.parts({})
				self.partSizes({})
			end

			local position = entry:isReady() and entry:getPosition()
			if typeof(position) == "Vector3" then
				self._proxy.Position = position
				if peek(self.hrp) ~= self._proxy then
					self.hrp(self._proxy)
				end
			elseif peek(self.hrp) ~= nil then
				self.hrp(nil)
			end
		end

		local health, maxHealth = entry:getHealth()
		if peek(self.health) ~= health then
			self.health(health)
		end
		if peek(self.maxHealth) ~= maxHealth then
			self.maxHealth(maxHealth)
		end

		local enemy = entry:isEnemy()
		if peek(self.isEnemy) ~= enemy then
			self.isEnemy(enemy)
		end

		local stance = "stand"
		local aiming = false
		local sprinting = false
		if tpo then
			local s = tpo._stanceSpring.t
			if s >= 0.75 then
				stance = "prone"
			elseif s >= 0.25 then
				stance = "crouch"
			end
			aiming = tpo._aimSpring.t == 0
			sprinting = tpo._sprintSpring.t == 0
		end
		if peek(self.stance) ~= stance then
			self.stance(stance)
		end
		if peek(self.aiming) ~= aiming then
			self.aiming(aiming)
		end
		if peek(self.sprinting) ~= sprinting then
			self.sprinting(sprinting)
		end

		local weaponObject = entry:getWeaponObject()
		local weaponName = weaponObject and weaponObject.weaponName or ""
		if peek(self.weapon) ~= weaponName then
			self.weapon(weaponName)
			local magSize = 0
			if weaponObject then
				local weaponData = weaponObject.weaponData
				magSize = (weaponData and tonumber(weaponData.magsize)) or 0
			end
			self:_resetAmmo(magSize)
		end

		if not peek(self.alive) then
			self.alive(true)
		end
	end

	function PfPlayer._resetAmmo(self: PfPlayer, magSize: number): ()
		self._magSize = magSize
		self._reloadToken += 1
		if peek(self.isReloading) then
			self.isReloading(false)
		end
		if magSize > 0 then
			self.ammoCapacity(magSize)
			self.ammo(magSize)
		else
			if peek(self.ammoCapacity) ~= nil then
				self.ammoCapacity(nil)
			end
			if peek(self.ammo) ~= nil then
				self.ammo(nil)
			end
		end
	end

	function PfPlayer._beginReload(self: PfPlayer): ()
		self._reloadToken += 1
		local token = self._reloadToken
		self.isReloading(true)
		task.delay(RELOAD_TIME, function(): ()
			if self._reloadToken ~= token or self._dead then
				return
			end
			setthreadidentity(8)
			self.isReloading(false)
			if (self._magSize :: number) > 0 then
				self.ammo(self._magSize)
			end
		end)
	end

	function PfPlayer.OnFire(self: PfPlayer): ()
		if self._dead then
			return
		end
		local capacity = self._magSize
		if capacity <= 0 then
			return
		end
		if peek(self.isReloading) then
			self._reloadToken += 1
			self.isReloading(false)
			self.ammo(capacity)
		end
		local current = peek(self.ammo)
		if type(current) ~= "number" then
			current = capacity
		end
		current -= 1
		if current <= 0 then
			self.ammo(0)
			self:_beginReload()
		else
			self.ammo(current)
		end
	end

	function PfPlayer.MarkDead(self: PfPlayer): ()
		if peek(self.weapon) ~= "" then
			self.weapon("")
		end
		if peek(self.stance) ~= "stand" then
			self.stance("stand")
		end
		if peek(self.aiming) then
			self.aiming(false)
		end
		if peek(self.sprinting) then
			self.sprinting(false)
		end
		if peek(self.spotted) then
			self.spotted(false)
		end
		if peek(self.isReloading) then
			self._reloadToken += 1
			self.isReloading(false)
		end
		if peek(self.ammo) ~= nil then
			self.ammo(nil)
		end
		if peek(self.ammoCapacity) ~= nil then
			self.ammoCapacity(nil)
		end
		self._magSize = 0
		if peek(self.alive) then
			self.alive(false)
		end
	end

	function PfPlayer.OnDied(self: PfPlayer): ()
		self._dead = true
		self:MarkDead()
		if peek(self.health) ~= 0 then
			self.health(0)
		end
	end

	function PfPlayer.OnRespawn(self: PfPlayer): ()
		self._dead = false
	end

	function PfPlayer.IsAlive(self: PfPlayer): boolean
		return peek(self.alive)
	end

	function PfPlayer.GetTeam(self: PfPlayer): string
		return peek(self.team)
	end

	function PfPlayer.IsEnemy(self: PfPlayer): boolean
		return peek(self.isEnemy)
	end

	function PfPlayer.GetCharacter(self: PfPlayer): Model?
		return peek(self.character)
	end

	function PfPlayer.GetParts(self: PfPlayer): { [string]: Instance }
		return peek(self.parts)
	end

	function PfPlayer.GetPartSizes(self: PfPlayer): { [string]: Vector3 }
		return peek(self.partSizes)
	end

	function PfPlayer.Destroy(self: PfPlayer): ()
		self._proxy:Destroy()
		self._janitor:Destroy()
	end

	export type PfPlayer =
		typeof(setmetatable(
			{} :: {
				_janitor: Janitor.Janitor,
				_proxy: BasePart,
				_dead: boolean,
				_magSize: number,
				_reloadToken: number,
				character: Charm.Atom<Model?>,
				hrp: Charm.Atom<BasePart?>,
				humanoid: Charm.Atom<Humanoid?>,
				alive: Charm.Atom<boolean>,
				health: Charm.Atom<number>,
				maxHealth: Charm.Atom<number>,
				parts: Charm.Atom<{ [string]: Instance }>,
				partSizes: Charm.Atom<{ [string]: Vector3 }>,
				team: Charm.Atom<string>,
				isEnemy: Charm.Atom<boolean>,
				weapon: Charm.Atom<string>,
				stance: Charm.Atom<string>,
				aiming: Charm.Atom<boolean>,
				sprinting: Charm.Atom<boolean>,
				spotted: Charm.Atom<boolean>,
				ammo: Charm.Atom<number?>,
				ammoCapacity: Charm.Atom<number?>,
				isReloading: Charm.Atom<boolean>,
				SyncFromEntry: (PfPlayer, any) -> (),
				MarkDead: (PfPlayer) -> (),
				OnDied: (PfPlayer) -> (),
				OnRespawn: (PfPlayer) -> (),
				OnFire: (PfPlayer) -> (),
				_resetAmmo: (PfPlayer, number) -> (),
				_beginReload: (PfPlayer) -> (),
			},
			PfPlayer
		))
		& BasePlayer.BasePlayer

	return PfPlayer
end)()
