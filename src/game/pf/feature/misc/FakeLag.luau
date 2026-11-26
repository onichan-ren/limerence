local UniversalFakeLag = require("@game/universal/feature/misc/FakeLag")
local ModuleController = require("@game/pf/module/ModuleController")
local repupdateFreeze = require("@game/pf/network/repupdateFreeze")
local localThirdPerson = require("@game/pf/thirdperson/localThirdPerson")
local gameUi = require("@game/gameUi")

local FakeLag = {}

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

function FakeLag.new(link: gameUi.Linker): UniversalFakeLag.FakeLag
	return UniversalFakeLag.new(link, {
		getRoot = getRoot,
		getCharacter = function(): Instance?
			local root = getRoot()
			return root and root.Parent
		end,
		isAlive = function(): boolean
			local ci = characterInterface()
			return ci ~= nil and ci.isAlive() == true
		end,
		setFrozen = function(frozen: boolean): ()
			if not frozen then
				repupdateFreeze.setFrozen(false)
				return
			end
			local root = getRoot()
			repupdateFreeze.setFrozen(true, root and root.Position)
		end,
		setGhost = function(frozenCFrame: CFrame?): ()
			localThirdPerson.setPositionOverride(frozenCFrame and frozenCFrame.Position)
			localThirdPerson.setAngleHold(frozenCFrame ~= nil)
		end,
	})
end

return FakeLag
