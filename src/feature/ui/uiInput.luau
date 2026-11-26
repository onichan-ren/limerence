local ContextActionService = cloneref(game:GetService("ContextActionService")) :: ContextActionService & any
local UserInputService = cloneref(game:GetService("UserInputService")) :: UserInputService

local strings = require("@share/strings")
local Janitor = require("@pkg/Janitor")
local Signal = require("@pkg/Signal")
local Sift = require("@pkg/Sift")

local uiInput = {
	inputBegan = Signal.new(),
	inputEnded = Signal.new(),
	_isFrozen = false,
	_janitor = Janitor.new(),
}

local inputEnums = Sift.Array.join(Enum.UserInputType:GetEnumItems(), Enum.KeyCode:GetEnumItems())

function uiInput.init()
	uiInput.unfreeze(true)
end

function uiInput.freeze(): ()
	if uiInput._isFrozen then
		return
	end
	uiInput._isFrozen = true

	local janitor = uiInput._janitor
	janitor:Cleanup()

	local actionName = strings.random()
	ContextActionService:BindCoreAction(
		actionName,
		LPH_NO_VIRTUALIZE(function(name: string, state: Enum.UserInputState, input: InputObject): ()
			if name ~= actionName then
				return
			end

			if state == Enum.UserInputState.Begin then
				uiInput.onInput(input)
			elseif state == Enum.UserInputState.End then
				uiInput.onInputEnd(input)
			end
		end),
		false,
		table.unpack(inputEnums)
	)

	janitor:Add(function()
		ContextActionService:UnbindCoreAction(actionName)
	end, true)
end

function uiInput.unfreeze(force: boolean): ()
	if not uiInput._isFrozen and not force then
		return
	end
	uiInput._isFrozen = false

	local janitor = uiInput._janitor
	janitor:Cleanup()

	local actionName = strings.random()
	ContextActionService:BindCoreAction(
		actionName,
		LPH_NO_VIRTUALIZE(function(name: string, state: Enum.UserInputState, input: InputObject): ()
			if name ~= actionName then
				return
			end

			if state == Enum.UserInputState.Begin then
				uiInput.onInput(input)
			elseif state == Enum.UserInputState.End then
				uiInput.onInputEnd(input)
			end

			return Enum.ContextActionResult.Pass
		end),
		false,
		table.unpack(inputEnums)
	)

	janitor:Add(function()
		ContextActionService:UnbindCoreAction(actionName)
	end, true)
end

function uiInput.onInput(input: InputObject): ()
	uiInput.inputBegan:Fire(input)
end

function uiInput.onInputEnd(input: InputObject): ()
	uiInput.inputEnded:Fire(input)
end

export type uiInput = typeof(uiInput)

return uiInput
