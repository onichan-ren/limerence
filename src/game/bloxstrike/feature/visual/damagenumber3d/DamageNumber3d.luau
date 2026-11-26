local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local UniversalDamageNumber3d = require("@game/universal/feature/visual/damagenumber3d/DamageNumber3d")
local WeaponController = require("@game/bloxstrike/weapon/WeaponController")
local PlayerController = require("@feature/player/PlayerController")
local clientApi = require("@game/bloxstrike/client/clientApi")
local predictDamage = require("@game/bloxstrike/feature/legitbot/predictDamage")
local gameUi = require("@game/gameUi")

local HIT_DEDUPE = 0.05

local damageFor = LPH_NO_VIRTUALIZE(function(player: Player, part: BasePart): number?
	local weapon = clientApi.GetWeapon()
	local camera = Workspace.CurrentCamera
	if not weapon or not camera then
		return nil
	end
	local damage = predictDamage(camera.CFrame.Position, part, weapon, false, PlayerController.Get(player))
	if type(damage) ~= "number" or damage <= 0 then
		return nil
	end
	return math.floor(damage + 0.5)
end)

local DamageNumber3d = {}

function DamageNumber3d.new(link: gameUi.Linker): UniversalDamageNumber3d.DamageNumber3d
	return UniversalDamageNumber3d.new(link, {
		connect = function(emit: (position: Vector3, amount: number, headshot: boolean) -> ())
			local lastHit: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
			local connection = WeaponController.hitPlayer:Connect(LPH_NO_VIRTUALIZE(function(player: Player, part: Instance): ()
				if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
					return
				end
				local now = os.clock()
				local last = lastHit[player]
				if last and now - last < HIT_DEDUPE then
					return
				end
				lastHit[player] = now
				local damage = damageFor(player, part)
				if not damage then
					return
				end
				emit(part.Position, damage, string.find(part.Name, "Head") ~= nil)
			end))
			return function()
				connection:Disconnect()
			end
		end,
	})
end

return DamageNumber3d
