local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local Janitor = require("@pkg/Janitor")
local Charm = require("@pkg/Charm")
local clientState = require("@game/op1/client/clientState")
local chamsUtil = require("@game/op1/feature/visual/self/chamsUtil")
local thirdPersonState = require("@game/op1/feature/visual/self/thirdPersonState")

local peek = Charm.peek
local sub = Charm.subscribe

export type Config = {
	key: string,
	label: string,
	tip: string,
	defaultColor: Color3,
	defaultMaterial: string,
	collect: (charObject: any) -> { BasePart },
	collectThirdPerson: ((clone: any) -> { BasePart })?,
	watch: ((charObject: any, schedule: () -> ()) -> (() -> ())?)?,
	suppressInThirdPerson: boolean?,
}

local base = {}
base.__index = base

setmetatable(base, { __index = BaseFeature })

export type SelfChams = typeof(setmetatable({} :: any, base))

function base.new(link: gameUi.Linker, config: Config): SelfChams
	local self = BaseFeature.new() :: any
	setmetatable(self, base)

	self._config = config
	self._store = {}
	self._enabled = false
	self._activeJanitor = nil :: Janitor.Janitor?
	self._watchCleanup = nil :: (() -> ())?

	link:Toggle(config.key, config.label, false):SetTip({ title = config.label, body = config.tip })
	link:Extra(link:Get(config.key), config.key .. "Opts", "Submenu", config.label)
	local opts = link:OnKey(config.key .. "Opts")
	self._opts = opts

	opts:Colorpicker("color", "Color", config.defaultColor, 0):SetTip({
		title = "Color",
		body = "Cham color and transparency.",
	})
	opts:Dropdown("material", "Material", chamsUtil.MATERIAL_OPTIONS, config.defaultMaterial):SetTip({
		title = "Material",
		body = "Material applied to the parts.",
	})

	self._enabledLink = link:Get(config.key)

	self:Track(self._enabledLink:OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if self._enabledLink:Peek() then
		self:Enable()
	end

	return self
end

function base.color(self: SelfChams): Color3
	local picker: any = self._opts:Get("color")
	return picker and picker:GetColor() or self._config.defaultColor
end

function base.transparency(self: SelfChams): number
	local picker: any = self._opts:Get("color")
	return picker and picker:GetTransparency() or 0
end

function base.material(self: SelfChams): Enum.Material
	return chamsUtil.material(self._opts:Peek("material"))
end

function base.rescan(self: SelfChams): ()
	chamsUtil.restoreAll(self._store)

	if not self._enabled then
		return
	end

	local inThirdPerson = peek(thirdPersonState.active)
	local parts: { BasePart }

	if inThirdPerson and self._config.collectThirdPerson then
		local clone = peek(thirdPersonState.clone)
		if not clone then
			return
		end
		parts = self._config.collectThirdPerson(clone)
	else
		if self._config.suppressInThirdPerson and inThirdPerson then
			return
		end
		local charObject = peek(clientState.charObject)
		if not charObject then
			return
		end
		parts = self._config.collect(charObject)
	end

	local material = self:material()
	local color = self:color()
	local transparency = self:transparency()

	for _, part in next, parts do
		chamsUtil.apply(self._store, part, material, color, transparency)
	end
end

function base.reapply(self: SelfChams): ()
	local material = self:material()
	local color = self:color()
	local transparency = self:transparency()

	for part in next, self._store do
		chamsUtil.apply(self._store, part, material, color, transparency)
	end
end

function base.Enable(self: SelfChams): ()
	if self._activeJanitor then
		return
	end

	self._enabled = true

	local janitor = Janitor.new()
	self._activeJanitor = janitor

	local scheduled = false
	local function schedule(): ()
		if scheduled then
			return
		end
		scheduled = true
		task.defer(function(): ()
			scheduled = false
			if self._enabled then
				self:rescan()
			end
		end)
	end

	local function rewatch(charObject: any): ()
		if self._watchCleanup then
			self._watchCleanup()
			self._watchCleanup = nil
		end
		if charObject and self._config.watch then
			self._watchCleanup = self._config.watch(charObject, schedule)
		end
	end

	janitor:Add(sub(clientState.charObject, function(charObject: any): ()
		rewatch(charObject)
		schedule()
	end), true)

	janitor:Add(sub(thirdPersonState.active, schedule), true)
	janitor:Add(sub(thirdPersonState.clone, schedule), true)
	janitor:Add(sub(thirdPersonState.revision, schedule), true)

	local colorPicker: any = self._opts:Get("color")
	if colorPicker then
		janitor:Add(colorPicker:OnUpdate(function(): ()
			self:reapply()
		end), true)
	end

	local materialEl: any = self._opts:Get("material")
	if materialEl then
		janitor:Add(materialEl:OnChange(function(): ()
			self:reapply()
		end), true)
	end

	janitor:Add(function(): ()
		if self._watchCleanup then
			self._watchCleanup()
			self._watchCleanup = nil
		end
		chamsUtil.restoreAll(self._store)
	end, true)

	rewatch(peek(clientState.charObject))
	self:rescan()
end

function base.Disable(self: SelfChams): ()
	self._enabled = false
	local janitor = self._activeJanitor
	if janitor then
		janitor:Destroy()
		self._activeJanitor = nil
	end
end

function base.Destroy(self: SelfChams): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

return base
