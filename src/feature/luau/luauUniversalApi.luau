local ScopeController = require("@feature/ui/scope/ScopeController")
local luauApiRegistry = require("@feature/luau/luauApiRegistry")
local universalAdapter = require("@game/universal/adapter/universalAdapter")
local universalBots = require("@game/universal/adapter/universalBots")
local universalEvents = require("@game/universal/adapter/universalEvents")

local luauUniversalApi = {}

local FN_SLOTS: { [string]: string } = {
	setCharacterResolver = "resolveCharacter",
	setPartsResolver = "resolveParts",
	setTeamResolver = "resolveTeam",
	setHealthResolver = "resolveHealth",
	setAliveResolver = "resolveAlive",
	setLocalTeamResolver = "resolveLocalTeam",
	setLocalAliveResolver = "resolveLocalAlive",
	setWeaponResolver = "resolveWeapon",
	setCanShoot = "canShoot",
	setCanFire = "canFire",
	setFire = "fire",
	setStopFire = "stopFire",
	setEspFilter = "espFilter",
}

luauApiRegistry.Register("universal", function(ctx)
	local registry = luauApiRegistry.CreateRegistry(ctx.onUnload)
	local api: { [string]: any } = {}

	local function addSlotSetter(callName: string, slot: string): ()
		api[callName] = function(fn: any): luauApiRegistry.RegistrationHandle
			if type(fn) ~= "function" then
				error(`api.universal.{callName}: expected a function`, 2)
			end
			universalAdapter.SetOverride(slot, fn)
			return registry.Add({
				id = fn,
				fn = fn,
				remove = function(id: any): ()
					if (universalAdapter.overrides :: any)[slot] == id then
						universalAdapter.SetOverride(slot, nil)
					end
				end,
			})
		end
	end

	for callName, slot in next, FN_SLOTS do
		addSlotSetter(callName, slot)
	end

	api.setHitboxParts = function(map: any): luauApiRegistry.RegistrationHandle
		if type(map) ~= "table" then
			error("api.universal.setHitboxParts: expected a table", 2)
		end
		local copy: { [string]: { string } } = {}
		for hitbox, list in next, map do
			if type(hitbox) ~= "string" or type(list) ~= "table" then
				error("api.universal.setHitboxParts: expected { [hitboxName]: { partName } }", 2)
			end
			local names = table.create(#list)
			for i = 1, #list do
				if type(list[i]) ~= "string" then
					error("api.universal.setHitboxParts: part names must be strings", 2)
				end
				names[i] = list[i]
			end
			copy[hitbox] = names
		end
		universalAdapter.SetOverride("hitboxParts", copy)
		return registry.Add({
			id = copy,
			remove = function(id: any): ()
				if universalAdapter.overrides.hitboxParts == id then
					universalAdapter.SetOverride("hitboxParts", nil)
				end
			end,
		})
	end

	api.setWeapon = function(weapon: any): ()
		universalAdapter.SetWeapon(weapon)
	end

	api.clearWeapon = function(): ()
		universalAdapter.ClearWeapon()
	end

	api.setWeaponList = function(list: any): luauApiRegistry.RegistrationHandle
		if type(list) ~= "table" then
			error("api.universal.setWeaponList: expected a list", 2)
		end
		local scopeIds: { string } = {}
		local groupSeen: { [string]: boolean } = {}
		for i = 1, #list do
			local entry = list[i]
			local name: string
			local group: string? = nil
			if type(entry) == "string" then
				name = entry
			elseif type(entry) == "table" and type(entry.name) == "string" then
				name = entry.name
				if type(entry.group) == "string" then
					group = entry.group
				end
			else
				error("api.universal.setWeaponList: entries must be strings or { name, group? }", 2)
			end
			if group then
				local groupId = group:lower()
				if not groupSeen[groupId] then
					groupSeen[groupId] = true
					ScopeController.RegisterGroup(groupId, group)
					scopeIds[#scopeIds + 1] = `group:{groupId}`
				end
				ScopeController.RegisterWeapon(name:lower(), name, groupId)
			else
				ScopeController.RegisterWeapon(name:lower(), name)
			end
			scopeIds[#scopeIds + 1] = `weapon:{name:lower()}`
		end
		return registry.Add({
			id = scopeIds,
			remove = function(id: { string }): ()
				for i = 1, #id do
					ScopeController.RemoveScope(id[i])
				end
			end,
		})
	end

	api.refresh = function(player: Player?): ()
		if player ~= nil and typeof(player) ~= "Instance" then
			error("api.universal.refresh: expected a Player or nil", 2)
		end
		universalAdapter.Refresh(player)
	end

	local function pickInstance(value: any): any
		if typeof(value) == "Instance" then
			return value
		end
		return nil
	end

	local function pickType(value: any, valueType: string): any
		if typeof(value) == valueType then
			return value
		end
		return nil
	end

	api.reportHit = function(info: any): ()
		if type(info) ~= "table" then
			error("api.universal.reportHit: expected a table", 2)
		end
		universalEvents.ReportHit({
			player = pickInstance(info.player),
			part = pickInstance(info.part),
			partName = pickType(info.partName, "string"),
			position = pickType(info.position, "Vector3"),
			damage = pickType(info.damage, "number"),
			headshot = pickType(info.headshot, "boolean"),
			lethal = pickType(info.lethal, "boolean"),
		})
	end

	api.reportKill = function(info: any): ()
		if type(info) ~= "table" then
			error("api.universal.reportKill: expected a table", 2)
		end
		universalEvents.ReportKill({
			player = pickInstance(info.player),
			position = pickType(info.position, "Vector3"),
			headshot = pickType(info.headshot, "boolean"),
		})
	end

	api.reportShot = function(origin: any, target: any, player: any): ()
		if typeof(origin) ~= "Vector3" or typeof(target) ~= "Vector3" then
			error("api.universal.reportShot: expected origin and target Vector3s", 2)
		end
		if player ~= nil and typeof(player) ~= "Instance" then
			error("api.universal.reportShot: player must be a Player or nil", 2)
		end
		universalEvents.ReportShot(origin, target, player :: Player?)
	end

	local scriptBots: { [Model]: boolean } = {}

	local function buildBotHandle(bot: any, model: Model): { [string]: any }
		return {
			setHealth = function(health: number, maxHealth: number?): ()
				if type(health) ~= "number" then
					error("bot.setHealth: expected a number", 2)
				end
				bot:SetHealth(health, maxHealth)
			end,
			setTeam = function(team: string): ()
				if type(team) ~= "string" then
					error("bot.setTeam: expected a string", 2)
				end
				bot:SetTeam(team)
			end,
			setAlive = function(alive: boolean): ()
				bot:SetAlive(alive == true)
			end,
			getModel = function(): Model
				return model
			end,
			remove = function(): ()
				scriptBots[model] = nil
				universalBots.Remove(model)
			end,
		}
	end

	api.bots = {
		add = function(model: any, opts: any): { [string]: any }
			if typeof(model) ~= "Instance" or not model:IsA("Model") then
				error("api.universal.bots.add: expected a Model", 2)
			end
			if opts ~= nil and type(opts) ~= "table" then
				error("api.universal.bots.add: opts must be a table", 2)
			end
			local bot = universalBots.Add(model, opts)
			scriptBots[model] = true
			return buildBotHandle(bot, model)
		end,
		remove = function(model: any): ()
			if typeof(model) ~= "Instance" then
				error("api.universal.bots.remove: expected a Model", 2)
			end
			scriptBots[model :: Model] = nil
			universalBots.Remove(model :: Model)
		end,
		getAll = function(): { Model }
			local out: { Model } = {}
			for model in next, universalBots.GetAll() do
				out[#out + 1] = model
			end
			return out
		end,
	}

	ctx.onUnload:Connect(function(): ()
		for model in next, scriptBots do
			universalBots.Remove(model)
		end
		table.clear(scriptBots)
		universalAdapter.Refresh(nil)
	end)

	return api
end)

return luauUniversalApi
