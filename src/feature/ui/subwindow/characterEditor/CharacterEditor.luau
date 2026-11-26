local Charm = require("@pkg/Charm")
local React = require("@pkg/React")

local Subwindow = require("@ui/subwindow/Subwindow")
local Slider = require("@ui/window/element/slider/Slider")
local renderer = require("@ui/subwindow/characterEditor/renderer")
local catalog = require("@ui/subwindow/characterEditor/catalog")
local characterDescription = require("@game/universal/feature/misc/characterDescription")

local HttpService = game:GetService("HttpService")

local at = Charm.atom
local sub = Charm.subscribe
local peek = Charm.peek
local e = React.createElement

local DEFAULT_BODY_COLOR = Color3.fromRGB(163, 162, 165)

export type OpenOptions = {
	source: any,
	name: string?,
	userId: number?,
	userInput: string?,
	load: boolean?,
	colorpicker: any?,
}

type ScaleConfig = { key: string, label: string, min: number, max: number, step: number, default: number }
type SliderEntry = { key: string, label: string, default: number, slider: Slider.Slider }
type ColorConfig = { keys: { string }, label: string }
type ColorEntry = { keys: { string }, label: string, picker: any }

local SCALES: { ScaleConfig } = {
	{ key = "HeightScale", label = "Height", min = 0.7, max = 1.3, step = 0.01, default = 1 },
	{ key = "WidthScale", label = "Width", min = 0.7, max = 1.3, step = 0.01, default = 1 },
	{ key = "HeadScale", label = "Head", min = 0.7, max = 1.3, step = 0.01, default = 1 },
	{ key = "BodyTypeScale", label = "Body Type", min = 0, max = 1, step = 0.01, default = 0 },
	{ key = "ProportionScale", label = "Proportion", min = 0, max = 1, step = 0.01, default = 0 },
	{ key = "DepthScale", label = "Depth", min = 0.7, max = 1.3, step = 0.01, default = 1 },
}

local BODY_COLORS: { ColorConfig } = {
	{ keys = { "HeadColor" }, label = "Head" },
	{ keys = { "TorsoColor" }, label = "Torso" },
	{ keys = { "LeftArmColor", "RightArmColor" }, label = "Arms" },
	{ keys = { "LeftLegColor", "RightLegColor" }, label = "Legs" },
}

local ALL_PART_KEYS = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Face" }

local STRING_ACCESSORY_KEYS = {
	"HatAccessory",
	"HairAccessory",
	"FaceAccessory",
	"NeckAccessory",
	"ShouldersAccessory",
	"FrontAccessory",
	"BackAccessory",
	"WaistAccessory",
}

local CLOTHING_NUMBER_KEYS = {
	"Shirt",
	"Pants",
	"GraphicTShirt",
	"Face",
	"Head",
	"Torso",
	"LeftArm",
	"RightArm",
	"LeftLeg",
	"RightLeg",
}

local MAX_ACCESSORIES = 10

local UNIFY_PART: { [string]: { string } } = {
	LeftArm = { "LeftArm", "RightArm" },
	RightArm = { "LeftArm", "RightArm" },
	LeftLeg = { "LeftLeg", "RightLeg" },
	RightLeg = { "LeftLeg", "RightLeg" },
}

local function defaultSortId(): string
	if catalog.getSort("relevance") then
		return "relevance"
	end
	local first = catalog.SORT_OPTIONS[1]
	return first and first.id or ""
end

local function resolveColor(color: Color3 | ColorSequence): Color3?
	if typeof(color) == "ColorSequence" then
		local keypoints = (color :: ColorSequence).Keypoints
		return keypoints[1] and keypoints[1].Value or nil
	end
	if typeof(color) == "Color3" then
		return color :: Color3
	end
	return nil
end

local CharacterEditor = {}
CharacterEditor.__index = CharacterEditor

setmetatable(CharacterEditor, { __index = Subwindow })

