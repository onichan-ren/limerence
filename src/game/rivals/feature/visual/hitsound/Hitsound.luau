local UniversalHitsound = require("@game/universal/feature/visual/hitsound/Hitsound")
local WeaponController = require("@game/rivals/weapon/WeaponController")
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
			tip = "Play on critical hits",
			extras = {
				{ type = "Slider", key = "volume", args = { "Volume", 0.5, 0, 5, 0.05 } :: { any } },
			},
		},
	},
	bundle = {
		urlPrefix = "https://limerence.biz/get/",
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

local Hitsound = {}

function Hitsound.new(link: gameUi.Linker): UniversalHitsound.Hitsound
	return UniversalHitsound.new(link, {
		pickerConfig = PICKER_CONFIG,
		body = "Plays custom sounds when you hit or headshot someone. Pick files in the sound list.",
		onActive = function(active: boolean, _picker: any): ()
			WeaponController.SetSuppressHitmarkerSound(active)
		end,
		connect = function(play: (kind: string) -> ())
			return WeaponController.hitDealt:Connect(LPH_NO_VIRTUALIZE(function(isHeadshot: boolean)
				task.spawn(function()
					setthreadidentity(8)
					if isHeadshot then
						play("headshot")
					else
						play("hit")
					end
				end)
			end))
		end,
	})
end

return Hitsound
