local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local gameUi = require("@game/gameUi")

local peek = Charm.peek
local sub = Charm.subscribe

local createBinding = React.createBinding
local joinBindings = React.joinBindings

export type EspCtx = {
	basePlayer: any,
	hrp: BasePart,
	camera: Camera,
	project: ((Vector3) -> Vector3)?,
	camPos: Vector3,
	screen: Vector3,
	depth: number,
	pps: number,
	visible: boolean,
	shouldShow: boolean,
	boxPosition: Vector2,
	boxSize: Vector2,
	alpha: number,
	deathFading: boolean,
	dt: number,
	elementAnimations: boolean,
	healthTextExtraLeft: number,
	viewport: Vector2,
	onScreen: boolean,
	offscreenReady: boolean,
	userId: number,
	stateBucket: any,
	dist: number,
	extra: { [string]: any },
}

export type Bindable<T> = {
	binding: any,
	set: (T) -> (),
}

export type EspElement<State, Settings> = {
	id: string,
	setup: (link: gameUi.Linker, opts: any?) -> Settings,
	createState: (player: Player, basePlayer: any, settings: Settings) -> State,
	update: (state: State, ctx: EspCtx, settings: Settings?) -> (),
	render: ((props: { state: State, settings: Settings, userId: number? }) -> React.Element<any>?)?,
	destroyState: ((state: State, settings: Settings) -> ())?,
	setActive: ((settings: Settings, active: boolean) -> ())?,
	deactivate: ((settings: Settings) -> ())?,
	container: boolean?,
}

export type AnyEspElement = EspElement<any, any>

local EspElement = {}

LPH_NO_VIRTUALIZE(function()
	function EspElement.createBindable<T>(initial: T): Bindable<T>
		local binding, set = createBinding(initial)
		local last = initial
		return {
			binding = binding,
			set = function(value: T): ()
				if value == last then
					return
				end
				last = value
				set(value)
			end,
		}
	end

	function EspElement.fadedTransparency(alphaBinding: any, sourceBinding: any?): any
		if sourceBinding then
			return joinBindings({ alphaBinding, sourceBinding }):map(function(values)
				return 1 - (1 - values[2].transparency) * values[1]
			end)
		end
		return alphaBinding:map(function(a: number)
			return 1 - a
		end)
	end

	function EspElement.vector2ToUDim2Offset(v: Vector2): UDim2
		return UDim2.fromOffset(v.X, v.Y)
	end

	local SWITCH_FADE_DURATION = 0.09

	export type SwitchFade = {
		_switchKey: string?,
		_switchAlpha: number,
	}

	function EspElement.stepSwitchFade(state: SwitchFade, liveKey: string?, dt: number, animate: boolean): (number, boolean)
		if not animate or dt <= 0 then
			state._switchKey = liveKey
			state._switchAlpha = 1
			return 1, false
		end

		local step = dt / SWITCH_FADE_DURATION

		if state._switchKey == nil then
			state._switchKey = liveKey
			state._switchAlpha = math.min(state._switchAlpha + step, 1)
			return state._switchAlpha, false
		end

		if liveKey ~= state._switchKey then
			local alpha = state._switchAlpha - step
			if alpha <= 0 then
				state._switchAlpha = 0
				state._switchKey = liveKey
				return 0, true
			end
			state._switchAlpha = alpha
			return alpha, true
		end

		state._switchAlpha = math.min(state._switchAlpha + step, 1)
		return state._switchAlpha, false
	end

	export type HealthCache = {
		_health: number,
		_maxHealth: number,
		_playerUnsub: () -> (),
	}

	function EspElement.attachHealthCache(basePlayer: any?, cache: HealthCache): ()
		if not basePlayer then
			cache._health = 0
			cache._maxHealth = 100
			cache._playerUnsub = function() end
			return
		end

		cache._health = peek(basePlayer.health)
		cache._maxHealth = peek(basePlayer.maxHealth)
		local unsubs = {
			sub(basePlayer.health, function(health: number): ()
				cache._health = health
			end),
			sub(basePlayer.maxHealth, function(maxHealth: number): ()
				cache._maxHealth = maxHealth
			end),
		}
		cache._playerUnsub = function(): ()
			for i = 1, #unsubs do
				unsubs[i]()
			end
		end
	end

	export type CharacterCache = {
		_character: Model?,
		_playerUnsub: () -> (),
	}

	function EspElement.attachCharacterCache(basePlayer: any?, cache: CharacterCache): ()
		if not basePlayer then
			cache._character = nil
			cache._playerUnsub = function() end
			return
		end

		cache._character = peek(basePlayer.character)
		cache._playerUnsub = sub(basePlayer.character, function(character: Model?): ()
			cache._character = character
		end)
	end
end)()

return EspElement
