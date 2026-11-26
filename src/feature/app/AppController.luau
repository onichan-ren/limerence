local ReactRoblox = require("@pkg/ReactRoblox")
local ReactCharm = require("@pkg/ReactCharm")
local React = require("@pkg/React")
local Charm = require("@pkg/Charm")
local appRoot = require("@src/feature/app/modules/appRoot")

local e = React.createElement

local AppController = {
	_elementsAtom = Charm.atom({} :: { React.Element<any> }),
	_screenGui = nil :: Instance?,
	_root = nil :: ReactRoblox.RootType?,
	_mounted = false,
}

local function AppRoot(): React.Element<any>
	local children = ReactCharm.useAtom(AppController._elementsAtom)
	local keyed: { [string]: React.Element<any> } = {}
	for index, child in next, children do
		keyed[`slot_{index}`] = child
	end
	return e(React.Fragment, nil, keyed)
end

function AppController.new(): AppController
	local reactRoot, screenGui = appRoot()

	AppController._screenGui = screenGui
	AppController._root = reactRoot

	return AppController
end

function AppController.Start(): ()
	local root = AppController._root
	if not root or AppController._mounted then
		return
	end

	AppController._mounted = true
	root:render(e(AppRoot))
end

function AppController.Render(element: React.Element<any>): ()
	local current = Charm.peek(AppController._elementsAtom)
	local nextList: { React.Element<any> } = {}
	for index, value in next, current do
		nextList[index] = value
	end
	nextList[#nextList + 1] = element
	AppController._elementsAtom(nextList)
end

function AppController.Destroy(): ()
	local root = AppController._root

	AppController._mounted = false
	AppController._elementsAtom({})

	if not root then
		return
	end
	AppController._root = nil

	root:unmount()

	local screenGui = AppController._screenGui
	if screenGui then
		screenGui:Destroy()
		AppController._screenGui = nil
	end
end

export type AppController = typeof(AppController)

return AppController
