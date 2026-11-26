local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")

local Element = require("@ui/window/element/Element")
local SubwindowController = require("@ui/subwindow/SubwindowController")
local FileController = require("@feature/file/FileController")
local fileTypes = require("@feature/file/fileTypes")
local fileExtensions = require("@feature/file/modules/fileExtensions")
local registry = require("@ui/window/element/registry")
local renderer = require("@ui/window/element/assetpicker/renderer")

local at = Charm.atom
local peek = Charm.peek
local e = React.createElement

local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")

export type AssignmentType = {
	key: string,
	label: string,
	icon: string?,
	tip: string?,
	extras: { ExtraSpec }?,
}

export type ExtraSpec = {
	type: string,
	key: string,
	args: { any }?,
}

export type BundleSpec = {
	urlPrefix: string,
	files: { string | { remote: string, name: string } },
	title: string?,
	icon: string?,
}

export type CreatorField = {
	key: string,
	label: string,
	placeholder: string?,
	default: string?,
	required: boolean?,
	kind: "text" | "number" | "select" | "button"?,
	options: { string }?,
	buttonText: string?,
	primary: boolean?,
	visibleWhen: ((values: { [string]: string }) -> boolean)?,
	onClick: ((source: any, values: { [string]: string }) -> ())?,
}

export type CreatorSpec = {
	title: string?,
	description: string?,
	fields: { CreatorField },
	build: ((values: { [string]: string }, name: string) -> (any?, string?))?,
	create: ((source: any, values: { [string]: string }, name: string) -> (string?, string?))?,
	loadValues: ((manifest: any) -> { [string]: any }?)?,
}

export type AssetPickerConfig = {
	assetType: string,
	category: string?,
	basePath: string?,
	assignmentTypes: { AssignmentType }?,
	bundle: BundleSpec?,
	creator: CreatorSpec?,
	extensions: { string }?,
	previewBehavior: ((source: AssetPicker, name: string, path: string) -> ())?,
	stopPreview: ((source: AssetPicker) -> ())?,
	previewImage: ((source: AssetPicker, name: string, path: string) -> string?)?,
	onEditAsset: ((source: AssetPicker, name: string) -> ())?,
	editLabel: string?,
	width: number?,
}

local SINGLE_SELECT_KEY = "__selected__"

local SOUND_FILE_TYPE = "sound"
local IMAGE_FILE_TYPE = "image"

local function fileTypeForAssetType(assetType: string): string
	if assetType == "sounds" then
		return SOUND_FILE_TYPE
	end
	if assetType == "images" then
		return IMAGE_FILE_TYPE
	end
	return assetType
end

local function basePathFor(assetType: string, category: string): string
	return `limerence.biz/assets/{assetType}/{category}`
end

local AssetPicker = {}
AssetPicker.__index = AssetPicker

setmetatable(AssetPicker, { __index = Element })

