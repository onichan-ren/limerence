local Players = cloneref(game:GetService("Players")) :: Players

local hook = require("@share/hook")

local LocalPlayer = Players.LocalPlayer

local BOTTOM_TARGETS = { "Health", "Armor", "Ammo", "Inventory", "Money" }

local nativeHud = {
	_coreHidden = {} :: { [Instance]: true },
	_killFeed = nil :: Instance?,
}

local function getGameplay(): Instance?
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local mainGui = playerGui and playerGui:FindFirstChild("MainGui")
	return mainGui and mainGui:FindFirstChild("Gameplay")
end

local function hideFrame(frame: Instance): ()
	hook.addInstance(frame)
	hook.blockProperty(frame, "Visible");
	(frame :: any).Visible = false
end

function nativeHud.hide(): ()
	local gameplay = getGameplay()
	local bottom = gameplay and gameplay:FindFirstChild("Bottom")
	if not bottom then
		return
	end
	for _, name in next, BOTTOM_TARGETS do
		local frame = bottom:FindFirstChild(name)
		if frame and not nativeHud._coreHidden[frame] then
			hideFrame(frame)
			nativeHud._coreHidden[frame] = true
		end
	end
	local middle = bottom:FindFirstChild("Middle")
	local team = middle and middle:FindFirstChild("Team")
	if team and not nativeHud._coreHidden[team] then
		hideFrame(team)
		nativeHud._coreHidden[team] = true
	end
end

function nativeHud.show(): ()
	local hidden = nativeHud._coreHidden
	nativeHud._coreHidden = {}
	for frame in next, hidden do
		hook.unblockProperty(frame, "Visible")
	end
end

function nativeHud.setKillFeedHidden(value: boolean): ()
	if value then
		if nativeHud._killFeed then
			return
		end
		local gameplay = getGameplay()
		local middle = gameplay and gameplay:FindFirstChild("Middle")
		local killFeed = middle and middle:FindFirstChild("KillFeed")
		if not killFeed then
			return
		end
		hideFrame(killFeed)
		nativeHud._killFeed = killFeed
	else
		if not nativeHud._killFeed then
			return
		end
		hook.unblockProperty(nativeHud._killFeed, "Visible")
		nativeHud._killFeed = nil
	end
end

function nativeHud.restore(): ()
	nativeHud.show()
	nativeHud.setKillFeedHidden(false)
end

return nativeHud
