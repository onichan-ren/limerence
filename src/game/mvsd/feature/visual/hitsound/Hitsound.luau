local UniversalHitsound = require("@game/universal/feature/visual/hitsound/Hitsound")
local WeaponController = require("@game/mvsd/weapon/WeaponController")
local PlayerController = require("@feature/player/PlayerController")
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
		connect = function(play: (kind: string) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player, part: Instance): ()
				if part.Name:find("Head") then
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
