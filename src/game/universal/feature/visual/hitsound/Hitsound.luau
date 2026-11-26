local CoreGui = cloneref(gethui())
local Signal = require("@pkg/Signal")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local fileExtensions = require("@feature/file/modules/fileExtensions")

local HITSOUND_CREATOR = {
	title = "New hit sound",
	description = "Import an audio file from a URL or an existing executor workspace path.",
	fields = {
		{ key = "source", label = "Audio", placeholder = "URL or file path", required = true },
	},
	create = function(source, values, name)
		local input = values.source
		local cleanPath = string.match(input, "^[^%?#]+") or input
		local extension = fileExtensions.getExtensionFromPath(cleanPath)
		extension = extension and string.lower(extension) or nil
		if not extension or fileExtensions[extension] ~= "sound" then
			return nil, "Audio must be an MP3, WAV, or OGG file."
		end

		local outputPath = `{source._basePath}/{name}.{extension}`
		if isfile(outputPath) then
			return nil, "An asset with that name already exists."
		end

		local data: string
		if string.find(input, "^https?://") then
			data = game:HttpGet(input)
		elseif isfile(input) then
			data = readfile(input)
		else
			return nil, "The URL or file path could not be found."
		end
		if data == "" then
			return nil, "The audio file is empty."
		end

		writefile(outputPath, data)
		return name
	end,
}

export type HitsoundOpts = {
	pickerConfig: any,
	connect: (play: (kind: string) -> ()) -> Signal.Connection,
	onActive: ((active: boolean, picker: any) -> ())?,
	body: string?,
}

local Hitsound = {}
Hitsound.__index = Hitsound

setmetatable(Hitsound, { __index = BaseFeature })

function Hitsound.new(link: gameUi.Linker, opts: HitsoundOpts): Hitsound
	local self = BaseFeature.new() :: any
	setmetatable(self, Hitsound)

	local toggle = link:Toggle("hitSound", "Hit Sound", false):SetTip({
		title = "Hit Sound",
		body = opts.body or "Plays custom sounds on hit, headshot, and kill. Assign files per slot in the picker.",
	})
	local pickerConfig = table.clone(opts.pickerConfig)
	pickerConfig.creator = HITSOUND_CREATOR
	local picker = link:Extra(toggle, "sounds", "AssetPicker", "Hit sound", pickerConfig)

	self._link = link
	self._enabledLink = toggle
	self._picker = picker
	self._enabled = false
	self._connect = opts.connect
	self._onActive = opts.onActive

	local connection = nil :: Signal.Connection?

	local function setListening(value: boolean): ()
		self._enabled = value

		if connection then
			connection:Disconnect()
			connection = nil
		end

		if self._onActive then
			self._onActive(value, self._picker)
		end

		if value then
			connection = self._connect(function(kind: string): ()
				self:Play(kind)
			end)
		end
	end

	self:Track(toggle:OnChange(setListening))
	self:Track(function(): ()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end)

	if toggle:Peek() then
		setListening(true)
	end

	return self
end

function Hitsound.Play(self: Hitsound, kind: string): ()
	if not self._enabled then
		return
	end

	local picker = self._picker
	if not picker then
		return
	end

	local path = picker:GetAssignedPath(kind)
	if not path then
		return
	end

	local volumeElement = picker:GetExtra(kind, "volume")
	local volume = volumeElement and (volumeElement:Peek() or 0.5) or 0.5

	local sound = Instance.new("Sound")
	sound.SoundId = getcustomasset(path)
	sound.Volume = volume
	sound.Parent = CoreGui
	sound:Play()

	sound.Ended:Once(function(): ()
		sound:Destroy()
	end)
end

function Hitsound.Destroy(self: Hitsound): ()
	if self._onActive then
		self._onActive(false, self._picker)
	end
	BaseFeature.Destroy(self)
end

export type Hitsound =
	typeof(setmetatable(
		{} :: {
			_link: gameUi.Linker,
			_enabledLink: any,
			_picker: any,
			_enabled: boolean,
			_connect: (play: (kind: string) -> ()) -> Signal.Connection,
			_onActive: ((active: boolean, picker: any) -> ())?,
		},
		Hitsound
	))
	& BaseFeature.BaseFeature

return Hitsound
