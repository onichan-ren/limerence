local Players = cloneref(game:GetService("Players")) :: Players

local ModuleController = require("@game/bloxstrike/module/ModuleController")
local Hook = require("@share/hook")
local Janitor = require("@pkg/Janitor")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")

local PersistentKillFeed = {}
PersistentKillFeed.__index = PersistentKillFeed

setmetatable(PersistentKillFeed, { __index = BaseFeature })

function PersistentKillFeed.new(link: gameUi.Linker): PersistentKillFeed
	local self = BaseFeature.new() :: any
	setmetatable(self, PersistentKillFeed)

	link:Toggle("persistentKillFeed", "Persistent Kill Feed", false):SetTip({
		title = "Persistent Kill Feed",
		body = "Keeps kill feed lines for your kills visible for the entire round.",
	})

	self._janitor = Janitor.new()

	self:Track(link:Get("persistentKillFeed"):OnChange(function(value: boolean)
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	return self
end

function PersistentKillFeed.Enable(self: PersistentKillFeed): ()
	if self._enabled then
		return
	end
	self._enabled = true

	local killFeed = ModuleController.GetModule("KillFeed")
	if not killFeed then
		return
	end

	local createTemplate = rawget(killFeed, "createTemplate")

	if not createTemplate then
		return
	end

	local userId = tostring(Players.LocalPlayer.UserId)

	local old = nil
	old = Hook.add(createTemplate, function(data)
		local killer = data.Killer
		local assistor = data.Assistor

		if killer ~= userId and assistor ~= userId then
			return old(data)
		end

		getfenv(old).task = {
			delay = newcclosure(function() end),
		}
		local result = old(data)
		getfenv(old).task = nil

		return result
	end)

	self._janitor:Add(workspace:GetAttributeChangedSignal("GameState"):Connect(function()
		if workspace:GetAttribute("GameState") == "Buy Period" or workspace:GetAttribute("GameState") == "Warmup" then
			self:_clearKillFeed()
		end
	end))

	self._janitor:Add(function()
		Hook.restore(createTemplate)
		self:_clearKillFeed()
	end)
end

function PersistentKillFeed._clearKillFeed(self: PersistentKillFeed): ()
	local killFeed = ModuleController.GetModule("KillFeed")
	if not killFeed then
		return
	end

	local initialize = rawget(killFeed, "Initialize") :: any
	local ui = getupvalue(initialize, 1)

	for _, child in next, ui:GetChildren() do
		if child.Name == "Kill" then
			child:Destroy()
		end
	end
end

function PersistentKillFeed.Disable(self: PersistentKillFeed): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	self._janitor:Cleanup()
end

function PersistentKillFeed.Destroy(self: PersistentKillFeed): ()
	self:Disable()
	BaseFeature.Destroy(self)
	self._janitor:Destroy()
end

export type PersistentKillFeed =
	typeof(setmetatable(
		{} :: {
			_enabled: boolean,
			_janitor: Janitor.Janitor,
		},
		PersistentKillFeed
	))
	& BaseFeature.BaseFeature

return PersistentKillFeed
