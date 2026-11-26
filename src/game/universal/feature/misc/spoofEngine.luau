local Players = cloneref(game:GetService("Players")) :: Players
local CoreGui = cloneref(game:GetService("CoreGui")) :: CoreGui
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local Janitor = require("@pkg/Janitor")

local LocalPlayer = Players.LocalPlayer

local spoofEngine = {}

export type FragmentReplacement = {
	from: string,
	to: string,
}

export type ReplacementSet = {
	exactText: { [string]: string },
	textFragments: { FragmentReplacement },
	idFragments: { FragmentReplacement },
	imageIds: { FragmentReplacement },
}

local escapePattern = LPH_NO_VIRTUALIZE(function(value: string): string
	return (string.gsub(value, "([^%w])", "%%%1"))
end)

local stripInvisible = LPH_NO_VIRTUALIZE(function(value: string): string
	if string.find(value, "\243\160", 1, true) == nil then
		return value
	end
	return (string.gsub(value, "\243\160[\128\129][\128-\191]", ""))
end)

local function newSet(): ReplacementSet
	return {
		exactText = {},
		textFragments = {},
		idFragments = {},
		imageIds = {},
	}
end

local addFragment = LPH_NO_VIRTUALIZE(function(list: { FragmentReplacement }, from: string?, to: string?): ()
	if type(from) ~= "string" or type(to) ~= "string" or from == "" or from == to then
		return
	end

	for _, entry in next, list do
		if entry.from == from then
			entry.to = to
			return
		end
	end

	list[#list + 1] = {
		from = from,
		to = to,
	}
end)

local sortFragments = LPH_NO_VIRTUALIZE(function(list: { FragmentReplacement }): ()
	table.sort(list, function(a: FragmentReplacement, b: FragmentReplacement): boolean
		return #a.from > #b.from
	end)
end)

local addExactText = LPH_NO_VIRTUALIZE(function(set: ReplacementSet, from: string?, to: string?): ()
	if type(from) ~= "string" or type(to) ~= "string" or from == "" or from == to then
		return
	end
	set.exactText[from] = to
end)

local addTextReplacement = LPH_NO_VIRTUALIZE(function(set: ReplacementSet, from: string?, to: string?): ()
	if type(from) ~= "string" or type(to) ~= "string" or from == "" or from == to then
		return
	end
	set.exactText[from] = to
	addFragment(set.textFragments, from, to)
end)

local addIdReplacement = LPH_NO_VIRTUALIZE(function(set: ReplacementSet, from: string?, to: string?): ()
	if type(from) ~= "string" or type(to) ~= "string" or from == "" or from == to then
		return
	end
	set.exactText[from] = to
	addFragment(set.idFragments, from, to)
end)

local isWordByte = LPH_NO_VIRTUALIZE(function(value: number?): boolean
	if not value then
		return false
	end
	return (value >= 48 and value <= 57)
		or (value >= 65 and value <= 90)
		or (value >= 97 and value <= 122)
		or value == 95
end)

local isDigitByte = LPH_NO_VIRTUALIZE(function(value: number?): boolean
	if not value then
		return false
	end
	return value >= 48 and value <= 57
end)

