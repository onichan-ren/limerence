local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage
local RunService = cloneref(game:GetService("RunService")) :: RunService
local Players = cloneref(game:GetService("Players")) :: Players

local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")
local ReactCharm = require("@pkg/ReactCharm")
local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local clientApi = require("@game/bloxstrike/client/clientApi")
local NetworkController = require("@game/bloxstrike/network/NetworkController")
local loadoutState = require("@game/bloxstrike/loadout/loadoutState")
local gameHudState = require("@game/bloxstrike/feature/visual/hud/gameHudState")
local nativeHud = require("@game/bloxstrike/feature/visual/hud/nativeHud")
local gameHudRenderer = require("@game/bloxstrike/feature/visual/hud/renderer")
local dpiState = require("@ui/util/dpiState")

local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement

local HUD_DISPLAY_ORDER = 100
local KILL_FEED_LIMIT = 7
local KILL_LIFETIME = 5
local KILL_FADE = 0.45

local TAG_ICON_NAMES = { "Headshot", "NoScope", "Smoke", "Wallbang", "Blind", "Jump", "FlashAssist" }

local LocalPlayer = Players.LocalPlayer

local SLOT_ORDER = {
	Primary = 1,
	Secondary = 2,
	Melee = 3,
	Grenade = 4,
	C4 = 5,
}

local COLOR_MENUS = {
	{
		key = "themeColors",
		label = "Theme Colors",
		pickers = {
			{ key = "accent", label = "Accent Color", color = Color3.fromRGB(225, 225, 225), transparency = 0 },
			{ key = "text", label = "Text Color", color = Color3.fromRGB(229, 229, 229), transparency = 0 },
			{
				key = "textSecondary",
				label = "Secondary Text Color",
				color = Color3.fromRGB(150, 150, 150),
				transparency = 0,
			},
		},
	},
	{
		key = "playerColors",
		label = "Player Colors",
		pickers = {
			{ key = "team", label = "Team Color", color = Color3.fromRGB(135, 180, 235), transparency = 0 },
			{ key = "enemy", label = "Enemy Color", color = Color3.fromRGB(220, 95, 95), transparency = 0 },
		},
	},
	{
		key = "panelColors",
		label = "Panel Colors",
		pickers = {
			{ key = "background", label = "Background Color", color = Color3.fromRGB(24, 24, 24), transparency = 0.25 },
			{ key = "surface", label = "Surface Color", color = Color3.fromRGB(40, 40, 40), transparency = 0 },
			{ key = "border", label = "Border Color", color = Color3.fromRGB(48, 48, 48), transparency = 0.5 },
			{ key = "shadow", label = "Shadow Color", color = Color3.fromRGB(0, 0, 0), transparency = 0.55 },
		},
	},
	{
		key = "killFeedColors",
		label = "Kill Feed Colors",
		pickers = {
			{
				key = "killBackground",
				label = "Background Color",
				color = Color3.fromRGB(24, 24, 24),
				transparency = 0.25,
			},
			{ key = "killStroke", label = "Stroke Color", color = Color3.fromRGB(48, 48, 48), transparency = 0.5 },
			{ key = "killShadow", label = "Glow Color", color = Color3.fromRGB(0, 0, 0), transparency = 0.55 },
			{ key = "killIcon", label = "Icon Color", color = Color3.fromRGB(229, 229, 229), transparency = 0 },
		},
	},
	{
		key = "teamColors",
		label = "Team Card Colors",
		pickers = {
			{ key = "teamLine", label = "Line Color", color = Color3.fromRGB(225, 225, 225), transparency = 0 },
			{ key = "teamPip", label = "Pip Color", color = Color3.fromRGB(225, 225, 225), transparency = 0 },
			{ key = "teamLabel", label = "Label Color", color = Color3.fromRGB(135, 180, 235), transparency = 0 },
		},
	},
}

local weaponDefCache: { [string]: any } = {}

local function resolveWeaponDef(weaponName: string): any
	local cached = weaponDefCache[weaponName]
	if cached ~= nil then
		return cached or nil
	end

	local defInst = ReplicatedStorage.Database.Custom.Weapons:FindFirstChild(weaponName)
	if not defInst then
		weaponDefCache[weaponName] = false
		return nil
	end

	setthreadidentity(2)
	local def = require(defInst)
	setthreadidentity(8)
	if type(def) ~= "table" then
		weaponDefCache[weaponName] = false
		return nil
	end

	weaponDefCache[weaponName] = def
	return def
