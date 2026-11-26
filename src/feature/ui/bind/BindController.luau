local Charm = require("@pkg/Charm")
local Sift = require("@pkg/Sift")

local bindHandler = require("@ui/bind/bindHandler")
local Bind = require("@ui/bind/Bind")
local bindState = require("@ui/bind/bindState")
local uiInput = require("@ui/uiInput")
local uiState = require("@ui/uiState")

local peek = Charm.peek
local sub = Charm.subscribe

local BindController = {}

function BindController.new(): BindController
	uiInput.inputBegan:Connect(bindHandler.onInputBegan)
	uiInput.inputEnded:Connect(bindHandler.onInputEnded)
	uiInput.init()

	sub(uiState.isOpen, function(open: boolean): ()
		if open then
			uiInput.freeze()
		else
			uiInput.unfreeze(false)
		end
	end)

	return BindController
end

function BindController.AddBind(name: string, callback: (active: boolean) -> ()): Bind
	local bind = Bind(name, callback)
	BindController._registerBind(bind)

	return bind
end

function BindController._registerBind(bind: Bind): ()
	local binds = bindState.binds
	local rawBinds = peek(bindState.binds)
	binds(Sift.Dictionary.set(rawBinds, bind.name, bind))
end

function BindController.RemoveBind(name: string): ()
	local rawBinds = peek(bindState.binds)
	if rawBinds[name] == nil then
		return
	end
	bindState.binds(Sift.Dictionary.removeKey(rawBinds, name))

	local rawActive = peek(bindState.activeBinds)
	if rawActive[name] ~= nil then
		bindState.activeBinds(Sift.Dictionary.removeKey(rawActive, name))
	end
end

function BindController.Destroy(): ()
	uiInput._janitor:Destroy()
end

export type BindController = typeof(BindController)
export type Bind = Bind.Bind

return BindController
