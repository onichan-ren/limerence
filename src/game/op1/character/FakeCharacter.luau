local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local ModuleController = require("@game/op1/module/ModuleController")

local DEFAULT_SKIN = 3

local MIRROR_PARTS = {
	"head",
	"torso",
	"arm1",
	"arm2",
	"leg1",
	"leg2",
	"shoulder1",
	"shoulder2",
	"hip1",
	"hip2",
}

local _loadout: any = nil
local _items: any = nil
local _globals: any = nil
local _util: any = nil
local _emptyCharacter: Instance? = nil

local function resolveModules(): boolean
	if not _loadout then
		_loadout = ModuleController.GetModule("Loadout")
	end
	if not _items then
		_items = ModuleController.GetModule("Items")
	end
	if not _globals then
		_globals = ModuleController.GetModule("Globals")
	end
	if not _util then
		_util = ModuleController.GetModule("Util")
	end
	if not _emptyCharacter then
		local gameScript = ModuleController.GetInstance("Game")
		_emptyCharacter = gameScript and gameScript:FindFirstChild("EmptyCharacter")
	end
	return _loadout ~= nil
		and _items ~= nil
		and _globals ~= nil
		and _util ~= nil
		and _emptyCharacter ~= nil
end

local function applyAttachments(rig: any, model: Model, class: any, weaponTag: string): ()
	local stored = class.attachments and class.attachments[weaponTag]
	if not stored then
		return
	end
	for _, attachType in next, _globals.attachment_types do
		local attachClass = _items.get_item_class(stored[attachType])
		if attachClass and attachType == attachClass.loadout_type then
			local _, state = attachClass:apply({ instance = model })
			if state then
				state:set(true)
			end
		end
	end
end

local function buildHolstered(rig: any, class: any, weaponTag: string?): Model?
	if not weaponTag then
		return nil
	end
	local class2 = _items.get_item_class(weaponTag)
	if not class2 or not class2.holster_part then
		return nil
	end
	if class2.tag ~= "Gun" then
		return nil
	end

	if not class2.model then
		return nil
	end

	local model = class2.model:Clone()
	model.Name = weaponTag
	model:SetAttribute("HolsterOffset", class2.holster_offset)
	model:SetAttribute("EquipOffset", class2.equip_offset)
	model:SetAttribute("HolsterPart", class2.holster_part)
	model:PivotTo(rig[class2.holster_part]:GetPivot() * class2.holster_offset)
	model.Parent = rig
	_util.weld_c(model.Root, rig[class2.holster_part]).Name = "HolsterWeld"
	_util.weld_model(model)

	applyAttachments(rig, model, class, weaponTag)
	return model
end

local FakeCharacter = {}
FakeCharacter.__index = FakeCharacter

function FakeCharacter.new(opts: any?): FakeCharacter
	local self = setmetatable({}, FakeCharacter) :: any
	self._rig = nil
	self._cframes = nil
	self._animState = nil
	self._weapons = {}
	self._activeSlot = nil
	self._queryable = opts and opts.queryable == true or false
	self._parent = (opts and opts.parent) or Workspace
	self._class = opts and opts.class or nil
	self._animate = not (opts and opts.animate == false)
	self._mirrorParts = nil
	self._mirrorSource = nil
	self._mirrorFlat = nil
	return self
end

FakeCharacter._reholster = function(self: FakeCharacter, model: Model): ()
	local rig = self._rig :: any
	local part = model:GetAttribute("HolsterPart") :: string
	local offset = model:GetAttribute("HolsterOffset") :: CFrame
	local existing = (model :: any).Root:FindFirstChild("HolsterWeld")
	if existing then
		existing:Destroy()
	end
	model:PivotTo(rig[part]:GetPivot() * offset)
	model.Parent = rig
	_util.weld_c((model :: any).Root, rig[part]).Name = "HolsterWeld"
end

FakeCharacter._equip = function(self: FakeCharacter, slot: string): ()
	local model = self._weapons[slot]
	if not model then
		return
	end
	local rig = self._rig :: any

	local current = self._activeSlot
	if current and current ~= slot and self._weapons[current] then
		self:_reholster(self._weapons[current])
	end

	local existing = (model :: any).Root:FindFirstChild("HolsterWeld")
	if existing then
		existing:Destroy()
	end
	model:PivotTo(rig.arm1:GetPivot() * model:GetAttribute("EquipOffset"))
	model.Parent = rig.arm1
	_util.weld_c((model :: any).Root, rig.arm1).Name = "HolsterWeld"

	if self._cframes then
		if slot == "secondary" then
			_loadout.animations.secondary_hold(self._cframes, rig)
		else
			_loadout.animations.primary_hold(self._cframes, rig)
		end
	end
	self._activeSlot = slot
