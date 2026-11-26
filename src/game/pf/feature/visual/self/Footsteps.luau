local UniversalFootsteps = require("@game/universal/feature/visual/footsteps/Footsteps")
local ModuleController = require("@game/pf/module/ModuleController")
local gameUi = require("@game/gameUi")

local Footsteps = {}

local _characterInterface: any = nil
local function characterInterface(): any
	if not _characterInterface then
		_characterInterface = ModuleController.GetModule("CharacterInterface")
	end
	return _characterInterface
end

local function getRoot(): BasePart?
	local ci = characterInterface()
	local co = ci and ci.getCharacterObject()
	return co and co:getRealRootPart()
end

function Footsteps.new(link: gameUi.Linker): UniversalFootsteps.Footsteps
	return UniversalFootsteps.new(link, {
		getRoot = getRoot,
		getCharacter = function(): Instance?
			local root = getRoot()
			return root and root.Parent
		end,
		isAlive = function(): boolean
			local ci = characterInterface()
			return ci ~= nil and ci.isAlive() == true
		end,
		isGrounded = function(): boolean
			local ci = characterInterface()
			local co = ci and ci.getCharacterObject()
			return co ~= nil and co:isGrounded() == true
		end,
	})
end

return Footsteps
