local Players = cloneref(game:GetService("Players")) :: Players
local FakeCharacter = require("@game/pf/thirdperson/FakeCharacter")
local ModuleController = require("@game/pf/module/ModuleController")

local LocalPlayer = Players.LocalPlayer

local PREVIEW_POSITION = Vector3.new(0, 10000, 0)
local OFFSET = CFrame.new(PREVIEW_POSITION)

local STANCE_MAP: { [string]: string } = {
	Standing = "stand",
	Crouch = "crouch",
	Prone = "prone",
}

local PART_NAMES = { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local WEAPON_SLOTS = { "Primary", "Secondary", "Melee" }
local SLOT_FOR_LABEL: { [string]: string } = {
	Primary = "Primary",
	Secondary = "Secondary",
	Melee = "Knife",
}

local function resolveLoadoutWeapon(label: string?): string?
	if not label then
		return nil
	end
	local slot = SLOT_FOR_LABEL[label]
	if not slot then
		return label
	end
	local utils = ModuleController.GetModule("ActiveLoadoutUtils")
	local playerData = ModuleController.GetModule("PlayerDataClientInterface")
	if not utils or not playerData then
		return label
	end
	setthreadidentity(8)
	local loadout = utils.getActiveLoadoutData(playerData.getPlayerData())
	if type(loadout) ~= "table" then
		return label
	end
	local data = loadout[slot]
	return (data and data.Name) or label
end

local TEAM_OPTIONS = { "Phantoms", "Ghosts" }
local DEFAULT_TEAM = "Phantoms"
local TEAM_COLORS: { [string]: BrickColor } = {
	Phantoms = BrickColor.new("Bright blue"),
	Ghosts = BrickColor.new("Bright orange"),
}

local FALLBACK_WEAPONS = { "AK12", "M4A1", "M9", "Knife" }

local current: any = nil
local building = false

local function teardown(): ()
	if current then
		setthreadidentity(8)
		if current.clone then
			current.clone:Destroy()
		end
		if current.fake then
			current.fake:destroy()
		end
	end
	current = nil
	task.wait()
end

local function teamColorFor(teamName: string?): BrickColor
	return TEAM_COLORS[teamName or DEFAULT_TEAM] or TEAM_COLORS[DEFAULT_TEAM]
end

local function buildClone(): Model?
	setthreadidentity(8)
	local fake = current.fake
	if not fake then
		return nil
	end

	task.wait()

	if not current or current.fake ~= fake then
		return nil
	end

	local tpo = fake:getThirdPersonObject()
	local live = tpo and tpo:getCharacterModel()
	if typeof(live) ~= "Instance" then
		return nil
	end

	local partSizes = rawget(tpo, "_partSizes") or {}
	local hash = tpo:getCharacterHash()

	live.Archivable = true
	local liveDesc = live:QueryDescendants("Instance")
	for i = 1, #liveDesc do
		liveDesc[i].Archivable = true
	end
	local clone = live:Clone()
	local cloneDesc = clone:QueryDescendants("Instance")

	local map = {}
	local liveToClone = {}
	for i = 1, #liveDesc do
		local l = liveDesc[i]
		local c = cloneDesc[i]
		if l:IsA("BasePart") and c and c:IsA("BasePart") then
			c.Anchored = true
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.Massless = true
			c.Size = partSizes[l] or l.Size
			c.CFrame = OFFSET * l.CFrame
			map[#map + 1] = { live = l, clone = c }
			liveToClone[l] = c
		end
	end

	for _, d in next, cloneDesc do
		if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end

	local parts: { [string]: BasePart } = {}
	for _, name in next, PART_NAMES do
		local lp = hash[name]
		local cp = lp and liveToClone[lp]
		if cp then
			parts[name] = cp
		end
	end

	local oldClone = current.clone
	current.clone = clone
	current.map = map
	current.parts = parts
	current.cloneTorso = parts.Torso
	current.weaponModel = fake:getWeaponModel()
	if oldClone then
		oldClone:Destroy()
	end
	setthreadidentity(8)

	return clone :: Model
end

local function build(teamName: string?, weaponName: string?): Model?
	setthreadidentity(8)
	local prev = current

	local fake = FakeCharacter.new({ teamColor = teamColorFor(teamName) })
	fake:update(Vector3.zero, Vector3.zero, { queryable = false, weaponName = weaponName, stance = "stand" })

	current = { fake = fake, team = teamName or DEFAULT_TEAM }
	local clone = buildClone()
	setthreadidentity(8)
	if not clone then
		fake:destroy()
		current = prev
		return prev and prev.clone
	end
	if prev then
		if prev.clone then
			prev.clone:Destroy()
		end
		if prev.fake then
			prev.fake:destroy()
		end
	end
	return clone
end

local function modelProvider(): Model?
	building = true
	local clone = build(DEFAULT_TEAM, resolveLoadoutWeapon(WEAPON_SLOTS[1]))
	building = false
	return clone
end

local function resolveHrp(_model: Model): BasePart?
	local torso = current and current.cloneTorso
	if typeof(torso) == "Instance" and torso:IsA("BasePart") then
		return torso
	end
	return nil
end

local function resolveParts(_model: Model): { [string]: BasePart }
	return (current and current.parts) or {}
end

local function mirror(): ()
	local map = current.map
	if not map then
		return
	end
	for i = 1, #map do
		local e = map[i]
		e.live.LocalTransparencyModifier = 1
		e.clone.CFrame = OFFSET * e.live.CFrame
	end
end

local function onFrame(_model: Model, _dt: number, states: { [string]: any }): Model?
	setthreadidentity(8)
	if not current or not current.fake then
		return nil
	end
	if building then
		return current.clone
	end

	local teamName = states.team or DEFAULT_TEAM
	local weaponName = resolveLoadoutWeapon(states.weapon)
	if teamName ~= current.team then
		building = true
		local clone = build(teamName, weaponName)
		building = false
		return clone
	end

	building = true
	current.fake:update(Vector3.zero, Vector3.zero, {
		stance = (states.state and STANCE_MAP[states.state]) or "stand",
		aim = states.aiming == true,
		sprint = false,
		weaponName = weaponName,
	})
	building = false

	if not current or not current.fake then
		return nil
	end

	if current.fake:getWeaponModel() ~= current.weaponModel then
		building = true
		local clone = buildClone()
		building = false
		return clone
	end

	mirror()
	return current.clone
end

local function getWeaponOptions(): { string }
	local ci = ModuleController.GetModule("ContentInterface")
	if not ci or type(ci.getAllWeaponsList) ~= "function" then
		return FALLBACK_WEAPONS
	end
	setthreadidentity(8)
	local list = ci.getAllWeaponsList()
	if type(list) ~= "table" or not next(list) then
		return FALLBACK_WEAPONS
	end
	local names: { string } = {}
	for _, name in next, list do
		if type(name) == "string" then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

local function isEnemyForTeam(teamName: string?): boolean
	return teamColorFor(teamName) ~= LocalPlayer.TeamColor
end

return {
	modelProvider = modelProvider,
	onFrame = onFrame,
	resolveHrp = resolveHrp,
	resolveParts = resolveParts,
	onDestroy = teardown,
	getWeaponOptions = getWeaponOptions,
	isEnemyForTeam = isEnemyForTeam,
	resolveLoadoutWeapon = resolveLoadoutWeapon,
	WEAPON_SLOTS = WEAPON_SLOTS,
	TEAM_OPTIONS = TEAM_OPTIONS,
	DEFAULT_TEAM = DEFAULT_TEAM,
}
