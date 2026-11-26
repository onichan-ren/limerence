local UniversalHitsound = require("@game/universal/feature/visual/hitsound/Hitsound")
local WeaponController = require("@game/overkill/weapon/WeaponController")
local isLethal = require("@game/overkill/feature/visual/lethal")
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

local Hitsound = {}

function Hitsound.new(link: gameUi.Linker): UniversalHitsound.Hitsound
	return UniversalHitsound.new(link, {
		pickerConfig = PICKER_CONFIG,
		connect = function(play: (kind: string) -> ())
			return WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player, _part: Instance, _partName: string, _position: Vector3, _damage: number, headshot: boolean): ()
				if headshot then
					play("headshot")
				elseif isLethal(player) then
					play("kill")
				else
					play("hit")
				end
			end))
		end,
	})
end

return Hitsound
