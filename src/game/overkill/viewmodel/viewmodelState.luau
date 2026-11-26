local Charm = require("@pkg/Charm")
local ModuleController = require("@game/overkill/module/ModuleController")
local clientState = require("@game/overkill/client/clientState")

local RunService = cloneref(game:GetService("RunService")) :: RunService

local at = Charm.atom
local peek = Charm.peek

local ViewmodelState = {
	viewmodel = at(nil :: any?),
}

local _moduleRef: any = nil
local _refcount = 0
local _conn: RBXScriptConnection? = nil

local resolveLocalVmc = LPH_NO_VIRTUALIZE(function(): any?
	local viewModel = _moduleRef
	if not viewModel then
		viewModel = ModuleController.GetModule("viewModel")
		_moduleRef = viewModel
	end
	if not viewModel then
		return nil
	end
	local character = peek(clientState.character)
	if not character then
		return nil
	end
	local active = viewModel.activeVMCs
	local map = active and active[character]
	if type(map) ~= "table" then
		return nil
	end
	for _, vmc in next, map do
		if type(vmc) == "table" and vmc.isLocal and not vmc.destroying then
			local model = vmc.viewModel
			if typeof(model) == "Instance" and model.Parent ~= nil then
				return vmc
			end
		end
	end
	return nil
end)

local update = LPH_NO_VIRTUALIZE(function(): ()
	local vmc = resolveLocalVmc()
	if vmc ~= peek(ViewmodelState.viewmodel) then
		ViewmodelState.viewmodel(vmc)
	end
end)

function ViewmodelState.Acquire(): ()
	_refcount += 1
	if _refcount == 1 then
		_conn = RunService.Heartbeat:Connect(update)
		update()
	end
end

function ViewmodelState.Release(): ()
	if _refcount <= 0 then
		return
	end
	_refcount -= 1
	if _refcount == 0 then
		if _conn then
			_conn:Disconnect()
			_conn = nil
		end
		_moduleRef = nil
		ViewmodelState.viewmodel(nil)
	end
end

return ViewmodelState
