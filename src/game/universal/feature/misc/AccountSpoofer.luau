local Players = cloneref(game:GetService("Players")) :: Players

local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local spoofEngine = require("@game/universal/feature/misc/spoofEngine")

local LocalPlayer = Players.LocalPlayer

local REAL_NAME = LocalPlayer.Name
local REAL_DISPLAY_NAME = LocalPlayer.DisplayName
local REAL_USER_ID = tostring(LocalPlayer.UserId)

local AccountSpoofer = {}
AccountSpoofer.__index = AccountSpoofer

setmetatable(AccountSpoofer, { __index = BaseFeature })

local function cleanInput(value: any): string
	if type(value) ~= "string" then
		return ""
	end
	return string.match(value, "^%s*(.-)%s*$") or ""
end

local normalizeUserId = LPH_NO_VIRTUALIZE(function(value: string): string
	local id = tonumber(value)
	if not id or id <= 0 then
		return ""
	end
	return tostring(math.floor(id))
end)

function AccountSpoofer.new(link: gameUi.Linker): AccountSpoofer
	local self = BaseFeature.new() :: any
	setmetatable(self, AccountSpoofer)

	link:Toggle("accountSpoofer", "Account Spoofer", false):SetTip({
		title = "Account Spoofer",
		body = "Replaces your username, display name, and id everywhere the game shows them.",
	})
	local accountSpooferLink = link:OnKey("accountSpoofer")
	accountSpooferLink:Submenu("opts", "Account Spoofer")
	local optionsLink = accountSpooferLink:OnKey("opts")
	optionsLink:Textbox("displayName", "Display Name", "limerence.biz", "Display name"):SetTip({
		title = "Display Name",
		body = "The display name that will replace your actual display name.",
	})
	optionsLink:Textbox("username", "Username", "limerence.biz", "Username"):SetTip({
		title = "Username",
		body = "The username that will replace your actual username.",
	})
	optionsLink:Textbox("id", "User Id", "676767", "User id", true):SetTip({
		title = "User ID",
		body = "The user ID that will replace your actual user ID.",
	})

	self._username = "limerence.biz"
	self._id = "676767"
	self._displayName = "limerence.biz"
	self._appliedUsername = ""
	self._appliedId = ""
	self._appliedDisplayName = ""
	self._binder = spoofEngine.new()
	self._applyQueued = false

	self:Track(link:Get("accountSpoofer"):OnChange(function(value: boolean)
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(link:Watch("accountSpoofer.opts.displayName", function(value: string)
		self._displayName = value
		self:_queueApply()
	end))

	self:Track(link:Watch("accountSpoofer.opts.username", function(value: string)
		self._username = value
		self:_queueApply()
	end))

	self:Track(link:Watch("accountSpoofer.opts.id", function(value: string)
		self._id = value
		self:_queueApply()
	end))

	return self
end

function AccountSpoofer._buildReplacements(self: AccountSpoofer, restoreReal: boolean?): ()
	local targetDisplayName = (restoreReal or self._displayName == "") and REAL_DISPLAY_NAME or self._displayName
	local targetUsername = (restoreReal or self._username == "") and REAL_NAME or self._username
	local targetId = (restoreReal or self._id == "") and REAL_USER_ID or self._id

	local replacements = spoofEngine.newSet()

	spoofEngine.addTextReplacement(replacements, REAL_DISPLAY_NAME, targetDisplayName)
	spoofEngine.addTextReplacement(replacements, self._appliedDisplayName, targetDisplayName)
	spoofEngine.addTextReplacement(replacements, self._displayName, targetDisplayName)

	spoofEngine.addTextReplacement(replacements, REAL_NAME, targetUsername)
	spoofEngine.addTextReplacement(replacements, "@" .. REAL_NAME, "@" .. targetUsername)
	spoofEngine.addTextReplacement(replacements, self._appliedUsername, targetUsername)
	spoofEngine.addTextReplacement(replacements, self._username, targetUsername)
	if self._appliedUsername ~= "" then
		spoofEngine.addTextReplacement(replacements, "@" .. self._appliedUsername, "@" .. targetUsername)
	end
	if self._username ~= "" then
		spoofEngine.addTextReplacement(replacements, "@" .. self._username, "@" .. targetUsername)
	end

	spoofEngine.addIdReplacement(replacements, REAL_USER_ID, targetId)
	spoofEngine.addIdReplacement(replacements, self._appliedId, targetId)
	spoofEngine.addIdReplacement(replacements, self._id, targetId)

	spoofEngine.addFragment(replacements.imageIds, REAL_USER_ID, targetId)
	spoofEngine.addFragment(replacements.imageIds, self._appliedId, targetId)
	spoofEngine.addFragment(replacements.imageIds, self._id, targetId)

	spoofEngine.sortFragments(replacements.textFragments)
	spoofEngine.sortFragments(replacements.idFragments)
	spoofEngine.sortFragments(replacements.imageIds)
	self._binder:SetReplacements(replacements)
end

function AccountSpoofer._queueApply(self: AccountSpoofer): ()
	if not self._enabled or self._applyQueued then
		return
	end

	self._applyQueued = true
	task.defer(function(): ()
		self._applyQueued = false
		if self._enabled then
			self:_apply()
		end
	end)
end

function AccountSpoofer._apply(self: AccountSpoofer): ()
	if not self._enabled then
		return
	end

	self._displayName = cleanInput(self._displayName)
	self._username = cleanInput(self._username)
	self._id = normalizeUserId(cleanInput(self._id))

	self:_buildReplacements()

	self._appliedDisplayName = self._displayName
	self._appliedUsername = self._username
	self._appliedId = self._id
end

function AccountSpoofer.Enable(self: AccountSpoofer): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self._binder:Start()
	self:_apply()
end

function AccountSpoofer.Disable(self: AccountSpoofer): ()
	if not self._enabled then
		return
	end
	self:_buildReplacements(true)
	self._binder:Patch()
	self._binder:Stop()
	self._enabled = false
	self._applyQueued = false
	self._appliedDisplayName = ""
	self._appliedUsername = ""
	self._appliedId = ""
end

function AccountSpoofer.Destroy(self: AccountSpoofer): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type AccountSpoofer =
	typeof(setmetatable(
		{} :: {
			_username: string,
			_id: string,
			_displayName: string,
			_appliedUsername: string,
			_appliedId: string,
			_appliedDisplayName: string,
			_binder: spoofEngine.Binder,
			_applyQueued: boolean,
			_enabled: boolean,
			_apply: (AccountSpoofer) -> (),
			_queueApply: (AccountSpoofer) -> (),
			_buildReplacements: (AccountSpoofer, boolean?) -> (),
		},
		AccountSpoofer
	))
	& BaseFeature.BaseFeature

return AccountSpoofer
