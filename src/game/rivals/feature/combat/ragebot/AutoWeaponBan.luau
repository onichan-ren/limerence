local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local ModuleController = require("@game/rivals/module/ModuleController")
local duelVote = require("@game/rivals/feature/combat/ragebot/duelVote")

local AUTO = "Auto"
local RANDOM = "Random"
local BAN_SLOTS: { string } = { "ban1", "ban2" }

local function allWeapons(): { string }
	local out: { string } = {}
	local itemLibrary = ModuleController.GetModule("ItemLibrary")
	local items = itemLibrary and rawget(itemLibrary, "Items")
	if items then
		for name, info in next, items do
			if type(info) == "table" and info.Class ~= nil and name ~= "MISSING_WEAPON" then
				out[#out + 1] = name
			end
		end
	end
	table.sort(out)
	table.insert(out, 1, RANDOM)
	table.insert(out, 1, AUTO)
	return out
end

local AutoWeaponBan = {}
AutoWeaponBan.__index = AutoWeaponBan

setmetatable(AutoWeaponBan, { __index = BaseFeature })

function AutoWeaponBan.new(link: gameUi.Linker): AutoWeaponBan
	local self = BaseFeature.new() :: any
	setmetatable(self, AutoWeaponBan)

	link:Toggle("autoWeaponBan", "Auto Weapon Ban", false):SetTip({
		title = "Auto Weapon Ban",
		body = "Bans your chosen weapons during the round's weapon ban phase, in order.",
	})

	local banLink = link:OnKey("autoWeaponBan")
	banLink:Submenu("opts", "Bans")
	local optsLink = banLink:OnKey("opts")

	local weapons = allWeapons()
	self._bans = {} :: { [string]: string }
	for i, key in next, BAN_SLOTS do
		optsLink:Dropdown(key, "Ban " .. i, weapons, AUTO)
		self._bans[key] = optsLink:Peek(key) or AUTO
		self:Track(optsLink:Get(key):OnChange(function(v: string): ()
			self._bans[key] = v or AUTO
		end))
	end

	self._link = link
	self._enabledLink = link:Get("autoWeaponBan")
	self._janitor = Janitor.new()
	self._lastOptions = nil
	self._voted = {}
	self._banned = {}

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("autoWeaponBan") then
		self:Enable()
	end

	return self
end

function AutoWeaponBan._onPhase(self: AutoWeaponBan, duel: any): ()
	if duel:Get("VoteOptionsType") ~= "Weapons" then
		return
	end
	if not duelVote.isBanPhase(duel, "Weapons") then
		return
	end
	local options = duel:Get("VoteOptions")
	if type(options) ~= "table" then
		return
	end

	if options ~= self._lastOptions then
		self._lastOptions = options
		self._voted = {}
		self._banned = {}
	end

	for _, key in next, BAN_SLOTS do
		if self._voted[key] then
			continue
		end
		local pick = self._bans[key]

		local choice: string? = nil
		if pick == AUTO or pick == RANDOM then
			local pool: { string } = {}
			for _, option in next, options do
				local name = option.Name
				if name and not self._banned[name] then
					pool[#pool + 1] = name
				end
			end
			if #pool > 0 then
				choice = pick == RANDOM and pool[math.random(1, #pool)] or pool[1]
			end
		elseif not self._banned[pick] then
			for _, option in next, options do
				if option.Name == pick then
					choice = pick
					break
				end
			end
		end

		if choice then
			self._voted[key] = true
			self._banned[choice] = true
			duelVote.send(choice)
		end
	end
end

function AutoWeaponBan.Enable(self: AutoWeaponBan): ()
	if self._enabled then
		return
	end
	self._enabled = true
	duelVote.bind(self._janitor, function(duel: any): ()
		self:_onPhase(duel)
	end)
end

function AutoWeaponBan.Disable(self: AutoWeaponBan): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._lastOptions = nil
	self._voted = {}
	self._banned = {}
	self._janitor:Cleanup()
end

function AutoWeaponBan.Destroy(self: AutoWeaponBan): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AutoWeaponBan = typeof(setmetatable(
	{} :: {
		_link: gameUi.Linker,
		_enabledLink: any,
		_enabled: boolean,
		_bans: { [string]: string },
		_lastOptions: any,
		_voted: { [string]: boolean },
		_banned: { [string]: boolean },
		_janitor: Janitor.Janitor,
	},
	AutoWeaponBan
)) & BaseFeature.BaseFeature

return AutoWeaponBan
