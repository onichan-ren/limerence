local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Element = require("@ui/window/element/Element")
local renderer = require("@ui/window/element/button/renderer")

local at = Charm.atom
local peek = Charm.peek
local e = React.createElement

local Button = {}
Button.__index = Button

setmetatable(Button, { __index = Element })

local DEFAULT_CONFIRM_TEXT = "Confirm?"
local DEFAULT_CONFIRM_TIMEOUT = 2.5

local function constructor(text: string, icon: string?): Button
	local self = Element.new(text) :: any

	setmetatable(self, Button)

	self._icon = at(icon)
	self._pressed = at(false)
	self._callbacks = {} :: { (Button) -> () }
	self._requireConfirm = at(false)
	self._confirmText = at(DEFAULT_CONFIRM_TEXT)
	self._confirmTimeout = DEFAULT_CONFIRM_TIMEOUT
	self._armed = at(false)
	self._armTimer = nil :: thread?

	return self
end

function Button.SetIcon(self: Button, icon: string?): Button
	self._icon(icon)
	return self
end

function Button.OnClick(self: Button, callback: (Button) -> ()): () -> ()
	table.insert(self._callbacks, callback)
	return function()
		local index = table.find(self._callbacks, callback)
		if index then
			table.remove(self._callbacks, index)
		end
	end
end

function Button.RequireConfirm(self: Button, prompt: string?, timeout: number?): Button
	self._requireConfirm(true)
	if prompt then
		self._confirmText(prompt)
	end
	if timeout then
		self._confirmTimeout = timeout
	end
	return self
end

function Button.ClearConfirm(self: Button): Button
	self._requireConfirm(false)
	if self._armTimer then
		task.cancel(self._armTimer)
		self._armTimer = nil
	end
	self._armed(false)
	return self
end

function Button.Click(self: Button): ()
	if peek(self._requireConfirm) then
		if not peek(self._armed) then
			self._armed(true)
			if self._armTimer then
				task.cancel(self._armTimer)
			end
			self._armTimer = task.delay(self._confirmTimeout, function()
				self._armed(false)
				self._armTimer = nil
			end)
			return
		end

		if self._armTimer then
			task.cancel(self._armTimer)
			self._armTimer = nil
		end
		self._armed(false)
	end

	for _, callback in self._callbacks do
		task.spawn(callback, self)
	end
end

function Button.Combine(self: any, text: string, icon: string?): Button
	return self:AddElement("Button", text, icon)
end

function Button.Render(self: Button, layoutOrder: number?): React.Element<any>
	return e(renderer.row, {
		Button = self,
		LayoutOrder = layoutOrder,
	})
end

function Button.RenderInternal(self: Button, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer.single, {
		Button = self,
		LayoutOrder = (props and props.layoutOrder) or 1,
	})
end

export type Button = typeof(setmetatable(
	{} :: {
		_icon: Charm.Atom<string?>,
		_pressed: Charm.Atom<boolean>,
		_callbacks: { (Button) -> () },
		_requireConfirm: Charm.Atom<boolean>,
		_confirmText: Charm.Atom<string>,
		_confirmTimeout: number,
		_armed: Charm.Atom<boolean>,
		_armTimer: thread?,
	},
	Button
)) & Element.Element

return constructor
