local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local PlayerController = require("@feature/player/PlayerController")
local playerDetail = require("@feature/record/module/playerDetail")

local peek = Charm.peek

local LocalPlayer = Players.LocalPlayer

local function getTarget(player: Player): any
	return PlayerController.Get(player)
end

local function localRoot(): BasePart?
	local character = LocalPlayer.Character
	return character and character.PrimaryPart
end

local arPlayerDetail = {}

function arPlayerDetail.Setup(): ()
	playerDetail.Register({
		id = "ar2",
		info = {
			{
				id = "health",
				label = "Health",
				order = 10,
				value = function(player: Player): string?
					local target = getTarget(player)
					if not target then
						return nil
					end
					return `{math.floor(peek(target.health) + 0.5)} / {peek(target.maxHealth)}`
				end,
			},
			{
				id = "weapon",
				label = "Weapon",
				order = 11,
				value = function(player: Player): string?
					local target = getTarget(player)
					local weapon = target and peek(target.weapon)
					return (weapon ~= nil and weapon ~= "") and weapon or nil
				end,
			},
			{
				id = "distance",
				label = "Distance",
				order = 12,
				value = function(player: Player): string?
					local target = getTarget(player)
					local targetHrp = target and peek(target.hrp)
					local root = localRoot()
					if not targetHrp or not root then
						return nil
					end
					return `{math.floor((targetHrp.Position - root.Position).Magnitude + 0.5)} studs`
				end,
			},
		},
	})
end

return arPlayerDetail
