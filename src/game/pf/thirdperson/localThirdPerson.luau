local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local ModuleController = require("@game/pf/module/ModuleController")
local clientState = require("@game/pf/client/clientState")
local FakeCharacter = require("@game/pf/thirdperson/FakeCharacter")
local hook = require("@share/hook")

local localThirdPerson = {
	_enabled = false,
	_conn = nil :: RBXScriptConnection?,
	_body = nil :: FakeCharacter.FakeCharacter?,
	_lastModel = nil :: Model?,
	_hiddenWeapons = {} :: { [any]: boolean },
	_lookOverride = nil :: ((Vector3) -> Vector3?)?,
	_positionOverride = nil :: Vector3?,
	_angleHold = false,
	_smoothing = 1,
	_cameraCFrame = nil :: CFrame?,
	_screenCullStep = nil :: any,
}

local function clearState(): ()
	localThirdPerson._lastModel = nil
	clientState.thirdPersonModel(nil)
	clientState.parts({})
	clientState.alive(false)
end

local function publishModel(tpo: any, model: Model?): ()
	if model == localThirdPerson._lastModel then
		return
	end
	localThirdPerson._lastModel = model
	clientState.thirdPersonModel(model)
	if model then
		local hash = tpo:getCharacterHash()
		clientState.parts({
			HumanoidRootPart = hash.Torso,
			Torso = hash.Torso,
			Head = hash.Head,
			["Left Arm"] = hash["Left Arm"],
			["Right Arm"] = hash["Right Arm"],
			["Left Leg"] = hash["Left Leg"],
			["Right Leg"] = hash["Right Leg"],
		})
		clientState.alive(true)
	else
		clientState.parts({})
		clientState.alive(false)
	end
end

local _characterInterface: any = nil
local _cameraInterface: any = nil

local function characterInterface(): any
	if not _characterInterface then
		_characterInterface = ModuleController.GetModule("CharacterInterface")
	end
	return _characterInterface
end

local function getCharacterObject(): any?
	return characterInterface().getCharacterObject()
end

local function isAlive(): boolean
	return characterInterface().isAlive()
end

local function getCamera(): any
	if not _cameraInterface then
		_cameraInterface = ModuleController.GetModule("CameraInterface")
	end
	return _cameraInterface.getActiveCamera("MainCamera", true)
end

local _camParts: { [BasePart]: boolean } = {}
local _camAddConn: RBXScriptConnection? = nil
local _camRemoveConn: RBXScriptConnection? = nil
local _trackedCamera: Camera? = nil
local _viewHidden = false

local function trackCamera(camera: Camera?): ()
	if _trackedCamera == camera then
		return
	end
	if _camAddConn then
		_camAddConn:Disconnect()
		_camAddConn = nil
	end
	if _camRemoveConn then
		_camRemoveConn:Disconnect()
		_camRemoveConn = nil
	end
	table.clear(_camParts)
	_trackedCamera = camera
	if not camera then
		return
	end
	for _, descendant in next, camera:QueryDescendants("BasePart") do
		_camParts[descendant] = true
		if _viewHidden then
			descendant.LocalTransparencyModifier = 1
		end
	end
	_camAddConn = camera.DescendantAdded:Connect(function(descendant: Instance): ()
		if descendant:IsA("BasePart") then
			_camParts[descendant] = true
			if _viewHidden then
				descendant.LocalTransparencyModifier = 1
			end
		end
	end)
	_camRemoveConn = camera.DescendantRemoving:Connect(function(descendant: Instance): ()
		if _camParts[descendant :: any] then
			_camParts[descendant :: any] = nil
			local part = descendant :: BasePart
			part.LocalTransparencyModifier = 0
		end
	end)
end

local function getActiveWeapon(co: any): any?
	return co:getWeaponController():getActiveWeapon()
end

local function unhideAllWeapons(co: any): ()
	local controller = co:getWeaponController()
	local weapons = controller and controller:getWeapons()
	if weapons then
		for _, w in next, weapons do
			if rawget(w, "_forceHidden") == true then
				w:toggleForceHide()
			end
		end
	end
	table.clear(localThirdPerson._hiddenWeapons)
end

local function setViewmodelHidden(co: any, weapon: any, isFirearm: boolean, hidden: boolean): ()
	if hidden then
		if isFirearm and weapon then
			if rawget(weapon, "_forceHidden") ~= true then
				weapon:toggleForceHide()
			end
			localThirdPerson._hiddenWeapons[weapon] = true
		end
	else
		unhideAllWeapons(co)
	end

	trackCamera(Workspace.CurrentCamera)
	if _viewHidden ~= hidden then
		_viewHidden = hidden
		local value = hidden and 1 or 0
		for part in next, _camParts do
			part.LocalTransparencyModifier = value
		end
	end

	if (rawget(co, "_currentArmState") ~= false) == hidden then
		co:toggleArms(not hidden)
	end
end

local function activeIndex(): number
	local body = localThirdPerson._body
	return (body and body:getActiveIndex()) or 1
end