local replaceBounded = LPH_NO_VIRTUALIZE(function(value: string, from: string, to: string, numericOnly: boolean): string
	if from == "" or from == to then
		return value
	end

	local nextValue = value
	local searchAt = 1
	while true do
		local startPos, endPos = string.find(nextValue, from, searchAt, true)
		if not startPos then
			break
		end

		local prevByte = startPos > 1 and string.byte(nextValue, startPos - 1) or nil
		local nextByte = endPos < #nextValue and string.byte(nextValue, endPos + 1) or nil

		local boundaryOk: boolean
		if numericOnly then
			boundaryOk = not isDigitByte(prevByte) and not isDigitByte(nextByte)
		else
			boundaryOk = not isWordByte(prevByte) and not isWordByte(nextByte)
		end

		if boundaryOk and string.sub(nextValue, startPos, startPos + #to - 1) == to then
			searchAt = startPos + #to
		elseif boundaryOk then
			nextValue = string.sub(nextValue, 1, startPos - 1) .. to .. string.sub(nextValue, endPos + 1)
			searchAt = startPos + #to
		else
			searchAt = endPos + 1
		end
	end
	return nextValue
end)

local writing = false

local patchText = LPH_NO_VIRTUALIZE(function(replacements: ReplacementSet, inst: Instance): ()
	if not (inst:IsA("TextLabel") or inst:IsA("TextButton")) then
		return
	end

	local textObject = inst :: any
	local text = textObject.Text
	local source = stripInvisible(text)
	local nextText = replacements.exactText[source]
	if not nextText then
		nextText = source
		for _, replacement in next, replacements.textFragments do
			nextText = replaceBounded(nextText, replacement.from, replacement.to, false)
		end
		for _, replacement in next, replacements.idFragments do
			nextText = replaceBounded(nextText, replacement.from, replacement.to, true)
		end
	end

	if nextText ~= text then
		writing = true
		textObject.Text = nextText
		writing = false
	end
end)

local patchImage = LPH_NO_VIRTUALIZE(function(replacements: ReplacementSet, inst: Instance): ()
	if not (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) then
		return
	end

	local imageObject = inst :: any
	local image = imageObject.Image
	local loweredSource = string.lower(image)
	local looksLikeAvatarThumb = string.find(loweredSource, "rbxthumb://type=avatar", 1, true)
		or string.find(loweredSource, "avatar-thumbnail", 1, true)
		or string.find(loweredSource, "headshot-thumbnail", 1, true)
		or string.find(loweredSource, "thumbnails.roblox.com", 1, true)
	if not looksLikeAvatarThumb then
		return
	end

	local nextImage = image
	for _, replacement in next, replacements.imageIds do
		local fromPattern = escapePattern(replacement.from)
		nextImage = string.gsub(nextImage, "([%?&]id=)" .. fromPattern, function(prefix: string): string
			return prefix .. replacement.to
		end)
		nextImage = string.gsub(nextImage, "([%?&]userId=)" .. fromPattern, function(prefix: string): string
			return prefix .. replacement.to
		end)
		nextImage = string.gsub(nextImage, "([%?&]userid=)" .. fromPattern, function(prefix: string): string
			return prefix .. replacement.to
		end)
		nextImage = string.gsub(
			nextImage,
			"(/users/)" .. fromPattern .. "(/)",
			function(prefix: string, suffix: string): string
				return prefix .. replacement.to .. suffix
			end
		)
	end

	if nextImage ~= image then
		writing = true
		imageObject.Image = nextImage
		writing = false
	end
end)

local function patchInstance(replacements: ReplacementSet, inst: Instance): ()
	patchText(replacements, inst)
	patchImage(replacements, inst)
end

local DEFAULT_CHUNK = 150
local GUI_CLASSES = { "GuiLabel", "GuiButton" }

local scanChunked = function(
	containers: { Instance },
	classes: { string },
	visit: (Instance) -> (),
	isAlive: () -> boolean,
	onComplete: (() -> ())?,
	chunkSize: number?
): ()
	local limit = chunkSize or DEFAULT_CHUNK
	task.spawn(LPH_NO_VIRTUALIZE(function(): ()
			local processed = 0
			for i = 1, #containers do
				local container = containers[i]
				for c = 1, #classes do
					local list = container:QueryDescendants(classes[c])
					for d = 1, #list do
						if not isAlive() then
							return
						end
						visit(list[d])
						processed += 1
						if processed >= limit then
							processed = 0
							task.wait()
						end
					end
				end
			end
			if onComplete and isAlive() then
				onComplete()
			end
		end))
	end

local function getPlayerGui(): PlayerGui?
	return LocalPlayer:FindFirstChildOfClass("PlayerGui") :: PlayerGui?
end

local Binder = {}
Binder.__index = Binder

function spoofEngine.new(): Binder
	return setmetatable({
		_replacements = newSet(),
		_boundInstances = setmetatable({}, { __mode = "k" }),
		_janitor = Janitor.new(),
		_patchQueued = false,
		_started = false,
	}, Binder) :: any
end

function Binder.SetReplacements(self: Binder, replacements: ReplacementSet): ()
	self._replacements = replacements
	if self._started then
		self:QueuePatch()
	end
end

function Binder._bindGuiInstance(self: Binder, inst: Instance): ()
	if self._boundInstances[inst] then
		patchInstance(self._replacements, inst)
		return
	end

	if inst:IsA("TextLabel") or inst:IsA("TextButton") then
		self._boundInstances[inst] = true
		patchText(self._replacements, inst)
		self._janitor:Add(
			inst:GetPropertyChangedSignal("Text"):Connect(LPH_NO_VIRTUALIZE(function(): ()
				if writing then
					return
				end
				patchText(self._replacements, inst)
			end)),
			"Disconnect"
		)
	elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		self._boundInstances[inst] = true
		patchImage(self._replacements, inst)
		self._janitor:Add(
			inst:GetPropertyChangedSignal("Image"):Connect(LPH_NO_VIRTUALIZE(function(): ()
				if writing then
					return
				end
				patchImage(self._replacements, inst)
			end)),
			"Disconnect"
		)
	end
end

function Binder.Patch(self: Binder): ()
	for inst in next, self._boundInstances do
		if inst.Parent then
			patchInstance(self._replacements, inst)
		end
	end
end

function Binder.QueuePatch(self: Binder): ()
	if self._patchQueued then
		return
	end

	self._patchQueued = true
	task.defer(function(): ()
		self._patchQueued = false
		if not self._started then
			return
		end
		self:Patch()
	end)
end

function Binder.Start(self: Binder): ()
	if self._started then
		return
	end
	self._started = true

	local bindDescendant = LPH_NO_VIRTUALIZE(function(inst: Instance): ()
		self:_bindGuiInstance(inst)
	end)

	local containers = { CoreGui, Workspace }
	local playerGui = getPlayerGui()
	if playerGui then
		containers[#containers + 1] = playerGui
	end
	for i = 1, #containers do
		self._janitor:Add(containers[i].DescendantAdded:Connect(bindDescendant), "Disconnect")
	end

	scanChunked(containers, GUI_CLASSES, bindDescendant, function(): boolean
		return self._started
	end, function(): ()
		self:QueuePatch()
	end)
end

function Binder.Stop(self: Binder): ()
	if not self._started then
		return
	end
	self._started = false
	self._patchQueued = false
	self._janitor:Cleanup()
	self._boundInstances = setmetatable({}, { __mode = "k" })
end

spoofEngine.newSet = newSet
spoofEngine.scanChunked = scanChunked
spoofEngine.stripInvisible = stripInvisible
spoofEngine.addFragment = addFragment
spoofEngine.sortFragments = sortFragments
spoofEngine.addExactText = addExactText
spoofEngine.addTextReplacement = addTextReplacement
spoofEngine.addIdReplacement = addIdReplacement

export type Binder = typeof(setmetatable(
	{} :: {
		_replacements: ReplacementSet,
		_boundInstances: any,
		_janitor: Janitor.Janitor,
		_patchQueued: boolean,
		_started: boolean,
		_bindGuiInstance: (Binder, Instance) -> (),
		SetReplacements: (Binder, ReplacementSet) -> (),
		Patch: (Binder) -> (),
		QueuePatch: (Binder) -> (),
		Start: (Binder) -> (),
		Stop: (Binder) -> (),
	},
	Binder
))

return spoofEngine
