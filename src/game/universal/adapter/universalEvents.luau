return LPH_JIT_MAX(function()
	local Signal = require("@pkg/Signal")

	export type HitEvent = {
		player: Player?,
		part: BasePart?,
		partName: string?,
		position: Vector3?,
		damage: number?,
		headshot: boolean,
		lethal: boolean?,
	}
	
	export type KillEvent = {
		player: Player?,
		position: Vector3?,
		headshot: boolean?,
	}
	
	export type ShotEvent = {
		player: Player?,
		origin: Vector3,
		target: Vector3,
	}
	
	local universalEvents = {
		hit = Signal.new() :: Signal.Signal<HitEvent>,
		kill = Signal.new() :: Signal.Signal<KillEvent>,
		shot = Signal.new() :: Signal.Signal<ShotEvent>,
	}
	
	local function isHeadName(name: string?): boolean
		return name ~= nil and string.find(name, "Head") ~= nil
	end
	
	function universalEvents.ReportHit(info: {
		player: Player?,
		part: BasePart?,
		partName: string?,
		position: Vector3?,
		damage: number?,
		headshot: boolean?,
		lethal: boolean?,
	}): ()
		local part = info.part
		local partName = info.partName
		if partName == nil and part then
			partName = part.Name
		end
		local position = info.position
		if position == nil and part then
			position = part.Position
		end
		local headshot = info.headshot
		if headshot == nil then
			headshot = isHeadName(partName)
		end
		universalEvents.hit:Fire({
			player = info.player,
			part = part,
			partName = partName,
			position = position,
			damage = info.damage,
			headshot = headshot :: boolean,
			lethal = info.lethal,
		})
	end
	
	function universalEvents.ReportKill(info: {
		player: Player?,
		position: Vector3?,
		headshot: boolean?,
	}): ()
		universalEvents.kill:Fire({
			player = info.player,
			position = info.position,
			headshot = info.headshot,
		})
	end
	
	function universalEvents.ReportShot(origin: Vector3, target: Vector3, player: Player?): ()
		universalEvents.shot:Fire({
			player = player,
			origin = origin,
			target = target,
		})
	end
	
	export type universalEvents = typeof(universalEvents)
	
	return universalEvents
	
end)()