local function destroyBody(): ()
	local co = getCharacterObject()
	if co then
		unhideAllWeapons(co)
	end
	local body = localThirdPerson._body
	if body then
		body:destroy()
	end
	table.clear(localThirdPerson._hiddenWeapons)
	clearState()
end

local _driveOpts = { stance = nil :: any, sprint = nil :: any, aim = nil :: any, weaponName = nil :: any }

local drive = LPH_NO_VIRTUALIZE(function(): ()
	local co = getCharacterObject()
	if not co or not isAlive() then
		local body = localThirdPerson._body
		if body and body:isBuilt() then
			destroyBody()
		end
		return
	end

	local body = localThirdPerson._body
	if not body then
		body = FakeCharacter.new()
		body:setPositionSmoothing(localThirdPerson._smoothing)
		body:setPositionOverride(localThirdPerson._positionOverride)
		body:setAngleHold(localThirdPerson._angleHold)
		localThirdPerson._body = body
	end

	local angles = getCamera():getAngles()
	local override = localThirdPerson._lookOverride
	if override then
		angles = override(angles) or angles
	end

	local weapon = getActiveWeapon(co)
	_driveOpts.stance = co:getMovementMode()
	_driveOpts.sprint = co:isSprinting()
	_driveOpts.aim = (weapon ~= nil and weapon.isAiming ~= nil and weapon:isAiming() == true) or false
	_driveOpts.weaponName = weapon and weapon.weaponName
	local justBuilt = body:update(co:getRealRootPart().Position, angles, _driveOpts)
	if justBuilt then
		return
	end

	local tpo = body:getThirdPersonObject()
	if tpo then
		publishModel(tpo, tpo:getCharacterModel())
	end

	setViewmodelHidden(co, weapon, activeIndex() <= 2, true)
end)

local function hookScreenCull(): ()
	if localThirdPerson._screenCullStep then
		return
	end
	local sc = ModuleController.GetModule("ScreenCull")
	if not sc or type(sc.step) ~= "function" then
		return
	end
	local target = sc.step
	localThirdPerson._screenCullStep = target
	local original
	original = hook.add(target, LPH_NO_VIRTUALIZE(function(cf: any, viewport: any, fov: any): ...any
		local override = localThirdPerson._cameraCFrame
		if localThirdPerson._enabled and override then
			return original(override, viewport, fov)
		end
		return original(cf, viewport, fov)
	end))
end

local function unhookScreenCull(): ()
	local target = localThirdPerson._screenCullStep
	if target then
		hook.restore(target)
		localThirdPerson._screenCullStep = nil
	end
	localThirdPerson._cameraCFrame = nil
end

function localThirdPerson.setCameraCFrame(cf: CFrame): ()
	localThirdPerson._cameraCFrame = cf
end

function localThirdPerson.setEnabled(enabled: boolean): ()
	if localThirdPerson._enabled == enabled then
		return
	end
	localThirdPerson._enabled = enabled
	clientState.thirdPerson(enabled)

	if enabled then
		hookScreenCull()
		localThirdPerson._conn = RunService.PreRender:Connect(drive)
	else
		if localThirdPerson._conn then
			localThirdPerson._conn:Disconnect()
			localThirdPerson._conn = nil
		end
		unhookScreenCull()
		local co = getCharacterObject()
		if co then
			local weapon = getActiveWeapon(co)
			setViewmodelHidden(co, weapon, activeIndex() <= 2, false)
		end
		trackCamera(nil)
		destroyBody()
	end
end

function localThirdPerson.setLookOverride(fn: ((Vector3) -> Vector3?)?): ()
	localThirdPerson._lookOverride = fn
end

function localThirdPerson.getLookOverride(): ((Vector3) -> Vector3?)?
	return localThirdPerson._lookOverride
end

function localThirdPerson.setPositionOverride(position: Vector3?): ()
	localThirdPerson._positionOverride = position
	local body = localThirdPerson._body
	if body then
		body:setPositionOverride(position)
	end
end

function localThirdPerson.getPositionOverride(): Vector3?
	return localThirdPerson._positionOverride
end

function localThirdPerson.setAngleHold(hold: boolean): ()
	localThirdPerson._angleHold = hold
	local body = localThirdPerson._body
	if body then
		body:setAngleHold(hold)
	end
end

function localThirdPerson.getAngleHold(): boolean
	return localThirdPerson._angleHold
end

function localThirdPerson.setPositionSmoothing(smooth: number): ()
	localThirdPerson._smoothing = smooth
	local body = localThirdPerson._body
	if body then
		body:setPositionSmoothing(smooth)
	end
end

function localThirdPerson.getCharacterModel(): Model?
	local body = localThirdPerson._body
	return body and body:getCharacterModel()
end

function localThirdPerson.getWeaponModel(): Instance?
	local body = localThirdPerson._body
	return body and body:getWeaponModel()
end

function localThirdPerson.Destroy(): ()
	localThirdPerson.setEnabled(false)
end

export type localThirdPerson = typeof(localThirdPerson)

return localThirdPerson
