local React = require("@pkg/React")
local ReactRoblox = require("@pkg/ReactRoblox")

local BaseFeature = require("@game/BaseFeature")
local Charm = require("@pkg/Charm")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local ModuleController = require("@game/pf/module/ModuleController")
local droppedWeaponState = require("@game/pf/feature/visual/dropped/droppedWeaponState")
local droppedWeaponRenderer = require("@game/pf/feature/visual/dropped/droppedWeaponRenderer")

local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local e = React.createElement
local peek = Charm.peek
local sub = Charm.subscribe

local DEFAULT_TEXT = Color3.fromRGB(200, 200, 200)
local DEFAULT_OUTLINE = Color3.fromRGB(18, 18, 18)

local SCAN_RADIUS = 1e9

local DroppedWeaponEsp = {}
DroppedWeaponEsp.__index = DroppedWeaponEsp

setmetatable(DroppedWeaponEsp, { __index = BaseFeature })

local _dropMap: { [Instance]: any }? = nil

local function invalidateDrops(): ()
	_dropMap = nil
end

local resolveDropData = LPH_NO_VIRTUALIZE(function(model: Instance): any?
	if not _dropMap then
		local env = ModuleController.GetModule("EnvironmentInterfaceClient")
		if not env then
			return nil
		end
		local drops = env.getNearbyWeapons(Vector3.zero, SCAN_RADIUS)
		if type(drops) ~= "table" then
			return nil
		end
		local map = {}
		for _, record in next, drops do
			local data = record.dropData
			if data and data.weaponModel then
				map[data.weaponModel] = data
			end
		end
		_dropMap = map
	end
	return _dropMap[model]
end)

local function entryFromData(data: any): droppedWeaponState.DroppedEntry
	local weaponObject = data.weaponObject
	return {
		model = data.weaponModel,
		label = (weaponObject and weaponObject.weaponName) or "Weapon",
		position = data.dropPosition,
	}
end

function DroppedWeaponEsp.new(link: gameUi.Linker): DroppedWeaponEsp
	local self = BaseFeature.new() :: any
	setmetatable(self, DroppedWeaponEsp)

	link:Toggle("indicator", "Indicator", false):SetTip({
		title = "Indicator",
		body = "On-screen markers for guns left on the ground.",
	})
	local masterLink = link:OnKey("indicator")
	masterLink:Submenu("opts", "Indicator")
	local optsLink = masterLink:OnKey("opts")

	optsLink:Colorpicker("textColor", "Text Color", DEFAULT_TEXT)
	optsLink:Toggle("textOutline", "Text Outline", true)
	local textOutlineLink = optsLink:OnKey("textOutline")
	textOutlineLink:Colorpicker("outlineColor", "Outline Color", DEFAULT_OUTLINE, 0)

	self._enabledLink = link:Get("indicator")
	self._tracked = {}
	self._byModel = {}
	self._folder = nil
	self._folderConns = {}

	local screenGui = instances.new("ScreenGui", {
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		Secure = true,
		Enabled = true,
		DisplayOrder = 15,
	}, cloneref(gethui()))
	self._screenGui = screenGui

	self._root = ReactRoblox.createRoot(screenGui)
	self._root:render(e(droppedWeaponRenderer, {
		enabledLink = self._enabledLink,
		weaponTextColorLink = link:Get("indicator.opts.textColor"),
		weaponTextOutlineLink = link:Get("indicator.opts.textOutline"),
		weaponTextOutlineColorLink = link:Get("indicator.opts.textOutline.outlineColor"),
	}))

	local function push(): ()
		if not peek(self._enabledLink._state) then
			return
		end
		droppedWeaponState.entries(table.clone(self._tracked))
	end

	local addModel = LPH_NO_VIRTUALIZE(function(model: Instance): ()
		if not model:IsA("Model") then
			return
		end
		task.defer(function(): ()
			if not peek(self._enabledLink._state) or not model.Parent then
				return
			end
			local data = resolveDropData(model)
			if not data then
				return
			end
			local id = data.weaponId or model
			self._tracked[id] = entryFromData(data)
			self._byModel[model] = id
			push()
		end)
	end)

	local function removeModel(model: Instance): ()
		local id = self._byModel[model]
		if id == nil then
			return
		end
		self._byModel[model] = nil
		self._tracked[id] = nil
		push()
	end

	local function syncExisting(): ()
		local folder = self._folder
		if not folder then
			return
		end
		for _, child in next, folder:GetChildren() do
			addModel(child)
		end
	end

	local function bindFolder(folder: Instance): ()
		self._folder = folder
		table.insert(self._folderConns, folder.ChildAdded:Connect(function(child: Instance): ()
			invalidateDrops()
			addModel(child)
		end))
		table.insert(self._folderConns, folder.ChildRemoved:Connect(function(child: Instance): ()
			invalidateDrops()
			removeModel(child)
		end))
	end

	local ignore = Workspace:FindFirstChild("Ignore")
	local folder = ignore and ignore:FindFirstChild("GunDrop")
	if folder then
		bindFolder(folder)
	else
		local conn
		conn = Workspace.DescendantAdded:Connect(function(descendant: Instance): ()
			local parent = descendant.Parent
			if descendant.Name == "GunDrop" and parent and parent.Name == "Ignore" then
				conn:Disconnect()
				self._folderWaitConn = nil
				bindFolder(descendant)
				if peek(self._enabledLink._state) then
					syncExisting()
				end
			end
		end)
		self._folderWaitConn = conn
	end

	self._enabledSub = sub(self._enabledLink._state, function(enabled: boolean): ()
		if enabled then
			syncExisting()
		else
			table.clear(self._tracked)
			table.clear(self._byModel)
			droppedWeaponState.entries({})
		end
	end)

	if peek(self._enabledLink._state) then
		syncExisting()
	end

	return self
end

function DroppedWeaponEsp.Destroy(self: DroppedWeaponEsp): ()
	for _, conn in next, self._folderConns do
		conn:Disconnect()
	end
	self._folderConns = {}
	if self._folderWaitConn then
		self._folderWaitConn:Disconnect()
		self._folderWaitConn = nil
	end
	if self._enabledSub then
		self._enabledSub()
		self._enabledSub = nil
	end
	if self._root then
		self._root:unmount()
	end
	if self._screenGui then
		self._screenGui:Destroy()
	end
	droppedWeaponState.entries({})
	BaseFeature.Destroy(self)
end

export type DroppedWeaponEsp =
	typeof(setmetatable(
		{} :: {
			_enabledLink: any,
			_tracked: { [any]: droppedWeaponState.DroppedEntry },
			_byModel: { [Instance]: any },
			_folder: Instance?,
			_folderConns: { RBXScriptConnection },
			_folderWaitConn: RBXScriptConnection?,
			_enabledSub: (() -> ())?,
			_screenGui: Instance,
			_root: ReactRoblox.RootType,
		},
		DroppedWeaponEsp
	))
	& BaseFeature.BaseFeature

return DroppedWeaponEsp