end

local function displayName(name: string): string
	if name == "T Knife" or name == "CT Knife" then
		return "Knife"
	end
	return name
end

local function getAnimations(entry: any): any
	local viewmodel = entry and entry.Viewmodel
	local animation = viewmodel and viewmodel.Animation
	return animation and animation.Animations or nil
end

local function getTrack(animations: any, name: string): any
	if not animations then
		return nil
	end
	return animations[name]
end

local killId = 0
local tagIcons: { [string]: string }? = nil
local pipIcon: string? = nil

local function getTagIcons(): { [string]: string }
	if tagIcons then
		return tagIcons
	end
	local icons = {}
	local kill = ReplicatedStorage.Assets.UI.KillFeed:FindFirstChild("Kill")
	local contents = kill and kill:FindFirstChild("Contents")
	if contents then
		for _, name in next, TAG_ICON_NAMES do
			local image = contents:FindFirstChild(name)
			if image and image:IsA("ImageLabel") then
				icons[name] = image.Image
			end
		end
	end
	tagIcons = icons
	return icons
end

local function getPipIcon(): string
	if pipIcon then
		return pipIcon
	end
	local icon = ""
	local team = ReplicatedStorage.Assets.UI.Team
	local skull = team.TCard:FindFirstChild("Skull1", true)
		or team.CTCard:FindFirstChild("Skull1", true)
	if skull then
		icon = (skull :: any).Image
	end
	if icon == "" then
		icon = getTagIcons().Headshot or ""
	end
	if icon ~= "" then
		pipIcon = icon
	end
	return icon
end

local function describePlayer(userId: any): (string?, boolean, boolean)
	local id = tonumber(userId)
	local player = id and Players:GetPlayerByUserId(id)
	if not player then
		return nil, false, false
	end
	return player.DisplayName, player:GetAttribute("Team") ~= clientApi.GetTeam(), player == LocalPlayer
end

local GameHud = {}
GameHud.__index = GameHud

setmetatable(GameHud, { __index = BaseFeature })

function GameHud.new(link: gameUi.Linker): GameHud
	local self = BaseFeature.new() :: any
	setmetatable(self, GameHud)

	link:Toggle("customHud", "Custom HUD", false):SetTip({
		title = "Custom HUD",
		body = "Replaces the game's health, armor, ammo and inventory HUD with a Limerence-styled one.",
	})
	local hudLink = link:OnKey("customHud")
	hudLink:Submenu("opts", "Custom HUD Options")
	local opts = hudLink:OnKey("opts")

	for _, menu in next, COLOR_MENUS do
		opts:Submenu(menu.key, menu.label)
		local menuLink = opts:OnKey(menu.key)
		for _, config in next, menu.pickers do
			menuLink:Colorpicker(config.key, config.label, config.color, config.transparency):SetTip({
				title = config.label,
				body = "Used by the custom HUD.",
			})
			local picker = menuLink:Get(config.key)
			local atom = (gameHudState.colors :: any)[config.key]
			atom(picker:GetSnapshot())
			self:Track(picker:OnUpdate(function(snapshot: any): ()
				atom({ color = snapshot.color, transparency = snapshot.transparency })
			end))
		end
	end

	self._rootLink = link
	self._enabledLink = link:Get("customHud")
	self._killFeedStateConn = nil :: RBXScriptConnection?
	self._janitor = nil :: Janitor.Janitor?
	self._slotsSignature = nil :: string?
	self._equippedDef = nil :: any
	self._meleeStart = nil :: number?
	self._meleeHeavy = false
	self._killFeedUnsub = nil :: (() -> ())?

	local hudGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Enabled = true,
		DisplayOrder = HUD_DISPLAY_ORDER,
	}, cloneref(gethui()))
	self._hudGui = hudGui

	self._hudRoot = ReactRoblox.createRoot(hudGui)

	local function GameHudRoot(): React.Element<any>
		local scale = ReactCharm.useAtom(dpiState.scale)
		return e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1 / scale, 1 / scale),
		}, {
			UIScale = e("UIScale", { Scale = scale }),
			Hud = e(gameHudRenderer),
		})
	end

	self._hudRoot:render(e(GameHudRoot))

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if self._enabledLink:Peek() then
		self:Enable()
	end

	return self