local function constructor(): CharacterEditor
	local self = Subwindow.new() :: any
	setmetatable(self, CharacterEditor)

	self._title = at("Character Editor")
	self._subtitle = at("Browse the catalog and shape your avatar.")
	self._source = at(nil :: any)
	self._name = at("")
	self._importField = at("")
	self._manifest = at({ version = 1 } :: { [string]: any })
	self._error = at(nil :: string?)
	self._errorNonce = at(0)
	self._busy = at(false)
	self._searchField = at("")
	self._searchResults = at({} :: { catalog.CatalogResult })
	self._searchError = at(nil :: string?)
	self._searchErrorNonce = at(0)
	self._searching = at(false)
	self._searchFinished = at(false)
	self._loadingMore = at(false)
	self._searchPages = nil :: any
	self._searchToken = nil :: any
	self._nameToken = nil :: any
	self._openKey = nil :: any
	self._loadName = nil :: string?
	self._sortId = at(defaultSortId())
	self._group = at(catalog.GROUPS[1].id)
	self._category = at(catalog.GROUPS[1].tabs[1].id)

	self._syncing = false
	self._sliders = {} :: { SliderEntry }
	for i = 1, #SCALES do
		local config = SCALES[i]
		local slider = Slider(config.label, config.default, config.min, config.max, config.step)
		local entry: SliderEntry = { key = config.key, label = config.label, default = config.default, slider = slider }
		self._sliders[i] = entry
		sub(slider._state, function(value: number): ()
			if self._syncing then
				return
			end
			self:SetField(config.key, value)
		end)
	end

	self._colors = {} :: { ColorEntry }
	self._allColor = nil :: any
	self._colorsReady = at(false)
	self._colorpickerCtor = nil :: any
	self._rigType = at("R15")

	return self
end

function CharacterEditor.SetRigType(self: CharacterEditor, rigType: string): ()
	self._rigType(rigType)
end

function CharacterEditor._setError(self: CharacterEditor, msg: string?): ()
	local errorAtom = self._error
	errorAtom(msg)
	if msg then
		local nonce = peek(self._errorNonce) + 1
		self._errorNonce(nonce)
		task.delay(3.05, function(): ()
			if peek(self._errorNonce) == nonce then
				errorAtom(nil)
			end
		end)
	end
end

function CharacterEditor._ensureColors(self: CharacterEditor): ()
	if #self._colors > 0 then
		return
	end
	local Colorpicker = self._colorpickerCtor
	if not Colorpicker then
		return
	end
	local entries = self._colors :: { ColorEntry }
	for i = 1, #BODY_COLORS do
		local config = BODY_COLORS[i]
		local picker = Colorpicker(config.label, DEFAULT_BODY_COLOR)
		entries[i] = { keys = config.keys, label = config.label, picker = picker }
		picker:OnColorChange(function(color: Color3 | ColorSequence): ()
			if self._syncing then
				return
			end
			local resolved = resolveColor(color)
			if resolved then
				local value =
					{ math.round(resolved.R * 255), math.round(resolved.G * 255), math.round(resolved.B * 255) }
				for k = 1, #config.keys do
					self:SetField(config.keys[k], value)
				end
			end
		end)
	end

	self._allColor = Colorpicker("All", DEFAULT_BODY_COLOR)
	self._allColor:OnColorChange(function(color: Color3 | ColorSequence): ()
		if self._syncing then
			return
		end
		local resolved = resolveColor(color)
		if not resolved then
			return
		end
		for i = 1, #entries do
			entries[i].picker:SetState(resolved)
		end
	end)

	self._colorsReady(true)
end

function CharacterEditor._syncSliders(self: CharacterEditor, manifest: { [string]: any }?): ()
	self._syncing = true
	local entries = self._sliders :: { SliderEntry }
	for i = 1, #entries do
		local entry = entries[i]
		local value = manifest and manifest[entry.key]
		entry.slider:SetValue(type(value) == "number" and value or entry.default)
	end
	self._syncing = false
end

function CharacterEditor._syncColors(self: CharacterEditor, manifest: { [string]: any }?): ()
	local entries = self._colors :: { ColorEntry }
	if #entries == 0 then
		return
	end
	self._syncing = true
	for i = 1, #entries do
		local entry = entries[i]
		local value = manifest and manifest[entry.keys[1]]
		if type(value) == "table" and #value >= 3 then
			entry.picker:SetState(Color3.fromRGB(value[1], value[2], value[3]))
		else
			entry.picker:SetState(DEFAULT_BODY_COLOR)
		end
	end
	local head = manifest and manifest.HeadColor
	if type(head) == "table" and #head >= 3 then
		self._allColor:SetState(Color3.fromRGB(head[1], head[2], head[3]))
	else
		self._allColor:SetState(DEFAULT_BODY_COLOR)
	end
	self._syncing = false
