return LPH_JIT_MAX(function()
	local Players = cloneref(game:GetService("Players")) :: Players

	local hook = require("@share/hook")
	local logger = require("@share/logger").new("inventoryEquip")
	local rankCharms = require("@game/rivals/feature/inventory/rankCharms")
	local playerDataAccess = require("@game/rivals/feature/inventory/playerDataAccess")
	local cosmeticLibraryAccess = require("@game/rivals/feature/inventory/cosmeticLibraryAccess")

	export type Overlay = {
		skin: string?,
		wrap: string?,
		charm: string?,
		finisher: string?,
		wrapInverted: boolean?,
	}

	export type OverlayMap = { [string]: Overlay }

	local inventoryEquip = {
		_installed = false,
		_originalGet = nil :: ((any, ...any) -> ...any)?,
		_controller = nil :: any,
		_getOverlayMap = nil :: (() -> OverlayMap)?,
		_entityInstalled = false,
		_originalEntityGet = nil :: ((any, ...any) -> ...any)?,
		_replicatedClass = nil :: any,
		_viewModelExists = nil :: ((string) -> boolean)?,
		_getUnlockSet = nil :: (() -> { [string]: boolean })?,
		_remoteProvider = nil :: ((userId: number) -> OverlayMap?)?,
	}

	function inventoryEquip.setUnlockProvider(getUnlockSet: (() -> { [string]: boolean })?): ()
		inventoryEquip._getUnlockSet = getUnlockSet
	end

	function inventoryEquip.setRemoteProvider(fn: ((userId: number) -> OverlayMap?)?): ()
		inventoryEquip._remoteProvider = fn
	end

	local function buildCosmeticTable(existingValue: any, name: string?): any?
		if name == nil then
			return nil
		end
		local clone = (type(existingValue) == "table" and table.clone(existingValue) or {})
		clone.Name = name
		return clone
	end

	local function buildCharmTable(existingValue: any, name: string?): any?
		if name == nil then
			return nil
		end
		local clone = (type(existingValue) == "table" and table.clone(existingValue) or {})
		local resolved = rankCharms.resolve(name)
		if resolved then
			clone.Name = resolved.charmName
			local meta = (type(clone.Metadata) == "table" and table.clone(clone.Metadata) or {})
			meta.SeasonELO = resolved.elo
			meta.SeasonLeaderboardRank = resolved.leaderboardRank
			clone.Metadata = meta
		else
			clone.Name = name
		end
		return clone
	end

	local function applyOverlayToEntry(entry: any, override: Overlay): any
		local clone = table.clone(entry)
		if override.skin ~= nil then
			clone.Skin = buildCosmeticTable(entry.Skin, override.skin)
		end
		if override.charm ~= nil then
			clone.Charm = buildCharmTable(entry.Charm, override.charm)
		end
		if override.finisher ~= nil then
			clone.Finisher = buildCosmeticTable(entry.Finisher, override.finisher)
		end
		if override.wrap ~= nil or override.wrapInverted ~= nil then
			local existing = (type(entry.Wrap) == "table" and table.clone(entry.Wrap) or {})
			if override.wrap ~= nil then
				existing.Name = override.wrap
			end
			if override.wrapInverted ~= nil then
				existing.Inverted = override.wrapInverted
			end
			if existing.Name == nil then
				clone.Wrap = nil
			else
				clone.Wrap = existing
			end
		end
		return clone
	end

	local function applyOverlayToInventory(inventory: { any }, overlayMap: OverlayMap): { any }
		local out = table.clone(inventory)
		for index, entry in next, out do
			if type(entry) ~= "table" or type(entry.Name) ~= "string" then
				continue
			end
			local override = overlayMap[entry.Name]
			if not override then
				continue
			end
			out[index] = applyOverlayToEntry(entry, override)
		end
		return out
	end

	inventoryEquip.applyOverlayToInventory = applyOverlayToInventory

	function inventoryEquip.installHook(controller: any, getOverlayMap: () -> OverlayMap): ()
		if inventoryEquip._installed then
			return
		end
		if type(controller) ~= "table" or type(controller.Get) ~= "function" then
			return
		end
		inventoryEquip._installed = true
		inventoryEquip._controller = controller
		inventoryEquip._getOverlayMap = getOverlayMap

		local originalGet
		originalGet = hook.add(controller.Get, function(self, key, ...)
			if key ~= "CosmeticInventory" and key ~= "WeaponInventory" then
				return originalGet(self, key, ...)
			end
			local cheat = getthreadidentity() == 8
			local exitIdentity = (cheat and 8 or 2)
			setthreadidentity(2)
			local results = table.pack(originalGet(self, key, ...))
			if key == "CosmeticInventory" then
				local fetchUnlock = inventoryEquip._getUnlockSet
				local unlocked = fetchUnlock and fetchUnlock() or nil
				setthreadidentity(exitIdentity)
				if not unlocked or next(unlocked) == nil then
					return table.unpack(results, 1, results.n)
				end
				local merged = (type(results[1]) == "table" and table.clone(results[1]) or {})
				for name, on in next, unlocked do
					if on and merged[name] == nil then
						merged[name] = true
					end
				end
				return merged
			end
			if key ~= "WeaponInventory" then
				setthreadidentity(exitIdentity)
				return table.unpack(results, 1, results.n)
			end
			local result = results[1]
			if type(result) ~= "table" then
				setthreadidentity(exitIdentity)
				return table.unpack(results, 1, results.n)
			end
			local fetch = inventoryEquip._getOverlayMap
			local overlay = fetch and fetch() or nil
			setthreadidentity(exitIdentity)
			if not overlay or next(overlay) == nil then
				return table.unpack(results, 1, results.n)
			end
			return applyOverlayToInventory(result, overlay)
		end)
		inventoryEquip._originalGet = originalGet
	end

	function inventoryEquip.uninstallHook(): ()
		if not inventoryEquip._installed then
			return
		end
		local controller = inventoryEquip._controller
		if controller and controller.Get then
			hook.restore(controller.Get)
		end
		inventoryEquip._installed = false
		inventoryEquip._originalGet = nil
		inventoryEquip._controller = nil
		inventoryEquip._getOverlayMap = nil
		inventoryEquip._getUnlockSet = nil
	end

	local COSMETIC_KEYS: { [string]: string } = {
		Skin = "skin",
		Wrap = "wrap",
		Charm = "charm",
		Finisher = "finisher",
	}

	local function appendNameCandidate(out: { string }, seen: { [string]: boolean }, value: any): ()
		if type(value) ~= "string" or value == "" or seen[value] then
			return
		end
		seen[value] = true
		out[#out + 1] = value
	end

	local function readEntityNameCandidates(entity: any, fallbackName: any): { string }
		local out: { string } = {}
		local seen: { [string]: boolean } = {}

		local data = rawget(entity, "Data")
		if type(data) == "table" then
			appendNameCandidate(out, seen, rawget(data, "Name"))
			appendNameCandidate(out, seen, rawget(data, "ItemName"))
			appendNameCandidate(out, seen, rawget(data, "WeaponName"))
		end

		local clientItem = rawget(entity, "ClientItem")
		if type(clientItem) == "table" then
			appendNameCandidate(out, seen, rawget(clientItem, "Name"))
			local clientData = rawget(clientItem, "Data")
			if type(clientData) == "table" then
				appendNameCandidate(out, seen, rawget(clientData, "Name"))
				appendNameCandidate(out, seen, rawget(clientData, "ItemName"))
				appendNameCandidate(out, seen, rawget(clientData, "WeaponName"))
			end
		end

		appendNameCandidate(out, seen, fallbackName)
		return out
	end

	local resolveOverlayEntry = LPH_NO_VIRTUALIZE(
		function(overlay: OverlayMap?, entity: any, fallbackName: any): (Overlay?, string?)
			if type(overlay) ~= "table" then
				return nil, nil
			end
			for _, candidate in next, readEntityNameCandidates(entity, fallbackName) do
				local entry = overlay[candidate]
				if type(entry) == "table" then
					return entry, candidate
				end
			end

			if type(fallbackName) == "string" and fallbackName ~= "" then
				local cosmetic = cosmeticLibraryAccess.getCosmetic(fallbackName)
				local weapon = cosmetic and cosmetic.weapon
				if type(weapon) == "string" then
					local overlayEntry = overlay[weapon]
					if type(overlayEntry) == "table" then
						return overlayEntry, weapon
					end
				end
			end

			if type(fallbackName) == "string" and fallbackName ~= "" then
				local weaponInventory = playerDataAccess.get("WeaponInventory")
				if type(weaponInventory) == "table" then
					for _, invEntry in next, weaponInventory do
						if type(invEntry) ~= "table" then
							continue
						end
						local weaponName = invEntry.Name
						if type(weaponName) ~= "string" then
							continue
						end
						local overlayEntry = overlay[weaponName]
						if type(overlayEntry) ~= "table" then
							continue
						end
						local skinValue = invEntry.Skin
						local equippedSkinName: string? = nil
						if type(skinValue) == "table" then
							equippedSkinName = type(skinValue.Name) == "string" and skinValue.Name or nil
						elseif type(skinValue) == "string" then
							equippedSkinName = skinValue
						end
						if equippedSkinName == fallbackName then
							return overlayEntry, weaponName
						end
					end
				end
			end

			return nil, nil
		end
	)

	local function getViewModelsFolder(): Instance?
		local localPlayer = Players.LocalPlayer
		if not localPlayer then
			return nil
		end
		local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
		local assets = playerScripts and playerScripts:FindFirstChild("Assets")
		return assets and assets:FindFirstChild("ViewModels")
	end

	local findSkinModel = LPH_NO_VIRTUALIZE(function(viewModels: Instance, skinName: string): Instance?
		for _, desc in next, viewModels:QueryDescendants("Instance") do
			if desc:IsA("Model") and desc.Name == skinName then
				return desc
			end
		end
		return nil
	end)

	local _injectedChildren: { [string]: { Instance } } = {}

	local hideInstance = LPH_NO_VIRTUALIZE(function(inst: any): ()
		if inst:HasTag("Wrappable") then
			inst:RemoveTag("Wrappable")
		end
		if inst:IsA("BasePart") then
			inst.Transparency = 1
			inst.CanCollide = false
			inst.CanQuery = false
			inst.CanTouch = false
		elseif inst:IsA("Decal") or inst:IsA("Texture") then
			inst.Transparency = 1
		elseif inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Trail") then
			inst.Enabled = false
		elseif inst:IsA("Light") then
			inst.Enabled = false
		end
	end)

	local WRAP_SKIP_NODES: { [string]: boolean } = {
		_fake = true,
		LeftArmWrapped = true,
		RightArmWrapped = true,
	}

	local mirrorMissingChildren
	mirrorMissingChildren = function(baseNode: Instance, skinNode: Instance, skinName: string): boolean
		for _, baseChild in next, baseNode:GetChildren() do
			if WRAP_SKIP_NODES[baseChild.Name] then
				continue
			end
			local existing = skinNode:FindFirstChild(baseChild.Name)
			if existing then
				if not mirrorMissingChildren(baseChild, existing, skinName) then
					return false
				end
				continue
			end
			local clone = baseChild:Clone()
			if not clone then
				return false
			end
			hideInstance(clone)
			for _, d in next, clone:QueryDescendants("Instance") do
				hideInstance(d)
			end
			clone.Parent = skinNode
			local list = _injectedChildren[skinName]
			if not list then
				list = {}
				_injectedChildren[skinName] = list
			end
			list[#list + 1] = clone
		end
		return true
	end

	local ensureSkinSafe = LPH_NO_VIRTUALIZE(function(baseName: string, skinName: string): boolean
		local viewModels = getViewModelsFolder()
		if not viewModels then
			return false
		end
		local skinModel = findSkinModel(viewModels, skinName)
		if not skinModel then
			return false
		end
		local weapons = viewModels:FindFirstChild("Weapons")
		local baseFolder = weapons and weapons:FindFirstChild(baseName)
		if not baseFolder then
			return false
		end
		return mirrorMissingChildren(baseFolder, skinModel, skinName)
	end)

	local _skinSafePairs: { [string]: boolean } = {}
	local _warnedSkinFailures: { [string]: boolean } = {}

	local function ensureSkinSafeCached(baseName: string, skinName: string): boolean
		local key = baseName .. "\0" .. skinName
		if _skinSafePairs[key] then
			return true
		end
		local ok = ensureSkinSafe(baseName, skinName)
		if ok then
			_skinSafePairs[key] = true
		end
		return ok
	end

	function inventoryEquip.clearInjectedChildren(): ()
		for _, list in next, _injectedChildren do
			for _, inst in next, list do
				inst:Destroy()
			end
		end
		_injectedChildren = {}
		_skinSafePairs = {}
		_warnedSkinFailures = {}
	end

	local function isLocalClientViewModel(self: any): boolean
		if not (rawget(self, "Equipped") and rawget(self, "Unequipped") and rawget(self, "ClientItem")) then
			return false
		end
		local clientItem = rawget(self, "ClientItem")
		if not clientItem then
			return true
		end
		local clientFighter = rawget(clientItem, "ClientFighter")
		if not clientFighter then
			return true
		end
		local isLocal: boolean = clientFighter.IsLocalPlayer == true
		if not isLocal then
			return false
		end
		return true
	end

	local function isLocalEntity(self: any): boolean
		local clientItem = rawget(self, "ClientItem")
		if not clientItem then
			return true
		end
		local clientFighter = rawget(clientItem, "ClientFighter")
		if not clientFighter then
			return true
		end
		local isLocal: boolean = clientFighter.IsLocalPlayer == true
		if not isLocal then
			return false
		end
		return true
	end

	local function entityUserId(self: any): number?
		local clientItem = rawget(self, "ClientItem")
		if not clientItem then
			return nil
		end
		local clientFighter = rawget(clientItem, "ClientFighter")
		if not clientFighter then
			return nil
		end
		local uid: number? = nil
		local player = clientFighter.Player
		if player then
			uid = player.UserId
		end
		return uid
	end

	local function selectOverlay(self: any, isLocalFn: (any) -> boolean): OverlayMap?
		if isLocalFn(self) then
			local fetch = inventoryEquip._getOverlayMap
			return fetch and fetch() or nil
		end
		local provider = inventoryEquip._remoteProvider
		if not provider then
			return nil
		end
		local uid = entityUserId(self)
		if not uid then
			return nil
		end
		return provider(uid)
	end

	function inventoryEquip.installEntityHook(
		replicatedClass: any,
		getOverlayMap: () -> OverlayMap,
		viewModelExists: ((string) -> boolean)?
	): ()
		if inventoryEquip._entityInstalled then
			return
		end
		if type(replicatedClass) ~= "table" or type(replicatedClass.Get) ~= "function" then
			logger:warn("ReplicatedClass.Get missing")
			return
		end
		inventoryEquip._entityInstalled = true
		inventoryEquip._replicatedClass = replicatedClass
		inventoryEquip._viewModelExists = viewModelExists
		if not inventoryEquip._getOverlayMap then
			inventoryEquip._getOverlayMap = getOverlayMap
		end

		local originalEntityGet
		local function entitySlowGet(self, key, ...)
			local cheat = getthreadidentity() == 8
			local exitIdentity = (cheat and 8 or 2)
			setthreadidentity(2)
			local results = table.pack(originalEntityGet(self, key, ...))
			setthreadidentity(exitIdentity)

			if key == "Name" then
				local resolvedName = results[1]
				if type(resolvedName) ~= "string" then
					return table.unpack(results, 1, results.n)
				end
				local overlay = selectOverlay(self, isLocalClientViewModel)
				if not overlay or next(overlay) == nil then
					return table.unpack(results, 1, results.n)
				end
				local entry, overlayWeaponName = resolveOverlayEntry(overlay, self, resolvedName)
				setthreadidentity(exitIdentity)
				if not entry or type(entry.skin) ~= "string" then
					return table.unpack(results, 1, results.n)
				end
				if entry.skin == resolvedName then
					return resolvedName
				end
				local baseName = overlayWeaponName or resolvedName
				if not ensureSkinSafeCached(baseName, entry.skin) then
					local warnKey = baseName .. "\0" .. entry.skin
					if not _warnedSkinFailures[warnKey] then
						_warnedSkinFailures[warnKey] = true
					end
					return table.unpack(results, 1, results.n)
				end
				return entry.skin
			end

			local overrideKey = COSMETIC_KEYS[key]
			if not overrideKey then
				return table.unpack(results, 1, results.n)
			end
			local overlay = selectOverlay(self, isLocalEntity)
			if not overlay or next(overlay) == nil then
				return table.unpack(results, 1, results.n)
			end
			local entry = select(1, resolveOverlayEntry(overlay, self, nil))
			setthreadidentity(exitIdentity)
			if not entry then
				return table.unpack(results, 1, results.n)
			end
			local existing = results[1]
			if key == "Wrap" then
				if entry.wrap == nil and entry.wrapInverted == nil then
					return table.unpack(results, 1, results.n)
				end
				local wrapTable = (type(existing) == "table" and table.clone(existing) or {})
				if entry.wrap ~= nil then
					wrapTable.Name = entry.wrap
				end
				if entry.wrapInverted ~= nil then
					wrapTable.Inverted = entry.wrapInverted
				end
				return wrapTable
			end
			local overrideName = (entry :: any)[overrideKey]
			if overrideName == nil then
				return table.unpack(results, 1, results.n)
			end
			if key == "Charm" then
				return buildCharmTable(existing, overrideName)
			end
			local cosmeticTable = (type(existing) == "table" and table.clone(existing) or {})
			cosmeticTable.Name = overrideName
			return cosmeticTable
		end
		originalEntityGet = hook.add(
			replicatedClass.Get,
			LPH_NO_VIRTUALIZE(function(self, key, ...)
				if key ~= "Name" and not COSMETIC_KEYS[key] then
					return originalEntityGet(self, key, ...)
				end
				return entitySlowGet(self, key, ...)
			end)
		)
		inventoryEquip._originalEntityGet = originalEntityGet
	end

	function inventoryEquip.uninstallEntityHook(): ()
		if not inventoryEquip._entityInstalled then
			return
		end
		local cls = inventoryEquip._replicatedClass
		if cls and cls.Get then
			hook.restore(cls.Get)
		end
		inventoryEquip._entityInstalled = false
		inventoryEquip._originalEntityGet = nil
		inventoryEquip._replicatedClass = nil
		inventoryEquip._viewModelExists = nil
	end

	function inventoryEquip.fireDataChanged(controller: any, key: string): ()
		if not controller then
			return
		end
		setthreadidentity(2)
		local signal = controller.GetDataChangedSignal(controller, key)
		setthreadidentity(8)
		if type(signal) ~= "table" then
			return
		end
		local fire = signal.Fire
		if type(fire) ~= "function" then
			return
		end
		setthreadidentity(2)
		fire(signal)
		setthreadidentity(8)
	end

	return inventoryEquip
end)()
