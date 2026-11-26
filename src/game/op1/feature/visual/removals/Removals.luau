local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local hook = require("@share/hook")
local Charm = require("@pkg/Charm")
local ModuleController = require("@game/op1/module/ModuleController")
local clientState = require("@game/op1/client/clientState")

local RunService = cloneref(game:GetService("RunService"))

local peek = Charm.peek

local Removals = {}
Removals.__index = Removals

setmetatable(Removals, { __index = BaseFeature })

export type Removals = typeof(setmetatable({} :: any, Removals))

function Removals.new(link: gameUi.Linker): Removals
	local self = BaseFeature.new() :: any
	setmetatable(self, Removals)

	self._removeBob = false
	self._removeSway = false
	self._smokeEmitters = {}

	link:Options("removals", "Removals")
	local removalsLink = link:OnKey("removals")

	removalsLink:Toggle("stun", "Stun", false):SetTip({
		title = "Stun",
		body = "Removes the flash and ringing when stunned.",
	})
	removalsLink:Toggle("sway", "Sway", false):SetTip({
		title = "Sway",
		body = "Holds the weapon steady, removing sway.",
	})
	removalsLink:Toggle("bob", "Bob", false):SetTip({
		title = "Bob",
		body = "Stops the weapon from bobbing as you move.",
	})
	removalsLink:Toggle("throwPredictor", "Throw Predictor", false):SetTip({
		title = "Throw Predictor",
		body = "Hides the grenade throw trajectory line.",
	})
	removalsLink:Toggle("gunSmoke", "Gun Smoke", false):SetTip({
		title = "Gun Smoke",
		body = "Removes the smoke puff from guns when firing.",
	})
	removalsLink:Toggle("kickback", "Weapon Kickback", false):SetTip({
		title = "Weapon Kickback",
		body = "Stops the weapon from punching back when you fire.",
	})

	self:Track(removalsLink:Get("stun"):OnChange(function(value: boolean): ()
		if value then
			self:EnableStun()
		else
			self:DisableStun()
		end
	end))

	self:Track(removalsLink:Get("gunSmoke"):OnChange(function(value: boolean): ()
		if value then
			self:EnableGunSmoke()
		else
			self:DisableGunSmoke()
		end
	end))

	self:Track(removalsLink:Get("kickback"):OnChange(function(value: boolean): ()
		if value then
			self:EnableKickback()
		else
			self:DisableKickback()
		end
	end))

	self:Track(removalsLink:Get("throwPredictor"):OnChange(function(value: boolean): ()
		if value then
			self:EnableThrowPredictor()
		else
			self:DisableThrowPredictor()
		end
	end))

	local function applyBobSway(): ()
		self:setBobSway(removalsLink:Peek("bob") == true, removalsLink:Peek("sway") == true)
	end

	self:Track(removalsLink:Get("bob"):OnChange(applyBobSway))
	self:Track(removalsLink:Get("sway"):OnChange(applyBobSway))

	if removalsLink:Peek("stun") then
		self:EnableStun()
	end
	if removalsLink:Peek("throwPredictor") then
		self:EnableThrowPredictor()
	end
	if removalsLink:Peek("gunSmoke") then
		self:EnableGunSmoke()
	end
	if removalsLink:Peek("kickback") then
		self:EnableKickback()
	end
	applyBobSway()

	return self
end

function Removals.blockSmoke(self: Removals, shot: Instance?): ()
	if not shot then
		return
	end
	local smoke = shot:FindFirstChild("Smoke")
	if smoke and not self._smokeEmitters[smoke] then
		hook.addInstance(smoke)
		hook.overrideMethod(smoke, "Emit", function(): () end)
		self._smokeEmitters[smoke] = true
	end
end

function Removals.EnableGunSmoke(self: Removals): ()
	if self._setupShotFn then
		return
	end

	local gun = ModuleController.GetModule("Gun")
	local setupShot = gun and gun.setup_shot

	if type(setupShot) == "function" and not hook.isFunctionHooked(setupShot) then
		local old
		old = hook.add(setupShot, function(gunSelf: any, source: any): any
			local shot = old(gunSelf, source)
			self:blockSmoke(shot)
			return shot
		end)
		self._setupShotFn = setupShot
	end

	local charObject = peek(clientState.charObject)
	local equipped = charObject and charObject.values and charObject.values.equipped
	if type(equipped) == "table" and equipped.shot then
		self:blockSmoke(equipped.shot)
	end
end