end

function CharacterEditor.Open(self: CharacterEditor, opts: OpenOptions): ()
	if opts.colorpicker then
		self._colorpickerCtor = opts.colorpicker
	end
	self:_ensureColors()

	local basePath = opts.source and opts.source._basePath or ""
	local key = `{tostring(basePath)}|{opts.name or ""}|{tostring(opts.userId)}`

	self._source(opts.source)
	self:SetPosition(UDim2.fromScale(0.5, 0.5))
	self:SetOpen(true)

	if not opts.load and key == self._openKey then
		if #peek(self._searchResults) == 0 and not peek(self._searching) then
			self:Search()
		end
		return
	end
	self._openKey = if opts.load then nil else key

	self._name(opts.name or "")
	self:_setError(nil)
	self._busy(false)
	self._importField("")
	self._searchField("")
	self._searchResults({})
	self._searching(false)
	self._searchFinished(false)
	self._loadingMore(false)
	self._searchPages = nil
	self._nameToken = nil
	self._loadName = if opts.load then opts.name or "" else nil
	self._sortId(defaultSortId())
	self._group(catalog.GROUPS[1].id)
	self._category(catalog.GROUPS[1].tabs[1].id)

	local loaded = false
	if opts.load then
		loaded = self:_loadFromFile(opts.source, opts.name or "")
	end
	if not loaded then
		self._manifest({ version = 1 })
	end
	local manifest = peek(self._manifest)
	self:_syncSliders(manifest)
	self:_syncColors(manifest)
	if loaded then
		self:_resolveNames(manifest)
	end

	if not loaded then
		if opts.userId then
			self:Import(opts.userId)
		elseif opts.userInput and opts.userInput ~= "" then
			self:ImportFromInput(opts.userInput)
		end
	end
	self:Search()
end

function CharacterEditor._loadFromFile(self: CharacterEditor, source: any, name: string): boolean
	if not source or not readfile or not isfile then
		return false
	end
	local path = `{source._basePath}/{name}.json`
	if not isfile(path) then
		return false
	end
	local ok, contents = pcall(readfile, path)
	if not ok or type(contents) ~= "string" then
		return false
	end
	local decodeOk, manifest = pcall(function(): any
		return HttpService:JSONDecode(contents)
	end)
	if not decodeOk or type(manifest) ~= "table" then
		return false
	end
	self._manifest(manifest)
	return true
end

function CharacterEditor.SetName(self: CharacterEditor, name: string): ()
	self._name(name)
end

function CharacterEditor.SetImportField(self: CharacterEditor, value: string): ()
	self._importField(value)
end

function CharacterEditor.SetField(self: CharacterEditor, key: string, value: any): ()
	local updated = table.clone(peek(self._manifest))
	updated[key] = value
	self._manifest(updated)
end