end

function GameHud._syncWeapon(self: GameHud): ()
	local entry = peek(loadoutState.currentEquipped)
	if not entry or type(entry.Name) ~= "string" or entry.Name == "" then
		self._equippedDef = nil
		gameHudState.weaponName("")
		gameHudState.weaponIcon("")
		gameHudState.isGun(false)
		gameHudState.magSize(0)
		gameHudState.rounds(0)
		gameHudState.capacity(0)
		return
	end

	local def = resolveWeaponDef(entry.Name)
	self._equippedDef = def
	gameHudState.weaponName(displayName(entry.Name))
	gameHudState.weaponIcon(def and def.Icon or "")
	gameHudState.isGun(def ~= nil and def.Class == "Weapon" and def.MuzzleType ~= "Zeus x27")
	gameHudState.magSize(def and tonumber(def.Rounds) or 0)
	gameHudState.rounds(type(entry.Rounds) == "number" and math.max(entry.Rounds, 0) or 0)
	gameHudState.capacity(type(entry.Capacity) == "number" and math.max(entry.Capacity, 0) or 0)
end

function GameHud._syncSlots(self: GameHud): ()
	local inventory = peek(loadoutState.inventory)
	local current = peek(loadoutState.currentEquipped)
	local currentId = current ~= nil and rawget(current :: any, "Identifier") or nil

	local slots = {}
	local function addItem(item: any): ()
		local name = rawget(item, "Name")
		if type(name) ~= "string" or name == "" then
			return
		end
		local def = resolveWeaponDef(name)
		local key = def and SLOT_ORDER[def.Slot] or 5
		local identifier = rawget(item, "Identifier")
		table.insert(slots, {
			key = key,
			name = displayName(name),
			icon = def and def.Icon or "",
			active = item == current or (currentId ~= nil and identifier == currentId),
		})
	end

	if type(inventory) == "table" then
		for _, container in next, inventory do
			if type(container) ~= "table" then
				continue
			end
			local items = rawget(container, "_items")
			if type(items) == "table" then
				for _, item in next, items do
					if type(item) == "table" then
						addItem(item)
					end
				end
			else
				addItem(container)
			end
		end
	end

	table.sort(slots, function(a, b)
		if a.key ~= b.key then
			return a.key < b.key
		end
		return a.name < b.name
	end)

	local signature = table.create(#slots)
	for index, slot in next, slots do
		signature[index] = slot.active and slot.name .. "*" or slot.name
	end
	local joined = table.concat(signature, "|")
	if joined == self._slotsSignature then
		return
	end
	self._slotsSignature = joined

	gameHudState.slots(slots)
end

function GameHud._computeAction(self: GameHud, entry: any): (string, number)
	local animations = getAnimations(entry)
	if entry.IsReloading == true then
		local props = entry.Properties
		if props and (tonumber(props.ReloadAnimationCount) or 1) > 1 then
			return "RELOADING", -1
		end
		local start = entry.ReloadStartTick
		local track = getTrack(animations, "Reload")
		local duration = track and track.Length or 0
		if type(start) ~= "number" or type(duration) ~= "number" or duration <= 0 then
			return "RELOADING", -1
		end
		return "RELOADING", math.clamp((tick() - start) / duration, 0, 1)
	end

	local def = self._equippedDef
	if def and def.Slot == "Melee" and entry.IsShooting == true then
		if not self._meleeStart then
			self._meleeStart = tick()
			local heavyTrack = getTrack(animations, "Heavy Swing")
			self._meleeHeavy = heavyTrack ~= nil and heavyTrack.IsPlaying == true
		end
		local props = entry.Properties
		local duration = props and tonumber(props.FireRate) or 0
		if self._meleeHeavy then
			duration *= 2.05
		end
		if duration <= 0 then
			return "ATTACKING", -1
		end
		return "ATTACKING", math.clamp((tick() - self._meleeStart) / duration, 0, 1)
	end
	self._meleeStart = nil
	self._meleeHeavy = false

	if def and def.Slot == "Grenade" then
		local startThrow = getTrack(animations, "StartThrow")
		if startThrow and startThrow.IsPlaying then
			local length = startThrow.Length
			if type(length) == "number" and length > 0 then
				return "THROWING", math.clamp(startThrow.TimePosition / length, 0, 1)
			end
			return "THROWING", -1
		end
		local throwIdle = getTrack(animations, "ThrowIdle")
		if throwIdle and throwIdle.IsPlaying then
			return "THROWING", 1
		end
		if entry.ThrowStarted == true and entry.ThrowFinished ~= true then
			return "THROWING", -1
		end
	end

	return "", 0
end

function GameHud._setKillFeed(self: GameHud, on: boolean): ()
	if on then
		if self._killFeedUnsub then
			return
		end
		local packet = NetworkController.GetPacket("UI", "UIPlayerKilled")
		local listen = packet and rawget(packet, "Listen")
		if type(listen) == "function" then
			setthreadidentity(2)
			local unsub = listen(function(data: any): ()
				task.spawn(function(): ()
					setthreadidentity(8)
					self:_onKill(data)
				end)
			end)
			setthreadidentity(8)
			if type(unsub) == "function" then
				self._killFeedUnsub = unsub
			end
		end
		if not self._killFeedStateConn then
			self._killFeedStateConn = workspace:GetAttributeChangedSignal("GameState"):Connect(function(): ()
				local state = workspace:GetAttribute("GameState")
				if state == "Buy Period" or state == "Warmup" then
					gameHudState.kills({})
					gameHudState.roundKills(0)
				end
			end)
		end
		nativeHud.setKillFeedHidden(true)
		gameHudState.killFeedEnabled(true)
	else
		if self._killFeedUnsub then
			self._killFeedUnsub()
			self._killFeedUnsub = nil
		end
		if self._killFeedStateConn then
			self._killFeedStateConn:Disconnect()
			self._killFeedStateConn = nil
		end
		gameHudState.killFeedEnabled(false)
		gameHudState.kills({})
		nativeHud.setKillFeedHidden(false)
	end
end

function GameHud._onKill(self: GameHud, data: any): ()
	if type(data) ~= "table" then
		return
	end

	local killerName, killerEnemy, killerLocal = describePlayer(data.Killer)
	local victimName, victimEnemy, victimLocal = describePlayer(data.Victim)
	if not killerName or not victimName then
		return
	end

	local assistName, assistEnemy, assistLocal = nil, false, false
	if data.Assistor then
		assistName, assistEnemy, assistLocal = describePlayer(data.Assistor)
	end

	local icons = getTagIcons()
	local tags = {}
	local function addTag(name: string): ()
		local icon = icons[name]
		if icon and icon ~= "" then
			table.insert(tags, { icon = icon })
		end
	end

	if data.Blind == true then
		addTag("Blind")
	end
	if assistName and data.FlashAssist == true then
		addTag("FlashAssist")
	end
	if data.Jump == true then
		addTag("Jump")
	end
	if type(data.Weapon) == "string" and data.Weapon ~= "" then
		local def = resolveWeaponDef(data.Weapon)
		local weaponIcon = def and (def.ReverseIcon or def.Icon) or ""
		if weaponIcon ~= "" then
			table.insert(tags, { icon = weaponIcon, wide = true })
		end
	end
	if data.NoScope == true then
		addTag("NoScope")
	end
	if data.Smoke == true then
		addTag("Smoke")
	end
	if data.Wallbang == true then
		addTag("Wallbang")
	end
	if data.Headshot == true then
		addTag("Headshot")
	end

	killId += 1
	local id = killId
	local entry: gameHudState.KillEntry = {
		id = id,
		killerName = killerName,
		killerEnemy = killerEnemy,
		killerLocal = killerLocal,
		assistName = assistName,
		assistEnemy = assistEnemy == true,
		assistLocal = assistLocal == true,
		victimName = victimName,
		victimEnemy = victimEnemy,
		victimLocal = victimLocal,
		tags = tags,
		dead = false,
	}

	local kills = table.clone(peek(gameHudState.kills))
	table.insert(kills, 1, entry)
	while #kills > KILL_FEED_LIMIT do
		table.remove(kills)
	end
	gameHudState.kills(kills)

	if killerLocal then
		gameHudState.roundKills(peek(gameHudState.roundKills) + 1)
	end

	if (killerLocal or assistLocal == true) and self._rootLink:Peek("persistentKillFeed") == true then
		return
	end

	task.delay(KILL_LIFETIME, function(): ()
		local list = table.clone(peek(gameHudState.kills))
		for index, item in next, list do
			if item.id == id then
				local copy = table.clone(item)
				copy.dead = true
				list[index] = copy
				gameHudState.kills(list)
				break
			end
		end
	end)
	task.delay(KILL_LIFETIME + KILL_FADE, function(): ()
		local list = peek(gameHudState.kills)
		local result = {}
		for _, item in next, list do
			if item.id ~= id then
				table.insert(result, item)
			end
		end
		if #result ~= #list then
			gameHudState.kills(result)
		end
	end)
end

function GameHud.Enable(self: GameHud): ()
	if self._janitor then
		return
	end
	local janitor = Janitor.new()
	self._janitor = janitor

	gameHudState.enabled(true)
	nativeHud.hide()
	self:_setKillFeed(true)

	janitor:Add(sub(clientApi.state.alive, function(alive: boolean): ()
		if not alive then
			gameHudState.roundKills(0)
		end
	end))
	janitor:Add(LocalPlayer.CharacterRemoving:Connect(function(): ()
		gameHudState.roundKills(0)
	end))
	gameHudState.pipIcon(getPipIcon())

	local function syncMoney(): ()
		gameHudState.money(tonumber(LocalPlayer:GetAttribute("Money")) or 0)
	end
	syncMoney()
	janitor:Add(LocalPlayer:GetAttributeChangedSignal("Money"):Connect(syncMoney))

	janitor:Add(sub(clientApi.state.isSpectating, function(spectating: boolean): ()
		if spectating then
			nativeHud.show()
			nativeHud.setKillFeedHidden(false)
		else
			nativeHud.hide()
			nativeHud.setKillFeedHidden(self._killFeedUnsub ~= nil)
		end
	end))

	self:_syncWeapon()
	self:_syncSlots()
	janitor:Add(sub(loadoutState.currentEquipped, function(): ()
		self:_syncWeapon()
		self:_syncSlots()
	end))
	janitor:Add(sub(loadoutState.inventory, function(): ()
		self:_syncSlots()
	end))

	local nextSlotSync = 0
	janitor:Add(RunService.PreRender:Connect(LPH_NO_VIRTUALIZE(function(): ()
		gameHudState.health(clientApi.GetHealth())
		gameHudState.maxHealth(clientApi.GetMaxHealth())

		local entry = peek(loadoutState.currentEquipped)
		if entry then
			gameHudState.rounds(type(entry.Rounds) == "number" and math.max(entry.Rounds, 0) or 0)
			gameHudState.capacity(type(entry.Capacity) == "number" and math.max(entry.Capacity, 0) or 0)
			local label, progress = self:_computeAction(entry)
			gameHudState.actionLabel(label)
			gameHudState.actionProgress(progress)
		else
			gameHudState.actionLabel("")
			gameHudState.actionProgress(0)
		end

		local now = os.clock()
		if now >= nextSlotSync then
			nextSlotSync = now + 0.5
			self:_syncSlots()
		end
	end)))
end

function GameHud.Disable(self: GameHud): ()
	if not self._janitor then
		return
	end
	self._janitor:Destroy()
	self._janitor = nil
	self._slotsSignature = nil
	self._meleeStart = nil
	self._meleeHeavy = false

	self:_setKillFeed(false)
	gameHudState.actionLabel("")
	gameHudState.actionProgress(0)
	gameHudState.roundKills(0)
	gameHudState.enabled(false)
	nativeHud.restore()
end

function GameHud.Destroy(self: GameHud): ()
	self:Disable()
	if self._hudRoot then
		self._hudRoot:unmount()
	end
	if self._hudGui then
		self._hudGui:Destroy()
	end
	BaseFeature.Destroy(self)
end

export type GameHud =
	typeof(setmetatable(
		{} :: {
			_rootLink: any,
			_enabledLink: any,
			_killFeedStateConn: RBXScriptConnection?,
			_janitor: Janitor.Janitor?,
			_slotsSignature: string?,
			_equippedDef: any,
			_meleeStart: number?,
			_meleeHeavy: boolean,
			_killFeedUnsub: (() -> ())?,
			_hudGui: Instance,
			_hudRoot: ReactRoblox.RootType,
		},
		GameHud
	))
	& BaseFeature.BaseFeature

return GameHud