function Removals.DisableGunSmoke(self: Removals): ()
	if self._setupShotFn then
		hook.restore(self._setupShotFn)
		self._setupShotFn = nil
	end

	for smoke in next, self._smokeEmitters do
		if smoke.Parent then
			hook.restoreMethod(smoke, "Emit")
			hook.restoreInstance(smoke)
		end
	end
	table.clear(self._smokeEmitters)
end

function Removals.EnableKickback(self: Removals): ()
	if self._kickbackFn then
		return
	end

	local gun = ModuleController.GetModule("Gun")
	local kickback = gun and gun.kickback

	if type(kickback) == "function" and not hook.isFunctionHooked(kickback) then
		hook.add(kickback, function(): () end)
		self._kickbackFn = kickback
	end
end

function Removals.DisableKickback(self: Removals): ()
	if self._kickbackFn then
		hook.restore(self._kickbackFn)
		self._kickbackFn = nil
	end
end

function Removals.EnableThrowPredictor(self: Removals): ()
	if self._throwDraw then
		return
	end

	local Trajectory = ModuleController.GetModule("Trajectory")
	local draw = Trajectory and Trajectory.draw

	if type(draw) == "function" and not hook.isFunctionHooked(draw) then
		hook.add(draw, function(): () end)
		self._throwDraw = draw
		Trajectory.clear()
	end
end

function Removals.DisableThrowPredictor(self: Removals): ()
	if self._throwDraw then
		hook.restore(self._throwDraw)
		self._throwDraw = nil
	end
end

function Removals.EnableStun(self: Removals): ()
	if self._stunConn then
		return
	end

	local Effects = ModuleController.GetModule("Effects")
	if Effects then
		if type(Effects.Flash) == "function" and not hook.isFunctionHooked(Effects.Flash) then
			hook.add(Effects.Flash, function(): () end)
			self._flashFn = Effects.Flash
		end
		if type(Effects.Ringing) == "function" and not hook.isFunctionHooked(Effects.Ringing) then
			hook.add(Effects.Ringing, function(): () end)
			self._ringFn = Effects.Ringing
		end
	end

	self._stunConn = RunService.RenderStepped:Connect(LPH_NO_VIRTUALIZE(function(): ()
		local frame = self._flashFrame
		if not frame then
			local UI = ModuleController.GetModule("UI")
			local found = UI and type(UI.get) == "function" and UI.get("Flash")
			frame = found and found.Frame or nil
			self._flashFrame = frame
		end
		if frame then
			frame.BackgroundTransparency = 1
		end

		local charObject = peek(clientState.charObject)
		if charObject and charObject.values and charObject.values.cframes then
			charObject.values.cframes:get("arm2"):remove_absolute("flashed")
		end
	end))
end

function Removals.DisableStun(self: Removals): ()
	if self._flashFn then
		hook.restore(self._flashFn)
		self._flashFn = nil
	end
	if self._ringFn then
		hook.restore(self._ringFn)
		self._ringFn = nil
	end
	if self._stunConn then
		self._stunConn:Disconnect()
		self._stunConn = nil
	end
	self._flashFrame = nil
end

function Removals.currentArms(self: Removals): any
	local charObject = peek(clientState.charObject)
	local cframes = charObject and charObject.values and charObject.values.cframes
	if not cframes then
		return nil
	end
	return cframes:get("arms")
end

function Removals.readdOffset(self: Removals, name: string): ()
	local arms = self:currentArms()
	if not arms then
		return
	end
	setthreadidentity(8)
	arms:set_offset(name)
end

function Removals.setBobSway(self: Removals, bob: boolean, sway: boolean): ()
	if self._removeSway and not sway then
		self:readdOffset("bob")
	end
	if self._removeBob and not bob then
		self:readdOffset("general")
	end

	self._removeBob = bob
	self._removeSway = sway

	if bob or sway then
		self:startBob()
	else
		self:stopBob()
	end
end

function Removals.startBob(self: Removals): ()
	if self._bobConn then
		return
	end
	self._bobConn = RunService.RenderStepped:Connect(LPH_NO_VIRTUALIZE(function(): ()
		local arms = self:currentArms()
		if not arms then
			return
		end
		if self._removeSway then
			arms:remove_offset("bob")
		end
		if self._removeBob then
			arms:remove_offset("general")
		end
	end))
end

function Removals.stopBob(self: Removals): ()
	if self._bobConn then
		self._bobConn:Disconnect()
		self._bobConn = nil
	end
end

function Removals.Destroy(self: Removals): ()
	self:DisableStun()
	self:DisableThrowPredictor()
	self:DisableGunSmoke()
	self:DisableKickback()
	self:setBobSway(false, false)
	BaseFeature.Destroy(self)
end

return Removals
