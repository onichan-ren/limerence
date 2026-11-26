local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")
local bindState = require("@ui/bind/bindState")
local Bind = require("@ui/bind/Bind")

local peek = Charm.peek

local bindHandler = {}

local function deactivateBind(bind: Bind): ()
	if not peek(bind.active) then
		return
	end

	local activeBinds = bindState.activeBinds
	activeBinds(Sift.Dictionary.removeKey(peek(activeBinds), bind.name))

	bind.active(false)
	bind.callback(false)
end

local function activateBind(bind: Bind): ()
	if peek(bind.active) then
		return
	end

	local activeBinds = bindState.activeBinds
	activeBinds(Sift.Dictionary.set(peek(activeBinds), bind.name, bind))

	bind.active(true)
	bind.callback(true)
end

local function matchesInput(bind: Bind, input: InputObject): boolean
	local bindInputs = peek(bind.inputs)
	return Sift.Array.contains(bindInputs, input.KeyCode) or Sift.Array.contains(bindInputs, input.UserInputType)
end

bindHandler.onInputBegan = LPH_NO_VIRTUALIZE(function(input: InputObject): ()
	for _, bind in next, peek(bindState.binds) do
		if not matchesInput(bind, input) then
			continue
		end

		local bindMode = peek(bind.mode)
		if bindMode == "onHold" then
			activateBind(bind)
		elseif bindMode == "offHold" then
			deactivateBind(bind)
		elseif bindMode == "toggle" then
			if peek(bind.active) then
				deactivateBind(bind)
			else
				activateBind(bind)
			end
		elseif bindMode == "onPress" then
			bind.callback(true)
		end
	end
end)

bindHandler.onInputEnded = LPH_NO_VIRTUALIZE(function(input: InputObject): ()
	for _, bind in next, peek(bindState.binds) do
		if not matchesInput(bind, input) then
			continue
		end

		local bindMode = peek(bind.mode)
		if bindMode == "onHold" then
			deactivateBind(bind)
		elseif bindMode == "offHold" then
			activateBind(bind)
		elseif bindMode == "onRelease" then
			bind.callback(true)
		end
	end
end)

export type bindHandler = typeof(bindHandler)
type Bind = Bind.Bind

return bindHandler