end

FakeCharacter._dress = function(self: FakeCharacter, rig: any, class: any): ()
	local skin = _globals.skin_colors[class.skin_color or DEFAULT_SKIN]
	for _, child in next, rig:GetChildren() do
		if child:IsA("BasePart") then
			child.Material = Enum.Material.SmoothPlastic
			child.CanCollide = false
			if child.Transparency == 0 then
				child.Color = skin
			end
		end
	end

	local toClear = rig:FindFirstChild("to_clear") or rig

	if class.hat and typeof(class.hat) == "table" then
		for _, tag in next, class.hat do
			local hatClass = _items.get_item_class(tag)
			if hatClass and hatClass.model then
				local hat = hatClass.model:Clone()
				hat.Parent = toClear
				for _, child in next, hat:GetChildren() do
					child:PivotTo(rig[child.Name]:GetPivot())
					_util.weld_c(child.PrimaryPart, rig[child.Name])
				end
				if hatClass.hide_head then
					rig.head.Transparency = 1
				end
			end
		end
	end

	if class.outfit then
		local outfitClass = _items.get_item_class(class.outfit)
		if outfitClass and outfitClass.model then
			local outfit = outfitClass.model:Clone()
			outfit.Parent = toClear
			for _, child in next, outfit:GetChildren() do
				child:PivotTo(rig[child.Name]:GetPivot())
				_util.weld_c(child.PrimaryPart, rig[child.Name])
			end
		end
	end
end

FakeCharacter._build = LPH_NO_VIRTUALIZE(function(self: FakeCharacter): boolean
	if self._rig then
		return true
	end
	if not resolveModules() then
		return false
	end

	local class = self._class or _loadout.chosen_class:get()
	if not class then
		return false
	end

	setthreadidentity(2)

	local rig = (_emptyCharacter :: Instance):Clone() :: Model
	self._rig = rig

	if self._animate then
		local cframes, animState = _loadout.setup_animations(rig)
		self._cframes = cframes
		self._animState = animState
	end

	self:_dress(rig, class)

	self._weapons.secondary = buildHolstered(rig, class, class.secondary)
	self._weapons.primary = buildHolstered(rig, class, class.primary)

	if self._weapons.primary then
		self:_equip("primary")
	elseif self._weapons.secondary then
		self:_equip("secondary")
	end

	local mirrorParts = {}
	for _, name in next, MIRROR_PARTS do
		local part = rig:FindFirstChild(name)
		if part then
			mirrorParts[name] = part
		end
	end
	self._mirrorParts = mirrorParts

	for _, descendant in next, rig:QueryDescendants("BasePart") do
		descendant.CanCollide = false
		descendant.CanTouch = false
		descendant.Massless = true
		descendant.CanQuery = self._queryable
	end
	for _, descendant in next, rig:QueryDescendants("Humanoid") do
		descendant:Destroy()
	end
	for _, descendant in next, rig:QueryDescendants("Motor6D") do
		descendant.Enabled = false
	end

	if not self._animate then
		for _, part in next, mirrorParts do
			part.Anchored = true
		end
	end

	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = true
		root.CanCollide = false
	end

	if self._animState then
		self._animState:set(true)
	end
	rig.Parent = self._parent

	setthreadidentity(8)
	return true
end)

function FakeCharacter.Build(self: FakeCharacter): boolean
	return self:_build()
end

function FakeCharacter.IsBuilt(self: FakeCharacter): boolean
	return self._rig ~= nil
end

FakeCharacter.SetCFrame = LPH_NO_VIRTUALIZE(function(self: FakeCharacter, cframe: CFrame): ()
	local rig = self._rig
	if not rig then
		return
	end
	local root = self._root or rig:FindFirstChild("HumanoidRootPart")
	self._root = root
	if root then
		(root :: BasePart).CFrame = cframe
	end
end)

