local Players = cloneref(game:GetService("Players")) :: Players
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local Signal = require("@pkg/Signal")
local ModuleController = require("@game/rivals/module/ModuleController")
local RivalsBot = require("@game/rivals/feature/training/RivalsBot")

local at = Charm.atom

local LocalPlayer = Players.LocalPlayer
local CONTAINER_NAME = "ShootingRangeEntities"

local function safeGet(obj: any, key: string): any
	setthreadidentity(2)
	local value = obj.Get(obj, key)
	setthreadidentity(8)
	return value
end

local function safeDataChangedSignal(obj: any, key: string): RBXScriptSignal?
	setthreadidentity(2)
	local signal = obj.GetDataChangedSignal(obj, key)
	setthreadidentity(8)
	return signal
end

local function safeConnect(signal: any, fn: (...any) -> ()): RBXScriptConnection?
	if not signal then
		return nil
	end
	local function wrapped(...): ()
		setthreadidentity(8)
		fn(...)
		setthreadidentity(2)
	end
	setthreadidentity(2)
	local connection = signal.Connect(signal, wrapped)
	setthreadidentity(8)
	return connection
end

local botSource = {
	added = Signal.new() :: Signal.Signal<RivalsBot.RivalsBot>,
	removed = Signal.new() :: Signal.Signal<RivalsBot.RivalsBot>,

	_bots = {} :: { [Model]: RivalsBot.RivalsBot },
	_destroyConns = {} :: { [Model]: RBXScriptConnection },
	_active = at(false),
	_refcount = 0,
	_rangeOn = false,
	_rangeJanitor = nil :: Janitor.Janitor?,
	_lfJanitor = nil :: Janitor.Janitor?,
	_scanJanitor = nil :: Janitor.Janitor?,
}

function botSource.GetAll(): { [Model]: RivalsBot.RivalsBot }
	return botSource._bots
end

local function isBotModel(inst: Instance): boolean
	return inst.Name == "Dummy"
		and inst:IsA("Model")
		and inst:FindFirstChildOfClass("Humanoid") ~= nil
		and inst:FindFirstChild("HumanoidRootPart") ~= nil
end

local removeBot: (model: Model) -> ()

local function addBot(model: Model): ()
	if botSource._bots[model] then
		return
	end
	local bot = RivalsBot.new(model)
	botSource._bots[model] = bot
	botSource._destroyConns[model] = model.Destroying:Connect(function(): ()
		removeBot(model)
	end)
	botSource.added:Fire(bot)
end

function removeBot(model: Model): ()
	local bot = botSource._bots[model]
	if not bot then
		return
	end
	local conn = botSource._destroyConns[model]
	if conn then
		conn:Disconnect()
		botSource._destroyConns[model] = nil
	end
	botSource._bots[model] = nil
	botSource.removed:Fire(bot)
	bot:Destroy()
end

local function clearBots(): ()
	for model, bot in next, botSource._bots do
		local conn = botSource._destroyConns[model]
		if conn then
			conn:Disconnect()
			botSource._destroyConns[model] = nil
		end
		botSource._bots[model] = nil
		botSource.removed:Fire(bot)
		bot:Destroy()
	end
end

local function startScan(): ()
	if botSource._scanJanitor then
		return
	end
	local janitor = Janitor.new()
	botSource._scanJanitor = janitor

	local container = Workspace:FindFirstChild(CONTAINER_NAME)
	if not container then
		return
	end

	for _, child in next, container:GetChildren() do
		if isBotModel(child) then
			addBot(child :: Model)
		end
	end

	janitor:Add(
		container.ChildAdded:Connect(function(child: Instance): ()
			if isBotModel(child) then
				addBot(child :: Model)
			end
		end),
		"Disconnect"
	)
end

local function stopScan(): ()
	if botSource._scanJanitor then
		botSource._scanJanitor:Destroy()
		botSource._scanJanitor = nil
	end
	clearBots()
end

local function setRange(inRange: boolean): ()
	if inRange == botSource._rangeOn then
		return
	end
	botSource._rangeOn = inRange
	botSource._active(inRange)
	if inRange then
		startScan()
	else
		stopScan()
	end
end

local function bindLocalFighter(janitor: Janitor.Janitor): ()
	local fc = ModuleController.GetModule("FighterController")
	if not fc then
		return
	end
	local localFighter = rawget(fc, "LocalFighter")
	if not localFighter then
		return
	end
	setRange(safeGet(localFighter, "IsInShootingRange") == true)
	local conn = safeConnect(safeDataChangedSignal(localFighter, "IsInShootingRange"), function(): ()
		setRange(safeGet(localFighter, "IsInShootingRange") == true)
	end)
	if conn then
		janitor:Add(conn, "Disconnect")
	end
end

local function startRangeWatch(): ()
	if botSource._rangeJanitor then
		return
	end
	local janitor = Janitor.new()
	botSource._rangeJanitor = janitor
	local lfJanitor = Janitor.new()
	botSource._lfJanitor = lfJanitor
	janitor:Add(lfJanitor, "Destroy")

	local function rebind(): ()
		lfJanitor:Cleanup()
		bindLocalFighter(lfJanitor)
		setthreadidentity(8)
	end

	rebind()

	local fc = ModuleController.GetModule("FighterController")
	if fc then
		local addedConn = safeConnect((fc :: any).ObjectAdded, function(fighter: any): ()
			if fighter and fighter.Player == LocalPlayer then
				rebind()
			end
		end)
		if addedConn then
			janitor:Add(addedConn, "Disconnect")
		end
	end
end

function botSource.Start(): ()
	botSource._refcount += 1
	if botSource._refcount > 1 then
		return
	end
	startRangeWatch()
end

function botSource.Destroy(): ()
	botSource._refcount -= 1
	if botSource._refcount > 0 then
		return
	end
	botSource._refcount = 0
	if botSource._rangeJanitor then
		botSource._rangeJanitor:Destroy()
		botSource._rangeJanitor = nil
		botSource._lfJanitor = nil
	end
	stopScan()
	botSource._rangeOn = false
	botSource._active(false)
end

return botSource
