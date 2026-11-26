local Charm = require("@pkg/Charm")
local React = require("@pkg/React")
local Sift = require("@pkg/Sift")

local Element = require("@ui/window/element/Element")
local SubwindowController = require("@ui/subwindow/SubwindowController")
local renderer = require("@ui/window/element/dropdown/renderer")

local at = Charm.atom
local peek = Charm.peek
local sub = Charm.subscribe
local e = React.createElement

local Dropdown = {}
Dropdown.__index = Dropdown

setmetatable(Dropdown, { __index = Element })

local function asMultiList(value: any): { string }
	if type(value) ~= "table" then
		return {}
	end
	local out: { string } = {}
	for _, item in value do
		if type(item) == "string" then
			table.insert(out, item)
		end
	end
	return out
end

local function arrayEquals(a: { string }, b: { string }): boolean
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function buildLabel(self: Dropdown): string
	local placeholder = peek(self._placeholder)
	local mode = peek(self._mode)
	local selection = peek(self._state)

	if mode == "multi" then
		local list = asMultiList(selection)
		if #list == 0 then
			return placeholder
		end
		if #list <= 2 then
			return table.concat(list, ", ")
		end
		return `{list[1]}, {list[2]}, +{#list - 2}`
	end

	if type(selection) == "string" and selection ~= "" then
		return selection
	end
	return placeholder
end

local function clampSelection(self: Dropdown): ()
	local options = peek(self._options)
	local optionSet: { [string]: true } = {}
	for _, opt in options do
		optionSet[opt] = true
	end

	local mode = peek(self._mode)

	if mode == "multi" then
		local raw = peek(self._state)
		local current: { string }
		if type(raw) == "table" then
			current = asMultiList(raw)
		elseif type(raw) == "string" and raw ~= "" then
			current = { raw }
		else
			current = {}
		end
		local kept: { string } = {}
		for _, item in current do
			if optionSet[item] then
				table.insert(kept, item)
			end
		end

		local maxN = peek(self._max)
		if maxN and #kept > maxN then
			while #kept > maxN do
				table.remove(kept)
			end
		end

		local minN = peek(self._min)
		if minN and #kept < minN then
			for _, opt in options do
				if #kept >= minN then
					break
				end
				local already = false
				for _, v in kept do
					if v == opt then
						already = true
						break
					end
				end
				if not already then
					table.insert(kept, opt)
				end
			end
		end

		if type(raw) ~= "table" or not arrayEquals(kept, current) then
			self._state(kept)
		end
		return
	end

	local current = peek(self._state)
	if type(current) == "string" and optionSet[current] then
		return
	end
	local fallback = options[1] and (options[1]) or ("")
	if current ~= fallback then
		self._state(fallback)
	end
end

