local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Charm = require("@pkg/Charm")
local Janitor = require("@pkg/Janitor")
local Signal = require("@pkg/Signal")
local OverkillBot = require("@game/overkill/feature/training/OverkillBot")

local at = Charm.atom

local botSource = {
	added = Signal.new() :: Signal.Signal<OverkillBot.OverkillBot>,
	removed = Signal.new() :: Signal.Signal<OverkillBot.OverkillBot>,
	died = Signal.new() :: Signal.Signal<OverkillBot.OverkillBot>,

	_bots = {} :: { [Model]: OverkillBot.OverkillBot },
	_destroyConns = {} :: { [Model]: RBXScriptConnection },
	_diedConns = {} :: { [Model]: Signal.Connection },
	_active = at(false),
	_refcount = 0,
	_janitor = nil :: Janitor.Janitor?,
	_bound = false,
}

function botSource.GetAll(): { [Model]: OverkillBot.OverkillBot }
	return botSource._bots
end

function botSource.GetByDummyUserId(userId: number): OverkillBot.OverkillBot?
	for model, bot in next, botSource._bots do
		if model:GetAttribute("BotUserId") == userId then
			return bot
		end
	end
	return nil
end

function botSource.GetByPlayer(player: any): OverkillBot.OverkillBot?
	for _, bot in next, botSource._bots do
		if bot:GetPlayer() == player then
			return bot
		end
	end
	return nil
end

local function isBotModel(inst: Instance): boolean
	return inst:IsA("Model") and inst:GetAttribute("IsDummy") == true
end

local removeBot: (model: Model) -> ()

local function addBot(model: Model): ()
	if botSource._bots[model] then
		return
	end
	local bot = OverkillBot.new(model)
	botSource._bots[model] = bot
	botSource._destroyConns[model] = model.Destroying:Connect(function(): ()
		removeBot(model)
	end)
	botSource._diedConns[model] = bot.died:Connect(function(): ()
		botSource.died:Fire(bot)
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
	local diedConn = botSource._diedConns[model]
	if diedConn then
		diedConn:Disconnect()
		botSource._diedConns[model] = nil
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
		local diedConn = botSource._diedConns[model]
		if diedConn then
			diedConn:Disconnect()
			botSource._diedConns[model] = nil
		end
		botSource._bots[model] = nil
		botSource.removed:Fire(bot)
		bot:Destroy()
	end
end

local function scanContainer(container: Instance, janitor: Janitor.Janitor): ()
	if botSource._bound then
		return
	end
	botSource._bound = true
	botSource._active(true)

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

local function bind(janitor: Janitor.Janitor): ()
	local world = Workspace:FindFirstChild("World")
	local entities = world and world:FindFirstChild("Entities")
	if entities then
		scanContainer(entities, janitor)
		return
	end

	janitor:Add(
		Workspace.DescendantAdded:Connect(function(inst: Instance): ()
			if botSource._bound then
				return
			end
			local parent = inst.Parent
			if inst.Name == "Entities" and parent and parent.Name == "World" then
				scanContainer(inst, janitor)
			end
		end),
		"Disconnect"
	)
end

function botSource.Start(): ()
	botSource._refcount += 1
	if botSource._refcount > 1 then
		return
	end
	local janitor = Janitor.new()
	botSource._janitor = janitor
	bind(janitor)
end

function botSource.Destroy(): ()
	botSource._refcount -= 1
	if botSource._refcount > 0 then
		return
	end
	botSource._refcount = 0
	if botSource._janitor then
		botSource._janitor:Destroy()
		botSource._janitor = nil
	end
	clearBots()
	botSource._bound = false
	botSource._active(false)
end

return botSource