local function constructor(text: string, config: AssetPickerConfig): AssetPicker
	local self = Element.new(text) :: any
	setmetatable(self, AssetPicker)

	self._config = config
	self._assetType = config.assetType
	self._category = config.category or ""
	self._fileType = fileTypeForAssetType(config.assetType)
	if config.basePath then
		self._basePath = config.basePath
	elseif config.category and config.category ~= "" then
		self._basePath = basePathFor(config.assetType, config.category)
	else
		self._basePath = `limerence.biz/assets/{config.assetType}`
	end
	self._extensions = config.extensions

	self._assetNames = at({} :: { string })
	self._assetByName = {} :: { [string]: { name: string, path: string, fullName: string } }
	self._previewCache = {} :: { [string]: string? }
	self._previewCacheBuilt = {} :: { [string]: boolean }
	self._previewBuilding = {} :: { [string]: boolean }
	self._previewVersion = at(0)
	self._defaultAssetNames = {} :: { [string]: boolean }
	self._removingAssets = at({} :: { [string]: boolean })
	self._focusedAsset = at(nil :: string?)

	local assignmentTypes = config.assignmentTypes or {}
	self._assignmentTypes = assignmentTypes
	self._singleSelect = #assignmentTypes == 0
	self._state({} :: { [string]: string? })
	self._open = at(false)

	self._extrasByKey = {} :: { [string]: { any } }
	self._extraByKey = {} :: { [string]: { [string]: any } }

	for _, assignType in next, assignmentTypes do
		local list: { any } = {}
		local lookup: { [string]: any } = {}
		if assignType.extras then
			for _, spec in next, assignType.extras do
				local factory = registry[spec.type]
				if factory then
					local element = factory(table.unpack(spec.args or {}))
					table.insert(list, element)
					lookup[spec.key] = element
				end
			end
		end
		self._extrasByKey[assignType.key] = list
		self._extraByKey[assignType.key] = lookup
	end

	self._activeSound = nil :: Sound?

	if isfolder and makefolder and not isfolder(self._basePath) then
		makefolder(self._basePath)
	end

	if config.bundle then
		local bundle = config.bundle
		local files: { { remote: string, name: string } } = {}
		for _, entry in next, bundle.files do
			if type(entry) == "string" then
				table.insert(files, { remote = entry, name = entry })
			else
				table.insert(files, entry)
			end
		end
		for _, entry in next, files do
			local defaultName = fileExtensions.getNameFromPath(entry.name)
			if defaultName then
				self._defaultAssetNames[defaultName] = true
			end
		end

		local categoryId = (config.category and config.category ~= "") and config.category or config.assetType
		FileController.QueueDownload({
			id = `assetpicker.{config.assetType}.{categoryId}`,
			title = bundle.title or `Downloading {categoryId}`,
			icon = bundle.icon,
			urlPrefix = bundle.urlPrefix,
			folder = self._basePath,
			files = files,
			onComplete = function(): ()
				self:Refresh()
			end,
		})
	end

	self:Refresh()

	return self
end

function AssetPicker.Refresh(self: AssetPicker): ()
	if not listfiles or not isfolder or not isfolder(self._basePath) then
		self._assetNames({})
		self._previewCache = {}
		self._previewCacheBuilt = {}
		self._previewBuilding = {}
		return
	end

	local list: { string } = {}
	self._assetByName = {}
	self._previewCache = {}
	self._previewCacheBuilt = {}
	self._previewBuilding = {}

	local extFilter = self._extensions
	local extLookup: { [string]: boolean }? = nil
	if extFilter then
		extLookup = {}
		for _, ext in next, extFilter do
			(extLookup :: any)[string.lower(ext)] = true
		end
	end

	local ok, results = pcall(listfiles, self._basePath)
	if ok and type(results) == "table" then
		for _, raw in next, results do
			local full = ((raw :: string):gsub("\\", "/"))
			local fullName = fileExtensions.getFullNameFromPath(full)
			local name = fileExtensions.getNameFromPath(full)
			local ext = fileExtensions.getExtensionFromPath(full)
			if not name or not ext then
				continue
			end
			if extLookup then
				if not (extLookup :: any)[string.lower(ext)] then
					continue
				end
			else
				local extType = fileExtensions[ext]
				if extType ~= self._fileType then
					continue
				end
			end

			local normalizedPath = `{self._basePath}/{fullName}`
			self._assetByName[name] = {
				name = name,
				path = normalizedPath,
				fullName = fullName :: string,
			}
			table.insert(list, name)
		end
	end

	table.sort(list)
	self._assetNames(list)
	local focused = peek(self._focusedAsset)
	if focused and not self._assetByName[focused] then
		self._focusedAsset(nil)
	end
end

function AssetPicker.GetCreator(self: AssetPicker): CreatorSpec?
	return self._config.creator
end

function AssetPicker.CanEditAsset(self: AssetPicker, name: string?): boolean
	return self:IsCustomAsset(name)
end

function AssetPicker.HasCustomEditor(self: AssetPicker): boolean
	return self._config.onEditAsset ~= nil
