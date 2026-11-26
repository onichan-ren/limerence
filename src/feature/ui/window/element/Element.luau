return LPH_NO_VIRTUALIZE(function()
	local Charm = require("@pkg/Charm")
	local React = require("@pkg/React")
	local Sift = require("@pkg/Sift")
	local renderer = require("@ui/window/element/renderer")
	local elementBindController = require("@ui/bind/elementBindController")

	local at = Charm.atom
	local peek = Charm.peek
	local sub = Charm.subscribe
	local e = React.createElement

	export type OverrideEntry = {
		value: any,
		priority: number,
		source: string?,
	}

	local _nextOverrideToken = 0
	local function nextOverrideToken(): number
		_nextOverrideToken += 1
		return _nextOverrideToken
	end

	local Element = {}
	Element.__index = Element

	function Element.new(text: string): Element
		local self = setmetatable({}, Element) :: Element

		self._state = at(nil)
		self._active = at(false)
		self._text = at(text)
		self._extras = at({} :: { [number]: Element })
		self._binds = at({} :: { elementBindController.ElementBind })
		self._bindable = at(false)
		self._tip = at(nil :: any?)
		self._visible = at(true)
		self._disabled = at(false)
		self._scopeKey = at(nil :: string?)
		self._scopeSource = at(nil :: string?)
		self._scopeIsInherited = at(false)
		self._overrides = at({} :: { [number]: OverrideEntry })

		return self
	end

	local function resolveOverride(overrides: { [number]: OverrideEntry }): (any, boolean)
		local bestPriority = -math.huge
		local bestValue: any = nil
		local hasAny = false
		for _, entry in next, overrides do
			if entry.priority > bestPriority then
				bestPriority = entry.priority
				bestValue = entry.value
				hasAny = true
			end
		end
		return bestValue, hasAny
	end

	function Element.GetEffectiveValue(self: Element): any
		local overrides = peek(self._overrides)
		local value, has = resolveOverride(overrides)
		if has then
			return value
		end
		return peek(self._state)
	end

	function Element.IsOverridden(self: Element): boolean
		return next(peek(self._overrides)) ~= nil
	end

	function Element.AddOverride(self: Element, value: any, priority: number, source: string?): number
		local token = nextOverrideToken()
		local current = peek(self._overrides)
		self._overrides(Sift.Dictionary.set(current, token, {
			value = value,
			priority = priority,
			source = source,
		}))
		return token
	end

	function Element.UpdateOverride(self: Element, token: number, value: any, priority: number?): boolean
		local current = peek(self._overrides)
		local entry = current[token]
		if not entry then
			return false
		end
		self._overrides(Sift.Dictionary.set(current, token, {
			value = value,
			priority = priority or entry.priority,
			source = entry.source,
		}))
		return true
	end

	function Element.RemoveOverride(self: Element, token: number): boolean
		local current = peek(self._overrides)
		if not current[token] then
			return false
		end
		self._overrides(Sift.Dictionary.removeKey(current, token))
		return true
	end

	function Element.ClearOverridesFromSource(self: Element, source: string): ()
		local current = peek(self._overrides)
		local next_: { [number]: OverrideEntry } = {}
		local changed = false
		for token, entry in next, current do
			if entry.source == source then
				changed = true
			else
				next_[token] = entry
			end
		end
		if changed then
			self._overrides(next_)
		end
	end

	function Element.GetOverrides(self: Element): { OverrideEntry }
		local current = peek(self._overrides)
		local out: { OverrideEntry } = {}
		for _, entry in next, current do
			out[#out + 1] = entry
		end
		return out
	end

	function Element.SetText(self: Element, text: string): ()
		self._text(text)
	end

	function Element.SetTip(self: Element, tip: (string | { title: string?, body: string })?): Element
		self._tip(tip)
		return self
	end

	function Element.SetBindable(self: Element, state: boolean): Element
		self._bindable(state)
		return self
	end

	function Element.SetVisible(self: Element, state: boolean): Element
		self._visible(state)
		return self
	end

	function Element.IsVisible(self: Element): boolean
		return peek(self._visible)
	end

	function Element.SetDisabled(self: Element, state: boolean): Element
		self._disabled(state)
		return self
	end

	function Element.IsDisabled(self: Element): boolean
		return peek(self._disabled)
	end

	function Element.AddBind(self: Element): elementBindController.ElementBind?
		local current = peek(self._binds)
		if #current >= elementBindController.MAX_BINDS then
			return nil
		end
		local eb = elementBindController.CreateBind(self, peek(self._text))
		self._binds(Sift.Array.push(current, eb))
		return eb
	end

	function Element.RemoveBind(self: Element, id: number): ()
		local current = peek(self._binds)
		for _, eb in next, current do
			if eb.id == id then
				elementBindController.DestroyBind(eb)
				break
			end
		end
		self._binds(Sift.Array.filter(current, function(eb: elementBindController.ElementBind)
			return eb.id ~= id
		end))
	end

	function Element.GetBinds(self: Element): { elementBindController.ElementBind }
		return peek(self._binds)
	end

	function Element.Destroy(self: Element): ()
		local current = peek(self._binds)
		for _, eb in next, current do
			elementBindController.DestroyBind(eb)
		end
		self._binds({})
	end

	function Element.OnChange(self: Element, callback: (value: any) -> ()): () -> ()
		local last = self:GetEffectiveValue()
		local function fire(): ()
			local current = self:GetEffectiveValue()
			if current == last then
				return
			end
			last = current
			callback(current)
		end
		local u1 = sub(self._state, fire)
		local u2 = sub(self._overrides, fire)
		return function(): ()
			u1()
			u2()
		end
	end

	function Element.Peek(self: Element): any
		return self:GetEffectiveValue()
	end

	function Element.PeekRaw(self: Element): any
		return peek(self._state)
	end

	function Element.Render(self: Element, layoutOrder: number?, props: RenderOptions?): React.Element<any>
		return e(renderer, {
			Element = self,
			LayoutOrder = layoutOrder,
			TextOffsetY = props and props.textOffsetY,
		})
	end

	function Element.RenderInternal(self: Element, _props: RenderInternalProps?): React.Element<any>
		return e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 0, 0),
			LayoutOrder = (_props and _props.layoutOrder) or 0,
		})
	end

	export type RenderInternalProps = {
		textRef: { current: TextButton? }?,
		layoutOrder: number?,
		textOffsetY: number?,
	}

	export type RenderOptions = {
		textOffsetY: number?,
	}

	export type Element = typeof(setmetatable(
		{} :: {
			_state: Charm.Atom<any>,
			_active: Charm.Atom<boolean>,
			_text: Charm.Atom<string>,
			_extras: Charm.Atom<{ [number]: Element }>,
			_binds: Charm.Atom<{ elementBindController.ElementBind }>,
			_bindable: Charm.Atom<boolean>,
			_tip: Charm.Atom<any?>,
			_visible: Charm.Atom<boolean>,
			_disabled: Charm.Atom<boolean>,
			_scopeKey: Charm.Atom<string?>,
			_scopeSource: Charm.Atom<string?>,
			_scopeIsInherited: Charm.Atom<boolean>,
			_overrides: Charm.Atom<{ [number]: OverrideEntry }>,
		},
		Element
	))

	return Element
end)()
