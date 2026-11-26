local Players = cloneref(game:GetService("Players")) :: Players

local sessionState = require("@feature/session/sessionState")

local LocalPlayer = Players.LocalPlayer

export type UsernameDisplayMode = "roblox" | "discord" | "hidden" | "custom"

local displayUsername = {}

displayUsername.MODE_LABELS = {
	roblox = "Roblox Username",
	discord = "Discord Name",
	hidden = "Hidden",
	custom = "Custom",
}

displayUsername.LABEL_TO_MODE = {
	["Roblox Username"] = "roblox",
	["Discord Name"] = "discord",
	["Hidden"] = "hidden",
	["Custom"] = "custom",
}

displayUsername.DROPDOWN_OPTIONS = {
	displayUsername.MODE_LABELS.roblox,
	displayUsername.MODE_LABELS.discord,
	displayUsername.MODE_LABELS.hidden,
	displayUsername.MODE_LABELS.custom,
}

local function discordName(): string
	local ok, name = pcall(function(): string
		return LP_DISCORD :: any
	end)
	if ok and type(name) == "string" and name ~= "" then
		return name
	end
	return LocalPlayer.Name
end

function displayUsername.resolve(mode: UsernameDisplayMode, customName: string?): string
	if mode == "discord" then
		return discordName()
	end
	if mode == "hidden" then
		return "User"
	end
	if mode == "custom" then
		local trimmed = type(customName) == "string" and string.match(customName, "^%s*(.-)%s*$") or ""
		if trimmed ~= "" then
			return trimmed
		end
		return "User"
	end
	return LocalPlayer.Name
end

function displayUsername.apply(mode: UsernameDisplayMode, customName: string?): ()
	sessionState.username(displayUsername.resolve(mode, customName))
end

function displayUsername.modeToLabel(mode: UsernameDisplayMode): string
	return displayUsername.MODE_LABELS[mode] or displayUsername.MODE_LABELS.roblox
end

function displayUsername.labelToMode(label: string): UsernameDisplayMode
	local mode = displayUsername.LABEL_TO_MODE[label]
	if mode then
		return mode :: UsernameDisplayMode
	end
	return "roblox"
end

function displayUsername.normalizeMode(value: any): UsernameDisplayMode
	if value == "roblox" or value == "discord" or value == "hidden" or value == "custom" then
		return value
	end
	if type(value) == "string" then
		return displayUsername.labelToMode(value)
	end
	return "roblox"
end

return displayUsername