end

function AssetPicker.EditAsset(self: AssetPicker, name: string): ()
	local onEdit = self._config.onEditAsset
	if onEdit and self:IsCustomAsset(name) then
		onEdit(self, name)
	end
end

function AssetPicker.GetEditValues(self: AssetPicker, name: string): { [string]: string }?
	local entry = self._assetByName[name]
	if not entry then
		return nil
	end
	local values: { [string]: string } = { name = name }
	if not (isfile and readfile and isfile(entry.path)) then
		return values
	end
	local ok, raw = pcall(readfile, entry.path)
	if not ok or type(raw) ~= "string" then
		return values
	end
	local decodeOk, manifest = pcall(function(): any
		return HttpService:JSONDecode(raw)
	end)
	if not decodeOk or type(manifest) ~= "table" then
		return values
	end
	local creator = self._config.creator
	local stored = manifest.__values
	if type(stored) == "table" then
		for key, value in next, stored do
			values[key] = tostring(value)
		end
	elseif creator and creator.loadValues then
		local loadOk, loaded = pcall(creator.loadValues, manifest)
		if loadOk and type(loaded) == "table" then
			for key, value in next, loaded do
				values[key] = tostring(value)
			end
		end
	elseif creator then
		for _, field in next, creator.fields do
			local mv = manifest[field.key]
			if mv ~= nil then
				values[field.key] = tostring(mv)
			end
		end
	end
	values.name = name
	return values
end

function AssetPicker.IsCustomAsset(self: AssetPicker, name: string?): boolean
	return name ~= nil
		and self._config.creator ~= nil
		and self._assetByName[name] ~= nil
		and not self._defaultAssetNames[name]
end

function AssetPicker.FocusAsset(self: AssetPicker, name: string?): ()
	self._focusedAsset(name)
end

function AssetPicker.DeleteAsset(self: AssetPicker, name: string): (boolean, string)
	if not self:IsCustomAsset(name) then
		return false, "Default assets cannot be deleted."
	end
	local entry = self._assetByName[name]
	if not entry then
		return false, "The asset could not be found."
	end

	delfile(entry.path)

	self:StopPreview()
	self._removingAssets(Sift.Dictionary.set(peek(self._removingAssets), name, true))
	if self:GetSelected() == name then
		self:Select(nil)
	end
	if peek(self._focusedAsset) == name then
		self._focusedAsset(nil)
	end
	for _, assignType in next, self._assignmentTypes do
		if self:GetAssignment(assignType.key) == name then
			self:Assign(assignType.key, nil)
		end
	end
	task.delay(0.28, function()
		self:Refresh()
		self._removingAssets(Sift.Dictionary.removeKey(peek(self._removingAssets), name))
	end)
	return true, name
end