function CharacterEditor._resolveNames(self: CharacterEditor, manifest: { [string]: any }): ()
	local names = manifest.itemNames
	local seen: { [number]: boolean } = {}
	local missing: { number } = {}
	local function want(id: any): ()
		if type(id) ~= "number" or id <= 0 or seen[id] then
			return
		end
		seen[id] = true
		if type(names) == "table" and names[tostring(id)] then
			return
		end
		missing[#missing + 1] = id
	end

	local accessories = manifest.accessories
	if type(accessories) == "table" then
		for i = 1, #accessories do
			want(accessories[i].AssetId)
		end
	end
	for i = 1, #STRING_ACCESSORY_KEYS do
		local raw = manifest[STRING_ACCESSORY_KEYS[i]]
		if type(raw) == "string" then
			for token in string.gmatch(raw, "%d+") do
				want(tonumber(token))
			end
		end
	end
	for i = 1, #CLOTHING_NUMBER_KEYS do
		want(manifest[CLOTHING_NUMBER_KEYS[i]])
	end

	if #missing == 0 then
		return
	end

	local token = {}
	self._nameToken = token
	task.spawn(function(): ()
		setthreadidentity(8)
		local resolved: { [string]: string } = {}
		for i = 1, #missing do
			if self._nameToken ~= token then
				return
			end
			local name = characterDescription.getAssetName(missing[i])
			if name then
				resolved[tostring(missing[i])] = name
			end
		end
		if self._nameToken ~= token or not next(resolved) then
			return
		end
		local current = table.clone(peek(self._manifest))
		local merged = table.clone(current.itemNames or {})
		for key, value in next, resolved do
			merged[key] = value
		end
		current.itemNames = merged
		self._manifest(current)
	end)
end

function CharacterEditor.Import(self: CharacterEditor, userId: number): ()
	self._busy(true)
	self:_setError(nil)
	task.spawn(function(): ()
		setthreadidentity(8)
		local desc = characterDescription.fromUserId(userId)
		self._busy(false)
		if not desc then
			self:_setError("Could not import that avatar.")
			return
		end
		local manifest = characterDescription.serialize(desc)
		manifest.userId = userId
		self._manifest(manifest)
		self:_syncSliders(manifest)
		self:_syncColors(manifest)
		self:_resolveNames(manifest)
	end)
end

function CharacterEditor.ImportFromInput(self: CharacterEditor, input: string): ()
	self._busy(true)
	self:_setError(nil)
	task.spawn(function(): ()
		setthreadidentity(8)
		local userId, err = characterDescription.resolveUser(input)
		if not userId then
			self._busy(false)
			self:_setError(err or "No Roblox user found.")
			return
		end
		local desc = characterDescription.fromUserId(userId)
		self._busy(false)
		if not desc then
			self:_setError("Could not import that avatar.")
			return
		end
		local manifest = characterDescription.serialize(desc)
		manifest.userId = userId
		self._manifest(manifest)
		self:_syncSliders(manifest)
		self:_syncColors(manifest)
		self:_resolveNames(manifest)
	end)
end

function CharacterEditor.SetSearchField(self: CharacterEditor, value: string): ()
	self._searchField(value)
end

function CharacterEditor.SelectGroup(self: CharacterEditor, id: string): ()
	self._group(id)
	local group = catalog.getGroup(id)
	if group and group.tabs[1] then
		self._category(group.tabs[1].id)
	end
	self:Search()
end

function CharacterEditor.SelectTab(self: CharacterEditor, id: string): ()
	self._category(id)
	self:Search()
end

function CharacterEditor.SetSort(self: CharacterEditor, id: string): ()
	self._sortId(id)
	self:Search()
end

function CharacterEditor.Search(self: CharacterEditor): ()
	local keyword = string.match(peek(self._searchField), "^%s*(.-)%s*$") or ""
	local tab = catalog.getTab(peek(self._category))
	local assetTypes = tab and tab.assetTypes
	local bundleTypes = tab and tab.bundleTypes
	if keyword == "" and tab and tab.keyword then
		keyword = tab.keyword
	end
	local hasAssetTypes = assetTypes and #assetTypes > 0
	local hasBundleTypes = bundleTypes and #bundleTypes > 0
	if keyword == "" and not hasAssetTypes and not hasBundleTypes then
		return
	end
	local sortType = catalog.getSort(peek(self._sortId))
	self._searching(true)
	self._searchPages = nil
	self._searchFinished(false)
	self._searchError(nil)
	local token = {}
	self._searchToken = token
	task.spawn(function(): ()
		local results, err, pages = catalog.search(keyword, assetTypes, bundleTypes, sortType)
		if self._searchToken ~= token then
			return
		end
		self._searching(false)
		self._searchResults(results)
		self._searchError(err)
		if err then
			self._searchErrorNonce(peek(self._searchErrorNonce) + 1)
		end
		self._searchPages = pages
		self._searchFinished(pages == nil)
	end)
end

function CharacterEditor.LoadMore(self: CharacterEditor): ()
	local pages = self._searchPages
	if not pages or peek(self._loadingMore) or peek(self._searchFinished) then
		return
	end
	self._loadingMore(true)
	local token = self._searchToken
	task.spawn(function(): ()
		local more, finished, err = catalog.loadMore(pages)
		self._loadingMore(false)
		if self._searchToken ~= token then
			return
		end
		if err then
			self._searchError(err)
			self._searchErrorNonce(peek(self._searchErrorNonce) + 1)
		end
		if #more > 0 then
			local existing = peek(self._searchResults)
			local combined = table.clone(existing)
			for i = 1, #more do
				combined[#combined + 1] = more[i]
			end
			self._searchResults(combined)
		end
		self._searchFinished(finished)
	end)
end

function CharacterEditor._applyBundleParts(
	self: CharacterEditor,
	item: catalog.CatalogResult,
	parts: { [string]: number },
	applyParts: { string }?
): ()
	if not next(parts) then
		self:_setError("That pack has no body parts.")
		return
	end
	local manifest = table.clone(peek(self._manifest))
	local names = table.clone(manifest.itemNames or {})
	manifest.itemNames = names
	local applied = false
	if applyParts then
		for k = 1, #applyParts do
			local key = applyParts[k]
			if parts[key] then
				manifest[key] = parts[key]
				if item.name then
					names[tostring(parts[key])] = item.name
				end
				applied = true
			end
		end
	else
		for k = 1, #ALL_PART_KEYS do
			local key = ALL_PART_KEYS[k]
			if parts[key] then
				manifest[key] = parts[key]
				if item.name then
					names[tostring(parts[key])] = item.name
				end
				applied = true
			end
		end
	end
	if applied then
		self._manifest(manifest)
		self:_setError(nil)
	else
		self:_setError("That pack doesn't include those parts.")
	end
end

function CharacterEditor._addBundle(self: CharacterEditor, item: catalog.CatalogResult): ()
	local tab = catalog.getTab(peek(self._category))
	local applyParts = tab and tab.applyParts

	local parts = catalog.resolveBundleParts(item)
	if parts then
		self:_applyBundleParts(item, parts, applyParts)
		return
	end

	self._busy(true)
	task.spawn(function(): ()
		setthreadidentity(8)
		local fetched = catalog.fetchBundleParts(item)
		self._busy(false)
		self:_applyBundleParts(item, fetched, applyParts)
	end)
end

function CharacterEditor.AddCatalogItem(self: CharacterEditor, item: catalog.CatalogResult): ()
	if item.isBundle then
		self:_addBundle(item)
		return
	end
	local id = item.id
	local info = catalog.classify(item.assetTypeName)
	local manifest = table.clone(peek(self._manifest))
	local names = table.clone(manifest.itemNames or {})
	if item.name then
		names[tostring(id)] = item.name
	end
	manifest.itemNames = names
	if info.kind == "accessory" then
		local list: { any } = {}
		local existing = manifest.accessories
		if type(existing) == "table" then
			for i = 1, #existing do
				if existing[i].AssetId == id then
					self:_setError("That item is already added.")
					return
				end
				list[i] = existing[i]
			end
		end
		if #list >= MAX_ACCESSORIES then
			self:_setError(`Accessory limit reached ({MAX_ACCESSORIES}).`)
			return
		end
		list[#list + 1] = { AccessoryType = info.accessoryType, AssetId = id, IsLayered = info.isLayered == true }
		manifest.accessories = list
	elseif info.kind == "clothing" then
		local key = info.clothingKey :: string
		local unify = UNIFY_PART[key]
		if unify then
			for u = 1, #unify do
				manifest[unify[u]] = id
			end
		else
			manifest[key] = id
		end
	else
		self:_setError("That item type can't be added.")
		return
	end
	self._manifest(manifest)
	self:_setError(nil)
end

function CharacterEditor._removeBundle(self: CharacterEditor, item: catalog.CatalogResult): ()
	local parts = catalog.resolveBundleParts(item)
	if not parts or not next(parts) then
		return
	end
	local manifest = table.clone(peek(self._manifest))
	for key, id in next, parts do
		if manifest[key] == id then
			manifest[key] = nil
		end
	end
	self._manifest(manifest)
	self:_setError(nil)
end

function CharacterEditor.RemoveCatalogItem(self: CharacterEditor, item: catalog.CatalogResult): ()
	if item.isBundle then
		self:_removeBundle(item)
		return
	end
	local info = catalog.classify(item.assetTypeName)
	if info.kind == "accessory" then
		self:RemoveWornAsset(item.id)
	elseif info.kind == "clothing" then
		local key = info.clothingKey :: string
		local manifest = table.clone(peek(self._manifest))
		local unify = UNIFY_PART[key]
		if unify then
			for u = 1, #unify do
				if manifest[unify[u]] == item.id then
					manifest[unify[u]] = nil
				end
			end
		elseif manifest[key] == item.id then
			manifest[key] = nil
		end
		self._manifest(manifest)
	end
	self:_setError(nil)
end

function CharacterEditor.RemoveWornAsset(self: CharacterEditor, assetId: number): ()
	local manifest = table.clone(peek(self._manifest))
	local existing = manifest.accessories
	if type(existing) == "table" then
		local list: { any } = {}
		for i = 1, #existing do
			if existing[i].AssetId ~= assetId then
				list[#list + 1] = existing[i]
			end
		end
		manifest.accessories = list
	end
	for i = 1, #STRING_ACCESSORY_KEYS do
		local key = STRING_ACCESSORY_KEYS[i]
		local raw = manifest[key]
		if type(raw) == "string" and raw ~= "" then
			local kept: { string } = {}
			for token in string.gmatch(raw, "%d+") do
				if tonumber(token) ~= assetId then
					kept[#kept + 1] = token
				end
			end
			manifest[key] = #kept > 0 and table.concat(kept, ",") or nil
		end
	end
	self._manifest(manifest)
end

function CharacterEditor.RemoveClothing(self: CharacterEditor, key: string): ()
	local manifest = table.clone(peek(self._manifest))
	manifest[key] = nil
	self._manifest(manifest)
end

function CharacterEditor.Save(self: CharacterEditor): ()
	local source = peek(self._source)
	if not source then
		return
	end
	if not writefile then
		self:_setError("Your executor cannot write files.")
		return
	end

	local name = string.match(peek(self._name), "^%s*(.-)%s*$") or ""
	name = string.gsub(name, "%.json$", "")
	if name == "" then
		self:_setError("This character needs a name. Set one in the picker before opening the editor.")
		return
	end
	if string.find(name, '[<>:"/\\|%?%*]') then
		self:_setError("The name contains characters that cannot be used in a file.")
		return
	end

	local manifest = table.clone(peek(self._manifest))
	manifest.name = name

	local encodeOk, encoded = pcall(function(): string
		return HttpService:JSONEncode(manifest)
	end)
	if not encodeOk then
		self:_setError("The character could not be encoded.")
		return
	end

	local path = `{source._basePath}/{name}.json`
	local writeOk = pcall(writefile, path, encoded)
	if not writeOk then
		self:_setError("The character could not be saved.")
		return
	end

	local loadName = self._loadName
	if loadName and loadName ~= name and delfile then
		pcall(delfile, `{source._basePath}/{loadName}.json`)
	end
	self._loadName = name

	if source.Refresh then
		source:Refresh()
	end
	if source.IsSingleSelect and source:IsSingleSelect() then
		source:Select(name)
	end
	self:SetOpen(false)
end

function CharacterEditor.Cancel(self: CharacterEditor): ()
	self:SetOpen(false)
end

function CharacterEditor.Render(self: CharacterEditor): React.Element<any>
	return e(renderer, { Editor = self })
end

export type CharacterEditor =
	typeof(setmetatable(
		{} :: {
			_title: Charm.Atom<string>,
			_subtitle: Charm.Atom<string>,
			_source: Charm.Atom<any>,
			_name: Charm.Atom<string>,
			_importField: Charm.Atom<string>,
			_manifest: Charm.Atom<{ [string]: any }>,
			_error: Charm.Atom<string?>,
			_errorNonce: Charm.Atom<number>,
			_busy: Charm.Atom<boolean>,
			_searchField: Charm.Atom<string>,
			_searchResults: Charm.Atom<{ catalog.CatalogResult }>,
			_searchError: Charm.Atom<string?>,
			_searchErrorNonce: Charm.Atom<number>,
			_searching: Charm.Atom<boolean>,
			_searchFinished: Charm.Atom<boolean>,
			_loadingMore: Charm.Atom<boolean>,
			_searchPages: any,
			_searchToken: any,
			_nameToken: any,
			_openKey: any,
			_loadName: string?,
			_sortId: Charm.Atom<string>,
			_group: Charm.Atom<string>,
			_category: Charm.Atom<string>,
			_syncing: boolean,
			_sliders: { SliderEntry },
			_colors: { ColorEntry },
			_allColor: any,
			_colorsReady: Charm.Atom<boolean>,
			_colorpickerCtor: any,
			_rigType: Charm.Atom<string>,
		},
		CharacterEditor
	))
	& Subwindow.Subwindow

return constructor
