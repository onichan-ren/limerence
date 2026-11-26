local RunService = cloneref(game:GetService("RunService")) :: RunService

local Charm = require("@pkg/Charm")
local strings = require("@share/strings")
local logger = require("@share/logger").new("positionSpoofer")

local peek = Charm.peek
local sub = Charm.subscribe

local RESTORE_PRIORITY = Enum.RenderPriority.First.Value

local positionSpoofer = {}

local _attached = false
local _unsub: (() -> ())? = nil
local _hrpAtom: Charm.Atom<BasePart?>? = nil
local _requests: { [number]: CFrame? } = {}
local _target: CFrame? = nil
local _clientCFrame: CFrame? = nil
local _displaced = false
local _displacedHrp: BasePart? = nil
local _displacedTarget: CFrame? = nil
local _hbConn: RBXScriptConnection? = nil
local _clientVelocity: Vector3? = nil
local _restoreBinding: string? = nil

local restoreDisplace = LPH_NO_VIRTUALIZE(function(): ()
	if not _displaced then
		return
	end
	local hrp = _displacedHrp
	local clientCFrame = _clientCFrame
	local target = _displacedTarget
	if hrp and hrp.Parent then
		if clientCFrame and target then
			hrp.CFrame = clientCFrame + (hrp.Position - target.Position)
		elseif clientCFrame then
			hrp.CFrame = clientCFrame
		end

		hrp.Anchored = true
		hrp.Anchored = false
		hrp.AssemblyLinearVelocity = _clientVelocity or Vector3.zero
	end
	_displaced = false
	_displacedHrp = nil
	_displacedTarget = nil
end)

local applyDisplace = LPH_NO_VIRTUALIZE(function(): ()
	if _displaced then
		return
	end

	local target = _target
	local hrp = _hrpAtom and peek(_hrpAtom :: Charm.Atom<BasePart?>)
	if not target or not hrp then
		return
	end

	_clientCFrame = hrp.CFrame
	_clientVelocity = hrp.AssemblyLinearVelocity
	hrp.CFrame = target
	_displacedHrp = hrp
	_displacedTarget = target
	_displaced = true
end)

local function startLoop(): ()
	if _hbConn then
		return
	end

	_restoreBinding = strings.randomSafe(8)
	RunService:BindToRenderStep(_restoreBinding :: string, RESTORE_PRIORITY, restoreDisplace)
	_hbConn = RunService.Heartbeat:Connect(applyDisplace)
	logger:log("loop started")
end

local function stopLoop(): ()
	if _hbConn then
		_hbConn:Disconnect()
		_hbConn = nil
	end
	if _restoreBinding then
		RunService:UnbindFromRenderStep(_restoreBinding)
		_restoreBinding = nil
	end
	restoreDisplace()
	logger:log("loop stopped")
end

function positionSpoofer.Attach(hrpAtom: Charm.Atom<BasePart?>): ()
	if _attached then
		return
	end
	_attached = true
	_hrpAtom = hrpAtom
	logger:debug("attached")

	_unsub = sub(hrpAtom, function(): ()
		restoreDisplace()
	end)
end

local function refreshLoop(): ()
	if _target then
		startLoop()
	else
		stopLoop()
	end
end

local function resolveTarget(): ()
	local bestPriority: number? = nil
	local best: CFrame? = nil
	for priority, cf in next, _requests do
		if bestPriority == nil or priority > bestPriority then
			bestPriority = priority
			best = cf
		end
	end
	_target = best
	logger:debug("target resolved, priority:", bestPriority, "position:", best and best.Position or nil)
	refreshLoop()
end

function positionSpoofer.SetTarget(cf: CFrame?, priority: number?): ()
	local slot = priority or 0
	logger:debug("set target, priority:", slot, "position:", cf and cf.Position or nil)
	_requests[slot] = cf
	resolveTarget()
end

function positionSpoofer.IsActive(): boolean
	return _target ~= nil
end

function positionSpoofer.GetServerCFrame(): CFrame?
	return _target
end

function positionSpoofer.GetClientCFrame(): CFrame?
	if _displaced then
		return _clientCFrame
	end
	local hrp = _hrpAtom and peek(_hrpAtom :: Charm.Atom<BasePart?>)
	if hrp then
		return hrp.CFrame
	end
	return _clientCFrame
end

function positionSpoofer.Detach(): ()
	if not _attached then
		return
	end
	_attached = false
	_target = nil
	table.clear(_requests)
	stopLoop()
	logger:debug("detached")

	if _unsub then
		_unsub()
		_unsub = nil
	end

	_hrpAtom = nil
	_clientCFrame = nil
end

return positionSpoofer
