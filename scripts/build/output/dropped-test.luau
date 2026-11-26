local a a={cache={}, load=function(b)if not a.cache[b]then a.cache[b]={c=a[b]()}end return a.cache[b].c end}do function a.a()













































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































































return {
	version = "1",
	url = "https://limerence.biz/get-package/packages-v1.luau",
}
end function a.b()
local b = a.load'a'

local c = "limerence.biz/cache"
local d = `{c}/packages-v{b.version}.luau`
local e = "@limerence_pkgs"

local f = {}

local g

local function fetchSource()	
local h = game.HttpGet(game,b.url)

	if not h or #h == 0 then
		error(`pkgBootstrap: response body is empty)`)
	end

	return h
end

local function readCache()	
if not isfile or not readfile then
		return nil
	end
	if not isfile(d) then
		return nil
	end
	local h = readfile(d)
	if type(h) ~= "string" or #h == 0 then
		return nil
	end
	return h
end

local function ensureFolder(h)	
if not isfolder or not makefolder then
		return
	end
	local i = ""
	for j in string.gmatch(h, "[^/]+") do
		i = i == "" and j or `{i}/{j}`
		if not isfolder(i) then
			makefolder(i)
		end
	end
end

local function writeCache(h)	
if not writefile then
		return
	end
	ensureFolder(c)
	local i, j = pcall(writefile, d, h)
	if not i then
		warn(`pkgBootstrap: writefile failed: {tostring(j)}`)
	end
end

local function load()	
if g then
		return
	end

	local h = readCache()
	if not h then
		local i = fetchSource()
		writeCache(i)
		h = i
	end

	local i, j = loadstring(h , e)
	if not i then
		error(`pkgBootstrap: loadstring failed: {tostring(j)}`)
	end

	local k, l = pcall(i)
	if not k then
		error(`pkgBootstrap: package bundle threw on load: {tostring(l)}`)
	end

	if type(l) ~= "table" then
		local m = getgenv().__limerence_pkgs
		if type(m) == "table" then
			l = m
		end
	end

	g = l
end

function f.get(h)	
if not g then
		load()
	end
	local i = (g )[h]
	if i == nil then
		error(`pkgBootstrap: package "{h}" not registered in bundle`)
	end
	return i
end

return f
end function a.c()
return a.load'b'.get"React"end function a.d()

return a.load'b'.get"ReactCharm"end function a.e()

return a.load'b'.get"ReactRipple"end function a.f()

local b = {}

LPH_NO_VIRTUALIZE(function()
	function b.log(c)		
print(c)
	end

	function b.warn(c)		
warn(c)
	end

	function b.error(c)		
error(c)
	end
end)()

if LPH_OBFUSCATED then
	b.log = function() end
	b.warn = function() end
	b.error = function() end
end

return b
end function a.g()
local b = a.load'f'

local c = {}

function c.download(d, e)	
if isfile(e) then
		return readfile(e)
	end

	local f = game.HttpGet(game,d)
	if not f or #f == 0 then
		b.error(`failed to download file from {d}`)
		return nil
	end
	writefile(e, f)
	return f
end



return c
end function a.h()


return {}end function a.i()a.load'h'


local c = {
    png = "image",
    jpg = "image",
    jpeg = "image",
    gif = "image",
    webp = "image",
    svg = "image",

    mp3 = "sound",
    wav = "sound",
    ogg = "sound",
    ttf = "font",
}

function c.getNameFromPath(d)    
return d.match(d, "([^/]+)%.[^.]+$")or d.match(d, "([^/]+)$")or nil
end

function c.getExtensionFromPath(d)    
local e = d.match(d, "%.([^./]+)$")
    
if not e then
        return nil
    end

    return e
end

function c.getFullNameFromPath(d)    
return d.match(d, "([^/]+)$")or nil
end

return c end function a.j()
local b = Random.new()
local c = b.NextInteger

local d = utf8.char

local e = {}

local f = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

LPH_NO_VIRTUALIZE(function()
	function e.random(g)		
local h = ""

		for i = 1, g or 15 do
			h ..= d(c(b, 33, 255))
		end

		return h
	end

	function e.randomSafe(g)		
local h = ""

		for i = 1, g or 15 do
			local j = c(b, 1, #f)
			h ..= f.sub(f,j, j)
		end

		return h
	end
end)()

return e
end function a.k()
local b = a.load'i'a.load'h'

local d = a.load'j'a.load'f'


local f = game.GetService(game, "HttpService")

local g = {}

function g.load(h, i)	
local j = b[b.getExtensionFromPath(i)]

	if j == "image" or j == "sound" then
		return j, g.loadGeneric(h, i)
	elseif j == "font" then
		return j, g.loadFont(h, i)
	end

	return "unknown", nil
end

function g.loadFont(h, i)	
local j = d.randomSafe()
	local k = j .. ".font.json"

	writefile(
		k,
		f.JSONEncode(		f, {
name=j,
faces={
				{
name="Bold",
weight=700,
style="normal",
assetId=getcustomasset(i),
				},
			},
		})	
)

	local l = Font.new(getcustomasset(k), Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	delfile(k)

	return l
end

function g.loadGeneric(h, i)	
return getcustomasset(i)
end

return g
end function a.l()
local b = {
    unknown = {},
    image = {},
    sound = {},
    font = {},
} 

return b end function a.m()
return a.load'b'.get"Charm"end function a.n()

return a.load'b'.get"Sift"end function a.o()

local b = a.load'm'

local c = b.atom













local d = {
	notifications = (c({} ) ),
	heights = (c({} ) ),
}



return d
end function a.p()
local b = a.load'm'
local c = a.load'n'

local d = a.load'o'

local e = b.peek

local f = 0.4

















local g = {}

local h = 0

local function findIndex(i, j)	
for k, l in next, i do
		if l.id == j then
			return k
		end
	end
	return nil
end

function g.Push(i)	
h += 1
	local j = `notif_{h}`

	local k= {
		id = j,
		title = i.title,
		subtext = i.subtext,
		icon = i.icon,
		showProgress = i.showProgress == true,
		progress = i.showProgress and (i.progress or 0) or nil,
		duration = i.duration,
		removing = false,
		createdAt = os.clock(),
	}

	local l = e(d.notifications)
	d.notifications(c.Array.push(l, k))

	if i.duration and i.duration > 0 then
		task.delay(i.duration, function()
			g.Dismiss(j)
		end)
	end

	return j
end

function g.Update(i, j)	
local k = e(d.notifications)
	local l = findIndex(k, i)
	if not l then
		return
	end

	local m = k[l]
	if m.removing then
		return
	end

	d.notifications(c.Array.set(k, l, c.Dictionary.merge(m, j)))
end

function g.Dismiss(i)	
local j = e(d.notifications)
	local k = findIndex(j, i)
	if not k then
		return
	end

	local l = j[k]
	if l.removing then
		return
	end

	d.notifications(c.Array.set(j, k, c.Dictionary.merge(l, { removing = true })))

	task.delay(f, function()
		local m = e(d.notifications)
		d.notifications(c.Array.filter(m, function(n)
			return n.id ~= i
		end))

		local n = e(d.heights)
		if n[i] ~= nil then
			d.heights(((c.Dictionary.removeKey ))(n, i))
		end
	end)
end

function g.Clear()	
local i = e(d.notifications)
	for j, k in next, i do
		g.Dismiss(k.id)
	end
end

return g
end function a.q()
local b = a.load'g'
local c = a.load'i'
local d = a.load'k'
local e = a.load'l'
local f = a.load'p'
local g = a.load'f'

















local h = {}

local function ensureFolder(i)	
if isfolder and not isfolder(i) then
		makefolder(i)
	end
end

function h.queue(i)	
ensureFolder(i.folder)

	local j= {}
	for k, l in next, i.files do
		local m = `{i.folder}/{l.name}`
		if not isfile(m) then
			table.insert(j, l)
		end
	end

	local k = #j
	if k == 0 then
		if i.onComplete then
			i.onComplete(0, 0)
		end
		return
	end

	local l = f.Push{
		title = i.title,
		subtext = `0 / {k}`,
		icon = i.icon,
		showProgress = true,
		progress = 0,
	}
	
task.spawn(function()		
local m = 0
		local n = 0

		for o, p in next, j do
			local q = `{i.folder}/{p.name}`
			local r = i.urlPrefix .. p.remote

			local s, t = pcall(b.download, r, q)
			if not s or t == nil then
				n += 1
				g.warn(`failed to download {r}`)
			else
				if i.autoLoad ~= false then
					local u = c[c.getExtensionFromPath(q) or ""]
					if u and u ~= "unknown" then
local v, w =d.load(t, q)
						local x = c.getNameFromPath(q)
						if w and x then
							e[u][x] = w
						end
					end
				end
				m += 1
			end

			f.Update(l, {
				progress = o / k,
				subtext = `{o} / {k}`,
			})
		end

		f.Update(l, {
			title = i.title,
			subtext = n > 0 and `Done ({n} failed)` or "Done",
			progress = 1,
		})

		task.delay(2, function()			
f.Dismiss(l)
		end)

		if i.onComplete then
			i.onComplete(m, n)
		end
	end)
end

return h
end function a.r()
local b = {
	url = "https://limerence.biz/get/",
	dir = {
		["limerence.biz"] = {
			assets = {
				fonts = {
					["light.ttf"] = "light.ttf",
					["bold.ttf"] = "bold.ttf",
					["semi_bold.ttf"] = "semi_bold.ttf",
					["pixel.ttf"] = "pixel.ttf",
					["pixel2.ttf"] = "pixel2.ttf",
				},
				images = {
					["logo.png"] = "logo.png",
					["keybinds.png"] = "keybinds.png",
					["draw.png"] = "draw.png",
					["down_arrow.png"] = "down_arrow.png",
					["latency.png"] = "latency.png",
					["computer.png"] = "computer.png",
					["double_right_arrow.png"] = "double_right_arrow.png",
					["terrain.png"] = "terrain.png",
					["rifle.png"] = "rifle.png",
					["search.png"] = "search.png",
					["paintbrush.png"] = "paintbrush.png",
					["cog.png"] = "cog.png",
					["transparency.png"] = "transparency.png",
					["color.png"] = "color.png",
					["drop.png"] = "drop.png",
					["trash.png"] = "trash.png",
					["point.png"] = "point.png",
					["options.png"] = "options.png",
					["checkmark.png"] = "checkmark.png",
					["filter.png"] = "filter.png",
					["write.png"] = "write.png",
					["disk.png"] = "disk.png",
					["load.png"] = "load.png",
					["curved_right_arrow.png"] = "curved_right_arrow.png",
					["pencil.png"] = "pencil.png",
					["shadow.png"] = "shadow.png",
					["aim.png"] = "aim.png",
					["person.png"] = "person.png",
					["file.png"] = "file.png",
					["refresh.png"] = "refresh.png",
					["unload.png"] = "unload.png",
					["loaded_config.png"] = "loaded_config.png",
					["saved_config.png"] = "saved_config.png",
					["bolt.png"] = "bolt.png",
					["download.png"] = "download.png",
					["skull_small.png"] = "skull_small.png",
					["scope_small.png"] = "scope_small.png",
					["grave_small.png"] = "grave_small.png",
					["beam.png"] = "beam.png",
					["hitmarker.png"] = "hitmarker.png",
					["karambit.png"] = "karambit.png",
					["circle_shadow.png"] = "circle_shadow.png",
					["server.png"] = "server.png",
					["tag.png"] = "tag.png",
					["join.png"] = "join.png",
					["delete.png"] = "delete.png",
					["copy_link.png"] = "copy_link.png",
					["set_state.png"] = "set_state.png",
					["flame.png"] = "flame.png",
					["he_grenade.png"] = "he_grenade.png",
					["molotov.png"] = "molotov.png",
					["incendiary.png"] = "incendiary.png",
					["clear.png"] = "clear.png",
					["c4.png"] = "c4.png",
					["clock.png"] = "clock.png",
				},
			},
			cache = {},
			configs = {},
			themes = {},
			luaus = {},
			records = {},
		},
	},
}

return b
end function a.s()
local b = a.load'g'
local c = a.load'i'
local d = a.load'k'
local e = a.load'q'
local f = a.load'r'
local g = a.load'l'a.load'h'

local i = a.load'p'
local j = a.load'f'

local k = {}







local l = LPH_NO_VIRTUALIZE(function()	
local l= {}

	local function walk(m, n)
		for o, p in next, n do
			local q = m and (m .. "/" .. o) or o
			local r = type(p)
			if r == "table" then
				if not isfolder(q) then
					makefolder(q)
				end
				walk(q, p)
			elseif r == "string" then
				l[#l + 1] = {
					path = q,
					url = f.url .. p,
					missing = not isfile(q),
				}
			end
		end
	end

	walk(nil, f.dir)

	return l
end)

function k.new()	
local m = l()

	local n = 0
	for o, p in next, m do
		if p.missing then
			n += 1
		end
	end

	local o	
if n > 0 then
		o = i.Push{
			title = "Downloading assets",
			subtext = `0 / {n}`,
			showProgress = true,
			progress = 0,
		}	
end

	local p = 0
	for q, r in next, m do
		local s = b.download(r.url, r.path)

		local t = k.Load(r.path, s)
		if not t then
			j.warn(`failed to load core file {r.path}`)
		end

		if o and r.missing then
			p += 1
			i.Update(o, {
				progress = p / n,
				subtext = `{p} / {n}`,
			})
		end
	end

	if o then
		i.Update(o, {
			title = "Assets downloaded",
			subtext = `{n} / {n}`,
			progress = 1,
		})
		local q = o
		task.delay(1.5, function()			
i.Dismiss(q)
		end)
	end

	return k
end

function k.Load(m, n)	
local o, p = d.load(n or readfile(m), m)
	if not p then
		j.log(`no data found for file {m}`)
		return false
	end

	local q = c.getNameFromPath(m)
	if not q then
		return false
	end

	local r = g[o]
	r[q] = p

	j.log(`loaded file {m} as {o}`)
	return true
end

function k.Get(m, n)	
local o = g[m]
	if not o then
		return nil
	end
	return o[n]
end

function k.QueueDownload(m)	
e.queue(m)
end

function k.Destroy()	
return
end



return k
end function a.t()
return a.load'b'.get"ReactRoblox"end function a.u()

local b = a.load'j'

local c = {}

local d= {
	Secure = function(d)		
local e = (getrawmetatable(d) )
		
local f = {
			__tostring = function()
				return LPH_CRASH()
			end,
			__iter = function()
				return LPH_CRASH()
			end,
			__len = function()
				return LPH_CRASH()
			end,
		}

		for g, h in next, e do
			if not f[g] then
				f[g] = h
			end
		end

		setrawmetatable(d, f)
	end,
}

c.newSimple = LPH_NO_VIRTUALIZE(function(e, f, g)	
local h = (Instance.new(e) )
	
for i, j in next, f do
		h[i] = j
	end

	if g then
		h.Parent = g
	end

	return h
end)

c.new = LPH_JIT_MAX(function(e, f, g)	
local h = (Instance.new(e) )
	
for i, j in next, f do
		local k = d[i]
		if k then
			k(h)
			continue
		end

		h[i] = j
	end

	if g then
		h.Parent = g
	end

	h.Name = b.random()

	return h
end)

return c
end function a.v()
local b = a.load't'

local c = a.load'u'

local function appRoot()    
local d = (c.new("ScreenGui", {
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
        Secure = true,
        Enabled = true,
        DisplayOrder = 100,
    }, cloneref(gethui())) )
    
return b.createRoot(d), d
end

return appRoot end function a.w()a.load't'

local c = a.load'd'
local d = a.load'c'
local e = a.load'm'
local f = a.load'v'

local g = d.createElement

local h = {
	_elementsAtom = e.atom({} ),
	_screenGui = nil ,
	_root = nil ,
	_mounted = false,
}

local function AppRoot()	
local i = c.useAtom(h._elementsAtom)
	local j= {}
	for k, l in next, i do
		j[`slot_{k}`] = l
	end
	return g(d.Fragment, nil, j)
end

function h.new()	
local i, j = f()

	h._screenGui = j
	h._root = i

	return h
end

function h.Start()	
local i = h._root
	if not i or h._mounted then
		return
	end

	h._mounted = true
	i.render(	i,g(AppRoot))
end

function h.Render(i)	
local j = e.peek(h._elementsAtom)
	local k= {}
	for l, m in next, j do
		k[l] = m
	end
	k[#k + 1] = i
	h._elementsAtom(k)
end

function h.Destroy()	
local i = h._root

	h._mounted = false
	h._elementsAtom{}
	
if not i then
		return
	end
	h._root = nil

	i.unmount(
	i)

	local j = h._screenGui
	if j then
		j.Destroy(		j)
		h._screenGui = nil
	end
end


return h
end function a.x()



return {}end function a.y()
local b = a.load'm'a.load'x'


local d = b.atom

local e = {}
e.__index = e

local function constructor(f, g)	
local h = (setmetatable({}, e) )
	
h.name = f
	h.inputs = d{}	
h.callback = g
	h.mode = d("toggle" )
	h.active = (d(false) )
	
return h
end

function e.SetMode(f, g)	
f.mode(g)

	return f
end

function e.SetInputs(f, g)	
f.inputs(g)

	return f
end












return constructor
end function a.z()
local b = a.load'm'a.load'y'


local d = b.atom

local e = {
	binds = (d{}),
	activeBinds = (d{}),
}




return e
end function a.A()
local b = a.load'm'
local c = a.load'n'
local d = a.load'z'a.load'y'


local f = b.peek

local g = {}

LPH_JIT_MAX(function()
	local function deactivateBind(h)		
if not f(h.active) then
			return
		end

		local i = d.activeBinds
		i(c.Dictionary.removeKey(f(i), h.name))

		h.active(false)
		h.callback(false)
	end

	local function activateBind(h)		
if f(h.active) then
			return
		end

		local i = d.activeBinds
		i(c.Dictionary.set(f(i), h.name, h))

		h.active(true)
		h.callback(true)
	end

	local function matchesInput(h, i)		
local j = f(h.inputs)
		return c.Array.contains(j, i.KeyCode) or c.Array.contains(j, i.UserInputType)
	end

	function g.onInputBegan(h)		
for i, j in next, f(d.binds) do
			if not matchesInput(j, h) then
				continue
			end

			local k = f(j.mode)
			if k == "onHold" then
				activateBind(j)
			elseif k == "offHold" then
				deactivateBind(j)
			elseif k == "toggle" then
				if f(j.active) then
					deactivateBind(j)
				else
					activateBind(j)
				end
			elseif k == "onPress" then
				j.callback(true)
			end
		end
	end

	function g.onInputEnded(h)		
for i, j in next, f(d.binds) do
			if not matchesInput(j, h) then
				continue
			end

			local k = f(j.mode)
			if k == "onHold" then
				deactivateBind(j)
			elseif k == "offHold" then
				activateBind(j)
			elseif k == "onRelease" then
				j.callback(true)
			end
		end
	end
end)()




return g
end function a.B()
return a.load'b'.get"Janitor"end function a.C()

return a.load'b'.get"Signal"end function a.D()

local b = (cloneref(game.GetService(game, "ContextActionService")) )
cloneref(game.GetService(game, "UserInputService")) 

local d = a.load'j'
local e = a.load'B'
local f = a.load'C'
local g = a.load'n'

local h = {
	inputBegan = f.new(),
	inputEnded = f.new(),
	_isFrozen = false,
	_janitor = e.new(),
}

local i = g.Array.join(Enum.UserInputType:GetEnumItems(), Enum.KeyCode:GetEnumItems())

function h.init()
	h.unfreeze(true)
end

function h.freeze()	
if h._isFrozen then
		return
	end
	h._isFrozen = true

	local j = h._janitor
	j.Cleanup(	j)

	local k = d.random()
	b.BindCoreAction(
	b,		k,
		LPH_NO_VIRTUALIZE(function(l, m, n)			
if l ~= k then
				return
			end

			if m == Enum.UserInputState.Begin then
				h.onInput(n)
			elseif m == Enum.UserInputState.End then
				h.onInputEnd(n)
			end
		end),
		false,
		table.unpack(i)
	)

	j.Add(
	j,function()
		b.UnbindCoreAction(		b,k)
	end, true)
end

function h.unfreeze(j)	if not h._isFrozen and not j then
		return
	end
	h._isFrozen = false

	local k = h._janitor
	k.Cleanup(	k)

	local l = d.random()
	b.BindCoreAction(
	b,		l,
		LPH_NO_VIRTUALIZE(function(m, n, o)			
if m ~= l then
				return
			end

			if n == Enum.UserInputState.Begin then
				h.onInput(o)
			elseif n == Enum.UserInputState.End then
				h.onInputEnd(o)
			end

			return Enum.ContextActionResult.Pass
		end),
		false,
		table.unpack(i)
	)

	k.Add(
	k,function()
		b.UnbindCoreAction(		b,l)
	end, true)
end

function h.onInput(j)	h.inputBegan:Fire(j)
end

function h.onInputEnd(j)	
h.inputEnded:Fire(j)
end



return h
end function a.E()
local b = a.load'm'

local c = b.atom

local d = {
    isOpen = c(false),
}



return d end function a.F()
local b = a.load'm'
local c = a.load'n'

local d = a.load'A'
local e = a.load'y'
local f = a.load'z'
local g = a.load'D'
local h = a.load'E'

local i = b.peek
local j = b.subscribe

local k = {}

function k.new()	
g.inputBegan:Connect(d.onInputBegan)
	g.inputEnded:Connect(d.onInputEnded)
	g.init()

	j(h.isOpen, function(l)		
if l then
			g.freeze()
		else
			g.unfreeze(false)
		end
	end)

	return k
end

function k.AddBind(l, m)	
local n = e(l, m)
	k._registerBind(n)

	return n
end

function k._registerBind(l)	
local m = f.binds
	local n = i(f.binds)
	m(c.Dictionary.set(n, l.name, l))
end

function k.RemoveBind(l)	
local m = i(f.binds)
	if m[l] == nil then
		return
	end
	f.binds(c.Dictionary.removeKey(m, l))

	local n = i(f.activeBinds)
	if n[l] ~= nil then
		f.activeBinds(c.Dictionary.removeKey(n, l))
	end
end

function k.Destroy()	
g._janitor:Destroy()
end




return k
end function a.G()


local b = {}

b.DEFAULT = { "cheat", "game", "ping", "fps", "playtime", "username" }

local c= {
	cheat = true,
	game = true,
	ping = true,
	fps = true,
	playtime = true,
	username = true,
}

function b.normalize(d)	
local e= {}
	local f= {}

	if type(d) == "table" then
		for g, h in next, d do
			if type(h) == "string" and c[h] and not f[h] then
				f[h] = true
				e[#e + 1] = h 			
end
		end
	end

	for g, h in next, b.DEFAULT do
		if not f[h] then
			e[#e + 1] = h
		end
	end

	return e
end

function b.swap(d, e, f)	
if e == f then
		return d
	end
	local g= {}
	for h, i in next, d do
		g[h] = i
	end
	local h = g[e]
	table.remove(g, e)
	table.insert(g, f, h)
	return g
end

function b.indexOf(d, e)	
for f, g in next, d do
		if g == e then
			return f
		end
	end
	return nil
end

return b
end function a.H()
local b = a.load'm'

local c = a.load'G'

local d = b.atom

local e = {
	enabled = d(false),
	position = d(UDim2.new(1, -10, 0, 10)),
	itemOrder = d(c.DEFAULT),
	showUsername = d(true),
	showCheat = d(true),
	showGame = d(true),
	showPing = d(true),
	showFps = d(true),
	showPlaytime = d(true),
}



return e
end function a.I()
local b = a.load'm'

local c = b.atom

local d = {
	scale = (c(1) ),
}

d.OPTIONS = { 1, 1.25, 1.5, 1.75, 2 } 
d.LABELS = { "100%", "125%", "150%", "175%", "200%" } 

function d.labelFor(e)	
for f, g in next, d.OPTIONS do
		if g == e then
			return d.LABELS[f]
		end
	end
	return "100%"
end

function d.scaleFor(e)	
for f, g in next, d.LABELS do
		if g == e then
			return d.OPTIONS[f]
		end
	end
	return 1
end

return d
end function a.J()
local b = a.load'm'
local c = a.load'f'
local d = (cloneref(game.GetService(game, "HttpService")) )
local e = a.load'H'
local f = a.load'G'
local g = a.load'I'

local h = b.atom
local i = b.peek

local j = {}

local k = "limerence.biz/user.json"

j.theme = (h(nil ) )
j.autoloadConfig = (h(nil ) )
j.developerMode = (h(false) )
j.showMenuOnStartup = (h(true) )
j.menuToggleKey = (h("KeyCode.LeftAlt" ) )
j.usernameDisplayMode = (h("roblox" ) )
j.usernameCustom = (h"")
j.dpiScale = (h(1) )

local l = j.theme
local m = j.autoloadConfig
local n = j.developerMode
local o = j.showMenuOnStartup
local p = j.menuToggleKey
local q = j.usernameDisplayMode
local r = j.usernameCustom
local s = j.dpiScale

local function persist()	
local t = i(e.position)
	local u = {
		theme = i(l),
		autoloadConfig = i(m),
		developerMode = i(n),
		showMenuOnStartup = i(o),
		menuToggleKey = i(p),
		usernameDisplayMode = i(q),
		usernameCustom = i(r),
		dpiScale = i(s),
		watermark = {
			showUsername = i(e.showUsername),
			showCheat = i(e.showCheat),
			showGame = i(e.showGame),
			showPing = i(e.showPing),
			showFps = i(e.showFps),
			showPlaytime = i(e.showPlaytime),
			itemOrder = i(e.itemOrder),
			position = {
				xScale = t.X.Scale,
				xOffset = t.X.Offset,
				yScale = t.Y.Scale,
				yOffset = t.Y.Offset,
			},
		},
	}
	writefile(k, d.JSONEncode(d,u))
end

function j.GetTheme()	
return i(l)
end

function j.SetTheme(t)	
if i(l) == t then
		return
	end
	l(t)
	persist()
end

function j.GetAutoloadConfig()	
return i(m)
end

function j.SetAutoloadConfig(t)	
if i(m) == t then
		return
	end
	m(t)
	persist()
end

function j.GetDeveloperMode()	
return i(n)
end

function j.SetDeveloperMode(t)	
if i(n) == t then
		return
	end
	n(t)
	persist()
end

function j.GetShowMenuOnStartup()	
return i(o)
end

function j.SetShowMenuOnStartup(t)	
if i(o) == t then
		return
	end
	o(t)
	persist()
end

function j.GetMenuToggleKey()	
return i(p)
end

function j.SetMenuToggleKey(t)	
if i(p) == t then
		return
	end
	p(t)
	persist()
end

function j.GetUsernameDisplayMode()	
return i(q)
end

function j.SetUsernameDisplayMode(t)	
if i(q) == t then
		return
	end
	q(t)
	persist()
end

function j.GetUsernameCustom()	
return i(r)
end

function j.SetUsernameCustom(t)	
if i(r) == t then
		return
	end
	r(t)
	persist()
end

local function normalizeDpiScale(t)	
if type(t) ~= "number" then
		return 1
	end
	for u, v in next, g.OPTIONS do
		if v == t then
			return v
		end
	end
	return 1
end

function j.GetDpiScale()	
return i(s)
end

function j.SetDpiScale(t)	
local u = normalizeDpiScale(t)
	if i(s) == u then
		return
	end
	s(u)
	g.scale(u)
	persist()
end

function j.new()	
if isfile(k) then
		local t, u = pcall(function()
			return d.JSONDecode(d,readfile(k))
		end)

		if t and type(u) == "table" then
			if type(u.theme) == "string" then
				local v = u.theme
				if v == "Default" then
					v = "Dark"
				end
				l(v)
			end
			if type(u.autoloadConfig) == "string" then
				m(u.autoloadConfig)
			end
			if type(u.developerMode) == "boolean" then
				n(u.developerMode)
			end
			if type(u.showMenuOnStartup) == "boolean" then
				o(u.showMenuOnStartup)
			end
			if type(u.menuToggleKey) == "string" then
				p(u.menuToggleKey)
			end
			if type(u.usernameDisplayMode) == "string" then
				q(u.usernameDisplayMode)
			end
			if type(u.usernameCustom) == "string" then
				r(u.usernameCustom)
			end
			if type(u.dpiScale) == "number" then
				local v = normalizeDpiScale(u.dpiScale)
				s(v)
				g.scale(v)
			end
			if type(u.watermark) == "table" then
				local v = u.watermark
				if type(v.showUsername) == "boolean" then e.showUsername(v.showUsername) end
				if type(v.showCheat) == "boolean" then e.showCheat(v.showCheat) end
				if type(v.showGame) == "boolean" then e.showGame(v.showGame) end
				if type(v.showPing) == "boolean" then e.showPing(v.showPing) end
				if type(v.showFps) == "boolean" then e.showFps(v.showFps) end
				if type(v.showPlaytime) == "boolean" then e.showPlaytime(v.showPlaytime) end
				if type(v.itemOrder) == "table" then
					e.itemOrder(f.normalize(v.itemOrder))
				end
				if type(v.position) == "table" then
					local w = v.position
					if type(w.xScale) == "number" and type(w.xOffset) == "number"
						and type(w.yScale) == "number" and type(w.yOffset) == "number"
					then
						e.position(UDim2.new(w.xScale, w.xOffset, w.yScale, w.yOffset))
					end
				end
			end
			c.log"loaded user preferences"		
end
	end

	for t, u in next, {
		e.showUsername,
		e.showCheat,
		e.showGame,
		e.showPing,
		e.showFps,
		e.showPlaytime,
		e.itemOrder,
	} do
		b.subscribe(u, persist)
	end

	local t	
b.subscribe(e.position, function()
		if t then
			task.cancel(t)
		end
		t = task.delay(1, function()
			t = nil
			persist()
		end)
	end)

	return j
end

function j.Destroy()end



return j
end function a.K()a.load'm'





















return {}
end function a.L()
local b = (cloneref(game.GetService(game, "UserInputService")) )

local c = a.load'm'
local d = a.load'n'

local e = a.load'y'
local f = a.load'F'
local g = a.load'z'a.load'K'


local i = c.atom
local j = c.peek
local k = c.subscribe

local function isInputHeld(l)	
if typeof(l) ~= "EnumItem" then
		return false
	end
	if (l ).EnumType == Enum.KeyCode then
		return b.IsKeyDown(b,l )
	end
	if (l ).EnumType == Enum.UserInputType then
		return b.IsMouseButtonPressed(b,l )
	end
	return false
end

local function isAnyInputHeld(l)	
for m, n in next, l do
		if isInputHeld(n) then
			return true
		end
	end
	return false
end




local l = {
	allBinds = i({} ),
	MAX_BINDS = 3,
}

local m = 0
local n= {}

local function nextId()	
m += 1
	return m
end

local function deactivateBind(o)	
if not j(o.active) then
		return
	end
	local p = j(g.activeBinds)
	g.activeBinds(d.Dictionary.removeKey(p, o.name))
	o.active(false)
	local q = j(g.binds)[o.name]
	if q then
		q.callback(false)
	end
end

local function activateBind(o)	
if j(o.active) then
		return
	end
	local p = j(g.binds)[o.name]
	if not p then
		return
	end
	local q = j(g.activeBinds)
	g.activeBinds(d.Dictionary.set(q, o.name, p))
	o.active(true)
	p.callback(true)
end

local function applyModeReset(o)	
if #j(o.inputs) == 0 then
		deactivateBind(o)
		return
	end
	if j(o.mode) == "offHold" and not isAnyInputHeld(j(o.inputs)) then
		activateBind(o)
	else
		deactivateBind(o)
	end
end

local function wireCallback(o, p)	
local q = j(g.binds)[p.name]
	if not q then
		return
	end

	q.callback = function(r)
		local s = j(p.targetValue)
		if s == nil then
			o._state(r)
		else
			if r then
				if j(p.savedValue) == nil then
					p.savedValue(j(o._state))
				end
				if o.SetValue and type(s) == "number" then
					o.SetValue(					o,s, true)
				else
					o._state(s)
				end
			else
				local t = j(p.savedValue)
				if t ~= nil then
					if o.SetValue and type(t) == "number" then
						o.SetValue(						o,t, true)
					else
						o._state(t)
					end
					p.savedValue(nil)
				end
			end
		end
	end
end

function l.CreateBind(o, p, q)	
local r = nextId()
	local s = `elb_{r}`

	local t = q
	if t == nil then
		local u = j(o._state)
		if type(u) ~= "boolean" then
			t = u
		end
	end

	local u= {
		id = r,
		name = s,
		mode = i("toggle" ),
		inputs = i{},
		targetValue = i(t),
		showInList = i(true),
		active = i(false),
		savedValue = i(nil),
	}

	local v = e(s, function() end)
	v.mode = u.mode
	v.inputs = u.inputs
	v.active = u.active
	f._registerBind(v)

	wireCallback(o, u)

	local w = k(u.mode, function()
		applyModeReset(u)
	end)
	local x = k(u.inputs, function()
		if #j(u.inputs) == 0 then
			deactivateBind(u)
			return
		end
		if j(u.mode) == "offHold" then
			applyModeReset(u)
		end
	end)
	n[r] = function()
		w()
		x()
	end

	local y = j(l.allBinds)
	l.allBinds(d.Array.push(y, {
		element = o,
		label = p,
		bind = u,
	}))

	return u
end

function l.DestroyBind(o)	
deactivateBind(o)

	local p = n[o.id]
	if p then
		p()
		n[o.id] = nil
	end

	local q = j(g.binds)
	g.binds(d.Dictionary.removeKey(q, o.name))

	local r = j(l.allBinds)
	l.allBinds(d.Array.filter(r, function(s)
		return s.bind.id ~= o.id
	end))
end

function l.RestoreActive(o)	
if j(o.active) then
		return
	end
	local p = j(g.binds)[o.name]
	if not p then
		return
	end
	local q = j(g.activeBinds)
	g.activeBinds(d.Dictionary.set(q, o.name, p))
	o.active(true)
end

function l.RewireAll(o)	
local p = j(l.allBinds)
	for q, r in next, p do
		if r.element == o then
			wireCallback(o, r.bind)
		end
	end
end

function l.GetAllBinds()	
return j(l.allBinds)
end

function l.HasBindFor(o)	
for p, q in next, j(l.allBinds) do
		if q.element == o and #j(q.bind.inputs) > 0 then
			return true
		end
	end
	return false
end

function l.GetInputLabel(o)	
local p= {
		[Enum.KeyCode.LeftControl] = "LCtrl",
		[Enum.KeyCode.RightControl] = "RCtrl",
		[Enum.KeyCode.LeftShift] = "LShift",
		[Enum.KeyCode.RightShift] = "RShift",
		[Enum.KeyCode.LeftAlt] = "LAlt",
		[Enum.KeyCode.RightAlt] = "RAlt",
		[Enum.KeyCode.Return] = "Enter",
		[Enum.KeyCode.Backspace] = "Back",
		[Enum.KeyCode.CapsLock] = "Caps",
		[Enum.KeyCode.Space] = "Space",
		[Enum.KeyCode.Delete] = "Del",
		[Enum.KeyCode.Home] = "Home",
		[Enum.KeyCode.End] = "End",
		[Enum.KeyCode.PageUp] = "PgUp",
		[Enum.KeyCode.PageDown] = "PgDn",
		[Enum.UserInputType.MouseButton1] = "LMB",
		[Enum.UserInputType.MouseButton2] = "RMB",
		[Enum.UserInputType.MouseButton3] = "MMB",
	}

	local q = p[o]
	if q then
		return q
	end

	local r = tostring(o)
	return r.match(r, "KeyCode%.(.+)$")or r.match(r, "UserInputType%.(.+)$")or r
end

function l.SerializeInput(o)	
local p = tostring(o)
	return p.match(p, "Enum%.(.+)$")or p
end

function l.DeserializeInput(o)	
local p, q = o.match(o, "^(.-)%.(.+)$")	
if not p or not q then
		return nil
	end
	if p == "KeyCode" then
		return ((Enum.KeyCode ))[q]
	elseif p == "UserInputType" then
		return ((Enum.UserInputType ))[q]
	end
	return nil
end

return l
end function a.M()
local b = a.load'c'
local c = a.load'm'

local d = c.atom
local e = b.createElement

local f = {}
f.__index = f

function f.new()	
local g = (setmetatable({}, f) )
	
g._isOpen = d(false)
	g._position = d(UDim2.fromScale(0, 0))

	return g
end

function f.SetPosition(g, h)	
g._position(h)
end

function f.SetOpen(g, h)	
g._isOpen(h)
end

function f.Render(g)	
return e("Frame", {
		BackgroundTransparency = 1,
	}, {})
end









return f
end function a.N()
local b = a.load'm'

local c = b.atom

local function number(d)	
return c(d)
end

local function rgba(d, e, f, g)	
return c{
(		Color3.fromRGB(d, e, f) ),
		g,
	}
end

local function rgb(d, e, f)	
return c(Color3.fromRGB(d, e, f))
end

local d = {
	colors = {
		canvas = {
			background = rgba(10, 10, 10, 0.4),
		},

		hud = {
			background = rgba(30, 30, 30, 0.2),
			backgroundSecondary = rgba(28, 28, 28, 0.4),
			bar = rgb(42, 42, 42),
			danger = rgb(220, 95, 95),
			good = rgb(120, 200, 130),
			image = rgb(177, 177, 177),
			neutral = rgb(200, 186, 160),
			shadow = rgba(0, 0, 0, 0.42),
			stroke = rgba(33, 33, 33, 0.5),
			text = rgb(178, 178, 178),
			textMuted = rgb(115, 115, 115),
			title = rgb(229, 229, 229),
			warning = rgb(220, 190, 110),
		},

		inventory = {
			cardBackground = rgb(26, 26, 26),
			cardBackgroundHover = rgb(32, 32, 32),
			cardImageBg = rgb(18, 18, 18),
			cardSkinName = rgb(228, 228, 228),
			cardWeaponName = rgb(130, 130, 130),
			tabIndicator = rgb(225, 225, 225),

			rarity = {
				common = rgb(176, 195, 217),
				uncommon = rgb(75, 106, 255),
				restricted = rgb(136, 71, 255),
				classified = rgb(211, 44, 230),
				covert = rgb(235, 75, 75),
				extraordinary = rgb(255, 215, 0),
				master = rgb(228, 174, 57),
			},
		},

		notify = {
			background = rgba(30, 30, 30, 0.2),
			backgroundSecondary = rgba(28, 28, 28, 0.4),
			image = rgb(177, 177, 177),
			progress = rgb(229, 229, 229),
			shadow = rgba(0, 0, 0, 0.42),
			stroke = rgba(33, 33, 33, 0.5),
			text = rgb(178, 178, 178),
			title = rgb(229, 229, 229),
		},

		status = {
			danger = rgb(220, 95, 95),
			good = rgb(120, 200, 130),
			neutral = rgb(160, 160, 160),
			placeholder = rgb(110, 110, 110),
			warning = rgb(220, 190, 110),
		},

		subwindow = {
			background = rgb(28, 28, 28),
			divider = rgb(40, 40, 40),
			image = rgb(140, 140, 140),
			stroke = rgb(44, 44, 44),
			text = rgb(200, 200, 200),
			title = rgb(228, 228, 228),
		},

		window = {
			background = rgb(22, 22, 22),
			divider = rgb(32, 32, 32),
			logo = rgb(150, 150, 150),
			searchMuted = rgb(108, 108, 108),
			shadow = rgba(8, 8, 8, 0.5),
			sidebar = rgb(18, 18, 18),
			stroke = rgb(38, 38, 38),
			tabHeading = rgb(108, 108, 108),
			tabIcon = rgb(176, 176, 176),
			tabLabel = rgb(176, 176, 176),
			tabLabelSelected = rgb(225, 225, 225),
			tabStroke = rgb(45, 45, 45),
			tabSurface = rgb(30, 30, 30),
			title = rgb(230, 230, 230),
			toolbar = rgb(20, 20, 20),

			section = {
				background = rgb(30, 30, 30),
				stroke = rgb(42, 42, 42),
				text = rgb(104, 104, 104),
			},

			element = {
				accent = rgb(120, 120, 120),
				accentSoft = rgb(66, 66, 66),
				accentStrong = rgb(190, 190, 190),
				caption = rgb(128, 128, 128),
				captionActive = rgb(196, 196, 196),
				fieldBackground = rgb(42, 42, 42),
				fieldBackgroundActive = rgb(56, 56, 56),
				fieldStroke = rgb(54, 54, 54),
				fieldStrokeActive = rgb(76, 76, 76),
				filterIcon = rgb(94, 94, 94),
				icon = rgb(140, 140, 140),
				iconActive = rgb(178, 178, 178),
				panel = rgb(26, 26, 26),
				panelStroke = rgb(42, 42, 42),
				rowHover = rgb(255, 255, 255),
				scrollThumb = rgb(140, 140, 140),
				surface = rgb(40, 40, 40),
				surfaceStroke = rgb(50, 50, 50),
				text = rgb(168, 168, 168),
				textActive = rgb(222, 222, 222),
				thumb = rgb(130, 130, 130),
				thumbActive = rgb(225, 225, 225),
				thumbHighlight = rgb(255, 255, 255),
				thumbStroke = rgb(22, 22, 22),
			},
		},
	},
	other = {
		animationSpeed = number(1),
		darkHoverTint = number(0.22),
		hoverTint = number(0.08),
	},
}



return d
end function a.O()







local b= {
	snap = {
		tension = 1700,
		friction = 65,
		precision = 0.01,
	},
	quick = {
		tension = 950,
		friction = 55,
		precision = 0.01,
	},
	quickPrecise = {
		tension = 1000,
		friction = 56,
		precision = 0.015,
	},
	smooth = {
		tension = 1000,
		friction = 65,
		precision = 0.005,
	},
	smoothPrecise = {
		tension = 1350,
		friction = 63,
		precision = 0.01,
	},
	subtle = {
		tension = 650,
		friction = 55,
	},
}

return b
end function a.P()


local b = 0

local c = {
	context = nil ,
	subwindows = {} ,
}

function c.containsScreenPoint(d, e, f)	
if not d then
		return false
	end
	local g = d.current
	if not g then
		return false
	end
	if not g.Visible then
		return false
	end
	local h= g
	while h and h.ClassName == "GuiObject" do
		if not h.Visible then
			return false
		end
		h = h.Parent
	end
	local i = g.AbsolutePosition
	local j = g.AbsoluteSize
	if j.X <= 0 or j.Y <= 0 then
		return false
	end
	return e >= i.X and e <= i.X + j.X and f >= i.Y and f <= i.Y + j.Y
end

local function isDescendantOf(d, e)	
if not d or not e then
		return false
	end
	local f= e
	while f do
		if f == d then
			return true
		end
		f = f.Parent
	end
	return false
end

function c.topmostFloatingRootAt(d, e)	
if c.containsScreenPoint(c.context, d, e) then
		local f = c.context.current
		if f then
			return f
		end
	end
	local f	
local g = -1	
for h, i in next, c.subwindows do
		if c.containsScreenPoint(h, d, e) and i > g then
			g = i
			f = h.current
		end
	end
	return f
end

function c.floatingOccludesElementAt(d, e, f)	
local g = c.topmostFloatingRootAt(e, f)
	if not g then
		return false
	end
	return not isDescendantOf(g, d)
end

function c.add(d, e)	
c.subwindows[d] = e
end

function c.remove(d)	
c.subwindows[d] = nil
end

function c.getNextOrder()	
b += 1
	return b
end

return c
end function a.Q()
local b = (cloneref(game.GetService(game, "UserInputService")) )

local c = a.load'c'

local d = a.load'P'

local e = c.useEffect
local f = c.useRef

local g = LPH_NO_VIRTUALIZE(function(g, h, i)	
if not g then
		return false
	end
	local j = g.current
	if not j then
		return false
	end
	if not j.Visible then
		return false
	end
	local k= j
	while k and k.ClassName == "GuiObject" do
		if not k.Visible then
			return false
		end
		k = k.Parent
	end
	local l = j.AbsolutePosition
	local m = j.AbsoluteSize
	if m.X <= 0 or m.Y <= 0 then
		return false
	end
	return h >= l.X and h <= l.X + m.X and i >= l.Y and i <= l.Y + m.Y
end)

local h = LPH_NO_VIRTUALIZE(
	function(
		h,
		i,
		j,
		k	
)		
local l = f(j)
		l.current = j

		local m = f(k)
		m.current = k

		e(function()
			if not i then
				return
			end

			local n			
local o = false

			task.defer(function()
				if o then
					return
				end

				n = b.InputBegan:Connect(function(p)
					local q = p.UserInputType
					if
						q ~= Enum.UserInputType.MouseButton1
						and q ~= Enum.UserInputType.MouseButton2
						and q ~= Enum.UserInputType.Touch
					then
						return
					end

					local r = h.current
					if not r then
						return
					end

					local s = p.Position.X
					local t = p.Position.Y

					if g(h, s, t) then
						return
					end

					if d.context ~= h and g(d.context, s, t) then
						return
					end

					local u = d.subwindows[h] or 0
					for v, w in next, d.subwindows do
						if v ~= h and w > u and g(v, s, t) then
							return
						end
					end

					local v = m.current
					if v then
						for w, x in next, v do
							if g(x, s, t) then
								return
							end
						end
					end

					l.current()
				end)
			end)

			return function()
				o = true
				if n then
					n.Disconnect(					n)
					n = nil
				end
			end
		end, { i } )
	end
)

return h
end function a.R()
local b = (cloneref(game.GetService(game, "Workspace")) )

local c = a.load'm'
local d = a.load'I'

local e = 10

local f = {}

f.PADDING = e

LPH_NO_VIRTUALIZE(function()
	local function getViewportRect(g)		
if g then
			local h = g.FindFirstAncestorWhichIsA(g, "LayerCollector")			
if h then
				return h.AbsolutePosition, h.AbsoluteSize
			end
		end

		local h = b.CurrentCamera
		local i = h and h.ViewportSize or Vector2.new(1920, 1080)
		return Vector2.zero, i
	end

	f.getViewportRect = getViewportRect

	function f.computeDelta(
		g,
		h,
		i,
		j,
		k	
)		
local l = k or e

		local m = i.X + l
		local n = i.Y + l
		local o = math.max(m, i.X + j.X - h.X - l)
		local p = math.max(n, i.Y + j.Y - h.Y - l)

		local q = math.clamp(g.X, m, o)
		local r = math.clamp(g.Y, n, p)

		return Vector2.new(q - g.X, r - g.Y)
	end

	function f.compute(g, h)		
local i = g.AbsoluteSize
		if i.X < 1 or i.Y < 1 then
			return Vector2.zero
		end

		local j, k = getViewportRect(g)
		local l =
			f.computeDelta(g.AbsolutePosition, i, j, k, h)

		local m = c.peek(d.scale)
		if m <= 0 then
			m = 1
		end
		if m == 1 then
			return l
		end
		return l / m
	end
end)()

return f
end function a.S()
local b = a.load'm'
local c = a.load'n'
local d = a.load'E'

local e = b.atom
local f = b.peek



local g= {
	TOOLTIP = 1,
	DROPDOWN = 2,
	MENU = 3,
	MODAL = 4,
}







local h= {}
local i = 0
local j = 0
local k = 0.2

local l = {
	PRIORITY = g,
	activePriority = (e(0) ),
	activeIds = (e({} ) ),
}

local function recomputeActive()	
local m = 0
	local n= {}
	for o, p in next, h do
		n[o] = p.priority
		if p.priority > m then
			m = p.priority
		end
	end
	l.activePriority(m)
	l.activeIds(n)
end

function l.Register(m, n, o)	
if type(m) ~= "string" or m == "" then
		return
	end

	local p= {}
	for q, r in next, h do
		if q ~= m and r.priority < n then
			table.insert(p, r)
		end
	end

	h[m] = { id = m, priority = n, dismiss = o }
	recomputeActive()

	for q, r in next, p do
		r.dismiss()
	end
end

function l.Unregister(m)	
local n = h[m]
	if not n then
		return
	end

	h[m] = nil

	if n.priority > g.TOOLTIP then
		i = os.clock() + 0.075
		j = math.max(j, os.clock() + k)
	end

	recomputeActive()
end

function l.IsSubwindowOpenAllowed()	
if not f(d.isOpen) then
		return false
	end
	return os.clock() >= j
end

function l.IsAllowed(m)	
if m <= g.TOOLTIP and os.clock() < i then
		return false
	end
	if m == g.TOOLTIP then
		if not f(d.isOpen) then
			return false
		end
		return true
	end
	return f(l.activePriority) <= m
end

function l.GetHighestActive()	
return f(l.activePriority)
end

function l.GetActive()	
return c.Dictionary.copy(f(l.activeIds))
end

function l.IsActive(m)	
return h[m] ~= nil
end

function l.DismissBelow(m)	
local n= {}
	for o, p in next, h do
		if p.priority < m then
			table.insert(n, p)
		end
	end
	for o, p in next, n do
		p.dismiss()
	end
end

return l
end function a.T()
local b = (cloneref(game.GetService(game, "Workspace")) )

local c = a.load'c'
local d = a.load'e'
local e = a.load'd'a.load'm'


local g = a.load'O'
local h = a.load'Q'
local i = a.load'P'
local j = a.load'R'
local k = a.load'S'

local l = d.useSpring
local m = c.useEffect
local n = c.useState
local o = c.useMemo
local p = c.useBinding
local q = c.useRef
local r = e.useAtom

local s = 10




























local function useSubwindowAnimation(t, u)	
local v = u or {} 	
local w = v.preset or g.smooth
	local x = v.slideOffset or 12
	local y = v.strokeIntensity or 1
	local z = v.clampToViewport ~= false
	local A = v.clampPadding or j.PADDING
	local B = q(v.onClickOutside)
	B.current = v.onClickOutside

	local C = r(t._isOpen)
	local D = r(t._position)

	local E, F = l(0, w)

	m(function()
		F.setGoal(		F,C and 1 or 0)
	end, { C })

	local G = q(nil )

	h(G, C, function()
		local H = B.current
		if H then
			H()
		end
	end)

	local H, I = n(s)

	m(function()
		if not C then
			return
		end
		local J = s + i.getNextOrder()
		I(J)
		i.add(G, J)
		return function()
			i.remove(G)
		end
	end, { C })

	local J = v.floatingId
	local K = v.floatingPriority or k.PRIORITY.MENU
	local L = q(v.onClickOutside)
	L.current = v.onClickOutside

	m(function()
		if not C or not J then
			return
		end
		k.Register(J, K, function()			
local M = L.current
			if M then
				M()
			end
		end)
		return function()
			k.Unregister(J)
		end
	end, { C, J, K })

	local M, N = p(Vector2.zero)

	m(function()
		N(Vector2.zero)
	end, { D })

	m(function()
		if not z or not C then
			return
		end

		local O = G.current
		if not O then
			return
		end

		local P= {}

		local function recompute()			
local Q = G.current
			if not Q then
				return
			end

			local R = j.compute(Q, A)
			if R.X == 0 and R.Y == 0 then
				return
			end

			N(M.getValue(M) + R)
		end

		table.insert(P, O.GetPropertyChangedSignal(O, "AbsoluteSize"):Connect(recompute))

		local Q = O.FindFirstAncestorWhichIsA(O, "LayerCollector")		
if Q then
			table.insert(P, Q.GetPropertyChangedSignal(Q, "AbsoluteSize"):Connect(recompute))
		end

		local R = b.CurrentCamera
		if R then
			table.insert(P, R.GetPropertyChangedSignal(R, "ViewportSize"):Connect(recompute))
		end

		recompute()

		return function()
			for S, T in next, P do
				T.Disconnect(				T)
			end
		end
	end, { C, z, A, D } )

	local O = o(function()
		return c.joinBindings{
			alpha = E,
			clamp = M,
		}:map(function(O)
			local P = O.alpha
			local Q = O.clamp
			local R = (1 - P) * x
			return UDim2.new(
				D.X.Scale,
				((D.X.Offset )) + Q.X,
				D.Y.Scale,
				((D.Y.Offset )) + R + Q.Y
			)
		end)
	end, { E, M, D, x })

	return {
		frameRef = G,
		isOpen = C,
		bind = E,
		zIndex = H,
		position = O,
		visible = E.map(E,function(P)
			return P > 0.01
		end),
		transparency = E.map(E,function(P)
			return 1 - P
		end),
		strokeTransparency = E.map(E,function(P)
			return 1 - P * y
		end),
	}
end

return useSubwindowAnimation
end function a.U()
local b = a.load'c'
local c = a.load's'

local d = b.createElement









local function useShadow(e)	
local f = e or {} 	
local g = f.multiplier or Vector2.new(1.4, 1.4)

	return d("ImageLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(g.X, g.Y),
		Image = c.Get("image", "shadow"),
		ImageColor3 = f.color or Color3.new(0, 0, 0),
		ImageTransparency = f.transparency or 0,
		Visible = f.visible == nil and true or f.visible,
		ZIndex = f.zIndex or 0,
		ScaleType = Enum.ScaleType.Stretch,
	}, {
		UICorner = d("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
	})
end

return useShadow
end function a.V()
local b = a.load'd'
local c = a.load'c'
local d = a.load'n'
local e = a.load'N'
local f = a.load's'
local g = a.load'T'
local h = a.load'U'

local i = e.colors.subwindow

local j = c.useMemo
local k = b.useAtom
local l = c.createElement

return function(m)	
local n = m.Options

	local o = k(n._title)
	local p = k(n._showTitle)
	local q = k(n._elements)

	local r = k(i.background)
	local s = k(i.divider)
	local t = k(i.stroke)
	local u = k(i.title)

	local v = j(function()
		local v = {}
		for w, x in q do
			v["E_" .. w .. "_" .. tostring(x)] = x.Render(x,w)
		end
		return v
	end, { q })

	local w = g(n, {
		slideOffset = 15,
		floatingId = "subwindow.options",
		onClickOutside = function()
			n.Close(			n)
		end,
	})

	return l("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 250, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = w.position,
		Visible = w.visible,
		ZIndex = w.zIndex,
	}, {
		Shadow = h{
			transparency = w.transparency,
			zIndex = 0,
		},
		Body = l("CanvasGroup", {
			ref = w.frameRef,
			BackgroundTransparency = 0,
			BackgroundColor3 = r,
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = Enum.AutomaticSize.Y,
			GroupTransparency = w.transparency,
			ZIndex = 1,
		}, {
			UIStroke = l("UIStroke", {
				Color = t,
				Transparency = w.strokeTransparency,
				Thickness = 1,
			}),
			UIPadding = l("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 11),
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
			}),
			UIListLayout = l("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			UICorner = l("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			TitleFrame = p and l("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 14),
				LayoutOrder = 0,
			}, {
				Title = l("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 14),
					LayoutOrder = 0,
					Text = o,
					TextColor3 = u,
					FontFace = f.Get("font", "semi_bold"),
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Divider = l("Frame", {
					BorderSizePixel = 0,
					BackgroundColor3 = s,
					Size = UDim2.new(1, 0, 0, 2),
					Position = UDim2.fromOffset(0, 18),
					LayoutOrder = 1,
				}),
			}) or nil,
			Elements = l(
				"Frame",
				{
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 2,
				},
				d.Dictionary.join({
					UIListLayout = l("UIListLayout", {
						VerticalAlignment = Enum.VerticalAlignment.Top,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 10),
					}),
					UIPadding = l("UIPadding", {
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
						PaddingTop = UDim.new(0, p and 4 or 1),
						PaddingBottom = UDim.new(0, 0),
					}),
				}, v)
			),
		}),
	})
end
end function a.W()
local b = a.load'm'
local c = a.load'c'

local d = a.load'M'
local e = a.load'V'

local f = b.atom
local g = b.peek
local h = b.subscribe
local i = c.createElement

local j = {}
j.__index = j

setmetatable(j, { __index = d })

local function constructor()	
local k = (d.new() )
	
setmetatable(k, j)

	k._title = f""	
k._showTitle = f(true)
	k._elements = f({} )
	k._source = f(nil )

	h(k._isOpen, function(l)
		if l then
			return
		end
		local m = g(k._source)
		if m and m._open then
			m._open(false)
		end
		k._source(nil )
	end)

	return k
end

function j.Open(k, l, m)	
local n = g(k._source)
	local o = g(k._elements)
	local p = g(l._elements)

	if n == l and o == p and g(k._isOpen) then
		return
	end

	if n and n ~= l and n._open then
		n._open(false)
	end

	if l._open then
		l._open(true)
	end

	local q = l._showTitle
	k._source(l)
	k._title(g(l._text))
	k._showTitle(q ~= nil and g(q) or true)
	k._elements(p)

	k.SetPosition(
	k,m or UDim2.new(0.5, 0, 0.5, 0))
	k.SetOpen(	k,true)
end

function j.Close(k)	k.SetOpen(	k,false)
end

function j.Render(k)	
return i(e, {
		Options = k,
	})
end














return constructor
end function a.X()







local b = 0.1

local c = {
	_open = nil ,
	_close = nil ,
	_lastOpenedAt = 0,
}

function c.SetHandlers(d, e)	
c._open = d
	c._close = e
end

function c.Open(d, e)	
c._lastOpenedAt = os.clock()
	if c._open then
		c._open(d, e)
	end
end

function c.Close()	
if c._close then
		c._close()
	end
end

function c.WasJustOpened()	
return os.clock() - c._lastOpenedAt < b
end



return c
end function a.Y()
local b = (cloneref(game.GetService(game, "UserInputService")) )
local c = (cloneref(game.GetService(game, "GuiService")) )

local d = a.load'm'
local e = a.load'I'

local f = {}

local function currentScale()	
local g = d.peek(e.scale)
	if g <= 0 then
		return 1
	end
	return g
end

f.getPosition = LPH_NO_VIRTUALIZE(function(g)	
local h	
local i
	
if g then
		h = g.Position.X
		i = g.Position.Y + ((c.GetGuiInset(c).Y ))
	else
		local j = b.GetMouseLocation(b)
		h = j.X
		i = j.Y
	end

	local j = currentScale()
	return UDim2.fromOffset(h / j, i / j)
end)

return f
end function a.Z()
local b= {}

return {
	elements = b,
}
end function a._()
local b = a.load'c'

local c = a.load'X'
local d = a.load'Y'
local e = a.load'J'
local f = a.load'Z'
local g = a.load'p'
local h = a.load's'

local i = a.load'm'
local j = i.peek

local k = b.useCallback
local l = b.useRef




local function findElementId(m)	
if not m then
		return nil
	end
	for n, o in next, f.elements do
		if o == m then
			return n
		end
	end
	return nil
end

local function appendDevItems(m, n)	
if not j(e.developerMode) then
		return
	end

	local o = findElementId(n)

	if #m > 0 then
		table.insert(m, { Divider = true })
	end

	if o then
		table.insert(m, {
			Label = "Copy ID",
			Icon = h.Get("image", "pencil"),
			Callback = function()				
if setclipboard then
					setclipboard(o)
				end
				g.Push{
					title = "Copied Id",
					subtext = `Copied {o} to clipboard`,
					duration = 2,
				}			
end,
		})
	end
end

local function useContext(m, n)	
local o = l(m)
	o.current = m

	local p = l(n)
	p.current = n

	return k(function(q, r)
		if r.UserInputType ~= Enum.UserInputType.MouseButton2 then
			return
		end

		local s = o.current
		local t		
if type(s) == "function" then
			t = s(q, r)
		else
			t = s 		
end

		t = t or {}
		appendDevItems(t, p.current)

		if #t == 0 then
			return
		end

		c.Open(t, d.getPosition(r))
	end, {})
end

return useContext
end function a.aa()
local b = (cloneref(game.GetService(game, "UserInputService")) )

local c = a.load'c'

local d = c.useEffect
local e = c.useRef



local function computeAlpha(f, g)	
local h = f.AbsolutePosition
	local i = f.AbsoluteSize
	local j = i.X > 0 and i.X or 1
	local k = i.Y > 0 and i.Y or 1
	return Vector2.new(
		math.clamp((g.X - h.X) / j, 0, 1),
		math.clamp((g.Y - h.Y) / k, 0, 1)
	)
end

local f = LPH_NO_VIRTUALIZE(function(f)	
local g = e(f)
	g.current = f

	local h = e(nil )
	local i = e(false)

	d(function()
		local j = b.InputChanged:Connect(function(j)
			if not i.current then
				return
			end
			if
				j.UserInputType ~= Enum.UserInputType.MouseMovement
				and j.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			local k = h.current
			if not k then
				return
			end

			g.current(computeAlpha(k, j.Position))
		end)

		local k = b.InputEnded:Connect(function(k)
			if
				k.UserInputType == Enum.UserInputType.MouseButton1
				or k.UserInputType == Enum.UserInputType.Touch
			then
				i.current = false
				h.current = nil
			end
		end)

		return function()
			j.Disconnect(			j)
			k.Disconnect(			k)
		end
	end, {})

	return function(j, k)
		if
			k.UserInputType ~= Enum.UserInputType.MouseButton1
			and k.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		i.current = true
		h.current = j
		g.current(computeAlpha(j, k.Position))
	end
end)

return f
end function a.ab()
local b = a.load'c'
local c = a.load'e'
local d = a.load'd'a.load'm'

local f = a.load'N'
local g = a.load'O'

local h = c.useSpring
local i = b.useEffect
local j = b.useMemo
local k = b.useBinding
local l = d.useAtom

local m = Color3.new(1, 1, 1)
local n = Color3.new(0, 0, 0)

local o = 0.5

local p = LPH_NO_VIRTUALIZE(function(p)	
return p.R * 0.299 + p.G * 0.587 + p.B * 0.114
end)

local function useAdvColor(
	q,
	r,
	s,
	t
)
	local u, v = b.useState(false)
	local w = l(q)
	local x = r and l(r) or nil
	local y = s and l(s) or false
	local z = (l(f.other.hoverTint) )	
local A = (l(f.other.darkHoverTint) )
	
local B, C = h(0, g.subtle)
	local D, E = h(0, g.quick)

	local F, G = k(w)
	local H, I = k(x or w)
	local J, K = k(Vector2.new(z, A))

	i(function()
		C.setGoal(		C,u and 1 or 0)
	end, { u })

	i(function()
		E.setGoal(		E,y and 1 or 0)
	end, { y })

	i(function()
		G(w)
	end, { w })

	i(function()
		I(x or w)
	end, { x, w })

	i(function()
		K(Vector2.new(z, A))
	end, { z, A })

	local L = j(function()
		return b.joinBindings{
			B,
			D,
			F,
			H,
			J,
		}:map(function(L)
			local M= L[1]
			local N= L[2]
			local O= L[3]
			local P= L[4]
			local Q= L[5]

			local R = r ~= nil
			local S = if R then O.Lerp(O,P, N) else O
			local T = p(O)
			local U = if R then T + (p(P) - T) * N else T

			local V = U > o
			local W = if V then n else m
			local X = if V then Q.Y else Q.X

			return S.Lerp(S,W, M * X)
		end)
	end, { B, D, F, H, J } )

	local M = j(function()
		return {
			onMouseEnter = function()
				v(true)
			end,
			onMouseLeave = function()
				v(false)
			end,
		}
	end, {})

	return j(function()
		return {
			binding = L,
			onMouseEnter = M.onMouseEnter,
			onMouseLeave = M.onMouseLeave,
		}
	end, { L, M } )
end

return useAdvColor
end function a.ac()
local b = LPH_NO_VIRTUALIZE(function(b)	
return b
end)

return b
end function a.ad()























local function shiftHue(b, c)	
local d, e, f = b.ToHSV(b)
	return Color3.fromHSV((d + c) % 1, e, f)
end

local function staticApply(b)	
return {
		color = b.color,
		rotation = b.rotation,
		transparency = b.transparency or 0,
	}
end

local function alwaysApplies()	
return true
end

local function sequenceOnly(b)	
return b
end

local function transparencyOnly(b, c)	
return c
end

local b= {
	{
		key = "none",
		label = "None",
		appliesTo = alwaysApplies,
		apply = staticApply,
	},
	{
		key = "shimmer",
		label = "Shimmer",
		appliesTo = sequenceOnly,
		apply = function(b)			
return {
				color = b.color,
				rotation = (b.rotation + b.time * b.speed * 60) % 360,
				transparency = b.transparency or 0,
			}
		end,
	},
	{
		key = "rainbow",
		label = "Rainbow",
		appliesTo = alwaysApplies,
		apply = function(b)			
local c = (b.time * b.speed * 0.2) % 1
			local d = b.color
			if typeof(d) == "ColorSequence" then
				local e = d.Keypoints
				local f = table.create(#e)
				for g = 1, #e do
					local h = e[g]
					f[g] = ColorSequenceKeypoint.new(h.Time, shiftHue(h.Value, c))
				end
				return {
					color = ColorSequence.new(f),
					rotation = b.rotation,
					transparency = b.transparency or 0,
				}
			end
			return {
				color = shiftHue(d , c),
				rotation = b.rotation,
				transparency = b.transparency or 0,
			}
		end,
	},
	{
		key = "blink",
		label = "Blink",
		appliesTo = transparencyOnly,
		apply = function(b)			
local c = b.transparency or 0
			local d = (b.time * b.speed) % 1
			local e = (1 - math.cos(d * math.pi * 2)) * 0.5
			return {
				color = b.color,
				rotation = b.rotation,
				transparency = c + (1 - c) * e,
			}
		end,
	},
}

local c= {}
local d= {}
for e, f in next, b do
	c[f.key] = f
	d[f.label] = f
end

local e = {}

e.list = b

function e.getByKey(f)	
return c[f]
end

function e.getKey(f)	
local g = d[f]
	return if g then g.key else nil
end

function e.getLabel(f)	
local g = c[f]
	return if g then g.label else "None"
end

function e.hasMotion(f)	
return f ~= "none" and c[f] ~= nil
end

function e.getApplicable(f, g)	
local h= {}
	for i, j in next, b do
		if j.appliesTo(f, g) then
			table.insert(h, j)
		end
	end
	return h
end

function e.getApplicableLabels(f, g)	
local h = e.getApplicable(f, g)
	local i= table.create(#h)
	for j, k in next, h do
		i[j] = k.label
	end
	return i
end

function e.appliesTo(f, g, h)	
local i = c[f]
	if not i then
		return false
	end
	return i.appliesTo(g, h)
end

function e.apply(f, g)	
local h = c[g]
	if not h then
		return staticApply(f)
	end
	return h.apply(f)
end

return e
end function a.ae()
local b = a.load'd'
local c = a.load'e'
local d = a.load'c'
local e = a.load'm'
local f = a.load'n'

local g = a.load'N'
local h = a.load's'
local i = a.load'_'
local j = a.load'aa'
local k = a.load'T'
local l = a.load'U'
local m = a.load'ab'
local n = a.load'Q'
local o = a.load'Y'
local p = a.load'ac'
local q = a.load'O'
local r = a.load'ad'

local s = g.colors.subwindow
local t = g.colors.window.element

local u = d.useEffect
local v = d.useState
local w = d.useRef
local x = d.useMemo
local y = c.useSpring
local z = b.useAtom
local A = d.joinBindings
local B = e.peek
local C = d.createElement

local D = 200
local E = 210
local F = 8

local G = 10
local H = 10

local I = 14
local J = 2
local K = 18

local L = 10
local M = 10
local N = 18

local O = 12
local P = 11

local Q = 140
local R = 6
local S = 8
local T = 12

local U = 18
local V = 74
local W = 34

local X = 56
local Y = 30
local Z = 54
local _ = 4

local aa = 18

local function snapScalarSpring(ab, ac)	
ab.setPosition(	ab,ac)
	ab.setGoal(	ab,ac)
end

local ab = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(0.166, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(0.666, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
}

local function rgbComponents(ac)	
local ad = math.clamp(math.round(ac.R * 255), 0, 255)
	local ae = math.clamp(math.round(ac.G * 255), 0, 255)
	local af = math.clamp(math.round(ac.B * 255), 0, 255)
	return ad, ae, af
end

local function formatHex(ac)	
local ad, ae, af = rgbComponents(ac)
	return string.format("%02X%02X%02X", ad, ae, af)
end

local function useBoolAtom(ac)	
local ad = x(function()
		return e.atom(false)
	end, {})
	u(function()
		ad(ac)
	end, { ac })
	return ad
end

local function Keypoint(ac





)	
local ad = ac.Colorpicker
	local ae = ac.Keypoint
	local af = ac.Index
	local ag = ac.KeypointCount
	local ah = ac.IsActive

	local ai, aj = y(ah and 1 or 0, {
		tension = 700,
		friction = 45,
	})

	u(function()
		aj.setGoal(		aj,ah and 1 or 0)
	end, { ah })

	local ak = i(function()
		local ak= {}
		local al = af > 1 and af < ag
		if al then
			table.insert(ak, {
				Label = "Delete Keypoint",
				Icon = h.Get("image", "delete"),
				Callback = function()
					ad.RemoveKeypoint(					ad,af)
				end,
			})
		end
		return ak
	end)

	return C("TextButton", {
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = ae.Value,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(ae.Time, 0.5),
		AnchorPoint = Vector2.new(ae.Time, 0.5),
		Text = "",
		AutoButtonColor = false,
		Active = false,
		ZIndex = 2,
		[d.Event.MouseButton1Click] = function()
			ad.SetActiveKeypoint(			ad,af)
		end,
		[d.Event.InputBegan] = p(ak),
	}, {
		UICorner = C("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		UIStroke = C("UIStroke", {
			Thickness = ai.map(ai,function(al)
				return 1 + al * 1.5
			end),
			Color = Color3.fromRGB(255, 255, 255),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

local function KeypointsFrame(ac)	
local ad = ac.Colorpicker

	local ae = z(ad._color)
	local af = z(ad._activeKeypoint)
	local ag = z(ad._keypointIds)

	local ah= typeof(ae) == "ColorSequence" and ae
		or ColorSequence.new(Color3.fromRGB(255, 255, 255))

	local ai = #ah.Keypoints
	local aj= {}
	for ak, al in ah.Keypoints do
		local am = ag[ak] or ak
		aj[`Keypoint_{am}`] = C(Keypoint, {
			Colorpicker = ad,
			Keypoint = al,
			Index = ak,
			KeypointCount = ai,
			IsActive = ak == af,
		})
	end

	local ak = i(function(ak, al)
		local am = ak.AbsolutePosition
		local an = ak.AbsoluteSize
		local ao = an.X > 0 and an.X or 1
		local ap = math.clamp((al.Position.X - am.X) / ao, 0, 1)

		return {
			{
				Label = "Add Keypoint",
				Icon = h.Get("image", "drop"),
				Callback = function()
					ad.AddKeypoint(					ad,ap)
				end,
			},
		}
	end)

	return C("Frame", {
		Size = UDim2.new(1, 0, 0, T),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = ac.LayoutOrder,
	}, {
		Bar = C(
			"TextButton",
			{
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
				Active = false,
				[d.Event.InputBegan] = function(al, am)
					if am.UserInputType == Enum.UserInputType.MouseButton2 then
						ak(al, am)
						return
					end
				end,
			},
			f.Dictionary.join({
				UICorner = C("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
				UIGradient = C("UIGradient", {
					Color = ah,
				}),
			}, aj)
		),
	})
end

local function SVFrame(ac)	
local ad = ac.Colorpicker

	local ae = z(s.stroke)
	local af = z(ad._hue)
	local ag = z(ad._saturation) or 0
	local ah = z(ad._value)

	local ai, aj = y(af, q.snap)
	local ak, al = y(ag, q.snap)
	local am, an = y(ah, q.snap)

	u(function()
		aj.setGoal(		aj,af)
	end, { af })
	u(function()
		al.setGoal(		al,ag)
	end, { ag })
	u(function()
		an.setGoal(		an,ah)
	end, { ah })

	u(function()
		if ac.SnapEpoch < 1 then
			return
		end
		local ao = B(ad._hue)
		local ap = B(ad._saturation) or 0
		local aq = B(ad._value)
		snapScalarSpring(aj, ao)
		snapScalarSpring(al, ap)
		snapScalarSpring(an, aq)
	end, { ac.SnapEpoch })

	local ao = ai.map(ai,function(ao)
		return Color3.fromHSV(ao, 1, 1)
	end)

	local ap = A{ ak, am }:map(function(ap)
		local aq = math.clamp(ap[1], 0, 1)
		local ar = math.clamp(ap[2], 0, 1)
		return UDim2.fromScale(aq, 1 - ar)
	end)
	local aq = A{ ak, am }:map(function(aq)
		local ar = math.clamp(aq[1], 0, 1)
		local as = math.clamp(aq[2], 0, 1)
		return Vector2.new(ar, 1 - as)
	end)

	local ar = j(function(ar)
		ad.SetSaturationValue(		ad,ar.X, 1 - ar.Y)
	end)

	return C("ImageLabel", {
		Image = h.Get("image", "color"),
		Size = UDim2.new(1, 0, 0, Q),
		BackgroundColor3 = ao,
		BorderSizePixel = 0,
		LayoutOrder = ac.LayoutOrder,
		[d.Event.InputBegan] = function(as, at)
			ar(as, at)
		end,
	}, {
		UICorner = C("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIStroke = C("UIStroke", {
			Thickness = 1,
			Color = ae,
		}),
		Dragger = C("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 8, 0, 8),
			AnchorPoint = aq,
			Position = ap,
		}, {
			UICorner = C("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			UIStroke = C("UIStroke", {
				Thickness = 1.5,
				Color = Color3.fromRGB(255, 255, 255),
			}),
		}),
	})
end

local function HueFrame(ac)	
local ad = ac.Colorpicker

	local ae = z(ad._hue)
	local af, ag = y(ae, q.snap)

	u(function()
		ag.setGoal(		ag,ae)
	end, { ae })

	u(function()
		if ac.SnapEpoch < 1 then
			return
		end
		snapScalarSpring(ag, B(ad._hue))
	end, { ac.SnapEpoch })

	local ah = af.map(af,function(ah)
		return UDim2.fromScale(math.clamp(ah, 0, 1), 0.5)
	end)
	local ai = af.map(af,function(ai)
		return Vector2.new(math.clamp(ai, 0, 1), 0.5)
	end)
	local aj = af.map(af,function(aj)
		return Color3.fromHSV(aj, 1, 1)
	end)

	local ak = j(function(ak)
		ad.SetHue(		ad,ak.X)
	end)

	return C("Frame", {
		Size = UDim2.new(1, 0, 0, R),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		LayoutOrder = ac.LayoutOrder,
		[d.Event.InputBegan] = function(al, am)
			ak(al, am)
		end,
	}, {
		UICorner = C("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		UIGradient = C("UIGradient", {
			Color = ab,
		}),
		Dragger = C("Frame", {
			BackgroundTransparency = 0,
			BackgroundColor3 = aj,
			BorderSizePixel = 0,
			AnchorPoint = ai,
			Position = ah,
			Size = UDim2.new(0, 8, 0, 8),
		}, {
			UICorner = C("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			UIStroke = C("UIStroke", {
				Thickness = 1.5,
				Color = Color3.fromRGB(255, 255, 255),
			}),
		}),
	})
end

local function TransparencyFrame(
	ac
)	
local ad = ac.Colorpicker

	local ae = z(ad._transparency) or 0
	local af, ag = y(ae, q.snap)

	u(function()
		ag.setGoal(		ag,ae)
	end, { ae })

	u(function()
		if ac.SnapEpoch < 1 then
			return
		end
		snapScalarSpring(ag, B(ad._transparency) or 0)
	end, { ac.SnapEpoch })

	local ah = af.map(af,function(ah)
		return UDim2.fromScale(math.clamp(ah, 0, 1), 0.5)
	end)
	local ai = af.map(af,function(ai)
		return Vector2.new(math.clamp(ai, 0, 1), 0.5)
	end)

	local aj = j(function(aj)
		ad.SetTransparency(		ad,aj.X)
	end)

	return C("ImageLabel", {
		Size = UDim2.new(1, 0, 0, S),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = h.Get("image", "transparency"),
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.new(0, 8, 0, 8),
		LayoutOrder = ac.LayoutOrder,
		[d.Event.InputBegan] = function(ak, al)
			aj(ak, al)
		end,
	}, {
		UICorner = C("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		UIGradient = C("UIGradient", {
			Transparency = NumberSequence.new{
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			},
		}),
		Dragger = C("Frame", {
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(136, 136, 136),
			AnchorPoint = ai,
			Position = ah,
			Size = UDim2.new(0, 2, 0, 8),
		}, {
			UICorner = C("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			UIStroke = C("UIStroke", {
				Thickness = 1.5,
				Color = Color3.fromRGB(255, 255, 255),
			}),
		}),
	})
end

local function TextField(ac






)	
local ad = z(t.caption)

	local ae, af = v(false)
	local ag = useBoolAtom(ae)

	local ah = m(t.fieldBackground, t.fieldBackgroundActive, ag)
	local ai = m(t.fieldStroke, t.fieldStrokeActive, ag)
	local aj = m(t.text, t.text, ag)

	local ak, al = v(ac.Text)

	u(function()
		al(ac.Text)
	end, { ac.Text })

	return C("Frame", {
		BackgroundColor3 = ah.binding,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(ac.Width, U),
		LayoutOrder = ac.LayoutOrder,
		[d.Event.MouseEnter] = function()
			ah.onMouseEnter()
			ai.onMouseEnter()
			aj.onMouseEnter()
		end,
		[d.Event.MouseLeave] = function()
			ah.onMouseLeave()
			ai.onMouseLeave()
			aj.onMouseLeave()
		end,
	}, {
		UICorner = C("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = C("UIStroke", {
			Color = ai.binding,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = C("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		UIListLayout = C("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
		Prefix = ac.Prefix and C("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = ac.Prefix,
			TextSize = P,
			TextColor3 = ad,
			FontFace = h.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 0,
		}) or nil,
		Input = C("TextBox", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Text = ak,
			TextSize = P,
			TextColor3 = aj.binding,
			PlaceholderText = ac.Placeholder or "",
			PlaceholderColor3 = ad,
			FontFace = h.Get("font", "semi_bold"),
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 1,
			[d.Change.Text] = function(am)
				al(am.Text)
			end,
			[d.Event.Focused] = function()
				af(true)
			end,
			[d.Event.FocusLost] = function(am)
				af(false)
				local an = ac.OnCommit(am.Text)
				if an == false then
					al(ac.Text)
				end
			end,
		}, {
			UIFlexItem = C("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
			}),
		}),
	})
end

local function InputsFrame(ac)	
local ad = ac.Colorpicker

	local ae = z(ad._hue)
	local af = z(ad._saturation) or 0
	local ag = z(ad._value)

	local ah = z(t.caption)

	local ai = Color3.fromHSV(ae, af, ag)
	local aj, ak, al = rgbComponents(ai)
	local am = formatHex(ai)

	return C("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = ac.LayoutOrder,
	}, {
		UIListLayout = C("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		HexRow = C("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, U),
			LayoutOrder = 0,
		}, {
			UIListLayout = C("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Label = C("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 24, 1, 0),
				Text = "Hex",
				TextSize = O,
				TextColor3 = ah,
				FontFace = h.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = 0,
			}),
			Field = C(TextField, {
				Text = am,
				Width = V,
				Prefix = "#",
				Placeholder = "RRGGBB",
				LayoutOrder = 1,
				OnCommit = function(an)					
return ad.SetColorFromHex(ad,an)
				end,
			}),
		}),
		RgbRow = C("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, U),
			LayoutOrder = 1,
		}, {
			UIListLayout = C("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Label = C("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 24, 1, 0),
				Text = "RGB",
				TextSize = O,
				TextColor3 = ah,
				FontFace = h.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = 0,
			}),
			R = C(TextField, {
				Text = tostring(aj),
				Width = W,
				Placeholder = "R",
				LayoutOrder = 1,
				OnCommit = function(an)					
local ao = tonumber(an)
					if ao == nil then
						return false
					end
					local ap = math.floor(ao + 0.5)
					if ap < 0 or ap > 255 then
						return false
					end
					ad.SetColorFromRGB(					ad,ap, ak, al)
					return true
				end,
			}),
			G = C(TextField, {
				Text = tostring(ak),
				Width = W,
				Placeholder = "G",
				LayoutOrder = 2,
				OnCommit = function(an)					
local ao = tonumber(an)
					if ao == nil then
						return false
					end
					local ap = math.floor(ao + 0.5)
					if ap < 0 or ap > 255 then
						return false
					end
					ad.SetColorFromRGB(					ad,aj, ap, al)
					return true
				end,
			}),
			B = C(TextField, {
				Text = tostring(al),
				Width = W,
				Placeholder = "B",
				LayoutOrder = 3,
				OnCommit = function(an)					
local ao = tonumber(an)
					if ao == nil then
						return false
					end
					local ap = math.floor(ao + 0.5)
					if ap < 0 or ap > 255 then
						return false
					end
					ad.SetColorFromRGB(					ad,aj, ak, ap)
					return true
				end,
			}),
		}),
	})
end

local function SliderRow(ac









)	
local ad = useBoolAtom(ac.IsActive)

	local ae = z(t.text)
	local af = m(t.panel, t.panel, ad)
	local ag = m(t.accentSoft, t.accent, ad)
	local ah = m(t.thumb, t.thumbActive, ad)
	local ai = m(t.fieldBackground, t.fieldBackgroundActive, ad)
	local aj = m(t.fieldStroke, t.fieldStrokeActive, ad)
	local ak = m(t.caption, t.captionActive, ad)

	local al = math.clamp(ac.Alpha, 0, 1)
	local am, an = y(al, q.snap)

	u(function()
		an.setGoal(		an,al)
	end, { al })

	u(function()
		local ao = ac.SnapEpoch or 0
		if ao < 1 then
			return
		end
		snapScalarSpring(an, math.clamp(ac.Alpha, 0, 1))
	end, { ac.SnapEpoch })

	local ao = j(function(ao)
		ac.OnDragAlpha(ao.X)
	end)

	local ap = w(nil )
	local aq = w(nil )
	local ar, as = v(false)

	local at = w(ac.OnCommitText)
	at.current = ac.OnCommitText

	u(function()
		local au = ap.current
		if not au then
			return nil
		end

		local av = {
			au.Focused:Connect(function()
				au.Text = ""
				as(true)
			end),
			au.FocusLost:Connect(function()
				as(false)
				at.current(au.Text)
				au.Text = ""
			end),
		}

		return function()
			for aw, ax in av do
				ax.Disconnect(				ax)
			end
		end 	
end, {})

	n(aq, ar, function()
		if ap.current then
			ap.current:ReleaseFocus()
		end
	end)

	return C("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, N),
		LayoutOrder = ac.LayoutOrder,
	}, {
		UIListLayout = C("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = C("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, X, 1, 0),
			Text = ac.Label,
			TextSize = O,
			TextColor3 = ae,
			FontFace = h.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 0,
		}),
		Slider = C("TextButton", {
			Size = UDim2.fromOffset(0, _),
			BackgroundColor3 = af.binding,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Text = "",
			Active = false,
			AutoButtonColor = false,
			LayoutOrder = 1,
			[d.Event.MouseEnter] = function()
				af.onMouseEnter()
				ag.onMouseEnter()
				ah.onMouseEnter()
			end,
			[d.Event.MouseLeave] = function()
				af.onMouseLeave()
				ag.onMouseLeave()
				ah.onMouseLeave()
			end,
			[d.Event.InputBegan] = p(function(au, av)
				if av.UserInputType ~= Enum.UserInputType.MouseButton1 then
					return
				end
				ao(au, av)
			end),
			[d.Event.MouseWheelForward] = function()
				ac.OnNudge(1)
			end,
			[d.Event.MouseWheelBackward] = function()
				ac.OnNudge(-1)
			end,
		}, {
			UICorner = C("UICorner", { CornerRadius = UDim.new(1, 0) }),
			UIFlexItem = C("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
				ItemLineAlignment = Enum.ItemLineAlignment.Automatic,
			}),
			Fill = C("Frame", {
				Size = am.map(am,function(au)
					return UDim2.fromScale(au, 1)
				end),
				BackgroundColor3 = ag.binding,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, {
				UICorner = C("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
			Circle = C("Frame", {
				Size = UDim2.fromOffset(8, 8),
				Position = am.map(am,function(au)
					return UDim2.fromScale(au, 0.5)
				end),
				AnchorPoint = am.map(am,function(au)
					return Vector2.new(au, 0.5)
				end),
				BackgroundColor3 = ah.binding,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				UICorner = C("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
		}),
		Box = C("TextButton", {
			ref = aq,
			Size = UDim2.fromOffset(0, U),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = ai.binding,
			BorderSizePixel = 0,
			LayoutOrder = 2,
			AutoButtonColor = false,
			Text = "",
			Active = false,
			ClipsDescendants = true,
			[d.Event.MouseEnter] = function()
				ai.onMouseEnter()
				aj.onMouseEnter()
				ak.onMouseEnter()
			end,
			[d.Event.MouseLeave] = function()
				ai.onMouseLeave()
				aj.onMouseLeave()
				ak.onMouseLeave()
			end,
			[d.Event.MouseButton1Click] = function()
				if ap.current then
					ap.current:CaptureFocus()
				end
			end,
		}, {
			UICorner = C("UICorner", { CornerRadius = UDim.new(0, 4) }),
			UIPadding = C("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 1),
				PaddingBottom = UDim.new(0, 1),
			}),
			UISizeConstraint = C("UISizeConstraint", {
				MinSize = Vector2.new(Y, U),
				MaxSize = Vector2.new(Z, U),
			}),
			UIStroke = C("UIStroke", {
				Color = aj.binding,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			Text = C("TextBox", {
				ref = ap,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 20, 0, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				Text = ar and "" or ac.FormattedValue,
				FontFace = h.Get("font", "semi_bold"),
				TextSize = P,
				TextColor3 = ak.binding,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ClearTextOnFocus = true,
				Interactable = ar,
				MultiLine = false,
				TextWrapped = false,
			}),
		}),
	})
end

local function AnimationRow(ac




)	
local ad = ac.Colorpicker
	local ae = ad._animationSource

	local af = z(ae._state)
	local ag = z(ae._open)
	local ah = z(t.text)

	local ai = m(t.panel, t.surface, ae._open)
	local aj = m(t.panelStroke, t.accentStrong, ae._open)
	local ak = m(t.icon, t.iconActive, ae._open)
	local al = m(t.caption, t.text, ae._open)

	local am, an = y(0, q.snap)

	u(function()
		an.setGoal(		an,ag and 1 or 0)
	end, { ag })

	local function toggle()		
if B(ae._open) then
			ae.ClosePicker()
			return
		end
		local ao = r.getApplicableLabels(ac.IsSequence, ac.HasTransparency)
		ae.OpenPicker(ao, o.getPosition())
	end

	return C("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, N),
		LayoutOrder = ac.LayoutOrder,
	}, {
		UIListLayout = C("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = C("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, X, 1, 0),
			Text = "Animation",
			TextSize = O,
			TextColor3 = ah,
			FontFace = h.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 0,
		}),
		Button = C("TextButton", {
			BorderSizePixel = 0,
			Size = UDim2.new(1, -(X + 6), 0, aa),
			LayoutOrder = 1,
			BackgroundColor3 = ai.binding,
			Text = "",
			Active = false,
			AutoButtonColor = false,
			[d.Event.MouseEnter] = function()
				ai.onMouseEnter()
				aj.onMouseEnter()
				ak.onMouseEnter()
				al.onMouseEnter()
			end,
			[d.Event.MouseLeave] = function()
				ai.onMouseLeave()
				aj.onMouseLeave()
				ak.onMouseLeave()
				al.onMouseLeave()
			end,
			[d.Event.MouseButton1Click] = toggle,
		}, {
			UIStroke = C("UIStroke", {
				Color = aj.binding,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			UICorner = C("UICorner", { CornerRadius = UDim.new(0, 3) }),
			UIPadding = C("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 2),
				PaddingBottom = UDim.new(0, 2),
			}),
			Image = C("ImageLabel", {
				Size = UDim2.fromOffset(8, 8),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Image = h.Get("image", "down_arrow"),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ImageColor3 = ak.binding,
				Rotation = am.map(am,function(ao)
					return ao * 180
				end),
			}),
			Text = C("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = h.Get("font", "semi_bold"),
				TextColor3 = al.binding,
				TextSize = P,
				Text = af,
				Size = UDim2.new(1, -12, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		}),
	})
end

local function CogButton(ac


)	
local ad = useBoolAtom(ac.IsOpen)

	local ae = m(s.image, s.title, ad)

	local af, ag = y(0, q.smooth)
	u(function()
		ag.setGoal(		ag,ac.IsOpen and 90 or 0)
	end, { ac.IsOpen })

	return C("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		[d.Event.MouseEnter] = function()
			ae.onMouseEnter()
		end,
		[d.Event.MouseLeave] = function()
			ae.onMouseLeave()
		end,
		[d.Event.MouseButton1Click] = ac.OnClick,
	}, {
		Icon = C("ImageLabel", {
			BackgroundTransparency = 1,
			Image = h.Get("image", "cog"),
			ImageColor3 = ae.binding,
			Size = UDim2.fromOffset(12, 12),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = af,
		}),
	})
end

local function MainPanel(ac







)	
local ad = ac.Colorpicker

	local ae = z(ad._title)

	local af = z(s.background)
	local ag = z(s.stroke)
	local ah = z(s.title)
	local ai = z(s.divider)

	local aj= {
		UIStroke = C("UIStroke", {
			Color = ag,
			Transparency = ac.Anim.strokeTransparency,
			Thickness = 1,
		}),
		UIPadding = C("UIPadding", {
			PaddingLeft = UDim.new(0, G),
			PaddingRight = UDim.new(0, G),
			PaddingTop = UDim.new(0, H),
			PaddingBottom = UDim.new(0, H),
		}),
		UIListLayout = C("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, L),
		}),
		UICorner = C("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		TitleFrame = C("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, I + J + 2),
			LayoutOrder = 0,
		}, {
			Title = C("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -22, 0, I),
				Text = ae,
				TextColor3 = ah,
				FontFace = h.Get("font", "semi_bold"),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			AdvancedButton = ac.CanShowAdvanced and C(CogButton, {
				IsOpen = ac.AdvancedOpen,
				OnClick = function()
					ad.ToggleAdvanced(					ad)
				end,
			}) or nil,
			Divider = C("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = ai,
				Size = UDim2.new(1, 0, 0, J),
				Position = UDim2.fromOffset(0, K),
			}),
		}),
	}

	local ak = 1

	if ac.IsSequence then
		aj.KeypointsFrame = C(KeypointsFrame, {
			Colorpicker = ad,
			LayoutOrder = ak,
		})
		ak += 1
	end

	aj.SVFrame = C(SVFrame, {
		Colorpicker = ad,
		LayoutOrder = ak,
		SnapEpoch = ac.SnapEpoch,
	})
	ak += 1

	aj.HueFrame = C(HueFrame, {
		Colorpicker = ad,
		LayoutOrder = ak,
		SnapEpoch = ac.SnapEpoch,
	})
	ak += 1

	if ac.HasTransparency then
		aj.TransparencyFrame = C(TransparencyFrame, {
			Colorpicker = ad,
			LayoutOrder = ak,
			SnapEpoch = ac.SnapEpoch,
		})
		ak += 1
	end

	aj.InputsFrame = C(InputsFrame, {
		Colorpicker = ad,
		LayoutOrder = ak,
	})

	return C("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, D, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 0,
	}, {
		Shadow = l{
			transparency = ac.Anim.transparency,
			zIndex = 0,
		},
		Body = C("CanvasGroup", {
			BackgroundTransparency = 0,
			BackgroundColor3 = af,
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = Enum.AutomaticSize.Y,
			GroupTransparency = ac.Anim.transparency,
			ZIndex = 1,
		}, aj),
	})
end

local function AdvancedPanel(ac






)	
local ad = ac.Colorpicker

	local ae = z(ad._rotation)
	local af = z(ad._speed)
	local ag = z(ad._animation)

	local ah = z(s.background)
	local ai = z(s.stroke)
	local aj = z(s.title)
	local ak = z(s.divider)

	local al = math.clamp(ae / 360, 0, 1)
	local am = math.clamp((af - 0.1) / 4.9, 0, 1)
	local an = r.hasMotion(ag)

	local ao = A{ ac.Anim.transparency, ac.OpenBind }:map(function(ao)
		local ap = ao[1]
		local aq = ao[2]
		return 1 - (1 - ap) * math.clamp(aq, 0, 1)
	end)
	local ap = A{ ac.Anim.strokeTransparency, ac.OpenBind }:map(function(ap)
		local aq = ap[1]
		local ar = ap[2]
		return 1 - (1 - aq) * math.clamp(ar, 0, 1)
	end)
	local aq = A{ ac.Anim.transparency, ac.OpenBind }:map(function(aq)
		local ar = aq[1]
		local as = aq[2]
		return 1 - (1 - ar) * math.clamp(as, 0, 1)
	end)
	local ar = ac.OpenBind:map(function(ar)
		local as = math.clamp(ar, 0, 1)
		return UDim2.fromOffset(math.round(-(1 - as) * 10), 0)
	end)

	return C("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, E, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = ar,
	}, {
		Shadow = l{
			transparency = aq,
			zIndex = 0,
		},
		Body = C("CanvasGroup", {
			BackgroundTransparency = 0,
			BackgroundColor3 = ah,
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = Enum.AutomaticSize.Y,
			GroupTransparency = ao,
			ZIndex = 1,
		}, {
			UIStroke = C("UIStroke", {
				Color = ai,
				Transparency = ap,
				Thickness = 1,
			}),
			UICorner = C("UICorner", { CornerRadius = UDim.new(0, 6) }),
			UIPadding = C("UIPadding", {
				PaddingLeft = UDim.new(0, G),
				PaddingRight = UDim.new(0, G),
				PaddingTop = UDim.new(0, H),
				PaddingBottom = UDim.new(0, H),
			}),
			UIListLayout = C("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, L),
			}),
			TitleFrame = C("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, I + J + 2),
				LayoutOrder = 0,
			}, {
				Title = C("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, I),
					Text = "Advanced",
					TextColor3 = aj,
					FontFace = h.Get("font", "semi_bold"),
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Divider = C("Frame", {
					BorderSizePixel = 0,
					BackgroundColor3 = ak,
					Size = UDim2.new(1, 0, 0, J),
					Position = UDim2.fromOffset(0, K),
				}),
			}),
			Rows = C("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1,
			}, {
				UIListLayout = C("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, M),
				}),
				Rotation = ac.IsSequence and C(SliderRow, {
					Label = "Rotation",
					Alpha = al,
					FormattedValue = string.format("%d°", math.round(ae)),
					IsActive = ae > 0,
					OnDragAlpha = function(as)
						ad.SetRotation(						ad,as * 360)
					end,
					OnCommitText = function(as)
						local at = as.gsub(as,"°", ""):gsub("%s", "")
						local au = tonumber(at)
						if au then
							ad.SetRotation(							ad,au)
						end
					end,
					OnNudge = function(as)
						ad.SetRotation(						ad,ae + as * 5)
					end,
					LayoutOrder = 0,
					SnapEpoch = ac.SnapEpoch,
				}) or nil,
				Animation = C(AnimationRow, {
					Colorpicker = ad,
					IsSequence = ac.IsSequence,
					HasTransparency = ac.HasTransparency,
					LayoutOrder = 1,
				}),
				Speed = an and C(SliderRow, {
					Label = "Speed",
					Alpha = am,
					FormattedValue = string.format("%.1fx", af),
					IsActive = math.abs(af - 1) > 0.001,
					OnDragAlpha = function(as)
						ad.SetSpeed(						ad,0.1 + as * 4.9)
					end,
					OnCommitText = function(as)
						local at = as.gsub(as,"x", ""):gsub("X", ""):gsub("%s", "")
						local au = tonumber(at)
						if au then
							ad.SetSpeed(							ad,au)
						end
					end,
					OnNudge = function(as)
						ad.SetSpeed(						ad,af + as * 0.1)
					end,
					LayoutOrder = 2,
					SnapEpoch = ac.SnapEpoch,
				}) or nil,
			}),
		}),
	})
end

return function(ac)	
local ad = ac.Colorpicker

	local ae = z(ad._color)
	local af = z(ad._transparency)
	local ag = z(ad._advancedOpen)

	local ah = typeof(ae) == "ColorSequence"
	local ai = af ~= nil
	local aj = r.getApplicable(ah, ai)
	local ak = #aj > 1

	local al = z(ad._sliderSnapEpoch)

	local am = k(ad, {
		slideOffset = 15,
		floatingId = "subwindow.colorpicker",
		onClickOutside = function()
			ad.Close(			ad)
		end,
	})

	local an = ak and ag and 1 or 0
	local ao, ap = y(an, q.smooth)

	u(function()
		ap.setGoal(		ap,an)
	end, { an })

	local aq = ao.map(ao,function(aq)
		return aq > 0.01
	end)

	return C("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = am.position,
		Visible = am.visible,
		ZIndex = am.zIndex,
	}, {
		Wrapper = C("Frame", {
			ref = am.frameRef,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
		}, {
			UIListLayout = C("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),
			MainPanel = C(MainPanel, {
				Colorpicker = ad,
				IsSequence = ah,
				HasTransparency = ai,
				AdvancedOpen = ag,
				CanShowAdvanced = ak,
				Anim = am,
				SnapEpoch = al,
			}),
			Gap = C("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, F, 0, 0),
				Visible = aq,
				LayoutOrder = 1,
			}),
			AdvancedWrapper = ak and C("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, E, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Visible = aq,
				LayoutOrder = 2,
			}, {
				AdvancedPanel = C(AdvancedPanel, {
					Colorpicker = ad,
					IsSequence = ah,
					HasTransparency = ai,
					Anim = am,
					OpenBind = ao,
					SnapEpoch = al,
				}),
			}) or nil,
		}),
	})
end
end function a.af()


local aa = {
	_open = nil ,
	_close = nil ,
	_wasJustClosedFor = nil ,
}

function aa.SetHandlers(
	ab,
	ac,
	ad
)	
aa._open = ab
	aa._close = ac
	aa._wasJustClosedFor = ad
end

function aa.Open(ab, ac)	
if aa._open then
		aa._open(ab, ac)
	end
end

function aa.Close(ab)	
if aa._close then
		aa._close(ab)
	end
end

function aa.WasJustClosedFor(ab)	
if aa._wasJustClosedFor then
		return aa._wasJustClosedFor(ab)
	end
	return false
end

return aa
end function a.ag()
local aa = a.load'm'
local ab = a.load'c'

local ac = a.load'M'
local ad = a.load'ae'
local ae = a.load'af'
local af = a.load'ad'

local ag = aa.atom
local ah = aa.peek
local ai = aa.subscribe
local aj = ab.createElement

local ak = {}
ak.__index = ak

setmetatable(ak, { __index = ac })

local function constructor()	
local al = (ac.new() )
	
setmetatable(al, ak)

	al._title = ag""	
al._color = ag((Color3.fromRGB(255, 255, 255) ))
	al._transparency = ag(nil )
	al._source = ag(nil )

	al._activeKeypoint = ag(1)
	al._keypointIds = ag({} )
	al._nextKeypointId = 0
	al._hue = ag(0)
	al._saturation = ag(0)
	al._value = ag(1)

	al._rotation = ag(0)
	al._animation = ag("none" )
	al._speed = ag(1)
	al._advancedOpen = ag(false)
	al._sliderSnapEpoch = ag(0)

	local am= {}
	am._options = ag({} )
	am._state = ag(af.getLabel(ah(al._animation)))
	am._mode = ag("single" )
	am._open = ag(false)
	am.Toggle = function(an, ao)		
local ap = af.getKey(ao)
		if not ap then
			return
		end
		if ah(al._animation) ~= ap then
			al.SetAnimation(			al,ap)
		end
		ae.Close(an)
	end
	am.OpenPicker = function(an, ao)		
am._options(an)
		ae.Open(am, ao)
	end
	am.ClosePicker = function()		
ae.Close(am)
	end
	al._animationSource = am

	ai(al._animation, function(an)		
local ao = af.getLabel(an)
		if ah(am._state) ~= ao then
			am._state(ao)
		end
	end)

	return al
end

function ak._assignIds(al, am)	
local an = table.create(am)
	for ao = 1, am do
		al._nextKeypointId += 1
		an[ao] = al._nextKeypointId
	end
	return an
end

local function getKeypointColor(al, am)	
if typeof(al) == "ColorSequence" then
		local an = al.Keypoints[am or 1]
		return an and an.Value or Color3.fromRGB(255, 255, 255)
	end
	return al
end

function ak._loadHsvFromCurrent(al)	
local am = ah(al._color)
	local an = ah(al._activeKeypoint)
	local ao = getKeypointColor(am, an)

	local ap, aq, ar = ao.ToHSV(ao)
	if aq > 0 then
		al._hue(ap)
	end
	al._saturation(aq)
	al._value(ar)
	al._sliderSnapEpoch(ah(al._sliderSnapEpoch) + 1)
end

function ak._pushColor(al, am)	
local an = ah(al._source)
	if not an then
		return
	end
	an._state(am)
end

function ak._pushTransparency(al, am)	
local an = ah(al._source)
	if not an or an._transparency == nil then
		return
	end
	an._transparency(am)
end

function ak._applyHsv(al)	
local am = ah(al._hue)
	local an = ah(al._saturation)
	local ao = ah(al._value)
	local ap = Color3.fromHSV(am, an, ao)

	local aq = ah(al._color)
	if typeof(aq) == "ColorSequence" then
		local ar = ah(al._activeKeypoint) or 1
		local as = aq.Keypoints
		if not as[ar] then
			return
		end

		local at = table.create(#as)
		for au, av in as do
			if au == ar then
				table.insert(at, ColorSequenceKeypoint.new(av.Time, ap))
			else
				table.insert(at, av)
			end
		end

		local au = ColorSequence.new(at)
		al._color(au)
		al._pushColor(		al,au)
	else
		al._color(ap)
		al._pushColor(		al,ap)
	end
end

function ak.SetHue(al, am)	
al._hue(math.clamp(am, 0, 1))
	al._applyHsv(	al)
end

function ak.SetSaturationValue(al, am, an)	
al._saturation(math.clamp(am, 0, 1))
	al._value(math.clamp(an, 0, 1))
	al._applyHsv(	al)
end

function ak.SetTransparency(al, am)	
local an = math.clamp(am, 0, 1)
	al._transparency(an)
	al._pushTransparency(	al,an)
end

function ak.SetRotation(al, am)	
local an = math.clamp(am, 0, 360)
	al._rotation(an)
	local ao = ah(al._source)
	if ao and ao._rotation then
		ao._rotation(an)
	end
end

function ak.SetAnimation(al, am)	
al._animation(am)
	local an = ah(al._source)
	if an and an._animation then
		an._animation(am)
	end
end

function ak.SetSpeed(al, am)	
local an = math.clamp(am, 0.1, 5)
	al._speed(an)
	local ao = ah(al._source)
	if ao and ao._speed then
		ao._speed(an)
	end
end

function ak.ToggleAdvanced(al)	
al._advancedOpen(not ah(al._advancedOpen))
end

function ak.SetColor3(al, am)	
local an, ao, ap = am.ToHSV(am)
	if ao > 0 then
		al._hue(an)
	end
	al._saturation(ao)
	al._value(ap)
	al._applyHsv(	al)
	al._sliderSnapEpoch(ah(al._sliderSnapEpoch) + 1)
end

function ak.SetColorFromRGB(al, am, an, ao)	
local ap = math.clamp(math.floor(am + 0.5), 0, 255)
	local aq = math.clamp(math.floor(an + 0.5), 0, 255)
	local ar = math.clamp(math.floor(ao + 0.5), 0, 255)
	al.SetColor3(	al,Color3.fromRGB(ap, aq, ar))
end

function ak.SetColorFromHex(al, am)	
local an = (am.gsub(am,"^#", ""):gsub("%s", ""))
	if #an == 3 then
		an = an.sub(an,1, 1):rep(2) .. an.sub(an,2, 2):rep(2) .. an.sub(an,3, 3):rep(2)
	end
	if #an ~= 6 then
		return false
	end
	if not an.match(an, "^[0-9a-fA-F]+$")then
		return false
	end
	local ao = tonumber(an.sub(an,1, 2), 16)
	local ap = tonumber(an.sub(an,3, 4), 16)
	local aq = tonumber(an.sub(an,5, 6), 16)
	if not (ao and ap and aq) then
		return false
	end
	al.SetColor3(	al,Color3.fromRGB(ao, ap, aq))
	return true
end

function ak.SetActiveKeypoint(al, am)	
local an = ah(al._color)
	if typeof(an) ~= "ColorSequence" then
		return
	end
	if not an.Keypoints[am] then
		return
	end
	al._activeKeypoint(am)
	al._loadHsvFromCurrent(	al)
end

function ak.RemoveKeypoint(al, am)	
local an = ah(al._color)
	if typeof(an) ~= "ColorSequence" then
		return
	end

	local ao = an.Keypoints
	if am <= 1 or am >= #ao then
		return
	end

	local ap = {}
	local aq = {}
	local ar = ah(al._keypointIds)
	for as, at in ao do
		if as ~= am then
			table.insert(ap, at)
			table.insert(aq, ar[as])
		end
	end

	local as = ColorSequence.new(ap)
	al._color(as)
	al._keypointIds(aq)
	al._pushColor(	al,as)

	local at = ah(al._activeKeypoint)
	if at == am then
		al._activeKeypoint(1)
		al._loadHsvFromCurrent(		al)
	elseif at > am then
		al._activeKeypoint(at - 1)
	end
end

function ak.AddKeypoint(al, am)	
local an = ah(al._color)
	if typeof(an) ~= "ColorSequence" then
		return
	end

	local ao = math.clamp(am, 0.001, 0.999)
	local ap = ah(al._hue)
	local aq = ah(al._saturation)
	local ar = ah(al._value)
	local as = Color3.fromHSV(ap, aq, ar)
	local at = al._assignIds(al,1)[1]

	local au = {}
	local av = {}
	local aw = ah(al._keypointIds)
	local ax 	
for b, c in an.Keypoints do
		if not ax and c.Time > ao then
			ax = b
			table.insert(au, ColorSequenceKeypoint.new(ao, as))
			table.insert(av, at)
		end
		table.insert(au, c)
		table.insert(av, aw[b])
	end
	if not ax then
		ax = #au + 1
		table.insert(au, ColorSequenceKeypoint.new(ao, as))
		table.insert(av, at)
	end

	local b = ColorSequence.new(au)
	al._color(b)
	al._keypointIds(av)
	al._pushColor(	al,b)
	al._activeKeypoint(ax)
end

function ak.Open(al, am, an)	
local ao = ah(al._source)

	if ao == am and ah(al._isOpen) then
		return
	end

	local ap = ah(am._state)
	local aq = am._transparency and ah(am._transparency) or nil

	al._title(ah(am._text))
	al._color(ap)
	al._transparency(aq)
	al._source(am)
	al._activeKeypoint(1)

	if typeof(ap) == "ColorSequence" then
		al._keypointIds(al._assignIds(al,#ap.Keypoints))
	else
		al._keypointIds{}	
end

	al._rotation(am._rotation and ah(am._rotation) or 0)
	al._animation(am._animation and ah(am._animation) or "none")
	al._speed(am._speed and ah(am._speed) or 1)

	al._loadHsvFromCurrent(
	al)

	al.SetPosition(
	al,an or UDim2.new(0, 10, 0, 10))
	al.SetOpen(	al,true)
end

function ak.Close(al)	al.SetOpen(	al,false)
end

function ak.Render(al)	return aj(ad, {
		Colorpicker = al,
	})
end


























return constructor
end function a.ah()
local aa = (cloneref(game.GetService(game, "TextService")) )

local ab = a.load'e'
local ac = a.load'd'
local ad = a.load'c'
local ae = a.load'n'

local af = a.load'N'
local ag = a.load's'
local ah = a.load'P'
local ai = a.load'X'
local aj = a.load'T'
local ak = a.load'O'

local al = ab.useSpring
local am = ad.useEffect
local an = ad.useMemo
local ao = ad.useState
local ap = ad.useRef
local aq = ac.useAtom
local ar = ad.createElement

local as = 0.15
local at = 5
local au = 5
local av = 22
local aw = 7
local ax = 6
local b = 220
local c = 13
local d = 8
local e = 10
local f = 13
local g = 6

local h = af.colors.subwindow
local i = af.colors.window.element

local j = (Instance.new"GetTextBoundsParams")

local function measuredLabelWidth(k)	
local l, m = pcall(function()		
j.Text = k
		j.FontFace = ag.Get("font", "semi_bold")
		j.Size = c
		return aa.GetTextBoundsAsync(aa,j)
	end)
	if l and typeof(m) == "Vector2" then
		return m.X
	end
	local n = utf8.len(k)
	if n then
		return n * c * 0.53
	end
	return #k * c * 0.53
end

local function computeMenuWidth(k)	
local l = d + e
	for m, n in k do
		if n.Divider then
			continue
		end
		local o = measuredLabelWidth(n.Label or "")
		local p = d + e + o
		if n.Icon then
			p += f + g
		end
		if p > l then
			l = p
		end
	end
	return math.min(b, math.max(2, math.ceil(l)))
end

local function ContextButton(k










)	
local l = k.Label
local _=k.Icon
	local n = k.Callback
	local o = k.OnClose
	local p = k.FillWidth

	local q, r = ao(false)
	local s = aq(h.image)
	local t = aq(h.text)

	local u, v = al(0, ak.snap)

	local w = ap(k.Icon)
	if k.Icon then
		w.current = k.Icon
	end
	local x, y = al(k.Icon and 0 or 1, ak.quick)
	am(function()
		y.setGoal(		y,k.Icon and 0 or 1)
	end, { k.Icon })

	local z = ap(nil )
	local A = ap(false)
	local B = ap(k.OnHoverEnter)
	local C = ap(k.OnHoverLeave)
	B.current = k.OnHoverEnter
	C.current = k.OnHoverLeave

	local function clearHover()		
if z.current then
			task.cancel(z.current)
			z.current = nil
		end
		if A.current then
			A.current = false
			local D = C.current
			if D then
				D()
			end
		end
	end

	am(function()
		v.setGoal(		v,q and 1 or 0)
	end, { q })

	am(function()
		if not k.IsContextOpen then
			clearHover()
		end
	end, { k.IsContextOpen })

	am(function()
		return function()
			clearHover()
		end
	end, {})

	local D= {
		UIListLayout = ar("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, g),
		}),
		UIPadding = ar("UIPadding", {
			PaddingLeft = UDim.new(0, d),
			PaddingRight = UDim.new(0, e),
			PaddingTop = UDim.new(0, 0),
			PaddingBottom = UDim.new(0, 0),
		}),
	}

	if w.current then
		D.Image = ar("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			Size = UDim2.fromOffset(f, f),
			Image = w.current,
			ImageColor3 = s,
			ImageTransparency = x,
		})
		D.TextHold = ar("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = 2,
		}, {
			UIFlexItem = ar("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
				ItemLineAlignment = Enum.ItemLineAlignment.Stretch,
			}),
			Text = ar("TextLabel", {
				TextSize = c,
				TextColor3 = t,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = l,
				BorderSizePixel = 0,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				FontFace = ag.Get("font", "semi_bold"),
			}),
		})
	else
		D.Text = ar("TextLabel", {
			TextSize = c,
			TextColor3 = t,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			AutomaticSize = Enum.AutomaticSize.X,
			Text = l,
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, c),
			LayoutOrder = 2,
			FontFace = ag.Get("font", "semi_bold"),
		})
	end

	return ar("TextButton", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = u.map(u,function(E)
			return 1 - (E * 0.03)
		end),
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutomaticSize = p and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		Size = p and UDim2.new(1, 0, 0, av) or UDim2.new(0, 0, 0, av),
		AutoButtonColor = false,
		LayoutOrder = k.LayoutOrder,
		[ad.Event.MouseButton1Click] = function()
			clearHover()
			o()
			if n then
				n()
			end
		end,
		[ad.Event.MouseEnter] = function()
			r(true)
			local E = B.current
			if E then
				if z.current then
					task.cancel(z.current)
				end
				local F = k.HoverDelay or as
				z.current = task.delay(F, function()
					z.current = nil
					A.current = true
					local G = B.current
					if G then
						G()
					end
				end)
			end
		end,
		[ad.Event.MouseLeave] = function()
			r(false)
			clearHover()
		end,
	}, D)
end

local function Divider(k)	
local l = aq(h.divider)

	return ar("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, aw),
		LayoutOrder = k.LayoutOrder,
	}, {
		Line = ar("Frame", {
			BackgroundColor3 = l,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
		}),
	})
end

return function(k)	
local l = k.Context

	local m = aq(h.background)
	local n = aq(h.stroke)
	local o = aq(i.scrollThumb)

	local p = aq(l._items)
	local q = aq(l._isOpen)

	local r = aj(l, {
		preset = ak.snap,
		slideOffset = 6,
		strokeIntensity = 0.6,
		floatingId = "subwindow.context",
		onClickOutside = function()
			if ai.WasJustOpened() then
				return
			end
			l.Close(			l)
		end,
	})

	am(function()
		ah.context = r.frameRef
		return function()
			ah.context = nil
		end
	end, {})

	local function close()		
l.Close(		l)
	end

	local s = 0
	local t = 0
	for u, v in p do
		if v.Divider then
			t += 1
		else
			s += 1
		end
	end
	local u = s > at
	local v = s * av + t * aw + ax * 2

	local w = an(function()		
return computeMenuWidth(p)
	end, { p })

	local x= {}

	for y, z in p do
		if z.Divider then
			x[`Divider_{y}`] = ar(Divider, { LayoutOrder = y })
		else
			x[`Item_{y}`] = ar(ContextButton, {
				Label = z.Label or "",
				Icon = z.Icon,
				Callback = z.Callback,
				OnHoverEnter = z.OnHoverEnter,
				OnHoverLeave = z.OnHoverLeave,
				HoverDelay = z.HoverDelay,
				OnClose = close,
				IsContextOpen = q,
				LayoutOrder = y,
				FillWidth = true,
			})
		end
	end

	local y	
if u then
		local z = au * av + ax * 2

		y = ar("CanvasGroup", {
			ref = r.frameRef,
			BackgroundTransparency = 0,
			BackgroundColor3 = m,
			Size = UDim2.fromOffset(w, z),
			AutomaticSize = Enum.AutomaticSize.None,
			GroupTransparency = r.transparency,
			ZIndex = 1,
		}, {
			UIStroke = ar("UIStroke", {
				Color = n,
				Transparency = r.strokeTransparency,
				Thickness = 1,
			}),
			UICorner = ar("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			Scroll = ar(
				"ScrollingFrame",
				{
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 1, 0),
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollBarThickness = 3,
					ScrollBarImageColor3 = o,
					ScrollBarImageTransparency = 0.2,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					VerticalScrollBarInset = Enum.ScrollBarInset.None,
					ZIndex = 1,
				},
				ae.Dictionary.join({
					UIPadding = ar("UIPadding", {
						PaddingLeft = UDim.new(0, 0),
						PaddingRight = UDim.new(0, 0),
						PaddingTop = UDim.new(0, ax),
						PaddingBottom = UDim.new(0, ax),
					}),
					UIListLayout = ar("UIListLayout", {
						VerticalAlignment = Enum.VerticalAlignment.Top,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 0),
					}),
				}, x)
			),
		})
	else
		y = ar("CanvasGroup", {
			ref = r.frameRef,
			BackgroundTransparency = 0,
			BackgroundColor3 = m,
			Size = UDim2.fromOffset(w, v),
			AutomaticSize = Enum.AutomaticSize.None,
			GroupTransparency = r.transparency,
			ZIndex = 1,
		}, {
			UIStroke = ar("UIStroke", {
				Color = n,
				Transparency = r.strokeTransparency,
				Thickness = 1,
			}),
			UICorner = ar("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			Items = ar(
				"Frame",
				{
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 1, 0),
					ZIndex = 1,
				},
				ae.Dictionary.join({
					UIPadding = ar("UIPadding", {
						PaddingLeft = UDim.new(0, 0),
						PaddingRight = UDim.new(0, 0),
						PaddingTop = UDim.new(0, ax),
						PaddingBottom = UDim.new(0, ax),
					}),
					UIListLayout = ar("UIListLayout", {
						VerticalAlignment = Enum.VerticalAlignment.Top,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 0),
					}),
				}, x)
			),
		})
	end

	return ar("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = r.position,
		Visible = r.visible,
		ZIndex = r.zIndex,
	}, {
		Body = y,
	})
end
end function a.ai()
local aa = a.load'm'
local ab = a.load'c'

local ac = a.load'M'
local ad = a.load'ah'

local ae = aa.atom
local af = ab.createElement

local ag = {}
ag.__index = ag

setmetatable(ag, { __index = ac })











local function constructor()	
local ah = (ac.new() )
	
setmetatable(ah, ag)

	ah._items = ae({} )

	return ah
end

function ag.Open(ah, ai, aj)	
if not ai or #ai == 0 then
		return
	end

	ah._items(ai)
	ah.SetPosition(	ah,aj or UDim2.new(0, 0, 0, 0))
	ah.SetOpen(	ah,true)
end

function ag.Close(ah)	
ah.SetOpen(	ah,false)
end

function ag.Render(ah)	
return af(ad, {
		Context = ah,
	})
end









return constructor
end function a.aj()
local aa = a.load'c'
local ab = a.load'e'
local ac = a.load'd'
local ad = a.load'm'
local ae = a.load'n'

local af = a.load's'
local ag = a.load'N'
local ah = a.load'T'
local ai = a.load'U'
local aj = a.load'O'
local ak = a.load'S'

local al = ab.useSpring
local am = aa.useEffect
local an = aa.useState
local ao = aa.useRef
local ap = ac.useAtom
local aq = aa.createElement

local ar = ag.colors.subwindow
local as = ag.colors.window.element

local at = 22
local au = 14

local av = ad.atom({} )
local aw = ad.atom(nil )
local ax = ad.atom"single"









local function Row(b)	
local c = b.Option
	local d = b.Mode
	local e = b.IsSelected
	local f = b.OnPick

	local g, h = an(false)
	local i = ao(nil )

	local j = ap(ar.text)
	local k = ap(as.accentStrong)
	local l = ap(as.accent)
	local m = ap(as.surfaceStroke)
	local n = ap(as.panel)
	local o = ap(as.thumbHighlight)

	local p, q = al(0, aj.snap)
	local r, s = al(0, aj.smooth)

	am(function()
		q.setGoal(		q,g and 1 or 0)
	end, { g })

	am(function()
		s.setGoal(		s,e and 1 or 0)
	end, { e })

	local t	
if d == "multi" then
		local u = 12
		t = aq("Frame", {
			BackgroundColor3 = r.map(r,function(v)
				return n.Lerp(n,l, v)
			end),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(u, u),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
		}, {
			UICorner = aq("UICorner", {
				CornerRadius = UDim.new(0, 3),
			}),
			UIStroke = aq("UIStroke", {
				Color = r.map(r,function(v)
					return m.Lerp(m,k, v)
				end),
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			UIScale = aq("UIScale", {
				Scale = r.map(r,function(v)
					return 0.92 + v * 0.08
				end),
			}),
			Mark = aq("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = af.Get("image", "checkmark"),
				ImageColor3 = o,
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromOffset(8, 8),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ImageTransparency = r.map(r,function(v)
					return 1 - v * v
				end),
			}),
		})
	elseif e then
		t = aq("Frame", {
			BackgroundColor3 = k,
			BorderSizePixel = 0,
			BackgroundTransparency = r.map(r,function(u)
				return 1 - u
			end),
			Size = UDim2.new(0, 2, 1, -8),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
		}, {
			UICorner = aq("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		})
	end

	return aq("TextButton", {
		ref = i,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = p.map(p,function(u)
			return 1 - (u * 0.04)
		end),
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, at),
		LayoutOrder = b.LayoutOrder,
		[aa.Event.MouseEnter] = function()
			h(true)
		end,
		[aa.Event.MouseLeave] = function()
			h(false)
		end,
		[aa.Event.MouseButton1Click] = function()
			f(c)
		end,
	}, {
		UIPadding = aq("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 0),
			PaddingBottom = UDim.new(0, 0),
		}),
		UIFlexItem = aq("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Fill,
			ItemLineAlignment = Enum.ItemLineAlignment.Stretch,
		}),
		Indicator = aq("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, au, 1, 0),
			LayoutOrder = 0,
		}, {
			Inner = t,
		}),
		Text = aq("TextLabel", {
			BackgroundTransparency = 1,
			TextColor3 = j,
			TextSize = 13,
			Text = c,
			Position = UDim2.fromOffset(au + 4, -1),
			Size = UDim2.new(1, -(au + 4), 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			FontFace = af.Get("font", "semi_bold"),
			LayoutOrder = 1,
		}),
	})
end

return function(b)	
local c = b.Dropdown

	local d = ap(c._source)

	local e = ap(ar.background)
	local f = ap(ar.stroke)

	local g = { d }
	local h = ap(d and d._options or av, g)
	local i = ap(d and d._state or aw, g)
	local j = ap(d and d._mode or ax, g)

	local k = ah(c, {
		preset = aj.snap,
		slideOffset = 0,
		strokeIntensity = 0.6,
		floatingId = "subwindow.dropdown",
		floatingPriority = ak.PRIORITY.DROPDOWN,
		onClickOutside = function()
			c.Close(			c)
		end,
	})

	local function isOptionSelected(l)		
if j == "multi" then
			if type(i) ~= "table" then
				return false
			end
			for m, n in i do
				if n == l then
					return true
				end
			end
			return false
		end
		return i == l
	end

	local function pickOption(l)		
if not d then
			return
		end
		d.Toggle(		d,l)
	end

	local l= {}
	for m, n in h do
		l[`Row_{m}_{n}`] = aq(Row, {
			Option = n,
			Mode = j,
			IsSelected = isOptionSelected(n),
			OnPick = pickOption,
			LayoutOrder = m,
		})
	end

	return aq("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = k.position,
		Visible = k.visible,
		ZIndex = k.zIndex,
	}, {
		Shadow = ai{
			transparency = k.transparency,
			zIndex = 0,
		},
		Body = aq("CanvasGroup", {
		ref = k.frameRef,
		BackgroundTransparency = 0,
		BackgroundColor3 = e,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		GroupTransparency = k.transparency,
		ZIndex = 1,
	}, {
		UIStroke = aq("UIStroke", {
			Color = f,
			Transparency = k.strokeTransparency,
			Thickness = 1,
		}),
		UICorner = aq("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIPadding = aq("UIPadding", {
			PaddingLeft = UDim.new(0, 0),
			PaddingRight = UDim.new(0, 0),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		}),
		UISizeConstraint = aq("UISizeConstraint", {
			MaxSize = Vector2.new(220, math.huge),
		}),
		Rows = aq(
			"Frame",
			{
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.new(1, 0, 0, 0),
			},
			ae.Dictionary.join({
				UIListLayout = aq("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Top,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),
			}, l)
		),
		}),
	})
end
end function a.ak()
local aa = a.load'm'
local ab = a.load'c'

local ac = a.load'M'
local ad = a.load'aj'

local ae = aa.atom
local af = aa.peek
local ag = aa.subscribe
local ah = ab.createElement

local ai = 0.1

local aj = {}
aj.__index = aj

setmetatable(aj, { __index = ac })

local function constructor()	
local ak = (ac.new() )	
setmetatable(ak, aj)

	ak._source = ae(nil )
	ak._lastClosedSource = nil
	ak._lastClosedAt = 0

	ag(ak._isOpen, function(al)
		if al then
			return
		end
		local am = af(ak._source)
		if am then
			am._open(false)
			ak._lastClosedSource = am
			ak._lastClosedAt = os.clock()
		end
		ak._source(nil )
	end)

	return ak
end

function aj.Open(ak, al, am)	
local an = af(ak._source)
	if an and an ~= al then
		an._open(false)
	end

	ak._source(al)
	al._open(true)

	ak.SetPosition(
	ak,am or UDim2.new(0.5, 0, 0.5, 0))
	ak.SetOpen(	ak,true)
end

function aj.Close(ak)	local al = af(ak._source)
	if al then
		al._open(false)
		ak._lastClosedSource = al
		ak._lastClosedAt = os.clock()
	end
	ak.SetOpen(	ak,false)
end

function aj.WasJustClosedFor(ak, al)	
return ak._lastClosedSource == al and os.clock() - ak._lastClosedAt < ai
end

function aj.Render(ak)	
return ah(ad, {
		Dropdown = ak,
	})
end











return constructor
end function a.al()
local aa = (cloneref(game.GetService(game, "UserInputService")) )
local ab = (cloneref(game.GetService(game, "RunService")) )

local ac = a.load'c'
local ad = a.load'm'
local ae = a.load'I'

local af = ac.useEffect
local ag = ac.useRef
local ah = ac.useCallback
local ai = ac.useBinding

local aj = LPH_NO_VIRTUALIZE(function(aj)
	local ak = ad.peek(aj)
	local al, am = ai(ak)

	local an = ag(false)
	local ao = ag(Vector2.zero)
	local ap = ag(Vector2.zero)
	local aq = ag(Vector2.zero)
	local ar = ag(nil )
	local as = ag(ak)
	local at = ag(aj)
	at.current = aj
	local au = ag(am)
	au.current = am

	af(function()
		local av = ad.subscribe(at.current, function(av)
			if an.current then
				return
			end
			if as.current ~= av then
				as.current = av
				au.current(av)
			end
		end)
		return av
	end, {})

	local av = ah(function(av)
		if av.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		an.current = true
		ao.current = Vector2.new(av.Position.X, av.Position.Y)

		local aw = ad.peek(at.current)
		ap.current = Vector2.new(aw.X.Scale, aw.Y.Scale)
		aq.current = Vector2.new(aw.X.Offset, aw.Y.Offset)
		as.current = aw
	end, {})

	af(function()
		local aw = aa.InputChanged:Connect(function(aw)
			if not an.current then
				return
			end
			if aw.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end

			local ax = Vector2.new(aw.Position.X, aw.Position.Y) - ao.current
			local b = ad.peek(ae.scale)
			if b <= 0 then
				b = 1
			end
			local c = ax / b
			ar.current = UDim2.new(
				ap.current.X,
				aq.current.X + c.X,
				ap.current.Y,
				aq.current.Y + c.Y
			)
		end)

		local ax = ab.Heartbeat:Connect(function()
			local ax = ar.current
			if ax == nil then
				return
			end
			ar.current = nil
			if as.current ~= ax then
				as.current = ax
				au.current(ax)
				at.current(ax)
			end
		end)

		local b = aa.InputEnded:Connect(function(b)
			if b.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			if not an.current then
				return
			end
			an.current = false
			local c = ar.current
			ar.current = nil
			if c and as.current ~= c then
				as.current = c
				au.current(c)
				at.current(c)
			end
		end)

		return function()
			aw.Disconnect(			aw)
			ax.Disconnect(			ax)
			b.Disconnect(			b)
		end
	end, {})

	return av, al
end)

return aj
end function a.am()
local aa = a.load'm'
local ab = a.load'd'
local ac = a.load'e'
local ad = a.load'c'
local ae = a.load'n'
local af = a.load'N'
local ag = a.load's'
local ah = a.load'ab'
local ai = a.load'T'
local aj = a.load'U'
local ak = a.load'al'
local al = a.load'O'
local am = a.load'S'

local an = af.colors.subwindow
local ao = af.colors.window.element

local ap = ad.useEffect
local aq = ad.useMemo
local ar = ad.useState
local as = ad.useRef
local at = ac.useSpring
local au = ab.useAtom
local av = ad.createElement

local aw = 320
local ax = 480
local b = 12
local c = 18
local d = 28
local e = 1
local f = 10








local function FooterButton(g)	
local h = aq(function()
		return aa.atom(g.Variant == "primary")
	end, {})

	local i = ah(ao.surface, ao.accentStrong, h, true)
	local j = au(ao.surfaceStroke)
	local k = ah(ao.text, ao.textActive, h)

	local l, m = ar(false)
local n, o =at(0, al.smooth)

	ap(function()
		o.setGoal(		o,l and 1 or 0)
	end, { l })

	return av("TextButton", {
		BackgroundColor3 = i.binding,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = UDim2.new(0, 70, 0, 22),
		LayoutOrder = g.LayoutOrder,
		[ad.Event.MouseEnter] = function()
			i.onMouseEnter()
			k.onMouseEnter()
		end,
		[ad.Event.MouseLeave] = function()
			m(false)
			i.onMouseLeave()
			k.onMouseLeave()
		end,
		[ad.Event.MouseButton1Down] = function()
			m(true)
		end,
		[ad.Event.MouseButton1Up] = function()
			m(false)
		end,
		[ad.Event.MouseButton1Click] = function()
			g.OnClick()
		end,
	}, {
		UICorner = av("UICorner", {
			CornerRadius = UDim.new(0, 5),
		}),
		UIStroke = av("UIStroke", {
			Color = j,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		Label = av("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = g.Text,
			TextColor3 = k.binding,
			TextSize = 12,
			FontFace = ag.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

return function(g)	
local h = g.ThemeEditor

	local i = au(h._title)
	local j = au(h._sections)

	local k = au(an.background)
	local l = au(an.divider)
	local m = au(an.stroke)
	local n = au(an.title)
	local o = au(ao.scrollThumb)

	local p = aq(function()
		local p = {}
		for q, r in next, j do
			p[`Section_{q}_{tostring(r)}`] = r.Render(r)
		end
		return p
	end, { j })

	local q = ai(h, {
		slideOffset = 18,
		floatingId = "subwindow.themeEditor",
		floatingPriority = am.PRIORITY.MODAL,
	})

	local r = ak(h._position)

	local s = as(nil )
	local t = as(nil )
	local u, v = ar(false)

	ap(function()
		local w= {}
		local function recompute()
			local x = s.current
			local y = t.current
			if not x or not y then
				return
			end
			v(y.AbsoluteSize.Y > x.AbsoluteSize.Y + 1)
		end

		local function tryConnect()
			for x, y in w do
				y.Disconnect(				y)
			end
			while w[1] do
				table.remove(w, 1)
			end

			local x = s.current
			local y = t.current
			if not x or not y then
				task.defer(tryConnect)
				return
			end

			table.insert(w, x.GetPropertyChangedSignal(x, "AbsoluteSize"):Connect(recompute))
			table.insert(w, y.GetPropertyChangedSignal(y, "AbsoluteSize"):Connect(recompute))
			task.defer(recompute)
		end

		tryConnect()

		return function()
			for x, y in w do
				y.Disconnect(				y)
			end
		end
	end, {})

	return av("Frame", {
		ref = q.frameRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(aw, ax),
		Position = q.position,
		Visible = q.visible,
		ZIndex = q.zIndex,
	}, {
		Shadow = aj{
			transparency = q.transparency,
			zIndex = 0,
		},
		UIStroke = av("UIStroke", {
			Color = m,
			Transparency = q.strokeTransparency,
			Thickness = 1,
		}),
		UICorner = av("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		Inner = av("CanvasGroup", {
			BackgroundTransparency = 0,
			BackgroundColor3 = k,
			Size = UDim2.fromScale(1, 1),
			GroupTransparency = q.transparency,
			ZIndex = 1,
		}, {
			UICorner = av("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			UIPadding = av("UIPadding", {
				PaddingLeft = UDim.new(0, 1),
				PaddingRight = UDim.new(0, 1),
				PaddingTop = UDim.new(0, 1),
				PaddingBottom = UDim.new(0, 1),
			}),
			Title = av("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(b, b),
				Size = UDim2.new(1, -b * 2, 0, c),
				Text = i,
				TextColor3 = n,
				TextSize = 14,
				FontFace = ag.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
			TitleDivider = av("Frame", {
				BackgroundColor3 = l,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(b, b + c + 4),
				Size = UDim2.new(1, -b * 2, 0, e),
			}),
			Scroll = av("ScrollingFrame", {
				ref = s,
				Active = false,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(b, b + c + 4 + e + 6),
				Size = UDim2.new(
					1,
					-b * 2,
					1,
					-(
							b
							+ c
							+ 4
							+ e
							+ 6
							+ d
							+ 6
							+ e
							+ 6
							+ b
						)
				),
				ClipsDescendants = true,
				ScrollingEnabled = u,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.fromOffset(0, 0),
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				ScrollBarImageColor3 = o,
				ScrollBarImageTransparency = u and 0.1 or 1,
				ScrollBarThickness = u and 3 or 0,
			}, {
				Inner = av(
					"Frame",
					{
						ref = t,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
					},
					ae.Dictionary.join({
						UIListLayout = av("UIListLayout", {
							VerticalAlignment = Enum.VerticalAlignment.Top,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, f),
						}),
						UIPadding = av("UIPadding", {
							PaddingLeft = UDim.new(0, 2),
							PaddingRight = UDim.new(0, 4),
							PaddingBottom = UDim.new(0, 4),
						}),
					}, p)
				),
			}),
			TitleDragStrip = av("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(b, b),
				Size = UDim2.new(1, -b * 2, 0, c + 4 + e),
				ZIndex = 5,
				Active = true,
				[ad.Event.InputBegan] = function(w, x)
					r(x)
				end,
			}),
			FooterDivider = av("Frame", {
				BackgroundColor3 = l,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, b, 1, -(b + d + 6)),
				Size = UDim2.new(1, -b * 2, 0, e),
			}),
			Footer = av("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, b, 1, -b),
				Size = UDim2.new(1, -b * 2, 0, d),
			}, {
				UIListLayout = av("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				Cancel = av(FooterButton, {
					Text = "Cancel",
					Variant = "secondary",
					LayoutOrder = 1,
					OnClick = function()
						h.Cancel(						h)
					end,
				}),
				Save = av(FooterButton, {
					Text = "Save",
					Variant = "primary",
					LayoutOrder = 2,
					OnClick = function()
						h.Save(						h)
					end,
				}),
			}),
		}),
	})
end
end function a.an()
local aa = a.load'm'
local ab = a.load'c'

local ac = a.load'M'
local ad = a.load'am'

local ae = aa.atom
local af = ab.createElement

local ag = {}
ag.__index = ag

setmetatable(ag, { __index = ac })

local function constructor()	
local ah = (ac.new() )	
setmetatable(ah, ag)

	ah._title = ae""	
ah._themeName = ae(nil )
	ah._sections = ae({} )

	ah._snapshot = nil 	
ah._onSave = nil 	
ah._onCancel = nil 
	
return ah
end

function ag.SetSections(ah, ai)	
ah._sections(ai)
end










function ag.Open(ah, ai)	
ah._title(ai.title)
	ah._themeName(ai.name)
	ah._snapshot = ai.snapshot
	ah._onSave = ai.onSave
	ah._onCancel = ai.onCancel

	ah.SetPosition(
	ah,ai.position or UDim2.fromScale(0.5, 0.5))
	ah.SetOpen(	ah,true)
end

function ag.Save(ah)	local ai = ah._onSave
	ah._snapshot = nil
	ah._onSave = nil
	ah._onCancel = nil
	ah.SetOpen(	ah,false)
	if ai then
		ai()
	end
end

function ag.Cancel(ah)	
local ai = ah._onCancel
	ah._snapshot = nil
	ah._onSave = nil
	ah._onCancel = nil
	ah.SetOpen(	ah,false)
	if ai then
		ai()
	end
end

function ag.Render(ah)	
return af(ad, { ThemeEditor = ah })
end















return constructor
end function a.ao()
local aa = (cloneref(game.GetService(game, "UserInputService")) )

local ab = a.load'e'
local ac = a.load'd'
local ad = a.load'c'
local ae = a.load'm'

local af = a.load'N'
local ag = a.load's'
local ah = a.load'T'
local ai = a.load'U'
local aj = a.load'ab'
local ak = a.load'L'
local al = a.load'O'

local am = ab.useSpring
local an = ac.useAtom
local ao = ad.useEffect
local ap = ad.useMemo
local aq = ad.useRef
local ar = ad.useState
local as = ae.peek
local at = ae.subscribe
local au = ad.createElement

local av = af.colors.subwindow
local aw = af.colors.window.element

local ax = 230
local b = 10
local c = 11
local d = 10
local e = 4
local f = 4
local g = 8
local h = 10
local i = 18
local j = 14
local k = 2
local l = 18

local m = 44
local n = 18
local o = 3
local p = m * o
local q = 56
local r = 18
local s = 18
local t = 30
local u = 14
local v = 10

local w = 12
local x = 11

local y= {
	{ mode = "toggle", label = "Toggle" },
	{ mode = "onHold", label = "Hold" },
	{ mode = "offHold", label = "Off" },
}

local function modeIndex(z)	
for A, B in next, y do
		if B.mode == z then
			return A - 1
		end
	end
	return 0
end

local function useBoolAtom(z)	
local A = ap(function()
		return ae.atom(false)
	end, {})
	ao(function()
		A(z)
	end, { z })
	return A
end

local function trim(z)	
return (z.gsub(z,"^%s+", ""):gsub("%s+$", ""))
end

local function formatTargetDraft(z)	
local A = type(z)
	if A == "number" then
		local B = math.round(z * 1000) / 1000
		local C = string.format("%.3f", B)
		C = C.gsub(C,"0+$", "")
		C = C.gsub(C,"%.$", "")
		return C
	elseif A == "string" then
		return z
	end
	return ""
end

local function Row(z



)	
local A = an(aw.text)

	return au("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, i),
		LayoutOrder = z.layoutOrder,
	}, {
		UIListLayout = au("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = au("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = z.label,
			TextSize = w,
			TextColor3 = A,
			FontFace = ag.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 0,
		}, {
			UIFlexItem = au("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
			}),
		}),
		Control = au("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 1,
		}, {
			UIListLayout = au("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Item = z.control,
		}),
	})
end

local function KeyChip(z





)	
local A = useBoolAtom(z.isListening)
	local B = z.hasInput and aw.text or aw.caption

	local C = aj(aw.fieldBackground, aw.fieldBackgroundActive, A)
	local D = aj(aw.fieldStroke, aw.fieldStrokeActive, A)
	local E = aj(B, aw.textActive, A)

	return au("TextButton", {
		BackgroundColor3 = C.binding,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(q, r),
		Text = z.label,
		TextSize = x,
		TextColor3 = E.binding,
		FontFace = ag.Get("font", "semi_bold"),
		AutoButtonColor = false,
		Active = false,
		LayoutOrder = z.layoutOrder,
		[ad.Event.MouseEnter] = function()
			C.onMouseEnter()
			D.onMouseEnter()
			E.onMouseEnter()
		end,
		[ad.Event.MouseLeave] = function()
			C.onMouseLeave()
			D.onMouseLeave()
			E.onMouseLeave()
		end,
		[ad.Event.MouseButton1Click] = z.onClick,
	}, {
		UICorner = au("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = au("UIStroke", {
			Color = D.binding,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

local function IconButton(z



)	
local A = aj(aw.surface)
	local B = aj(aw.surfaceStroke)
	local C = aj(aw.icon, aw.iconActive)

	return au("TextButton", {
		BackgroundColor3 = A.binding,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(s, s),
		Text = "",
		Active = false,
		AutoButtonColor = false,
		LayoutOrder = z.layoutOrder,
		[ad.Event.MouseEnter] = function()
			A.onMouseEnter()
			B.onMouseEnter()
			C.onMouseEnter()
		end,
		[ad.Event.MouseLeave] = function()
			A.onMouseLeave()
			B.onMouseLeave()
			C.onMouseLeave()
		end,
		[ad.Event.MouseButton1Click] = z.onPress,
	}, {
		UICorner = au("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = au("UIStroke", {
			Color = B.binding,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Image = au("ImageLabel", {
			BackgroundTransparency = 1,
			Image = z.image,
			ImageColor3 = C.binding,
			Size = UDim2.fromOffset(12, 12),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		}),
	})
end

local function Switch(z



)	
local A = useBoolAtom(z.on)
	local B = aj(aw.surface, aw.accent, A, true)
	local C = aj(aw.surfaceStroke, aw.accentStrong, A)
	local D = aj(aw.thumb, aw.thumbActive, A, true)

	local E, F = am(z.on and 1 or 0, al.quick)

	ao(function()
		F.setGoal(		F,z.on and 1 or 0)
	end, { z.on })

	return au("TextButton", {
		BackgroundColor3 = B.binding,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(t, u),
		Text = "",
		Active = false,
		AutoButtonColor = false,
		LayoutOrder = z.layoutOrder,
		[ad.Event.MouseEnter] = function()
			B.onMouseEnter()
			C.onMouseEnter()
			D.onMouseEnter()
		end,
		[ad.Event.MouseLeave] = function()
			B.onMouseLeave()
			C.onMouseLeave()
			D.onMouseLeave()
		end,
		[ad.Event.MouseButton1Click] = z.onClick,
	}, {
		UICorner = au("UICorner", { CornerRadius = UDim.new(0, 8) }),
		UIStroke = au("UIStroke", {
			Color = C.binding,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = au("UIPadding", {
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		}),
		Knob = au("Frame", {
			Size = UDim2.fromOffset(v, v),
			Position = E.map(E,function(G)
				return UDim2.fromScale(G, 0)
			end),
			AnchorPoint = E.map(E,function(G)
				return Vector2.new(G, 0)
			end),
			BackgroundColor3 = D.binding,
			BorderSizePixel = 0,
		}, {
			UICorner = au("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
	})
end

local function SegmentButton(z




)	
local A = useBoolAtom(z.selected)
	local B = aj(aw.text, aw.textActive, A)
	local C = an(aw.accentSoft)

	local D, E = ar(false)
	local F, G = am(0, al.subtle)

	ao(function()
		local H = (D and not z.selected) and 1 or 0
		G.setGoal(		G,H)
	end, { D, z.selected })

	return au("TextButton", {
		BackgroundColor3 = C,
		BackgroundTransparency = F.map(F,function(H)
			return 1 - H * 0.6
		end),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(z.xOffset, 0),
		Size = UDim2.fromOffset(m, n),
		Text = z.label,
		TextSize = x,
		TextColor3 = B.binding,
		FontFace = ag.Get("font", "semi_bold"),
		AutoButtonColor = false,
		Active = false,
		ZIndex = 2,
		[ad.Event.MouseEnter] = function()
			E(true)
			B.onMouseEnter()
		end,
		[ad.Event.MouseLeave] = function()
			E(false)
			B.onMouseLeave()
		end,
		[ad.Event.MouseButton1Click] = z.onPress,
	}, {
		UICorner = au("UICorner", { CornerRadius = UDim.new(0, 4) }),
	})
end

local function ModeSegmented(z



)	
local A = an(aw.surface)
	local B = an(aw.accentStrong)
	local C = an(aw.surfaceStroke)

	local D = modeIndex(z.selected)
	local E, F = am(D, al.smoothPrecise)

	ao(function()
		F.setGoal(		F,D)
	end, { D })

	local G= {
		UICorner = au("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = au("UIStroke", {
			Color = C,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Highlight = au("Frame", {
			BackgroundColor3 = B,
			BorderSizePixel = 0,
			Position = E.map(E,function(G)
				return UDim2.fromOffset(G * m, 0)
			end),
			Size = UDim2.fromOffset(m, n),
			ZIndex = 1,
		}, {
			UICorner = au("UICorner", { CornerRadius = UDim.new(0, 4) }),
		}),
	}

	for H, I in next, y do
		G[I.mode] = au(SegmentButton, {
			label = I.label,
			selected = z.selected == I.mode,
			xOffset = (H - 1) * m,
			onPress = function()
				z.onSelect(I.mode)
			end,
		})
	end

	return au("Frame", {
		BackgroundColor3 = A,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(p, n),
		LayoutOrder = z.layoutOrder,
	}, G)
end

local function TargetEntry(z



)	
local A = an(aw.fieldBackground)
	local B = an(aw.fieldStroke)
	local C = an(aw.caption)
	local D = an(aw.text)

	local E, F = ar(formatTargetDraft(z.value))

	ao(function()
		F(formatTargetDraft(z.value))
	end, { z.value })

	return au("TextBox", {
		BackgroundColor3 = A,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(80, i),
		Text = E,
		TextSize = x,
		TextColor3 = D,
		PlaceholderText = z.placeholder,
		PlaceholderColor3 = C,
		FontFace = ag.Get("font", "semi_bold"),
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		[ad.Change.Text] = function(G)
			F(G.Text)
		end,
		[ad.Event.FocusLost] = function(G)
			z.onCommit(G.Text)
		end,
	}, {
		UICorner = au("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = au("UIStroke", {
			Color = B,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = au("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
	})
end

local function BindEditorBindRows(z










)	
local A = z.element
	local B = z.bind
	local C = z.listeningId
	local D = z.setListeningId

	local E = an(B.mode)
	local F = an(B.inputs)
	local G = an(B.showInList)
	local H = an(A._state, { A })
	local I = type(H)

	local J = C == B.id
	local K = #F > 0
	local L = J and "..."
		or not K and "—"
		or ak.GetInputLabel(F[1])

	local M = ap(function()		
if type(A.CreateTargetProxy) == "function" then
			return A.CreateTargetProxy(A,as(B.targetValue))
		end
		return nil
	end, { A, B.id })

	ao(function()
		if not M then
			return
		end
		local N = at(M._state, function(N)
			B.targetValue(N)
		end)
		local O = at(B.targetValue, function(O)
			if O ~= nil then
				M._state(O)
			end
		end)
		return function()
			N()
			O()
		end
	end, { M })

	local N = (M == nil) and (I == "number" or I == "string")

	local function commitFallback(O)		
if not N then
			return
		end
		local P = type(as(A._state))
		if P == "number" then
			local Q = tonumber(trim(O))
			if Q ~= nil then
				B.targetValue(Q)
			end
		elseif P == "string" then
			B.targetValue(O)
		end
	end

	local O= {
		UIListLayout = au("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, h),
		}),
		UIPadding = au("UIPadding", {
			PaddingLeft = UDim.new(0, e),
			PaddingRight = UDim.new(0, e),
			PaddingTop = UDim.new(0, f),
		}),
	}

	if z.totalBinds > 1 then
		O.Header = au(Row, {
			label = `Bind {z.index}`,
			layoutOrder = 0,
			control = au(IconButton, {
				image = ag.Get("image", "trash"),
				onPress = z.onRemoveBind,
				layoutOrder = 0,
			}),
		})
	end

	O.Key = au(Row, {
		label = "Key",
		layoutOrder = 1,
		control = au("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(q + s + 6, r),
		}, {
			UIListLayout = au("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Chip = au(KeyChip, {
				label = L,
				isListening = J,
				hasInput = K,
				onClick = function()
					D(B.id)
				end,
				layoutOrder = 0,
			}),
			Clear = au(IconButton, {
				image = ag.Get("image", "clear"),
				onPress = function()
					B.inputs{}					
if J then
						D(nil)
					end
				end,
				layoutOrder = 1,
			}),
		}),
	})

	O.Mode = au(Row, {
		label = "Mode",
		layoutOrder = 2,
		control = au(ModeSegmented, {
			selected = E,
			onSelect = function(P)
				B.mode(P )
			end,
			layoutOrder = 0,
		}),
	})

	if M then
		O.Target = au(Row, {
			label = "Set to",
			layoutOrder = 3,
			control = M.RenderInternal(M, { layoutOrder = 0 }),
		})
	elseif N then
		local P= as(B.targetValue)
		if P == nil then
			P = H
		end
		O.Target = au(Row, {
			label = "Set to",
			layoutOrder = 3,
			control = au(TargetEntry, {
				value = P,
				placeholder = I == "number" and "Number" or "Value",
				onCommit = commitFallback,
			}),
		})
	end

	O.ShowInList = au(Row, {
		label = "Show in list",
		layoutOrder = 4,
		control = au(Switch, {
			on = G,
			onClick = function()
				B.showInList(not as(B.showInList))
			end,
			layoutOrder = 0,
		}),
	})

	local P, Q = am(z.isInitial and 1 or 0, al.smoothPrecise)

	ao(function()
		Q.setGoal(		Q,z.isRemoving and 0 or 1)
	end, { z.isRemoving })

	return au("CanvasGroup", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = z.layoutOrder,
		GroupTransparency = P.map(P,function(R)
			return 1 - R
		end),
	}, O)
end

local z = 0.25

local function BindEditorBody(A)	
local B = A.element

	local C, D = ar(nil )
	local E, F = ar({} )
	local G = an(B._binds, { B })

	local H = aq(nil )
	if H.current == nil then
		local I= {}
		for J, K in next, G do
			I[K.id] = true
		end
		H.current = I
	end

	ao(function()
		D(nil)
		if #as(B._binds) == 0 and B.AddBind then
			B.AddBind(			B)
		end
	end, { B })

	ao(function()
		if not C then
			return
		end

		local I = aa.InputBegan:Connect(function(I)
			if I.UserInputType == Enum.UserInputType.Keyboard then
				if I.KeyCode == Enum.KeyCode.Escape then
					D(nil)
					return
				end
				for J, K in next, as(B._binds) do
					if K.id == C then
						K.inputs{ I.KeyCode }						
break
					end
				end
				D(nil)
			elseif
				I.UserInputType == Enum.UserInputType.MouseButton1
				or I.UserInputType == Enum.UserInputType.MouseButton2
				or I.UserInputType == Enum.UserInputType.MouseButton3
			then
				for J, K in next, as(B._binds) do
					if K.id == C then
						K.inputs{ I.UserInputType }						
break
					end
				end
				D(nil)
			end
		end)

		return function()
			I.Disconnect(			I)
		end
	end, { C, B })

	local I = aj(aw.surface)
	local J = aj(aw.surfaceStroke)
	local K = aj(aw.text, aw.textActive)
	local L = an(av.divider)

	local function startRemove(M)		
if E[M] then
			return
		end
		F(function(N)
			local O = table.clone(N)
			O[M] = true
			return O
		end)
		if C == M then
			D(nil)
		end
		task.delay(z, function()			
B.RemoveBind(			B,M)
			F(function(N)
				if not N[M] then
					return N
				end
				local O = table.clone(N)
				O[M] = nil
				return O
			end)
		end)
	end

	local M= {
		UIListLayout = au("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, g),
		}),
	}

	local N = 0
	for O, P in next, G do
		if O > 1 then
			M[`Divider_{O}`] = au("Frame", {
				BackgroundColor3 = L,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 1),
				LayoutOrder = N,
			})
			N += 1
		end
		local Q = ((H.current ))[P.id] == true
		M[`Bind_{P.id}`] = au(BindEditorBindRows, {
			element = B,
			bind = P,
			index = O,
			totalBinds = #G,
			listeningId = C,
			setListeningId = D,
			onRemoveBind = function()
				startRemove(P.id)
			end,
			isInitial = Q,
			isRemoving = E[P.id] == true,
			layoutOrder = N,
		})
		N += 1
	end

	if #G < ak.MAX_BINDS then
		M.AddBind = au("TextButton", {
			BackgroundColor3 = I.binding,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -e * 2, 0, i),
			Position = UDim2.new(0.5, 0, 0, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			Text = "+ Add bind",
			TextSize = x,
			TextColor3 = K.binding,
			FontFace = ag.Get("font", "semi_bold"),
			AutoButtonColor = false,
			Active = false,
			LayoutOrder = N,
			[ad.Event.MouseEnter] = function()
				I.onMouseEnter()
				J.onMouseEnter()
				K.onMouseEnter()
			end,
			[ad.Event.MouseLeave] = function()
				I.onMouseLeave()
				J.onMouseLeave()
				K.onMouseLeave()
			end,
			[ad.Event.MouseButton1Click] = function()
				if B.AddBind then
					B.AddBind(					B)
				end
			end,
		}, {
			UICorner = au("UICorner", { CornerRadius = UDim.new(0, 4) }),
			UIStroke = au("UIStroke", {
				Color = J.binding,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
	end

	return au("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, M)
end

return function(A)	
local B = A.BindEditor

	local C = an(B._element)
	local D = an(av.background)
	local E = an(av.stroke)
	local F = an(av.title)
	local G = an(av.divider)

	local H = ah(B, {
		preset = al.snap,
		slideOffset = 8,
		floatingId = "subwindow.bindEditor",
		onClickOutside = function()
			B.Close(			B)
		end,
	})

	local I = aq(nil )
	local J, K = am(0, al.smoothPrecise)
	local L = aq(false)

	ao(function()
		local M = I.current
		if not M then
			return
		end
		local function update()			
local N = M.AbsoluteContentSize.Y
			if N <= 0 then
				return
			end
			local O = N + d * 2
			if not L.current then
				L.current = true
				K.setPosition(				K,O)
			end
			K.setGoal(			K,O)
		end
		update()
		local N = M.GetPropertyChangedSignal(M, "AbsoluteContentSize"):Connect(update)
		return function()
			N.Disconnect(			N)
		end
	end, { C })

	local M = J.map(J,function(M)
		return UDim2.fromOffset(ax, math.max(M, 0))
	end)

	return au("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = M,
		Position = H.position,
		Visible = H.visible,
		ZIndex = H.zIndex,
	}, {
		Shadow = ai{
			transparency = H.transparency,
			zIndex = 0,
		},
		Body = au("CanvasGroup", {
			ref = H.frameRef,
			BackgroundColor3 = D,
			BackgroundTransparency = 0,
			Size = UDim2.fromScale(1, 1),
			GroupTransparency = H.transparency,
			ZIndex = 1,
		}, {
			UICorner = au("UICorner", { CornerRadius = UDim.new(0, 6) }),
			UIStroke = au("UIStroke", {
				Color = E,
				Transparency = H.strokeTransparency,
				Thickness = 1,
			}),
			UIPadding = au("UIPadding", {
				PaddingLeft = UDim.new(0, b),
				PaddingRight = UDim.new(0, c),
				PaddingTop = UDim.new(0, d),
				PaddingBottom = UDim.new(0, d),
			}),
			UIListLayout = au("UIListLayout", {
				ref = I,
				FillDirection = Enum.FillDirection.Vertical,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, g),
			}),
			TitleFrame = au("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, j + k + 2),
				LayoutOrder = 0,
			}, {
				Title = au("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, j),
					Text = "Bind Settings",
					TextColor3 = F,
					FontFace = ag.Get("font", "semi_bold"),
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Divider = au("Frame", {
					BorderSizePixel = 0,
					BackgroundColor3 = G,
					Size = UDim2.new(1, 0, 0, k),
					Position = UDim2.fromOffset(0, l),
				}),
			}),
			Content = C and au(BindEditorBody, {
				element = C,
				key = tostring(C),
			}) or nil,
		}),
	})
end
end function a.ap()
local aa = a.load'm'
local ab = a.load'c'

local ac = a.load'M'
local ad = a.load'ao'

local ae = aa.atom
local af = aa.peek
local ag = ab.createElement

local ah = {}
ah.__index = ah

setmetatable(ah, { __index = ac })

local function constructor()	
local ai = (ac.new() )	
setmetatable(ai, ah)
	ai._element = ae(nil )
	return ai
end

function ah.Open(ai, aj, ak)	
ai._element(aj)
	if aj and aj.AddBind and aj._binds and #af(aj._binds) == 0 then
		aj.AddBind(		aj)
	end
	ai.SetPosition(	ai,ak or UDim2.new(0.5, 0, 0.5, 0))
	ai.SetOpen(	ai,true)
end

function ah.Close(ai)	
ai.SetOpen(	ai,false)
end

function ah.Render(ai)	
return ag(ad, { BindEditor = ai })
end









return constructor
end function a.aq()
local aa = a.load'm'

local ab = aa.atom











local ac = {
	active = (ab(false) ),
	info = (ab(nil ) ),
	anchor = (ab(nil ) ),
}



return ac
end function a.ar()
local aa = (cloneref(game.GetService(game, "UserInputService")) )

local ab = a.load'm'
local ac = a.load'aq'
local ad = a.load'S'
local ae = a.load'E'

local af = 0.4
local ag = "tooltip"

local ah = {}

local ai
local aj
local ak = 0
local al = false

local function clearPending()	
if ai then
		task.cancel(ai)
		ai = nil
	end
end

local function clearMoveListener()	
if aj then
		aj.Disconnect(		aj)
		aj = nil
	end
end

local function clearRegistration()	
if al then
		al = false
		ad.Unregister(ag)
	end
end

function ah.Show(am, an)	
if not ad.IsAllowed(ad.PRIORITY.TOOLTIP) then
		return
	end

	ak += 1
	local ao = ak
	clearPending()
	clearMoveListener()

	local function schedule()		
clearPending()
		ai = task.delay(af, function()
			ai = nil
			if ak ~= ao then
				return
			end
			if not ad.IsAllowed(ad.PRIORITY.TOOLTIP) then
				return
			end
			ac.info(am)
			ac.anchor(an)
			ac.active(true)
			if not al then
				al = true
				ad.Register(ag, ad.PRIORITY.TOOLTIP, ah.Hide)
			end
		end)
	end

	aj = aa.InputChanged:Connect(function(ap)		
if ap.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		if ak ~= ao then
			return
		end
		ac.active(false)
		clearRegistration()
		schedule()
	end)

	schedule()
end

function ah.UpdateAnchor(am)	
ac.anchor(am)
end

function ah.Hide()	
ak += 1
	clearPending()
	clearMoveListener()
	clearRegistration()
	ac.active(false)
end

ab.subscribe(ae.isOpen, function(am)	
if not am then
		ah.Hide()
	end
end)

return ah
end function a.as()
local aa = a.load'c'
local ab = a.load'm'
local ac = (cloneref(game.GetService(game, "GuiService")) )
local ad = a.load'ar'a.load'aq'

local af = a.load'I'

local ag = aa.useEffect
local ah = aa.useMemo
local ai = aa.useRef








local function normalize(aj)	
if aj == nil then
		return nil
	end
	if type(aj) == "string" then
		if aj == "" then
			return nil
		end
		return { body = aj }
	end
	if not aj.body or aj.body == "" then
		return nil
	end
	return { title = aj.title, body = aj.body }
end

local function useTooltip(aj, ak)	
local al = ai(normalize(aj))
	al.current = normalize(aj)

	local am = ai(ak)
	am.current = ak

	local an = ai(false)

	ag(function()
		return function()
			if an.current then
				ad.Hide()
				an.current = false
			end
		end
	end, {})

	ag(function()
		if not al.current and an.current then
			ad.Hide()
			an.current = false
		end
	end, { aj })

	return ah(function()
		return {
			onMouseEnter = function()
				local ao = al.current
				local ap = am.current
				local aq = ap and ap.current
				if not ao or not aq then
					return
				end
				an.current = true
				local ar = ab.peek(af.scale)
				if ar <= 0 then
					ar = 1
				end
				local as = aq.AbsolutePosition + Vector2.new(0, (ac.GetGuiInset(ac).Y ))
				ad.Show(ao, {
					position = as / ar,
					size = aq.AbsoluteSize / ar,
				})
			end,
			onMouseLeave = function()
				if an.current then
					ad.Hide()
					an.current = false
				end
			end,
		}
	end, {})
end

return useTooltip
end function a.at()
local aa = a.load'm'
local ab = a.load'd'
local ac = a.load'e'
local ad = a.load'c'
local ae = a.load'n'

local af = a.load's'
local ag = a.load'N'
local ah = a.load'ab'
local ai = a.load'T'
local aj = a.load'U'
local ak = a.load'as'
local al = a.load'O'
local am = a.load'S'

local an = ag.colors.subwindow
local ao = ag.colors.window.element

local ap = ad.useEffect
local aq = ad.useMemo
local ar = ad.useState
local as = ad.useRef
local at = ac.useSpring
local au = ab.useAtom
local av = ad.createElement

local aw = 220
local ax = 180
local b = 8
local c = 16
local d = 1
local e = 20
local f = 14
local g = 4
local h = 14
local i = 6

local j = aa.atom({} )
local k = aa.atom({} )
local l= {}

















local function AssignButton(m)	
local n = aq(function()
		return aa.atom(false)
	end, {})

	ap(function()
		n(m.IsActive)
	end, { m.IsActive })

	local o = ah(ao.surface, ao.accent, n, true)
	local p = ah(ao.surfaceStroke, ao.accentStrong, n)

	local q = au(ao.icon)
	local r = au(ao.thumbActive)

	local s, t = at(0, al.smoothPrecise)
	ap(function()
		t.setGoal(		t,m.IsActive and 1 or 0)
	end, { m.IsActive })

	local u = s.map(s,function(u)
		return q.Lerp(q,r, u)
	end)

	local v = m.Type.icon and (af.Get("image", m.Type.icon)) or (nil)

	local w = as(nil )
	local x	
if m.IsActive then
		x = `Unassign {m.Type.label}`
	elseif m.Type.tip and m.Type.tip ~= "" then
		x = m.Type.tip
	else
		x = `Assign {m.Type.label}`
	end
	local y = ak(x, w)

	return av("TextButton", {
		ref = w,
		BackgroundColor3 = o.binding,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = UDim2.fromOffset(f, f),
		LayoutOrder = m.LayoutOrder,
		[ad.Event.MouseEnter] = function()
			o.onMouseEnter()
			p.onMouseEnter()
			y.onMouseEnter()
		end,
		[ad.Event.MouseLeave] = function()
			o.onMouseLeave()
			p.onMouseLeave()
			y.onMouseLeave()
		end,
		[ad.Event.MouseButton1Click] = function()
			m.OnClick()
		end,
	}, {
		UICorner = av("UICorner", {
			CornerRadius = UDim.new(0, 3),
		}),
		UIStroke = av("UIStroke", {
			Color = p.binding,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		Icon = v and av("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = v,
			ImageColor3 = u,
			Size = UDim2.fromOffset(8, 8),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		}) or av("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = string.upper(string.sub(m.Type.label, 1, 1)),
			TextColor3 = u,
			TextSize = 10,
			FontFace = af.Get("font", "semi_bold"),
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end











local function AssetRow(m)	
local n, o = ar(false)

	local p, q = at(0, al.snap)
	ap(function()
		q.setGoal(		q,n and 1 or 0)
	end, { n })

	local r = au(an.text)
	local s = au(an.title)
	local t = au(ao.fieldBackgroundActive)

	local u = m.Selected or false
	local v = m.SingleSelect or false

	local w, x = at(u and 1 or 0, al.smoothPrecise)
	ap(function()
		x.setGoal(		x,u and 1 or 0)
	end, { u })

	local y	
if m.Source and type(m.Source.GetPreviewImage) == "function" then
		y = m.Source:GetPreviewImage(m.Name)
	end
	local z = y ~= nil and y ~= ""
	local A = z and (h + i) or 0

	local B = #m.AssignmentTypes > 0
	local C = #m.AssignmentTypes
	local D = B and (C * f + math.max(0, C - 1) * g) or 0
	local E = (B and (D + 6) or 0) + A

	local F= {}
	if B then
		for G, H in next, m.AssignmentTypes do
			local I = m.Assignments[H.key] == m.Name
			F[`Assign_{H.key}`] = av(AssignButton, {
				Type = H,
				IsActive = I,
				AssetName = m.Name,
				LayoutOrder = G,
				OnClick = function()
					m.Source:Assign(H.key, not I and m.Name or nil)
				end,
			})
		end
	end

	local G = ad.joinBindings{ p, w }:map(function(G)
		local H = G[1]
		local I = G[2]
		return 1 - math.max(I, H * 0.08)
	end)
	local H = w.map(w,function(H)
		return r.Lerp(r,s, H)
	end)

	return av("TextButton", {
		BackgroundColor3 = t,
		BackgroundTransparency = G,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = UDim2.new(1, 0, 0, e),
		LayoutOrder = m.LayoutOrder,
		[ad.Event.MouseEnter] = function()
			o(true)
		end,
		[ad.Event.MouseLeave] = function()
			o(false)
		end,
		[ad.Event.MouseButton1Click] = function()
			m.Source:Preview(m.Name)
			if v then
				m.Source:Select(m.Name)
			end
		end,
	}, {
		UICorner = av("UICorner", {
			CornerRadius = UDim.new(0, 3),
		}),
		UIPadding = av("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		Thumb = z and av("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = y,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(h, h),
			ZIndex = 2,
		}, {
			UICorner = av("UICorner", {
				CornerRadius = UDim.new(0, 2),
			}),
		}) or nil,
		Label = av("TextLabel", {
			BackgroundTransparency = 1,
			Text = m.Name,
			TextColor3 = H,
			TextSize = 12,
			FontFace = af.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.new(1, -E, 1, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, A, 0.5, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		Assigns = B and av(
			"Frame",
			{
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0, D, 0, f),
			},
			ae.Dictionary.join({
				UIListLayout = av("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, g),
				}),
			}, F)
		) or nil,
	})
end










local function ExtrasGroup(m)	
local n, o = at(0, al.smoothPrecise)
	local p, q = ar(not m.Visible)

	ap(function()
		if m.Visible then
			q(false)
			o.setGoal(			o,1)
			return
		end
		o.setGoal(		o,0)
		local r = task.delay(0.5, function()
			q(true)
		end)
		return function()
			task.cancel(r)
		end
	end, { m.Visible })

	local r, s = ar(0)
	local t = as(nil )

	ap(function()
		local u = t.current
		if not u then
			return
		end
		local function update()			
local v = u.AbsoluteSize.Y
			if v > 0 then
				s(v)
			end
		end
		update()
		local v = u.GetPropertyChangedSignal(u, "AbsoluteSize"):Connect(update)
		return function()
			v.Disconnect(			v)
		end
	end, {})

	local u = n.map(n,function(u)
		return 1 - u
	end)

	local v = n.map(n,function(v)
		return UDim2.new(0, 0, 0, math.floor((1 - v) * -6))
	end)

	local w = n.map(n,function(w)
		return UDim2.new(1, 0, 0, math.max(0, math.floor(w * r)))
	end)

	local x= {
		UIListLayout = av("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		UIPadding = av("UIPadding", {
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2),
			PaddingTop = UDim.new(0, 1),
			PaddingBottom = UDim.new(0, 2),
		}),
		Heading = av("TextLabel", {
			BackgroundTransparency = 1,
			Text = string.upper(m.Label),
			TextColor3 = m.MutedColor,
			TextSize = 10,
			FontFace = af.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 11),
			LayoutOrder = 0,
		}),
	}
	for y, z in next, m.Extras do
		x[`E_{y}`] = z.Render(z,y)
	end

	return av("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = not p,
		Size = w,
		LayoutOrder = m.LayoutOrder,
	}, {
		Inner = av("CanvasGroup", {
			ref = t,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = v,
			GroupTransparency = u,
		}, x),
	})
end

return function(m)	
local n = m.AssetPicker

	local o = au(n._source)
	local p = au(n._title)

	local q = au(an.background)
	local r = au(an.divider)
	local s = au(an.stroke)
	local t = au(an.title)
	local u = au(ag.colors.hud.textMuted)
	local v = au(ao.scrollThumb)

	local w = { o }
	local x = au(o and o._assetNames or k, w)
	local y = au(o and o._state or j, w)

	local z = ai(n, {
		slideOffset = 14,
		floatingId = "subwindow.assetPicker",
		floatingPriority = am.PRIORITY.MENU,
		onClickOutside = function()
			n.Close(			n)
		end,
	})

	local A= o and o._assignmentTypes or l
	local B = false
	if o and type(o.IsSingleSelect) == "function" then
		B = o.IsSingleSelect(o)
	end
	local C	
if B and o then
		C = o.GetSelected(o)
	end

	local D= {}
	if o then
		for E, F in next, A do
			local G = o.GetExtras(o,F.key)
			if not G or #G == 0 then
				continue
			end
			table.insert(D, {
				layoutOrder = E,
				key = F.key,
				label = F.label,
				extras = G,
			})
		end
	end

	local E = false
	for F, G in next, D do
		if y[G.key] then
			E = true
			break
		end
	end

	local F, G = ar(E)

	ap(function()
		if E then
			G(true)
			return
		end
		local H = task.delay(0.5, function()
			G(false)
		end)
		return function()
			task.cancel(H)
		end
	end, { E })

	local H, I = at(E and 1 or 0, al.smoothPrecise)
	ap(function()
		I.setGoal(		I,E and 1 or 0)
	end, { E })

	local J = F or E

	local K= {}
	for L, M in next, x do
		K[`Row_{L}_{M}`] = av(AssetRow, {
			Name = M,
			Source = o,
			AssignmentTypes = A,
			Assignments = y,
			Selected = B and C == M,
			SingleSelect = B,
			LayoutOrder = L,
		})
	end

	local L = math.min(ax, math.max(e * 1, #x * (e + 2)))
	if #x == 0 then
		L = 28
	end

	local M= {}
	for N, O in next, D do
		M[`Group_{O.key}`] = av(ExtrasGroup, {
			GroupKey = O.key,
			Label = O.label,
			Extras = O.extras,
			LayoutOrder = O.layoutOrder,
			MutedColor = u,
			Visible = y[O.key] ~= nil,
		})
	end

	return av("Frame", {
		ref = z.frameRef,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, aw, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = z.position,
		Visible = z.visible,
		ZIndex = z.zIndex,
	}, {
		Shadow = aj{
			transparency = z.transparency,
			zIndex = 0,
		},
		Body = av("CanvasGroup", {
			BackgroundTransparency = 0,
			BackgroundColor3 = q,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			GroupTransparency = z.transparency,
			ZIndex = 1,
		}, {
			UIStroke = av("UIStroke", {
				Color = s,
				Transparency = z.strokeTransparency,
				Thickness = 1,
			}),
			UICorner = av("UICorner", {
				CornerRadius = UDim.new(0, 5),
			}),
			UIPadding = av("UIPadding", {
				PaddingLeft = UDim.new(0, b),
				PaddingRight = UDim.new(0, b),
				PaddingTop = UDim.new(0, b),
				PaddingBottom = UDim.new(0, b),
			}),
			UIListLayout = av("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Title = av("TextLabel", {
				BackgroundTransparency = 1,
				Text = p,
				TextColor3 = t,
				TextSize = 15,
				FontFace = af.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				Size = UDim2.new(1, 0, 0, c),
				LayoutOrder = 0,
			}),
			TitleDivider = av("Frame", {
				BackgroundColor3 = r,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, d),
				LayoutOrder = 1,
			}),
			Empty = #x == 0 and av("TextLabel", {
					BackgroundTransparency = 1,
					Text = "No assets found",
					TextColor3 = u,
					TextSize = 11,
					FontFace = af.Get("font", "semi_bold"),
					Size = UDim2.new(1, 0, 0, 28),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
					LayoutOrder = 2,
				}) or nil,
			List = #x > 0 and av(
					"ScrollingFrame",
					{
						Active = false,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Size = UDim2.new(1, 0, 0, L),
						CanvasSize = UDim2.fromOffset(0, 0),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
						ScrollBarImageColor3 = v,
						ScrollBarImageTransparency = #x * (e + 2) > ax and 0.1 or 1,
						ScrollBarThickness = #x * (e + 2) > ax and 3 or 0,
						LayoutOrder = 2,
					},
					ae.Dictionary.join({
						UIListLayout = av("UIListLayout", {
							FillDirection = Enum.FillDirection.Vertical,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							VerticalAlignment = Enum.VerticalAlignment.Top,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 2),
						}),
						UIPadding = av("UIPadding", {
							PaddingRight = UDim.new(0, 4),
						}),
					}, K)
				) or nil,
			ExtrasDivider = J and av("Frame", {
					BackgroundColor3 = r,
					BackgroundTransparency = H.map(H,function(N)
						return 1 - N
					end),
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, d),
					LayoutOrder = 3,
				}) or nil,
			Extras = J and av(
					"Frame",
					{
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						LayoutOrder = 4,
					},
					ae.Dictionary.join({
						UIListLayout = av("UIListLayout", {
							FillDirection = Enum.FillDirection.Vertical,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							VerticalAlignment = Enum.VerticalAlignment.Top,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 6),
						}),
					}, M)
				) or nil,
		}),
	})
end
end function a.au()
local aa = a.load'm'
local ab = a.load'c'

local ac = a.load'M'
local ad = a.load'at'

local ae = aa.atom
local af = aa.peek
local ag = aa.subscribe
local ah = ab.createElement

local ai = {}
ai.__index = ai

setmetatable(ai, { __index = ac })

local function constructor()	
local aj = (ac.new() )	
setmetatable(aj, ai)

	aj._title = ae""	
aj._source = ae(nil )
	aj._activePreview = ae(nil )

	ag(aj._isOpen, function(ak)		
if ak then
			return
		end

		local al = af(aj._source)
		if al then
			if al.StopPreview then
				al.StopPreview(				al)
			end
			if al._open then
				al._open(false)
			end
		end

		aj._activePreview(nil)
		aj._source(nil )
	end)

	return aj
end

function ai.Open(aj, ak, al)	
local am = af(aj._source)
	if am and am ~= ak and am._open then
		am._open(false)
	end

	if ak._open then
		ak._open(true)
	end

	if ak.Refresh then
		ak.Refresh(		ak)
	end

	aj._source(ak)
	aj._title(af(ak._text) or "Assets")

	aj.SetPosition(
	aj,al or UDim2.fromScale(0.5, 0.5))
	aj.SetOpen(	aj,true)
end

function ai.Close(aj)	aj.SetOpen(	aj,false)
end

function ai.SetActivePreview(aj, ak)	
aj._activePreview(ak)
end

function ai.Render(aj)	
return ah(ad, { AssetPicker = aj })
end











return constructor
end function a.av()
local aa = a.load'm'

local ab = aa.atom















local ac = {
	scopes = ab({} ),
	order = ab({} ),
	values = ab({} ),
	enabled = ab({} ),
	currentScope = ab"global",
	equippedScope = ab"global",
	equipped = ab(nil ),
	autoFollowEquipped = ab(true),
	menuOpen = ab(false),
	menuPosition = ab(UDim2.new(0, 0, 0, 0)),
}



return ac
end function a.aw()
local aa = a.load'm'
local ab = a.load'n'
local ac = a.load'av'
local ad = a.load'E'

local ae = aa.atom
local af = aa.peek
local ag = aa.subscribe











local ah = "global"

local ai = {
	state = ac,
	GLOBAL_ID = ah,
}

local aj= {}
local ak= {}
local al= {}

local function ensureScope(am, an)	
local ao = af(ac.scopes)
	if ao[am] then
		return
	end
	ac.scopes(ab.Dictionary.set(ao, am, an))
	local ap = af(ac.order)
	ac.order(ab.Array.push(ap, am))
end

ensureScope(ah, {
	id = ah,
	parent = nil,
	label = "Global",
	kind = "global",
	layoutOrder = 0,
})

ag(ad.isOpen, function(am)	
if not am or not af(ac.autoFollowEquipped) then
		return
	end
	if af(ac.equipped) == nil then
		return
	end
	local an = af(ac.equippedScope)
	if an == ah then
		return
	end
	if af(ac.enabled)[an] ~= true then
		return
	end
	if af(ac.currentScope) ~= an and af(ac.scopes)[an] then
		ac.currentScope(an)
	end
end)

function ai.RegisterScope(am)	
ensureScope(am.id, am)
	return am
end

function ai.RegisterGroup(am, an, ao)	
return ai.RegisterScope{
		id = `group:{am}`,
		parent = ah,
		label = an,
		kind = "group",
		groupLabel = "Groups",
		layoutOrder = ao,
	}
end

function ai.RegisterWeapon(am, an, ao, ap)	
return ai.RegisterScope{
		id = `weapon:{am}`,
		parent = ao and `group:{ao}` or ah,
		label = an,
		kind = "weapon",
		groupLabel = "Weapons",
		layoutOrder = ap,
	}
end

function ai.GetScope(am)	
return af(ac.scopes)[am]
end

function ai.RemoveScope(am)	
if am == ah then
		return
	end
	local an = af(ac.scopes)
	if not an[am] then
		return
	end
	ac.scopes(ab.Dictionary.removeKey(an, am))
	ac.order(ab.Array.filter(af(ac.order), function(ao)
		return ao ~= am
	end))
	ac.values(ab.Dictionary.removeKey(af(ac.values), am))
	ac.enabled(ab.Dictionary.removeKey(af(ac.enabled), am))
	if af(ac.currentScope) == am then
		ac.currentScope(ah)
	end
end

function ai.GetChildren(am)	
local an= {}
	for ao, ap in next, af(ac.order) do
		local aq = af(ac.scopes)[ap]
		if aq and aq.parent == am then
			an[#an + 1] = aq
		end
	end
	return an
end

local function isScopeBucketActive(am)	
if am == ah then
		return true
	end
	return af(ac.enabled)[am] == true
end

local function resolveAt(am, an)	
local ao = af(ac.scopes)
	local ap = af(ac.values)
	local aq = ak[an] == true

	local ar= aq and ah or am
	while ar do
		if isScopeBucketActive(ar) then
			local as = ap[ar]
			if as and as[an] ~= nil then
				return {
					value = as[an],
					source = ar,
					inherited = ar ~= am,
					exists = true,
				}
			end
		end
		local as = ao[ar]
		ar = as and as.parent or nil
	end

	return {
		value = nil,
		source = ah,
		inherited = am ~= ah,
		exists = false,
	}
end

local function resolveOverrideFromElement(am)	
if not am or type(am.GetEffectiveValue) ~= "function" then
		return nil, false
	end
	if not am.IsOverridden or not am.IsOverridden(am) then
		return nil, false
	end
	return am.GetEffectiveValue(am), true
end

function ai.Resolve(am, an)	
local ao = aj[am]
	if ao then
		local ap, aq = resolveOverrideFromElement(ao.element)
		if aq then
			return {
				value = ap,
				source = ah,
				inherited = false,
				exists = true,
			}
		end
	end
	return resolveAt(an or af(ac.equippedScope), am)
end

function ai.GetResolvedValue(am, an)	
local ao = aj[am]
	if ao then
		local ap, aq = resolveOverrideFromElement(ao.element)
		if aq then
			return ap
		end
	end
	return resolveAt(an or af(ac.equippedScope), am).value
end

function ai.GetResolvedSettings(am)	
local an = am or af(ac.equippedScope)
	local ao = af(ac.scopes)
	local ap = af(ac.values)

	local aq= {}
	local ar= an
	while ar do
		table.insert(aq, 1, ar)
		local as = ao[ar]
		ar = as and as.parent or nil
	end

	local as= {}
	for at, au in next, aq do
		local av = ap[au]
		if av then
			for aw, ax in next, av do
				as[aw] = ax
			end
		end
	end
	return as
end

function ai.HasOverride(am, an)	
local ao = an or af(ac.currentScope)
	local ap = af(ac.values)[ao]
	return ap ~= nil and ap[am] ~= nil
end

function ai.IsScopeEnabled(am)	
if am == ah then
		return true
	end
	return af(ac.enabled)[am] == true
end

function ai.SetScopeEnabled(am, an)	
if am == ah then
		return
	end
	local ao = af(ac.enabled)
	if (ao[am] == true) == an then
		return
	end
	if an then
		ac.enabled(ab.Dictionary.set(ao, am, true))
	else
		ac.enabled(ab.Dictionary.removeKey(ao, am))
	end
end

function ai.ToggleScopeEnabled(am)	
ai.SetScopeEnabled(am, not ai.IsScopeEnabled(am))
end

function ai.SetValue(am, an, ao)	
local ap = ao or af(ac.currentScope)
	local aq = af(ac.values)
	local ar = aq[ap] or {}
	if ar[am] == an then
		return
	end
	local as = ab.Dictionary.set(ar, am, an)
	ac.values(ab.Dictionary.set(aq, ap, as))
end

function ai.ClearValue(am, an)	
local ao = an or af(ac.currentScope)
	local ap = af(ac.values)
	local aq = ap[ao]
	if not aq or aq[am] == nil then
		return
	end
	local ar = ab.Dictionary.removeKey(aq, am)
	if next(ar) == nil then
		ac.values(ab.Dictionary.removeKey(ap, ao))
	else
		ac.values(ab.Dictionary.set(ap, ao, ar))
	end
end

function ai.SetCurrentScope(am)	
if not af(ac.scopes)[am] then
		return
	end
	if af(ac.currentScope) == am then
		return
	end
	ac.currentScope(am)
end

function ai.GetCurrentScope()	
return af(ac.currentScope)
end

function ai.RegisterScopeResolver(am)	
table.insert(al, am)
	return function()
		local an = table.find(al, am)
		if an then
			table.remove(al, an)
		end
	end
end

function ai.GetResolvedScope(am)	
local an = am ~= nil and am or af(ac.equipped)

	for ao, ap in next, al do
		local aq = ap(an)
		if aq and af(ac.scopes)[aq] then
			return aq
		end
	end

	if an then
		local ao = `weapon:{an.lower(an)}`
		local ap = af(ac.scopes)
		if ap[ao] then
			local aq = af(ac.enabled)
			if aq[ao] then
				return ao
			end
			local ar = ap[ao].parent
			while ar and ar ~= ah do
				if aq[ar] then
					return ar
				end
				local as = ap[ar]
				ar = as and as.parent or nil
			end
		end
	end

	return ah
end

function ai.SetEquipped(am)	
if af(ac.equipped) ~= am then
		ac.equipped(am)
	end
	local an = ai.GetResolvedScope(am)
	if af(ac.equippedScope) ~= an then
		ac.equippedScope(an)
	end
	if af(ac.autoFollowEquipped) and af(ad.isOpen) then
		ai.SetCurrentScope(an)
	end
end

function ai.SetAutoFollow(am)	
ac.autoFollowEquipped(am)
	if am then
		ai.SetCurrentScope(ai.GetResolvedScope(af(ac.equipped)))
	end
end





function ai.BindElement(am, an, ao)	
if aj[an] then
		ai.UnbindElement(an)
	end

	local ap = ao ~= nil and ao.globalOnly == true
	if ap then
		ak[an] = true
	else
		ak[an] = nil
	end

	local aq = false

	if am._scopeIsInherited == nil then
		am._scopeIsInherited = ae(false)
	end
	if am._scopeSource == nil then
		am._scopeSource = ae(ah)
	end
	if am._scopeKey == nil then
		am._scopeKey = ae(an )
	else
		am._scopeKey(an)
	end

	if not ai.HasOverride(an, ah) then
		ai.SetValue(an, af(am._state), ah)
	end

	local function pushFromStore()		
local ar = resolveAt(af(ac.currentScope), an)
		aq = true
		if ar.exists then
			am._state(ar.value)
		end
		am._scopeSource(ar.source)
		am._scopeIsInherited(ar.inherited)
		aq = false
	end

	local ar= {}

	table.insert(
		ar,
		ag(am._state, function(as)			
if aq then
				return
			end
			local at = ap and ah or af(ac.currentScope)
			ai.SetValue(an, as, at)
		end)
	)

	table.insert(ar, ag(ac.currentScope, pushFromStore))
	table.insert(ar, ag(ac.values, pushFromStore))
	table.insert(ar, ag(ac.enabled, pushFromStore))

	pushFromStore()

	aj[an] = { element = am, unsubs = ar }

	return function()
		ai.UnbindElement(an)
	end
end

function ai.UnbindElement(am)	
local an = aj[am]
	if not an then
		return
	end
	for ao, ap in next, an.unsubs do
		ap()
	end
	aj[am] = nil
	ak[am] = nil
end

function ai.IsBound(am)	
return aj[am] ~= nil
end

function ai.RevertOverride(am, an)	
ai.ClearValue(am, an)
end

function ai.ListScopesGrouped()	
local am = af(ac.order)
	local an = af(ac.scopes)

	local ao= {}
	local ap= {}
	local aq= {}

	for ar, as in next, am do
		local at = an[as]
		if not at then
			continue
		end
		local au = at.groupLabel
		local av = au or "__root__"
		if not ap[av] then
			ap[av] = true
			ao[#ao + 1] = au
		end
		local aw = aq[av] or {}
		aw[#aw + 1] = at
		aq[av] = aw
	end

	local ar= {}
	for as, at in next, ao do
		local au = at or "__root__"
		ar[#ar + 1] = { groupLabel = at, scopes = aq[au] }
	end
	return ar
end

local am = {}
am.__index = function(an, ao)	
local ap = rawget(an, "_prefix")
	local aq = ap == "" and ao or ap .. "." .. ao
	return ai.GetResolvedValue(aq)
end



function ai.Settings(an)	
return (setmetatable({ _prefix = an or "" }, am) )
end

local function buildSnapshot(an)	
local ao = an == "" and "" or an .. "."
	local ap = #ao
	local aq= {}
	for ar in next, aj do
		if ap == 0 or string.sub(ar, 1, ap) == ao then
			local as = ap == 0 and ar or string.sub(ar, ap + 1)
			aq[as] = ai.GetResolvedValue(ar)
		end
	end
	return aq
end

function ai.Snapshot(an)	
return buildSnapshot(an or "")
end

function ai.Watch(an, ao)	
local function refresh()		
ao(buildSnapshot(an))
	end

	refresh()

	local ap= {
		ag(ac.values, refresh),
		ag(ac.equippedScope, refresh),
		ag(ac.enabled, refresh),
	}

	return function()
		for aq, ar in next, ap do
			ar()
		end
	end
end

function ai.OnChange(an, ao)	
local ap = ai.GetResolvedValue(an)
	ao(ap)

	local function refresh()		
local aq = ai.GetResolvedValue(an)
		if aq == ap then
			return
		end
		ap = aq
		ao(aq)
	end

	local aq= {
		ag(ac.values, refresh),
		ag(ac.equippedScope, refresh),
		ag(ac.enabled, refresh),
	}

	local ar = aj[an]
	if ar and ar.element and ar.element._overrides then
		table.insert(aq, ag(ar.element._overrides, refresh))
	end

	return function()
		for as, at in next, aq do
			at()
		end
	end
end

function ai.new()	
return ai
end

function ai.Destroy()	
for an in next, aj do
		ai.UnbindElement(an)
	end
	ak = {}
	al = {}
end



return ai
end function a.ax()
local aa = a.load'e'
local ab = a.load'd'
local ac = a.load'c'
local ad = a.load'n'

local ae = a.load'N'
local af = a.load's'
local ag = a.load'aw'
local ah = a.load'av'
local ai = a.load'T'
local aj = a.load'O'

local ak = aa.useSpring
local al = ac.useEffect
local am = ac.useMemo
local an = ac.useState
local ao = ab.useAtom
local ap = ac.createElement

local aq = ae.colors.subwindow
local ar = ae.colors.window.element

local as = 24
local at = 22
local au = 6
local av = 6
local aw = 188
local ax = 210
local b = "__root__"

local function GroupLabel(c)	
local d = ao(ar.caption)
	return ap("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, at),
		LayoutOrder = c.LayoutOrder,
	}, {
		UIPadding = ap("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 2),
		}),
		Text = ap("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Text = string.upper(c.Label),
			TextColor3 = d,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			FontFace = af.Get("font", "semi_bold"),
		}),
	})
end

local function ScopeRow(c





)	
local d, e = an(false)
	local f = ao(aq.text)
	local g = ao(aq.title)
	local h = ao(ar.thumbActive)

	local i, j = ak(0, aj.snap)
	local k, l = ak(0, aj.smooth)

	al(function()
		j.setGoal(		j,d and 1 or 0)
	end, { d })

	al(function()
		l.setGoal(		l,c.IsActive and 1 or 0)
	end, { c.IsActive })

	return ap("TextButton", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = ac.joinBindings{ i, k }:map(function(m)
			local n = m[1]
			local o = m[2]
			return 1 - (n * 0.04 + o * 0.035)
		end),
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, as),
		LayoutOrder = c.LayoutOrder,
		[ac.Event.MouseEnter] = function()
			e(true)
		end,
		[ac.Event.MouseLeave] = function()
			e(false)
		end,
		[ac.Event.MouseButton1Click] = function()
			c.OnSelect()
		end,
	}, {
		UICorner = ap("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		ActiveBar = ap("Frame", {
			BackgroundColor3 = h,
			BackgroundTransparency = k.map(k,function(m)
				return 1 - m
			end),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.fromOffset(2, 12),
			ZIndex = 2,
		}, {
			UICorner = ap("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
		UIPadding = ap("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 10),
		}),
		UIListLayout = ap("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = ap("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Text = c.Label,
			TextColor3 = k.map(k,function(m)
				return f.Lerp(f,g, m)
			end),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			FontFace = af.Get("font", "semi_bold"),
			LayoutOrder = 1,
		}, {
			UIFlexItem = ap("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
				ItemLineAlignment = Enum.ItemLineAlignment.Stretch,
			}),
		}),
		Check = c.IsActive and ap("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(9, 9),
			Image = af.Get("image", "checkmark"),
			ImageColor3 = h,
			LayoutOrder = 2,
		}) or nil,
	})
end

local function buildLayout(
	c,
	d
)	




local e= {}
	local f= {}
	local g= {}
	local h = 0

	for i, j in next, d do
		local k = c[j]
		if not k then
			continue
		end
		local l = k.groupLabel or b
		if not f[l] then
			f[l] = true
			e[#e + 1] = l
			if k.groupLabel then
				h += 1
			end
		end
		local m = g[l] or {}
		m[#m + 1] = k
		g[l] = m
	end

	return {
		groupOrder = e,
		buckets = g,
		visibleGroupCount = h,
	}
end

return function(c)	
local d = c.ScopeMenu

	local e = ao(aq.background)
	local f = ao(aq.stroke)

	local g = ao(ah.scopes)
	local h = ao(ah.order)
	local i = ao(ah.currentScope)

	local j = ai(d, {
		preset = aj.snap,
		slideOffset = 6,
		strokeIntensity = 0.6,
		floatingId = "subwindow.scopeMenu",
		onClickOutside = function()
			if d.WasJustClosed(d) then
				return
			end
			d.Close(			d)
		end,
	})

	local k = am(function()
		return buildLayout(g, h)
	end, { g, h } )

	local l = am(function()		
local l= {}
		local m = 1

		for n, o in next, k.groupOrder do
			if o ~= b then
				l[#l + 1] = ap(GroupLabel, {
					Label = o,
					LayoutOrder = m,
					key = `group_{o}`,
				})
				m += 1
			end
			for p, q in next, k.buckets[o] do
				l[#l + 1] = ap(ScopeRow, {
					Label = q.label,
					ScopeId = q.id,
					IsActive = i == q.id,
					LayoutOrder = m,
					key = `scope_{q.id}`,
					OnSelect = function()
						ag.SetCurrentScope(q.id)
						d.Close(						d)
					end,
				})
				m += 1
			end
		end

		return l
	end, { k, i } )

	local m= {}
	for n, o in next, l do
		m[`Row_{n}`] = o
	end

	local n = 0
	for o, p in next, k.buckets do
		n += #p
	end
	local o = n * as + k.visibleGroupCount * at + av * 2
	local p = math.min(o, ax)
	local q = o > ax
	local r = ao(ar.scrollThumb)

	return ap("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(aw, p),
		Position = j.position,
		Visible = j.visible,
		ZIndex = j.zIndex,
	}, {
		Body = ap("CanvasGroup", {
			ref = j.frameRef,
			BackgroundTransparency = 0,
			BackgroundColor3 = e,
			Size = UDim2.fromScale(1, 1),
			GroupTransparency = j.transparency,
			ZIndex = 1,
		}, {
			UIStroke = ap("UIStroke", {
				Color = f,
				Transparency = j.strokeTransparency,
				Thickness = 1,
			}),
			UICorner = ap("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			Items = ap(
				"ScrollingFrame",
				{
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollingEnabled = q,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					VerticalScrollBarInset = Enum.ScrollBarInset.None,
					ScrollBarThickness = q and 3 or 0,
					ScrollBarImageColor3 = r,
					ScrollBarImageTransparency = 0.2,
					Active = false,
					ZIndex = 1,
				},
				ad.Dictionary.join({
					UIPadding = ap("UIPadding", {
						PaddingTop = UDim.new(0, av),
						PaddingBottom = UDim.new(0, av),
						PaddingLeft = UDim.new(0, au),
						PaddingRight = UDim.new(0, au),
					}),
					UIListLayout = ap("UIListLayout", {
						VerticalAlignment = Enum.VerticalAlignment.Top,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 1),
					}),
				}, m)
			),
		}),
	})
end
end function a.ay()
local aa = a.load'm'
local ab = a.load'c'

local ac = a.load'M'
local ad = a.load'av'
local ae = a.load'ax'

local af = aa.atom
local ag = aa.subscribe
local ah = ab.createElement

local ai = {}
ai.__index = ai

setmetatable(ai, { __index = ac })



local function constructor()	
local aj = (ac.new() )	
setmetatable(aj, ai)

	aj._onManage = af(nil )
	aj._anchorRef = af(nil )
	aj._lastClosedAt = 0

	ag(aj._isOpen, function(ak)		
ad.menuOpen(ak)
	end)

	return aj
end

function ai.Open(aj, ak, al)	
aj._anchorRef(al)
	aj.SetPosition(	aj,ak or UDim2.new(0, 0, 0, 0))
	aj.SetOpen(	aj,true)
end

function ai.Close(aj)	
aj._lastClosedAt = os.clock()
	aj.SetOpen(	aj,false)
end

function ai.WasJustClosed(aj)	
return os.clock() - aj._lastClosedAt < 0.1
end

function ai.SetOnManage(aj, ak)	
aj._onManage(ak)
end

function ai.Render(aj)	
return ah(ae, {
		ScopeMenu = aj,
	})
end











return constructor
end function a.az()
local aa = a.load'm'
local ab = a.load'd'
local ac = a.load'e'
local ad = a.load'c'

local ae = a.load'N'
local af = a.load's'
local ag = a.load'ab'
local ah = a.load'T'
local ai = a.load'U'
local aj = a.load'al'
local ak = a.load'O'
local al = a.load'S'

local am = ae.colors.subwindow
local an = ae.colors.window.element

local ao = ad.useEffect
local ap = ad.useMemo
local aq = ad.useState
local ar = ac.useSpring
local as = ab.useAtom
local at = ad.createElement

local au = 320
local av = 176
local aw = 12
local ax = 18
local b = 14
local c = 24
local d = 1
local e = 80








local function FooterButton(f)	
local g = ap(function()
		return aa.atom(f.Variant == "primary")
	end, {})

	local h = ag(an.surface, an.accentStrong, g, true)
	local i = as(an.surfaceStroke)
	local j = ag(an.text, an.textActive, g)

	local k, l = aq(false)
local m, n =ar(0, ak.smooth)
	ao(function()
		n.setGoal(		n,k and 1 or 0)
	end, { k })

	return at("TextButton", {
		BackgroundColor3 = h.binding,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = UDim2.new(0, 72, 0, c),
		LayoutOrder = f.LayoutOrder,
		[ad.Event.MouseEnter] = function()
			h.onMouseEnter()
			j.onMouseEnter()
		end,
		[ad.Event.MouseLeave] = function()
			l(false)
			h.onMouseLeave()
			j.onMouseLeave()
		end,
		[ad.Event.MouseButton1Down] = function()
			l(true)
		end,
		[ad.Event.MouseButton1Up] = function()
			l(false)
		end,
		[ad.Event.MouseButton1Click] = function()
			f.OnClick()
		end,
	}, {
		UICorner = at("UICorner", {
			CornerRadius = UDim.new(0, 5),
		}),
		UIStroke = at("UIStroke", {
			Color = i,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		Label = at("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = f.Text,
			TextColor3 = j.binding,
			TextSize = 12,
			FontFace = af.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

return function(f)	
local g = f.Editor

	local h = as(g._title)
	local i = as(g._subtitle)
	local j = as(g._note)
	local k = as(g._notePlaceholder)

	local l = as(am.background)
	local m = as(am.divider)
	local n = as(am.stroke)
	local o = as(am.title)
	local p = as(an.caption)
	local q = as(an.caption)
	local r = as(an.fieldBackground)
	local s = as(an.fieldStroke)
	local t = as(am.text)

	local u = ah(g, {
		slideOffset = 18,
		floatingId = "subwindow.recordEditor",
		floatingPriority = al.PRIORITY.MODAL,
	})

	local v = aj(g._position)

	return at("Frame", {
		ref = u.frameRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(au, av),
		Position = u.position,
		Visible = u.visible,
		ZIndex = u.zIndex,
	}, {
		Shadow = ai{
			transparency = u.transparency,
			zIndex = 0,
		},
		UIStroke = at("UIStroke", {
			Color = n,
			Transparency = u.strokeTransparency,
			Thickness = 1,
		}),
		UICorner = at("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		Inner = at("CanvasGroup", {
			BackgroundTransparency = 0,
			BackgroundColor3 = l,
			Size = UDim2.fromScale(1, 1),
			GroupTransparency = u.transparency,
			ZIndex = 1,
		}, {
			UICorner = at("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			UIPadding = at("UIPadding", {
				PaddingLeft = UDim.new(0, 1),
				PaddingRight = UDim.new(0, 1),
				PaddingTop = UDim.new(0, 1),
				PaddingBottom = UDim.new(0, 1),
			}),
			Title = at("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(aw, aw),
				Size = UDim2.new(1, -aw * 2, 0, ax),
				Text = h,
				TextColor3 = o,
				TextSize = 14,
				FontFace = af.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Subtitle = at("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(aw, aw + ax),
				Size = UDim2.new(1, -aw * 2, 0, b),
				Text = i,
				TextColor3 = p,
				TextSize = 11,
				FontFace = af.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			TitleDivider = at("Frame", {
				BackgroundColor3 = m,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(aw, aw + ax + b + 4),
				Size = UDim2.new(1, -aw * 2, 0, d),
			}),
			TitleDragStrip = at("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(aw, aw),
				Size = UDim2.new(1, -aw * 2, 0, ax + b + 4),
				ZIndex = 5,
				Active = true,
				[ad.Event.InputBegan] = function(w, x)
					v(x)
				end,
			}),
			NoteFrame = at("Frame", {
				BackgroundColor3 = r,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(aw, aw + ax + b + 12),
				Size = UDim2.new(1, -aw * 2, 0, e),
			}, {
				UICorner = at("UICorner", {
					CornerRadius = UDim.new(0, 4),
				}),
				UIStroke = at("UIStroke", {
					Color = s,
					Thickness = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				UIPadding = at("UIPadding", {
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				}),
				Input = at("TextBox", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClearTextOnFocus = false,
					MultiLine = true,
					TextWrapped = true,
					PlaceholderText = k,
					PlaceholderColor3 = q,
					Text = j,
					TextColor3 = t,
					TextSize = 12,
					FontFace = af.Get("font", "semi_bold"),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Size = UDim2.fromScale(1, 1),
					[ad.Change.Text] = function(w)
						g.SetNote(						g,w.Text)
					end,
				}),
			}),
			Footer = at("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, aw, 1, -aw + 6),
				Size = UDim2.new(1, -aw * 2, 0, c),
			}, {
				UIListLayout = at("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				Cancel = at(FooterButton, {
					Text = "Cancel",
					Variant = "secondary",
					LayoutOrder = 1,
					OnClick = function()
						g.Cancel(						g)
					end,
				}),
				Save = at(FooterButton, {
					Text = "Save",
					Variant = "primary",
					LayoutOrder = 2,
					OnClick = function()
						g.Save(						g)
					end,
				}),
			}),
		}),
	})
end
end function a.aA()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'M'
local ad = a.load'az'

local ae = aa.atom
local af = aa.peek
local ag = ab.createElement

local ah = {}
ah.__index = ah

setmetatable(ah, { __index = ac })











local function constructor()	
local ai = (ac.new() )	
setmetatable(ai, ah)

	ai._title = ae""	
ai._subtitle = ae""	
ai._note = ae""	
ai._notePlaceholder = ae"Add a note..."
	
ai._onSave = nil 	
ai._onCancel = nil 
	
return ai
end

function ah.SetNote(ai, aj)	
ai._note(aj or "")
end

function ah.GetNote(ai)	
return af(ai._note)
end

function ah.Open(ai, aj)	
ai._title(aj.title)
	ai._subtitle(aj.subtitle or "")
	ai._note(aj.noteValue or "")
	ai._notePlaceholder(aj.notePlaceholder or "Add a note...")

	ai._onSave = aj.onSave
	ai._onCancel = aj.onCancel

	ai.SetPosition(
	ai,aj.position or UDim2.fromScale(0.5, 0.5))
	ai.SetOpen(	ai,true)
end

function ah.Save(ai)	local aj = ai._onSave
	local ak = af(ai._note)
	ai._onSave = nil
	ai._onCancel = nil
	ai.SetOpen(	ai,false)
	if aj then
		aj(ak)
	end
end

function ah.Cancel(ai)	
local aj = ai._onCancel
	ai._onSave = nil
	ai._onCancel = nil
	ai.SetOpen(	ai,false)
	if aj then
		aj()
	end
end

function ah.Render(ai)	
return ag(ad, { Editor = ai })
end













return constructor
end function a.aB()
local aa = a.load'm'

local ab = aa.peek
local ac = aa.atom

local ad = ac(UDim2.fromScale(0.5, 0.5))

local ae = {}

function ae.syncMenuPosition(af)	
ad(af)
end

function ae.menuCenter()	
return ab(ad)
end

return ae
end function a.aC()
local aa = a.load'c'
local ab = a.load'e'
local ac = a.load'd'
local ad = a.load'm'

local ae = a.load's'
local af = a.load'N'
local ag = a.load'ab'
local ah = a.load'T'
local ai = a.load'U'
local aj = a.load'al'
local ak = a.load'O'
local al = a.load'S'

local am = aa.useEffect
local an = aa.useMemo
local ao = aa.useState
local ap = aa.useCallback
local aq = ab.useSpring
local ar = ac.useAtom
local as = aa.createElement

local at = af.colors.subwindow
local au = af.colors.window.element
local av = af.colors.inventory

local aw = 360
local ax = 303
local b = 11
local c = 18
local d = 1
local e = 118
local f = 6
local g = 25








local function FooterButton(h)	
local i, j = ao(false)
	local k, l = ao(false)

	local m = an(function()
		return ad.atom(h.Variant == "primary")
	end, {})

	am(function()
		if h.Variant == "primary" then
			m(true)
		else
			m(i or k)
		end
	end, { i, k, h.Variant })

	local n = ag(au.surface, au.accentStrong, m, true)
	local o = ar(au.surfaceStroke)
	local p = ag(au.text, au.textActive, m)

	local q, r = aq(0, ak.quick)
	am(function()
		r.setGoal(		r,k and 1 or 0)
	end, { k })

	local s = an(function()
		return q.map(q,function(s)
			return 1 - s * 0.04
		end)
	end, { q } )

	return as("TextButton", {
		BackgroundColor3 = n.binding,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = UDim2.fromOffset(96, 24),
		LayoutOrder = h.LayoutOrder,
		[aa.Event.MouseEnter] = function()
			j(true)
			if h.Variant ~= "primary" then
				n.onMouseEnter()
				p.onMouseEnter()
			end
		end,
		[aa.Event.MouseLeave] = function()
			j(false)
			l(false)
			if h.Variant ~= "primary" then
				n.onMouseLeave()
				p.onMouseLeave()
			end
		end,
		[aa.Event.MouseButton1Down] = function()
			l(true)
		end,
		[aa.Event.MouseButton1Up] = function()
			l(false)
		end,
		[aa.Event.MouseButton1Click] = function()
			h.OnClick()
		end,
	}, {
		UICorner = as("UICorner", {
			CornerRadius = UDim.new(0, 5),
		}),
		UIStroke = as("UIStroke", {
			Color = o,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UIScale = as("UIScale", {
			Scale = s,
		}),
		Label = as("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = h.Text,
			TextColor3 = p.binding,
			TextSize = 12,
			FontFace = ae.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

return function(h)	
local i = h.SkinConfig

	local j = ar(i._weapon)
	local k = ar(i._skin)
	local l = ar(i._rarity)
	local m = ar(i._icon)

	local n = ar(at.background)
	local o = ar(at.divider)
	local p = ar(at.stroke)
	local q = ar(at.title)
	local r = ar(av.cardImageBg)

	local s = (av.rarity[l] or av.rarity.common) 	
local t = ar(s)

	local u = ah(i, {
		slideOffset = 18,
		floatingId = "subwindow.skinConfig",
		floatingPriority = al.PRIORITY.MODAL,
	})

	local v = aj(i._position)

	local w = ap(function()
		i.Cancel(		i)
	end, { i } )

	local x = ap(function()
		i.Submit(		i,i.BuildPayload(i))
	end, { i } )

	local y = an(function()
		return i._floatEl:Render(0)
	end, { i._floatEl } )

	local z = an(function()
		return i._seedEl:Render(1)
	end, { i._seedEl } )

	local A = an(function()
		return i._nameTagEl:Render(2)
	end, { i._nameTagEl } )

	local B = an(function()
		return i._statTrackEl:Render(3)
	end, { i._statTrackEl } )

	return as("Frame", {
		ref = u.frameRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(aw, ax),
		Position = u.position,
		Visible = u.visible,
		ZIndex = u.zIndex,
	}, {
		Shadow = ai{
			transparency = u.transparency,
			zIndex = 0,
		},
		UIStroke = as("UIStroke", {
			Color = p,
			Transparency = u.strokeTransparency,
			Thickness = 1,
		}),
		UICorner = as("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		Inner = as("CanvasGroup", {
			BackgroundTransparency = 0,
			BackgroundColor3 = n,
			Size = UDim2.fromScale(1, 1),
			GroupTransparency = u.transparency,
			ZIndex = 1,
		}, {
			UICorner = as("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			Title = as("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(b, b),
				Size = UDim2.new(1, -b * 2, 0, c),
				Text = `{j}  /  {k}`,
				TextColor3 = q,
				TextSize = 14,
				FontFace = ae.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			TitleDivider = as("Frame", {
				BackgroundColor3 = o,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(b, b + c + 4),
				Size = UDim2.new(1, -b * 2, 0, d),
			}),
			TitleDragStrip = as("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(b, b),
				Size = UDim2.new(1, -b * 2, 0, c + 4 + d),
				ZIndex = 5,
				Active = true,
				[aa.Event.InputBegan] = function(C, D)
					v(D)
				end,
			}),
			Preview = as("Frame", {
				BackgroundColor3 = r,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(b, b + c + 4 + d + 8),
				Size = UDim2.new(1, -b * 2, 0, e),
				ClipsDescendants = true,
			}, {
				UICorner = as("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
				UIStroke = as("UIStroke", {
					Color = p,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = 1,
				}),
				RarityAccent = as("Frame", {
					BackgroundColor3 = t,
					BackgroundTransparency = 0.85,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
				}, {
					UIGradient = as("UIGradient", {
						Color = ColorSequence.new(t),
						Transparency = NumberSequence.new{
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(1, 0.55),
						},
						Rotation = 90,
					}),
				}),
				Icon = as("ImageLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(0.78, 0, 0.78, 0),
					Image = m or "",
					ScaleType = Enum.ScaleType.Fit,
				}),
				RarityBar = as("Frame", {
					BackgroundColor3 = t,
					BackgroundTransparency = 0.25,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 2),
				}),
			}),
			Form = as("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, b, 1, -(11 + g + 10 + d + 11)),
				Size = UDim2.new(1, -b * 2, 0, 56+ 3 * f),
			}, {
				UIListLayout = as("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, f),
				}),
				Float = y,
				Seed = z,
				Nametag = A,
				StatTrak = B,
			}),
			FooterDivider = as("Frame", {
				BackgroundColor3 = o,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, b, 1, -(10 + g + 10)),
				Size = UDim2.new(1, -b * 2, 0, d),
			}),
			Footer = as("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, b, 1, -11),
				Size = UDim2.new(1, -b * 2, 0, g),
			}, {
				UIListLayout = as("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				Cancel = as(FooterButton, {
					Text = "Cancel",
					Variant = "secondary",
					LayoutOrder = 0,
					OnClick = w,
				}),
				Add = as(FooterButton, {
					Text = "Add To Inventory",
					Variant = "primary",
					LayoutOrder = 1,
					OnClick = x,
				}),
			}),
		}),
	})
end
end function a.aD()
local aa = {
	_openBindEditor = nil ,
	_openContext = nil ,
}

function aa.SetHandlers(
	ab,
	ac
)	
aa._openBindEditor = ab
	aa._openContext = ac
end

function aa.OpenBindEditor(ab, ac)	
if aa._openBindEditor then
		aa._openBindEditor(ab, ac)
	end
end

function aa.OpenContext(ab, ac)	
if aa._openContext then
		aa._openContext(ab, ac)
	end
end

return aa
end function a.aE()
local aa = (cloneref(game.GetService(game, "UserInputService")) )
local ab = (cloneref(game.GetService(game, "GuiService")) )







local ac= {}
local ad

local function ensureListener()	
if ad then
		return
	end
	ad = aa.InputBegan:Connect(LPH_NO_VIRTUALIZE(function(ae)
		if ae.UserInputType ~= Enum.UserInputType.MouseButton2 then
			return
		end
		if next(ac) == nil then
			return
		end

		local af = aa.GetMouseLocation(aa) - Vector2.new(0, (ab.GetGuiInset(ab).Y ))
		local ag = af.X
		local ah = af.Y

		for ai in next, ac do
			local aj = ai.frameRef.current
			if not aj then
				continue
			end

			local ak = aj.AbsoluteSize
			if ak.X <= 0 or ak.Y <= 0 then
				continue
			end

			local al = aj.AbsolutePosition
			if ag < al.X or ag > al.X + ak.X then
				continue
			end
			if ah < al.Y or ah > al.Y + ak.Y then
				continue
			end

			local am= aj
			local an = true
			while am and am.IsA(am, "GuiObject")do
				if not am.Visible then
					an = false
					break
				end
				am = am.Parent
			end
			if not an then
				continue
			end

			local ao = false
			for ap, aq in next, aj.GetDescendants(aj) do
				if aq.ClassName ~= "GuiObject" then
					continue
				end
				if not aq.GetAttribute(aq, "ConsumesRightClick")then
					continue
				end
				local ar = aq.AbsolutePosition
				local as = aq.AbsoluteSize
				if
					ag >= ar.X
					and ag <= ar.X + as.X
					and ah >= ar.Y
					and ah <= ar.Y + as.Y
				then
					ao = true
					break
				end
			end
			if ao then
				continue
			end

			ai.handler(af)
		end
	end))
end

local function register(ae, af)	
local ag= { frameRef = ae, handler = af }
	ac[ag] = true
	ensureListener()
	return function()
		ac[ag] = nil
	end
end

return {
	register = register,
}
end function a.aF()
local aa = a.load'd'
local ab = a.load'e'
local ac = a.load'c'
local ad = a.load'n'
local ae = a.load's'
local af = a.load'N'
local ag = a.load'aD'
local ah = a.load'Y'
local ai = a.load'J'
local aj = a.load'Z'
local ak = a.load'p'
local al = a.load'O'

local am = a.load'L'
local an = a.load'aE'

local ao = a.load'ab'
local ap = a.load'as'
local aq = aa.useAtom
local ar = ac.useEffect
local as = ac.useMemo
local at = ac.useRef
local au = ac.useState
local av = ab.useSpring
local aw = ac.createElement

local ax = af.colors.window.element

local b = 1
local c = 100






return function(d)	
local e = d.Element

	local f = ao(ax.text, ax.textActive, e._active)
	local g = aq(e._text)
	local h = aq(e._extras)
	local i = aq(e._bindable)
	local j = aq(ai.developerMode)
	local k = aq(e._tip)
	local l = aq(e._visible)
	local m = aq(e._overrides)
	local n = aq(ax.accent)
	local o = at(nil)
	local p = at(nil )
	local q = at(nil )

	local r = m ~= nil and next(m) ~= nil
	local s = as(function()
		if not r or not m then
			return nil
		end
		local s= {}
		local t= {}
		for u, v in next, m do
			local w = v.source
			if type(w) == "string" and w ~= "" and not s[w] then
				s[w] = true
				t[#t + 1] = w
			end
		end
		local u		
local v		
if #t == 0 then
			u = "A script"
			v = false
		elseif #t == 1 then
			u = t[1]
			v = false
		elseif #t == 2 then
			u = `{t[1]} and {t[2]}`
			v = true
		else
			local w = table.concat(t, ", ", 1, #t - 1)
			u = `{w}, and {t[#t]}`
			v = true
		end
		return `{u} {if v then "are" else "is"} overriding this value.`
	end, { r, m } )

	local t = ap(s, q)

	local u, v = au(false)
	local w, x = av(0, al.subtle)

	ar(function()
		x.setGoal(		x,u and 1 or 0)
	end, { u })

	local y = as(function()
		return w.map(w,function(y)
			local z = 10 + y * 2
			return UDim2.fromOffset(z, z)
		end)
	end, { w } )

	local z = as(function()
		return w.map(w,function(z)
			return 0.25 - z * 0.25
		end)
	end, { w } )

	local A = as(function()
		return {
			onMouseEnter = function(A)
				v(true)
				t.onMouseEnter(A)
			end,
			onMouseLeave = function(A)
				v(false)
				t.onMouseLeave(A)
			end,
		}
	end, { t } )

	local B = ap(k, p)

	local C = at(e)
	C.current = e
	local D = at(i)
	D.current = i
	local E = at(j)
	E.current = j

	ar(function()
		local F = an.register(p, function()
			local F = C.current
			local G = D.current
			local H = E.current

			if not G and not H then
				return
			end

			if not H then
				ag.OpenBindEditor(F, ah.getPosition())
				return
			end

			local I			
for J, K in next, aj.elements do
				if K == F then
					I = J
					break
				end
			end

			local J= {}

			if I then
				table.insert(J, {
					Label = "Copy ID",
					Icon = ae.Get("image", "pencil"),
					Callback = function()						
if setclipboard then
							setclipboard(I)
						end
						ak.Push{
							title = "Copied Id",
							subtext = `Copied {I} to clipboard`,
							duration = 2,
						}					
end,
				})
			elseif G then
				ag.OpenBindEditor(F, ah.getPosition())
				return
			end

			if G then
				table.insert(J, { Divider = true })
				table.insert(J, {
					Label = am.HasBindFor(F) and "Edit Bind(s)..." or "Bind...",
					Icon = ae.Get("image", "keybinds"),
					Callback = function()						
ag.OpenBindEditor(F, ah.getPosition())
					end,
				})
			end

			ag.OpenContext(J, ah.getPosition())
		end)

		return F
	end, {})

	local F = as(function()
		return e.RenderInternal(e, { textRef = o, layoutOrder = c })	
end, { e })

	local G = as(function()
		local G = {}
		for H, I in h do
			G["Extra_" .. H] = I.RenderInternal(I, {
				layoutOrder = b + H - 1,
			})		
end
		return G
	end, { h })

	return aw(
		"Frame",
		{
			ref = p,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 14),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = l,
			LayoutOrder = d.LayoutOrder,
			[ac.Event.MouseEnter] = B.onMouseEnter,
			[ac.Event.MouseLeave] = B.onMouseLeave,
		},
		ad.Dictionary.join({
			UIListLayout = aw("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 7),
			}),
			Text = aw("TextButton", {
				ref = o,
				BackgroundTransparency = 1,
				FontFace = ae.Get("font", "semi_bold"),
				TextColor3 = f.binding,
				TextSize = 13,
				Text = g,
				Size = UDim2.new(0, 0, 0, 14),
				LayoutOrder = 0,
				AutoButtonColor = false,
				Active = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				AutomaticSize = Enum.AutomaticSize.X,
			}, {
				UIPadding = aw("UIPadding", {
					PaddingBottom = UDim.new(0, 2),
				}),
				UIFlexItem = aw("UIFlexItem", {
					FlexMode = Enum.UIFlexMode.Fill,
					ItemLineAlignment = Enum.ItemLineAlignment.Automatic,
				}),
			}),
			OverrideIndicator = if r
				then aw("Frame", {
					ref = q,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(10, 10),
					LayoutOrder = c - 1,
					[ac.Event.MouseEnter] = A.onMouseEnter,
					[ac.Event.MouseLeave] = A.onMouseLeave,
				}, {
					Icon = aw("ImageLabel", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Image = ae.Get("image", "bolt") or "",
						ImageColor3 = n,
						ImageTransparency = z,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = y,
					}),
				})
				else nil,
			Element = F,
		}, G)
	)
end
end function a.aG()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'n'
local ad = a.load'aF'
local ae = a.load'L'

local af = aa.atom
local ag = aa.peek
local ah = aa.subscribe
local ai = ab.createElement







local aj = 0
local function nextOverrideToken()	
aj += 1
	return aj
end

local ak = {}
ak.__index = ak

function ak.new(al)	
local am = (setmetatable({}, ak) )
	
am._state = af(nil)
	am._active = af(false)
	am._text = af(al)
	am._extras = af({} )
	am._binds = af({} )
	am._bindable = af(false)
	am._tip = af(nil )
	am._visible = af(true)
	am._scopeKey = af(nil )
	am._scopeSource = af(nil )
	am._scopeIsInherited = af(false)
	am._overrides = af({} )

	return am
end

local function resolveOverride(al)	
local am = -math.huge
	local an	
local ao = false
	for ap, aq in next, al do
		if aq.priority > am then
			am = aq.priority
			an = aq.value
			ao = true
		end
	end
	return an, ao
end

function ak.GetEffectiveValue(al)	
local am = ag(al._overrides)
	local an, ao = resolveOverride(am)
	if ao then
		return an
	end
	return ag(al._state)
end

function ak.IsOverridden(al)	
return next(ag(al._overrides)) ~= nil
end

function ak.AddOverride(al, am, an, ao)	
local ap = nextOverrideToken()
	local aq = ag(al._overrides)
	al._overrides(ac.Dictionary.set(aq, ap, {
		value = am,
		priority = an,
		source = ao,
	}))
	return ap
end

function ak.UpdateOverride(al, am, an, ao)	
local ap = ag(al._overrides)
	local aq = ap[am]
	if not aq then
		return false
	end
	al._overrides(ac.Dictionary.set(ap, am, {
		value = an,
		priority = ao or aq.priority,
		source = aq.source,
	}))
	return true
end

function ak.RemoveOverride(al, am)	
local an = ag(al._overrides)
	if not an[am] then
		return false
	end
	al._overrides(ac.Dictionary.removeKey(an, am))
	return true
end

function ak.ClearOverridesFromSource(al, am)	
local an = ag(al._overrides)
	local ao= {}
	local ap = false
	for aq, ar in next, an do
		if ar.source == am then
			ap = true
		else
			ao[aq] = ar
		end
	end
	if ap then
		al._overrides(ao)
	end
end

function ak.GetOverrides(al)	
local am = ag(al._overrides)
	local an= {}
	for ao, ap in next, am do
		an[#an + 1] = ap
	end
	return an
end

function ak.SetText(al, am)	
al._text(am)
end

function ak.SetTip(al, am)	
al._tip(am)
	return al
end

function ak.SetBindable(al, am)	
al._bindable(am)
	return al
end

function ak.SetVisible(al, am)	
al._visible(am)
	return al
end

function ak.IsVisible(al)	
return ag(al._visible)
end

function ak.AddBind(al)	
local am = ag(al._binds)
	if #am >= ae.MAX_BINDS then
		return nil
	end
	local an = ae.CreateBind(al, ag(al._text))
	al._binds(ac.Array.push(am, an))
	return an
end

function ak.RemoveBind(al, am)	
local an = ag(al._binds)
	for ao, ap in next, an do
		if ap.id == am then
			ae.DestroyBind(ap)
			break
		end
	end
	al._binds(ac.Array.filter(an, function(ao)
		return ao.id ~= am
	end))
end

function ak.GetBinds(al)	
return ag(al._binds)
end

function ak.Destroy(al)	
local am = ag(al._binds)
	for an, ao in next, am do
		ae.DestroyBind(ao)
	end
	al._binds{}
end

function ak.OnChange(al, am)	
local an = al.GetEffectiveValue(al)
	local function fire()		
local ao = al.GetEffectiveValue(al)
		if ao == an then
			return
		end
		an = ao
		am(ao)
	end
	local ao = ah(al._state, fire)
	local ap = ah(al._overrides, fire)
	return function()		
ao()
		ap()
	end
end

function ak.Peek(al)	
return al.GetEffectiveValue(al)
end

function ak.PeekRaw(al)	
return ag(al._state)
end

function ak.Render(al, am)	
return ai(ad, {
		Element = al,
		LayoutOrder = am,
	})
end

function ak.RenderInternal(al, am)	
return ai("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 0, 0),
		LayoutOrder = (am and am.layoutOrder) or 0,
	})
end
























return ak
end function a.aH()
local aa = a.load'c'

local ab = aa.useEffect
local ac = aa.useRef




















local function useLabelHover(
	ad,
	ae,
	af
)	
local ag = ac(af and af.onClick)
	ag.current = af and af.onClick

	local ah = ac(ae)
	ah.current = ae

	ab(function()
		local ai = ad and ad.current
		if not ai then
			return nil
		end

		local aj= {
			ai.MouseEnter:Connect(function()
				for aj, ak in ah.current do
					ak.onMouseEnter()
				end
			end),
			ai.MouseLeave:Connect(function()
				for aj, ak in ah.current do
					ak.onMouseLeave()
				end
			end),
			ai.MouseButton1Click:Connect(function()
				local aj = ag.current
				if aj then
					aj()
				end
			end),
		}

		return function()
			for ak, al in aj do
				al.Disconnect(				al)
			end
		end
	end, { ad })
end

return useLabelHover
end function a.aI()
local aa = a.load'c'
local ab = a.load'e'
local ac = a.load'd'

local ad = a.load's'
local ae = a.load'N'
local af = a.load'ab'
local ag = a.load'aa'
local ah = a.load'aH'
local ai = a.load'Q'
local aj = a.load'O'
local ak = a.load'ac'

local al = ab.useSpring
local am = aa.useEffect
local an = aa.useState
local ao = aa.useRef
local ap = aa.useMemo
local aq = aa.useCallback
local ar = ac.useAtom
local as = aa.createElement

local at = ae.colors.window.element







return function(au)	
local av = au.Slider
	local aw = au.TextRef
	local ax = au.LayoutOrder or 2

	local b = ao(nil )
	local c = ao(nil )
	local d, e = an(false)

	local f = ar(av._state) or av._min
	local g = ar(av._formattedValue)

	local h = af(at.panel, at.panel, av._active)
	local i = af(at.accentSoft, at.accent, av._active)
	local j = af(at.thumb, at.thumbActive, av._active)
	local k = af(at.fieldBackground, at.fieldBackgroundActive, av._active)
	local l = af(at.fieldStroke, at.fieldStrokeActive, av._active)
	local m = af(at.caption, at.captionActive, av._active)

	local n = av._max - av._min
	local o = n > 0 and (math.clamp((f - av._min) / n, 0, 1)) or 0

	local p, q = al(o, aj.snap)

	am(function()
		q.setGoal(		q,o)
	end, { o })

	local r = ao(av)
	r.current = av

	local s = ag(function(s)
		r.current:SetFromAlpha(s.X)
	end)

	local t = ap(function()
		return function()
			h.onMouseEnter()
			i.onMouseEnter()
			j.onMouseEnter()
		end
	end, { h, i, j } )

	local u = ap(function()
		return function()
			h.onMouseLeave()
			i.onMouseLeave()
			j.onMouseLeave()
		end
	end, { h, i, j } )

	local v = ap(function()
		return function()
			k.onMouseEnter()
			l.onMouseEnter()
			m.onMouseEnter()
		end
	end, { k, l, m } )

	local w = ap(function()
		return function()
			k.onMouseLeave()
			l.onMouseLeave()
			m.onMouseLeave()
		end
	end, { k, l, m } )

	local x = ap(function()
		return ak(function(x, y)
			if y.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			s(x, y)
		end)
	end, { s } )

	local y = aq(function()
		r.current:Nudge(1)
	end, {})

	local z = aq(function()
		r.current:Nudge(-1)
	end, {})

	local A = aq(function()
		if b.current then
			b.current:CaptureFocus()
		end
	end, {})

	local B = ap(function()
		return { h, i, j, k, l, m }
	end, { h, i, j, k, l, m } )

	local C = ap(function()
		return {
			onClick = function()
				if b.current then
					b.current:CaptureFocus()
				end
			end,
		}
	end, {})

	local D = aq(function()
		if b.current then
			b.current:ReleaseFocus()
		end
	end, {})

	local E = ap(function()
		return p.map(p,function(E)
			return UDim2.fromScale(E, 1)
		end)
	end, { p } )

	local F = ap(function()
		return p.map(p,function(F)
			return UDim2.fromScale(F, 0.5)
		end)
	end, { p } )

	local G = ap(function()
		return p.map(p,function(G)
			return Vector2.new(G, 0.5)
		end)
	end, { p } )

	am(function()
		local H = b.current
		if not H then
			return
		end

		local I = {
			H.Focused:Connect(function()
				H.Text = ""
				e(true)
			end),
			H.FocusLost:Connect(function()
				e(false)
				r.current:SetFromText(H.Text)
				H.Text = ""
			end),
		}

		return function()
			for J, K in I do
				K.Disconnect(				K)
			end
		end
	end, {})

	ai(c, d, D)

	ah(aw, B, C)

	return as("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(115, 14),
		BorderSizePixel = 0,
		LayoutOrder = ax,
	}, {
		UIListLayout = as("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Slider = as("TextButton", {
			Size = UDim2.fromOffset(70, 4),
			BackgroundColor3 = h.binding,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			LayoutOrder = 0,
			AutoButtonColor = false,
			Text = "",
			Active = false,
			[aa.Event.MouseEnter] = t,
			[aa.Event.MouseLeave] = u,
			[aa.Event.InputBegan] = x,
			[aa.Event.MouseWheelForward] = y,
			[aa.Event.MouseWheelBackward] = z,
		}, {
			UICorner = as("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			UIFlexItem = as("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
				ItemLineAlignment = Enum.ItemLineAlignment.Automatic,
			}),
			Fill = as("Frame", {
				Size = E,
				BackgroundColor3 = i.binding,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, {
				UICorner = as("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			}),
			Circle = as("Frame", {
				Size = UDim2.fromOffset(8, 8),
				Position = F,
				AnchorPoint = G,
				BackgroundColor3 = j.binding,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				UICorner = as("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			}),
		}),
		Box = as("TextButton", {
			ref = c,
			Size = UDim2.fromOffset(0, 14),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = k.binding,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			AutoButtonColor = false,
			Text = "",
			Active = false,
			ClipsDescendants = true,
			[aa.Event.MouseEnter] = v,
			[aa.Event.MouseLeave] = w,
			[aa.Event.MouseButton1Click] = A,
		}, {
			UICorner = as("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			UIPadding = as("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 1),
				PaddingBottom = UDim.new(0, 1),
			}),
			UISizeConstraint = as("UISizeConstraint", {
				MinSize = Vector2.new(30, 14),
				MaxSize = Vector2.new(72, 14),
			}),
			UIStroke = as("UIStroke", {
				Color = l.binding,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			Text = as("TextBox", {
				ref = b,
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 20, 0, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				Text = d and "" or g,
				FontFace = ad.Get("font", "semi_bold"),
				TextSize = 11,
				TextColor3 = m.binding,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ClearTextOnFocus = true,
				Interactable = d,
				MultiLine = false,
				TextWrapped = false,
			}),
		}),
	})
end
end function a.aJ()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'aG'
local ad = a.load'aI'

local ae = aa.peek
local af = aa.subscribe
local ag = aa.atom
local ah = ab.createElement

local ai = {}
ai.__index = ai

setmetatable(ai, { __index = ac })

local function trimTrailingZeros(aj)	
if not aj.find(aj, "%.")then
		return aj
	end
	aj = aj.gsub(aj,"0+$", "")
	aj = aj.gsub(aj,"%.$", "")
	return aj
end

local function snapToStep(aj, ak)	
local al = aj._step
	if al and al > 0 then
		return aj._min + math.round((ak - aj._min) / al) * al
	end
	return ak
end

local function formatValue(aj)	
local ak = ae(aj._state) or 0
	local al = aj._valueTextOverrides
	if al then
		local am = snapToStep(aj, ak)
		local an = al[am]
		if an ~= nil and an ~= "" then
			return an
		end
	end

	local am = math.round(ak * 1000) / 1000
	local an = trimTrailingZeros(string.format("%.3f", am))

	local ao = aj._prefix
	if ao then
		an = ao .. an
	end

	local ap = aj._suffix
	if ap then
		an = an .. ap
	end

	return an
end

local function constructor(
	aj,
	ak,
	al,
	am,
	an,
	ao,
	ap
)	
local aq = (ac.new(aj) )
	
setmetatable(aq, ai)

	aq._bindable(true)

	aq._min = al
	aq._max = am
	aq._step = an
	aq._prefix = ao
	aq._suffix = ap
	aq._valueTextOverrides = nil 	
aq._formattedValue = ag""
	
af(aq._state, function(ar)
		aq._active(ar > aq._min)
		aq._formattedValue(formatValue(aq))
	end)

	aq._state(math.clamp(ak, al, am))

	return aq
end

function ai.SetValue(aj, ak, al)	
local am = math.clamp(ak, aj._min, aj._max)

	if al and aj._step and aj._step > 0 then
		local an = aj._min + math.round((am - aj._min) / aj._step) * aj._step
		am = math.clamp(an, aj._min, aj._max)
	end

	aj._state(am)
end

function ai.SetValueTextOverrides(aj, ak)	
aj._valueTextOverrides = ak
	aj._formattedValue(formatValue(aj))
	return aj
end

function ai.SetFromAlpha(aj, ak)	
local al = aj._min + math.clamp(ak, 0, 1) * (aj._max - aj._min)
	aj.SetValue(	aj,al, true)
end

function ai.Nudge(aj, ak)	
local al = ae(aj._state) or aj._min
	local am = aj._max - aj._min
	local an = aj._step
	local ao = an and an > 0 and (math.max(an, am * 0.05)) or (am * 0.05)

	aj.SetValue(
	aj,al + ao * ak, true)
end

function ai.SetFromText(aj, ak)	local al = tonumber(ak)
	if not al then
		return false
	end

	aj.SetValue(
	aj,al, false)
	return true
end

function ai.GetAlpha(aj)	local ak = aj._max - aj._min
	if ak == 0 then
		return 0
	end
	local al = ae(aj._state) or aj._min
	return math.clamp((al - aj._min) / ak, 0, 1)
end

function ai.RenderInternal(aj, ak)	
return ah(ad, {
		Slider = aj,
		TextRef = ak and ak.textRef,
		LayoutOrder = ak and ak.layoutOrder,
	})
end

function ai.CreateTargetProxy(aj, ak)	
local al= ak or ae(aj._state) or aj._min
	local am = constructor("", al, aj._min, aj._max, aj._step, aj._prefix, aj._suffix)
	am._valueTextOverrides = aj._valueTextOverrides
	am._formattedValue(formatValue(am))
	return am
end
















return constructor
end function a.aK()
local aa = a.load'c'
local ab = a.load'e'
local ac = a.load'd'
local ad = a.load'N'

local ae = a.load'ab'
local af = a.load'aH'
local ag = a.load'O'
local ah = aa.useEffect
local ai = ac.useAtom
local aj = aa.createElement

local ak = ad.colors.window.element







return function(al)	
local am = al.Toggle
	local an = al.TextRef
	local ao = al.LayoutOrder or 2

	local ap = ai(am._state)

	local aq = ae(ak.surface, ak.accent, am._active, true)
	local ar = ae(ak.thumb, ak.thumbActive, am._active, true)
	local as = ae(ak.surfaceStroke, ak.accentStrong, am._active)

	local at, au = ab.useSpring(0, ag.quick)

	ah(function()
		au.setGoal(		au,ap and 1 or 0)
	end, { ap })

	af(an, { aq, ar }, {
		onClick = function()
			am.Toggle(			am)
		end,
	})

	return aj("TextButton", {
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(30, 14),
		BackgroundColor3 = aq.binding,
		[aa.Event.MouseEnter] = function()
			aq.onMouseEnter()
			ar.onMouseEnter()
		end,
		[aa.Event.MouseLeave] = function()
			aq.onMouseLeave()
			ar.onMouseLeave()
		end,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		[aa.Event.MouseButton1Click] = function()
			am.Toggle(			am)
		end,
		LayoutOrder = ao,
	}, {
		UIStroke = aj("UIStroke", {
			Color = as.binding,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UICorner = aj("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		UIPadding = aj("UIPadding", {
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		}),
		Circle = aj("Frame", {
			BackgroundTransparency = 0,
			BackgroundColor3 = ar.binding,
			Position = at.map(at,function(av)
				return UDim2.fromScale(av, 0)
			end),
			AnchorPoint = at.map(at,function(av)
				return Vector2.new(av, 0)
			end),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(10, 10),
		}, {
			UICorner = aj("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
	})
end
end function a.aL()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'aG'
local ad = a.load'aK'

local ae = aa.peek
local af = aa.subscribe
local ag = ab.createElement

local ah = {}
ah.__index = ah

setmetatable(ah, { __index = ac })

local function constructor(ai, aj)	
local ak = (ac.new(ai) )
	
setmetatable(ak, ah)

	ak._bindable(true)

	af(ak._state, function(al)
		ak._active(al)
	end)

	ak._state(aj)

	return ak
end

function ah.Toggle(ai)	
ai._state(not ae(ai._state))
end

function ah.SetState(ai, aj)	
ai._state(aj)
end

function ah.RenderInternal(ai, aj)	
return ag(ad, {
		Toggle = ai,
		TextRef = aj and aj.textRef,
		LayoutOrder = aj and aj.layoutOrder,
	})
end



return constructor
end function a.aM()
local aa = a.load'c'
local ab = a.load'd'

local ac = a.load's'
local ad = a.load'N'
local ae = a.load'ab'
local af = a.load'aH'
local ag = a.load'Q'

local ah = aa.useState
local ai = aa.useRef
local aj = aa.useEffect
local ak = aa.useMemo
local al = aa.useCallback
local am = ab.useAtom
local an = aa.createElement

local ao = ad.colors.window.element







return function(ap)	
local aq = ap.Textbox
	local ar = ap.TextRef
	local as = ap.LayoutOrder or 2

	local at = am(aq._state) or ""
	local au = am(aq._placeholder)

	local av = ai(nil )
	local aw = ai(nil )
	local ax, b = ah(false)

	local c = ae(ao.fieldBackground, ao.fieldBackgroundActive, aq._active)
	local d = ae(ao.fieldStroke, ao.fieldStrokeActive, aq._active)
	local e = ae(ao.caption, ao.captionActive, aq._active)
	local f = am(ao.caption)

	local g = ai(aq)
	g.current = aq

	local h = ak(function()
		return function()
			c.onMouseEnter()
			d.onMouseEnter()
			e.onMouseEnter()
		end
	end, { c, d, e } )

	local i = ak(function()
		return function()
			c.onMouseLeave()
			d.onMouseLeave()
			e.onMouseLeave()
		end
	end, { c, d, e } )

	local j = al(function()
		if av.current then
			av.current:CaptureFocus()
		end
	end, {})

	local k = al(function()
		if av.current then
			av.current:ReleaseFocus()
		end
	end, {})

	local l = ak(function()
		return { c, d, e }
	end, { c, d, e } )

	local m = ak(function()
		return {
			onClick = function()
				if av.current then
					av.current:CaptureFocus()
				end
			end,
		}
	end, {})

	aj(function()
		local n = av.current
		if not n then
			return
		end

		local o = {
			n.Focused:Connect(function()
				b(true)
			end),
			n.FocusLost:Connect(function()
				b(false)
			end),
			n.GetPropertyChangedSignal(			n, "Text"):Connect(function()
				local o = n.Text
				if g.current._numeric then
					local p = string.gsub(o, "[^%d]", "")
					if p ~= o then
						n.Text = p
						return
					end
				end
				g.current._state(o)
			end),
		}

		return function()
			for p, q in o do
				q.Disconnect(				q)
			end
		end
	end, {})

	ag(aw, ax, k)
	af(ar, l, m)

	return an("TextButton", {
		ref = aw,
		Size = UDim2.fromOffset(115, 14),
		BackgroundColor3 = c.binding,
		BorderSizePixel = 0,
		LayoutOrder = as,
		AutoButtonColor = false,
		Text = "",
		Active = false,
		ClipsDescendants = true,
		[aa.Event.MouseEnter] = h,
		[aa.Event.MouseLeave] = i,
		[aa.Event.MouseButton1Click] = j,
	}, {
		UICorner = an("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIPadding = an("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 1),
			PaddingBottom = UDim.new(0, 1),
		}),
		UIStroke = an("UIStroke", {
			Color = d.binding,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		Input = an("TextBox", {
			ref = av,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ClearTextOnFocus = false,
			Text = at,
			PlaceholderText = au,
			PlaceholderColor3 = f,
			TextColor3 = e.binding,
			FontFace = ac.Get("font", "semi_bold"),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextEditable = true,
			MultiLine = false,
			TextWrapped = false,
			Interactable = true,
		}),
	})
end
end function a.aN()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'aG'
local ad = a.load'aM'local _=

aa.peek
local af = aa.subscribe
local ag = aa.atom
local ah = ab.createElement

local ai = {}
ai.__index = ai

setmetatable(ai, { __index = ac })

local function constructor(aj, ak, al, am)	
local an = (ac.new(aj) )
	
setmetatable(an, ai)

	an._bindable(false)

	an._placeholder = ag(al or "")
	an._numeric = am == true

	af(an._state, function(ao)
		an._active(type(ao) == "string" and ao ~= "")
	end)

	an._state(ak or "")

	return an
end

function ai.SetValue(aj, ak)	
if aj._numeric then
		ak = string.gsub(ak, "[^%d]", "")
	end
	aj._state(ak)
end

function ai.SetPlaceholder(aj, ak)	
aj._placeholder(ak)
	return aj
end

function ai.RenderInternal(aj, ak)	
return ah(ad, {
		Textbox = aj,
		TextRef = ak and ak.textRef,
		LayoutOrder = ak and ak.layoutOrder,
	})
end









return constructor
end function a.aO()
local aa = a.load'm'
local ab = a.load'c'

local ac = a.load'M'
local ad = a.load'aB'
local ae = a.load'aC'
local af = a.load'aJ'
local ag = a.load'aL'
local ah = a.load'aN'

local ai = aa.atom
local aj = aa.peek
local ak = ab.createElement

local al = {}
al.__index = al

setmetatable(al, { __index = ac })




















local function constructor()	
local am = (ac.new() )	
setmetatable(am, al)

	am._weapon = ai""	
am._skin = ai""	
am._rarity = ai"common"	
am._icon = ai(nil )

	am._floatEl = af("Float", 0.07, 0, 1, 0.001)
	am._seedEl = ah("Paint Seed", "0", "0", true)
	am._nameTagEl = ah("Nametag", "", "Enter a nametag")
	am._statTrackEl = ag("StatTrak™", false)

	am._onSubmit = nil 	
am._onCancel = nil 
	
return am
end

function al.Open(am, an)	
am._weapon(an.weapon)
	am._skin(an.skin)
	am._rarity(an.rarity or "common")
	am._icon(an.icon)
	am._onSubmit = an.onSubmit
	am._onCancel = an.onCancel

	am._floatEl:SetValue(0.07)
	am._seedEl:SetValue"0"	
am._nameTagEl:SetValue""	
am._statTrackEl:SetState(false)

	am.SetPosition(
	am,an.position or ad.menuCenter())
	am.SetOpen(	am,true)
end

function al.BuildPayload(am)	local an = tonumber(am._seedEl:Peek()) or 0
	return {
		weapon = aj(am._weapon),
		skin = aj(am._skin),
		float = am._floatEl:Peek() or 0,
		seed = an,
		nameTag = am._nameTagEl:Peek() or "",
		statTrack = am._statTrackEl:Peek() == true,
	}
end

function al.Submit(am, an)	
local ao = am._onSubmit
	am._onSubmit = nil
	am._onCancel = nil
	am.SetOpen(	am,false)
	if ao then
		ao(an)
	end
end

function al.Cancel(am)	
local an = am._onCancel
	am._onSubmit = nil
	am._onCancel = nil
	am.SetOpen(	am,false)
	if an then
		an()
	end
end

function al.Close(am)	
am._onSubmit = nil
	am._onCancel = nil
	am.SetOpen(	am,false)
end

function al.Render(am)	
return ak(ae, { SkinConfig = am })
end



















return constructor
end function a.aP()
local aa = a.load'W'
local ab = a.load'ag'
local ac = a.load'ai'
local ad = a.load'ak'
local ae = a.load'an'
local af = a.load'ap'
local ag = a.load'au'
local ah = a.load'ay'
local ai = a.load'aA'
local aj = a.load'aO'

local ak = {
	Options = aa,
	Colorpicker = ab,
	Context = ac,
	Dropdown = ad,
	ThemeEditor = ae,
	BindEditor = af,
	AssetPicker = ag,
	ScopeMenu = ah,
	RecordEditor = ai,
	SkinConfig = aj,
}



return ak
end function a.aQ()
local aa = a.load'm'
local ab = a.load'n'a.load'aP'


local ad = a.load'W'
local ae = a.load'ag'
local af = a.load'ai'
local ag = a.load'ak'
local ah = a.load'an'
local ai = a.load'ap'
local aj = a.load'au'
local ak = a.load'ay'
local al = a.load'aA'
local am = a.load'aO'
local an = a.load'S'
local ao = a.load'X'
local ap = a.load'af'
local aq = a.load'aD'

local ar = aa.peek
local as = aa.atom
local at = aa.subscribe

local au = {
	subwindows = as({} ),
	anyOpen = as(false),
}

local function recomputeAnyOpen()	
for av, aw in next, ar(au.subwindows) do
		if ar(aw._isOpen) then
			au.anyOpen(true)
			return
		end
	end
	au.anyOpen(false)
end

function au.Add(av, aw)	
local ax = ar(au.subwindows)
	au.subwindows(ab.Dictionary.set(ax, av, aw))

	at(aw._isOpen, recomputeAnyOpen)
	recomputeAnyOpen()

	return aw
end

function au.Get(av)	
return ar(au.subwindows)[av]
end

function au.OpenOptions(av, aw)	
if not an.IsSubwindowOpenAllowed() then
		return nil
	end
	local ax= au.Get"Options"	
if not ax then
		return nil
	end

	ax.Open(
	ax,av, aw)

	return ax
end

local av = { "Submenu", "Submenu2", "Submenu3", "Submenu4" }

function au.OpenSubmenu(aw, ax)	if not an.IsSubwindowOpenAllowed() then
		return nil
	end

	local b = ar(au.subwindows)

	for c, d in next, av do
		local e= b[d]
		if e and ar(e._source) == aw then
			e.Open(			e,aw, ax)
			return e
		end
	end

	for c, d in next, av do
		local e= b[d]
		if e and not ar(e._isOpen) then
			e.Open(			e,aw, ax)
			return e
		end
	end

	local c= b[av[1] ]
	if not c then
		return nil
	end
	c.Open(	c,aw, ax)
	return c
end

function au.CloseAllSubmenus()	
local aw = ar(au.subwindows)
	for ax, b in next, av do
		local c= aw[b]
		if c then
			c.Close(			c)
		end
	end
end

function au.OpenColorpicker(aw, ax)	
if not an.IsSubwindowOpenAllowed() then
		return nil
	end
	local b= au.Get"Colorpicker"	
if not b then
		return nil
	end

	b.Open(
	b,aw, ax)

	return b
end

function au.OpenDropdown(aw, ax)	if not an.IsSubwindowOpenAllowed() then
		return nil
	end
	local b= au.Get"Dropdown"	
if not b then
		return nil
	end

	b.Open(
	b,aw, ax)

	return b
end

function au.CloseDropdown(aw)	local ax= au.Get"Dropdown"	
if not ax then
		return
	end

	if aw and ar(ax._source) ~= aw then
		return
	end

	ax.Close(
	ax)
end

function au.WasDropdownJustClosedFor(aw)	local ax= au.Get"Dropdown"	
if not ax then
		return false
	end
	return ax.WasJustClosedFor(ax,aw)
end

function au.OpenThemeEditor(aw)	
if not an.IsSubwindowOpenAllowed() then
		return nil
	end
	local ax= au.Get"ThemeEditor"	
if not ax then
		return nil
	end

	ax.Open(
	ax,aw)

	return ax
end

function au.OpenContext(aw, ax)	if not an.IsSubwindowOpenAllowed() then
		return nil
	end
	local b= au.Get"Context"	
if not b then
		return nil
	end

	b.Open(
	b,aw, ax)

	return b
end

function au.CloseContext()	local aw= au.Get"Context"	
if not aw then
		return
	end

	aw.Close(
	aw)
end

function au.OpenAssetPicker(aw, ax)	if not an.IsSubwindowOpenAllowed() then
		return nil
	end
	local b= au.Get"AssetPicker"	
if not b then
		return nil
	end

	b.Open(
	b,aw, ax)

	return b
end

function au.OpenScopeMenu(aw, ax)	if not an.IsSubwindowOpenAllowed() then
		return nil
	end
	local b= au.Get"ScopeMenu"	
if not b then
		return nil
	end
	b.Open(	b,aw, ax)
	return b
end

function au.CloseScopeMenu()	
local aw= au.Get"ScopeMenu"	
if not aw then
		return
	end
	aw.Close(	aw)
end

function au.WasScopeMenuJustClosed()	
local aw= au.Get"ScopeMenu"	
if not aw then
		return false
	end
	return aw.WasJustClosed(aw)
end

function au.OpenRecordEditor(aw)	
if not an.IsSubwindowOpenAllowed() then
		return nil
	end
	local ax= au.Get"RecordEditor"	
if not ax then
		return nil
	end

	ax.Open(
	ax,aw)

	return ax
end

function au.OpenSkinConfig(aw)	if not an.IsSubwindowOpenAllowed() then
		return nil
	end
	local ax= au.Get"SkinConfig"	
if not ax then
		return nil
	end

	ax.Open(
	ax,aw)

	return ax
end

function au.CloseSkinConfig()	local aw= au.Get"SkinConfig"	
if not aw then
		return
	end
	aw.Close(	aw)
end

function au.OpenBindEditor(aw, ax)	
if not an.IsSubwindowOpenAllowed() then
		return nil
	end
	local b= au.Get"BindEditor"	
if not b then
		return nil
	end

	b.Open(
	b,aw, ax)

	return b
end

function au.CloseAll()	for aw, ax in next, ar(au.subwindows) do
		ax.SetOpen(		ax,false)
	end
end

function au.init()	
au.Add("Options", ad())
	au.Add("Submenu", ad())
	au.Add("Submenu2", ad())
	au.Add("Submenu3", ad())
	au.Add("Submenu4", ad())
	au.Add("Colorpicker", ae())
	au.Add("Dropdown", ag())
	au.Add("ThemeEditor", ah())
	au.Add("BindEditor", ai())
	au.Add("AssetPicker", aj())
	au.Add("ScopeMenu", ak())
	au.Add("RecordEditor", al())
	au.Add("SkinConfig", am())

	local aw = af()
	au.Add("Context", aw)

	ao.SetHandlers(function(ax, b)
		if not an.IsSubwindowOpenAllowed() then
			return
		end
		aw.Open(		aw,ax, b)
	end, function()
		aw.Close(		aw)
	end)

	ap.SetHandlers(function(ax, b)
		au.OpenDropdown(ax, b)
	end, function(ax)
		if ax then
			au.CloseDropdown(ax)
		else
			au.CloseDropdown()
		end
	end, function(ax)
		return au.WasDropdownJustClosedFor(ax)
	end)

	aq.SetHandlers(function(ax, b)
		au.OpenBindEditor(ax, b)
	end, function(ax, b)
		au.OpenContext(ax, b)
	end)
end















return au
end function a.aR()
local aa = a.load'm'

local ab = aa.atom

local ac = {
	openTab = ab(nil),
	searchQuery = ab"",
}



return ac
end function a.aS()
local aa = a.load'm'

local ab = aa.peek












local ac = {}

local function lowerContains(ad, ae)	
if not ad or ad == "" then
		return false
	end
	if ae == "" then
		return true
	end
	return string.find(string.lower(ad), ae, 1, true) ~= nil
end









local function extraMatches(ad, ae)	
if not ad._extras then
		return false
	end
	local af = ab(ad._extras)
	for ag, ah in next, af do
		if lowerContains(ab(ah._text), ae) then
			return true
		end
	end
	return false
end

local function recurseInto(ad, ae, af, ag)	
local ah= {}
	for ai, aj in next, ad do
		local ak = ab(aj._text)
		if lowerContains(ak, ae.q) or extraMatches(aj, ae.q) then
			table.insert(ah, aj)
		end

		if aj._elements then
			recurseInto(ab(aj._elements), ae, aj, ak)
		end
		if aj._extras then
			for al, am in next, ab(aj._extras) do
				if am._elements then
					recurseInto(ab(am._elements), ae, am, ab(am._text))
				end
			end
		end
	end
	if #ah > 0 then
		table.insert(ae.results, {
			tabGroup = ae.tabGroup,
			tab = ae.tab,
			section = ae.section,
			submenu = af,
			submenuTitle = ag,
			elements = ah,
		})
	end
end

ac.walk = LPH_NO_VIRTUALIZE(function(ad, ae)	
local af = string.lower(ae)
	local ag= {}

	local ah = ab(ad._tabGroups)
	for ai, aj in next, ah do
		local ak = lowerContains(aj.title, af)
		local al = ab(aj.tabs)
		for am, an in next, al do
			local ao = ak or lowerContains(an.title, af)
			local ap = ab(an._containers)
			for aq, ar in next, ap do
				local as = ab(ar._sections)
				for at, au in next, as do
					local av = ao or lowerContains(au._title, af)
					if av then
						local aw = ab(au._elements)
						if #aw > 0 then
							table.insert(ag, {
								tabGroup = aj,
								tab = an,
								section = au,
								submenu = nil,
								submenuTitle = nil,
								elements = aw,
							})
						end
					else
						local aw= {
							q = af,
							tabGroup = aj,
							tab = an,
							section = au,
							results = ag,
						}
						recurseInto(ab(au._elements), aw, nil, nil)
					end
				end
			end
		end
	end

	return ag
end)

return ac
end function a.aT()
local aa = a.load'c'
local ab = a.load'e'
local ac = a.load'd'
local ad = a.load'n'

local ae = a.load's'
local af = a.load'N'
local ag = a.load'aR'
local ah = a.load'O'
local ai = a.load'aS'

local aj = ac.useAtom
local ak = ab.useSpring
local al = aa.useEffect
local am = aa.useMemo
local an = aa.useState
local ao = aa.useRef
local ap = aa.createElement

local aq = af.colors.window
local ar = aq.section
local as = aq.element

local at = 1






local function ResultPanel(au)	
local av = au.Result

	local aw = aj(ar.background)
	local ax = aj(ar.stroke)
	local b = aj(ar.text)
	local c = aj(as.caption)

	local d = am(function()
		local d= {}
		for e, f in next, av.elements do
			d[tostring(f)] = f.Render(f,e)
		end
		return d
	end, { av.elements })

	local e = av.tabGroup.title .. "  /  " .. av.tab.title
	if av.submenuTitle then
		e = e .. "  /  " .. av.submenuTitle
	end

	return ap("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = au.LayoutOrder,
	}, {
		UIListLayout = ap("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		Header = ap("TextButton", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 14),
			Text = "",
			AutoButtonColor = false,
			Active = false,
			LayoutOrder = 0,
			[aa.Event.MouseButton1Click] = function()
				ag.openTab(av.tab)
				ag.searchQuery""			
end,
		}, {
			UIListLayout = ap("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			Title = ap("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = ae.Get("font", "semi_bold"),
				TextColor3 = b,
				TextSize = 11,
				Text = av.section._title,
				Size = UDim2.fromOffset(0, 14),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 0,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Caption = ap("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = ae.Get("font", "light"),
				TextColor3 = c,
				TextSize = 11,
				Text = e,
				Size = UDim2.fromOffset(0, 14),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),
		Panel = ap(
			"Frame",
			{
				BackgroundColor3 = aw,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 34),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
			},
			ad.Dictionary.join({
				UIStroke = ap("UIStroke", {
					Color = ax,
					Thickness = 1,
				}),
				UICorner = ap("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
				UIPadding = ap("UIPadding", {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
				}),
				UIListLayout = ap("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Top,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 10),
				}),
			}, d)
		),
	})
end

return function(au)	
local av = au.Window

	local aw = aj(ag.searchQuery)
	aj(av._tabGroups)

	local ax = aw ~= ""

	local b, c = ak(0, ah.quick)
	al(function()
		c.setGoal(		c,ax and 1 or 0)
	end, { ax })

	local d = am(function()
		if not ax then
			return {}
		end
		return ai.walk(av, aw)
	end, { ax, aw } )

	local e = aj(aq.searchMuted)
	local f = aj(as.scrollThumb)
	local g = aj(aq.background)

	local h = ao(nil )
	local i = ao(nil )
	local j, k = an(false)

	al(function()
		local l= {}
		local m = false

		local function recompute()			
if m then
				return
			end
			local n = h.current
			local o = i.current
			if not n or not o then
				return
			end
			if n.AbsoluteSize.Y < 1 then
				return
			end
			local p = o.AbsoluteSize.Y > n.AbsoluteSize.Y + at
			k(p)
		end

		local function attach()			
if m then
				return
			end
			local n = h.current
			local o = i.current
			if not n or not o then
				task.defer(attach)
				return
			end
			table.insert(l, n.GetPropertyChangedSignal(n, "AbsoluteSize"):Connect(recompute))
			table.insert(l, o.GetPropertyChangedSignal(o, "AbsoluteSize"):Connect(recompute))
			task.defer(recompute)
		end

		attach()

		return function()
			m = true
			for n, o in next, l do
				o.Disconnect(				o)
			end
		end
	end, { d } )

	local l= {}
	for m, n in next, d do
		local o = tostring(n.section)
		if n.submenu then
			o = o .. "_" .. tostring(n.submenu)
		end
		l[o] = ap(ResultPanel, {
			Result = n,
			LayoutOrder = m,
		})
	end

	local m = #d > 0

	return ap("CanvasGroup", {
		BackgroundColor3 = g,
		BackgroundTransparency = b.map(b,function(n)
			return 1 - n
		end),
		BorderSizePixel = 0,
		Size = UDim2.new(1, -16, 1, -71),
		Position = b.map(b,function(n)
			return UDim2.fromOffset(8, 59 + (1 - n) * 10)
		end),
		GroupTransparency = b.map(b,function(n)
			return 1 - n
		end),
		Visible = b.map(b,function(n)
			return n > 0.01
		end),
		ZIndex = 5,
	}, {
		Scroll = ap("ScrollingFrame", {
			ref = h,
			Active = false,
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			ClipsDescendants = true,
			ScrollingEnabled = j,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			ScrollBarImageColor3 = f,
			ScrollBarThickness = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
			Visible = m,
			ZIndex = 1,
		}, {
			Content = ap(
				"Frame",
				{
					ref = i,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
				},
				ad.Dictionary.join({
					UIPadding = ap("UIPadding", {
						PaddingLeft = UDim.new(0, 1),
						PaddingRight = UDim.new(0, 1),
						PaddingTop = UDim.new(0, 0),
						PaddingBottom = UDim.new(0, 0),
					}),
					UIListLayout = ap("UIListLayout", {
						VerticalAlignment = Enum.VerticalAlignment.Top,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 12),
					}),
				}, l)
			),
		}),
		Empty = not m and ap("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0),
			Text = "No results found",
			TextColor3 = e,
			TextSize = 13,
			FontFace = ae.Get("font", "semi_bold"),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 2,
		}) or nil,
	})
end
end function a.aU()
local aa = a.load'e'
local ab = a.load'd'
local ac = a.load'c'
local ad = a.load'm'

local ae = a.load'N'
local af = a.load's'
local ag = a.load'aQ'
local ah = a.load'av'
local ai = a.load'O'
local aj = a.load'I'

local ak = aa.useSpring
local al = ac.useState
local am = ac.useEffect
local an = ac.useRef
local ao = ab.useAtom
local ap = ac.createElement

local aq = ae.colors.window.element









return function(ar)	
local as = ao(ah.currentScope)
	local at = ao(ah.scopes)
	local au = ao(ah.menuOpen)

	local av = ao(aq.fieldBackground)
	local aw = ao(aq.fieldBackgroundActive)
	local ax = ao(aq.fieldStroke)
	local b = ao(aq.fieldStrokeActive)
	local c = ao(aq.textActive)
	local d = ao(aq.icon)

	local e, f = al(false)

	local g, h = ak(0, ai.subtle)
	local i, j = ak(0, ai.smooth)

	am(function()
		h.setGoal(		h,e and 1 or 0)
	end, { e })

	am(function()
		j.setGoal(		j,au and 1 or 0)
	end, { au })

	am(function()
		local k = ar.OnManage
		local l= ag.Get"ScopeMenu"		
if l then
			l.SetOnManage(			l,k)
		end
		return function()
			if l then
				l.SetOnManage(				l,nil)
			end
		end
	end, { ar.OnManage } )

	local k = an(nil )

	local l = at[as]
	local m = l and l.label or as

	return ap("TextButton", {
		ref = k,
		BackgroundColor3 = g.map(g,function(n)
			return av.Lerp(av,aw, n * 0.55)
		end),
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		Size = ar.Size or UDim2.fromOffset(0, 22),
		AutomaticSize = ar.Size and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		Position = ar.Position,
		AnchorPoint = ar.AnchorPoint,
		LayoutOrder = ar.LayoutOrder,
		[ac.Event.MouseEnter] = function()
			f(true)
		end,
		[ac.Event.MouseLeave] = function()
			f(false)
		end,
		[ac.Event.MouseButton1Click] = function()
			if ag.WasScopeMenuJustClosed() then
				return
			end
			if ad.peek(ah.menuOpen) then
				ag.CloseScopeMenu()
				return
			end
			local n = k.current
			if not n then
				return
			end
			local o = n.AbsolutePosition
			local p = n.AbsoluteSize
			local q = 184
			local r = ad.peek(aj.scale)
			if r <= 0 then
				r = 1
			end
			local s = (o.X + p.X) / r - q
			local t = (o.Y + p.Y) / r + 6
			local u = UDim2.fromOffset(math.floor(s), math.floor(t))
			ag.OpenScopeMenu(u, k)
		end,
	}, {
		UICorner = ap("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIStroke = ap("UIStroke", {
			Color = g.map(g,function(n)
				return ax.Lerp(ax,b, n)
			end),
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		UIPadding = ap("UIPadding", {
			PaddingLeft = UDim.new(0, 9),
			PaddingRight = UDim.new(0, 8),
		}),
		UIListLayout = ap("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 7),
		}),
		Label = ap("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = m,
			TextColor3 = c,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			FontFace = af.Get("font", "semi_bold"),
			LayoutOrder = 1,
		}),
		Arrow = ap("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(8, 8),
			Image = af.Get("image", "down_arrow"),
			ImageColor3 = d,
			Rotation = i.map(i,function(n)
				return n * 180
			end),
			LayoutOrder = 2,
		}),
	})
end
end function a.aV()
local aa = a.load'e'
local ab = a.load'd'
local ac = a.load'c'
local ad = a.load'n'
local ae = a.load'm'
local af = a.load's'
local ag = a.load'N'
local ah = a.load'aR'
local ai = a.load'aT'

local aj = a.load'al'
local ak = a.load'U'
local al = a.load'aU'
local am = aa.useSpring
local an = ab.useAtom
local ao = ac.useEffect
local ap = ac.useMemo
local aq = ac.useCallback
local ar = ac.useRef
local as = ac.useState
local at = ac.createElement











local au = ag.colors.window

local function tabGroupFrames(av)	
local aw = av.TabGroup
	local ax = an(aw.tabs)

	local b = ap(function()
		return ad.Array.map(ax, function(b)
			return b.Render(b)
		end)
	end, { ax })

	return at(ac.Fragment, nil, b)
end

local function topBar(av)local _=
av.Window

	local ax = an(au.toolbar)
	local b = an(au.divider)

	local c = an(au.searchMuted)
	local d = an(au.element.textActive)

	local e = an(ah.searchQuery)
	local f = an(ah.openTab)
	local g, h = as(false)
	local i = ar(nil )

	local j = aq(function(j)
		ah.searchQuery(j.Text)
	end, {})

	ao(function()
		if not f or not f._useScope then
			h(false)
			return
		end
		h(ae.peek(f._useScope))
		local k = ae.subscribe(f._useScope, function(k)
			h(k)
		end)
		return k
	end, { f } )

	ao(function()
		local k = i.current
		if not k then
			return
		end
		if k.Text ~= e then
			k.Text = e
		end
	end, { e })

	return at("Frame", {
		Size = UDim2.new(1, -141, 0, 50),
		Position = UDim2.fromOffset(141, 0),
		BorderSizePixel = 0,
		BackgroundColor3 = ax,
		ZIndex = 2,
	}, {
		Cover = at("Frame", {
			BackgroundColor3 = ax,
			Size = UDim2.new(1, 0, 0.25, 0),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			BorderSizePixel = 0,
			ZIndex = 2,
		}),
		Divider = at("Frame", {
			BackgroundColor3 = b,
			Size = UDim2.new(1, 0, 0, 1),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 2,
		}),
		UICorner = at("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		ScopeSelector = g and at("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 2,
		}, {
			Selector = at(al, {}),
		}) or nil,
		SearchBar = at("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -250, 1, -26),
			Position = UDim2.fromOffset(15, 13),
			ZIndex = 2,
		}, {
			UIListLayout = at("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
			}),
			SearchIcon = at("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(12, 12),
				Image = af.Get("image", "search"),
				ImageColor3 = c,
				LayoutOrder = 1,
				ZIndex = 2,
			}),
			SearchInput = at("TextBox", {
				ref = i,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				PlaceholderText = "Search...",
				PlaceholderColor3 = c,
				TextColor3 = d,
				TextSize = 14,
				FontFace = af.Get("font", "light"),
				AutomaticSize = Enum.AutomaticSize.None,
				Size = UDim2.new(1, -20, 0, 14),
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
				[ac.Change.Text] = j,
				ZIndex = 2,
			}),
		}),
	})
end

return function(av)	
local aw = av.Window

	local ax = an(au.background)
	local b = an(au.divider)
	local c = an(au.stroke)
	local d = an(au.shadow)
	local e = (d[1] )	
local f = (d[2] )	
local g = an(au.title)
	local h = an(au.sidebar)
	local i = an(au.logo)

	local j = an(aw._tabGroups)
	local k = an(aw._isOpen)
	local l = an(aw._size)

	local m = ap(function()
		return ad.Array.map(j, function(m, n)
			return m.Render(m,aw._openTab)
		end)
	end, { j })

	local n = ap(function()
		return ad.Array.map(j, function(n)
			return at(tabGroupFrames, { TabGroup = n })
		end)
	end, { j })

	local o, p = am(0, {
		tension = 700,
		friction = 50,
	})

	ao(function()
		p.setGoal(		p,k and 1 or 0)
	end, { k })

	local q, r = aj(aw._position)

	local s = aq(function(s, t)
		q(t)
	end, { q } )

	local t = ap(function()
		return o.map(o,function(t)
			return t > 0.01
		end)
	end, { o } )

	local u = ap(function()
		return o.map(o,function(u)
			local v = 1 - u
			return 1 - (1 - v) * (1 - f)
		end)
	end, { o, f } )

	local v = ap(function()
		return o.map(o,function(v)
			return 1 - v
		end)
	end, { o } )

	local w = ap(function()
		return o.map(o,function(w)
			return 1 - w
		end)
	end, { o } )

	return at("Frame", {
		Size = l,
		Position = r,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = t,
	}, {
		Shadow = ak{
			color = e,
			transparency = u,
			zIndex = 0,
		},
		Body = at("CanvasGroup", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = h,
			BorderSizePixel = 0,
			ZIndex = 1,
			[ac.Event.InputBegan] = s,
			BackgroundTransparency = 0,
			GroupTransparency = v,
		}, {
			Background = at(
				"Frame",
				{
					BackgroundColor3 = ax,
					Position = UDim2.fromOffset(141, 0),
					Size = UDim2.new(1, -141, 1, 0),
					BorderSizePixel = 0,
				},
				ad.Dictionary.join({
					UICorner = at("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),
					SearchView = at(ai, {
						Window = aw,
					}),
				}, n)
			),
			TopShadow = at("Frame", {
				BackgroundColor3 = ax,
				Position = UDim2.fromOffset(141, 52),
				Size = UDim2.new(1, -141, 0, 11),
				BorderSizePixel = 0,
				Visible = true,
				ZIndex = 2,
			}, {
				UIGradient = at("UIGradient", {
					Rotation = 90,
					Transparency = NumberSequence.new{
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(0.5, 0),
						NumberSequenceKeypoint.new(1, 1),
					},
				}),
			}),
			BottomShadow = at("Frame", {
				BackgroundColor3 = ax,
				Position = UDim2.new(0, 145, 1, 0),
				AnchorPoint = Vector2.new(0, 1),
				Size = UDim2.new(1, -153, 0, 12),
				BorderSizePixel = 0,
				Rotation = 180,
				ZIndex = 2,
			}, {
				UIGradient = at("UIGradient", {
					Rotation = 90,
					Transparency = NumberSequence.new{
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(0.4, 0),
						NumberSequenceKeypoint.new(1, 1),
					},
				}),
			}),
			UICorner = at("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			UIStroke = at("UIStroke", {
				Color = c,
				Transparency = w,
				Thickness = 1,
			}),
			SideDivider = at("Frame", {
				BackgroundColor3 = b,
				Size = UDim2.new(0, 1, 1, 0),
				Position = UDim2.fromOffset(140, 0),
				BorderSizePixel = 0,
			}),
			TopBar = at(topBar, {
				Window = aw,
			}),
			TopLeft = at("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(140, 31),
			}, {
				UIListLayout = at("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Bottom,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 6),
				}),
				Logo = at("ImageLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					LayoutOrder = 1,
					Size = UDim2.fromOffset(14, 14),
					Image = af.Get("image", "logo"),
					ImageColor3 = i,
				}),
				Title = at("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					LayoutOrder = 2,
					Text = "Limerence",
					TextColor3 = g,
					TextSize = 18,
					Size = UDim2.fromOffset(0, 14),
					FontFace = af.Get("font", "semi_bold"),
					AutomaticSize = Enum.AutomaticSize.X,
				}),
			}),
			TabButtons = at(
				"Frame",
				{
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 50),
					Size = UDim2.new(0, 140, 1, -60),
					BorderSizePixel = 0,
				},
				ad.Dictionary.join({
					UIPadding = at("UIPadding", {
						PaddingLeft = UDim.new(0, 10),
						PaddingRight = UDim.new(0, 10),
						PaddingTop = UDim.new(0, 0),
						PaddingBottom = UDim.new(0, 0),
					}),
					UIListLayout = at("UIListLayout", {
						VerticalAlignment = Enum.VerticalAlignment.Top,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
				}, m)
			),
		}),
	})
end
end function a.aW()
local aa = a.load'm'
local ab = a.load'e'
local ac = a.load'd'
local ad = a.load'c'

local ae = a.load'N'
local af = a.load's'
local ag = a.load'aw'
local ah = a.load'av'
local ai = a.load'ab'
local aj = a.load'O'

local ak = aa.atom
local al = ab.useSpring
local am = ad.useEffect
local an = ad.useRef
local ao = ac.useAtom
local ap = ad.createElement

local aq = ae.colors.window.element

local ar = 26
local as = 28
local at = 14
local au = 10






return function(av)	
local aw = av.ScopeId
	local ax = av.Progress

	local b = ao(ah.enabled)
	local c = ao(ah.scopes)

	local d = ao(aq.panel)
	local e = ao(aq.panelStroke)
	local f = ao(aq.textActive)
	local g = ao(aq.caption)

	local h = an(nil )
	if not h.current then
		h.current = ak(false)
	end
	local i = (h.current )
	
local j = ai(aq.surface, aq.accent, i, true)
	local k = ai(aq.thumb, aq.thumbActive, i, true)
	local l = ai(aq.surfaceStroke, aq.accentStrong, i)

	local m, n = al(0, aj.quick)

	local o = aw and (c[aw]) or (nil)
	local p = aw ~= nil and b[aw] == true

	am(function()
		i(p)
		n.setGoal(		n,p and 1 or 0)
	end, { p })

	if not o or not aw or aw == ag.GLOBAL_ID then
		return nil
	end

	local q = aw

	return ap("CanvasGroup", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ar),
		Position = ax.map(ax,function(r)
			return UDim2.fromOffset(0, math.floor((1 - r) * -10))
		end),
		GroupTransparency = ax.map(ax,function(r)
			return 1 - r
		end),
	}, {
		Panel = ap("Frame", {
			BackgroundColor3 = d,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -2, 1, -2),
			Position = UDim2.fromOffset(1, 1),
		}, {
			UICorner = ap("UICorner", {
				CornerRadius = UDim.new(0, 5),
			}),
			UIStroke = ap("UIStroke", {
				Color = e,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = ap("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 8),
			}),
			UIListLayout = ap("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			}),
			Editing = ap("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = "Editing",
				TextColor3 = g,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				FontFace = af.Get("font", "semi_bold"),
				LayoutOrder = 1,
			}),
			ScopeName = ap("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = o.label,
				TextColor3 = f,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				FontFace = af.Get("font", "semi_bold"),
				LayoutOrder = 2,
			}),
			Spacer = ap("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = 3,
			}, {
				UIFlexItem = ap("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
			}),
			ToggleGroup = ap("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(0, at),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 4,
			}, {
				UIListLayout = ap("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 5),
				}),
				Label = ap("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(0, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					Text = "Override Global",
					TextColor3 = g,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					FontFace = af.Get("font", "semi_bold"),
					LayoutOrder = 1,
				}),
				Switch = ap("TextButton", {
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(as, at),
					BackgroundColor3 = j.binding,
					Text = "",
					Active = false,
					AutoButtonColor = false,
					LayoutOrder = 2,
					[ad.Event.MouseEnter] = function()
						j.onMouseEnter()
						k.onMouseEnter()
					end,
					[ad.Event.MouseLeave] = function()
						j.onMouseLeave()
						k.onMouseLeave()
					end,
					[ad.Event.MouseButton1Click] = function()
						ag.ToggleScopeEnabled(q)
					end,
				}, {
					UIStroke = ap("UIStroke", {
						Color = l.binding,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = 1,
					}),
					UICorner = ap("UICorner", {
						CornerRadius = UDim.new(0, 8),
					}),
					UIPadding = ap("UIPadding", {
						PaddingLeft = UDim.new(0, 2),
						PaddingRight = UDim.new(0, 2),
						PaddingTop = UDim.new(0, 2),
						PaddingBottom = UDim.new(0, 2),
					}),
					Circle = ap("Frame", {
						BackgroundTransparency = 0,
						BackgroundColor3 = k.binding,
						Position = m.map(m,function(r)
							return UDim2.fromScale(r, 0)
						end),
						AnchorPoint = m.map(m,function(r)
							return Vector2.new(r, 0)
						end),
						BorderSizePixel = 0,
						Size = UDim2.fromOffset(au, au),
					}, {
						UICorner = ap("UICorner", {
							CornerRadius = UDim.new(1, 0),
						}),
					}),
				}),
			}),
		}),
	})
end
end function a.aX()
local aa = a.load'e'
local ab = a.load'd'
local ac = a.load'c'
local ad = a.load'n'
local ae = a.load'aR'
local af = a.load'N'
local ag = a.load'aW'
local ah = a.load'av'
local ai = a.load'aw'

local aj = ac.useEffect
local ak = ac.useState
local al = ac.useRef
local am = aa.useSpring
local an = ac.useMemo
local ao = ab.useAtom
local ap = ac.createElement

local aq = 1

local ar = af.colors.window.element

local as = ae.openTab









local function Container(at)	
local au = at.Container

	local av = ao(au._sections)

	local aw = an(function()
		return ad.Array.map(av, function(aw)
			return aw.Render(aw)
		end)
	end, { av })

	return ap(
		"Frame",
		{
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0.5, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		},
		ad.Dictionary.join({
			UIFlexItem = ap("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
				ItemLineAlignment = Enum.ItemLineAlignment.Automatic,
			}),
			UIListLayout = ap("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 9),
			}),
		}, aw)
	)
end

return function(at)	
local au = at.Tab

	local av = ao(ar.scrollThumb)

	local aw = ao(as) == au

	local ax = ao(au._customRenderer)
	local b = ao(au._headerAccessory)
	local c = ao(au._useScope)
	local d = ao(ah.currentScope)
	local e = c and d ~= ai.GLOBAL_ID

	local f, g = am(0, {
		tension = 700,
		friction = 50,
		precision = 0.01,
	})

	local h, i = ak(nil )

	aj(function()
		if c and d ~= ai.GLOBAL_ID then
			i(d)
		end
	end, { c, d } )

	aj(function()
		g.setGoal(		g,e and 1 or 0)
	end, { e })

	local j = c and h ~= nil
	local k = e and d or h

	local l = ao(au._containers)
	local m = an(function()
		if ax then
			return {}
		end
		return ad.Array.map(l, function(m)
			return ap(Container, {
				Container = m,
				IsOpen = aw,
			})
		end)
	end, { l, ax } )

	local n = an(function()
		if not ax then
			return nil
		end
		return ax.render(au)
	end, { ax, au } )

	local o = an(function()		
if not b then
			return nil
		end
		return b.render(au)
	end, { b, au } )

	local p, q = am(1, {
		friction = 52,
		tension = 950,
		precision = 0.01,
	})

	local r = al(nil )
	local s = al(nil )
	local t, u = ak(false)

	aj(function()
		q.setGoal(		q,aw and 0 or 1)
	end, { aw })

	aj(function()
		local v= {}
		local w = 0
		local x = false

		local function recompute()
			if x then
				return
			end
			local y = r.current
			local z = s.current
			if not y or not z then
				return
			end
			if y.AbsoluteSize.Y < 1 then
				return
			end
			local A = z.AbsoluteSize.Y > y.AbsoluteSize.Y + aq
			u(A)
		end

		local function tryConnect()
			if x then
				return
			end
			for y, z in v do
				z.Disconnect(				z)
			end
			while v[1] do
				table.remove(v, 1)
			end

			local y = r.current
			local z = s.current
			if not y or not z then
				w = w + 1
				if w < 8 then
					task.defer(tryConnect)
				end
				return
			end

			table.insert(v, y.GetPropertyChangedSignal(y, "AbsoluteSize"):Connect(recompute))
			table.insert(v, z.GetPropertyChangedSignal(z, "AbsoluteSize"):Connect(recompute))
			table.insert(v, y.GetPropertyChangedSignal(y, "CanvasSize"):Connect(recompute))
			task.defer(recompute)
			task.defer(recompute)
		end

		tryConnect()

		return function()
			x = true
			for y, z in v do
				z.Disconnect(				z)
			end
		end
	end, { aw, l } )

	local v = an(function()
		return p.map(p,function(v)
			return v
		end)
	end, { p } )

	local w = an(function()
		return p.map(p,function(w)
			return w < 0.99
		end)
	end, { p } )

	local x = an(function()
		return p.map(p,function(x)
			local y = x * 15
			return UDim2.fromOffset(8, 59 - y)
		end)
	end, { p } )

	local y = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -16, 1, -71),
		GroupTransparency = v,
		Visible = w,
		Position = x,
	}

	local z = o and 28 or 0
	local A = 34

	local B = an(function()
		return f.map(f,function(B)
			return UDim2.fromOffset(0, math.floor(z + B * A))
		end)
	end, { f, z } )
	local C = an(function()
		return f.map(f,function(C)
			return UDim2.new(1, 0, 1, -math.floor(z + C * A))
		end)
	end, { f, z } )

	local D = j
			and ap("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 26),
				Position = UDim2.fromOffset(0, 0),
				ZIndex = 4,
			}, {
				Bar = ap(ag, {
					ScopeId = k,
					Progress = f,
				}),
			})
		or nil

	if ax and n then
		return ap("CanvasGroup", y, {
			Custom = n,
			Accessory = o and ap("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(0, 22),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.new(1, 0, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				ZIndex = 5,
			}, {
				Accessory = o,
			}) or nil,
			OverrideBar = D,
		})
	end

	return ap("CanvasGroup", y, {
		Accessory = o and ap("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			Position = UDim2.new(1, 0, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
			ZIndex = 5,
		}, {
			Accessory = o,
		}) or nil,
		OverrideBar = D,
		Scroll = ap("ScrollingFrame", {
			ref = r,
			Active = false,
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = B,
			Size = C,
			ClipsDescendants = true,
			ScrollingEnabled = t,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			ScrollBarImageColor3 = av,
			ScrollBarThickness = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
		}, {
			Content = ap(
				"Frame",
				{
					ref = s,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
				},
				ad.Dictionary.join({
					UIListLayout = ap("UIListLayout", {
						VerticalAlignment = Enum.VerticalAlignment.Top,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						SortOrder = Enum.SortOrder.LayoutOrder,
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 12),
					}),
					UIPadding = ap("UIPadding", {
						PaddingLeft = UDim.new(0, 1),
						PaddingRight = UDim.new(0, 1),
						PaddingTop = UDim.new(0, 1),
						PaddingBottom = UDim.new(0, 1),
					}),
				}, m)
			),
		}),
	})
end
end function a.aY()
local aa = a.load'd'
local ab = a.load'c'
local ac = a.load's'
local ad = a.load'N'
local ae = a.load'n'

local af = aa.useAtom
local ag = ab.useMemo
local ah = ab.createElement

local ai = ad.colors.window.section





return function(aj)	
local ak = aj.Section

	local al = af(ak._elements)
	local am = af(ak._headerAccessory)

	local an = ag(function()
		local an = {}
		for ao, ap in next, al do
			an[ao] = ap.Render(ap,ao)
		end
		return an
	end, { al })

	local ao = ag(function()		
if not am then
			return nil
		end
		return am.Render(am,2)
	end, { am })

	local ap = af(ai.background)
	local aq = af(ai.stroke)
	local ar = af(ai.text)

	return ah("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		UIListLayout = ah("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		Header = ah("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 0,
		}, {
			UIListLayout = ah("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Title = ah("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = ac.Get("font", "semi_bold"),
				TextColor3 = ar,
				TextSize = 11,
				Text = ak._title,
				Size = UDim2.fromOffset(0, 14),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 0,
			}),
			Spacer = ah("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = 1,
			}, {
				UIFlexItem = ah("UIFlexItem", {
					FlexMode = Enum.UIFlexMode.Fill,
				}),
			}),
			Accessory = ao,
		}),
		Frame = ah(
			"Frame",
			{
				BackgroundColor3 = ap,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 34),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
			},
			ae.Dictionary.join({
				UIStroke = ah("UIStroke", {
					Color = aq,
					Thickness = 1,
				}),
				UICorner = ah("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
				UIPadding = ah("UIPadding", {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
				}),
				UIListLayout = ah("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Top,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 10),
				}),
			}, an)
		),
	})
end
end function a.aZ()a.load'aG'


local ab = {} 

return ab
end function a.a_()
local aa = a.load'c'
local ab = a.load'N'
local ac = a.load's'

local ad = a.load'ab'
local ae = a.load'aH'
local af = a.load'Y'
local ag = aa.createElement

local ah = ab.colors.window.element







return function(ai)	
local aj = ai.Options
	local ak = ai.TextRef
	local al = ai.LayoutOrder or 2

	local am = ad(ah.surface, ah.accent, aj._active)
	local an = ad(ah.surfaceStroke, ah.accentStrong, aj._active)
	local ao = ad(ah.icon, ah.iconActive, aj._active)

	ae(ak, { am }, {
		onClick = function()
			aj.Open(			aj,af.getPosition())
		end,
	})

	return ag("TextButton", {
		BackgroundColor3 = am.binding,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(30, 14),
		[aa.Event.MouseEnter] = function()
			am.onMouseEnter()
		end,
		[aa.Event.MouseLeave] = function()
			am.onMouseLeave()
		end,
		[aa.Event.MouseButton1Click] = function()
			aj.Open(			aj,af.getPosition())
		end,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		LayoutOrder = al,
	}, {
		ImageLabel = ag("ImageLabel", {
			BackgroundTransparency = 1,
			Image = ac.Get("image", "double_right_arrow"),
			ImageColor3 = ao.binding,
			Size = UDim2.fromOffset(8, 8),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
		}),
		UICorner = ag("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIStroke = ag("UIStroke", {
			Color = an.binding,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
	})
end
end function a.a0()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'n'

local ad = a.load'aG'
local ae = a.load'aQ'
local af = a.load'aZ'
local ag = a.load'a_'

local ah = aa.peek
local ai = aa.atom
local aj = ab.createElement

local ak = {}
ak.__index = ak

setmetatable(ak, { __index = ad })

local function constructor(al)	
local am = (ad.new(al) )
	
setmetatable(am, ak)

	am._elements = ai({} )

	return am
end

function ak.AddElement(al, am, ...)	
local an = af[am]
	if not an then
		return nil
	end

	local ao = an(...)
	local ap = ah(al._elements)
	al._elements(ac.Array.insert(ap, #ap + 1, ao))

	return ao
end

function ak.Open(al, am)	
ae.OpenOptions(al, am)
end

function ak.RenderInternal(al, am)	
return aj(ag, {
		Options = al,
		TextRef = am and am.textRef,
		LayoutOrder = am and am.layoutOrder,
	})
end








return constructor
end function a.a1()
local aa = a.load'm'

local ab = aa.atom
local ac = aa.peek

local ad = {
	color = ab(nil ),
	transparency = ab(nil ),
}

function ad.set(ae, af)	
ad.color(ae)
	ad.transparency(af)
end

function ad.peek()	
return ac(ad.color), ac(ad.transparency)
end

function ad.has()	
return ac(ad.color) ~= nil
end

return ad
end function a.a2()
local aa = a.load'c'
local ab = a.load'e'
local ac = a.load'd'
local ad = a.load'm'
local ae = a.load'aQ'
local af = a.load'Y'
local ag = a.load'_'
local ah = a.load'a1'
local ai = a.load'O'
local aj = a.load'ac'

local ak = aa.useEffect
local al = ab.useSpring
local am = aa.useState
local an = aa.useRef
local ao = ac.useAtom
local ap = aa.useMemo
local aq = ad.peek
local ar = aa.createElement

local function toSequence(as)	
if as == nil then
		return nil
	end
	if typeof(as) == "ColorSequence" then
		return as
	end
	return ColorSequence.new{
		ColorSequenceKeypoint.new(0, as),
		ColorSequenceKeypoint.new(1, as),
	}
end







return function(as)	
local at = as.Colorpicker
	local au = as.LayoutOrder or 1

	local av, aw = am(false)
	local ax = ao(at._state)
	local b = ao(ah.color)
	local c = ao(ah.transparency)

	local d, e = am(nil )

	local f = ap(function()
		return (toSequence(ax) )	
end, { ax })

	local g = ap(function()
		return toSequence(d)
	end, { d })

	local h, i = al(0, {
		tension = 750,
		friction = 55,
	})

	local j, k = al(0, ai.smoothPrecise)

	ak(function()
		i.setGoal(		i,av and 1 or 0)
	end, { av })

	ak(function()
		k.setGoal(		k,d and 1 or 0)
	end, { d })

	local l = an(nil )

	ak(function()
		local m = l.current
		if m then
			m.SetAttribute(			m,"ConsumesRightClick", true)
		end
	end, {})

	local m = ag(function()
		local m = b
			and (typeof(b) == "ColorSequence") == at._isSequence

		local n= {
			{
				Label = "Copy color",
				Callback = function()
					local n = aq(at._state)
					local o					
if at._supportsTransparency then
						o = aq(at._transparency)
					end
					ah.set(n, o)
				end,
			},
		}
		if m then
			table.insert(n, {
				Label = "Paste color",
				Callback = function()
					at._state(b)
					if at._supportsTransparency and c ~= nil then
						at._transparency(c)
					end
				end,
				OnHoverEnter = function()
					e(b)
				end,
				OnHoverLeave = function()
					e(nil)
				end,
			})
		end
		return n
	end, at)

	return ar("TextButton", {
		ref = l,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(12, 12),
		[aa.Event.MouseEnter] = function()
			aw(true)
		end,
		[aa.Event.MouseLeave] = function()
			aw(false)
		end,
		[aa.Event.MouseButton1Click] = function()
			ae.OpenColorpicker(at, af.getPosition())
		end,
		[aa.Event.InputBegan] = aj(m),
		Text = "",
		Active = false,
		AutoButtonColor = false,
		LayoutOrder = au,
	}, {
		UIGradient = ar("UIGradient", {
			Color = f,
		}),
		UICorner = ar("UICorner", {
			CornerRadius = UDim.new(0, 3),
		}),
		UIStroke = ar("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = 0.5,
			Thickness = h.map(h,function(n)
				return 1.05 + n
			end),
		}, {
			UIGradient = ar("UIGradient", {
				Color = f,
			}),
		}),
		Preview = g and ar("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = j.map(j,function(n)
				return 1 - n
			end),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			UICorner = ar("UICorner", {
				CornerRadius = UDim.new(0, 3),
			}),
			UIGradient = ar("UIGradient", {
				Color = g,
			}),
			UIStroke = ar("UIStroke", {
				Color = Color3.fromRGB(255, 255, 255),
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Transparency = j.map(j,function(n)
					return 1 - n * 0.5
				end),
				Thickness = h.map(h,function(n)
					return 1.05 + n
				end),
			}, {
				UIGradient = ar("UIGradient", {
					Color = g,
				}),
			}),
		}) or nil,
	})
end
end function a.a3()
local aa = (cloneref(game.GetService(game, "RunService")) )
local ab = a.load'm'
local ac = a.load'ad'

local ad = ab.peek

local ae = {}



local af= (setmetatable({}, { __mode = "k" }) )
local ag

local ah = LPH_NO_VIRTUALIZE(function()	
local ah = os.clock()
	for ai in next, af do
		ai._setCurrent(ac.apply({
			color = ad(ai._state),
			rotation = ad(ai._rotation),
			transparency = ad(ai._transparency),
			speed = ad(ai._speed),
			time = ah,
		}, ad(ai._animation)))
	end
end)

local function ensureLoop()	
if ag then
		return
	end
	if not next(af) then
		return
	end
	ag = aa.PreRender:Connect(ah)
end

local function teardownLoop()	
if not ag then
		return
	end
	if next(af) then
		return
	end
	ag.Disconnect(	ag)
	ag = nil
end

function ae.computeStatic(ai)	
return {
		color = ad(ai._state),
		rotation = ad(ai._rotation),
		transparency = ad(ai._transparency) or 0,
	}
end

function ae.register(ai)	
af[ai] = true
	ensureLoop()
end

function ae.unregister(ai)	
af[ai] = nil
	teardownLoop()
end

return ae
end function a.a4()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'aG'
local ad = a.load'a2'
local ae = a.load'a3'
local af = a.load'ad'

local ag = aa.atom
local ah = aa.peek
local ai = aa.subscribe
local aj = ab.createElement
local ak = ab.createBinding
local al = (ab ).__subscribeToBinding

local am = {}
am.__index = am

setmetatable(am, { __index = ac })




local function colorFromCurrent(an)	
local ao = an.color
	if typeof(ao) == "ColorSequence" then
		local ap = ao.Keypoints[1]
		return if ap then ap.Value else Color3.fromRGB(255, 255, 255)
	end
	return ao
end

local function gradientFromCurrent(an)	
local ao = an.color
	if typeof(ao) == "ColorSequence" then
		return ao
	end
	return ColorSequence.new(ao )
end

local function rotationFromCurrent(an)	
return an.rotation
end

local function transparencyFromCurrent(an)	
return an.transparency
end

local function constructor(an, ao, ap)	
local aq = (ac.new(an) )
	
setmetatable(aq, am)

	aq._transparency = ag(ap)
	aq._supportsTransparency = ap ~= nil
	aq._isSequence = ao and typeof(ao) == "ColorSequence" or false
	aq._state = ag(ao or Color3.fromRGB(255, 255, 255))
	aq._rotation = ag(0)
	aq._animation = ag("none" )
	aq._speed = ag(1)

	local ar, as = ak(ae.computeStatic(aq))
	aq._current = ar
	aq._setCurrent = as

	aq._currentColor = ar.map(ar,colorFromCurrent)
	aq._currentGradient = ar.map(ar,gradientFromCurrent)
	aq._currentRotation = ar.map(ar,rotationFromCurrent)
	aq._currentTransparency = ar.map(ar,transparencyFromCurrent)

	local function syncStatic()		
aq._setCurrent(ae.computeStatic(aq))
	end

	ai(aq._state, function()		
if ah(aq._animation) == "none" then
			syncStatic()
		end
	end)
	ai(aq._transparency, function()		
if ah(aq._animation) == "none" then
			syncStatic()
		end
	end)
	ai(aq._rotation, function()		
if ah(aq._animation) == "none" then
			syncStatic()
		end
	end)
	ai(aq._animation, function(at)		
if at == "none" then
			ae.unregister(aq)
			syncStatic()
		else
			ae.register(aq)
		end
	end)

	if ah(aq._animation) ~= "none" then
		ae.register(aq)
	end

	return aq
end

function am.SetState(an, ao)	
an._state(ao)
end

function am.SetTransparency(an, ao)	
an._transparency(ao)
end

function am.SetRotation(an, ao)	
an._rotation(ao)
end

function am.SetAnimation(an, ao)	
if not af.appliesTo(ao, an._isSequence, an._supportsTransparency) then
		return
	end
	an._animation(ao)
end

function am.SetSpeed(an, ao)	
an._speed(ao)
end

function am.OnColorChange(an, ao)	
return ai(an._state, ao)
end

function am.OnTransparencyChange(an, ao)	
return ai(an._transparency, ao)
end

function am.PeekColor(an)	
return ah(an._state)
end

function am.PeekTransparency(an)	
return ah(an._transparency)
end

function am.GetColor(an)	
return ((an._currentColor )):getValue()
end

function am.GetGradient(an)	
return ((an._currentGradient )):getValue()
end

function am.GetTransparency(an)	
return ((an._currentTransparency )):getValue()
end

function am.GetRotation(an)	
return ((an._currentRotation )):getValue()
end








function am.GetSnapshot(an)	
return {
		color = an.GetColor(an),
		gradient = an.GetGradient(an),
		transparency = an.GetTransparency(an),
		rotation = an.GetRotation(an),
	}
end

function am.OnUpdate(an, ao)	
return al(an._current, function()		
ao(an.GetSnapshot(an))
	end)
end

function am.RenderInternal(an, ao)	
return aj(ad, {
		Colorpicker = an,
		TextRef = ao and ao.textRef,
		LayoutOrder = ao and ao.layoutOrder,
	})
end






















return constructor
end function a.a5()
local aa = a.load'c'
local ab = a.load'd'
local ac = a.load'e'
local ad = a.load'n'

local ae = a.load's'
local af = a.load'N'
local ag = a.load'ab'
local ah = a.load'_'
local ai = a.load'aa'
local aj = a.load'ac'
local ak = a.load'O'

local al = aa.useState
local am = aa.useRef
local an = aa.useMemo
local ao = aa.useEffect
local ap = ac.useSpring
local aq = ab.useAtom
local ar = aa.createElement

local as = af.colors.window.element

local at = 1
local au = 6
local av = 10
local aw = 4
local ax = 4
local b = 6
local c = 6
local d = 0.2
local e = 6
local f = (au + 2) / au








local function formatAxisValue(g)	
if g == math.floor(g) then
		return tostring(math.floor(g))
	end
	return string.format("%.2f", g):gsub("0+$", ""):gsub("%.$", "")
end

local function hitTestPoints(g, h, i)	
local j = h.Position.X - g.AbsolutePosition.X
	local k = h.Position.Y - g.AbsolutePosition.Y
	local l = g.AbsoluteSize.X
	local m = g.AbsoluteSize.Y

	for n, o in i do
		local p = o.x * l
		local q = (1 - o.y) * m
		local r = j - p
		local s = k - q
		if r * r + s * s <= av * av then
			return n
		end
	end
	return nil
end











local function Point(g)	
local h = g.Curve
	local i = g.Index
	local j = g.Point
	local k = g.IsActive
	local l = g.IsEndpoint
	local m = g.SurfaceRef
	local n = g.OnHoverEnter

	local o = k and as.thumbHighlight or as.thumbActive
	local p = aq(o)
	local q = aq(as.thumbStroke)

	local r, s = al(false)
	ao(function()
		s(true)
	end, {})

	local t = not r and (k or f) or 1
	local u, v = ap(0, ak.smooth)
	ao(function()
		v.setGoal(		v,t)
	end, { t })

	local w = ai(function(w)
		h.MovePoint(		h,i, w.X, 1 - w.Y)
	end)

	local x = ah(function()
		if l then
			return nil
		end
		return {
			{
				Label = "Delete Point",
				Icon = ae.Get("image", "delete"),
				Callback = function()
					h.RemovePoint(					h,i)
				end,
			},
		}
	end, h)

	local y = am(nil )

	ao(function()
		local z = y.current
		if z then
			z.SetAttribute(			z,"ConsumesRightClick", true)
		end
	end, {})

	return ar("TextButton", {
		ref = y,
		Size = UDim2.fromOffset(au, au),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(j.x, 1 - j.y),
		BackgroundColor3 = p,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 3,
		[aa.Event.MouseEnter] = function()
			n(i)
		end,
		[aa.Event.InputBegan] = aj(function(z, A)
			if A.UserInputType == Enum.UserInputType.MouseButton1 then
				if k then
					h.SetActivePoint(					h,nil)
				else
					h.SetActivePoint(					h,i)
				end
				local B = m.current
				if B then
					w(B, A)
				end
				return
			end
			x(z, A)
		end),
	}, {
		UIScale = ar("UIScale", {
			Scale = u,
		}),
		UICorner = ar("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		UIStroke = ar("UIStroke", {
			Color = q,
			Thickness = 1,
		}),
	})
end

local function buildGrid(g)	
local h= {}

	for i = 1, aw - 1 do
		local j = i / aw
		h[`VLine_{i}`] = ar("Frame", {
			Size = UDim2.new(0, 1, 1, 0),
			Position = UDim2.fromScale(j, 0),
			BackgroundColor3 = g,
			BorderSizePixel = 0,
			ZIndex = 1,
		})
	end

	for i = 1, ax - 1 do
		local j = i / ax
		h[`HLine_{i}`] = ar("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromScale(0, j),
			BackgroundColor3 = g,
			BorderSizePixel = 0,
			ZIndex = 1,
		})
	end

	return h
end

local function buildCurveSegments(
	g,
	h,
	i
)	
local j= {}

	if #g < 2 or h.X <= 0 or h.Y <= 0 then
		return j
	end

	local k = h.X
	local l = h.Y

	for m = 1, #g - 1 do
		local n = g[m]
		local o = g[m + 1]

		local p = n.x * k
		local q = (1 - n.y) * l
		local r = o.x * k
		local s = (1 - o.y) * l

		local t = r - p
		local u = s - q
		local v = math.sqrt(t * t + u * u)
		if v <= 0 then
			continue
		end

		j[`Seg_{m}`] = ar("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((p + r) / 2, (q + s) / 2),
			Size = UDim2.fromOffset(v + 1, at),
			Rotation = math.deg(math.atan2(u, t)),
			BackgroundColor3 = i,
			BorderSizePixel = 0,
			ZIndex = 2,
		})
	end

	return j
end

return function(g)	
local h = g.CurveEditor
	local i = g.LayoutOrder or 2

	local j = aq(h._state) or {}
	local k = aq(h._activeIdx)
	local l = aq(h._text)

	local m = am(nil )
	local n, o = al(Vector2.new(280, h._height - b * 2))
	local p, q = al(nil )
	local r, s = al(false)
	local t = am(false)
	t.current = r

	local u, v = ap(0, ak.smooth)
	ao(function()
		v.setGoal(		v,r and 1 or 0)
	end, { r })

	ao(function()
		s(false)
		if not (p and p.Kind == "curve") then
			return nil
		end
		local w = false
		task.delay(d, function()
			if not w then
				s(true)
			end
		end)
		return function()
			w = true
		end 	
end, { p } )

	ao(function()
		local w = m.current
		if not w then
			return nil
		end

		o(w.AbsoluteSize)
		local x = w.GetPropertyChangedSignal(w, "AbsoluteSize"):Connect(function()
			o(w.AbsoluteSize)
		end)

		return function()
			x.Disconnect(			x)
		end 	
end, {})

	local w = aq(as.panel)
	local x = aq(as.panelStroke)
	local y = aq(as.surface)
	local z = aq(as.accentStrong)
	local A = aq(as.thumbActive)
	local B = aq(as.caption)
	local C = ag(as.text, as.textActive, h._active)

	local D = an(function()
		return buildCurveSegments(j, n, z)
	end, { j, n, z } )

	local E = an(function()
		return buildGrid(y)
	end, { y })

	local function setPointHover(F)
		q({ Kind = "point", Index = F } )
	end

	local function setCurveHoverFromInput(F)
		local G = m.current
		if not G then
			return
		end
		local H = hitTestPoints(G, F, j)
		if H then
			q({ Kind = "point", Index = H } )
			return
		end
		local I = F.Position.X - G.AbsolutePosition.X
		local J = F.Position.Y - G.AbsolutePosition.Y
		local K = G.AbsoluteSize.X
		local L = G.AbsoluteSize.Y
		if K <= 0 or L <= 0 then
			return
		end
		local M = math.clamp(I / K, 0, 1)
		local N = 1 - math.clamp(J / L, 0, 1)
		local O = h.SampleNormalized(h,M)
		q({ Kind = "curve", X = M, Y = O, CursorY = N } )
	end

	local F= {}
	for G, H in j do
		F[`Point_{G}`] = ar(Point, {
			Curve = h,
			Index = G,
			Point = H,
			IsActive = G == k,
			IsEndpoint = G == 1 or G == #j,
			SurfaceRef = m,
			OnHoverEnter = setPointHover,
		})
	end

	local G = formatAxisValue(h._xMin) .. h._xSuffix
	local H = formatAxisValue(h._xMax) .. h._xSuffix

	local I = ""
	if p then
		local J		
local K		
if p.Kind == "point" then
			local L = p.Index and j[p.Index]
			if L then
				J, K = L.x, L.y
			end
		elseif p.Kind == "curve" then
			J, K = p.X, p.Y
		end

		if J and K then
			local L = h._xMin + J * (h._xMax - h._xMin)
			local M = h._min + K * (h._max - h._min)
			I = formatAxisValue(L) .. h._xSuffix .. ", " .. formatAxisValue(M) .. h._ySuffix
		end
	end

	local J= {}
	if p and p.Kind == "curve" and p.X and p.CursorY then
		J.Ghost = ar("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(p.X, 1 - p.CursorY),
			Size = UDim2.fromOffset(au, au),
			BackgroundColor3 = A,
			BackgroundTransparency = u.map(u,function(K)				
return 1 - K * 0.5
			end),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			UIScale = ar("UIScale", {
				Scale = u.map(u,function(K)					
return 0.5 + K * 0.5
				end),
			}),
			UICorner = ar("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			UIStroke = ar("UIStroke", {
				Color = z,
				Thickness = 1,
				Transparency = u.map(u,function(K)					
return 1 - K * 0.65
				end),
			}),
			Glow = ar("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(au + e, au + e),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, {
				UICorner = ar("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
				UIStroke = ar("UIStroke", {
					Color = z,
					Thickness = 1,
					Transparency = u.map(u,function(K)						
return 1 - K * 0.2
					end),
				}),
			}),
		})
	end

	return ar("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = i,
	}, {
		UIListLayout = ar("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = ar("TextButton", {
			BackgroundTransparency = 1,
			FontFace = ae.Get("font", "semi_bold"),
			TextColor3 = C.binding,
			TextSize = 13,
			Text = l,
			Size = UDim2.new(1, 0, 0, 14),
			LayoutOrder = 0,
			AutoButtonColor = false,
			Active = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			[aa.Event.MouseEnter] = function()
				C.onMouseEnter()
			end,
			[aa.Event.MouseLeave] = function()
				C.onMouseLeave()
			end,
		}, {
			PointLabel = ar("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = ae.Get("font", "semi_bold"),
				TextColor3 = C.binding,
				TextSize = 13,
				Text = I,
				Size = UDim2.new(1, 0, 0, 14),
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}),
		Canvas = ar("TextButton", {
			Size = UDim2.new(1, 0, 0, h._height),
			BackgroundColor3 = w,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			AutoButtonColor = false,
			Text = "",
			Active = false,
			ClipsDescendants = true,
			[aa.Event.InputBegan] = aj(function(K, L)
				if L.UserInputType == Enum.UserInputType.MouseButton1 then
					local M = m.current
					if M and hitTestPoints(M, L, j) == nil then
						if t.current then
							local N = L.Position.X - M.AbsolutePosition.X
							local O = L.Position.Y - M.AbsolutePosition.Y
							local P = M.AbsoluteSize.X
							local Q = M.AbsoluteSize.Y
							local R = P > 0 and (math.clamp(N / P, 0, 1)) or 0
							local S = Q > 0 and (1 - math.clamp(O / Q, 0, 1)) or 0
							local T = h.AddPoint(h,R, S)
							if T then
								h.SetActivePoint(								h,T)
							end
							s(false)
						else
							h.SetActivePoint(							h,nil)
						end
					end
					return
				end
			end),
			[aa.Event.InputChanged] = function(K, L)
				if L.UserInputType == Enum.UserInputType.MouseMovement then
					setCurveHoverFromInput(L)
				end
			end,
			[aa.Event.MouseLeave] = function()
				q(nil )
			end,
		}, {
			UICorner = ar("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			UIStroke = ar("UIStroke", {
				Color = x,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			AxisLeft = ar("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = ae.Get("font", "semi_bold"),
				TextColor3 = B,
				TextSize = 11,
				Text = G,
				Size = UDim2.fromOffset(0, 12),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.fromOffset(c, c),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 4,
			}),
			AxisRight = ar("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = ae.Get("font", "semi_bold"),
				TextColor3 = B,
				TextSize = 11,
				Text = H,
				Size = UDim2.fromOffset(0, 12),
				AutomaticSize = Enum.AutomaticSize.X,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -c, 0, c),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 4,
			}),
			Surface = ar("Frame", {
				ref = m,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(b, b),
				Size = UDim2.new(1, -b * 2, 1, -b * 2),
			}, ad.Dictionary.join({}, E, D, J, F)),
		}),
	})
end
end function a.a6()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'aG'
local ad = a.load'a5'

local ae = aa.peek
local af = aa.subscribe
local ag = aa.atom
local ah = ab.createElement

local ai = {}
ai.__index = ai

setmetatable(ai, { __index = ac })

local aj = 256



local function lerp(ak, al, am)	
return ak + (al - ak) * am
end

local function buildLut(ak)	
local al = table.create(aj)

	if #ak == 0 then
		for am = 1, aj do
			al[am] = 0
		end
		return al
	end

	if #ak == 1 then
		for am = 1, aj do
			al[am] = ak[1].y
		end
		return al
	end

	for am = 0, aj - 1 do
		local an = am / (aj - 1)

		local ao = #ak - 1
		for ap = 1, #ak - 1 do
			if an <= ak[ap + 1].x then
				ao = ap
				break
			end
		end

		local ap = ak[ao]
		local aq = ak[ao + 1]
		local ar = aq.x - ap.x
		local as = ar > 0 and ((an - ap.x) / ar) or (0)

		al[am + 1] = math.clamp(lerp(ap.y, aq.y, as), 0, 1)
	end

	return al
end

local function sortPoints(ak)	
local al = table.clone(ak)
	table.sort(al, function(am, an)
		return am.x < an.x
	end)
	return al
end

local function clampPoint(ak)	
return {
		x = math.clamp(ak.x, 0, 1),
		y = math.clamp(ak.y, 0, 1),
	}
end

local ak= {
	linear = {
		{ x = 0, y = 0 },
		{ x = 1, y = 1 },
	},
	easeIn = {
		{ x = 0, y = 0 },
		{ x = 0.7, y = 0.15 },
		{ x = 1, y = 1 },
	},
	easeOut = {
		{ x = 0, y = 0 },
		{ x = 0.3, y = 0.85 },
		{ x = 1, y = 1 },
	},
	sCurve = {
		{ x = 0, y = 0 },
		{ x = 0.3, y = 0.1 },
		{ x = 0.7, y = 0.9 },
		{ x = 1, y = 1 },
	},
}

local function clonePreset(al)	
local am = ak[al] or ak.linear
	local an = table.create(#am)
	for ao, ap in am do
		an[ao] = { x = ap.x, y = ap.y }
	end
	return an
end

local function constructor(al, am, an, ao)	
local ap = (ac.new(al) )
	
setmetatable(ap, ai)

	ap._bindable(true)

	ap._min = am
	ap._max = an
	ap._xMin = 0
	ap._xMax = 1
	ap._xSuffix = ""
	ap._ySuffix = ""
	ap._height = 100
	ap._lut = ag({} )
	ap._activeIdx = ag(nil )

	af(ap._state, function(aq)
		if aq then
			ap._lut(buildLut(aq))
		end
	end)

	ap._state(ao or clonePreset"linear")

	return ap
end

function ai.SetXRange(al, am, an, ao)	
al._xMin = am
	al._xMax = an
	al._xSuffix = ao or ""
	return al
end

function ai.SetYSuffix(al, am)	
al._ySuffix = am
	return al
end

function ai.SetHeight(al, am)	
al._height = math.max(40, am)
	return al
end

function ai.SetPoints(al, am)	
local an= {}
	for ao, ap in am do
		table.insert(an, clampPoint(ap))
	end
	an = sortPoints(an)

	if #an >= 2 then
		an[1] = { x = 0, y = an[1].y }
		an[#an] = { x = 1, y = an[#an].y }
	end

	al._state(an)
end

function ai.AddPoint(al, am, an)	
local ao = ae(al._state)
	if not ao then
		return nil
	end

	local ap = math.clamp(am, 0.001, 0.999)
	local aq = math.clamp(an, 0, 1)

	local ar = table.clone(ao)
	table.insert(ar, { x = ap, y = aq })

	local as = sortPoints(ar)
	al._state(as)

	for at, au in as do
		if au.x == ap and au.y == aq then
			return at
		end
	end
	return nil
end

function ai.RemovePoint(al, am)	
local an = ae(al._state)
	if not an then
		return
	end
	if am <= 1 or am >= #an then
		return
	end

	local ao = table.clone(an)
	table.remove(ao, am)
	al._state(ao)

	local ap = ae(al._activeIdx)
	if ap == am then
		al._activeIdx(nil)
	elseif ap and ap > am then
		al._activeIdx(ap - 1)
	end
end

function ai.MovePoint(al, am, an, ao)	
local ap = ae(al._state)
	if not ap then
		return
	end
	local aq = ap[am]
	if not aq then
		return
	end

	local ar = math.clamp(ao, 0, 1)
	local as
	if am == 1 then
		as = 0
	elseif am == #ap then
		as = 1
	else
		local at = ap[am - 1].x + 0.001
		local au = ap[am + 1].x - 0.001
		as = math.clamp(an, at, au)
	end

	local at = table.clone(ap)
	at[am] = { x = as, y = ar }
	al._state(at)
end

function ai.SetActivePoint(al, am)	
al._activeIdx(am)
end

function ai.Reset(al, am)	
al.SetPoints(	al,clonePreset(am or "linear"))
	al._activeIdx(nil)
end

function ai.Sample(al, am)	
local an = ae(al._lut)
	if #an == 0 then
		return al._min
	end

	local ao = al._xMax - al._xMin
	local ap = ao > 0 and (math.clamp((am - al._xMin) / ao, 0, 1)) or (0)

	local aq = ap * (aj - 1)
	local ar = math.floor(aq) + 1
	local as = math.min(ar + 1, aj)
	local at = aq - math.floor(aq)

	local au = lerp(an[ar], an[as], at)
	return al._min + au * (al._max - al._min)
end

function ai.SampleNormalized(al, am)	
local an = ae(al._lut)
	if #an == 0 then
		return 0
	end

	local ao = math.clamp(am, 0, 1)
	local ap = ao * (aj - 1)
	local aq = math.floor(ap) + 1
	local ar = math.min(aq + 1, aj)
	local as = ap - math.floor(ap)

	return lerp(an[aq], an[ar], as)
end

function ai.Render(al, am)	
return ah(ad, {
		CurveEditor = al,
		LayoutOrder = am,
	})
end

function ai.RenderInternal(al, am)	
return ah(ad, {
		CurveEditor = al,
		LayoutOrder = am and am.layoutOrder,
	})
end


















return constructor
end function a.a7()
local aa = a.load'c'
local ab = a.load'e'
local ac = a.load'd'
local ad = a.load'm'

local ae = a.load's'
local af = a.load'N'
local ag = a.load'ab'
local ah = a.load'aH'
local ai = a.load'Y'
local aj = a.load'O'

local ak = ab.useSpring
local al = aa.useEffect
local am = aa.useMemo
local an = aa.useCallback
local ao = ac.useAtom
local ap = ad.peek
local aq = aa.createElement

local ar = af.colors.window.element







return function(as)	
local at = as.Dropdown
	local au = as.TextRef
	local av = as.LayoutOrder or 2

	local aw = ao(at._label)
	local ax = ao(at._placeholder)
	local b = ao(at._open)

	local c = ag(ar.panel, ar.surface, at._open)
	local d = ag(ar.panelStroke, ar.accentStrong, at._open)
	local e = ag(ar.icon, ar.iconActive, at._open)
	local f = ag(ar.caption, ar.text, at._active)

	local g, h = ak(0, aj.snap)

	al(function()
		h.setGoal(		h,b and 1 or 0)
	end, { b })

	local i = aa.useRef(at)
	i.current = at

	local j = an(function()		
local j = i.current
		if ap(j._open) then
			j.Close(			j)
		elseif not j.WasJustClosed(j) then
			j.Open(			j,ai.getPosition())
		end
	end, {})

	local k = am(function()
		return { c, d, e, f }
	end, { c, d, e, f } )

	local l = am(function()
		return { onClick = j }
	end, { j } )

	ah(au, k, l)

	local m = am(function()
		return function()
			c.onMouseEnter()
			d.onMouseEnter()
			e.onMouseEnter()
			f.onMouseEnter()
		end
	end, { c, d, e, f } )

	local n = am(function()
		return function()
			c.onMouseLeave()
			d.onMouseLeave()
			e.onMouseLeave()
			f.onMouseLeave()
		end
	end, { c, d, e, f } )

	local o = am(function()
		return g.map(g,function(o)
			return o * 180
		end)
	end, { g } )

	local p = aw == "" and (ax) or (aw)

	return aq("TextButton", {
		BorderSizePixel = 0,
		Size = UDim2.new(0, 114, 0, 16),
		LayoutOrder = av,
		BackgroundColor3 = c.binding,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		[aa.Event.MouseEnter] = m,
		[aa.Event.MouseLeave] = n,
		[aa.Event.MouseButton1Click] = j,
	}, {
		UIStroke = aq("UIStroke", {
			Color = d.binding,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UICorner = aq("UICorner", {
			CornerRadius = UDim.new(0, 3),
		}),
		UIPadding = aq("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		}),
		Image = aq("ImageLabel", {
			Size = UDim2.fromOffset(8, 8),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Image = ae.Get("image", "down_arrow"),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ImageColor3 = e.binding,
			Rotation = o,
		}),
		Text = aq("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = ae.Get("font", "semi_bold"),
			TextColor3 = f.binding,
			TextSize = 12,
			Text = p,
			Size = UDim2.new(1, -12, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
	})
end
end function a.a8()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'n'

local ad = a.load'aG'
local ae = a.load'aQ'
local af = a.load'a7'

local ag = aa.atom
local ah = aa.peek
local ai = aa.subscribe
local aj = ab.createElement

local ak = {}
ak.__index = ak

setmetatable(ak, { __index = ad })

local function asMultiList(al)	
if type(al) ~= "table" then
		return {}
	end
	local am= {}
	for an, ao in al do
		if type(ao) == "string" then
			table.insert(am, ao)
		end
	end
	return am
end

local function arrayEquals(al, am)	
if #al ~= #am then
		return false
	end
	for an = 1, #al do
		if al[an] ~= am[an] then
			return false
		end
	end
	return true
end

local function buildLabel(al)	
local am = ah(al._placeholder)
	local an = ah(al._mode)
	local ao = ah(al._state)

	if an == "multi" then
		local ap = asMultiList(ao)
		if #ap == 0 then
			return am
		end
		if #ap <= 2 then
			return table.concat(ap, ", ")
		end
		return `{ap[1]}, {ap[2]}, +{#ap - 2}`
	end

	if type(ao) == "string" and ao ~= "" then
		return ao
	end
	return am
end

local function clampSelection(al)	
local am = ah(al._options)
	local an= {}
	for ao, ap in am do
		an[ap] = true
	end

	local ao = ah(al._mode)

	if ao == "multi" then
		local ap = asMultiList(ah(al._state))
		local aq= {}
		for ar, as in ap do
			if an[as] then
				table.insert(aq, as)
			end
		end

		local ar = ah(al._max)
		if ar and #aq > ar then
			while #aq > ar do
				table.remove(aq)
			end
		end

		local as = ah(al._min)
		if as and #aq < as then
			for at, au in am do
				if #aq >= as then
					break
				end
				local av = false
				for aw, ax in aq do
					if ax == au then
						av = true
						break
					end
				end
				if not av then
					table.insert(aq, au)
				end
			end
		end

		if not arrayEquals(aq, ap) then
			al._state(aq)
		end
		return
	end

	local ap = ah(al._state)
	if type(ap) == "string" and an[ap] then
		return
	end
	local aq = am[1] and (am[1]) or ("")
	if ap ~= aq then
		al._state(aq)
	end
end

local function constructor(al, am, an)	
local ao = (ad.new(al) )	
setmetatable(ao, ak)

	ao._bindable(true)

	ao._options = ag(am or {} )
	ao._mode = ag("single" )
	ao._min = ag(0)
	ao._max = ag(nil )
	ao._placeholder = ag"Select..."	
ao._open = ag(false)
	ao._label = ag""
	
if an ~= nil then
		ao._state(an)
	end

	clampSelection(ao)
	ao._label(buildLabel(ao))
	ao._active(buildLabel(ao) ~= ah(ao._placeholder))

	local function refresh()		
clampSelection(ao)
		ao._label(buildLabel(ao))

		local ap = ah(ao._mode)
		if ap == "multi" then
			ao._active(#asMultiList(ah(ao._state)) > 0)
		else
			local aq = ah(ao._state)
			ao._active(type(aq) == "string" and aq ~= "")
		end
	end

	ai(ao._state, refresh)
	ai(ao._options, refresh)
	ai(ao._mode, refresh)
	ai(ao._min, refresh)
	ai(ao._max, refresh)
	ai(ao._placeholder, function()
		ao._label(buildLabel(ao))
	end)

	return ao
end

function ak.SetOptions(al, am)	
al._options(am)
	return al
end

function ak.SetMode(al, am)	
al._mode(am)
	return al
end

function ak.SetMin(al, am)	
al._min(am)
	return al
end

function ak.SetMax(al, am)	
al._max(am)
	return al
end

function ak.SetPlaceholder(al, am)	
al._placeholder(am)
	return al
end

function ak.SetSelected(al, am)	
al._state(am)
	return al
end

function ak.Toggle(al, am)	
local an = ah(al._options)
	local ao = false
	for ap, aq in an do
		if aq == am then
			ao = true
			break
		end
	end
	if not ao then
		return
	end

	local ap = ah(al._mode)
	if ap == "multi" then
		local aq = asMultiList(ah(al._state))
		local ar		
for as, at in aq do
			if at == am then
				ar = as
				break
			end
		end

		if ar then
			local as = ah(al._min)
			if as and #aq <= as then
				return
			end
			al._state(ac.Array.removeIndex(aq, ar))
		else
			local as = ah(al._max)
			if as and #aq >= as then
				return
			end
			al._state(ac.Array.push(aq, am))
		end
		return
	end

	if ah(al._state) == am then
		return
	end
	al._state(am)
	al.Close(	al)
end

function ak.IsSelected(al, am)	
local an = ah(al._mode)
	if an == "multi" then
		for ao, ap in asMultiList(ah(al._state)) do
			if ap == am then
				return true
			end
		end
		return false
	end
	return ah(al._state) == am
end

function ak.Open(al, am)	
ae.OpenDropdown(al, am)
end

function ak.Close(al)	
ae.CloseDropdown(al)
end

function ak.WasJustClosed(al)	
return ae.WasDropdownJustClosedFor(al)
end

function ak.RenderInternal(al, am)	
return aj(af, {
		Dropdown = al,
		TextRef = am and am.textRef,
		LayoutOrder = am and am.layoutOrder,
	})
end

function ak.CreateTargetProxy(al, am)	
local an = ah(al._options)
	local ao = ah(al._mode)
	local ap= am
	if ap == nil then
		ap = ah(al._state)
	end

	local aq = constructor("", an, ap)
	aq.SetMode(	aq,ao)
	local ar = ah(al._min)
	local as = ah(al._max)
	if ar then
		aq.SetMin(		aq,ar)
	end
	if as then
		aq.SetMax(		aq,as)
	end
	return aq
end














return constructor
end function a.a9()
local aa = a.load'c'
local ab = a.load's'
local ac = a.load'N'

local ad = a.load'ab'
local ae = a.load'aH'
local af = a.load'Y'
local ag = aa.useMemo
local ah = aa.useCallback
local ai = aa.useRef
local aj = aa.createElement

local ak = ac.colors.window.element







return function(al)	
local am = al.Submenu
	local an = al.TextRef
	local ao = al.LayoutOrder or 1

	local ap = ad(ak.surface, ak.accent, am._open)
	local aq = ad(ak.surfaceStroke, ak.accentStrong, am._open)
	local ar = ad(ak.caption, ak.textActive, am._open)

	local as = ai(am)
	as.current = am

	local at = ah(function()		
as.current:Open(af.getPosition())
	end, {})

	local au = ag(function()
		return { ap, aq, ar }
	end, { ap, aq, ar } )

	local av = ag(function()
		return { onClick = at }
	end, { at } )

	ae(an, au, av)

	local aw = ag(function()
		return function()
			ap.onMouseEnter()
			aq.onMouseEnter()
			ar.onMouseEnter()
		end
	end, { ap, aq, ar } )

	local ax = ag(function()
		return function()
			ap.onMouseLeave()
			aq.onMouseLeave()
			ar.onMouseLeave()
		end
	end, { ap, aq, ar } )

	return aj("TextButton", {
		BackgroundColor3 = ap.binding,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(14, 14),
		LayoutOrder = ao,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		[aa.Event.MouseEnter] = aw,
		[aa.Event.MouseLeave] = ax,
		[aa.Event.MouseButton1Click] = at,
	}, {
		ImageLabel = aj("ImageLabel", {
			BackgroundTransparency = 1,
			Image = ab.Get("image", "options"),
			ImageColor3 = ar.binding,
			Size = UDim2.fromOffset(10, 10),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		}),
		UICorner = aj("UICorner", {
			CornerRadius = UDim.new(0, 3),
		}),
		UIStroke = aj("UIStroke", {
			Color = aq.binding,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
	})
end
end function a.ba()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'n'

local ad = a.load'aG'
local ae = a.load'aQ'
local af = a.load'aZ'
local ag = a.load'a9'

local ah = aa.peek
local ai = aa.atom
local aj = ab.createElement

local ak = {}
ak.__index = ak

setmetatable(ak, { __index = ad })

local function constructor(al)	
local am = (ad.new(al) )
	
setmetatable(am, ak)

	am._elements = ai({} )
	am._open = ai(false)
	am._showTitle = ai(false)

	return am
end

function ak.AddElement(al, am, ...)	
local an = af[am]
	if not an then
		return nil
	end

	local ao = an(...)
	local ap = ah(al._elements)
	al._elements(ac.Array.insert(ap, #ap + 1, ao))

	return ao
end

function ak.Open(al, am)	
ae.OpenSubmenu(al, am)
end

function ak.RenderInternal(al, am)	
return aj(ag, {
		Submenu = al,
		TextRef = am and am.textRef,
		LayoutOrder = am and am.layoutOrder,
	})
end










return constructor
end function a.bb()
local aa = a.load'c'
local ab = a.load'e'
local ac = a.load'd'
local ad = a.load'n'

local ae = a.load's'
local af = a.load'N'
local ag = a.load'ab'
local ah = a.load'as'
local ai = a.load'O'
local aj = a.load'm'
local ak = a.load'X'
local al = a.load'Y'

local am = aa.useState
local an = aa.useEffect
local ao = aa.useMemo
local ap = aa.useCallback
local aq = aa.useRef
local ar = ab.useSpring
local as = ac.useAtom
local at = aa.memo
local au = aa.createElement

local av = af.colors.window.element
local aw = af.colors.window
local ax = af.colors.subwindow

local b = 22
local c = 0
local d = 22
local e = 4
local f = 4
local g = 26
local h = 4
local i = 12
local j = 0.18





































local function Row(k)	
local l = k.Item
	local m = k.IsSelected
	local n = k.IsEditing
	local o = k.Renamable
	local p = l.leaving
	local q = k.OnPick
	local r = k.OnBeginEdit
	local s = k.OnCommitEdit
	local t = k.OnCancelEdit

	local u = aq(nil )

	an(function()
		local v = u.current
		if n and v then
			v.CaptureFocus(			v)
			v.CursorPosition = #v.Text + 1
			v.SelectionStart = 1
		end
	end, { n })

	local v = ao(function()
		return aj.atom(false)
	end, {})

	local w, x = am(false)
	an(function()
		v(m)
	end, { m })

	local y = ag(av.caption, av.textActive, v)
	local z = ag(av.icon, av.iconActive, v)
	local A = as(av.accentStrong)
	local B = as(av.rowHover)

	local C, D = ar(0, ai.smooth)
	local E, F = ar(0, ai.snap)
	local G, H = ar(0, ai.smoothPrecise)

	an(function()
		D.setGoal(		D,not p and 1 or 0)
	end, { p })

	an(function()
		F.setGoal(		F,(w and not p) and 1 or 0)
	end, { w, p })

	an(function()
		H.setGoal(		H,m and 1 or 0)
	end, { m })

	local I = l.icon ~= nil and l.icon ~= ""

	local J, K = ar(I and 1 or 0, ai.smooth)
	an(function()
		K.setGoal(		K,I and 1 or 0)
	end, { I })

	local L, M = am(l.icon or "")
	an(function()
		if I then
			M((l.icon ))
		end
	end, { I, l.icon })

	local N = ao(function()
		return J.map(J,function(N)
			return h + 6 + N * (i + 6)
		end)
	end, { J } )

	local O = ao(function()
		return N.map(N,function(O)
			return UDim2.fromOffset(O, 0)
		end)
	end, { N } )
	local P = ao(function()
		return N.map(N,function(P)
			return UDim2.new(1, -P, 1, 0)
		end)
	end, { N } )

	local Q = ao(function()
		return G.map(G,function(Q)
			return UDim2.new(0, h, 0, math.floor(4 + Q * 8))
		end)
	end, { G } )

	local R = ao(function()
		return G.map(G,function(R)
			return 1 - R
		end)
	end, { G } )

	local S = ao(function()
		return C.map(C,function(S)
			return 1 - S
		end)
	end, { C } )

	local T = ao(function()
		return aa.joinBindings{ C, J }:map(function(T)
			return 1 - T[1] * T[2]
		end)
	end, { C, J } )

	local U = ao(function()
		return aa.joinBindings{ C, E, G }:map(function(U)
			local V = (U[2] * 0.10 + U[3] * 0.08) * U[1]
			return 1 - V
		end)
	end, { C, E, G } )

	local V = ao(function()
		return C.map(C,function(V)
			return UDim2.new(1, 0, 0, math.floor(V * b))
		end)
	end, { C } )

	local W = ao(function()
		return function()
			x(true)
			y.onMouseEnter()
			z.onMouseEnter()
		end
	end, { y, z } )

	local X = ao(function()
		return function()
			x(false)
			y.onMouseLeave()
			z.onMouseLeave()
		end
	end, { y, z } )

	local Y = aq(l)
	Y.current = l
	local Z = aq(p)
	Z.current = p
	local _ = aq(n)
	_.current = n
	local ay = aq(m)
	ay.current = m
	local az = aq(o)
	az.current = o

	local aA = ap(function()
		if Z.current or _.current then
			return
		end
		if ay.current and az.current then
			r(Y.current.id)
		else
			q(Y.current.id)
		end
	end, { q, r } )

	local aB = ap(function(aB, aC, aD)
		if aD and aD.KeyCode == Enum.KeyCode.Escape then
			t()
		else
			s(aB.Text)
		end
	end, { s, t } )

	local aC= {
		UICorner = au("UICorner", {
			CornerRadius = UDim.new(0, 3),
		}),
		UIPadding = au("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 6),
		}),
		Indicator = au("Frame", {
			BackgroundColor3 = A,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = Q,
			BackgroundTransparency = R,
		}, {
			UICorner = au("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
		Text = n and au("TextBox", {
				ref = u,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				FontFace = ae.Get("font", "semi_bold"),
				TextColor3 = y.binding,
				TextSize = 12,
				Text = l.name or l.id,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				Position = O,
				Size = P,
				MultiLine = false,
				TextWrapped = false,
				[aa.Event.FocusLost] = aB,
			}) or au("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = ae.Get("font", "semi_bold"),
				TextColor3 = y.binding,
				TextSize = 12,
				Text = l.name or l.id,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = O,
				Size = P,
				TextTransparency = S,
			}),
		Icon = au("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = L,
			ImageColor3 = z.binding,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, h + 6, 0.5, 0),
			Size = UDim2.fromOffset(i, i),
			ImageTransparency = T,
		}),
	}

	return au("TextButton", {
		BackgroundColor3 = B,
		BackgroundTransparency = U,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = V,
		LayoutOrder = k.LayoutOrder,
		[aa.Event.MouseEnter] = W,
		[aa.Event.MouseLeave] = X,
		[aa.Event.MouseButton1Click] = aA,
	}, aC)
end

local ay = at(Row, function(ay, az)
	if ay.IsSelected ~= az.IsSelected then return false end
	if ay.IsEditing ~= az.IsEditing then return false end
	if ay.Renamable ~= az.Renamable then return false end
	if ay.LayoutOrder ~= az.LayoutOrder then return false end
	if ay.OnPick ~= az.OnPick then return false end
	if ay.OnBeginEdit ~= az.OnBeginEdit then return false end
	if ay.OnCommitEdit ~= az.OnCommitEdit then return false end
	if ay.OnCancelEdit ~= az.OnCancelEdit then return false end
	local aA = ay.Item
	local aB = az.Item
	return aA.id == aB.id and aA.name == aB.name and aA.icon == aB.icon and aA.leaving == aB.leaving
end)






local function FilterButton(az)	
local aA = az.OnOpen

	local aB, aC = am(false)
	local aD = ao(function()
		return aj.atom(false)
	end, {})

	an(function()
		aD(aB)
	end, { aB })

	local k = ag(av.filterIcon, av.accentStrong, aD)
	local l = aq(nil )
	local m = ah(az.Tip, l)

	return au("TextButton", {
		ref = l,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		[aa.Event.MouseEnter] = function()
			aC(true)
			m.onMouseEnter()
		end,
		[aa.Event.MouseLeave] = function()
			aC(false)
			m.onMouseLeave()
		end,
		[aa.Event.MouseButton1Click] = function()
			aA()
		end,
	}, {
		Icon = au("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = ae.Get("image", "filter"),
			ImageColor3 = k.binding,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
		}),
	})
end

local function buildSelectionLabel(az, aA)	
if not aA then
		return ""
	end
	for aB, aC in az do
		if aC.id == aA then
			return aC.name or aC.id
		end
	end
	return ""
end

return function(az)	
local aA = az.List
	local aB = az.LayoutOrder or 2

	local aC = (as(aA._items) )	
local aD = (as(aA._state) )	
local k = as(aA._search)
	local l = as(aA._showSearch)
	local m = as(aA._maxHeight)
	local n = as(aA._emptyText)
	local o = as(aA._placeholder)
	local p = as(aA._text)
	local q = (as(aA._filters) )	
local r = (as(aA._filterId) )	
local s = as(aA._renamable)
	local t = (as(aA._editingId) )
	
local u = as(av.panel)
	local v = as(av.panelStroke)
	local w = as(av.scrollThumb)
	local x = as(av.caption)
	local y = as(aw.searchMuted)
	local z = as(ax.text)
	local A = as(av.panelStroke)
	local B = ag(av.text, av.textActive, aA._active)

	local C = aq(aC)
	local D = aq({} )
	local E, F = am({} )

	an(function()
		local G = C.current
		local H= {}
		for I, J in aC do
			H[J.id] = J
		end

		local I= {}
		for J, K in G do
			if not H[K.id] then
				I[K.id] = K
			end
		end

		F(function(J)
			local K= {}
			for L, M in J do
				if not H[L] then
					K[L] = M
				end
			end
			for L, M in I do
				K[L] = M
			end
			return K
		end)

		C.current = aC
	end, { aC } )

	an(function()
		local G = D.current
		for H in E do
			if not G[H] then
				G[H] = task.delay(j, function()
					G[H] = nil
					F(function(I)
						local J= {}
						for K, L in I do
							if K ~= H then
								J[K] = L
							end
						end
						return J
					end)
				end)
			end
		end
		for H, I in G do
			if not E[H] then
				task.cancel(I)
				G[H] = nil
			end
		end
		return nil 	
end, { E } )

	an(function()
		return function()
			for G, H in D.current do
				task.cancel(H)
			end
			D.current = {}
		end
	end, {})

	local G = string.lower(k or "")
	local function matches(H)		
if G == "" then
			return true
		end
		local I = string.lower(H.name or H.id)
		return string.find(I, G, 1, true) ~= nil
	end

	local H	
if r then
		for I, J in q do
			if J.id == r then
				H = J
				break
			end
		end
	end

	local I= {}
	local J= {}
	for K, L in aC do
		J[L.id] = true
		if matches(L) then
			table.insert(I, L)
		end
	end

	if H and H.sort then
		table.sort(I, H.sort)
	end

	local K= {}
	for L, M in I do
		table.insert(K, {
			id = M.id,
			name = M.name,
			icon = M.icon,
			leaving = false,
		})
	end
	for L, M in E do
		if not J[L] and matches(M) then
			table.insert(K, {
				id = M.id,
				name = M.name,
				icon = M.icon,
				leaving = true,
			})
		end
	end

	local L = #q > 0
	local M = l or L

	local N = 32
	local O = #K
	local P = #I
	local Q = P > 0
	local R = P * b + math.max(0, P - 1) * c + f * 2
	local S = O * b
		+ math.max(0, O - 1) * c
		+ f * 2

	local T = Q and R or (math.max(N, R))

	local U = not Q
	local V, W = ar(U and 1 or 0, ai.smooth)
	an(function()
		W.setGoal(		W,U and 1 or 0)
	end, { U })

	local X = M and (d + 1) or 0
	local Y = math.max(g, X + T)
	local Z = math.min(Y, m)
	local _ = math.max(0, Z - X)
	local aE = T > _

	local aF, aG = ar(Z, ai.snap)
	an(function()
		aG.setGoal(		aG,Z)
	end, { Z })

	local aH = aq(aA)
	aH.current = aA
	local aI = aq(aD)
	aI.current = aD

	local aJ = ap(function(aJ)		
local aK = aH.current
		if aI.current == aJ then
			aK._state(nil)
		else
			aK._state(aJ)
		end
	end, {})

	local aK = ap(function(aK)		
aH.current:BeginEdit(aK)
	end, {})

	local aL = ap(function(aL)		
aH.current:CommitEdit(aL)
	end, {})

	local aM = ap(function()		
aH.current:CancelEdit()
	end, {})

	local aN= {}
	for aO, aP in K do
		aN[`Row_{aP.id}`] = au(ay, {
			Item = aP,
			IsSelected = (not aP.leaving) and aP.id == aD,
			IsEditing = (not aP.leaving) and aP.id == t,
			Renamable = s,
			LayoutOrder = aO,
			OnPick = aJ,
			OnBeginEdit = aK,
			OnCommitEdit = aL,
			OnCancelEdit = aM,
		})
	end

	local aO = au("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = ae.Get("font", "semi_bold"),
		TextColor3 = x,
		TextSize = 12,
		Text = G ~= "" and "No matches" or n,
		Size = UDim2.new(1, 0, 0, N),
		Position = UDim2.fromOffset(0, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTransparency = V.map(V,function(aO)
			return 1 - aO
		end),
		ZIndex = 0,
	})

	local aP = buildSelectionLabel(aC, aD)

	local aQ = (k ~= nil and k ~= "")
	local aR = aQ and z or y

	local function openFilterMenu()
		local aS= {}
		table.insert(aS, {
			Label = "Default",
			Icon = r == nil and ae.Get("image", "checkmark") or nil,
			Callback = function()
				aA._filterId(nil)
			end,
		})
		if #q > 0 then
			table.insert(aS, { Divider = true })
		end
		for aT, aU in q do
			table.insert(aS, {
				Label = aU.name,
				Icon = r == aU.id and ae.Get("image", "checkmark") or nil,
				Callback = function()
					aA._filterId(aU.id)
				end,
			})
		end

		ak.Open(aS, al.getPosition())
	end

	local aS	
local aT	
if M then
		local aU= {
			UIPadding = au("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		}

		if l then
			aU.Icon = au("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = ae.Get("image", "search"),
				ImageColor3 = y,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(10, 10),
			})

			local aV = L and (34) or 16
			aU.Input = au("TextBox", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				PlaceholderText = o,
				PlaceholderColor3 = y,
				Text = k,
				TextColor3 = aR,
				TextSize = 12,
				FontFace = ae.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				Position = UDim2.fromOffset(16, 0),
				Size = UDim2.new(1, -aV, 1, 0),
				[aa.Change.Text] = function(aW)
					aA._search(aW.Text)
				end,
			})
		end

		if L then
			aU.Filter = au(FilterButton, {
				OnOpen = openFilterMenu,
				Tip = "Filter",
			})
		end

		aS = au("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, d),
			Position = UDim2.fromOffset(0, 0),
		}, aU)

		aT = au("Frame", {
			BackgroundColor3 = A,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, d),
			Size = UDim2.new(1, 0, 0, 1),
		})
	end

	local aU = ad.Dictionary.join({
		UIListLayout = au("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, c),
		}),
		UIPadding = au("UIPadding", {
			PaddingLeft = UDim.new(0, 0),
			PaddingRight = UDim.new(0, 0),
			PaddingTop = UDim.new(0, f),
			PaddingBottom = UDim.new(0, f),
		}),
	}, aN)

	local aV= au("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, aU)

	local aW = aF.map(aF,function(aW)
		local aX = math.max(0, math.floor(aW) - X)
		return UDim2.new(1, 0, 0, aX)
	end)

	local aX = UDim2.fromOffset(0, math.max(T, S))

	local aY = au("ScrollingFrame", {
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingEnabled = aE,
		AnchorPoint = Vector2.new(0, 0),
		Size = aW,
		Position = UDim2.fromOffset(0, X),
		CanvasSize = aX,
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		ClipsDescendants = true,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ScrollBarImageColor3 = w,
		ScrollBarImageTransparency = aE and 0.1 or 1,
		ScrollBarThickness = aE and 3 or 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		LayoutOrder = 1,
	}, {
		UIPadding = au("UIPadding", {
			PaddingLeft = UDim.new(0, e),
			PaddingRight = UDim.new(0, e),
		}),
		Empty = aO,
		Inner = aV,
	})

	return au("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = aB,
	}, {
		UIListLayout = au("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = au("TextButton", {
			BackgroundTransparency = 1,
			FontFace = ae.Get("font", "semi_bold"),
			TextColor3 = B.binding,
			TextSize = 13,
			Text = p,
			Size = UDim2.new(1, 0, 0, 14),
			LayoutOrder = 0,
			AutoButtonColor = false,
			Active = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			[aa.Event.MouseEnter] = function()
				B.onMouseEnter()
			end,
			[aa.Event.MouseLeave] = function()
				B.onMouseLeave()
			end,
		}, {
			Selection = au("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = ae.Get("font", "semi_bold"),
				TextColor3 = B.binding,
				TextSize = 13,
				Text = aP,
				Size = UDim2.new(1, 0, 0, 14),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		}),
		Canvas = au("Frame", {
			BackgroundColor3 = u,
			BorderSizePixel = 0,
			Size = aF.map(aF,function(aZ)
				return UDim2.new(1, 0, 0, math.floor(aZ))
			end),
			LayoutOrder = 1,
			ClipsDescendants = true,
		}, {
			UICorner = au("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			UIStroke = au("UIStroke", {
				Color = v,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1,
			}),
			Search = aS,
			Divider = aT,
			Scroll = aY,
		}),
	})
end
end function a.bc()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'aG'
local ad = a.load'bb'

local ae = aa.atom
local af = aa.peek
local ag = aa.subscribe
local ah = ab.createElement

local ai = {}
ai.__index = ai

setmetatable(ai, { __index = ac })















local aj = {
	Alphabetical = function(aj, ak)		
return string.lower(aj.name or aj.id) < string.lower(ak.name or ak.id)
	end,
	AlphabeticalDesc = function(aj, ak)		
return string.lower(aj.name or aj.id) > string.lower(ak.name or ak.id)
	end,
}

local function normalizeOne(ak)	
if type(ak) == "string" then
		return { id = ak, name = ak }
	end
	if type(ak) == "table" and type(ak.id) == "string" then
		return {
			id = ak.id,
			name = type(ak.name) == "string" and ak.name or ak.id,
			icon = type(ak.icon) == "string" and ak.icon or nil,
		}
	end
	return nil
end

local function normalize(ak)	
if not ak then
		return {}
	end
	local al= {}
	local am= {}
	for an, ao in ak do
		local ap = normalizeOne(ao)
		if ap and not am[ap.id] then
			am[ap.id] = true
			table.insert(al, ap)
		end
	end
	return al
end

local function indexOf(ak, al)	
for am, an in ak do
		if an.id == al then
			return am
		end
	end
	return nil
end

local function constructor(ak, al, am)	
local an = (ac.new(ak) )
	
setmetatable(an, ai)

	an._items = ae(normalize(al))
	an._search = ae""	
an._showSearch = ae(false)
	an._maxHeight = ae(120)
	an._emptyText = ae"No items"	
an._placeholder = ae"Search..."	
an._filters = ae({} )
	an._filterId = ae(nil )
	an._renamable = ae(false)
	an._editingId = ae(nil )
	an._renameCallbacks = {} 
	
ag(an._state, function(ao)
		an._active(ao ~= nil and ao ~= "")
	end)

	if am ~= nil and indexOf(af(an._items), am) then
		an._state(am)
	end

	return an
end

function ai.SetItems(ak, al)	
ak._items(normalize(al))

	local am = af(ak._state)
	if am and not indexOf(af(ak._items), am) then
		ak._state(nil)
	end

	return ak
end

function ai.AddItem(ak, al)	
local am = normalizeOne(al)
	if not am then
		return ak
	end

	local an = af(ak._items)
	if indexOf(an, am.id) then
		return ak
	end

	local ao = table.clone(an)
	table.insert(ao, am)
	ak._items(ao)

	return ak
end

function ai.RemoveItem(ak, al)	
local am = af(ak._items)
	local an = indexOf(am, al)
	if not an then
		return ak
	end

	local ao = table.clone(am)
	table.remove(ao, an)
	ak._items(ao)

	if af(ak._state) == al then
		ak._state(nil)
	end

	return ak
end

function ai.SetSelected(ak, al)	
if al == nil then
		ak._state(nil)
		return ak
	end
	if indexOf(af(ak._items), al) then
		ak._state(al)
	end
	return ak
end

function ai.GetSelected(ak)	
return af(ak._state)
end

function ai.GetSelectedItem(ak)	
local al = af(ak._state)
	if not al then
		return nil
	end
	for am, an in af(ak._items) do
		if an.id == al then
			return an
		end
	end
	return nil
end

function ai.SetShowSearch(ak, al)	
ak._showSearch(al)
	return ak
end

function ai.SetMaxHeight(ak, al)	
ak._maxHeight(math.max(40, al))
	return ak
end

function ai.SetEmptyText(ak, al)	
ak._emptyText(al)
	return ak
end

function ai.SetPlaceholder(ak, al)	
ak._placeholder(al)
	return ak
end

local function findFilter(ak, al)	
for am, an in ak do
		if an.id == al then
			return am
		end
	end
	return nil
end

function ai.AddFilter(ak, al, am)	
local an = af(ak._filters)
	local ao = table.clone(an)
	local ap = findFilter(ao, al)
	local aq= { id = al, name = al, sort = am }
	if ap then
		ao[ap] = aq
	else
		table.insert(ao, aq)
	end
	ak._filters(ao)

	if af(ak._filterId) == nil and not ap then
		ak._filterId(al)
	end

	return ak
end

function ai.RemoveFilter(ak, al)	
local am = af(ak._filters)
	local an = findFilter(am, al)
	if not an then
		return ak
	end

	local ao = table.clone(am)
	table.remove(ao, an)
	ak._filters(ao)

	if af(ak._filterId) == al then
		ak._filterId(ao[1] and ao[1].id or nil)
	end

	return ak
end

function ai.SetFilter(ak, al)	
if al == nil then
		ak._filterId(nil)
		return ak
	end
	if findFilter(af(ak._filters), al) then
		ak._filterId(al)
	end
	return ak
end

function ai.GetFilter(ak)	
return af(ak._filterId)
end

function ai.SetRenamable(ak, al)	
ak._renamable(al)
	return ak
end

function ai.IsRenamable(ak)	
return af(ak._renamable)
end

function ai.OnRename(ak, al)	
table.insert(ak._renameCallbacks, al)
	return function()
		local am = table.find(ak._renameCallbacks, al)
		if am then
			table.remove(ak._renameCallbacks, am)
		end
	end
end

function ai.BeginEdit(ak, al)	
if not af(ak._renamable) then
		return
	end
	if not indexOf(af(ak._items), al) then
		return
	end
	ak._editingId(al)
end

function ai.CancelEdit(ak)	
ak._editingId(nil)
end

function ai.CommitEdit(ak, al)	
local am = af(ak._editingId)
	if not am then
		return
	end

	ak._editingId(nil)

	if not al or al == "" or al == am then
		return
	end

	local an = af(ak._items)
	if indexOf(an, al) then
		return
	end

	local ao = table.clone(an)
	for ap, aq in ao do
		if aq.id == am then
			ao[ap] = { id = al, name = al, icon = aq.icon }
			break
		end
	end
	ak._items(ao)

	if af(ak._state) == am then
		ak._state(al)
	end

	for ap, aq in ak._renameCallbacks do
		task.spawn(aq, am, al)
	end
end

function ai.Render(ak, al)	
return ah(ad, {
		List = ak,
		LayoutOrder = al,
	})
end

function ai.RenderInternal(ak, al)	
return ah(ad, {
		List = ak,
		LayoutOrder = al and al.layoutOrder,
	})
end




















return {
	__call = constructor,
	Sort = aj,
}
end function a.bd()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'e'
local ad = a.load'd'
local ae = a.load'n'

local af = a.load's'
local ag = a.load'N'
local ah = a.load'ab'
local ai = a.load'O'

local aj = ab.useState
local ak = ab.useEffect
local al = ab.useMemo
local am = ab.useCallback
local an = ab.useRef
local ao = ac.useSpring
local ap = ad.useAtom
local aq = ab.createElement

local ar = 0.06

local as = ag.colors.window.element

local at = 24
local au = 12
local av = 8
local aw = 5












local function SingleButton(ax)	
local ay = ax.Button

	local az = ap(ay._text)
	local aA = ap(ay._icon)
	local aB = ap(ay._armed)
	local aC = ap(ay._confirmText)
	local aD = aA ~= nil and aA ~= ""
	local aE = aB and (aC) or (az)

	local aF, aG = aj(false)
	local aH, aI = aj(false)
	local aJ = an(nil )

	local aK = ap(ay._active)
	local aL = al(function()
		return aa.atom(false)
	end, {})

	ak(function()
		aL(aK or aB or aF or aH)
	end, { aK, aB, aF, aH } )

	local aM = ah(as.surface, as.accentStrong, aL, true)
	local aN = ap(as.surfaceStroke)
	local aO = ap(as.accentStrong)
	local aP = ah(as.text, as.textActive, aL)
	local aQ = ah(as.icon, as.iconActive, aL)

	local aR = aF or aH
	local aS, aT = ao(0, ai.smooth)

	ak(function()
		aT.setGoal(		aT,aR and 1 or 0)
	end, { aR })

	ak(function()
		return function()
			local aU = aJ.current
			if aU then
				task.cancel(aU)
				aJ.current = nil
			end
		end
	end, {})

	local aU = am(function()		
local aU = aJ.current
		if aU then
			task.cancel(aU)
		end
		aI(true)
		aJ.current = task.delay(ar, function()
			aJ.current = nil
			aI(false)
		end)
	end, {})

	local aV = al(function()
		return aS.map(aS,function(aV)
			return aN.Lerp(aN,aO, aV)
		end)
	end, { aS, aN, aO } )

	local aW = an(ay)
	aW.current = ay

	local aX = al(function()
		return function()
			aM.onMouseEnter()
			aP.onMouseEnter()
			aQ.onMouseEnter()
		end
	end, { aM, aP, aQ } )

	local aY = al(function()
		return function()
			aG(false)
			aM.onMouseLeave()
			aP.onMouseLeave()
			aQ.onMouseLeave()
		end
	end, { aM, aP, aQ } )

	local aZ = am(function()
		aG(true)
	end, {})

	local b = am(function()
		aG(false)
	end, {})

	local c = am(function()
		aU()
		aW.current:Click()
	end, { aU } )

	local d= {
		UICorner = aq("UICorner", {
			CornerRadius = UDim.new(0, aw),
		}),
		UIStroke = aq("UIStroke", {
			Color = aV,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		UIPadding = aq("UIPadding", {
			PaddingLeft = UDim.new(0, av),
			PaddingRight = UDim.new(0, av),
		}),
		UIFlexItem = aq("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Fill,
			ItemLineAlignment = Enum.ItemLineAlignment.Stretch,
		}),
		Content = aq("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, au),
			AutomaticSize = Enum.AutomaticSize.X,
		}, {
			UIListLayout = aq("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Icon = aD and aq("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = aA,
				ImageColor3 = aQ.binding,
				Size = UDim2.fromOffset(au, au),
				LayoutOrder = 0,
			}) or nil,
			Label = aq("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = af.Get("font", "semi_bold"),
				TextColor3 = aP.binding,
				TextSize = 12,
				Text = aE,
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = 1,
			}),
		}),
	}

	return aq("TextButton", {
		BackgroundColor3 = aM.binding,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = UDim2.new(0, 0, 0, at),
		LayoutOrder = ax.LayoutOrder,
		[ab.Event.MouseEnter] = aX,
		[ab.Event.MouseLeave] = aY,
		[ab.Event.MouseButton1Down] = aZ,
		[ab.Event.MouseButton1Up] = b,
		[ab.Event.MouseButton1Click] = c,
	}, d)
end

local function rowRenderer(ax)	
local ay = ax.Button
	local az = ax.LayoutOrder or 1

	local aA = ap(ay._extras)

	local aB = al(function()
		local aB= {}
		for aC, aD in aA do
			aB[`Extra_{aC}`] = aq(SingleButton, {
				Button = aD,
				LayoutOrder = aC,
			})
		end
		return aB
	end, { aA })

	local aC = aq(SingleButton, {
		Button = ay,
		LayoutOrder = 0,
	})

	return aq(
		"Frame",
		{
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, at),
			LayoutOrder = az,
		},
		ae.Dictionary.join({
			UIListLayout = aq("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Primary = aC,
		}, aB)
	)
end

return {
	row = rowRenderer,
	single = SingleButton,
}
end function a.be()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'aG'
local ad = a.load'bd'

local ae = aa.atom
local af = aa.peek
local ag = ab.createElement

local ah = {}
ah.__index = ah

setmetatable(ah, { __index = ac })

local ai = "Confirm?"
local aj = 2.5

local function constructor(ak, al)	
local am = (ac.new(ak) )
	
setmetatable(am, ah)

	am._icon = ae(al)
	am._pressed = ae(false)
	am._callbacks = {} 	
am._requireConfirm = ae(false)
	am._confirmText = ae(ai)
	am._confirmTimeout = aj
	am._armed = ae(false)
	am._armTimer = nil 
	
return am
end

function ah.SetIcon(ak, al)	
ak._icon(al)
	return ak
end

function ah.OnClick(ak, al)	
table.insert(ak._callbacks, al)
	return function()
		local am = table.find(ak._callbacks, al)
		if am then
			table.remove(ak._callbacks, am)
		end
	end
end

function ah.RequireConfirm(ak, al, am)	
ak._requireConfirm(true)
	if al then
		ak._confirmText(al)
	end
	if am then
		ak._confirmTimeout = am
	end
	return ak
end

function ah.ClearConfirm(ak)	
ak._requireConfirm(false)
	if ak._armTimer then
		task.cancel(ak._armTimer)
		ak._armTimer = nil
	end
	ak._armed(false)
	return ak
end

function ah.Click(ak)	
if af(ak._requireConfirm) then
		if not af(ak._armed) then
			ak._armed(true)
			if ak._armTimer then
				task.cancel(ak._armTimer)
			end
			ak._armTimer = task.delay(ak._confirmTimeout, function()
				ak._armed(false)
				ak._armTimer = nil
			end)
			return
		end

		if ak._armTimer then
			task.cancel(ak._armTimer)
			ak._armTimer = nil
		end
		ak._armed(false)
	end

	for al, am in ak._callbacks do
		task.spawn(am, ak)
	end
end

function ah.Combine(ak, al, am)	
return (ak.AddElement(ak,"Button", al, am) )
end

function ah.Render(ak, al)	
return ag(ad.row, {
		Button = ak,
		LayoutOrder = al,
	})
end

function ah.RenderInternal(ak, al)	
return ag(ad.single, {
		Button = ak,
		LayoutOrder = (al and al.layoutOrder) or 1,
	})
end















return constructor
end function a.bf()
local aa = (cloneref(game.GetService(game, "UserInputService")) )

local ab = a.load'c'
local ac = a.load'e'
local ad = a.load'd'
local ae = a.load's'
local af = a.load'N'
local ag = a.load'L'
local ah = a.load'ab'
local ai = a.load'aH'
local aj = a.load'O'

local ak = ac.useSpring
local al = ad.useAtom
local am = ab.useEffect
local an = ab.useMemo
local ao = ab.useCallback
local ap = ab.useState
local aq = ab.createElement

local ar = af.colors.window.element

local as = 50
local at = 16







return function(au)	
local av = au.Key
	local aw = au.TextRef
	local ax = au.LayoutOrder or 2

	local ay = al(av._state)
	local az = al(av._listening)

	local aA = ah(ar.fieldBackground, ar.fieldBackgroundActive, av._listening)
	local aB = ah(ar.fieldStroke, ar.fieldStrokeActive, av._listening)

	local aC = al(ar.textActive)
	local aD = al(ar.text)
	local aE = al(ar.caption)

	local aF, aG = ap(false)
	local aH, aI = ak(az and 1 or 0, aj.snap)
	local aJ, aK = ak(0, aj.subtle)

	am(function()
		aI.setGoal(		aI,az and 1 or 0)
	end, { az })

	am(function()
		aK.setGoal(		aK,aF and 1 or 0)
	end, { aF })

	am(function()
		if not az then
			return
		end

		local aL = aa.InputBegan:Connect(function(aL)			
if aL.UserInputType == Enum.UserInputType.Keyboard then
				if aL.KeyCode == Enum.KeyCode.Escape then
					av.SetListening(					av,false)
					return
				end
				av._state(aL.KeyCode)
				av.SetListening(				av,false)
			elseif
				aL.UserInputType == Enum.UserInputType.MouseButton1
				or aL.UserInputType == Enum.UserInputType.MouseButton2
				or aL.UserInputType == Enum.UserInputType.MouseButton3
			then
				av._state(aL.UserInputType)
				av.SetListening(				av,false)
			end
		end)

		return function()
			aL.Disconnect(			aL)
		end
	end, { az })

	local aL = ay ~= nil
	local aM = az and "..." or not aL and "—" or ag.GetInputLabel(ay)
	local aN= aL and aD or aE

	local aO = an(function()
		return aH.map(aH,function(aO)
			return aN.Lerp(aN,aC, aO)
		end)
	end, { aH, aN, aC } )

	local aP = ao(function()		
av.SetListening(		av,not az)
	end, { az } )

	local aQ = an(function()
		return { aA, aB }
	end, { aA, aB } )

	local aR = an(function()
		return { onClick = aP }
	end, { aP } )

	ai(aw, aQ, aR)

	local aS = an(function()
		return function()
			aG(true)
			aA.onMouseEnter()
			aB.onMouseEnter()
		end
	end, { aA, aB } )

	local aT = an(function()
		return function()
			aG(false)
			aA.onMouseLeave()
			aB.onMouseLeave()
		end
	end, { aA, aB } )

	local aU = an(function()
		return aJ.map(aJ,function(aU)
			return 1 + aU * 0.75
		end)
	end, { aJ } )

	return aq("TextButton", {
		BackgroundColor3 = aA.binding,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(as, at),
		Text = aM,
		TextSize = 11,
		TextColor3 = aO,
		FontFace = ae.Get("font", "semi_bold"),
		AutoButtonColor = false,
		Active = false,
		LayoutOrder = ax,
		[ab.Event.MouseEnter] = aS,
		[ab.Event.MouseLeave] = aT,
		[ab.Event.MouseButton1Click] = aP,
		[ab.Event.MouseButton2Click] = function()
			av.SetListening(			av,false)
			av._state(nil)
		end,
	}, {
		UICorner = aq("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIStroke = aq("UIStroke", {
			Color = aB.binding,
			Thickness = aU,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end
end function a.bg()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'aG'
local ad = a.load'F'
local ae = a.load'y'
local af = a.load'z'
local ag = a.load'bf'

local ah = aa.atom
local ai = aa.subscribe
local aj = aa.peek
local ak = ab.createElement

local al = {}
al.__index = al

setmetatable(al, { __index = ac })

local am = 0
local function nextId()	
am += 1
	return am
end




local function firstInput(an)	
return an[1]
end

local function constructor(an, ao, ap, aq)	
local ar = (ac.new(an) )	
setmetatable(ar, al)

	ar._callbacks = {} 	
ar._listening = ah(false)
	ar._attachedBind = aq ~= nil

	if aq then
		local as = aj(af.binds)[aq]
		if not as then
			error(`Key: bind "{aq}" not found`, 2)
		end

		ar._bind = as
		ar._mode = as.mode

		local at = aj(as.inputs)
		ar._state(ao or firstInput(at))

		ar._unsubInputs = ai(ar._state, function(au)			
local av = aj(as.inputs)
			local aw = au
			if firstInput(av) == aw then
				return
			end
			as.inputs(aw and { aw } or {})
		end)

		ar._unsubFromBind = ai(as.inputs, function(au)			
local av = firstInput(au)
			if aj(ar._state) == av then
				return
			end
			ar._state(av)
		end)
	else
		ar._state(ao)
		ar._mode = ah(ap or "onPress")

		local as = nextId()
		local at = `keyel_{as}`

		local au = ae(at, function(au)			
for av, aw in next, ar._callbacks do
				task.spawn(aw, au)
			end
		end)
		au.mode = ar._mode
		au.inputs(ao and { ao } or {})
		ad._registerBind(au)
		ar._bind = au

		ar._unsubInputs = ai(ar._state, function(av)			
au.inputs(av and { av } or {})
		end)
	end

	return ar
end

function al.Destroy(an)	
if an._unsubInputs then
		an._unsubInputs()
		an._unsubInputs = nil
	end
	if an._unsubFromBind then
		an._unsubFromBind()
		an._unsubFromBind = nil
	end
	if an._bind and not an._attachedBind then
		ad.RemoveBind(an._bind.name)
	end
	an._callbacks = {}
	ac.Destroy(an)
end

function al.OnCallback(an, ao)	
table.insert(an._callbacks, ao)
	return function()
		local ap = table.find(an._callbacks, ao)
		if ap then
			table.remove(an._callbacks, ap)
		end
	end
end

function al.SetMode(an, ao)	
if an._attachedBind then
		an._bind.mode(ao)
	else
		an._mode(ao)
	end
	return an
end

function al.SetKey(an, ao)	
an._state(ao)
	return an
end

function al.SetListening(an, ao)	
an._listening(ao)
end

function al.RenderInternal(an, ao)	
return ak(ag, {
		Key = an,
		TextRef = ao and ao.textRef,
		LayoutOrder = ao and ao.layoutOrder,
	})
end














return constructor
end function a.bh()
local aa = a.load'c'
local ab = a.load'N'
local ac = a.load's'

local ad = a.load'ab'
local ae = a.load'aH'
local af = a.load'Y'

local ag = aa.createElement

local ah = ab.colors.window.element







return function(ai)	
local aj = ai.AssetPicker
	local ak = ai.TextRef
	local al = ai.LayoutOrder or 2

	local am = ad(ah.surface, ah.accent, aj._open)
	local an = ad(ah.surfaceStroke, ah.accentStrong, aj._open)
	local ao = ad(ah.icon, ah.iconActive, aj._open)

	ae(ak, { am }, {
		onClick = function()
			aj.Open(			aj,af.getPosition())
		end,
	})

	return ag("TextButton", {
		BackgroundColor3 = am.binding,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(14, 14),
		[aa.Event.MouseEnter] = function()
			am.onMouseEnter()
		end,
		[aa.Event.MouseLeave] = function()
			am.onMouseLeave()
		end,
		[aa.Event.MouseButton1Click] = function()
			aj.Open(			aj,af.getPosition())
		end,
		Text = "",
		Active = false,
		AutoButtonColor = false,
		LayoutOrder = al,
	}, {
		ImageLabel = ag("ImageLabel", {
			BackgroundTransparency = 1,
			Image = ac.Get("image", "options"),
			ImageColor3 = ao.binding,
			Size = UDim2.fromOffset(10, 10),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		}),
		UICorner = ag("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIStroke = ag("UIStroke", {
			Color = an.binding,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
	})
end
end function a.bi()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'n'

local ad = a.load'aG'
local ae = a.load'aQ'
local af = a.load's'
local ag = a.load'i'
local ah = a.load'aZ'
local ai = a.load'bh'

local aj = aa.atom
local ak = aa.peek
local al = ab.createElement


































local am = "__selected__"

local an = "sound"
local ao = "image"

local function fileTypeForAssetType(ap)	
if ap == "sounds" then
		return an
	end
	if ap == "images" then
		return ao
	end
	return ap
end

local function basePathFor(ap, aq)	
return `limerence.biz/assets/{ap}/{aq}`
end

local ap = {}
ap.__index = ap

setmetatable(ap, { __index = ad })

local function constructor(aq, ar)	
local as = (ad.new(aq) )	
setmetatable(as, ap)

	as._config = ar
	as._assetType = ar.assetType
	as._category = ar.category or ""
	as._fileType = fileTypeForAssetType(ar.assetType)
	if ar.basePath then
		as._basePath = ar.basePath
	elseif ar.category and ar.category ~= "" then
		as._basePath = basePathFor(ar.assetType, ar.category)
	else
		as._basePath = `limerence.biz/assets/{ar.assetType}`
	end
	as._extensions = ar.extensions

	as._assetNames = aj({} )
	as._assetByName = {} 	
as._previewCache = {} 	
as._previewCacheBuilt = {} 
	
local at = ar.assignmentTypes or {}
	as._assignmentTypes = at
	as._singleSelect = #at == 0
	as._state({} )
	as._open = aj(false)

	as._extrasByKey = {} 	
as._extraByKey = {} 
	
for au, av in next, at do
		local aw= {}
		local ax= {}
		if av.extras then
			for ay, az in next, av.extras do
				local aA = ah[az.type]
				if aA then
					local aB = aA(table.unpack(az.args or {}))
					table.insert(aw, aB)
					ax[az.key] = aB
				end
			end
		end
		as._extrasByKey[av.key] = aw
		as._extraByKey[av.key] = ax
	end

	as._activeSound = nil 
	
if isfolder and makefolder and not isfolder(as._basePath) then
		makefolder(as._basePath)
	end

	if ar.bundle then
		local au = ar.bundle
		local av= {}
		for aw, ax in next, au.files do
			if type(ax) == "string" then
				table.insert(av, { remote = ax, name = ax })
			else
				table.insert(av, ax)
			end
		end

		local aw = (ar.category and ar.category ~= "") and ar.category or ar.assetType
		af.QueueDownload{
			id = `assetpicker.{ar.assetType}.{aw}`,
			title = au.title or `Downloading {aw}`,
			icon = au.icon,
			urlPrefix = au.urlPrefix,
			folder = as._basePath,
			files = av,
			onComplete = function()				
as.Refresh(				as)
			end,
		}	
end

	as.Refresh(
	as)

	return as
end

function ap.Refresh(aq)	if not listfiles or not isfolder or not isfolder(aq._basePath) then
		aq._assetNames{}		
aq._previewCache = {}
		aq._previewCacheBuilt = {}
		return
	end

	local ar= {}
	aq._assetByName = {}
	aq._previewCache = {}
	aq._previewCacheBuilt = {}

	local as = aq._extensions
	local at	
if as then
		at = {}
		for au, av in next, as do
			(at )[string.lower(av)] = true
		end
	end

	local au, av = pcall(listfiles, aq._basePath)
	if au and type(av) == "table" then
		for aw, ax in next, av do
			local ay = (ax .gsub(ax ,"\\", "/"))
			local az = ag.getFullNameFromPath(ay)
			local aA = ag.getNameFromPath(ay)
			local aB = ag.getExtensionFromPath(ay)
			if not aA or not aB then
				continue
			end
			if at then
				if not (at )[string.lower(aB)] then
					continue
				end
			else
				local aC = ag[aB]
				if aC ~= aq._fileType then
					continue
				end
			end

			local aC = `{aq._basePath}/{az}`
			aq._assetByName[aA] = {
				name = aA,
				path = aC,
				fullName = az ,
			}
			table.insert(ar, aA)
		end
	end

	table.sort(ar)
	aq._assetNames(ar)
end

function ap.GetPreviewImage(aq, ar)	
if aq._previewCacheBuilt[ar] then
		return aq._previewCache[ar]
	end
	local as = aq._config.previewImage
	if not as then
		aq._previewCacheBuilt[ar] = true
		return nil
	end
	local at = aq._assetByName[ar]
	if not at then
		return nil
	end
	local au, av = pcall(as, aq, ar, at.path)
	if au and type(av) == "string" and av ~= "" then
		aq._previewCache[ar] = av
	else
		aq._previewCache[ar] = nil
	end
	aq._previewCacheBuilt[ar] = true
	return aq._previewCache[ar]
end

function ap.GetExtras(aq, ar)	
return aq._extrasByKey[ar] or {}
end

function ap.GetExtra(aq, ar, as)	
local at = aq._extraByKey[ar]
	if not at then
		return nil
	end
	return at[as]
end

function ap.GetAssignment(aq, ar)	
local as = ak(aq._state) or {}
	return as[ar]
end

function ap.GetAssignedPath(aq, ar)	
local as = aq.GetAssignment(aq,ar)
	if not as then
		return nil
	end
	local at = aq._assetByName[as]
	if at then
		return at.path
	end
	return `{aq._basePath}/{as}`
end

function ap.Assign(aq, ar, as)	
local at = ak(aq._state) or {}
	aq._state(ac.Dictionary.set(at, ar, as))
end

function ap.IsSingleSelect(aq)	
return aq._singleSelect
end

function ap.Select(aq, ar)	
aq.Assign(	aq,am, ar)
end

function ap.GetSelected(aq)	
return aq.GetAssignment(aq,am)
end

function ap.GetSelectedPath(aq)	
return aq.GetAssignedPath(aq,am)
end

function ap.Preview(aq, ar)	
local as= ae.Get"AssetPicker"
	
aq.StopPreview(
	aq)

	if as then
		as.SetActivePreview(		as,ar)
	end

	local at = aq._assetByName[ar]
	if not at then
		return
	end

	local au = af.Get(aq._fileType, ar)
	if not au then
		au = getcustomasset(at.path)
	end

	local av = aq._config
	if av.previewBehavior then
		av.previewBehavior(aq, ar, at.path)
		return
	end

	if aq._fileType == an then
		local aw = game.GetService(game, "SoundService")		local ax = Instance.new"Sound"		
ax.SoundId = au
		local ay = 1
		for az, aA in next, aq._assignmentTypes do
			if aq.GetAssignment(aq,aA.key) == ar then
				local aB = aq.GetExtra(aq,aA.key, "volume")
				if aB and aB.Peek then
					local aC = aB.Peek(aB)
					if type(aC) == "number" then
						ay = aC
					end
				end
				break
			end
		end
		ax.Volume = ay
		ax.Parent = aw
		ax.Play(		ax)

		aq._activeSound = ax

		ax.Ended:Once(function()
			if aq._activeSound == ax then
				aq._activeSound = nil
				if as then
					as.SetActivePreview(					as,nil)
				end
			end
			ax.Destroy(			ax)
		end)
	end
end

function ap.StopPreview(aq)	
local ar = aq._config
	if ar.stopPreview then
		ar.stopPreview(aq)
	elseif aq._activeSound then
		aq._activeSound:Stop()
		aq._activeSound:Destroy()
		aq._activeSound = nil
	end

	local as= ae.Get"AssetPicker"	
if as then
		as.SetActivePreview(		as,nil)
	end
end

function ap.Open(aq, ar)	
ae.OpenAssetPicker(aq, ar)
end

function ap.AddElement(aq, ar, ...)	
local as = ah[ar]
	if not as then
		return nil
	end
	local at = as(...)
	local au = ak(aq._extras)
	aq._extras(ac.Array.insert(au, #au + 1, at))
	return at
end

function ap.RenderInternal(aq, ar)	
return al(ai, {
		AssetPicker = aq,
		TextRef = ar and ar.textRef,
		LayoutOrder = ar and ar.layoutOrder,
	})
end

























return constructor
end function a.bj()
local aa = a.load'c'
local ab = a.load'e'
local ac = a.load'd'
local ad = a.load'n'
local ae = a.load'm'

local af = a.load's'
local ag = a.load'N'
local ah = a.load'ab'
local ai = a.load'O'
local aj = a.load'Y'

local ak = aa.useState
local al = aa.useEffect
local am = aa.useMemo
local _=aa.useRef
local ao = ab.useSpring
local ap = ac.useAtom
local aq = aa.createElement

local ar = ag.colors.window.element
local as = ag.colors.subwindow

local at = 22
local au = 24
local av = 26
local aw = 4
local ax = 32























local function alignToEnum(az)	
if az == "center" then
		return Enum.TextXAlignment.Center
	elseif az == "right" then
		return Enum.TextXAlignment.Right
	end
	return Enum.TextXAlignment.Left
end

local function getColumnWeight(az)	
local aA = az.weight
	if not aA or aA <= 0 then
		return 1
	end
	return aA
end

local function getColumnValue(az, aA)	
return aA[az.id]
end

local function formatCellText(az, aA, aB)	
if az.formatter then
		local aC, aD = pcall(az.formatter, aB, aA)
		if aC and aD ~= nil then
			return tostring(aD)
		end
	end
	if aB == nil then
		return ""
	end
	return tostring(aB)
end










local az = 10

local function HeaderCell(aA)	
local aB = aA.Column
	local aC = aB.sortable == true and aA.OnClick ~= nil
	local aD, aE = ak(false)

	local aF = am(function()
		return ae.atom(false)
	end, {})

	al(function()
		aF(aA.SortActive or (aC and aD))
	end, { aA.SortActive, aD, aC } )

	local aG = ah(ar.caption, ar.textActive, aF)

	local aH	
if aA.SortActive then
		aH = aA.SortDirection == "desc" and "↓" or "↑"
	end

	local aI = aH ~= nil
	local aJ = aI and UDim2.new(1, -(az + 4), 1, 0) or UDim2.fromScale(1, 1)

	local aK= {
		UIPadding = aq("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
	}

	if aB.headerRenderer then
		local aL, aM = pcall(aB.headerRenderer, aB)
		if aL and aM then
			aK.Custom = aM
		end
	end

	if not aK.Custom then
		aK.Label = aq("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = af.Get("font", "bold"),
			TextColor3 = aG.binding,
			TextSize = 12,
			Text = string.upper(aB.name or aB.id),
			TextXAlignment = alignToEnum(aB.align),
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(0, 0),
			Size = aJ,
		})

		if aH then
			aK.Arrow = aq("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = af.Get("font", "bold"),
				TextColor3 = aG.binding,
				TextSize = 11,
				Text = aH,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0, az, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Center,
			})
		end
	end

	local aL	
if aC then
		aL = aq("TextButton", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Active = false,
			Size = UDim2.fromScale(1, 1),
			[aa.Event.MouseEnter] = function()
				aE(true)
				aG.onMouseEnter()
			end,
			[aa.Event.MouseLeave] = function()
				aE(false)
				aG.onMouseLeave()
			end,
			[aa.Event.MouseButton1Click] = function()
				if aA.OnClick then
					aA.OnClick(aB)
				end
			end,
		}, aK)
	else
		aL = aq("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, aK)
	end

	return aq("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(aA.Weight, 0, 1, 0),
		LayoutOrder = aA.LayoutOrder,
		ClipsDescendants = true,
	}, {
		UIFlexItem = aq("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Fill,
			ItemLineAlignment = Enum.ItemLineAlignment.Stretch,
		}),
		Inner = aL,
	})
end









local function Cell(aA)	
local aB = aA.Column
	local aC = aA.Row

	local aD = ah(ar.text, ar.textActive, aA.ActiveAtom)
	local aE = getColumnValue(aB, aC)

	local aF	
if aB.renderer then
		local aG, aH = pcall(aB.renderer, aC, aE)
		if aG and aH then
			aF = aH
		end
	end

	if not aF then
		aF = aq("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = af.Get("font", "semi_bold"),
			TextColor3 = aD.binding,
			TextSize = 12,
			Text = formatCellText(aB, aC, aE),
			TextXAlignment = alignToEnum(aB.align),
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.fromScale(1, 1),
		})
	end

	return aq("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(aA.Weight, 0, 1, 0),
		LayoutOrder = aA.LayoutOrder,
		ClipsDescendants = true,
	}, {
		UIFlexItem = aq("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Fill,
			ItemLineAlignment = Enum.ItemLineAlignment.Stretch,
		}),
		UIPadding = aq("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		Content = aF,
	})
end












local function TableRow(aA)	
local aB = aA.Row
	local aC = aA.RowIndex
	local aD = aA.Columns
	local aE = aA.IsSelected

	local aF, aG = ak(false)

	local aH = am(function()
		return ae.atom(false)
	end, {})

	al(function()
		aH(aE)
	end, { aE })

	local aI, aJ = ao(0, ai.quick)
	local aK, aL = ao(0, ai.smoothPrecise)

	al(function()
		aJ.setGoal(		aJ,aF and 1 or 0)
	end, { aF })

	al(function()
		aL.setGoal(		aL,aE and 1 or 0)
	end, { aE })

	local aM = ap(ar.accentStrong)
	local aN = ap(ar.panel)
	local aO = ap(ar.fieldBackground)

	local aP = aa.joinBindings{ aI, aK }:map(function(aP)		
local aQ= aP[1]
		local aR= aP[2]
		local aS= aN
		if aA.IsZebra then
			aS = aS.Lerp(aS,aO, 0.35)
		end
		aS = aS.Lerp(aS,aO, aQ * 0.45)
		aS = aS.Lerp(aS,aM, aR * 0.18)
		return aS
	end)

	local aQ = aa.joinBindings{ aI, aK }:map(function(aQ)		
local aR= aQ[1]
		local aS= aQ[2]
		if aA.IsZebra or aR > 0 or aS > 0 then
			return 0
		end
		return 1
	end)

	local aR= {
		UIListLayout = aq("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
		Indicator = aq("Frame", {
			BackgroundColor3 = aM,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = aK.map(aK,function(aR)				
return UDim2.new(0, 2, 0, math.floor(8 + aR * 6))
			end),
			BackgroundTransparency = aK.map(aK,function(aR)				
return 1 - aR
			end),
			ZIndex = 2,
		}),
	}

	for aS, aT in aD do
		aR[`Cell_{aT.id}_{aS}`] = aq(Cell, {
			Column = aT,
			Row = aB,
			Weight = getColumnWeight(aT),
			LayoutOrder = aS,
			ActiveAtom = aH,
		})
	end

	return aq(
		"TextButton",
		{
			BackgroundColor3 = aP,
			BackgroundTransparency = aQ,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Active = false,
			Size = UDim2.new(1, 0, 0, aA.Height),
			LayoutOrder = aC,
			ClipsDescendants = true,
			[aa.Event.MouseEnter] = function()
				aG(true)
			end,
			[aa.Event.MouseLeave] = function()
				aG(false)
			end,
			[aa.Event.MouseButton1Click] = function()
				aA.OnClick(aB, aC)
			end,
			[aa.Event.InputBegan] = function(aS, aT)
				if aT.UserInputType == Enum.UserInputType.MouseButton2 then
					aA.OnContextMenu(aB, aC, aj.getPosition(aT))
				end
			end ,
		},
		ad.Dictionary.join({
			UIPadding = aq("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),
		}, aR)
	)
end









local function PageButton(aA)	
local aB = aA.Enabled

	local aC, aD = ak(false)
	local aE, aF = ak(false)

	local aG = am(function()
		return ae.atom(false)
	end, {})

	al(function()
		aG(aB and (aC or aE))
	end, { aC, aE, aB })

	local aH = ah(ar.surface, ar.accentSoft, aG)
	local aI = ap(ar.surfaceStroke)
	local aJ = ah(ar.text, ar.textActive, aG)

	return aq("TextButton", {
		BackgroundColor3 = aH.binding,
		BackgroundTransparency = aB and 0 or 0.4,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = false,
		Text = "",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = aA.LayoutOrder,
		[aa.Event.MouseEnter] = function()
			if aB then
				aD(true)
				aH.onMouseEnter()
				aJ.onMouseEnter()
			end
		end,
		[aa.Event.MouseLeave] = function()
			aD(false)
			aF(false)
			aH.onMouseLeave()
			aJ.onMouseLeave()
		end,
		[aa.Event.MouseButton1Down] = function()
			if aB then
				aF(true)
			end
		end,
		[aa.Event.MouseButton1Up] = function()
			aF(false)
		end,
		[aa.Event.MouseButton1Click] = function()
			if aB then
				aA.OnClick()
			end
		end,
	}, {
		UICorner = aq("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIStroke = aq("UIStroke", {
			Color = aI,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = aB and 0 or 0.5,
		}),
		UIPadding = aq("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		Label = aq("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = af.Get("font", "semi_bold"),
			TextColor3 = aJ.binding,
			TextTransparency = aB and 0 or 0.5,
			TextSize = 11,
			Text = aA.Label,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
	})
end

return function(aA)	
local aB = aA.Table
	local aC = aA.LayoutOrder or 1

	local aD = (ap(aB._columns) )	
local aE = (ap(aB._rows) )	
local aF = (ap(aB._rowKey) )	
local aG = (ap(aB._selectedKey) )	
local aH = ap(aB._loading)
	local aI = ap(aB._emptyText)
	local aJ = ap(aB._loadingText)
	local aK = (ap(aB._errorText) )	
local aL = ap(aB._maxHeight)
	local aM = ap(aB._rowHeight)
	local aN = ap(aB._showPagination)
	local aO = (ap(aB._nextCursor) )	
local aP = (ap(aB._previousCursor) )	
local aQ = ap(aB._pageIndex)
	local aR = (ap(aB._cooldownUntil) )	
local aS = (ap(aB._search) )	
local aT = (ap(aB._showSearch) )	
local aU = (ap(aB._searchPlaceholder) )	
local aV = (ap(aB._sortColumnId) )	
local aW = (ap(aB._sortDirection) )	
local aX = ap(aB._text)
local
aY, aZ =ak(0)
	al(function()
		local b = aR - os.clock()
		if b <= 0 then
			return nil 		
end
		local c = task.delay(b, function()
			aZ(function(c)				
return c + 1
			end)
		end)
		return function()
			task.cancel(c)
		end
	end, { aR })

	local b = aR > os.clock()

	local c = ap(ar.panel)
	local d = ap(ar.panelStroke)
	local e = ap(ar.panelStroke)
	local f = ap(ar.surface)
	local g = ap(ar.caption)
	local h = ah(ar.text, ar.textActive, aB._active)
	local i = ap(as.text)
	local j = ap(as.text)
	local k = ap(ar.scrollThumb)

	local l = string.lower(aS or "")
	local m= {}
	if l == "" then
		m = aE
	else
		for n, o in next, aE do
			local p = false
			for q, r in next, aD do
				local s				
if r.searchValue then
					local t, u = pcall(r.searchValue, o)
					s = (t and type(u) == "string") and u or ""
				else
					local t = o[r.id]
					if t == nil then
						s = ""
					elseif r.formatter then
						local u, v = pcall(r.formatter, t, o)
						s = (u and type(v) == "string") and v or tostring(t)
					else
						s = tostring(t)
					end
				end
				if s ~= "" and string.find(string.lower(s), l, 1, true) then
					p = true
					break
				end
			end
			if p then
				table.insert(m, o)
			end
		end
	end

	if aV then
		local n		
for o, p in next, aD do
			if p.id == aV then
				n = p
				break
			end
		end
		if n then
			local o = table.clone(m)
			local function getSortValue(p)				
if n.sortKey then
					local q, r = pcall(n.sortKey, p)
					if q then
						return r
					end
				end
				return p[n.id]
			end
			local p = aW ~= "desc"
			table.sort(o, function(q, r)				
local s, t= getSortValue(q), getSortValue(r)
				if s == nil and t == nil then
					return false
				end
				if s == nil then
					return not p
				end
				if t == nil then
					return p
				end
				if type(s) == "number" and type(t) == "number" then
					if p then
						return s < t
					end
					return s > t
				end
				local u, v = string.lower(tostring(s)), string.lower(tostring(t))
				if p then
					return u < v
				end
				return u > v
			end)
			m = o
		end
	end

	local n = math.max(16, aM or av)
	local o = #m
	local p = o > 0
	local q = #aE > 0
	local r = (not p) or aK ~= nil

	local s = o * n + aw * 2
	local t = r and ax or 0
	local u = math.max(t, s)
	local v = aN and au or 0
	local w = aT and (at + 1) or 0
	local x = w + at + 1

	local y =
		math.max(ax, aL - x - v - (aN and 1 or 0))
	local z = math.min(u, y)
	local A = s > z

	local B = x + z + (aN and (v + 1) or 0)

	local C, D = ao(B, ai.snap)
	al(function()
		D.setGoal(		D,B)
	end, { B })

	local E= {
		UIListLayout = aq("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
		UIPadding = aq("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
	}

	local function onHeaderClick(F)		
aB.ToggleSort(		aB,F.id)
	end

	for F, G in aD do
		local H = aV == G.id
		E[`Header_{G.id}_{F}`] = aq(HeaderCell, {
			Column = G,
			Weight = getColumnWeight(G),
			LayoutOrder = F,
			SortActive = H,
			SortDirection = aW,
			OnClick = onHeaderClick,
		})
	end

	local F	
if aT then
		F = aq("Frame", {
			BackgroundColor3 = f,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, at),
			Position = UDim2.fromOffset(0, 0),
			ClipsDescendants = true,
		}, {
			UIPadding = aq("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			Icon = aq("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = af.Get("image", "search"),
				ImageColor3 = g,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(10, 10),
			}),
			Input = aq("TextBox", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				PlaceholderText = aU,
				PlaceholderColor3 = g,
				Text = aS,
				TextColor3 = j,
				TextSize = 12,
				FontFace = af.Get("font", "semi_bold"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				Position = UDim2.fromOffset(16, 0),
				Size = UDim2.new(1, -16, 1, 0),
				[aa.Change.Text] = function(G)
					aB._search(G.Text)
				end,
			}),
		})
	end

	local G = aT
			and aq("Frame", {
				BackgroundColor3 = e,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, at),
				Size = UDim2.new(1, 0, 0, 1),
			})
		or nil

	local H = aq("Frame", {
		BackgroundColor3 = f,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, at),
		Position = UDim2.fromOffset(0, w),
		ClipsDescendants = true,
	}, E)

	local I = aq("Frame", {
		BackgroundColor3 = e,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, w + at),
		Size = UDim2.new(1, 0, 0, 1),
	})

	local function onRowClick(J, K)		
aB.HandleRowClick(		aB,J, K)
	end

	local function onRowContextMenu(J, K, L)		
aB.HandleRowContextMenu(		aB,J, K, L)
	end

	local J= {
		UIListLayout = aq("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),
		UIPadding = aq("UIPadding", {
			PaddingTop = UDim.new(0, aw),
			PaddingBottom = UDim.new(0, aw),
		}),
	}

	for K, L in m do
		local M = L[aF]
		local N = M ~= nil and tostring(M) or `idx_{K}`
		local O = aG ~= nil and tostring(aG) == N

		J[`Row_{N}_{K}`] = aq(TableRow, {
			Row = L,
			RowIndex = K,
			Columns = aD,
			IsSelected = O,
			IsZebra = K % 2 == 0,
			Height = n,
			OnClick = onRowClick,
			OnContextMenu = onRowContextMenu,
		})
	end

	local K	
local L	
if aK then
		K = aK
		L = i
	elseif aH and not p then
		K = aJ
		L = g
	elseif l ~= "" and q then
		K = "No matches"
		L = g
	else
		K = aI
		L = g
	end

	local M = r
			and aq("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = af.Get("font", "semi_bold"),
				TextColor3 = L,
				TextSize = 12,
				Text = K,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 2,
			})
		or nil

	local N = aq(
		"ScrollingFrame",
		{
			Active = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, x),
			Size = UDim2.new(1, 0, 0, z),
			CanvasSize = UDim2.fromOffset(0, math.max(s, z)),
			AutomaticCanvasSize = Enum.AutomaticSize.None,
			ScrollingEnabled = A,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = A and 3 or 0,
			ScrollBarImageColor3 = k,
			ScrollBarImageTransparency = A and 0.1 or 1,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			ClipsDescendants = true,
		},
		ad.Dictionary.join({
			Status = M,
		}, p and J or {})
	)

	local O	
if aN then
		local P = `Page {aQ}`
		if aH then
			P = P .. " · " .. aJ
		end

		O = aq("Frame", {
			BackgroundColor3 = f,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, au),
			Position = UDim2.fromOffset(0, x + z + 1),
		}, {
			UIPadding = aq("UIPadding", {
				PaddingLeft = UDim.new(0, 3),
				PaddingRight = UDim.new(0, 3),
				PaddingTop = UDim.new(0, 3),
				PaddingBottom = UDim.new(0, 3),
			}),
			UIListLayout = aq("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			Previous = aq(PageButton, {
				Label = "Previous",
				Enabled = aP ~= nil and not aH and not b,
				OnClick = function()
					aB.PreviousPage(					aB)
				end,
				LayoutOrder = 0,
			}),
			Next = aq(PageButton, {
				Label = "Next",
				Enabled = aO ~= nil and not aH and not b,
				OnClick = function()
					aB.NextPage(					aB)
				end,
				LayoutOrder = 1,
			}),
			Spacer = aq("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, 0),
				LayoutOrder = 2,
			}, {
				UIFlexItem = aq("UIFlexItem", {
					FlexMode = Enum.UIFlexMode.Fill,
				}),
				PageLabel = aq("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					FontFace = af.Get("font", "semi_bold"),
					TextColor3 = g,
					TextSize = 11,
					Text = P,
					Size = UDim2.fromScale(1, 1),
					TextXAlignment = Enum.TextXAlignment.Right,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
			}),
			Refresh = aq(PageButton, {
				Label = "Refresh",
				Enabled = not aH and not b,
				OnClick = function()
					aB.Refresh(					aB)
				end,
				LayoutOrder = 3,
			}),
		})
	end

	local P = aN
			and aq("Frame", {
				BackgroundColor3 = e,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, x + z),
				Size = UDim2.new(1, 0, 0, 1),
			})
		or nil

	local Q = aX ~= nil and aX ~= ""

	local R	
if Q then
		R = aq("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = af.Get("font", "semi_bold"),
			TextColor3 = h.binding,
			TextSize = 13,
			Text = aX,
			Size = UDim2.new(1, 0, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
		})
	end

	local S = aq("Frame", {
		BackgroundColor3 = c,
		BorderSizePixel = 0,
		Size = C.map(C,function(S)			
return UDim2.new(1, 0, 0, math.floor(S))
		end),
		LayoutOrder = 1,
		ClipsDescendants = true,
	}, {
		UICorner = aq("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		UIStroke = aq("UIStroke", {
			Color = d,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = 1,
		}),
		SearchBar = F,
		SearchDivider = G,
		Header = H,
		HeaderDivider = I,
		Body = N,
		FooterDivider = P,
		Footer = O,
	})

	return aq("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = aC,
	}, {
		UIListLayout = aq("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Label = R,
		Canvas = S,
	})
end
end function a.bk()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'aG'
local ad = a.load'bj'

local ae = aa.atom
local af = aa.peek
local ag = ab.createElement

local ah = {}
ah.__index = ah

setmetatable(ah, { __index = ac })



































local function disconnector(ai, aj)	
return function()
		local ak = table.find(ai, aj)
		if ak then
			table.remove(ai, ak)
		end
	end
end

local function constructor(ai, aj)	
local ak = (ac.new(ai) )
	
setmetatable(ak, ah)

	ak._columns = ae(aj or {} )
	ak._rows = ae({} )
	ak._rowKey = ae"id"	
ak._selectedKey = ae(nil )
	ak._loading = ae(false)
	ak._emptyText = ae"No items"	
ak._loadingText = ae"Loading..."	
ak._errorText = ae(nil )
	ak._maxHeight = ae(360)
	ak._rowHeight = ae(26)
	ak._showPagination = ae(true)

	ak._dataSource = nil 	
ak._currentCursor = ae(nil )
	ak._nextCursor = ae(nil )
	ak._previousCursor = ae(nil )
	ak._pageIndex = ae(1)
	ak._fetchToken = 0
	ak._cooldown = ae(4)
	ak._cooldownUntil = ae(0)

	ak._search = ae""	
ak._showSearch = ae(false)
	ak._searchPlaceholder = ae"Search..."	
ak._sortColumnId = ae(nil )
	ak._sortDirection = ae("asc" )

	ak._rowClickCallbacks = {} 	
ak._rowContextCallbacks = {} 	
ak._pageChangeCallbacks = {} 	
ak._selectionCallbacks = {} 
	
return ak
end

function ah.SetColumns(ai, aj)	
ai._columns(aj or {})
	return ai
end

function ah.GetColumns(ai)	
return af(ai._columns)
end

function ah.SetRowKey(ai, aj)	
ai._rowKey(aj)
	return ai
end

function ah.SetRows(ai, aj)	
ai._rows(aj or {})
	ai._errorText(nil)
	return ai
end

function ah.GetRows(ai)	
return af(ai._rows)
end

function ah.SetEmptyText(ai, aj)	
ai._emptyText(aj or "No items")
	return ai
end

function ah.SetLoadingText(ai, aj)	
ai._loadingText(aj or "Loading...")
	return ai
end

function ah.SetLoading(ai, aj)	
ai._loading(aj and true or false)
	return ai
end

function ah.IsLoading(ai)	
return af(ai._loading)
end

function ah.SetMaxHeight(ai, aj)	
ai._maxHeight(math.max(80, aj))
	return ai
end

function ah.SetRowHeight(ai, aj)	
ai._rowHeight(math.max(16, aj))
	return ai
end

function ah.SetShowPagination(ai, aj)	
ai._showPagination(aj and true or false)
	return ai
end

function ah.SetDataSource(ai, aj)	
ai._dataSource = aj
	return ai
end

function ah.SetRefreshCooldown(ai, aj)	
ai._cooldown(math.max(0, aj))
	return ai
end

function ah.GetCooldownRemaining(ai)	
local aj = os.clock()
	local ak = af(ai._cooldownUntil)
	if ak <= aj then
		return 0
	end
	return ak - aj
end

function ah.IsOnCooldown(ai)	
return ai.GetCooldownRemaining(ai) > 0
end

function ah.SetShowSearch(ai, aj)	
ai._showSearch(aj and true or false)
	return ai
end

function ah.SetSearchPlaceholder(ai, aj)	
ai._searchPlaceholder(aj or "Search...")
	return ai
end

function ah.SetSearch(ai, aj)	
ai._search(aj or "")
	return ai
end

function ah.GetSearch(ai)	
return af(ai._search)
end

function ah.SetSort(ai, aj, ak)	
ai._sortColumnId(aj)
	ai._sortDirection(ak or "asc")
	return ai
end

function ah.GetSort(ai)	
return af(ai._sortColumnId), (af(ai._sortDirection) )
end

function ah.ToggleSort(ai, aj)	
local ak = af(ai._sortColumnId)
	local al = af(ai._sortDirection)
	if ak ~= aj then
		ai._sortColumnId(aj)
		ai._sortDirection"asc"	
elseif al == "asc" then
		ai._sortDirection"desc"	
else
		ai._sortColumnId(nil)
		ai._sortDirection"asc"	
end
end

local function fireSelection(ai)	
local aj= ai.GetSelectedRow(ai)
	for ak, al in ai._selectionCallbacks do
		task.spawn(al, aj)
	end
end

local function findRowByKey(ai, aj, ak)	
if ak == nil then
		return nil
	end
	for al, am in ai do
		if tostring(am[aj]) == ak then
			return am
		end
	end
	return nil
end

function ah.SetSelected(ai, aj)	
if aj == nil then
		if af(ai._selectedKey) ~= nil then
			ai._selectedKey(nil)
			fireSelection(ai)
		end
		return ai
	end

	local ak = tostring(aj)
	if af(ai._selectedKey) == ak then
		return ai
	end

	ai._selectedKey(ak)
	fireSelection(ai)
	return ai
end

function ah.GetSelectedKey(ai)	
return af(ai._selectedKey)
end

function ah.GetSelectedRow(ai)	
return findRowByKey(af(ai._rows), af(ai._rowKey), af(ai._selectedKey))
end

function ah.ClearSelection(ai)	
return ai.SetSelected(ai,nil)
end

function ah.GetPageIndex(ai)	
return af(ai._pageIndex)
end

function ah.HasNextPage(ai)	
return af(ai._nextCursor) ~= nil
end

function ah.HasPreviousPage(ai)	
return af(ai._previousCursor) ~= nil
end

function ah.OnRowClick(ai, aj)	
table.insert(ai._rowClickCallbacks, aj)
	return disconnector(ai._rowClickCallbacks, aj)
end

function ah.OnRowContextMenu(ai, aj)	
table.insert(ai._rowContextCallbacks, aj)
	return disconnector(ai._rowContextCallbacks, aj)
end

function ah.OnPageChange(ai, aj)	
table.insert(ai._pageChangeCallbacks, aj)
	return disconnector(ai._pageChangeCallbacks, aj)
end

function ah.OnSelectionChange(ai, aj)	
table.insert(ai._selectionCallbacks, aj)
	return disconnector(ai._selectionCallbacks, aj)
end

function ah.HandleRowClick(ai, aj, ak)	
local al = af(ai._rowKey)
	local am = aj[al]
	if am ~= nil then
		ai.SetSelected(		ai,tostring(am))
	end
	for an, ao in ai._rowClickCallbacks do
		task.spawn(ao, aj, ak)
	end
end

function ah.HandleRowContextMenu(ai, aj, ak, al)	
for am, an in ai._rowContextCallbacks do
		task.spawn(an, aj, ak, al)
	end
end

local function loadPage(ai, aj, ak, al)	
local am= ai._dataSource
	if not am then
		return
	end

	if not al and ai.IsOnCooldown(ai) then
		return
	end

	ai._fetchToken += 1
	local an = ai._fetchToken

	ai._loading(true)
	ai._errorText(nil)
	ai._cooldownUntil(os.clock() + af(ai._cooldown))

	task.spawn(function()
		local ao, ap= pcall(am, aj)

		if an ~= ai._fetchToken then
			return
		end

		ai._loading(false)

		if not ao then
			ai._errorText(tostring(ap))
			return
		end

		if type(ap) ~= "table" then
			ai._errorText"Invalid response"			
return
		end

		ai._rows(ap.rows or {})
		ai._nextCursor(ap.nextCursor)
		ai._previousCursor(ap.previousCursor)
		ai._currentCursor(aj)
		if ap.error then
			ai._errorText(tostring(ap.error))
		end

		local aq = af(ai._pageIndex)
		local ar = aq
		if ak == 1 then
			ar = aq + 1
		elseif ak == -1 then
			ar = math.max(1, aq - 1)
		elseif ak == 0 then
			ar = 1
		end

		ai._pageIndex(ar)

		local as = af(ai._selectedKey)
		if as and not findRowByKey(af(ai._rows), af(ai._rowKey), as) then
			ai._selectedKey(nil)
			fireSelection(ai)
		end

		for at, au in ai._pageChangeCallbacks do
			task.spawn(au, aj, ar)
		end
	end)
end

function ah.Refresh(ai)	
loadPage(ai, af(ai._currentCursor), 0)
end

function ah.Reload(ai)	
loadPage(ai, nil, 0, true)
end

function ah.NextPage(ai)	
local aj = af(ai._nextCursor)
	if aj then
		loadPage(ai, aj, 1)
	end
end

function ah.PreviousPage(ai)	
local aj = af(ai._previousCursor)
	if aj then
		loadPage(ai, aj, -1)
	end
end

function ah.Render(ai, aj)	
return ag(ad, {
		Table = ai,
		LayoutOrder = aj,
	})
end

function ah.RenderInternal(ai, aj)	
return ag(ad, {
		Table = ai,
		LayoutOrder = aj and aj.layoutOrder,
	})
end





































return constructor
end function a.bl()
local aa = a.load'm'
local ab = a.load'n'

local ac = a.load'aG'
local ad = a.load'a0'
local ae = a.load'aL'
local af = a.load'aJ'
local ag = a.load'a4'
local ah = a.load'a6'
local ai = a.load'a8'
local aj = a.load'ba'
local ak = a.load'bc'
local al = a.load'be'
local am = a.load'bg'
local an = a.load'bi'
local ao = a.load'bk'
local ap = a.load'aN'
local aq = a.load'aZ'

local ar = aa.peek

aq.Options = ad
aq.Toggle = ae
aq.Slider = af
aq.Colorpicker = ag
aq.CurveEditor = ah
aq.Dropdown = ai
aq.Submenu = aj
aq.List = ak.__call
aq.Button = al
aq.Key = am
aq.AssetPicker = an
aq.Table = ao
aq.Textbox = ap

local as= ac
function as.AddElement(at, au, ...)	
local av = aq[au]
	if not av then
		return nil
	end

	local aw = av(...)
	local ax = ar(at._extras)
	at._extras(ab.Array.insert(ax, #ax + 1, aw))

	return aw
end



return aq
end function a.bm()
local aa = a.load'c'
local ab = a.load'm'
local ac = a.load'n'

local ad = a.load'aY'
local ae = a.load'bl'

local af = ab.peek
local ag = ab.atom
local ah = aa.createElement

local ai = {}
ai.__index = ai

local function constructor(aj)	
local ak = (setmetatable({}, ai) )
	
ak._title = aj
	ak._elements = ag{}	
ak._headerAccessory = ag(nil )

	return ak
end

function ai.SetHeaderAccessory(aj, ak)	
aj._headerAccessory(ak)
	return aj
end

function ai.AddElement(aj, ak, ...)	
local al = ae[ak]
	if not al then
		return nil
	end

	local am = al(...)
	local an = af(aj._elements)
	aj._elements(ac.Array.insert(an, #an + 1, am))

	return am
end

function ai.Render(aj)	
return ah(ad, {
		Section = aj,
	})
end










return constructor
end function a.bn()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'n'
local ad = a.load'aX'
local ae = a.load'bm'
local af = a.load'aR'

local ag = aa.peek
local ah = aa.subscribe
local ai = aa.atom
local aj = ab.createElement

local ak = {}
ak.__index = ak

local function constructor(al, am, an)	
local ao = (setmetatable({}, ak) )
	
ao.title = al
	ao.icon = am
	ao.layoutOrder = nil 
	
ao._isOpen = ai(false)

	local ap = an.containers or 1
	local aq = {}

	for ar = 1, ap do
		aq[ar] = {
			_sections = ai{},
		}
	end

	ao._containers = ai(aq)
	ao._customRenderer = ai(nil )
	ao._headerAccessory = ai(nil )
	ao._useScope = ai(false)

	ah(af.openTab, function(ar)
		if ar == ao then
			ao._isOpen(true)
		else
			ao._isOpen(false)
		end
	end)

	return ao
end

function ak.AddSection(al, am, an)	
local ao = ag(al._containers)
	local ap = ao[an]

	local aq = ag(ap._sections)
	local ar = ae(am)
	ap._sections(ac.Array.insert(aq, #aq + 1, ar))

	return ar
end

function ak.GetSection(al, am)	
local an = ag(al._containers)
	for ao, ap in next, an do
		local aq = ag(ap._sections)
		for ar, as in next, aq do
			if as._title == am then
				return as
			end
		end
	end
	return nil
end

function ak.Render(al)	
return aj(ad, {
		Tab = al,
	})
end

function ak.UseScope(al, am)	
al._useScope(am ~= false)
	return al
end

function ak.SetHeaderAccessory(al, am)	
if am then
		al._headerAccessory{ render = am }	
else
		al._headerAccessory(nil)
	end
	return al
end

function ak.SetRenderer(al, am)	
if am then
		al._customRenderer{ render = am }	
else
		al._customRenderer(nil)
	end
	return al
end

function ak.IsOpen(al)	
return ag(al._isOpen)
end


















return constructor
end function a.bo()
local aa = a.load'm'
local ab = a.load'e'
local ac = a.load'd'
local ad = a.load'N'
local ae = a.load'c'
local af = a.load'n'
local ag = a.load's'
local ah = a.load'aR'
local ai = a.load'O'

local aj = a.load'ab'
local ak = ae.useEffect
local al = ab.useSpring
local am = ae.useMemo
local an = ae.useCallback
local ao = ae.useRef
local ap = ae.useState
local aq = ac.useAtom
local ar = aa.peek
local as = ae.createElement

local at = ah.openTab
local au = ad.colors.window

local av = 2
local aw = 14
local ax = 28
local ay = 6








local function TabButton(az)	
local aA = az.tab

	local aB = aq(au.tabStroke)
	local aC = aq(au.tabIcon)

	local aD = aA._isOpen
	local aE = aq(aD)

	local aF = aj(au.sidebar, au.tabSurface, aD)
	local aG = aj(au.tabLabel, au.tabLabelSelected, aD)

	local aH, aI = ab.useSpring(0, {
		tension = 700,
		friction = 50,
	})

	ak(function()
		aI.setGoal(		aI,aE and 1 or 0)
		if aE then
			aF.onMouseLeave()
		end
	end, { aE })

	local aJ = ao(aE)
	aJ.current = aE
	local aK = ao(aA)
	aK.current = aA

	local aL = am(function()
		return function()
			if aJ.current then
				return
			end
			aF.onMouseEnter()
		end
	end, { aF } )

	local aM = am(function()
		return function()
			aF.onMouseLeave()
		end
	end, { aF } )

	local aN = an(function()
		at(aK.current)
		ah.searchQuery""	
end, {})

	local aO = am(function()
		return aH.map(aH,function(aO)
			return 1 - aO
		end)
	end, { aH } )

	return as("TextButton", {
		BackgroundColor3 = aF.binding,
		LayoutOrder = aA.layoutOrder or 2,
		[ae.Event.MouseEnter] = aL,
		[ae.Event.MouseLeave] = aM,
		[ae.Event.MouseButton1Click] = aN,
		Text = "",
		AutoButtonColor = false,
		Active = false,
		Size = UDim2.new(1, 0, 0, 28),
	}, {
		UICorner = as("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),
		UIStroke = as("UIStroke", {
			Color = aB,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = aO,
			Thickness = 1,
		}),
		TabIcon = as("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 8, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.fromOffset(14, 14),
			Image = aA.icon,
			ImageColor3 = aC,
		}),
		TabText = as("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 31, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Text = aA.title,
			FontFace = ag.Get("font", "semi_bold"),
			TextColor3 = aG.binding,
			TextSize = 13,
			Size = UDim2.fromOffset(0, 14),
			AutomaticSize = Enum.AutomaticSize.X,
		}),
	})
end

return function(az)	
local aA = az.TabGroup
	local aB = aA.layoutOrder or 1

	local aC = aq(au.tabHeading)
	local aD = aq(aA.tabs)
	local aE = aq(aA._visible)

	local aF = am(function()
		return af.Array.map(aD, function(aF)
			return as(TabButton, {
				tab = aF,
			})
		end)
	end, { aD })

	local aG = ao(0)
local aH, aI =ap(0)

	local aJ = #aD
	local aK = aJ == 0 and 0 or (aw + aJ * (ax + ay))
	local aL = aK == 0 and 0 or (aK + av * 2)

	ak(function()
		if aL > 0 then
			aG.current = aL
		end
	end, { aL })

	local aM = aE and aL > 0 and 0 or 1
	local aN, aO = al(aM, ai.smooth)

	ak(function()
		aO.setGoal(		aO,aM)
	end, { aM })

	ak(function()
		local aP = aO.onComplete(aO,function(aP)
			if aP < 0.99 then
				return
			end
			if ar(aA._visible) then
				return
			end
			if #ar(aA.tabs) > 0 then
				return
			end
			if aG.current <= 0 then
				return
			end
			aG.current = 0
			aI(function(aQ)
				return aQ + 1
			end)
		end)
		return aP
	end, { aA, aO })

	local aP = aL > 0 and aL or aG.current
	local aQ = UDim2.new(1, 0, 0, math.max(0, aP))
	local aR = UDim2.new(1, 0, 0, math.max(0, aP))

	return as("CanvasGroup", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = aQ,
		GroupTransparency = aN,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = aB,
	}, {
		Inner = as(
			"Frame",
			{
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 0),
				Size = aR,
				BorderSizePixel = 0,
			},
			af.Dictionary.join({
				UIPadding = as("UIPadding", {
					PaddingLeft = UDim.new(0, av),
					PaddingRight = UDim.new(0, av),
					PaddingTop = UDim.new(0, av),
					PaddingBottom = UDim.new(0, av),
				}),
				UIListLayout = as("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Top,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, ay),
				}),
				Title = as("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(0, 14),
					AutomaticSize = Enum.AutomaticSize.X,
					BorderSizePixel = 0,
					FontFace = ag.Get("font", "semi_bold"),
					TextColor3 = aC,
					TextSize = 10,
					LayoutOrder = 0,
					Text = aA.title,
				}),
			}, aF)
		),
	})
end
end function a.bp()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'n'
local ad = a.load'bn'
local ae = a.load'bo'

local af = aa.peek
local ag = ab.createElement
local ah = aa.atom

local ai = {}
ai.__index = ai

local function constructor(aj, ak)	
local al = (setmetatable({}, ai) )
	
al.title = aj
	al.layoutOrder = ak
	al.tabs = ah{}	
al._visible = (ah(true) )
	
return al
end

function ai.AddTab(aj, ak, al, am)	
local an = af(aj.tabs)
	local ao = ad(ak, al, am)
	ao.layoutOrder = #an + 1

	aj.tabs(ac.Array.insert(an, #an + 1, ao))

	return ao
end

function ai.Render(aj)	
return ag(ae, {
		TabGroup = aj,
	})
end












return constructor
end function a.bq()
local aa = a.load'm'
local ab = a.load'c'
local ac = a.load'n'

local ad = a.load'aV'a.load'bn'

local af = a.load'bp'

local ag = aa.peek
local ah = aa.atom
local ai = ab.createElement

local aj = {}
aj.__index = aj

local function constructor(ak)	
local al = (setmetatable({}, aj) )
	
al._name = ak
	al._isOpen = ah(false)
	al._size = ah(UDim2.fromOffset(680, 560))
	al._position = ah(UDim2.fromScale(0.5, 0.5))
	al._tabGroups = (ah{})
	
return al
end

function aj.AddTabGroup(ak, al, am)	
local an = ag(ak._tabGroups)
	local ao = af(al, am or (#an + 1))

	ak._tabGroups(ac.Array.insert(an, #an + 1, ao))

	return ao
end

function aj.GetTabGroup(ak, al)	
for am, an in ag(ak._tabGroups) do
		if an.title == al then
			return an
		end
	end
	return nil
end

function aj.RemoveTabGroup(ak, al)	
local am = ag(ak._tabGroups)
	local an = {}
	for ao, ap in next, am do
		if ap.title ~= al then
			table.insert(an, ap)
		end
	end
	ak._tabGroups(an)
end

function aj.AddTabToGroup(
	ak,
	al,
	am,
	an,
	ao
)	
local ap = ak.GetTabGroup(ak,al)
	if not ap then
		return nil
	end
	return ap.AddTab(ap,am, an, ao or {})
end

function aj.IsOpen(ak)	
return ag(ak._isOpen)
end

function aj.SetOpen(ak, al)	
ak._isOpen(al)
end

function aj.ToggleOpen(ak)	
ak._isOpen(not ag(ak._isOpen))
end

function aj.SetSize(ak, al)	
ak._size(al)
end

function aj.SetPosition(ak, al)	
ak._position(al)
end

function aj.Render(ak)	
return ai(ad, {
		Window = ak,
	})
end












return constructor
end function a.br()
local aa = a.load'm'
local ab = a.load'n'a.load'bq'


local ad = a.load'E'

local ae = aa.peek
local af = aa.atom

local ag = {
	windows = af({} ),
}

function ag.Add(ah)	
local ai = ae(ag.windows)
	ag.windows(ab.Array.insert(ai, #ai + 1, ah))

	ah.SetOpen(
	ah,ae(ad.isOpen))

	return ah
end

function ag.SetAllOpen(ah)	for ai, aj in next, ae(ag.windows) do
		aj.SetOpen(		aj,ah)
	end
end




return ag
end function a.bs()
local aa = a.load'm'

local ab = aa.atom

local ac = {
	position = ab(UDim2.fromOffset(20, 500)),
	showBindList = ab(false),
}



return ac
end function a.bt()
local aa = a.load'e'
local ab = a.load'd'
local ac = a.load'c'

local ad = a.load's'
local ae = a.load'N'
local af = a.load'E'
local ag = a.load'bs'
local ah = a.load'L'
local ai = a.load'al'
local aj = a.load'U'
local ak = a.load'O'

local al = a.load'm'

local am = aa.useSpring
local an = ab.useAtom
local ao = ac.useEffect
local ap = ac.useMemo
local aq = ac.useState
local ar = ac.useRef
local as = al.peek
local at = al.subscribe
local au = ac.memo
local av = ac.createElement

local aw = ae.colors.hud
local ax = ae.colors.window.element

local ay = 94
local az = 30
local aA = 20
local aB = 4
local aC = 6
local aD = 6
local aE = 5
local aF = 28
local aG = 18
local aH = 10
local aI = 6
local aJ = 60
local aK = 180

local aL = Vector2.new(0, 0.5)
local aM = Vector2.new(1, 0.5)
local aN = UDim.new(0, aC)
local aO = UDim.new(1, 0)
local aP = UDim.new(0, 2)
local aQ = UDim.new(0, 5)
local aR = UDim.new(0, 6)
local aS = UDim.new(0, 8)
local aT = UDim.new(0, 3)
local aU = UDim.new(0, aB)
local aV = UDim2.fromOffset(aG, aH)
local aW = UDim2.new(0, 5, 0.5, 0)
local aX = UDim2.new(0, aF, 0.5, 0)
local aY = UDim2.fromOffset(0, 14)
local aZ = UDim2.fromOffset(0, 11)
local b = UDim2.fromOffset(aI, aI)
local c = UDim2.new(1, 0, 0.5, 0)
local d = UDim2.fromOffset(0, aA)
local e = UDim2.fromOffset(0, 14)
local f = UDim2.fromOffset(14, 14)
local g = UDim2.new(1, 0, 1, 0)
local h = Vector2.new(0.5, 0.5)
local i = UDim2.fromScale(0.5, 0.5)
local j = Vector2.new(aK, math.huge)
local k = Vector2.new(aJ, math.huge)
local l = UDim2.fromOffset(ay, az)
local m = Vector2.new(1.3, 1.47)
local n = Vector2.new(1.35, 1.47)

local function shouldDisplay(o, p)	
return o and p
end

local function formatBindStateValue(o)	
local p = type(o)
	if p == "boolean" then
		return o and "On" or "Off"
	elseif p == "number" then
		local q = math.round(o * 1000) / 1000
		local r = string.format("%.3f", q)
		r = r.gsub(r,"0+$", "")
		r = r.gsub(r,"%.$", "")
		return r
	elseif p == "string" then
		return o
	end
	return "—"
end

local function ToggleBind(o









)	
local p = o.parentTransparency
	local q = p.map(p,function(q)
		return 1 - (1 - o.bgAlpha) * (1 - q)
	end)
	local r = p.map(p,function(r)
		return 1 - (1 - o.trackAlpha) * (1 - r)
	end)

	return av("Frame", {
		BackgroundColor3 = o.bgColor,
		BackgroundTransparency = q,
		BorderSizePixel = 0,
		Size = d,
		AutomaticSize = Enum.AutomaticSize.X,
	}, {
		UICorner = av("UICorner", {
			CornerRadius = aN,
		}),
		Toggle = av("Frame", {
			Size = aV,
			BackgroundColor3 = o.trackColor,
			BackgroundTransparency = r,
			BorderSizePixel = 0,
			Position = aW,
			AnchorPoint = aL,
		}, {
			UICorner = av("UICorner", {
				CornerRadius = aO,
			}),
			UIPadding = av("UIPadding", {
				PaddingLeft = aP,
				PaddingRight = aP,
				PaddingTop = aP,
				PaddingBottom = aP,
			}),
			Circle = av("Frame", {
				Size = b,
				BackgroundColor3 = o.knobColor,
				BackgroundTransparency = p,
				BorderSizePixel = 0,
				Position = c,
				AnchorPoint = aM,
			}, {
				UICorner = av("UICorner", {
					CornerRadius = aO,
				}),
			}),
		}),
		Name = av("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = o.name,
			TextSize = 12,
			TextColor3 = o.textColor,
			TextTransparency = p,
			FontFace = ad.Get("font", "semi_bold"),
			Size = aY,
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = aX,
			AnchorPoint = aL,
		}, {
			UISizeConstraint = av("UISizeConstraint", {
				MaxSize = j,
			}),
			UIPadding = av("UIPadding", {
				PaddingRight = aS,
			}),
		}),
	})
end

local function TextBind(o







)	
local p = o.parentTransparency
	local q = p.map(p,function(q)
		return 1 - (1 - o.bgAlpha) * (1 - q)
	end)

	return av("Frame", {
		BackgroundColor3 = o.bgColor,
		BackgroundTransparency = q,
		BorderSizePixel = 0,
		Size = d,
		AutomaticSize = Enum.AutomaticSize.X,
	}, {
		UICorner = av("UICorner", {
			CornerRadius = aN,
		}),
		UIListLayout = av("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = aR,
		}),
		UIPadding = av("UIPadding", {
			PaddingLeft = aS,
			PaddingRight = aS,
		}),
		Value = av("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = o.value,
			TextSize = 10,
			TextColor3 = o.valueColor,
			TextTransparency = p,
			FontFace = ad.Get("font", "semi_bold"),
			Size = aZ,
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 0,
		}, {
			UISizeConstraint = av("UISizeConstraint", {
				MaxSize = k,
			}),
		}),
		Name = av("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = o.name,
			TextSize = 12,
			TextColor3 = o.textColor,
			TextTransparency = p,
			FontFace = ad.Get("font", "semi_bold"),
			Size = aY,
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 1,
		}, {
			UISizeConstraint = av("UISizeConstraint", {
				MaxSize = j,
			}),
		}),
	})
end

local function Chip(o







)	
local p= {
		UICorner = av("UICorner", { CornerRadius = aT }),
		UIPadding = av("UIPadding", {
			PaddingLeft = aQ,
			PaddingRight = aQ,
		}),
	}

	if o.icon then
		p.Icon = av("ImageLabel", {
			BackgroundTransparency = 1,
			Image = o.icon,
			ImageColor3 = o.textColor,
			ImageTransparency = o.parentTransparency,
			Size = f,
			AnchorPoint = h,
			Position = i,
		})
	else
		p.Label = av("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = o.text or "?",
			TextSize = 10,
			TextColor3 = o.textColor,
			TextTransparency = o.parentTransparency,
			FontFace = ad.Get("font", "semi_bold"),
			Size = g,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	end

	return av("Frame", {
		BackgroundColor3 = o.bgColor,
		BackgroundTransparency = o.parentTransparency:map(function(q)
			return 1 - (1 - o.bgAlpha) * (1 - q)
		end),
		BorderSizePixel = 0,
		Size = e,
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = o.layoutOrder,
	}, p)
end

local o = au(function(o



)	
local p = o.entry.element

	local q = an(p._state, { p })
	local r = p._formattedValue or p._state
	local s = an(r, { p })

	local t = an(aw.background)
	local u = (t[1] )	
local v = (t[2] )	
local w = an(aw.backgroundSecondary)
	local x = (w[1] )	
local y = (w[2] )
	
local z = an(aw.title)
	local A = an(aw.text)
	local B = an(ax.thumbActive)
	local C = an(ax.thumb)

	local D = o.slotIndex ~= nil
	local E = ar(o.slotIndex or 0)
	if o.slotIndex ~= nil then
		E.current = o.slotIndex
	end
	local F = E.current
	local G = F * (aA + aB)

	local H, I = am(G, ak.smoothPrecise)

	ao(function()
		I.setGoal(		I,G)
	end, { G })

	local J, K = am(0, ak.smoothPrecise)

	ao(function()
		K.setGoal(		K,D and 1 or 0)
	end, { D })

	local L = ac.joinBindings{ H, J }:map(function(L)
		local M = L[1]
		local N = L[2]
		return UDim2.new(0, 0, 0, M - (1 - N) * aE)
	end)

	local M = ac.joinBindings{ o.parentTransparency, J }:map(function(M)
		local N = M[1]
		local O = M[2]
		return 1 - (1 - N) * O
	end)

	local N = if p._formattedValue ~= nil and s ~= nil and s ~= ""
		then tostring(s)
		else formatBindStateValue(q)
	local O = type(q)

	local P = J.map(J,function(P)
		return P > 0.001
	end)

	local Q = an(aw.shadow)
	local R = (Q[1] )	
local S = (Q[2] )
	
local T = M.map(M,function(T)
		return 1 - (1 - T) * (1 - S)
	end)

	local U = O == "boolean"
			and av(ToggleBind, {
				name = o.entry.label,
				on = q ,
				bgColor = u,
				bgAlpha = v,
				trackColor = x,
				trackAlpha = y,
				knobColor = q and B or C,
				textColor = A,
				parentTransparency = M,
			})
		or av(TextBind, {
			name = o.entry.label,
			value = N,
			bgColor = u,
			bgAlpha = v,
			valueColor = z,
			textColor = A,
			parentTransparency = M,
		})

	return av("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = L,
		Size = d,
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = P,
	}, {
		Shadow = aj{
			color = R,
			transparency = T,
			multiplier = n,
			zIndex = 0,
		},
		Pill = av("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = d,
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 1,
		}, {
			Content = U,
		}),
	})
end)

local p = au(function(p


)	
local q = an(aw.background)
	local r = (q[1] )	
local s = (q[2] )	
local t = an(aw.stroke)
	local u = (t[1] )	
local v = (t[2] )	
local w = an(aw.image)
	local x = an(aw.title)

	local y = an(aw.shadow)
	local z = (y[1] )	
local A = (y[2] )
	
local B = p.widgetBind:map(function(B)
		local C = 1 - B * 0.7
		return 1 - (1 - C) * (1 - A)
	end)

	return av("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = l,
		LayoutOrder = 0,
	}, {
		Shadow = aj{
			color = z,
			transparency = B,
			multiplier = m,
			zIndex = 0,
		},
		Bar = av("Frame", {
			BackgroundColor3 = r,
			BackgroundTransparency = p.parentTransparency:map(function(C)
				return 1 - (1 - s) * (1 - C)
			end),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0),
			ZIndex = 1,
		}, {
			UICorner = av("UICorner", {
				CornerRadius = aN,
			}),
			UIStroke = av("UIStroke", {
				Color = u,
				Thickness = 1,
				Transparency = p.parentTransparency:map(function(C)
					return 1 - (1 - v) * (1 - C)
				end),
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = av("UIPadding", {
				PaddingLeft = aS,
				PaddingRight = aS,
			}),
			UIListLayout = av("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = aR,
			}),
			IconChip = av(Chip, {
				icon = ad.Get("image", "keybinds"),
				textColor = w,
				bgAlpha = 1,
				parentTransparency = p.parentTransparency,
				layoutOrder = 0,
			}),
			Title = av("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = "Keybinds",
				TextSize = 14,
				TextColor3 = x,
				TextTransparency = p.parentTransparency,
				FontFace = ad.Get("font", "semi_bold"),
				Size = aY,
				AutomaticSize = Enum.AutomaticSize.X,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
			}),
		}),
	})
end)

return function()	
local q = an(ah.allBinds)
	local r = an(ag.showBindList)
	local s = an(af.isOpen)

	local t, u = ai(ag.position)

	local v, w = am(0, ak.smoothPrecise)

	ao(function()
		w.setGoal(		w,r and 1 or 0)
	end, { r })

	local x = ap(function()
		return v.map(v,function(x)
			return 1 - x
		end)
	end, { v })
local
y, z =aq(0)
	ao(function()
		local A= {}
		for B, C in next, q do
			table.insert(
				A,
				at(C.bind.active, function()
					z(function(D)						
return D + 1
					end)
				end)
			)
			table.insert(
				A,
				at(C.bind.showInList, function()
					z(function(D)						
return D + 1
					end)
				end)
			)
		end
		return function()
			for B, C in next, A do
				C()
			end
		end
	end, { q })

	local A= {}
	local B = 0
	for C, D in next, q do
		if shouldDisplay(as(D.bind.showInList), as(D.bind.active)) then
			A[D.bind.id] = B
			B += 1
		end
	end

	local C= {}
	for D, E in next, q do
		C[`Row_{E.bind.id}`] = av(o, {
			entry = E,
			slotIndex = A[E.bind.id],
			parentTransparency = x,
		})
	end

	local D = B * aA + math.max(0, B - 1) * aB

	return av("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = ac.joinBindings{ v, u }:map(function(E)
			local F= E[1]
			local G= E[2]
			local H = (1 - F) * aD
			return UDim2.new(
				G.X.Scale,
				G.X.Offset,
				G.Y.Scale,
				((G.Y.Offset )) - H
			)
		end),
		Visible = v.map(v,function(E)
			return E > 0.01
		end),
	}, {
		Main = av("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			ZIndex = 1,
			[ac.Event.InputBegan] = s and function(E, F)
				t(F)
			end or nil,
		}, {
			UIListLayout = av("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = aU,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			Header = av(p, {
				parentTransparency = x,
				widgetBind = v,
			}),
			Rows = av("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 0, D),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 1,
			}, C),
		}),
	})
end
end function a.bu()
local aa = a.load'm'

local ab = aa.atom

local ac = {
	username = (ab""),
	cheat = (ab"limerence"),
	gameName = (ab""),
	ping = (ab(0) ),
	fps = (ab(0) ),
	playTime = (ab(0) ),
}



return ac
end function a.bv()
local aa = {}

function aa.format(ab)	
ab = math.max(0, math.floor(ab))
	if ab >= 3600 then
		local ac = math.floor(ab / 3600)
		local ad = math.floor((ab % 3600) / 60)
		local ae = ab % 60
		return string.format("%d:%02d:%02d", ac, ad, ae)
	end
	local ac = math.floor(ab / 60)
	local ad = ab % 60
	return string.format("%d:%02d", ac, ad)
end

return aa
end function a.bw()
local aa = a.load'c'
local ab = a.load'm'

local ac = aa.createBinding
local ad = aa.useEffect
local ae = aa.useRef
local af = ab.peek
local ag = ab.subscribe

local ah = LPH_NO_VIRTUALIZE(function(ah)	
local ai = ae(nil )
	local aj = ae(nil )

	if ai.current == nil then
		local ak, al = ac(af(ah))
		ai.current = ak
		aj.current = al
	end

	ad(function()
		aj.current(af(ah))
		return ag(ah, function(ak)			
aj.current(ak)
		end)
	end, { ah })

	return ai.current
end)

return ah
end function a.bx()
local aa = (cloneref(game.GetService(game, "UserInputService")) )

local ab = a.load'e'
local ac = a.load'd'
local ad = a.load'c'
local ae = a.load'm'

local af = a.load's'
local ag = a.load'bu'
local ah = a.load'bv'
local ai = a.load'H'
local aj = a.load'G'
local ak = a.load'N'
local al = a.load'E'
local am = a.load'I'
local an = a.load'X'
local ao = a.load'Y'
local ap = a.load'U'
local aq = a.load'al'
local ar = a.load'bw'
local as = a.load'O'

local at = ab.useSpring
local au = ac.useAtom
local av = ad.useEffect
local aw = ad.useMemo
local ax = ad.useRef
local ay = ad.useState
local az = ad.useCallback
local aA = ad.memo
local aB = ad.createElement

local aC = ak.colors.hud

local aD = 28
local aE = 14
local aF = 14
local aG = 14
local aH = 8
local aI = 4
local aJ = 6
local aK = 6
local aL = 6
local aM = 0.42
local aN = 0.38



local function hitIndexAtIconX(
	aO,
	aP,
	aQ
)	
for aR, aS in next, aO do
		local aT = aP[aS]
		if aT then
			local aU = aT.AbsoluteSize.X
			if aU > 0 then
				local aV = aT.AbsolutePosition.X
				if aQ >= aV and aQ <= aV + aU then
					return aR
				end
			end
		end
	end
	return nil
end

local aO = aA(function(aO












)	
local aP = au(aC.image)
	local aQ = au(aC.title)

	local aR = ax(nil )
	local aS = ax(nil )
	local aT = ax(nil )
	local aU, aV = ay(0)

	av(function()
		aO.onRegisterIcon(aO.id, aT.current)
		return function()
			aO.onRegisterIcon(aO.id, nil)
		end
	end, { aO.id, aO.onRegisterIcon })

	av(function()
		local aW = aS.current
		if not aW then
			return
		end
		local function readWidth()			
local aX = ae.peek(am.scale)
			if aX <= 0 then
				aX = 1
			end
			return aW.AbsoluteSize.X / aX
		end
		aV(readWidth())
		local aX = aW.GetPropertyChangedSignal(aW, "AbsoluteSize"):Connect(function()
			if aS.current then
				aV(readWidth())
			end
		end)
		return function()
			aX.Disconnect(			aX)
		end
	end, {})

	local aW = aO.shown and (aU + aJ) or 0
	local aX, aY = at(aW, as.smoothPrecise)

	av(function()
		aY.setGoal(		aY,aW)
	end, { aW })

	local aZ, b = at(not aO.shown and 1 or 0, as.smoothPrecise)

	av(function()
		b.setGoal(		b,not aO.shown and 1 or 0)
	end, { aO.shown })

	local c = aO.canReorder
		and aO.draggingId ~= nil
		and aO.id ~= aO.draggingId
		and aO.id ~= aO.hoverTargetId

	local d, e = at(0, as.smoothPrecise)

	av(function()
		e.setGoal(		e,c and 1 or 0)
	end, { c })

	local f = aw(function()
		return aX.map(aX,function(f)
			return UDim2.fromOffset(math.max(0, f), aD)
		end)
	end, { aX })

	local g = aw(function()
		return ad.joinBindings{ aZ, aO.masterFade, d }:map(function(g)
			local h = g[1]
			local i = g[2]
			local j = g[3]
			local k = 1 - j * aM
			return 1 - (1 - h) * (1 - i) * k
		end)
	end, { aZ, aO.masterFade, d } )

	local h = aw(function()
		local h = aP.Lerp(aP,Color3.new(0, 0, 0), aN)
		return d.map(d,function(i)
			return aP.Lerp(aP,h, i)
		end)
	end, { d, aP } )

	local i = aw(function()
		local i = aQ.Lerp(aQ,Color3.new(0, 0, 0), aN)
		return d.map(d,function(j)
			return aQ.Lerp(aQ,i, j)
		end)
	end, { d, aQ } )

	local j = az(function(j, k)		
if not aO.canReorder or k.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		aO.onIconPress(aO.id)
	end, { aO.canReorder, aO.id, aO.onIconPress, aO.onContextOpen })

	return aB("Frame", {
		ref = aR,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = aO.layoutOrder,
		Size = f,
		Active = false,
		ZIndex = aO.draggingId == aO.id and 3 or 1,
	}, {
		Content = aB("Frame", {
			ref = aS,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, aD),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
		}, {
			UIListLayout = aB("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, aI),
			}),
			Icon = aB("ImageButton", {
				ref = aT,
				Active = false,
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = aO.icon,
				ImageColor3 = h,
				ImageTransparency = g,
				Size = UDim2.fromOffset(aG, aG),
				LayoutOrder = 0,
				[ad.Event.InputBegan] = j,
			}),
			Text = aB("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = aO.text,
				TextSize = aF,
				TextColor3 = i,
				TextTransparency = g,
				FontFace = af.Get("font", "semi_bold"),
				Size = UDim2.fromOffset(0, aE),
				AutomaticSize = Enum.AutomaticSize.X,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = 1,
				Active = false,
			}),
		}),
	})
end)

local function buildItems(aP)	
local aQ = af.Get("image", "checkmark")
	local function entry(aR, aS)		
local aT = ae.peek(aS)
		return {
			Label = aR,
			Icon = aT and aQ or nil,
			Callback = function()
				aS(not aT)
				aP()
			end,
		}
	end
	return {
		entry("Show Play Time", ai.showPlaytime),
		entry("Show Username", ai.showUsername),
		entry("Show Cheat", ai.showCheat),
		entry("Show Game", ai.showGame),
		entry("Show Ping", ai.showPing),
		entry("Show FPS", ai.showFps),
	}
end

return function()	
local aP = au(ai.enabled)
	local aQ = au(al.isOpen)
	local aR = au(ai.itemOrder)

	local aS = ar(ag.username)
	local aT = ar(ag.cheat)
	local aU = ar(ag.gameName)
	local aV = ar(ag.ping)
	local aW = ar(ag.fps)
	local aX = ar(ag.playTime)

	local aY = aw(function()
		return aV.map(aV,function(aY)
			return `{aY}ms`
		end)
	end, { aV })

	local aZ = aw(function()
		return aW.map(aW,function(aZ)
			return `{aZ} fps`
		end)
	end, { aW })

	local b = aw(function()
		return aX.map(aX,ah.format)
	end, { aX })

	local c = au(ai.showUsername)
	local d = au(ai.showCheat)
	local e = au(ai.showGame)
	local f = au(ai.showPing)
	local g = au(ai.showFps)
	local h = au(ai.showPlaytime)

	local i = au(aC.background)
	local j = (i[1] )	
local k = (i[2] )
	
local l = au(aC.stroke)
	local m = (l[1] )	
local n = (l[2] )
	
local o = au(aC.shadow)
	local p = (o[1] )	
local q = (o[2] )
	
local r, s = at(0, as.smoothPrecise)

	av(function()
		s.setGoal(		s,aP and 1 or 0)
	end, { aP })

	local t, u = aq(ai.position)

	local v = ax(nil )
	local w = ax({} )
	local x = ax(nil )
	local y, z = ay(nil )
	local A, B = ay(nil )

	local C = ax(nil )
	local D, E = ay(0)

	av(function()
		local F = v.current
		if not F then
			return
		end
		local function readWidth()			
local G = ae.peek(am.scale)
			if G <= 0 then
				G = 1
			end
			return F.AbsoluteContentSize.X / G
		end
		E(readWidth())
		local G = F.GetPropertyChangedSignal(F, "AbsoluteContentSize"):Connect(function()
			if v.current then
				E(readWidth())
			end
		end)
		return function()
			G.Disconnect(			G)
		end
	end, { aR })

	local F = az(function(F, G)		
w.current[F] = G
	end, {})

	local G = az(function(G)		
if not aQ or x.current then
			return
		end
		local H = ae.peek(ai.itemOrder)
		local I = aj.indexOf(H, G)
		if not I then
			return
		end
		x.current = I
		z(G)
		B(nil)
	end, { aQ })

	av(function()
		if not y then
			return
		end

		local H = aa.InputChanged:Connect(LPH_NO_VIRTUALIZE(function(H)			
if H.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			local I = x.current
			if not I then
				return
			end
			local J = ae.peek(ai.itemOrder)
			local K = hitIndexAtIconX(J, w.current, H.Position.X)
			local L = if K then J[K] else nil
			B(L)

			if K and K ~= I then
				local M = aj.swap(J, I, K)
				ai.itemOrder(M)
				x.current = K
			end
		end))

		local I = aa.InputEnded:Connect(function(I)			
if I.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			x.current = nil
			z(nil)
			B(nil)
		end)

		return function()
			H.Disconnect(			H)
			I.Disconnect(			I)
		end
	end, { y })

	local H = D + aH * 2 - aJ

	local I = aw(function()
		return r.map(r,function(I)
			return 1 - I
		end)
	end, { r })

	local J = r.map(r,function(J)
		return UDim2.fromOffset(math.max(0, H) * J, aD)
	end)

	local K = aw(function()
		return ad.joinBindings{ r, u }:map(function(K)
			local L= K[1]
			local M= K[2]
			local N = (1 - L) * aL
			return UDim2.new(M.X.Scale, M.X.Offset, M.Y.Scale, ((M.Y.Offset )) - N)
		end)
	end, { r, u } )

	local L = aw(function()
		return r.map(r,function(L)
			return L > 0.001
		end)
	end, { r })

	local M = aw(function()
		return r.map(r,function(M)
			return 1 - M * (1 - k)
		end)
	end, { r, k } )

	local N = aw(function()
		return r.map(r,function(N)
			return 1 - N * (1 - n)
		end)
	end, { r, n } )

	local O = aw(function()
		return r.map(r,function(O)
			return 1 - O * (1 - q)
		end)
	end, { r, q } )

	local P = aQ and aP

	local Q = aw(
		function()
			return {
				cheat = {
					icon = af.Get("image", "logo"),
					text = aT,
					shown = d,
				},
				game = {
					icon = af.Get("image", "terrain"),
					text = aU,
					shown = e,
				},
				ping = {
					icon = af.Get("image", "latency"),
					text = aY,
					shown = f,
				},
				fps = {
					icon = af.Get("image", "computer"),
					text = aZ,
					shown = g,
				},
				playtime = {
					icon = af.Get("image", "clock"),
					text = b,
					shown = h,
				},
				username = {
					icon = af.Get("image", "person"),
					text = aS,
					shown = c,
				},
			}
		end,
		{
			aT,
			aU,
			aY,
			aZ,
			b,
			aS,
			d,
			e,
			f,
			g,
			h,
			c,
		} 	
)

	local R = az(function(R)		
if not aP then
			return
		end
		local S = ao.getPosition(R)
		C.current = S
		local function refresh()
			local T = C.current
			if T then
				an.Open(buildItems(refresh), T)
			end
		end
		an.Open(buildItems(refresh), S)
	end, { aP })

	local S = az(function(S, T)		
if not aP or not aQ or x.current then
			return
		end
		if T.UserInputType == Enum.UserInputType.MouseButton1 then
			t(T)
		elseif T.UserInputType == Enum.UserInputType.MouseButton2 then
			R(T)
		end
	end, { aP, aQ, t })

	local T = aw(
		function()
			local T= {
				UICorner = aB("UICorner", {
					CornerRadius = UDim.new(0, aK),
				}),
				UIStroke = aB("UIStroke", {
					Color = m,
					Transparency = N,
					Thickness = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				UIPadding = aB("UIPadding", {
					PaddingLeft = UDim.new(0, aH),
					PaddingRight = UDim.new(0, aH - aJ),
				}),
				UIListLayout = aB("UIListLayout", {
					ref = v,
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),
			}

			for U, V in next, aR do
				local W = Q[V]
				if W then
					T[V] = aB(aO, {
						key = V,
						id = V,
						icon = W.icon,
						text = W.text,
						shown = W.shown,
						masterFade = I,
						layoutOrder = U,
						canReorder = P,
						draggingId = y,
						hoverTargetId = A,
						onRegisterIcon = F,
						onIconPress = G,
						onContextOpen = R,
					})
				end
			end

			return T
		end,
		{
			aR,
			Q,
			I,
			m,
			N,
			P,
			y,
			A,
			F,
			G,
			R,
		} 	
)

	return aB("Frame", {
		Active = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = K,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = J,
		Visible = L,
	}, {
		Shadow = ap{
			color = p,
			transparency = O,
			zIndex = 0,
			multiplier = Vector2.new(1.24, 1.46),
		},
		Body = aB("Frame", {
			BackgroundColor3 = j,
			BackgroundTransparency = M,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			ClipsDescendants = true,
			Active = false,
			[ad.Event.InputBegan] = S,
		}, T),
	})
end
end function a.by()
local aa= {}

return aa
end function a.bz()
local aa = a.load'm'

local ab = aa.atom

local ac = {
	enabled = ab(false),
	position = ab(UDim2.new(0.5, 0, 1, -80)),
}



return ac
end function a.bA()
local aa = (cloneref(game.GetService(game, "RunService")) )

local ab = a.load'e'
local ac = a.load'd'
local ad = a.load'c'
local ae = a.load'm'

local af = a.load's'
local ag = a.load'by'
local ah = a.load'bz'
local ai = a.load'N'
local aj = a.load'E'
local ak = a.load'al'
local al = a.load'U'
local am = a.load'O'

local an = ab.useSpring
local ao = ac.useAtom
local ap = ad.useEffect
local aq = ad.useMemo
local ar = ad.useBinding
local as = ad.createElement

local at = ae.peek

local au = ai.colors.hud

local av = 12.5
local aw = 28
local ax = 72
local ay = 14
local az = 8
local aA = 6
local aB = 6

return function()	
local aC = ao(ah.enabled)
	local aD = ao(aj.isOpen)

	local aE, aF = ar"0 u/s"
	
ap(function()
		if not aC then
			aF"0 u/s"			
return
		end
		local aG = ag.clientState
		if not aG then
			return
		end
		local aH = aa.RenderStepped:Connect(function()
			local aH = at(aG.parts)
			local aI = (aH.HumanoidRootPart )			
if not aI then
				aF"0 u/s"				
return
			end
			local aJ = aI.AssemblyLinearVelocity
			local aK = math.sqrt(aJ.X * aJ.X + aJ.Z * aJ.Z) * av
			aF(string.format("%d u/s", aK + 0.5))
		end)
		return function()
			aH.Disconnect(			aH)
		end
	end, { aC })

	local aG = ao(au.title)

	local aH = ao(au.background)
	local aI = (aH[1] )	
local aJ = (aH[2] )
	
local aK = ao(au.stroke)
	local aL = (aK[1] )	
local aM = (aK[2] )
	
local aN = ao(au.shadow)
	local aO = (aN[1] )	
local aP = (aN[2] )
	
local aQ, aR = an(0, am.smoothPrecise)

	ap(function()
		aR.setGoal(		aR,aC and 1 or 0)
	end, { aC })

	local aS, aT = ak(ah.position)

	local aU = aq(function()
		return aQ.map(aQ,function(aU)
			return UDim2.fromOffset(ax * aU, aw)
		end)
	end, { aQ })

	local aV = aq(function()
		return ad.joinBindings{ aQ, aT }:map(function(aV)
			local aW= aV[1]
			local aX= aV[2]
			local aY = (1 - aW) * aB
			return UDim2.new(aX.X.Scale, aX.X.Offset, aX.Y.Scale, ((aX.Y.Offset )) + aY)
		end)
	end, { aQ, aT } )

	local aW = aq(function()
		return aQ.map(aQ,function(aW)
			return aW > 0.001
		end)
	end, { aQ })

	local aX = aq(function()
		return aQ.map(aQ,function(aX)
			return 1 - aX * (1 - aJ)
		end)
	end, { aQ, aJ } )

	local aY = aq(function()
		return aQ.map(aQ,function(aY)
			return 1 - aY * (1 - aM)
		end)
	end, { aQ, aM } )

	local aZ = aq(function()
		return aQ.map(aQ,function(aZ)
			return 1 - aZ * (1 - aP)
		end)
	end, { aQ, aP } )

	local b = aq(function()
		return aQ.map(aQ,function(b)
			return 1 - b
		end)
	end, { aQ })

	local function onInputBegan(c, d)		
if not aD or not aC then
			return
		end
		if d.UserInputType == Enum.UserInputType.MouseButton1 then
			aS(d)
		end
	end

	return as("Frame", {
		Active = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = aV,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = aU,
		Visible = aW,
		[ad.Event.InputBegan] = onInputBegan,
	}, {
		Shadow = al{
			color = aO,
			transparency = aZ,
			zIndex = 0,
			multiplier = Vector2.new(1.24, 1.46),
		},
		Body = as("Frame", {
			BackgroundColor3 = aI,
			BackgroundTransparency = aX,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			ClipsDescendants = true,
		}, {
			UICorner = as("UICorner", {
				CornerRadius = UDim.new(0, aA),
			}),
			UIStroke = as("UIStroke", {
				Color = aL,
				Transparency = aY,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = as("UIPadding", {
				PaddingLeft = UDim.new(0, az),
				PaddingRight = UDim.new(0, az),
			}),
			Text = as("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = aE,
				TextSize = ay,
				TextColor3 = aG,
				TextTransparency = b,
				FontFace = af.Get("font", "semi_bold"),
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		}),
	})
end
end function a.bB()
local aa = a.load'm'

local ab = aa.atom

local ac = {
	enabled = ab(false),
	position = ab(UDim2.new(0.5, 0, 0, 80)),
	hideWhenEmpty = ab(true),
}



return ac
end function a.bC()
local aa = a.load'e'
local ab = a.load'd'
local ac = a.load'c'
local ad = a.load'm'

local ae = a.load's'
local af = a.load'by'

local ag = ad.atom(0)
local ah = a.load'bB'
local ai = a.load'N'
local aj = a.load'E'
local ak = a.load'al'
local al = a.load'U'
local am = a.load'O'

local an = aa.useSpring
local ao = ab.useAtom
local ap = ac.useEffect
local aq = ac.useMemo
local ar = ac.createElement

local as = ai.colors.hud

local at = 28
local au = 14
local av = 14
local aw = 8
local ax = 6
local ay = 6
local az = 6

return function()	
local aA = ao(ah.enabled)
	local aB = ao(ah.hideWhenEmpty)
	local aC = ao(aj.isOpen)
	local aD = af.clientState
	local aE = (aD and aD.spectatorCount) or ag
	local aF = (ao(aE) )
	
local aG = aA and (aC or not aB or aF > 0)

	local aH = ao(as.title)
	local aI = ao(as.image)

	local aJ = ao(as.background)
	local aK = (aJ[1] )	
local aL = (aJ[2] )
	
local aM = ao(as.stroke)
	local aN = (aM[1] )	
local aO = (aM[2] )
	
local aP = ao(as.shadow)
	local aQ = (aP[1] )	
local aR = (aP[2] )
	
local aS, aT = an(0, am.smoothPrecise)

	ap(function()
		aT.setGoal(		aT,aG and 1 or 0)
	end, { aG })

	local aU, aV = ak(ah.position)

	local aW = aq(function()
		return aS.map(aS,function(aW)
			return UDim2.fromOffset(0, at * aW)
		end)
	end, { aS })

	local aX = aq(function()
		return ac.joinBindings{ aS, aV }:map(function(aX)
			local aY= aX[1]
			local aZ= aX[2]
			local b = (1 - aY) * az
			return UDim2.new(aZ.X.Scale, aZ.X.Offset, aZ.Y.Scale, ((aZ.Y.Offset )) - b)
		end)
	end, { aS, aV } )

	local aY = aq(function()
		return aS.map(aS,function(aY)
			return aY > 0.001
		end)
	end, { aS })

	local aZ = aq(function()
		return aS.map(aS,function(aZ)
			return 1 - aZ * (1 - aL)
		end)
	end, { aS, aL } )

	local b = aq(function()
		return aS.map(aS,function(b)
			return 1 - b * (1 - aO)
		end)
	end, { aS, aO } )

	local c = aq(function()
		return aS.map(aS,function(c)
			return 1 - c * (1 - aR)
		end)
	end, { aS, aR } )

	local d = aq(function()
		return aS.map(aS,function(d)
			return 1 - d
		end)
	end, { aS })

	local function onInputBegan(e, f)		
if not aC or not aA then
			return
		end
		if f.UserInputType == Enum.UserInputType.MouseButton1 then
			aU(f)
		end
	end

	local e = aF == 1 and "1 spectator" or `{aF} spectators`

	return ar("Frame", {
		Active = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = aX,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = aW,
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = aY,
		[ac.Event.InputBegan] = onInputBegan,
	}, {
		Shadow = al{
			color = aQ,
			transparency = c,
			zIndex = 0,
			multiplier = Vector2.new(1.24, 1.46),
		},
		Body = ar("Frame", {
			BackgroundColor3 = aK,
			BackgroundTransparency = aZ,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 1,
			ClipsDescendants = true,
		}, {
			UICorner = ar("UICorner", {
				CornerRadius = UDim.new(0, ay),
			}),
			UIStroke = ar("UIStroke", {
				Color = aN,
				Transparency = b,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			UIPadding = ar("UIPadding", {
				PaddingLeft = UDim.new(0, aw),
				PaddingRight = UDim.new(0, aw),
			}),
			UIListLayout = ar("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, ax),
			}),
			Icon = ar("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = (ae.Get("image", "person") ),
				ImageColor3 = aI,
				ImageTransparency = d,
				Size = UDim2.fromOffset(av, av),
				LayoutOrder = 0,
			}),
			Text = ar("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = e,
				TextSize = au,
				TextColor3 = aH,
				TextTransparency = d,
				FontFace = ae.Get("font", "semi_bold"),
				Size = UDim2.fromOffset(1, au + 2),
				AutomaticSize = Enum.AutomaticSize.X,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = 1,
			}),
		}),
	})
end
end function a.bD()
local aa = a.load'c'
local ab = a.load'e'
local ac = a.load'd'
local ad = a.load'n'
local ae = a.load'm'

local af = a.load's'
local ag = a.load'N'
local ah = a.load'o'
local ai = a.load'I'
local aj = a.load'O'
local ak = a.load'U'

local al = ac.useAtom
local am = aa.useEffect
local an = aa.useMemo
local ao = aa.useRef
local ap = ab.useSpring
local aq = ae.peek
local ar = aa.memo
local as = aa.createElement

local at = ag.colors.notify

local au = Font.fromEnum(Enum.Font.GothamBold)

local function resolveFont()	
return af.Get("font", "semi_bold") or au
end

local av = 240
local aw = 1
local ax = 44
local ay = 4
local az = 10
local aA = 24
local aB = 6
local aC = 3
local aD = 12
local aE = 8
local aF = 10

local aG = Vector2.new(1, 0)
local aH = Vector2.new(0, 1)
local aI = UDim2.fromScale(1, 1)
local aJ = Vector2.new(1.3, 1.5)
UDim.new(0, 0)
local aL = UDim.new(0, 1)
local aM = UDim.new(0, aD)
local aN = UDim.new(0, aE)
local aO = UDim.new(0, aF)
local aP = UDim.new(0, aB)
local aQ = UDim2.new(0, 0, 1, 0)
local aR = UDim2.new(1, 0, 0, aC)
local aS = UDim2.fromOffset(20, 20)
local aT = UDim2.new(1, 0, 0, 0)
local aU = UDim2.new(1, 0, 0, 0)
local aV = UDim2.fromOffset(av, 0)

local function visToOpaque(aW)	
return 1 - aW
end

local function progressToSize(aW)	
return UDim2.new(math.clamp(aW, 0, 1), 0, 1, 0)
end

local aW = ar(function(aW


)	
local aX = aW.notification

	local aY = al(at.background)
	local aZ = (aY[1] )	
local b = (aY[2] )
	
local c = al(at.backgroundSecondary)
	local d = (c[1] )	
local e = (c[2] )
	
local f = al(at.stroke)
	local g = (f[1] )	
local h = (f[2] )
	
local i = al(at.shadow)
	local j = (i[1] )	
local k = (i[2] )
	
local l = al(at.image)
	local m = al(at.title)
	local n = al(at.text)
	local o = al(at.progress)

	local p = aW.slotY ~= nil
	local q = ao(aW.slotY or az)
	if aW.slotY ~= nil then
		q.current = aW.slotY
	end
	local r = q.current

	local s = ao(nil )

	am(function()
		local t = s.current
		if not t then
			return
		end

		local function update()			
local u = aq(ah.heights)
			local v = aq(ai.scale)
			if v <= 0 then
				v = 1
			end
			local w = t.AbsoluteSize.Y / v
			if w > 0 and u[aX.id] ~= w then
				ah.heights(ad.Dictionary.merge(u, { [aX.id] = w }))
			end
		end

		update()
		local u = t.GetPropertyChangedSignal(t, "AbsoluteSize"):Connect(update)
		return function()			
u.Disconnect(			u)
		end
	end, {})

	local t, u = ap(r, aj.smoothPrecise)
	am(function()
		u.setGoal(		u,r)
	end, { r })

	local v, w = ap(0, aj.smoothPrecise)
	am(function()
		w.setGoal(		w,p and 1 or 0)
	end, { p })

	local x, y = ap(aX.progress or 0, aj.smoothPrecise)
	am(function()
		y.setGoal(		y,aX.progress or 0)
	end, { aX.progress })

	local z = aa.joinBindings{ t, v }:map(function(z)
		local A = z[1]
		local B = z[2]
		local C = (1 - B) * aA
		return UDim2.new(1, -az + C, 0, A)
	end)

	local A = v.map(v,function(A)
		return A > 0.001
	end)

	local B = v.map(v,visToOpaque)

	local C = v.map(v,function(C)
		return 1 - (1 - b) * C
	end)

	local D = v.map(v,function(D)
		return 1 - (1 - h) * D
	end)

	local E = v.map(v,function(E)
		return 1 - (1 - e) * E
	end)

	local F = v.map(v,function(F)
		return 1 - (1 - k) * F
	end)

	local G = aX.icon and (af.Get("image", aX.icon)) or nil

	local H	
if aX.showProgress then
		H = as("Frame", {
			BackgroundColor3 = d,
			BackgroundTransparency = E,
			BorderSizePixel = 0,
			AnchorPoint = aH,
			Position = aQ,
			Size = aR,
			ZIndex = 2,
		}, {
			Fill = as("Frame", {
				BackgroundColor3 = o,
				BackgroundTransparency = v.map(v,visToOpaque),
				BorderSizePixel = 0,
				Size = x.map(x,progressToSize),
			}),
		})
	end

	local I = as("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = resolveFont(),
		Text = aX.title,
		TextColor3 = m,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = aT,
		LayoutOrder = 0,
	})

	local J	
if aX.subtext and aX.subtext ~= "" then
		J = as("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = resolveFont(),
			Text = aX.subtext,
			TextColor3 = n,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = aT,
			LayoutOrder = 1,
		})
	end

	local K= {
		UIListLayout = as("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = aL,
		}),
		Title = I,
	}
	if J then
		K.Subtext = J
	end

	local L= {
		UICorner = as("UICorner", {
			CornerRadius = aP,
		}),
		UIStroke = as("UIStroke", {
			Color = g,
			Transparency = D,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Inner = as("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 1,
		}, {
			UIPadding = as("UIPadding", {
				PaddingLeft = aM,
				PaddingRight = aM,
				PaddingTop = aN,
				PaddingBottom = aN,
			}),
			UIListLayout = as("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = aO,
			}),
			Icon = G and as("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = aS,
				Image = G,
				ImageColor3 = l,
				LayoutOrder = 0,
			}) or nil,
			Text = as("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1,
			}, {
				UIFlexItem = as("UIFlexItem", {
					FlexMode = Enum.UIFlexMode.Fill,
					ItemLineAlignment = Enum.ItemLineAlignment.Center,
				}),
				Content = as("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
				}, K),
			}),
		}),
	}

	if H then
		L.Progress = H
	end

	return as("Frame", {
		ref = s,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = aG,
		Position = z,
		Size = aV,
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = A,
		ZIndex = aw,
	}, {
		Shadow = ak{
			color = j,
			transparency = F,
			multiplier = aJ,
			zIndex = 0,
		},
		Pill = as("CanvasGroup", {
			BackgroundColor3 = aZ,
			BackgroundTransparency = C,
			BorderSizePixel = 0,
			Size = aU,
			AutomaticSize = Enum.AutomaticSize.Y,
			GroupTransparency = B,
			ZIndex = 1,
		}, L),
		UISizeConstraint = as("UISizeConstraint", {
			MinSize = Vector2.new(ax, ax),
		}),
	})
end)

return LPH_NO_VIRTUALIZE(function()	
local aX = al(ah.notifications)
	local aY = al(ah.heights)

	local aZ = an(function()
		local aZ= {}
		local b = az
		for c, d in next, aX do
			local e			
if not d.removing then
				e = b
				b = b + (aY[d.id] or ax) + ay
			end
			aZ[d.id] = as(aW, {
				notification = d,
				slotY = e,
			})
		end
		return aZ
	end, { aX, aY } )

	return as("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = aI,
		ZIndex = aw,
	}, aZ)
end)
end function a.bE()
local aa = a.load'c'
local ab = a.load'd'

local ac = a.load'bt'
local ad = a.load'bx'
local ae = a.load'bA'
local af = a.load'bC'
local ag = a.load'bD'
local ah = a.load'I'

local ai = ab.useAtom
local aj = aa.createElement

local ak = 2
local al = 1
local am = 10

return function()	
local an = ai(ah.scale)

	return aj("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = ak,
	}, {
		UIScale = aj("UIScale", { Scale = an }),
		Content = aj("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = al,
		}, {
			BindList = aj(ac),
			Watermark = aj(ad),
			Speedometer = aj(ae),
			Spectators = aj(af),
		}),
		NotifyLayer = aj("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = am,
		}, {
			Notify = aj(ag),
		}),
	})
end
end function a.bF()
local aa = a.load'c'
local ab = a.load'w'
local ac = a.load'bE'

local ad = aa.createElement

local ae = {
	_initialized = false,
}

function ae.new()	
if ae._initialized then
		return ae
	end
	ae._initialized = true
	ab.Render(ad(ac))
	return ae
end



return ae
end function a.bG()
local aa = a.load'e'
local ab = a.load'd'
local ac = a.load'c'
local ad = a.load'n'

local ae = a.load'N'
local af = a.load'E'
local ag = a.load'I'

local ah = aa.useSpring
local ai = ac.useEffect
local aj = ac.useMemo
local ak = ab.useAtom
local al = ac.createElement






return function(am)	
local an = ak(af.isOpen)
	local ao = ak(am.Windows)
	local ap = ak(am.SubwindowOpen)
	local aq = ak(ae.colors.canvas.background)
	local ar = ak(ag.scale)

	local as = aj(function()
		return ad.Array.map(ao, function(as)
			return as.Render(as)
		end)
	end, { ao })

	local at, au = table.unpack(aq)

	local av, aw = ah(0, {
		tension = 500,
		friction = 38,
	})

	ai(function()
		aw.setGoal(		aw,an and 1 or 0)
	end, { an })

	return al("Frame", {
		BackgroundColor3 = at,
		BorderSizePixel = 0,
		BackgroundTransparency = av.map(av,function(ax)
			return 1 - ax * (1 - au)
		end),
		Size = UDim2.fromScale(1, 1),
		Visible = av.map(av,function(ax)
			return ax > 0.01
		end),
		ZIndex = 1,
	}, {
		UIScale = al("UIScale", { Scale = ar }),
		Windows = al("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			Interactable = not ap,
		}, as),
	})
end
end function a.bH()
local aa = a.load'd'
local ab = a.load'c'
local ac = a.load'n'

local ad = a.load'I'

local ae = aa.useAtom
local af = ab.useMemo
local ag = ab.createElement





return function(ah)	
local ai = ae(ah.Subwindows)
	local aj = ae(ad.scale)

	local ak = af(function()
		return ac.Dictionary.map(ai, function(ak)
			return ak.Render(ak)
		end)
	end, { ai })

	local al= {
		UIScale = ag("UIScale", { Scale = aj }),
	}
	for am, an in next, ak do
		al[am] = an
	end

	return ag("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, al)
end
end function a.bI()
local aa = a.load'e'
local ab = a.load'd'
local ac = a.load'c'

local ad = a.load's'
local ae = a.load'N'
local af = a.load'aq'
local ag = a.load'I'
local ah = a.load'O'
local ai = a.load'U'

local aj = ab.useAtom
local ak = ac.useEffect
local al = aa.useSpring
local am = ac.createElement

local an = ae.colors.subwindow

local ao = 6
local ap = 8
local aq = 250

return function()	
local ar = aj(af.active)
	local as = aj(af.info)
	local at = aj(af.anchor)

	local au = aj(an.background)
	local av = aj(an.stroke)
	local aw = aj(an.title)
	local ax = aj(an.text)
	local ay = aj(ag.scale)

	local az, aA = al(0, ah.quickPrecise)

	ak(function()
		aA.setGoal(		aA,ar and 1 or 0)
	end, { ar })

	local aB = as ~= nil and at ~= nil

	local aC = aB and (at.position.X + at.size.X + ap) or 0
	local aD = aB and (at.position.Y - 2) or 0

	local aE = az.map(az,function(aE)
		local aF = (1 - aE) * ao
		return UDim2.fromOffset(aC - aF, aD)
	end)

	local aF = az.map(az,function(aF)
		return aB and aF > 0.01
	end)

	local aG = az.map(az,function(aG)
		return 1 - aG
	end)

	local aH = az.map(az,function(aH)
		return 1 - aH
	end)

	local aI = as and as.title or nil
	local aJ = as and as.body or ""
	local aK = aI ~= nil and aI ~= ""

	local aL= {
		UIStroke = am("UIStroke", {
			Color = av,
			Transparency = aH,
			Thickness = 1,
		}),
		UICorner = am("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		UIPadding = am("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 9),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 7),
		}),
		UIListLayout = am("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 3),
		}),
		Body = am("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = ad.Get("font", "semi_bold"),
			Text = aJ,
			TextColor3 = ax,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			LayoutOrder = 2,
		}, {
			UISizeConstraint = am("UISizeConstraint", {
				MaxSize = Vector2.new(aq, math.huge),
			}),
		}),
	}

	if aK then
		aL.Title = am("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = ad.Get("font", "semi_bold"),
			Text = aI,
			TextColor3 = aw,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			LayoutOrder = 1,
		})
	end

	return am("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	}, {
		UIScale = am("UIScale", { Scale = ay }),
		Anchor = am("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			Position = aE,
			Visible = aF,
			ZIndex = 1,
		}, {
			Shadow = ai{
				transparency = aG,
				zIndex = 0,
			},
			Body = am("CanvasGroup", {
				BackgroundColor3 = au,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				GroupTransparency = aG,
				ZIndex = 1,
			}, aL),
		}),
	})
end
end function a.bJ()
local aa = (cloneref(game.GetService(game, "UserInputService")) )
local ab = (cloneref(game.GetService(game, "RunService")) )

local ac = a.load'm'
local ad = a.load'c'

local ae = a.load'w'
local af = a.load'F'
local ag = a.load'J'
local ah = a.load'L'
local ai = a.load'aQ'
local aj = a.load'br'
local ak = a.load'bq'
local al = a.load'bF'
local am = a.load'bG'
local an = a.load'bH'
local ao = a.load'bI'
local ap = a.load'E'
local aq = a.load'aR'
local ar = a.load'aB'

local as = ac.peek
local at = ac.subscribe
local au = ad.createElement

local av = "Toggle Menu"

local aw = {
	_toggleBind = nil ,
	_mainWindow = nil ,
	_mouseConnection = nil ,
}

local function menuToggleInputFromUser()	
local ax = ag.GetMenuToggleKey()
	if not ax then
		return nil
	end
	return ah.DeserializeInput(ax)
end

local function applyMenuToggleInputsFromUser()	
local ax = aw._toggleBind
	if not ax then
		return
	end
	local ay = menuToggleInputFromUser()
	ax.SetInputs(	ax,ay and { ay } or {})
end

local function persistMenuToggleKeyFromBind()	
local ax = aw._toggleBind
	if not ax then
		return
	end
	local ay = as(ax.inputs)
	local az = ay[1]
	local aA = az and ah.SerializeInput(az) or nil
	ag.SetMenuToggleKey(aA)
end

function aw.new()	
af.new()
	ai.init()
	al.new()

	ae.Render(au(am, {
		Windows = aj.windows,
		SubwindowOpen = ai.anyOpen,
	}))

	ae.Render(au(an, {
		Subwindows = ai.subwindows,
	}))

	ae.Render(au(ao))

	aw._toggleBind = af.AddBind(av, function()
		ap.isOpen(not as(ap.isOpen))
	end):SetMode"onPress"
	
applyMenuToggleInputsFromUser()

	at(ag.menuToggleKey, function()		
applyMenuToggleInputsFromUser()
	end)

	at(((aw._toggleBind )).inputs, function()		
persistMenuToggleKeyFromBind()
	end)

	at(ap.isOpen, function(ax)
		local ay = aw._mouseConnection
		if ay then
			ay.Disconnect(			ay)
			aw._mouseConnection = nil
		end
		aj.SetAllOpen(ax)

		if not ax then
			ai.CloseAll()
		else
			aw._mouseConnection = ab.PreRender:Connect(LPH_NO_VIRTUALIZE(function()				
aa.MouseBehavior = Enum.MouseBehavior.Default
				aa.MouseIconEnabled = true
			end))
		end
	end)

	local ax = ak"Limerence"	
aw.AddWindow(ax)

	aw._mainWindow = ax

	at(ax._position, ar.syncMenuPosition)
	ar.syncMenuPosition(as(ax._position))

	ax.AddTabGroup(
	ax,"COMMON", 99)

	return aw
end

function aw.AddWindow(ax)	return aj.Add(ax)
end

function aw.EnsureTabGroup(ax)	
local ay = aw._mainWindow
	if not ay then
		return nil
	end

	local az = ay.GetTabGroup(ay,ax)
	if az then
		return az
	end

	return ay.AddTabGroup(ay,ax)
end

function aw.OpenOptions(ax)	
return ai.OpenOptions(ax)
end

function aw.GetMainWindow()	
return (aw._mainWindow )
end

function aw.GetTab(ax)	
local ay = aw._mainWindow
	if not ay then
		return nil
	end

	for az, aA in next, as(ay._tabGroups) do
		for aB, aC in next, as(aA.tabs) do
			if aC.title == ax then
				return aC
			end
		end
	end
	return nil
end

function aw.OpenTab(ax)	
local ay = aw.GetTab(ax)
	if not ay then
		return false
	end
	aq.openTab(ay)
	return true
end

function aw.GetMenuToggleBindName()	
return av
end

function aw.GetMenuToggleInput()	
return menuToggleInputFromUser()
end

function aw.Destroy()	
af.Destroy()
	local ax = aw._mouseConnection
	if ax then
		ax.Disconnect(		ax)
		aw._mouseConnection = nil
	end
end



return aw
end function a.bK()
local aa = a.load'm'

local ab = aa.atom
local ac = aa.peek



























local ad= ab{}
local ae= {}
local af = 1

local ag = LPH_NO_VIRTUALIZE(function(ag)	
if type(ag) ~= "table" then
		return tostring(ag)
	end
	if ag.title then
		return tostring(ag.title)
	end
	if ag._text then
		local ah = ac(ag._text)
		if ah ~= nil then
			return tostring(ah)
		end
	end
	if ag._title then
		return tostring(ag._title)
	end
	if ag._name then
		return tostring(ag._name)
	end
	return "unnamed"
end)

local function tokenize(ah)	
local ai= {}
	for aj in string.gmatch(ah.lower(ah), "[%w]+") do
		ai[#ai + 1] = aj
	end
	return ai
end

local ah = {}

function ah.add(ai, aj)	
local ak= aj or {}

	local al = af
	af += 1

	local am= {
		id = al,
		kind = ak.kind or "element",
		label = ak.label or ag(ai),
		ref = ai,
		tags = ak.tags or {},
		configKey = ak.configKey,
		parentId = ak.parentId,
		location = ak.location,
		serialize = ak.serialize,
		deserialize = ak.deserialize,
	}

	if am.configKey then
		ae[am.configKey] = al
	end

	local an = ac(ad)
	local ao = table.clone(an)
	ao[al] = am
	ad(ao)

	return ai
end

function ah.get(ai)	
return ac(ad)[ai]
end

function ah.getByConfigKey(ai)	
local aj = ae[ai]
	if not aj then
		return nil
	end
	return ac(ad)[aj]
end

function ah.getAll()	
return ad
end

ah.search = LPH_NO_VIRTUALIZE(function(ai, aj, ak)	
local al= {}
	local am = tokenize(ai)
	if #am == 0 then
		return al
	end
	

local an= {}

	for ao, ap in next, ac(ad) do
		if aj and ap.kind ~= aj then
			continue
		end

		local aq = ap.label:lower()
		if ap.configKey then
			aq = aq .. " " .. ap.configKey:lower()
		end
		for ar, as in next, ap.tags do
			aq = aq .. " " .. as.lower(as)
		end
		if ap.location then
			local ar = ap.location
			if ar.tabGroup then
				aq = aq .. " " .. ar.tabGroup:lower()
			end
			if ar.tab then
				aq = aq .. " " .. ar.tab:lower()
			end
			if ar.section then
				aq = aq .. " " .. ar.section:lower()
			end
		end

		local ar = 0
		local as = true
		for at, au in next, am do
			local av = string.find(aq, au, 1, true)
			if not av then
				as = false
				break
			end
			ar += 1 / av
		end

		if as then
			an[#an + 1] = { entry = ap, score = ar }
		end
	end

	table.sort(an, function(ao, ap)
		return ao.score > ap.score
	end)

	for ao, ap in next, an do
		if ak and ao > ak then
			break
		end
		al[#al + 1] = ap.entry
	end

	return al
end)

return ah
end function a.bL()
local function rgb(aa, ab, ac)	
return Color3.fromRGB(aa, ab, ac)
end

local function rgba(aa, ab, ac, ad)	
return { (Color3.fromRGB(aa, ab, ac) ), ad }
end

local aa
aa = LPH_NO_VIRTUALIZE(function(ab, ac, ad)	
for ae, af in next, ac do
		local ag = ab == "" and ae or `{ab}.{ae}`
		if typeof(af) == "Color3" then
			ad[ag] = af
		elseif type(af) == "table" then
			if af[1] ~= nil and typeof(af[1]) == "Color3" then
				ad[ag] = af
			else
				aa(ag, af, ad)
			end
		end
	end
	return ad
end)

local ab = {
	canvas = {
		background = rgba(10, 10, 10, 0.4),
	},

	hud = {
		background = rgba(30, 30, 30, 0.2),
		backgroundSecondary = rgba(28, 28, 28, 0.4),
		bar = rgb(42, 42, 42),
		danger = rgb(220, 95, 95),
		good = rgb(120, 200, 130),
		image = rgb(177, 177, 177),
		neutral = rgb(200, 186, 160),
		shadow = rgba(0, 0, 0, 0.42),
		stroke = rgba(33, 33, 33, 0.5),
		text = rgb(178, 178, 178),
		textMuted = rgb(115, 115, 115),
		title = rgb(229, 229, 229),
		warning = rgb(220, 190, 110),
	},

	inventory = {
		cardBackground = rgb(26, 26, 26),
		cardBackgroundHover = rgb(32, 32, 32),
		cardImageBg = rgb(18, 18, 18),
		cardSkinName = rgb(228, 228, 228),
		cardWeaponName = rgb(130, 130, 130),
		tabIndicator = rgb(225, 225, 225),

		rarity = {
			common = rgb(176, 195, 217),
			uncommon = rgb(94, 152, 217),
			classified = rgb(211, 44, 230),
			covert = rgb(235, 75, 75),
			extraordinary = rgb(245, 197, 24),
			master = rgb(228, 174, 57),
		},
	},

	notify = {
		background = rgba(22, 22, 22, 0.08),
		backgroundSecondary = rgba(44, 44, 44, 0.15),
		image = rgb(190, 190, 190),
		progress = rgb(225, 225, 225),
		shadow = rgba(0, 0, 0, 0.45),
		stroke = rgba(58, 58, 58, 0.25),
		text = rgb(180, 180, 180),
		title = rgb(235, 235, 235),
	},

	status = {
		danger = rgb(220, 95, 95),
		good = rgb(120, 200, 130),
		neutral = rgb(160, 160, 160),
		placeholder = rgb(110, 110, 110),
		warning = rgb(220, 190, 110),
	},

	subwindow = {
		background = rgb(28, 28, 28),
		divider = rgb(40, 40, 40),
		image = rgb(140, 140, 140),
		stroke = rgb(44, 44, 44),
		text = rgb(200, 200, 200),
		title = rgb(228, 228, 228),
	},

	window = {
		background = rgb(22, 22, 22),
		divider = rgb(32, 32, 32),
		logo = rgb(150, 150, 150),
		searchMuted = rgb(108, 108, 108),
		shadow = rgba(8, 8, 8, 0.5),
		sidebar = rgb(18, 18, 18),
		stroke = rgb(38, 38, 38),
		tabHeading = rgb(108, 108, 108),
		tabIcon = rgb(176, 176, 176),
		tabLabel = rgb(176, 176, 176),
		tabLabelSelected = rgb(225, 225, 225),
		tabStroke = rgb(45, 45, 45),
		tabSurface = rgb(30, 30, 30),
		title = rgb(230, 230, 230),
		toolbar = rgb(20, 20, 20),

		section = {
			background = rgb(30, 30, 30),
			stroke = rgb(42, 42, 42),
			text = rgb(104, 104, 104),
		},

		element = {
			accent = rgb(120, 120, 120),
			accentSoft = rgb(66, 66, 66),
			accentStrong = rgb(190, 190, 190),
			caption = rgb(128, 128, 128),
			captionActive = rgb(196, 196, 196),
			fieldBackground = rgb(42, 42, 42),
			fieldBackgroundActive = rgb(56, 56, 56),
			fieldStroke = rgb(54, 54, 54),
			fieldStrokeActive = rgb(76, 76, 76),
			filterIcon = rgb(94, 94, 94),
			icon = rgb(140, 140, 140),
			iconActive = rgb(178, 178, 178),
			panel = rgb(26, 26, 26),
			panelStroke = rgb(42, 42, 42),
			rowHover = rgb(255, 255, 255),
			scrollThumb = rgb(140, 140, 140),
			surface = rgb(40, 40, 40),
			surfaceStroke = rgb(50, 50, 50),
			text = rgb(168, 168, 168),
			textActive = rgb(222, 222, 222),
			thumb = rgb(130, 130, 130),
			thumbActive = rgb(225, 225, 225),
			thumbHighlight = rgb(255, 255, 255),
			thumbStroke = rgb(22, 22, 22),
		},
	},
}

local ac = {
	canvas = {
		background = rgba(215, 215, 215, 0.4),
	},

	hud = {
		background = rgba(252, 252, 252, 0.5),
		backgroundSecondary = rgba(245, 245, 245, 0.5),
		bar = rgb(210, 210, 210),
		danger = rgb(200, 70, 70),
		good = rgb(60, 150, 80),
		image = rgb(85, 85, 85),
		neutral = rgb(175, 155, 95),
		shadow = rgba(0, 0, 0, 0.2),
		stroke = rgba(215, 215, 215, 0.8),
		text = rgb(50, 50, 50),
		textMuted = rgb(110, 110, 110),
		title = rgb(20, 20, 20),
		warning = rgb(195, 145, 50),
	},

	inventory = {
		cardBackground = rgb(252, 252, 252),
		cardBackgroundHover = rgb(245, 248, 255),
		cardImageBg = rgb(240, 240, 240),
		cardSkinName = rgb(15, 15, 15),
		cardWeaponName = rgb(120, 120, 120),
		tabIndicator = rgb(37, 99, 235),

		rarity = {
			common = rgb(140, 158, 180),
			uncommon = rgb(70, 130, 200),
			classified = rgb(187, 39, 204),
			covert = rgb(212, 60, 60),
			extraordinary = rgb(218, 165, 32),
			master = rgb(202, 150, 40),
		},
	},

	notify = {
		background = rgba(252, 252, 252, 0.05),
		backgroundSecondary = rgba(228, 228, 228, 0.1),
		image = rgb(60, 60, 60),
		progress = rgb(37, 99, 235),
		shadow = rgba(0, 0, 0, 0.18),
		stroke = rgba(210, 210, 210, 0.2),
		text = rgb(60, 60, 60),
		title = rgb(15, 15, 15),
	},

	status = {
		danger = rgb(200, 70, 70),
		good = rgb(60, 150, 80),
		neutral = rgb(120, 120, 120),
		placeholder = rgb(150, 150, 150),
		warning = rgb(195, 145, 50),
	},

	subwindow = {
		background = rgb(252, 252, 252),
		divider = rgb(225, 225, 225),
		image = rgb(85, 85, 85),
		stroke = rgb(218, 218, 218),
		text = rgb(40, 40, 40),
		title = rgb(15, 15, 15),
	},

	window = {
		background = rgb(240, 240, 240),
		divider = rgb(225, 225, 225),
		logo = rgb(85, 85, 85),
		searchMuted = rgb(120, 120, 120),
		shadow = rgba(0, 0, 0, 0.2),
		sidebar = rgb(230, 230, 230),
		stroke = rgb(220, 220, 220),
		tabHeading = rgb(120, 120, 120),
		tabIcon = rgb(55, 55, 55),
		tabLabel = rgb(55, 55, 55),
		tabLabelSelected = rgb(15, 15, 15),
		tabStroke = rgb(222, 222, 222),
		tabSurface = rgb(245, 245, 245),
		title = rgb(15, 15, 15),
		toolbar = rgb(230, 230, 230),

		section = {
			background = rgb(248, 248, 248),
			stroke = rgb(225, 225, 225),
			text = rgb(125, 125, 125),
		},

		element = {
			accent = rgb(59, 130, 246),
			accentSoft = rgb(191, 219, 254),
			accentStrong = rgb(37, 99, 235),
			caption = rgb(95, 95, 95),
			captionActive = rgb(37, 99, 235),
			fieldBackground = rgb(245, 245, 245),
			fieldBackgroundActive = rgb(232, 242, 254),
			fieldStroke = rgb(220, 220, 220),
			fieldStrokeActive = rgb(59, 130, 246),
			filterIcon = rgb(140, 140, 140),
			icon = rgb(90, 90, 90),
			iconActive = rgb(37, 99, 235),
			panel = rgb(252, 252, 252),
			panelStroke = rgb(225, 225, 225),
			rowHover = rgb(0, 0, 0),
			scrollThumb = rgb(170, 170, 170),
			surface = rgb(245, 245, 245),
			surfaceStroke = rgb(220, 220, 220),
			text = rgb(40, 40, 40),
			textActive = rgb(15, 15, 15),
			thumb = rgb(110, 110, 110),
			thumbActive = rgb(255, 255, 255),
			thumbHighlight = rgb(255, 255, 255),
			thumbStroke = rgb(37, 99, 235),
		},
	},
}

local ad = {
	canvas = {
		background = rgba(20, 16, 12, 0.4),
	},

	hud = {
		background = rgba(38, 28, 22, 0.25),
		backgroundSecondary = rgba(34, 25, 20, 0.4),
		bar = rgb(56, 42, 34),
		danger = rgb(225, 100, 85),
		good = rgb(130, 185, 120),
		image = rgb(185, 160, 135),
		neutral = rgb(195, 165, 130),
		shadow = rgba(0, 0, 0, 0.45),
		stroke = rgba(58, 44, 36, 0.5),
		text = rgb(195, 170, 145),
		textMuted = rgb(125, 100, 80),
		title = rgb(240, 220, 195),
		warning = rgb(225, 175, 130),
	},

	inventory = {
		cardBackground = rgb(34, 26, 22),
		cardBackgroundHover = rgb(46, 34, 28),
		cardImageBg = rgb(24, 18, 14),
		cardSkinName = rgb(245, 220, 195),
		cardWeaponName = rgb(150, 125, 100),
		tabIndicator = rgb(225, 175, 130),

		rarity = {
			common = rgb(180, 165, 145),
			uncommon = rgb(150, 175, 215),
			classified = rgb(220, 110, 220),
			covert = rgb(230, 95, 80),
			extraordinary = rgb(240, 195, 80),
			master = rgb(232, 180, 75),
		},
	},

	notify = {
		background = rgba(30, 22, 18, 0.08),
		backgroundSecondary = rgba(58, 44, 36, 0.15),
		image = rgb(210, 180, 150),
		progress = rgb(225, 175, 130),
		shadow = rgba(10, 6, 4, 0.45),
		stroke = rgba(72, 56, 46, 0.25),
		text = rgb(200, 175, 150),
		title = rgb(245, 220, 195),
	},

	status = {
		danger = rgb(225, 110, 95),
		good = rgb(155, 200, 130),
		neutral = rgb(175, 155, 130),
		placeholder = rgb(125, 105, 90),
		warning = rgb(230, 195, 125),
	},

	subwindow = {
		background = rgb(38, 28, 22),
		divider = rgb(58, 44, 36),
		image = rgb(160, 140, 115),
		stroke = rgb(62, 48, 40),
		text = rgb(210, 185, 155),
		title = rgb(240, 220, 195),
	},

	window = {
		background = rgb(30, 22, 18),
		divider = rgb(48, 36, 28),
		logo = rgb(170, 140, 110),
		searchMuted = rgb(120, 100, 80),
		shadow = rgba(10, 6, 4, 0.55),
		sidebar = rgb(24, 18, 14),
		stroke = rgb(56, 42, 34),
		tabHeading = rgb(125, 105, 85),
		tabIcon = rgb(195, 165, 135),
		tabLabel = rgb(195, 165, 135),
		tabLabelSelected = rgb(245, 220, 190),
		tabStroke = rgb(62, 48, 38),
		tabSurface = rgb(42, 32, 26),
		title = rgb(245, 225, 195),
		toolbar = rgb(28, 20, 16),

		section = {
			background = rgb(42, 32, 26),
			stroke = rgb(60, 46, 38),
			text = rgb(118, 98, 80),
		},

		element = {
			accent = rgb(170, 140, 110),
			accentSoft = rgb(90, 70, 55),
			accentStrong = rgb(225, 175, 130),
			caption = rgb(140, 120, 100),
			captionActive = rgb(215, 185, 155),
			fieldBackground = rgb(56, 42, 34),
			fieldBackgroundActive = rgb(72, 56, 46),
			fieldStroke = rgb(72, 56, 46),
			fieldStrokeActive = rgb(96, 76, 62),
			filterIcon = rgb(105, 85, 70),
			icon = rgb(160, 135, 115),
			iconActive = rgb(195, 165, 135),
			panel = rgb(34, 26, 22),
			panelStroke = rgb(56, 42, 34),
			rowHover = rgb(245, 220, 195),
			scrollThumb = rgb(160, 130, 105),
			surface = rgb(50, 38, 30),
			surfaceStroke = rgb(64, 48, 38),
			text = rgb(185, 160, 135),
			textActive = rgb(240, 215, 185),
			thumb = rgb(160, 135, 110),
			thumbActive = rgb(240, 215, 185),
			thumbHighlight = rgb(255, 235, 200),
			thumbStroke = rgb(30, 22, 18),
		},
	},
}

local ae = {}

ae.NAMES = { "Dark", "Light", "Mocha" }

ae.SNAPSHOTS = {
	Dark = aa("", ab, {}),
	Light = aa("", ac, {}),
	Mocha = aa("", ad, {}),
}

function ae.IsBuiltin(af)	
return ae.SNAPSHOTS[af] ~= nil
end

function ae.GetSnapshot(af)	
return ae.SNAPSHOTS[af]
end

return ae
end function a.bM()
local aa = a.load'm'
local ab = a.load'N'
local ac = a.load'bL'
local ad = a.load'p'
local ae = a.load'f'
local af = (cloneref(game.GetService(game, "HttpService")) )

local ag = aa.peek

local ah = {}

local ai = "limerence.biz/themes"
local aj = "Dark"

ah.DEFAULT_NAME = aj
ah.BUILTIN_NAMES = ac.NAMES

local function pathFor(ak)	
return `{ai}/{ak}.json`
end

local ak
ak = LPH_NO_VIRTUALIZE(function(al, am, an)
	for ao, ap in next, am do
		local aq = al == "" and (ao) or (`{al}.{ao}`)
		if type(ap) == "function" then
			an(aq, ap)
		elseif type(ap) == "table" then
			ak(aq, ap, an)
		end
	end
end)

ah.walkColors = ak

function ah.Snapshot()	
local al= {}
	ak("", ab.colors, function(am, an)
		al[am] = ag(an)
	end)
	return al
end

function ah.Restore(al)	
ak("", ab.colors, function(am, an)
		local ao = al[am]
		if ao ~= nil then
			an(ao)
		end
	end)
end

function ah.toJson()	
local al= {}
	ak("", ab.colors, function(am, an)
		local ao = ag(an)
		if typeof(ao) == "Color3" then
			al[am] = { r = ao.R, g = ao.G, b = ao.B }
		elseif type(ao) == "table" then
			local ap = ao[1]
			if typeof(ap) == "Color3" then
				al[am] = { r = ap.R, g = ap.G, b = ap.B, a = ao[2] }
			end
		end
	end)
	return af.JSONEncode(af,al)
end

local function migrateLegacyThemePaths(al)
	local function move(am, an)
		if al[an] == nil and al[am] ~= nil then
			al[an] = al[am]
		end
	end

	if al["window.searchMuted"] == nil then
		al["window.searchMuted"] = al["window.searchIcon"] or al["window.searchText"]
	end
	move("window.side", "window.sidebar")
	move("window.top", "window.toolbar")
	move("window.tabGroupText", "window.tabHeading")
	move("window.tabButtonBackground", "window.tabSurface")
	move("window.tabButtonStroke", "window.tabStroke")
	move("window.unselectedTabText", "window.tabLabel")
	move("window.selectedTabText", "window.tabLabelSelected")

	local am = "window.element."
	move(am .. "canvas", am .. "panel")
	move(am .. "canvasStroke", am .. "panelStroke")
	move(am .. "secondary", am .. "surface")
	move(am .. "secondaryStroke", am .. "surfaceStroke")
	move(am .. "primary", am .. "accent")
	move(am .. "dimPrimary", am .. "accentSoft")
	move(am .. "activePrimary", am .. "accentStrong")
	move(am .. "knob", am .. "thumb")
	move(am .. "activeKnob", am .. "thumbActive")
	move(am .. "brightKnob", am .. "thumbHighlight")
	move(am .. "knobStroke", am .. "thumbStroke")
	move(am .. "valueBackground", am .. "fieldBackground")
	move(am .. "activeValueBackground", am .. "fieldBackgroundActive")
	move(am .. "valueStroke", am .. "fieldStroke")
	move(am .. "activeValueStroke", am .. "fieldStrokeActive")
	move(am .. "mutedText", am .. "caption")
	move(am .. "activeMutedText", am .. "captionActive")
	move(am .. "activeText", am .. "textActive")
	move(am .. "activeIcon", am .. "iconActive")
	move("hud.mutedText", "hud.textMuted")
	move("hud.secondaryBackground", "hud.backgroundSecondary")
end

function ah.fromJson(al)	
local am = af.JSONDecode(af,al)
	migrateLegacyThemePaths(am)
	ak("", ab.colors, function(an, ao)
		local ap = am[an]
		if not ap then
			return
		end
		local aq = ag(ao)
		if typeof(aq) == "Color3" then
			ao(Color3.new(ap.r, ap.g, ap.b))
		elseif type(aq) == "table" then
			ao{ Color3.new(ap.r, ap.g, ap.b), ap.a or aq[2] }		
end
	end)
end

function ah.IsBuiltin(al)	
return ac.IsBuiltin(al)
end

function ah.IsDefault(al)	
return ah.IsBuiltin(al)
end

local function resolveLegacyName(al)	
if al == "Default" then
		return "Dark"
	end
	return al
end

function ah.SaveToFile(al)	
if ah.IsBuiltin(al) then
		return
	end
	writefile(pathFor(al), ah.toJson())
end

function ah.LoadFromFile(al, am)	
al = resolveLegacyName(al)

	local an = ac.GetSnapshot(al)
	if an then
		ah.Restore(an)
		if not am then
			ad.Push{
				title = "Loaded theme",
				subtext = al,
				icon = "paintbrush",
				duration = 2,
			}		
end
		return true
	end

	local ao = pathFor(al)
	if not isfile(ao) then
		if not am then
			ad.Push{
				title = `Theme error: {al}`,
				subtext = "file not found",
				icon = "trash",
				duration = 2,
			}		
end
		return false
	end
	ah.fromJson(readfile(ao))
	if not am then
		ad.Push{
			title = "Loaded theme",
			subtext = al,
			icon = "paintbrush",
			duration = 2,
		}	
end
	return true
end

function ah.CreateTheme(al)	
if ah.IsBuiltin(al) then
		return false
	end

	local am = pathFor(al)
	if isfile(am) then
		return false
	end
	writefile(am, "{}")
	return true
end

function ah.RenameTheme(al, am)	
if al == am then
		return false
	end

	if ah.IsBuiltin(al) or ah.IsBuiltin(am) then
		return false
	end

	local an = pathFor(al)
	local ao = pathFor(am)

	if not isfile(an) then
		return false
	end

	if isfile(ao) then
		return false
	end

	writefile(ao, readfile(an))
	delfile(an)
	return true
end

function ah.HasTheme(al)	
if ah.IsBuiltin(al) then
		return true
	end
	return isfile(pathFor(al))
end

function ah.DeleteTheme(al)	
if ah.IsBuiltin(al) then
		return false
	end

	local am = pathFor(al)
	if not isfile(am) then
		return false
	end

	delfile(am)
	return true
end

function ah.ListThemes()	
local al= {}
	local am= {}

	for an, ao in next, ac.NAMES do
		table.insert(al, ao)
		am[ao] = true
	end

	if not isfolder(ai) then
		return al
	end

	local an= {}
	for ao, ap in next, listfiles(ai) do
		local aq = ap.match(ap, "([^/\\]+)%.json$")		
if aq and not am[aq] then
			table.insert(an, aq)
		end
	end
	table.sort(an)

	for ao, ap in next, an do
		table.insert(al, ap)
	end

	return al
end

ae.log(`registered {#ac.NAMES} built-in themes`)

return ah
end function a.bN()
local aa = a.load'm'

local ab = a.load'bM'
local ac = a.load'aB'
local ad = a.load'J'
local ae = a.load's'
local af = a.load'aQ'
local ag = a.load'bm'
local ah = a.load'N'a.load'bn'


local aj = aa.peek
local ak = aa.subscribe

local al = "Unnamed"

local function uniqueName(am, an)	
local ao= {}
	for ap, aq in next, am do
		ao[aq] = true
	end

	if not ao[an] then
		return an
	end

	local ap = 2
	while ao[`{an} {ap}`] do
		ap += 1
	end
	return `{an} {ap}`
end

local function toItems(am, an)	
local ao = ae.Get("image", "curved_right_arrow")
	local ap = {}
	for aq, ar in next, am do
		ap[aq] = {
			id = ar,
			name = ar,
			icon = ar == an and ao or nil,
		}
	end
	return ap
end

local function camelToTitle(am)	
local an = am.gsub(am,"(%l)(%u)", "%1 %2")
	return (an.gsub(an,"^.", string.upper))
end

local function bindColorpicker(am, an, ao)	
local ap = false

	ak(am._state, function(aq)
		if ap then
			return
		end
		ap = true
		if ao then
			an{ aq, aj(am._transparency) }		
else
			an(aq)
		end
		ap = false
	end)

	if ao then
		ak(am._transparency, function(aq)
			if ap then
				return
			end
			ap = true
			an{ aj(am._state), aq }			
ap = false
		end)
	end

	ak(an, function(aq)
		if ap then
			return
		end
		ap = true
		if ao then
			am.SetState(			am,aq[1])
			am.SetTransparency(			am,aq[2])
		else
			am.SetState(			am,aq)
		end
		ap = false
	end)
end

local function buildSection(am, an)	
local ao = ag(am)

	local ap= {}
	for aq in next, an do
		table.insert(ap, aq)
	end
	table.sort(ap)

	for aq, ar in next, ap do
		local as = an[ar]
		if type(as) ~= "function" then
			continue
		end

		local at = aj(as)
		local au = camelToTitle(ar)

		if typeof(at) == "Color3" then
			local av = ao.AddElement(ao,"Colorpicker", au, at)
			bindColorpicker(av, as, false)
		elseif type(at) == "table" and typeof(at[1]) == "Color3" then
			local av = ao.AddElement(ao,"Colorpicker", au, at[1], at[2])
			bindColorpicker(av, as, true)
		end
	end

	return ao
end

local am = false
local function ensureSections()	
if am then
		return
	end
	am = true

	local an= af.Get"ThemeEditor"	
if not an then
		return
	end

	an.SetSections(
	an, {
		buildSection("CANVAS", ah.colors.canvas),
		buildSection("ELEMENT", ah.colors.window.element),
		buildSection("HUD", ah.colors.hud),
		buildSection("NOTIFICATION", ah.colors.notify),
		buildSection("SECTION", ah.colors.window.section),
		buildSection("STATUS", ah.colors.status),
		buildSection("SUBWINDOW", ah.colors.subwindow),
		buildSection("WINDOW", ah.colors.window),
	})end

return function(an)	
local ao = an.AddSection(an,"THEMES", 1)

	local ap = (ao.AddElement(ao,"List", "Theme") )	
ap.SetRenamable(	ap,true)
	ap.SetEmptyText(	ap, "No themes")	
ap.SetMaxHeight(	ap,180)

	local function currentTheme()		
return ad.GetTheme() or ab.DEFAULT_NAME
	end

	local function refresh()		
ap.SetItems(		ap,toItems(ab.ListThemes(), currentTheme()))
	end

	ak(ad.theme, refresh)

	ap.OnRename(
	ap,function(aq, ar)		if not ab.RenameTheme(aq, ar) then
			refresh()
			return
		end
		if ad.GetTheme() == aq then
			ad.SetTheme(ar)
		end
	end)

	local aq = (ao.AddElement(ao,"Button", "Create", ae.Get("image", "write")) )	
aq.OnClick(	aq,function()		
ensureSections()

		local ar = uniqueName(ab.ListThemes(), al)
		local as = ab.Snapshot()

		af.OpenThemeEditor{
			title = `Create Theme — {ar}`,
			name = ar,
			position = ac.menuCenter(),
			snapshot = as,
			onSave = function()
				ab.SaveToFile(ar)
				ad.SetTheme(ar)
				refresh()
				ap.SetSelected(				ap,ar)
			end,
			onCancel = function()
				ab.Restore(as)
			end,
		}	
end)

	local ar = aq.Combine(aq, "Delete")	
ar.SetIcon(	ar,ae.Get("image", "delete"))
	ar.RequireConfirm(	ar)
	ar.OnClick(	ar,function()		
local as = ap.GetSelected(ap)
		if not as then
			return
		end
		ab.DeleteTheme(as)
		if ad.GetTheme() == as then
			ad.SetTheme(nil)
		end
		refresh()
	end)

	local as = (ao.AddElement(ao,"Button", "Edit", ae.Get("image", "pencil")) )	
as.OnClick(	as,function()		
local at = ap.GetSelected(ap)
		if not at or ab.IsDefault(at) then
			return
		end

		ensureSections()

		local au = ad.GetTheme()
		local av = ab.Snapshot()
		ab.LoadFromFile(at, true)
		ad.SetTheme(at)

		af.OpenThemeEditor{
			title = `Edit Theme — {at}`,
			name = at,
			position = ac.menuCenter(),
			snapshot = av,
			onSave = function()
				ab.SaveToFile(at)
			end,
			onCancel = function()
				ab.Restore(av)
				ad.SetTheme(au)
			end,
		}	
end)

	local at = as.Combine(as, "Load")	
at.SetIcon(	at,ae.Get("image", "load"))
	at.OnClick(	at,function()		
local au = ap.GetSelected(ap)
		if not au then
			return
		end
		ab.LoadFromFile(au)
		ad.SetTheme(au)
	end)

	refresh()
end
end function a.bO()
local aa = (cloneref(game.GetService(game, "Players")) )

local ab = a.load'bu'

local ac = aa.LocalPlayer



local ad = {}

ad.MODE_LABELS = {
	roblox = "Roblox Username",
	discord = "Discord Name",
	hidden = "Hidden",
	custom = "Custom",
}

ad.LABEL_TO_MODE = {
	["Roblox Username"] = "roblox",
	["Discord Name"] = "discord",
Hidden="hidden",
Custom="custom",
}

ad.DROPDOWN_OPTIONS = {
	ad.MODE_LABELS.roblox,
	ad.MODE_LABELS.discord,
	ad.MODE_LABELS.hidden,
	ad.MODE_LABELS.custom,
}

local function discordName()	
local ae, af = pcall(function()		
return LP_DISCORD 	
end)
	if ae and type(af) == "string" and af ~= "" then
		return af
	end
	return ac.Name
end

function ad.resolve(ae, af)	
if ae == "discord" then
		return discordName()
	end
	if ae == "hidden" then
		return "User"
	end
	if ae == "custom" then
		local ag = type(af) == "string" and string.match(af, "^%s*(.-)%s*$") or ""
		if ag ~= "" then
			return ag
		end
		return "User"
	end
	return ac.Name
end

function ad.apply(ae, af)	
ab.username(ad.resolve(ae, af))
end

function ad.modeToLabel(ae)	
return ad.MODE_LABELS[ae] or ad.MODE_LABELS.roblox
end

function ad.labelToMode(ae)	
local af = ad.LABEL_TO_MODE[ae]
	if af then
		return af 	
end
	return "roblox"
end

function ad.normalizeMode(ae)	
if ae == "roblox" or ae == "discord" or ae == "hidden" or ae == "custom" then
		return ae
	end
	if type(ae) == "string" then
		return ad.labelToMode(ae)
	end
	return "roblox"
end

return ad
end function a.bP()
local aa = a.load'm'

local ab = aa.subscribe
local ac = aa.peek




















local ad = {}

local function listNames(ae, af)	
if not listfiles or not isfolder or not isfolder(ae) then
		return {}
	end

	local ag = af and (`([^/\\]+)%.{af}$`) or ("([^/\\]+)$")
	local ah= {}

	local ai = listfiles(ae)
	if type(ai) ~= "table" then
		return ah
	end

	for aj, ak in next, ai do
		local al = ak.match(ak,ag)
		if al then
			table.insert(ah, al)
		end
	end

	return ah
end

function ad.create(ae)	
local af = ae.interval or 1
	local ag = ae.pollOnActivate ~= false

	local ah= {}
	local ai= {}
	local aj = false
	local ak	
local al
	
local function poll()		
if aj then
			return
		end

		local am = listNames(ae.path, ae.extension)
		local an= {}
		for ao, ap in next, am do
			an[ap] = true
		end

		local ao= {}
		local ap= {}
		for aq in next, an do
			if not ah[aq] then
				table.insert(ao, aq)
			end
		end
		for aq in next, ah do
			if not an[aq] then
				table.insert(ap, aq)
			end
		end

		ah = an
		ai = am

		if #ao == 0 and #ap == 0 then
			return
		end

		local aq = ae.onAdded
		if aq then
			for ar, as in next, ao do
				aq(as)
			end
		end

		local ar = ae.onRemoved
		if ar then
			for as, at in next, ap do
				ar(at)
			end
		end

		local as = ae.onChange
		if as then
			as(am, ao, ap)
		end
	end

	local function stopLoop()		
local am = ak
		ak = nil
		if am and coroutine.status(am) ~= "dead" then
			pcall(task.cancel, am)
		end
	end

	local function startLoop()		
if ak or aj then
			return
		end
		ak = task.spawn(function()
			while not aj do
				task.wait(af)
				if aj then
					return
				end
				if ae.activeWhile and not ac(ae.activeWhile) then
					ak = nil
					return
				end
				poll()
			end
			ak = nil
		end)
	end

	local am = {} 
	
function am:Refresh()		
if aj then
			return
		end
		poll()
	end

	function am:GetNames()		
return table.clone(ai)
	end

	function am:Stop()		
if aj then
			return
		end
		aj = true
		if al then
			al()
			al = nil
		end
		stopLoop()
	end

	if ae.activeWhile then
		if ac(ae.activeWhile) then
			if ag then
				poll()
			end
			startLoop()
		end
		al = ab(ae.activeWhile, function(an)			
if aj then
				return
			end
			if an then
				if ag then
					poll()
				end
				startLoop()
			else
				stopLoop()
			end
		end)
	else
		poll()
		startLoop()
	end

	return am
end

return ad
end function a.bQ()
local aa = a.load'm'
local ab = a.load'bJ'
local ac = a.load's'
local ad = a.load'J'
local ae = a.load'bK'
local af = a.load'bN'
local ag = a.load'bs'
local ah = a.load'H'
local ai = a.load'bB'
local aj = a.load'bO'
local ak = a.load'G'
local al = a.load'E'
local am = a.load'I'
local an = a.load'bP'a.load'bn'


local ap = aa.atom
local aq = aa.subscribe
local ar = aa.peek

local as = LPH_NO_VIRTUALIZE(function(as, at)	
return as.X.Scale == at.X.Scale and as.X.Offset == at.X.Offset and as.Y.Scale == at.Y.Scale and as.Y.Offset == at.Y.Offset
end)











local at = "Unnamed"

local au = LPH_NO_VIRTUALIZE(function(au, av)	
local aw= {}
	for ax, ay in next, au do
		aw[ay] = true
	end

	if not aw[av] then
		return av
	end

	local ax = 2
	while aw[`{av} {ax}`] do
		ax += 1
	end
	return `{av} {ax}`
end)

local function toItems(av, aw)	
local ax = ac.Get("image", "curved_right_arrow")
	local ay = {}
	for az, aA in next, av do
		ay[az] = {
			id = aA,
			name = aA,
			icon = aA == aw and ax or nil,
		}
	end
	return ay
end

return function(av)	
local aw = ab.GetMainWindow()
	local ax = aw.GetTabGroup(aw, "COMMON")
	
if not ax then
		return nil
	end

	local ay = ae.add(
		ax.AddTab(		ax,"Settings", (ac.Get("image", "cog") ), {
			containers = 2,
		}),
		{ kind = "tab" }
	)

	local az = ay.AddSection(ay,"CONFIGS", 1)

	local aA = (az.AddElement(az,"List", "Config") )	
av.Link("settings.configList", aA)
	aA.SetRenamable(	aA,true)
	aA.SetEmptyText(	aA, "No configs")	
aA.SetMaxHeight(	aA,180)

	local function refresh()		
aA.SetItems(		aA,toItems(av.ListConfigs(), ad.GetAutoloadConfig()))
	end

	aq(ad.autoloadConfig, refresh)

	aA.OnRename(
	aA,function(aB, aC)		if not av.RenameConfig(aB, aC) then
			refresh()
			return
		end
		if ad.GetAutoloadConfig() == aB then
			ad.SetAutoloadConfig(aC)
		end
	end)

	an.create{
		path = "limerence.biz/configs",
		extension = "json",
		interval = 1,
		activeWhile = al.isOpen,
		onChange = refresh,
	}
	
local aB = (az.AddElement(az,"Button", "Create", ac.Get("image", "write")) )	
aB.OnClick(	aB,function()		
local aC = au(av.ListConfigs(), at)
		av.CreateConfig(aC)
		refresh()
		aA.SetSelected(		aA,aC)
	end)

	local aC = aB.Combine(aB, "Delete")	
aC.SetIcon(	aC,ac.Get("image", "delete"))
	aC.RequireConfirm(	aC)
	aC.OnClick(	aC,function()		
local aD = aA.GetSelected(aA)
		if not aD then
			return
		end
		av.DeleteConfig(aD)
		if ad.GetAutoloadConfig() == aD then
			ad.SetAutoloadConfig(nil)
		end
		refresh()
	end)

	local aD = (az.AddElement(az,"Button", "Save", ac.Get("image", "disk")) )	
aD.OnClick(	aD,function()		
local aE = aA.GetSelected(aA)
		if not aE then
			return
		end
		av.SaveToFile(aE)
	end)

	local aE = aD.Combine(aD, "Load")	
aE.SetIcon(	aE,ac.Get("image", "load"))
	aE.OnClick(	aE,function()		
local aF = aA.GetSelected(aA)
		if not aF then
			return
		end
		av.LoadFromFile(aF)
	end)

	local aF =
(		az.AddElement(		az,"Button", "Autoload", ac.Get("image", "curved_right_arrow")) )	
aF.SetIcon(	aF,ac.Get("image", "curved_right_arrow"))
	aF.OnClick(	aF,function()		
local aG = aA.GetSelected(aA)
		if not aG then
			return
		end
		if ad.GetAutoloadConfig() == aG then
			ad.SetAutoloadConfig(nil)
		else
			ad.SetAutoloadConfig(aG)
		end
	end)

	refresh()

	local aG = ay.AddSection(ay,"DISPLAY", 2)

	local aH = (aG.AddElement(
aG,		"Dropdown",
		"DPI Scale",
		am.LABELS,
		am.labelFor(ad.GetDpiScale())
	) )	
aH.SetBindable(	aH,false)
	aH.SetTip(	aH, {
		title = "DPI Scale",
		body = "Scales the entire menu, HUD, and subwindows. 100% matches the default size.",
	})
	
aq(aH._state, function(aI)		
ad.SetDpiScale(am.scaleFor(aI))
	end)

	aq(ad.dpiScale, function(aI)		
local aJ = am.labelFor(aI)
		if ar(aH._state) ~= aJ then
			aH._state(aJ)
		end
	end)

	local aI = ay.AddSection(ay,"STARTUP", 2)

	local aJ =
(		aI.AddElement(		aI,"Toggle", "Show Menu on Load", ar(ad.showMenuOnStartup)) )	
aJ.SetBindable(	aJ,false)
	aJ.SetTip(	aJ, {
		title = "Show Menu on Load",
		body = "Show the menu automatically when the script runs.",
	})
	
aq(aJ._state, function(aK)		
ad.SetShowMenuOnStartup(aK)
	end)

	aq(ad.showMenuOnStartup, function(aK)		
if ar(aJ._state) ~= aK then
			aJ._state(aK)
		end
	end)

	local aK = (aI.AddElement(
aI,		"Key",
		"Menu Toggle",
		ab.GetMenuToggleInput(),
		"onPress",
		ab.GetMenuToggleBindName()
	) )	
aK.SetBindable(	aK,false)
	aK.SetTip(	aK, {
		title = "Menu Toggle",
		body = "Key used to open and close the menu. Saved in user preferences.",
	})
	
local aL = ay.AddSection(ay,"HUD", 2)

	local function applyUsernameDisplay()		
aj.apply(
			aj.normalizeMode(ad.GetUsernameDisplayMode()),
			ad.GetUsernameCustom()
		)
	end

	local aM = (aL.AddElement(
aL,		"Dropdown",
		"Username Display",
		aj.DROPDOWN_OPTIONS,
		aj.modeToLabel(aj.normalizeMode(ad.GetUsernameDisplayMode()))
	) )	
aM.SetBindable(	aM,false)
	aM.SetTip(	aM, {
		title = "Username Display",
		body = "How your name appears in the HUD watermark. Discord Name uses the LP_DISCORD macro when available.",
	})
	
aq(aM._state, function(aN)		
ad.SetUsernameDisplayMode(aj.labelToMode(aN))
		applyUsernameDisplay()
	end)

	aq(ad.usernameDisplayMode, function(aN)		
local aO = aj.modeToLabel(aj.normalizeMode(aN))
		if ar(aM._state) ~= aO then
			aM._state(aO)
		end
	end)

	local aN =
(		aL.AddElement(		aL,"Textbox", "Custom Username", ad.GetUsernameCustom(), "Username") )	
aN.SetBindable(	aN,false)
	aN.SetTip(	aN, {
		title = "Custom Username",
		body = "Shown in the watermark when Username Display is set to Custom.",
	})
	
local function syncCustomUsernameVisible()		
local aO = ad.GetUsernameDisplayMode() == "custom"
		aN.SetVisible(		aN,aO)
	end

	syncCustomUsernameVisible()

	aq(aN._state, function(aO)		
ad.SetUsernameCustom(aO)
		if ad.GetUsernameDisplayMode() == "custom" then
			applyUsernameDisplay()
		end
	end)

	aq(ad.usernameDisplayMode, function(aO)		
syncCustomUsernameVisible()
	end)

	local aO = (aL.AddElement(aL,"Toggle", "Show Watermark", false) )	
aO.SetBindable(	aO,false)
	av.Link("hud.showWatermark", aO)

	aq(aO._state, function(aP)
		ah.enabled(aP)
	end)

	aq(ah.enabled, function(aP)
		aO._state(aP)
	end)

	local aP = {
		_state = ap(ar(ah.position)),
	}
	av.Link("hud.watermarkPosition", aP)

	aq(aP._state, function(aQ)
		if not as(ar(ah.position), aQ) then
			ah.position(aQ)
		end
	end)

	aq(ah.position, function(aQ)
		if not as(ar(aP._state), aQ) then
			aP._state(aQ)
		end
	end)

	local aQ = {
		_state = ap(ar(ai.position)),
	}
	av.Link("hud.spectatorsPosition", aQ)

	aq(aQ._state, function(aR)
		if not as(ar(ai.position), aR) then
			ai.position(aR)
		end
	end)

	aq(ai.position, function(aR)
		if not as(ar(aQ._state), aR) then
			aQ._state(aR)
		end
	end)

	local aR = {
		_state = ap(ar(ah.itemOrder)),
	}
	av.Link("hud.watermarkItemOrder", aR)

	aq(aR._state, function(aS)
		local aT = ak.normalize(aS)
		local aU = ar(ah.itemOrder)
		if #aT ~= #aU then
			ah.itemOrder(aT )
			return
		end
		for aV, aW in next, aT do
			if aU[aV] ~= aW then
				ah.itemOrder(aT )
				return
			end
		end
	end)

	aq(ah.itemOrder, function(aS)
		local aT = (ak.normalize(aS) )		
local aU = ar(aR._state)
		if #aT ~= #aU then
			aR._state(aT)
			return
		end
		for aV, aW in next, aT do
			if aU[aV] ~= aW then
				aR._state(aT)
				return
			end
		end
	end)

	local aS = (aL.AddElement(aL,"Toggle", "Show Bind List", ar(ag.showBindList)) )	
aS.SetBindable(	aS,false)
	av.Link("hud.showBindList", aS)

	aq(aS._state, function(aT)
		ag.showBindList(aT)
	end)

	aq(ag.showBindList, function(aT)
		aS._state(aT)
	end)

	af(ay)

	return ay
end
end function a.bR()
return LPH_JIT_MAX(function()
	local aa = a.load'm'	
local ab = a.load'Z'	
local ac = a.load'L'	
local ad = (cloneref(game.GetService(game, "HttpService")) )
	
local ae = aa.peek

	local af = {}

	local ag





= {}

	function af.RegisterExtension(
		ah,
		ai,
		aj,
		ak	
)		
ag[ah] = { save = ai, load = aj, prepare = ak }
	end

	function af.UnregisterExtension(ah)		
ag[ah] = nil
	end

	local function serializeValue(ah)		
local ai = typeof(ah)

		if ai == "Color3" then
			return { __t = "Color3", r = ah.R, g = ah.G, b = ah.B }
		end

		if ai == "UDim2" then
			return {
				__t = "UDim2",
				xs = ah.X.Scale,
				xo = ah.X.Offset,
				ys = ah.Y.Scale,
				yo = ah.Y.Offset,
			}
		end

		if ai == "ColorSequence" then
			local aj = {}
			for ak, al in next, ah.Keypoints do
				aj[ak] = {
					time = al.Time,
					r = al.Value.R,
					g = al.Value.G,
					b = al.Value.B,
				}
			end
			return { __t = "ColorSequence", keypoints = aj }
		end

		return ah
	end

	local function deserializeValue(ah)		
if type(ah) ~= "table" then
			return ah
		end

		local ai = ah.__t
		if ai == "Color3" then
			return Color3.new(ah.r, ah.g, ah.b)
		end

		if ai == "UDim2" then
			return UDim2.new(ah.xs, ah.xo, ah.ys, ah.yo)
		end

		if ai == "ColorSequence" then
			local aj = {}
			for ak, al in next, ah.keypoints do
				aj[ak] =
					ColorSequenceKeypoint.new(al.time, Color3.new(al.r, al.g, al.b))
			end
			return ColorSequence.new(aj)
		end

		return ah
	end

	function af.toJson()		
local ah= {}
		local ai= {}
		local aj= {}
		local ak= {}
		local al= {}
		local am= {}

		for an, ao in next, ab.elements do
			local ap = ae(ao._state)
			if ap ~= nil then
				ah[an] = serializeValue(ap)
			end

			if ao._transparency then
				local aq = ae(ao._transparency)
				if aq ~= nil then
					ai[an] = aq
				end
			end

			if ao._rotation then
				local aq = ae(ao._rotation)
				if aq ~= nil then
					aj[an] = aq
				end
			end

			if ao._animation then
				local aq = ae(ao._animation)
				if aq ~= nil then
					ak[an] = aq
				end
			end

			if ao._speed then
				local aq = ae(ao._speed)
				if aq ~= nil then
					al[an] = aq
				end
			end

			if ao._binds then
				local aq = ae(ao._binds)
				if #aq > 0 then
					local ar = {}
					for as, at in next, aq do
						local au = {}
						for av, aw in next, ae(at.inputs) do
							table.insert(au, ac.SerializeInput(aw))
						end
						local av = ae(at.targetValue)
						local aw = ae(at.savedValue)
						table.insert(ar, {
							mode = ae(at.mode),
							inputs = au,
							showInList = ae(at.showInList),
							targetValue = av ~= nil and serializeValue(av) or nil,
							active = ae(at.active),
							savedValue = aw ~= nil and serializeValue(aw) or nil,
						})
					end
					am[an] = ar
				end
			end
		end

		local an= {}
		for ao, ap in next, ag do
			local aq, ar = pcall(ap.save)
			if aq and ar ~= nil then
				an[ao] = ar
			end
		end

		return ad.JSONEncode(ad, {
			values = ah,
			transparency = ai,
			rotations = aj,
			animations = ak,
			speeds = al,
			binds = am,
			extensions = an,
		})	
end

	function af.fromJson(ah)		
local ai = ad.JSONDecode(ad,ah)
		local aj = ai.values or {}
		local ak = ai.transparency or {}
		local al = ai.rotations or {}
		local am = ai.animations or {}
		local an = ai.speeds or {}
		local ao = ai.binds or {}

		local ap = {
			["aim.hitboxes"] = "targetting.hitboxes",
			["aim.conditions"] = "targetting.conditions",
			["aim.conditions.opts.blindThreshold"] = "targetting.conditions.opts.blindThreshold",
			["aim.conditions.opts.smokeThreshold"] = "targetting.conditions.opts.smokeThreshold",
			["aim.reactionTime"] = "targetting.reactionTime",
			["aim.targetSwitchDelay"] = "targetting.targetSwitchDelay",
		}
		for aq, ar in next, ap do
			if aj[ar] == nil and aj[aq] ~= nil then
				local as = ab.elements[ar]
				if as then
					aj[ar] = aj[aq]
				end
			end
		end

		if aj["aim.fov"] == nil and aj["targetting.fov"] ~= nil then
			local aq = ab.elements["aim.fov"]
			if aq then
				aj["aim.fov"] = aj["targetting.fov"]
			end
		end

		local aq = ai.extensions
		if type(aq) == "table" then
			for ar, as in next, ag do
				local at = as.prepare
				if at then
					local au = aq[ar]
					if au ~= nil then
						setthreadidentity(8)
						pcall(at, au)
					end
				end
			end
		end

		for ar, as in next, aj do
			local at = ab.elements[ar]
			if not at then
				continue
			end
			setthreadidentity(8)
			at._state(deserializeValue(as))
		end

		for ar, as in next, ak do
			local at = ab.elements[ar]
			if not at or not at._transparency then
				continue
			end
			at._transparency(as)
		end

		for ar, as in next, al do
			local at = ab.elements[ar]
			if not at or not at._rotation then
				continue
			end
			at._rotation(as)
		end

		for ar, as in next, am do
			local at = ab.elements[ar]
			if not at or not at._animation then
				continue
			end
			at._animation(as)
		end

		for ar, as in next, an do
			local at = ab.elements[ar]
			if not at or not at._speed then
				continue
			end
			at._speed(as)
		end

		for ar, as in next, ao do
			local at = ab.elements[ar]
			if not at or not at._binds then
				continue
			end

			for au, av in next, ae(at._binds) do
				at.RemoveBind(				at,av.id)
			end

			local au= {}

			for av, aw in next, as do
				local ax = at.AddBind(at)
				if not ax then
					continue
				end

				if aw.mode then
					ax.mode(aw.mode)
				end

				if aw.inputs then
					local ay = {}
					for az, aA in next, aw.inputs do
						local aB = ac.DeserializeInput(aA)
						if aB then
							table.insert(ay, aB)
						end
					end
					ax.inputs(ay)
				end

				if aw.showInList ~= nil then
					ax.showInList(aw.showInList)
				end

				if aw.targetValue ~= nil then
					ax.targetValue(deserializeValue(aw.targetValue))
				end

				if aw.savedValue ~= nil then
					ax.savedValue(deserializeValue(aw.savedValue))
				end

				if aw.active == true and aw.mode == "toggle" then
					table.insert(au, { eb = ax, savedValue = aw.savedValue })
				end
			end

			ac.RewireAll(at)

			for av, aw in next, au do
				ac.RestoreActive(aw.eb)
			end
		end

		if type(aq) == "table" then
			for ar, as in next, ag do
				local at = aq[ar]
				if at ~= nil then
					setthreadidentity(8)
					pcall(as.load, at)
				end
			end
		end
	end
	return af
end)()
end function a.bS()
local aa = a.load'bQ'
local ab = a.load'bR'
local ac = a.load'Z'
local ad = a.load'p'a.load'f'


local af = {}

local ag = "limerence.biz/configs"

local function pathFor(ah)	
return `{ag}/{ah}.json`
end

function af.new()	
if not isfolder(ag) then
		makefolder(ag)
	end

	aa(af)

	return af
end

function af.Link(ah, ai)	
ac.elements[ah] = ai
	local aj = ai._extraByKey
	if type(aj) == "table" then
		for ak, al in next, aj do
			for am, an in next, al do
				af.Link(`{ah}.extras.{ak}.{am}`, an)
			end
		end
	end
	return ai
end

function af.Unlink(ah)	
local ai = ac.elements[ah]
	local aj = ai and ai._extraByKey
	if type(aj) == "table" then
		for ak, al in next, aj do
			for am in next, al do
				af.Unlink(`{ah}.extras.{ak}.{am}`)
			end
		end
	end
	ac.elements[ah] = nil
end

function af.GetKey(ah)	
for ai, aj in next, ac.elements do
		if aj == ah then
			return ai
		end
	end
	return nil
end

function af.GetElement(ah)	
return ac.elements[ah]
end

function af.SaveToFile(ah)	
writefile(pathFor(ah), ab.toJson())
	ad.Push{
		title = "Saved config",
		subtext = ah,
		icon = "saved_config",
		duration = 2,
	}
end

function af.CreateConfig(ah)	
local ai = pathFor(ah)
	if isfile(ai) then
		return false
	end

	writefile(ai, '{"values":{},"transparency":{}}')
	return true
end

function af.LoadFromFile(ah)	
local ai = pathFor(ah)
	if not isfile(ai) then
		return false
	end

	ab.fromJson(readfile(ai))
	ad.Push{
		title = "Loaded config",
		subtext = ah,
		icon = "loaded_config",
		duration = 2,
	}	
return true
end

function af.RenameConfig(ah, ai)	
if ah == ai then
		return false
	end

	local aj = pathFor(ah)
	local ak = pathFor(ai)

	if not isfile(aj) then
		return false
	end

	if isfile(ak) then
		return false
	end

	writefile(ak, readfile(aj))
	delfile(aj)
	return true
end

function af.HasConfig(ah)	
return isfile(pathFor(ah))
end

function af.DeleteConfig(ah)	
local ai = pathFor(ah)
	if not isfile(ai) then
		return false
	end

	delfile(ai)
	ad.Push{
		title = "Deleted config",
		subtext = ah,
		icon = "trash",
		duration = 2,
	}	
return true
end

function af.ListConfigs()	
local ah= {}

	if not isfolder(ag) then
		return ah
	end

	for ai, aj in next, listfiles(ag) do
		local ak = aj.match(aj, "([^/\\]+)%.json$")		
if ak then
			table.insert(ah, ak)
		end
	end

	return ah
end

function af.Destroy()end



return af
end function a.bT()
local aa = game.JobId

local ab = {
	_destroyers = {} ,
	_modules = {} ,
}

local ac = ab._destroyers
local ad = ab._modules

function ab.init()	
local ae = (getreg() )
	
local af = ae[aa]
	if af then
		pcall(af)
		task.wait()
	end

	ae[aa] = ab.unload

	for ag, ah in next, ad do
		local ai = ah.new()
		ac[#ac + 1] = ai.Destroy

		ad[ag] = nil
	end
end

function ab.add(ae)	
ad[#ad + 1] = ae
end

function ab.addDestroyer(ae)	
ac[#ac + 1] = ae
end

function ab.mount(ae, ...)	
local af = ae.new(...)
	local ag= af or ae
	local ah = ag.Destroy

	if type(ah) == "function" then
		ac[#ac + 1] = function()			
pcall(ah, ag)
		end
	end

	return af
end

function ab.unload()	
for ae, af in next, ac do
		pcall(af)
	end
	table.clear(ac)
end



return ab
end function a.bU()
local aa = a.load'm'
local ab = a.load'bJ'
local ac = a.load's'
local ad = a.load'bS'
local ae = a.load'aw'
local af = a.load'bK'
local ag = a.load'bT'

local ah = aa.subscribe
local ai = aa.peek

local aj = {}

function aj.Group(ak)	
return ab.EnsureTabGroup(ak)
end

function aj.Tab(ak, al, am, an)	
if not ak then
		return nil
	end
	return af.add(
		ak.AddTab(		ak,al, (ac.Get("image", am) ), {
			containers = an or 2,
		}),
		{ kind = "tab" }
	)
end

local ak = {}
ak.__index = ak

local function joinKey(al, am)	
if al == "" then
		return am
	end
	return `{al}.{am}`
end

local function makeLinker(al, am, an, ao)	
return (setmetatable({
		_host = al,
		_prefix = am,
		_scoped = an or false,
		_globalOnly = ao or false,
		_elements = {} ,
	}, ak) )
end

local function add(al, am, an)	
if am then
		local ao = joinKey(al._prefix, am)
		ad.Link(ao, an)
		al._elements[am] = an
		if al._scoped then
			ae.BindElement(an, ao, { globalOnly = al._globalOnly })
		end
	end
	return an
end

function aj.Section(al, am, an, ao)	
return makeLinker(al.AddSection(al,am, an or 1), ao or "")
end

function aj.ScopedSection(al, am, an, ao)	
return makeLinker(al.AddSection(al,am, an or 1), ao or "", true)
end

function ak.Raw(al)	
return al._host
end

function ak.Self(al)	
return al._host
end

local function resolveKey(al, am)	
local an = string.find(am, ".", 1, true)
	if not an then
		return al._elements[am]
	end
	local ao = string.sub(am, 1, an - 1)
	local ap = string.sub(am, an + 1)
	local aq = al._elements[ao]
	if not aq then
		return nil
	end
	if not aq._linkerChild then
		return nil
	end
	return resolveKey(aq._linkerChild, ap)
end

function ak.Get(al, am)	
return resolveKey(al, am)
end

function ak.Watch(al, am, an)	
local ao = resolveKey(al, am)
	if not ao then
		return function() end
	end
	if type(ao.OnChange) == "function" then
		return ao.OnChange(ao,an)
	end
	return ah(ao._state, an)
end

function ak.Tip(al, am, an)	
local ao = resolveKey(al, am)
	if ao and ao.SetTip then
		ao.SetTip(		ao,an)
	end
	return al
end

function ak.Peek(al, am)	
local an = resolveKey(al, am)
	if not an then
		return nil
	end
	if type(an.Peek) == "function" then
		return an.Peek(an)
	end
	return ai(an._state)
end

function ak.PeekTransparency(al, am)	
local an = resolveKey(al, am)
	if not an or not an._transparency then
		return nil
	end
	return ai(an._transparency)
end

function ak.On(al, am, an)	
local ao = al._prefix
	if an and an ~= "" then
		ao = joinKey(ao, an)
	end
	local ap = makeLinker(am, ao, al._scoped, al._globalOnly)
	am._linkerChild = ap
	return ap
end

function ak.Scoped(al, am)	
al._scoped = am ~= false
	return al
end

function ak.Global(al)	
return (setmetatable({
		_host = al._host,
		_prefix = al._prefix,
		_scoped = al._scoped,
		_globalOnly = al._scoped,
		_elements = al._elements,
	}, ak) )
end

function ak.OnKey(al, am)	
local an = al._elements[am]
	if not an then
		return al
	end
	if an._linkerChild then
		return an._linkerChild
	end
	return al.On(al,an, am)
end

function ak.Toggle(al, am, an, ao)	
return add(al, am, al._host:AddElement("Toggle", an, ao or false))
end

function ak.Slider(
	al,
	am,
	an,
	ao,
	ap,
	aq,
	ar,
	as,
	at
)	
return add(al, am, al._host:AddElement("Slider", an, ao, ap, aq, ar, as, at))
end

function ak.Dropdown(al, am, an, ao, ap)	
return add(al, am, al._host:AddElement("Dropdown", an, ao, ap))
end

function ak.Colorpicker(
	al,
	am,
	an,
	ao,
	ap
)	
return add(al, am, al._host:AddElement("Colorpicker", an, ao, ap))
end

function ak.CurveEditor(al, am, an, ao, ap, aq)	
return add(al, am, al._host:AddElement("CurveEditor", an, ao, ap, aq))
end

function ak.List(al, am, an, ao, ap)	
return add(al, am, al._host:AddElement("List", an, ao, ap))
end

function ak.Button(al, am, an)	
return al._host:AddElement("Button", am, an)
end

function ak.Key(
	al,
	am,
	an,
	ao,
	ap
)	
local aq = al._host:AddElement("Key", an, ao, ap)
	if am then
		local ar = joinKey(al._prefix, am)
		ad.Link(ar, aq)
		al._elements[am] = aq
		if al._scoped then
			ae.BindElement(aq, ar, { globalOnly = true })
		end
	end
	return aq
end

function ak.Submenu(al, am, an)	
local ao = an or am or ""
	local ap = al._host:AddElement("Submenu", ao)
	if am then
		al._elements[am] = ap
	end
	return ap
end

function ak.AssetPicker(al, am, an, ao)	
local ap = al._host:AddElement("AssetPicker", an, ao)
	return add(al, am, ap)
end

function ak.Extra(al, am, an, ao, ...)	
local ap = am.AddElement(am,ao, ...)
	if not ap then
		return nil
	end
	return add(al, an, ap)
end

function ak.Options(al, am, an)	
local ao = an or am or ""
	local ap = al._host:AddElement("Options", ao)
	if am then
		al._elements[am] = ap
	end
	return ap
end

function aj.Mount(al, am, an)	
local ao = al.new(am, an)
	if ao.Destroy then
		ag.addDestroyer(function()
			ao.Destroy(			ao)
		end)
	end
	return ao
end












return aj
end function a.bV()
local aa = a.load'm'
local ab = a.load'c'a.load'bU'


local ad = aa.peek
local ae = aa.subscribe

local af = ab.createBinding
local ag = ab.joinBindings





































local ah = {}

LPH_NO_VIRTUALIZE(function()
	function ah.createBindable(ai)		
local aj, ak = af(ai)
		return { binding = aj, set = ak }
	end

	function ah.fadedTransparency(ai, aj)		
if aj then
			return ag{ ai, aj }:map(function(ak)
				return 1 - (1 - ak[2].transparency) * ak[1]
			end)
		end
		return ai.map(ai,function(ak)
			return 1 - ak
		end)
	end

	function ah.vector2ToUDim2Offset(ai)		
return UDim2.fromOffset(ai.X, ai.Y)
	end

	





function ah.attachHealthCache(ai, aj)		
if not ai then
			aj._health = 0
			aj._maxHealth = 100
			aj._playerUnsub = function() end
			return
		end

		aj._health = ad(ai.health)
		aj._maxHealth = ad(ai.maxHealth)
		local ak = {
			ae(ai.health, function(ak)				
aj._health = ak
			end),
			ae(ai.maxHealth, function(ak)				
aj._maxHealth = ak
			end),
		}
		aj._playerUnsub = function()			
for al = 1, #ak do
				ak[al]()
			end
		end
	end

	




function ah.attachCharacterCache(ai, aj)		
if not ai then
			aj._character = nil
			aj._playerUnsub = function() end
			return
		end

		aj._character = ad(ai.character)
		aj._playerUnsub = ae(ai.character, function(ak)			
aj._character = ak
		end)
	end
end)()

return ah
end function a.bW()
local aa = (cloneref(game.GetService(game, "ReplicatedStorage")) )

local ab = a.load'm'
local ac = a.load'bV'

local ad = ab.peek
local ae = ab.subscribe

local af= {}








local ag = {}

ag.createBindable = ac.createBindable
ag.fadedTransparency = ac.fadedTransparency
ag.vector2ToUDim2Offset = ac.vector2ToUDim2Offset
ag.attachHealthCache = ac.attachHealthCache
ag.attachCharacterCache = ac.attachCharacterCache






function ag.attachWeaponCache(ah, ai)	
if not ah then
		ai._weaponName = nil
		ai._playerUnsub = function() end
		return
	end

	local function sync(aj)		
ai._weaponName = aj and aj.Name or nil
	end

	sync(ad(ah.currentEquipped))
	ai._playerUnsub = ae(ah.currentEquipped, sync)
end










local function resolveWeaponMaxRounds(ah)	
local ai = af[ah]
	if ai then
		return ai.maxRounds, ai.maxRounds > 0
	end

	local aj = aa.Database.Custom.Weapons:FindFirstChild(ah)
	if not aj then
		return 0, false
	end

	setthreadidentity(4)
	local ak, al = pcall(require, aj)
	setthreadidentity(8)
	if not ak or type(al) ~= "table" then
		return 0, false
	end

	if (al ).Class ~= "Weapon" or (al ).MuzzleType == "Zeus x27" then
		return 0, false
	end

	local am = (al ).Rounds
	if type(am) ~= "number" or am <= 0 then
		return 0, false
	end

	af[ah] = {
		maxRounds = am,
		muzzleType = (al ).MuzzleType,
	}
	return am, true
end

function ag.attachAmmoCache(ah, ai)	
if not ah then
		ai._showAmmo = false
		ai._weaponName = nil
		ai._rounds = 0
		ai._capacity = 0
		ai._maxRounds = 1
		ai._playerUnsub = function() end
		return
	end

	local function sync(aj)		
if type(aj) ~= "table" or type(aj.Name) ~= "string" or aj.Name == "" then
			ai._showAmmo = false
			ai._weaponName = nil
			ai._rounds = 0
			ai._capacity = 0
			return
		end

		local ak, al = resolveWeaponMaxRounds(aj.Name)
		if not al then
			ai._showAmmo = false
			ai._weaponName = nil
			ai._rounds = 0
			ai._capacity = 0
			return
		end

		ai._showAmmo = true
		ai._weaponName = aj.Name
		ai._maxRounds = ak
		ai._rounds = if type(aj.Rounds) == "number" then math.max(aj.Rounds, 0) else 0
		ai._capacity = if type(aj.Capacity) == "number" then math.max(aj.Capacity, 0) else 0
	end

	sync(ad(ah.currentEquipped))
	ai._playerUnsub = ae(ah.currentEquipped, sync)
end

return ag
end function a.bX()
local aa = a.load'm'

local ab = aa.atom













local ac = {
	entries = ab({} ),
}



return ac
end end
local aa = a.load'c'
local ab = a.load'd'
local ac = a.load'e'

local ad = a.load's'
local ae = a.load'bW'
local af = a.load'bX'

local ag = (cloneref(game.GetService(game, "RunService")) )
local ah = (cloneref(game.GetService(game, "Workspace")) )

local ai = aa.createElement
local aj = aa.useBinding
local ak = aa.useEffect
local al = ac.useSpring
local am = ab.useAtom

local an = 24
local ao = 55
local ap = 0.7
local aq = ao * ap
local ar = math.max(ao - aq, 1)

local as = { dampingRatio = 0.65, frequency = 3.5, precision = 0.005 }
local at = { dampingRatio = 1, frequency = 90, precision = 0.5 }
local au = Vector2.new(0.5, 0.5)

local av = 36
local aw = 2
local ax = 2
local ay = 0
local az = Color3.new(1, 1, 1)

local function toNumberSequence(aA)	
return NumberSequence.new(aA)
end

local aA = math.floor
local aB = math.clamp

local function modelWorldPosition(aC)	
local aD = aC.PrimaryPart
	if aD then
		return aD.Position
	end
	local aE = aC.GetPivot(aC)
	if typeof(aE) == "CFrame" then
		return aE.Position
	end
	return nil
end


















local aC = LPH_NO_VIRTUALIZE(function(
	aC,
	aD,
	aE,
	aF,
	aG,
	aH
)	
local aI = aC.model
	if not aI.Parent then
		return
	end

	local aJ = modelWorldPosition(aI)
	if not aJ then
		return
	end

	local aK = ah.CurrentCamera
	local aL = aK.ViewportSize
	local aM, aN = aL.X, aL.Y
	local aO = aK.WorldToViewportPoint(aK,aJ)
	local aP = aO.X
	local aQ = aO.Y
	local aR = aO.Z <= 0

	local aS = aR
		or aP < an
		or aP > aM - an
		or aQ < an
		or aQ > aN - an

	aD(aS and 0 or 1)

	local aT = aK.CFrame.Position
	local aU = aJ.X - aT.X
	local aV = aJ.Y - aT.Y
	local aW = aJ.Z - aT.Z
	local aX = math.sqrt(aU * aU + aV * aV + aW * aW)
	local aY = aB(1 - (aX - aq) / ar, 0, 1)
	aE(aY)

	if aH[1] then
		aH[1] = false
		aF.setPosition(		aF,aP)
		aG.setPosition(		aG,aQ)
	end

	aF.setGoal(
	aF,aP)
	aG.setGoal(	aG,aQ)
end)

local aD = LPH_JIT_MAX(function(aD)	local aE = aD.entry
	local aF = aD.weaponStyle
	local aG = aF ~= nil

	local aH = if aG then aF.textColor else aD.color
	local aI = if aG then aF.textOutline else true
	local aJ = if aG then aF.textOutlineColor else Color3.fromRGB(18, 18, 18)

	local aK = aG and aF.showAmmo and aE.showAmmo and aE.maxRounds > 0

	local aL, aM = aj(1)
	local aN, aO = aj(0)
	local aP, aQ = al(0, at)
	local aR, aS = al(0, at)
	local aT, aU = al(1, as)

	ak(function()
		aU.setGoal(		aU,1)
	end, {})

	ak(function()
		local aV = { true }
		local function step()			
aC(aE, aO, aM, aQ, aS, aV)
		end
		step()
		local aW = ag.PreRender:Connect(step)
		return function()
			aW.Disconnect(			aW)
		end
	end, { aE.model })

	local aV = aa.joinBindings{ aP, aR }:map(function(aV)		
return UDim2.fromOffset(aA(aV[1]), aA(aV[2]))
	end)

	local aW = aa.joinBindings{ aT, aL, aN }		
:map(function(aW)			
return aW[1] * aW[2] * aW[3]
		end)

	local aX = aW.map(aW,function(aX)		
return aB(1 - aX, 0, 1)
	end)

	local aY = if aE.maxRounds > 0 then aE.rounds / aE.maxRounds else 0
	local aZ = ae.fadedTransparency(aW)

	return ai("Frame", {
		AnchorPoint = au,
		Position = aV,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(aK and av or 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Layout = ai("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, ax),
		}),
		Label = ai("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromOffset(0, 12),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = aE.label,
			TextColor3 = aH,
			TextTransparency = aX,
			FontFace = ad.Get("font", "pixel2"),
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, {
			Stroke = aI and ai("UIStroke", {
				Color = aJ,
				Thickness = 1,
				Transparency = aX,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			}) or nil,
		}),
		AmmoBar = aK and aF and ai("Frame", {
			LayoutOrder = 2,
			Size = UDim2.fromOffset(av, aw),
			BackgroundColor3 = aF.ammoBackgroundPicker._currentColor,
			BackgroundTransparency = aZ,
			BorderSizePixel = 0,
		}, {
			Fill = ai("Frame", {
				Size = UDim2.fromScale(math.clamp(aY, 0, 1), 1),
				BackgroundColor3 = az,
				BackgroundTransparency = aZ,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, {
				UIGradient = ai("UIGradient", {
					Color = aF.ammoFillPicker._currentGradient,
					Rotation = ay,
					Transparency = aF.ammoFillPicker._currentTransparency:map(toNumberSequence),
				}),
			}),
			Outline = aF.barOutline and ai("UIStroke", {
				Color = aF.barOutlinePicker._currentColor,
				Transparency = aZ,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				LineJoinMode = Enum.LineJoinMode.Miter,
			}) or nil,
		}) or nil,
	})
end)


















return LPH_NO_VIRTUALIZE(function(aE)	
local aF = (am(aE.enabledLink._state) )	
local aG = (am(aE.weaponLink._state) )	
local aH = (am(aE.bombLink._state) )	
local aI = (am(aE.itemLink._state) )	
local aJ = (am(aE.weaponAmmoLink._state) )	
local aK = (am(aE.weaponTextOutlineLink._state) )	
local aL = (am(aE.weaponBarOutlineLink._state) )	
local aM = (am(af.entries) )
	
if not aF then
		return nil
	end

	local aN= {
		textColor = aE.weaponTextColorLink._currentColor,
		textOutline = aK,
		textOutlineColor = aE.weaponTextOutlineColorLink._currentColor,
		showAmmo = aJ,
		ammoFillPicker = aE.weaponAmmoFillLink,
		ammoBackgroundPicker = aE.weaponAmmoBackgroundLink,
		barOutline = aL,
		barOutlinePicker = aE.weaponBarOutlineColorLink,
	}

	local aO = aE.bombColorLink._currentColor
	local aP = aE.itemColorLink._currentColor

	local aQ= {}
	for aR, aS in next, aM do
		if not aR.Parent then
			continue
		end

		local aT = false
		local aU		
local aV		
if aS.kind == "weapon" then
			aT = aG
			aU = aN.textColor
			aV = aN
		elseif aS.kind == "bomb" then
			aT = aH
			aU = aO
		else
			aT = aI
			aU = aP
		end

		if not aT then
			continue
		end

		aQ[tostring(aR)] = ai(aD, {
			entry = aS,
			color = aU,
			weaponStyle = aV,
		})
	end

	return ai("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, aQ)
end)