function AssetPicker.CreateAsset(
	self: AssetPicker,
	nameValue: string,
	values: { [string]: string },
	editOldName: string?
): (boolean, string)
	local creator = self._config.creator
	if not creator then
		return false, "Creation is not available for this asset type."
	end
	if not writefile then
		return false, "Your executor does not support writing files."
	end

	local name = string.match(nameValue, "^%s*(.-)%s*$") or ""
	name = string.gsub(name, "%.json$", "")
	if name == "" then
		return false, "Enter a name for the asset."
	end
	if string.find(name, '[<>:"/\\|%?%*]') then
		return false, "The name contains characters that cannot be used in a file."
	end

	local oldEntry = editOldName and self._assetByName[editOldName] or nil

	local normalized = table.clone(values)
	for _, field in next, creator.fields do
		if field.kind == "button" then
			continue
		end
		if field.visibleWhen and not field.visibleWhen(normalized) then
			continue
		end
		local raw = string.match(normalized[field.key] or "", "^%s*(.-)%s*$") or ""
		normalized[field.key] = raw
		if field.required and raw == "" then
			return false, `{field.label} is required.`
		end
		if field.kind == "number" and raw ~= "" and tonumber(raw) == nil then
			return false, `{field.label} must be a number.`
		end
	end

	if isfolder and makefolder and not isfolder(self._basePath) then
		local folderOk = pcall(makefolder, self._basePath)
		if not folderOk then
			return false, "The asset folder could not be created."
		end
	end
	if creator.create then
		if oldEntry and delfile then
			pcall(delfile, oldEntry.path)
		end
		local createdName, createError = creator.create(self, normalized, name)
		if not createdName then
			return false, createError or "The asset could not be created."
		end
		self:Refresh()
		if self:IsSingleSelect() then
			self:Select(createdName)
		end
		return true, createdName
	end

	local path = `{self._basePath}/{name}.json`
	if isfile and isfile(path) and name ~= editOldName then
		return false, "An asset with that name already exists."
	end

	local manifest: any = nil
	local buildError: string? = nil
	if creator.build then
		local ok, result, message = pcall(creator.build, normalized, name)
		if not ok then
			return false, "The asset could not be generated."
		end
		manifest = result
		buildError = message
	else
		manifest = { name = name }
		for _, field in next, creator.fields do
			local value = normalized[field.key]
			if value ~= "" then
				manifest[field.key] = field.kind == "number" and tonumber(value) or value
			end
		end
	end
	if not manifest then
		return false, buildError or "Check the fields and try again."
	end
	if type(manifest) == "table" then
		manifest.__values = normalized
	end

	local encodedOk, encoded = pcall(function()
		return HttpService:JSONEncode(manifest)
	end)
	if not encodedOk then
		return false, "The asset could not be encoded."
	end
	local writeOk = pcall(writefile, path, encoded)
	if not writeOk then
		return false, "The asset file could not be saved."
	end

	if oldEntry and name ~= editOldName and delfile then
		pcall(delfile, oldEntry.path)
	end

	self:Refresh()
	if self:IsSingleSelect() then
		self:Select(name)
	end
	return true, name
end

function AssetPicker.GetPreviewImage(self: AssetPicker, name: string): string?
	if self._previewCacheBuilt[name] then
		return self._previewCache[name]
	end
	local resolver = self._config.previewImage
	if not resolver then
		self._previewCacheBuilt[name] = true
		return nil
	end
	local entry = self._assetByName[name]
	if not entry then
		return nil
	end
	if self._previewBuilding[name] then
		return nil
	end
	self._previewBuilding[name] = true
	local path = entry.path
	task.spawn(function(): ()
		local ok, result = pcall(resolver, self, name, path)
		self._previewBuilding[name] = nil
		if self._assetByName[name] ~= entry then
			return
		end
		if ok and type(result) == "string" and result ~= "" then
			self._previewCache[name] = result
		else
			self._previewCache[name] = nil
		end
		self._previewCacheBuilt[name] = true
		self._previewVersion(peek(self._previewVersion) + 1)
	end)
	return nil
end

function AssetPicker.GetExtras(self: AssetPicker, assignKey: string): { any }
	return self._extrasByKey[assignKey] or {}
end

function AssetPicker.GetExtra(self: AssetPicker, assignKey: string, extraKey: string): any?
	local lookup = self._extraByKey[assignKey]
	if not lookup then
		return nil
	end
	return lookup[extraKey]
end

function AssetPicker.GetAssignment(self: AssetPicker, assignKey: string): string?
	local current = peek(self._state) or {}
	return current[assignKey]
end

function AssetPicker.GetAssignedPath(self: AssetPicker, assignKey: string): string?
	local name = self:GetAssignment(assignKey)
	if not name then
		return nil
	end
	local entry = self._assetByName[name]
	if entry then
		return entry.path
	end
	return `{self._basePath}/{name}`
end

function AssetPicker.Assign(self: AssetPicker, assignKey: string, assetName: string?): ()
	local current = peek(self._state) or {}
	self._state(Sift.Dictionary.set(current, assignKey, assetName))
end

function AssetPicker.IsSingleSelect(self: AssetPicker): boolean
	return self._singleSelect