FakeCharacter.MirrorFrom = LPH_NO_VIRTUALIZE(function(self: FakeCharacter, source: Instance?, delta: Vector3): ()
	local parts = self._mirrorParts
	if not parts or not source then
		return
	end
	if source ~= self._mirrorSource then
		self._mirrorSource = source
		local flat = {}
		for name, clonePart in next, parts do
			local src = (source :: any):FindFirstChild(name)
			if src then
				flat[#flat + 1] = clonePart
				flat[#flat + 1] = src
			end
		end
		self._mirrorFlat = flat
	end
	local flat = self._mirrorFlat
	for index = 1, #flat, 2 do
		flat[index].CFrame = flat[index + 1].CFrame + delta
	end
end)

function FakeCharacter.SetEquippedSlot(self: FakeCharacter, slot: string): ()
	if not self._rig or slot == self._activeSlot then
		return
	end
	setthreadidentity(2)
	self:_equip(slot)
	setthreadidentity(8)
end

function FakeCharacter.SetQueryable(self: FakeCharacter, enabled: boolean): ()
	self._queryable = enabled
	local rig = self._rig
	if not rig then
		return
	end
	for _, descendant in next, rig:QueryDescendants("BasePart") do
		descendant.CanQuery = enabled
	end
end

function FakeCharacter.GetModel(self: FakeCharacter): Model?
	return self._rig
end

function FakeCharacter.GetRoot(self: FakeCharacter): BasePart?
	local rig = self._rig
	if not rig then
		return nil
	end
	return rig:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function FakeCharacter.GetWeaponModel(self: FakeCharacter): Model?
	return self._activeSlot and self._weapons[self._activeSlot] or nil
end

function FakeCharacter.GetBodyParts(self: FakeCharacter): { BasePart }
	local rig = self._rig
	local parts: { BasePart } = {}
	if not rig then
		return parts
	end

	local weapons: { [Instance]: boolean } = {}
	for _, model in next, self._weapons do
		if model then
			weapons[model] = true
		end
	end

	for _, descendant in next, rig:QueryDescendants("BasePart") do
		if descendant.Name ~= "HumanoidRootPart" then
			local skip = false
			local node: Instance? = descendant
			while node and node ~= rig do
				if weapons[node] then
					skip = true
					break
				end
				node = node.Parent
			end
			if not skip then
				parts[#parts + 1] = descendant
			end
		end
	end

	return parts
end

function FakeCharacter.GetActiveSlot(self: FakeCharacter): string?
	return self._activeSlot
end

function FakeCharacter.Destroy(self: FakeCharacter): ()
	if self._animState then
		setthreadidentity(2)
		self._animState:set(false)
		setthreadidentity(8)
		self._animState = nil
	end
	if self._rig then
		self._rig:Destroy()
		self._rig = nil
	end
	self._cframes = nil
	self._root = nil
	self._mirrorParts = nil
	self._mirrorSource = nil
	self._mirrorFlat = nil
	table.clear(self._weapons)
	self._activeSlot = nil
end

export type FakeCharacter = typeof(setmetatable(
	{} :: {
		_rig: Model?,
		_root: Instance?,
		_cframes: any,
		_animState: any,
		_weapons: { [string]: Model? },
		_activeSlot: string?,
		_queryable: boolean,
		_parent: Instance,
		_class: any,
		_animate: boolean,
		_mirrorParts: { [string]: BasePart }?,
		_mirrorSource: Instance?,
		_mirrorFlat: { any }?,
		_reholster: (FakeCharacter, Model) -> (),
		_equip: (FakeCharacter, string) -> (),
		_dress: (FakeCharacter, any, any) -> (),
		_build: (FakeCharacter) -> boolean,
		Build: (FakeCharacter) -> boolean,
		IsBuilt: (FakeCharacter) -> boolean,
		SetCFrame: (FakeCharacter, CFrame) -> (),
		MirrorFrom: (FakeCharacter, Instance?, Vector3) -> (),
		SetEquippedSlot: (FakeCharacter, string) -> (),
		SetQueryable: (FakeCharacter, boolean) -> (),
		GetModel: (FakeCharacter) -> Model?,
		GetRoot: (FakeCharacter) -> BasePart?,
		GetWeaponModel: (FakeCharacter) -> Model?,
		GetBodyParts: (FakeCharacter) -> { BasePart },
		GetActiveSlot: (FakeCharacter) -> string?,
		Destroy: (FakeCharacter) -> (),
	},
	FakeCharacter
))

return FakeCharacter
