local UniversalHitsound = require("@game/universal/feature/visual/hitsound/Hitsound")
local ModuleController = require("@game/bloxstrike/module/ModuleController")
local WeaponController = require("@game/bloxstrike/weapon/WeaponController")
local PlayerController = require("@feature/player/PlayerController")
local Hook = require("@share/hook")
local gameUi = require("@game/gameUi")

local PICKER_CONFIG = {
	assetType = "sounds",
	category = "hitsound",
	assignmentTypes = {
		{
			key = "hit",
			label = "Hit",
			icon = "scope_small",
			tip = "Play on body shots",
			extras = {
				{ type = "Slider", key = "volume", args = { "Volume", 0.5, 0, 5, 0.05 } :: { any } },
			},
		},
		{
			key = "headshot",
			label = "Headshot",
			icon = "skull_small",
			tip = "Play on headshots",
			extras = {
				{ type = "Slider", key = "volume", args = { "Volume", 0.5, 0, 5, 0.05 } :: { any } },
			},
		},
		{
			key = "kill",
			label = "Kill",
			icon = "grave_small",
			tip = "Play on lethal hits",
			extras = {
				{ type = "Slider", key = "volume", args = { "Volume", 0.5, 0, 5, 0.05 } :: { any } },
			},
		},
	},
	bundle = {
		urlPrefix = "https://raw.githubusercontent.com/onichan-ren/limerence/main/assets/hitsounds/",
		title = "Downloading hitsounds",
		icon = "download",
		files = {
			"Primordial.wav",
			"Neverlose.wav",
			"Sparkle.wav",
			"Bubble.wav",
			"Rifk7.wav",
			"Rust.wav",
			"Osu.mp3",
		},
	},
}

local function disableHeadshotSound(picker: any)
	local soundClass = ModuleController.GetModule("SoundClass")
	local playSoundAtPosition = rawget(soundClass, "PlaySoundAtPosition") :: (...any) -> ()

	local oldPlaySoundAtPosition = nil
	oldPlaySoundAtPosition = Hook.add(playSoundAtPosition, function(self, ...)
		if not picker:GetAssignedPath("headshot") then
			return oldPlaySoundAtPosition(self, ...)
		end

		local data = { ... }
		local idk = data[1]

		if not idk then
			return oldPlaySoundAtPosition(self, ...)
		end

		local name = idk.Name
		if name == "Headshot" or name == "Helmet Headshot" and data[4] then
			return
		end

		return oldPlaySoundAtPosition(self, ...)
	end)
end

local function enableHeadshotSound()
	local soundClass = ModuleController.GetModule("SoundClass")
	local playSoundAtPosition = rawget(soundClass, "PlaySoundAtPosition") :: (...any) -> ()

	Hook.restore(playSoundAtPosition)
end

local Hitsound = {}

function Hitsound.new(link: gameUi.Linker): UniversalHitsound.Hitsound
	return UniversalHitsound.new(link, {
		pickerConfig = PICKER_CONFIG,
		onActive = function(active: boolean, picker: any): ()
			if active then
				disableHeadshotSound(picker)
			else
				enableHeadshotSound()
			end
		end,
		connect = function(play: (kind: string) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player, part: Instance): ()
				if part.Name == "Head" then
					play("headshot")
				else
					local playerData = PlayerController.Get(player)
					if playerData and not playerData:IsAlive() then
						play("kill")
					else
						play("hit")
					end
				end
			end))
		end,
	})
end

return Hitsound