end

function AssetPicker.Select(self: AssetPicker, assetName: string?): ()
	self:Assign(SINGLE_SELECT_KEY, assetName)
end

function AssetPicker.GetSelected(self: AssetPicker): string?
	return self:GetAssignment(SINGLE_SELECT_KEY)
end

function AssetPicker.GetSelectedPath(self: AssetPicker): string?
	return self:GetAssignedPath(SINGLE_SELECT_KEY)
end

function AssetPicker.Preview(self: AssetPicker, name: string): ()
	local sub: any = SubwindowController.Get("AssetPicker")

	self:StopPreview()

	if sub then
		sub:SetActivePreview(name)
	end

	local entry = self._assetByName[name]
	if not entry then
		return
	end

	local assetId = FileController.Get(self._fileType, name)
	if not assetId then
		assetId = getcustomasset(entry.path)
	end

	local config = self._config
	if config.previewBehavior then
		config.previewBehavior(self, name, entry.path)
		return
	end

	if self._fileType == SOUND_FILE_TYPE then
		local sound = Instance.new("Sound")
		sound.SoundId = assetId :: string
		local previewVolume = 1
		for _, assignType in next, self._assignmentTypes do
			if self:GetAssignment(assignType.key) == name then
				local volEl = self:GetExtra(assignType.key, "volume")
				if volEl and volEl.Peek then
					local v = volEl:Peek()
					if type(v) == "number" then
						previewVolume = v
					end
				end
				break
			end
		end
		sound.Volume = previewVolume
		sound.Parent = SoundService
		sound:Play()

		self._activeSound = sound

		sound.Ended:Once(function()
			if self._activeSound == sound then
				self._activeSound = nil
				if sub then
					sub:SetActivePreview(nil)
				end
			end
			sound:Destroy()
		end)
	end
end

function AssetPicker.StopPreview(self: AssetPicker): ()
	local config = self._config
	if config.stopPreview then
		config.stopPreview(self)
	elseif self._activeSound then
		self._activeSound:Stop()
		self._activeSound:Destroy()
		self._activeSound = nil
	end

	local sub: any = SubwindowController.Get("AssetPicker")
	if sub then
		sub:SetActivePreview(nil)
	end
end

function AssetPicker.Open(self: AssetPicker, position: UDim2?): ()
	SubwindowController.OpenAssetPicker(self, position)
end

function AssetPicker.AddElement(self: AssetPicker, type: string, ...: any): any?
	local elementType = registry[type]
	if not elementType then
		return nil
	end
	local element = elementType(...)
	local raw = peek(self._extras)
	self._extras(Sift.Array.insert(raw, #raw + 1, element))
	return element
end

function AssetPicker.RenderInternal(self: AssetPicker, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		AssetPicker = self,
		TextRef = props and props.textRef,
		LayoutOrder = props and props.layoutOrder,
	})
end

export type AssetPicker =
	typeof(setmetatable(
		{} :: {
			_config: AssetPickerConfig,
			_assetType: string,
			_category: string,
			_fileType: fileTypes.fileType,
			_basePath: string,
			_extensions: { string }?,
			_assetNames: Charm.Atom<{ string }>,
			_assetByName: { [string]: { name: string, path: string, fullName: string } },
			_previewCache: { [string]: string? },
			_previewCacheBuilt: { [string]: boolean },
			_previewBuilding: { [string]: boolean },
			_previewVersion: Charm.Atom<number>,
			_defaultAssetNames: { [string]: boolean },
			_removingAssets: Charm.Atom<{ [string]: boolean }>,
			_focusedAsset: Charm.Atom<string?>,
			_assignmentTypes: { AssignmentType },
			_singleSelect: boolean,
			_open: Charm.Atom<boolean>,
			_extrasByKey: { [string]: { any } },
			_extraByKey: { [string]: { [string]: any } },
			_activeSound: Sound?,
		},
		AssetPicker
	))
	& Element.Element

return constructor
