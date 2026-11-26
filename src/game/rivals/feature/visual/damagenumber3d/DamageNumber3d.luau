local UniversalDamageNumber3d = require("@game/universal/feature/visual/damagenumber3d/DamageNumber3d")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local NetworkController = require("@game/rivals/network/NetworkController")
local ModuleController = require("@game/rivals/module/ModuleController")
local gameUi = require("@game/gameUi")

local HIT_WINDOW = 1

local function findVictimDamage(...: any): (BasePart?, number?)
	local count = select("#", ...)
	for i = 1, count - 1 do
		local part = select(i, ...)
		if typeof(part) == "Instance" and part:IsA("BasePart") then
			local damage = select(i + 1, ...)
			if type(damage) == "number" then
				return part, damage
			end
		end
	end
	return nil, nil
end

local DamageNumber3d = {}

function DamageNumber3d.new(link: gameUi.Linker): UniversalDamageNumber3d.DamageNumber3d
	return UniversalDamageNumber3d.new(link, {
		headshotBody = "Color when the hit lands on the head hitbox.",
		connect = function(emit: (position: Vector3, amount: number, headshot: boolean) -> ())
			local enumLibrary = ModuleController.GetModule("EnumLibrary")
			if not enumLibrary then
				return function() end
			end

			local ourHits: { [Model]: { clock: number, part: BasePart } } = {}

			local function isDamageNumber(...: any): boolean
				for i = 1, math.min(select("#", ...), 4) do
					local value = select(i, ...)
					if type(value) == "string" and enumLibrary:FromEnum(value, true) == "DamageNumberEffect" then
						return true
					end
				end
				return false
			end

			local hitConnection = WeaponController.hitTarget:Connect(LPH_NO_VIRTUALIZE(function(model: Model, part: BasePart): ()
				ourHits[model] = { clock = os.clock(), part = part }
			end))

			local remoteConnection = NetworkController.ConnectRemote("Replication.Fighter.Replicate", LPH_NO_VIRTUALIZE(function(...)
				if not isDamageNumber(...) then
					return
				end

				local part, damage = findVictimDamage(...)
				if not part or not damage then
					return
				end

				local victim = part:FindFirstAncestorOfClass("Model")
				if not victim then
					return
				end

				local mark = ourHits[victim]
				if not mark or os.clock() - mark.clock > HIT_WINDOW then
					return
				end
				ourHits[victim] = nil

				local hitPart = mark.part
				emit(hitPart.Position, math.ceil(damage), string.find(hitPart.Name, "Head") ~= nil)
			end))

			return function()
				hitConnection:Disconnect()
				if remoteConnection then
					remoteConnection:Disconnect()
				end
			end
		end,
	})
end

return DamageNumber3d
