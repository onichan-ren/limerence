local Charm = require("@pkg/Charm")
local React = require("@pkg/React")

local Subwindow = require("@ui/subwindow/Subwindow")
local subwindowPosition = require("@ui/util/subwindowPosition")
local renderer = require("@ui/subwindow/skinConfig/renderer")
local Slider = require("@ui/window/element/slider/Slider")
local Toggle = require("@ui/window/element/toggle/Toggle")
local Textbox = require("@ui/window/element/textbox/Textbox")

local at = Charm.atom
local peek = Charm.peek
local e = React.createElement

local SkinConfig = {}
SkinConfig.__index = SkinConfig

setmetatable(SkinConfig, { __index = Subwindow })

export type SkinConfigSubmit = {
	weapon: string,
	skin: string,
	float: number,
	seed: number,
	nameTag: string,
	statTrack: boolean,
}

export type OpenOptions = {
	weapon: string,
	skin: string,
	rarity: string?,
	icon: string?,
	position: UDim2?,
	float: number?,
	seed: number?,
	nameTag: string?,
	statTrack: boolean?,
	submitLabel: string?,
	onSubmit: ((SkinConfigSubmit) -> ())?,
	onCancel: (() -> ())?,
}

local function constructor(): SkinConfig
	local self = Subwindow.new() :: any
	setmetatable(self, SkinConfig)

	self._weapon = at("")
	self._skin = at("")
	self._rarity = at("common")
	self._icon = at(nil :: string?)
	self._submitLabel = at("Add To Inventory")

	self._floatEl = Slider("Float", 0.07, 0, 1, 0.001)
	self._seedEl = Textbox("Paint Seed", "0", "0", true)
	self._nameTagEl = Textbox("Nametag", "", "Enter a nametag")
	self._statTrackEl = Toggle("StatTrak™", false)

	self._onSubmit = nil :: ((SkinConfigSubmit) -> ())?
	self._onCancel = nil :: (() -> ())?

	return self
end

function SkinConfig.Open(self: SkinConfig, opts: OpenOptions): ()
	self._weapon(opts.weapon)
	self._skin(opts.skin)
	self._rarity(opts.rarity or "common")
	self._icon(opts.icon)
	self._submitLabel(opts.submitLabel or "Add To Inventory")
	self._onSubmit = opts.onSubmit
	self._onCancel = opts.onCancel

	self._floatEl:SetValue(opts.float ~= nil and opts.float or 0.07)
	self._seedEl:SetValue(opts.seed ~= nil and tostring(opts.seed) or "0")
	self._nameTagEl:SetValue(opts.nameTag ~= nil and opts.nameTag or "")
	self._statTrackEl:SetState(opts.statTrack == true)

	self:SetPosition(opts.position or subwindowPosition.menuCenter())
	self:SetOpen(true)
end

function SkinConfig.BuildPayload(self: SkinConfig): SkinConfigSubmit
	local seedNum = tonumber(self._seedEl:Peek()) or 0
	return {
		weapon = peek(self._weapon),
		skin = peek(self._skin),
		float = self._floatEl:Peek() or 0,
		seed = seedNum,
		nameTag = self._nameTagEl:Peek() or "",
		statTrack = self._statTrackEl:Peek() == true,
	}
end

function SkinConfig.Submit(self: SkinConfig, payload: SkinConfigSubmit): ()
	local onSubmit = self._onSubmit
	self._onSubmit = nil
	self._onCancel = nil
	self:SetOpen(false)
	if onSubmit then
		onSubmit(payload)
	end
end

function SkinConfig.Cancel(self: SkinConfig): ()
	local onCancel = self._onCancel
	self._onSubmit = nil
	self._onCancel = nil
	self:SetOpen(false)
	if onCancel then
		onCancel()
	end
end

function SkinConfig.Close(self: SkinConfig): ()
	self._onSubmit = nil
	self._onCancel = nil
	self:SetOpen(false)
end

function SkinConfig.Render(self: SkinConfig): React.Element<any>
	return e(renderer, { SkinConfig = self })
end

export type SkinConfig =
	typeof(setmetatable(
		{} :: {
			_weapon: Charm.Atom<string>,
			_skin: Charm.Atom<string>,
			_rarity: Charm.Atom<string>,
			_icon: Charm.Atom<string?>,
			_submitLabel: Charm.Atom<string>,
			_floatEl: any,
			_seedEl: any,
			_nameTagEl: any,
			_statTrackEl: any,
			_onSubmit: ((SkinConfigSubmit) -> ())?,
			_onCancel: (() -> ())?,
		},
		SkinConfig
	))
	& Subwindow.Subwindow

return constructor