local function constructor(text: string, options: { string }?, default: any?): Dropdown
	local self = Element.new(text) :: any
	setmetatable(self, Dropdown)

	self._bindable(true)

	self._options = at(options or {} :: { string })
	self._mode = at((type(default) == "table" and "multi" or "single") :: "single" | "multi")
	self._min = at(0)
	self._max = at(nil :: number?)
	self._placeholder = at("Select...")
	self._open = at(false)
	self._label = at("")

	if default ~= nil then
		self._state(default)
	end

	clampSelection(self)
	self._label(buildLabel(self))
	self._active(buildLabel(self) ~= peek(self._placeholder))

	local function refresh(): ()
		clampSelection(self)
		self._label(buildLabel(self))

		local mode = peek(self._mode)
		if mode == "multi" then
			self._active(#asMultiList(peek(self._state)) > 0)
		else
			local sel = peek(self._state)
			self._active(type(sel) == "string" and sel ~= "")
		end
	end

	sub(self._state, refresh)
	sub(self._options, refresh)
	sub(self._mode, refresh)
	sub(self._min, refresh)
	sub(self._max, refresh)
	sub(self._placeholder, function()
		self._label(buildLabel(self))
	end)

	return self
end

function Dropdown.SetOptions(self: Dropdown, options: { string }): Dropdown
	self._options(options)
	return self
end

function Dropdown.SetMode(self: Dropdown, mode: "single" | "multi"): Dropdown
	if peek(self._mode) == mode then
		return self
	end
	local current = peek(self._state)
	self._mode(mode)
	if mode == "multi" then
		if type(current) == "string" and current ~= "" then
			self._state({ current })
		end
	else
		local list = asMultiList(current)
		self._state(list[1] or "")
	end
	return self
end

function Dropdown.SetMin(self: Dropdown, min: number): Dropdown
	self._min(min)
	return self
end

function Dropdown.SetMax(self: Dropdown, max: number?): Dropdown
	self._max(max)
	return self
end

function Dropdown.SetPlaceholder(self: Dropdown, placeholder: string): Dropdown
	self._placeholder(placeholder)
	return self
end

function Dropdown.SetSelected(self: Dropdown, selection: any): Dropdown
	self._state(selection)
	return self
end

function Dropdown.Toggle(self: Dropdown, option: string): ()
	local options = peek(self._options)
	local known = false
	for _, opt in options do
		if opt == option then
			known = true
			break
		end
	end
	if not known then
		return
	end

	local mode = peek(self._mode)
	if mode == "multi" then
		local current = asMultiList(peek(self._state))
		local indexOf: number? = nil
		for i, v in current do
			if v == option then
				indexOf = i
				break
			end
		end

		if indexOf then
			local minN = peek(self._min)
			if minN and #current <= minN then
				return
			end
			self._state(Sift.Array.removeIndex(current, indexOf))
		else
			local maxN = peek(self._max)
			if maxN and #current >= maxN then
				return
			end
			self._state(Sift.Array.push(current, option))
		end
		return
	end

	if peek(self._state) == option then
		return
	end
	self._state(option)
	self:Close()
end

function Dropdown.IsSelected(self: Dropdown, option: string): boolean
	local mode = peek(self._mode)
	if mode == "multi" then
		for _, v in asMultiList(peek(self._state)) do
			if v == option then
				return true
			end
		end
		return false
	end
	return peek(self._state) == option
end

function Dropdown.Open(self: Dropdown, position: UDim2?): ()
	SubwindowController.OpenDropdown(self, position)
end

function Dropdown.Close(self: Dropdown): ()
	SubwindowController.CloseDropdown(self)
end

function Dropdown.WasJustClosed(self: Dropdown): boolean
	return SubwindowController.WasDropdownJustClosedFor(self)
end

function Dropdown.RenderInternal(self: Dropdown, props: Element.RenderInternalProps?): React.Element<any>
	return e(renderer, {
		Dropdown = self,
		TextRef = props and props.textRef,
		LayoutOrder = props and props.layoutOrder,
	})
end

function Dropdown.CreateTargetProxy(self: Dropdown, initial: any): Dropdown
	local options = peek(self._options)
	local mode = peek(self._mode)
	local start: any = initial
	if start == nil then
		start = peek(self._state)
	end

	local proxy = constructor("", options, start)
	proxy:SetMode(mode ::  "single" | "multi")
	local minN = peek(self._min)
	local maxN = peek(self._max)
	if minN then
		proxy:SetMin(minN)
	end
	if maxN then
		proxy:SetMax(maxN)
	end
	return proxy
end

export type Dropdown = typeof(setmetatable(
	{} :: {
		_options: Charm.Atom<{ string }>,
		_mode: Charm.Atom<"single" | "multi">,
		_min: Charm.Atom<number>,
		_max: Charm.Atom<number?>,
		_placeholder: Charm.Atom<string>,
		_open: Charm.Atom<boolean>,
		_label: Charm.Atom<string>,
	},
	Dropdown
)) & Element.Element

return constructor
