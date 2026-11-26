local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")

local RunService = cloneref(game:GetService("RunService")) :: RunService

local ATTEMPT_INTERVAL = 0.3

local InstantReload = {}
InstantReload.__index = InstantReload

setmetatable(InstantReload, { __index = BaseFeature })

local tryAutoReload = LPH_NO_VIRTUALIZE(function(self: InstantReload, character: any, now: number): ()
	local weapon = character.EquippedItem
	if not weapon or weapon.Type ~= "Firearm" or weapon.Reloading or type(weapon.OnReload) ~= "function" then
		return
	end

	local fireConfig = weapon.FireConfig
	if not fireConfig then
		return
	end

	local magAmmo = 0
	local attachments = weapon.Attachments
	local loadedMag = attachments and attachments.Ammo
	if loadedMag and loadedMag.WorkingAmount then
		magAmmo = loadedMag.WorkingAmount
	elseif fireConfig.InternalMag and weapon.WorkingAmount then
		magAmmo = weapon.WorkingAmount
	end
	if magAmmo > 0 then
		return
	end

	self._nextTry = now + ATTEMPT_INTERVAL

	local inventory = character.Inventory
	if not inventory then
		return
	end

	local internalMag = fireConfig.InternalMag
	local caliber = weapon.Caliber
	local magazineTypes = weapon.MagazineTypes
	local hasReserve = false

	for _, container in next, inventory.Containers do
		if not container.IsCarried then
			continue
		end
		for _, item in next, container.Occupants do
			if item.Caliber ~= caliber or item.Amount <= 0 then
				continue
			end
			if internalMag then
				if item.Type == "Ammo" and item.SubType ~= "Magazine" then
					hasReserve = true
					break
				end
			elseif item.SubType == "Magazine" and magazineTypes and table.find(magazineTypes, item.Name) then
				hasReserve = true
				break
			end
		end
		if hasReserve then
			break
		end
	end

	if not hasReserve then
		return
	end

	setthreadidentity(2)
	character:RunInputActionIf("UseItem", character.UseItemInput, false)
	character:RunInputActionIf("Aim", character.AimingInput, false)
	character:RunInputActionIf("Binoculars", character.BinocularsEnabled ~= "", false)
	local started = weapon:OnReload(character)
	character.LastReloadTry = now
	setthreadidentity(8)

	if not started then
		self._nextTry = now + 1
	end
end)

local advance = LPH_NO_VIRTUALIZE(function(self: InstantReload, arLocalPlayer: any): ()
	local character = arLocalPlayer.Character
	if not character then
		self._handled = nil
		return
	end

	if self._autoReload then
		local now = os.clock()
		if now >= self._nextTry then
			tryAutoReload(self, character, now)
		end
	end

	local animator = character.Animator
	if not animator or type(animator.IsReloadPlaying) ~= "function" then
		return
	end
	if not animator:IsReloadPlaying() then
		self._handled = nil
		return
	end

	local callback = animator.ReloadCallback
	if self._handled == callback then
		return
	end
	self._handled = callback

	setthreadidentity(2)
	if type(callback) == "function" then
		callback("Commit", "Load")
	end
	animator:RunAction("Stop Firearm Reload", false, "Natural")
	setthreadidentity(8)
end)

function InstantReload.new(link: gameUi.Linker): InstantReload
	local self = BaseFeature.new() :: any
	setmetatable(self, InstantReload)

	self._enabled = false
	self._conn = nil :: RBXScriptConnection?
	self._handled = nil :: any
	self._autoReload = false
	self._nextTry = 0

	local toggle = link:Toggle("instantReload", "Instant Reload", false):SetTip({
		title = "Instant Reload",
		body = "Reloads finish instantly with no animation.",
	})
	link:Extra(toggle, "instantReloadOptions", "Submenu", "Instant Reload Options")
	local optionsLink = link:OnKey("instantReloadOptions")
	optionsLink:Toggle("autoReload", "Auto Reload", false):SetTip({
		title = "Auto Reload",
		body = "Automatically reloads your weapon when the magazine runs empty.",
	})

	self:Track(link:Get("instantReload"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	self:Track(optionsLink:Get("autoReload"):OnChange(function(value: boolean): ()
		self._autoReload = value == true
		self._nextTry = 0
	end))
	self._autoReload = optionsLink:Peek("autoReload") == true

	if link:Peek("instantReload") then
		self:Enable()
	end

	return self
end

function InstantReload.Enable(self: InstantReload): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local playersModule = ModuleController.GetModule("LocalPlayer")
	if not playersModule then
		return
	end

	local arLocalPlayer = playersModule.module.get()

	self._handled = nil
	self._nextTry = 0
	self._conn = RunService.Heartbeat:Connect(function(): ()
		advance(self, arLocalPlayer)
	end)
end

function InstantReload.Disable(self: InstantReload): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
end

function InstantReload.Destroy(self: InstantReload): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type InstantReload = typeof(setmetatable(
	{} :: {
		_enabled: boolean,
		_conn: RBXScriptConnection?,
		_handled: any,
		_autoReload: boolean,
		_nextTry: number,
	},
	InstantReload
)) & BaseFeature.BaseFeature

return InstantReload
