local a
a = {
	cache = {},
	load = function(b)
		if not a.cache[b] then
			a.cache[b] = { c = a[b]() }
		end
		return a.cache[b].c
	end,
}
do
	function a.a()
		return function(b)
			return typeof(b) == "number" and b == b and b ~= math.huge and b ~= -math.huge
		end
	end
	function a.b()
		return function(b)
			return type(b) == "number" and b ~= math.huge and b == math.floor(b)
		end
	end
	function a.c()
		return function(b)
			return type(b) == "number" and b ~= b
		end
	end
	function a.d()
		return 9007199254740991
	end
	function a.e()
		local b = a.load("b")
		local c = a.load("d")
		return function(d)
			return b(d) and math.abs(d) <= c
		end
	end
	function a.f()
		return -9007199254740991
	end
	function a.g()
		return function(b, c)
			local d = b
			if typeof(b) == "string" then
				local e = 0 / 0
				d = tonumber(b) or e
			end
			if typeof(d) ~= "number" then
				return "nan"
			end
			if c ~= nil then
				if typeof(c) ~= "number" then
					error("TypeError: fractionDigits must be a number between 0 and 100")
				end
				if c < 0 or c > 100 then
					error("RangeError: fractionDigits must be between 0 and 100")
				end
			end
			local e
			if c == nil then
				e = "%e"
			else
				e = "%." .. tostring(c) .. "e"
			end
			local g = string.format(e, d):gsub("%+0", "+"):gsub("%-0", "-"):gsub("0*e", "e")
			return g
		end
	end
	function a.h()
		return {
			isFinite = a.load("a"),
			isInteger = a.load("b"),
			isNaN = a.load("c"),
			isSafeInteger = a.load("e"),
			MAX_SAFE_INTEGER = a.load("d"),
			MIN_SAFE_INTEGER = a.load("f"),
			NaN = 0 / 0,
			toExponential = a.load("g"),
		}
	end
	function a.i()
		return a.load("h")
	end
	function a.j()
		local b = a.load("i")
		return function(c)
			return not not c and c ~= 0 and c ~= "" and not b.isNaN(c)
		end
	end
	function a.k()
		return { toJSBoolean = a.load("j") }
	end
	function a.l()
		return a.load("k")
	end
	function a.m()
		return {}
	end
	function a.n()
		return a.load("m")
	end
	function a.o()
		return function(b)
			if typeof(b) ~= "table" then
				return false
			end
			if next(b) == nil then
				return true
			end
			local c = #b
			if c == 0 then
				return false
			end
			local d = 0
			local e = 0
			for g in pairs(b) do
				if typeof(g) ~= "number" then
					return false
				end
				if g % 1 ~= 0 or g < 1 then
					return false
				end
				d += 1
				e += g
			end
			return e == (d * (d + 1) / 2)
		end
	end
	function a.p()
		local b = _G.__DEV__
		local c = a.load("o")
		local d = a.load("n")
		local e =
			"Array.concat(...) only works with array-like tables but it received an object-like table.\nYou can avoid this error by wrapping the object-like table into an array. Example: `concat({1, 2}, {a = true})` should be `concat({1, 2}, { {a = true} }`"
		local function concat(g, ...)
			local h
			local i = 0
			if c(g) then
				h = table.clone(g)
				i = #g
			else
				i += 1
				h = {}
				h[i] = g
			end
			for j = 1, select("#", ...) do
				local k = select(j, ...)
				local l = typeof(k)
				if k == nil then
				elseif l == "table" then
					if b then
						if not c(k) then
							error(e)
						end
					end
					for m = 1, #k do
						i += 1
						h[i] = k[m]
					end
				else
					i += 1
					h[i] = k
				end
			end
			return h
		end
		return concat
	end
	function a.q()
		local b = _G.__DEV__
		local c = a.load("n")
		return function(d, e, g)
			if b then
				if typeof(d) ~= "table" then
					error(string.format("Array.every called on %s", typeof(d)))
				end
				if typeof(e) ~= "function" then
					error("callback is not a function")
				end
			end
			local h = #d
			local i = 1
			while i <= h do
				local j = d[i]
				local k
				if j ~= nil then
					if g ~= nil then
						k = (e)(g, j, i, d)
					else
						k = (e)(j, i, d)
					end
					if not k then
						return false
					end
				end
				i += 1
			end
			return true
		end
	end
	function a.r()
		local b = _G.__DEV__
		local c = a.load("n")
		return function(d, e, g)
			if b then
				if typeof(d) ~= "table" then
					error(string.format("Array.filter called on %s", typeof(d)))
				end
				if typeof(e) ~= "function" then
					error("callback is not a function")
				end
			end
			local h = #d
			local i = {}
			local j = 1
			if g == nil then
				for k = 1, h do
					local l = d[k]
					if l ~= nil then
						if (e)(l, k, d) then
							i[j] = l
							j += 1
						end
					end
				end
			else
				for k = 1, h do
					local l = d[k]
					if l ~= nil then
						if (e)(g, l, k, d) then
							i[j] = l
							j += 1
						end
					end
				end
			end
			return i
		end
	end
	function a.s()
		local b = a.load("n")
		return function(c, d)
			for e = 1, #c do
				local g = c[e]
				if d(g, e, c) then
					return g
				end
			end
			return nil
		end
	end
	function a.t()
		local b = a.load("n")
		return function(c, d)
			for e = 1, #c do
				local g = c[e]
				if d(g, e, c) then
					return e
				end
			end
			return -1
		end
	end
	function a.u()
		local b = _G.__DEV__
		local c = a.load("o")
		local d = a.load("n")
		local function flat(e, g)
			if b then
				if typeof(e) ~= "table" then
					error(string.format("Array.flat called on %s", typeof(e)))
				end
				if g ~= nil and typeof(g) ~= "number" then
					error("depth is not a number or nil")
				end
			end
			local h = g or 1
			local i = {}
			for j, k in e do
				if c(k) then
					local l = k
					local m = if h > 1 then flat(l, h - 1) else l
					for n, o in m do
						table.insert(i, o)
					end
				else
					table.insert(i, k)
				end
			end
			return i
		end
		return flat
	end
	function a.v()
		local b = _G.__DEV__
		local c = a.load("n")
		return function(d, e, g)
			if b then
				if typeof(d) ~= "table" then
					error(string.format("Array.map called on %s", typeof(d)))
				end
				if typeof(e) ~= "function" then
					error("callback is not a function")
				end
			end
			local h = #d
			local i = {}
			local j = 1
			while j <= h do
				local k = d[j]
				if k ~= nil then
					local l
					if g ~= nil then
						l = (e)(g, k, j, d)
					else
						l = (e)(k, j, d)
					end
					i[j] = l
				end
				j += 1
			end
			return i
		end
	end
	function a.w()
		local b = _G.__DEV__
		local c = a.load("u")
		local d = a.load("v")
		local e = a.load("n")
		local function flatMap(g, h, i)
			if b then
				if typeof(g) ~= "table" then
					error(string.format("Array.flatMap called on %s", typeof(g)))
				end
				if typeof(h) ~= "function" then
					error("callback is not a function")
				end
			end
			return c(d(g, h, i))
		end
		return flatMap
	end
	function a.x()
		local b = _G.__DEV__
		local c = a.load("n")
		return function(d, e, g)
			if b then
				if typeof(d) ~= "table" then
					error(string.format("Array.forEach called on %s", typeof(d)))
				end
				if typeof(e) ~= "function" then
					error("callback is not a function")
				end
			end
			local h = #d
			local i = 1
			while i <= h do
				local j = d[i]
				if g ~= nil then
					(e)(g, j, i, d)
				else
					(e)(j, i, d)
				end
				if #d < h then
					h = #d
				end
				i += 1
			end
		end
	end
	function a.y()
		local b = cloneref or function(b)
			return b
		end
		local c = b(game.GetService(game, "HttpService"))
		local d = a.load("o")
		local e = a.load("n")
		local g = 10
		local h = 2
		local i
		local j
		local k
		local l
		local m
		local function inspect(n, o)
			local p = o or { depth = h }
			local q = p.depth or h
			p.depth = if q >= 0 then q else h
			return i(n, {}, p)
		end
		local function isIndexKey(n, o)
			return type(n) == "number" and n <= o and 1 <= n and math.floor(n) == n
		end
		local function getTableLength(n)
			local o = 1
			local p = rawget(n, o)
			while p ~= nil do
				o += 1
				p = rawget(n, o)
			end
			return o - 1
		end
		local function sortKeysForPrinting(n, o)
			local p = type(n)
			local q = type(o)
			if p == q and (p == "number" or p == "string") then
				return n < o
			end
			return p < q
		end
		local function rawpairs(n)
			return next, n, nil
		end
		local function getFragmentedKeys(n)
			local o = {}
			local p = 0
			local q = getTableLength(n)
			for r, s in rawpairs(n) do
				if not isIndexKey(r, q) then
					p = p + 1
					o[p] = r
				end
			end
			table.sort(o, sortKeysForPrinting)
			return o, p, q
		end
		function i(n, o, p)
			local q = typeof(n)
			if q == "string" then
				return c.JSONEncode(c, n)
			elseif q == "number" then
				if n ~= n then
					return "NaN"
				elseif n == math.huge then
					return "Infinity"
				elseif n == -math.huge then
					return "-Infinity"
				else
					return tostring(n)
				end
			elseif q == "function" then
				local r = "[function"
				local s = debug.info(n, "n")
				if s ~= nil and s ~= "" then
					r ..= " " .. s
				end
				return r .. "]"
			elseif q == "table" then
				return j(n, o, p)
			else
				return tostring(n)
			end
		end
		function j(n, o, p)
			if table.find(o, n) ~= nil then
				return "[Circular]"
			end
			local q = { unpack(o) }
			table.insert(q, n)
			if typeof(n.toJSON) == "function" then
				local r = n.toJSON(n, n)
				if r ~= n then
					if typeof(r) == "string" then
						return r
					else
						return i(r, q, p)
					end
				end
			elseif d(n) then
				return k(n, q, p)
			end
			return l(n, q, p)
		end
		function l(n, o, p)
			local q = ""
			local r = getmetatable(n)
			if r and rawget(r, "__tostring") then
				return tostring(n)
			end
			local s, t, u = getFragmentedKeys(n)
			if u == 0 and t == 0 then
				q ..= "{}"
				return q
			end
			if #o > p.depth then
				q ..= "[" .. m(n) .. "]"
				return q
			end
			local v = {}
			for w = 1, u do
				local x = i(n[w], o, p)
				table.insert(v, x)
			end
			for w = 1, t do
				local x = s[w]
				local y = i(n[x], o, p)
				table.insert(v, x .. ": " .. y)
			end
			q ..= "{ " .. table.concat(v, ", ") .. " }"
			return q
		end
		function k(n, o, p)
			local q = #n
			if q == 0 then
				return "[]"
			end
			if #o > p.depth then
				return "[Array]"
			end
			local r = math.min(g, q)
			local s = q - r
			local t = {}
			for u = 1, r do
				t[u] = (i(n[u], o, p))
			end
			if s == 1 then
				table.insert(t, "... 1 more item")
			elseif s > 1 then
				table.insert(t, ("... %s more items").format("... %s more items", tostring(s)))
			end
			return "[" .. table.concat(t, ", ") .. "]"
		end
		function m(n)
			return "Object"
		end
		return inspect
	end
	function a.z()
		local b = a.load("n")
		return function(c, d, e)
			local g = {}
			local h = #c
			g = table.create(h)
			if d then
				for i = 1, h do
					if e ~= nil then
						(g)[i] = (d)(e, (string.sub(c, i, i)), i)
					else
						(g)[i] = (d)((string.sub(c, i, i)), i)
					end
				end
			else
				for i = 1, h do
					(g)[i] = string.sub(c, i, i)
				end
			end
			return g
		end
	end
	function a.A()
		local b = _G.__DEV__
		local c = a.load("y")
		local d = a.load("o")
		local e = a.load("x")
		local g = a.load("z")
		local h = a.load("n")
		local i = {
			__iter = function(i)
				return next, i._array
			end,
			__tostring = function(i)
				local j = "Set "
				if #i._array > 0 then
					j ..= "(" .. tostring(#i._array) .. ") "
				end
				j ..= c(i._array)
				return j
			end,
		};
		(i).__index = i
		function i.new(j)
			local k
			local l = {}
			if j ~= nil then
				local m
				if typeof(j) == "table" then
					if d(j) then
						m = table.clone(j)
					else
						local n = getmetatable(j)
						if n and rawget(n, "__iter") then
							m = j
						elseif b then
							error("cannot create array from an object-like table")
						end
					end
				elseif typeof(j) == "string" then
					m = (g(j))
				else
					error(
						("cannot create array from value of type `%s`").format(
							"cannot create array from value of type `%s`",
							typeof(j)
						)
					)
				end
				if m then
					k = table.create(#m)
					for n, o in m do
						if not l[o] then
							l[o] = true
							table.insert(k, o)
						end
					end
				else
					k = {}
				end
			else
				k = {}
			end
			return (setmetatable({ size = #k, _map = l, _array = k }, i))
		end
		function i:add(j)
			if not self._map[j] then
				self.size = self.size + 1
				self._map[j] = true
				table.insert(self._array, j)
			end
			return self
		end
		function i:clear()
			self.size = 0
			table.clear(self._map)
			table.clear(self._array)
		end
		function i:delete(j)
			if not self._map[j] then
				return false
			end
			self.size = self.size - 1
			self._map[j] = nil
			local k = table.find(self._array, j)
			if k then
				table.remove(self._array, k)
			end
			return true
		end
		function i:forEach(j, k)
			if typeof(j) ~= "function" then
				error("callback is not a function")
			end
			e(self._array, function(l)
				if k ~= nil then
					(j)(k, l, l, self)
				else
					(j)(l, l, self)
				end
			end)
		end
		function i:has(j)
			return self._map[j] ~= nil
		end
		function i:ipairs()
			if b then
				warn(
					debug.traceback(
						"`for _,_ in mySet:ipairs() do` is deprecated and will be removed in a future release, please use `for _,_ in mySet do` instead\n",
						2
					)
				)
			end
			return ipairs(self._array)
		end
		return i
	end
	function a.B()
		local b = _G.__DEV__
		local function instanceof(c, d)
			if b then
				assert(typeof(d) == "table", "Received a non-table as the second argument for instanceof")
			end
			if typeof(c) ~= "table" then
				return false
			end
			local e, g = pcall(function()
				return d.new ~= nil and c.new == d.new
			end)
			if e and g then
				return true
			end
			local h = { [c] = true }
			while c and typeof(c) == "table" do
				c = getmetatable(c)
				if typeof(c) == "table" then
					c = c.__index
					if c == d then
						return true
					end
				end
				if typeof(c) == "table" then
					if h[c] then
						return false
					end
					h[c] = true
				end
			end
			return false
		end
		return instanceof
	end
	function a.C()
		local b = a.load("B")
		return b
	end
	function a.D()
		return a.load("C")
	end
	function a.E()
		local b = _G.__DEV__
		local c = a.load("x")
		local d = a.load("v")
		local e = a.load("o")
		local g = a.load("D")
		local h = a.load("n")
		local i = {}
		function i.new(j)
			local k
			local l
			if j == nil then
				k = {}
				l = {}
			elseif e(j) then
				if b then
					if #j > 0 and typeof((j)[1]) ~= "table" then
						error(
							"Value `"
								.. typeof((j)[1])
								.. "` is not an entry object.\n Cannot create Map from {K, V} form, it must be { {K, V}... }"
						)
					end
				end
				k = table.create(#j)
				l = {}
				for m, n in j do
					local o = n[1]
					if b then
						if o == nil then
							error("cannot create Map from a table that isn't an array.")
						end
					end
					local p = n[2]
					if l[o] == nil then
						table.insert(k, o)
					end
					l[o] = p
				end
			elseif g(j, i) then
				k = table.clone((j)._array)
				l = table.clone((j)._map)
			else
				error(
					("`%s` `%s` is not iterable, cannot make Map using it").format(
						"`%s` `%s` is not iterable, cannot make Map using it",
						typeof(j),
						tostring(j)
					)
				)
			end
			return (setmetatable({ size = #k, _map = l, _array = k }, i))
		end
		function i:set(j, k)
			if self._map[j] == nil then
				self.size = self.size + 1
				table.insert(self._array, j)
			end
			self._map[j] = k
			return self
		end
		function i:get(j)
			return self._map[j]
		end
		function i:clear()
			local j = table
			self.size = 0
			j.clear(self._map)
			j.clear(self._array)
		end
		function i:delete(j)
			if self._map[j] == nil then
				return false
			end
			self.size = self.size - 1
			self._map[j] = nil
			local k = table.find(self._array, j)
			if k then
				table.remove(self._array, k)
			end
			return true
		end
		function i:forEach(j, k)
			if b then
				if typeof(j) ~= "function" then
					error("callback is not a function")
				end
			end
			c(self._array, function(l)
				local m = self._map[l]
				if k ~= nil then
					(j)(k, m, l, self)
				else
					(j)(m, l, self)
				end
			end)
		end
		function i:has(j)
			return self._map[j] ~= nil
		end
		function i:keys()
			return self._array
		end
		function i:values()
			return d(self._array, function(j)
				return self._map[j]
			end)
		end
		function i:entries()
			return d(self._array, function(j)
				return { j, self._map[j] }
			end)
		end
		function i:ipairs()
			if b then
				warn(
					debug.traceback(
						"`for _,_ in myMap:ipairs() do` is deprecated and will be removed in a future release, please use `for _,_ in myMap do` instead\n",
						2
					)
				)
			end
			return ipairs(self.entries(self))
		end
		function i.__iter(j)
			return next, j.entries(j)
		end
		function i.__index(j, k)
			local l = rawget(i, k)
			if l ~= nil then
				return l
			end
			if b then
				assert(
					rawget(j, "_map"),
					"Map has been corrupted, and is missing private state! Did you accidentally call table.clear() instead of map:clear()?"
				)
			end
			return i.get(j, k)
		end
		function i.__newindex(j, k, l)
			j.set(j, k, l)
		end
		return i
	end
	function a.F()
		local b = a.load("n")
		return function(c, d, e)
			local g = {}
			if d then
				g = {}
				for h, i in c do
					if e ~= nil then
						(g)[h] = (d)(e, i, h)
					else
						(g)[h] = (d)(i, h)
					end
				end
			else
				g = table.clone((c)._array)
			end
			return g
		end
	end
	function a.G()
		local b = a.load("n")
		return function(c, d, e)
			local g = {}
			if d then
				g = {}
				for h, i in c do
					if e ~= nil then
						(g)[h] = (d)(e, i, h)
					else
						(g)[h] = (d)(i, h)
					end
				end
			else
				g = {}
				for h, i in c do
					(g)[h] = i
				end
			end
			return g
		end
	end
	function a.H()
		local b = a.load("n")
		return function(c, d, e)
			local g = {}
			if d then
				local h = #c
				g = table.create(h)
				for i = 1, h do
					if e ~= nil then
						(g)[i] = (d)(e, (c)[i], i)
					else
						(g)[i] = (d)((c)[i], i)
					end
				end
			else
				g = table.clone(c)
			end
			return g
		end
	end
	function a.I()
		local b = a.load("A")
		local c = a.load("E")
		local d = a.load("o")
		local e = a.load("D")
		local g = a.load("n")
		local h = a.load("z")
		local i = a.load("F")
		local j = a.load("G")
		local k = a.load("H")
		return function(l, m, n)
			if l == nil then
				error("cannot create array from a nil value")
			end
			local o = typeof(l)
			local p
			if o == "table" and d(l) then
				p = k(l, m, n)
			elseif e(l, b) then
				p = i(l, m, n)
			elseif e(l, c) then
				p = j(l, m, n)
			elseif o == "string" then
				p = h(l, m, n)
			else
				p = {}
			end
			return p
		end
	end
	function a.J()
		local b = a.load("n")
		return function(c, d, e)
			local g = e or 1
			local h = #c
			if g < 1 then
				g = math.max(h - math.abs(g), 1)
			end
			for i = g, h do
				if c[i] == d then
					return i
				end
			end
			return -1
		end
	end
	function a.K()
		local b = a.load("n")
		local c = a.load("J")
		return function(d, e, g)
			return c(d, e, g) ~= -1
		end
	end
	function a.L()
		local b = a.load("n")
		local c = a.load("v")
		return function(d, e)
			if #d == 0 then
				return ""
			end
			local g = c(d, function(g)
				return tostring(g)
			end)
			return table.concat(g, e or ",")
		end
	end
	function a.M()
		local b = _G.__DEV__
		local c = a.load("n")
		return function(d, e, g)
			if b then
				if typeof(d) ~= "table" then
					error(string.format("Array.reduce called on %s", typeof(d)))
				end
				if typeof(e) ~= "function" then
					error("callback is not a function")
				end
			end
			local h = #d
			local i
			local j = 1
			if g ~= nil then
				i = g
			else
				j = 2
				if h == 0 then
					error("reduce of empty array with no initial value")
				end
				i = d[1]
			end
			for k = j, h do
				i = e(i, d[k], k, d)
			end
			return i
		end
	end
	function a.N()
		local b = a.load("n")
		return function(c)
			local d = #c
			local e = 1
			while e < d do
				c[e], c[d] = c[d], c[e]
				e = e + 1
				d = d - 1
			end
			return c
		end
	end
	function a.O()
		local b = _G.__DEV__
		local c = a.load("o")
		local d = a.load("n")
		return function(e)
			if b then
				if not c(e) then
					error(string.format("Array.shift called on non-array %s", typeof(e)))
				end
			end
			if #e > 0 then
				return table.remove(e, 1)
			else
				return nil
			end
		end
	end
	function a.P()
		local b = a.load("n")
		return function(c, d, e)
			if typeof(c) ~= "table" then
				error(string.format("Array.slice called on %s", typeof(c)))
			end
			local g = #c
			local h = d or 1
			local i
			if e == nil or e > g + 1 then
				i = g + 1
			else
				i = e
			end
			if h > g + 1 then
				return {}
			end
			local j = {}
			if h < 1 then
				h = math.max(g - math.abs(h), 1)
			end
			if i < 1 then
				i = math.max(g - math.abs(i), 1)
			end
			local k = h
			local l = 1
			while k < i do
				j[l] = c[k]
				k = k + 1
				l = l + 1
			end
			return j
		end
	end
	function a.Q()
		local b = a.load("n")
		return function(c, d, e)
			if typeof(c) ~= "table" then
				error(string.format("Array.some called on %s", typeof(c)))
			end
			if typeof(d) ~= "function" then
				error("callback is not a function")
			end
			for g, h in c do
				if e ~= nil then
					if h ~= nil and (d)(e, h, g, c) then
						return true
					end
				else
					if h ~= nil and (d)(h, g, c) then
						return true
					end
				end
			end
			return false
		end
	end
	function a.R()
		local b = newproxy(true)
		local c = getmetatable(b)
		c.__tostring = function()
			return "Object.None"
		end
		return b
	end
	function a.S()
		local b = a.load("R")
		local c = a.load("n")
		local d = function(d, e)
			return type(d) .. tostring(d) < type(e) .. tostring(e)
		end
		return function(e, g)
			local h = d
			if g ~= nil and g ~= b then
				if typeof(g) ~= "function" then
					error("invalid argument to Array.sort: compareFunction must be a function")
				end
				h = function(i, j)
					local k = g(i, j)
					if typeof(k) ~= "number" then
						error(
							("invalid result from compare function, expected number but got %s").format(
								"invalid result from compare function, expected number but got %s",
								typeof(k)
							)
						)
					end
					return k < 0
				end
			end
			table.sort(e, h)
			return e
		end
	end
	function a.T()
		local b = a.load("n")
		return function(c, d, e, ...)
			if d > #c then
				local g = select("#", ...)
				for h = 1, g do
					local i = select(h, ...)
					table.insert(c, i)
				end
				return {}
			else
				local g = #c
				if d < 1 then
					d = math.max(g - math.abs(d), 1)
				end
				local h = {}
				local i = e or g
				if i > 0 then
					local j = math.min(g, d + math.max(0, i - 1))
					for k = d, j do
						local l = (table.remove(c, d))
						table.insert(h, l)
					end
				end
				local j = select("#", ...)
				for k = j, 1, -1 do
					local l = select(k, ...)
					table.insert(c, d, l)
				end
				return h
			end
		end
	end
	function a.U()
		local b = _G.__DEV__
		local c = a.load("o")
		local d = a.load("n")
		return function(e, ...)
			if b then
				if not c(e) then
					error(string.format("Array.unshift called on non-array %s", typeof(e)))
				end
			end
			local g = select("#", ...)
			if g > 0 then
				for h = g, 1, -1 do
					local i = select(h, ...)
					table.insert(e, 1, i)
				end
			end
			return #e
		end
	end
	function a.V()
		local b = a.load("n")
		return {
			concat = a.load("p"),
			every = a.load("q"),
			filter = a.load("r"),
			find = a.load("s"),
			findIndex = a.load("t"),
			flat = a.load("u"),
			flatMap = a.load("w"),
			forEach = a.load("x"),
			from = a.load("I"),
			includes = a.load("K"),
			indexOf = a.load("J"),
			isArray = a.load("o"),
			join = a.load("L"),
			map = a.load("v"),
			reduce = a.load("M"),
			reverse = a.load("N"),
			shift = a.load("O"),
			slice = a.load("P"),
			some = a.load("Q"),
			sort = a.load("S"),
			splice = a.load("T"),
			unshift = a.load("U"),
		}
	end
	function a.W()
		local b = a.load("R")
		local c = a.load("n")
		return function(d, e, g, h, ...)
			if e ~= nil and typeof(e) == "table" then
				for i, j in pairs(e) do
					if j == b then
						(d)[i] = nil
					else
						(d)[i] = j
					end
				end
			end
			if g ~= nil and typeof(g) == "table" then
				for i, j in pairs(g) do
					if j == b then
						(d)[i] = nil
					else
						(d)[i] = j
					end
				end
			end
			if h ~= nil and typeof(h) == "table" then
				for i, j in pairs(h) do
					if j == b then
						(d)[i] = nil
					else
						(d)[i] = j
					end
				end
			end
			for i = 1, select("#", ...) do
				local j = select(i, ...)
				if j ~= nil and typeof(j) == "table" then
					for k, l in pairs(j) do
						if l == b then
							(d)[k] = nil
						else
							(d)[k] = l
						end
					end
				end
			end
			return d
		end
	end
	function a.X()
		local b = a.load("n")
		return function(c)
			assert(c ~= nil, "cannot get entries from a nil value")
			local d = typeof(c)
			local e = {}
			if d == "table" then
				for g, h in pairs(c) do
					table.insert(e, { g, h })
				end
			elseif d == "string" then
				for g = 1, string.len(c) do
					e[g] = {
						tostring(g),
						string.sub(c, g, g),
					}
				end
			end
			return e
		end
	end
	function a.Y()
		local b = a.load("n")
		return function(c)
			return (table.freeze(c))
		end
	end
	function a.Z()
		return function(b, c)
			if b == c then
				return b ~= 0 or 1 / b == 1 / c
			else
				return b ~= b and c ~= c
			end
		end
	end
	function a._()
		local b = _G.__DEV__
		local c = a.load("n")
		return function(d)
			if b then
				print("Luau now has a direct table.isfrozen call that can save the overhead of this library function call")
			end
			return table.isfrozen(d)
		end
	end
	function a.aa()
		local b = a.load("A")
		local c = a.load("n")
		local d = a.load("D")
		return function(e)
			if e == nil then
				error("cannot extract keys from a nil value")
			end
			local g = typeof(e)
			local h
			if g == "table" then
				h = {}
				if d(e, b) then
					return h
				end
				for i in pairs(e) do
					table.insert(h, i)
				end
			elseif g == "string" then
				local i = e.len(e)
				h = table.create(i)
				for j = 1, i do
					h[j] = tostring(j)
				end
			end
			return h
		end
	end
	function a.ab()
		local b = a.load("n")
		local function preventExtensions(c)
			local d = tostring(c)
			return (
				setmetatable(c, {
					__newindex = function(e, g, h)
						local i = ("%q (%s) is not a valid member of %s").format(
							"%q (%s) is not a valid member of %s",
							tostring(g),
							typeof(g),
							d
						)
						error(i, 2)
					end,
					__metatable = false,
				})
			)
		end
		return preventExtensions
	end
	function a.ac()
		local b = a.load("n")
		return function(c)
			return (table.freeze(c))
		end
	end
	function a.ad()
		local b = a.load("n")
		return function(c)
			if c == nil then
				error("cannot extract values from a nil value")
			end
			local d = typeof(c)
			local e
			if d == "table" then
				e = {}
				for g, h in pairs(c) do
					table.insert(e, h)
				end
			elseif d == "string" then
				local g = c.len(c)
				e = table.create(g)
				for h = 1, g do
					(e)[h] = c.sub(c, h, h)
				end
			end
			return e
		end
	end
	function a.ae()
		return {
			assign = a.load("W"),
			entries = a.load("X"),
			freeze = a.load("Y"),
			is = a.load("Z"),
			isFrozen = a.load("_"),
			keys = a.load("aa"),
			preventExtensions = a.load("ab"),
			seal = a.load("ac"),
			values = a.load("ad"),
			None = a.load("R"),
		}
	end
	function a.af()
		local b = a.load("E")
		local c = a.load("ae")
		local d = a.load("D")
		local e = a.load("n")
		local function coerceToMap(g)
			return d(g, b) and g or b.new(c.entries(g))
		end
		return coerceToMap
	end
	function a.ag()
		local b = a.load("E")
		local c = a.load("D")
		local d = a.load("M")
		local e = a.load("n")
		local function coerceToTable(g)
			if not c(g, b) then
				return g
			end
			return d(g.entries(g), function(h, i)
				h[i[1]] = i[2]
				return h
			end, {})
		end
		return coerceToTable
	end
	function a.ah()
		local b = a.load("n")
		local c = a.load("E")
		local d = a.load("af")
		local e = a.load("ag")
		return { Map = c, coerceToMap = d, coerceToTable = e }
	end
	function a.ai()
		local b = a.load("n")
		local c = {};
		(c).__index = c
		function c.new()
			local d = setmetatable({}, { __mode = "k" })
			return (setmetatable({ _weakMap = d }, c))
		end
		function c:get(d)
			return self._weakMap[d]
		end
		function c:set(d, e)
			self._weakMap[d] = e
			return self
		end
		function c:has(d)
			return self._weakMap[d] ~= nil
		end
		return c
	end
	function a.aj()
		local b = a.load("V")
		local c = a.load("ah")
		local d = a.load("ae")
		local e = a.load("A")
		local g = a.load("ai")
		local h = a.load("y")
		local i = a.load("n")
		return {
			Array = b,
			Object = d,
			Map = c.Map,
			coerceToMap = c.coerceToMap,
			coerceToTable = c.coerceToTable,
			Set = e,
			WeakMap = g,
			inspect = h,
		}
	end
	function a.ak()
		return a.load("aj")
	end
	function a.al()
		return a.load("aj")
	end
	function a.am()
		local b = a.load("al").inspect
		local c = "  "
		return function()
			local d = {}
			local e = 0
			local function indent()
				return string.rep(c, e)
			end
			function d.log(g, ...)
				local h
				if typeof(g) == "string" then
					h = string.format(g, ...)
				else
					h = b(g)
				end
				print(indent() .. h)
			end
			function d.debug(g, ...)
				local h
				if typeof(g) == "string" then
					h = string.format(g, ...)
				else
					h = b(g)
				end
				print(indent() .. h)
			end
			function d.info(g, ...)
				local h
				if typeof(g) == "string" then
					h = string.format(g, ...)
				else
					h = b(g)
				end
				print(indent() .. h)
			end
			function d.warn(g, ...)
				local h
				if typeof(g) == "string" then
					h = string.format(g, ...)
				else
					h = b(g)
				end
				warn(indent() .. h)
			end
			function d.error(g, ...)
				local h
				if typeof(g) == "string" then
					h = string.format(g, ...)
				else
					h = b(g)
				end
				warn(indent() .. h)
			end
			function d.group(g, ...)
				local h
				if typeof(g) == "string" then
					h = string.format(g, ...)
				else
					h = b(g)
				end
				print(indent() .. h)
				e = e + 1
			end
			function d.groupCollapsed(g, ...)
				local h
				if typeof(g) == "string" then
					h = string.format(g, ...)
				else
					h = b(g)
				end
				print(indent() .. h)
				e = e + 1
			end
			function d.groupEnd()
				if e > 0 then
					e = e - 1
				end
			end
			return d
		end
	end
	function a.an()
		local b = a.load("am")
		return b()
	end
	function a.ao()
		return a.load("an")
	end
	function a.ap()
		return bit32.countlz
	end
	function a.aq()
		return { clz32 = a.load("ap") }
	end
	function a.ar()
		return a.load("aq")
	end
	function a.as()
		return a.load("h")
	end
	function a.at()
		return a.load("h")
	end
	function a.au()
		local b = a.load("at")
		local c = b.NaN
		return function(d, e)
			if type(e) ~= "number" then
				e = 1
			end
			local g = string.len(d)
			if e < 1 or e > g then
				return c
			end
			local h = utf8.offset(d, e)
			if h == nil or h > g then
				return c
			end
			local i = utf8.codepoint(d, h, h)
			if i == nil then
				return c
			end
			return i
		end
	end
	function a.av()
		local function endsWith(b, c, d)
			local e = c.len(c)
			if e == 0 then
				return true
			end
			local g = b.len(b)
			local h = d or g
			if h > g then
				h = g
			end
			if h < 1 then
				return false
			end
			local i = h - e + 1
			return b.find(b, c, i, true) == i
		end
		return endsWith
	end
	function a.aw()
		local b = "([" .. ("$%^()-[].?").gsub("$%^()-[].?", "(.)", "%%%1") .. "])"
		local function findOr(c, d, e)
			local g = utf8.offset(c, e or 1)
			local h = {}
			for i, j in d do
				j = j.gsub(j, b, "%%%1")
				local k, l = string.find(c, j, g)
				if k then
					local m = string.sub(c, 1, k - 1)
					local n, o = utf8.len(m)
					if n == nil then
						error(
							("string `%s` has an invalid byte at position %s").format(
								"string `%s` has an invalid byte at position %s",
								m,
								tostring(o)
							)
						)
					end
					local p = n + 1
					local q = { index = p, match = string.sub(c, k, l) }
					table.insert(h, q)
				end
			end
			if #h == 0 then
				return nil
			end
			local i
			for j, k in h do
				if i == nil then
					i = k
				end
				if k.index < i.index then
					i = k
				end
			end
			return i
		end
		return findOr
	end
	function a.ax()
		local b = "([" .. ("$%^()-[].?").gsub("$%^()-[].?", "(.)", "%%%1") .. "])"
		local function includes(c, d, e)
			local g, h = utf8.len(c)
			assert(
				g ~= nil,
				("string `%s` has an invalid byte at position %s").format(
					"string `%s` has an invalid byte at position %s",
					c,
					tostring(h)
				)
			)
			if g == 0 then
				return false
			end
			if #d == 0 then
				return true
			end
			local i = 1
			if e ~= nil then
				i = tonumber(e) or 1
				if i > g then
					return false
				end
			end
			if i < 1 then
				i = 1
			end
			local j = utf8.offset(c, i)
			local k = d.gsub(d, b, "%%%1")
			local l, m = string.find(c, k, j)
			return l ~= nil
		end
		return includes
	end
	function a.ay()
		local b = "([" .. ("$%^()-[].?").gsub("$%^()-[].?", "(.)", "%%%1") .. "])"
		return function(c, d, e)
			local g = #c
			local h = if e ~= nil then if e < 1 then 1 else e else 1
			if #d == 0 then
				return if h > g then g else h
			end
			if h > g then
				return -1
			end
			d = d.gsub(d, b, "%%%1")
			local i = #d
			for j = h, g do
				if string.sub(c, j, j + i - 1) == d then
					return j
				end
			end
			return -1
		end
	end
	function a.az()
		local function lastIndexOf(b, c, d)
			local e = string.len(b)
			local g
			if d then
				g = d
			else
				g = e
			end
			if d and d < 1 then
				g = 1
			end
			if d and d > e then
				g = e
			end
			if c == "" then
				return g
			end
			local h, i
			local j = 0
			repeat
				h = i
				i, j = string.find(b, c, j + 1, true)
			until i == nil or i > g
			if h == nil then
				return -1
			end
			return h
		end
		return lastIndexOf
	end
	function a.aA()
		local function slice(b, c, d)
			local e, g = utf8.len(b)
			assert(
				e ~= nil,
				("string `%s` has an invalid byte at position %s").format(
					"string `%s` has an invalid byte at position %s",
					b,
					tostring(g)
				)
			)
			local h = tonumber(c)
			assert(typeof(h) == "number", "startIndexStr should be a number")
			if h + e < 0 then
				h = 1
			end
			if h > e then
				return ""
			end
			local i = e + 1
			if d ~= nil then
				local j = 0 / 0
				i = tonumber(d) or j
			end
			assert(typeof(i) == "number", "lastIndexStr should convert to number")
			if i > e then
				i = e + 1
			end
			local j = (utf8.offset(b, h))
			local k = (utf8.offset(b, i)) - 1
			return string.sub(b, j, k)
		end
		return slice
	end
	function a.aB()
		return a.load("m")
	end
	function a.aC()
		local b = a.load("aw")
		local c = a.load("aA")
		local d = a.load("aB")
		local e = a.load("at").MAX_SAFE_INTEGER
		local function split(g, h, i)
			if h == nil then
				return { g }
			end
			if i == 0 then
				return {}
			end
			local j = if i == nil or i < 0 then e else i
			local k = h
			local l
			if typeof(k) == "string" then
				if k == "" then
					local m = {}
					for n in g.gmatch(g, ".") do
						table.insert(m, n)
					end
					return m
				end
				l = { k }
			else
				l = k
			end
			local m = 1
			local n = {}
			local o
			local p, q = utf8.len(g)
			assert(
				p ~= nil,
				("string `%s` has an invalid byte at position %s").format(
					"string `%s` has an invalid byte at position %s",
					g,
					tostring(q)
				)
			)
			repeat
				local r = b(g, l, m)
				if r ~= nil then
					table.insert(n, c(g, m, r.index))
					local s = utf8.len(r.match)
					m = r.index + s
				else
					table.insert(n, c(g, m, nil))
				end
				if r ~= nil then
					o = r
				end
			until r == nil or m > p or #n >= j
			if o ~= nil then
				local r, s = utf8.len(o.match)
				assert(
					r ~= nil,
					("string `%s` has an invalid byte at position %s").format(
						"string `%s` has an invalid byte at position %s",
						o.match,
						tostring(s)
					)
				)
				if o.index + r == p + 1 then
					table.insert(n, "")
				end
			end
			return n
		end
		return split
	end
	function a.aD()
		local function startsWith(b, c, d)
			if string.len(c) == 0 then
				return true
			end
			local e
			if d == nil or d < 1 then
				e = 1
			else
				e = d
			end
			if e > string.len(b) then
				return false
			end
			return b.find(b, c, e, true) == e
		end
		return startsWith
	end
	function a.aE()
		return function(b, c, d)
			if d and d <= 0 then
				return ""
			end
			return string.sub(b, c, d and c + d - 1 or nil)
		end
	end
	function a.aF()
		return function(b)
			return (b.gsub(b, "^[%s]+", ""))
		end
	end
	function a.aG()
		return function(b)
			return (b.gsub(b, "[%s]+$", ""))
		end
	end
	function a.aH()
		local b = a.load("aF")
		local c = a.load("aG")
		return function(d)
			return b(c(d))
		end
	end
	function a.aI()
		return {
			charCodeAt = a.load("au"),
			endsWith = a.load("av"),
			findOr = a.load("aw"),
			includes = a.load("ax"),
			indexOf = a.load("ay"),
			lastIndexOf = a.load("az"),
			slice = a.load("aA"),
			split = a.load("aC"),
			startsWith = a.load("aD"),
			substr = a.load("aE"),
			trim = a.load("aH"),
			trimEnd = a.load("aG"),
			trimStart = a.load("aF"),
			trimRight = a.load("aG"),
			trimLeft = a.load("aF"),
		}
	end
	function a.aJ()
		return a.load("aI")
	end
	function a.aK()
		return {
			new = function(b)
				local c = (newproxy(true))
				local d = "Symbol()"
				if b then
					d = ("Symbol(%s)").format("Symbol(%s)", b)
				end
				getmetatable(c).__tostring = function()
					return d
				end
				return c
			end,
		}
	end
	function a.aL()
		local b = a.load("aK")
		local c = {}
		return {
			getOrInit = function(d)
				if c[d] == nil then
					c[d] = b.new(d)
				end
				return c[d]
			end,
			__clear = function()
				c = {}
			end,
		}
	end
	function a.aM()
		local b = a.load("aK")
		local c = a.load("aL")
		local d = setmetatable({}, {
			__call = function(d, e)
				return b.new(e)
			end,
		})
		d.for_ = c.getOrInit
		return d
	end
	function a.aN()
		return a.load("aM")
	end
	function a.aO()
		return a.load("aj")
	end
	function a.aP()
		local b = newproxy(false)
		local c = 1
		local d = 2
		local e = 3
		return function(g)
			local function setTimeout(h, i, ...)
				local j = { ... }
				local k = { [b] = c }
				if i == nil then
					i = 0
				end
				local l = i / 1000
				g(l, function()
					if k[b] == c then
						h(unpack(j))
						k[b] = d
					end
				end)
				return k
			end
			local function clearTimeout(h)
				if h == nil then
					return
				end
				if h[b] == c then
					h[b] = e
				end
			end
			return { setTimeout = setTimeout, clearTimeout = clearTimeout }
		end
	end
	function a.aQ()
		local b = newproxy(false)
		local c = 1
		local d = 3
		return function(e)
			local function setInterval(g, h, ...)
				local i = { ... }
				local j = { [b] = c }
				if h == nil then
					h = 0
				end
				local k = h / 1000
				local l
				l = function()
					e(k, function()
						if j[b] == c then
							g(unpack(i))
							l()
						end
					end)
				end
				l()
				return j
			end
			local function clearInterval(g)
				if g == nil then
					return
				end
				if g[b] == c then
					g[b] = d
				end
			end
			return { setInterval = setInterval, clearInterval = clearInterval }
		end
	end
	function a.aR()
		local b = a.load("aO").Object
		local c = a.load("aP")
		local d = a.load("aQ")
		return b.assign({}, c(task.delay), d(task.delay))
	end
	function a.aS()
		return a.load("aR")
	end
	function a.aT()
		return a.load("m")
	end
	function a.aU()
		local b = a.load("aT")
		local c = {}
		local d = "Error"
		c.__index = c
		c.__tostring = function(e)
			return getmetatable(c).__tostring(e)
		end
		local function __createError(e)
			local g = (setmetatable({ name = d, message = e or "" }, c))
			c.__captureStackTrace(g, 4)
			return g
		end
		function c.new(e)
			return __createError(e)
		end
		function c.captureStackTrace(e, g)
			c.__captureStackTrace(e, 3, g)
		end
		function c.__captureStackTrace(e, g, h)
			local i = e
			if typeof(h) == "function" then
				local j = debug.traceback(nil, g)
				local k = debug.info(h, "n")
				local l = debug.info(h, "s")
				local m = string.gsub(l, "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
				local n = m .. ":%d* function " .. k
				local o = string.find(j, n)
				local p
				if o ~= nil then
					o, p = string.find(j, "\n", o + 1)
				end
				if p ~= nil then
					j = string.sub(j, p + 1)
				end
				i.__stack = j
			else
				i.__stack = debug.traceback(nil, g)
			end
			c.__recalculateStacktrace(i)
		end
		function c.__recalculateStacktrace(e)
			local g = e
			local h = g.message
			local i = g.name or d
			local j = i .. (if h ~= nil and h ~= "" then (": " .. h) else "")
			local k = if g.__stack then g.__stack else ""
			g.stack = j .. "\n" .. k
		end
		return setmetatable(c, {
			__call = function(e, ...)
				return __createError(...)
			end,
			__tostring = function(e)
				if e.name ~= nil then
					if e.message and e.message ~= "" then
						return string.format("%s: %s", tostring(e.name), tostring(e.message))
					end
					return tostring(e.name)
				end
				return tostring(d)
			end,
		})
	end
	function a.aV()
		local b = a.load("aU")
		return b
	end
	function a.aW()
		return a.load("C")
	end
	function a.aX()
		local b = a.load("ak")
		local c = b.Array
		local d = b.Object
		local e = a.load("l")
		local g = a.load("aJ")
		local h = a.load("aT")
		local i = b.inspect
		local j = a.load("aV")
		local k = a.load("aW")
		local l = { stderr = {
			isTTY = false,
			columns = 0,
			hasColors = function(...)
				return true
			end,
		} }
		function ErrorCaptureStackTrace(m, ...)
			j.captureStackTrace(m, ...)
		end
		local function removeColors(m)
			return m
		end
		local m = ""
		local n = ""
		local o = ""
		local p = ""
		local q = {
			deepStrictEqual = "Expected values to be strictly deep-equal:",
			strictEqual = "Expected values to be strictly equal:",
			strictEqualObject = 'Expected "actual" to be reference-equal to "expected":',
			deepEqual = "Expected values to be loosely deep-equal:",
			notDeepStrictEqual = 'Expected "actual" not to be strictly deep-equal to:',
			notStrictEqual = 'Expected "actual" to be strictly unequal to:',
			notStrictEqualObject = 'Expected "actual" not to be reference-equal to "expected":',
			notDeepEqual = 'Expected "actual" not to be loosely deep-equal to:',
			notIdentical = "Values have same structure but are not reference-equal:",
			notDeepEqualUnequal = "Expected values not to be loosely deep-equal:",
		}
		local r = 12
		local function copyError(s)
			local t = d.keys(s)
			local u = {}
			for v, w in t do
				u[w] = s[w]
			end
			u.message = s.message
			return u
		end
		local function inspectValue(s)
			return i(
				s,
				{
					compact = false,
					customInspect = false,
					depth = 1000,
					maxArrayLength = math.huge,
					showHidden = false,
					showProxy = false,
					sorted = true,
					getters = true,
				}
			)
		end
		local function createErrDiff(s, t, u)
			local v = ""
			local w = ""
			local x = ""
			local y = false
			local z = inspectValue(s)
			local A = g.split(z, "\n")
			local B = g.split(inspectValue(t), "\n")
			local C = 0
			local D = ""
			if
				u == "strictEqual"
				and (
					typeof(s) == "table" and s ~= nil and typeof(t) == "table" and t ~= nil
					or typeof(s) == "function" and typeof(t) == "function"
				)
			then
				u = "strictEqualObject"
			end
			if #A == 1 and #B == 1 and A[1] ~= B[1] then
				local E = false
				local F = if E then removeColors(A[1]) else A[1]
				local G = if e.toJSBoolean(E) then removeColors(B[1]) else B[1]
				local H = string.len(F) + string.len(G)
				if H <= r then
					if
						(typeof(s) ~= "table" or s == nil)
						and (typeof(t) ~= "table" or t == nil)
						and (s ~= 0 or t ~= 0)
					then
						return ("%s\n\n").format("%s\n\n", q[u]) .. ("%s !== %s\n").format("%s !== %s\n", A[1], B[1])
					end
				elseif u ~= "strictEqualObject" then
					local I = if l.stderr.isTTY then l.stderr.columns else 80
					if H < I then
						while string.sub(F, C + 1, C + 1) == string.sub(G, C + 1, C + 1) do
							C += 1
						end
						if C > 2 then
							D = ("\n  %s^").format("\n  %s^", string.rep(" ", C))
							C = 0
						end
					end
				end
			end
			local E = A[#A]
			local F = B[#B]
			while E == F do
				local G = C
				C += 1
				if G < 3 then
					x = ("\n  %s%s").format("\n  %s%s", E, x)
				else
					v = E
				end
				table.remove(A)
				table.remove(B)
				if #A == 0 or #B == 0 then
					break
				end
				E = A[#A]
				F = B[#B]
			end
			local G = math.max(#A, #B)
			if G == 0 then
				local H = g.split(z, "\n")
				if #H > 50 then
					H[47] = ("%s...%s").format("%s...%s", m, p)
					while #H > 47 do
						table.remove(H)
					end
				end
				return ("%s\n\n").format("%s\n\n", q.notIdentical) .. ("%s\n").format("%s\n", c.join(H, "\n"))
			end
			if C >= 5 then
				x = ("\n%s...%s%s").format("\n%s...%s%s", m, p, x)
				y = true
			end
			if v ~= "" then
				x = ("\n  %s%s").format("\n  %s%s", v, x)
				v = ""
			end
			local H = 0
			local I = 0
			local J = q[u] .. ("\n%s+ actual%s %s- expected%s").format("\n%s+ actual%s %s- expected%s", n, p, o, p)
			local K = (" %s...%s Lines skipped").format(" %s...%s Lines skipped", m, p)
			local L = A
			local M = ("%s+%s").format("%s+%s", n, p)
			local N = #B
			if #A < G then
				L = B
				M = ("%s-%s").format("%s-%s", o, p)
				N = #A
			end
			for O = 1, G do
				C = O
				if N < O then
					if I > 2 then
						if I > 3 then
							if I > 4 then
								if I == 5 then
									w ..= ("\n  %s").format("\n  %s", L[(O - 3)])
									H += 1
								else
									w ..= ("\n%s...%s").format("\n%s...%s", m, p)
									y = true
								end
							end
							w ..= ("\n  %s").format("\n  %s", L[(O - 2)])
							H += 1
						end
						w ..= ("\n  %s").format("\n  %s", L[(O - 1)])
						H += 1
					end
					I = 0
					if L == A then
						w ..= ("\n%s %s").format("\n%s %s", M, L[O])
					else
						v ..= ("\n%s %s").format("\n%s %s", M, L[O])
					end
					H += 1
				else
					local P = B[O]
					local Q = A[O]
					local R = Q ~= P and (not e.toJSBoolean(g.endsWith(Q, ",")) or g.slice(Q, 0, -1) ~= P)
					if R and g.endsWith(P, ",") and g.slice(P, 0, -1) == Q then
						R = false
						Q ..= ","
					end
					if R then
						if I > 2 then
							if I > 3 then
								if I > 4 then
									if I == 5 then
										w ..= ("\n  %s").format("\n  %s", A[O - 3])
										H += 1
									else
										w ..= ("\n%s...%s").format("\n%s...%s", m, p)
										y = true
									end
								end
								w ..= ("\n  %s").format("\n  %s", A[O - 2])
								H += 1
							end
							w ..= ("\n  %s").format("\n  %s", A[O - 1])
							H += 1
						end
						I = 0
						w ..= ("\n%s+%s %s").format("\n%s+%s %s", n, p, Q)
						v ..= ("\n%s-%s %s").format("\n%s-%s %s", o, p, P)
						H += 2
					else
						w ..= v
						v = ""
						I += 1
						if I <= 2 then
							w ..= ("\n  %s").format("\n  %s", Q)
							H += 1
						end
					end
				end
				if H > 50 and O < G - 2 then
					return ("%s%s\n%s\n%s...%s%s\n").format("%s%s\n%s\n%s...%s%s\n", J, K, w, m, p, v)
						.. ("%s...%s").format("%s...%s", m, p)
				end
			end
			return ("%s%s\n%s%s%s%s").format("%s%s\n%s%s%s%s", J, if y then K else "", w, v, x, D)
		end
		local s = (setmetatable({}, {
			__index = j,
		}))
		s.__index = s
		s.__tostring = function(t)
			return t.toString(t)
		end
		function s.new(t)
			local u
			local v, w, x = t.message, t.operator, t.stackStartFn
			local y, z = t.actual, t.expected
			if v ~= nil then
				u = (setmetatable(j.new(tostring(v)), s))
			else
				if l.stderr.isTTY then
					if l.stderr:hasColors() then
						m = "\27[34m"
						n = "\27[32m"
						p = "\27[39m"
						o = "\27[31m"
					else
						m = ""
						n = ""
						p = ""
						o = ""
					end
				end
				if
					typeof(y) == "table"
					and y ~= nil
					and typeof(z) == "table"
					and z ~= nil
					and c.indexOf(d.keys(y), "stack") ~= -1
					and k(y, j)
					and c.indexOf(d.keys(z), "stack") ~= -1
					and k(z, j)
				then
					y = copyError(y)
					z = copyError(z)
				end
				if w == "deepStrictEqual" or w == "strictEqual" then
					u = (setmetatable(j.new(createErrDiff(y, z, w)), s))
				elseif w == "notDeepStrictEqual" or w == "notStrictEqual" then
					local A = q[w]
					local B = g.split(inspectValue(y), "\n")
					if w == "notStrictEqual" and (typeof(y) == "table" and y ~= nil or typeof(y) == "function") then
						A = q.notStrictEqualObject
					end
					if #B > 50 then
						B[47] = ("%s...%s").format("%s...%s", m, p)
						while #B > 47 do
							table.remove(B)
						end
					end
					if #B == 1 then
						u = (
							setmetatable(
								j.new(
									("%s%s%s").format("%s%s%s", A, if string.len(B[1]) > 5 then "\n\n" else " ", B[1])
								),
								s
							)
						)
					else
						u = (setmetatable(j.new(("%s\n\n%s\n").format("%s\n\n%s\n", A, c.join(B, "\n"))), s))
					end
				else
					local A = inspectValue(y)
					local B = inspectValue(z)
					local C = q[tostring(w)]
					if w == "notDeepEqual" and A == B then
						A = ("%s\n\n%s").format("%s\n\n%s", C, A)
						if string.len(A) > 1024 then
							A = ("%s...").format("%s...", g.slice(A, 0, 1021))
						end
						u = (setmetatable(j.new(A), s))
					else
						if string.len(A) > 512 then
							A = ("%s...").format("%s...", g.slice(A, 0, 509))
						end
						if string.len(B) > 512 then
							B = ("%s...").format("%s...", g.slice(B, 0, 509))
						end
						if w == "deepEqual" then
							A = ("%s\n\n%s\n\nshould loosely deep-equal\n\n").format(
								"%s\n\n%s\n\nshould loosely deep-equal\n\n",
								C,
								A
							)
						else
							local D = q[("%sUnequal").format("%sUnequal", tostring(w))]
							if e.toJSBoolean(D) then
								A = ("%s\n\n%s\n\nshould not loosely deep-equal\n\n").format(
									"%s\n\n%s\n\nshould not loosely deep-equal\n\n",
									D,
									A
								)
							else
								B = (" %s %s").format(" %s %s", tostring(w), B)
							end
						end
						u = (setmetatable(j.new(("%s%s").format("%s%s", A, B)), s))
					end
				end
			end
			u.generatedMessage = not e.toJSBoolean(v)
			u.name = "AssertionError [ERR_ASSERTION]"
			u.code = "ERR_ASSERTION"
			u.actual = y
			u.expected = z
			u.operator = w
			ErrorCaptureStackTrace(u, x or s.new)
			u.name = "AssertionError"
			return u
		end
		function s:toString()
			return ("%s [%s]: %s").format("%s [%s]: %s", self.name, self.code, self.message)
		end
		s.name = "AssertionError"
		return { AssertionError = s }
	end
	function a.aY()
		local b = a.load("aX")
		return b.AssertionError
	end
	function a.aZ()
		return {}
	end
	function a.a_()
		return function(b, c, d)
			local e = {}
			e.__index = e
			e.__tostring = function(g)
				return getmetatable(b).__tostring(g)
			end
			local g = {}
			e.new = function(...)
				local h = {}
				d(h, ...)
				return setmetatable(h, e)
			end
			if typeof(getmetatable(b)) == "table" and getmetatable(b).__call then
				g.__call = function(h, ...)
					return e.new(...)
				end
			end
			g.__index = b
			g.__tostring = function(h)
				if h == e then
					return tostring(c)
				end
				return getmetatable(b).__tostring(h)
			end
			setmetatable(e, g)
			return e
		end
	end
	function a.a0()
		local b = a.load("l")
		local c = a.load("ak")
		local d = a.load("ao")
		local e = a.load("ar")
		local g = a.load("as")
		local h = a.load("aJ")
		local i = a.load("aN")
		local j = a.load("aS")
		local k = a.load("aT")
		local l = a.load("aY")
		local m = a.load("aV")
		local n = a.load("aZ")
		local o = a.load("a_")
		local p = a.load("aW")
		return {
			Array = c.Array,
			AssertionError = l,
			Boolean = b,
			console = d,
			Error = m,
			extends = o,
			instanceof = p,
			Math = e,
			Number = g,
			Object = c.Object,
			Map = c.Map,
			coerceToMap = c.coerceToMap,
			coerceToTable = c.coerceToTable,
			Set = c.Set,
			WeakMap = c.WeakMap,
			String = h,
			Symbol = i,
			setTimeout = j.setTimeout,
			clearTimeout = j.clearTimeout,
			setInterval = j.setInterval,
			clearInterval = j.clearInterval,
			util = { inspect = c.inspect },
		}
	end
	function a.a1()
		return a.load("a0")
	end
	function a.a2()
		return a.load("a0")
	end
	function a.a3()
		local b = a.load("a2")
		return {}
	end
	function a.a4()
		local b = a.load("a2")
		local c = a.load("a3")
		local d = {}
		d.DiscreteEvent = 0
		d.UserBlockingEvent = 1
		d.ContinuousEvent = 2
		return d
	end
	function a.a5()
		local b = a.load("a2")
		local c = a.load("a3")
		return {}
	end
	function a.a6()
		local b = a.load("a2")
		local c = b.Error
		local function invariant(d, e, ...)
			if not d then
				error(c(string.format(e, ...)))
			end
		end
		return invariant
	end
	function a.a7()
		local b = a.load("a6")
		function shim(...)
			b(
				false,
				"The current renderer does not support hydration. This error is likely caused by a bug in React. Please file an issue."
			)
		end
		return {
			supportsHydration = false,
			canHydrateInstance = shim,
			canHydrateTextInstance = shim,
			canHydrateSuspenseInstance = shim,
			isSuspenseInstancePending = shim,
			isSuspenseInstanceFallback = shim,
			registerSuspenseInstanceRetry = shim,
			getNextHydratableSibling = shim,
			getFirstHydratableChild = shim,
			hydrateInstance = shim,
			hydrateTextInstance = shim,
			hydrateSuspenseInstance = shim,
			getNextHydratableInstanceAfterSuspenseInstance = shim,
			commitHydratedContainer = shim,
			commitHydratedSuspenseInstance = shim,
			clearSuspenseBoundary = shim,
			clearSuspenseBoundaryFromContainer = shim,
			didNotMatchHydratedContainerTextInstance = shim,
			didNotMatchHydratedTextInstance = shim,
			didNotHydrateContainerInstance = shim,
			didNotHydrateInstance = shim,
			didNotFindHydratableContainerInstance = shim,
			didNotFindHydratableContainerTextInstance = shim,
			didNotFindHydratableContainerSuspenseInstance = shim,
			didNotFindHydratableInstance = shim,
			didNotFindHydratableTextInstance = shim,
			didNotFindHydratableSuspenseInstance = shim,
		}
	end
	function a.a8()
		local b = a.load("a6")
		local function shim(...)
			b(
				false,
				"The current renderer does not support persistence. This error is likely caused by a bug in React. Please file an issue."
			)
		end
		return {
			supportsPersistence = false,
			cloneInstance = shim,
			cloneFundamentalInstance = shim,
			createContainerChildSet = shim,
			appendChildToContainerChildSet = shim,
			finalizeContainerChildren = shim,
			replaceContainerChildren = shim,
			cloneHiddenInstance = shim,
			cloneHiddenTextInstance = shim,
		}
	end
	function a.a9()
		local b = a.load("a6")
		local function shim(...)
			b(
				false,
				"The current renderer does not support test selectors. This error is likely caused by a bug in React. Please file an issue."
			)
		end
		return {
			supportsTestSelectors = false,
			findFiberRoot = shim,
			getBoundingRect = shim,
			getTextContent = shim,
			isHiddenSubtree = shim,
			matchAccessibilityRole = shim,
			setFocusIfFocusable = shim,
			setupIntersectionObserver = shim,
		}
	end
	function a.ba()
		return { WithNoHydration = a.load("a7"), WithNoPersistence = a.load("a8"), WithNoTestSelectors = a.load("a9") }
	end
	function a.bb()
		local b = a.load("a2")
		local c = a.load("a5")
		local d = a.load("a4")
		local e = { current = nil }
		return e
	end
	function a.bc()
		local b = { transition = 0 }
		return b
	end
	function a.bd()
		local b = { current = nil }
		return b
	end
	function a.be()
		local b = {}
		local c
		function b.setExtraStackFrame(d)
			if _G.__DEV__ then
				c = d
			end
		end
		if _G.__DEV__ then
			b.getCurrentStack = nil
			function b.getStackAddendum()
				local d = ""
				if c then
					d = d .. c
				end
				local e = b.getCurrentStack
				if e then
					d = d .. (e() or "")
				end
				return d
			end
		end
		return b
	end
	function a.bf()
		local b = {
			current = false,
		}
		return b
	end
	function a.bg()
		local b = a.load("a2").console
		local function onlyInTestError(c)
			return function()
				b.error(c .. " is only available in tests, not in production")
			end
		end
		local c = a.load("bb")
		local d = a.load("bc")
		local e = a.load("bd")
		local g = a.load("be")
		local h = a.load("bf")
		local i = {
			ReactCurrentDispatcher = c,
			ReactCurrentBatchConfig = d,
			ReactCurrentOwner = e,
			IsSomeRendererActing = h,
			ReactDebugCurrentFrame = if _G.__DEV__
				then g
				else {
					setExtraStackFrame = function(i)
						onlyInTestError("setExtraStackFrame")
					end,
				},
		}
		return i
	end
	function a.bh()
		local b = a.load("a2")
		local c = b.Error
		local d = b.util.inspect
		local e = "\n------ Error caught by React ------\n"
		local function describeError(g)
			if typeof(g) == "string" then
				local h, i = string.find(g, ":[%d]+: ")
				local j = if i then string.sub(g, i + 1) else g
				local k = b.Error.new(j)
				k.stack = debug.traceback(nil, 2)
				return k
			end
			return g
		end
		local function errorToString(g)
			local h
			if typeof(g) == "table" then
				if (g).message and (g).stack then
					h = e .. (g).message .. e .. tostring((g).stack)
				else
					h = d(g)
				end
			else
				h = d(g)
			end
			return h
		end
		local function parseReactError(g)
			local h = string.split(g, e)
			if #h == 3 then
				local i, j, k = table.unpack(h)
				local l = c.new(j)
				l.stack = k
				return l, i
			else
				local i = c.new(g)
				i.stack = nil
				return i, ""
			end
		end
		return {
			describeError = describeError,
			errorToString = errorToString,
			parseReactError = parseReactError,
			__ERROR_DIVIDER = e,
		}
	end
	function a.bi()
		local b = a.load("a2")
		local c = b.console
		local d = b.Array
		local e = a.load("bg")
		local g
		local h = {}
		h.warn = function(i, ...)
			if _G.__DEV__ then
				g("warn", i, { ... })
			end
		end
		h.error = function(i, ...)
			if _G.__DEV__ then
				g("error", i, { ... })
			end
		end
		function g(i, j, k)
			if _G.__DEV__ then
				local l = e.ReactDebugCurrentFrame
				local m = l.getStackAddendum()
				if m ~= "" then
					j ..= "%s"
					k = d.slice(k, 1)
					table.insert(k, m)
				end
				local n = d.map(k, tostring)
				table.insert(n, 1, "Warning: " .. j)
				c[i](unpack(n))
			end
		end
		return h
	end
	function a.bj()
		local b = a.load("a2")
		local c = b.console
		local d = a.load("bi")
		if _G.__DEV__ then
			local e = setmetatable({ warn = d.warn, error = d.error }, { __index = c })
			return e
		end
		return c
	end
	function a.bk()
		local b = {}
		b.REACT_ELEMENT_TYPE = 0xeac7
		b.REACT_PORTAL_TYPE = 0xeaca
		b.REACT_FRAGMENT_TYPE = 0xeacb
		b.REACT_STRICT_MODE_TYPE = 0xeacc
		b.REACT_PROFILER_TYPE = 0xead2
		b.REACT_PROVIDER_TYPE = 0xeacd
		b.REACT_CONTEXT_TYPE = 0xeace
		b.REACT_FORWARD_REF_TYPE = 0xead0
		b.REACT_SUSPENSE_TYPE = 0xead1
		b.REACT_SUSPENSE_LIST_TYPE = 0xead8
		b.REACT_MEMO_TYPE = 0xead3
		b.REACT_LAZY_TYPE = 0xead4
		b.REACT_BLOCK_TYPE = 0xead9
		b.REACT_SERVER_BLOCK_TYPE = 0xeada
		b.REACT_FUNDAMENTAL_TYPE = 0xead5
		b.REACT_SCOPE_TYPE = 0xead7
		b.REACT_OPAQUE_ID_TYPE = 0xeae0
		b.REACT_DEBUG_TRACING_MODE_TYPE = 0xeae1
		b.REACT_OFFSCREEN_TYPE = 0xeae2
		b.REACT_LEGACY_HIDDEN_TYPE = 0xeae3
		b.REACT_BINDING_TYPE = 0xeae4
		b.getIteratorFn = function(c)
			if typeof(c) == "table" then
				if c["$$typeof"] == b.REACT_PORTAL_TYPE then
					return nil
				end
				return function()
					local d, e
					return {
						next = function()
							d, e = next(c, d)
							return { done = e == nil, key = d, value = e }
						end,
					}
				end
			end
			return nil
		end
		return b
	end
	function a.bl()
		local b = a.load("bj")
		local c = 0
		local d
		local e
		local g
		local h
		local i
		local j
		local k
		local l = function() end
		local m = {}
		m.disabledLog = l
		m.disableLogs = function()
			if _G.__DEV__ then
				if c == 0 then
					d = b.log
					e = b.info
					g = b.warn
					h = b.error
					i = b.group
					j = b.groupCollapsed
					k = b.groupEnd
					b.info = l
					b.log = l
					b.warn = l
					b.error = l
					b.group = l
					b.groupCollapsed = l
					b.groupEnd = l
				end
				c = c + 1
			end
		end
		m.reenableLogs = function()
			if _G.__DEV__ then
				c = c - 1
				if c == 0 then
					b.log = d
					b.info = e
					b.warn = g
					b.error = h
					b.group = i
					b.groupCollapsed = j
					b.groupEnd = k
				end
				if c < 0 then
					b.error("disabledDepth fell below zero. This is a bug in React. Please file an issue.")
				end
			end
		end
		return m
	end
	function a.bm()
		local b = a.load("a5")
		local c = a.load("a3")
		local d = a.load("bk")
		local e = d.REACT_SUSPENSE_TYPE
		local g = d.REACT_SUSPENSE_LIST_TYPE
		local h = d.REACT_FORWARD_REF_TYPE
		local i = d.REACT_MEMO_TYPE
		local j = d.REACT_BLOCK_TYPE
		local k = d.REACT_LAZY_TYPE
		local l = a.load("bl")
		local m = l.disableLogs
		local n = l.reenableLogs
		local o = a.load("bg")
		local p = o.ReactCurrentDispatcher
		local q = "    in "
		local r
		local s
		local function describeOwner(t)
			if type(t) == "function" then
				return debug.info(t, "n")
			elseif type(t) == "table" then
				return tostring(t)
			end
			return nil
		end
		local function describeBuiltInComponentFrame(t, u, v)
			local w
			if _G.__DEV__ and v then
				w = describeOwner(v)
			end
			return r(t, u, w)
		end
		local t = false
		local u
		if _G.__DEV__ then
			u = setmetatable({}, { __mode = "k" })
		end
		local function describeNativeComponentFrame(v, w)
			if not v or t then
				return ""
			end
			if _G.__DEV__ then
				local x = u[v]
				if x ~= nil then
					return x
				end
			end
			local x
			t = true
			local y
			if _G.__DEV__ then
				y = p.current
				p.current = nil
				m()
			end
			local z
			local A, B = xpcall(function()
				if w then
				else
					local A, B = pcall(function()
						z = debug.traceback()
						error({ stack = z })
					end)
					x = B;
					(v)()
				end
			end, function(A)
				return { message = A, stack = z }
			end)
			local C
			if B and x and type(B.stack) == "string" then
				local D = string.split(B.stack, "\n")
				local E = string.split(x.stack, "\n")
				local F = #D - 1
				local G = #E - 1
				while F >= 2 and G >= 0 and D[F] ~= E[G] do
					G = G - 1
				end
				while F >= 3 and G >= 1 do
					F = F - 1
					G = G - 1
					if D[F] ~= E[G] then
						if F ~= 1 or G ~= 1 then
							repeat
								F = F - 1
								G = G - 1
								if G < 0 or D[F] ~= E[G] then
									local H = "\n" .. q .. D[F]
									if _G.__DEV__ then
										u[v] = H
									end
									C = H
								end
							until not (F >= 3 and G >= 1)
						end
						break
					end
				end
			end
			t = false
			if _G.__DEV__ then
				p.current = y
				n()
			end
			if C ~= nil then
				return C
			end
			local D = if type(v) == "function"
				then debug.info(v, "n")
				else if type(v) == "table" then tostring(v) else ""
			local E = ""
			if D ~= nil and D ~= "" then
				E = describeBuiltInComponentFrame(D)
			end
			if _G.__DEV__ then
				u[v] = E
			end
			return E
		end
		local v = "^(.*)[\\/]"
		function r(w, x, y)
			local z = ""
			if _G.__DEV__ and x then
				local A = x.fileName
				local B = string.gsub(A, v, "")
				if string.match(B, "^init%.") then
					local C = string.match(A, v)
					if C and #C ~= 0 then
						local D = string.gsub(C, v, "")
						B = D .. "/" .. B
					end
				end
				z = " (at " .. B .. ":" .. x.lineNumber .. ")"
			elseif y then
				z = " (created by " .. y .. ")"
			end
			return "\n    in " .. (w or "Unknown") .. z
		end
		local function describeClassComponentFrame(w, x, y)
			local z = tostring(w)
			local A
			if _G.__DEV__ and y then
				A = describeOwner(y)
			end
			return r(z, x, A)
		end
		function s(w, x, y)
			if not w then
				return ""
			end
			local z = if type(w) == "function" then debug.info(w, "n") else tostring(w)
			local A
			if _G.__DEV__ and y then
				A = describeOwner(y)
			end
			return r(z, x, A)
		end
		local function describeUnknownElementTypeFrameInDEV(w, x, y)
			if not _G.__DEV__ then
				return ""
			end
			if w == nil then
				return ""
			end
			if type(w) == "table" and type(w.__ctor) == "function" then
				return describeClassComponentFrame(w, x, y)
			end
			if type(w) == "function" then
				return s(w, x, y)
			end
			if type(w) == "string" then
				return describeBuiltInComponentFrame(w, x, y)
			end
			if w == e then
				return describeBuiltInComponentFrame("Suspense", x, y)
			elseif w == g then
				return describeBuiltInComponentFrame("SuspenseList", x, y)
			end
			if type(w) == "table" then
				local z = w["$$typeof"]
				if z == h then
					return s(w.render, x, y)
				elseif z == i then
					return describeUnknownElementTypeFrameInDEV(w.type, x, y)
				elseif z == j then
					return s(w._render, x, y)
				elseif z == k then
					local A = w
					local B = A._payload
					local C = A._init
					local D, E = pcall(function()
						describeUnknownElementTypeFrameInDEV(C(B), x, y)
					end)
					if D then
						return E
					end
				end
			end
			return ""
		end
		return {
			describeComponentFrame = r,
			describeBuiltInComponentFrame = describeBuiltInComponentFrame,
			describeNativeComponentFrame = describeNativeComponentFrame,
			describeClassComponentFrame = describeClassComponentFrame,
			describeFunctionComponentFrame = s,
			describeUnknownElementTypeFrameInDEV = describeUnknownElementTypeFrameInDEV,
		}
	end
	function a.bn()
		local b = a.load("a2")
		local c = b.Error
		local d = a.load("bj")
		local e = {}
		local g = a.load("bm")
		local h = g.describeUnknownElementTypeFrameInDEV
		local i = a.load("bg")
		local j = a.load("bh").describeError
		local k = i.ReactDebugCurrentFrame
		local function setCurrentlyValidatingElement(l)
			if _G.__DEV__ then
				if l then
					local m = l._owner
					local n = h(l.type, l._source, if m ~= nil then m.type else nil);
					(k.setExtraStackFrame)(n)
				else
					(k.setExtraStackFrame)(nil)
				end
			end
		end
		local function checkPropTypes(l, m, n, o, p, q)
			if _G.__DEV__ or _G.__DISABLE_ALL_WARNINGS_EXCEPT_PROP_VALIDATION__ then
				if l and m then
					d.warn("You've defined both propTypes and validateProps on " .. (p or "a component"))
				end
				if m then
					if typeof(m) ~= "function" then
						d.error(
							("validateProps must be a function, but it is a %s.\nCheck the definition of the component %q.").format(
								"validateProps must be a function, but it is a %s.\nCheck the definition of the component %q.",
								typeof(m),
								p or ""
							)
						)
					else
						local r, s = m(n)
						if not r then
							s = s or "<Validator function did not supply a message>"
							local t = string.format(
								"validateProps failed on a %s type in %s: %s",
								o,
								p or "<UNKNOWN Component>",
								tostring(s)
							)
							error(t)
						end
					end
				end
				if l then
					assert(typeof(l) == "table", "propTypes needs to be a table")
					for r, s in l do
						local t, u = xpcall(function()
							if typeof(l[r]) ~= "function" then
								local t = c.new(
									(p or "React class")
										.. ": "
										.. o
										.. " type `"
										.. r
										.. "` is invalid; "
										.. "it must be a function, usually from the `prop-types` package, but received `"
										.. typeof(l[r])
										.. "`.This often happens because of typos such as `PropTypes.function` instead of `PropTypes.func`."
								)
								t.name = "Invariant Violation"
								error(t)
							end
							return (l[r])(n, r, p, o, nil, "SECRET_DO_NOT_PASS_THIS_OR_YOU_WILL_BE_FIRED")
						end, j)
						local v = typeof(u) == "table"
						if u ~= nil and not v then
							setCurrentlyValidatingElement(q)
							d.error(
								string.format(
									"%s: type specification of %s `%s` is invalid; the type checker function must return `nil` or an `Error` but returned a %s. You may have forgotten to pass an argument to the type checker creator (arrayOf, instanceOf, objectOf, oneOf, oneOfType, and shape all require an argument).",
									p or "React class",
									o,
									r,
									typeof(u)
								)
							)
							setCurrentlyValidatingElement(nil)
						end
						if v and e[(u).message] == nil then
							e[tostring((u).message)] = true
							setCurrentlyValidatingElement(q)
							d.warn(string.format("Failed %s type: %s", o, tostring((u).message)))
							setCurrentlyValidatingElement(nil)
						end
					end
				end
			end
		end
		return checkPropTypes
	end
	function a.bo()
		local b = a.load("a2")
		local c = b.setTimeout
		return function(d)
			return c(d, 0)
		end
	end
	function a.bp()
		local b = {}
		b.canUseDOM = function()
			return false
		end
		return b
	end
	function a.bq()
		local b = cloneref(game.GetService(game, "HttpService"))
		local function formatProdErrorMessage(c, ...)
			local d = "https://reactjs.org/docs/error-decoder.html?invariant=" .. tostring(c)
			local e = select("#", ...)
			for g = 1, e, 1 do
				d = d .. "&args[]=" .. b.UrlEncode(b, select(g, ...))
			end
			return string.format(
				"Minified React error #%d; visit %s for the full message or use the non-minified dev environment for full errors and additional helpful warnings.",
				c,
				d
			)
		end
		return formatProdErrorMessage
	end
	function a.br()
		local b = a.load("bj")
		local c = a.load("bk")
		local d = c.REACT_CONTEXT_TYPE
		local e = c.REACT_FORWARD_REF_TYPE
		local g = c.REACT_FRAGMENT_TYPE
		local h = c.REACT_PORTAL_TYPE
		local i = c.REACT_MEMO_TYPE
		local j = c.REACT_PROFILER_TYPE
		local k = c.REACT_PROVIDER_TYPE
		local l = c.REACT_STRICT_MODE_TYPE
		local m = c.REACT_SUSPENSE_TYPE
		local n = c.REACT_SUSPENSE_LIST_TYPE
		local o = c.REACT_LAZY_TYPE
		local p = c.REACT_BLOCK_TYPE
		local q = a.load("a4")
		local r = a.load("bh").describeError
		local function getWrappedName(s, t, u)
			local v = "<function>"
			if typeof(t) == "table" then
				v = t.displayName or t.name or ""
			end
			return s.displayName or (v ~= "" and string.format("%s(%s)", u, v) or u)
		end
		local function getContextName(s)
			return s.displayName or "Context"
		end
		local function getComponentName(s)
			if s == nil then
				return nil
			end
			local t = typeof(s)
			if _G.__DEV__ then
				if t == "table" and typeof(s.tag) == "number" then
					b.warn("Received an unexpected object in getComponentName(). This is likely a bug in React. Please file an issue.")
				end
			end
			if t == "function" then
				local u = debug.info(s, "n")
				if u and string.len(u) > 0 then
					return u
				else
					return nil
				end
			end
			if t == "string" then
				return s
			end
			if s == g then
				return "Fragment"
			elseif s == h then
				return "Portal"
			elseif s == j then
				return "Profiler"
			elseif s == l then
				return "StrictMode"
			elseif s == m then
				return "Suspense"
			elseif s == n then
				return "SuspenseList"
			end
			if t == "table" then
				local u = s["$$typeof"]
				if u == d then
					local v = s
					return getContextName(v) .. ".Consumer"
				elseif u == k then
					local v = s
					return getContextName(v._context) .. ".Provider"
				elseif u == e then
					return getWrappedName(s, s.render, "ForwardRef")
				elseif u == i then
					return getComponentName(s.type)
				elseif u == p then
					return getComponentName(s._render)
				elseif u == o then
					local v = s
					local w = v._payload
					local x = v._init
					local y, z = xpcall(x, r, w)
					if y then
						return getComponentName(z)
					else
						return nil
					end
				else
					if s.displayName then
						return s.displayName
					end
					if s.name then
						return s.name
					end
					local v = getmetatable(s)
					if v and rawget(v, "__tostring") then
						return tostring(s)
					end
				end
			end
			return nil
		end
		return getComponentName
	end
	function a.bs()
		local b = a.load("bh").describeError
		local function invokeGuardedCallbackProd(c, d, e, g, ...)
			local h, i
			if not _G.__YOLO__ then
				if g == nil then
					h, i = xpcall(e, b, ...)
				else
					h, i = xpcall(e, b, g, ...)
				end
			else
				h = true
				if g == nil then
					e(...)
				else
					e(g, ...)
				end
			end
			if not h then
				c.onError(i)
			end
		end
		local c = invokeGuardedCallbackProd
		if _G.__DEV__ then
		end
		return c
	end
	function a.bt()
		local b = a.load("bk")
		local c = b.REACT_CONTEXT_TYPE
		local d = b.REACT_FORWARD_REF_TYPE
		local e = b.REACT_FRAGMENT_TYPE
		local g = b.REACT_PROFILER_TYPE
		local h = b.REACT_PROVIDER_TYPE
		local i = b.REACT_DEBUG_TRACING_MODE_TYPE
		local j = b.REACT_STRICT_MODE_TYPE
		local k = b.REACT_SUSPENSE_TYPE
		local l = b.REACT_MEMO_TYPE
		local m = b.REACT_LAZY_TYPE
		local n = b.REACT_FUNDAMENTAL_TYPE
		local o = b.REACT_BLOCK_TYPE
		local p = b.REACT_SERVER_BLOCK_TYPE
		local q = b.REACT_LEGACY_HIDDEN_TYPE
		return function(r)
			local s = typeof(r)
			if s == "string" or s == "function" then
				return true
			end
			if r == e or r == g or r == i or r == j or r == k or r == q then
				return true
			end
			if s == "table" then
				if r.isReactComponent then
					return true
				end
				if
					r["$$typeof"] == m
					or r["$$typeof"] == l
					or r["$$typeof"] == h
					or r["$$typeof"] == c
					or r["$$typeof"] == d
					or r["$$typeof"] == n
					or r["$$typeof"] == o
					or r[1] == p
				then
					return true
				end
			end
			return false
		end
	end
	function a.bu()
		local function is(b, c)
			return b == c and (b ~= 0 or 1 / b == 1 / c) or b ~= b and c ~= c
		end
		local b = is
		return b
	end
	function a.bv()
		local b = a.load("a6")
		local c = a.load("bs")
		local d
		local e = false
		local g
		local h = false
		local i
		local j = {
			onError = function(j)
				e = true
				g = j
			end,
		}
		local k = {}
		k.invokeGuardedCallback = function(...)
			e = false
			g = nil
			c(j, ...)
		end
		k.invokeGuardedCallbackAndCatchFirstError = function(...)
			k.invokeGuardedCallback(...)
			if e then
				local l = d()
				if not h then
					h = true
					i = l
				end
			end
		end
		k.rethrowCaughtError = function()
			if h then
				local l = i
				h = false
				i = nil
				error(l)
			end
		end
		k.hasCaughtError = function()
			return e
		end
		d = function()
			if e then
				local l = g
				e = false
				g = nil
				return l
			else
				b(
					false,
					"clearCaughtError was called but no error was captured. This error is likely caused by a bug in React. Please file an issue."
				)
				return nil
			end
		end
		k.clearCaughtError = d
		return k
	end
	function a.bw()
		local b = {}
		b.enableFilterEmptyStringAttributesDOM = true
		b.enableDebugTracing = false
		b.enableSchedulingProfiler = _G.__PROFILE__ and _G.__EXPERIMENTAL__
		b.debugRenderPhaseSideEffectsForStrictMode = _G.__DEV__
		b.replayFailedUnitOfWorkWithInvokeGuardedCallback = _G.__DEV__
		b.warnAboutDeprecatedLifecycles = true
		b.enableProfilerTimer = _G.__PROFILE__
		b.enableProfilerCommitHooks = false
		b.enableSchedulerTracing = _G.__PROFILE__
		b.enableSuspenseServerRenderer = _G.__EXPERIMENTAL__
		b.enableSelectiveHydration = _G.__EXPERIMENTAL__
		b.enableBlocksAPI = _G.__EXPERIMENTAL__
		b.enableLazyElements = _G.__EXPERIMENTAL__
		b.enableSchedulerDebugging = false
		b.disableJavaScriptURLs = false
		b.enableFundamentalAPI = false
		b.enableScopeAPI = false
		b.enableCreateEventHandleAPI = false
		b.warnAboutUnmockedScheduler = false
		b.enableSuspenseCallback = false
		b.warnAboutDefaultPropsOnFunctionComponents = false
		b.disableSchedulerTimeoutBasedOnReactExpirationTime = false
		b.enableTrustedTypesIntegration = false
		b.warnAboutSpreadingKeyToJSX = true
		b.enableComponentStackLocations = true
		b.enableNewReconciler = true
		b.skipUnmountedBoundaries = true
		b.disableInputAttributeSyncing = true
		b.warnAboutStringRefs = false
		b.disableLegacyContext = false
		b.disableTextareaChildren = false
		b.disableModulePatternComponents = false
		b.warnUnstableRenderSubtreeIntoContainer = false
		b.enableLegacyFBSupport = true
		b.deferRenderPhaseUpdateToNextBatch = false
		b.decoupleUpdatePriorityFromScheduler = true
		b.enableDiscreteEventFlushingChange = false
		b.enableEagerRootListeners = false
		b.enableDoubleInvokingEffects = false
		return b
	end
	function a.bx()
		local b = a.load("a2")
		local c = b.Error
		local d = b.util.inspect
		local e = a.load("br")
		local g = {}
		local function isValidFiber(h)
			return h.tag ~= nil and h.subtreeFlags ~= nil and h.lanes ~= nil and h.childLanes ~= nil
		end
		g.remove = function(h)
			h._reactInternals = nil
		end
		g.get = function(h)
			local i = h._reactInternals
			if not isValidFiber(i) then
				error(
					c.new(
						"invalid fiber in "
							.. (e(h) or "UNNAMED Component")
							.. " during get from ReactInstanceMap! "
							.. d(i)
					)
				)
			elseif i.alternate ~= nil and not isValidFiber(i.alternate) then
				error(
					c.new(
						"invalid alternate fiber ("
							.. (e(h) or "UNNAMED alternate")
							.. ") in "
							.. (e(h) or "UNNAMED Component")
							.. " during get from ReactInstanceMap! "
							.. d(i.alternate)
					)
				)
			end
			return i
		end
		g.has = function(h)
			return h._reactInternals ~= nil
		end
		g.set = function(h, i)
			local j = i
			local k
			while j ~= nil do
				if not isValidFiber(j) then
					k = "invalid fiber in "
						.. (e(h) or "UNNAMED Component")
						.. " being set in ReactInstanceMap! "
						.. d(j)
						.. "\n"
					if i ~= j then
						k ..= " (from original fiber " .. (e(h) or "UNNAMED Component") .. ")"
					end
					error(c.new(k))
				elseif (j).alternate ~= nil and not isValidFiber((j).alternate) then
					k = "invalid alternate fiber ("
						.. (e(h) or "UNNAMED alternate")
						.. ") in "
						.. (e(h) or "UNNAMED Component")
						.. " being set in ReactInstanceMap! "
						.. d((j).alternate)
						.. "\n"
					if i ~= j then
						k ..= " (from original fiber " .. (e(h) or "UNNAMED Component") .. ")"
					end
					error(c.new(k))
				end
				j = (j).return_
			end
			(h)._reactInternals = i
		end
		return g
	end
	function a.by()
		return "17.2.1"
	end
	function a.bz()
		local b = a.load("bu")
		local function shallowEqual(c, d)
			if b(c, d) then
				return true
			end
			if typeof(c) ~= "table" or c == nil or typeof(d) ~= "table" or d == nil then
				return false
			end
			for e, g in c do
				if not b(d[e], g) then
					return false
				end
			end
			for e, g in d do
				if not b(c[e], g) then
					return false
				end
			end
			return true
		end
		return shallowEqual
	end
	function a.bA()
		local b = a.load("bj")
		local c = {}
		setmetatable(c, {
			__index = function(d, e)
				if _G.__DEV__ then
					b.warn("Attempted to access uninitialized state. Use setState to initialize state")
				end
				return nil
			end,
			__newindex = function(d, e)
				if _G.__DEV__ then
					b.error("Attempted to directly mutate state. Use setState to assign new values to state.")
				end
				return nil
			end,
			__tostring = function(d)
				return "<uninitialized component state>"
			end,
			__metatable = "UninitializedState",
		})
		return c
	end
	function a.bB()
		local b = {}
		function b.named(c)
			assert(type(c) == "string", "Symbols must be created using a string name!")
			local d = newproxy(true)
			local e = string.format("Symbol(%s)", c)
			getmetatable(d).__tostring = function()
				return e
			end
			return d
		end
		return b
	end
	function a.bC()
		local b = a.load("bB")
		local c = newproxy(true)
		local d = {}
		local function addType(e)
			d[e] = b.named("Roact" .. e)
		end
		addType("HostChangeEvent")
		addType("HostEvent")
		function d.of(e)
			if typeof(e) ~= "table" then
				return nil
			end
			return e[c]
		end
		getmetatable(c).__index = d
		getmetatable(c).__tostring = function()
			return "RoactType"
		end
		return c
	end
	function a.bD()
		local b = a.load("bC")
		local c = {}
		local d = {
			__tostring = function(d)
				return string.format("RoactHostChangeEvent(%s)", d.name)
			end,
		}
		setmetatable(c, {
			__index = function(e, g)
				local h = { [b] = b.HostChangeEvent, name = g }
				setmetatable(h, d)
				c[g] = h
				return h
			end,
		})
		return c
	end
	function a.bE()
		local b = a.load("bC")
		local c = {}
		local d = {
			__tostring = function(d)
				return string.format("RoactHostEvent(%s)", d.name)
			end,
		}
		setmetatable(c, {
			__index = function(e, g)
				local h = { [b] = b.HostEvent, name = g }
				setmetatable(h, d)
				c[g] = h
				return h
			end,
		})
		return c
	end
	function a.bF()
		local b = a.load("bB")
		local c = b.named("RobloxTag")
		return c
	end
	function a.bG()
		local b = a.load("a2")
		local c = a.load("a4")
		local d = a.load("a3")
		local e = a.load("a5")
		local g = a.load("ba")
		local h = a.load("bg")
		local i = a.load("bh")
		return {
			checkPropTypes = a.load("bn"),
			console = a.load("bj"),
			ConsolePatchingDev = a.load("bl"),
			consoleWithStackDev = a.load("bi"),
			enqueueTask = a.load("bo"),
			ExecutionEnvironment = a.load("bp"),
			formatProdErrorMessage = a.load("bq"),
			getComponentName = a.load("br"),
			invariant = a.load("a6"),
			invokeGuardedCallbackImpl = a.load("bs"),
			isValidElementType = a.load("bt"),
			objectIs = a.load("bu"),
			ReactComponentStackFrame = a.load("bm"),
			ReactElementType = a.load("a5"),
			ReactErrorUtils = a.load("bv"),
			ReactFeatureFlags = a.load("bw"),
			ReactInstanceMap = a.load("bx"),
			ReactSharedInternals = h,
			ReactFiberHostConfig = g,
			ReactSymbols = a.load("bk"),
			ReactVersion = a.load("by"),
			shallowEqual = a.load("bz"),
			UninitializedState = a.load("bA"),
			ReactTypes = c,
			describeError = i.describeError,
			errorToString = i.errorToString,
			parseReactError = i.parseReactError,
			Symbol = a.load("bB"),
			Type = a.load("bC"),
			Change = a.load("bD"),
			Event = a.load("bE"),
			Tag = a.load("bF"),
		}
	end
	function a.bH()
		return a.load("bG")
	end
	function a.bI()
		local b = a.load("bH")
		local function createMutableSource(c, d)
			local e =
				{ _getVersion = d, _source = c, _workInProgressVersionPrimary = nil, _workInProgressVersionSecondary = nil }
			if _G.__DEV__ then
				e._currentPrimaryRenderer = nil
				e._currentSecondaryRenderer = nil
			end
			return e
		end
		return createMutableSource
	end
	function a.bJ()
		local b = a.load("bH").console
		local c = {}
		local function warnNoop(d, e)
			if _G.__DEV__ then
				local g = d.__componentName or "ReactClass"
				local h = g .. "." .. e
				if c[h] then
					return
				end
				b.error(
					"Can't call %s on a component that is not yet mounted. This is a no-op, but it might indicate a bug in your application. Instead, assign to `self.state` directly with the desired state in the %s component's `init` method.",
					e,
					g
				)
				c[h] = true
			end
		end
		local d = {
			isMounted = function(d)
				return false
			end,
			enqueueForceUpdate = function(d, e, g)
				warnNoop(d, "forceUpdate")
			end,
			enqueueReplaceState = function(d, e, g, h)
				warnNoop(d, "replaceState")
			end,
			enqueueSetState = function(d, e, g, h)
				warnNoop(d, "setState")
			end,
		}
		return d
	end
	function a.bK()
		local b = _G.__DEV__
		local c = _G.__COMPAT_WARNINGS__
		local d = a.load("a1")
		local e = d.Object
		local g = a.load("bH").console
		local h = a.load("bH")
		local i = a.load("bJ")
		local j = {}
		if b then
			e.freeze(j)
		end
		local k = a.load("bH").UninitializedState
		local l = { isReactComponent = true }
		local function trimPath(m)
			local n = string.match(m, "%.%u[%.%w]-$")
			if n then
				return string.gsub(n, "^%.", "")
			end
			return m
		end
		local function warnAboutExistingLifecycle(m, n, o)
			g.warn(
				"%s already defined '%s', but it also defining the deprecated Roact method '%s'. %s should only implement one of these methods, preferably using the non-deprecated name.",
				m,
				o,
				n,
				m
			)
		end
		local function warnAboutDeprecatedLifecycleName(m, n, o)
			if b and c then
				local p, q = debug.info(3, "sln")
				g.warn(
					"%s is using method '%s', which is no longer supported and should be updated to '%s'\nFile: %s:%s",
					m,
					n,
					o,
					trimPath(p),
					tostring(q)
				)
			end
		end
		local m = {
			didMount = "componentDidMount",
			shouldUpdate = "shouldComponentUpdate",
			willUpdate = "UNSAFE_componentWillUpdate",
			didUpdate = "componentDidUpdate",
			willUnmount = "componentWillUnmount",
		}
		local function handleNewLifecycle(n, o, p)
			if m[o] ~= nil then
				if n[m[o]] ~= nil then
					warnAboutExistingLifecycle(n.__componentName, o, m[o])
				elseif o == "willUpdate" and n["componentWillUpdate"] then
					warnAboutExistingLifecycle(n.__componentName, o, "UNSAFE_componentWillUpdate")
				else
					warnAboutDeprecatedLifecycleName(n.__componentName, o, m[o])
				end
				o = m[o]
			end
			rawset(n, o, p)
		end
		local n = {
			__newindex = handleNewLifecycle,
			__index = l,
			__tostring = function(n)
				return n.__componentName
			end,
		}
		local o = (setmetatable({ __componentName = "Component" }, n))
		local p = if not _G.__TESTEZ_RUNNING_TEST__ then 900 else 0
		local q = 1
		local r = table.create(p)
		for s = 1, p do
			table.insert(r, { props = nil, context = nil, state = k, __refs = j, __updater = i })
		end
		local function setStateInInit(s, t, u)
			if b and u ~= nil then
				g.warn(
					'Received a `callback` argument to `setState` during initialization of "%s". The callback behavior is not supported when using `setState` in `init`.\n\nConsider defining similar behavior in a `compontentDidMount` method instead.',
					s.__componentName
				)
			end
			local v = t and type(t)
			if t == nil or (v ~= "table" and v ~= "function") then
				error("setState(...): takes an object of state variables to update or a function which returns an object of state variables.")
			end
			local w = s.state
			local x
			if v == "function" then
				x = t(w, s.props)
			else
				x = t
			end
			s.state = e.assign({}, w, x)
		end
		function o:extend(s)
			if s == nil then
				if c then
					g.warn("Component:extend() accepting no arguments is deprecated, and will not be supported in a future version of Roact. Please provide an explicit name.")
				end
				s = ""
			elseif type(s) ~= "string" then
				error("Component class name must be a string")
			end
			local t = { __componentName = s, setState = self.setState, forceUpdate = self.forceUpdate, init = nil }
			t.__index = t
			function t.__ctor(u, v, w)
				local x
				if q <= p then
					x = r[q]
					x.props = u
					x.context = v
					r[q] = nil
					q += 1
				else
					x = { props = u, context = v, state = k, __refs = j, __updater = w or i }
				end
				x = setmetatable(x, t)
				if t.init and type(t.init) == "function" then
					x.setState = setStateInInit
					t.init(x, u, v)
					x.setState = nil
				end
				return x
			end
			setmetatable(t, getmetatable(self))
			return t
		end
		function o:setState(s, t)
			if s ~= nil and type(s) ~= "table" and type(s) ~= "function" then
				error("setState(...): takes an object of state variables to update or a function which returns an object of state variables.")
			end
			self.__updater.enqueueSetState(self, s, t, "setState")
		end
		function o:forceUpdate(s)
			self.__updater.enqueueForceUpdate(self, s, "forceUpdate")
		end
		if b then
			local s = {
				isMounted = {
					"isMounted",
					"Instead, make sure to clean up subscriptions and pending requests in componentWillUnmount to prevent memory leaks.",
				},
				replaceState = {
					"replaceState",
					"Refactor your code to use setState instead (see https://github.com/facebook/react/issues/3236).",
				},
			}
			local t = function(t, u)
				(o)[t] = function()
					g.warn("%s(...) is deprecated in plain JavaScript React classes. %s", u[1], u[2])
					return nil
				end
			end
			for u, v in s do
				if s[u] ~= nil then
					t(u, s[u])
				end
			end
		end
		local s = (o.extend(o, "PureComponent"));
		(s).extend = o.extend
		local t = { isReactComponent = true, isPureReactComponent = true }
		setmetatable(s, {
			__newindex = handleNewLifecycle,
			__index = t,
			__tostring = function(u)
				return u.__componentName
			end,
		})
		return { Component = o, PureComponent = s }
	end
	function a.bL()
		local b = a.load("bH")
		local c = b.console
		local d = a.load("a1")
		local e = d.util.inspect
		local g = a.load("bH")
		local h = a.load("bH").ReactSymbols
		local i = h.REACT_LAZY_TYPE
		local j = -1
		local k = 0
		local l = 1
		local m = 2
		function lazyInitializer(n)
			if n._status == j then
				local o = n._result
				local p = o()
				local q = n
				q._status = k
				q._result = p
				p.andThen(p, function(r)
					if n._status == k then
						local s = r.default
						if _G.__DEV__ then
							if s == nil then
								c.error(
									"lazy: Expected the result of a dynamic import() call. Instead received: `%s`\n\nYour code should look like: \n  local MyComponent = lazy(function() return reqquire(script.Parent.MyComponent) end)",
									e(r)
								)
							end
						end
						local t = n
						t._status = l
						t._result = s
					end
				end, function(r)
					if n._status == k then
						local s = n
						s._status = m
						s._result = r
					end
				end)
			end
			if n._status == l then
				return n._result
			else
				error(n._result)
			end
		end
		local n = {}
		n.lazy = function(o)
			local p = { _status = -1, _result = o }
			local q = { ["$$typeof"] = i, _payload = p, _init = lazyInitializer }
			if _G.__DEV__ then
				local r
				local s
				setmetatable(q, {
					__index = function(t, u)
						if u == "defaultProps" then
							return r
						end
						if u == "propTypes" then
							return s
						end
						return
					end,
					__newindex = function(t, u, v)
						if u == "defaultProps" then
							c.error("React.lazy(...): It is not supported to assign `defaultProps` to a lazy component import. Either specify them where the component is defined, or create a wrapping component around it.")
							r = v
							setmetatable(t, { __index = function() end, __newindex = function() end })
						end
						if u == "propTypes" then
							c.error("React.lazy(...): It is not supported to assign `propTypes` to a lazy component import. Either specify them where the component is defined, or create a wrapping component around it.")
							s = v
							setmetatable(t, { __index = function() end, __newindex = function() end })
						end
					end,
				})
			end
			return q
		end
		return n
	end
	function a.bM()
		local b = _G.__DEV__
		local c = a.load("a1")
		local d = c.Error
		local e = a.load("bH").console
		local g = a.load("bH")
		local h = a.load("bL")
		local i = a.load("bH").getComponentName
		local j = a.load("bH").ReactSymbols.REACT_ELEMENT_TYPE
		local k = a.load("bH").ReactSharedInternals.ReactCurrentOwner
		local l = { key = true, ref = true, __self = true, __source = true }
		local m, n, o
		if b then
			o = {}
		end
		local p = {}
		local function hasValidRef(q)
			if b then
				if q.ref ~= nil and type(q.ref) == "table" then
					if (q.ref).isReactWarning then
						return false
					end
				end
			end
			return q.ref ~= nil
		end
		local function hasValidKey(q)
			if b then
				if q.key ~= nil and type(q.key) == "table" then
					if (q.key).isReactWarning then
						return false
					end
				end
			end
			return q.key ~= nil
		end
		local q = { isReactWarning = true }
		local function defineKeyPropWarningGetter(r, s)
			local t = function()
				if b then
					if not m then
						m = true
						e.error(
							"%s: `key` is not a prop. Trying to access it will result in `nil` being returned. If you need to access the same value within the child component, you should pass it as a different prop. (https://reactjs.org/link/special-props)",
							s
						)
					end
				end
			end
			r.key = nil
			setmetatable(r, {
				__index = function(u, v)
					if v == "key" then
						t()
						return q
					end
					return nil
				end,
			})
		end
		local function defineRefPropWarningGetter(r, s)
			local t = function()
				if b then
					if not n then
						n = true
						e.error(
							"%s: `ref` is not a prop. Trying to access it will result in `nil` being returned. If you need to access the same value within the child component, you should pass it as a different prop. (https://reactjs.org/link/special-props)",
							s
						)
					end
				end
			end
			r.ref = nil
			setmetatable(r, {
				__index = function(u, v)
					if v == "ref" then
						t()
						return q
					end
					return nil
				end,
			})
		end
		local function warnIfStringRefCannotBeAutoConverted(r)
			if b then
				if type(r.ref) == "string" and k.current then
					local s = i(k.current.type)
					if not o[s] then
						error(
							string.format(
								'Component "%s" contains the string ref "%s". Support for string refs has been removed. We recommend using useRef() or createRef() instead. Learn more about using refs safely here: https://reactjs.org/link/strict-mode-string-ref',
								s or "Unknown",
								r.ref
							)
						)
					end
				end
			end
		end
		local function ReactElement(r, s, t, u, v, w, x)
			local y = { type = r, key = s, ref = t, props = x, _owner = w }
			y["$$typeof"] = j
			if b then
				local z = {
					validated = false,
				}
				y._store = setmetatable({}, {
					__index = z,
					__newindex = function(A, B, C)
						if B == "validated" then
							z.validated = C
						else
							rawset(A, B, C)
						end
					end,
				})
				setmetatable(y, {
					__index = { _self = u, _source = v },
				})
			end
			return y
		end
		p.jsx = function(r, s, t)
			error("JSX is currently unsupported")
		end
		p.jsxDEV = function(r, s, t, u, v)
			error("JSX is currently unsupported")
			return nil
		end
		local function createElement(r, s, ...)
			local t = if s ~= nil then (table.clone(s)) else {}
			local u
			local v
			local w
			local x
			if s ~= nil then
				if hasValidRef(s) then
					v = (s).ref
					if b then
						warnIfStringRefCannotBeAutoConverted(s)
					end
				end
				if hasValidKey(s) then
					local y = (s).key
					if type(y) == "number" then
						u = y
					else
						u = tostring(y)
					end
				end
				x = if (s).__source == nil then nil else (s).__source
				if t.key ~= nil then
					t.key = nil
				end
				if t.ref ~= nil then
					t.ref = nil
				end
				if t.__self ~= nil then
					t.__self = nil
				end
				if t.__source ~= nil then
					t.__source = nil
				end
			end
			local y = select("#", ...)
			if y == 1 then
				t.children = select(1, ...)
			elseif y > 1 then
				local z = table.create(y)
				for A = 1, y do
					local B = select(A, ...)
					table.insert(z, B)
				end
				if b then
					table.freeze(z)
				end
				t.children = z
			end
			if type(r) == "table" and (r).defaultProps then
				local z = (r).defaultProps
				for A, B in z do
					if t[A] == nil then
						t[A] = (z)[A]
					end
				end
			end
			if b then
				if u or v then
					local z
					if type(r) == "function" then
						z = debug.info(r, "n") or "<function>"
					elseif type(r) == "table" then
						z = ((r).displayName or (r).name) or "Unknown"
					else
						z = r
					end
					if u then
						defineKeyPropWarningGetter(t, z)
					end
					if v then
						defineRefPropWarningGetter(t, z)
					end
				end
				if x == nil then
					x = { fileName = debug.info(3, "s"), lineNumber = debug.info(3, "l") }
				end
			end
			return (ReactElement(r, u, v, w, x, k.current, t))
		end
		p.createElement = createElement
		p.cloneAndReplaceKey = function(r, s)
			local t = ReactElement(r.type, s, r.ref, r._self, r._source, r._owner, r.props)
			return t
		end
		p.cloneElement = function(r, s, ...)
			if r == nil then
				error(
					d.new(
						"React.cloneElement(...): The argument must be a React element, but you passed " .. tostring(r)
					)
				)
			end
			local t = r.props
			local u = if t ~= nil then (table.clone(t)) else {}
			local v = r.key
			local w = r.ref
			local x = r._source
			local y = r._owner
			if s ~= nil then
				local z = s.ref
				if z ~= nil then
					w = z
					y = k.current
				else
					hasValidRef(s)
				end
				local A = s.key
				if A ~= nil then
					if type(A) == "number" then
						v = A
					else
						v = A or "nil"
					end
				else
					hasValidKey(s)
				end
			end
			local z = r.type
			local A = if type(z) == "table" then z.defaultProps else nil
			if s ~= nil then
				for B, C in s do
					if (s)[B] ~= nil and not l[B] then
						if (s)[B] == nil and A ~= nil then
							(u)[B] = (A)[B]
						else
							(u)[B] = (s)[B]
						end
					end
				end
			end
			local B = select("#", ...)
			if B == 1 then
				u.children = select(1, ...)
			elseif B > 1 then
				(u).children = { ... }
			end
			return (ReactElement(r.type, v, w, nil, x, y, u))
		end
		p.isValidElement = function(r)
			return type(r) == "table" and r["$$typeof"] == j
		end
		return p
	end
	function a.bN()
		local b = a.load("bH")
		local c = a.load("bH").invariant
		local d = a.load("bH").ReactSymbols
		local e = d.getIteratorFn
		local g = d.REACT_ELEMENT_TYPE
		local h = d.REACT_PORTAL_TYPE
		local i = a.load("a1")
		local j = i.Array
		local k = a.load("bM")
		local l = k.isValidElement
		local m = k.cloneAndReplaceKey
		local n = "."
		local o = ":"
		local function escape(p)
			local q = string.gsub(p, "=", "=0")
			q = string.gsub(q, ":", "=2")
			return "$" .. q
		end
		local function escapeUserProvidedKey(p)
			return p
		end
		local function getElementKey(p, q)
			if typeof(p) == "table" and p ~= nil and p.key ~= nil then
				return escape(tostring(p.key))
			end
			return tostring(q)
		end
		local function mapIntoArray(p, q, r, s, t)
			local u = typeof(p)
			if u == "nil" or u == "boolean" or u == "userdata" then
				p = nil
			end
			local v = false
			if p == nil then
				v = true
			else
				if u == "string" or u == "number" then
					v = true
				elseif u == "table" then
					local w = (p)["$$typeof"]
					if w == g or w == h then
						v = true
					end
				end
			end
			if v then
				local w = p
				local x = t(w)
				local y = if s == "" then n .. getElementKey(w, 1) else s
				if j.isArray(x) then
					local z = ""
					if y ~= nil then
						z = escapeUserProvidedKey(y) .. "/"
					end
					mapIntoArray(x, q, z, "", function(A)
						return A
					end)
				elseif x ~= nil then
					if l(x) then
						local z = (x).key
						x = m(
							x,
							r
								.. (if z and (not w or (w).key ~= z)
									then escapeUserProvidedKey(tostring(z)) .. "/"
									else "")
								.. y
						)
					end
					table.insert(q, x)
				end
				return 1
			end
			local w
			local x
			local y = 0
			local z = if s == "" then n else s .. o
			if j.isArray(p) then
				for A = 1, #p do
					w = (p)[A]
					x = z .. getElementKey(w, A)
					y += mapIntoArray(w, q, r, x, t)
				end
			else
				local A = e(p)
				if typeof(A) == "function" then
					local B = p
					local C = A(B)
					local D
					local E = 1
					D = C.next()
					while not D.done do
						w = D.value
						x = z .. getElementKey(w, E)
						E += 1
						y += mapIntoArray(w, q, r, x, t)
						D = C.next()
					end
				end
			end
			return y
		end
		local function mapChildren(p, q, r)
			if p == nil then
				return nil
			end
			local s = {}
			local t = 1
			mapIntoArray(p, s, "", "", function(u)
				local v = q(u, t)
				t += 1
				return v
			end)
			return s
		end
		local function countChildren(p)
			local q = 0
			mapChildren(p, function()
				q += 1
				return
			end)
			return q
		end
		local function forEachChildren(p, q, r)
			mapChildren(p, function(...)
				q(...)
				return
			end, r)
		end
		local function toArray(p)
			return mapChildren(p, function(q)
				return q
			end) or {}
		end
		local function onlyChild(p)
			c(l(p), "React.Children.only expected to receive a single React element child.")
			return p
		end
		return { forEach = forEachChildren, map = mapChildren, count = countChildren, only = onlyChild, toArray = toArray }
	end
	function a.bO()
		local b = a.load("a1")
		local c = b.Array
		local d = b.Boolean
		local e = b.Object
		local g = a.load("bH").console
		local h = b.util.inspect
		local i = a.load("bH")
		local j = a.load("bH").isValidElementType
		local k = a.load("bH").getComponentName
		local l = a.load("bH").ReactSymbols
		local m = l.getIteratorFn
		local n = l.REACT_FORWARD_REF_TYPE
		local o = l.REACT_MEMO_TYPE
		local p = l.REACT_FRAGMENT_TYPE
		local q = l.REACT_ELEMENT_TYPE
		local r = a.load("bH").ReactFeatureFlags.warnAboutSpreadingKeyToJSX
		local s = a.load("bH").checkPropTypes
		local t = a.load("bH").ReactSharedInternals.ReactCurrentOwner
		local u = a.load("bM")
		local v = u.isValidElement
		local w = u.createElement
		local x = u.cloneElement
		local y = u.jsxDEV
		local z = a.load("bH").ReactSharedInternals.ReactDebugCurrentFrame.setExtraStackFrame
		local A = a.load("bH").ReactComponentStackFrame.describeUnknownElementTypeFrameInDEV
		local B = {}
		local function setCurrentlyValidatingElement(C)
			if _G.__DEV__ then
				if C then
					local D = C._owner
					local E
					if D then
						E = D.type
					end
					local F = A(C.type, C._source, E);
					(z)(F)
				else
					(z)(nil)
				end
			end
		end
		local C
		if _G.__DEV__ then
			C = false
		end
		local function hasOwnProperty(D, E)
			return D[E] ~= nil
		end
		local function getDeclarationErrorAddendum()
			if t.current then
				local D = k(t.current.type)
				if D then
					return "\n\nCheck the render method of `" .. D .. "`."
				end
			end
			return ""
		end
		local function getSourceInfoErrorAddendum(D)
			if D ~= nil then
				local E = string.gsub(D.fileName, "^.*[\\/]", "")
				local F = D.lineNumber
				return "\n\nCheck your code at " .. E .. ":" .. F .. "."
			end
			return ""
		end
		local function getSourceInfoErrorAddendumForProps(D)
			if D ~= nil then
				return getSourceInfoErrorAddendum(D.__source)
			end
			return ""
		end
		local D = {}
		local function getCurrentComponentErrorInfo(E)
			local F = getDeclarationErrorAddendum()
			if not d.toJSBoolean(F) then
				local G = if typeof(E) == "string"
					then E
					else if typeof(E) == "table" then E.displayName or E.name else nil
				if not G and typeof(E) == "function" then
					local H = debug.info(E, "n")
					G = if H ~= "" then H else nil
				end
				if G then
					F = string.format("\n\nCheck the top-level render call using <%s>.", G)
				end
			end
			return F
		end
		local function validateExplicitKey(E, F, G)
			if E._store == nil or E._store.validated then
				return
			end
			(E._store).validated = true
			if (E.key ~= nil) ~= (G ~= nil) then
				return
			end
			local H = getCurrentComponentErrorInfo(F)
			if D[H] then
				return
			end
			D[H] = true
			local I = ""
			if E and E._owner and E._owner ~= t.current then
				I = string.format(" It was passed a child from %s.", tostring(k(E._owner.type)))
			end
			if _G.__DEV__ then
				setCurrentlyValidatingElement(E)
				if E.key ~= nil and G ~= nil then
					g.error(
						'Child element received a "key" prop ("%s") in addition to a key in the "children" table of its parent ("%s"). Please provide only one key definition. When both are present, the "key" prop will take precedence.%s%s See https://reactjs.org/link/warning-keys for more information.',
						tostring(E.key),
						tostring(G),
						H,
						I
					)
				else
					g.error(
						'Each child in a list should have a unique "key" prop.%s%s See https://reactjs.org/link/warning-keys for more information.',
						H,
						I
					)
				end
				setCurrentlyValidatingElement(nil)
			end
		end
		local function validateChildKeys(E, F)
			if typeof(E) ~= "table" then
				return
			end
			if c.isArray(E) then
				for G = 1, #E do
					local H = E[G]
					if v(H) then
						validateExplicitKey(H, F)
					end
				end
			elseif v(E) then
				if E._store then
					E._store.validated = true
				end
			elseif E then
				local G = m(E)
				if typeof(G) == "function" then
					if G ~= E.entries then
						local H = G(E)
						local I = H.next()
						while not I.done do
							if v(I.value) then
								validateExplicitKey(I.value, F, I.key)
							end
							I = H.next()
						end
					end
				end
			end
		end
		local function validatePropTypes(E)
			if _G.__DEV__ or _G.__DISABLE_ALL_WARNINGS_EXCEPT_PROP_VALIDATION__ then
				local F = E.type
				if F == nil or typeof(F) == "string" then
					return
				end
				local G
				local H
				if typeof(F) == "function" then
					return
				elseif typeof(F) == "table" then
					G = F.propTypes
					H = F.validateProps
				else
					return
				end
				if G or H then
					local I = k(F)
					s(G, H, E.props, "prop", I, E)
				elseif (F).PropTypes ~= nil and not C then
					C = true
					local I = k(F)
					g.error(
						"Component %s declared `PropTypes` instead of `propTypes`. Did you misspell the property assignment?",
						I or "Unknown"
					)
				end
				if (F).getDefaultProps ~= nil then
					g.error("getDefaultProps is only used on classic React.createClass definitions. Use a static property named `defaultProps` instead.")
				end
			end
		end
		local function validateFragmentProps(E)
			if _G.__DEV__ then
				local F = e.keys(E.props)
				for G = 1, #F do
					local H = F[G]
					if H ~= "children" and H ~= "key" then
						setCurrentlyValidatingElement(E)
						g.error(
							"Invalid prop `%s` supplied to `React.Fragment`. React.Fragment can only have `key` and `children` props.",
							H
						)
						setCurrentlyValidatingElement(nil)
						break
					end
				end
				if E.ref ~= nil then
					setCurrentlyValidatingElement(E)
					g.error("Invalid attribute `ref` supplied to `React.Fragment`.")
					setCurrentlyValidatingElement(nil)
				end
			end
		end
		local function jsxWithValidation(E, F, G, H, I, J)
			local K = j(E)
			if not K then
				local L = ""
				if E == nil or (typeof(E) == "table" and #e.keys(E) == 0) then
					L ..= " You likely forgot to export your component from the file it's defined in, or you might have mixed up default and named imports."
				end
				local M = getSourceInfoErrorAddendum(I)
				if M then
					L ..= M
				else
					L ..= getDeclarationErrorAddendum()
				end
				local N
				if E == nil then
					N = "nil"
				elseif c.isArray(E) then
					N = "array"
				elseif typeof(E) == "table" and E["$$typeof"] == q then
					N = string.format("<%s />", k(E.type) or "Unknown")
					L ..= " Did you accidentally export a JSX literal or Element instead of a component?"
				else
					N = typeof(E)
					L ..= "\n" .. h(E)
				end
				if _G.__DEV__ then
					g.error(
						"React.jsx: type is invalid -- expected a string (for built-in components) or a class/function (for composite components) but got: %s.%s",
						N,
						L
					)
				end
			end
			local L = y(E, F, G, I, J)
			if L == nil then
				return L
			end
			if K then
				local M = F.children
				if M ~= nil then
					if H then
						if c.isArray(M) then
							for N = 1, #M do
								validateChildKeys(M[N], E)
							end
							e.freeze(M)
						else
							if _G.__DEV__ then
								g.error("React.jsx: Static children should always be an array. You are likely explicitly calling React.jsxs or React.jsxDEV. Use the Babel transform instead.")
							end
						end
					else
						validateChildKeys(M, E)
					end
				end
			end
			if _G.__DEV__ then
				if r then
					if hasOwnProperty(F, "key") then
						g.error(
							"React.jsx: Spreading a key to JSX is a deprecated pattern. Explicitly pass a key after spreading props in your JSX call. E.g. <%s {...props} key={key} />",
							k(E) or "ComponentName"
						)
					end
				end
			end
			if E == p then
				validateFragmentProps(L)
			else
				validatePropTypes(L)
			end
			return L
		end
		B.jsxWithValidation = jsxWithValidation
		B.jsxWithValidationStatic = function(E, F, G)
			return jsxWithValidation(E, F, G, true)
		end
		B.jsxWithValidationDynamic = function(E, F, G)
			return jsxWithValidation(E, F, G, false)
		end
		local function createElementWithValidation(E, F, ...)
			local G = j(E)
			if not G then
				local H = ""
				if E == nil or (typeof(E) == "table" and #e.keys(E) == 0) then
					H ..= " You likely forgot to export your component from the file it's defined in, or you might have mixed up default and named imports."
				end
				local I = getSourceInfoErrorAddendumForProps(F)
				if I then
					H ..= I
				else
					H ..= getDeclarationErrorAddendum()
				end
				local J
				if E == nil then
					J = "nil"
				elseif c.isArray(E) then
					J = "array"
				elseif E ~= nil and typeof(E) == "table" and E["$$typeof"] == q then
					J = string.format("<%s />", k((E).type) or "Unknown")
					H ..= " Did you accidentally export a JSX literal or Element instead of a component?"
				else
					J = typeof(E)
					if E ~= nil then
						H ..= "\n" .. h(E)
					end
				end
				if _G.__DEV__ then
					g.error(
						"React.createElement: type is invalid -- expected a string (for built-in components) or a class/function (for composite components) but got: %s.%s",
						J,
						H
					)
				end
			end
			local H = w(E, F, ...)
			if H == nil then
				return H
			end
			if G then
				for I = 1, select("#", ...) do
					validateChildKeys(select(I, ...), E)
				end
			end
			if E == p then
				validateFragmentProps(H)
			else
				validatePropTypes(H)
			end
			return H
		end
		B.createElementWithValidation = createElementWithValidation
		B.cloneElementWithValidation = function(E, F, ...)
			local G = { E, F, ... }
			local H = x(E, F, ...)
			for I = 3, #G do
				validateChildKeys(G[I], H.type)
			end
			validatePropTypes(H)
			return H
		end
		return B
	end
	function a.bP()
		local function createSignal()
			local b = {}
			local c = {}
			local d = false
			local function subscribe(e)
				assert(typeof(e) == "function", "Can only subscribe to signals with a function.")
				local g = { callback = e, disconnected = false }
				if d and not b[e] then
					c[e] = g
				end
				b[e] = g
				local function disconnect()
					assert(not g.disconnected, "Listeners can only be disconnected once.")
					g.disconnected = true
					b[e] = nil
					c[e] = nil
				end
				return disconnect
			end
			local function fire(...)
				d = true
				for e, g in b do
					if not g.disconnected and not c[e] then
						e(...)
					end
				end
				d = false
				table.clear(c)
			end
			return subscribe, fire
		end
		return createSignal
	end
	function a.bQ()
		local b = a.load("a1")
		local c = a.load("bH").ReactSymbols
		local d = a.load("bH")
		local e = b.Symbol
		local g = a.load("bP")
		local h = e("BindingImpl")
		local i = {}
		local j = {}
		function j.getValue(k)
			return i.getValue(k)
		end
		function j.map(k, l)
			return i.map(k, l)
		end
		local k = {
			__index = j,
			__tostring = function(k)
				return string.format("RoactBinding(%s)", tostring(k.getValue(k)))
			end,
		}
		function i.update(l, m)
			return (l[h]).update(m)
		end
		function i.subscribe(l, m)
			return (l[h]).subscribe(m)
		end
		function i.getValue(l)
			return (l[h]):getValue()
		end
		function i.create(l)
			local m, n = g()
			local o = { value = l, subscribe = m }
			function o.update(p)
				o.value = p
				n(p)
			end
			function o.getValue()
				return o.value
			end
			local p
			if _G.__DEV__ then
				p = debug.traceback("Binding created at:", 3)
			end
			return (setmetatable({ ["$$typeof"] = c.REACT_BINDING_TYPE, [h] = o, _source = p }, k)), o.update
		end
		function i.map(l, m)
			if _G.__DEV__ then
				assert(
					typeof(l) == "table" and l["$$typeof"] == c.REACT_BINDING_TYPE,
					"Expected `self` to be a binding"
				)
				assert(typeof(m) == "function", "Expected arg #1 to be a function")
			end
			local n = {}
			function n.subscribe(o)
				return i.subscribe(l, function(p)
					o(m(p))
				end)
			end
			function n.update(o)
				error("Bindings created by Binding:map(fn) cannot be updated directly", 2)
			end
			function n.getValue()
				return m(l.getValue(l))
			end
			local o
			if _G.__DEV__ then
				o = debug.traceback("Mapped binding created at:", 3)
			end
			return (setmetatable({ ["$$typeof"] = c.REACT_BINDING_TYPE, [h] = n, _source = o }, k))
		end
		function i.join(l)
			if _G.__DEV__ then
				assert(typeof(l) == "table", "Expected arg #1 to be of type table")
				for m, n in l do
					if typeof(n) ~= "table" or (n)["$$typeof"] ~= c.REACT_BINDING_TYPE then
						local o = ("Expected arg #1 to contain only bindings, but key %q had a non-binding value").format(
							"Expected arg #1 to contain only bindings, but key %q had a non-binding value",
							tostring(m)
						)
						error(o, 2)
					end
				end
			end
			local m = {}
			local function getValue()
				local n = {}
				for o, p in pairs(l) do
					n[o] = p.getValue(p)
				end
				return n
			end
			function m.subscribe(n)
				local o = {}
				for p, q in l do
					o[p] = i.subscribe(q, function(r)
						n(getValue())
					end)
				end
				return function()
					if o == nil then
						return
					end
					for p, q in o do
						q()
					end
					o = nil
				end
			end
			function m.update(n)
				error("Bindings created by joinBindings(...) cannot be updated directly", 2)
			end
			function m.getValue()
				return getValue()
			end
			local n
			if _G.__DEV__ then
				n = debug.traceback("Joined binding created at:", 2)
			end
			return (setmetatable({ ["$$typeof"] = c.REACT_BINDING_TYPE, [h] = m, _source = n }, k))
		end
		return i
	end
	function a.bR()
		local b = a.load("bH")
		local c = a.load("bQ")
		local d = {}
		d.createRef = function()
			local e, g = c.create(nil)
			local h = {}
			if _G.__DEV__ then
				e._source = debug.traceback("Ref created at:", 1)
			end
			setmetatable(h, {
				__index = function(i, j)
					if j == "current" then
						return e.getValue(e)
					else
						return (e)[j]
					end
				end,
				__newindex = function(i, j, k)
					if j == "current" then
						c.update(e, k)
					end
					(e)[j] = k
				end,
				__tostring = function(i)
					return string.format("Ref(%s)", tostring(e.getValue(e)))
				end,
			})
			return h
		end
		return d
	end
	function a.bS()
		local b = a.load("bH").console
		local c = a.load("bH").ReactSymbols
		local d = a.load("bH")
		local e = c.REACT_FORWARD_REF_TYPE
		local g = c.REACT_MEMO_TYPE
		local h = {}
		h.forwardRef = function(i)
			if _G.__DEV__ then
				if typeof(i) == "table" and (i)["$$typeof"] == g then
					b.error("forwardRef requires a render function but received a `memo` component. Instead of forwardRef(memo(...)), use memo(forwardRef(...)).")
				elseif typeof(i) ~= "function" then
					b.error("forwardRef requires a render function but was given %s.", typeof(i))
				else
					local j, k = debug.info(i, "a")
					if j ~= 0 and j ~= 2 then
						b.error(
							"forwardRef render functions accept exactly two parameters: props and ref. %s",
							(function()
								if j == 1 then
									return "Did you forget to use the ref parameter?"
								end
								return "Any additional parameter will be undefined."
							end)()
						)
					end
				end
			end
			local j = { ["$$typeof"] = e, render = i }
			if _G.__DEV__ then
				local k
				setmetatable(j, {
					__index = function(l, m)
						if m == "displayName" then
							return k
						end
						return rawget(l, m)
					end,
					__newindex = function(l, m, n)
						if m == "displayName" then
							k = n
						else
							rawset(l, m, n)
						end
					end,
				})
			end
			return j
		end
		return h
	end
	function a.bT()
		local b = a.load("a1")
		local c = b.Array
		local d = a.load("bH").console
		local e = a.load("bH")
		local g = a.load("bH")
		local h = a.load("bH").ReactSharedInternals.ReactCurrentDispatcher
		local function resolveDispatcher()
			local i = h.current
			if _G.__DEV__ then
				if i == nil then
					d.error("Invalid hook call. Hooks can only be called inside of the body of a function component. This could happen for one of the following reasons:\n1. You might have mismatching versions of React and the renderer (such as React DOM)\n2. You might be breaking the Rules of Hooks\n3. You might have more than one copy of React in the same app\nSee https://reactjs.org/link/invalid-hook-call for tips about how to debug and fix this problem.")
				end
			end
			return i
		end
		local i = {}
		local function useContext(j, k, ...)
			local l = resolveDispatcher()
			if _G.__DEV__ then
				if k ~= nil then
					d.error(
						"useContext() second argument is reserved for future use in React. Passing it is not supported. You passed: %s.%s",
						k,
						(typeof(k) == "number" and c.isArray({ ... }))
								and "\n\n\nDid you call Array.map(useContext)? Calling Hooks inside a loop is not supported. Learn more at https://reactjs.org/link/rules-of-hooks"
							or ""
					)
				end
				if (j)._context ~= nil then
					local m = (j)._context
					if m.Consumer == j then
						d.error("Calling useContext(Context.Consumer) is not supported, may cause bugs, and will be removed in a future major release. Did you mean to call useContext(Context) instead?")
					elseif m.Provider == j then
						d.error("Calling useContext(Context.Provider) is not supported. Did you mean to call useContext(Context) instead?")
					end
				end
			end
			return l.useContext(j, k)
		end
		i.useContext = useContext
		local function useState(j, ...)
			local k = resolveDispatcher()
			return k.useState(j, ...)
		end
		i.useState = useState
		local function useReducer(j, k, l)
			local m = resolveDispatcher()
			return m.useReducer(j, k, l)
		end
		i.useReducer = useReducer
		local function useRef(j)
			local k = resolveDispatcher()
			return k.useRef(j)
		end
		i.useRef = useRef
		local function useBinding(j)
			local k = resolveDispatcher()
			return k.useBinding(j)
		end
		i.useBinding = useBinding
		local function useEffect(j, k)
			local l = resolveDispatcher()
			return l.useEffect(j, k)
		end
		i.useEffect = useEffect
		local function useLayoutEffect(j, k)
			local l = resolveDispatcher()
			return l.useLayoutEffect(j, k)
		end
		i.useLayoutEffect = useLayoutEffect
		local function useCallback(j, k)
			local l = resolveDispatcher()
			return l.useCallback(j, k)
		end
		i.useCallback = useCallback
		local function useMemo(j, k)
			local l = resolveDispatcher()
			return l.useMemo(j, k)
		end
		i.useMemo = useMemo
		local function useImperativeHandle(j, k, l)
			local m = resolveDispatcher()
			return m.useImperativeHandle(j, k, l)
		end
		i.useImperativeHandle = useImperativeHandle
		local function useDebugValue(j, k)
			if _G.__DEV__ then
				local l = resolveDispatcher()
				return l.useDebugValue(j, k)
			end
			return nil
		end
		i.useDebugValue = useDebugValue
		i.emptyObject = {}
		i.useOpaqueIdentifier = function()
			local j = resolveDispatcher()
			return j.useOpaqueIdentifier()
		end
		i.useMutableSource = function(j, k, l)
			local m = resolveDispatcher()
			return m.useMutableSource(j, k, l)
		end
		return i
	end
	function a.bU()
		local b = a.load("bH")
		local c = b.console
		local d = a.load("a1")
		local e = d.Array
		local g = d.Object
		local h = d.util.inspect
		local i = b.ReactSymbols
		local j = i.REACT_MEMO_TYPE
		local k = i.REACT_ELEMENT_TYPE
		local l = b.isValidElementType
		local m = b.getComponentName
		local n = {}
		n.memo = function(o, p)
			if _G.__DEV__ then
				local q = l(o)
				if not q then
					local r = ""
					if o == nil or (typeof(o) == "table" and #g.keys(o) == 0) then
						r = r
							.. " You likely forgot to export your component from the file it's defined in, or you might have mixed up default and named imports."
					end
					local s
					if o == nil then
						s = "nil"
					elseif e.isArray(o) then
						s = "array"
					elseif o ~= nil and typeof(o) == "table" and (o)["$$typeof"] == k then
						s = string.format("<%s />", m((o).type) or "UNKNOWN")
						r = " Did you accidentally export a JSX literal or Element instead of a component?"
					else
						s = typeof(o)
						if o ~= nil then
							r = "\n" .. h(o)
						end
					end
					c.error("memo: The first argument must be a component. Instead received: `%s`.%s", s, r)
				end
			end
			local q = { ["$$typeof"] = j, type = o, compare = p or nil }
			if _G.__DEV__ then
				local r
				setmetatable(q, {
					__index = function(s, t)
						if t == "displayName" then
							return r
						end
						return rawget(s, t)
					end,
					__newindex = function(s, t, u)
						if t == "displayName" then
							r = u
							if typeof(o) == "table" and (o).displayName == nil then
								(o).displayName = r
							end
						else
							rawset(s, t, u)
						end
					end,
				})
			end
			return q
		end
		return n
	end
	function a.bV()
		local b = a.load("bH")
		local c = b.console
		local d = a.load("bH").ReactSymbols
		local e = d.REACT_PROVIDER_TYPE
		local g = d.REACT_CONTEXT_TYPE
		local h = {}
		h.createContext = function(i, j)
			local k = {
				["$$typeof"] = g,
				_calculateChangedBits = j,
				_currentValue = i,
				_currentValue2 = i,
				_threadCount = 0,
				Provider = nil,
				Consumer = nil,
				displayName = nil,
				_currentRenderer = nil,
				_currentRenderer2 = nil,
			}
			k.Provider = { ["$$typeof"] = e, _context = k }
			local l = false
			if _G.__DEV__ then
				local m = { ["$$typeof"] = g, _context = k, _calculateChangedBits = k._calculateChangedBits }
				setmetatable(m, {
					__index = function(n, o)
						if o == "_currentValue" then
							return k._currentValue
						elseif o == "_currentValue2" then
							return k._currentValue2
						elseif o == "_threadCount" then
							return k._threadCount
						elseif o == "displayName" then
							return k.displayName
						end
						return nil
					end,
					__newindex = function(n, o, p)
						if o == "_currentValue" then
							k._currentValue = p
						elseif o == "_currentValue2" then
							k._currentValue2 = p
						elseif o == "_threadCount" then
							k._threadCount = p
						elseif o == "displayName" then
							if not l then
								c.warn(
									"Setting `displayName` on Context.Consumer has no effect. "
										.. "You should set it directly on the context with Context.displayName = "
										.. p
										.. "."
								)
								l = true
							end
						end
					end,
				})
				k.Consumer = m
			else
				k.Consumer = k
			end
			if _G.__DEV__ then
				k._currentRenderer = nil
				k._currentRenderer2 = nil
			end
			return k
		end
		return h
	end
	function a.bW()
		local b = a.load("a1")
		return b.Object.None
	end
	function a.bX()
		local b = a.load("a1")
		local c = a.load("bI")
		local d = a.load("bH").ReactSharedInternals
		local e = a.load("bK")
		local g = a.load("bN")
		local h = a.load("bO")
		local i = a.load("bM")
		local j = a.load("bR")
		local k = a.load("bS")
		local l = a.load("bT")
		local m = a.load("bU")
		local n = a.load("bV")
		local o = a.load("bL")
		local p = a.load("bQ")
		local q = a.load("bW")
		local r = a.load("bH")
		local s = r.ReactSymbols
		local t = _G.__DEV__ or _G.__DISABLE_ALL_WARNINGS_EXCEPT_PROP_VALIDATION__
		local u = a.load("bH")
		local v = if t then h.createElementWithValidation else i.createElement
		local w = if t then h.cloneElementWithValidation else i.cloneElement
		return {
			Children = g,
			createMutableSource = c,
			createRef = j.createRef,
			Component = e.Component,
			PureComponent = e.PureComponent,
			createContext = n.createContext,
			forwardRef = k.forwardRef,
			lazy = o.lazy,
			memo = m.memo,
			useCallback = l.useCallback,
			useContext = l.useContext,
			useEffect = l.useEffect,
			useImperativeHandle = l.useImperativeHandle,
			useDebugValue = l.useDebugValue,
			useLayoutEffect = l.useLayoutEffect,
			useMemo = l.useMemo,
			useMutableSource = l.useMutableSource,
			useReducer = l.useReducer,
			useRef = l.useRef,
			useBinding = l.useBinding,
			useState = l.useState,
			Fragment = s.REACT_FRAGMENT_TYPE,
			Profiler = s.REACT_PROFILER_TYPE,
			StrictMode = s.REACT_STRICT_MODE_TYPE,
			unstable_DebugTracingMode = s.REACT_DEBUG_TRACING_MODE_TYPE,
			Suspense = s.REACT_SUSPENSE_TYPE,
			createElement = v,
			cloneElement = w,
			isValidElement = i.isValidElement,
			__SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED = d,
			unstable_LegacyHidden = s.REACT_LEGACY_HIDDEN_TYPE,
			createBinding = p.create,
			joinBindings = p.join,
			None = q,
			__subscribeToBinding = p.subscribe,
			Event = a.load("bH").Event,
			Change = a.load("bH").Change,
			Tag = a.load("bH").Tag,
			unstable_parseReactError = a.load("bH").parseReactError,
		}
	end
	function a.bY()
		local b = a.load("a1")
		local c = a.load("bX")
		local d = a.load("bL")
		local e = a.load("bH")
		return c
	end
	function a.bZ()
		local b = a.load("bY")
		return b
	end
	function a.b_()
		return a.load("a0")
	end
	function a.b0()
		return a.load("bG")
	end
	function a.b1()
		return {
			FunctionComponent = 0,
			ClassComponent = 1,
			IndeterminateComponent = 2,
			HostRoot = 3,
			HostPortal = 4,
			HostComponent = 5,
			HostText = 6,
			Fragment = 7,
			Mode = 8,
			ContextConsumer = 9,
			ContextProvider = 10,
			ForwardRef = 11,
			Profiler = 12,
			SuspenseComponent = 13,
			MemoComponent = 14,
			SimpleMemoComponent = 15,
			LazyComponent = 16,
			IncompleteClassComponent = 17,
			DehydratedFragment = 18,
			SuspenseListComponent = 19,
			FundamentalComponent = 20,
			ScopeComponent = 21,
			Block = 22,
			OffscreenComponent = 23,
			LegacyHiddenComponent = 24,
		}
	end
	function a.b2()
		return {
			NoMode = 0b0,
			StrictMode = 0b1,
			BlockingMode = 0b10,
			ConcurrentMode = 0b100,
			ProfileMode = 0b1000,
			DebugTracingMode = 0b10000,
		}
	end
	function a.b3()
		local b = {}
		b.NoFlags = 0b0
		b.PerformedWork = 0b1
		b.Placement = 0b10
		b.Update = 0b100
		b.PlacementAndUpdate = 0b110
		b.Deletion = 0b1000
		b.ContentReset = 0b10000
		b.Callback = 0b100000
		b.DidCapture = 0b1000000
		b.Ref = 0b10000000
		b.Snapshot = 0b100000000
		b.Passive = 0b1000000000
		b.PassiveUnmountPendingDev = 0b10000000000000
		b.Hydrating = 0b10000000000
		b.HydratingAndUpdate = 0b10000000100
		b.LifecycleEffectMask = 0b1110100100
		b.HostEffectMask = 0b11111111111
		b.Incomplete = 0b100000000000
		b.ShouldCapture = 0b1000000000000
		b.ForceUpdateForLegacySuspense = 0b100000000000000
		b.PassiveStatic = 0b1000000000000000
		b.BeforeMutationMask = 0b1100001010
		b.MutationMask = 0b10010011110
		b.LayoutMask = 0b10100100
		b.PassiveMask = 0b1000001000
		b.StaticMask = 0b1000000000000000
		b.MountLayoutDev = 0b10000000000000000
		b.MountPassiveDev = 0b100000000000000000
		return b
	end
	function a.b4()
		return { LegacyRoot = 0, BlockingRoot = 1, ConcurrentRoot = 2 }
	end
	function a.b5()
		return a.load("bG")
	end
	function a.b6()
		return { enableSchedulerDebugging = false, enableIsInputPending = false, enableProfiling = _G.__PROFILE__ }
	end
	function a.b7()
		return a.load("a0")
	end
	function a.b8()
		local b = a.load("b7")
		local c = b.Object
		local d = a.load("b5")
		local e = d.console
		local g = d.errorToString
		local h = d.describeError
		local i = function()
			return os.clock() * 1000
		end
		local j = b.setTimeout
		local k = b.clearTimeout
		local l = false
		local m
		local n = c.None
		local o = 15
		local p = 0
		local function shouldYieldToHost()
			return i() >= p
		end
		local function requestPaint() end
		local function forceFrameRate(q)
			if q < 0 or q > 125 then
				e.warn("forceFrameRate takes a positive int between 0 and 125, forcing frame rates higher than 125 fps is not supported")
				return
			end
			if q > 0 then
				o = math.floor(1000 / q)
			else
				o = 5
			end
		end
		local function performWorkUntilDeadline()
			if m ~= nil then
				local q = i()
				p = q + o
				local r = true
				local s, t
				local function doWork()
					local u = (m)(r, q)
					if not u then
						l = false
						m = nil
					else
						task.delay(0, performWorkUntilDeadline)
					end
					return nil
				end
				if not _G.__YOLO__ then
					s, t = xpcall(doWork, h)
				else
					t = doWork()
					s = true
				end
				if not s then
					task.delay(0, performWorkUntilDeadline)
					error(g(t))
				end
			else
				l = false
			end
		end
		local function wrapPerformWorkWithCoroutine(q)
			local r = coroutine.create(function()
				while true do
					local r = coroutine.wrap(q)
					local s, t = pcall(r)
					coroutine.yield(s, t)
				end
			end)
			return function()
				local s, t, u = coroutine.resume(r)
				if not t then
					error(u)
				end
			end
		end
		performWorkUntilDeadline = wrapPerformWorkWithCoroutine(performWorkUntilDeadline)
		local function requestHostCallback(q)
			m = q
			if not l then
				l = true
				task.delay(0, performWorkUntilDeadline)
			end
		end
		local function cancelHostCallback()
			m = nil
		end
		local function requestHostTimeout(q, r)
			n = j(function()
				q(i())
			end, r)
		end
		local function cancelHostTimeout()
			k(n)
			n = c.None
		end
		return {
			requestHostCallback = requestHostCallback,
			cancelHostCallback = cancelHostCallback,
			requestHostTimeout = requestHostTimeout,
			cancelHostTimeout = cancelHostTimeout,
			shouldYieldToHost = shouldYieldToHost,
			requestPaint = requestPaint,
			getCurrentTime = i,
			forceFrameRate = forceFrameRate,
		}
	end
	function a.b9()
		return a.load("b8")
	end
	function a.ca()
		return {
			NoPriority = 0,
			ImmediatePriority = 1,
			UserBlockingPriority = 2,
			NormalPriority = 3,
			LowPriority = 4,
			IdlePriority = 5,
		}
	end
	function a.cb()
		local b = a.load("b5").console
		local c = {}
		local d = a.load("ca")
		local e = a.load("b6")
		local g = e.enableProfiling
		local h = 0
		local i = 0
		local j = 131072
		local k = 524288
		local l = 0
		local m
		local n
		local o = 1
		local p = 1
		local q = 2
		local r = 3
		local s = 4
		local t = 5
		local u = 6
		local v = 7
		local w = 8
		local function logEvent(x)
			if n ~= nil then
				o += #x
				if o + 1 > l then
					l *= 2
					if l > k then
						b["error"]("Scheduler Profiling: Event log exceeded maximum size. Don't forget to call `stopLoggingProfilingEvents()`.")
						c.stopLoggingProfilingEvents()
						return
					end
					local y = {}
					table.insert(y, n)
					m = y
					n = y
				end
				table.insert(n, x)
			end
		end
		c.startLoggingProfilingEvents = function()
			l = j
			m = {}
			n = m
			o = 1
		end
		c.stopLoggingProfilingEvents = function()
			local x = m
			l = 0
			m = nil
			n = nil
			o = 1
			return x
		end
		c.markTaskStart = function(x, y)
			if g then
				if n ~= nil then
					logEvent({ p, y * 1000, x.id, x.priorityLevel })
				end
			end
		end
		c.markTaskCompleted = function(x, y)
			if g then
				if n ~= nil then
					logEvent({ q, y * 1000, x.id })
				end
			end
		end
		c.markTaskCanceled = function(x, y)
			if g then
				if n ~= nil then
					logEvent({ s, y * 1000, x.id })
				end
			end
		end
		c.markTaskErrored = function(x, y)
			if g then
				if n ~= nil then
					logEvent({ r, y * 1000, x.id })
				end
			end
		end
		c.markTaskRun = function(x, y)
			if g then
				h += 1
				if n ~= nil then
					logEvent({ t, y * 1000, x.id, h })
				end
			end
		end
		c.markTaskYield = function(x, y)
			if g then
				if n ~= nil then
					logEvent({ u, y * 1000, x.id, h })
				end
			end
		end
		c.markSchedulerSuspended = function(x)
			if g then
				i += 1
				if n ~= nil then
					logEvent({ v, x * 1000, i })
				end
			end
		end
		c.markSchedulerUnsuspended = function(x)
			if g then
				if n ~= nil then
					logEvent({ w, x * 1000, i })
				end
			end
		end
		return c
	end
	function a.cc()
		return function(b)
			local c = a.load("b5").describeError
			local d = a.load("b6")
			local e = d.enableSchedulerDebugging
			local g = d.enableProfiling
			local h = b or a.load("b9")
			local i = h.requestHostCallback
			local j = h.requestHostTimeout
			local k = h.cancelHostTimeout
			local l = h.shouldYieldToHost
			local m = h.getCurrentTime
			local n = h.forceFrameRate
			local o = h.requestPaint
			local p, q, r
			local s = function(s, t)
				local u = #s + 1
				s[u] = t
				q(s, t, u)
			end
			local t = function(t)
				return t[1]
			end
			local u = function(u)
				local v = u[1]
				if v ~= nil then
					local w = u[#u]
					u[#u] = nil
					if w ~= v then
						u[1] = w
						r(u, w, 1)
					end
					return v
				else
					return nil
				end
			end
			q = function(v, w, x)
				while true do
					local y = math.floor(x / 2)
					local z = v[y]
					if z ~= nil and p(z, w) > 0 then
						v[y] = w
						v[x] = z
						x = y
					else
						return
					end
				end
			end
			r = function(v, w, x)
				local y = #v
				while x < y do
					local z = x * 2
					local A = v[z]
					local B = z + 1
					local C = v[B]
					if A ~= nil and p(A, w) < 0 then
						if C ~= nil and p(C, A) < 0 then
							v[x] = C
							v[B] = w
							x = B
						else
							v[x] = A
							v[z] = w
							x = z
						end
					elseif C ~= nil and p(C, w) < 0 then
						v[x] = C
						v[B] = w
						x = B
					else
						return
					end
				end
			end
			p = function(v, w)
				local x = v.sortIndex - w.sortIndex
				if x == 0 then
					return v.id - w.id
				end
				return x
			end
			local v = a.load("ca")
			local w = v.ImmediatePriority
			local x = v.UserBlockingPriority
			local y = v.NormalPriority
			local z = v.LowPriority
			local A = v.IdlePriority
			local B = a.load("cb")
			local C = B.markTaskRun
			local D = B.markTaskYield
			local E = B.markTaskCompleted
			local F = B.markTaskCanceled
			local G = B.markTaskErrored
			local H = B.markSchedulerSuspended
			local I = B.markSchedulerUnsuspended
			local J = B.markTaskStart
			local K = B.stopLoggingProfilingEvents
			local L = B.startLoggingProfilingEvents
			local M = 1073741823
			local N = -1
			local O = 250
			local P = 5000
			local Q = 10000
			local R = M
			local S = {}
			local T = {}
			local U = 1
			local V = false
			local W
			local X = y
			local Y = false
			local Z = false
			local _ = false
			local aa, ab, ac
			local function advanceTimers(ad)
				local ae = t(T)
				while ae ~= nil do
					if ae.callback == nil then
						u(T)
					elseif ae.startTime <= ad then
						u(T)
						ae.sortIndex = ae.expirationTime
						s(S, ae)
						if g then
							J(ae, ad)
							ae.isQueued = true
						end
					else
						return
					end
					ae = t(T)
				end
			end
			aa = function(ad)
				_ = false
				advanceTimers(ad)
				if not Z then
					if t(S) ~= nil then
						Z = true
						i(ab)
					else
						local ae = t(T)
						if ae ~= nil then
							j(aa, ae.startTime - ad)
						end
					end
				end
			end
			ab = function(ad, ae)
				if g then
					I(ae)
				end
				Z = false
				if _ then
					_ = false
					k()
				end
				Y = true
				local af = X
				local ag, ah
				if not _G.__YOLO__ then
					if g then
						ag, ah = xpcall(ac, c, ad, ae)
						if not ag then
							if W ~= nil then
								local ai = m()
								G(W, ai)
								W.isQueued = false
							end
						end
					else
						ag = true
						ah = ac(ad, ae)
					end
				else
					ag = true
					ah = ac(ad, ae)
				end
				W = nil
				X = af
				Y = false
				if g then
					local ai = m()
					H(ai)
				end
				if not ag then
					error(ah)
				end
				return ah
			end
			ac = function(ad, ae)
				local af = ae
				advanceTimers(af)
				W = t(S)
				while W ~= nil and not (e and V) do
					if W.expirationTime > af and (not ad or l()) then
						break
					end
					local ag = W.callback
					if typeof(ag) == "function" then
						W.callback = nil
						X = W.priorityLevel
						local ah = W.expirationTime <= af
						C(W, af)
						local ai = ag(ah)
						af = m()
						if typeof(ai) == "function" then
							W.callback = ai
							D(W, af)
						else
							if g then
								E(W, af)
								W.isQueued = false
							end
							if W == t(S) then
								u(S)
							end
						end
						advanceTimers(af)
					else
						u(S)
					end
					W = t(S)
				end
				if W ~= nil then
					return true
				else
					local ag = t(T)
					if ag ~= nil then
						j(aa, ag.startTime - af)
					end
					return false
				end
			end
			local function unstable_runWithPriority(ad, ae)
				if ad == w or ad == x or ad == y or ad == z or ad == A then
				else
					ad = y
				end
				local af = X
				X = ad
				local ag, ah
				if not _G.__YOLO__ then
					ag, ah = xpcall(ae, c)
				else
					ag = true
					ah = ae()
				end
				X = af
				if not ag then
					error(ah)
				end
				return ah
			end
			local function unstable_next(ad)
				local ae
				if X == w or X == x or X == y then
					ae = y
				else
					ae = X
				end
				local af = X
				X = ae
				local ag, ah
				if not _G.__YOLO__ then
					ag, ah = xpcall(ad, c)
				else
					ag = true
					ah = ad()
				end
				X = af
				if not ag then
					error(ah)
				end
				return ah
			end
			local function unstable_wrapCallback(ad)
				local ae = X
				return function(...)
					local af = X
					X = ae
					local ag, ah
					if not _G.__YOLO__ then
						ag, ah = xpcall(ad, c, ...)
					else
						ag = true
						ah = ad(...)
					end
					X = af
					if not ag then
						error(ah)
					end
					return ah
				end
			end
			local function unstable_scheduleCallback(ad, ae, af)
				local ag = m()
				local ah
				if typeof(af) == "table" then
					local ai = af.delay
					if typeof(ai) == "number" and ai > 0 then
						ah = ag + ai
					else
						ah = ag
					end
				else
					ah = ag
				end
				local ai
				if ad == w then
					ai = N
				elseif ad == x then
					ai = O
				elseif ad == A then
					ai = R
				elseif ad == z then
					ai = Q
				else
					ai = P
				end
				local aj = ah + ai
				local ak =
					{ id = U, callback = ae, priorityLevel = ad, startTime = ah, expirationTime = aj, sortIndex = -1 }
				U += 1
				if g then
					ak.isQueued = false
				end
				if ah > ag then
					ak.sortIndex = ah
					s(T, ak)
					if #S == 0 and ak == t(T) then
						if _ then
							k()
						else
							_ = true
						end
						j(aa, ah - ag)
					end
				else
					ak.sortIndex = aj
					s(S, ak)
					if g then
						J(ak, ag)
						ak.isQueued = true
					end
					if not Z and not Y then
						Z = true
						i(ab)
					end
				end
				return ak
			end
			local function unstable_pauseExecution()
				V = true
			end
			local function unstable_continueExecution()
				V = false
				if not Z and not Y then
					Z = true
					i(ab)
				end
			end
			local function unstable_getFirstCallbackNode()
				return t(S)
			end
			local function unstable_cancelCallback(ad)
				if g then
					if ad.isQueued then
						local ae = m()
						F(ad, ae)
						ad.isQueued = false
					end
				end
				ad.callback = nil
			end
			local function unstable_getCurrentPriorityLevel()
				return X
			end
			local ad = o
			return {
				unstable_ImmediatePriority = w,
				unstable_UserBlockingPriority = x,
				unstable_NormalPriority = y,
				unstable_IdlePriority = A,
				unstable_LowPriority = z,
				unstable_runWithPriority = unstable_runWithPriority,
				unstable_next = unstable_next,
				unstable_scheduleCallback = unstable_scheduleCallback,
				unstable_cancelCallback = unstable_cancelCallback,
				unstable_wrapCallback = unstable_wrapCallback,
				unstable_getCurrentPriorityLevel = unstable_getCurrentPriorityLevel,
				unstable_shouldYield = l,
				unstable_requestPaint = ad,
				unstable_continueExecution = unstable_continueExecution,
				unstable_pauseExecution = unstable_pauseExecution,
				unstable_getFirstCallbackNode = unstable_getFirstCallbackNode,
				unstable_now = m,
				unstable_forceFrameRate = n,
				unstable_Profiling = (function()
					if g then
						return {
							startLoggingProfilingEvents = L,
							stopLoggingProfilingEvents = K,
						}
					end
					return nil
				end)(),
			}
		end
	end
	function a.cd()
		local aa = a.load("b7")
		local ab = aa.Set
		local ac = {}
		local ad = a.load("b5").ReactFeatureFlags
		local ae = ad.enableSchedulerTracing
		local af = 0
		local ag = 0
		local ah = 0
		local ai
		local aj
		if ae then
			ai = { current = ab.new() }
			aj = { current = nil }
		end
		ac.__interactionsRef = ai
		ac.__subscriberRef = aj
		ac.unstable_clear = function(ak)
			if not ae then
				return ak()
			end
			local b = ai.current
			ai.current = ab.new()
			local c, d = pcall(ak)
			ai.current = b
			if not c then
				error(d)
			end
			return d
		end
		ac.unstable_getCurrent = function()
			if not ae then
				return nil
			else
				return ai.current
			end
		end
		ac.unstable_getThreadID = function()
			ah += 1
			return ah
		end
		ac.unstable_trace = function(ak, b, c, d)
			local e = if d ~= nil then d else af
			if not ae then
				return c()
			end
			local g = { __count = 1, id = ag, name = ak, timestamp = b }
			ag += 1
			local h = ai.current
			local i = ab.new(h)
			i.add(i, g)
			ai.current = i
			local j = aj.current
			local k
			local l, m = pcall(function()
				if j ~= nil then
					j.onInteractionTraced(g)
				end
			end)
			local n, o = pcall(function()
				if j ~= nil then
					j.onWorkStarted(i, e)
				end
			end)
			local p, q = pcall(function()
				k = c()
			end)
			ai.current = h
			local r, s = pcall(function()
				if j ~= nil then
					j.onWorkStopped(i, e)
				end
			end)
			g.__count -= 1
			if j ~= nil and g.__count == 0 then
				j.onInteractionScheduledWorkCompleted(g)
			end
			if not r then
				error(s)
			end
			if not p then
				error(q)
			end
			if not n then
				error(o)
			end
			if not l then
				error(m)
			end
			return k
		end
		ac.unstable_wrap = function(ak, b)
			if b == nil then
				b = af
			end
			if not ae then
				return ak
			end
			local c = ai.current
			local d = aj.current
			if d ~= nil then
				d.onWorkScheduled(c, b)
			end
			for e, g in c do
				g.__count += 1
			end
			local e = false
			local function _wrapped(g, ...)
				local h = ai.current
				ai.current = c
				d = aj.current
				local i, j = pcall(function(...)
					local i
					local j, k = pcall(function()
						if d ~= nil then
							d.onWorkStarted(c, b)
						end
					end)
					local l, m = pcall(function(...)
						i = ak(...)
					end, ...)
					ai.current = h
					if d ~= nil then
						d.onWorkStopped(c, b)
					end
					if not l then
						error(m)
					end
					if not j then
						error(k)
					end
					return i
				end, ...)
				if not e then
					e = true
					for k, l in c do
						l.__count -= 1
						if d ~= nil and l.__count == 0 then
							d.onInteractionScheduledWorkCompleted(l)
						end
					end
				end
				if not i then
					error(j)
				end
				return j
			end
			local g = function()
				d = aj.current
				local g, h = pcall(function()
					if d ~= nil then
						d.onWorkCanceled(c, b)
					end
				end)
				for i, j in c do
					j.__count -= 1
					if d ~= nil and j.__count == 0 then
						d.onInteractionScheduledWorkCompleted(j)
					end
				end
				if not g then
					error(h)
				end
			end
			local h = {}
			setmetatable(h, { __call = _wrapped })
			h.cancel = g
			return h
		end
		return ac
	end
	function a.ce()
		local aa = {}
		local ab = a.load("b7").Object
		local ac = a.load("cd")
		local ad = a.load("b5").ReactFeatureFlags
		local ae = ad.enableSchedulerTracing
		local af = ac.__subscriberRef
		local ag = {}
		if ae then
			ag = {}
		end
		aa.unstable_subscribe = function(ah)
			if ae then
				ag[ah] = true
				if #ab.keys(ag) == 1 then
					af.current = {
						onInteractionScheduledWorkCompleted = onInteractionScheduledWorkCompleted,
						onInteractionTraced = onInteractionTraced,
						onWorkCanceled = onWorkCanceled,
						onWorkScheduled = onWorkScheduled,
						onWorkStarted = onWorkStarted,
						onWorkStopped = onWorkStopped,
					}
				end
			end
		end
		aa.unstable_unsubscribe = function(ah)
			if ae then
				ag[ah] = nil
				if #ab.keys(ag) == 0 then
					af.current = nil
				end
			end
		end
		function onInteractionTraced(ah)
			local ai = false
			local aj
			for ak, b in ag do
				local c, d = pcall(ak.onInteractionTraced, ah)
				if not c then
					local e = d
					if not ai then
						ai = true
						aj = e
					end
				end
			end
			if ai then
				error(aj)
			end
		end
		function onInteractionScheduledWorkCompleted(ah)
			local ai = false
			local aj
			for ak, b in ag do
				local c, d = pcall(ak.onInteractionScheduledWorkCompleted, ah)
				if not c then
					local e = d
					if not ai then
						ai = true
						aj = e
					end
				end
			end
			if ai then
				error(aj)
			end
		end
		function onWorkScheduled(ah, ai)
			local aj = false
			local ak
			for b, c in ag do
				local d, e = pcall(b.onWorkScheduled, ah, ai)
				if not d then
					local g = e
					if not aj then
						aj = true
						ak = g
					end
				end
			end
			if aj then
				error(ak)
			end
		end
		function onWorkStarted(ah, ai)
			local aj = false
			local ak
			for b, c in ag do
				local d, e = pcall(b.onWorkStarted, ah, ai)
				if not d then
					local g = e
					if not aj then
						aj = true
						ak = g
					end
				end
			end
			if aj then
				error(ak)
			end
		end
		function onWorkStopped(ah, ai)
			local aj = false
			local ak
			for b, c in ag do
				local d, e = pcall(b.onWorkStopped, ah, ai)
				if not d then
					local g = e
					if not aj then
						aj = true
						ak = g
					end
				end
			end
			if aj then
				error(ak)
			end
		end
		function onWorkCanceled(ah, ai)
			local aj = false
			local ak
			for b, c in ag do
				local d, e = pcall(b.onWorkCanceled, ah, ai)
				if not d then
					local g = e
					if not aj then
						aj = true
						ak = g
					end
				end
			end
			if aj then
				error(ak)
			end
		end
		return aa
	end
	function a.cf()
		local aa = {}
		local ab = 0
		local ac
		local ad
		local ae = -1
		local af
		local ag = -1
		local ah = false
		local ai = false
		local aj = false
		local ak = false
		local b = a.load("b5").console
		local c = a.load("b5").ConsolePatchingDev
		local d = c.disabledLog
		aa.requestHostCallback = function(e)
			ac = e
		end
		aa.cancelHostCallback = function()
			ac = nil
		end
		aa.requestHostTimeout = function(e, g)
			ad = e
			ae = ab + g
		end
		aa.cancelHostTimeout = function()
			ad = nil
			ae = -1
		end
		aa.shouldYieldToHost = function()
			local e = af
			if (ag ~= -1 and e ~= nil and #e >= ag) or (ak and aj) then
				ah = true
				return true
			end
			return false
		end
		aa.getCurrentTime = function()
			return ab
		end
		aa.forceFrameRate = function() end
		aa.reset = function()
			if ai then
				error("Cannot reset while already flushing work.")
			end
			ab = 0
			ac = nil
			ad = nil
			ae = -1
			af = nil
			ag = -1
			ah = false
			ai = false
			aj = false
		end
		aa.unstable_flushNumberOfYields = function(e)
			if ai then
				error("Already flushing work.")
			end
			if ac ~= nil then
				local g = ac
				ag = e
				ai = true
				local h, i = pcall(function()
					local h = true
					repeat
						h = g(true, ab)
					until not h or ah
					if not h then
						ac = nil
					end
				end)
				ag = -1
				ah = false
				ai = false
				if not h then
					error(i)
				end
			end
		end
		aa.unstable_flushUntilNextPaint = function()
			if ai then
				error("Already flushing work.")
			end
			if ac ~= nil then
				local e = ac
				ak = true
				aj = false
				ai = true
				local g, h = pcall(function()
					local g = true
					repeat
						g = e(true, ab)
					until not g or ah
					if not g then
						ac = nil
					end
				end)
				ak = false
				ah = false
				ai = false
				if not g then
					error(h)
				end
			end
		end
		aa.unstable_flushExpired = function()
			if ai then
				error("Already flushing work.")
			end
			if ac ~= nil then
				ai = true
				local e, g = pcall(function()
					local e = ac
					local g = e(false, ab)
					if not g then
						ac = nil
					end
				end)
				ai = false
				if not e then
					error(g)
				end
			end
		end
		aa.unstable_flushAllWithoutAsserting = function()
			if ai then
				error("Already flushing work.")
			end
			if ac ~= nil then
				local e = ac
				ai = true
				local g, h = pcall(function()
					local g = true
					repeat
						g = e(true, ab)
					until not g
					if not g then
						ac = nil
					end
				end)
				ai = false
				if not g then
					error(h)
				end
				return true
			else
				return false
			end
		end
		aa.unstable_clearYields = function()
			if af == nil then
				return {}
			end
			local e = af
			af = nil
			return e
		end
		aa.unstable_flushAll = function()
			if af ~= nil then
				error("Log is not empty. Assert on the log of yielded values before flushing additional work.")
			end
			aa.unstable_flushAllWithoutAsserting()
			if af ~= nil then
				error("While flushing work, something yielded a value. Use an assertion helper to assert on the log of yielded values, e.g. expect(Scheduler).toFlushAndYield([...])")
			end
		end
		aa.unstable_yieldValue = function(e)
			if b.log == d then
				return
			end
			if af == nil then
				af = { e }
			else
				local g = af
				table.insert(g, e)
			end
		end
		aa.unstable_advanceTime = function(e)
			if b.log == d then
				return
			end
			ab += e
			if ad ~= nil and ae <= ab then
				local g = ad
				g(ab)
				ae = -1
				ad = nil
			end
		end
		aa.requestPaint = function()
			aj = true
		end
		return aa
	end
	function a.cg()
		local aa = a.load("cd")
		local ab = a.load("ce")
		local ac = a.load("cc")
		local ad = a.load("cf")
		local ae = ac(ad)
		local af = {}
		af.tracing = {}
		for ag, ah in ae do
			af[ag] = ah
		end
		for ag, ah in aa do
			af.tracing[ag] = ah
		end
		for ag, ah in ab do
			af.tracing[ag] = ah
		end
		af.unstable_flushAllWithoutAsserting = ad.unstable_flushAllWithoutAsserting
		af.unstable_flushNumberOfYields = ad.unstable_flushNumberOfYields
		af.unstable_flushExpired = ad.unstable_flushExpired
		af.unstable_clearYields = ad.unstable_clearYields
		af.unstable_flushUntilNextPaint = ad.unstable_flushUntilNextPaint
		af.unstable_flushAll = ad.unstable_flushAll
		af.unstable_yieldValue = ad.unstable_yieldValue
		af.unstable_advanceTime = ad.unstable_advanceTime
		af.unstable_Profiling = ae.unstable_Profiling
		return af
	end
	function a.ch()
		local aa = a.load("cc")
		local function onlyInTestError(ab)
			return function()
				error(ab .. " is only available in tests, not in production")
			end
		end
		local ab = aa(nil)
		local ac = a.load("cd")
		local ad = a.load("ce")
		if _G.__ROACT_17_MOCK_SCHEDULER__ then
			return a.load("cg")
		end
		local ae = {
			unstable_ImmediatePriority = ab.unstable_ImmediatePriority,
			unstable_UserBlockingPriority = ab.unstable_UserBlockingPriority,
			unstable_NormalPriority = ab.unstable_NormalPriority,
			unstable_IdlePriority = ab.unstable_IdlePriority,
			unstable_LowPriority = ab.unstable_LowPriority,
			unstable_runWithPriority = ab.unstable_runWithPriority,
			unstable_next = ab.unstable_next,
			unstable_scheduleCallback = ab.unstable_scheduleCallback,
			unstable_cancelCallback = ab.unstable_cancelCallback,
			unstable_wrapCallback = ab.unstable_wrapCallback,
			unstable_getCurrentPriorityLevel = ab.unstable_getCurrentPriorityLevel,
			unstable_shouldYield = ab.unstable_shouldYield,
			unstable_requestPaint = ab.unstable_requestPaint,
			unstable_continueExecution = ab.unstable_continueExecution,
			unstable_pauseExecution = ab.unstable_pauseExecution,
			unstable_getFirstCallbackNode = ab.unstable_getFirstCallbackNode,
			unstable_now = ab.unstable_now,
			unstable_forceFrameRate = ab.unstable_forceFrameRate,
			unstable_flushAllWithoutAsserting = (onlyInTestError("unstable_flushAllWithoutAsserting")),
			unstable_flushAll = onlyInTestError("unstable_flushAll"),
			unstable_flushNumberOfYields = onlyInTestError("unstable_flushNumberOfYields"),
			unstable_clearYields = (onlyInTestError("unstable_clearYields")),
			unstable_flushUntilNextPaint = onlyInTestError("unstable_clearYields"),
			unstable_advanceTime = onlyInTestError("unstable_advanceTime"),
			unstable_flushExpired = onlyInTestError("unstable_flushExpired"),
			unstable_yieldValue = onlyInTestError("unstable_yieldValue"),
			tracing = { unstable_wrap = onlyInTestError("unstable_wrap"), __interactionsRef = {}, __subscriberRef = {} },
		}
		for af, ag in ac do
			ae.tracing[af] = ag
		end
		for af, ag in ad do
			ae.tracing[af] = ag
		end
		return ae
	end
	function a.ci()
		return a.load("ch")
	end
	function a.cj()
		local aa = a.load("b_")
		local ab = a.load("b0")
		local ac = a.load("b1")
		local ad = a.load("b2")
		local ae = a.load("b3")
		local af = a.load("b4")
		local ag = a.load("b0")
		local ah = a.load("ci")
		return {}
	end
	function a.ck()
		local aa = {}
		return aa
	end
	function a.cl()
		local aa = {}
		return {
			register = function(ab, ac)
				aa[ab] = ac
			end,
			get = function(ab)
				return aa[ab]
			end,
			lazy = function(ab)
				return setmetatable({}, {
					__index = function(ac, ad)
						local ae = aa[ab]
						if ae then
							return ae[ad]
						end
						return nil
					end,
					__newindex = function(ac, ad, ae)
						local af = aa[ab]
						if af then
							af[ad] = ae
						end
					end,
				})
			end,
		}
	end
	function a.cm()
		local aa = {
			ImmediatePriority = 99,
			UserBlockingPriority = 98,
			NormalPriority = 97,
			LowPriority = 96,
			IdlePriority = 95,
			NoPriority = 90,
		}
		return aa
	end
	function a.cn()
		local aa = a.load("cj")
		local ab = a.load("b0").console
		local ac = a.load("cm")
		local ad = a.load("b0").invariant
		local ae = ac.ImmediatePriority
		local af = ac.UserBlockingPriority
		local ag = ac.NormalPriority
		local ah = ac.LowPriority
		local ai = ac.IdlePriority
		local aj = ac.NoPriority
		local ak = {}
		local b = 15
		ak.SyncLanePriority = b
		local c = 14
		ak.SyncBatchedLanePriority = c
		local d = 13
		local e = 12
		ak.InputDiscreteLanePriority = e
		local g = 11
		local h = 10
		ak.InputContinuousLanePriority = h
		local i = 9
		local j = 8
		ak.DefaultLanePriority = j
		local k = 7
		local l = 6
		ak.TransitionPriority = l
		local m = 5
		local n = 4
		local o = 3
		local p = 2
		local q = 1
		local r = 0
		ak.NoLanePriority = r
		local s = 0b0
		ak.NoLanes = s
		local t = 0b0
		ak.NoLane = t
		local u = 0b1
		ak.SyncLane = u
		local v = 0b10
		ak.SyncBatchedLane = v
		local w = 0b100
		ak.InputDiscreteHydrationLane = w
		local x = 0b11000
		local y = 0b100000
		local z = 0b11000000
		local A = 0b100000000
		ak.DefaultHydrationLane = A
		local B = 0b111000000000
		ak.DefaultLanes = B
		local C = 0b1000000000000
		local D = 0b1111111110000000000000
		local E = 0b11110000000000000000000000
		ak.RetryLanes = E
		local F = 0b10000000000000000000000000
		ak.SomeRetryLane = F
		local G = 0b100000000000000000000000000
		ak.SelectiveHydrationLane = G
		local H = 0b111111111111111111111111111
		local I = 0b1000000000000000000000000000
		ak.IdleHydrationLane = I
		local J = 0b110000000000000000000000000000
		local K = 0b1000000000000000000000000000000
		ak.OffscreenLane = K
		local L = -1
		ak.NoTimestamp = L
		local M = ak.NoLanePriority
		ak.getCurrentUpdateLanePriority = function()
			return M
		end
		ak.setCurrentUpdateLanePriority = function(N)
			M = N
		end
		local N = ak.DefaultLanePriority
		local function getHighestPriorityLanes(O)
			if bit32.band(u, O) ~= s then
				N = b
				return u
			end
			if bit32.band(v, O) ~= s then
				N = c
				return v
			end
			if bit32.band(w, O) ~= s then
				N = d
				return w
			end
			local P = bit32.band(x, O)
			if P ~= s then
				N = e
				return P
			end
			if bit32.band(O, y) ~= s then
				N = g
				return y
			end
			local Q = bit32.band(z, O)
			if Q ~= s then
				N = h
				return Q
			end
			if bit32.band(O, A) ~= s then
				N = i
				return A
			end
			local R = bit32.band(B, O)
			if R ~= s then
				N = j
				return R
			end
			if bit32.band(O, C) ~= s then
				N = k
				return C
			end
			local S = bit32.band(D, O)
			if S ~= s then
				N = l
				return S
			end
			local T = bit32.band(E, O)
			if T ~= s then
				N = m
				return T
			end
			if bit32.band(O, G) ~= 0 then
				N = n
				return G
			end
			if bit32.band(O, I) ~= s then
				N = o
				return I
			end
			local U = bit32.band(J, O)
			if U ~= s then
				N = p
				return U
			end
			if bit32.band(K, O) ~= s then
				N = q
				return K
			end
			if _G.__DEV__ then
				ab.error("Should have found matching lanes. This is a bug in React.")
			end
			N = j
			return O
		end
		local function schedulerPriorityToLanePriority(O)
			if O == ae then
				return b
			elseif O == af then
				return h
			elseif O == ag or O == ah then
				return j
			elseif O == ai then
				return p
			else
				return r
			end
		end
		ak.schedulerPriorityToLanePriority = schedulerPriorityToLanePriority
		local function lanePriorityToSchedulerPriority(O)
			if O == b or O == c then
				return ae
			elseif O == d or O == e or O == g or O == h then
				return af
			elseif O == i or O == j or O == k or O == l or O == n or O == m then
				return ag
			elseif O == o or O == p or O == q then
				return ai
			elseif O == r then
				return aj
			else
				ad(false, "Invalid update priority: %s. This is a bug in React.", O)
				error("unreachable")
			end
		end
		ak.lanePriorityToSchedulerPriority = lanePriorityToSchedulerPriority
		local O, P, Q
		local function getNextLanes(R, S)
			local T = R.pendingLanes
			if T == s then
				N = r
				return s
			end
			local U = s
			local V = r
			local W = R.expiredLanes
			local X = R.suspendedLanes
			local Y = R.pingedLanes
			if W ~= s then
				U = W
				N = b
				V = b
			else
				local Z = bit32.band(T, H)
				if Z ~= s then
					local _ = bit32.band(Z, bit32.bnot(X))
					if _ ~= s then
						U = getHighestPriorityLanes(_)
						V = N
					else
						local al = bit32.band(Z, Y)
						if al ~= s then
							U = getHighestPriorityLanes(al)
							V = N
						end
					end
				else
					local al = bit32.band(T, bit32.bnot(X))
					if al ~= s then
						U = getHighestPriorityLanes(al)
						V = N
					else
						if Y ~= s then
							U = getHighestPriorityLanes(Y)
							V = N
						end
					end
				end
			end
			if U == s then
				return s
			end
			U = bit32.band(T, bit32.lshift(P(U), 1) - 1)
			if S ~= s and S ~= U and bit32.band(S, X) == s then
				getHighestPriorityLanes(S)
				local al = N
				if V <= al then
					return S
				else
					N = V
				end
			end
			local al = R.entangledLanes
			if al ~= s then
				local Z = R.entanglements
				local _ = bit32.band(U, al)
				while _ > 0 do
					local am = O(_)
					local an = bit32.lshift(1, am)
					U = bit32.bor(U, Z[am])
					_ = bit32.band(_, bit32.bnot(an))
				end
			end
			return U
		end
		ak.getNextLanes = getNextLanes
		local function getMostRecentEventTime(al, am)
			local an = al.eventTimes
			local R = L
			while am > 0 do
				local S = O(am)
				local T = bit32.lshift(1, S)
				local U = an[S]
				if U > R then
					R = U
				end
				am = bit32.band(am, bit32.bnot(T))
			end
			return R
		end
		ak.getMostRecentEventTime = getMostRecentEventTime
		local function computeExpirationTime(al, am)
			getHighestPriorityLanes(al)
			local an = N
			if an >= h then
				return am + 250
			elseif an >= l then
				return am + 5000
			else
				return L
			end
		end
		ak.computeExpirationTime = computeExpirationTime
		local function markStarvedLanesAsExpired(al, am)
			local an = al.pendingLanes
			local R = al.suspendedLanes
			local S = al.pingedLanes
			local T = al.expirationTimes
			local U = an
			while U > 0 do
				local V = O(U)
				local W = bit32.lshift(1, V)
				local X = T[V]
				if X == L then
					if bit32.band(W, R) == s or bit32.band(W, S) ~= s then
						T[V] = computeExpirationTime(W, am)
					end
				elseif X <= am then
					al.expiredLanes = bit32.bor(al.expiredLanes, W)
				end
				U = bit32.band(U, bit32.bnot(W))
			end
		end
		ak.markStarvedLanesAsExpired = markStarvedLanesAsExpired
		local function getHighestPriorityPendingLanes(al)
			return getHighestPriorityLanes(al.pendingLanes)
		end
		ak.getHighestPriorityPendingLanes = getHighestPriorityPendingLanes
		local function getLanesToRetrySynchronouslyOnError(al)
			local am = bit32.band(al.pendingLanes, bit32.bnot(K))
			if am ~= s then
				return am
			end
			if bit32.band(am, K) ~= 0 then
				return K
			end
			return s
		end
		ak.getLanesToRetrySynchronouslyOnError = getLanesToRetrySynchronouslyOnError
		local function returnNextLanesPriority()
			return N
		end
		ak.returnNextLanesPriority = returnNextLanesPriority
		local function includesNonIdleWork(al)
			return bit32.band(al, H) ~= s
		end
		ak.includesNonIdleWork = includesNonIdleWork
		local function includesOnlyRetries(al)
			return bit32.band(al, E) == al
		end
		ak.includesOnlyRetries = includesOnlyRetries
		local function includesOnlyTransitions(al)
			return bit32.band(al, D) == al
		end
		ak.includesOnlyTransitions = includesOnlyTransitions
		local al
		local function findUpdateLane(am, an)
			if am == r then
			elseif am == b then
				return u
			elseif am == c then
				return v
			elseif am == e then
				local R = al(bit32.band(x, bit32.bnot(an)))
				if R == t then
					return findUpdateLane(h, an)
				end
				return R
			elseif am == h then
				local R = al(bit32.band(z, bit32.bnot(an)))
				if R == t then
					return findUpdateLane(j, an)
				end
				return R
			elseif am == j then
				local R = al(bit32.band(B, bit32.bnot(an)))
				if R == t then
					R = al(bit32.band(D, bit32.bnot(an)))
					if R == t then
						R = al(B)
					end
				end
				return R
			elseif am == l or am == m then
			elseif am == p then
				local R = al(bit32.band(J, bit32.bnot(an)))
				if R == t then
					R = al(J)
				end
				return R
			end
			ad(false, "Invalid update priority: %s. This is a bug in React.", am)
			error("unreachable")
		end
		ak.findUpdateLane = findUpdateLane
		local function findTransitionLane(am, an)
			local R = al(bit32.band(D, bit32.bnot(an)))
			if R == t then
				R = al(bit32.band(D, bit32.bnot(am)))
				if R == t then
					R = al(D)
				end
			end
			return R
		end
		ak.findTransitionLane = findTransitionLane
		local function findRetryLane(am)
			local an = al(bit32.band(E, bit32.bnot(am)))
			if an == t then
				an = al(E)
			end
			return an
		end
		ak.findRetryLane = findRetryLane
		local function getHighestPriorityLane(am)
			return bit32.band(am, -am)
		end
		function P(am)
			local an = 31 - bit32.countlz(am)
			if an < 0 then
				return s
			else
				return bit32.lshift(1, an)
			end
		end
		function Q(am)
			return bit32.lshift(P(am), 1) - 1
		end
		function al(am)
			return getHighestPriorityLane(am)
		end
		ak.pickArbitraryLane = al
		function O(am)
			return 31 - bit32.countlz(am)
		end
		local function includesSomeLane(am, an)
			return bit32.band(am, an) ~= s
		end
		ak.includesSomeLane = includesSomeLane
		local function isSubsetOfLanes(am, an)
			return bit32.band(am, an) == an
		end
		ak.isSubsetOfLanes = isSubsetOfLanes
		local function mergeLanes(am, an)
			return bit32.bor(am, an)
		end
		ak.mergeLanes = mergeLanes
		local function removeLanes(am, an)
			return bit32.band(am, bit32.bnot(an))
		end
		ak.removeLanes = removeLanes
		local function laneToLanes(am)
			return am
		end
		ak.laneToLanes = laneToLanes
		local function higherPriorityLane(am, an)
			if am ~= t and an ~= t then
				if am < an then
					return am
				end
				return an
			else
				if am ~= t then
					return am
				end
				return an
			end
		end
		ak.higherPriorityLane = higherPriorityLane
		local function higherLanePriority(am, an)
			if am ~= r and am > an then
				return am
			else
				return an
			end
		end
		ak.higherLanePriority = higherLanePriority
		local function createLaneMap(am)
			local an = {
				[0] = am,
				[1] = am,
				[2] = am,
				[3] = am,
				[4] = am,
				[5] = am,
				[6] = am,
				[7] = am,
				[8] = am,
				[9] = am,
				[10] = am,
				[11] = am,
				[12] = am,
				[13] = am,
				[14] = am,
				[15] = am,
				[16] = am,
				[17] = am,
				[18] = am,
				[19] = am,
				[20] = am,
				[21] = am,
				[22] = am,
				[23] = am,
				[24] = am,
				[25] = am,
				[26] = am,
				[27] = am,
				[28] = am,
				[29] = am,
				[30] = am,
				[31] = am,
			}
			return an
		end
		ak.createLaneMap = createLaneMap
		local function markRootUpdated(am, an, R)
			am.pendingLanes = bit32.bor(am.pendingLanes, an)
			local S = an - 1
			am.suspendedLanes = bit32.band(am.suspendedLanes, S)
			am.pingedLanes = bit32.band(am.pingedLanes, S)
			local T = am.eventTimes
			local U = 31 - bit32.countlz(an)
			T[U] = R
		end
		ak.markRootUpdated = markRootUpdated
		local function markRootSuspended(am, an)
			am.suspendedLanes = bit32.bor(am.suspendedLanes, an)
			am.pingedLanes = bit32.band(am.pingedLanes, bit32.bnot(an))
			local R = am.expirationTimes
			local S = an
			while S > 0 do
				local T = O(S)
				local U = bit32.lshift(1, T)
				R[T] = L
				S = bit32.band(S, bit32.bnot(U))
			end
		end
		ak.markRootSuspended = markRootSuspended
		local function markRootPinged(am, an, R)
			am.pingedLanes = bit32.bor(am.pingedLanes, bit32.band(am.suspendedLanes, an))
		end
		ak.markRootPinged = markRootPinged
		local function markRootExpired(am, an)
			am.expiredLanes = bit32.bor(am.expiredLanes, bit32.band(an, am.pendingLanes))
		end
		ak.markRootExpired = markRootExpired
		local function markDiscreteUpdatesExpired(am)
			am.expiredLanes = bit32.bor(am.expiredLanes, bit32.band(x, am.pendingLanes))
		end
		ak.markDiscreteUpdatesExpired = markDiscreteUpdatesExpired
		local function hasDiscreteLanes(am)
			return bit32.band(am, x) ~= s
		end
		ak.hasDiscreteLanes = hasDiscreteLanes
		local function markRootMutableRead(am, an)
			am.mutableReadLanes = bit32.bor(am.mutableReadLanes, bit32.band(an, am.pendingLanes))
		end
		ak.markRootMutableRead = markRootMutableRead
		local function markRootFinished(am, an)
			local R = bit32.band(am.pendingLanes, bit32.bnot(an))
			am.pendingLanes = an
			am.suspendedLanes = 0
			am.pingedLanes = 0
			am.expiredLanes = bit32.band(am.expiredLanes, an)
			am.mutableReadLanes = bit32.band(am.mutableReadLanes, an)
			am.entangledLanes = bit32.band(am.entangledLanes, an)
			local S = am.entanglements
			local T = am.eventTimes
			local U = am.expirationTimes
			local V = R
			while V > 0 do
				local W = O(V)
				local X = bit32.lshift(1, W)
				S[W] = s
				T[W] = L
				U[W] = L
				V = bit32.band(V, bit32.bnot(X))
			end
		end
		ak.markRootFinished = markRootFinished
		local function markRootEntangled(am, an)
			am.entangledLanes = bit32.bor(am.entangledLanes, an)
			local R = am.entanglements
			local S = an
			while S > 0 do
				local T = O(S)
				local U = bit32.lshift(1, T)
				R[T] = bit32.bor(R[T], an)
				S = bit32.band(S, bit32.bnot(U))
			end
		end
		ak.markRootEntangled = markRootEntangled
		local function getBumpedLaneForHydration(am, an)
			getHighestPriorityLanes(an)
			local R = N
			local S
			if R == b or R == c then
				S = t
			elseif R == d or R == e then
				S = w
			elseif R == g or R == h then
				S = y
			elseif R == i or R == j then
				S = A
			elseif R == k or R == l then
				S = C
			elseif R == m then
				S = C
			elseif R == n then
				S = G
			elseif R == o or R == p then
				S = I
			elseif R == q or R == r then
				S = t
			else
				ad(false, "Invalid lane: %s. This is a bug in React.", tostring(S))
			end
			if bit32.band(S, bit32.bor(am.suspendedLanes, an)) ~= t then
				return t
			end
			return S
		end
		ak.getBumpedLaneForHydration = getBumpedLaneForHydration
		return ak
	end
	function a.co()
		local aa = a.load("b0")
		local ab = a.load("cj")
		local ac = a.load("ck")
		local ad = a.load("cn")
		local ae = a.load("b1")
		local af = ae.SuspenseComponent
		local ag = ae.SuspenseListComponent
		local ah = a.load("b3")
		local ai = ah.NoFlags
		local aj = ah.DidCapture
		local ak = {}
		ak.shouldCaptureSuspense = function(al, am)
			local an = al.memoizedState
			if an then
				if an.dehydrated ~= nil then
					return true
				end
				return false
			end
			local b = al.memoizedProps
			if b.fallback == nil then
				return false
			end
			if b.unstable_avoidThisFallback ~= true then
				return true
			end
			if am then
				return false
			end
			return true
		end
		ak.findFirstSuspended = function(al)
			local am = al
			while am ~= nil do
				if am.tag == af then
					local an = am.memoizedState
					if an then
						local b = an.dehydrated
						if b == nil or ac.isSuspenseInstancePending(b) or ac.isSuspenseInstanceFallback(b) then
							return am
						end
					end
				elseif am.tag == ag and am.memoizedProps.revealOrder ~= nil then
					local an = bit32.band(am.flags, aj) ~= ai
					if an then
						return am
					end
				elseif am.child ~= nil then
					am.child.return_ = am
					am = am.child
					continue
				end
				if am == al then
					return nil
				end
				while am.sibling == nil do
					if am.return_ == nil or am.return_ == al then
						return nil
					end
					am = am.return_
				end
				(am.sibling).return_ = am.return_
				am = am.sibling
			end
			return nil
		end
		return ak
	end
	function a.cp()
		local aa = a.load("b0").console
		local ab = a.load("cj")
		local ac = a.load("ck")
		local ad = a.load("co")
		local ae = a.load("b0").invariant
		local af = a.load("b0").ReactInstanceMap.get
		local ag = a.load("b0").ReactSharedInternals
		local ah = a.load("b0").getComponentName
		local ai = a.load("b1")
		local aj = ai.ClassComponent
		local ak = ai.HostComponent
		local al = ai.HostRoot
		local am = ai.HostPortal
		local an = ai.HostText
		local b = ai.FundamentalComponent
		local c = ai.SuspenseComponent
		local d = a.load("b3")
		local e = d.NoFlags
		local g = d.Placement
		local h = d.Hydrating
		local i = a.load("b0").ReactFeatureFlags.enableFundamentalAPI
		local j = ag.ReactCurrentOwner
		local k = {}
		local function getNearestMountedFiber(l)
			local m = l
			local n = l
			if not l.alternate then
				local o = m
				repeat
					m = o
					if bit32.band(m.flags, bit32.bor(g, h)) ~= e then
						n = m.return_
					end
					o = m.return_
				until not o
			else
				while m.return_ do
					m = m.return_
				end
			end
			if m.tag == al then
				return n
			end
			return nil
		end
		k.getNearestMountedFiber = getNearestMountedFiber
		k.getSuspenseInstanceFromFiber = function(l)
			if l.tag == c then
				local m = l.memoizedState
				if m == nil then
					local n = l.alternate
					if n ~= nil then
						m = n.memoizedState
					end
				end
				if m then
					return m.dehydrated
				end
			end
			return nil
		end
		k.getContainerFromFiber = function(l)
			return if l.tag == al then l.stateNode.containerInfo else nil
		end
		k.isFiberMounted = function(l)
			return getNearestMountedFiber(l) == l
		end
		k.isMounted = function(l)
			if _G.__DEV__ then
				local m = j.current
				if m ~= nil and m.tag == aj then
					local n = m
					local o = n.stateNode
					if not o._warnedAboutRefsInRender then
						aa.error(
							"%s is accessing isMounted inside its render() function. render() should be a pure function of props and state. It should never access something that requires stale data from the previous render, such as refs. Move this logic to componentDidMount and componentDidUpdate instead.",
							ah(n.type) or "A component"
						)
					end
					o._warnedAboutRefsInRender = true
				end
			end
			local m = af(l)
			if not m then
				return false
			else
				local n = m
				return getNearestMountedFiber(n) == m
			end
		end
		local function assertIsMounted(l)
			ae(getNearestMountedFiber(l) == l, "Unable to find node on an unmounted component.")
		end
		local function findCurrentFiberUsingSlowPath(l)
			local m = l.alternate
			if not m then
				local n = getNearestMountedFiber(l)
				ae(n ~= nil, "Unable to find node on an unmounted component.")
				if n ~= l then
					return nil
				end
				return l
			end
			local n = l
			local o = m
			while true do
				local p = n.return_
				if p == nil then
					break
				end
				local q = p.alternate
				if q == nil then
					local r = p.return_
					if r ~= nil then
						n = r
						o = r
						continue
					end
					break
				end
				if p.child == q.child then
					local r = p.child
					while r do
						if r == n then
							assertIsMounted(p)
							return l
						end
						if r == o then
							assertIsMounted(p)
							return m
						end
						r = r.sibling
					end
					ae(false, "Unable to find node on an unmounted component.")
				end
				if n.return_ ~= o.return_ then
					n = p
					o = q
				else
					local r = false
					local s = p.child
					while s do
						if s == n then
							r = true
							n = p
							o = q
							break
						end
						if s == o then
							r = true
							o = p
							n = q
							break
						end
						s = s.sibling
					end
					if not r then
						s = q.child
						while s do
							if s == n then
								r = true
								n = q
								o = p
								break
							end
							if s == o then
								r = true
								o = q
								n = p
								break
							end
							s = s.sibling
						end
						ae(
							r,
							"Child was not found in either parent set. This indicates a bug in React related to the return pointer. Please file an issue."
						)
					end
				end
				ae(
					n.alternate == o,
					"Return fibers should always be each others' alternates. This error is likely caused by a bug in React. Please file an issue."
				)
			end
			ae(n.tag == al, "Unable to find node on an unmounted component.")
			if n.stateNode.current == n then
				return l
			end
			return m
		end
		k.findCurrentFiberUsingSlowPath = findCurrentFiberUsingSlowPath
		k.findCurrentHostFiber = function(l)
			local m = findCurrentFiberUsingSlowPath(l)
			if not m then
				return nil
			end
			local n = m
			while true do
				local o = n.child
				if n.tag == ak or n.tag == an then
					return n
				elseif o then
					o.return_ = n
					n = o
					continue
				end
				if n == m then
					return nil
				end
				local p = n.return_
				local q = n.sibling
				while not q do
					if not p or p == m then
						return nil
					end
					n = p
				end
				(q).return_ = p
				n = q
			end
			return nil
		end
		k.findCurrentHostFiberWithNoPortals = function(l)
			local m = findCurrentFiberUsingSlowPath(l)
			if not m then
				return nil
			end
			local n = m
			while true do
				local o = n.child
				if n.tag == ak or n.tag == an or (i and n.tag == b) then
					return n
				elseif o and n.tag ~= am then
					o.return_ = n
					n = o
					continue
				end
				if n == m then
					return nil
				end
				local p = n.return_
				local q = n.sibling
				while not q do
					if not p or p == m then
						return nil
					end
					n = p
				end
				(q).return_ = p
				n = q
			end
			return nil
		end
		k.isFiberSuspenseAndTimedOut = function(l)
			local m = l.memoizedState
			return l.tag == c and m ~= nil and m.dehydrated == nil
		end
		k.doesFiberContain = function(l, m)
			local n = m
			local o = l.alternate
			while n ~= nil do
				if n == l or n == o then
					return true
				end
				n = n.return_
			end
			return false
		end
		return k
	end
	function a.cq()
		local aa = a.load("b0").console
		local ab = a.load("cj")
		local ac = {}
		local ad = {}
		local ae
		if _G.__DEV__ then
			ae = {}
		end
		local af = 0
		local function createCursor(ag)
			return { current = ag }
		end
		local function isEmpty()
			return af == 0
		end
		local function pop(ag, ah)
			if af < 1 then
				if _G.__DEV__ then
					aa.error("Unexpected pop.")
				end
				return
			end
			if _G.__DEV__ then
				if ah ~= ae[af] then
					aa.error("Unexpected Fiber popped.")
				end
			end
			local ai = ad[af]
			if ai == ac then
				ag.current = nil
			else
				ag.current = ai
			end
			ad[af] = nil
			if _G.__DEV__ then
				ae[af] = nil
			end
			af -= 1
		end
		local function push(ag, ah, ai)
			af += 1
			local aj = ag.current
			if aj == nil then
				ad[af] = ac
			else
				ad[af] = aj
			end
			if _G.__DEV__ then
				ae[af] = ai
			end
			ag.current = ah
		end
		local function checkThatStackIsEmpty()
			if _G.__DEV__ then
				if af ~= 0 then
					aa.error("Expected an empty stack. Something was not reset properly.")
				end
			end
		end
		local function resetStackAfterFatalErrorInDev()
			if _G.__DEV__ then
				af = 0
				table.clear(ad)
				table.clear(ae)
			end
		end
		return {
			createCursor = createCursor,
			isEmpty = isEmpty,
			pop = pop,
			push = push,
			checkThatStackIsEmpty = checkThatStackIsEmpty,
			resetStackAfterFatalErrorInDev = resetStackAfterFatalErrorInDev,
		}
	end
	function a.cr()
		local aa = _G.__DEV__
		local ab = _G.__DISABLE_ALL_WARNINGS_EXCEPT_PROP_VALIDATION__
		local ac = a.load("b_")
		local ad = ac.Object
		local ae = ac.Error
		local af = a.load("b0").console
		local ag = a.load("cj")
		local ah = a.load("cq")
		local ai = a.load("cp").isFiberMounted
		local aj = a.load("b0").ReactFeatureFlags.disableLegacyContext
		local ak = a.load("b1")
		local al = ak.ClassComponent
		local am = ak.HostRoot
		local an = a.load("b0").getComponentName
		local b = a.load("b0").checkPropTypes
		local c = ah.createCursor
		local d = ah.push
		local e = ah.pop
		local g
		if aa then
			g = {}
		end
		local h = {}
		if aa then
			ad.freeze(h)
		end
		local i = c(h)
		local j = c(false)
		local k = h
		local l
		local function getUnmaskedContext(m, n, o)
			if o and l(n) then
				return k
			end
			return i.current
		end
		local function cacheContext(m, n, o)
			local p = m.stateNode
			p.__reactInternalMemoizedUnmaskedChildContext = n
			p.__reactInternalMemoizedMaskedChildContext = o
		end
		local function getMaskedContext(m, n)
			local o = m.type
			if type(o) == "function" then
				return n
			end
			local p = o.contextTypes
			if not p then
				return h
			end
			local q = m.stateNode
			if q and q.__reactInternalMemoizedUnmaskedChildContext == n then
				return q.__reactInternalMemoizedMaskedChildContext
			end
			local r = {}
			for s, t in p do
				r[s] = n[s]
			end
			if aa or ab then
				local s = an(o) or "Unknown"
				b(p, nil, r, "context", s)
			end
			if q then
				cacheContext(m, n, r)
			end
			return r
		end
		local function hasContextChanged()
			if aj then
				return false
			else
				return j.current
			end
		end
		function l(m)
			if type(m) == "function" then
				return false
			end
			local n = m.childContextTypes
			return n ~= nil
		end
		local function popContext(m)
			e(j, m)
			e(i, m)
		end
		local function popTopLevelContextObject(m)
			e(j, m)
			e(i, m)
		end
		local function pushTopLevelContextObject(m, n, o)
			if i.current ~= h then
				error(
					ae.new("Unexpected context found on stack. This error is likely caused by a bug in React. Please file an issue.")
				)
			end
			d(i, n, m)
			d(j, o, m)
		end
		local function processChildContext(m, n, o)
			local p = m.stateNode
			local q = n.childContextTypes
			if p.getChildContext == nil or type(p.getChildContext) ~= "function" then
				if aa then
					local r = an(n) or "Unknown"
					if not g[r] then
						g[r] = true
						af.error(
							"%s.childContextTypes is specified but there is no getChildContext() method on the instance. You can either define getChildContext() on %s or remove childContextTypes from it.",
							r,
							r
						)
					end
				end
				return o
			end
			local r = p.getChildContext(p)
			for s, t in r do
				if q[s] == nil then
					local u = an(n) or "Unknown"
					error(
						ae.new(
							string.format('%s.getChildContext(): key "%s" is not defined in childContextTypes.', u, s)
						)
					)
				end
			end
			if aa or ab then
				local s = an(n) or "Unknown"
				b(q, nil, r, "child context", s)
			end
			return ad.assign({}, o, r)
		end
		local function pushContextProvider(m)
			local n = m.stateNode
			local o = (n and n.__reactInternalMemoizedMergedChildContext) or h
			k = i.current
			d(i, o, m)
			d(j, j.current, m)
			return true
		end
		local function invalidateContextProvider(m, n, o)
			local p = m.stateNode
			if not p then
				error(
					ae.new("Expected to have an instance by this point. This error is likely caused by a bug in React. Please file an issue.")
				)
			end
			if o then
				local q = processChildContext(m, n, k)
				p.__reactInternalMemoizedMergedChildContext = q
				e(j, m)
				e(i, m)
				d(i, q, m)
				d(j, o, m)
			else
				e(j, m)
				d(j, o, m)
			end
		end
		local function findCurrentUnmaskedContext(m)
			if m.tag ~= al or not ai(m) then
				error(
					ae.new("Expected subtree parent to be a mounted class component. This error is likely caused by a bug in React. Please file an issue.")
				)
			end
			local n = m
			repeat
				if n.tag == am then
					return n.stateNode.context
				elseif n.tag == al then
					local o = n.type
					if o.childContextTypes ~= nil then
						return n.stateNode.__reactInternalMemoizedMergedChildContext
					end
				end
				n = n.return_
			until n == nil
			error(
				ae.new("Found unexpected detached subtree parent. This error is likely caused by a bug in React. Please file an issue.")
			)
		end
		return {
			emptyContextObject = h,
			getUnmaskedContext = getUnmaskedContext,
			cacheContext = cacheContext,
			getMaskedContext = getMaskedContext,
			hasContextChanged = hasContextChanged,
			popContext = popContext,
			popTopLevelContextObject = popTopLevelContextObject,
			pushTopLevelContextObject = pushTopLevelContextObject,
			processChildContext = processChildContext,
			isContextProvider = l,
			pushContextProvider = pushContextProvider,
			invalidateContextProvider = invalidateContextProvider,
			findCurrentUnmaskedContext = findCurrentUnmaskedContext,
		}
	end
	function a.cs()
		local aa = a.load("b0")
		local ab = a.load("cn")
		return {}
	end
	function a.ct()
		local aa = a.load("b0").console
		local ab = a.load("b_")
		local ac = {}
		local function isCallable(ad)
			if typeof(ad) == "function" then
				return true
			end
			if typeof(ad) == "table" then
				local ae = getmetatable(ad)
				if ae and rawget(ae, "__call") then
					return true
				end
				if ad._isMockFunction then
					return true
				end
			end
			return false
		end
		local ad = a.load("b0").ReactFeatureFlags.enableProfilerTimer
		local ae = a.load("cj")
		local af = a.load("b0")
		local ag = a.load("b3").DidCapture
		local ah
		local ai
		local aj = false
		ac.isDevToolsPresent = function()
			return _G.__REACT_DEVTOOLS_GLOBAL_HOOK__ ~= nil
		end
		ac.injectInternals = function(ak)
			if _G.__REACT_DEVTOOLS_GLOBAL_HOOK__ == nil then
				return false
			end
			local al = _G.__REACT_DEVTOOLS_GLOBAL_HOOK__
			if al.isDisabled then
				return true
			end
			if not al.supportsFiber then
				if _G.__DEV__ then
					aa.error("The installed version of React DevTools is too old and will not work with the current version of React. Please update React DevTools. https://reactjs.org/link/react-devtools")
				end
				return true
			end
			local am, an = pcall(function()
				ah = al.inject(ak)
				ai = al
			end)
			if not am then
				if _G.__DEV__ then
					aa.error("React instrumentation encountered an error: %s.", an)
				end
			end
			return true
		end
		ac.onScheduleRoot = function(ak, al)
			if _G.__DEV__ then
				if ai and isCallable(ai.onScheduleFiberRoot) then
					local am, an = pcall(ai.onScheduleFiberRoot, ah, ak, al)
					if not am then
						if _G.__DEV__ and not aj then
							aj = true
							aa.error("React instrumentation encountered an error: %s", an)
						end
					end
				end
			end
		end
		ac.onCommitRoot = function(ak, al)
			if ai and isCallable(ai.onCommitFiberRoot) then
				local am, an = pcall(function()
					local am = bit32.band(ak.current.flags, ag) == ag
					if ad then
						ai.onCommitFiberRoot(ah, ak, al, am)
					else
						ai.onCommitFiberRoot(ah, ak, nil, am)
					end
				end)
				if not am then
					if _G.__DEV__ then
						if not aj then
							aj = true
							aa.error("React instrumentation encountered an error: %s", an)
						end
					end
				end
			end
		end
		ac.onCommitUnmount = function(ak)
			if ai and isCallable(ai.onCommitFiberUnmount) then
				local al, am = pcall(ai.onCommitFiberUnmount, ah, ak)
				if not al then
					if _G.__DEV__ then
						if not aj then
							aj = true
							aa.error("React instrumentation encountered an error: %s", am)
						end
					end
				end
			end
		end
		return ac
	end
	function a.cu()
		local aa = a.load("b0")
		local ab = a.load("cj")
		local ac = a.load("b0").ReactSymbols
		local ad = ac.REACT_FORWARD_REF_TYPE
		local ae
		local af
		local ag = {}
		local function resolveFunctionForHotReloading(ah)
			if _G.__DEV__ then
				if ae == nil then
					return ah
				end
				local ai = ae(ah)
				if ai == nil then
					return ah
				end
				return ai.current
			else
				return ah
			end
		end
		ag.resolveFunctionForHotReloading = resolveFunctionForHotReloading
		local function resolveClassForHotReloading(ah)
			return resolveFunctionForHotReloading(ah)
		end
		ag.resolveClassForHotReloading = resolveClassForHotReloading
		local function resolveForwardRefForHotReloading(ah)
			if _G.__DEV__ then
				if ae == nil then
					return ah
				end
				local ai = ae(ah)
				if ai == nil then
					if ah ~= nil and typeof(ah.render) == "function" then
						local aj = resolveFunctionForHotReloading(ah.render)
						if ah.render ~= aj then
							local ak = { ["$$typeof"] = ad, render = aj, displayName = nil }
							if ah.displayName ~= nil then
								ak.displayName = ah.displayName
							end
							return ak
						end
					end
					return ah
				end
				return ai.current
			else
				return ah
			end
		end
		ag.resolveForwardRefForHotReloading = resolveForwardRefForHotReloading
		ag.isCompatibleFamilyForHotReloading = function(ah, ai)
			warn("isCompatibleFamilyForHotReloading is stubbed (returns false)")
			return false
		end
		ag.markFailedErrorBoundaryForHotReloading = function(ah)
			if _G.__DEV__ then
				if ae == nil then
					return
				end
				if af == nil then
					af = {}
				end
				table.insert(af, ah)
			end
		end
		return ag
	end
	function a.cv()
		local aa = _G.__DEV__
		local ab = a.load("b_")
		local ac = ab.Object
		local ad = ab.Array
		local ae = ab.util.inspect
		local af = a.load("b0").console
		local ag = a.load("b0")
		local ah = a.load("cj")
		local ai = a.load("b4")
		local aj = a.load("b1")
		local ak = a.load("b2")
		local al = a.load("cn")
		local am = a.load("ck")
		local an = a.load("cs")
		local b = a.load("b0").invariant
		local c = a.load("b0").ReactFeatureFlags
		local d = c.enableProfilerTimer
		local e = a.load("b3")
		local g = e.NoFlags
		local h = e.Placement
		local i = e.StaticMask
		local j = ai.ConcurrentRoot
		local k = ai.BlockingRoot
		local l = aj.IndeterminateComponent
		local m = aj.ClassComponent
		local n = aj.HostRoot
		local o = aj.HostComponent
		local p = aj.HostText
		local q = aj.HostPortal
		local r = aj.ForwardRef
		local s = aj.Fragment
		local t = aj.Mode
		local u = aj.ContextProvider
		local v = aj.ContextConsumer
		local w = aj.Profiler
		local x = aj.SuspenseComponent
		local y = aj.SuspenseListComponent
		local z = aj.DehydratedFragment
		local A = aj.FunctionComponent
		local B = aj.MemoComponent
		local C = aj.SimpleMemoComponent
		local D = aj.LazyComponent
		local E = aj.FundamentalComponent
		local F = aj.ScopeComponent
		local G = aj.OffscreenComponent
		local H = aj.LegacyHiddenComponent
		local I = a.load("b0").getComponentName
		local J = a.load("ct")
		local K = J.isDevToolsPresent
		local L = a.load("cu")
		local M = L.resolveClassForHotReloading
		local N = L.resolveFunctionForHotReloading
		local O = L.resolveForwardRefForHotReloading
		local P = al.NoLanes
		local Q = ak.NoMode
		local R = ak.ConcurrentMode
		local S = ak.DebugTracingMode
		local T = ak.ProfileMode
		local U = ak.StrictMode
		local V = ak.BlockingMode
		local W = a.load("b0").ReactSymbols
		local X = W.REACT_FORWARD_REF_TYPE
		local Y = W.REACT_FRAGMENT_TYPE
		local Z = W.REACT_ELEMENT_TYPE
		local _ = W.REACT_DEBUG_TRACING_MODE_TYPE
		local ao = W.REACT_STRICT_MODE_TYPE
		local ap = W.REACT_PROFILER_TYPE
		local aq = W.REACT_PROVIDER_TYPE
		local ar = W.REACT_CONTEXT_TYPE
		local as = W.REACT_SUSPENSE_TYPE
		local au = W.REACT_SUSPENSE_LIST_TYPE
		local av = W.REACT_MEMO_TYPE
		local aw = W.REACT_LAZY_TYPE
		local ax = W.REACT_OFFSCREEN_TYPE
		local ay = W.REACT_LEGACY_HIDDEN_TYPE
		local az, aA, aB, aC, aD, aE, aF, aG
		local aH = 1
		local function createFiber(aI, aJ, aK, aL, aM, aN, aO, aP)
			local aQ = {
				tag = aI,
				key = aK,
				elementType = aM,
				type = aN,
				stateNode = aO,
				index = 1,
				pendingProps = aJ,
				mode = aL,
				flags = g,
				subtreeFlags = g,
				lanes = if aP then aP else P,
				childLanes = P,
			}
			if d then
				aQ.actualDuration = 0
				aQ.actualStartTime = -1
				aQ.selfBaseDuration = 0
				aQ.treeBaseDuration = 0
			end
			if aa then
				aQ._debugID = aH
				aH += 1
				aQ._debugSource = nil
				aQ._debugOwner = nil
				aQ._debugNeedsRemount = false
				aQ._debugHookTypes = nil
			end
			return aQ
		end
		function _shouldConstruct(aI)
			return type(aI) ~= "function" and not not aI.isReactComponent
		end
		local function isSimpleFunctionComponent(aI)
			return type(aI) == "function"
		end
		local function resolveLazyComponentTag(aI)
			local aJ = typeof(aI)
			if aJ == "function" then
				return A
			end
			if aJ == "table" then
				if aI.isReactComponent then
					return m
				end
				local aK = aI["$$typeof"]
				if aK == X then
					return r
				end
				if aK == av then
					return B
				end
			end
			return l
		end
		local function createWorkInProgress(aI, aJ)
			local aK = aI.alternate
			if aK == nil then
				aK = createFiber(aI.tag, aJ, aI.key, aI.mode, aI.elementType, aI.type, aI.stateNode)
				if aa then
					aK._debugID = aI._debugID
					aK._debugSource = aI._debugSource
					aK._debugOwner = aI._debugOwner
					aK._debugHookTypes = aI._debugHookTypes
				end
				aK.alternate = aI
				aI.alternate = aK
			else
				aK.pendingProps = aJ
				aK.type = aI.type
				aK.flags = g
				aK.subtreeFlags = g
				aK.deletions = nil
				if d then
					aK.actualDuration = 0
					aK.actualStartTime = -1
				end
			end
			aK.flags = bit32.band(aI.flags, i)
			aK.childLanes = aI.childLanes
			aK.lanes = aI.lanes
			aK.child = aI.child
			aK.memoizedProps = aI.memoizedProps
			aK.memoizedState = aI.memoizedState
			aK.updateQueue = aI.updateQueue
			local aL = aI.dependencies
			if aL == nil then
				aK.dependencies = nil
			else
				aK.dependencies = { lanes = aL.lanes, firstContext = aL.firstContext }
			end
			aK.sibling = aI.sibling
			aK.index = aI.index
			aK.ref = aI.ref
			if d then
				aK.selfBaseDuration = aI.selfBaseDuration
				aK.treeBaseDuration = aI.treeBaseDuration
			end
			if aa then
				aK._debugNeedsRemount = aI._debugNeedsRemount
				if aK.tag == l or aK.tag == A or aK.tag == C then
					aK.type = N(aI.type)
				elseif aK.tag == m then
					aK.type = M(aI.type)
				elseif aK.tag == r then
					aK.type = O(aI.type)
				end
			end
			return aK
		end
		local function resetWorkInProgress(aI, aJ)
			aI.flags = bit32.band(aI.flags, bit32.bor(i, h))
			local aK = aI.alternate
			if aK == nil then
				aI.childLanes = P
				aI.lanes = aJ
				aI.child = nil
				aI.subtreeFlags = g
				aI.memoizedProps = nil
				aI.memoizedState = nil
				aI.updateQueue = nil
				aI.dependencies = nil
				aI.stateNode = nil
				if d then
					aI.selfBaseDuration = 0
					aI.treeBaseDuration = 0
				end
			else
				aI.childLanes = aK.childLanes
				aI.lanes = aK.lanes
				aI.child = aK.child
				aI.subtreeFlags = aK.subtreeFlags
				aI.deletions = nil
				aI.memoizedProps = aK.memoizedProps
				aI.memoizedState = aK.memoizedState
				aI.updateQueue = aK.updateQueue
				aI.type = aK.type
				local aL = aK.dependencies
				if aL == nil then
					aI.dependencies = nil
				else
					aI.dependencies = { lanes = aL.lanes, firstContext = aL.firstContext }
				end
				if d then
					aI.selfBaseDuration = aK.selfBaseDuration
					aI.treeBaseDuration = aK.treeBaseDuration
				end
			end
			return aI
		end
		local function createHostRootFiber(aI)
			local aJ
			if aI == j then
				aJ = bit32.bor(R, V, U)
			elseif aI == k then
				aJ = bit32.bor(V, U)
			else
				aJ = Q
			end
			if d and K() then
				aJ = bit32.bor(aJ, T)
			end
			return createFiber(n, nil, nil, aJ)
		end
		local function createFiberFromTypeAndProps(aI, aJ, aK, aL, aM, aN)
			local aO = l
			local aP = aI
			local aQ = type(aI)
			if aQ == "function" then
				if aa then
					aP = N(aP)
				end
			elseif aQ == "table" and not not aI.isReactComponent then
				aO = m
				if aa then
					aP = M(aP)
				end
			elseif aQ == "string" then
				aO = o
			else
				if aI == Y then
					return aB(aK.children, aM, aN, aJ)
				elseif aI == _ then
					aO = t
					aM = bit32.bor(aM, S)
				elseif aI == ao then
					aO = t
					aM = bit32.bor(aM, U)
				elseif aI == ap then
					return aA(aK, aM, aN, aJ)
				elseif aI == as then
					return aD(aK, aM, aN, aJ)
				elseif aI == ax then
					return aE(aK, aM, aN, aJ)
				elseif aI == ay then
					return aF(aK, aM, aN, aJ)
				else
					local aR = false
					local aS
					if aQ == "table" then
						aS = aI["$$typeof"]
						if aS == aq then
							aO = u
							aR = true
						elseif aS == ar then
							aO = v
							aR = true
						elseif aS == X then
							aO = r
							if aa then
								aP = O(aP)
							end
							aR = true
						elseif aS == av then
							aO = B
							aR = true
						elseif aS == aw then
							aO = D
							aP = nil
							aR = true
						end
					end
					if not aR then
						local aT = ""
						if aa then
							if aI == nil or (aQ == "table" and #ac.keys(aI) == 0) then
								aT ..= " You likely forgot to export your component from the file it's defined in, or you might have mixed up default and named imports."
							elseif aI ~= nil and aQ == "table" then
								aT ..= "\n" .. ae(aI)
							end
							local aU
							if aL then
								aU = I(aL.type)
							end
							if aU ~= nil and aU ~= "" then
								aT ..= "\n\nCheck the render method of `" .. aU .. "`."
							elseif aL then
								aT ..= "\n" .. ae(aL)
							end
						end
						local aU
						if aI == nil then
							aU = "nil"
						elseif ad.isArray(aI) then
							aU = "array"
						elseif aQ == "table" and aS == Z then
							aU = string.format("<%s />", I(aI.type) or "Unknown")
							aT = " Did you accidentally export a JSX literal or Element instead of a component?"
						else
							aU = aQ
						end
						b(
							false,
							"Element type is invalid: expected a string (for built-in components) or a class/function (for composite components) but got: %s.%s",
							aU,
							aT
						)
					end
				end
			end
			local aR = createFiber(aO, aK, aJ, aM, aI, aP, nil, aN)
			if aa then
				aR._debugOwner = aL
			end
			return aR
		end
		local function createFiberFromElement(aI, aJ, aK)
			local aL
			if aa then
				aL = aI._owner
			end
			local aM = aI.type
			local aN = aI.key
			local aO = aI.props
			local aP = createFiberFromTypeAndProps(aM, aN, aO, aL, aJ, aK)
			if aa then
				aP._debugSource = aI._source
				aP._debugOwner = aI._owner
			end
			return aP
		end
		function aB(aI, aJ, aK, aL)
			local aM = createFiber(s, aI, aL, aJ, nil, nil, nil, aK)
			return aM
		end
		function aC(aI, aJ, aK, aL, aM)
			local aN = createFiber(E, aJ, aM, aK, aI, aI, nil, aL)
			return aN
		end
		function az(aI, aJ, aK, aL, aM)
			local aN = createFiber(F, aJ, aM, aK, aI, aI, nil, aL)
			return aN
		end
		function aA(aI, aJ, aK, aL)
			if aa then
				if typeof(aI.id) ~= "string" then
					af.error('Profiler must specify an "id" as a prop')
				end
			end
			local aM = createFiber(
				w,
				aI,
				aL,
				bit32.bor(aJ, T),
				ap,
				ap,
				if d then { effectDuration = 0, passiveEffectDuration = 0 } else nil,
				aK
			)
			return aM
		end
		function aD(aI, aJ, aK, aL)
			local aM = createFiber(x, aI, aL, aJ, as, as, nil, aK)
			return aM
		end
		function aG(aI, aJ, aK, aL)
			local aM = createFiber(y, aI, aL, aJ, au, if aa then au else nil, nil, aK)
			return aM
		end
		function aE(aI, aJ, aK, aL)
			local aM = createFiber(G, aI, aL, aJ, ax, if aa then ax else nil, nil, aK)
			return aM
		end
		function aF(aI, aJ, aK, aL)
			local aM = createFiber(H, aI, aL, aJ, ay, if aa then ay else nil, nil, aK)
			return aM
		end
		local function createFiberFromText(aI, aJ, aK)
			local aL = createFiber(p, aI, nil, aJ, nil, nil, nil, aK)
			return aL
		end
		local function createFiberFromHostInstanceForDeletion()
			local aI = createFiber(o, nil, nil, Q, "DELETED", "DELETED")
			return aI
		end
		local function createFiberFromDehydratedFragment(aI)
			local aJ = createFiber(z, nil, nil, Q, nil, nil, aI)
			return aJ
		end
		local function createFiberFromPortal(aI, aJ, aK)
			local aL = if aI.children ~= nil then aI.children else {}
			local aM = createFiber(
				q,
				aL,
				aI.key,
				aJ,
				nil,
				nil,
				{ containerInfo = aI.containerInfo, pendingChildren = nil, implementation = aI.implementation },
				aK
			)
			return aM
		end
		local function assignFiberPropertiesInDEV(aI, aJ)
			if aI == nil then
				aI = createFiber(l, nil, nil, Q)
			end
			aI.tag = aJ.tag
			aI.key = aJ.key
			aI.elementType = aJ.elementType
			aI.type = aJ.type
			aI.stateNode = aJ.stateNode
			aI.return_ = aJ.return_
			aI.child = aJ.child
			aI.sibling = aJ.sibling
			aI.index = aJ.index
			aI.ref = aJ.ref
			aI.pendingProps = aJ.pendingProps
			aI.memoizedProps = aJ.memoizedProps
			aI.updateQueue = aJ.updateQueue
			aI.memoizedState = aJ.memoizedState
			aI.dependencies = aJ.dependencies
			aI.mode = aJ.mode
			aI.flags = aJ.flags
			aI.subtreeFlags = aJ.subtreeFlags
			aI.deletions = aJ.deletions
			aI.lanes = aJ.lanes
			aI.childLanes = aJ.childLanes
			aI.alternate = aJ.alternate
			if d then
				aI.actualDuration = aJ.actualDuration
				aI.actualStartTime = aJ.actualStartTime
				aI.selfBaseDuration = aJ.selfBaseDuration
				aI.treeBaseDuration = aJ.treeBaseDuration
			end
			aI._debugID = aJ._debugID
			aI._debugSource = aJ._debugSource
			aI._debugOwner = aJ._debugOwner
			aI._debugNeedsRemount = aJ._debugNeedsRemount
			aI._debugHookTypes = aJ._debugHookTypes
			return aI
		end
		return {
			isSimpleFunctionComponent = isSimpleFunctionComponent,
			resolveLazyComponentTag = resolveLazyComponentTag,
			createWorkInProgress = createWorkInProgress,
			resetWorkInProgress = resetWorkInProgress,
			createHostRootFiber = createHostRootFiber,
			createFiberFromTypeAndProps = createFiberFromTypeAndProps,
			createFiberFromElement = createFiberFromElement,
			createFiberFromFragment = aB,
			createFiberFromFundamental = aC,
			createFiberFromSuspense = aD,
			createFiberFromSuspenseList = aG,
			createFiberFromOffscreen = aE,
			createFiberFromLegacyHidden = aF,
			createFiberFromText = createFiberFromText,
			createFiberFromHostInstanceForDeletion = createFiberFromHostInstanceForDeletion,
			createFiberFromDehydratedFragment = createFiberFromDehydratedFragment,
			createFiberFromPortal = createFiberFromPortal,
			assignFiberPropertiesInDEV = assignFiberPropertiesInDEV,
		}
	end
	function a.cw()
		local aa = a.load("cn")
		local ab = aa.NoLanes
		local ac = aa.mergeLanes
		local ad = {}
		ad.workInProgressRootSkippedLanes = function(ae)
			if ae == nil then
				return ab
			end
			ab = ae
			return ab
		end
		ad.markSkippedUpdateLanes = function(ae)
			ab = ac(ae, ab)
		end
		return ad
	end
	function a.cx()
		local aa = _G.__DEV__
		local ab = _G.__YOLO__
		local ac = a.load("b_")
		local ad = ac.Object
		local ae = a.load("b0").console
		local af = a.load("cj")
		local ag = a.load("cn")
		local ah = ag.NoLane
		local ai = ag.NoLanes
		local aj = ag.isSubsetOfLanes
		local ak = ag.mergeLanes
		local al
		local function enterDisallowedContextReadInDEV()
			if not al then
				al = a.load("cl").lazy("ReactFiberNewContext")
			end
			al.enterDisallowedContextReadInDEV()
		end
		local function exitDisallowedContextReadInDEV()
			if not al then
				al = a.load("cl").lazy("ReactFiberNewContext")
			end
			al.exitDisallowedContextReadInDEV()
		end
		local am = a.load("b3")
		local an = am.Callback
		local ao = am.ShouldCapture
		local ap = am.DidCapture
		local aq = a.load("b0").ReactFeatureFlags
		local ar = aq.debugRenderPhaseSideEffectsForStrictMode
		local as = a.load("b2")
		local au = as.StrictMode
		local av = a.load("cw").markSkippedUpdateLanes
		local aw = a.load("b0").describeError
		local ax = a.load("b0").ConsolePatchingDev
		local ay = ax.disableLogs
		local az = ax.reenableLogs
		local aA = {}
		local aB = 0
		aA.UpdateState = aB
		local aC = 1
		aA.ReplaceState = aC
		local aD = 2
		aA.ForceUpdate = aD
		local aE = 3
		aA.CaptureUpdate = aE
		local aF = false
		local aG
		local aH
		if aa then
			aG = false
			aH = nil
			aA.resetCurrentlyProcessingQueue = function()
				aH = nil
			end
		end
		local aI = 210
		local aJ = table.create(aI)
		local aK = aI
		for aL = 1, aI do
			aJ[aL] = { eventTime = -1, lane = -1, tag = -1, payload = nil, callback = nil, next = nil }
		end
		local function initializeUpdateQueue(aL)
			local aM = {
				baseState = aL.memoizedState,
				firstBaseUpdate = nil,
				lastBaseUpdate = nil,
				shared = { pending = nil },
				effects = nil,
			}
			aL.updateQueue = aM
		end
		aA.initializeUpdateQueue = initializeUpdateQueue
		local function cloneUpdateQueue(aL, aM)
			local aN = aM.updateQueue
			local aO = aL.updateQueue
			if aN == aO then
				local aP = table.clone(aO)
				aM.updateQueue = aP
			end
		end
		aA.cloneUpdateQueue = cloneUpdateQueue
		local function createUpdate(aL, aM, aN, aO)
			if aK > 0 then
				local aP = aJ[aK]
				aJ[aK] = nil
				aK -= 1
				aP.eventTime = aL
				aP.lane = aM
				aP.tag = aB
				aP.payload = aN
				aP.callback = aO
				return aP
			end
			local aP = { eventTime = aL, lane = aM, tag = aB, payload = aN, callback = aO, next = nil }
			return aP
		end
		aA.createUpdate = createUpdate
		local function enqueueUpdate(aL, aM)
			local aN = aL.updateQueue
			if aN == nil then
				return
			end
			local aO = (aN).shared
			local aP = aO.pending
			if aP == nil then
				aM.next = aM
			else
				aM.next = aP.next
				aP.next = aM
			end
			aO.pending = aM
			if aa then
				if aH == aO and not aG then
					ae.error("An update (setState, replaceState, or forceUpdate) was scheduled from inside an update function. Update functions should be pure, with zero side-effects. Consider using componentDidUpdate or a callback.")
					aG = true
				end
			end
		end
		aA.enqueueUpdate = enqueueUpdate
		local function enqueueCapturedUpdate(aL, aM)
			local aN = aL.updateQueue
			local aO = aL.alternate
			if aO ~= nil then
				local aP = aO.updateQueue
				if aN == aP then
					local aQ
					local aR
					local aS = aN.firstBaseUpdate
					if aS ~= nil then
						local aT = aS
						repeat
							local aU = {
								eventTime = aT.eventTime,
								lane = aT.lane,
								tag = aT.tag,
								payload = aT.payload,
								callback = aT.callback,
								next = nil,
							}
							if aR == nil then
								aR = aU
								aQ = aU
							else
								aR.next = aU
								aR = aU
							end
							aT = aT.next
						until aT == nil
						if aR == nil then
							aR = aM
							aQ = aM
						else
							aR.next = aM
							aR = aM
						end
					else
						aR = aM
						aQ = aM
					end
					aN = {
						baseState = aP.baseState,
						firstBaseUpdate = aQ,
						lastBaseUpdate = aR,
						shared = aP.shared,
						effects = aP.effects,
					}
					aL.updateQueue = aN
					return
				end
			end
			local aP = aN.lastBaseUpdate
			if aP == nil then
				aN.firstBaseUpdate = aM
			else
				aP.next = aM
			end
			aN.lastBaseUpdate = aM
		end
		aA.enqueueCapturedUpdate = enqueueCapturedUpdate
		local function getStateFromUpdate(aL, aM, aN, aO, aP, aQ)
			local aR = aN.tag
			if aR == aC then
				local aS = aN.payload
				if type(aS) == "function" then
					if aa then
						enterDisallowedContextReadInDEV()
					end
					local aT = aS(aO, aP)
					if aa then
						if ar and bit32.band(aL.mode, au) ~= 0 then
							ay()
							local aU, b
							if not ab then
								aU, b = xpcall(aS, aw, aO, aP)
							else
								aU = true
								aS(aO, aP)
							end
							az()
							if not aU then
								error(b)
							end
						end
						exitDisallowedContextReadInDEV()
					end
					return aT
				end
				return aS
			elseif aR == aE or aR == aB then
				if aR == aE then
					aL.flags = bit32.bor(bit32.band(aL.flags, bit32.bnot(ao)), ap)
				end
				local aS = aN.payload
				local aT
				if type(aS) == "function" then
					if aa then
						enterDisallowedContextReadInDEV()
					end
					aT = aS(aO, aP)
					if aa then
						if ar and bit32.band(aL.mode, au) ~= 0 then
							ay()
							local aU, b
							if not ab then
								aU, b = xpcall(aS, aw, aO, aP)
							else
								aU = true
								aS(aO, aP)
							end
							az()
							if not aU then
								error(b)
							end
						end
						exitDisallowedContextReadInDEV()
					end
				else
					aT = aS
				end
				if aT == nil then
					return aO
				end
				return ad.assign({}, aO, aT)
			elseif aR == aD then
				aF = true
				return aO
			end
			return aO
		end
		aA.getStateFromUpdate = getStateFromUpdate
		local function processUpdateQueue(aL, aM, aN, aO)
			local aP = aL.updateQueue
			aF = false
			if aa then
				aH = aP.shared
			end
			local aQ = aP.firstBaseUpdate
			local aR = aP.lastBaseUpdate
			local aS = aP.shared.pending
			if aS ~= nil then
				aP.shared.pending = nil
				local aT = aS
				local aU = aT.next
				aT.next = nil
				if aR == nil then
					aQ = aU
				else
					aR.next = aU
				end
				aR = aT
				local b = aL.alternate
				if b ~= nil then
					local c = b.updateQueue
					local d = c.lastBaseUpdate
					if d ~= aR then
						if d == nil then
							c.firstBaseUpdate = aU
						else
							d.next = aU
						end
						c.lastBaseUpdate = aT
					end
				end
			end
			if aQ ~= nil then
				local aT = aP.baseState
				local aU = ai
				local b
				local c
				local d
				local e = aQ
				while true do
					local g = e.lane
					local h = e.eventTime
					if not aj(aO, g) then
						local i = {
							eventTime = h,
							lane = g,
							tag = e.tag,
							payload = e.payload,
							callback = e.callback,
							next = nil,
						}
						if d == nil then
							c = i
							d = i
							b = aT
						else
							d.next = i
							d = i
						end
						aU = ak(aU, g)
					else
						if d ~= nil then
							local i =
								{ eventTime = h, lane = ah, tag = e.tag, payload = e.payload, callback = e.callback, next = nil }
							d.next = i
							d = i
						end
						aT = getStateFromUpdate(aL, aP, e, aT, aM, aN)
						local i = e.callback
						if i ~= nil and e.lane ~= ah then
							aL.flags = bit32.bor(aL.flags, an)
							local j = aP.effects
							if j == nil then
								aP.effects = { e }
							else
								table.insert(j, e)
							end
						end
					end
					e = e.next
					if e == nil then
						aS = aP.shared.pending
						if aS == nil then
							break
						else
							local i = aS
							local j = i.next
							i.next = nil
							e = j
							aP.lastBaseUpdate = i
							aP.shared.pending = nil
						end
					end
				end
				if d == nil then
					b = aT
				end
				aP.baseState = b
				aP.firstBaseUpdate = c
				aP.lastBaseUpdate = d
				av(aU)
				aL.lanes = aU
				aL.memoizedState = aT
			end
			if aa then
				aH = nil
			end
		end
		aA.processUpdateQueue = processUpdateQueue
		local function callCallback(aL, aM)
			if type(aL) ~= "function" then
				error(
					string.format(
						"Invalid argument passed as callback. Expected a function. Instead received: %s",
						tostring(aL)
					)
				)
			end
			aL(aM)
		end
		aA.resetHasForceUpdateBeforeProcessing = function()
			aF = false
		end
		aA.checkHasForceUpdateAfterProcessing = function()
			return aF
		end
		local function commitUpdateQueue(aL, aM, aN)
			local aO = aM.effects
			aM.effects = nil
			if aO ~= nil then
				for aP, aQ in aO do
					local aR = aQ.callback
					if aR ~= nil then
						callCallback(aR, aN)
					end
					table.clear(aQ)
					table.insert(aJ, aQ)
					aK += 1
				end
			end
		end
		aA.commitUpdateQueue = commitUpdateQueue
		return aA
	end
	function a.cy()
		local aa = a.load("b_")
		local ab = aa.Set
		local ac = aa.Map
		local ad = a.load("cj")
		local ae = a.load("b4")
		local af = a.load("ck")
		local ag = a.load("cv")
		local ah = ag.createHostRootFiber
		local ai = a.load("cn")
		local aj = ai.NoLanes
		local ak = ai.NoLanePriority
		local al = ai.NoTimestamp
		local am = ai.createLaneMap
		local an = a.load("b0").ReactFeatureFlags
		local ao = an.enableSchedulerTracing
		local ap = an.enableSuspenseCallback
		local aq = a.load("ci").tracing
		local ar = aq.unstable_getThreadID
		local as = a.load("cx")
		local au = as.initializeUpdateQueue
		local av = ae.LegacyRoot
		local aw = ae.BlockingRoot
		local ax = ae.ConcurrentRoot
		local ay = {}
		local function FiberRootNode(az, aA, aB)
			local aC = {
				tag = aA,
				containerInfo = az,
				pendingChildren = nil,
				current = nil,
				pingCache = nil,
				finishedWork = nil,
				timeoutHandle = af.noTimeout,
				context = nil,
				pendingContext = nil,
				hydrate = aB,
				callbackNode = nil,
				callbackPriority = ak,
				eventTimes = am(aj),
				expirationTimes = am(al),
				pendingLanes = aj,
				suspendedLanes = aj,
				pingedLanes = aj,
				expiredLanes = aj,
				mutableReadLanes = aj,
				finishedLanes = aj,
				entangledLanes = aj,
				entanglements = am(aj),
			}
			if af.supportsHydration then
				aC.mutableSourceEagerHydrationData = nil
			end
			if ao then
				aC.interactionThreadID = ar()
				aC.memoizedInteractions = ab.new()
				aC.pendingInteractionMap = ac.new()
			end
			if ap then
				aC.hydrationCallbacks = nil
			end
			if _G.__DEV__ then
				if aA == aw then
					aC._debugRootType = "createBlockingRoot()"
				elseif aA == ax then
					aC._debugRootType = "createRoot()"
				elseif aA == av then
					aC._debugRootType = "createLegacyRoot()"
				end
			end
			return aC
		end
		ay.createFiberRoot = function(az, aA, aB, aC)
			local aD = FiberRootNode(az, aA, aB)
			if ap then
				aD.hydrationCallbacks = aC
			end
			local aE = ah(aA)
			aD.current = aE
			aE.stateNode = aD
			au(aE)
			return aD
		end
		return ay
	end
	function a.cz()
		local aa = a.load("b_")
		local ab = aa.Array
		local ac = a.load("cj")
		local ad = a.load("ci")
		local ae = a.load("b0").ReactFeatureFlags
		local af = ae.decoupleUpdatePriorityFromScheduler
		local ag = a.load("b0").invariant
		local ah = a.load("b0").describeError
		local ai = a.load("cn")
		local aj = ai.SyncLanePriority
		local ak = ai.getCurrentUpdateLanePriority
		local al = ai.setCurrentUpdateLanePriority
		local am = ad.unstable_runWithPriority
		local an = ad.unstable_scheduleCallback
		local ao = ad.unstable_cancelCallback
		local ap = ad.unstable_shouldYield
		local aq = ad.unstable_requestPaint
		local ar = ad.unstable_now
		local as = ad.unstable_getCurrentPriorityLevel
		local au = ad.unstable_ImmediatePriority
		local av = ad.unstable_UserBlockingPriority
		local aw = ad.unstable_NormalPriority
		local ax = ad.unstable_LowPriority
		local ay = ad.unstable_IdlePriority
		local az = a.load("cm")
		local aA = az.ImmediatePriority
		local aB = az.UserBlockingPriority
		local aC = az.NormalPriority
		local aD = az.LowPriority
		local aE = az.IdlePriority
		local aF = az.NoPriority
		local aG
		local aH = {}
		local aI = ap
		local aJ
		if aq ~= nil then
			aJ = aq
		else
			aJ = function() end
		end
		local aK
		local aL
		local aM = false
		local aN = ar()
		local function now()
			return ar() - aN
		end
		local function getCurrentPriorityLevel()
			local aO = as()
			if aO == au then
				return aA
			elseif aO == av then
				return aB
			elseif aO == aw then
				return aC
			elseif aO == ax then
				return aD
			elseif aO == ay then
				return aE
			else
				ag(false, "Unknown priority level.")
				return aF
			end
		end
		function reactPriorityToSchedulerPriority(aO)
			if aO == aA then
				return au
			elseif aO == aB then
				return av
			elseif aO == aC then
				return aw
			elseif aO == aD then
				return ax
			elseif aO == aE then
				return ay
			else
				ag(false, "Unknown priority level.")
				return nil
			end
		end
		local function runWithPriority(aO, aP)
			local aQ = reactPriorityToSchedulerPriority(aO)
			return am(aQ, aP)
		end
		local function scheduleCallback(aO, aP, aQ)
			local aR = reactPriorityToSchedulerPriority(aO)
			return an(aR, aP, aQ)
		end
		local function scheduleSyncCallback(aO)
			if aK == nil then
				aK = { aO }
				aL = an(au, aG)
			else
				local aP = aK
				table.insert(aP, aO)
			end
			return aH
		end
		local function cancelCallback(aO)
			if aO ~= aH then
				ao(aO)
			end
		end
		local function flushSyncCallbackQueue()
			if aL ~= nil then
				local aO = aL
				aL = nil
				ao(aO)
			end
			return aG()
		end
		aG = function()
			if not aM and aK ~= nil then
				aM = true
				local aO = 1
				if af then
					local aP = ak()
					local aQ = true
					local aR
					if not _G.__YOLO__ then
						local aS = true
						local aT = aK
						al(aj)
						aQ, aR = xpcall(runWithPriority, ah, aA, function()
							for aU, b in aT do
								aO = aU
								repeat
									b = (b(aS))
								until b == nil
							end
						end)
						aK = nil
					else
						aQ = true
						local aS = true
						local aT = aK
						al(aj)
						runWithPriority(aA, function()
							for aU, b in aT do
								aO = aU
								repeat
									b = (b(aS))
								until b == nil
								aO += 1
							end
						end)
						aK = nil
					end
					al(aP)
					aM = false
					if not aQ then
						if aK ~= nil then
							aK = ab.slice(aK, aO + 1)
						end
						an(au, flushSyncCallbackQueue)
						error(aR)
					end
				else
					local aP, aQ
					if not _G.__YOLO__ then
						local aR = true
						local aS = aK
						aP, aQ = xpcall(runWithPriority, ah, aA, function()
							for aT, aU in aS do
								aO = aT
								repeat
									aU = (aU(aR))
								until aU == nil
							end
						end)
						aK = nil
					else
						aP = true
						local aR = true
						local aS = aK
						runWithPriority(aA, function()
							for aT, aU in aS do
								aO = aT
								repeat
									aU = (aU(aR))
								until aU == nil
							end
						end)
						aK = nil
					end
					aM = false
					if not aP then
						if aK ~= nil then
							aK = ab.slice(aK, aO + 1)
						end
						an(au, flushSyncCallbackQueue)
						error(aQ)
					end
				end
				return true
			else
				return false
			end
		end
		return {
			ImmediatePriority = aA,
			UserBlockingPriority = aB,
			NormalPriority = aC,
			LowPriority = aD,
			IdlePriority = aE,
			NoPriority = aF,
			getCurrentPriorityLevel = getCurrentPriorityLevel,
			flushSyncCallbackQueue = flushSyncCallbackQueue,
			runWithPriority = runWithPriority,
			scheduleCallback = scheduleCallback,
			scheduleSyncCallback = scheduleSyncCallback,
			cancelCallback = cancelCallback,
			now = now,
			requestPaint = aJ,
			shouldYield = aI,
		}
	end
	function a.cA()
		local aa = a.load("b0")
		local ab = aa.console
		local ac = {}
		local ad
		local ae = a.load("cn")
		local af = a.load("b0").ReactFeatureFlags.enableDebugTracing
		local ag = ab
		local ah
		local ai = {}
		local aj = 0
		function decimalToBinaryString(ak)
			local al = ""
			repeat
				local am = ak / 2
				local an, ao = math.modf(am)
				ak = an
				al = math.ceil(ao) .. al
			until ak == 0
			local am = 31 - string.len(al)
			return string.rep("0", am) .. al
		end
		local function formatLanes(ak)
			return "0b" .. decimalToBinaryString(ak)
		end
		local function group(...)
			for ak, al in { ... } do
				table.insert(ai, al)
			end
			if ah == nil then
				ah = ag.log
				ag.log = ad
			end
		end
		local function groupEnd()
			table.remove(ai, 1)
			while aj > #ai do
				ag.groupEnd()
				aj -= 1
			end
			if #ai == 0 then
				ag.log = ah
				ah = nil
			end
		end
		function ad(...)
			if aj < #ai then
				for ak = aj + 1, #ai do
					local al = ai[ak]
					ag.group(al)
				end
				aj = #ai
			end
			if typeof(ah) == "function" then
				(ah)(...)
			else
				ag.log(...)
			end
		end
		local ak = ""
		local function logCommitStarted(al)
			if _G.__DEV__ then
				if af then
					group(string.format("* commit (%s)", formatLanes(al)), ak, "", "")
				end
			end
		end
		ac.logCommitStarted = logCommitStarted
		local function logCommitStopped()
			if _G.__DEV__ then
				if af then
					groupEnd()
				end
			end
		end
		ac.logCommitStopped = logCommitStopped
		local function logComponentSuspended(al, am)
			if _G.__DEV__ then
				if af then
					ad(string.format("* %s suspended", al))
					am.andThen(am, function()
						ad(string.format("* %s resolved", al))
					end, function()
						ad(string.format("* %s rejected", al))
					end)
				end
			end
		end
		ac.logComponentSuspended = logComponentSuspended
		local function logLayoutEffectsStarted(al)
			if _G.__DEV__ then
				if af then
					group(string.format("* layout effects (%s)", formatLanes(al)))
				end
			end
		end
		ac.logLayoutEffectsStarted = logLayoutEffectsStarted
		local function logLayoutEffectsStopped()
			if _G.__DEV__ then
				if af then
					groupEnd()
				end
			end
		end
		ac.logLayoutEffectsStopped = logLayoutEffectsStopped
		local function logPassiveEffectsStarted(al)
			if _G.__DEV__ then
				if af then
					group(string.format("* passive effects (%s)", formatLanes(al)))
				end
			end
		end
		ac.logPassiveEffectsStarted = logPassiveEffectsStarted
		local function logPassiveEffectsStopped()
			if _G.__DEV__ then
				if af then
					groupEnd()
				end
			end
		end
		ac.logPassiveEffectsStopped = logPassiveEffectsStopped
		local function logRenderStarted(al)
			if _G.__DEV__ then
				if af then
					group(string.format("* render (%s)", formatLanes(al)))
				end
			end
		end
		ac.logRenderStarted = logRenderStarted
		local function logRenderStopped()
			if _G.__DEV__ then
				if af then
					groupEnd()
				end
			end
		end
		ac.logRenderStopped = logRenderStopped
		local function logForceUpdateScheduled(al, am)
			if _G.__DEV__ then
				if af then
					ad(string.format("* %s forced update (%s)", al, formatLanes(am)))
				end
			end
		end
		ac.logForceUpdateScheduled = logForceUpdateScheduled
		local function logStateUpdateScheduled(al, am, an)
			if _G.__DEV__ then
				if af then
					ad(string.format("* %s updated state (%s)", al, formatLanes(am)))
				end
			end
		end
		ac.logStateUpdateScheduled = logStateUpdateScheduled
		return ac
	end
	function a.cB()
		local aa = {}
		local ab = a.load("b_")
		local ac = ab.WeakMap
		local ad = a.load("cn")
		local ae = a.load("cj")
		local af = a.load("b0")
		local ag = a.load("b0").ReactFeatureFlags
		local ah = ag.enableSchedulingProfiler
		local ai = a.load("b0").ReactVersion
		local aj = a.load("b0").getComponentName
		local ak = _G.performance ~= nil
		local al = _G.performance or { mark = function(al) end }
		function formatLanes(am)
			return tostring(am)
		end
		if ah then
			if ak then
				al.mark("--react-init-" .. tostring(ai))
			end
		end
		aa.markCommitStarted = function(am)
			if ah then
				if ak then
					al.mark("--commit-start-" .. formatLanes(am))
				end
			end
		end
		aa.markCommitStopped = function()
			if ah then
				if ak then
					al.mark("--commit-stop")
				end
			end
		end
		local am = ac.new()
		local an = 0
		function getWakeableID(ao)
			if not am.has(am, ao) then
				am.set(am, ao, an)
				an += 1
			end
			return am.get(am, ao)
		end
		aa.markComponentSuspended = function(ao, ap)
			if ah then
				if ak then
					local aq = getWakeableID(ap)
					local ar = aj(ao.type) or "Unknown"
					al.mark("--suspense-suspend-" .. tostring(aq) .. "-" .. ar)
					ap.andThen(ap, function()
						al.mark("--suspense-resolved-" .. tostring(aq) .. "-" .. ar)
					end, function()
						al.mark("--suspense-rejected-" .. tostring(aq) .. "-" .. ar)
					end)
				end
			end
		end
		aa.markLayoutEffectsStarted = function(ao)
			if ah then
				if ak then
					al.mark("--layout-effects-start-" .. formatLanes(ao))
				end
			end
		end
		aa.markLayoutEffectsStopped = function()
			if ah then
				if ak then
					al.mark("--layout-effects-stop")
				end
			end
		end
		aa.markPassiveEffectsStarted = function(ao)
			if ah then
				if ak then
					al.mark("--passive-effects-start-" .. formatLanes(ao))
				end
			end
		end
		aa.markPassiveEffectsStopped = function()
			if ah then
				if ak then
					al.mark("--passive-effects-stop")
				end
			end
		end
		aa.markRenderStarted = function(ao)
			if ah then
				if ak then
					al.mark("--render-start-" .. formatLanes(ao))
				end
			end
		end
		aa.markRenderYielded = function()
			if ah then
				if ak then
					al.mark("--render-yield")
				end
			end
		end
		aa.markRenderStopped = function()
			if ah then
				if ak then
					al.mark("--render-stop")
				end
			end
		end
		aa.markRenderScheduled = function(ao)
			if ah then
				if ak then
					al.mark("--schedule-render-" .. formatLanes(ao))
				end
			end
		end
		aa.markForceUpdateScheduled = function(ao, ap)
			if ah then
				if ak then
					local aq = aj(ao.type) or "Unknown"
					al.mark("--schedule-forced-update-" .. formatLanes(ap) .. "-" .. aq)
				end
			end
		end
		aa.markStateUpdateScheduled = function(ao, ap)
			if ah then
				if ak then
					local aq = aj(ao.type) or "Unknown"
					al.mark("--schedule-state-update-" .. formatLanes(ap) .. "-" .. aq)
				end
			end
		end
		return aa
	end
	function a.cC()
		local aa = a.load("b0").ReactSharedInternals
		local ab = aa.ReactCurrentBatchConfig
		return {
			NoTransition = 0,
			requestCurrentTransition = function()
				return ab.transition
			end,
		}
	end
	function a.cD()
		local aa = a.load("b0").console
		local ab = {}
		local ac = a.load("b0")
		local ad = a.load("cj")
		local ae = a.load("ck").isPrimaryRenderer
		local af = {}
		local ag
		if _G.__DEV__ then
			ag = {}
		end
		ab.markSourceAsDirty = function(ah)
			table.insert(af, ah)
		end
		ab.resetWorkInProgressVersions = function()
			for ah, ai in af do
				if ae then
					ai._workInProgressVersionPrimary = nil
				else
					ai._workInProgressVersionSecondary = nil
				end
			end
			table.clear(af)
		end
		ab.getWorkInProgressVersion = function(ah)
			if ae then
				return ah._workInProgressVersionPrimary
			else
				return ah._workInProgressVersionSecondary
			end
		end
		ab.setWorkInProgressVersion = function(ah, ai)
			if ae then
				ah._workInProgressVersionPrimary = ai
			else
				ah._workInProgressVersionSecondary = ai
			end
			table.insert(af, ah)
		end
		ab.warnAboutMultipleRenderersDEV = function(ah)
			if _G.__DEV__ then
				if ae then
					if ah._currentPrimaryRenderer == nil then
						ah._currentPrimaryRenderer = ag
					elseif ah._currentPrimaryRenderer ~= ag then
						aa.error("Detected multiple renderers concurrently rendering the same mutable source. This is currently unsupported.")
					end
				else
					if ah._currentSecondaryRenderer == nil then
						ah._currentSecondaryRenderer = ag
					elseif ah._currentSecondaryRenderer ~= ag then
						aa.error("Detected multiple renderers concurrently rendering the same mutable source. This is currently unsupported.")
					end
				end
			end
		end
		ab.registerMutableSourceForHydration = function(ah, ai)
			local aj = ai._getVersion
			local ak = aj(ai._source)
			if ah.mutableSourceEagerHydrationData == nil then
				ah.mutableSourceEagerHydrationData = { ai, ak }
			end
		end
		return ab
	end
	function a.cE()
		local aa = a.load("cj")
		local ab = a.load("cq")
		local ac = a.load("ck")
		local ad = ab.createCursor
		local ae = ab.push
		local af = ab.pop
		local ag = {}
		local ah = ad(ag)
		local ai = ad(ag)
		local aj = ad(ag)
		function requiredContext(ak)
			return ak
		end
		function getRootHostContainer()
			return aj.current
		end
		function pushHostContainer(ak, al)
			ae(aj, al, ak)
			ae(ai, ak, ak)
			ae(ah, ag, ak)
			local am = ac.getRootHostContext(al)
			af(ah, ak)
			ae(ah, am, ak)
		end
		function popHostContainer(ak)
			af(ah, ak)
			af(ai, ak)
			af(aj, ak)
		end
		function getHostContext()
			return ah.current
		end
		function pushHostContext(ak)
			local al = requiredContext(aj.current)
			local am = requiredContext(ah.current)
			local an = ac.getChildHostContext(am, ak.type, al)
			if am == an then
				return
			end
			ae(ai, ak, ak)
			ae(ah, an, ak)
		end
		function popHostContext(ak)
			if ai.current ~= ak then
				return
			end
			af(ah, ak)
			af(ai, ak)
		end
		return {
			getHostContext = getHostContext,
			getRootHostContainer = getRootHostContainer,
			popHostContainer = popHostContainer,
			popHostContext = popHostContext,
			pushHostContainer = pushHostContainer,
			pushHostContext = pushHostContext,
		}
	end
	function a.cF()
		local aa = a.load("cj")
		local ab = a.load("cq")
		local ac = ab.createCursor
		local ad = ab.push
		local ae = ab.pop
		local af = {}
		local ag = 0b0
		local ah = 0b1
		local ai = 0b1
		af.InvisibleParentSuspenseContext = ai
		local aj = 0b10
		af.ForceSuspenseFallback = aj
		local ak = ac(ag)
		af.suspenseStackCursor = ak
		function af.hasSuspenseContext(al, am)
			return bit32.band(al, am) ~= 0
		end
		function af.setDefaultShallowSuspenseContext(al)
			return bit32.band(al, ah)
		end
		function af.setShallowSuspenseContext(al, am)
			return bit32.bor(bit32.band(al, ah), am)
		end
		function af.addSubtreeSuspenseContext(al, am)
			return bit32.bor(al, am)
		end
		function af.pushSuspenseContext(al, am)
			ad(ak, am, al)
		end
		function af.popSuspenseContext(al)
			ae(ak, al)
		end
		return af
	end
	function a.cG()
		local aa = a.load("b0").console
		local function unimplemented(ab)
			print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
			print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
			print("UNIMPLEMENTED ERROR: " .. ab)
			error("FIXME (roblox): " .. ab .. " is unimplemented", 2)
		end
		local ab = a.load("cj")
		local ac = a.load("ck")
		local ad = a.load("co")
		local ae = a.load("b1")
		local af = ae.HostComponent
		local ag = ae.HostText
		local ah = ae.HostRoot
		local ai = ae.SuspenseComponent
		local aj = a.load("b3")
		local ak = aj.Placement
		local al = aj.Hydrating
		local am = a.load("b0").invariant
		local an = a.load("cv")
		local ao = an.createFiberFromDehydratedFragment
		local ap = a.load("b0").ReactFeatureFlags.enableSuspenseServerRenderer
		local aq = a.load("cn").OffscreenLane
		local ar
		local as
		local au = false
		function warnIfHydrating()
			if _G.__DEV__ then
				if au then
					aa.error("We should not be hydrating here. This is a bug in React. Please file a bug.")
				end
			end
		end
		function enterHydrationState(av)
			if not ac.supportsHydration then
				return false
			end
			local aw = av.stateNode.containerInfo
			as = ac.getFirstHydratableChild(aw)
			ar = av
			au = true
			return true
		end
		function reenterHydrationStateFromDehydratedSuspenseInstance(av, aw)
			if not ac.supportsHydration then
				return false
			end
			as = ac.getNextHydratableSibling(aw)
			popToNextHostParent(av)
			au = true
			return true
		end
		function deleteHydratableInstance(av, aw)
			unimplemented("deleteHydratableInstance")
		end
		function insertNonHydratedInstance(av, aw)
			unimplemented("insertNonHydratedInstance")
			aw.flags = bit32.bor(bit32.band(aw.flags, bit32.bnot(al)), ak)
			if _G.__DEV__ then
			end
		end
		function tryHydrate(av, aw)
			if av.tag == af then
				local ax = av.type
				local ay = av.pendingProps
				local az = ac.canHydrateInstance(aw, ax, ay)
				if az ~= nil then
					av.stateNode = az
					return true
				end
				return false
			elseif av.tag == ag then
				local ax = av.pendingProps
				local ay = ac.canHydrateTextInstance(aw, ax)
				if ay ~= nil then
					av.stateNode = ay
					return true
				end
				return false
			elseif av.tag == ai then
				if ap then
					local ax = ac.canHydrateSuspenseInstance(aw)
					if ax ~= nil then
						local ay = { dehydrated = ax, retryLane = aq }
						av.memoizedState = ay
						local az = ao(ax)
						az.return_ = av
						av.child = az
						return true
					end
				end
				return false
			else
				return false
			end
		end
		function tryToClaimNextHydratableInstance(av)
			if not au then
				return
			end
			local aw = as
			if not aw then
				insertNonHydratedInstance(ar, av)
				au = false
				ar = av
				return
			end
			local ax = aw
			if not tryHydrate(av, aw) then
				aw = ac.getNextHydratableSibling(ax)
				if not aw or not tryHydrate(av, aw) then
					insertNonHydratedInstance(ar, av)
					au = false
					ar = av
					return
				end
				deleteHydratableInstance(ar, ax)
			end
			ar = av
			as = ac.getFirstHydratableChild(aw)
		end
		function prepareToHydrateHostInstance(av, aw, ax)
			if not ac.supportsHydration then
				am(
					false,
					"Expected prepareToHydrateHostInstance() to never be called. This error is likely caused by a bug in React. Please file an issue."
				)
			end
			local ay = av.stateNode
			local az = ac.hydrateInstance(ay, av.type, av.memoizedProps, aw, ax, av)
			av.updateQueue = az
			if az ~= nil then
				return true
			end
			return false
		end
		function prepareToHydrateHostTextInstance(av)
			if not ac.supportsHydration then
				am(
					false,
					"Expected prepareToHydrateHostTextInstance() to never be called. This error is likely caused by a bug in React. Please file an issue."
				)
			end
			local aw = av.stateNode
			local ax = av.memoizedProps
			local ay = ac.hydrateTextInstance(aw, ax, av)
			if _G.__DEV__ then
				if ay then
					local az = ar
					if az ~= nil then
						if az.tag == ah then
							local aA = az.stateNode.containerInfo
							ac.didNotMatchHydratedContainerTextInstance(aA, aw, ax)
						elseif az.tag == af then
							local aA = az.type
							local aB = az.memoizedProps
							local aC = az.stateNode
							ac.didNotMatchHydratedTextInstance(aA, aB, aC, aw, ax)
						end
					end
				end
			end
			return ay
		end
		function prepareToHydrateHostSuspenseInstance(av)
			if not ac.supportsHydration then
				am(
					false,
					"Expected prepareToHydrateHostSuspenseInstance() to never be called. This error is likely caused by a bug in React. Please file an issue."
				)
			end
			local aw = av.memoizedState
			local ax
			if aw ~= nil then
				ax = aw.dehydrated
			else
				ax = nil
			end
			am(
				ax,
				"Expected to have a hydrated suspense instance. This error is likely caused by a bug in React. Please file an issue."
			)
			ac.hydrateSuspenseInstance(ax, av)
		end
		function skipPastDehydratedSuspenseInstance(av)
			if not ac.supportsHydration then
				am(
					false,
					"Expected skipPastDehydratedSuspenseInstance() to never be called. This error is likely caused by a bug in React. Please file an issue."
				)
			end
			local aw = av.memoizedState
			local ax
			if aw ~= nil then
				ax = aw.dehydrated
			else
				ax = nil
			end
			am(
				ax,
				"Expected to have a hydrated suspense instance. This error is likely caused by a bug in React. Please file an issue."
			)
			return ac.getNextHydratableInstanceAfterSuspenseInstance(ax)
		end
		function popToNextHostParent(av)
			local aw = av.return_
			while aw ~= nil and aw.tag ~= af and aw.tag ~= ah and aw.tag ~= ai do
				aw = aw.return_
			end
			ar = aw
		end
		function popHydrationState(av)
			if not ac.supportsHydration then
				return false
			end
			if av ~= ar then
				return false
			end
			if not au then
				popToNextHostParent(av)
				au = true
				return false
			end
			local aw = av.type
			if
				av.tag ~= af or (aw ~= "head" and aw ~= "body" and not ac.shouldSetTextContent(aw, av.memoizedProps))
			then
				local ax = as
				while ax do
					deleteHydratableInstance(av, ax)
					ax = ac.getNextHydratableSibling(ax)
				end
			end
			popToNextHostParent(av)
			if av.tag == ai then
				as = skipPastDehydratedSuspenseInstance(av)
			else
				if ar then
					as = ac.getNextHydratableSibling(av.stateNode)
				else
					as = nil
				end
			end
			return true
		end
		function resetHydrationState()
			if not ac.supportsHydration then
				return
			end
			ar = nil
			as = nil
			au = false
		end
		function getIsHydrating()
			return au
		end
		return {
			warnIfHydrating = warnIfHydrating,
			enterHydrationState = enterHydrationState,
			getIsHydrating = getIsHydrating,
			reenterHydrationStateFromDehydratedSuspenseInstance = reenterHydrationStateFromDehydratedSuspenseInstance,
			resetHydrationState = resetHydrationState,
			tryToClaimNextHydratableInstance = tryToClaimNextHydratableInstance,
			prepareToHydrateHostInstance = prepareToHydrateHostInstance,
			prepareToHydrateHostTextInstance = prepareToHydrateHostTextInstance,
			prepareToHydrateHostSuspenseInstance = prepareToHydrateHostSuspenseInstance,
			popHydrationState = popHydrationState,
		}
	end
	function a.cH()
		return { MAX_SIGNED_31_BIT_INT = 1073741823 }
	end
	function a.cI()
		local aa = a.load("b_")
		local ab = aa.Number
		local ac = aa.Error
		local ad = a.load("b0").console
		local ae = a.load("b0")
		local af = a.load("cj")
		local ag = a.load("cq")
		local ah = a.load("cn")
		local ai = a.load("cx")
		local aj = a.load("ck")
		local ak = ag.createCursor
		local al = ag.push
		local am = ag.pop
		local an = a.load("cH").MAX_SIGNED_31_BIT_INT
		local ao = a.load("b1")
		local ap = ao.ContextProvider
		local aq = ao.ClassComponent
		local ar = ah.NoLanes
		local as = ah.NoTimestamp
		local au = ah.isSubsetOfLanes
		local av = ah.includesSomeLane
		local aw = ah.mergeLanes
		local ax = ah.pickArbitraryLane
		local ay = a.load("b0").objectIs
		local az = ai.createUpdate
		local aA = ai.ForceUpdate
		local aB = {}
		local aC = ak(nil)
		local aD
		if _G.__DEV__ then
			aD = {}
		end
		local aE
		local aF
		local aG
		local aH = false
		aB.resetContextDependencies = function()
			aE = nil
			aF = nil
			aG = nil
			if _G.__DEV__ then
				aH = false
			end
		end
		aB.enterDisallowedContextReadInDEV = function()
			if _G.__DEV__ then
				aH = true
			end
		end
		aB.exitDisallowedContextReadInDEV = function()
			if _G.__DEV__ then
				aH = false
			end
		end
		aB.pushProvider = function(aI, aJ)
			local aK = aI.type._context
			if aj.isPrimaryRenderer then
				al(aC, aK._currentValue, aI)
				aK._currentValue = aJ
				if _G.__DEV__ then
					if aK._currentRenderer ~= nil and aK._currentRenderer ~= aD then
						ad.error("Detected multiple renderers concurrently rendering the same context provider. This is currently unsupported.")
					end
					aK._currentRenderer = aD
				end
			else
				al(aC, aK._currentValue2, aI)
				aK._currentValue2 = aJ
				if _G.__DEV__ then
					if aK._currentRenderer2 ~= nil and aK._currentRenderer2 ~= aD then
						ad.error("Detected multiple renderers concurrently rendering the same context provider. This is currently unsupported.")
					end
					aK._currentRenderer2 = aD
				end
			end
		end
		aB.popProvider = function(aI)
			local aJ = aC.current
			am(aC, aI)
			local aK = aI.type._context
			if aj.isPrimaryRenderer then
				aK._currentValue = aJ
			else
				aK._currentValue2 = aJ
			end
		end
		aB.calculateChangedBits = function(aI, aJ, aK)
			if ay(aK, aJ) then
				return 0
			else
				local aL = an
				if typeof(aI._calculateChangedBits) == "function" then
					aL = aI._calculateChangedBits(aK, aJ)
				end
				return math.floor(aL)
			end
		end
		aB.scheduleWorkOnParentPath = function(aI, aJ)
			local aK = aI
			while aK ~= nil do
				local aL = aK.alternate
				if not au(aK.childLanes, aJ) then
					aK.childLanes = aw(aK.childLanes, aJ)
					if aL ~= nil then
						aL.childLanes = aw(aL.childLanes, aJ)
					end
				elseif aL ~= nil and not au(aL.childLanes, aJ) then
					aL.childLanes = aw(aL.childLanes, aJ)
				else
					break
				end
				aK = aK.return_
			end
		end
		aB.propagateContextChange = function(aI, aJ, aK, aL)
			local aM = aI.child
			if aM ~= nil then
				aM.return_ = aI
			end
			while aM ~= nil do
				local aN
				local aO = aM.dependencies
				if aO ~= nil then
					aN = aM.child
					local aP = aO.firstContext
					while aP ~= nil do
						if aP.context == aJ and bit32.band(aP.observedBits, aK) ~= 0 then
							if aM.tag == aq then
								local aQ = az(as, ax(aL))
								aQ.tag = aA
								local aR = aM.updateQueue
								if aR == nil then
								else
									local aS = (aR).shared
									local aT = aS.pending
									if aT == nil then
										aQ.next = aQ
									else
										aQ.next = aT.next
										aT.next = aQ
									end
									aS.pending = aQ
								end
							end
							aM.lanes = bit32.bor(aM.lanes, aL)
							local aQ = aM.alternate
							if aQ ~= nil then
								aQ.lanes = bit32.bor(aQ.lanes, aL)
							end
							aB.scheduleWorkOnParentPath(aM.return_, aL)
							aO.lanes = bit32.bor(aO.lanes, aL)
							break
						end
						aP = aP.next
					end
				elseif aM.tag == ap then
					if aM.type == aI.type then
						aN = nil
					else
						aN = aM.child
					end
				else
					aN = aM.child
				end
				if aN ~= nil then
					aN.return_ = aM
				else
					aN = aM
					while aN ~= nil do
						if aN == aI then
							aN = nil
							break
						end
						local aP = aN.sibling
						if aP ~= nil then
							aP.return_ = aN.return_
							aN = aP
							break
						end
						aN = aN.return_
					end
				end
				aM = aN
			end
		end
		aB.prepareToReadContext = function(aI, aJ, aK)
			aE = aI
			aF = nil
			aG = nil
			local aL = aI.dependencies
			if aL ~= nil then
				local aM = aL.firstContext
				if aM ~= nil then
					if av(aL.lanes, aJ) then
						aK()
					end
					aL.firstContext = nil
				end
			end
		end
		aB.readContext = function(aI, aJ)
			if _G.__DEV__ then
				if aH then
					ad.error("Context can only be read while React is rendering. In classes, you can read it in the render method or getDerivedStateFromProps. In function components, you can read it directly in the function body, but not inside Hooks like useReducer() or useMemo().")
				end
			end
			if aG == aI then
			elseif aJ == false or aJ == 0 then
			else
				local aK
				if typeof(aJ) ~= "number" or aJ == ab.MAX_SAFE_INTEGER then
					aG = aI
					aK = ab.MAX_SAFE_INTEGER
				else
					aK = aJ
				end
				local aL = { context = aI, observedBits = aK, next = nil }
				if aF == nil then
					if aE == nil then
						error(
							ac.new("Context can only be read while React is rendering. In classes, you can read it in the render method or getDerivedStateFromProps. In function components, you can read it directly in the function body, but not inside Hooks like useReducer() or useMemo().")
						)
					end
					aF = aL;
					(aE).dependencies = { lanes = ar, firstContext = aL, responders = nil }
				else
					(aF).next = aL
					aF = aL
				end
			end
			return if aj.isPrimaryRenderer then aI._currentValue else aI._currentValue2
		end
		local aI = a.load("cl")
		local aJ = aB
		aI.register("ReactFiberNewContext", aJ)
		return aJ
	end
	function a.cJ()
		local aa = a.load("cj")
		local ab = a.load("b0").ReactFeatureFlags
		local ac = ab.enableProfilerTimer
		local ad = ab.enableProfilerCommitHooks
		local ae = a.load("b1")
		local af = ae.Profiler
		local ag = a.load("ci")
		local ah = ag.unstable_now
		local ai = 0
		local aj = -1
		local ak = -1
		local al = -1
		function getCommitTime()
			return ai
		end
		function recordCommitTime()
			if not ac then
				return
			end
			ai = ah()
		end
		function startProfilerTimer(am)
			if not ac then
				return
			end
			ak = ah()
			if am.actualStartTime ~= nil and am.actualStartTime < 0 then
				am.actualStartTime = ah()
			end
		end
		function stopProfilerTimerIfRunning(am)
			if not ac then
				return
			end
			ak = -1
		end
		function stopProfilerTimerIfRunningAndRecordDelta(am, an)
			if not ac then
				return
			end
			if ak >= 0 then
				local ao = ah() - ak
				am.actualDuration += ao
				if an then
					am.selfBaseDuration = ao
				end
				ak = -1
			end
		end
		function recordLayoutEffectDuration(am)
			if not ac or not ad then
				return
			end
			if aj >= 0 then
				local an = ah() - aj
				aj = -1
				local ao = am.return_
				while ao ~= nil do
					if ao.tag == af then
						local ap = ao.stateNode
						ap.effectDuration += an
						break
					end
					ao = ao.return_
				end
			end
		end
		function recordPassiveEffectDuration(am)
			if not ac or not ad then
				return
			end
			if al >= 0 then
				local an = ah() - al
				al = -1
				local ao = am.return_
				while ao ~= nil do
					if ao.tag == af then
						local ap = ao.stateNode
						if ap ~= nil then
							ap.passiveEffectDuration += an
						end
						break
					end
					ao = ao.return_
				end
			end
		end
		function startLayoutEffectTimer()
			if not ac or not ad then
				return
			end
			aj = ah()
		end
		function startPassiveEffectTimer()
			if not ac or not ad then
				return
			end
			al = ah()
		end
		function transferActualDuration(am)
			local an = am.child
			while an do
				am.actualDuration += an.actualDuration
				an = an.sibling
			end
		end
		return {
			getCommitTime = getCommitTime,
			recordCommitTime = recordCommitTime,
			recordLayoutEffectDuration = recordLayoutEffectDuration,
			recordPassiveEffectDuration = recordPassiveEffectDuration,
			startLayoutEffectTimer = startLayoutEffectTimer,
			startPassiveEffectTimer = startPassiveEffectTimer,
			startProfilerTimer = startProfilerTimer,
			stopProfilerTimerIfRunning = stopProfilerTimerIfRunning,
			stopProfilerTimerIfRunningAndRecordDelta = stopProfilerTimerIfRunningAndRecordDelta,
			transferActualDuration = transferActualDuration,
		}
	end
	function a.cK()
		local aa = a.load("cj")
		local ab = a.load("cn")
		local ac = a.load("co")
		local ad = a.load("cD").resetWorkInProgressVersions
		local ae = a.load("b1")
		local af = a.load("b3")
		local ag = a.load("b2")
		local ah = a.load("b0").ReactFeatureFlags
		local ai = ah.enableSuspenseServerRenderer
		local aj = ah.enableProfilerTimer
		local ak = a.load("cE")
		local al = ak.popHostContainer
		local am = ak.popHostContext
		local an = a.load("cF").popSuspenseContext
		local ao = a.load("cG").resetHydrationState
		local ap = a.load("cr")
		local aq = ap.isContextProvider
		local ar = ap.popContext
		local as = ap.popTopLevelContextObject
		local au = a.load("cI").popProvider
		local av
		local aw = function(...)
			if not av then
				av = nil
			end
			return av(...)
		end
		local ax = a.load("cJ").transferActualDuration
		local ay = a.load("b0").invariant
		local function unwindWork(az, aA)
			if az.tag == ae.ClassComponent then
				local aC = az.type
				if aq(aC) then
					ar(az)
				end
				local aD = az.flags
				if bit32.band(aD, af.ShouldCapture) ~= 0 then
					az.flags = bit32.bor(bit32.band(aD, bit32.bnot(af.ShouldCapture)), af.DidCapture)
					if aj and bit32.band(az.mode, ag.ProfileMode) ~= ag.NoMode then
						ax(az)
					end
					return az
				end
				return nil
			elseif az.tag == ae.HostRoot then
				al(az)
				as(az)
				ad()
				local aC = az.flags
				ay(
					bit32.band(aC, af.DidCapture) == af.NoFlags,
					"The root failed to unmount after an error. This is likely a bug in React. Please file an issue."
				)
				az.flags = bit32.bor(bit32.band(aC, bit32.bnot(af.ShouldCapture)), af.DidCapture)
				return az
			elseif az.tag == ae.HostComponent then
				am(az)
				return nil
			elseif az.tag == ae.SuspenseComponent then
				an(az)
				if ai then
					local aC = az.memoizedState
					if aC ~= nil and aC.dehydrated ~= nil then
						ay(
							az.alternate ~= nil,
							"Threw in newly mounted dehydrated component. This is likely a bug in React. Please file an issue."
						)
						ao()
					end
				end
				local aC = az.flags
				if bit32.band(aC, af.ShouldCapture) ~= 0 then
					az.flags = bit32.bor(bit32.band(aC, bit32.bnot(af.ShouldCapture)), af.DidCapture)
					if aj and (bit32.band(az.mode, ag.ProfileMode) ~= ag.NoMode) then
						ax(az)
					end
					return az
				end
				return nil
			elseif az.tag == ae.SuspenseListComponent then
				an(az)
				return nil
			elseif az.tag == ae.HostPortal then
				al(az)
				return nil
			elseif az.tag == ae.ContextProvider then
				au(az)
				return nil
			elseif az.tag == ae.OffscreenComponent or az.tag == ae.LegacyHiddenComponent then
				aw(az)
				return nil
			else
				return nil
			end
		end
		function unwindInterruptedWork(az)
			if az.tag == ae.ClassComponent then
				local aA
				if typeof(az.type) == "table" then
					aA = az.type.childContextTypes
				end
				if aA ~= nil then
					ar(az)
				end
			elseif az.tag == ae.HostRoot then
				al(az)
				as(az)
				ad()
			elseif az.tag == ae.HostComponent then
				am(az)
			elseif az.tag == ae.HostPortal then
				al(az)
			elseif az.tag == ae.SuspenseComponent then
				an(az)
			elseif az.tag == ae.SuspenseListComponent then
				an(az)
			elseif az.tag == ae.ContextProvider then
				au(az)
			elseif az.tag == ae.OffscreenComponent or az.tag == ae.LegacyHiddenComponent then
				aw(az)
				return
			else
				return
			end
		end
		return { unwindWork = unwindWork, unwindInterruptedWork = unwindInterruptedWork }
	end
	function a.cL()
		local aa = a.load("b_")
		local ab = a.load("cj")
		local ac = a.load("b1")
		local ad = ac.HostComponent
		local ae = ac.LazyComponent
		local af = ac.SuspenseComponent
		local ag = ac.SuspenseListComponent
		local ah = ac.FunctionComponent
		local ai = ac.IndeterminateComponent
		local aj = ac.ForwardRef
		local ak = ac.SimpleMemoComponent
		local al = ac.ClassComponent
		local am = a.load("b0").ReactComponentStackFrame
		local an = am.describeBuiltInComponentFrame
		local ao = am.describeFunctionComponentFrame
		local ap = am.describeClassComponentFrame
		local function describeFiber(aq)
			local ar
			if _G.__DEV__ then
				local as = aq._debugOwner
				if as then
					ar = as.type
				end
			end
			local as
			if _G.__DEV__ then
				as = aq._debugSource
			end
			if aq.tag == ad then
				return an(aq.type, as, ar)
			elseif aq.tag == ae then
				return an("Lazy", as, ar)
			elseif aq.tag == af then
				return an("Suspense", as, ar)
			elseif aq.tag == ag then
				return an("SuspenseList", as, ar)
			elseif aq.tag == ah or aq.tag == ai or aq.tag == ak then
				return ao(aq.type, as, ar)
			elseif aq.tag == aj then
				return ao(aq.type.render, as, ar)
			elseif aq.tag == al then
				return ap(aq.type, as, ar)
			else
				return ""
			end
		end
		return {
			getStackByFiberInDevAndProd = function(aq)
				local ar, as = pcall(function()
					local ar = ""
					local as = aq
					repeat
						ar ..= describeFiber(as)
						as = (as).return_
					until as == nil
					return ar
				end)
				if not ar then
					local au = "\nError generating stack: "
					if typeof(as) == "table" and (as).message and (as).stack then
						return au .. (as).message .. "\n" .. tostring((as).stack)
					end
					return au .. tostring(as)
				end
				return as
			end,
		}
	end
	function a.cM()
		local aa = a.load("cj")
		local ab = a.load("cL").getStackByFiberInDevAndProd
		local ac = {}
		ac.createCapturedValue = function(ad, ae)
			return { value = ad, source = ae, stack = ab(ae) }
		end
		return ac
	end
	function a.cN()
		local aa = {}
		aa.showErrorDialog = function(ab, ac)
			return true
		end
		return aa
	end
	function a.cO()
		local aa = a.load("b_")
		local ab = aa.util.inspect
		local ac = aa.setTimeout
		local ad = a.load("b0")
		local ae = ad.console
		local af = ad.errorToString
		local ag = a.load("cj")
		local ah = a.load("cM")
		local ai = a.load("cN").showErrorDialog
		local aj = a.load("b1").ClassComponent
		local ak = a.load("b0").getComponentName
		local al = {}
		al.logCapturedError = function(am, an)
			local ao, ap = pcall(function()
				local ao = ai(am, an)
				if ao == false then
					return nil
				end
				local ap = an.value
				if _G.__DEV__ then
					local aq = an.source
					local ar = an.stack
					local as = ar or ""
					if ap ~= nil and ap._suppressLogging then
						if am.tag == aj then
							return
						end
						ae["error"](ap)
					end
					local au
					if aq ~= nil then
						au = ak(aq.type)
					else
						au = nil
					end
					local av
					if au then
						av = "The above error occurred in the <" .. tostring(au) .. "> component:"
					else
						av = "The above error occurred in one of your React components:"
					end
					local aw
					local ax = ak(am.type)
					if ax then
						aw = "React will try to recreate this component tree from scratch "
							.. "using the error boundary you provided, "
							.. ax
							.. "."
					else
						aw =
							"Consider adding an error boundary to your tree to customize error handling behavior.\nVisit https://reactjs.org/link/error-boundaries to learn more about error boundaries."
					end
					local ay = av .. "\n" .. as .. "\n\n" .. aw
					ae["error"](ay)
				else
					ae["error"](ab(ap))
				end
				return nil
			end)
			if not ao then
				warn("failed to error with error: " .. ab(ap))
				ac(function()
					error(af(ap))
				end)
			end
		end
		return al
	end
	function a.cP()
		local aa = a.load("b_")
		local ab = aa.Object
		local ac = a.load("b0").console
		local ad = a.load("cj")
		local ae = a.load("cn")
		local af = a.load("cM")
		local ag = a.load("cx")
		local ah = a.load("b0")
		local ai = a.load("cF")
		local aj = a.load("b0").getComponentName
		local ak = a.load("b1")
		local al = ak.ClassComponent
		local am = ak.HostRoot
		local an = ak.SuspenseComponent
		local ao = ak.IncompleteClassComponent
		local ap = a.load("b3")
		local aq = ap.DidCapture
		local ar = ap.Incomplete
		local as = ap.NoFlags
		local au = ap.ShouldCapture
		local av = ap.LifecycleEffectMask
		local aw = ap.ForceUpdateForLegacySuspense
		local ax = a.load("co").shouldCaptureSuspense
		local ay = a.load("b2")
		local az = ay.NoMode
		local aA = ay.BlockingMode
		local aC = ay.DebugTracingMode
		local aD = a.load("b0").ReactFeatureFlags
		local aE = aD.enableDebugTracing
		local aF = aD.enableSchedulingProfiler
		local aG = a.load("cM").createCapturedValue
		local aH = ag.enqueueCapturedUpdate
		local aI = ag.createUpdate
		local aJ = ag.CaptureUpdate
		local aK = ag.ForceUpdate
		local aL = ag.enqueueUpdate
		local aM = a.load("cu").markFailedErrorBoundaryForHotReloading
		local aN = ai.hasSuspenseContext
		local aO = ai.InvisibleParentSuspenseContext
		local aP = ai.suspenseStackCursor
		local aQ
		local aR, aS, aT
		local aU = function(...)
			if not aR then
				local aU = a.load("cl")
				aQ = aU.lazy("ReactFiberWorkLoop")
				aR = aQ.markLegacyErrorBoundaryAsFailed
			end
			return aR(...)
		end
		local b = function(...)
			if aQ == nil then
				local b = a.load("cl")
				aQ = b.lazy("ReactFiberWorkLoop")
			end
			aT = aQ.pingSuspendedRoot
			return aT(...)
		end
		local c = function(...)
			if aQ == nil then
				local c = a.load("cl")
				aQ = c.lazy("ReactFiberWorkLoop")
			end
			aS = aQ.isAlreadyFailedLegacyErrorBoundary
			return aS(...)
		end
		local d = a.load("cO").logCapturedError
		local e = a.load("cA").logComponentSuspended
		local g = a.load("cB").markComponentSuspended
		local h = ae.SyncLane
		local i = ae.NoTimestamp
		local j = ae.includesSomeLane
		local k = ae.mergeLanes
		local l = ae.pickArbitraryLane
		function createRootErrorUpdate(m, n, o, p)
			local q = aI(i, o)
			q.tag = aJ
			q.payload = { element = ab.None }
			local r = n.value
			q.callback = function()
				if p ~= nil then
					p(r)
				end
				d(m, n)
			end
			return q
		end
		function createClassErrorUpdate(m, n, o)
			local p = aI(i, o)
			p.tag = aJ
			local q = (m.type).getDerivedStateFromError
			if typeof(q) == "function" then
				local r = n.value
				p.payload = function()
					d(m, n)
					return q(r)
				end
			end
			local r = m.stateNode
			if r ~= nil and typeof(r.componentDidCatch) == "function" then
				p.callback = function()
					if _G.__DEV__ then
						aM(m)
					end
					if typeof(q) ~= "function" then
						aU(r)
						d(m, n)
					end
					local s = n.value
					local t = n.stack
					r.componentDidCatch(r, s, { componentStack = t or "" })
					if _G.__DEV__ then
						if typeof(q) ~= "function" then
							if not j(m.lanes, h) then
								ac.error(
									"%s: Error boundaries should implement getDerivedStateFromError(). In that method, return a state update to display an error message or fallback UI.",
									aj(m.type) or "Unknown"
								)
							end
						end
					end
				end
			elseif _G.__DEV__ then
				p.callback = function()
					aM(m)
				end
			end
			return p
		end
		local function attachPingListener(m, n, o)
			local p = m.pingCache
			local q
			if p == nil then
				q = {}
				m.pingCache = { [n] = q }
				p = m.pingCache
			else
				q = (p)[n]
				if q == nil then
					q = {};
					(p)[n] = q
				end
			end
			if not q[o] then
				q[o] = true
				local r = function()
					return b(m, n, o)
				end
				n.andThen(n, r, r)
			end
		end
		function throwException(m, n, o, p, q, r, s)
			o.flags = bit32.bor(o.flags, ar)
			if p ~= nil and typeof(p) == "table" and typeof(p.andThen) == "function" then
				local t = p
				if _G.__DEV__ then
					if aE then
						if bit32.band(o.mode, aC) ~= 0 then
							local u = aj(o.type) or "Unknown"
							e(u, t)
						end
					end
				end
				if aF then
					g(o, t)
				end
				if bit32.band(o.mode, aA) == az then
					local u = o.alternate
					if u then
						o.updateQueue = u.updateQueue
						o.memoizedState = u.memoizedState
						o.lanes = u.lanes
					else
						o.updateQueue = nil
						o.memoizedState = nil
					end
				end
				local u = aN(aP.current, aO)
				local v = n
				repeat
					if v.tag == an and ax(v, u) then
						local w = v.updateQueue
						if w == nil then
							local x = { [t] = true }
							v.updateQueue = x
						else
							w[t] = true
						end
						if bit32.band(v.mode, aA) == az then
							v.flags = bit32.bor(v.flags, aq)
							o.flags = bit32.bor(o.flags, aw)
							o.flags = bit32.band(o.flags, bit32.bnot(bit32.bor(av, ar)))
							if o.tag == al then
								local x = o.alternate
								if x == nil then
									o.tag = ao
								else
									local y = aI(i, h)
									y.tag = aK
									aL(o, y)
								end
							end
							o.lanes = k(o.lanes, h)
							return
						end
						attachPingListener(m, t, q)
						v.flags = bit32.bor(v.flags, au)
						v.lanes = q
						return
					end
					v = v.return_
				until v == nil
				p = (aj(o.type) or "A React component")
					.. " suspended while rendering, but no fallback UI was specified.\n\nAdd a <Suspense fallback=...> component higher in the tree to provide a loading indicator or placeholder to display."
			end
			s()
			p = aG(p, o)
			local t = n
			repeat
				if t.tag == am then
					local u = p
					t.flags = bit32.bor(t.flags, au)
					local v = l(q)
					t.lanes = k(t.lanes, v)
					local w = createRootErrorUpdate(t, u, v, r)
					aH(t, w)
					return
				elseif t.tag == al then
					local u = p
					local v = t.type
					local w = t.stateNode
					if
						bit32.band(t.flags, aq) == as
						and (
							typeof(v.getDerivedStateFromError) == "function"
							or (w ~= nil and typeof(w.componentDidCatch) == "function" and not c(w))
						)
					then
						t.flags = bit32.bor(t.flags, au)
						local x = l(q)
						t.lanes = k(t.lanes, x)
						local y = createClassErrorUpdate(t, u, x)
						aH(t, y)
						return
					end
				end
				t = t.return_
			until t == nil
		end
		return {
			throwException = throwException,
			createRootErrorUpdate = createRootErrorUpdate,
			createClassErrorUpdate = createClassErrorUpdate,
		}
	end
	function a.cQ()
		return { NoFlags = 0b0, HasEffect = 0b1, Layout = 0b10, Passive = 0b100 }
	end
	function a.cR()
		local aa = _G.__DEV__
		local ab = a.load("cj")
		local ac = a.load("b0").ReactSharedInternals
		local ad = a.load("cL")
		local ae = ad.getStackByFiberInDevAndProd
		local af = a.load("b0").getComponentName
		local ag = ac.ReactDebugCurrentFrame
		local ah = { current = nil, isRendering = false }
		ah.getCurrentFiberOwnerNameInDevOrNull = function()
			if aa then
				if ah.current == nil then
					return nil
				end
				local ai = (ah.current)._debugOwner
				if ai then
					return af(ai.type)
				end
			end
			return nil
		end
		local function getCurrentFiberStackInDev()
			if aa then
				if ah.current == nil then
					return ""
				end
				return ae(ah.current)
			end
			return ""
		end
		ah.resetCurrentFiber = function()
			if aa then
				(ag).getCurrentStack = nil
				ah.current = nil
				ah.isRendering = false
			end
		end
		ah.setCurrentFiber = function(ai)
			if aa then
				(ag).getCurrentStack = getCurrentFiberStackInDev
				ah.current = ai
				ah.isRendering = false
			end
		end
		ah.setIsRendering = function(ai)
			if aa then
				ah.isRendering = ai
			end
		end
		ah.getIsRendering = function()
			if aa then
				return ah.isRendering
			end
			return false
		end
		return ah
	end
	function a.cS()
		local function resolveDefaultProps(aa, ab)
			if aa and typeof(aa) == "table" and aa.defaultProps then
				local ac = (table.clone(ab))
				local ad = aa.defaultProps
				for ae, af in ad do
					if ac[ae] == nil then
						ac[ae] = ad[ae]
					end
				end
				return ac
			end
			return ab
		end
		return { resolveDefaultProps = resolveDefaultProps }
	end
	function a.cT()
		local function unimplemented(aa)
			print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
			print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
			print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
			print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
			print("UNIMPLEMENTED ERROR: " .. tostring(aa))
			error("FIXME (roblox): " .. aa .. " is unimplemented", 2)
		end
		local aa = _G.__DEV__
		local ab = _G.__YOLO__
		local ac = 0
		local ad = 20
		local function isCallable(ae)
			if typeof(ae) == "function" then
				return true
			end
			if typeof(ae) == "table" then
				local af = getmetatable(ae)
				if af and rawget(af, "__call") then
					return true
				end
				if ae._isMockFunction then
					return true
				end
			end
			return false
		end
		local ae = a.load("b0").console
		local af = a.load("b_")
		local ag = af.Error
		local ah = af.Set
		local ai = a.load("ck")
		local aj = a.load("cj")
		local ak = a.load("co")
		local al = a.load("cx")
		local am = a.load("b0")
		local an = a.load("cs")
		local ao = a.load("cQ")
		local ap = a.load("ci").tracing.unstable_wrap
		local aq = a.load("b0").ReactFeatureFlags
		local ar = aq.enableSchedulerTracing
		local as = aq.enableProfilerTimer
		local au = aq.enableProfilerCommitHooks
		local av = aq.enableSuspenseCallback
		local aw = aq.enableDoubleInvokingEffects
		local ax = a.load("b1")
		local ay = ax.FunctionComponent
		local az = ax.ForwardRef
		local aA = ax.ClassComponent
		local aC = ax.HostRoot
		local aD = ax.HostComponent
		local aE = ax.HostText
		local aF = ax.HostPortal
		local aG = ax.Profiler
		local aH = ax.SuspenseComponent
		local aI = ax.DehydratedFragment
		local aJ = ax.IncompleteClassComponent
		local aK = ax.MemoComponent
		local aL = ax.SimpleMemoComponent
		local aM = ax.SuspenseListComponent
		local aN = ax.FundamentalComponent
		local aO = ax.ScopeComponent
		local aP = ax.Block
		local aQ = ax.OffscreenComponent
		local aR = ax.LegacyHiddenComponent
		local aS = a.load("b0").ReactErrorUtils
		local aT = aS.invokeGuardedCallback
		local aU = aS.hasCaughtError
		local b = aS.clearCaughtError
		local c = a.load("b3")
		local d = c.NoFlags
		local e = c.ContentReset
		local g = c.Placement
		local h = c.Snapshot
		local i = c.Update
		local j = c.Callback
		local k = c.LayoutMask
		local l = c.PassiveMask
		local m = c.Ref
		local n = a.load("b0").getComponentName
		local o = a.load("b0").invariant
		local p = a.load("b0").describeError
		local q = a.load("cR")
		local r = q.current
		local s = q.resetCurrentFiber
		local t = q.setCurrentFiber
		local u = a.load("ct").onCommitUnmount
		local v = a.load("cS").resolveDefaultProps
		local w = a.load("cJ")
		local x = w.startLayoutEffectTimer
		local y = w.recordPassiveEffectDuration
		local z = w.recordLayoutEffectDuration
		local A = w.startPassiveEffectTimer
		local B = w.getCommitTime
		local C = a.load("b2").ProfileMode
		local D = al.commitUpdateQueue
		local E
		local function resolveRetryWakeable(F, G)
			if not E then
				E = a.load("cl").lazy("ReactFiberWorkLoop")
			end
			E.resolveRetryWakeable(F, G)
		end
		local function markCommitTimeOfFallback()
			if not E then
				E = a.load("cl").lazy("ReactFiberWorkLoop")
			end
			E.markCommitTimeOfFallback()
		end
		local function schedulePassiveEffectCallback()
			ae.warn(
				"ReactFiberCommitWork: schedulePassiveEffectCallback causes a dependency cycle\n" .. debug.traceback()
			)
		end
		local function captureCommitPhaseError(F, G, H)
			ae.warn("ReactFiberCommitWork: captureCommitPhaseError causes a dependency cycle")
			error(H)
		end
		local F = ao.NoFlags
		local G = ao.HasEffect
		local H = ao.Layout
		local I = ao.Passive
		local J
		local K = function()
			if not J then
				local K = a.load("cl")
				local L = K.lazy("ReactFiberBeginWork")
				J = L.didWarnAboutReassigningProps or false
			end
			return J
		end
		local L, M, N, O, P, Q, R, S, T, U
		local V
		local function callComponentWillUnmountWithTimer(W, X)
			X.props = W.memoizedProps
			X.state = W.memoizedState
			if as and au and bit32.band(W.mode, C) ~= 0 then
				local Y, Z = xpcall(function()
					x()
					X.componentWillUnmount(X)
				end, p)
				z(W)
				if not Y then
					error(Z)
				end
			else
				X.componentWillUnmount(X)
			end
		end
		function safelyCallComponentWillUnmount(W, X, Y)
			local Z, _ = xpcall(callComponentWillUnmountWithTimer, p, W, X)
			if not Z then
				captureCommitPhaseError(W, Y, _)
			end
		end
		local function safelyDetachRef(W, X)
			local Y = W.ref
			if Y ~= nil then
				if typeof(Y) == "function" then
					local Z, _ = xpcall(Y, p)
					if not Z then
						captureCommitPhaseError(W, X, _)
					end
				else
					Y.current = nil
				end
			end
		end
		local function safelyCallDestroy(W, X, Y)
			local Z, _ = xpcall(Y, p)
			if not Z then
				captureCommitPhaseError(W, X, _)
			end
		end
		local function commitBeforeMutationLifeCycles(W, X)
			if X.tag == ay or X.tag == az or X.tag == aL or X.tag == aP then
				return
			elseif X.tag == aA then
				if bit32.band(X.flags, h) ~= 0 then
					if W ~= nil then
						local Y = (W).memoizedProps
						local Z = (W).memoizedState
						local _ = X.stateNode
						if aa then
							if X.type == X.elementType and not K then
								if _.props ~= X.memoizedProps then
									ae.error(
										"Expected %s props to match memoized props before getSnapshotBeforeUpdate. This might either be because of a bug in React, or because a component reassigns its own `this.props`. Please file an issue.",
										n(X.type) or "instance"
									)
								end
								if _.state ~= X.memoizedState then
									ae.error(
										"Expected %s state to match memoized state before getSnapshotBeforeUpdate. This might either be because of a bug in React, or because a component reassigns its own `this.state`. Please file an issue.",
										n(X.type) or "instance"
									)
								end
							end
						end
						local aV = _.getSnapshotBeforeUpdate(_, X.elementType == X.type and Y or v(X.type, Y), Z)
						if aa then
						end
						_.__reactInternalSnapshotBeforeUpdate = aV
					end
				end
				return
			elseif X.tag == aC then
				if ai.supportsMutation then
					if bit32.band(X.flags, h) ~= 0 then
						local aV = X.stateNode
						ai.clearContainer(aV.containerInfo)
					end
				end
				return
			elseif X.tag == aD or X.tag == aE or X.tag == aF or X.tag == aJ then
				return
			end
			o(
				false,
				"This unit of work tag should not have side-effects. This error is likely caused by a bug in React. Please file an issue."
			)
		end
		local function commitHookEffectListUnmount(aV, W, X)
			local Y = W.updateQueue
			local Z
			if Y ~= nil then
				Z = (Y).lastEffect
			end
			if Z ~= nil then
				local _ = Z.next
				local aW = _
				repeat
					if bit32.band(aW.tag, aV) == aV then
						local aX = aW.destroy
						aW.destroy = nil
						if aX ~= nil then
							safelyCallDestroy(W, X, aX)
						end
					end
					aW = aW.next
				until aW == _
			end
		end
		local function commitHookEffectListMount(aV, aW)
			local aX = aW.updateQueue
			local W = if aX ~= nil then aX.lastEffect else nil
			if W ~= nil then
				local X = W.next
				local Y = X
				repeat
					if bit32.band(Y.tag, aV) == aV then
						local Z = Y.create
						Y.destroy = Z()
						if aa then
							local _ = Y.destroy
							if _ ~= nil and typeof(_) ~= "function" then
								local aY
								if _ == nil then
									aY =
										" You returned nil. If your effect does not require clean up, return nil (or nothing)."
								elseif typeof(_.andThen) == "function" then
									aY =
										"\n\n\nIt looks like you wrote useEffect(Promise.new(function() --[[...]] end) or returned a Promise. Instead, write the async function inside your effect and call it immediately:\n\nuseEffect(function()\n  function fetchData()\n    -- You can await here\n    local response = MyAPI.getData(someId):await()\n    -- ...\n  end\n  fetchData()\nend, {someId}) -- Or {} if effect doesn't need props or state\n\nLearn more about data fetching with Hooks: https://reactjs.org/link/hooks-data-fetching"
								else
									aY = " You returned: " .. _
								end
								ae.error(
									"An effect function must not return anything besides a function, which is used for clean-up.%s",
									aY
								)
							end
						end
					end
					Y = Y.next
				until Y == X
			end
		end
		function commitProfilerPassiveEffect(aV, aW)
			if as and au then
				if aW.tag == aG then
					local aX = aW.stateNode.passiveEffectDuration
					local aY, W = aW.memoizedProps.id, aW.memoizedProps.onPostCommit
					local X = B()
					if typeof(W) == "function" then
						if ar then
							W(aY, if aW.alternate == nil then "mount" else "update", aX, X, aV.memoizedInteractions)
						else
							W(aY, if aW.alternate == nil then "mount" else "update", aX, X)
						end
					end
				end
			end
		end
		local function recursivelyCommitLayoutEffects(aV, aW, aX, aY)
			if aX ~= nil then
				captureCommitPhaseError = aX
			end
			if aY ~= nil then
				schedulePassiveEffectCallback = aY
			end
			local W = aV.flags
			local X = aV.tag
			if X == aG then
				local Y
				if as and au then
					Y = V
					V = aV
				end
				local Z = aV.child
				while Z ~= nil do
					local _ = bit32.band(aV.subtreeFlags, k)
					if _ ~= d then
						if aa then
							local aZ = r
							t(Z)
							aT(
								nil,
								recursivelyCommitLayoutEffects,
								nil,
								Z,
								aW,
								captureCommitPhaseError,
								schedulePassiveEffectCallback
							)
							if aU() then
								local a_ = b()
								captureCommitPhaseError(Z, aV, a_)
							end
							if aZ ~= nil then
								t(aZ)
							else
								s()
							end
						else
							local aZ, a_ = xpcall(
								recursivelyCommitLayoutEffects,
								p,
								Z,
								aW,
								captureCommitPhaseError,
								schedulePassiveEffectCallback
							)
							if not aZ then
								captureCommitPhaseError(Z, aV, a_)
							end
						end
					end
					Z = Z.sibling
				end
				local aZ = bit32.band(W, bit32.bor(i, j))
				if aZ ~= d then
					if as then
						if aa then
							local a_ = r
							t(aV)
							aT(nil, commitLayoutEffectsForProfiler, nil, aV, aW)
							if aU() then
								local _ = b()
								captureCommitPhaseError(aV, aV.return_, _)
							end
							if a_ ~= nil then
								t(a_)
							else
								s()
							end
						else
							local a_, _ = xpcall(commitLayoutEffectsForProfiler, p, aV, aW)
							if not a_ then
								captureCommitPhaseError(aV, aV.return_, _)
							end
						end
					end
				end
				if as and au then
					if Y ~= nil then
						Y.stateNode.effectDuration += aV.stateNode.effectDuration
					end
					V = Y
				end
			else
				local aZ = aV.child
				while aZ ~= nil do
					local a_ = bit32.band(aV.subtreeFlags, k)
					if a_ ~= d then
						if aa then
							local Y = q.current
							t(aZ)
							if ac < ad then
								ac += 1
								aT(
									nil,
									recursivelyCommitLayoutEffects,
									nil,
									aZ,
									aW,
									captureCommitPhaseError,
									schedulePassiveEffectCallback
								)
								ac -= 1
								if aU() then
									local Z = b()
									captureCommitPhaseError(aZ, aV, Z)
								end
							else
								recursivelyCommitLayoutEffects(
									aZ,
									aW,
									captureCommitPhaseError,
									schedulePassiveEffectCallback
								)
							end
							if Y ~= nil then
								t(Y)
							else
								s()
							end
						else
							local Y, Z
							if not ab and ac < ad then
								ac += 1
								Y, Z = xpcall(
									recursivelyCommitLayoutEffects,
									p,
									aZ,
									aW,
									captureCommitPhaseError,
									schedulePassiveEffectCallback
								)
								ac -= 1
							else
								Y = true
								recursivelyCommitLayoutEffects(
									aZ,
									aW,
									captureCommitPhaseError,
									schedulePassiveEffectCallback
								)
							end
							if not Y then
								captureCommitPhaseError(aZ, aV, Z)
							end
						end
					end
					aZ = aZ.sibling
				end
				local a_ = bit32.band(W, bit32.bor(i, j))
				if a_ ~= d then
					if X == ay or X == az or X == aL or X == aP then
						if as and au and bit32.band(aV.mode, C) ~= 0 then
							local Y, Z = xpcall(function()
								x()
								commitHookEffectListMount(bit32.bor(H, G), aV)
							end, p)
							z(aV)
							if not Y then
								error(Z)
							end
						else
							commitHookEffectListMount(bit32.bor(H, G), aV)
						end
						if bit32.band(aV.subtreeFlags, l) ~= d then
							schedulePassiveEffectCallback()
						end
					elseif X == aA then
						R(aV)
					elseif X == aC then
						P(aV)
					elseif X == aD then
						Q(aV)
					elseif X == aH then
						commitSuspenseHydrationCallbacks(aW, aV)
					elseif X == aN or X == aF or X == aE or X == aJ or X == aR or X == aQ or X == aO or X == aM then
					else
						o(
							false,
							"This unit of work tag should not have side-effects. This error is likely caused by a bug in React. Please file an issue."
						)
					end
				end
				if bit32.band(W, m) ~= 0 then
					commitAttachRef(aV)
				end
			end
		end
		function commitLayoutEffectsForProfiler(aV, aW)
			if as then
				local aX = aV.flags
				local aY = aV.alternate
				local aZ, a_ = aV.memoizedProps.onCommit, aV.memoizedProps.onRender
				local W = aV.stateNode.effectDuration
				local X = B()
				local Y = i
				local Z = j
				if bit32.band(aX, Y) ~= d and isCallable(a_) then
					if ar then
						a_(
							aV.memoizedProps.id,
							if aY == nil then "mount" else "update",
							aV.actualDuration,
							aV.treeBaseDuration,
							aV.actualStartTime,
							X,
							aW.memoizedInteractions
						)
					else
						a_(
							aV.memoizedProps.id,
							if aY == nil then "mount" else "update",
							aV.actualDuration,
							aV.treeBaseDuration,
							aV.actualStartTime,
							X
						)
					end
				end
				if au then
					if bit32.band(aX, Z) ~= d and isCallable(aZ) then
						if ar then
							aZ(
								aV.memoizedProps.id,
								if aY == nil then "mount" else "update",
								W,
								X,
								aW.memoizedInteractions
							)
						else
							aZ(aV.memoizedProps.id, if aY == nil then "mount" else "update", W, X)
						end
					end
				end
			end
		end
		function R(aV)
			local aW = aV.stateNode
			local aX = aV.alternate
			if bit32.band(aV.flags, i) ~= 0 then
				if aX == nil then
					if aa then
						if aV.type == aV.elementType and not K then
							if aW.props ~= aV.memoizedProps then
								ae.error(
									"Expected %s props to match memoized props before componentDidMount. This might either be because of a bug in React, or because a component reassigns its own `this.props`. Please file an issue.",
									n(aV.type) or "instance"
								)
							end
							if aW.state ~= aV.memoizedState then
								ae.error(
									"Expected %s state to match memoized state before componentDidMount. This might either be because of a bug in React, or because a component reassigns its own `this.state`. Please file an issue.",
									n(aV.type) or "instance"
								)
							end
						end
					end
					if as and au and bit32.band(aV.mode, C) ~= 0 then
						local aY, aZ = xpcall(function()
							x()
							aW.componentDidMount(aW)
						end, p)
						z(aV)
						if not aY then
							error(aZ)
						end
					else
						aW.componentDidMount(aW)
					end
				else
					local aY = aV.elementType == aV.type and aX.memoizedProps or v(aV.type, aX.memoizedProps)
					local aZ = aX.memoizedState
					if aa then
						if aV.type == aV.elementType and not K then
							if aW.props ~= aV.memoizedProps then
								ae.error(
									"Expected %s props to match memoized props before componentDidUpdate. This might either be because of a bug in React, or because a component reassigns its own `this.props`. Please file an issue.",
									n(aV.type) or "instance"
								)
							end
							if aW.state ~= aV.memoizedState then
								ae.error(
									"Expected %s state to match memoized state before componentDidUpdate. This might either be because of a bug in React, or because a component reassigns its own `this.state`. Please file an issue.",
									n(aV.type) or "instance"
								)
							end
						end
					end
					if as and au and bit32.band(aV.mode, C) ~= 0 then
						local a_, W = xpcall(function()
							x()
							aW.componentDidUpdate(aW, aY, aZ, aW.__reactInternalSnapshotBeforeUpdate)
						end, p)
						z(aV)
						if not a_ then
							error(W)
						end
					else
						aW.componentDidUpdate(aW, aY, aZ, aW.__reactInternalSnapshotBeforeUpdate)
					end
				end
			end
			local aY = aV.updateQueue
			if aY ~= nil then
				if aa then
					if aV.type == aV.elementType and not K then
						if aW.props ~= aV.memoizedProps then
							ae.error(
								"Expected %s props to match memoized props before processing the update queue. This might either be because of a bug in React, or because a component reassigns its own `this.props`. Please file an issue.",
								n(aV.type) or "instance"
							)
						end
						if aW.state ~= aV.memoizedState then
							ae.error(
								"Expected %s state to match memoized state before processing the update queue. This might either be because of a bug in React, or because a component reassigns its own `this.state`. Please file an issue.",
								n(aV.type) or "instance"
							)
						end
					end
				end
				D(aV, aY, aW)
			end
		end
		function P(aV)
			local aW = aV.updateQueue
			if aW ~= nil then
				local aX
				if aV.child ~= nil then
					local aY = aV.child
					if aY.tag == aD then
						aX = ai.getPublicInstance(aY.stateNode)
					elseif aY.tag == aA then
						aX = aY.stateNode
					end
				end
				D(aV, aW, aX)
			end
		end
		function Q(aV)
			local aW = aV.stateNode
			local aX = aV.alternate
			if aX == nil and bit32.band(aV.flags, i) ~= 0 then
				local aY = aV.type
				local aZ = aV.memoizedProps
				ai.commitMount(aW, aY, aZ, aV)
			end
		end
		local function hideOrUnhideAllChildren(aV, aW)
			if ai.supportsMutation then
				local aX = aV
				while true do
					if aX.tag == aD then
						local aY = aX.stateNode
						if aW then
							ai.hideInstance(aY)
						else
							ai.unhideInstance(aX.stateNode, aX.memoizedProps)
						end
					elseif aX.tag == aE then
						local aY = aX.stateNode
						if aW then
							ai.hideTextInstance(aY)
						else
							ai.unhideTextInstance(aY, aX.memoizedProps)
						end
					elseif (aX.tag == aQ or aX.tag == aR) and aX.memoizedState ~= nil and aX ~= aV then
					elseif aX.child ~= nil then
						(aX.child).return_ = aX
						aX = aX.child
						continue
					end
					if aX == aV then
						return
					end
					while aX.sibling == nil do
						if aX.return_ == nil or aX.return_ == aV then
							return
						end
						aX = aX.return_
					end
					(aX.sibling).return_ = aX.return_
					aX = aX.sibling
				end
			end
		end
		function commitAttachRef(aV)
			local aW = aV.ref
			if aW ~= nil then
				local aX = aV.stateNode
				local aY
				if aV.tag == aD then
					aY = ai.getPublicInstance(aX)
				else
					aY = aX
				end
				if typeof(aW) == "function" then
					aW(aY)
				else
					if aa then
						if typeof(aW) ~= "table" then
							ae.error(
								"Unexpected ref object provided for %s. Use either a ref-setter function or React.createRef().",
								n(aV.type) or "instance"
							)
							return
						end
					end
					aW.current = aY
				end
			end
		end
		function commitDetachRef(aV)
			local aW = aV.ref
			if aW ~= nil then
				if typeof(aW) == "function" then
					aW(nil)
				else
					aW.current = nil
				end
			end
		end
		function U(aV, aW, aX, aY)
			u(aW)
			if aW.tag == ay or aW.tag == az or aW.tag == aK or aW.tag == aL or aW.tag == aP then
				local aZ = aW.updateQueue
				if aZ ~= nil then
					local a_ = (aZ).lastEffect
					if a_ ~= nil then
						local W = a_.next
						local X = W
						repeat
							if X.destroy ~= nil then
								if bit32.band(X.tag, H) ~= F then
									if as and au and bit32.band(aW.mode, C) ~= 0 then
										x()
										safelyCallDestroy(aW, aX, X.destroy)
										z(aW)
									else
										safelyCallDestroy(aW, aX, X.destroy)
									end
								end
							end
							X = X.next
						until X == W
					end
				end
				return
			elseif aW.tag == aA then
				safelyDetachRef(aW, aX)
				local aZ = aW.stateNode
				if typeof(aZ.componentWillUnmount) == "function" then
					safelyCallComponentWillUnmount(aW, aZ, aX)
				end
				return
			elseif aW.tag == aD then
				safelyDetachRef(aW, aX)
				return
			elseif aW.tag == aF then
				if ai.supportsMutation then
					S(aV, aW, aX, aY)
				elseif ai.supportsPersistence then
					unimplemented("emptyPortalContainer")
				end
				return
			end
		end
		function T(aV, aW, aX, aY)
			local aZ = aW
			while true do
				U(aV, aZ, aX, aY)
				if aZ.child ~= nil and (not ai.supportsMutation or aZ.tag ~= aF) then
					(aZ.child).return_ = aZ
					aZ = aZ.child
					continue
				end
				if aZ == aW then
					return
				end
				while aZ.sibling == nil do
					if aZ.return_ == nil or aZ.return_ == aW then
						return
					end
					aZ = aZ.return_
				end
				(aZ.sibling).return_ = aZ.return_
				aZ = aZ.sibling
			end
		end
		local function detachFiberMutation(aV)
			local aW = aV.alternate
			if aW ~= nil then
				aW.return_ = nil
				aV.alternate = nil
			end
			aV.return_ = nil
		end
		local function getHostParentFiber(aV)
			local aW = aV.return_
			while aW ~= nil do
				if L(aW) then
					return aW
				end
				aW = aW.return_
			end
			error(
				ag.new("Expected to find a host parent. This error is likely caused by a bug in React. Please file an issue.")
			)
		end
		function L(aV)
			return aV.tag == aD or aV.tag == aC or aV.tag == aF
		end
		function M(aV)
			local aW = aV
			while true do
				local aX = false
				while aW.sibling == nil do
					if aW.return_ == nil or L(aW.return_) then
						return nil
					end
					aW = aW.return_
				end
				(aW.sibling).return_ = aW.return_
				aW = aW.sibling
				while aW.tag ~= aD and aW.tag ~= aE and aW.tag ~= aI do
					if bit32.band(aW.flags, g) ~= 0 then
						aX = true
						break
					end
					if aW.child == nil or aW.tag == aF then
						aX = true
						break
					else
						(aW.child).return_ = aW
						aW = aW.child
					end
				end
				if aX then
					continue
				end
				if bit32.band(aW.flags, g) == 0 then
					return aW.stateNode
				end
			end
		end
		local function commitPlacement(aV)
			if not ai.supportsMutation then
				return
			end
			local aW = getHostParentFiber(aV)
			local aX
			local aY
			local aZ = aW.stateNode
			if aW.tag == aD then
				aX = aZ
				aY = false
			elseif aW.tag == aC then
				aX = aZ.containerInfo
				aY = true
			elseif aW.tag == aF then
				aX = aZ.containerInfo
				aY = true
			else
				o(
					false,
					"Invalid host parent fiber. This error is likely caused by a bug in React. Please file an issue."
				)
			end
			if bit32.band(aW.flags, e) ~= 0 then
				ai.resetTextContent(aX)
				aW.flags = bit32.band(aW.flags, bit32.bnot(e))
			end
			local a_ = M(aV)
			if aY then
				O(aV, a_, aX)
			else
				N(aV, a_, aX)
			end
		end
		function O(aV, aW, aX)
			local aY = aV.tag
			local aZ = aY == aD or aY == aE
			if aZ then
				local a_ = aV.stateNode
				if aW then
					ai.insertInContainerBefore(aX, a_, aW)
				else
					ai.appendChildToContainer(aX, a_)
				end
			elseif aY == aF then
			else
				local a_ = aV.child
				if a_ ~= nil then
					O(a_, aW, aX)
					local W = a_.sibling
					while W ~= nil do
						O(W, aW, aX)
						W = W.sibling
					end
				end
			end
		end
		function N(aV, aW, aX)
			local aY = aV.tag
			local aZ = aY == aD or aY == aE
			if aZ then
				local a_ = aV.stateNode
				if aW then
					ai.insertBefore(aX, a_, aW)
				else
					ai.appendChild(aX, a_)
				end
			elseif aY == aF then
			else
				local a_ = aV.child
				if a_ ~= nil then
					N(a_, aW, aX)
					local W = a_.sibling
					while W ~= nil do
						N(W, aW, aX)
						W = W.sibling
					end
				end
			end
		end
		function S(aV, aW, aX, aY)
			local aZ = aW
			local a_ = false
			local W
			local X
			while true do
				if not a_ then
					local Y = aZ.return_
					while true do
						if Y == nil then
							error(
								ag.new("Expected to find a host parent. This error is likely caused by a bug in React. Please file an issue.")
							)
						end
						local Z = Y.stateNode
						if Y.tag == aD then
							W = Z
							X = false
							break
						elseif Y.tag == aC then
							W = Z.containerInfo
							X = true
							break
						elseif Y.tag == aF then
							W = Z.containerInfo
							X = true
							break
						end
						Y = Y.return_
					end
					a_ = true
				end
				if aZ.tag == aD or aZ.tag == aE then
					T(aV, aZ, aX, aY)
					if X then
						ai.removeChildFromContainer(W, aZ.stateNode)
					else
						ai.removeChild(W, aZ.stateNode)
					end
				elseif aZ.tag == aF then
					if aZ.child ~= nil then
						W = aZ.stateNode.containerInfo
						X = true
						aZ.child.return_ = aZ
						aZ = aZ.child
						continue
					end
				else
					U(aV, aZ, aX, aY)
					if aZ.child ~= nil then
						aZ.child.return_ = aZ
						aZ = aZ.child
						continue
					end
				end
				if aZ == aW then
					return
				end
				while aZ.sibling == nil do
					if aZ.return_ == nil or aZ.return_ == aW then
						return
					end
					aZ = aZ.return_
					if aZ.tag == aF then
						a_ = false
					end
				end
				(aZ.sibling).return_ = aZ.return_
				aZ = aZ.sibling
			end
		end
		local function commitDeletion(aV, aW, aX, aY)
			S(aV, aW, aX, aY)
			local aZ = aW.alternate
			detachFiberMutation(aW)
			if aZ ~= nil then
				detachFiberMutation(aZ)
			end
		end
		local function commitWork(aV, aW)
			if aW.tag == ay or aW.tag == az or aW.tag == aK or aW.tag == aL or aW.tag == aP then
				if as and au and bit32.band(aW.mode, C) ~= 0 then
					local aX, aY = xpcall(function()
						x()
						commitHookEffectListUnmount(bit32.bor(H, G), aW, aW.return_)
					end, p)
					z(aW)
					if not aX then
						error(aY)
					end
				else
					commitHookEffectListUnmount(bit32.bor(H, G), aW, aW.return_)
				end
				return
			elseif aW.tag == aA then
				return
			elseif aW.tag == aD then
				local aX = aW.stateNode
				if aX ~= nil then
					local aY = aW.memoizedProps
					local aZ
					if aV then
						aZ = aV.memoizedProps
					else
						aZ = aY
					end
					local a_ = aW.type
					local W = aW.updateQueue
					aW.updateQueue = nil
					if W ~= nil then
						ai.commitUpdate(aX, W, a_, aZ, aY, aW)
					end
				end
				return
			elseif aW.tag == aE then
				o(
					aW.stateNode ~= nil,
					"This should have a text node initialized. This error is likely caused by a bug in React. Please file an issue."
				)
				local aX = aW.stateNode
				local aY = aW.memoizedProps
				local aZ
				if aV ~= nil then
					aZ = (aV).memoizedProps
					aZ = aY
				end
				ai.commitTextUpdate(aX, aZ, aY)
				return
			elseif aW.tag == aC then
				if ai.supportsHydration then
					local aX = aW.stateNode
					if aX.hydrate then
						aX.hydrate = false
						unimplemented("commitWork: HostRoot: commitHydratedContainer")
					end
				end
				return
			elseif aW.tag == aG then
				return
			elseif aW.tag == aH then
				commitSuspenseComponent(aW)
				attachSuspenseRetryListeners(aW)
				return
			elseif aW.tag == aM then
				unimplemented("commitWork: SuspenseListComponent")
			elseif aW.tag == aJ then
				return
			elseif aW.tag == aQ or aW.tag == aR then
				local aX = aW.memoizedState
				local aY = aX ~= nil
				hideOrUnhideAllChildren(aW, aY)
				return
			end
			o(
				false,
				"This unit of work tag should not have side-effects. This error is likely caused by a bug in React. Please file an issue."
			)
		end
		function commitSuspenseComponent(aV)
			local aW = aV.memoizedState
			if aW ~= nil then
				markCommitTimeOfFallback()
				if ai.supportsMutation then
					local aX = aV.child
					hideOrUnhideAllChildren(aX, true)
				end
			end
			if av and aW ~= nil then
				local aX = aV.memoizedProps.suspenseCallback
				if typeof(aX) == "function" then
					local aY = aV.updateQueue
					if aY ~= nil then
						aX(table.clone(aY))
					end
				elseif aa then
					if aX ~= nil then
						ae.error("Unexpected type for suspenseCallback: %s", tostring(aX))
					end
				end
			end
		end
		function commitSuspenseHydrationCallbacks(aV, aW)
			if not ai.supportsHydration then
				return
			end
			local aX = aW.memoizedState
			if aX == nil then
				local aY = aW.alternate
				if aY ~= nil then
					local aZ = aY.memoizedState
					if aZ ~= nil then
						local a_ = aZ.dehydrated
						if a_ ~= nil then
							ai.commitHydratedSuspenseInstance(a_)
							if av then
								local W = aV.hydrationCallbacks
								if W ~= nil then
									local X = W.onHydrated
									if X then
										X(a_)
									end
								end
							end
						end
					end
				end
			end
		end
		function attachSuspenseRetryListeners(aV)
			local aW = aV.updateQueue
			if aW ~= nil then
				aV.updateQueue = nil
				local aX = aV.stateNode
				if aX == nil then
					aV.stateNode = ah.new()
					aX = aV.stateNode
				end
				for aY, aZ in aW do
					local a_ = function()
						return resolveRetryWakeable(aV, aY)
					end
					if not aX.has(aX, aY) then
						if ar then
							if aY.__reactDoNotTraceInteractions ~= true then
								a_ = ap(a_)
							end
						end
						aX.add(aX, aY)
						aY.andThen(aY, function()
							return a_()
						end, function()
							return a_()
						end)
					end
				end
			end
		end
		function isSuspenseBoundaryBeingHidden(aV, aW)
			if aV ~= nil then
				local aX = (aV).memoizedState
				if aX == nil or (aX).dehydrated ~= nil then
					local aY = aW.memoizedState
					return aY ~= nil and (aY).dehydrated == nil
				end
			end
			return false
		end
		function commitResetTextContent(aV)
			if not ai.supportsMutation then
				return
			end
			ai.resetTextContent(aV.stateNode)
		end
		local function commitPassiveUnmount(aV)
			if aV.tag == ay or aV.tag == az or aV.tag == aL or aV.tag == aP then
				if as and au and bit32.band(aV.mode, C) ~= 0 then
					A()
					commitHookEffectListUnmount(bit32.bor(I, G), aV, aV.return_)
					y(aV)
				else
					commitHookEffectListUnmount(bit32.bor(I, G), aV, aV.return_)
				end
			end
		end
		local function commitPassiveUnmountInsideDeletedTree(aV, aW)
			if aV.tag == ay or aV.tag == az or aV.tag == aL or aV.tag == aP then
				if as and au and bit32.band(aV.mode, C) ~= 0 then
					A()
					commitHookEffectListUnmount(I, aV, aW)
					y(aV)
				else
					commitHookEffectListUnmount(I, aV, aW)
				end
			end
		end
		local function commitPassiveMount(aV, aW)
			if aW.tag == ay or aW.tag == az or aW.tag == aL or aW.tag == aP then
				if as and au and bit32.band(aW.mode, C) ~= 0 then
					A()
					local aX, aY = xpcall(commitHookEffectListMount, p, bit32.bor(I, G), aW)
					y(aW)
					if not aX then
						error(aY)
					end
				else
					commitHookEffectListMount(bit32.bor(I, G), aW)
				end
			elseif aW.tag == aG then
				commitProfilerPassiveEffect(aV, aW)
			end
		end
		function invokeLayoutEffectMountInDEV(aV)
			if aa and aw then
				if aV.tag == ay or aV.tag == az or aV.tag == aL or aV.tag == aP then
					aT(nil, commitHookEffectListMount, nil, bit32.bor(H, G), aV)
					if aU() then
						local aW = b()
						captureCommitPhaseError(aV, aV.return_, aW)
					end
					return
				end
			elseif aV.tag == aA then
				local aW = aV.stateNode
				aT(nil, aW.componentDidMount, aW)
				if aU() then
					local aX = b()
					captureCommitPhaseError(aV, aV.return_, aX)
				end
				return
			end
		end
		function invokePassiveEffectMountInDEV(aV)
			if aa and aw then
				if aV.tag == ay or aV.tag == az or aV.tag == aL or aV.tag == aP then
					aT(nil, commitHookEffectListMount, nil, bit32.bor(I, G), aV)
					if aU() then
						local aW = b()
						captureCommitPhaseError(aV, aV.return_, aW)
					end
					return
				end
			end
		end
		function invokeLayoutEffectUnmountInDEV(aV)
			if aa and aw then
				if aV.tag == ay or aV.tag == az or aV.tag == aL or aV.tag == aP then
					aT(nil, commitHookEffectListUnmount, nil, bit32.bor(H, G), aV, aV.return_)
					if aU() then
						local aW = b()
						captureCommitPhaseError(aV, aV.return_, aW)
					end
					return
				end
			elseif aV.tag == aA then
				local aW = aV.stateNode
				if typeof(aW.componentWillUnmount) == "function" then
					safelyCallComponentWillUnmount(aV, aW, aV.return_)
				end
				return
			end
		end
		function invokePassiveEffectUnmountInDEV(aV)
			if aa and aw then
				if aV.tag == ay or aV.tag == az or aV.tag == aL or aV.tag == aP then
					aT(nil, commitHookEffectListUnmount, nil, bit32.bor(I, G), aV, aV.return_)
					if aU() then
						local aW = b()
						captureCommitPhaseError(aV, aV.return_, aW)
					end
					return
				end
			end
		end
		return {
			safelyCallDestroy = safelyCallDestroy,
			commitBeforeMutationLifeCycles = commitBeforeMutationLifeCycles,
			commitResetTextContent = commitResetTextContent,
			commitPlacement = commitPlacement,
			commitDeletion = commitDeletion,
			commitWork = commitWork,
			commitAttachRef = commitAttachRef,
			commitDetachRef = commitDetachRef,
			commitPassiveUnmount = commitPassiveUnmount,
			commitPassiveUnmountInsideDeletedTree = commitPassiveUnmountInsideDeletedTree,
			commitPassiveMount = commitPassiveMount,
			invokeLayoutEffectMountInDEV = invokeLayoutEffectMountInDEV,
			invokeLayoutEffectUnmountInDEV = invokeLayoutEffectUnmountInDEV,
			invokePassiveEffectMountInDEV = invokePassiveEffectMountInDEV,
			invokePassiveEffectUnmountInDEV = invokePassiveEffectUnmountInDEV,
			isSuspenseBoundaryBeingHidden = isSuspenseBoundaryBeingHidden,
			recursivelyCommitLayoutEffects = recursivelyCommitLayoutEffects,
		}
	end
	function a.cU()
		local aa = "Non-promise value passed into %s at index %s"
		local ab = "Please pass a list of promises to %s"
		local ac = "Please pass a handler function to %s!"
		local ad = { __mode = "k" }
		local function isCallable(ae)
			if type(ae) == "function" then
				return true
			end
			if type(ae) == "table" then
				local af = getmetatable(ae)
				if af and type(rawget(af, "__call")) == "function" then
					return true
				end
			end
			return false
		end
		local function makeEnum(ae, af)
			local ag = {}
			for ah, ai in ipairs(af) do
				ag[ai] = ai
			end
			return setmetatable(ag, {
				__index = function(ah, ai)
					error(string.format("%s is not in %s!", ai, ae), 2)
				end,
				__newindex = function()
					error(string.format("Creating new members in %s is not allowed!", ae), 2)
				end,
			})
		end
		local ae
		do
			ae = {
				Kind = makeEnum(
					"Promise.Error.Kind",
					{ "ExecutionError", "AlreadyCancelled", "NotResolvedInTime", "TimedOut" }
				),
			}
			ae.__index = ae
			function ae.new(af, ag)
				af = af or {}
				return setmetatable(
					{
						error = tostring(af.error) or "[This error has no error text.]",
						trace = af.trace,
						context = af.context,
						kind = af.kind,
						parent = ag,
						createdTick = os.clock(),
						createdTrace = debug.traceback(),
					},
					ae
				)
			end
			function ae.is(af)
				if type(af) == "table" then
					local ag = getmetatable(af)
					if type(ag) == "table" then
						return rawget(af, "error") ~= nil and type(rawget(ag, "extend")) == "function"
					end
				end
				return false
			end
			function ae.isKind(af, ag)
				assert(ag ~= nil, "Argument #2 to Promise.Error.isKind must not be nil")
				return ae.is(af) and af.kind == ag
			end
			function ae:extend(af)
				af = af or {}
				af.kind = af.kind or self.kind
				return ae.new(af, self)
			end
			function ae:getErrorChain()
				local af = { self }
				while af[#af].parent do
					table.insert(af, af[#af].parent)
				end
				return af
			end
			function ae:__tostring()
				local af = { string.format("-- Promise.Error(%s) --", self.kind or "?") }
				for ag, ah in ipairs(self.getErrorChain(self)) do
					table.insert(af, table.concat({ ah.trace or ah.error, ah.context }, "\n"))
				end
				return table.concat(af, "\n")
			end
		end
		local function pack(...)
			return select("#", ...), { ... }
		end
		local function packResult(af, ...)
			return af, select("#", ...), { ... }
		end
		local function makeErrorHandler(af)
			assert(af ~= nil, "traceback is nil")
			return function(ag)
				if type(ag) == "table" then
					return ag
				end
				return ae.new({
					error = ag,
					kind = ae.Kind.ExecutionError,
					trace = debug.traceback(tostring(ag), 2),
					context = "Promise created at:\n\n" .. af,
				})
			end
		end
		local function runExecutor(af, ag, ...)
			return packResult(xpcall(ag, makeErrorHandler(af), ...))
		end
		local function createAdvancer(af, ag, ah, ai)
			return function(...)
				local aj, ak, al = runExecutor(af, ag, ...)
				if aj then
					ah(unpack(al, 1, ak))
				else
					ai(al[1])
				end
			end
		end
		local function isEmpty(af)
			return next(af) == nil
		end
		local af = {
			Error = ae,
			Status = makeEnum("Promise.Status", { "Started", "Resolved", "Rejected", "Cancelled" }),
			_getTime = os.clock,
			_timeEvent = cloneref(game.GetService(game, "RunService")).Heartbeat,
			_unhandledRejectionCallbacks = {},
		}
		af.prototype = {}
		af.__index = af.prototype
		function af._new(ag, ah, ai)
			if ai ~= nil and not af.is(ai) then
				error("Argument #2 to Promise.new must be a promise or nil", 2)
			end
			local aj = {
				_thread = nil,
				_source = ag,
				_status = af.Status.Started,
				_values = nil,
				_valuesLength = -1,
				_unhandledRejection = true,
				_queuedResolve = {},
				_queuedReject = {},
				_queuedFinally = {},
				_cancellationHook = nil,
				_parent = ai,
				_consumers = setmetatable({}, ad),
			}
			if ai and ai._status == af.Status.Started then
				ai._consumers[aj] = true
			end
			setmetatable(aj, af)
			local function resolve(...)
				aj._resolve(aj, ...)
			end
			local function reject(...)
				aj._reject(aj, ...)
			end
			local function onCancel(ak)
				if ak then
					if aj._status == af.Status.Cancelled then
						ak()
					else
						aj._cancellationHook = ak
					end
				end
				return aj._status == af.Status.Cancelled
			end
			aj._thread = coroutine.create(function()
				local ak, al, am = runExecutor(aj._source, ah, resolve, reject, onCancel)
				if not ak then
					reject(am[1])
				end
			end)
			task.spawn(aj._thread)
			return aj
		end
		function af.new(ag)
			return af._new(debug.traceback(nil, 2), ag)
		end
		function af:__tostring()
			return string.format("Promise(%s)", self._status)
		end
		function af.defer(ag)
			local ah = debug.traceback(nil, 2)
			local ai
			ai = af._new(ah, function(aj, ak, al)
				local am
				am = af._timeEvent:Connect(function()
					am.Disconnect(am)
					local an, ao, ap = runExecutor(ah, ag, aj, ak, al)
					if not an then
						ak(ap[1])
					end
				end)
			end)
			return ai
		end
		af.async = af.defer
		function af.resolve(...)
			local ag, ah = pack(...)
			return af._new(debug.traceback(nil, 2), function(ai)
				ai(unpack(ah, 1, ag))
			end)
		end
		function af.reject(...)
			local ag, ah = pack(...)
			return af._new(debug.traceback(nil, 2), function(ai, aj)
				aj(unpack(ah, 1, ag))
			end)
		end
		function af._try(ag, ah, ...)
			local ai, aj = pack(...)
			return af._new(ag, function(ak)
				ak(ah(unpack(aj, 1, ai)))
			end)
		end
		function af.try(ag, ...)
			return af._try(debug.traceback(nil, 2), ag, ...)
		end
		function af._all(ag, ah, ai)
			if type(ah) ~= "table" then
				error(string.format(ab, "Promise.all"), 3)
			end
			for aj, ak in pairs(ah) do
				if not af.is(ak) then
					error(string.format(aa, "Promise.all", tostring(aj)), 3)
				end
			end
			if #ah == 0 or ai == 0 then
				return af.resolve({})
			end
			return af._new(ag, function(aj, ak, al)
				local am = {}
				local an = {}
				local ao = 0
				local ap = 0
				local aq = false
				local function cancel()
					for ar, as in ipairs(an) do
						as.cancel(as)
					end
				end
				local function resolveOne(ar, ...)
					if aq then
						return
					end
					ao = ao + 1
					if ai == nil then
						am[ar] = ...
					else
						am[ao] = ...
					end
					if ao >= (ai or #ah) then
						aq = true
						aj(am)
						cancel()
					end
				end
				al(cancel)
				for ar, as in ipairs(ah) do
					an[ar] = as.andThen(as, function(...)
						resolveOne(ar, ...)
					end, function(...)
						ap = ap + 1
						if ai == nil or #ah - ap < ai then
							cancel()
							aq = true
							ak(...)
						end
					end)
				end
				if aq then
					cancel()
				end
			end)
		end
		function af.all(...)
			local ag = { ... }
			if type(ag[1]) == "table" and not af.is(ag[1]) then
				ag = ag[1]
			end
			return af._all(debug.traceback(nil, 2), ag)
		end
		function af.fold(ag, ah, ai)
			assert(type(ag) == "table", "Bad argument #1 to Promise.fold: must be a table")
			assert(isCallable(ah), "Bad argument #2 to Promise.fold: must be a function")
			local aj = af.resolve(ai)
			return af.each(ag, function(ak, al)
				aj = aj.andThen(aj, function(am)
					return ah(am, ak, al)
				end)
			end):andThen(function()
				return aj
			end)
		end
		function af.some(ag, ah)
			assert(type(ah) == "number", "Bad argument #2 to Promise.some: must be a number")
			return af._all(debug.traceback(nil, 2), ag, ah)
		end
		function af.any(ag)
			return af._all(debug.traceback(nil, 2), ag, 1):andThen(function(ah)
				return ah[1]
			end)
		end
		function af.allSettled(ag)
			if type(ag) ~= "table" then
				error(string.format(ab, "Promise.allSettled"), 2)
			end
			for ah, ai in pairs(ag) do
				if not af.is(ai) then
					error(string.format(aa, "Promise.allSettled", tostring(ah)), 2)
				end
			end
			if #ag == 0 then
				return af.resolve({})
			end
			return af._new(debug.traceback(nil, 2), function(ah, ai, aj)
				local ak = {}
				local al = {}
				local am = 0
				local function resolveOne(an, ...)
					am = am + 1
					ak[an] = ...
					if am >= #ag then
						ah(ak)
					end
				end
				aj(function()
					for an, ao in ipairs(al) do
						ao.cancel(ao)
					end
				end)
				for an, ao in ipairs(ag) do
					al[an] = ao.finally(ao, function(...)
						resolveOne(an, ...)
					end)
				end
			end)
		end
		function af.race(ag)
			assert(type(ag) == "table", string.format(ab, "Promise.race"))
			for ah, ai in pairs(ag) do
				assert(af.is(ai), string.format(aa, "Promise.race", tostring(ah)))
			end
			return af._new(debug.traceback(nil, 2), function(ah, ai, aj)
				local ak = {}
				local al = false
				local function cancel()
					for am, an in ipairs(ak) do
						an.cancel(an)
					end
				end
				local function finalize(am)
					return function(...)
						cancel()
						al = true
						return am(...)
					end
				end
				if aj(finalize(ai)) then
					return
				end
				for am, an in ipairs(ag) do
					ak[am] = an.andThen(an, finalize(ah), finalize(ai))
				end
				if al then
					cancel()
				end
			end)
		end
		function af.each(ag, ah)
			assert(type(ag) == "table", string.format(ab, "Promise.each"))
			assert(isCallable(ah), string.format(ac, "Promise.each"))
			return af._new(debug.traceback(nil, 2), function(ai, aj, ak)
				local al = {}
				local am = {}
				local an = false
				local function cancel()
					for ao, ap in ipairs(am) do
						ap.cancel(ap)
					end
				end
				ak(function()
					an = true
					cancel()
				end)
				local ao = {}
				for ap, aq in ipairs(ag) do
					if af.is(aq) then
						if aq.getStatus(aq) == af.Status.Cancelled then
							cancel()
							return aj(
								ae.new({
									error = "Promise is cancelled",
									kind = ae.Kind.AlreadyCancelled,
									context = string.format(
										"The Promise that was part of the array at index %d passed into Promise.each was already cancelled when Promise.each began.\n\nThat Promise was created at:\n\n%s",
										ap,
										aq._source
									),
								})
							)
						elseif aq.getStatus(aq) == af.Status.Rejected then
							cancel()
							return aj(select(2, aq.await(aq)))
						end
						local ar = aq.andThen(aq, function(...)
							return ...
						end)
						table.insert(am, ar)
						ao[ap] = ar
					else
						ao[ap] = aq
					end
				end
				for ap, aq in ipairs(ao) do
					if af.is(aq) then
						local ar
						ar, aq = aq.await(aq)
						if not ar then
							cancel()
							return aj(aq)
						end
					end
					if an then
						return
					end
					local ar = af.resolve(ah(aq, ap))
					table.insert(am, ar)
					local as, au = ar.await(ar)
					if not as then
						cancel()
						return aj(au)
					end
					al[ap] = au
				end
				ai(al)
			end)
		end
		function af.is(ag)
			if type(ag) ~= "table" then
				return false
			end
			local ah = getmetatable(ag)
			if ah == af then
				return true
			elseif ah == nil then
				return isCallable(ag.andThen)
			elseif
				type(ah) == "table"
				and type(rawget(ah, "__index")) == "table"
				and isCallable(rawget(rawget(ah, "__index"), "andThen"))
			then
				return true
			end
			return false
		end
		function af.promisify(ag)
			return function(...)
				return af._try(debug.traceback(nil, 2), ag, ...)
			end
		end
		do
			local ag
			local ah
			function af.delay(ai)
				assert(type(ai) == "number", "Bad argument #1 to Promise.delay, must be a number.")
				if not (ai >= 1.6666666666666665E-2) or ai == math.huge then
					ai = 1.6666666666666665E-2
				end
				return af._new(debug.traceback(nil, 2), function(aj, ak, al)
					local am = af._getTime()
					local an = am + ai
					local ao = { resolve = aj, startTime = am, endTime = an }
					if ah == nil then
						ag = ao
						ah = af._timeEvent:Connect(function()
							local ap = af._getTime()
							while ag ~= nil and ag.endTime < ap do
								local aq = ag
								ag = aq.next
								if ag == nil then
									ah.Disconnect(ah)
									ah = nil
								else
									ag.previous = nil
								end
								aq.resolve(af._getTime() - aq.startTime)
							end
						end)
					else
						if ag.endTime < an then
							local ap = ag
							local aq = ap.next
							while aq ~= nil and aq.endTime < an do
								ap = aq
								aq = ap.next
							end
							ap.next = ao
							ao.previous = ap
							if aq ~= nil then
								ao.next = aq
								aq.previous = ao
							end
						else
							ao.next = ag
							ag.previous = ao
							ag = ao
						end
					end
					al(function()
						local ap = ao.next
						if ag == ao then
							if ap == nil then
								ah.Disconnect(ah)
								ah = nil
							else
								ap.previous = nil
							end
							ag = ap
						else
							local aq = ao.previous
							aq.next = ap
							if ap ~= nil then
								ap.previous = aq
							end
						end
					end)
				end)
			end
		end
		function af.prototype:timeout(ag, ah)
			local ai = debug.traceback(nil, 2)
			return af.race({
				af.delay(ag):andThen(function()
					return af.reject(
						ah == nil
								and ae.new({
									kind = ae.Kind.TimedOut,
									error = "Timed out",
									context = string.format(
										"Timeout of %d seconds exceeded.\n:timeout() called at:\n\n%s",
										ag,
										ai
									),
								})
							or ah
					)
				end),
				self,
			})
		end
		function af.prototype:getStatus()
			return self._status
		end
		function af.prototype:_andThen(ag, ah, ai)
			self._unhandledRejection = false
			return af._new(ag, function(aj, ak)
				local al = aj
				if ah then
					al = createAdvancer(ag, ah, aj, ak)
				end
				local am = ak
				if ai then
					am = createAdvancer(ag, ai, aj, ak)
				end
				if self._status == af.Status.Started then
					table.insert(self._queuedResolve, al)
					table.insert(self._queuedReject, am)
				elseif self._status == af.Status.Resolved then
					al(unpack(self._values, 1, self._valuesLength))
				elseif self._status == af.Status.Rejected then
					am(unpack(self._values, 1, self._valuesLength))
				elseif self._status == af.Status.Cancelled then
					ak(
						ae.new({
							error = "Promise is cancelled",
							kind = ae.Kind.AlreadyCancelled,
							context = "Promise created at\n\n" .. ag,
						})
					)
				end
			end, self)
		end
		function af.prototype:andThen(ag, ah)
			assert(ag == nil or isCallable(ag), string.format(ac, "Promise:andThen"))
			assert(ah == nil or isCallable(ah), string.format(ac, "Promise:andThen"))
			return self._andThen(self, debug.traceback(nil, 2), ag, ah)
		end
		function af.prototype:andThenAsync(ag, ah)
			assert(ag == nil or isCallable(ag), string.format(ac, "Promise:andThenAsync"))
			assert(ah == nil or isCallable(ah), string.format(ac, "Promise:andThenAsync"))
			return self._andThen(self, debug.traceback(nil, 2), function(...)
				local ai, aj = pack(...)
				return af.defer(function(ak)
					ak(unpack(aj, 1, ai))
				end)
			end, function(...)
				local ai, aj = pack(...)
				return af.defer(function(ak, al)
					al(unpack(aj, 1, ai))
				end)
			end):andThen(ag, ah)
		end
		function af.prototype:catch(ag)
			assert(ag == nil or isCallable(ag), string.format(ac, "Promise:catch"))
			return self._andThen(self, debug.traceback(nil, 2), nil, ag)
		end
		function af.prototype:tap(ag)
			assert(isCallable(ag), string.format(ac, "Promise:tap"))
			return self._andThen(self, debug.traceback(nil, 2), function(...)
				local ah = ag(...)
				if af.is(ah) then
					local ai, aj = pack(...)
					return ah.andThen(ah, function()
						return unpack(aj, 1, ai)
					end)
				end
				return ...
			end)
		end
		function af.prototype:andThenCall(ag, ...)
			assert(isCallable(ag), string.format(ac, "Promise:andThenCall"))
			local ah, ai = pack(...)
			return self._andThen(self, debug.traceback(nil, 2), function()
				return ag(unpack(ai, 1, ah))
			end)
		end
		function af.prototype:andThenReturn(...)
			local ag, ah = pack(...)
			return self._andThen(self, debug.traceback(nil, 2), function()
				return unpack(ah, 1, ag)
			end)
		end
		function af.prototype:cancel()
			if self._status ~= af.Status.Started then
				return
			end
			self._status = af.Status.Cancelled
			if self._cancellationHook then
				self._cancellationHook()
			end
			coroutine.close(self._thread)
			if self._parent then
				self._parent:_consumerCancelled(self)
			end
			for ag in pairs(self._consumers) do
				ag.cancel(ag)
			end
			self._finalize(self)
		end
		function af.prototype:_consumerCancelled(ag)
			if self._status ~= af.Status.Started then
				return
			end
			self._consumers[ag] = nil
			if next(self._consumers) == nil then
				self.cancel(self)
			end
		end
		function af.prototype:_finally(ag, ah, ai)
			if not ai then
				self._unhandledRejection = false
			end
			return af._new(ag, function(aj, ak)
				local al = aj
				if ah then
					al = createAdvancer(ag, ah, aj, ak)
				end
				if ai then
					local am = al
					al = function(...)
						if self._status == af.Status.Rejected then
							return aj(self)
						end
						return am(...)
					end
				end
				if self._status == af.Status.Started then
					table.insert(self._queuedFinally, al)
				else
					al(self._status)
				end
			end, self)
		end
		function af.prototype:finally(ag)
			assert(ag == nil or isCallable(ag), string.format(ac, "Promise:finally"))
			return self._finally(self, debug.traceback(nil, 2), ag)
		end
		function af.prototype:finallyCall(ag, ...)
			assert(isCallable(ag), string.format(ac, "Promise:finallyCall"))
			local ah, ai = pack(...)
			return self._finally(self, debug.traceback(nil, 2), function()
				return ag(unpack(ai, 1, ah))
			end)
		end
		function af.prototype:finallyReturn(...)
			local ag, ah = pack(...)
			return self._finally(self, debug.traceback(nil, 2), function()
				return unpack(ah, 1, ag)
			end)
		end
		function af.prototype:done(ag)
			assert(ag == nil or isCallable(ag), string.format(ac, "Promise:done"))
			return self._finally(self, debug.traceback(nil, 2), ag, true)
		end
		function af.prototype:doneCall(ag, ...)
			assert(isCallable(ag), string.format(ac, "Promise:doneCall"))
			local ah, ai = pack(...)
			return self._finally(self, debug.traceback(nil, 2), function()
				return ag(unpack(ai, 1, ah))
			end, true)
		end
		function af.prototype:doneReturn(...)
			local ag, ah = pack(...)
			return self._finally(self, debug.traceback(nil, 2), function()
				return unpack(ah, 1, ag)
			end, true)
		end
		function af.prototype:awaitStatus()
			self._unhandledRejection = false
			if self._status == af.Status.Started then
				local ag = coroutine.running()
				self.finally(self, function()
					task.spawn(ag)
				end)
				coroutine.yield()
			end
			if self._status == af.Status.Resolved then
				return self._status, unpack(self._values, 1, self._valuesLength)
			elseif self._status == af.Status.Rejected then
				return self._status, unpack(self._values, 1, self._valuesLength)
			end
			return self._status
		end
		local function awaitHelper(ag, ...)
			return ag == af.Status.Resolved, ...
		end
		function af.prototype:await()
			return awaitHelper(self.awaitStatus(self))
		end
		local function expectHelper(ag, ...)
			if ag ~= af.Status.Resolved then
				error((...) == nil and "Expected Promise rejected with no value." or (...), 3)
			end
			return ...
		end
		function af.prototype:expect()
			return expectHelper(self.awaitStatus(self))
		end
		af.prototype.awaitValue = af.prototype.expect
		function af.prototype:_unwrap()
			if self._status == af.Status.Started then
				error("Promise has not resolved or rejected.", 2)
			end
			local ag = self._status == af.Status.Resolved
			return ag, unpack(self._values, 1, self._valuesLength)
		end
		function af.prototype:_resolve(...)
			if self._status ~= af.Status.Started then
				if af.is((...)) then
					(...):_consumerCancelled(self)
				end
				return
			end
			if af.is((...)) then
				if select("#", ...) > 1 then
					local ag = string.format(
						"When returning a Promise from andThen, extra arguments are discarded! See:\n\n%s",
						self._source
					)
					warn(ag)
				end
				local ag = ...
				local ah = ag.andThen(ag, function(...)
					self._resolve(self, ...)
				end, function(...)
					local ah = ag._values[1]
					if ag._error then
						ah = ae.new({
							error = ag._error,
							kind = ae.Kind.ExecutionError,
							context = "[No stack trace available as this Promise originated from an older version of the Promise library (< v2)]",
						})
					end
					if ae.isKind(ah, ae.Kind.ExecutionError) then
						return self._reject(
							self,
							ah.extend(
								ah,
								{
									error = "This Promise was chained to a Promise that errored.",
									trace = "",
									context = string.format(
										"The Promise at:\n\n%s\n...Rejected because it was chained to the following Promise, which encountered an error:\n",
										self._source
									),
								}
							)
						)
					end
					self._reject(self, ...)
				end)
				if ah._status == af.Status.Cancelled then
					self.cancel(self)
				elseif ah._status == af.Status.Started then
					self._parent = ah
					ah._consumers[self] = true
				end
				return
			end
			self._status = af.Status.Resolved
			self._valuesLength, self._values = pack(...)
			for ag, ah in ipairs(self._queuedResolve) do
				coroutine.wrap(ah)(...)
			end
			self._finalize(self)
		end
		function af.prototype:_reject(...)
			if self._status ~= af.Status.Started then
				return
			end
			self._status = af.Status.Rejected
			self._valuesLength, self._values = pack(...)
			if not isEmpty(self._queuedReject) then
				for ag, ah in ipairs(self._queuedReject) do
					coroutine.wrap(ah)(...)
				end
			else
				local ag = tostring((...))
				coroutine.wrap(function()
					af._timeEvent:Wait()
					if not self._unhandledRejection then
						return
					end
					local ah = string.format("Unhandled Promise rejection:\n\n%s\n\n%s", ag, self._source)
					for ai, aj in ipairs(af._unhandledRejectionCallbacks) do
						task.spawn(aj, self, unpack(self._values, 1, self._valuesLength))
					end
					if af.TEST then
						return
					end
					warn(ah)
				end)()
			end
			self._finalize(self)
		end
		function af.prototype:_finalize()
			for ag, ah in ipairs(self._queuedFinally) do
				coroutine.wrap(ah)(self._status)
			end
			self._queuedFinally = nil
			self._queuedReject = nil
			self._queuedResolve = nil
			if not af.TEST then
				self._parent = nil
				self._consumers = nil
			end
			task.defer(coroutine.close, self._thread)
		end
		function af.prototype:now(ag)
			local ah = debug.traceback(nil, 2)
			if self._status == af.Status.Resolved then
				return self._andThen(self, ah, function(...)
					return ...
				end)
			else
				return af.reject(
					ag == nil
							and ae.new({
								kind = ae.Kind.NotResolvedInTime,
								error = "This Promise was not resolved in time for :now()",
								context = ":now() was called at:\n\n" .. ah,
							})
						or ag
				)
			end
		end
		function af.retry(ag, ah, ...)
			assert(isCallable(ag), "Parameter #1 to Promise.retry must be a function")
			assert(type(ah) == "number", "Parameter #2 to Promise.retry must be a number")
			local ai, aj = { ... }, select("#", ...)
			return af.resolve(ag(...)):catch(function(...)
				if ah > 0 then
					return af.retry(ag, ah - 1, unpack(ai, 1, aj))
				else
					return af.reject(...)
				end
			end)
		end
		function af.retryWithDelay(ag, ah, ai, ...)
			assert(isCallable(ag), "Parameter #1 to Promise.retry must be a function")
			assert(type(ah) == "number", "Parameter #2 (times) to Promise.retry must be a number")
			assert(type(ai) == "number", "Parameter #3 (seconds) to Promise.retry must be a number")
			local aj, ak = { ... }, select("#", ...)
			return af.resolve(ag(...)):catch(function(...)
				if ah > 0 then
					af.delay(ai):await()
					return af.retryWithDelay(ag, ah - 1, ai, unpack(aj, 1, ak))
				else
					return af.reject(...)
				end
			end)
		end
		function af.fromEvent(ag, ah)
			ah = ah or function()
				return true
			end
			return af._new(debug.traceback(nil, 2), function(ai, aj, ak)
				local al
				local am = false
				local function disconnect()
					al.Disconnect(al)
					al = nil
				end
				al = ag.Connect(ag, function(...)
					local an = ah(...)
					if an == true then
						ai(...)
						if al then
							disconnect()
						else
							am = true
						end
					elseif type(an) ~= "boolean" then
						error("Promise.fromEvent predicate should always return a boolean")
					end
				end)
				if am and al then
					return disconnect()
				end
				ak(disconnect)
			end)
		end
		function af.onUnhandledRejection(ag)
			table.insert(af._unhandledRejectionCallbacks, ag)
			return function()
				local ah = table.find(af._unhandledRejectionCallbacks, ag)
				if ah then
					table.remove(af._unhandledRejectionCallbacks, ah)
				end
			end
		end
		return af
	end
	function a.cV()
		return a.load("cU")
	end
	function a.cW()
		local aa = a.load("b0").getComponentName
		local ab = a.load("b1")
		local ac = a.load("cj")
		local ad = 1
		local ae = 10
		local af = _G.__REACT_MICROPROFILER_LEVEL or 0
		local ag = false
		local ah
		function startTimerSampling(ai)
			if ag then
				warn("RobloxReactProfiling Timer Sampling already running.")
			end
			ag = true
			ah = ai
		end
		function endTimerSampling()
			ag = false
			ah = nil
		end
		function getFirstStringKey(ai)
			for aj, ak in ai do
				if type(aj) == "string" then
					return aj
				end
			end
			return nil
		end
		function startTimer(ai)
			if ag then
				ai.startTime = os.clock()
			end
		end
		function endTimer(ai)
			if ag then
				ai.endTime = os.clock()
				if ah then
					ah(ai)
				end
			end
		end
		function profileRootBeforeUnitOfWork(ai)
			local aj = ai.current
			local ak
			if aj then
				if aj.memoizedProps then
					ak = getFirstStringKey(aj.memoizedProps)
				end
				if ak == nil and aj.stateNode and aj.stateNode.containerInfo then
					ak = aj.stateNode.containerInfo.Name
				end
			end
			if ak == "Folder" and aj.child then
				local al = aj.child
				local am
				if al.memoizedProps then
					am = getFirstStringKey(al.memoizedProps)
				end
				if am == nil and al.stateNode and al.stateNode.containerInfo then
					am = al.stateNode.containerInfo.Name
				end
				if am ~= nil then
					ak = am
				end
			end
			if ak ~= nil then
				local al = {
					id = ak,
					startTime = 0,
					endTime = 0,
				}
				startTimer(al)
				return al
			end
			return nil
		end
		function profileRootAfterYielding(ai)
			if ai then
				endTimer(ai)
			end
		end
		function profileUnitOfWorkBefore(ai)
			local aj = aa(ai.type)
			if ai.key then
				aj = tostring(ai.key) .. "=" .. (aj or "?")
			end
			local ak
			if ai.stateNode then
				if ai.tag == ab.HostComponent or ai.tag == ab.HostText then
					local al = ai.stateNode:FindFirstAncestorWhichIsA("LayerCollector")
					if al then
						ak = "[" .. al.GetFullName(al) .. "] "
					end
				end
			end
			if ak then
				aj = ak .. " : " .. (aj or "?")
			end
			if aj ~= nil then
				return true
			end
			return false
		end
		function profileUnitOfWorkAfter(ai)
			if ai then
			end
		end
		function profileCommitBefore() end
		function profileCommitAfter() end
		function noop(...) end
		return {
			startTimerSampling = startTimerSampling,
			endTimerSampling = endTimerSampling,
			profileRootBeforeUnitOfWork = if af >= ad then profileRootBeforeUnitOfWork else noop,
			profileRootAfterYielding = if af >= ad then profileRootAfterYielding else noop,
			profileUnitOfWorkBefore = if af >= ae then profileUnitOfWorkBefore else noop,
			profileUnitOfWorkAfter = if af >= ae then profileUnitOfWorkAfter else noop,
			profileCommitBefore = if af >= ad then profileCommitBefore else noop,
			profileCommitAfter = if af >= ad then profileCommitAfter else noop,
		}
	end
	function a.cX()
		return a.load("bY")
	end
	function a.cY()
		local aa = a.load("b0").console
		local ab = a.load("cj")
		local ac = a.load("cR")
		local ad = ac.resetCurrentFiber
		local ae = ac.setCurrentFiber
		local af = a.load("b0").getComponentName
		local ag = a.load("b2").StrictMode
		local ah = {
			recordUnsafeLifecycleWarnings = function(ah, ai) end,
			flushPendingUnsafeLifecycleWarnings = function() end,
			recordLegacyContextWarning = function(ah, ai) end,
			flushLegacyContextWarning = function() end,
			discardPendingWarnings = function() end,
		}
		if _G.__DEV__ then
			local ai = function(ai)
				local aj
				local ak = ai
				while ak ~= nil do
					if bit32.band(ak.mode, ag) ~= 0 then
						aj = ak
					end
					ak = ak.return_
				end
				return aj
			end
			local aj = function(aj)
				local ak = {}
				for al, am in aj do
					table.insert(ak, al)
				end
				table.sort(ak)
				return table.concat(ak, ", ")
			end
			local ak = {}
			local al = {}
			local am = {}
			local an = {}
			local ao = {}
			local ap = {}
			local aq = {}
			ah.recordUnsafeLifecycleWarnings = function(ar, as)
				if aq[ar.type] then
					return
				end
				if typeof(as.componentWillMount) == "function" then
					table.insert(ak, ar)
				end
				if bit32.band(ar.mode, ag) ~= 0 and typeof(as.UNSAFE_componentWillMount) == "function" then
					table.insert(al, ar)
				end
				if typeof(as.componentWillReceiveProps) == "function" then
					table.insert(am, ar)
				end
				if bit32.band(ar.mode, ag) ~= 0 and typeof(as.UNSAFE_componentWillReceiveProps) == "function" then
					table.insert(an, ar)
				end
				if typeof(as.componentWillUpdate) == "function" then
					table.insert(ao, ar)
				end
				if bit32.band(ar.mode, ag) ~= 0 and typeof(as.UNSAFE_componentWillUpdate) == "function" then
					table.insert(ap, ar)
				end
			end
			ah.flushPendingUnsafeLifecycleWarnings = function()
				local ar = {}
				if #ak > 0 then
					for as, au in ak do
						ar[af(au.type) or "Component"] = true
						aq[au.type] = true
					end
					table.clear(ak)
				end
				local as = {}
				if #al > 0 then
					for au, av in al do
						as[af(av.type) or "Component"] = true
						aq[av.type] = true
					end
					table.clear(al)
				end
				local au = {}
				if #am > 0 then
					for av, aw in am do
						au[af(aw.type) or "Component"] = true
						aq[aw.type] = true
					end
					table.clear(am)
				end
				local av = {}
				if #an > 0 then
					for aw, ax in an do
						av[af(ax.type) or "Component"] = true
						aq[ax.type] = true
					end
					table.clear(an)
				end
				local aw = {}
				if #ao > 0 then
					for ax, ay in ao do
						aw[af(ay.type) or "Component"] = true
						aq[ay.type] = true
					end
					table.clear(ao)
				end
				local ax = {}
				if #ap > 0 then
					for ay, az in ap do
						ax[af(az.type) or "Component"] = true
						aq[az.type] = true
					end
					table.clear(ap)
				end
				if next(as) ~= nil then
					local ay = aj(as)
					aa.error(
						"Using UNSAFE_componentWillMount in strict mode is not recommended and may indicate bugs in your code. See https://reactjs.org/link/unsafe-component-lifecycles for details.\n\n* Move code with side effects to componentDidMount, and set initial state in the constructor.\n\nPlease update the following components: %s",
						ay
					)
				end
				if next(av) ~= nil then
					local ay = aj(av)
					aa.error(
						"Using UNSAFE_componentWillReceiveProps in strict mode is not recommended and may indicate bugs in your code. See https://reactjs.org/link/unsafe-component-lifecycles for details.\n\n* Move data fetching code or side effects to componentDidUpdate.\n* If you're updating state whenever props change, refactor your code to use memoization techniques or move it to static getDerivedStateFromProps. Learn more at: https://reactjs.org/link/derived-state\n\nPlease update the following components: %s",
						ay
					)
				end
				if next(ax) ~= nil then
					local ay = aj(ax)
					aa.error(
						"Using UNSAFE_componentWillUpdate in strict mode is not recommended and may indicate bugs in your code. See https://reactjs.org/link/unsafe-component-lifecycles for details.\n\n* Move data fetching code or side effects to componentDidUpdate.\n\nPlease update the following components: %s",
						ay
					)
				end
				if next(ar) ~= nil then
					local ay = aj(ar)
					aa.warn(
						"componentWillMount has been renamed, and is not recommended for use. See https://reactjs.org/link/unsafe-component-lifecycles for details.\n\n* Move code with side effects to componentDidMount, and set initial state in the constructor.\n* Rename componentWillMount to UNSAFE_componentWillMount to suppress this warning in non-strict mode. In React 18.x, only the UNSAFE_ name will work.\n\nPlease update the following components: %s",
						ay
					)
				end
				if next(au) ~= nil then
					local ay = aj(au)
					aa.warn(
						"componentWillReceiveProps has been renamed, and is not recommended for use. See https://reactjs.org/link/unsafe-component-lifecycles for details.\n\n* Move data fetching code or side effects to componentDidUpdate.\n* If you're updating state whenever props change, refactor your code to use memoization techniques or move it to static getDerivedStateFromProps. Learn more at: https://reactjs.org/link/derived-state\n* Rename componentWillReceiveProps to UNSAFE_componentWillReceiveProps to suppress this warning in non-strict mode. In React 18.x, only the UNSAFE_ name will work.\n\nPlease update the following components: %s",
						ay
					)
				end
				if next(aw) ~= nil then
					local ay = aj(aw)
					aa.warn(
						"componentWillUpdate has been renamed, and is not recommended for use. See https://reactjs.org/link/unsafe-component-lifecycles for details.\n\n* Move data fetching code or side effects to componentDidUpdate.\n* Rename componentWillUpdate to UNSAFE_componentWillUpdate to suppress this warning in non-strict mode. In React 18.x, only the UNSAFE_ name will work.\n\nPlease update the following components: %s",
						ay
					)
				end
			end
			local ar = {}
			local as = {}
			ah.recordLegacyContextWarning = function(au, av)
				local aw = ai(au)
				if aw == nil then
					aa.error("Expected to find a StrictMode component in a strict mode tree. This error is likely caused by a bug in React. Please file an issue.")
					return
				end
				if as[au.type] then
					return
				end
				local ax = ar[aw]
				if
					typeof(au.type) ~= "function"
					and (
						au.type.contextTypes ~= nil
						or au.type.childContextTypes ~= nil
						or (av ~= nil and typeof(av.getChildContext) == "function")
					)
				then
					if ax == nil then
						ax = {}
						ar[aw] = ax
					end
					table.insert(ax, au)
				end
			end
			ah.flushLegacyContextWarning = function()
				for au, av in ar do
					if #av == 0 then
						return
					end
					local aw = av[1]
					local ax = {}
					for ay, az in av do
						ax[af(az.type) or "Component"] = true
						as[az.type] = true
					end
					local ay = aj(ax)
					local az, aA = pcall(function()
						ae(aw)
						aa.error(
							"Legacy context API has been detected within a strict-mode tree.\n\nThe old API will be supported in all 16.x releases, but applications using it should migrate to the new version.\n\nPlease update the following components: %s\n\nLearn more about this warning here: https://reactjs.org/link/legacy-context",
							ay
						)
					end)
					ad()
					if not az then
						error(aA)
					end
				end
			end
			ah.discardPendingWarnings = function()
				table.clear(ak)
				table.clear(al)
				table.clear(am)
				table.clear(an)
				table.clear(ao)
				table.clear(ap)
				table.clear(ar)
			end
		end
		return ah
	end
	function a.cZ()
		local aa = _G.__DEV__
		local ab = a.load("b_")
		local ac = ab.Array
		local ad = ab.Error
		local ae = a.load("b0").console
		local af = a.load("b0").describeError
		local ag = a.load("b0")
		local ah = a.load("cX")
		local ai = a.load("cj")
		local aj = a.load("cn")
		local ak = a.load("b0").getComponentName
		local al = a.load("b3")
		local am = al.Placement
		local an = al.Deletion
		local ao = a.load("b0").ReactSymbols
		local ap = ao.getIteratorFn
		local aq = ao.REACT_ELEMENT_TYPE
		local ar = ao.REACT_FRAGMENT_TYPE
		local as = ao.REACT_PORTAL_TYPE
		local au = ao.REACT_LAZY_TYPE
		local av = ao.REACT_BLOCK_TYPE
		local aw = a.load("b1")
		local ax = aw.FunctionComponent
		local ay = aw.ClassComponent
		local az = aw.HostText
		local aA = aw.HostPortal
		local aC = aw.ForwardRef
		local aD = aw.Fragment
		local aE = aw.SimpleMemoComponent
		local aF = aw.Block
		local aG = a.load("b0").invariant
		local aH = a.load("b0").ReactFeatureFlags
		local aI = aH.enableLazyElements
		local aJ = aH.enableBlocksAPI
		local aK = a.load("cv")
		local aL = aK.createWorkInProgress
		local aM = aK.resetWorkInProgress
		local aN = aK.createFiberFromElement
		local aO = aK.createFiberFromFragment
		local aP = aK.createFiberFromText
		local aQ = aK.createFiberFromPortal
		local aR = {}
		local aS
		local aT
		local aU
		local aV = function(aV, aW) end
		if aa then
			aS = false
			aT = {}
			aU = {}
			aV = function(aW, aX)
				if aW == nil or type(aW) ~= "table" then
					return
				end
				if not aW._store or aW._store.validated or aW.key ~= nil then
					return
				end
				aG(
					aW._store ~= nil and type(aW._store) == "table",
					"React Component in warnForMissingKey should have a _store. This error is likely caused by a bug in React. Please file an issue."
				)
				aW._store.validated = true
				local aY = ak(aX.type) or "Component"
				if aT[aY] then
					return
				end
				aT[aY] = true
				ae.error('Each child in a list should have a unique "key" prop. See https://reactjs.org/link/warning-keys for more information.')
			end
		end
		local aW = ac.isArray
		function coerceRef(aX, aY, aZ)
			local a_ = aZ.ref
			if a_ ~= nil and type(a_) == "string" then
				if not aZ._owner or not aZ._self or aZ._owner.stateNode == aZ._self then
					local b
					if aa then
						b = ak(aX.type) or "Component"
					else
						b = "<enable __DEV__ mode for component names>"
					end
					error(
						ad.new(
							string.format(
								'Component "%s" contains the string ref "%s". Support for string refs has been removed. We recommend using useRef() or createRef() instead. Learn more about using refs safely here: https://reactjs.org/link/strict-mode-string-ref',
								b,
								tostring(a_)
							)
						)
					)
				end
				if not aZ._owner then
					error("Expected ref to be a function or an object returned by React.createRef(), or nil.")
				end
			end
			return a_
		end
		local function warnOnFunctionType(aX)
			if aa then
				local aY = ak(aX.type) or "Component"
				if aU[aY] then
					return
				end
				aU[aY] = true
				ae.error("Functions are not valid as a React child. This may happen if you return a Component instead of <Component /> from render. Or maybe you meant to call this function rather than return it.")
			end
		end
		function resolveLazyType(aX)
			local aY = aX._payload
			local aZ = aX._init
			local a_, b = xpcall(aZ, af, aY)
			if not a_ then
				return aX
			end
			return b
		end
		local function ChildReconciler(aX)
			local function deleteChild(aY, aZ)
				if not aX then
					return
				end
				local a_ = aY.deletions
				if a_ == nil then
					aY.deletions = { aZ }
					aY.flags = bit32.bor(aY.flags, an)
				else
					table.insert(a_, aZ)
				end
			end
			local function deleteRemainingChildren(aY, aZ)
				if not aX then
					return nil
				end
				local a_ = aZ
				while a_ ~= nil do
					deleteChild(aY, a_)
					a_ = a_.sibling
				end
				return nil
			end
			local function mapRemainingChildren(aY, aZ)
				local a_ = {}
				local b = aZ
				while b ~= nil do
					if b.key ~= nil then
						a_[b.key] = b
					else
						a_[b.index] = b
					end
					b = b.sibling
				end
				return a_
			end
			local function useFiber(aY, aZ)
				local a_ = aL(aY, aZ)
				a_.index = 1
				a_.sibling = nil
				return a_
			end
			local function placeChild(aY, aZ, a_)
				aY.index = a_
				if not aX then
					return aZ
				end
				local b = aY.alternate
				if b ~= nil then
					local c = b.index
					if c < aZ then
						aY.flags = bit32.bor(aY.flags, am)
						return aZ
					else
						return c
					end
				else
					aY.flags = bit32.bor(aY.flags, am)
					return aZ
				end
			end
			local function placeSingleChild(aY)
				if aX and aY.alternate == nil then
					aY.flags = bit32.bor(aY.flags, am)
				end
				return aY
			end
			local function updateTextNode(aY, aZ, a_, b)
				if aZ == nil or (aZ).tag ~= az then
					local c = aP(a_, aY.mode, b)
					c.return_ = aY
					return c
				else
					local c = useFiber(aZ, a_)
					c.return_ = aY
					return c
				end
			end
			local function updateElement(aY, aZ, a_, b)
				if aZ ~= nil then
					if (aZ).elementType == a_.type then
						local c = useFiber(aZ, a_.props)
						c.ref = coerceRef(aY, aZ, a_)
						c.return_ = aY
						if aa then
							c._debugSource = a_._source
							c._debugOwner = a_._owner
						end
						return c
					elseif aJ and (aZ).tag == aF then
						local c = a_.type
						if type(c) == "table" and c["$$typeof"] == au then
							c = (resolveLazyType(c))
						end
						if c["$$typeof"] == av and c._render == (aZ).type._render then
							local d = useFiber(aZ, a_.props)
							d.return_ = aY
							d.type = c
							if aa then
								d._debugSource = a_._source
								d._debugOwner = a_._owner
							end
							return d
						end
					end
				end
				local c = aN(a_, aY.mode, b)
				c.ref = coerceRef(aY, aZ, a_)
				c.return_ = aY
				return c
			end
			local function updatePortal(aY, aZ, a_, b)
				if
					aZ == nil
					or (aZ).tag ~= aA
					or (aZ).stateNode.containerInfo ~= a_.containerInfo
					or (aZ).stateNode.implementation ~= a_.implementation
				then
					local c = aQ(a_, aY.mode, b)
					c.return_ = aY
					return c
				else
					local c = useFiber(aZ, a_.children or {})
					c.return_ = aY
					return c
				end
			end
			local function updateFragment(aY, aZ, a_, b, c)
				if aZ == nil or (aZ).tag ~= aD then
					local d = aO(a_, aY.mode, b, c)
					d.return_ = aY
					return d
				else
					local d = useFiber(aZ, a_)
					d.return_ = aY
					return d
				end
			end
			local function assignStableKey(aY, aZ)
				if aZ.key == nil then
					local a_ = type(aY)
					if a_ == "string" or a_ == "number" then
						aZ.key = aY
					elseif a_ == "table" then
						aZ.key = tostring(aY)
					end
				end
			end
			local function createChild(aY, aZ, a_, b)
				if aZ == nil then
					return nil
				end
				local c = type(aZ)
				if c == "table" then
					assignStableKey(b, aZ)
					local d = aZ["$$typeof"]
					if d == aq then
						local e = aN(aZ, aY.mode, a_)
						e.ref = coerceRef(aY, nil, aZ)
						e.return_ = aY
						return e
					elseif d == as then
						local e = aQ(aZ, aY.mode, a_)
						e.return_ = aY
						return e
					elseif d == au then
						if aI then
							local e = aZ._payload
							local g = aZ._init
							return createChild(aY, g(e), a_)
						end
					end
					local e = aO(aZ, aY.mode, a_, nil)
					e.return_ = aY
					return e
				end
				if c == "string" or c == "number" then
					local d = aP(tostring(aZ), aY.mode, a_)
					d.return_ = aY
					return d
				end
				if aa then
					if c == "function" then
						warnOnFunctionType(aY)
					end
				end
				return nil
			end
			local function updateSlot(aY, aZ, a_, b, c)
				if a_ == nil then
					return nil
				end
				local d = if aZ ~= nil then aZ.key else nil
				local e = type(a_)
				if e == "table" then
					assignStableKey(c, a_)
					local g = a_["$$typeof"]
					if g == aq then
						if a_.key == d then
							if a_.type == ar then
								return updateFragment(aY, aZ, a_.props.children, b, d)
							end
							return updateElement(aY, aZ, a_, b)
						else
							return nil
						end
					elseif g == as then
						if a_.key == d then
							return updatePortal(aY, aZ, a_, b)
						else
							return nil
						end
					elseif g == au then
						if aI then
							local h = a_._payload
							local i = a_._init
							return updateSlot(aY, aZ, i(h), b)
						end
					end
					if d ~= nil then
						return nil
					end
					return updateFragment(aY, aZ, a_, b)
				end
				if e == "string" or e == "number" then
					if d ~= nil then
						return nil
					end
					return updateTextNode(aY, aZ, tostring(a_), b)
				end
				if aa then
					if e == "function" then
						warnOnFunctionType(aY)
					end
				end
				return nil
			end
			local function updateFromMap(aY, aZ, a_, b, c, d)
				if b == nil then
					return nil
				end
				local e = type(b)
				if e == "table" then
					assignStableKey(d, b)
					local g
					local h = b["$$typeof"]
					if h == aq then
						if b.key == nil then
							g = a_
						else
							g = b.key
						end
						local i = aY[g]
						if b.type == ar then
							return updateFragment(aZ, i, b.props.children, c, b.key)
						end
						return updateElement(aZ, i, b, c)
					elseif h == as then
						if b.key == nil then
							g = a_
						else
							g = b.key
						end
						local i = aY[g]
						return updatePortal(aZ, i, b, c)
					elseif h == au then
						if aI then
							local i = b._payload
							local j = b._init
							return updateFromMap(aY, aZ, a_, j(i), c)
						end
					end
					local i = aY[a_]
					return updateFragment(aZ, i, b, c)
				end
				if e == "string" or e == "number" then
					local g = aY[a_] or nil
					return updateTextNode(aZ, g, tostring(b), c)
				end
				if aa then
					if e == "function" then
						warnOnFunctionType(aZ)
					end
				end
				return nil
			end
			local function warnOnInvalidKey(aY, aZ, a_)
				if aa then
					if aY == nil or type(aY) ~= "table" then
						return aZ
					end
					local b = aY["$$typeof"]
					if b == aq or b == as then
						aV(aY, a_)
						local c = aY.key
						if type(c) ~= "string" then
						elseif aZ == nil then
							aZ = {};
							(aZ)[c] = true
						elseif not (aZ)[c] then
							(aZ)[c] = true
						else
							ae.error(
								"Encountered two children with the same key, `%s`. Keys should be unique so that components maintain their identity across updates. Non-unique keys may cause children to be duplicated and/or omitted \u{2014} the behavior is unsupported and could change in a future version.",
								c
							)
						end
					elseif b == au then
						if aI then
							local c = aY._payload
							local d = aY._init
							warnOnInvalidKey(d(c), aZ, a_)
						end
					end
				end
				return aZ
			end
			local function reconcileChildrenArray(aY, aZ, a_, b)
				if aa then
					local c
					for d, e in a_ do
						c = warnOnInvalidKey(e, c, aY)
					end
				end
				local c
				local d
				local e = aZ
				local g = 1
				local h = 1
				local i
				local j = #a_
				while e ~= nil and h <= j do
					if e.index > h then
						i = e
						e = nil
					else
						i = e.sibling
					end
					local k
					local l = a_[h]
					if l ~= nil and type(l) == "table" and l["$$typeof"] ~= nil then
						k = updateSlot(aY, e, l, b, h)
					else
						k = updateSlot(aY, e, l, b)
					end
					if k == nil then
						if e == nil then
							e = i
						end
						break
					end
					if aX then
						if e and (k).alternate == nil then
							deleteChild(aY, e)
						end
					end
					g = placeChild(k, g, h)
					if d == nil then
						c = k
					else
						(d).sibling = k
					end
					d = k
					e = i
					h += 1
				end
				if h > j then
					deleteRemainingChildren(aY, e)
					return c
				end
				if e == nil then
					while h <= j do
						local k
						local l = a_[h]
						if l ~= nil and type(l) == "table" and l["$$typeof"] ~= nil then
							k = createChild(aY, l, b, h)
						else
							k = createChild(aY, l, b)
						end
						if k == nil then
							h += 1
							continue
						end
						g = placeChild(k, g, h)
						if d == nil then
							c = k
						else
							(d).sibling = k
						end
						d = k
						h += 1
					end
					return c
				end
				local k = mapRemainingChildren(aY, e)
				while h <= j do
					local l = updateFromMap(k, aY, h, a_[h], b, h)
					if l ~= nil then
						if aX then
							if l.alternate ~= nil then
								k[if l.key == nil then h else l.key] = nil
							end
						end
						g = placeChild(l, g, h)
						if d == nil then
							c = l
						else
							(d).sibling = l
						end
						d = l
					end
					h += 1
				end
				if aX then
					for l, m in k do
						deleteChild(aY, m)
					end
				end
				return c
			end
			local function reconcileChildrenIterator(aY, aZ, a_, b, c)
				if aa then
					if a_.entries == c then
						if not aS then
							ae.error("Using Maps as children is not supported. Use an array of keyed ReactElements instead.")
						end
						aS = true
					end
					local d = c(a_)
					if d then
						local e
						local g = d.next()
						while not g.done do
							g = d.next()
							local h = g.value
							e = warnOnInvalidKey(h, e, aY)
						end
					end
				end
				local d = c(a_)
				local e
				local g
				local h = aZ
				local i = 1
				local j = 1
				local k
				local l = d.next()
				while h ~= nil and not l.done do
					if h.index > j then
						k = h
						h = nil
					else
						k = h.sibling
					end
					local m = updateSlot(aY, h, l.value, b, l.key)
					if m == nil then
						if h == nil then
							h = k
						end
						break
					end
					if aX then
						if h and (m).alternate == nil then
							deleteChild(aY, h)
						end
					end
					i = placeChild(m, i, j)
					if g == nil then
						e = m
					else
						g.sibling = m
					end
					g = m
					h = k
					j += 1
					l = d.next()
				end
				if l.done then
					deleteRemainingChildren(aY, h)
					return e
				end
				if h == nil then
					while not l.done do
						local m = createChild(aY, l.value, b, l.key)
						if m == nil then
							j += 1
							l = d.next()
							continue
						end
						i = placeChild(m, i, j)
						if g == nil then
							e = m
						else
							g.sibling = m
						end
						g = m
						j += 1
						l = d.next()
					end
					return e
				end
				local m
				while not l.done do
					if not m then
						m = mapRemainingChildren(aY, h)
					end
					local n = updateFromMap(m, aY, j, l.value, b, l.key)
					if n ~= nil then
						if aX then
							if n.alternate ~= nil then
								if n.key == nil then
									m[j] = nil
								else
									m[n.key] = nil
								end
							end
						end
						i = placeChild(n, i, j)
						if g == nil then
							e = n
						else
							g.sibling = n
						end
						g = n
					end
					j += 1
					l = d.next()
				end
				if aX then
					for n, o in m do
						deleteChild(aY, o)
					end
				end
				return e
			end
			local function reconcileSingleTextNode(aY, aZ, a_, b)
				if aZ ~= nil and (aZ).tag == az then
					deleteRemainingChildren(aY, (aZ).sibling)
					local c = useFiber(aZ, a_)
					c.return_ = aY
					return c
				end
				deleteRemainingChildren(aY, aZ)
				local c = aP(a_, aY.mode, b)
				c.return_ = aY
				return c
			end
			local function reconcileSingleElement(aY, aZ, a_, b)
				local c = a_.key
				local d = aZ
				while d ~= nil do
					if d.key == c then
						if d.tag == aD then
							if a_.type == ar then
								deleteRemainingChildren(aY, d.sibling)
								local e = useFiber(d, a_.props.children)
								e.return_ = aY
								if aa then
									e._debugSource = a_._source
									e._debugOwner = a_._owner
								end
								return e
							end
						else
							if d.elementType == a_.type then
								deleteRemainingChildren(aY, d.sibling)
								local e = useFiber(d, a_.props)
								e.ref = coerceRef(aY, d, a_)
								e.return_ = aY
								if aa then
									e._debugSource = a_._source
									e._debugOwner = a_._owner
								end
								return e
							end
						end
						deleteRemainingChildren(aY, d)
						break
					else
						deleteChild(aY, d)
					end
					d = d.sibling
				end
				if a_.type == ar then
					local e = aO(a_.props.children, aY.mode, b, a_.key)
					e.return_ = aY
					return e
				else
					local e = aN(a_, aY.mode, b)
					e.ref = coerceRef(aY, aZ, a_)
					e.return_ = aY
					return e
				end
			end
			local function reconcileSinglePortal(aY, aZ, a_, b)
				local c = a_.key
				local d = aZ
				while d ~= nil do
					if d.key == c then
						if
							d.tag == aA
							and d.stateNode.containerInfo == a_.containerInfo
							and d.stateNode.implementation == a_.implementation
						then
							deleteRemainingChildren(aY, d.sibling)
							local e = useFiber(d, a_.children or {})
							e.return_ = aY
							return e
						else
							deleteRemainingChildren(aY, d)
							break
						end
					else
						deleteChild(aY, d)
					end
					d = d.sibling
				end
				local e = aQ(a_, aY.mode, b)
				e.return_ = aY
				return e
			end
			local function reconcileChildFibers(aY, aZ, a_, b)
				local c = type(a_)
				local d = a_ ~= nil and c == "table" and a_.type == ar and a_.key == nil
				if d then
					a_ = a_.props.children
					c = type(a_)
				end
				local e = aW(a_)
				local g = a_ ~= nil and c == "table" and not e
				if g then
					local h = a_["$$typeof"]
					if h == aq then
						return placeSingleChild(reconcileSingleElement(aY, aZ, a_, b))
					elseif h == as then
						return placeSingleChild(reconcileSinglePortal(aY, aZ, a_, b))
					elseif h == au then
						if aI then
							local i = a_._payload
							local j = a_._init
							return reconcileChildFibers(aY, aZ, j(i), b)
						end
					end
				elseif e then
					return reconcileChildrenArray(aY, aZ, a_, b)
				elseif c == "string" or c == "number" then
					return placeSingleChild(reconcileSingleTextNode(aY, aZ, tostring(a_), b))
				end
				local h = ap(a_)
				if h then
					return reconcileChildrenIterator(aY, aZ, a_, b, h)
				end
				if aa then
					if c == "function" then
						warnOnFunctionType(aY)
					end
				end
				if a_ == nil and not d then
					local i = false
					if i and (aY.tag == ay or aY.tag == ax or aY.tag == aC or aY.tag == aE) then
						aG(
							false,
							"%s(...): Nothing was returned from render. This usually means a return statement is missing. Or, to render nothing, return nil.",
							ak(aY.type) or "Component"
						)
					end
				end
				return deleteRemainingChildren(aY, aZ)
			end
			return reconcileChildFibers
		end
		aR.reconcileChildFibers = ChildReconciler(true)
		aR.mountChildFibers = ChildReconciler(false)
		aR.cloneChildFibers = function(aX, aY)
			if aY.child == nil then
				return
			end
			local aZ = aY.child
			local a_ = aL(aZ, aZ.pendingProps)
			aY.child = a_
			a_.return_ = aY
			while aZ.sibling ~= nil do
				aZ = aZ.sibling
				a_.sibling = aL(aZ, aZ.pendingProps)
				a_ = a_.sibling
				a_.return_ = aY
			end
			a_.sibling = nil
		end
		aR.resetChildFibers = function(aX, aY)
			local aZ = aX.child
			while aZ ~= nil do
				aM(aZ, aY)
				aZ = aZ.sibling
			end
		end
		return aR
	end
	function a.c_()
		local aa = _G.__DEV__
		local ab = a.load("b_")
		local ac = ab.Object
		local ad = a.load("b0").console
		local ae = a.load("cj")
		local af = a.load("cn")
		local ag = a.load("cx")
		local ah = a.load("b0")
		local ai = a.load("cX")
		local aj = a.load("b3")
		local ak = aj.Update
		local al = aj.Snapshot
		local am = aj.MountLayoutDev
		local an = a.load("b0").ReactFeatureFlags
		local ao = an.debugRenderPhaseSideEffectsForStrictMode
		local ap = an.disableLegacyContext
		local aq = an.enableDebugTracing
		local ar = an.enableSchedulingProfiler
		local as = an.warnAboutDeprecatedLifecycles
		local au = an.enableDoubleInvokingEffects
		local av = a.load("cY")
		local aw = a.load("cp").isMounted
		local ax = a.load("b0").ReactInstanceMap
		local ay = ax.get
		local az = ax.set
		local aA = a.load("b0").shallowEqual
		local aC = a.load("b0").getComponentName
		local aD = a.load("b0").UninitializedState
		local aE = a.load("b0").describeError
		local aF = a.load("b0").ReactSymbols
		local aG = aF.REACT_CONTEXT_TYPE
		local aH = aF.REACT_PROVIDER_TYPE
		local aI = a.load("cS").resolveDefaultProps
		local aJ = a.load("b2")
		local aK = aJ.DebugTracingMode
		local aL = aJ.StrictMode
		local aM = ag.enqueueUpdate
		local aN = ag.processUpdateQueue
		local aO = ag.checkHasForceUpdateAfterProcessing
		local aP = ag.resetHasForceUpdateBeforeProcessing
		local aQ = ag.createUpdate
		local aR = ag.ReplaceState
		local aS = ag.ForceUpdate
		local aT = ag.initializeUpdateQueue
		local aU = ag.cloneUpdateQueue
		local aV = af.NoLanes
		local aW = a.load("cr")
		local aX = aW.cacheContext
		local aY = aW.getMaskedContext
		local aZ = aW.getUnmaskedContext
		local a_ = aW.hasContextChanged
		local b = aW.emptyContextObject
		local c = a.load("cI")
		local d = c.readContext
		local e = a.load("cA")
		local g = e.logForceUpdateScheduled
		local h = e.logStateUpdateScheduled
		local i = a.load("b0").ConsolePatchingDev
		local j = i.disableLogs
		local k = i.reenableLogs
		local l = a.load("cB")
		local m = l.markForceUpdateScheduled
		local n = l.markStateUpdateScheduled
		local o = {}
		local p = ai.Component:extend("").__refs
		local q
		local r
		local s
		local t
		local u
		local v
		local w
		local x
		local y
		local z
		if aa then
			q = {}
			r = {}
			s = {}
			t = {}
			x = {}
			u = {}
			y = {}
			z = {}
			local A = {}
			function w(B, C)
				if B == nil or type(B) == "function" then
					return
				end
				local D = C .. "_" .. tostring(B)
				if not A[D] then
					A[D] = true
					ad.error(
						"%s(...): Expected the last optional `callback` argument to be a function. Instead received: %s.",
						C,
						tostring(B)
					)
				end
			end
			function v(B, C) end
		end
		local function applyDerivedStateFromProps(A, B, C, D)
			local E = A.memoizedState
			if aa then
				if ao and bit32.band(A.mode, aL) ~= 0 then
					j()
					local F, G = xpcall(C, aE, D, E)
					k()
					if not F then
						error(G)
					end
				end
			end
			local F = C(D, E)
			if aa then
				v(B, F)
			end
			local G = if F == nil then E else ac.assign({}, E, F)
			A.memoizedState = G
			if A.lanes == aV then
				local H = A.updateQueue
				H.baseState = G
			end
		end
		local A
		local function initializeClassComponentUpdater()
			local B = a.load("cl")
			local C = B.lazy("ReactFiberWorkLoop")
			local D = C.requestUpdateLane
			local E = C.scheduleUpdateOnFiber
			A = {
				isMounted = aw,
				enqueueSetState = function(F, G, H)
					local I = ay(F)
					local J = C.requestEventTime()
					local K = D(I)
					local L = aQ(J, K, G, H)
					if H ~= nil then
						if aa then
							w(H, "setState")
						end
					end
					aM(I, L)
					E(I, K, J)
					if aa then
						if aq then
							if bit32.band(I.mode, aK) ~= 0 then
								local M = aC(I.type) or "Unknown"
								h(M, K, G)
							end
						end
					end
					if ar then
						n(I, K)
					end
				end,
				enqueueReplaceState = function(F, G, H)
					local I = ay(F)
					local J = C.requestEventTime()
					local K = D(I)
					local L = aQ(J, K, G, H)
					L.tag = aR
					if H ~= nil then
						if aa then
							w(H, "replaceState")
						end
					end
					aM(I, L)
					E(I, K, J)
					if aa then
						if aq then
							if bit32.band(I.mode, aK) ~= 0 then
								local M = aC(I.type) or "Unknown"
								h(M, K, G)
							end
						end
					end
					if ar then
						n(I, K)
					end
				end,
				enqueueForceUpdate = function(F, G)
					local H = ay(F)
					local I = C.requestEventTime()
					local J = D(H)
					local K = aQ(I, J, nil, G)
					K.tag = aS
					if G ~= nil then
						if aa then
							w(G, "forceUpdate")
						end
					end
					aM(H, K)
					E(H, J, I)
					if aa then
						if aq then
							if bit32.band(H.mode, aK) ~= 0 then
								local L = aC(H.type) or "Unknown"
								g(L, J)
							end
						end
					end
					if ar then
						m(H, J)
					end
				end,
			}
		end
		local function getClassComponentUpdater()
			if A == nil then
				initializeClassComponentUpdater()
			end
			return A
		end
		function checkShouldComponentUpdate(B, C, D, E, F, G, H)
			local I = B.stateNode
			if I.shouldComponentUpdate ~= nil and type(I.shouldComponentUpdate) == "function" then
				if aa then
					if ao and bit32.band(B.mode, aL) ~= 0 then
						j()
						local J, K = xpcall(I.shouldComponentUpdate, aE, I, E, G, H)
						k()
						if not J then
							error(K)
						end
					end
				end
				local J = I.shouldComponentUpdate(I, E, G, H)
				if aa then
					if J == nil then
						ad.error(
							"%s.shouldComponentUpdate(): Returned nil instead of a boolean value. Make sure to return true or false.",
							aC(C) or "Component"
						)
					end
				end
				return J
			end
			if type(C) == "table" and C.isPureReactComponent then
				return (not aA(D, E) or not aA(F, G))
			end
			return true
		end
		local function checkClassInstance(B, C, D)
			local E = B.stateNode
			if aa then
				local F = aC(C) or "Component"
				local G = E.render
				if not G then
					if type(C.render) == "function" then
						ad.error(
							"%s(...): No `render` method found on the returned component instance: did you accidentally return an object from the constructor?",
							F
						)
					else
						ad.error(
							"%s(...): No `render` method found on the returned component instance: you may have forgotten to define `render`.",
							F
						)
					end
				end
				if E.getInitialState and not E.getInitialState.isReactClassApproved and not E.state then
					ad.error(
						"getInitialState was defined on %s, a plain JavaScript class. This is only supported for classes created using React.createClass. Did you mean to define a state property instead?",
						F
					)
				end
				if E.getDefaultProps and not E.getDefaultProps.isReactClassApproved then
					ad.error(
						"getDefaultProps was defined on %s, a plain JavaScript class. This is only supported for classes created using React.createClass. Use a static property to define defaultProps instead.",
						F
					)
				end
				if E.propTypes and not C.propTypes then
					ad.error(
						"propTypes was defined as an instance property on %s. Use a static property to define propTypes instead.",
						F
					)
				end
				if E.contextType and not C.contextType then
					ad.error(
						"contextType was defined as an instance property on %s. Use a static property to define contextType instead.",
						F
					)
				end
				if ap then
					if C.childContextTypes then
						ad.error(
							"%s uses the legacy childContextTypes API which is no longer supported. Use React.createContext() instead.",
							F
						)
					end
					if C.contextTypes then
						ad.error(
							"%s uses the legacy contextTypes API which is no longer supported. Use React.createContext() with static contextType instead.",
							F
						)
					end
				else
					if E.contextTypes and not C.contextTypes then
						ad.error(
							"contextTypes was defined as an instance property on %s. Use a static property to define contextTypes instead.",
							F
						)
					end
					if type(C) == "table" and C.contextType and C.contextTypes and not y[C] then
						y[C] = true
						ad.error(
							"%s declares both contextTypes and contextType static properties. The legacy contextTypes property will be ignored.",
							F
						)
					end
				end
				if type(E.componentShouldUpdate) == "function" then
					ad.error(
						"%s has a method called componentShouldUpdate(). Did you mean shouldComponentUpdate()? The name is phrased as a question because the function is expected to return a value.",
						F
					)
				end
				if type(C) == "table" and C.isPureReactComponent and E.shouldComponentUpdate ~= nil then
					ad.error(
						"%s has a method called shouldComponentUpdate(). shouldComponentUpdate should not be used when extending React.PureComponent. Please extend React.Component if shouldComponentUpdate is used.",
						aC(C) or "A pure component"
					)
				end
				if type(E.componentDidUnmount) == "function" then
					ad.error(
						"%s has a method called componentDidUnmount(). But there is no such lifecycle method. Did you mean componentWillUnmount()?",
						F
					)
				end
				if type(E.componentDidReceiveProps) == "function" then
					ad.error(
						"%s has a method called componentDidReceiveProps(). But there is no such lifecycle method. If you meant to update the state in response to changing props, use componentWillReceiveProps(). If you meant to fetch data or run side-effects or mutations after React has updated the UI, use componentDidUpdate().",
						F
					)
				end
				if type(E.componentWillRecieveProps) == "function" then
					ad.error(
						"%s has a method called componentWillRecieveProps(). Did you mean componentWillReceiveProps()?",
						F
					)
				end
				if type(E.UNSAFE_componentWillRecieveProps) == "function" then
					ad.error(
						"%s has a method called UNSAFE_componentWillRecieveProps(). Did you mean UNSAFE_componentWillReceiveProps()?",
						F
					)
				end
				local H = E.props ~= D
				if E.props ~= nil and H then
					ad.error(
						"%s(...): When calling super() in `%s`, make sure to pass up the same props that your component's constructor was passed.",
						F,
						F
					)
				end
				if rawget(E, "defaultProps") then
					ad.error(
						"Setting defaultProps as an instance property on %s is not supported and will be ignored. Instead, define defaultProps as a static property on %s.",
						F,
						F
					)
				end
				if
					type(E.getSnapshotBeforeUpdate) == "function"
					and type(E.componentDidUpdate) ~= "function"
					and not s[C]
				then
					s[C] = true
					ad.error(
						"%s: getSnapshotBeforeUpdate() should be used with componentDidUpdate(). This component defines getSnapshotBeforeUpdate() only.",
						aC(C)
					)
				end
				local I = E.state
				if I ~= nil and type(I) ~= "table" then
					ad.error("%s.state: must be set to an object or nil", F)
				end
				if
					type(C) == "table"
					and type(E.getChildContext) == "function"
					and type(C.childContextTypes) ~= "table"
				then
					ad.error(
						"%s.getChildContext(): childContextTypes must be defined in order to use getChildContext().",
						F
					)
				end
			end
		end
		local function adoptClassInstance(B, C)
			C.__updater = getClassComponentUpdater()
			B.stateNode = C
			az(C, B)
			if aa then
				C._reactInternalInstance = o
			end
		end
		local function constructClassInstance(B, C, D)
			local E = false
			local F = b
			local G = b
			local H = C.contextType
			if aa then
				if C["contextType"] ~= nil then
					local I = H == nil or (H["$$typeof"] == aG and H._context == nil)
					if not I and not z[C] then
						z[C] = true
						local J = ""
						if H == nil then
							J =
								" However, it is set to nil. This can be caused by a typo or by mixing up named and default imports. This can also happen due to a circular dependency, so try moving the createContext() call to a separate file."
						elseif type(H) ~= "table" then
							J = " However, it is set to a " .. type(H) .. "."
						elseif H["$$typeof"] == aH then
							J = " Did you accidentally pass the Context.Provider instead?"
						elseif H._context ~= nil then
							J = " Did you accidentally pass the Context.Consumer instead?"
						else
							J ..= " However, it is set to an object with keys {"
							for K, L in H do
								J ..= K .. ", "
							end
							J ..= "}."
						end
						ad.error(
							"%s defines an invalid contextType. contextType should point to the Context object returned by React.createContext().%s",
							aC(C) or "Component",
							J
						)
					end
				end
			end
			if H ~= nil and type(H) == "table" then
				G = d(H)
			elseif not ap then
				F = aZ(B, C, true)
				local I = C.contextTypes
				E = I ~= nil
				G = E and aY(B, F) or b
			end
			if aa then
				if ao and bit32.band(B.mode, aL) ~= 0 then
					j()
					local I, J = xpcall(C.__ctor, aE, D, G)
					k()
					if not I then
						error(J)
					end
				end
			end
			local I = C.__ctor(D, G)
			B.memoizedState = I.state
			local J = B.memoizedState
			adoptClassInstance(B, I)
			if aa then
				if type(C.getDerivedStateFromProps) == "function" and J == aD then
					local K = aC(C) or "Component"
					if not r[K] then
						r[K] = true
						ad.error(
							"`%s` uses `getDerivedStateFromProps` but its initial state has not been initialized. This is not recommended. Instead, define the initial state by passing an object to `self:setState` in the `init` method of `%s`. This ensures that `getDerivedStateFromProps` arguments have a consistent shape.",
							K,
							K
						)
					end
				end
				if type(C.getDerivedStateFromProps) == "function" or type(I.getSnapshotBeforeUpdate) == "function" then
					local K
					local L
					local M
					if type(I.componentWillMount) == "function" then
						K = "componentWillMount"
					elseif type(I.UNSAFE_componentWillMount) == "function" then
						K = "UNSAFE_componentWillMount"
					end
					if type(I.componentWillReceiveProps) == "function" then
						L = "componentWillReceiveProps"
					elseif type(I.UNSAFE_componentWillReceiveProps) == "function" then
						L = "UNSAFE_componentWillReceiveProps"
					end
					if type(I.componentWillUpdate) == "function" then
						M = "componentWillUpdate"
					elseif type(I.UNSAFE_componentWillUpdate) == "function" then
						M = "UNSAFE_componentWillUpdate"
					end
					if K ~= nil or L ~= nil or M ~= nil then
						local N = aC(C) or "Component"
						local O
						if type(C.getDerivedStateFromProps) == "function" then
							O = "getDerivedStateFromProps()"
						else
							O = "getSnapshotBeforeUpdate()"
						end
						local P
						if K ~= nil then
							P = ("\n  " .. tostring(K))
						else
							P = ""
						end
						local Q
						if L ~= nil then
							Q = ("\n  " .. tostring(L))
						else
							Q = ""
						end
						local R
						if M ~= nil then
							R = "\n  " .. tostring(M)
						else
							R = ""
						end
						if not t[N] then
							t[N] = true
							ad.error(
								"Unsafe legacy lifecycles will not be called for components using new component APIs.\n\n%s uses %s but also contains the following legacy lifecycles:%s%s%s\n\nThe above lifecycles should be removed. Learn more about this warning here:\nhttps://reactjs.org/link/unsafe-component-lifecycles",
								N,
								O,
								P,
								Q,
								R
							)
						end
					end
				end
			end
			if E then
				aX(B, F, G)
			end
			return I
		end
		local function callComponentWillMount(B, C)
			local D = C.state
			if C.componentWillMount ~= nil and type(C.componentWillMount) == "function" then
				C.componentWillMount(C)
			end
			if C.UNSAFE_componentWillMount ~= nil and type(C.UNSAFE_componentWillMount) == "function" then
				C.UNSAFE_componentWillMount(C)
			end
			if D ~= C.state then
				if aa then
					ad.error(
						"%s.componentWillMount(): Assigning directly to this.state is deprecated (except inside a component's constructor). Use setState instead.",
						aC(B.type) or "Component"
					)
				end
				getClassComponentUpdater().enqueueReplaceState(C, C.state)
			end
		end
		function callComponentWillReceiveProps(B, C, D, E)
			local F = C.state
			if C.componentWillReceiveProps ~= nil and type(C.componentWillReceiveProps) == "function" then
				C.componentWillReceiveProps(C, D, E)
			end
			if C.UNSAFE_componentWillReceiveProps ~= nil and type(C.UNSAFE_componentWillReceiveProps) == "function" then
				C.UNSAFE_componentWillReceiveProps(C, D, E)
			end
			if C.state ~= F then
				if aa then
					local G = aC(B.type) or "Component"
					if not q[G] then
						q[G] = true
						ad.error(
							"%s.componentWillReceiveProps(): Assigning directly to this.state is deprecated (except inside a component's constructor). Use setState instead.",
							G
						)
					end
				end
				getClassComponentUpdater().enqueueReplaceState(C, C.state)
			end
		end
		local function mountClassInstance(B, C, D, E)
			if aa then
				checkClassInstance(B, C, D)
			end
			local F = B.stateNode
			F.props = D
			F.state = B.memoizedState
			F.__refs = p
			aT(B)
			local G
			if type(C) == "table" then
				G = C.contextType
			end
			if G ~= nil and type(G) == "table" then
				F.context = d(G)
			elseif ap then
				F.context = b
			else
				local H = aZ(B, C, true)
				F.context = aY(B, H)
			end
			if aa then
				if F.state == D then
					local H = aC(C) or "Component"
					if not x[H] then
						x[H] = true
						ad.error(
							"%s: It is not recommended to assign props directly to state because updates to props won't be reflected in state. In most cases, it is better to use props directly.",
							H
						)
					end
				end
				if bit32.band(B.mode, aL) ~= 0 then
					av.recordLegacyContextWarning(B, F)
				end
				if as then
					av.recordUnsafeLifecycleWarnings(B, F)
				end
			end
			aN(B, D, F, E)
			F.state = B.memoizedState
			local H = type(C)
			local I
			if type(C) == "table" then
				I = C.getDerivedStateFromProps
			end
			if I ~= nil and type(I) == "function" then
				applyDerivedStateFromProps(B, C, I, D)
				F.state = B.memoizedState
			end
			if
				H == "table"
				and type(C.getDerivedStateFromProps) ~= "function"
				and type(F.getSnapshotBeforeUpdate) ~= "function"
				and (type(F.UNSAFE_componentWillMount) == "function" or type(F.componentWillMount) == "function")
			then
				callComponentWillMount(B, F)
				aN(B, D, F, E)
				F.state = B.memoizedState
			end
			if type(F.componentDidMount) == "function" then
				if aa and au then
					B.flags = bit32.bor(B.flags, bit32.bor(am, ak))
				else
					B.flags = bit32.bor(B.flags, ak)
				end
			end
		end
		function resumeMountClassInstance(B, C, D, E)
			local F = B.stateNode
			local G = B.memoizedProps
			F.props = G
			local H = F.context
			local I = C.contextType
			local J = b
			if I ~= nil and type(I) == "table" then
				J = d(I)
			elseif not ap then
				local K = aZ(B, C, true)
				J = aY(B, K)
			end
			local K = C.getDerivedStateFromProps
			local L = type(K) == "function" or type(F.getSnapshotBeforeUpdate) == "function"
			if
				not L
				and (
					type(F.UNSAFE_componentWillReceiveProps) == "function"
					or type(F.componentWillReceiveProps) == "function"
				)
			then
				if G ~= D or H ~= J then
					callComponentWillReceiveProps(B, F, D, J)
				end
			end
			aP()
			local M = B.memoizedState
			F.state = M
			local N = M
			aN(B, D, F, E)
			N = B.memoizedState
			if G == D and M == N and not a_() and not aO() then
				if type(F.componentDidMount) == "function" then
					if aa and au then
						B.flags = bit32.bor(B.flags, am, ak)
					else
						B.flags = bit32.bor(B.flags, ak)
					end
				end
				return false
			end
			if K ~= nil and type(K) == "function" then
				applyDerivedStateFromProps(B, C, K, D)
				N = B.memoizedState
			end
			local O = aO() or checkShouldComponentUpdate(B, C, G, D, M, N, J)
			if O then
				if
					not L and (
						type(F.UNSAFE_componentWillMount) == "function" or type(F.componentWillMount) == "function"
					)
				then
					if type(F.componentWillMount) == "function" then
						F.componentWillMount(F)
					end
					if type(F.UNSAFE_componentWillMount) == "function" then
						F.UNSAFE_componentWillMount(F)
					end
				end
				if type(F.componentDidMount) == "function" then
					if aa and au then
						B.flags = bit32.bor(B.flags, am, ak)
					else
						B.flags = bit32.bor(B.flags, ak)
					end
				end
			else
				if type(F.componentDidMount) == "function" then
					if aa and au then
						B.flags = bit32.bor(B.flags, am, ak)
					else
						B.flags = bit32.bor(B.flags, ak)
					end
				end
				B.memoizedProps = D
				B.memoizedState = N
			end
			F.props = D
			F.state = N
			F.context = J
			return O
		end
		local function updateClassInstance(B, C, D, E, F)
			local G = C.stateNode
			aU(B, C)
			local H = C.memoizedProps
			local I = if C.type == C.elementType then H else aI(C.type, H)
			G.props = I
			local J = C.pendingProps
			local K = G.context
			local L
			local M
			if type(D) == "table" then
				L = D.contextType
				M = D.getDerivedStateFromProps
			end
			local N = b
			if type(L) == "table" then
				N = d(L)
			elseif not ap then
				local O = aZ(C, D, true)
				N = aY(C, O)
			end
			local O = (M ~= nil and type(M) == "function")
				or (G.getSnapshotBeforeUpdate ~= nil and type(G.getSnapshotBeforeUpdate) == "function")
			if
				not O
				and (
					(
						G.UNSAFE_componentWillReceiveProps ~= nil
						and type(G.UNSAFE_componentWillReceiveProps) == "function"
					) or (G.componentWillReceiveProps ~= nil and type(G.componentWillReceiveProps) == "function")
				)
			then
				if H ~= J or K ~= N then
					callComponentWillReceiveProps(C, G, E, N)
				end
			end
			aP()
			local P = C.memoizedState
			G.state = P
			local Q = G.state
			aN(C, E, G, F)
			Q = C.memoizedState
			if H == J and P == Q and not a_() and not aO() then
				if G.componentDidUpdate ~= nil and type(G.componentDidUpdate) == "function" then
					if H ~= B.memoizedProps or P ~= B.memoizedState then
						C.flags = bit32.bor(C.flags, ak)
					end
				end
				if G.getSnapshotBeforeUpdate ~= nil and type(G.getSnapshotBeforeUpdate) == "function" then
					if H ~= B.memoizedProps or P ~= B.memoizedState then
						C.flags = bit32.bor(C.flags, al)
					end
				end
				return false
			end
			if M ~= nil and type(M) == "function" then
				applyDerivedStateFromProps(C, D, M, E)
				Q = C.memoizedState
			end
			local R = aO() or checkShouldComponentUpdate(C, D, I, E, P, Q, N)
			if R then
				if
					not O
					and (
						(G.UNSAFE_componentWillUpdate ~= nil and type(G.UNSAFE_componentWillUpdate) == "function")
						or (G.componentWillUpdate ~= nil and type(G.componentWillUpdate) == "function")
					)
				then
					if G.componentWillUpdate ~= nil and type(G.componentWillUpdate) == "function" then
						G.componentWillUpdate(G, E, Q, N)
					end
					if G.UNSAFE_componentWillUpdate ~= nil and type(G.UNSAFE_componentWillUpdate) == "function" then
						G.UNSAFE_componentWillUpdate(G, E, Q, N)
					end
				end
				if G.componentDidUpdate ~= nil and type(G.componentDidUpdate) == "function" then
					C.flags = bit32.bor(C.flags, ak)
				end
				if G.getSnapshotBeforeUpdate ~= nil and type(G.getSnapshotBeforeUpdate) == "function" then
					C.flags = bit32.bor(C.flags, al)
				end
			else
				if G.componentDidUpdate ~= nil and type(G.componentDidUpdate) == "function" then
					if H ~= B.memoizedProps or P ~= B.memoizedState then
						C.flags = bit32.bor(C.flags, ak)
					end
				end
				if G.getSnapshotBeforeUpdate ~= nil and type(G.getSnapshotBeforeUpdate) == "function" then
					if H ~= B.memoizedProps or P ~= B.memoizedState then
						C.flags = bit32.bor(C.flags, al)
					end
				end
				C.memoizedProps = E
				C.memoizedState = Q
			end
			G.props = E
			G.state = Q
			G.context = N
			return R
		end
		return {
			adoptClassInstance = adoptClassInstance,
			constructClassInstance = constructClassInstance,
			mountClassInstance = mountClassInstance,
			resumeMountClassInstance = resumeMountClassInstance,
			updateClassInstance = updateClassInstance,
			applyDerivedStateFromProps = applyDerivedStateFromProps,
			emptyRefsObject = p,
		}
	end
	function a.c0()
		local function unimplemented(aa)
			print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
			print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
			print("UNIMPLEMENTED ERROR: " .. tostring(aa))
			error("FIXME (roblox): " .. aa .. " is unimplemented", 2)
		end
		local aa = _G.__DEV__
		local ab = _G.__DISABLE_ALL_WARNINGS_EXCEPT_PROP_VALIDATION__
		local ac = _G.__COMPAT_WARNINGS__
		local ad = a.load("b0")
		local ae = ad.console
		local af = a.load("b_")
		local ag = af.Array
		local ah = af.Object
		local ai = af.util.inspect
		local aj = a.load("b0")
		local ak = a.load("cX")
		local al = a.load("cj")
		local am = a.load("cn")
		local an = a.load("co")
		local ao = a.load("cF")
		local ap = a.load("cs")
		local aq = a.load("b0").checkPropTypes
		local ar = a.load("b1")
		local as = ar.FunctionComponent
		local au = ar.ClassComponent
		local av = ar.HostRoot
		local aw = ar.HostComponent
		local ax = ar.HostText
		local ay = ar.HostPortal
		local az = ar.ForwardRef
		local aA = ar.Fragment
		local aC = ar.Mode
		local aD = ar.ContextProvider
		local aE = ar.ContextConsumer
		local aF = ar.Profiler
		local aG = ar.SuspenseComponent
		local aH = ar.SuspenseListComponent
		local aI = ar.MemoComponent
		local aJ = ar.SimpleMemoComponent
		local aK = ar.LazyComponent
		local aL = ar.IncompleteClassComponent
		local aM = ar.OffscreenComponent
		local aN = ar.LegacyHiddenComponent
		local aO = a.load("b3")
		local aP = aO.NoFlags
		local aQ = aO.StaticMask
		local aR = aO.PerformedWork
		local aS = aO.Placement
		local aT = aO.Hydrating
		local aU = aO.ContentReset
		local aV = aO.DidCapture
		local aW = aO.Ref
		local aX = aO.Deletion
		local aY = aO.ForceUpdateForLegacySuspense
		local aZ = a.load("b0").ReactSharedInternals
		local a_ = a.load("b0").ReactFeatureFlags
		local b = a_.debugRenderPhaseSideEffectsForStrictMode
		local c = a_.disableLegacyContext
		local d = a_.disableModulePatternComponents
		local e = a_.enableProfilerTimer
		local g = a_.enableSchedulerTracing
		local h = a_.enableSuspenseServerRenderer
		local i = a_.warnAboutDefaultPropsOnFunctionComponents
		local j = a.load("b0").invariant
		local k = a.load("b0").describeError
		local l = a.load("b0").shallowEqual
		local m = a.load("b0").getComponentName
		local n = a.load("b0").ReactSymbols
		local o = n.REACT_LAZY_TYPE
		local p = n.getIteratorFn
		local q = a.load("cY")
		local r = a.load("cR")
		local s = r.getCurrentFiberOwnerNameInDevOrNull
		local t = r.setIsRendering
		local u = a.load("cu")
		local v = u.resolveFunctionForHotReloading
		local w = u.resolveForwardRefForHotReloading
		local x = u.resolveClassForHotReloading
		local y = (a.load("cZ"))
		local z = y.mountChildFibers
		local A = y.reconcileChildFibers
		local B = y.cloneChildFibers
		local C = a.load("cx")
		local D = C.processUpdateQueue
		local E = C.cloneUpdateQueue
		local F = C.initializeUpdateQueue
		local G = a.load("b2")
		local H = G.ConcurrentMode
		local I = G.NoMode
		local J = G.ProfileMode
		local K = G.StrictMode
		local L = G.BlockingMode
		local M = a.load("ck")
		local N = a.load("cE")
		local O = N.pushHostContext
		local P = N.pushHostContainer
		local Q = ao.suspenseStackCursor
		local R = ao.hasSuspenseContext
		local S = ao.ForceSuspenseFallback
		local T = ao.addSubtreeSuspenseContext
		local U = ao.InvisibleParentSuspenseContext
		local V = ao.pushSuspenseContext
		local W = ao.setDefaultShallowSuspenseContext
		local X = a.load("cI")
		local Y = X.propagateContextChange
		local Z = X.readContext
		local _ = X.calculateChangedBits
		local a0 = X.prepareToReadContext
		local a1 = X.pushProvider
		local a2 = { renderWithHooksRef = nil, bailoutHooksRef = nil, shouldSuspendRef = nil }
		local function shouldSuspend(a3)
			if not a2.shouldSuspendRef then
				local a4 = a.load("cl")
				local a5 = a4.lazy("ReactFiberReconciler")
				a2.shouldSuspendRef = function(a6)
					return a5.shouldSuspend and a5.shouldSuspend(a6) or false
				end
			end
			return a2.shouldSuspendRef(a3)
		end
		local function initReactFiberHooks()
			local a3 = a.load("cl")
			local a4 = a3.lazy("ReactFiberHooks")
			a2.renderWithHooksRef = a4.renderWithHooks
			a2.bailoutHooksRef = a4.bailoutHooks
		end
		local function renderWithHooks(...)
			if not a2.renderWithHooksRef then
				initReactFiberHooks()
			end
			return a2.renderWithHooksRef(...)
		end
		local function bailoutHooks(...)
			if not a2.bailoutHooksRef then
				initReactFiberHooks()
			end
			return a2.bailoutHooksRef(...)
		end
		local a3 = a.load("cJ").stopProfilerTimerIfRunning
		local a4 = a.load("cr")
		local a5 = a4.getMaskedContext
		local a6 = a4.getUnmaskedContext
		local a7 = a4.hasContextChanged
		local a8 = a4.pushContextProvider
		local a9 = a4.isContextProvider
		local ba = a4.pushTopLevelContextObject
		local bb = a4.invalidateContextProvider
		local bc = a.load("cG")
		local bd = bc.resetHydrationState
		local be = bc.enterHydrationState
		local bf = bc.reenterHydrationStateFromDehydratedSuspenseInstance
		local bg = bc.tryToClaimNextHydratableInstance
		local bh = bc.warnIfHydrating
		local bi = (a.load("c_"))
		local bj = bi.adoptClassInstance
		local bk = bi.applyDerivedStateFromProps
		local bl = bi.constructClassInstance
		local bm = bi.mountClassInstance
		local bn = bi.resumeMountClassInstance
		local bo = bi.updateClassInstance
		local bp = a.load("cS").resolveDefaultProps
		local bq = a.load("cv")
		local br = bq.resolveLazyComponentTag
		local bs = bq.createFiberFromFragment
		local bt = bq.createFiberFromOffscreen
		local bu = bq.createFiberFromTypeAndProps
		local bv = bq.isSimpleFunctionComponent
		local bw = bq.createWorkInProgress
		local bx = a.load("cl")
		local by = bx.lazy("ReactFiberWorkLoop")
		local bz
		local bA = a.load("cD").setWorkInProgressVersion
		local bB = a.load("cw").markSkippedUpdateLanes
		local bC = a.load("b0").ConsolePatchingDev
		local bD = bC.disableLogs
		local bE = bC.reenableLogs
		local bF = aZ.ReactCurrentOwner
		local bG = {}
		local bH, bI
		local bJ = false
		local bK = {
			didWarnAboutBadClass = {},
			didWarnAboutModulePatternComponent = {},
			didWarnAboutContextTypeOnFunctionComponent = {},
			didWarnAboutGetDerivedStateOnFunctionComponent = {},
			didWarnAboutFunctionRefs = {},
			didWarnAboutDefaultPropsOnFunctionComponent = {},
		}
		local bL
		if aa then
			bK.didWarnAboutBadClass = {}
			bK.didWarnAboutModulePatternComponent = {}
			bK.didWarnAboutContextTypeOnFunctionComponent = {}
			bK.didWarnAboutGetDerivedStateOnFunctionComponent = {}
			bK.didWarnAboutFunctionRefs = {}
			bG.didWarnAboutReassigningProps = false
			bK.didWarnAboutDefaultPropsOnFunctionComponent = {}
		end
		local function reconcileChildren(bM, bN, bO, bP)
			if bM == nil then
				bN.child = z(bN, nil, bO, bP)
			else
				bN.child = A(bN, (bM).child, bO, bP)
			end
		end
		local function forceUnmountCurrentAndReconcile(bM, bN, bO, bP)
			bN.child = A(bN, bM.child, nil, bP)
			bN.child = A(bN, nil, bO, bP)
		end
		local function updateForwardRef(bM, bN, bO, bP, bQ)
			if aa or ab then
				if bN.type ~= bN.elementType then
					local bR = bO.propTypes
					local bS = bO.validateProps
					if bR or bS then
						aq(bR, bS, bP, "prop", m(bO))
					end
				end
			end
			local bR = bO.render
			local bS = bN.ref
			local bT
			a0(bN, bQ, bG.markWorkInProgressReceivedUpdate)
			if aa then
				bF.current = bN
				t(true)
				bT = renderWithHooks(bM, bN, bR, bP, bS, bQ)
				if b and bit32.band(bN.mode, K) ~= 0 then
					bD()
					local bU, bV = xpcall(renderWithHooks, k, bM, bN, bR, bP, bS, bQ)
					if bU then
						bT = bV
					end
					bE()
					if not bU then
						error(bV)
					end
				end
				t(false)
			else
				bT = renderWithHooks(bM, bN, bR, bP, bS, bQ)
			end
			if bM ~= nil and not bJ then
				bailoutHooks(bM, bN, bQ)
				return bH(bM, bN, bQ)
			end
			bN.flags = bit32.bor(bN.flags, aR)
			reconcileChildren(bM, bN, bT, bQ)
			return bN.child
		end
		local function updateMemoComponent(bM, bN, bO, bP, bQ, bR)
			if bM == nil then
				local bS = bO.type
				if bv(bS) and bO.compare == nil and bO.defaultProps == nil then
					local bT = bS
					if aa then
						bT = v(bS)
					end
					bN.tag = aJ
					bN.type = bT
					if aa then
						validateFunctionComponentInDev(bN, bS)
					end
					return bL(bM, bN, bT, bP, bQ, bR)
				end
				if aa or ab then
					local bT
					local bU
					if type(bS) == "table" then
						bT = bS.propTypes
						bU = bS.validateProps
					end
					if bT or bU then
						aq(bT, bU, bP, "prop", m(bS))
					end
				end
				local bT = bu(bO.type, nil, bP, bN, bN.mode, bR)
				bT.ref = bN.ref
				bT.return_ = bN
				bN.child = bT
				return bT
			end
			local bS = bM
			if aa or ab then
				local bT = bO.type
				local bU
				local bV
				if type(bT) == "table" then
					bU = bT.propTypes
					bV = bT.validateProps
				end
				if bU or bV then
					aq(bU, bV, bP, "prop", m(bT))
				end
			end
			local bT = bS.child
			if not am.includesSomeLane(bQ, bR) then
				local bU = bT.memoizedProps
				local bV = bO.compare
				if bV == nil then
					bV = l
				end
				if bV(bU, bP) and bS.ref == bN.ref then
					return bH(bS, bN, bR)
				end
			end
			bN.flags = bit32.bor(bN.flags, aR)
			local bU = bw(bT, bP)
			bU.ref = bN.ref
			bU.return_ = bN
			bN.child = bU
			return bU
		end
		function bL(bM, bN, bO, bP, bQ, bR)
			if aa or ab then
				if bN.type ~= bN.elementType then
					local bS = bN.elementType
					if bS["$$typeof"] == o then
						local bT = bS
						local bU = bT._payload
						local bV = bT._init
						local bW, bX = xpcall(bV, k, bU)
						if bW then
							bS = bX
						else
							bS = nil
						end
						local bY
						local bZ
						if bS ~= nil and type(bS) == "table" then
							bY = (bS).propTypes
							bZ = (bS).validateProps
						end
						if bY or bZ then
							aq(bY, bZ, bP, "prop", m(bS))
						end
					end
				end
			end
			if bM ~= nil then
				local bS = bM
				local bT = bS.memoizedProps
				local bU = true
				if aa then
					bU = bN.type == bS.type
				end
				if l(bT, bP) and bS.ref == bN.ref and bU then
					bJ = false
					if not am.includesSomeLane(bR, bQ) then
						bN.lanes = bS.lanes
						return bH(bS, bN, bR)
					elseif bit32.band(bS.flags, aY) ~= aP then
						bJ = true
					end
				end
			end
			return bI(bM, bN, bO, bP, bR)
		end
		local function updateOffscreenComponent(bM, bN, bO)
			local bP = bN.pendingProps
			local bQ = bP.children
			local bR
			if bM ~= nil then
				bR = (bM).memoizedState
			end
			if bP.mode == "hidden" or bP.mode == "unstable-defer-without-hiding" then
				if bit32.band(bN.mode, H) == I then
					local bS = {
						baseLanes = am.NoLanes,
					}
					bN.memoizedState = bS
					by.pushRenderLanes(bN, bO)
				elseif not am.includesSomeLane(bO, am.OffscreenLane) then
					local bS
					if bR ~= nil then
						local bT = (bR).baseLanes
						bS = am.mergeLanes(bT, bO)
					else
						bS = bO
					end
					if g then
						by.markSpawnedWork(am.OffscreenLane)
					end
					bN.childLanes = am.laneToLanes(am.OffscreenLane)
					bN.lanes = bN.childLanes
					local bT = { baseLanes = bS }
					bN.memoizedState = bT
					by.pushRenderLanes(bN, bS)
					return nil
				else
					local bS = { baseLanes = am.NoLanes }
					bN.memoizedState = bS
					local bT = bO
					if bR ~= nil then
						bT = (bR).baseLanes
					end
					by.pushRenderLanes(bN, bT)
				end
			else
				local bS
				if bR ~= nil then
					bS = am.mergeLanes((bR).baseLanes, bO)
					bN.memoizedState = nil
				else
					bS = bO
				end
				by.pushRenderLanes(bN, bS)
			end
			reconcileChildren(bM, bN, bQ, bO)
			return bN.child
		end
		local bM = updateOffscreenComponent
		function updateFragment(bN, bO, bP)
			local bQ = bO.pendingProps
			reconcileChildren(bN, bO, bQ, bP)
			return bO.child
		end
		function updateMode(bN, bO, bP)
			local bQ = bO.pendingProps.children
			reconcileChildren(bN, bO, bQ, bP)
			return bO.child
		end
		function updateProfiler(bN, bO, bP)
			if e then
				local bQ = bO.stateNode
				bQ.effectDuration = 0
				bQ.passiveEffectDuration = 0
			end
			local bQ = bO.pendingProps
			local bR = bQ.children
			reconcileChildren(bN, bO, bR, bP)
			return bO.child
		end
		local function markRef(bN, bO)
			local bP = bO.ref
			if (bN == nil and bP ~= nil) or (bN ~= nil and (bN).ref ~= bP) then
				bO.flags = bit32.bor(bO.flags, aW)
			end
		end
		function bI(bN, bO, bP, bQ, bR)
			if aa or ab then
				if type(bP) ~= "function" and (bO.type ~= bO.elementType) then
					local bS
					local bT
					if type(bP) == "table" then
						bS = (bP).propTypes
						bT = (bP).validateProps
					end
					if bS or bT then
						aq(bS, bT, bQ, "prop", m(bP))
					end
				end
			end
			local bS
			if not c then
				local bT = a6(bO, bP, true)
				bS = a5(bO, bT)
			end
			local bT
			a0(bO, bR, bG.markWorkInProgressReceivedUpdate)
			if aa then
				bF.current = bO
				t(true)
				bT = renderWithHooks(bN, bO, bP, bQ, bS, bR)
				if b and bit32.band(bO.mode, K) ~= 0 then
					bD()
					local bU, bV = xpcall(renderWithHooks, k, bN, bO, bP, bQ, bS, bR)
					bE()
					if bU then
						bT = bV
					else
						error(bV)
					end
				end
				t(false)
			else
				bT = renderWithHooks(bN, bO, bP, bQ, bS, bR)
			end
			if bN ~= nil and not bJ then
				bailoutHooks(bN, bO, bR)
				return bH(bN, bO, bR)
			end
			bO.flags = bit32.bor(bO.flags, aR)
			reconcileChildren(bN, bO, bT, bR)
			return bO.child
		end
		local function updateClassComponent(bN, bO, bP, bQ, bR)
			if aa or ab then
				if bO.type ~= bO.elementType then
					local bS = bP.propTypes
					local bT = bP.validateProps
					if bS or bT then
						aq(bS, bT, bQ, "prop", m(bP))
					end
				end
			end
			local bS
			if a9(bP) then
				bS = true
				a8(bO)
			else
				bS = false
			end
			a0(bO, bR, bG.markWorkInProgressReceivedUpdate)
			local bT = bO.stateNode
			local bU
			if bT == nil then
				if bN ~= nil then
					bN.alternate = nil
					bO.alternate = nil
					bO.flags = bit32.bor(bO.flags, aS)
				end
				bl(bO, bP, bQ)
				bm(bO, bP, bQ, bR)
				bU = true
			elseif bN == nil then
				bU = bn(bO, bP, bQ, bR)
			else
				bU = bo(bN, bO, bP, bQ, bR)
			end
			local bV = finishClassComponent(bN, bO, bP, bU, bS, bR)
			if aa then
				local bW = bO.stateNode
				if bU and bW.props ~= bQ then
					if not bG.didWarnAboutReassigningProps then
						ae.error(
							"It looks like %s is reassigning its own `this.props` while rendering. This is not supported and can lead to confusing bugs.",
							m(bO.type) or "a component"
						)
					end
					bG.didWarnAboutReassigningProps = true
				end
			end
			return bV
		end
		function finishClassComponent(bN, bO, bP, bQ, bR, bS)
			markRef(bN, bO)
			local bT = bit32.band(bO.flags, aV) ~= aP
			if not bQ and not bT then
				if bR then
					bb(bO, bP, false)
				end
				return bH(bN, bO, bS)
			end
			local bU = bO.stateNode
			bF.current = bO
			local bV
			if bT and (bP.getDerivedStateFromError == nil or type(bP.getDerivedStateFromError) ~= "function") then
				bV = nil
				if e then
					a3(bO)
				end
			else
				if aa then
					t(true)
					bV = bU.render(bU)
					if b and bit32.band(bO.mode, K) ~= 0 then
						bD()
						local bW, bX = xpcall(bU.render, k, bU)
						bE()
						if not bW then
							error(bX)
						end
					end
					t(false)
				else
					bV = bU.render(bU)
				end
			end
			bO.flags = bit32.bor(bO.flags, aR)
			if bN ~= nil and bT then
				forceUnmountCurrentAndReconcile(bN, bO, bV, bS)
			else
				reconcileChildren(bN, bO, bV, bS)
			end
			bO.memoizedState = bU.state
			if bR then
				bb(bO, bP, true)
			end
			return bO.child
		end
		local function pushHostRootContext(bN)
			local bO = bN.stateNode
			if bO.pendingContext then
				ba(bN, bO.pendingContext, bO.pendingContext ~= bO.context)
			elseif bO.context then
				ba(bN, bO.context, false)
			end
			P(bN, bO.containerInfo)
		end
		local function updateHostRoot(bN, bO, bP)
			pushHostRootContext(bO)
			local bQ = bO.updateQueue
			j(
				bN ~= nil and bQ ~= nil,
				"If the root does not have an updateQueue, we should have already bailed out. This error is likely caused by a bug in React. Please file an issue."
			)
			local bR = bO.pendingProps
			local bS = bO.memoizedState
			local bT
			if bS ~= nil then
				bT = bS.element
			end
			E(bN, bO)
			D(bO, bR, nil, bP)
			local bU = bO.memoizedState
			local bV = bU.element
			if bV == bT then
				bd()
				return bH(bN, bO, bP)
			end
			local bW = bO.stateNode
			if bW.hydrate and be(bO) then
				if M.supportsHydration then
					local bX = bW.mutableSourceEagerHydrationData
					if bX ~= nil then
						for bY = 1, #bX, 2 do
							local bZ = bX[bY]
							local b_ = bX[bY + 1]
							bA(bZ, b_)
						end
					end
				end
				local bX = z(bO, nil, bV, bP)
				bO.child = bX
				local bY = bX
				while bY do
					bY.flags = bit32.bor(bit32.band(bY.flags, bit32.bnot(aS)), aT)
					bY = bY.sibling
				end
			else
				reconcileChildren(bN, bO, bV, bP)
				bd()
			end
			return bO.child
		end
		local function updateHostComponent(bN, bO, bP)
			O(bO)
			if bN == nil then
				bg(bO)
			end
			local bQ = bO.type
			local bR = bO.pendingProps
			local bS
			if bN ~= nil then
				bS = bN.memoizedProps
			end
			local bT = bR.children
			local bU = M.shouldSetTextContent(bQ, bR)
			if bU then
				bT = nil
			elseif bS ~= nil and M.shouldSetTextContent(bQ, bS) then
				bO.flags = bit32.bor(bO.flags, aU)
			end
			bO.flags = bit32.bor(bO.flags, aR)
			markRef(bN, bO)
			reconcileChildren(bN, bO, bT, bP)
			return bO.child
		end
		local function updateHostText(bN, bO)
			if bN == nil then
				bg(bO)
			end
			return nil
		end
		local function mountLazyComponent(bN, bO, bP, bQ, bR)
			if bN ~= nil then
				bN.alternate = nil
				bO.alternate = nil
				bO.flags = bit32.bor(bO.flags, aS)
			end
			local bS = bO.pendingProps
			local bT = bP
			local bU = bT._payload
			local bV = bT._init
			local bW = bV(bU)
			bO.type = bW
			bO.tag = br(bW)
			local bX = bO.tag
			local bY = bp(bW, bS)
			local bZ
			if bX == as then
				if aa then
					validateFunctionComponentInDev(bO, bW)
					bW = v(bW)
					bO.type = bW
				end
				bZ = bI(nil, bO, bW, bY, bR)
				return bZ
			elseif bX == au then
				if aa then
					bW = x(bW)
					bO.type = bW
				end
				bZ = updateClassComponent(nil, bO, bW, bY, bR)
				return bZ
			elseif bX == az then
				if aa then
					bW = w(bW)
					bO.type = bW
				end
				bZ = updateForwardRef(nil, bO, bW, bY, bR)
				return bZ
			elseif bX == aI then
				if aa or ab then
					if bO.type ~= bO.elementType then
						local b_ = bW.propTypes
						local b0 = bW.validateProps
						if b_ or b0 then
							aq(b_, b0, bY, "prop", m(bW))
						end
					end
				end
				bZ = updateMemoComponent(nil, bO, bW, bp(bW.type, bY), bQ, bR)
				return bZ
			end
			local b_ = ""
			if aa then
				if bW ~= nil and type(bW) == "table" and bW["$$typeof"] == o then
					b_ = " Did you wrap a component in React.lazy() more than once?"
				elseif type(bW) == "table" and bW["$$typeof"] == nil then
					b_ = "\n" .. ai(bW)
				end
			end
			j(
				false,
				"Element type is invalid. Received a promise that resolves to: %s. Lazy element type must resolve to a class or function.%s",
				tostring(bW),
				b_
			)
			return nil
		end
		function mountIncompleteClassComponent(bN, bO, bP, bQ, bR)
			if bN ~= nil then
				bN.alternate = nil
				bO.alternate = nil
				bO.flags = bit32.bor(bO.flags, aS)
			end
			bO.tag = au
			local bS
			if a9(bP) then
				bS = true
				a8(bO)
			else
				bS = false
			end
			a0(bO, bR, bG.markWorkInProgressReceivedUpdate)
			bl(bO, bP, bQ)
			bm(bO, bP, bQ, bR)
			return finishClassComponent(nil, bO, bP, true, bS, bR)
		end
		local function mountIndeterminateComponent(bN, bO, bP, bQ)
			if bN ~= nil then
				bN.alternate = nil
				bO.alternate = nil
				bO.flags = bit32.bor(bO.flags, aS)
			end
			local bR = bO.pendingProps
			local bS
			if not c then
				local bT = a6(bO, bP, false)
				bS = a5(bO, bT)
			end
			a0(bO, bQ, bG.markWorkInProgressReceivedUpdate)
			local bT
			if aa then
				if type(bP) == "table" and type(bP.render) == "function" then
					local bU = m(bP) or "Unknown"
					if not bK.didWarnAboutBadClass[bU] then
						ae.error(
							"The <%s /> component appears to have a render method, but doesn't extend React.Component. This is likely to cause errors. Change %s to extend React.Component instead.",
							bU,
							bU
						)
						bK.didWarnAboutBadClass[bU] = true
					end
				end
				if bit32.band(bO.mode, K) ~= 0 then
					q.recordLegacyContextWarning(bO)
				end
				t(true)
				bF.current = bO
				bT = renderWithHooks(nil, bO, bP, bR, bS, bQ)
				t(false)
			else
				bT = renderWithHooks(nil, bO, bP, bR, bS, bQ)
			end
			bO.flags = bit32.bor(bO.flags, aR)
			local bU = type(bT)
			if aa then
				if bT ~= nil and bU == "table" and type(bT.render) == "function" and bT["$$typeof"] == nil then
					local bV = m(bP) or "Unknown"
					if not bK.didWarnAboutModulePatternComponent[bV] then
						ae.error(
							"The <%s /> component appears to be a function component that returns a class instance. Change %s to a class that extends React.Component instead. ",
							bV,
							bV
						)
						bK.didWarnAboutModulePatternComponent[bV] = true
					end
				end
			end
			if not d and bT ~= nil and bU == "table" and type(bT.render) == "function" and bT["$$typeof"] == nil then
				if aa then
					local bV = m(bP) or "Unknown"
					if not bK.didWarnAboutModulePatternComponent[bV] then
						ae.error(
							"The <%s /> component appears to be a function component that returns a class instance. "
								.. "Change %s to a class that extends React.Component instead. "
								.. bV,
							bV
						)
						bK.didWarnAboutModulePatternComponent[bV] = true
					end
				end
				bO.tag = au
				bO.memoizedState = nil
				bO.updateQueue = nil
				local bV = false
				if a9(bP) then
					bV = true
					a8(bO)
				else
					bV = false
				end
				bO.memoizedState = bT.state
				F(bO)
				local bW
				if type(bP) ~= "function" then
					bW = (bP).getDerivedStateFromProps
				end
				if bW ~= nil and type(bW) == "function" then
					bk(bO, bP, bW, bR)
				end
				bj(bO, bT)
				bm(bO, bP, bR, bQ)
				return finishClassComponent(nil, bO, bP, true, bV, bQ)
			else
				bO.tag = as
				if aa then
					if c and bP.contextTypes then
						ae.error(
							"%s uses the legacy contextTypes API which is no longer supported. Use React.createContext() with React.useContext() instead.",
							m(bP) or "Unknown"
						)
					end
					if b and bit32.band(bO.mode, K) ~= 0 then
						bD()
						local bV, bW = xpcall(renderWithHooks, k, nil, bO, bP, bR, bS, bQ)
						bE()
						if bV then
							bT = bW
						else
							error(bW)
						end
					end
				end
				reconcileChildren(nil, bO, bT, bQ)
				if aa then
					validateFunctionComponentInDev(bO, bP)
				end
				return bO.child
			end
		end
		function validateFunctionComponentInDev(bN, bO)
			if aa then
				if bN.ref ~= nil then
					local bP = ""
					local bQ = s()
					if bQ then
						bP ..= "\n\nCheck the render method of `" .. bQ .. "`."
					end
					local bR = bQ or bN._debugID or ""
					local bS = bN._debugSource
					if bS then
						bR = bS.fileName .. ":" .. bS.lineNumber
					end
					if not bK.didWarnAboutFunctionRefs[bR] then
						bK.didWarnAboutFunctionRefs[bR] = true
						ae.error(
							"Function components cannot be given refs. Attempts to access this ref will fail. Did you mean to use React.forwardRef()?%s",
							bP
						)
					end
				end
				if i and type(bO) ~= "function" and bO.defaultProps ~= nil then
					local bP = m(bO) or "Unknown"
					if not bK.didWarnAboutDefaultPropsOnFunctionComponent[bP] then
						ae.error(
							"%s: Support for defaultProps will be removed from function components in a future major release.",
							bP
						)
						bK.didWarnAboutDefaultPropsOnFunctionComponent[bP] = true
					end
				end
				if
					type(bO) ~= "function"
					and bO.getDerivedStateFromProps ~= nil
					and type(bO.getDerivedStateFromProps) == "function"
				then
					local bP = m(bO) or "Unknown"
					if not bK.didWarnAboutGetDerivedStateOnFunctionComponent[bP] then
						ae.error("%s: Function components do not support getDerivedStateFromProps.", bP)
						bK.didWarnAboutGetDerivedStateOnFunctionComponent[bP] = true
					end
				end
				if type(bO) ~= "function" and bO.contextType ~= nil and type(bO.contextType) == "table" then
					local bP = m(bO) or "Unknown"
					if not bK.didWarnAboutContextTypeOnFunctionComponent[bP] then
						ae.error("%s: Function components do not support contextType.", bP)
						bK.didWarnAboutContextTypeOnFunctionComponent[bP] = true
					end
				end
			end
		end
		local bN = {
			dehydrated = nil,
			retryLane = am.NoLane,
		}
		local function mountSuspenseOffscreenState(bO)
			return { baseLanes = bO }
		end
		local function updateSuspenseOffscreenState(bO, bP)
			return { baseLanes = am.mergeLanes(bO.baseLanes, bP) }
		end
		local function shouldRemainOnFallback(bO, bP, bQ, bR)
			if bP ~= nil then
				local bS = (bP).memoizedState
				if bS == nil then
					return false
				end
			end
			return R(bO, S)
		end
		local function getRemainingWorkInPrimaryTree(bO, bP)
			return am.removeLanes(bO.childLanes, bP)
		end
		local bO
		local bP
		local bQ
		local bR
		local bS
		local function updateSuspenseComponent(bT, bU, bV)
			local bW = bU.pendingProps
			if aa then
				if shouldSuspend(bU) then
					bU.flags = bit32.bor(bU.flags, aV)
				end
			end
			local bX = Q.current
			local bY = false
			local bZ = bit32.band(bU.flags, aV) ~= aP
			if bZ or shouldRemainOnFallback(bX, bT, bU, bV) then
				bY = true
				bU.flags = bit32.band(bU.flags, bit32.bnot(aV))
			else
				if bT == nil or bT.memoizedState ~= nil then
					if bW.fallback ~= nil and bW.unstable_avoidThisFallback ~= true then
						bX = T(bX, U)
					end
				end
			end
			bX = W(bX)
			V(bU, bX)
			if bT == nil then
				if bW.fallback ~= nil then
					bg(bU)
					if h then
						local b_ = bU.memoizedState
						if b_ ~= nil then
							local b0 = (b_).dehydrated
							if b0 ~= nil then
								return bP(bU, b0, bV)
							end
						end
					end
				end
				local b_ = bW.children
				local b0 = bW.fallback
				if bY then
					local b1 = mountSuspenseFallbackChildren(bU, b_, b0, bV)
					local b2 = bU.child
					b2.memoizedState = mountSuspenseOffscreenState(bV)
					bU.memoizedState = bN
					return b1
				elseif bW.unstable_expectedLoadTime ~= nil and type(bW.unstable_expectedLoadTime) == "number" then
					local b1 = mountSuspenseFallbackChildren(bU, b_, b0, bV)
					local b2 = bU.child
					b2.memoizedState = mountSuspenseOffscreenState(bV)
					bU.memoizedState = bN
					bU.lanes = am.SomeRetryLane
					if g then
						by.markSpawnedWork(am.SomeRetryLane)
					end
					return b1
				else
					return bQ(bU, b_, bV)
				end
			else
				local b_ = bT.memoizedState
				if b_ ~= nil then
					if h then
						local b0 = (b_).dehydrated
						if b0 ~= nil then
							if not bZ then
								return bS(bT, bU, b0, b_, bV)
							elseif bU.memoizedState ~= nil then
								bU.child = bT.child
								bU.flags = bit32.bor(bU.flags, aV)
								return nil
							else
								local b1 = bW.children
								local b2 = bW.fallback
								local b3 = mountSuspenseFallbackAfterRetryWithoutHydrating(bT, bU, b1, b2, bV)
								local b4 = bU.child
								b4.memoizedState = mountSuspenseOffscreenState(bV)
								bU.memoizedState = bN
								return b3
							end
						end
					end
					if bY then
						local b0 = bW.fallback
						local b1 = bW.children
						local b2 = bR(bT, bU, b1, b0, bV)
						local b3 = bU.child
						local b4 = (bT.child).memoizedState
						if b4 == nil then
							b3.memoizedState = mountSuspenseOffscreenState(bV)
						else
							b3.memoizedState = updateSuspenseOffscreenState(b4, bV)
						end
						b3.childLanes = getRemainingWorkInPrimaryTree(bT, bV)
						bU.memoizedState = bN
						return b2
					else
						local b0 = bW.children
						local b1 = bO(bT, bU, b0, bV)
						bU.memoizedState = nil
						return b1
					end
				else
					if bY then
						local b0 = bW.fallback
						local b1 = bW.children
						local b2 = bR(bT, bU, b1, b0, bV)
						local b3 = bU.child
						local b4 = (bT.child).memoizedState
						if b4 == nil then
							b3.memoizedState = mountSuspenseOffscreenState(bV)
						else
							b3.memoizedState = updateSuspenseOffscreenState(b4, bV)
						end
						b3.childLanes = getRemainingWorkInPrimaryTree(bT, bV)
						bU.memoizedState = bN
						return b2
					else
						local b0 = bW.children
						local b1 = bO(bT, bU, b0, bV)
						bU.memoizedState = nil
						return b1
					end
				end
			end
		end
		function bQ(bT, bU, bV)
			local bW = bT.mode
			local bX = { mode = "visible", children = bU }
			local bY = bt(bX, bW, bV, nil)
			bY.return_ = bT
			bT.child = bY
			return bY
		end
		function mountSuspenseFallbackChildren(bT, bU, bV, bW)
			local bX = bT.mode
			local bY = bT.child
			local bZ = { mode = "hidden", children = bU }
			local b_
			local b0
			if bit32.band(bX, L) == I and bY ~= nil then
				b_ = bY
				b_.childLanes = am.NoLanes
				b_.pendingProps = bZ
				if e and bit32.band(bT.mode, J) ~= 0 then
					b_.actualDuration = 0
					b_.actualStartTime = -1
					b_.selfBaseDuration = 0
					b_.treeBaseDuration = 0
				end
				b0 = bs(bV, bX, bW, nil)
			else
				b_ = bt(bZ, bX, am.NoLanes, nil)
				b0 = bs(bV, bX, bW, nil)
			end
			b_.return_ = bT
			b0.return_ = bT
			b_.sibling = b0
			bT.child = b_
			return b0
		end
		local function createWorkInProgressOffscreenFiber(bT, bU)
			return bw(bT, bU)
		end
		function bO(bT, bU, bV, bW)
			local bX = bT.child
			local bY = bX.sibling
			local bZ = createWorkInProgressOffscreenFiber(bX, { mode = "visible", children = bV })
			if bit32.band(bU.mode, L) == I then
				bZ.lanes = bW
			end
			bZ.return_ = bU
			bZ.sibling = nil
			if bY ~= nil then
				local b_ = bU.deletions
				if b_ == nil then
					bU.deletions = { bY }
					bU.flags = bit32.bor(bU.flags, aX)
				else
					table.insert(b_, bY)
				end
			end
			bU.child = bZ
			return bZ
		end
		function bR(bT, bU, bV, bW, bX)
			local bY = bU.mode
			local bZ = bT.child
			local b_ = bZ.sibling
			local b0 = { mode = "hidden", children = bV }
			local b1
			if bit32.band(bY, L) == I and bU.child ~= bZ then
				local b2 = bU.child
				b1 = b2
				b1.childLanes = am.NoLanes
				b1.pendingProps = b0
				if e and bit32.band(bU.mode, J) ~= 0 then
					b1.actualDuration = 0
					b1.actualStartTime = -1
					b1.selfBaseDuration = bZ.selfBaseDuration
					b1.treeBaseDuration = bZ.treeBaseDuration
				end
				bU.deletions = nil
			else
				b1 = createWorkInProgressOffscreenFiber(bZ, b0)
				b1.subtreeFlags = bit32.band(bZ.subtreeFlags, aQ)
			end
			local b2
			if b_ ~= nil then
				b2 = bw(b_, bW)
			else
				b2 = bs(bW, bY, bX, nil)
				b2.flags = bit32.bor(b2.flags, aS)
			end
			b2.return_ = bU
			b1.return_ = bU
			b1.sibling = b2
			bU.child = b1
			return b2
		end
		local function retrySuspenseComponentWithoutHydrating(bT, bU, bV)
			A(bU, bT.child, nil, bV)
			local bW = bU.pendingProps
			local bX = bW.children
			local bY = bQ(bU, bX, bV)
			bY.flags = bit32.bor(bY.flags, aS)
			bU.memoizedState = nil
			return bY
		end
		function mountSuspenseFallbackAfterRetryWithoutHydrating(bT, bU, bV, bW, bX)
			local bY = bU.mode
			local bZ = bt(bV, bY, am.NoLanes, nil)
			local b_ = bs(bW, bY, bX, nil)
			b_.flags = bit32.bor(b_.flags, aS)
			bZ.return_ = bU
			b_.return_ = bU
			bZ.sibling = b_
			bU.child = bZ
			if bit32.band(bU.mode, L) ~= I then
				A(bU, bT.child, nil, bX)
			end
			return b_
		end
		function bP(bT, bU, bV)
			if bit32.band(bT.mode, L) == I then
				if aa then
					ae.error("Cannot hydrate Suspense in legacy mode. Switch fromReactDOM.hydrate(element, container) to ReactDOM.createBlockingRoot(container, { hydrate: true }).render(element) or remove the Suspense componentsthe server rendered components.")
				end
				bT.lanes = am.laneToLanes(am.SyncLane)
			elseif M.isSuspenseInstanceFallback(bU) then
				if g then
					by.markSpawnedWork(am.DefaultHydrationLane)
				end
				bT.lanes = am.laneToLanes(am.DefaultHydrationLane)
			else
				bT.lanes = am.laneToLanes(am.OffscreenLane)
				if g then
					by.markSpawnedWork(am.OffscreenLane)
				end
			end
			return nil
		end
		function bS(bT, bU, bV, bW, bX)
			bh()
			if bit32.band(by.getExecutionContext(), by.RetryAfterError) ~= by.NoContext then
				return retrySuspenseComponentWithoutHydrating(bT, bU, bX)
			end
			if bit32.band(bU.mode, L) == I then
				return retrySuspenseComponentWithoutHydrating(bT, bU, bX)
			end
			if M.isSuspenseInstanceFallback(bV) then
				return retrySuspenseComponentWithoutHydrating(bT, bU, bX)
			end
			local bY = am.includesSomeLane(bX, bT.childLanes)
			if bJ or bY then
				local bZ = by.getWorkInProgressRoot()
				if bZ ~= nil then
					local b_ = am.getBumpedLaneForHydration(bZ, bX)
					if b_ ~= am.NoLane and b_ ~= bW.retryLane then
						bW.retryLane = b_
						local b0 = am.NoTimestamp
						by.scheduleUpdateOnFiber(bT, b_, b0)
					end
				end
				by.renderDidSuspendDelayIfPossible()
				return retrySuspenseComponentWithoutHydrating(bT, bU, bX)
			elseif M.isSuspenseInstancePending(bV) then
				bU.flags = bit32.bor(bU.flags, aV)
				bU.child = bT.child
				local bZ = function()
					return by.retryDehydratedSuspenseBoundary(bT)
				end
				if g then
					if bz == nil then
						bz = a.load("ci").tracing.unstable_wrap
					end
					bZ = bz(bZ)
				end
				M.registerSuspenseInstanceRetry(bV, bZ)
				return nil
			else
				bf(bU, bV)
				local bZ = bU.pendingProps
				local b_ = bZ.children
				local b0 = bQ(bU, b_, bX)
				b0.flags = bit32.bor(b0.flags, aT)
				return b0
			end
		end
		function updatePortalComponent(bT, bU, bV)
			P(bU, bU.stateNode.containerInfo)
			local bW = bU.pendingProps
			if bT == nil then
				bU.child = A(bU, nil, bW, bV)
			else
				reconcileChildren(bT, bU, bW, bV)
			end
			return bU.child
		end
		local bT = false
		local function updateContextProvider(bU, bV, bW)
			local bX = bV.type
			local bY = bX._context
			local bZ = bV.pendingProps
			local b_ = bV.memoizedProps
			local b0 = bZ.value
			if aa or ab then
				if ag.indexOf(ah.keys(bZ), "value") < 1 then
					if not bT then
						bT = true
						ae.error("The `value` prop is required for the `<Context.Provider>`. Did you misspell it or forget to pass it?")
					end
				end
				local b1 = bV.type.propTypes
				local b2 = bV.type.validateProps
				if b1 or b2 then
					aq(b1, b2, bZ, "prop", "Context.Provider")
				end
			end
			a1(bV, b0)
			if b_ ~= nil then
				local b1 = b_.value
				local b2 = _(bY, b0, b1)
				if b2 == 0 then
					if b_.children == bZ.children and not a7() then
						return bH(bU, bV, bW)
					end
				else
					Y(bV, bY, b2, bW)
				end
			end
			local b1 = bZ.children
			reconcileChildren(bU, bV, b1, bW)
			return bV.child
		end
		local bU = {
			usingContextAsConsumer = false,
			usingLegacyConsumer = false,
		}
		function updateContextConsumer(bV, bW, bX)
			local bY = bW.type
			if aa then
				if (bY)._context == nil then
					if bY ~= bY.Consumer then
						if not bU.usingContextAsConsumer then
							bU.usingContextAsConsumer = true
							ae.error("Rendering <Context> directly is not supported and will be removed in a future major release. Did you mean to render <Context.Consumer> instead?")
						end
					end
				else
					bY = (bY)._context
				end
			end
			local bZ = bW.pendingProps
			local b_
			if bZ.render then
				if aa and ac then
					if not bU.usingLegacyConsumer then
						bU.usingLegacyConsumer = true
						ae.warn("Your Context.Consumer component is using legacy Roact syntax, which won't be supported in future versions of Roact. \nPlease provide no props and supply the 'render' function as a child (the 3rd argument of createElement). For example: \n       createElement(ContextConsumer, {render = function(...) end})\nbecomes:\n       createElement(ContextConsumer, nil, function(...) end)\nFor more info, reference the React documentation here: \nhttps://reactjs.org/docs/context.html#contextconsumer")
					end
				end
				b_ = bZ.render
			else
				b_ = bZ.children
			end
			if aa then
				if type(b_) ~= "function" then
					ae.error("A context consumer was rendered with multiple children, or a child that isn't a function. A context consumer expects a single child that is a function. If you did pass a function, make sure there is no trailing or leading whitespace around it.")
				end
			end
			a0(bW, bX, bG.markWorkInProgressReceivedUpdate)
			local b0 = Z(bY, bZ.unstable_observedBits)
			local b1
			if aa then
				bF.current = bW
				t(true)
				b1 = b_(b0)
				t(false)
			else
				b1 = b_(b0)
			end
			bW.flags = bit32.bor(bW.flags, aR)
			reconcileChildren(bV, bW, b1, bX)
			return bW.child
		end
		bG.markWorkInProgressReceivedUpdate = function()
			bJ = true
		end
		function bH(bV, bW, bX)
			if bV then
				bW.dependencies = bV.dependencies
			end
			if e then
				a3(bW)
			end
			bB(bW.lanes)
			if not am.includesSomeLane(bX, bW.childLanes) then
				return nil
			else
				B(bV, bW)
				return bW.child
			end
		end
		function remountFiber(bV, bW, bX)
			if aa then
				local bY = bW.return_
				if bY == nil then
					error("Cannot swap the root fiber.")
				end
				assert(bY ~= nil, "returnFiber was nil in remountFiber")
				bV.alternate = nil
				bW.alternate = nil
				bX.index = bW.index
				bX.sibling = bW.sibling
				bX.return_ = bW.return_
				bX.ref = bW.ref
				if bW == bY.child then
					bY.child = bX
				else
					local bZ = bY.child
					if bZ == nil then
						error("Expected parent to have a child.")
					end
					assert(bZ ~= nil, "prevSibling was nil in remountFiber")
					while bZ.sibling ~= bW do
						bZ = bZ.sibling
						if bZ == nil then
							error("Expected to find the previous sibling.")
						end
					end
					bZ.sibling = bX
				end
				local bZ = bY.deletions
				if bZ == nil then
					bY.deletions = { bV }
					bY.flags = bit32.bor(bY.flags, aX)
				else
					table.insert(bZ, bV)
				end
				bX.flags = bit32.bor(bX.flags, aS)
				return bX
			else
				error("Did not expect this call in production. This is a bug in React. Please file an issue.")
			end
		end
		local function beginWork(bV, bW, bX)
			local bY = bW.lanes
			if aa then
				if bW._debugNeedsRemount and bV ~= nil then
					return remountFiber(
						bV,
						bW,
						bu(bW.type, bW.key, bW.pendingProps, bW._debugOwner or nil, bW.mode, bW.lanes)
					)
				end
			end
			if bV ~= nil then
				local bZ = bV.memoizedProps
				local b_ = bW.pendingProps
				if bZ ~= b_ or a7() or if aa then bW.type ~= bV.type else false then
					bJ = true
				elseif not am.includesSomeLane(bX, bY) then
					bJ = false
					if bW.tag == av then
						pushHostRootContext(bW)
						bd()
					elseif bW.tag == aw then
						O(bW)
					elseif bW.tag == au then
						local b0 = bW.type
						if a9(b0) then
							a8(bW)
						end
					elseif bW.tag == ay then
						P(bW, bW.stateNode.containerInfo)
					elseif bW.tag == aD then
						local b0 = bW.memoizedProps.value
						a1(bW, b0)
					elseif bW.tag == aF then
						if e then
							local b0 = bW.stateNode
							b0.effectDuration = 0
							b0.passiveEffectDuration = 0
						end
					elseif bW.tag == aG then
						local b0 = bW.memoizedState
						if b0 ~= nil then
							if h then
								if (b0).dehydrated ~= nil then
									V(bW, W(Q.current))
									bW.flags = bit32.bor(bW.flags, aV)
									return nil
								end
							end
							local b1 = bW.child
							local b2 = b1.childLanes
							if am.includesSomeLane(bX, b2) then
								return updateSuspenseComponent(bV, bW, bX)
							else
								V(bW, W(Q.current))
								local b3 = bH(bV, bW, bX)
								if b3 ~= nil then
									return b3.sibling
								else
									return nil
								end
							end
						else
							V(bW, W(Q.current))
						end
					elseif bW.tag == aH then
						unimplemented("beginWork: SuspenseListComponent")
					elseif bW.tag == aM or bW.tag == aN then
						bW.lanes = am.NoLanes
						return updateOffscreenComponent(bV, bW, bX)
					end
					return bH(bV, bW, bX)
				else
					if bit32.band(bV.flags, aY) ~= aP then
						bJ = true
					else
						bJ = false
					end
				end
			else
				bJ = false
			end
			bW.lanes = am.NoLanes
			if bW.tag == ar.IndeterminateComponent then
				return mountIndeterminateComponent(bV, bW, bW.type, bX)
			elseif bW.tag == aK then
				local bZ = bW.elementType
				return mountLazyComponent(bV, bW, bZ, bY, bX)
			elseif bW.tag == as then
				local bZ = bW.type
				local b_ = bW.pendingProps
				local b0
				if bW.elementType == bZ then
					b0 = b_
				else
					b0 = bp(bZ, b_)
				end
				return bI(bV, bW, bZ, b0, bX)
			elseif bW.tag == au then
				local bZ = bW.type
				local b_ = bW.pendingProps
				local b0 = bW.elementType == bZ and b_ or bp(bZ, b_)
				return updateClassComponent(bV, bW, bZ, b0, bX)
			elseif bW.tag == av then
				return updateHostRoot(bV, bW, bX)
			elseif bW.tag == aw then
				return updateHostComponent(bV, bW, bX)
			elseif bW.tag == ax then
				return updateHostText(bV, bW)
			elseif bW.tag == aG then
				return updateSuspenseComponent(bV, bW, bX)
			elseif bW.tag == ay then
				return updatePortalComponent(bV, bW, bX)
			elseif bW.tag == az then
				local bZ = bW.type
				local b_ = bW.pendingProps
				local b0 = b_
				if bW.elementType ~= bZ then
					b0 = bp(bZ, b_)
				end
				return updateForwardRef(bV, bW, bZ, b0, bX)
			elseif bW.tag == aA then
				return updateFragment(bV, bW, bX)
			elseif bW.tag == aC then
				return updateMode(bV, bW, bX)
			elseif bW.tag == aF then
				return updateProfiler(bV, bW, bX)
			elseif bW.tag == aD then
				return updateContextProvider(bV, bW, bX)
			elseif bW.tag == aE then
				return updateContextConsumer(bV, bW, bX)
			elseif bW.tag == aI then
				local bZ = bW.type
				local b_ = bW.pendingProps
				local b0 = bp(bZ, b_)
				if aa or ab then
					if bW.type ~= bW.elementType then
						local b1
						local b2
						if type(bZ) == "table" then
							b1 = bZ.propTypes
							b2 = bZ.validateProps
						end
						if b1 or b2 then
							aq(b1, b2, b0, "prop", m(bZ))
						end
					end
				end
				b0 = bp(bZ.type, b0)
				return updateMemoComponent(bV, bW, bZ, b0, bY, bX)
			elseif bW.tag == aJ then
				return bL(bV, bW, bW.type, bW.pendingProps, bY, bX)
			elseif bW.tag == aL then
				local bZ = bW.type
				local b_ = bW.pendingProps
				local b0 = bW.elementType == bZ and b_ or bp(bZ, b_)
				return mountIncompleteClassComponent(bV, bW, bZ, b0, bX)
			elseif bW.tag == aM then
				return updateOffscreenComponent(bV, bW, bX)
			elseif bW.tag == aN then
				return bM(bV, bW, bX)
			end
			j(
				false,
				"Unknown unit of work tag (%s). This error is likely caused by a bug in React. Please file an issue.",
				tostring(bW.tag)
			)
			return nil
		end
		bG.beginWork = beginWork
		local bV = a.load("cl")
		local bW = bG
		bV.register("ReactFiberBeginWork", bW)
		return bW
	end
	function a.c1()
		local function unimplemented(aa)
			print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
			print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
			print("UNIMPLEMENTED ERROR: " .. tostring(aa))
			error("FIXME (roblox): " .. aa .. " is unimplemented", 2)
		end
		local aa = a.load("cj")
		local ab = a.load("cn")
		local ac = ab.OffscreenLane
		local ad = a.load("ck")
		local ae = a.load("cs")
		local af = a.load("cD")
		local ag = af.resetWorkInProgressVersions
		local ah = a.load("b1")
		local ai = ah.IndeterminateComponent
		local aj = ah.FunctionComponent
		local ak = ah.ClassComponent
		local al = ah.HostRoot
		local am = ah.HostComponent
		local an = ah.HostText
		local ao = ah.HostPortal
		local ap = ah.ContextProvider
		local aq = ah.ContextConsumer
		local ar = ah.ForwardRef
		local as = ah.Fragment
		local au = ah.Mode
		local av = ah.Profiler
		local aw = ah.SuspenseComponent
		local ax = ah.SuspenseListComponent
		local ay = ah.MemoComponent
		local az = ah.SimpleMemoComponent
		local aA = ah.LazyComponent
		local aC = ah.IncompleteClassComponent
		local aD = ah.FundamentalComponent
		local aE = ah.ScopeComponent
		local aF = ah.Block
		local aG = ah.OffscreenComponent
		local aH = ah.LegacyHiddenComponent
		local aI = a.load("co")
		local aJ = a.load("b2")
		local aK = aJ.NoMode
		local aL = aJ.ConcurrentMode
		local aM = aJ.BlockingMode
		local aN = aJ.ProfileMode
		local aO = a.load("b3")
		local aP = aO.Ref
		local aQ = aO.Update
		local aR = aO.Callback
		local aS = aO.Passive
		local aT = aO.Deletion
		local aU = aO.NoFlags
		local aV = aO.DidCapture
		local aW = aO.Snapshot
		local aX = aO.MutationMask
		local aY = aO.LayoutMask
		local aZ = aO.PassiveMask
		local a_ = aO.StaticMask
		local a0 = aO.PerformedWork
		local a1 = a.load("b0").invariant
		local a2 = a.load("cE")
		local a3 = a2.getRootHostContainer
		local a4 = a2.popHostContext
		local a5 = a2.getHostContext
		local a6 = a2.popHostContainer
		local a7 = a.load("cF")
		local a8 = a7.popSuspenseContext
		local a9 = a7.suspenseStackCursor
		local b = a7.InvisibleParentSuspenseContext
		local ba = a7.hasSuspenseContext
		local bb = a.load("cr")
		local bc = bb.isContextProvider
		local bd = bb.popContext
		local be = bb.popTopLevelContextObject
		local bf = a.load("cI").popProvider
		local bg = a.load("cG")
		local bh = bg.prepareToHydrateHostSuspenseInstance
		local bi = bg.popHydrationState
		local bj = bg.resetHydrationState
		local bk = bg.prepareToHydrateHostInstance
		local bl = bg.prepareToHydrateHostTextInstance
		local bm = a.load("b0").ReactFeatureFlags
		local bn = bm.enableSchedulerTracing
		local bo = bm.enableSuspenseCallback
		local bp = bm.enableSuspenseServerRenderer
		local bq = bm.enableFundamentalAPI
		local br = bm.enableProfilerTimer
		local bs = a.load("cl")
		local bt = bs.lazy("ReactFiberWorkLoop")
		local bu = ab.NoLanes
		local bv = ab.includesSomeLane
		local bw = ab.mergeLanes
		local by = a.load("cJ")
		local bz = by.transferActualDuration
		local function markUpdate(bA)
			bA.flags = bit32.bor(bA.flags, aQ)
		end
		local function markRef(bA)
			bA.flags = bit32.bor(bA.flags, aP)
		end
		local function hadNoMutationsEffects(bA, bB)
			local bC = bA ~= nil and bA.child == bB.child
			if bC then
				return true
			end
			local bD = bB.child
			while bD ~= nil do
				if bit32.band(bD.flags, aX) ~= aU then
					return false
				end
				if bit32.band(bD.subtreeFlags, aX) ~= aU then
					return false
				end
				bD = bD.sibling
			end
			return true
		end
		local bA
		local bB
		local bC
		local bD
		if ad.supportsMutation then
			bA = function(bE, bF, bH, bI)
				local bJ = bF.child
				while bJ ~= nil do
					if bJ.tag == am or bJ.tag == an then
						ad.appendInitialChild(bE, bJ.stateNode)
					elseif bq and bJ.tag == aD then
						ad.appendInitialChild(bE, bJ.stateNode.instance)
					elseif bJ.tag == ao then
					elseif bJ.child ~= nil then
						bJ.child.return_ = bJ
						bJ = bJ.child
						continue
					end
					if bJ == bF then
						return
					end
					while bJ.sibling == nil do
						if bJ.return_ == nil or bJ.return_ == bF then
							return
						end
						bJ = bJ.return_
					end
					(bJ.sibling).return_ = bJ.return_
					bJ = bJ.sibling
				end
			end
			bB = function(bE, bF) end
			function bC(bE, bF, bH, bI, bJ)
				local bK = bE.memoizedProps
				if bK == bI then
					return
				end
				local bL = bF.stateNode
				local bM = a5()
				local bN = ad.prepareUpdate(bL, bH, bK, bI, bJ, bM)
				bF.updateQueue = bN
				if bN then
					markUpdate(bF)
				end
			end
			function bD(bE, bF, bH, bI)
				if bH ~= bI then
					markUpdate(bF)
				end
			end
		elseif ad.supportsPersistence then
			bA = function(bE, bF, bH, bI)
				unimplemented("appendAllChildren")
			end
			local function appendAllChildrenToContainer(bE, bF, bH, bI)
				unimplemented("appendAllChildrenToContainer")
			end
			function bB(bE, bF)
				local bH = bF.stateNode
				local bI = hadNoMutationsEffects(bE, bF)
				if bI then
				else
					local bJ = bH.containerInfo
					local bK = ad.createContainerChildSet(bJ)
					appendAllChildrenToContainer(bK, bF, false, false)
					bH.pendingChildren = bK
					markUpdate(bF)
					ad.finalizeContainerChildren(bJ, bK)
				end
			end
		else
			bB = function(bE, bF) end
		end
		local function bubbleProperties(bE)
			local bF = bE.alternate ~= nil and (bE.alternate).child == bE.child
			local bH = bu
			local bI = aU
			if not bF then
				if br and bit32.band(bE.mode, aN) ~= aK then
					local bJ = bE.actualDuration
					local bK = bE.selfBaseDuration
					local bL = bE.child
					while bL ~= nil do
						bH = bw(bH, bw(bL.lanes, bL.childLanes))
						bI = bit32.bor(bI, bL.subtreeFlags)
						bI = bit32.bor(bI, bL.flags)
						bJ += bL.actualDuration
						bK += bL.treeBaseDuration
						bL = bL.sibling
					end
					bE.actualDuration = bJ
					bE.treeBaseDuration = bK
				else
					local bJ = bE.child
					while bJ ~= nil do
						bH = bit32.bor(bH, bit32.bor(bJ.lanes, bJ.childLanes))
						bI = bit32.bor(bI, bJ.subtreeFlags)
						bI = bit32.bor(bI, bJ.flags)
						bJ.return_ = bE
						bJ = bJ.sibling
					end
				end
				bE.subtreeFlags = bit32.bor(bE.subtreeFlags, bI)
			else
				if br and bit32.band(bE.mode, aN) ~= aK then
					local bJ = bE.selfBaseDuration
					local bK = bE.child
					while bK ~= nil do
						bH = bw(bH, bw(bK.lanes, bK.childLanes))
						bI = bit32.bor(bI, bit32.band(bK.subtreeFlags, a_))
						bI = bit32.bor(bI, bit32.band(bK.flags, a_))
						bJ += bK.treeBaseDuration
						bK = bK.sibling
					end
					bE.treeBaseDuration = bJ
				else
					local bJ = bE.child
					while bJ ~= nil do
						bH = bit32.bor(bH, bit32.bor(bJ.lanes, bJ.childLanes))
						bI = bit32.bor(bI, bit32.band(bJ.subtreeFlags, a_))
						bI = bit32.bor(bI, bit32.band(bJ.flags, a_))
						bJ.return_ = bE
						bJ = bJ.sibling
					end
				end
				bE.subtreeFlags = bit32.bor(bE.subtreeFlags, bI)
			end
			bE.childLanes = bH
			return bF
		end
		local function completeWork(bE, bF, bH)
			local bI = bF.pendingProps
			if
				bF.tag == ai
				or bF.tag == aA
				or bF.tag == az
				or bF.tag == aj
				or bF.tag == ar
				or bF.tag == as
				or bF.tag == au
				or bF.tag == aq
				or bF.tag == ay
			then
				bubbleProperties(bF)
				return nil
			elseif bF.tag == ak then
				local bJ = bF.type
				if bc(bJ) then
					bd(bF)
				end
				bubbleProperties(bF)
				return nil
			elseif bF.tag == al then
				a6(bF)
				be(bF)
				ag()
				local bJ = bF.stateNode
				if bJ.pendingContext then
					bJ.context = bJ.pendingContext
					bJ.pendingContext = nil
				end
				if bE == nil or bE.child == nil then
					local bK = bi(bF)
					if bK then
						markUpdate(bF)
					elseif not bJ.hydrate then
						bF.flags = bit32.bor(bF.flags, aW)
					end
				end
				bB(bE, bF)
				bubbleProperties(bF)
				return nil
			elseif bF.tag == am then
				a4(bF)
				local bJ = a3()
				local bK = bF.type
				if bE ~= nil and bF.stateNode ~= nil then
					bC(bE, bF, bK, bI, bJ)
					if bE.ref ~= bF.ref then
						markRef(bF)
					end
				else
					if not bI then
						a1(
							bF.stateNode ~= nil,
							"We must have new props for new mounts. This error is likely caused by a bug in React. Please file an issue."
						)
						bubbleProperties(bF)
						return nil
					end
					local bL = a5()
					local bM = bi(bF)
					if bM then
						if bk(bF, bJ, bL) then
							markUpdate(bF)
						end
					else
						local bN = ad.createInstance(bK, bI, bJ, bL, bF)
						bA(bN, bF, false, false)
						bF.stateNode = bN
						if ad.finalizeInitialChildren(bN, bK, bI, bJ, bL) then
							markUpdate(bF)
						end
					end
					if bF.ref ~= nil then
						markRef(bF)
					end
				end
				bubbleProperties(bF)
				return nil
			elseif bF.tag == an then
				local bJ = bI
				if bE and bF.stateNode ~= nil then
					local bK = bE.memoizedProps
					bD(bE, bF, bK, bJ)
				else
					if typeof(bJ) ~= "string" then
						a1(
							bF.stateNode ~= nil,
							"We must have new props for new mounts. This error is likely caused by a bug in React. Please file an issue."
						)
					end
					local bK = a3()
					local bL = a5()
					local bM = bi(bF)
					if bM then
						if bl(bF) then
							markUpdate(bF)
						end
					else
						bF.stateNode = ad.createTextInstance(bJ, bK, bL, bF)
					end
				end
				bubbleProperties(bF)
				return nil
			elseif bF.tag == av then
				local bJ = bubbleProperties(bF)
				if not bJ then
					local bK = aQ
					local bL = aR
					local bM = aS
					local bN = bF.subtreeFlags
					local bO = bF.flags
					local bP = bO
					if bit32.band(bO, a0) ~= aU or bit32.band(bN, a0) ~= aU then
						bP = bit32.bor(bP, bK)
					end
					if bit32.band(bO, bit32.bor(aY, aT)) ~= aU or bit32.band(bN, bit32.bor(aY, aT)) ~= aU then
						bP = bit32.bor(bP, bL)
					end
					if bit32.band(bO, aZ) ~= aU or bit32.band(bN, aZ) ~= aU then
						bP = bit32.bor(bP, bM)
					end
					bF.flags = bP
				end
				return nil
			elseif bF.tag == aw then
				a8(bF)
				local bJ = bF.memoizedState
				if bp then
					if bJ ~= nil and (bJ).dehydrated ~= nil then
						if bE == nil then
							local bK = bi(bF)
							a1(
								bK,
								"A dehydrated suspense component was completed without a hydrated node. This is probably a bug in React."
							)
							bh(bF)
							if bn then
								bt.markSpawnedWork(ac)
							end
							bubbleProperties(bF)
							if br then
								if bit32.band(bF.mode, aN) ~= aK then
									local bL = bJ ~= nil
									if bL then
										local bM = bF.child
										if bM ~= nil then
											bF.treeBaseDuration = bM.treeBaseDuration
										end
									end
								end
							end
							return nil
						else
							bj()
							if bit32.band(bF.flags, aV) == aU then
								bF.memoizedState = nil
							end
							bF.flags = bit32.bor(bF.flags, aQ)
							bubbleProperties(bF)
							if br then
								if bit32.band(bF.mode, aN) ~= aK then
									local bK = bJ ~= nil
									if bK then
										local bL = bF.child
										if bL ~= nil then
											bF.treeBaseDuration -= bL.treeBaseDuration
										end
									end
								end
							end
							return nil
						end
					end
				end
				if bit32.band(bF.flags, aV) ~= aU then
					bF.lanes = bH
					if br and bit32.band(bF.mode, aN) ~= aK then
						bz(bF)
					end
					return bF
				end
				local bK = bJ ~= nil
				local bL = false
				if bE == nil then
					if bF.memoizedProps.fallback ~= nil then
						bi(bF)
					end
				else
					local bM = bE.memoizedState
					bL = bM ~= nil
				end
				if bK and not bL then
					if bit32.band(bF.mode, aM) ~= aK then
						local bM = bE == nil and bF.memoizedProps.unstable_avoidThisFallback ~= true
						if bM or ba(a9.current, b) then
							bt.renderDidSuspend()
						else
							bt.renderDidSuspendDelayIfPossible()
						end
					end
				end
				if ad.supportsPersistence then
					if bK then
						bF.flags = bit32.bor(bF.flags, aQ)
					end
				end
				if ad.supportsMutation then
					if bK or bL then
						bF.flags = bit32.bor(bF.flags, aQ)
					end
				end
				if bo and bF.updateQueue ~= nil and bF.memoizedProps.suspenseCallback ~= nil then
					bF.flags = bit32.bor(bF.flags, aQ)
				end
				bubbleProperties(bF)
				if br then
					if bit32.band(bF.mode, aN) ~= aK then
						if bK then
							local bM = bF.child
							if bM ~= nil then
								bF.treeBaseDuration -= bM.treeBaseDuration
							end
						end
					end
				end
				return nil
			elseif bF.tag == ao then
				a6(bF)
				bB(bE, bF)
				if bE == nil then
					ad.preparePortalMount(bF.stateNode.containerInfo)
				end
				bubbleProperties(bF)
				return nil
			elseif bF.tag == ap then
				bf(bF)
				bubbleProperties(bF)
				return nil
			elseif bF.tag == aC then
				local bJ = bF.type
				if bc(bJ) then
					bd(bF)
				end
				bubbleProperties(bF)
				return nil
			elseif bF.tag == ax then
				unimplemented("SuspenseListComponent")
			elseif bF.tag == aD then
				unimplemented("FundamentalComponent")
			elseif bF.tag == aE then
				unimplemented("ScopeComponent")
			elseif bF.tag == aF then
				unimplemented("Block")
			elseif bF.tag == aG or bF.tag == aH then
				bt.popRenderLanes(bF)
				local bJ = bF.memoizedState
				local bK = bJ ~= nil
				if bE ~= nil then
					local bL = bE.memoizedState
					local bM = bL ~= nil
					if bM ~= bK and bI.mode ~= "unstable-defer-without-hiding" then
						bF.flags = bit32.bor(bF.flags, aQ)
					end
				end
				if not bK or bv(bt.subtreeRenderLanes, ac) or bit32.band(bF.mode, aL) == aK then
					bubbleProperties(bF)
				end
				return nil
			end
			a1(
				false,
				"Unknown unit of work tag (%s). This error is likely caused by a bug in React. Please file an issue.",
				tostring(bF.tag)
			)
			return nil
		end
		return { completeWork = completeWork }
	end
	function a.c2()
		local function unimplemented(aa)
			print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
			print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
			print("UNIMPLEMENTED ERROR: " .. aa)
			error("FIXME (roblox): " .. aa .. " is unimplemented")
		end
		local aa = _G.__DEV__
		local ab = a.load("b_")
		local ac = ab.Array
		local ad = ab.Error
		local ae = ab.Object
		local af = a.load("cX").createRef
		local ag = a.load("cX").createBinding
		local ah = a.load("b0").console
		local ai = a.load("b0")
		local aj = a.load("cj")
		local ak = a.load("cn")
		local al = a.load("cQ")
		local am = a.load("b0").ReactSharedInternals
		local an = a.load("b0").ReactFeatureFlags
		local ao = an.enableDebugTracing
		local ap = an.enableSchedulingProfiler
		local aq = an.enableNewReconciler
		local ar = an.enableDoubleInvokingEffects
		local as = a.load("b2").DebugTracingMode
		local au = ak.NoLane
		local av = ak.NoLanes
		local aw = ak.isSubsetOfLanes
		local ax = ak.mergeLanes
		local ay = ak.removeLanes
		local az = ak.markRootEntangled
		local aA = ak.markRootMutableRead
		local aC = a.load("cI")
		local aD = aC.readContext
		local aE = a.load("b3")
		local aF = aE.Update
		local aG = aE.Passive
		local aH = aE.PassiveStatic
		local aI = aE.MountLayoutDev
		local aJ = aE.MountPassiveDev
		local aK = al.HasEffect
		local aL = al.Layout
		local aM = al.Passive
		local aN = a.load("cl")
		local aO = aN.lazy("ReactFiberWorkLoop")
		local aP = a.load("b0").invariant
		local aQ = a.load("b0").getComponentName
		local function is(aR, aS)
			return aR == aS and (aR ~= 0 or 1 / aR == 1 / aS) or aR ~= aR and aS ~= aS
		end
		local aR = a.load("cl")
		local aS = aR.lazy("ReactFiberBeginWork")
		local aT = function(...)
			return aS.markWorkInProgressReceivedUpdate(...)
		end
		local aU = a.load("cG").getIsHydrating
		local aV = a.load("ck")
		local aW = a.load("cD")
		local aX = aW.warnAboutMultipleRenderersDEV
		local aY = aW.getWorkInProgressVersion
		local aZ = aW.setWorkInProgressVersion
		local a_ = aW.markSourceAsDirty
		local a0 = a.load("cA").logStateUpdateScheduled
		local a1 = a.load("cB").markStateUpdateScheduled
		local a2 = am.ReactCurrentDispatcher
		local a3
		local a4
		if aa then
			a4 = {}
			a3 = {}
		end
		local a5 = {}
		local a6 = av
		local a7
		local a8
		local a9
		local b = false
		local ba = false
		local bb = 25
		local bc
		local bd
		local be = 0
		local bf = false
		local bg
		local bh
		local bi
		local bj
		local bk
		local bl
		local bm
		local function getHighestIndex(bn)
			local bo = 0
			for bp, bq in bn do
				bo = if bp > bo then bp else bo
			end
			return bo
		end
		local function isArrayOrSparseArray(bn)
			if type(bn) ~= "table" then
				return false
			end
			for bo, bp in bn do
				if type(bo) ~= "number" then
					return false
				end
			end
			return true
		end
		local function mountHookTypesDev()
			if aa then
				local bn = bc
				if bd == nil then
					bd = { bn }
				else
					table.insert(bd, bn)
				end
			end
		end
		function updateHookTypesDev()
			if aa then
				local bn = bc
				if bd ~= nil then
					be += 1
					if bd[be] ~= bn then
						warnOnHookMismatchInDev(bn)
					end
				end
			end
		end
		local function checkDepsAreArrayDev(bn)
			if aa then
				if bn ~= nil and not isArrayOrSparseArray(bn) then
					ah.error(
						"%s received a final argument that is not an array (instead, received `%s`). When specified, the final argument must be an array.",
						bc,
						type(bn)
					)
				end
			end
		end
		function warnOnHookMismatchInDev(bn)
			if aa then
				local bo = aQ(a7.type) or "Component"
				if not a3[bo] then
					a3[bo] = true
					if bd ~= nil then
						local bp = ""
						local bq = 30
						for br = 1, be do
							local bs = (bd)[br]
							local bt
							if br == be then
								bt = bn
							else
								bt = bs
							end
							local bu = tostring(br) .. ". " .. (bs or "undefined")
							while string.len(bu) < bq do
								bu ..= " "
							end
							bu ..= bt .. "\n"
							bp ..= bu
						end
						ah.error(
							"React has detected a change in the order of Hooks called by %s. This will lead to bugs and errors if not fixed. For more information, read the Rules of Hooks: https://reactjs.org/link/rules-of-hooks\n\n   Previous render            Next render\n   ------------------------------------------------------\n%s   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n",
							bo,
							bp
						)
					end
				end
			end
		end
		local function throwInvalidHookError()
			error(
				ad.new("Invalid hook call. Hooks can only be called inside of the body of a function component. This could happen for one of the following reasons:\n1. You might have mismatching versions of React and the renderer (such as React DOM)\n2. You might be breaking the Rules of Hooks\n3. You might have more than one copy of React in the same app\nSee https://reactjs.org/link/invalid-hook-call for tips about how to debug and fix this problem.")
			)
		end
		local function areHookInputsEqual(bn, bo)
			if aa then
				if bf then
					return false
				end
			end
			if bo == nil then
				if aa then
					ah.error(
						"%s received a final argument during this render, but not during the previous render. Even though the final argument is optional, its type cannot change between renders.",
						bc
					)
				end
				return false
			end
			local bp = getHighestIndex(bn)
			local bq = getHighestIndex(bo)
			if bp ~= bq then
				return false
			end
			local br = math.min(bq, bp)
			for bs = 1, br do
				if is(bn[bs], bo[bs]) then
					continue
				end
				return false
			end
			return true
		end
		a5.bailoutHooks = function(bn, bo, bp)
			bo.updateQueue = bn.updateQueue
			if aa and ar then
				bo.flags = bit32.band(bo.flags, bit32.bnot(bit32.bor(aJ, aG, aI, aF)))
			else
				bo.flags = bit32.band(bo.flags, bit32.bnot(bit32.bor(aG, aF)))
			end
			bn.lanes = ay(bn.lanes, bp)
		end
		local bn = false
		a5.resetHooksAfterThrow = function()
			a2.current = a5.ContextOnlyDispatcher
			if b then
				local bo = a7.memoizedState
				while bo ~= nil do
					local bp = bo.queue
					if bp ~= nil then
						bp.pending = nil
					end
					bo = bo.next
				end
				b = false
			end
			a6 = av
			a7 = nil
			a8 = nil
			a9 = nil
			if aa then
				bd = nil
				be = 0
				bc = nil
				bn = false
			end
			ba = false
		end
		local function mountWorkInProgressHook()
			local bo = { memoizedState = nil, baseState = nil, baseQueue = nil, queue = nil, next = nil }
			if a9 == nil then
				a7.memoizedState = bo
				a9 = bo
			else
				a9.next = bo
				a9 = bo
			end
			return a9
		end
		local function updateWorkInProgressHook()
			local bo
			if a8 == nil then
				local bp = a7.alternate
				if bp ~= nil then
					bo = bp.memoizedState
				else
					bo = nil
				end
			else
				bo = a8.next
			end
			local bp
			if a9 == nil then
				bp = a7.memoizedState
			else
				bp = a9.next
			end
			if bp ~= nil then
				a9 = bp
				bp = a9.next
				a8 = bo
			else
				if bo == nil then
					error(ad.new("Rendered more hooks than during the previous render."))
				end
				a8 = bo
				local bq = {
					memoizedState = a8.memoizedState,
					baseState = a8.baseState,
					baseQueue = a8.baseQueue,
					queue = a8.queue,
					next = nil,
				}
				if a9 == nil then
					a9 = bq
					a7.memoizedState = bq
				else
					a9.next = bq
					a9 = bq
				end
			end
			return a9
		end
		function basicStateReducer(bo, bp)
			if type(bp) == "function" then
				return bp(bo)
			else
				return bp
			end
		end
		function mountReducer(bo, bp, bq)
			local br = mountWorkInProgressHook()
			local bs
			if bq ~= nil then
				bs = bq(bp)
			else
				bs = bp
			end
			br.baseState = bs
			br.memoizedState = br.baseState
			local bt = { pending = nil, dispatch = nil, lastRenderedReducer = bo, lastRenderedState = bs }
			br.queue = bt
			local bu = a7
			local bv = function(bv, ...)
				dispatchAction(bu, bt, bv, ...)
			end
			bt.dispatch = bv
			return br.memoizedState, bv
		end
		function updateReducer(bo, bp, bq)
			local br = updateWorkInProgressHook()
			local bs = br.queue
			assert(bs ~= nil, "Should have a queue. This is likely a bug in React. Please file an issue.")
			bs.lastRenderedReducer = bo
			local bt = a8
			local bu = bt.baseQueue
			local bv = bs.pending
			if bv ~= nil then
				if bu ~= nil then
					local bw = bu.next
					local by = bv.next
					bu.next = by
					bv.next = bw
				end
				bu = bv
				bt.baseQueue = bu
				bs.pending = nil
			end
			if bu ~= nil then
				local bw = bu.next
				local by = bt.baseState
				local bz
				local bA
				local bB
				local bC = bw
				repeat
					local bD = bC.lane
					if bit32.band(a6, bD) ~= bD then
						local bE = {
							lane = bD,
							action = bC.action,
							eagerReducer = bC.eagerReducer,
							eagerState = bC.eagerState,
							next = nil,
						}
						if bB == nil then
							bB = bE
							bA = bB
							bz = by
						else
							bB.next = bE
							bB = bB.next
						end
						a7.lanes = ax(a7.lanes, bD)
						aO.markSkippedUpdateLanes(bD)
					else
						if bB ~= nil then
							local bE = {
								lane = au,
								action = bC.action,
								eagerReducer = bC.eagerReducer,
								eagerState = bC.eagerState,
								next = nil,
							}
							bB.next = bE
							bB = bB.next
						end
						if bC.eagerReducer == bo then
							by = bC.eagerState
						else
							local bE = bC.action
							by = bo(by, bE)
						end
					end
					bC = bC.next
				until bC == nil or bC == bw
				if bB == nil then
					bz = by
				else
					bB.next = bA
				end
				if not is(by, br.memoizedState) then
					aT()
				end
				br.memoizedState = by
				br.baseState = bz
				br.baseQueue = bB
				bs.lastRenderedState = by
			end
			local bw = bs.dispatch
			return br.memoizedState, bw
		end
		function rerenderReducer(bo, bp, bq)
			local br = updateWorkInProgressHook()
			local bs = br.queue
			assert(bs ~= nil, "Should have a queue. This is likely a bug in React. Please file an issue.")
			bs.lastRenderedReducer = bo
			local bt = bs.dispatch
			local bu = bs.pending
			local bv = br.memoizedState
			if bu ~= nil then
				bs.pending = nil
				local bw = bu.next
				local by = bw
				repeat
					local bz = by.action
					bv = bo(bv, bz)
					by = by.next
				until by == bw
				if not is(bv, br.memoizedState) then
					aT()
				end
				br.memoizedState = bv
				if br.baseQueue == nil then
					br.baseState = bv
				end
				bs.lastRenderedState = bv
			end
			return bv, bt
		end
		function readFromUnsubcribedMutableSource(bo, bp, bq)
			if aa then
				aX(bp)
			end
			local br = bp._getVersion
			local bs = br(bp._source)
			local bt = false
			local bu = aY(bp)
			if bu ~= nil then
				bt = bu == bs
			else
				bt = aw(a6, bo.mutableReadLanes)
				if bt then
					aZ(bp, bs)
				end
			end
			if bt then
				local bv = bq(bp._source)
				if aa then
					if type(bv) == "function" then
						ah.error("Mutable source should not return a function as the snapshot value. Functions may close over mutable values and cause tearing.")
					end
				end
				return bv
			else
				a_(bp)
				error(
					ad.new("Cannot read from mutable source during the current render without tearing. This is a bug in React. Please file an issue.")
				)
			end
		end
		function useMutableSource(bo, bp, bq, br)
			local bs = aO.getWorkInProgressRoot()
			aP(bs ~= nil, "Expected a work-in-progress root. This is a bug in React. Please file an issue.")
			local bt = bp._getVersion
			local bu = bt(bp._source)
			local bv = a2.current
			assert(bv ~= nil, "dispatcher was nil, this is a bug in React")
			local bw, by = bv.useState(function()
				return readFromUnsubcribedMutableSource(bs, bp, bq)
			end)
			local bz = bw
			local bA = a9
			local bB = bo.memoizedState
			if bB.refs == nil then
				error(tostring(debug.traceback()))
			end
			local bC = bB.refs
			local bD = bC.getSnapshot
			local bE = bB.source
			local bF = bB.subscribe
			local bH = a7
			bo.memoizedState = { refs = bC, source = bp, subscribe = br }
			bv.useEffect(function()
				bC.getSnapshot = bq
				bC.setSnapshot = by
				local bI = bt(bp._source)
				if not is(bu, bI) then
					local bJ = bq(bp._source)
					if aa then
						if type(bJ) == "function" then
							ah.error("Mutable source should not return a function as the snapshot value. Functions may close over mutable values and cause tearing.")
						end
					end
					if not is(bz, bJ) then
						by(bJ)
						local bK = aO.requestUpdateLane(bH)
						aA(bs, bK)
					end
					az(bs, bs.mutableReadLanes)
				end
			end, { bq, bp, br })
			bv.useEffect(function()
				local bI = function()
					local bI = bC.getSnapshot
					local bJ = bC.setSnapshot
					local bK, bL = pcall(function()
						bJ(bI(bp._source))
						local bK = aO.requestUpdateLane(bH)
						aA(bs, bK)
					end)
					if not bK then
						bJ(function()
							error(bL)
						end)
					end
				end
				local bJ = br(bp._source, bI)
				if aa then
					if type(bJ) ~= "function" then
						ah.error("Mutable source subscribe function must return an unsubscribe function.")
					end
				end
				return bJ
			end, { bp, br })
			if not is(bD, bq) or not is(bE, bp) or not is(bF, br) then
				local bI =
					{ pending = nil, dispatch = nil, lastRenderedReducer = basicStateReducer, lastRenderedState = bz }
				local bJ = a7
				by = function(...)
					dispatchAction(bJ, bI, ...)
				end
				bI.dispatch = by
				bA.queue = bI
				bA.baseQueue = nil
				bz = readFromUnsubcribedMutableSource(bs, bp, bq)
				bA.baseState = bz
				bA.memoizedState = bA.baseState
			end
			return bz
		end
		function mountMutableSource(bo, bp, bq)
			local br = mountWorkInProgressHook()
			br.memoizedState = {
				refs = { getSnapshot = bp, setSnapshot = nil },
				source = bo,
				subscribe = bq,
			}
			return useMutableSource(br, bo, bp, bq)
		end
		function updateMutableSource(bo, bp, bq)
			local br = updateWorkInProgressHook()
			return useMutableSource(br, bo, bp, bq)
		end
		function mountState(bo)
			local bp = mountWorkInProgressHook()
			if type(bo) == "function" then
				local bq = bo
				bo = bq()
			end
			bp.baseState = bo
			bp.memoizedState = bp.baseState
			local bq = {
				pending = nil,
				dispatch = nil,
				lastRenderedReducer = nil,
				lastRenderedState = bo,
			}
			bq.lastRenderedReducer = basicStateReducer
			bp.queue = bq
			local br = a7
			local bs = function(bs, ...)
				dispatchAction(br, bq, bs, ...)
			end
			bq.dispatch = bs
			return bp.memoizedState, bs
		end
		function updateState(bo)
			return updateReducer(basicStateReducer, bo)
		end
		function rerenderState(bo)
			return rerenderReducer(basicStateReducer, bo)
		end
		local function pushEffect(bo, bp, bq, br)
			local bs = { tag = bo, create = bp, destroy = bq, deps = br, next = nil }
			local bt = a7.updateQueue
			if bt == nil then
				bt = { lastEffect = nil }
				a7.updateQueue = bt
				bs.next = bs
				bt.lastEffect = bs
			else
				local bu = bt.lastEffect
				if bu == nil then
					bt.lastEffect = bs
					bs.next = bs
				else
					local bv = bu.next
					bu.next = bs
					bs.next = bv
					bt.lastEffect = bs
				end
			end
			return bs
		end
		function mountBinding(bo)
			local bp = mountWorkInProgressHook()
			local bq, br = ag(bo)
			bp.memoizedState = { bq, br }
			return bq, br
		end
		function updateBinding(bo)
			local bp = updateWorkInProgressHook()
			return unpack(bp.memoizedState)
		end
		function mountRef(bo)
			local bp = mountWorkInProgressHook()
			local bq = af()
			bq.current = bo
			bp.memoizedState = bq
			return bq
		end
		function updateRef(bo)
			local bp = updateWorkInProgressHook()
			return bp.memoizedState
		end
		local function mountEffectImpl(bo, bp, bq, br)
			local bs = mountWorkInProgressHook()
			local bt = br
			a7.flags = bit32.bor(a7.flags, bo)
			bs.memoizedState = pushEffect(bit32.bor(aK, bp), bq, nil, bt)
		end
		function updateEffectImpl(bo, bp, bq, br)
			local bs = updateWorkInProgressHook()
			local bt = br
			local bu
			if a8 ~= nil then
				local bv = a8.memoizedState
				bu = bv.destroy
				if bt ~= nil then
					local bw = bv.deps
					if areHookInputsEqual(bt, bw) then
						bs.memoizedState = pushEffect(bp, bq, bu, bt)
						return
					end
				end
			end
			a7.flags = bit32.bor(a7.flags, bo)
			bs.memoizedState = pushEffect(bit32.bor(aK, bp), bq, bu, bt)
		end
		local function mountEffect(bo, bp)
			if aa then
				if type(_G.jest) ~= "nil" or _G.__TESTEZ_RUNNING_TEST__ then
					aO.warnIfNotCurrentlyActingEffectsInDEV(a7)
				end
			end
			if aa and ar then
				mountEffectImpl(bit32.bor(aJ, aG, aH), aM, bo, bp)
			else
				mountEffectImpl(bit32.bor(aG, aH), aM, bo, bp)
			end
		end
		local function updateEffect(bo, bp)
			if aa then
				if type(_G.jest) ~= "nil" or _G.__TESTEZ_RUNNING_TEST__ then
					aO.warnIfNotCurrentlyActingEffectsInDEV(a7)
				end
			end
			updateEffectImpl(aG, aM, bo, bp)
		end
		local function mountLayoutEffect(bo, bp)
			if aa and ar then
				mountEffectImpl(bit32.bor(aI, aF), aL, bo, bp)
			else
				mountEffectImpl(aF, aL, bo, bp)
			end
		end
		local function updateLayoutEffect(bo, bp)
			updateEffectImpl(aF, aL, bo, bp)
		end
		function imperativeHandleEffect(bo, bp)
			if bp ~= nil and type(bp) == "function" then
				local bq = bp
				local br = bo()
				bq(br)
				return function()
					return bq(nil)
				end
			elseif bp ~= nil then
				local bq = bp
				if aa then
					local br = getmetatable(bq) ~= nil and #ae.keys(bq) == 0
					if not br then
						ah.error(
							"Expected useImperativeHandle() first argument to either be a ref callback or React.createRef() object. Instead received: %s.",
							"an object with keys {" .. ac.join(ae.keys(bq), ", ") .. "}"
						)
					end
				end
				local br = bo()
				bq.current = br
				return function()
					bq.current = nil
				end
			else
				return nil
			end
		end
		function mountImperativeHandle(bo, bp, bq)
			if aa then
				if type(bp) ~= "function" then
					ah.error(
						"Expected useImperativeHandle() second argument to be a function that creates a handle. Instead received: %s.",
						if bp ~= nil then type(bp) else "nil"
					)
				end
			end
			local br = if bq ~= nil then ac.concat(bq, { bo }) else nil
			if aa and ar then
				return mountEffectImpl(bit32.bor(aI, aF), aL, function()
					return imperativeHandleEffect(bp, bo)
				end, br)
			else
				return mountEffectImpl(aF, aL, function()
					return imperativeHandleEffect(bp, bo)
				end, br)
			end
		end
		function updateImperativeHandle(bo, bp, bq)
			if aa then
				if type(bp) ~= "function" then
					local br = "nil"
					if bp then
						br = type(bp)
					end
					ah.error(
						"Expected useImperativeHandle() second argument to be a function that creates a handle. Instead received: %s.",
						br
					)
				end
			end
			local br
			if bq ~= nil then
				br = table.clone(bq)
				table.insert(br, bo)
			end
			return updateEffectImpl(aF, aL, function()
				return imperativeHandleEffect(bp, bo)
			end, br)
		end
		function mountDebugValue(bo, bp) end
		local bo = mountDebugValue
		function mountCallback(bp, bq)
			local br = mountWorkInProgressHook()
			local bs = bq
			br.memoizedState = { bp, bs }
			return bp
		end
		function updateCallback(bp, bq)
			local br = updateWorkInProgressHook()
			local bs = bq
			local bt = br.memoizedState
			if bt ~= nil then
				if bs ~= nil then
					local bu = bt[2]
					if areHookInputsEqual(bs, bu) then
						return bt[1]
					end
				end
			end
			br.memoizedState = { bp, bs }
			return bp
		end
		function mountMemo(bp, bq)
			local br = mountWorkInProgressHook()
			local bs = bq
			local bt = { bp() }
			br.memoizedState = { bt, bs }
			return unpack(bt)
		end
		function updateMemo(bp, bq)
			local br = updateWorkInProgressHook()
			local bs = bq
			local bt = br.memoizedState
			if bt ~= nil then
				if bs ~= nil then
					local bu = bt[2]
					if areHookInputsEqual(bs, bu) then
						return unpack(bt[1])
					end
				end
			end
			local bu = { bp() }
			br.memoizedState = { bu, bs }
			return unpack(bu)
		end
		local bp = false
		a5.getIsUpdatingOpaqueValueInRenderPhaseInDEV = function()
			if aa then
				return bp
			end
			return nil
		end
		function mountOpaqueIdentifier()
			local bq
			if aa then
				ah.warn("!!! unimplemented: warnOnOpaqueIdentifierAccessInDEV")
			else
				bq = aV.makeClientId
			end
			if aU() then
				unimplemented("ReactFiberHooks: getIsHydrating() true")
				return nil
			else
				local br = bq()
				mountState(br)
				return br
			end
		end
		function updateOpaqueIdentifier()
			local bq, br = updateState(nil)
			return bq
		end
		function rerenderOpaqueIdentifier()
			local bq, br = rerenderState(nil)
			return bq
		end
		function dispatchAction(bq, br, bs, ...)
			if aa then
				local bt = select("#", ...)
				local bu
				if bt == 1 then
					bu = select(1, ...)
				end
				if type(bu) == "function" then
					ah.error("State updates from the useState() and useReducer() Hooks don't support the second callback argument. To execute a side effect after rendering, declare it in the component body with useEffect().")
				end
			end
			local bt = aO.requestEventTime()
			local bu = aO.requestUpdateLane(bq)
			local bv = { lane = bu, action = bs, eagerReducer = nil, eagerState = nil, next = nil }
			local bw = br.pending
			if bw == nil then
				bv.next = bv
			else
				bv.next = bw.next
				bw.next = bv
			end
			br.pending = bv
			local by = bq.alternate
			if bq == a7 or (by ~= nil and by == a7) then
				b = true
				ba = true
			else
				if bq.lanes == av and (by == nil or by.lanes == av) then
					local bz = br.lastRenderedReducer
					if bz ~= nil then
						local bA
						if aa then
							bA = a2.current
							a2.current = bl
						end
						local bB = br.lastRenderedState
						local bC, bD = pcall(bz, bB, bs)
						if bC then
							bv.eagerReducer = bz
							bv.eagerState = bD
						end
						if aa then
							a2.current = bA
						end
						if is(bD, bB) then
							return
						end
						if not bC then
						end
					end
				end
				if aa then
					if type(_G.jest) ~= "nil" or _G.__TESTEZ_RUNNING_TEST__ then
						aO.warnIfNotScopedWithMatchingAct(bq)
						aO.warnIfNotCurrentlyActingUpdatesInDEV(bq)
					end
				end
				aO.scheduleUpdateOnFiber(bq, bu, bt)
			end
			if aa then
				if ao then
					if bit32.band(bq.mode, as) ~= 0 then
						local bz = aQ(bq.type) or "Unknown"
						a0(bz, bu, bs)
					end
				end
			end
			if ap then
				a1(bq, bu)
			end
			return
		end
		local bq = {
			readContext = aD,
			useCallback = throwInvalidHookError,
			useContext = throwInvalidHookError,
			useEffect = throwInvalidHookError,
			useImperativeHandle = throwInvalidHookError,
			useLayoutEffect = throwInvalidHookError,
			useMemo = throwInvalidHookError,
			useReducer = throwInvalidHookError,
			useRef = throwInvalidHookError,
			useBinding = throwInvalidHookError,
			useState = throwInvalidHookError,
			useDebugValue = throwInvalidHookError,
			useMutableSource = throwInvalidHookError,
			useOpaqueIdentifier = throwInvalidHookError,
			unstable_isNewReconciler = aq,
		}
		a5.ContextOnlyDispatcher = bq
		local br = {
			readContext = aD,
			useCallback = mountCallback,
			useContext = aD,
			useEffect = mountEffect,
			useImperativeHandle = mountImperativeHandle,
			useLayoutEffect = mountLayoutEffect,
			useMemo = mountMemo,
			useReducer = mountReducer,
			useRef = mountRef,
			useBinding = mountBinding,
			useState = mountState,
			useDebugValue = mountDebugValue,
			useMutableSource = mountMutableSource,
			useOpaqueIdentifier = mountOpaqueIdentifier,
			unstable_isNewReconciler = aq,
		}
		local bs = {
			readContext = aD,
			useCallback = updateCallback,
			useContext = aD,
			useEffect = updateEffect,
			useImperativeHandle = updateImperativeHandle,
			useLayoutEffect = updateLayoutEffect,
			useMemo = updateMemo,
			useReducer = updateReducer,
			useRef = updateRef,
			useBinding = updateBinding,
			useState = updateState,
			useDebugValue = bo,
			useMutableSource = updateMutableSource,
			useOpaqueIdentifier = updateOpaqueIdentifier,
			unstable_isNewReconciler = aq,
		}
		local bt = {
			readContext = aD,
			useCallback = updateCallback,
			useContext = aD,
			useEffect = updateEffect,
			useImperativeHandle = updateImperativeHandle,
			useLayoutEffect = updateLayoutEffect,
			useMemo = updateMemo,
			useReducer = rerenderReducer,
			useRef = updateRef,
			useBinding = updateBinding,
			useState = rerenderState,
			useDebugValue = bo,
			useMutableSource = updateMutableSource,
			useOpaqueIdentifier = rerenderOpaqueIdentifier,
			unstable_isNewReconciler = aq,
		}
		if aa then
			local bu = function()
				ah.error("Context can only be read while React is rendering. In classes, you can read it in the render method or getDerivedStateFromProps. In function components, you can read it directly in the function body, but not inside Hooks like useReducer() or useMemo().")
			end
			local bv = function()
				ah.error("Do not call Hooks inside useEffect(...), useMemo(...), or other built-in Hooks. You can only call Hooks at the top level of your React function. For more information, see https://reactjs.org/link/rules-of-hooks")
			end
			bg = {
				readContext = function(bw, by)
					return aD(bw, by)
				end,
				useCallback = function(bw, by)
					bc = "useCallback"
					mountHookTypesDev()
					checkDepsAreArrayDev(by)
					return mountCallback(bw, by)
				end,
				useContext = function(bw, by)
					bc = "useContext"
					mountHookTypesDev()
					return aD(bw, by)
				end,
				useEffect = function(bw, by)
					bc = "useEffect"
					mountHookTypesDev()
					checkDepsAreArrayDev(by)
					return mountEffect(bw, by)
				end,
				useImperativeHandle = function(bw, by, bz)
					bc = "useImperativeHandle"
					mountHookTypesDev()
					checkDepsAreArrayDev(bz)
					return mountImperativeHandle(bw, by, bz)
				end,
				useLayoutEffect = function(bw, by)
					bc = "useLayoutEffect"
					mountHookTypesDev()
					checkDepsAreArrayDev(by)
					return mountLayoutEffect(bw, by)
				end,
				useMemo = function(bw, by)
					bc = "useMemo"
					mountHookTypesDev()
					checkDepsAreArrayDev(by)
					local bz = a2.current
					a2.current = bk
					local bA = { pcall(mountMemo, bw, by) }
					a2.current = bz
					if not bA[1] then
						error(bA[2])
					end
					return unpack(bA, 2)
				end,
				useReducer = function(bw, by, bz)
					bc = "useReducer"
					mountHookTypesDev()
					local bA = a2.current
					a2.current = bk
					local bB, bC, bD = pcall(mountReducer, bw, by, bz)
					a2.current = bA
					if not bB then
						error(bC)
					end
					return bC, bD
				end,
				useRef = function(bw)
					bc = "useRef"
					mountHookTypesDev()
					return mountRef(bw)
				end,
				useBinding = function(bw)
					bc = "useBinding"
					mountHookTypesDev()
					return mountBinding(bw)
				end,
				useState = function(bw)
					bc = "useState"
					mountHookTypesDev()
					local by = a2.current
					a2.current = bk
					local bz, bA, bB = pcall(mountState, bw)
					a2.current = by
					if not bz then
						error(bA)
					end
					return bA, bB
				end,
				useDebugValue = function(bw, by)
					bc = "useDebugValue"
					mountHookTypesDev()
					return mountDebugValue(bw, by)
				end,
				useMutableSource = function(bw, by, bz)
					bc = "useMutableSource"
					mountHookTypesDev()
					return mountMutableSource(bw, by, bz)
				end,
				useOpaqueIdentifier = function()
					bc = "useOpaqueIdentifier"
					mountHookTypesDev()
					return mountOpaqueIdentifier()
				end,
				unstable_isNewReconciler = aq,
			}
			bh = {
				readContext = function(bw, by)
					return aD(bw, by)
				end,
				useCallback = function(bw, by)
					bc = "useCallback"
					updateHookTypesDev()
					checkDepsAreArrayDev(by)
					return mountCallback(bw, by)
				end,
				useContext = function(bw, by)
					bc = "useContext"
					updateHookTypesDev()
					return aD(bw, by)
				end,
				useEffect = function(bw, by)
					bc = "useEffect"
					updateHookTypesDev()
					return mountEffect(bw, by)
				end,
				useImperativeHandle = function(bw, by, bz)
					bc = "useImperativeHandle"
					updateHookTypesDev()
					return mountImperativeHandle(bw, by, bz)
				end,
				useLayoutEffect = function(bw, by)
					bc = "useLayoutEffect"
					updateHookTypesDev()
					return mountLayoutEffect(bw, by)
				end,
				useMemo = function(bw, by)
					bc = "useMemo"
					updateHookTypesDev()
					local bz = a2.current
					a2.current = bk
					local bA = { pcall(mountMemo, bw, by) }
					a2.current = bz
					if not bA[1] then
						error(bA[2])
					end
					return unpack(bA, 2)
				end,
				useReducer = function(bw, by, bz)
					bc = "useReducer"
					updateHookTypesDev()
					local bA = a2.current
					a2.current = bk
					local bB, bC, bD = pcall(mountReducer, bw, by, bz)
					a2.current = bA
					if not bB then
						error(bC)
					end
					return bC, bD
				end,
				useRef = function(bw)
					bc = "useRef"
					updateHookTypesDev()
					return mountRef(bw)
				end,
				useBinding = function(bw)
					bc = "useBinding"
					updateHookTypesDev()
					return mountBinding(bw)
				end,
				useState = function(bw)
					bc = "useState"
					updateHookTypesDev()
					local by = a2.current
					a2.current = bk
					local bz, bA, bB = pcall(mountState, bw)
					a2.current = by
					if not bz then
						error(bA)
					end
					return bA, bB
				end,
				useDebugValue = function(bw, by)
					bc = "useDebugValue"
					updateHookTypesDev()
					return mountDebugValue(bw, by)
				end,
				useMutableSource = function(bw, by, bz)
					bc = "useMutableSource"
					updateHookTypesDev()
					return mountMutableSource(bw, by, bz)
				end,
				useOpaqueIdentifier = function()
					bc = "useOpaqueIdentifier"
					updateHookTypesDev()
					return mountOpaqueIdentifier()
				end,
				unstable_isNewReconciler = aq,
			}
			bi = {
				readContext = function(bw, by)
					return aD(bw, by)
				end,
				useCallback = function(bw, by)
					bc = "useCallback"
					updateHookTypesDev()
					return updateCallback(bw, by)
				end,
				useContext = function(bw, by)
					bc = "useContext"
					updateHookTypesDev()
					return aD(bw, by)
				end,
				useEffect = function(bw, by)
					bc = "useEffect"
					updateHookTypesDev()
					return updateEffect(bw, by)
				end,
				useImperativeHandle = function(bw, by, bz)
					bc = "useImperativeHandle"
					updateHookTypesDev()
					return updateImperativeHandle(bw, by, bz)
				end,
				useLayoutEffect = function(bw, by)
					bc = "useLayoutEffect"
					updateHookTypesDev()
					return updateLayoutEffect(bw, by)
				end,
				useMemo = function(bw, by)
					bc = "useMemo"
					updateHookTypesDev()
					local bz = a2.current
					a2.current = bl
					local bA = { pcall(updateMemo, bw, by) }
					a2.current = bz
					if not bA[1] then
						error(bA[2])
					end
					return unpack(bA, 2)
				end,
				useReducer = function(bw, by, bz)
					bc = "useReducer"
					updateHookTypesDev()
					local bA = a2.current
					a2.current = bl
					local bB, bC, bD = pcall(updateReducer, bw, by, bz)
					a2.current = bA
					if not bB then
						error(bC)
					end
					return bC, bD
				end,
				useRef = function(bw)
					bc = "useRef"
					updateHookTypesDev()
					return updateRef(bw)
				end,
				useBinding = function(bw)
					bc = "useBinding"
					updateHookTypesDev()
					return updateBinding(bw)
				end,
				useState = function(bw)
					bc = "useState"
					updateHookTypesDev()
					local by = a2.current
					a2.current = bl
					local bz, bA, bB = pcall(updateState, bw)
					a2.current = by
					if not bz then
						error(bA)
					end
					return bA, bB
				end,
				useDebugValue = function(bw, by)
					bc = "useDebugValue"
					updateHookTypesDev()
					return bo(bw, by)
				end,
				useMutableSource = function(bw, by, bz)
					bc = "useMutableSource"
					updateHookTypesDev()
					return updateMutableSource(bw, by, bz)
				end,
				useOpaqueIdentifier = function()
					bc = "useOpaqueIdentifier"
					updateHookTypesDev()
					return updateOpaqueIdentifier()
				end,
				unstable_isNewReconciler = aq,
			}
			bj = {
				readContext = function(bw, by)
					return aD(bw, by)
				end,
				useCallback = function(bw, by)
					bc = "useCallback"
					updateHookTypesDev()
					return mountCallback(bw, by)
				end,
				useContext = function(bw, by)
					bc = "useContext"
					updateHookTypesDev()
					return aD(bw, by)
				end,
				useEffect = function(bw, by)
					bc = "useEffect"
					updateHookTypesDev()
					return updateEffect(bw, by)
				end,
				useImperativeHandle = function(bw, by, bz)
					bc = "useImperativeHandle"
					updateHookTypesDev()
					return updateImperativeHandle(bw, by, bz)
				end,
				useLayoutEffect = function(bw, by)
					bc = "useLayoutEffect"
					updateHookTypesDev()
					return updateLayoutEffect(bw, by)
				end,
				useMemo = function(bw, by)
					bc = "useMemo"
					updateHookTypesDev()
					local bz = a2.current
					a2.current = bm
					local bA = { pcall(updateMemo, bw, by) }
					a2.current = bz
					if not bA[1] then
						error(bA[2])
					end
					return unpack(bA, 2)
				end,
				useReducer = function(bw, by, bz)
					bc = "useReducer"
					updateHookTypesDev()
					local bA = a2.current
					a2.current = bm
					local bB, bC, bD = pcall(rerenderReducer, bw, by, bz)
					a2.current = bA
					if not bB then
						error(bC)
					end
					return bC, bD
				end,
				useRef = function(bw)
					bc = "useRef"
					updateHookTypesDev()
					return updateRef(bw)
				end,
				useBinding = function(bw)
					bc = "useBinding"
					updateHookTypesDev()
					return updateBinding(bw)
				end,
				useState = function(bw)
					bc = "useState"
					updateHookTypesDev()
					local by = a2.current
					a2.current = bm
					local bz, bA, bB = pcall(rerenderState, bw)
					a2.current = by
					if not bz then
						error(bA)
					end
					return bA, bB
				end,
				useDebugValue = function(bw, by)
					bc = "useDebugValue"
					updateHookTypesDev()
					return bo(bw, by)
				end,
				useMutableSource = function(bw, by, bz)
					bc = "useMutableSource"
					updateHookTypesDev()
					return updateMutableSource(bw, by, bz)
				end,
				useOpaqueIdentifier = function()
					bc = "useOpaqueIdentifier"
					updateHookTypesDev()
					return rerenderOpaqueIdentifier()
				end,
				unstable_isNewReconciler = aq,
			}
			bk = {
				readContext = function(bw, by)
					bu()
					return aD(bw, by)
				end,
				useCallback = function(bw, by)
					bc = "useCallback"
					bv()
					mountHookTypesDev()
					return mountCallback(bw, by)
				end,
				useContext = function(bw, by)
					bc = "useContext"
					bv()
					mountHookTypesDev()
					return aD(bw, by)
				end,
				useEffect = function(bw, by)
					bc = "useEffect"
					bv()
					mountHookTypesDev()
					return mountEffect(bw, by)
				end,
				useImperativeHandle = function(bw, by, bz)
					bc = "useImperativeHandle"
					bv()
					mountHookTypesDev()
					return mountImperativeHandle(bw, by, bz)
				end,
				useLayoutEffect = function(bw, by)
					bc = "useLayoutEffect"
					bv()
					mountHookTypesDev()
					return mountLayoutEffect(bw, by)
				end,
				useMemo = function(bw, by)
					bc = "useMemo"
					bv()
					mountHookTypesDev()
					local bz = a2.current
					a2.current = bk
					local bA = { pcall(mountMemo, bw, by) }
					a2.current = bz
					if not bA[1] then
						error(bA[2])
					end
					return unpack(bA, 2)
				end,
				useReducer = function(bw, by, bz)
					bc = "useReducer"
					bv()
					mountHookTypesDev()
					local bA = a2.current
					a2.current = bk
					local bB, bC, bD = pcall(mountReducer, bw, by, bz)
					a2.current = bA
					if not bB then
						error(bC)
					end
					return bC, bD
				end,
				useRef = function(bw)
					bc = "useRef"
					bv()
					mountHookTypesDev()
					return mountRef(bw)
				end,
				useBinding = function(bw)
					bc = "useBinding"
					bv()
					mountHookTypesDev()
					return mountBinding(bw)
				end,
				useState = function(bw)
					bc = "useState"
					bv()
					mountHookTypesDev()
					local by = a2.current
					a2.current = bk
					local bz, bA, bB = pcall(mountState, bw)
					a2.current = by
					if not bz then
						error(bA)
					end
					return bA, bB
				end,
				useDebugValue = function(bw, by)
					bc = "useDebugValue"
					bv()
					mountHookTypesDev()
					return mountDebugValue(bw, by)
				end,
				useMutableSource = function(bw, by, bz)
					bc = "useMutableSource"
					bv()
					mountHookTypesDev()
					return mountMutableSource(bw, by, bz)
				end,
				useOpaqueIdentifier = function()
					bc = "useOpaqueIdentifier"
					bv()
					mountHookTypesDev()
					return mountOpaqueIdentifier()
				end,
				unstable_isNewReconciler = aq,
			}
			bl = {
				readContext = function(bw, by)
					bu()
					return aD(bw, by)
				end,
				useCallback = function(bw, by)
					bc = "useCallback"
					bv()
					updateHookTypesDev()
					return mountCallback(bw, by)
				end,
				useContext = function(bw, by)
					bc = "useContext"
					bv()
					updateHookTypesDev()
					return aD(bw, by)
				end,
				useEffect = function(bw, by)
					bc = "useEffect"
					bv()
					updateHookTypesDev()
					return updateEffect(bw, by)
				end,
				useImperativeHandle = function(bw, by, bz)
					bc = "useImperativeHandle"
					bv()
					updateHookTypesDev()
					return updateImperativeHandle(bw, by, bz)
				end,
				useLayoutEffect = function(bw, by)
					bc = "useLayoutEffect"
					bv()
					updateHookTypesDev()
					return updateLayoutEffect(bw, by)
				end,
				useMemo = function(bw, by)
					bc = "useMemo"
					bv()
					updateHookTypesDev()
					local bz = a2.current
					a2.current = bl
					local bA = {
						pcall(updateMemo, bw, by),
					}
					a2.current = bz
					if not bA[1] then
						error(bA[2])
					end
					return unpack(bA, 2)
				end,
				useReducer = function(bw, by, bz)
					bc = "useReducer"
					bv()
					updateHookTypesDev()
					local bA = a2.current
					a2.current = bl
					local bB, bC, bD = pcall(updateReducer, bw, by, bz)
					a2.current = bA
					if not bB then
						error(bC)
					end
					return bC, bD
				end,
				useRef = function(bw)
					bc = "useRef"
					bv()
					updateHookTypesDev()
					return updateRef(bw)
				end,
				useBinding = function(bw)
					bc = "useBinding"
					bv()
					updateHookTypesDev()
					return updateBinding(bw)
				end,
				useState = function(bw)
					bc = "useState"
					bv()
					updateHookTypesDev()
					local by = a2.current
					a2.current = bl
					local bz, bA, bB = pcall(updateState, bw)
					a2.current = by
					if not bz then
						error(bA)
					end
					return bA, bB
				end,
				useDebugValue = function(bw, by)
					bc = "useDebugValue"
					bv()
					updateHookTypesDev()
					return bo(bw, by)
				end,
				useMutableSource = function(bw, by, bz)
					bc = "useMutableSource"
					bv()
					updateHookTypesDev()
					return updateMutableSource(bw, by, bz)
				end,
				useOpaqueIdentifier = function()
					bc = "useOpaqueIdentifier"
					bv()
					updateHookTypesDev()
					return updateOpaqueIdentifier()
				end,
				unstable_isNewReconciler = aq,
			}
			bm = {
				readContext = function(bw, by)
					bu()
					return aD(bw, by)
				end,
				useCallback = function(bw, by)
					bc = "useCallback"
					bv()
					updateHookTypesDev()
					return updateCallback(bw, by)
				end,
				useContext = function(bw, by)
					bc = "useContext"
					bv()
					updateHookTypesDev()
					return aD(bw, by)
				end,
				useEffect = function(bw, by)
					bc = "useEffect"
					bv()
					updateHookTypesDev()
					return updateEffect(bw, by)
				end,
				useImperativeHandle = function(bw, by, bz)
					bc = "useImperativeHandle"
					bv()
					updateHookTypesDev()
					return updateImperativeHandle(bw, by, bz)
				end,
				useLayoutEffect = function(bw, by)
					bc = "useLayoutEffect"
					bv()
					updateHookTypesDev()
					return updateLayoutEffect(bw, by)
				end,
				useMemo = function(bw, by)
					bc = "useMemo"
					bv()
					updateHookTypesDev()
					local bz = a2.current
					a2.current = bl
					local bA = { pcall(updateMemo, bw, by) }
					a2.current = bz
					if not bA[1] then
						error(bA[2])
					end
					return unpack(bA, 2)
				end,
				useReducer = function(bw, by, bz)
					bc = "useReducer"
					bv()
					updateHookTypesDev()
					local bA = a2.current
					a2.current = bl
					local bB, bC, bD = pcall(rerenderReducer, bw, by, bz)
					a2.current = bA
					if not bB then
						error(bC)
					end
					return bC, bD
				end,
				useRef = function(bw)
					bc = "useRef"
					bv()
					updateHookTypesDev()
					return updateRef(bw)
				end,
				useBinding = function(bw)
					bc = "useBinding"
					bv()
					updateHookTypesDev()
					return updateBinding(bw)
				end,
				useState = function(bw)
					bc = "useState"
					bv()
					updateHookTypesDev()
					local by = a2.current
					a2.current = bl
					local bz, bA, bB = pcall(rerenderState, bw)
					a2.current = by
					if not bz then
						error(bA)
					end
					return bA, bB
				end,
				useDebugValue = function(bw, by)
					bc = "useDebugValue"
					bv()
					updateHookTypesDev()
					return bo(bw, by)
				end,
				useMutableSource = function(bw, by, bz)
					bc = "useMutableSource"
					bv()
					updateHookTypesDev()
					return updateMutableSource(bw, by, bz)
				end,
				useOpaqueIdentifier = function()
					bc = "useOpaqueIdentifier"
					bv()
					updateHookTypesDev()
					return rerenderOpaqueIdentifier()
				end,
				unstable_isNewReconciler = aq,
			}
		end
		local function renderWithHooks(bu, bv, bw, by, bz, bA)
			a6 = bA
			a7 = bv
			if aa then
				bd = if bu ~= nil then bu._debugHookTypes else nil
				be = 0
			end
			bv.memoizedState = nil
			bv.updateQueue = nil
			bv.lanes = av
			if aa then
				if bu ~= nil and bu.memoizedState ~= nil then
					a2.current = bi
				elseif bd ~= nil then
					a2.current = bh
				else
					a2.current = bg
				end
			else
				a2.current = (bu == nil or bu.memoizedState == nil) and br or bs
			end
			local bB = bw(by, bz)
			if ba then
				local bC = 0
				repeat
					ba = false
					if bC >= bb then
						error(
							ad.new("Too many re-renders. React limits the number of renders to prevent an infinite loop.")
						)
					end
					bC += 1
					a8 = nil
					a9 = nil
					bv.updateQueue = nil
					if aa then
						be = 0
					end
					a2.current = aa and bj or bt
					bB = bw(by, bz)
				until not ba
			end
			a2.current = bq
			if aa then
				bv._debugHookTypes = bd
			end
			local bC = a8 ~= nil and a8.next ~= nil
			a6 = av
			a7 = nil
			a8 = nil
			a9 = nil
			if aa then
				bc = nil
				bd = nil
				be = 0
			end
			b = false
			if bC then
				error(
					ad.new("Rendered fewer hooks than expected. This may be caused by an accidental early return statement.")
				)
			end
			return bB
		end
		a5.renderWithHooks = renderWithHooks
		local bu = a.load("cl")
		local bv = a5
		bu.register("ReactFiberHooks", bv)
		return bv
	end
	function a.c3()
		local aa = a.load("b_")
		local ab = a.load("ck")
		local ac = {}
		local ad = {}
		ac.onCommitRoot = function()
			if ab.supportsTestSelectors then
				for ae, af in ad do
					af()
				end
			end
		end
		return ac
	end
	function a.c4()
		local aa = _G.__DEV__
		local ab = _G.__YOLO__
		local ac = a.load("b0").console
		local ad = a.load("b_")
		local ae = ad.Set
		local af = {}
		local ag = a.load("b0")
		local ah = a.load("cj")
		local ai = a.load("cn")
		local aj = a.load("ci")
		local ak = a.load("co")
		local al = a.load("cq")
		local am = a.load("b0").ReactFeatureFlags
		local an = am.enableDebugTracing
		local ao = am.enableSchedulingProfiler
		local ap = am.skipUnmountedBoundaries
		local aq = am.enableDoubleInvokingEffects
		local ar = a.load("b0")
		local as = a.load("b0").describeError
		local au = ar.ReactSharedInternals
		local av = ar.invariant
		local aw = a.load("cz")
		local ax = aw.scheduleCallback
		local ay = aw.cancelCallback
		local az = aw.getCurrentPriorityLevel
		local aA = aw.runWithPriority
		local aC = aw.shouldYield
		local aD = aw.requestPaint
		local aE = aw.now
		local aF = aw.NoPriority
		local aG = aw.ImmediatePriority
		local aH = aw.UserBlockingPriority
		local aI = aw.NormalPriority
		local aJ = aw.flushSyncCallbackQueue
		local aK = aw.scheduleSyncCallback
		local aL = a.load("cA")
		local aM = a.load("cB")
		local aO = a.load("ci").tracing
		local aP, aQ = aO.__interactionsRef, aO.__subscriberRef
		local aS = a.load("ck")
		local aT = a.load("cv")
		local aU = a.load("b2")
		local aV = a.load("b1")
		local aW = a.load("b4").LegacyRoot
		local aX = a.load("b3")
		local aY = ai.pickArbitraryLane
		local aZ = ai.hasDiscreteLanes
		local a_ = ai.includesNonIdleWork
		local a0 = ai.includesOnlyRetries
		local a1 = ai.includesOnlyTransitions
		local a2 = ai.getNextLanes
		local a3 = ai.returnNextLanesPriority
		local a4 = ai.setCurrentUpdateLanePriority
		local a6 = ai.getCurrentUpdateLanePriority
		local a7 = ai.markStarvedLanesAsExpired
		local a8 = ai.getLanesToRetrySynchronouslyOnError
		local a9 = ai.getMostRecentEventTime
		local b = ai.markRootUpdated
		local ba = ai.markRootSuspended
		local bb = ai.markRootPinged
		local bc = ai.markRootExpired
		local bd = ai.markDiscreteUpdatesExpired
		local be = ai.markRootFinished
		local bf = ai.schedulerPriorityToLanePriority
		local bg = ai.lanePriorityToSchedulerPriority
		local bh = a.load("cC")
		local bi = (a.load("cK"))
		local bj = bi.unwindWork
		local bk = bi.unwindInterruptedWork
		local bl = (a.load("cP"))
		local bm = bl.throwException
		local bn = bl.createRootErrorUpdate
		local bo = bl.createClassErrorUpdate
		local bp = a.load("cT")
		local bq = bp.commitBeforeMutationLifeCycles
		local br = bp.commitPlacement
		local bs = bp.commitWork
		local bt = bp.commitDeletion
		local bu = bp.commitPassiveUnmount
		local bv = bp.commitPassiveUnmountInsideDeletedTree
		local bw = bp.commitPassiveMount
		local by = bp.commitDetachRef
		local bz = bp.invokeLayoutEffectMountInDEV
		local bA = bp.invokePassiveEffectMountInDEV
		local bB = bp.invokeLayoutEffectUnmountInDEV
		local bC = bp.invokePassiveEffectUnmountInDEV
		local bD = bp.recursivelyCommitLayoutEffects
		local bE = a.load("cV")
		local bF = a.load("cx").enqueueUpdate
		local bH = a.load("cI").resetContextDependencies
		local bI = a.load("cW")
		local bJ
		local bK = {
			resetHooksAfterThrowRef = nil,
			ContextOnlyDispatcherRef = nil,
			getIsUpdatingOpaqueValueInRenderPhaseInDEVRef = nil,
			originalBeginWorkRef = nil,
			completeWorkRef = nil,
		}
		local bL = function(bL, bM, bN)
			if not bK.originalBeginWorkRef then
				bK.originalBeginWorkRef = a.load("c0").beginWork
			end
			return bK.originalBeginWorkRef(bL, bM, bN)
		end
		local bM = function(bM, bN, bO)
			if not bK.completeWorkRef then
				bK.completeWorkRef = a.load("c1").completeWork
			end
			return (bK.completeWorkRef)(bM, bN, bO)
		end
		local bN
		local function initReactFiberHooks()
			bN = a.load("c2")
			bK.resetHooksAfterThrowRef = bN.resetHooksAfterThrow
			bK.ContextOnlyDispatcherRef = bN.ContextOnlyDispatcher
			bK.getIsUpdatingOpaqueValueInRenderPhaseInDEVRef = bN.getIsUpdatingOpaqueValueInRenderPhaseInDEV
		end
		local bO = function()
			if not bK.resetHooksAfterThrowRef then
				initReactFiberHooks()
			end
			return bK.resetHooksAfterThrowRef()
		end
		local bP = function()
			if not bK.ContextOnlyDispatcherRef then
				initReactFiberHooks()
			end
			return bK.ContextOnlyDispatcherRef
		end
		local bQ = function()
			if not bK.getIsUpdatingOpaqueValueInRenderPhaseInDEVRef then
				initReactFiberHooks()
			end
			return bK.getIsUpdatingOpaqueValueInRenderPhaseInDEVRef()
		end
		local bR = a.load("cM").createCapturedValue
		local bS = al.push
		local bT = al.pop
		local bU = al.createCursor
		local bV = a.load("cJ")
		local bW = a.load("b0").getComponentName
		local bX = a.load("cY")
		local bY = a.load("cR")
		local bZ = bY.current
		local b_ = bY.resetCurrentFiber
		local b0 = bY.setCurrentFiber
		local b1 = a.load("b0").ReactErrorUtils
		local b2 = b1.invokeGuardedCallback
		local b3 = b1.hasCaughtError
		local b4 = b1.clearCaughtError
		local c = a.load("ct").onCommitRoot
		local d = a.load("c3").onCommitRoot
		local e = a.load("b0").enqueueTask
		local g = a.load("cp").doesFiberContain
		local h = au.ReactCurrentDispatcher
		local i = au.ReactCurrentOwner
		local j = au.IsSomeRendererActing
		local k, l
		local m = {}
		local n = 0b0
		local o = 0b1
		local p = 0b10
		local q = 0b100
		local r = 0b1000
		local s = 0b10000
		local t = 0b100000
		local u = 0b1000000
		af.NoContext = n
		af.RetryAfterError = u
		local v =
			{ Incomplete = 0, FatalErrored = 1, Errored = 2, Suspended = 3, SuspendedWithDelay = 4, Completed = 5 }
		local w = n
		local x
		local y
		local z = ai.NoLanes
		af.subtreeRenderLanes = ai.NoLanes
		local A = bU(ai.NoLanes)
		local B = v.Incomplete
		local C
		local D = ai.NoLanes
		local E = a.load("cw")
		local F = E.workInProgressRootSkippedLanes
		local G = ai.NoLanes
		local H = ai.NoLanes
		local I
		local J = 0
		local K = 500
		local L = math.huge
		local M = 500
		local N
		local function resetRenderTimer()
			L = aE() + M
		end
		af.getRenderTargetTime = function()
			return L
		end
		local O = false
		local P
		local Q
		local R = false
		local S
		local T = aF
		local U = ai.NoLanes
		local V
		local W = 50
		local X = 0
		local Y
		local Z = 50
		local _ = 0
		local b5
		local b6 = ai.NoTimestamp
		local b7 = ai.NoLanes
		local b8 = ai.NoLanes
		local b9
		local ca = false
		af.getWorkInProgressRoot = function()
			return x
		end
		af.requestEventTime = function()
			if bit32.band(w, bit32.bor(s, t)) ~= n then
				return aE()
			end
			if b6 ~= ai.NoTimestamp then
				return b6
			end
			b6 = aE()
			return b6
		end
		af.requestUpdateLane = function(cb)
			local cc = cb.mode
			if bit32.band(cc, aU.BlockingMode) == aU.NoMode then
				return ai.SyncLane
			elseif bit32.band(cc, aU.ConcurrentMode) == aU.NoMode then
				return if az() == aG then ai.SyncLane else ai.SyncBatchedLane
			elseif not am.deferRenderPhaseUpdateToNextBatch and bit32.band(w, s) ~= n and z ~= ai.NoLanes then
				return aY(z)
			end
			if b7 == ai.NoLanes then
				b7 = D
			end
			local cd = bh.requestCurrentTransition() ~= bh.NoTransition
			if cd then
				if b8 ~= ai.NoLanes then
					if I ~= nil then
						b8 = I.pendingLanes
					else
						b8 = ai.NoLanes
					end
				end
				return ai.findTransitionLane(b7, b8)
			end
			local ce = az()
			local cf
			if bit32.band(w, q) ~= n and ce == aH then
				cf = ai.findUpdateLane(ai.InputDiscreteLanePriority, b7)
			else
				local cg = bf(ce)
				if am.decoupleUpdatePriorityFromScheduler then
					local ch = a6()
					if cg ~= ch and ch ~= ai.NoLanePriority then
						if aa then
							ac.error(
								"Expected current scheduler lane priority %s to match current update lane priority %s",
								tostring(cg),
								tostring(ch)
							)
						end
					end
				end
				cf = ai.findUpdateLane(cg, b7)
			end
			return cf
		end
		function requestRetryLane(cb)
			local cc = cb.mode
			if bit32.band(cc, aU.BlockingMode) == aU.NoMode then
				return ai.SyncLane
			elseif bit32.band(cc, aU.ConcurrentMode) == aU.NoMode then
				return if az() == aG then ai.SyncLane else ai.SyncBatchedLane
			end
			if b7 == ai.NoLanes then
				b7 = D
			end
			return ai.findRetryLane(b7)
		end
		af.scheduleUpdateOnFiber = function(cb, cc, cd)
			m.checkForNestedUpdates()
			local ce = m.markUpdateLaneFromFiberToRoot(cb, cc)
			if ce == nil then
				return nil
			end
			b(ce, cc, cd)
			if ce == x then
				m.warnAboutRenderPhaseUpdatesInDEV(cb)
				if am.deferRenderPhaseUpdateToNextBatch or bit32.band(w, s) == n then
					G = ai.mergeLanes(G, cc)
				end
				if B == v.SuspendedWithDelay then
					m.markRootSuspended(ce, z)
				end
			end
			local cf = az()
			if cc == ai.SyncLane then
				if bit32.band(w, r) ~= n and bit32.band(w, bit32.bor(s, t)) == n then
					m.schedulePendingInteractions(ce, cc)
					m.performSyncWorkOnRoot(ce)
				else
					bJ(ce, cd)
					m.schedulePendingInteractions(ce, cc)
					if w == n then
						resetRenderTimer()
						aJ()
					end
				end
			else
				if bit32.band(w, q) ~= n and (cf == aH or cf == aG) then
					if V == nil then
						V = ae.new({ ce })
					else
						V.add(V, ce)
					end
				end
				bJ(ce, cd)
				m.schedulePendingInteractions(ce, cc)
			end
			I = ce
			return ce
		end
		m.markUpdateLaneFromFiberToRoot = function(cb, cc)
			cb.lanes = ai.mergeLanes(cb.lanes, cc)
			local cd = cb.alternate
			if cd ~= nil then
				cd.lanes = ai.mergeLanes(cd.lanes, cc)
			end
			if aa then
				if cd == nil and bit32.band(cb.flags, bit32.bor(aX.Placement, aX.Hydrating)) ~= aX.NoFlags then
					m.warnAboutUpdateOnNotYetMountedFiberInDEV(cb)
				end
			end
			local ce = cb
			local cf = cb.return_
			while cf ~= nil do
				cf.childLanes = ai.mergeLanes(cf.childLanes, cc)
				cd = cf.alternate
				if cd ~= nil then
					cd.childLanes = ai.mergeLanes(cd.childLanes, cc)
				else
					if aa then
						if bit32.band(cf.flags, bit32.bor(aX.Placement, aX.Hydrating)) ~= aX.NoFlags then
							m.warnAboutUpdateOnNotYetMountedFiberInDEV(cb)
						end
					end
				end
				ce = cf
				cf = cf.return_
			end
			if ce.tag == aV.HostRoot then
				local cg = ce.stateNode
				return cg
			else
				return nil
			end
		end
		bJ = function(cb, cc)
			local cd = cb.callbackNode
			a7(cb, cc)
			local ce
			if cb == x then
				ce = z
			else
				ce = ai.NoLanes
			end
			local cf = a2(cb, ce)
			local cg = a3()
			if cf == ai.NoLanes then
				if cd ~= nil then
					ay(cd)
					cb.callbackNode = nil
					cb.callbackPriority = ai.NoLanePriority
				end
				return
			end
			if cd ~= nil then
				local ch = cb.callbackPriority
				if ch == cg then
					return
				end
				ay(cd)
			end
			local ch
			if cg == ai.SyncLanePriority then
				ch = aK(function()
					local ci = bI.profileRootBeforeUnitOfWork(cb)
					local cj = m.performSyncWorkOnRoot(cb)
					bI.profileRootAfterYielding(ci)
					return cj
				end)
			elseif cg == ai.SyncBatchedLanePriority then
				ch = ax(aG, function()
					local ci = bI.profileRootBeforeUnitOfWork(cb)
					local cj = m.performSyncWorkOnRoot(cb)
					bI.profileRootAfterYielding(ci)
					return cj
				end)
			else
				local ci = bg(cg)
				ch = ax(ci, function()
					local cj = bI.profileRootBeforeUnitOfWork(cb)
					local ck = m.performConcurrentWorkOnRoot(cb)
					bI.profileRootAfterYielding(cj)
					return ck
				end)
			end
			cb.callbackPriority = cg
			cb.callbackNode = ch
		end
		m.performConcurrentWorkOnRoot = function(cb)
			b6 = ai.NoTimestamp
			b7 = ai.NoLanes
			b8 = ai.NoLanes
			av(bit32.band(w, bit32.bor(s, t)) == n, "Should not already be working.")
			local cc = cb.callbackNode
			local cd = af.flushPassiveEffects()
			if cd then
				if cb.callbackNode ~= cc then
					return nil
				end
			end
			local ce = a2(cb, if cb == x then z else ai.NoLanes)
			if ce == ai.NoLanes then
				return nil
			end
			local cf = m.renderRootConcurrent(cb, ce)
			if ai.includesSomeLane(D, G) then
				m.prepareFreshStack(cb, ai.NoLanes)
			elseif cf ~= v.Incomplete then
				if cf == v.Errored then
					w = bit32.bor(w, u)
					if cb.hydrate then
						cb.hydrate = false
						aS.clearContainer(cb.containerInfo)
					end
					ce = a8(cb)
					if ce ~= ai.NoLanes then
						cf = m.renderRootSync(cb, ce)
					end
				end
				if cf == v.FatalErrored then
					local cg = C
					m.prepareFreshStack(cb, ai.NoLanes)
					m.markRootSuspended(cb, ce)
					bJ(cb, aE())
					error(cg)
				end
				local cg = cb.current.alternate
				cb.finishedWork = cg
				cb.finishedLanes = ce
				m.finishConcurrentRender(cb, cf, ce)
			end
			bJ(cb, aE())
			if cb.callbackNode == cc then
				return function()
					return m.performConcurrentWorkOnRoot(cb)
				end
			end
			return nil
		end
		local cb = 0
		local cc = false
		function shouldForceFlushFallbacksInDEV()
			return aa and cb > 0
		end
		m.finishConcurrentRender = function(cd, ce, cf)
			if ce == v.Incomplete or ce == v.FatalErrored then
				av(false, "Root did not complete. This is a bug in React.")
			elseif ce == v.Errored then
				m.commitRoot(cd)
			elseif ce == v.Suspended then
				m.markRootSuspended(cd, cf)
				if a0(cf) and not shouldForceFlushFallbacksInDEV() then
					local cg = J + K - aE()
					if cg > 10 then
						local ch = a2(cd, ai.NoLanes)
						if ch ~= ai.NoLanes then
							return
						end
						local ci = cd.suspendedLanes
						if not ai.isSubsetOfLanes(ci, cf) then
							local cj = af.requestEventTime()
							bb(cd, ci, cj)
							return
						end
						cd.timeoutHandle = aS.scheduleTimeout(function()
							return m.commitRoot(cd)
						end, cg)
						return
					end
				end
				m.commitRoot(cd)
			elseif ce == v.SuspendedWithDelay then
				m.markRootSuspended(cd, cf)
				if a1(cf) then
					return
				end
				if not shouldForceFlushFallbacksInDEV() then
					local cg = a9(cd, cf)
					local ch = cg
					local ci = aE() - ch
					local cj = jnd(ci) - ci
					if cj > 10 then
						cd.timeoutHandle = aS.scheduleTimeout(function()
							return m.commitRoot(cd)
						end, cj)
						return
					end
				end
				m.commitRoot(cd)
			elseif ce == v.Completed then
				m.commitRoot(cd)
			else
				av(false, "Unknown root exit status.")
			end
		end
		m.markRootSuspended = function(cd, ce)
			ce = ai.removeLanes(ce, H)
			ce = ai.removeLanes(ce, G)
			ba(cd, ce)
		end
		m.performSyncWorkOnRoot = function(cd)
			av(bit32.band(w, bit32.bor(s, t)) == n, "Should not already be working.")
			af.flushPassiveEffects()
			local ce
			local cf
			if cd == x and ai.includesSomeLane(cd.expiredLanes, z) then
				ce = z
				cf = m.renderRootSync(cd, ce)
				if ai.includesSomeLane(D, G) then
					ce = a2(cd, ce)
					cf = m.renderRootSync(cd, ce)
				end
			else
				ce = a2(cd, ai.NoLanes)
				cf = m.renderRootSync(cd, ce)
			end
			if cd.tag ~= aW and cf == v.Errored then
				w = bit32.bor(w, u)
				if cd.hydrate then
					cd.hydrate = false
					aS.clearContainer(cd.containerInfo)
				end
				ce = a8(cd)
				if ce ~= ai.NoLanes then
					cf = m.renderRootSync(cd, ce)
				end
			end
			if cf == v.FatalErrored then
				local cg = C
				m.prepareFreshStack(cd, ai.NoLanes)
				m.markRootSuspended(cd, ce)
				bJ(cd, aE())
				error(cg)
			end
			local cg = cd.current.alternate
			cd.finishedWork = cg
			cd.finishedLanes = ce
			m.commitRoot(cd)
			bJ(cd, aE())
			return nil
		end
		af.flushRoot = function(cd, ce)
			bc(cd, ce)
			bJ(cd, aE())
			if bit32.band(w, bit32.bor(s, t)) == n then
				resetRenderTimer()
				aJ()
			end
		end
		af.getExecutionContext = function()
			return w
		end
		af.flushDiscreteUpdates = function()
			if bit32.band(w, bit32.bor(o, s, t)) ~= n then
				if aa then
					if bit32.band(w, s) ~= n then
						ac.error("unstable_flushDiscreteUpdates: Cannot flush updates when React is already rendering.")
					end
				end
				return
			end
			m.flushPendingDiscreteUpdates()
			af.flushPassiveEffects()
		end
		af.deferredUpdates = function(cd)
			if am.decoupleUpdatePriorityFromScheduler then
				local ce = a6()
				local cf, cg
				if not ab then
					a4(ai.DefaultLanePriority)
					cf, cg = xpcall(aA, as, aI, cd)
				else
					cf = true
					a4(ai.DefaultLanePriority)
					cg = aA(aI, cd)
				end
				a4(ce)
				if cf then
					return cg
				else
					error(cg)
				end
			else
				return aA(aI, cd)
			end
		end
		m.flushPendingDiscreteUpdates = function()
			if V ~= nil then
				local cd = V
				V = nil
				cd.forEach(cd, function(ce)
					bd(ce)
					bJ(ce, aE())
				end)
			end
			aJ()
		end
		af.batchedUpdates = function(cd, ce)
			local cf = w
			w = bit32.bor(w, o)
			local cg, ch
			if not ab then
				cg, ch = xpcall(cd, as, ce)
			else
				cg = true
				ch = cd(ce)
			end
			w = cf
			if w == n then
				resetRenderTimer()
				aJ()
			end
			if cg then
				return ch
			else
				error(ch)
			end
		end
		af.batchedEventUpdates = function(cd, ce)
			local cf = w
			w = bit32.bor(w, p)
			local cg, ch
			if not ab then
				cg, ch = xpcall(cd, as, ce)
			else
				cg = true
				ch = cd(ce)
			end
			w = cf
			if w == n then
				resetRenderTimer()
				aJ()
			end
			if cg then
				return ch
			else
				error(ch)
			end
		end
		af.discreteUpdates = function(cd, ce, cf, cg, ch)
			local ci = w
			w = bit32.bor(w, q)
			if am.decoupleUpdatePriorityFromScheduler then
				local cj = a6()
				a4(ai.InputDiscreteLanePriority)
				local ck, cl = xpcall(aA, as, aH, function()
					return cd(ce, cf, cg, ch)
				end)
				a4(cj)
				w = ci
				if w == n then
					resetRenderTimer()
					aJ()
				end
				if ck then
					return cl
				else
					error(cl)
				end
			else
				local cj, ck = xpcall(aA, as, aH, function()
					return cd(ce, cf, cg, ch)
				end)
				w = ci
				if w == n then
					resetRenderTimer()
					aJ()
				end
				if cj then
					return ck
				else
					error(ck)
				end
			end
		end
		af.unbatchedUpdates = function(cd, ce)
			local cf = w
			w = bit32.band(w, bit32.bnot(o))
			w = bit32.bor(w, r)
			local cg, ch
			if not ab then
				cg, ch = xpcall(cd, as, ce)
			else
				cg = true
				ch = cd(ce)
			end
			w = cf
			if w == n then
				resetRenderTimer()
				aJ()
			end
			if cg then
				return ch
			else
				error(ch)
			end
		end
		af.flushSync = function(cd, ce)
			local cf = w
			if (bit32.band(cf, bit32.bor(s, t))) ~= n then
				if aa then
					ac.error("flushSync was called from inside a lifecycle method. React cannot flush when React is already rendering. Consider moving this call to a scheduler task or micro task.")
				end
				return cd(ce)
			end
			w = bit32.bor(w, o)
			if am.decoupleUpdatePriorityFromScheduler then
				local cg = a6()
				a4(ai.SyncLanePriority)
				local ch, ci
				if not ab then
					if cd then
						ch, ci = xpcall(aA, as, aG, function()
							return cd(ce)
						end)
					else
						ch = true
						ci = nil
					end
				else
					ch = true
					a4(ai.SyncLanePriority)
					if cd then
						ci = aA(aG, function()
							return cd(ce)
						end)
					else
						ci = nil
					end
				end
				a4(cg)
				w = cf
				aJ()
				if not ch then
					error(ci)
				end
				return ci
			else
				local cg, ch
				if not ab then
					if cd then
						cg, ch = xpcall(aA, as, aG, function()
							return cd(ce)
						end)
					else
						cg = true
						ch = nil
					end
				else
					cg = true
					if cd then
						ch = aA(aG, function()
							return cd(ce)
						end)
					else
						ch = nil
					end
				end
				w = cf
				aJ()
				if not cg then
					error(ch)
				end
				return ch
			end
		end
		af.flushControlled = function(cd)
			local ce = w
			w = bit32.bor(w, o)
			if am.decoupleUpdatePriorityFromScheduler then
				local cf = a6()
				a4(ai.SyncLanePriority)
				local cg, ch = xpcall(aA, as, aG, cd)
				a4(cf)
				w = ce
				if w == n then
					resetRenderTimer()
					aJ()
				end
				if not cg then
					error(ch)
				end
			else
				local cf, cg = xpcall(aA, as, aG, cd)
				w = ce
				if w == n then
					resetRenderTimer()
					aJ()
				end
				if not cf then
					error(cg)
				end
			end
		end
		af.pushRenderLanes = function(cd, ce)
			bS(A, af.subtreeRenderLanes, cd)
			af.subtreeRenderLanes = ai.mergeLanes(af.subtreeRenderLanes, ce)
			D = ai.mergeLanes(D, ce)
		end
		af.popRenderLanes = function(cd)
			af.subtreeRenderLanes = A.current
			bT(A, cd)
		end
		m.prepareFreshStack = function(cd, ce)
			cd.finishedWork = nil
			cd.finishedLanes = ai.NoLanes
			local cf = cd.timeoutHandle
			if cf ~= aS.noTimeout then
				cd.timeoutHandle = aS.noTimeout
				aS.cancelTimeout(cf)
			end
			if y ~= nil then
				local cg = y.return_
				while cg ~= nil do
					bk(cg)
					cg = cg.return_
				end
			end
			x = cd
			y = aT.createWorkInProgress(cd.current, nil)
			z = ce
			af.subtreeRenderLanes = ce
			D = ce
			B = v.Incomplete
			C = nil
			F(ai.NoLanes)
			G = ai.NoLanes
			H = ai.NoLanes
			if am.enableSchedulerTracing then
				b5 = nil
			end
			if aa then
				bX.discardPendingWarnings()
			end
		end
		m.handleError = function(cd, ce)
			while true do
				local cf = y
				local cg, ch = pcall(function()
					bH()
					bO()
					b_()
					i.current = nil
					if cf == nil or cf.return_ == nil then
						B = v.FatalErrored
						C = ce
						y = nil
						return
					end
					if am.enableProfilerTimer and bit32.band((cf).mode, aU.ProfileMode) ~= 0 then
						bV.stopProfilerTimerIfRunningAndRecordDelta(cf, true)
					end
					bm(cd, (cf).return_, cf, ce, z, af.onUncaughtError, af.renderDidError)
					m.completeUnitOfWork(cf)
				end)
				if not cg then
					ce = ch
					if y == cf and cf ~= nil then
						cf = cf.return_
						y = cf
					else
						cf = y
					end
					continue
				end
				return
			end
		end
		m.pushDispatcher = function()
			local cd = h.current
			h.current = bP()
			if cd == nil then
				return bP()
			else
				return cd
			end
		end
		m.popDispatcher = function(cd)
			h.current = cd
		end
		m.pushInteractions = function(cd)
			if am.enableSchedulerTracing then
				local ce = aP.current
				aP.current = cd.memoizedInteractions
				return ce
			end
			return nil
		end
		m.popInteractions = function(cd)
			if am.enableSchedulerTracing then
				aP.current = cd
			end
		end
		af.markCommitTimeOfFallback = function()
			J = aE()
		end
		af.markSkippedUpdateLanes = function(cd)
			E.markSkippedUpdateLanes(cd)
		end
		af.renderDidSuspend = function()
			if B == v.Incomplete then
				B = v.Suspended
			end
		end
		af.renderDidSuspendDelayIfPossible = function()
			if B == v.Incomplete or B == v.Suspended then
				B = v.SuspendedWithDelay
			end
			if x ~= nil and (a_(F()) or a_(G)) then
				m.markRootSuspended(x, z)
			end
		end
		af.renderDidError = function()
			if B ~= v.Completed then
				B = v.Errored
			end
		end
		af.renderHasNotSuspendedYet = function()
			return B == v.Incomplete
		end
		m.renderRootSync = function(cd, ce)
			local cf = w
			w = bit32.bor(w, s)
			local cg = m.pushDispatcher()
			if x ~= cd or z ~= ce then
				m.prepareFreshStack(cd, ce)
				m.startWorkOnPendingInteractions(cd, ce)
			end
			local ch = m.pushInteractions(cd)
			if aa then
				if an then
					aL.logRenderStarted(ce)
				end
			end
			if ao then
				aM.markRenderStarted(ce)
			end
			while true do
				local ci, cj
				if not ab then
					ci, cj = xpcall(m.workLoopSync, as)
				else
					ci = true
					m.workLoopSync()
				end
				if not ci then
					m.handleError(cd, cj)
				else
					break
				end
			end
			bH()
			if am.enableSchedulerTracing then
				m.popInteractions(ch)
			end
			w = cf
			m.popDispatcher(cg)
			if y ~= nil then
				av(
					false,
					"Cannot commit an incomplete root. This error is likely caused by a bug in React. Please file an issue."
				)
			end
			if aa then
				if an then
					aL.logRenderStopped()
				end
			end
			if ao then
				aM.markRenderStopped()
			end
			x = nil
			z = ai.NoLanes
			return B
		end
		m.workLoopSync = function()
			while y ~= nil do
				m.performUnitOfWork(y)
			end
		end
		m.renderRootConcurrent = function(cd, ce)
			local cf = w
			w = bit32.bor(w, s)
			local cg = m.pushDispatcher()
			if x ~= cd or z ~= ce then
				resetRenderTimer()
				m.prepareFreshStack(cd, ce)
				m.startWorkOnPendingInteractions(cd, ce)
			end
			local ch = m.pushInteractions(cd)
			if aa then
				if an then
					aL.logRenderStarted(ce)
				end
			end
			if ao then
				aM.markRenderStarted(ce)
			end
			while true do
				local ci, cj
				if not ab then
					ci, cj = xpcall(m.workLoopConcurrent, as)
					if ci then
						cj = "break"
					end
				else
					ci = true
					cj = "break"
					m.workLoopConcurrent()
				end
				if cj == "break" then
					break
				end
				if not ci then
					m.handleError(cd, cj)
				end
			end
			bH()
			if am.enableSchedulerTracing then
				m.popInteractions(ch)
			end
			m.popDispatcher(cg)
			w = cf
			if aa then
				if an then
					aL.logRenderStopped()
				end
			end
			if y ~= nil then
				if ao then
					aM.markRenderYielded()
				end
				return v.Incomplete
			else
				if ao then
					aM.markRenderStopped()
				end
				x = nil
				z = ai.NoLanes
				return B
			end
		end
		m.workLoopConcurrent = function()
			while y ~= nil and not aC() do
				m.performUnitOfWork(y)
			end
		end
		m.performUnitOfWork = function(cd)
			local ce = bI.profileUnitOfWorkBefore(cd)
			local cf = cd.alternate
			b0(cd)
			local cg
			if am.enableProfilerTimer and bit32.band(cd.mode, aU.ProfileMode) ~= aU.NoMode then
				bV.startProfilerTimer(cd)
				cg = m.beginWork(cf, cd, af.subtreeRenderLanes)
				bV.stopProfilerTimerIfRunningAndRecordDelta(cd, true)
			else
				cg = m.beginWork(cf, cd, af.subtreeRenderLanes)
			end
			b_()
			cd.memoizedProps = cd.pendingProps
			if cg == nil then
				m.completeUnitOfWork(cd)
			else
				y = cg
			end
			i.current = nil
			bI.profileUnitOfWorkAfter(ce)
		end
		m.completeUnitOfWork = function(cd)
			local ce = cd
			repeat
				local cf = ce.alternate
				local cg = ce.return_
				if bit32.band(ce.flags, aX.Incomplete) == aX.NoFlags then
					b0(ce)
					local ch
					if not am.enableProfilerTimer or bit32.band(ce.mode, aU.ProfileMode) == aU.NoMode then
						ch = bM(cf, ce, af.subtreeRenderLanes)
					else
						bV.startProfilerTimer(ce)
						ch = bM(cf, ce, af.subtreeRenderLanes)
						bV.stopProfilerTimerIfRunningAndRecordDelta(ce, false)
					end
					b_()
					if ch ~= nil then
						y = ch
						return
					end
				else
					local ch = bj(ce, af.subtreeRenderLanes)
					if ch ~= nil then
						ch.flags = bit32.band(ch.flags, aX.HostEffectMask)
						y = ch
						return
					end
					if am.enableProfilerTimer and bit32.band(ce.mode, aU.ProfileMode) ~= aU.NoMode then
						bV.stopProfilerTimerIfRunningAndRecordDelta(ce, false)
						local ci = ce.actualDuration or 0
						local cj = ce.child
						while cj ~= nil do
							ci += cj.actualDuration or 0
							cj = cj.sibling
						end
						ce.actualDuration = ci
					end
					if cg ~= nil then
						cg.flags = bit32.bor(cg.flags, aX.Incomplete)
						cg.subtreeFlags = aX.NoFlags
						cg.deletions = nil
					end
				end
				local ch = ce.sibling
				if ch ~= nil then
					y = ch
					return
				end
				ce = cg
				y = ce
			until ce == nil
			if B == v.Incomplete then
				B = v.Completed
			end
		end
		m.commitRoot = function(cd)
			local ce = az()
			aA(aG, function()
				bI.profileCommitBefore()
				local cf = m.commitRootImpl(cd, ce)
				bI.profileCommitAfter()
				return cf
			end)
			return nil
		end
		m.commitRootImpl = function(cd, ce)
			repeat
				af.flushPassiveEffects()
			until S == nil
			flushRenderPhaseStrictModeWarningsInDEV()
			av(bit32.band(w, bit32.bor(s, t)) == n, "Should not already be working.")
			local cf = cd.finishedWork
			local cg = cd.finishedLanes
			if aa then
				if an then
					aL.logCommitStarted(cg)
				end
			end
			if ao then
				aM.markCommitStarted(cg)
			end
			if cf == nil then
				if aa then
					if an then
						aL.logCommitStopped()
					end
				end
				if ao then
					aM.markCommitStopped()
				end
				return nil
			end
			cd.finishedWork = nil
			cd.finishedLanes = ai.NoLanes
			av(
				cf ~= cd.current,
				"Cannot commit the same tree as before. This error is likely caused by a bug in React. Please file an issue."
			)
			cd.callbackNode = nil
			local ch = ai.mergeLanes(cf.lanes, cf.childLanes)
			be(cd, ch)
			if V ~= nil then
				if not aZ(ch) and V.has(V, cd) then
					V.delete(V, cd)
				end
			end
			if cd == x then
				x = nil
				y = nil
				z = ai.NoLanes
			end
			local ci = bit32.band(
				cf.subtreeFlags,
				bit32.bor(aX.BeforeMutationMask, aX.MutationMask, aX.LayoutMask, aX.PassiveMask)
			) ~= aX.NoFlags
			local cj = bit32.band(
				cf.flags,
				bit32.bor(aX.BeforeMutationMask, aX.MutationMask, aX.LayoutMask, aX.PassiveMask)
			) ~= aX.NoFlags
			if ci or cj then
				local ck
				if am.decoupleUpdatePriorityFromScheduler then
					ck = a6()
					a4(ai.SyncLanePriority)
				end
				local cl = w
				w = bit32.bor(w, t)
				local cm = m.pushInteractions(cd)
				i.current = nil
				b9 = aS.prepareForCommit(cd.containerInfo)
				ca = false
				m.commitBeforeMutationEffects(cf)
				b9 = nil
				if am.enableProfilerTimer then
					bV.recordCommitTime()
				end
				m.commitMutationEffects(cf, cd, ce)
				if ca then
					aS.afterActiveInstanceBlur()
				end
				aS.resetAfterCommit(cd.containerInfo)
				cd.current = cf
				if aa then
					if an then
						aL.logLayoutEffectsStarted(cg)
					end
				end
				if ao then
					aM.markLayoutEffectsStarted(cg)
				end
				if aa then
					b0(cf)
					b2(nil, bD, nil, cf, cd, af.captureCommitPhaseError, af.schedulePassiveEffectCallback)
					if b3() then
						local cn = b4()
						k(cf, cf, cn)
					end
					b_()
				else
					local cn, co
					if not ab then
						cn, co = xpcall(bD, as, cf, cd, af.captureCommitPhaseError, af.schedulePassiveEffectCallback)
					else
						cn = true
						bD(cf, cd, af.captureCommitPhaseError, af.schedulePassiveEffectCallback)
					end
					if not cn then
						k(cf, cf, co)
					end
				end
				if aa then
					if an then
						aL.logLayoutEffectsStopped()
					end
				end
				if ao then
					aM.markLayoutEffectsStopped()
				end
				if
					bit32.band(cf.subtreeFlags, aX.PassiveMask) ~= aX.NoFlags
					or bit32.band(cf.flags, aX.PassiveMask) ~= aX.NoFlags
				then
					if not R then
						R = true
						ax(aI, function()
							af.flushPassiveEffects()
							return nil
						end)
					end
				end
				aD()
				if am.enableSchedulerTracing then
					m.popInteractions(cm)
				end
				w = cl
				if am.decoupleUpdatePriorityFromScheduler and ck ~= nil then
					a4(ck)
				end
			else
				cd.current = cf
				if am.enableProfilerTimer then
					bV.recordCommitTime()
				end
			end
			local ck = R
			if R then
				R = false
				S = cd
				U = cg
				T = ce
			end
			ch = cd.pendingLanes
			if ch ~= ai.NoLanes then
				if am.enableSchedulerTracing then
					if b5 ~= nil then
						local cl = b5
						b5 = nil
						for cm = 1, #cl do
							scheduleInteractions(cd, cl[cm], cd.memoizedInteractions)
						end
					end
					m.schedulePendingInteractions(cd, ch)
				end
			else
				Q = nil
			end
			if aa and aq then
				if not ck then
					commitDoubleInvokeEffectsInDEV(cd.current, false)
				end
			end
			if am.enableSchedulerTracing then
				if not ck then
					m.finishPendingInteractions(cd, cg)
				end
			end
			if ch == ai.SyncLane then
				if cd == Y then
					X += 1
				else
					X = 0
					Y = cd
				end
			else
				X = 0
			end
			c(cf.stateNode, ce)
			if aa then
				d()
			end
			bJ(cd, aE())
			if O then
				O = false
				local cl = P
				P = nil
				error(cl)
			end
			if bit32.band(w, r) ~= n then
				if aa then
					if an then
						aL.logCommitStopped()
					end
				end
				if ao then
					aM.markCommitStopped()
				end
				return nil
			end
			aJ()
			if aa then
				if an then
					aL.logCommitStopped()
				end
			end
			if ao then
				aM.markCommitStopped()
			end
			return nil
		end
		m.commitBeforeMutationEffects = function(cd)
			local ce = cd
			while ce ~= nil do
				if ce.deletions ~= nil then
					m.commitBeforeMutationEffectsDeletions(ce.deletions)
				end
				if ce.child ~= nil then
					local cf = bit32.band(ce.subtreeFlags, aX.BeforeMutationMask)
					if cf ~= aX.NoFlags then
						m.commitBeforeMutationEffects(ce.child)
					end
				end
				if aa then
					b0(ce)
					b2(nil, m.commitBeforeMutationEffectsImpl, nil, ce)
					if b3() then
						local cf = b4()
						af.captureCommitPhaseError(ce, ce.return_, cf)
					end
					b_()
				else
					local cf, cg
					if not ab then
						cf, cg = xpcall(m.commitBeforeMutationEffectsImpl, as, ce)
					else
						cf = true
						m.commitBeforeMutationEffectsImpl(ce)
					end
					if not cf then
						af.captureCommitPhaseError(ce, ce.return_, cg)
					end
				end
				ce = ce.sibling
			end
		end
		m.commitBeforeMutationEffectsImpl = function(cd)
			local ce = cd.alternate
			local cf = cd.flags
			if not ca and b9 ~= nil then
				if cd.tag == aV.SuspenseComponent and bp.isSuspenseBoundaryBeingHidden(ce, cd) and g(cd, b9) then
					ca = true
					aS.beforeActiveInstanceBlur()
				end
			end
			if bit32.band(cf, aX.Snapshot) ~= aX.NoFlags then
				b0(cd)
				bq(ce, cd)
				b_()
			end
			if bit32.band(cf, aX.Passive) ~= aX.NoFlags then
				if not R then
					R = true
					ax(aI, function()
						af.flushPassiveEffects()
						return nil
					end)
				end
			end
		end
		m.commitBeforeMutationEffectsDeletions = function(cd)
			for ce = 1, #cd do
				local cf = cd[ce]
				if g(cf, b9) then
					ca = true
					aS.beforeActiveInstanceBlur()
				end
			end
		end
		m.commitMutationEffects = function(cd, ce, cf)
			local cg = cd
			while cg ~= nil do
				local ch = cg.deletions
				if ch ~= nil then
					for ci, cj in ch do
						local ck, cl = xpcall(bt, as, ce, cj, cg, cf)
						if not ck then
							af.captureCommitPhaseError(cj, cg, cl)
						end
					end
				end
				if cg.child ~= nil then
					local ci = bit32.band(cg.subtreeFlags, aX.MutationMask)
					if ci ~= aX.NoFlags then
						m.commitMutationEffects(cg.child, ce, cf)
					end
				end
				if aa then
					b0(cg)
					b2(nil, m.commitMutationEffectsImpl, nil, cg, ce, cf)
					if b3() then
						local ci = b4()
						af.captureCommitPhaseError(cg, cg.return_, ci)
					end
					b_()
				else
					local ci, cj
					if not ab then
						ci, cj = xpcall(m.commitMutationEffectsImpl, as, cg, ce, cf)
					else
						ci = true
						m.commitMutationEffectsImpl(cg, ce, cf)
					end
					if not ci then
						af.captureCommitPhaseError(cg, cg.return_, cj)
					end
				end
				cg = cg.sibling
			end
		end
		m.commitMutationEffectsImpl = function(cd, ce, cf)
			local cg = cd.flags
			if bit32.band(cg, aX.Ref) ~= 0 then
				local ch = cd.alternate
				if ch ~= nil then
					by(ch)
				end
			end
			local ch = bit32.band(cg, bit32.bor(aX.Placement, aX.Update, aX.Hydrating))
			if ch == aX.Placement then
				br(cd)
				cd.flags = bit32.band(cd.flags, bit32.bnot(aX.Placement))
			elseif ch == aX.PlacementAndUpdate then
				br(cd)
				cd.flags = bit32.band(cd.flags, bit32.bnot(aX.Placement))
				local ci = cd.alternate
				bs(ci, cd)
			elseif ch == aX.Update then
				local ci = cd.alternate
				bs(ci, cd)
			end
		end
		m.commitMutationEffectsDeletions = function(cd, ce, cf, cg)
			for ch, ci in cd do
				local cj, ck = xpcall(bt, as, cf, ci, ce, cg)
				if not cj then
					af.captureCommitPhaseError(ci, ce, ck)
				end
			end
		end
		af.schedulePassiveEffectCallback = function()
			if not R then
				R = true
				ax(aI, function()
					af.flushPassiveEffects()
					return nil
				end)
			end
		end
		local cd
		af.flushPassiveEffects = function()
			if T ~= aF then
				local ce = if T > aI then aI else T
				T = aF
				if am.decoupleUpdatePriorityFromScheduler then
					local cf = a6()
					a4(bf(ce))
					local cg, ch
					if not ab then
						cg, ch = xpcall(aA, as, ce, cd)
					else
						cg = true
						a4(bf(ce))
						ch = aA(ce, cd)
					end
					a4(cf)
					if not cg then
						error(ch)
					end
					return ch
				else
					return aA(ce, cd)
				end
			end
			return false
		end
		l = function(ce, cf)
			local cg = cf
			while cg ~= nil do
				local ch
				if am.enableProfilerTimer and am.enableProfilerCommitHooks then
					if cg.tag == aV.Profiler then
						ch = N
						N = cg
					end
				end
				local ci = bit32.band(cg.subtreeFlags, aX.PassiveMask)
				if cg.child ~= nil and ci ~= aX.NoFlags then
					l(ce, cg.child)
				end
				if bit32.band(cg.flags, aX.Passive) ~= aX.NoFlags then
					if aa then
						b0(cg)
						b2(nil, bw, nil, ce, cg)
						if b3() then
							local cj = b4()
							af.captureCommitPhaseError(cg, cg.return_, cj)
						end
						b_()
					else
						local cj, ck
						if not ab then
							cj, ck = xpcall(bw, as, ce, cg)
						else
							cj = true
							bw(ce, cg)
						end
						if not cj then
							af.captureCommitPhaseError(cg, cg.return_, ck)
						end
					end
				end
				if am.enableProfilerTimer and am.enableProfilerCommitHooks then
					if cg.tag == aV.Profiler then
						if ch ~= nil then
							ch.stateNode.passiveEffectDuration += cg.stateNode.passiveEffectDuration
						end
						N = ch
					end
				end
				cg = cg.sibling
			end
		end
		local function flushPassiveUnmountEffects(ce)
			local cf = ce
			while cf ~= nil do
				local cg = cf.deletions
				if cg ~= nil then
					for ch = 1, #cg do
						local ci = cg[ch]
						m.flushPassiveUnmountEffectsInsideOfDeletedTree(ci, cf)
						m.detachFiberAfterEffects(ci)
					end
				end
				local ch = cf.child
				if ch ~= nil then
					local ci = bit32.band(cf.subtreeFlags, aX.PassiveMask)
					if ci ~= aX.NoFlags then
						flushPassiveUnmountEffects(ch)
					end
				end
				local ci = bit32.band(cf.flags, aX.Passive)
				if ci ~= aX.NoFlags then
					b0(cf)
					bu(cf)
					b_()
				end
				cf = cf.sibling
			end
		end
		m.flushPassiveUnmountEffectsInsideOfDeletedTree = function(ce, cf)
			if bit32.band(ce.subtreeFlags, aX.PassiveStatic) ~= aX.NoFlags then
				local cg = ce.child
				while cg ~= nil do
					m.flushPassiveUnmountEffectsInsideOfDeletedTree(cg, cf)
					cg = cg.sibling
				end
			end
			if bit32.band(ce.flags, aX.PassiveStatic) ~= aX.NoFlags then
				b0(ce)
				bv(ce, cf)
				b_()
			end
		end
		cd = function()
			if S == nil then
				return false
			end
			local ce = S
			local cf = U
			S = nil
			U = ai.NoLanes
			av(bit32.band(w, bit32.bor(s, t)) == n, "Cannot flush passive effects while already rendering.")
			if aa then
				if an then
					aL.logPassiveEffectsStarted(cf)
				end
			end
			if ao then
				aM.markPassiveEffectsStarted(cf)
			end
			local cg = w
			w = bit32.bor(w, t)
			local ch = m.pushInteractions(ce)
			flushPassiveUnmountEffects(ce.current)
			l(ce, ce.current)
			if aa then
				if an then
					aL.logPassiveEffectsStopped()
				end
			end
			if ao then
				aM.markPassiveEffectsStopped()
			end
			if aa and aq then
				commitDoubleInvokeEffectsInDEV(ce.current, true)
			end
			if am.enableSchedulerTracing then
				m.popInteractions(ch)
				m.finishPendingInteractions(ce, cf)
			end
			w = cg
			aJ()
			if S == nil then
				_ = 0
			else
				_ = _ + 1
			end
			return true
		end
		af.isAlreadyFailedLegacyErrorBoundary = function(ce)
			return Q ~= nil and Q.has(Q, ce)
		end
		af.markLegacyErrorBoundaryAsFailed = function(ce)
			if Q == nil then
				Q = ae.new({ ce })
			else
				Q.add(Q, ce)
			end
		end
		local function prepareToThrowUncaughtError(ce)
			if not O then
				O = true
				P = ce
			end
		end
		af.onUncaughtError = prepareToThrowUncaughtError
		k = function(ce, cf, cg)
			local ch = bR(cg, cf)
			local ci = bn(ce, ch, ai.SyncLane, af.onUncaughtError)
			bF(ce, ci)
			local cj = af.requestEventTime()
			local ck = m.markUpdateLaneFromFiberToRoot(ce, ai.SyncLane)
			if ck ~= nil then
				b(ck, ai.SyncLane, cj)
				bJ(ck, cj)
				m.schedulePendingInteractions(ck, ai.SyncLane)
			end
		end
		af.captureCommitPhaseError = function(ce, cf, cg)
			if ce.tag == aV.HostRoot then
				k(ce, ce, cg)
				return
			end
			local ch
			if ap then
				ch = cf
			else
				ch = ce.return_
			end
			while ch ~= nil do
				if ch.tag == aV.HostRoot then
					k(ch, ce, cg)
					return
				else
					if ch.tag == aV.ClassComponent then
						local ci = ch.type
						local cj = ch.stateNode
						if
							typeof(ci.getDerivedStateFromError) == "function"
							or (
								typeof(cj.componentDidCatch) == "function"
								and not af.isAlreadyFailedLegacyErrorBoundary(cj)
							)
						then
							local ck = bR(cg, ce)
							local cl = bo(ch, ck, ai.SyncLane)
							bF(ch, cl)
							local cm = af.requestEventTime()
							local cn = m.markUpdateLaneFromFiberToRoot(ch, ai.SyncLane)
							if cn ~= nil then
								b(cn, ai.SyncLane, cm)
								bJ(cn, cm)
								m.schedulePendingInteractions(cn, ai.SyncLane)
							end
							return
						end
					end
					ch = ch.return_
				end
			end
		end
		af.pingSuspendedRoot = function(ce, cf, cg)
			local ch = ce.pingCache
			if ch ~= nil then
				ch[cf] = nil
			end
			local ci = af.requestEventTime()
			bb(ce, cg, ci)
			if x == ce and ai.isSubsetOfLanes(z, cg) then
				if B == v.SuspendedWithDelay or B == v.Suspended and a0(z) and aE() - J < K then
					m.prepareFreshStack(ce, ai.NoLanes)
				else
					H = ai.mergeLanes(H, cg)
				end
			end
			bJ(ce, ci)
			m.schedulePendingInteractions(ce, cg)
		end
		function retryTimedOutBoundary(ce, cf)
			if cf == ai.NoLane then
				cf = requestRetryLane(ce)
			end
			local cg = af.requestEventTime()
			local ch = m.markUpdateLaneFromFiberToRoot(ce, cf)
			if ch ~= nil then
				b(ch, cf, cg)
				bJ(ch, cg)
				m.schedulePendingInteractions(ch, cf)
			end
		end
		af.resolveRetryWakeable = function(ce, cf)
			local cg = ai.NoLane
			local ch
			ch = ce.stateNode
			if ch ~= nil then
				ch.delete(ch, cf)
			end
			retryTimedOutBoundary(ce, cg)
		end
		function jnd(ce)
			if ce < 120 then
				return 120
			elseif ce < 480 then
				return 480
			elseif ce < 1080 then
				return 1080
			elseif ce < 1920 then
				return 1920
			elseif ce < 3000 then
				return 3000
			elseif ce < 4320 then
				return 4320
			else
				return math.ceil(ce / 1960) * 1960
			end
		end
		m.checkForNestedUpdates = function()
			if X > W then
				X = 0
				Y = nil
				av(
					false,
					"Maximum update depth exceeded. This can happen when a component repeatedly calls setState inside componentWillUpdate or componentDidUpdate. React limits the number of nested updates to prevent infinite loops."
				)
			end
			if aa then
				if _ > Z then
					_ = 0
					ac.error("Maximum update depth exceeded. This can happen when a component calls setState inside useEffect, but useEffect either doesn't have a dependency array, or one of the dependencies changes on every render.")
				end
			end
		end
		function flushRenderPhaseStrictModeWarningsInDEV()
			if aa then
				bX.flushLegacyContextWarning()
				if am.warnAboutDeprecatedLifecycles then
					bX.flushPendingUnsafeLifecycleWarnings()
				end
			end
		end
		function commitDoubleInvokeEffectsInDEV(ce, cf)
			if aa and aq then
				b0(ce)
				invokeEffectsInDev(ce, aX.MountLayoutDev, bB)
				if cf then
					invokeEffectsInDev(ce, aX.MountPassiveDev, bC)
				end
				invokeEffectsInDev(ce, aX.MountLayoutDev, bz)
				if cf then
					invokeEffectsInDev(ce, aX.MountPassiveDev, bA)
				end
				b_()
			end
		end
		function invokeEffectsInDev(ce, cf, cg)
			if aa and aq then
				local ch = ce
				while ch ~= nil do
					if ch.child ~= nil then
						local ci = bit32.band(ch.subtreeFlags, cf)
						if ci ~= aX.NoFlags then
							invokeEffectsInDev(ch.child, cf, cg)
						end
					end
					if bit32.band(ch.flags, cf) ~= aX.NoFlags then
						cg(ch)
					end
					ch = ch.sibling
				end
			end
		end
		local ce
		m.warnAboutUpdateOnNotYetMountedFiberInDEV = function(cf)
			if aa then
				if bit32.band(w, s) ~= n then
					return
				end
				if bit32.band(cf.mode, bit32.bor(aU.BlockingMode, aU.ConcurrentMode)) == 0 then
					return
				end
				local cg = cf.tag
				if
					cg ~= aV.IndeterminateComponent
					and cg ~= aV.HostRoot
					and cg ~= aV.ClassComponent
					and cg ~= aV.FunctionComponent
					and cg ~= aV.ForwardRef
					and cg ~= aV.MemoComponent
					and cg ~= aV.SimpleMemoComponent
					and cg ~= aV.Block
				then
					return
				end
				local ch = bW(cf.type) or "ReactComponent"
				if ce ~= nil then
					if ce[ch] then
						return
					end
					ce[ch] = true
				else
					ce = { [ch] = true }
				end
				local ci = bY.current
				local cj, ck = pcall(function()
					b0(cf)
					ac.error("Can't perform a React state update on a component that hasn't mounted yet. This indicates that you have a side-effect in your render function that asynchronously later calls tries to update the component. Move this work to useEffect instead.")
				end)
				if ci then
					b0(cf)
				else
					b_()
				end
				if not cj then
					error(ck)
				end
			end
		end
		if aa and am.replayFailedUnitOfWorkWithInvokeGuardedCallback then
			local cf
			m.beginWork = function(cg, ch, ci)
				local cj = aT.assignFiberPropertiesInDEV(cf, ch)
				local ck, cl = xpcall(bL, as, cg, ch, ci)
				if not ck then
					local cm = cl
					if cm ~= nil and typeof(cm) == "table" and typeof(cm.andThen) == "function" then
						error(cm)
					end
					bH()
					bO()
					bk(ch)
					aT.assignFiberPropertiesInDEV(ch, cj)
					if am.enableProfilerTimer and bit32.band(ch.mode, aU.ProfileMode) ~= 0 then
						bV.startProfilerTimer(ch)
					end
					b2(nil, bL, nil, cg, ch, ci)
					if b3() then
						local cn = b4()
						error(cn)
					else
						error(cm)
					end
				end
				return cl
			end
		else
			m.beginWork = bL
		end
		local cf = false
		local cg
		if aa then
			cg = {}
		end
		m.warnAboutRenderPhaseUpdatesInDEV = function(ch)
			if aa then
				if bY.isRendering and bit32.band(w, s) ~= n and not bQ() then
					if
						ch.tag == aV.FunctionComponent
						or ch.tag == aV.ForwardRef
						or ch.tag == aV.SimpleMemoComponent
					then
						local ci = (function()
							if y ~= nil then
								return bW((y).type)
							end
							return "Unknown"
						end)()
						local cj = ci
						if cg[cj] == nil then
							cg[cj] = true
							local ck = bW(ch.type) or "Unknown"
							ac.error(
								"Cannot update a component (`%s`) while rendering a different component (`%s`). To locate the bad setState() call inside `%s`, follow the stack trace as described in https://reactjs.org/link/setstate-in-render",
								ck,
								ci,
								ci
							)
						end
					elseif ch.tag == aV.ClassComponent then
						if not cf then
							ac.error("Cannot update during an existing state transition (such as within `render`). Render methods should be a pure function of props and state.")
							cf = true
						end
					end
				end
			end
		end
		af.IsThisRendererActing = { current = false }
		af.warnIfNotScopedWithMatchingAct = function(ch)
			if aa then
				if aS.warnsIfNotActing == true and j.current == true and af.IsThisRendererActing.current ~= true then
					local ci = bY.current
					local cj, ck = pcall(function()
						b0(ch)
						ac.error("It looks like you're using the wrong act() around your test interactions.\nBe sure to use the matching version of act() corresponding to your renderer:\n\n-- for react-roblox:\nlocal React = require(Packages.React)\n-- ...\nReact.TestUtils.act(function() ... end)\n\n-- for react-test-renderer:\nlocal TestRenderer = require(Packages.ReactTestRenderer)\n-- ...\nTestRenderer.act(function() ... end)")
					end)
					if ci then
						b0(ch)
					else
						b_()
					end
					if not cj then
						error(ck)
					end
				end
			end
		end
		af.warnIfNotCurrentlyActingEffectsInDEV = function(ch)
			if aa then
				if
					aS.warnsIfNotActing == true
					and bit32.band(ch.mode, aU.StrictMode) ~= aU.NoMode
					and j.current == false
					and af.IsThisRendererActing.current == false
				then
					ac.error(
						"An update to %s ran an effect, but was not wrapped in act(...).\n\nWhen testing, code that causes React state updates should be wrapped into act(...):\n\nact(function()\n  --[[ fire events that update state ]]\nend)\n--[[ assert on the output ]]\n\nThis ensures that you're testing the behavior the user would see in the real client. Learn more at https://reactjs.org/link/wrap-tests-with-act",
						bW(ch.type)
					)
				end
			end
		end
		af.warnIfNotCurrentlyActingUpdatesInDEV = function(ch)
			if aa then
				if
					aS.warnsIfNotActing == true
					and w == n
					and j.current == false
					and af.IsThisRendererActing.current == false
				then
					local ci = bZ
					local cj, ck = pcall(function()
						b0(ch)
						ac.error(
							"An update to %s inside a test was not wrapped in act(...).\n\nWhen testing, code that causes React state updates should be wrapped into act(...):\n\nact(function()\n  --[[ fire events that update state ]]\nend)\n--[[ assert on the output ]]\n\nThis ensures that you're testing the behavior the user would see in the client application. Learn more at https://reactjs.org/link/wrap-tests-with-act",
							bW(ch.type)
						)
					end)
					if ci then
						b0(ch)
					else
						b_()
					end
					if cj then
						return ck
					end
				end
			end
			return
		end
		local ch = false
		af.warnIfUnmockedScheduler = function(ci)
			if aa then
				if ch == false and aj.unstable_flushAllWithoutAsserting == nil then
					if bit32.band(ci.mode, aU.BlockingMode) ~= 0 or bit32.band(ci.mode, aU.ConcurrentMode) ~= 0 then
						ch = true
						ac.error("In Concurrent or Sync modes, the 'scheduler' module needs to be mocked to guarantee consistent behaviour across tests and client application. For example, with Jest: \njest.mock('scheduler', function() return require(@pkg/scheduler).unstable_mock end)\n\nFor more info, visit https://reactjs.org/link/mock-scheduler")
					elseif am.warnAboutUnmockedScheduler == true then
						ch = true
						ac.error("Starting from React v18, the 'scheduler' module will need to be mocked to guarantee consistent behaviour across tests and client applications. For example, with Jest: \njest.mock('scheduler', function() return require(@pkg/scheduler).unstable_mock end)\n\nFor more info, visit https://reactjs.org/link/mock-scheduler")
					end
				end
			end
		end
		function computeThreadID(ci, cj)
			return cj * 1000 + ci.interactionThreadID
		end
		af.markSpawnedWork = function(ci)
			if not am.enableSchedulerTracing then
				return
			end
			if b5 == nil then
				b5 = { ci }
			else
				table.insert(b5, ci)
			end
		end
		function scheduleInteractions(ci, cj, ck)
			if not am.enableSchedulerTracing then
				return
			end
			if ck.size > 0 then
				local cl = ci.pendingInteractionMap
				local cm = cl.get(cl, cj)
				if cm ~= nil then
					ck.forEach(ck, function(cn)
						if not cm.has(cm, cn) then
							cn.__count += 1
						end
						cm.add(cm, cn)
					end)
				else
					cl.set(cl, cj, ae.new(ck))
					for cn, co in ck do
						co.__count += 1
					end
				end
				local cn = aQ.current
				if cn ~= nil then
					local co = computeThreadID(ci, cj)
					cn.onWorkScheduled(ck, co)
				end
			end
		end
		m.schedulePendingInteractions = function(ci, cj)
			if not am.enableSchedulerTracing then
				return
			end
			scheduleInteractions(ci, cj, aP.current)
		end
		m.startWorkOnPendingInteractions = function(ci, cj)
			if not am.enableSchedulerTracing then
				return
			end
			local ck = ae.new()
			ci.pendingInteractionMap:forEach(function(cl, cm)
				if ai.includesSomeLane(cj, cm) then
					cl.forEach(cl, function(cn)
						ck.add(ck, cn)
					end)
				end
			end)
			ci.memoizedInteractions = ck
			if ck.size > 0 then
				local cl = aQ.current
				if cl ~= nil then
					local cm = computeThreadID(ci, cj)
					local cn, co = xpcall(cl.onWorkStarted, as, ck, cm)
					if not cn then
						ax(aG, function()
							error(co)
						end)
					end
				end
			end
		end
		m.finishPendingInteractions = function(ci, cj)
			if not am.enableSchedulerTracing then
				return
			end
			local ck = ci.pendingLanes
			local cl
			local cm = true
			local cn
			if cl ~= nil and ci.memoizedInteractions.size > 0 then
				local co = computeThreadID(ci, cj)
				cl = aQ.current
				cm, cn = xpcall(cl.onWorkStopped, as, ci.memoizedInteractions, co)
			end
			local co = ci.pendingInteractionMap
			co.forEach(co, function(cp, cq)
				if not ai.includesSomeLane(ck, cq) then
					co.delete(co, cq)
					cp.forEach(cp, function(cr)
						cr.__count -= 1
						if cl ~= nil and cr.__count == 0 then
							local cs, ct = xpcall(cl.onInteractionScheduledWorkCompleted, as, cr)
							if not cs then
								ax(aG, function()
									error(ct)
								end)
							end
						end
					end)
				end
			end)
			if not cm then
				ax(aG, function()
					error(cn)
				end)
			end
		end
		local ci = false
		local cj = false
		local ck = aj.unstable_flushAllWithoutAsserting
		local cl = typeof(ck) == "function"
		local function flushActWork()
			if ck ~= nil then
				local cm = ci
				ci = true
				local cn, co = xpcall(ck, as)
				ci = cm
				if not cn then
					error(co)
				else
					return co
				end
			else
				local cm = ci
				ci = true
				local cn, co = xpcall(function()
					local cn = false
					while af.flushPassiveEffects() do
						cn = true
					end
					return cn
				end, as)
				ci = cm
				if not cn then
					error(co)
				else
					return co
				end
			end
		end
		local function flushWorkAndMicroTasks(cm)
			local cn, co = xpcall(flushActWork, as)
			if cn then
				cn, co = xpcall(e, as, function()
					if flushActWork() then
						flushWorkAndMicroTasks(cm)
					else
						cm()
					end
				end)
			end
			if not cn then
				cm(co)
			end
		end
		af.act = function(cm)
			if not (aa or _G.__ROACT_17_MOCK_SCHEDULER__) then
				if cc == false then
					cc = true
					ac.error("act(...) is not supported in production builds of React, and might not behave as expected.")
				end
			end
			local cn = cb
			cb += 1
			local co = j.current
			local cp = af.IsThisRendererActing.current
			local cq = cj
			j.current = true
			af.IsThisRendererActing.current = true
			cj = true
			local function onDone()
				cb -= 1
				j.current = co
				af.IsThisRendererActing.current = cp
				cj = cq
				if aa then
					if cb > cn then
						ac.error("You seem to have overlapping act() calls, this is not supported. Be sure to await previous act() calls before making a new one. ")
					end
				end
			end
			local cr, cs = xpcall(af.batchedUpdates, as, cm)
			if not cr then
				onDone()
				error(cs)
			end
			if cs ~= nil and typeof(cs) == "table" and typeof(cs.andThen) == "function" then
				local ct = false
				if aa then
					if typeof(bE) ~= nil then
						bE.resolve():andThen(function() end):andThen(function()
							if ct == false then
								ac.error("You called act(Promise.new(function() --[[ ... ]] end)) without :await() or :expect(). This could lead to unexpected testing behaviour, interleaving multiple act calls and mixing their scopes. You should - act(function() Promise.new(function() --[[ ... ]] end):await() end);")
							end
						end)
					end
				end
				return {
					andThen = function(cu, cv, cw)
						ct = true
						return cs.andThen(cs, function()
							if cb > 1 or (cl == true and co == true) then
								onDone()
								cv()
								return
							end
							flushWorkAndMicroTasks(function(cx)
								onDone()
								if cx then
									cw(cx)
								else
									cv()
								end
							end)
						end, function(cx)
							onDone()
							cw(cx)
						end)
					end,
				}
			else
				if aa then
					if cs ~= nil then
						ac.error(
							"The callback passed to act(...) function must return nil, or a Promise. You returned %s",
							tostring(cs)
						)
					end
				end
				local ct, cu = xpcall(function()
					if cb == 1 and (cl == false or co == false) then
						flushActWork()
					end
					onDone()
				end, as)
				if not ct then
					onDone()
					error(cu)
				end
				return {
					andThen = function(cv, cw, cx)
						if aa then
							ac.error("Do not await the result of calling act(...) with sync logic, it is not a Promise.")
						end
						cw()
					end,
				}
			end
		end
		m.detachFiberAfterEffects = function(cm)
			cm.child = nil
			cm.deletions = nil
			cm.dependencies = nil
			cm.memoizedProps = nil
			cm.memoizedState = nil
			cm.pendingProps = nil
			cm.sibling = nil
			cm.stateNode = nil
			cm.updateQueue = nil
			if aa then
				cm._debugOwner = nil
			end
		end
		local cm = a.load("cl")
		local cn = af
		cm.register("ReactFiberWorkLoop", cn)
		return cn
	end
	function a.c5()
		local aa = a.load("b0").ReactSymbols.REACT_PORTAL_TYPE
		local ab = a.load("b0")
		local function createPortal(ac, ad, ae, ag)
			if ag ~= nil then
				ag = tostring(ag)
			end
			return { ["$$typeof"] = aa, key = ag, children = ac, containerInfo = ad, implementation = ae }
		end
		return { createPortal = createPortal }
	end
	function a.c6()
		local aa = _G.__DEV__
		local ab = a.load("b0")
		local ac = a.load("b_")
		local ad = ac.Array
		local ae = ac.Object
		local ag = a.load("b0").console
		local ah = a.load("cj")
		local ai = a.load("b4")
		local aj = a.load("b3")
		local ak = a.load("ck")
		local al = a.load("b1")
		local am = al.FundamentalComponent
		local an = a.load("b0")
		local ao = a.load("cn")
		local ap = a.load("co")
		local aq = a.load("cp")
		local ar = aq.findCurrentHostFiber
		local as = aq.findCurrentHostFiberWithNoPortals
		local au = a.load("b0").ReactInstanceMap.get
		local av = al.HostComponent
		local aw = al.ClassComponent
		local ax = al.HostRoot
		local ay = al.SuspenseComponent
		local az = a.load("b0").getComponentName
		local aA = a.load("b0").invariant
		local aC = a.load("b0").describeError
		local aD = a.load("b0").ReactFeatureFlags.enableSchedulingProfiler
		local aE = a.load("b0").ReactSharedInternals
		local aF = a.load("ck").getPublicInstance
		local aG = a.load("cr")
		local aH = aG.findCurrentUnmaskedContext
		local aI = aG.processChildContext
		local aJ = aG.emptyContextObject
		local aK = aG.isContextProvider
		local aL = a.load("cy")
		local aM = aL.createFiberRoot
		local aO = a.load("ct")
		local aP = aO.injectInternals
		local aQ = aO.onScheduleRoot
		local aS = (a.load("c4"))
		local aT = aS.act
		local aU = a.load("cx")
		local aV = aU.createUpdate
		local aW = aU.enqueueUpdate
		local aX = a.load("cR")
		local aY = aX.isRendering
		local aZ = aX.resetCurrentFiber
		local a_ = aX.setCurrentFiber
		local a0 = a.load("b2")
		local a1 = a0.StrictMode
		local a2 = ao.SyncLane
		local a3 = ao.InputDiscreteHydrationLane
		local a4 = ao.SelectiveHydrationLane
		local a6 = ao.NoTimestamp
		local a7 = ao.getHighestPriorityPendingLanes
		local a8 = ao.higherPriorityLane
		local a9 = ao.getCurrentUpdateLanePriority
		local b = ao.setCurrentUpdateLanePriority
		local ba = a.load("cB").markRenderScheduled
		local bb = {}
		bb.ReactRootTags = ai
		bb.ReactWorkTags = al
		bb.ReactTypeOfMode = a0
		bb.ReactFiberFlags = aj
		bb.getNearestMountedFiber = aq.getNearestMountedFiber
		bb.findCurrentFiberUsingSlowPath = aq.findCurrentFiberUsingSlowPath
		bb.createPortal = a.load("c5").createPortal
		local bc
		local bd
		if aa then
			bc = false
			bd = {}
		end
		local function getContextForSubtree(be)
			if not be then
				return aJ
			end
			local bf = au(be)
			local bg = aH(bf)
			if bf.tag == aw then
				local bh = bf.type
				if aK(bh) then
					return aI(bf, bh, bg)
				end
			end
			return bg
		end
		local function findHostInstance(be)
			local bf = au(be)
			if bf == nil then
				if typeof(be.render) == "function" then
					aA(false, "Unable to find node on an unmounted component.")
				else
					aA(false, "Argument appears to not be a ReactComponent. Keys: %s", table.concat(ae.keys(be)))
				end
			end
			local bg = ar(bf)
			if bg == nil then
				return nil
			end
			return bg.stateNode
		end
		local function findHostInstanceWithWarning(be, bf)
			if aa then
				local bg = au(be)
				if bg == nil then
					if typeof(be.render) == "function" then
						aA(false, "Unable to find node on an unmounted component.")
					else
						aA(false, "Argument appears to not be a ReactComponent. Keys: %s", table.concat(ae.keys(be)))
					end
				end
				local bh = ar(bg)
				if bh == nil then
					return nil
				end
				if bit32.band(bh.mode, a1) ~= 0 then
					local bi = az(bg.type) or "Component"
					if not bd[bi] then
						bd[bi] = true
						local bj = aX.current
						local bk, bl = xpcall(function()
							a_(bh)
							if bit32.band(bg.mode, a1) ~= 0 then
								ag.error(
									"%s is deprecated in StrictMode. %s was passed an instance of %s which is inside StrictMode. Instead, add a ref directly to the element you want to reference. Learn more about using refs safely here: https://reactjs.org/link/strict-mode-find-node",
									bf,
									bf,
									bi
								)
							else
								ag.error(
									"%s is deprecated in StrictMode. %s was passed an instance of %s which renders StrictMode children. Instead, add a ref directly to the element you want to reference. Learn more about using refs safely here: https://reactjs.org/link/strict-mode-find-node",
									bf,
									bf,
									bi
								)
							end
						end, aC)
						if bj then
							a_(bj)
						else
							aZ()
						end
						if not bk then
							error(bl)
						end
					end
				end
				return bh.stateNode
			end
			return findHostInstance(be)
		end
		bb.createContainer = function(be, bf, bg, bh)
			return aM(be, bf, bg, bh)
		end
		bb.updateContainer = function(be, bf, bg, bh)
			if aa then
				aQ(bf, be)
			end
			local bi = bf.current
			local bj = aS.requestEventTime()
			if aa then
				if _G.__TESTEZ_RUNNING_TEST__ then
					aS.warnIfUnmockedScheduler(bi)
					aS.warnIfNotScopedWithMatchingAct(bi)
				end
			end
			local bk = aS.requestUpdateLane(bi)
			if aD then
				ba(bk)
			end
			local bl = getContextForSubtree(bg)
			if bf.context == nil then
				bf.context = bl
			else
				bf.pendingContext = bl
			end
			if aa then
				if aY and aX.current ~= nil and not bc then
					bc = true
					ag.error(
						"Render methods should be a pure function of props and state; triggering nested component updates from render is not allowed. If necessary, trigger nested updates in componentDidUpdate.\n\nCheck the render method of %s.",
						az((aX.current).type) or "Unknown"
					)
				end
			end
			local bm = aV(bj, bk)
			if be == nil then
				be = ae.None
			end
			bm.payload = { element = be }
			if bh ~= nil then
				if aa then
					if typeof(bh) ~= "function" then
						ag.error(
							"render(...): Expected the last optional `callback` argument to be a function. Instead received: %s.",
							tostring(bh)
						)
					end
				end
				bm.callback = bh
			end
			aW(bi, bm)
			aS.scheduleUpdateOnFiber(bi, bk, bj)
			return bk
		end
		bb.batchedEventUpdates = aS.batchedEventUpdates
		bb.batchedUpdates = aS.batchedUpdates
		bb.unbatchedUpdates = aS.unbatchedUpdates
		bb.deferredUpdates = aS.deferredUpdates
		bb.discreteUpdates = aS.discreteUpdates
		bb.flushDiscreteUpdates = aS.flushDiscreteUpdates
		bb.flushControlled = aS.flushControlled
		bb.flushSync = aS.flushSync
		bb.flushPassiveEffects = aS.flushPassiveEffects
		bb.IsThisRendererActing = aS.IsThisRendererActing
		bb.act = aT
		bb.getPublicRootInstance = function(be)
			local bf = be.current
			if not bf.child then
				return nil
			end
			if bf.child.tag == av then
				return aF(bf.child.stateNode)
			else
				return bf.child.stateNode
			end
		end
		local be
		bb.attemptSynchronousHydration = function(bf)
			if bf.tag == ax then
				local bg = bf.stateNode
				if bg.hydrate then
					local bh = a7(bg)
					aS.flushRoot(bg, bh)
				end
			elseif bf.tag == ay then
				local bg = aS.requestEventTime()
				aS.flushSync(function()
					return aS.scheduleUpdateOnFiber(bf, a2, bg)
				end)
				local bh = a3
				be(bf, bh)
			end
		end
		local function markRetryLaneImpl(bf, bg)
			local bh = bf.memoizedState
			if bh then
				if bh ~= nil and bh.dehydrated ~= nil then
					bh.retryLane = a8(bh.retryLane, bg)
				end
			end
		end
		be = function(bf, bg)
			markRetryLaneImpl(bf, bg)
			local bh = bf.alternate
			if bh then
				markRetryLaneImpl(bh, bg)
			end
		end
		bb.attemptUserBlockingHydration = function(bf)
			if bf.tag ~= ay then
				return
			end
			local bg = aS.requestEventTime()
			local bh = a3
			aS.scheduleUpdateOnFiber(bf, bh, bg)
			be(bf, bh)
		end
		bb.attemptContinuousHydration = function(bf)
			if bf.tag ~= ay then
				return
			end
			local bg = aS.requestEventTime()
			local bh = a4
			aS.scheduleUpdateOnFiber(bf, bh, bg)
			be(bf, bh)
		end
		bb.attemptHydrationAtCurrentPriority = function(bf)
			if bf.tag ~= ay then
				return
			end
			local bg = aS.requestEventTime()
			local bh = aS.requestUpdateLane(bf)
			aS.scheduleUpdateOnFiber(bf, bh, bg)
			be(bf, bh)
		end
		bb.runWithPriority = function(bf, bg)
			local bh = a9()
			b(bf)
			local bi, bj = xpcall(bg, aC)
			b(bh)
			if not bi then
				error(bj)
			end
			return bj
		end
		bb.getCurrentUpdateLanePriority = a9
		bb.findHostInstance = findHostInstance
		bb.findHostInstanceWithWarning = findHostInstanceWithWarning
		bb.findHostInstanceWithNoPortals = function(bf)
			local bg = as(bf)
			if bg == nil then
				return nil
			end
			if bg.tag == am then
				return bg.stateNode.instance
			end
			return bg.stateNode
		end
		local function shouldSuspendImpl(bf)
			return false
		end
		bb.shouldSuspend = function(bf)
			return shouldSuspendImpl(bf)
		end
		local bf
		local bg
		local bh
		local bi
		local bj
		local bk
		local bl
		local bm
		if aa then
			local function copyWithDeleteImpl(bn, bo, bp)
				local bq = bo[bp]
				local br
				if ad.isArray(bn) then
					br = ad.slice(bn)
				else
					br = table.clone(bn)
				end
				if bp + 1 == #bo then
					if ad.isArray(br) then
						local bs = bq
						ad.splice(br, bs, 1)
					else
						br[bq] = nil
					end
					return br
				end
				br[bq] = copyWithDeleteImpl(bn[bq], bo, bp + 1)
				return br
			end
			local function copyWithDelete(bn, bo)
				return copyWithDeleteImpl(bn, bo, 0)
			end
			local function copyWithRenameImpl(bn, bo, bp, bq)
				local br = bo[bq]
				local bs
				if ad.isArray(bn) then
					bs = ad.slice(bn)
				else
					bs = table.clone(bn)
				end
				if bq + 1 == #bo then
					local bt = bp[bq]
					bs[bt] = bs[br]
					if ad.isArray(bs) then
						ad.splice(bs, br, 1)
					else
						bs[br] = nil
					end
				else
					bs[br] = copyWithRenameImpl(bn[br], bo, bp, bq + 1)
				end
				return bs
			end
			local function copyWithRename(bn, bo, bp)
				if #bo ~= #bp then
					ag.warn("copyWithRename() expects paths of the same length")
					return nil
				else
					for bq = 1, #bp do
						if bo[bq] ~= bp[bq] then
							ag.warn("copyWithRename() expects paths to be the same except for the deepest key")
							return nil
						end
					end
				end
				return copyWithRenameImpl(bn, bo, bp, 0)
			end
			local function copyWithSetImpl(bn, bo, bp, bq)
				if bp >= (#bo + 1) then
					return bq
				end
				local br = bo[bp]
				local bs
				if ad.isArray(bn) then
					bs = ad.slice(bn)
				else
					bs = table.clone(bn)
				end
				bs[br] = copyWithSetImpl(bn[br], bo, bp + 2, bq)
				return bs
			end
			local function copyWithSet(bn, bo, bp)
				return copyWithSetImpl(bn, bo, 1, bp)
			end
			local function findHook(bn, bo)
				local bp = bn.memoizedState
				while bp ~= nil and bo > 1 do
					bp = bp.next
					bo -= 1
				end
				return bp
			end
			bf = function(bn, bo, bp, bq)
				local br = findHook(bn, bo)
				if br ~= nil then
					local bs = copyWithSet(br.memoizedState, bp, bq)
					br.memoizedState = bs
					br.baseState = bs
					bn.memoizedProps = table.clone(bn.memoizedProps)
					aS.scheduleUpdateOnFiber(bn, a2, a6)
				end
			end
			bg = function(bn, bo, bp)
				local bq = findHook(bn, bo)
				if bq ~= nil then
					local br = copyWithDelete(bq.memoizedState, bp)
					bq.memoizedState = br
					bq.baseState = br
					bn.memoizedProps = table.clone(bn.memoizedProps)
					aS.scheduleUpdateOnFiber(bn, a2, a6)
				end
			end
			bh = function(bn, bo, bp, bq)
				local br = findHook(bn, bo)
				if br ~= nil then
					local bs = copyWithRename(br.memoizedState, bp, bq)
					br.memoizedState = bs
					br.baseState = bs
					bn.memoizedProps = table.clone(bn.memoizedProps)
					aS.scheduleUpdateOnFiber(bn, a2, a6)
				end
			end
			bi = function(bn, bo, bp)
				bn.pendingProps = copyWithSet(bn.memoizedProps, bo, bp)
				local bq = bn.alternate
				if bq then
					bq.pendingProps = bn.pendingProps
				end
				aS.scheduleUpdateOnFiber(bn, a2, a6)
			end
			bj = function(bn, bo)
				bn.pendingProps = copyWithDelete(bn.memoizedProps, bo)
				local bp = bn.alternate
				if bp then
					bp.pendingProps = bn.pendingProps
				end
				aS.scheduleUpdateOnFiber(bn, a2, a6)
			end
			bk = function(bn, bo, bp)
				bn.pendingProps = copyWithRename(bn.memoizedProps, bo, bp)
				local bq = bn.alternate
				if bq then
					bq.pendingProps = bn.pendingProps
				end
				aS.scheduleUpdateOnFiber(bn, a2, a6)
			end
			bl = function(bn)
				aS.scheduleUpdateOnFiber(bn, a2, a6)
			end
			bm = function(bn)
				shouldSuspendImpl = bn
			end
		end
		function findHostInstanceByFiber(bn)
			local bo = ar(bn)
			if bo == nil then
				return nil
			end
			return bo.stateNode
		end
		function emptyFindFiberByHostInstance(bn)
			return nil
		end
		function getCurrentFiberForDevTools()
			return aX.current
		end
		bb.injectIntoDevTools = function(bn)
			local bo = bn.findFiberByHostInstance
			local bp = aE.ReactCurrentDispatcher
			local bq
			if aa then
				bq = getCurrentFiberForDevTools
			end
			return aP({
				bundleType = bn.bundleType,
				version = bn.version,
				rendererPackageName = bn.rendererPackageName,
				rendererConfig = bn.rendererConfig,
				overrideHookState = bf,
				overrideHookStateDeletePath = bg,
				overrideHookStateRenamePath = bh,
				overrideProps = bi,
				overridePropsDeletePath = bj,
				overridePropsRenamePath = bk,
				setSuspenseHandler = bm,
				scheduleUpdate = bl,
				currentDispatcherRef = bp,
				findHostInstanceByFiber = findHostInstanceByFiber,
				findFiberByHostInstance = bo or emptyFindFiberByHostInstance,
				getCurrentFiber = bq,
			})
		end
		bb.robloxReactProfiling = a.load("cW")
		return bb
	end
	function a.c7()
		local aa = a.load("cl")
		local ab = a.load("c6")
		aa.register("ReactFiberReconciler", ab)
		return ab
	end
	function a.c8()
		local aa = a.load("cj")
		local ab = a.load("b4")
		local function initialize(ac)
			local ad = a.load("ck")
			for ae, ag in ac do
				ad[ae] = ag
			end
			return a.load("c7")
		end
		return initialize
	end
	function a.c9()
		return a.load("c8")
	end
	function a.da()
		return a.load("bG")
	end
	function a.db()
		local aa = a.load("c9")
		local ab = a.load("da")
		return {}
	end
	function a.dc()
		return a.load("a0")
	end
	function a.dd()
		local aa = {}
		return {
			register = function(ab, ac)
				aa[ab] = ac
			end,
			get = function(ab)
				return aa[ab]
			end,
			lazy = function(ab)
				return setmetatable({}, {
					__index = function(ac, ad)
						local ae = aa[ab]
						if ae then
							return ae[ad]
						end
						return nil
					end,
					__newindex = function(ac, ad, ae)
						local ag = aa[ab]
						if ag then
							ag[ad] = ae
						end
					end,
				})
			end,
		}
	end
	function a.de()
		return a.load("bY")
	end
	function a.df()
		local aa = a.load("da").console
		local ab = "Change."
		local ac = { Disabled = "Disabled", Suspended = "Suspended", Enabled = "Enabled" }
		local ad = {}
		ad.__index = ad
		function ad.new(ae)
			local ag = setmetatable(
				{
					_suspendedEventQueue = {},
					_connections = {},
					_listeners = {},
					_status = ac.Disabled,
					_isResuming = false,
					_instance = ae,
				},
				ad
			)
			return ag
		end
		function ad:connectEvent(ae, ag)
			self._connect(self, ae, self._instance[ae], ag)
		end
		function ad:connectPropertyChange(ae, ag)
			local ah, ai = pcall(self._instance.GetPropertyChangedSignal, self._instance, ae)
			if not ah then
				error(string.format("Cannot get changed signal on property %q: %s", tostring(ae), ai), 0)
			end
			self._connect(self, ab .. ae, ai, ag)
		end
		function ad:_connect(ae, ag, ah)
			if ah == nil then
				if self._connections[ae] ~= nil then
					self._connections[ae]:Disconnect()
					self._connections[ae] = nil
				end
				self._listeners[ae] = nil
			else
				if self._connections[ae] == nil then
					self._connections[ae] = ag.Connect(ag, function(...)
						if self._status == ac.Enabled then
							self._listeners[ae](self._instance, ...)
						elseif self._status == ac.Suspended then
							local ai = select("#", ...)
							table.insert(self._suspendedEventQueue, {
								ae,
								ai,
								...,
							})
						end
					end)
				end
				self._listeners[ae] = ah
			end
		end
		function ad:suspend()
			self._status = ac.Suspended
		end
		function ad:resume()
			if self._isResuming then
				return
			end
			self._isResuming = true
			for ae, ag in self._suspendedEventQueue do
				local ah = self._listeners[ag[1]]
				local ai = ag[2]
				if ah ~= nil then
					local aj = coroutine.create(ah)
					local ak, al = coroutine.resume(aj, self._instance, unpack(ag, 3, 2 + ai))
					if not ak then
						aa.warn("%s", al)
					end
				end
			end
			self._isResuming = false
			self._status = ac.Enabled
			table.clear(self._suspendedEventQueue)
		end
		return ad
	end
	function a.dg()
		local aa = a.load("da").Symbol
		local ab = aa.named("Nil")
		local ac = {}
		local function tryPropertyName(ad, ae)
			return ad[ae]
		end
		local function getDefaultInstanceProperty(ad, ae)
			local ag = ac[ad]
			if ag then
				local ah = ag[ae]
				if ah == ab then
					return true, nil
				end
				if ah ~= nil then
					return true, ah
				end
			else
				ag = {}
				ac[ad] = ag
			end
			local ah = Instance.new(ad)
			local ai, aj = pcall(tryPropertyName, ah, ae)
			ah.Destroy(ah)
			if ai then
				if aj == nil then
					ag[ae] = ab
				else
					ag[ae] = aj
				end
			end
			return ai, aj
		end
		return getDefaultInstanceProperty
	end
	function a.dh()
		local aa = _G.__DEV__
		local ab = cloneref(game.GetService(game, "CollectionService"))
		local ac = a.load("dc")
		local ad = ac.Object
		local ae = ac.util.inspect
		local ag = a.load("da").console
		local ah = a.load("de")
		local ai = a.load("da").ReactSymbols
		local aj = a.load("df")
		local ak = a.load("da").Type
		local al = a.load("dg")
		local am = a.load("db")
		local an = a.load("de").Tag
		local ao = {}
		local ap = {}
		local aq = "Error applying initial props to Roblox Instance '%s' (%s):\n  %s\n"
		local ar = "Error updating props on Roblox Instance '%s' (%s):\n  %s\n"
		local as =
			"Error updating binding or ref assigned to key %s of '%s' (%s).\n\nUpdated value:\n  %s\n\nError:\n  %s\n\n%s\n"
		local function identity(...)
			return ...
		end
		local function setRobloxInstanceProperty(au, av, aw)
			if aw == nil then
				local ax, ay = pcall(au.ResetPropertyToDefault, au, av)
				if ax then
					return
				end
				local az = au.ClassName
				local aA, aC = al(az, av)
				aw = aC
			end
			au[av] = aw
		end
		local function removeBinding(au, av)
			local aw = ap[au]
			if aw ~= nil then
				local ax = aw[av]
				ax()
				aw[av] = nil
			end
		end
		local function attachBinding(au, av, aw)
			local function updateBoundProperty(ax)
				local az, aA = xpcall(setRobloxInstanceProperty, identity, au, av, ax)
				if not az then
					local aC = aw._source or "<enable DEV mode for stack>"
					local aD = string.format(as, av, au.Name, au.ClassName, tostring(ax), aA, aC)
					ag.error(aD)
					error(aD, 0)
				end
			end
			if ap[au] == nil then
				ap[au] = {}
			end
			ap[au][av] = ah.__subscribeToBinding(aw, updateBoundProperty)
			updateBoundProperty(aw.getValue(aw))
		end
		local function applyTags(au, av, aw)
			if aa then
				if aw ~= nil and typeof(aw) ~= "string" then
					ag.error(
						"Type provided for ReactRoblox.Tag is invalid - tags should be specified as a single string, with individual tags delimited by spaces. Instead received:\n%s",
						ae(aw)
					)
					return
				end
			end
			local ax = {}
			for az in string.gmatch(av or "", "%S+") do
				ax[az] = true
			end
			local az = {}
			for aA in string.gmatch(aw or "", "%S+") do
				az[aA] = true
			end
			for aA, aC in ax do
				if not az[aA] then
					ab.RemoveTag(ab, au, aA)
				end
			end
			for aA, aC in az do
				if not ax[aA] then
					ab.AddTag(ab, au, aA)
				end
			end
		end
		local function removeAllTags(au)
			for av, aw in ab.GetTags(ab, au) do
				ab.RemoveTag(ab, au, aw)
			end
		end
		local function applyProp(au, av, aw, ax)
			local az = ak.of(av)
			if az == ak.HostEvent or az == ak.HostChangeEvent then
				local aA = ao[au]
				if aA == nil then
					aA = (aj.new(au))
					ao[au] = aA
				end
				local aC = av.name
				if az == ak.HostChangeEvent then
					aA.connectPropertyChange(aA, aC, aw)
				else
					aA.connectEvent(aA, aC, aw)
				end
				return
			end
			local aA = typeof(aw) == "table" and aw["$$typeof"] == ai.REACT_BINDING_TYPE
			local aC = ax ~= nil and typeof(ax) == "table" and ax["$$typeof"] == ai.REACT_BINDING_TYPE
			if aC then
				removeBinding(au, av)
			end
			if aA then
				attachBinding(au, av, aw)
			elseif av == an then
				applyTags(au, ax, aw)
			else
				setRobloxInstanceProperty(au, av, aw)
			end
		end
		local function applyProps(au, av)
			for aw, ax in av do
				if aw == "ref" or aw == "children" then
					continue
				end
				applyProp(au, aw, ax)
			end
		end
		local function setInitialProperties(au, av, aw, ax)
			local az, aA = xpcall(applyProps, identity, au, aw)
			if not az then
				local aC = string.format(aq, au.Name, au.ClassName, aA)
				ag.error(aC)
				error(aC, 0)
			end
			if ao[au] ~= nil then
				ao[au]:resume()
			end
		end
		local function safelyApplyProperties(au, av, aw)
			local ax = #av
			for az = 1, ax, 2 do
				local aA = av[az]
				local aC = av[az + 1]
				if aC == ad.None then
					aC = nil
				end
				if aA ~= "ref" and aA ~= "children" then
					applyProp(au, aA, aC, aw[aA])
				end
			end
		end
		local function updateProperties(au, av, aw)
			if ao[au] ~= nil then
				ao[au]:suspend()
			end
			local ax, az = xpcall(safelyApplyProperties, identity, au, av, aw)
			if not ax then
				local aA = string.format(ar, au.Name, au.ClassName, az)
				ag.error(aA)
				error(aA, 0)
			end
			if ao[au] ~= nil then
				ao[au]:resume()
			end
		end
		local function cleanupBindings(au)
			local av = ap[au]
			if av ~= nil then
				for aw, ax in av do
					ax()
				end
				ap[au] = nil
			end
		end
		local function cleanupHostComponent(au)
			if ao[au] ~= nil then
				ao[au] = nil
			end
			cleanupBindings(au)
			if typeof(au) ~= "Instance" then
				return
			end
			removeAllTags(au)
			for av, aw in au.GetDescendants(au) do
				if ao[aw] ~= nil then
					ao[aw] = nil
				end
				cleanupBindings(aw)
				removeAllTags(au)
			end
		end
		return {
			setInitialProperties = setInitialProperties,
			updateProperties = updateProperties,
			cleanupHostComponent = cleanupHostComponent,
			_instanceToEventManager = ao,
			_instanceToBindings = ap,
		}
	end
	function a.di()
		local aa = a.load("dc")
		local ab = aa.Object
		local ac = a.load("dh")
		local ad = a.load("db")
		local ae = {}
		ae.setInitialProperties = ac.setInitialProperties
		local function diffProperties(ag, ah, ai, aj, ak)
			local al
			local am = ai
			local an = aj
			for ao, ap in am do
				if an[ao] ~= nil then
					continue
				end
				al = al or table.create(2)
				table.insert(al, ao)
				table.insert(al, ab.None)
			end
			for ao, ap in an do
				local aq = if am ~= nil then am[ao] else nil
				if ap == aq then
					continue
				end
				al = al or table.create(2)
				table.insert(al, ao)
				table.insert(al, ap)
			end
			return al
		end
		ae.diffProperties = diffProperties
		ae.updateProperties = ac.updateProperties
		ae.cleanupHostComponent = ac.cleanupHostComponent
		return ae
	end
	function a.dj()
		local function unimplemented(aa)
			print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
			print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
			print("UNIMPLEMENTED ERROR: " .. tostring(aa))
			error("FIXME (roblox): " .. aa .. " is unimplemented", 2)
		end
		local aa = cloneref(game.GetService(game, "CollectionService"))
		local ab = a.load("dc")
		local ac = ab.util.inspect
		local ad = a.load("da").console
		local ae = ab.Object
		local ag = ab.setTimeout
		local ah = ab.clearTimeout
		local ai = a.load("db")
		local aj = a.load("dd")
		local ak = aj.lazy("ReactRobloxComponentTree")
		local al = a.load("di")
		local am = al.setInitialProperties
		local an = al.diffProperties
		local ao = al.updateProperties
		local ap = al.cleanupHostComponent
		local aq = a.load("da").ReactFeatureFlags
		local ar = aq.enableCreateEventHandleAPI
		local function recursivelyUncacheFiberNode(as)
			if typeof(as) ~= "Instance" then
				return
			end
			ak.uncacheFiberNode(as)
			for au, av in as.GetDescendants(as) do
				ak.uncacheFiberNode(av)
			end
		end
		local as = {}
		ae.assign(as, a.load("da").ReactFiberHostConfig.WithNoPersistence)
		as.getRootHostContext = function(au)
			return au.ClassName
		end
		as.getChildHostContext = function(au, av, aw)
			return au
		end
		as.getPublicInstance = function(au)
			return au
		end
		as.prepareForCommit = function(au)
			local av
			if ar then
				unimplemented("enableCreateEventHandleAPI")
			end
			return av
		end
		as.beforeActiveInstanceBlur = function()
			if ar then
				unimplemented("enableCreateEventHandleAPI")
			end
		end
		as.afterActiveInstanceBlur = function()
			if ar then
				unimplemented("enableCreateEventHandleAPI")
			end
		end
		as.resetAfterCommit = function(au) end
		as.createInstance = function(au, av, aw, ax, az)
			local aA = Instance.new(au)
			if az.key then
				aA.Name = az.key
			else
				local aC = az.return_
				while aC do
					if aC.key then
						aA.Name = aC.key
						break
					end
					aC = aC.return_
				end
			end
			ak.precacheFiberNode(az, aA)
			ak.updateFiberProps(aA, av)
			return aA
		end
		as.appendInitialChild = function(au, av)
			av.Parent = au
		end
		as.finalizeInitialChildren = function(au, av, aw, ax, az)
			am(au, av, aw, ax)
			return false
		end
		local function prepareUpdate(au, av, aw, ax, az, aA)
			return an(au, av, aw, ax, az)
		end
		as.prepareUpdate = prepareUpdate
		as.shouldSetTextContent = function(au, av)
			return false
		end
		as.createTextInstance = function(au, av, aw, ax)
			unimplemented("createTextInstance")
			return nil
		end
		as.isPrimaryRenderer = true
		as.warnsIfNotActing = true
		as.scheduleTimeout = ag
		as.cancelTimeout = ah
		as.noTimeout = -1
		as.supportsMutation = true
		as.commitMount = function(au, av, aw, ax)
			unimplemented("commitMount")
		end
		as.commitUpdate = function(au, av, aw, ax, az, aA)
			ak.updateFiberProps(au, az)
			ao(au, av, ax)
		end
		local function checkTags(au)
			if typeof(au) ~= "Instance" then
				ad.warn("Could not check tags on non-instance %s.", ac(au))
				return
			end
			if not au.IsDescendantOf(au, game) then
				if #aa.GetTags(aa, au) > 0 then
					ad.warn(
						'Tags applied to orphaned %s "%s" cannot be accessed via CollectionService:GetTagged. If you\'re relying on tag behavior in a unit test, consider mounting your test root into the DataModel.',
						au.ClassName,
						au.Name
					)
				end
			end
		end
		as.appendChild = function(au, av)
			av.Parent = au
			if _G.__DEV__ then
				checkTags(av)
			end
		end
		as.appendChildToContainer = function(au, av)
			local aw = au
			as.appendChild(aw, av)
		end
		as.insertBefore = function(au, av, aw)
			av.Parent = au
			if _G.__DEV__ then
				checkTags(av)
			end
		end
		as.insertInContainerBefore = function(au, av, aw)
			local ax = au
			as.insertBefore(ax, av, aw)
		end
		as.removeChild = function(au, av)
			recursivelyUncacheFiberNode(av)
			ap(av)
			av.Parent = nil
			av.Destroy(av)
		end
		as.removeChildFromContainer = function(au, av)
			as.removeChild(au, av)
		end
		as.clearSuspenseBoundary = function(au, av)
			unimplemented("clearSuspenseBoundary")
		end
		as.clearSuspenseBoundaryFromContainer = function(au, av)
			unimplemented("clearSuspenseBoundaryFromContainer")
		end
		as.hideInstance = function(au)
			unimplemented("hideInstance")
		end
		as.hideTextInstance = function(au)
			unimplemented("hideTextInstance")
		end
		as.unhideInstance = function(au, av)
			unimplemented("unhideInstance")
		end
		as.unhideTextInstance = function(au, av)
			unimplemented("unhideTextInstance")
		end
		as.clearContainer = function(au)
			local av = au
			for aw, ax in av.GetChildren(av) do
				as.removeChild(av, ax)
			end
		end
		as.preparePortalMount = function(au) end
		return as
	end
	function a.dk()
		local aa = a.load("db")
		local ab = a.load("c9")
		local ac = a.load("da")
		local ad
		local ae
		local ag
		local ah
		local ai
		local aj
		local ak = ac.invariant
		local al = {}
		local am = {}
		local an = {}
		local ao = {}
		local ap = string.sub(tostring(math.random()), 3)
		local aq = "__reactFiber$" .. ap
		local ar = "__reactContainer$" .. ap
		al.precacheFiberNode = function(as, au)
			an[au] = as
		end
		al.uncacheFiberNode = function(as)
			an[as] = nil
			ao[as] = nil
		end
		al.markContainerAsRoot = function(as, au)
			am[au] = as
		end
		al.unmarkContainerAsRoot = function(as)
			am[as] = nil
		end
		al.isContainerMarkedAsRoot = function(as)
			return not not am[as]
		end
		al.getClosestInstanceFromNode = function(as)
			local au = an[as]
			if au then
				return au
			end
			local av = as.Parent
			while av do
				au = an[av]
				if au then
					local aw = au.alternate
					if au.child ~= nil or (aw ~= nil and aw.child ~= nil) then
						if aj == nil then
							aj = ((a.load("dj"))).getParentSuspenseInstance
						end
						local ax = aj(as)
						while ax ~= nil do
							local az = an[ax]
							if az then
								return az
							end
							ax = aj(ax)
						end
					end
					return au
				end
				as = av
				av = as.Parent
			end
			return nil
		end
		al.getInstanceFromNode = function(as)
			if ad == nil then
				local au = a.load("dd")
				local av = au.lazy("ReactReconciler")
				ad = av.ReactWorkTags
				ae = ad.HostComponent
				ag = ad.HostComponent
				ah = ad.HostComponent
				ai = ad.HostComponent
			end
			local au = (as)[aq] or (as)[ar]
			if au then
				if au.tag == ae or au.tag == ag or au.tag == ai or au.tag == ah then
					return au
				else
					return nil
				end
			end
			return nil
		end
		al.getNodeFromInstance = function(as)
			if as.tag == ae or as.tag == ag then
				return as.stateNode
			end
			ak(false, "getNodeFromInstance: Invalid argument.")
			error("getNodeFromInstance: Invalid argument.")
		end
		al.getFiberCurrentPropsFromNode = function(as)
			return ao[as]
		end
		al.updateFiberProps = function(as, au)
			ao[as] = au
		end
		local as = a.load("dd")
		local au = al
		as.register("ReactRobloxComponentTree", au)
		return au
	end
	function a.dl()
		local aa = a.load("c9")
		local ab = a.load("dj")
		local ac = aa(ab)
		local ad = a.load("dd")
		ad.register("ReactReconciler", ac)
		return ac
	end
	function a.dm()
		local aa = a.load("db")
		local ab = a.load("c9")
		local ac = a.load("da")
		local ad = a.load("c9")
		local ae = a.load("dk")
		local ag = a.load("dl")
		local ah = a.load("da").invariant
		local ai = a.load("da").ReactFeatureFlags.enableEagerRootListeners
		local aj = ag.ReactRootTags.BlockingRoot
		local ak = ag.ReactRootTags.ConcurrentRoot
		local am = ag.ReactRootTags.LegacyRoot
		local an
		local ao = {}
		ao.__index = ao
		function ao.new(ap, aq)
			local ar = (setmetatable({}, ao))
			ar._internalRoot = an(ap, ak, aq)
			return ar
		end
		local function createBlockingRoot(ap, aq, ar)
			local as = (setmetatable({}, ao))
			as._internalRoot = an(ap, aq, ar)
			return as
		end
		function ao:render(ap)
			local aq = self._internalRoot
			ag.updateContainer(ap, aq, nil)
		end
		function ao:unmount()
			local ap = self._internalRoot
			local aq = ap.containerInfo
			ag.flushSync(function()
				ag.updateContainer(nil, ap, nil, function()
					ae.unmarkContainerAsRoot(aq)
				end)
			end)
			ag.flushPassiveEffects()
		end
		an = function(ap, aq, ar)
			local as = ar ~= nil and ar.hydrate == true
			local au = if ar ~= nil then ar.hydrationOptions else nil
			local av = (ar ~= nil and ar.hydrationOptions ~= nil and ar.hydrationOptions.mutableSources) or nil
			local aw = ag.createContainer(ap, aq, as, au)
			ae.markContainerAsRoot(aw.current, ap)
			if ai then
			end
			if av then
			end
			return aw
		end
		local ap = {}
		local function isValidContainer(aq)
			return typeof(aq) == "Instance"
		end
		ap.isValidContainer = isValidContainer
		ap.createRoot = function(aq, ar)
			ah(isValidContainer(aq), "createRoot(...): Target container is not a Roblox Instance.")
			warnIfReactDOMContainerInDEV(aq)
			return ao.new(aq, ar)
		end
		ap.createBlockingRoot = function(aq, ar)
			ah(isValidContainer(aq), "createRoot(...): Target container is not a Roblox Instance.")
			warnIfReactDOMContainerInDEV(aq)
			return createBlockingRoot(aq, aj, ar)
		end
		ap.createLegacyRoot = function(aq, ar)
			return createBlockingRoot(aq, am, ar)
		end
		function warnIfReactDOMContainerInDEV(aq)
			if _G.__DEV__ then
			end
		end
		return ap
	end
	function a.dn()
		local aa = a.load("da")
		local ab = a.load("db")
		local ac
		ac = a.load("dm")
		local ad = ac.createRoot
		local ae = ac.createBlockingRoot
		local ag = ac.createLegacyRoot
		local ah = ac.isValidContainer
		local ai = a.load("dl")
		local aj = ai.batchedUpdates
		local ak = ai.flushSync
		local am = ai.injectIntoDevTools
		local an = ai.flushPassiveEffects
		local ao = ai.IsThisRendererActing
		local ap = ai.createPortal
		local aq = a.load("da").ReactVersion
		local ar = a.load("da").invariant
		local as = a.load("da").ReactFeatureFlags
		local au = as.enableNewReconciler
		local av = a.load("dk")
		local aw = a.load("da").Event
		local ax = a.load("da").Change
		local az = a.load("da").Tag
		local function createPortal(aA, aC, aD)
			ar(ah(aC), "Target container is not a Roblox Instance.")
			return ap(aA, aC, nil, aD)
		end
		local aA = {
			Events = {
				getInstanceFromNode = av.getInstanceFromNode,
				getNodeFromInstance = av.getNodeFromInstance,
				getFiberCurrentPropsFromNode = av.getFiberCurrentPropsFromNode,
				flushPassiveEffects = an,
				IsThisRendererActing = ao,
			},
		}
		local aC = {
			createPortal = createPortal,
			unstable_batchedUpdates = aj,
			flushSync = ak,
			__SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED = aA,
			version = aq,
			createRoot = ad,
			createBlockingRoot = ae,
			createLegacyRoot = ag,
			Event = aw,
			Change = ax,
			Tag = az,
			unstable_isNewReconciler = au,
			act = function(aC)
				error("ReactRoblox.act is only available in testing environments, not production. Enable the `__ROACT_17_MOCK_SCHEDULER__` global in your test configuration in order to use `act`.")
			end,
		}
		if _G.__ROACT_17_MOCK_SCHEDULER__ then
			aC.act = ai.act
		end
		local aD = am({
			findFiberByHostInstance = av.getClosestInstanceFromNode,
			bundleType = if _G.__DEV__ then 1 else 0,
			version = aq,
			rendererPackageName = "ReactRoblox",
		})
		if _G.__DEV__ then
		end
		aC.robloxReactProfiling = ai.robloxReactProfiling
		return aC
	end
	function a.dp()
		local aa = a.load("db")
		return a.load("dn")
	end
	function a.dq()
		local aa = a.load("dp")
		return aa
	end
	function a.dr()
		local function merge(aa, ab)
			local ac = aa
			for ad, ae in ab do
				if aa[ad] == ae then
					continue
				end
				if ac == aa then
					ac = table.clone(aa)
				end
				ac[ad] = ae
			end
			return ac
		end
		return merge
	end
	function a.ds()
		local function f(aa)
			return if aa >= 0.0031308 then 1.055 * aa ^ 0.4166666666666667 - 0.055 else 12.92 * aa
		end
		local function fInv(aa)
			return if aa >= 0.04045 then ((aa + 0.055) / 1.055) ^ 2.4 else aa / 12.92
		end
		local function cbrt(aa)
			return if aa >= 0 then aa ^ 0.3333333333333333 else -(-aa) ^ 0.3333333333333333
		end
		local function fromSRGB(aa)
			local ab = vector.create(fInv(aa.x), fInv(aa.y), fInv(aa.z))
			local ac = vector.create(
				cbrt(vector.dot(vector.create(0.4122214708, 0.5363325363, 0.0514459929), ab)),
				cbrt(vector.dot(vector.create(0.2119034982, 0.6806995451, 0.1073969566), ab)),
				cbrt(vector.dot(vector.create(0.0883024619, 0.2817188376, 0.6299787005), ab))
			)
			return vector.create(
				vector.dot(vector.create(0.2104542553, 0.793617785, -4.0720468E-3), ac),
				vector.dot(vector.create(1.9779984951, -2.428592205, 0.4505937099), ac),
				vector.dot(vector.create(0.0259040371, 0.7827717662, -0.808675766), ac)
			)
		end
		local function toSRGB(aa)
			local ab = vector.create(
				vector.dot(vector.create(1, 0.3963377774, 0.2158037573), aa),
				vector.dot(vector.create(1, -0.1055613458, -6.3854172799999995E-2), aa),
				vector.dot(vector.create(1, -8.94841775E-2, -1.291485548), aa)
			)
			local ac = ab * ab * ab
			local ad = vector.create(
				vector.dot(vector.create(4.0767416621, -3.3077115913, 0.2309699292), ac),
				vector.dot(vector.create(-1.2684380046, 2.6097574011, -0.3413193965), ac),
				vector.dot(vector.create(-4.1960863E-3, -0.7034186147, 1.707614701), ac)
			)
			return vector.create(f(ad.x), f(ad.y), f(ad.z))
		end
		return { fromSRGB = fromSRGB, toSRGB = toSRGB }
	end
	function a.dt()
		local aa = a.load("dr")
		local ab = a.load("ds")
		local ac = {
			number = function(ac, ad)
				ac[1] = ad
			end,
			vector = function(ac, ad)
				ac[1] = ad
			end,
			Vector3 = function(ac, ad)
				ac[1] = ad
			end,
			table = function(ac, ad)
				for ae, ag in ad do
					ac[ae] = ag
				end
			end,
			Vector2 = function(ac, ad)
				ac[1] = vector.create(ad.X, ad.Y, 0)
			end,
			CFrame = function(ac, ad)
				ac[1] = ad.Position
				ac[2] = ad.XVector
				ac[3] = ad.YVector
				ac[4] = ad.ZVector
			end,
			Color3 = function(ac, ad)
				ac[1] = ab.fromSRGB(vector.create(ad.R, ad.G, ad.B))
			end,
			UDim = function(ac, ad)
				ac[1] = vector.create(ad.Scale, ad.Offset, 0)
			end,
			UDim2 = function(ac, ad)
				ac[1] = vector.create(ad.X.Scale, ad.X.Offset, ad.Y.Scale)
				ac[2] = ad.Y.Offset
			end,
			Rect = function(ac, ad)
				ac[1] = vector.create(ad.Min.X, ad.Min.Y, ad.Max.X)
				ac[2] = ad.Max.Y
			end,
		}
		local ad = {
			number = function(ad)
				return ad[1]
			end,
			vector = function(ad)
				return ad[1]
			end,
			Vector3 = function(ad)
				return ad[1]
			end,
			table = function(ad)
				return table.clone(ad)
			end,
			Vector2 = function(ad)
				local ae = ad[1]
				return Vector2.new(ae.x, ae.y)
			end,
			CFrame = function(ad)
				return CFrame.fromMatrix(ad[1], ad[2], ad[3], ad[4]):Orthonormalize()
			end,
			Color3 = function(ad)
				local ae = vector.max(ab.toSRGB(ad[1]), vector.zero)
				return Color3.new(ae.x, ae.y, ae.z)
			end,
			UDim = function(ad)
				local ae = ad[1]
				return UDim.new(ae.x, math.round(ae.y))
			end,
			UDim2 = function(ad)
				local ae = ad[1]
				local ag = ad[2]
				return UDim2.new(ae.x, math.round(ae.y), ae.z, math.round(ag))
			end,
			Rect = function(ad)
				local ae = ad[1]
				local ag = ad[2]
				return Rect.new(ae.x, ae.y, ae.z, ag)
			end,
		}
		local function create(ae)
			local ag = typeof(ae)
			local ah = {}
			local ai = ac[ag]
			local aj = ad[ag]
			if not ai or not aj then
				error(`Unsupported type {ag} for Ripple animation value`)
			end
			ai(ah, ae)
			return { components = ah, value = ae, encode = ai, decode = aj }
		end
		local function copy(ae)
			return { components = table.clone(ae.components), value = ae.value, encode = ae.encode, decode = ae.decode }
		end
		local function zero(ae)
			local ag = ae.components
			for ah in ag do
				ag[ah] *= 0
			end
			ae.dirty = true
			return ae
		end
		local function recomputeValue(ae)
			local ag = ae.decode(ae.components)
			ae.value = ag
			ae.dirty = nil
			return ag
		end
		local function getValue(ae)
			return if ae.dirty then recomputeValue(ae) else ae.value
		end
		local function setValue(ae, ag)
			local ah = getValue(ae)
			if type(ag) == "table" then
				ag = aa(ah, ag)
			end
			if ag == ah then
				return false
			end
			ae.encode(ae.components, ag)
			ae.value = ag
			ae.dirty = nil
			return true
		end
		local function addValue(ae, ag)
			local ah = {}
			ae.encode(ah, ag)
			for ai, aj in ah do
				ae.components[ai] += aj
			end
			ae.dirty = true
		end
		local function assign(ae, ag)
			for ah, ai in ag.components do
				ae.components[ah] = ai
			end
			ae.value = getValue(ag)
			ae.dirty = nil
		end
		local function lerp(ae, ag, ah, ai)
			for aj, ak in ah.components do
				local am = ag.components[aj]
				ae.components[aj] = am + (ak - am) * ai
			end
			ae.dirty = true
		end
		return {
			create = create,
			copy = copy,
			zero = zero,
			setValue = setValue,
			addValue = addValue,
			getValue = getValue,
			recomputeValue = recomputeValue,
			assign = assign,
			lerp = lerp,
		}
	end
	function a.du()
		local aa = cloneref or function(aa)
			return aa
		end
		local function scheduler(ab, ac)
			local ad = {}
			local ae = 0
			local ag
			local function remove(ah)
				local ai = table.find(ad, ah)
				if ai then
					ad[ai] = ad[ae]
					ad[ae] = nil
					ae -= 1
				end
			end
			local function step(ah)
				for ai = ae, 1, -1 do
					ac(ad[ai], ah, remove)
				end
			end
			local function update(ah, ai)
				return ac(ah, ai, remove)
			end
			local function add(ah)
				if table.find(ad, ah) then
					return
				end
				table.insert(ad, ah)
				ae += 1
				if not game or ag then
					return
				end
				ag = aa(game.GetService(game, "RunService")).Heartbeat:Connect(function(ai)
					step(ai)
					if ag and ae == 0 then
						ag.Disconnect(ag)
						ag = nil
					end
				end)
			end
			local function clear()
				table.clear(ad)
				ae = 0
			end
			return { states = ad, update = update, step = step, add = add, remove = remove, clear = clear }
		end
		return scheduler
	end
	function a.dv()
		local aa
		local function run(ab, ac, ...)
			aa = nil
			ac(...)
			aa = ab
		end
		local function runner()
			while true do
				run(coroutine.yield())
			end
		end
		local function spawn(ab, ...)
			local ac = aa or task.spawn(runner)
			task.spawn(ac, ac, ab, ...)
		end
		local function call(ab, ...)
			ab(...)
		end
		return (if task then spawn else call)
	end
	function a.dw()
		local aa = a.load("dv")
		local function signal()
			local ab = {}
			local ac = 0
			local function subscribe(ad)
				table.insert(ab, ad)
				ac += 1
				return function()
					local ae = table.find(ab, ad)
					if ae then
						ab[ae] = ab[ac]
						ab[ac] = nil
						ac -= 1
					end
				end
			end
			local function fire(...)
				for ad = ac, 1, -1 do
					aa(ab[ad], ...)
				end
			end
			return subscribe, fire
		end
		return signal
	end
	function a.dx()
		return {}
	end
	function a.dy()
		local aa = a.load("dt")
		local ab = a.load("du")
		local ac = a.load("dw")
		local ad = a.load("dx")
		local ae = aa.getValue
		local ag = aa.recomputeValue
		local ah = 1e-3
		local ai = 62.5
		local aj = {};
		(aj).__index = aj
		local function belowThreshold(ak, am)
			if type(ak) == "number" then
				return math.abs(ak) <= am
			else
				local an = vector.abs(ak)
				return math.max(an.x, an.y, an.z) <= am
			end
		end
		local ak = ab("Spring", function(ak, am, an)
			if ak.complete then
				an(ak)
				return ae(ak.position)
			end
			local ao = ak.position
			local ap = ak.velocity
			local aq = ak.goal
			local ar = ak.restPosition
			local as = ak.restVelocity
			local au = ak.dampingRatio
			local av = ak.frequency * 2 * math.pi
			local aw = math.exp(-am * au * av)
			local ax = true
			local az = ao.components
			local aA = ap.components
			local aC = aq.components
			if au == 1 then
				for aD, aE in az do
					local aF = aA[aD]
					local aG = aC[aD]
					local aH = aE - aG
					local aI = (aF * am + aH * (av * am + 1)) * aw + aG
					local aJ = (aF - av * am * (aH * av + aF)) * aw
					if ax then
						ax = belowThreshold(aI - aG, ar) and belowThreshold(aJ, as)
					end
					az[aD] = aI
					aA[aD] = aJ
				end
			elseif au < 1 then
				local aD = (1 - au * au) ^ 0.5
				local aE = math.cos(av * aD * am)
				local aF = math.sin(av * aD * am)
				local aG
				if aD > 1e-4 then
					aG = aF / aD
				else
					local aH = am * av
					aG = aH + ((aH * aH) * (aD * aD) * (aD * aD) / 20 - aD * aD) * (aH * aH * aH) / 6
				end
				local aH
				if av * aD > 1e-4 then
					aH = aF / (av * aD)
				else
					local aI = av * aD
					aH = am + ((am * am) * (aI * aI) * (aI * aI) / 20 - aI * aI) * (am * am * am) / 6
				end
				for aI, aJ in az do
					local aK = aA[aI]
					local aL = aC[aI]
					local aM = aJ - aL
					local aO = (aM * (aE + au * aG) + aK * aH) * aw + aL
					local aP = (aK * (aE - aG * au) - aM * (aG * av)) * aw
					if ax then
						ax = belowThreshold(aO - aL, ar) and belowThreshold(aP, as)
					end
					az[aI] = aO
					aA[aI] = aP
				end
			else
				local aD = math.sqrt(au * au - 1)
				local aE = -av * (au - aD)
				local aF = -av * (au + aD)
				local aG = math.exp(aE * am)
				local aH = math.exp(aF * am)
				for aI, aJ in az do
					local aK = aA[aI]
					local aL = aC[aI]
					local aM = aJ - aL
					local aO = (aK - aM * aE) / (2 * av * aD)
					local aP = aG * (aM - aO)
					local aQ = aP + aO * aH + aL
					local aS = aP * aE + aO * aH * aF
					if ax then
						ax = belowThreshold(aQ - aL, ar) and belowThreshold(aS, as)
					end
					az[aI] = aQ
					aA[aI] = aS
				end
			end
			local aD = if not ax then ag(ao) else ae(aq)
			ap.dirty = true
			ak.complete = ax
			ak.fireChange(aD, am)
			if ax then
				an(ak)
				aa.assign(ao, aq)
				aa.zero(ap)
				ak.fireComplete(aD)
			end
			return aD
		end)
		local function createSpring(am, an)
			local ao = an or {}
			local ap = aa.create(ao.position or am)
			local aq, ar = ac()
			local as, au = ac()
			local av = {
				position = ap,
				velocity = aa.zero(aa.copy(ap)),
				goal = aa.copy(ap),
				dampingRatio = 1,
				frequency = 1,
				restPosition = ah,
				restVelocity = ah * ai,
				started = false,
				complete = true,
				onChange = aq,
				fireChange = ar,
				onComplete = as,
				fireComplete = au,
			}
			local aw = (setmetatable({ state = av }, aj))
			aw.configure(aw, ao)
			if ao.start then
				aw.start(aw)
			end
			return aw
		end
		function aj:scheduleUpdate()
			self.state.complete = false
			if self.state.started then
				ak.add(self.state)
			end
		end
		function aj:start()
			self.state.started = true
			if not self.state.complete then
				ak.add(self.state)
			end
		end
		function aj:stop()
			self.state.started = false
			ak.remove(self.state)
		end
		function aj:idle()
			return self.state.complete
		end
		function aj:step(am)
			return ak.update(self.state, am)
		end
		function aj:configure(am)
			local an = self.state
			an.restPosition = am.precision or an.restPosition
			an.restVelocity = am.restVelocity or an.restPosition * ai
			if am.dampingRatio or am.frequency then
				an.dampingRatio = am.dampingRatio or an.dampingRatio
				an.frequency = am.frequency or an.frequency
			else
				local ao = am.tension or 170
				local ap = am.friction or 26
				local aq = am.mass or 1
				an.dampingRatio = ap / (2 * (aq * ao) ^ 0.5)
				an.frequency = (ao / aq) ^ 0.5 / 2 / math.pi
			end
			if am.velocity then
				self.setVelocity(self, am.velocity)
			end
			if am.impulse then
				self.impulse(self, am.impulse)
			end
			if am.position then
				self.setPosition(self, am.position)
			end
		end
		function aj:getPosition()
			return aa.getValue(self.state.position)
		end
		function aj:getVelocity()
			return aa.getValue(self.state.velocity)
		end
		function aj:getGoal()
			return aa.getValue(self.state.goal)
		end
		function aj:setPosition(am)
			if aa.setValue(self.state.position, am) then
				self.scheduleUpdate(self)
				self.state.fireChange(aa.getValue(self.state.position), 0)
			end
		end
		function aj:setVelocity(am)
			if aa.setValue(self.state.velocity, am) then
				self.scheduleUpdate(self)
			end
		end
		function aj:setGoal(am, an)
			if an then
				self.configure(self, an)
			end
			if aa.setValue(self.state.goal, am) then
				self.scheduleUpdate(self)
			end
		end
		function aj:impulse(am)
			aa.addValue(self.state.velocity, am)
			self.scheduleUpdate(self)
		end
		function aj:halt()
			aa.zero(self.state.velocity)
		end
		function aj:onChange(am)
			return self.state.onChange(am)
		end
		function aj:onComplete(am)
			return self.state.onComplete(am)
		end
		function aj:destroy()
			self.stop(self)
		end
		return { scheduler = ak, createSpring = createSpring }
	end
	function a.dz()
		local aa = a.load("dy")
		return {
			default = { tension = 170, friction = 26 },
			gentle = { tension = 120, friction = 14 },
			wobbly = { tension = 180, friction = 12 },
			stiff = { tension = 210, friction = 20 },
			slow = { tension = 280, friction = 60 },
			molasses = { tension = 280, friction = 120 },
			figmaGentle = { tension = 100, friction = 15 },
			figmaQuick = { tension = 300, friction = 20 },
			figmaBouncy = { tension = 600, friction = 15 },
			figmaSlow = { tension = 80, friction = 20 },
		}
	end
	function a.dA()
		local aa = math.pi
		local ab = 1.70158
		local ac = ab * 1.525
		local ad = ab + 1
		local ae = (2 * aa) / 3
		local ag = (2 * aa) / 4.5
		local function linear(ah)
			return ah
		end
		local function instant(ah)
			return if ah == 0 then 0 else 1
		end
		local function smoothstep(ah)
			return ah * ah * (3 - 2 * ah)
		end
		local function quadIn(ah)
			return ah * ah
		end
		local function quadOut(ah)
			return 1 - (1 - ah) * (1 - ah)
		end
		local function quadInOut(ah)
			return if ah < 0.5 then 2 * ah * ah else 1 - ((-2 * ah + 2) ^ 2) / 2
		end
		local function cubicIn(ah)
			return ah * ah * ah
		end
		local function cubicOut(ah)
			return 1 - (1 - ah) ^ 3
		end
		local function cubicInOut(ah)
			return if ah < 0.5 then 4 * ah * ah * ah else 1 - ((-2 * ah + 2) ^ 3) / 2
		end
		local function quartIn(ah)
			return ah * ah * ah * ah
		end
		local function quartOut(ah)
			return 1 - (1 - ah) ^ 4
		end
		local function quartInOut(ah)
			return if ah < 0.5 then 8 * ah * ah * ah * ah else 1 - ((-2 * ah + 2) ^ 4) / 2
		end
		local function quintIn(ah)
			return ah * ah * ah * ah * ah
		end
		local function quintOut(ah)
			return 1 - (1 - ah) ^ 5
		end
		local function quintInOut(ah)
			return if ah < 0.5 then 16 * ah * ah * ah * ah * ah else 1 - ((-2 * ah + 2) ^ 5) / 2
		end
		local function sineIn(ah)
			return 1 - math.cos((ah * aa) / 2)
		end
		local function sineOut(ah)
			return math.sin((ah * aa) / 2)
		end
		local function sineInOut(ah)
			return -(math.cos(aa * ah) - 1) / 2
		end
		local function expoIn(ah)
			return if ah == 0 then 0 else 2 ^ (10 * ah - 10)
		end
		local function expoOut(ah)
			return if ah == 1 then 1 else 1 - 2 ^ (-10 * ah)
		end
		local function expoInOut(ah)
			return if ah == 0
				then 0
				elseif ah == 1 then 1
				elseif ah < 0.5 then (2 ^ (20 * ah - 10)) / 2
				else (2 - (2 ^ (-20 * ah + 10))) / 2
		end
		local function circIn(ah)
			return 1 - (1 - (ah ^ 2)) ^ 0.5
		end
		local function circOut(ah)
			return (1 - (ah - 1) ^ 2) ^ 0.5
		end
		local function circInOut(ah)
			return if ah < 0.5
				then (1 - (1 - ((2 * ah) ^ 2)) ^ 0.5) / 2
				else (((1 - ((-2 * ah + 2) ^ 2)) ^ 0.5) + 1) / 2
		end
		local function backIn(ah)
			return ad * ah * ah * ah - ab * ah * ah
		end
		local function backOut(ah)
			return 1 + ad * ((ah - 1) ^ 3) + ab * ((ah - 1) ^ 2)
		end
		local function backInOut(ah)
			return if ah < 0.5
				then (((2 * ah) ^ 2) * ((ac + 1) * 2 * ah - ac)) / 2
				else (((2 * ah - 2) ^ 2) * ((ac + 1) * (ah * 2 - 2) + ac) + 2) / 2
		end
		local function elasticIn(ah)
			return if ah == 0 then 0 elseif ah == 1 then 1 else -(2 ^ (10 * ah - 10)) * math.sin((ah * 10 - 10.75) * ae)
		end
		local function elasticOut(ah)
			return if ah == 0 then 0 elseif ah == 1 then 1 else (2 ^ (-10 * ah)) * math.sin((ah * 10 - 0.75) * ae) + 1
		end
		local function elasticInOut(ah)
			return if ah == 0
				then 0
				elseif ah == 1 then 1
				elseif ah < 0.5 then -((2 ^ (20 * ah - 10)) * math.sin((20 * ah - 11.125) * ag)) / 2
				else ((2 ^ (-20 * ah + 10)) * math.sin((20 * ah - 11.125) * ag)) / 2 + 1
		end
		local function bounceOut(ah)
			local ai = 7.5625
			local aj = 2.75
			if ah < 1 / aj then
				return ai * ah * ah
			elseif ah < 2 / aj then
				ah -= 1.5 / aj
				return ai * ah * ah + 0.75
			elseif ah < 2.5 / aj then
				ah -= 2.25 / aj
				return ai * ah * ah + 0.9375
			else
				ah -= 2.625 / aj
				return ai * ah * ah + 0.984375
			end
		end
		local function bounceIn(ah)
			return 1 - bounceOut(1 - ah)
		end
		local function bounceInOut(ah)
			return if ah < 0.5 then (1 - bounceOut(1 - 2 * ah)) / 2 else (1 + bounceOut(2 * ah - 1)) / 2
		end
		return {
			linear = linear,
			instant = instant,
			smoothstep = smoothstep,
			quadIn = quadIn,
			quadOut = quadOut,
			quadInOut = quadInOut,
			cubicIn = cubicIn,
			cubicOut = cubicOut,
			cubicInOut = cubicInOut,
			quartIn = quartIn,
			quartOut = quartOut,
			quartInOut = quartInOut,
			quintIn = quintIn,
			quintOut = quintOut,
			quintInOut = quintInOut,
			sineIn = sineIn,
			sineOut = sineOut,
			sineInOut = sineInOut,
			expoIn = expoIn,
			expoOut = expoOut,
			expoInOut = expoInOut,
			circIn = circIn,
			circOut = circOut,
			circInOut = circInOut,
			backIn = backIn,
			backOut = backOut,
			backInOut = backInOut,
			elasticIn = elasticIn,
			elasticOut = elasticOut,
			elasticInOut = elasticInOut,
			bounceIn = bounceIn,
			bounceOut = bounceOut,
			bounceInOut = bounceInOut,
		}
	end
	function a.dB()
		local aa = a.load("ds")
		local ab = a.load("dx")
		local function interpolate(ac, ad, ae)
			local ag = typeof(ac)
			if ag == "number" or ag == "vector" or ag == "Vector3" or ag == "Vector2" then
				return ac + (ad - ac) * ae
			elseif ag == "Color3" then
				local ah = aa.fromSRGB(vector.create(ac.R, ac.G, ac.B))
				local ai = aa.fromSRGB(vector.create(ad.R, ad.G, ad.B))
				local aj = vector.max(aa.toSRGB(ah + (ai - ah) * ae), vector.zero)
				return Color3.new(aj.x, aj.y, aj.z)
			elseif ag == "UDim2" or ag == "CFrame" then
				return ac.Lerp(ac, ad, ae)
			elseif ag == "UDim" then
				return UDim.new(math.lerp(ac.Scale, ad.Scale, ae), math.lerp(ac.Offset, ad.Offset, ae))
			elseif ag == "Rect" then
				return Rect.new(
					math.lerp(ac.Min.X, ad.Min.X, ae),
					math.lerp(ac.Min.Y, ad.Min.Y, ae),
					math.lerp(ac.Max.X, ad.Max.X, ae),
					math.lerp(ac.Max.Y, ad.Max.Y, ae)
				)
			elseif ag == "table" then
				local ah = ac
				for ai, aj in ad do
					local ak = ac[ai]
					if not ak then
						continue
					end
					local am = ak + (aj - ak) * ae
					if ah[ai] ~= am then
						if ah == ac then
							ah = table.clone(ac)
						end
						ah[ai] = am
					end
				end
				return ah
			else
				error(`Unsupported type for interpolation: {ag}`)
			end
		end
		return interpolate
	end
	function a.dC()
		local aa = a.load("dA")
		local ab = a.load("dB")
		local ac = a.load("dr")
		local ad = a.load("du")
		local ae = a.load("dw")
		local ag = a.load("dx")
		local ah = {};
		(ah).__index = ah
		local function getAlpha(ai, aj, ak)
			if aj < 0 then
				aj = math.huge
			end
			if aj > 1 and ai >= 1 then
				if ak then
					return math.abs((ai - 1) % 2 - 1)
				elseif ai < aj then
					return ai % 1
				end
				return 1
			end
			return ai
		end
		local ai = ad("Tween", function(ai, aj, ak)
			if ai.complete then
				ak(ai)
				return ai.position
			end
			ai.elapsed += aj
			local am = math.clamp(ai.elapsed / ai.duration, 0, ai.repeats)
			if am ~= am then
				am = ai.repeats
			end
			local an = getAlpha(am, ai.repeats, ai.reverses)
			local ao = if an > 0 and an < 1 then ai.easingFunction(an) else an
			local ap = ab(ai.from, ai.goal, ao)
			ai.position = ap
			ai.fireChange(ap, aj)
			if am == ai.repeats then
				ak(ai)
				ai.complete = true
				ai.fireComplete(ap)
			end
			return ap
		end)
		local function createTween(aj, ak)
			local am = ak or {}
			local an = am.position or aj
			local ao, ap = ae()
			local aq, ar = ae()
			local as = {
				position = an,
				from = an,
				goal = an,
				easingFunction = aa.linear,
				duration = 1,
				repeats = 1,
				reverses = false,
				elapsed = 0,
				started = false,
				complete = true,
				onChange = ao,
				fireChange = ap,
				onComplete = aq,
				fireComplete = ar,
			}
			local au = (setmetatable({ state = as }, ah))
			au.configure(au, am)
			if am.start then
				au.start(au)
			end
			return au
		end
		function ah:resumeFromCurrentPosition()
			local aj = self.state
			aj.complete = false
			aj.elapsed = 0
			aj.from = aj.position
			if aj.started then
				ai.add(aj)
			end
		end
		function ah:start()
			self.state.started = true
			if not self.state.complete then
				ai.add(self.state)
			end
		end
		function ah:stop()
			self.state.started = false
			ai.remove(self.state)
		end
		function ah:idle()
			return self.state.complete
		end
		function ah:step(aj)
			return ai.update(self.state, aj)
		end
		function ah:configure(aj)
			local ak = self.state
			ak.easingFunction = aa[aj.easing] or ak.easingFunction
			ak.duration = aj.duration or ak.duration
			ak.repeats = aj.repeats or ak.repeats
			ak.reverses = aj.reverses or ak.reverses
			if aj.position then
				self.setPosition(self, aj.position)
			end
			if not ak.complete and ak.elapsed ~= 0 then
				self.resumeFromCurrentPosition(self)
			end
		end
		function ah:getPosition()
			return self.state.position
		end
		function ah:getFrom()
			return self.state.from
		end
		function ah:getGoal()
			return self.state.goal
		end
		function ah:setPosition(aj)
			local ak = if type(aj) == "table" then ac(self.state.position, aj) else aj
			if self.state.position ~= ak then
				self.state.position = ak
				self.resumeFromCurrentPosition(self)
				self.state.fireChange(ak, 0)
			end
		end
		function ah:setGoal(aj, ak)
			if ak then
				self.configure(self, ak)
			end
			local am = if type(aj) == "table" then ac(self.state.goal, aj) else aj
			if self.state.goal ~= am then
				self.state.goal = am
				self.resumeFromCurrentPosition(self)
			end
		end
		function ah:onChange(aj)
			return self.state.onChange(aj)
		end
		function ah:onComplete(aj)
			return self.state.onComplete(aj)
		end
		function ah:destroy()
			self.stop(self)
		end
		return { scheduler = ai, createTween = createTween }
	end
	function a.dD()
		local aa = a.load("du")
		local ab = a.load("dw")
		local ac = a.load("dy")
		local ad = a.load("dC")
		local ae = a.load("dx")
		local ag = {};
		(ag).__index = ag
		local ah = aa("Motion", function(ah, ai, aj)
			if ah.complete then
				aj(ah)
				return ah.current:getPosition()
			end
			local ak = ah.current:step(ai)
			if ah.current:idle() then
				aj(ah)
				ah.complete = true
				ah.fireComplete(ak)
			end
			return ak
		end)
		local function omitStartOption(ai)
			local aj = ai
			if aj == nil or aj.start ~= true then
				return aj
			else
				local ak = table.clone(aj)
				ak.start = nil
				return ak
			end
		end
		local function createMotion(ai, aj)
			local ak = aj or {}
			local am = ac.createSpring(ai, omitStartOption(ak.spring))
			local an = ad.createTween(ai, omitStartOption(ak.tween))
			local ao = if not ak.tween then am else an
			local ap, aq = ab()
			local ar, as = ab()
			local au = {
				spring = am,
				tween = an,
				current = ao,
				started = false,
				complete = true,
				onChange = ap,
				onComplete = ar,
				fireComplete = as,
			}
			local av = (setmetatable({
				state = au,
			}, ag))
			if ak.start then
				av.start(av)
			end
			am.onChange(am, function(aw, ax)
				if au.current == am then
					aq(aw, ax)
				end
			end)
			an.onChange(an, function(aw, ax)
				if au.current == an then
					aq(aw, ax)
				end
			end)
			return av
		end
		function ag:scheduleUpdate()
			self.state.complete = false
			if self.state.started then
				ah.add(self.state)
			end
		end
		function ag:prepareSpring()
			local ai = self.state
			if ai.current ~= ai.spring then
				ai.spring:setPosition(ai.tween:getPosition())
				ai.current = ai.spring
			end
		end
		function ag:prepareTween()
			local ai = self.state
			if ai.current ~= ai.tween then
				ai.tween:setPosition(ai.spring:getPosition())
				ai.spring:halt()
				ai.current = ai.tween
			end
		end
		function ag:start()
			self.state.started = true
			if not self.state.complete then
				ah.add(self.state)
			end
		end
		function ag:stop()
			self.state.started = false
			ah.remove(self.state)
		end
		function ag:idle()
			return self.state.complete
		end
		function ag:step(ai)
			return ah.update(self.state, ai)
		end
		function ag:configure(ai)
			if ai.spring then
				self.state.spring:configure(ai.spring)
			end
			if ai.tween then
				self.state.tween:configure(ai.tween)
			end
			if not self.state.current:idle() then
				self.scheduleUpdate(self)
			end
		end
		function ag:getPosition()
			return self.state.current:getPosition()
		end
		function ag:getVelocity()
			return self.state.spring:getVelocity()
		end
		function ag:getGoal()
			return self.state.current:getGoal()
		end
		function ag:setPosition(ai)
			self.state.current:setPosition(ai)
			if not self.state.current:idle() then
				self.scheduleUpdate(self)
			end
		end
		function ag:setVelocity(ai)
			if self.state.current == self.state.spring then
				self.state.spring:setVelocity(ai)
				if not self.state.current:idle() then
					self.scheduleUpdate(self)
				end
			end
		end
		function ag:setGoal(ai, aj)
			if aj then
				if aj.spring then
					return self.spring(self, ai, aj.spring)
				elseif aj.tween then
					return self.tween(self, ai, aj.tween)
				end
			end
			self.state.current:setGoal(ai)
			if not self.state.current:idle() then
				self.scheduleUpdate(self)
			end
		end
		function ag:spring(ai, aj)
			self.prepareSpring(self)
			self.state.spring:setGoal(ai, aj)
			if not self.state.spring:idle() then
				self.scheduleUpdate(self)
			end
		end
		function ag:tween(ai, aj)
			self.prepareTween(self)
			self.state.tween:setGoal(ai, aj)
			if not self.state.tween:idle() then
				self.scheduleUpdate(self)
			end
		end
		function ag:onChange(ai)
			return self.state.onChange(ai)
		end
		function ag:onComplete(ai)
			return self.state.onComplete(ai)
		end
		function ag:destroy()
			self.stop(self)
		end
		return { scheduler = ah, createMotion = createMotion }
	end
	function a.dE()
		local aa = a.load("dz")
		local ab = a.load("dA")
		local ac = a.load("dD")
		local ad = a.load("dy")
		local ae = a.load("dC")
		local ag = a.load("dx")
		return {
			config = aa,
			easing = ab,
			createMotion = ac.createMotion,
			motionScheduler = ac.scheduler,
			createSpring = ad.createSpring,
			springScheduler = ad.scheduler,
			createTween = ae.createTween,
			tweenScheduler = ae.scheduler,
		}
	end
	function a.dF()
		return a.load("dE")
	end
	function a.dG()
		return a.load("bY")
	end
	function a.dH()
		local aa = a.load("dG")
		local ab = a.load("dF")
		local function useMotion(ac, ad)
			local ae, ag = aa.useBinding(ac)
			local ah = aa.useRef(nil)
			if not ah.current then
				ah.current = ab.createMotion(ac, ad)
			end
			aa.useEffect(function()
				local ai = ah.current:onChange(ag)
				if not ad or ad.start ~= false then
					ah.current:start()
				end
				return function()
					ah.current:stop()
					ai()
				end
			end, {})
			return ae, ah.current
		end
		return useMotion
	end
	function a.dI()
		local aa = a.load("dG")
		local ab = a.load("dF")
		local function useSpring(ac, ad)
			local ae, ag = aa.useBinding(ac)
			local ah = aa.useRef(nil)
			if not ah.current then
				ah.current = ab.createSpring(ac, ad)
			end
			aa.useEffect(function()
				local ai = ah.current:onChange(ag)
				if not ad or ad.start ~= false then
					ah.current:start()
				end
				return function()
					ah.current:stop()
					ai()
				end
			end, {})
			return ae, ah.current
		end
		return useSpring
	end
	function a.dJ()
		local aa = a.load("dG")
		local ab = a.load("dF")
		local function useTween(ac, ad)
			local ae, ag = aa.useBinding(ac)
			local ah = aa.useRef(nil)
			if not ah.current then
				ah.current = ab.createTween(ac, ad)
			end
			aa.useEffect(function()
				local ai = ah.current:onChange(ag)
				if not ad or ad.start ~= false then
					ah.current:start()
				end
				return function()
					ah.current:stop()
					ai()
				end
			end, {})
			return ae, ah.current
		end
		return useTween
	end
	function a.dK()
		local aa = a.load("dF")
		local ab = a.load("dH")
		local ac = a.load("dI")
		local ad = a.load("dJ")
		return {
			config = aa.config,
			easing = aa.easing,
			createMotion = aa.createMotion,
			createSpring = aa.createSpring,
			createTween = aa.createTween,
			useMotion = ab,
			useSpring = ac,
			useTween = ad,
		}
	end
	function a.dL()
		local aa = a.load("dK")
		return aa
	end
	function a.dM()
		return nil
	end
	function a.dN()
		local aa = a.load("dM")
		local ab = _G.__DEV__
		local ac = setmetatable({}, { __mode = "k" })
		local ad = {}
		local ae = false
		local ag = { stack = {}, index = 0 }
		local function try(ah, ai, ...)
			if ab then
				local aj = coroutine.create(ah)
				local ak, am = coroutine.resume(aj, ...)
				if ai then
					ai()
				end
				if coroutine.status(aj) == "suspended" then
					local an, ao, ap = debug.info(ah, "sln")
					coroutine.close(aj)
					error(
						"Yielding is not allowed in atom functions. Consider wrapping this code in a Promise or task.defer instead."
							.. `\nFunction defined at: {an}:{ao}`
							.. if ap == "" then "" else ` function {ap}`
					)
				elseif not ak then
					local an, ao, ap = debug.info(ah, "sln")
					error(
						"An error occurred while running an atom function"
							.. `\nFunction defined at: {an}:{ao}`
							.. (if ap == "" then "" else ` function {ap}`)
							.. `\nError: {am}`
					)
				end
				return am
			end
			if not ai then
				return ah(...)
			end
			local aj, ak = pcall(ah, ...)
			ai()
			assert(aj, ak)
			return ak
		end
		local function isAtom(ah)
			return not not (ah and ac[ah])
		end
		local function notify(ah)
			if ae then
				for ai in next, ac[ah] do
					ad[ai] = true
				end
				return
			end
			for ai in next, table.clone(ac[ah]) do
				try(ai)
			end
		end
		local function peek(ah, ...)
			if type(ah) ~= "function" then
				return ah
			end
			if ag.index == 0 then
				return ah(...)
			end
			ag.index += 1
			ag.stack[ag.index] = {}
			local ai = try(ah, function()
				ag.stack[ag.index] = nil
				ag.index -= 1
			end, ...)
			return ai
		end
		local function capture(ah, ...)
			if ac[ah] then
				return { [ah] = true }, peek(ah)
			end
			local ai = {}
			ag.index += 1
			ag.stack[ag.index] = ai
			local aj = try(ah, function()
				ag.stack[ag.index] = nil
				ag.index -= 1
			end, ...)
			return ai, aj
		end
		local function batch(ah)
			if ae then
				return ah()
			end
			ae = true
			try(ah, function()
				ae = false
			end)
			for ai in next, ad do
				try(ai)
			end
			table.clear(ad)
		end
		local function connect(ah, ai, aj)
			for ak in next, ah do
				ac[ak][ai] = aj or true
			end
		end
		local function disconnect(ah, ai)
			for aj in next, ah do
				ac[aj][ai] = nil
			end
		end
		return {
			listeners = ac,
			capturing = ag,
			isAtom = isAtom,
			notify = notify,
			capture = capture,
			batch = batch,
			peek = peek,
			connect = connect,
			disconnect = disconnect,
		}
	end
	function a.dO()
		local aa = a.load("dN")
		local ab = a.load("dM")
		local function atom(ac, ad)
			local ae = ad and ad.equals
			local function atom(...)
				if select("#", ...) == 0 then
					local ag = aa.capturing.index
					if ag > 0 then
						aa.capturing.stack[ag][atom] = true
					end
					return ac
				end
				local ag = aa.peek(..., ac)
				if ac ~= ag and not (ae and ae(ac, ag)) then
					ac = ag
					aa.notify(atom)
				end
				return ac
			end
			aa.listeners[atom] = setmetatable({}, { __mode = "v" })
			return atom
		end
		return atom
	end
	function a.dP()
		local aa = a.load("dO")
		local ab = a.load("dN")
		local ac = a.load("dM")
		local function computed(ad, ae)
			local ag, ah = ab.capture(ad)
			local ai = aa(ah, ae)
			local aj = setmetatable({ current = ai }, { __mode = "v" })
			local function listener()
				local ak = aj.current
				if ak then
					ab.disconnect(ag, listener)
					ag, ah = ab.capture(ad)
					ab.connect(ag, listener, ak)
					ak(ah)
				end
			end
			ab.connect(ag, listener, ai)
			return ai
		end
		return computed
	end
	function a.dQ()
		local aa = a.load("dN")
		local function effect(ab)
			local ac = {}
			local ad
			local ae = false
			local ag
			local function listener()
				if ad then
					ad()
				end
				aa.disconnect(ac, listener)
				ac, ad = aa.capture(ab, ag)
				if not ae then
					aa.connect(ac, listener)
				end
			end
			function ag()
				if ae then
					return
				end
				ae = true
				aa.disconnect(ac, listener)
				if ad then
					ad()
				end
			end
			ac, ad = aa.capture(ab, ag)
			if not ae then
				aa.connect(ac, listener)
			end
			return ag
		end
		return effect
	end
	function a.dR()
		local aa = a.load("dN")
		local ab = a.load("dM")
		local function subscribe(ac, ad)
			local ae, ag = aa.capture(ac)
			local ah = false
			local function handler()
				local ai = ag
				aa.disconnect(ae, handler)
				ae, ag = aa.capture(ac)
				if not ah then
					aa.connect(ae, handler)
				end
				if ag ~= ai then
					ad(ag, ai)
				end
			end
			aa.connect(ae, handler)
			return function()
				if not ah then
					ah = true
					aa.disconnect(ae, handler)
				end
			end
		end
		return subscribe
	end
	function a.dS()
		local aa = a.load("dO")
		local ab = a.load("dN")
		local ac = a.load("dR")
		local ad = a.load("dM")
		local function mapped(ae, ag)
			local ah = aa({})
			local ai = setmetatable({ current = ah }, { __mode = "v" })
			local aj = {}
			local ak
			local function listener(am)
				local an = ai.current
				if not an then
					return ak()
				end
				local ao = table.clone(an())
				local ap = {}
				for aq, ar in next, am do
					local as, au = ag(ar, aq)
					if au == nil then
						au = aq
					end
					if ao[au] ~= as then
						ao[au] = as
					else
						ap[au] = aq
					end
				end
				for aq in next, aj do
					if ap[aq] == nil and ao[aq] == aj[aq] then
						ao[aq] = nil
					end
				end
				aj = ao
				an(ao)
			end
			ak = ac(ae, listener)
			ab.peek(function()
				listener(ae())
			end)
			return ah
		end
		return mapped
	end
	function a.dT()
		local aa = a.load("dN")
		local ab = a.load("dR")
		local ac = a.load("dM")
		local function noop() end
		local function observe(ad, ae)
			local ag = {}
			local function listener(ah)
				for ai, aj in next, ag do
					if ah[ai] == nil then
						ag[ai] = nil
						aj()
					end
				end
				for ai, aj in next, ah do
					if not ag[ai] then
						ag[ai] = ae(aj, ai) or noop
					end
				end
			end
			local ah = ab(ad, listener)
			aa.peek(function()
				listener(ad())
			end)
			return function()
				ah()
				for ai, aj in next, ag do
					aj()
				end
				table.clear(ag)
			end
		end
		return observe
	end
	function a.dU()
		local aa = a.load("dO")
		local ab = a.load("dP")
		local ac = a.load("dQ")
		local ad = a.load("dS")
		local ae = a.load("dT")
		local ag = a.load("dN")
		local ah = a.load("dR")
		local ai = a.load("dM")
		return {
			atom = aa,
			computed = ab,
			effect = ac,
			mapped = ad,
			observe = ae,
			subscribe = ah,
			batch = ag.batch,
			capture = ag.capture,
			isAtom = ag.isAtom,
			notify = ag.notify,
			peek = ag.peek,
		}
	end
	function a.dV()
		return a.load("dU")
	end
	function a.dW()
		return a.load("bY")
	end
	function a.dX()
		local aa = a.load("dV")
		local ab = a.load("dW")
		local function useAtom(ac, ad)
			local ae, ag = ab.useState(ac)
			ab.useEffect(function()
				ag(ac())
				return aa.subscribe(ac, ag)
			end, ad or {})
			return ae
		end
		return { useAtom = useAtom }
	end
	function a.dY()
		return a.load("dX")
	end
	function a.dZ()
		local aa = a.load("dU")
		return aa
	end
	function a.d_()
		local aa = newproxy(true)
		getmetatable(aa).__tostring = function()
			return "Sift.None"
		end
		return aa
	end
	function a.d0()
		local aa = a.load("d_")
		return nil
	end
	function a.d1()
		local function at(aa, ab)
			local ac = #aa
			if ab < 1 then
				ab += ac
			end
			return aa[ab]
		end
		return at
	end
	function a.d2()
		local aa = a.load("d_")
		local function concat(...)
			local ab = {}
			for ac = 1, select("#", ...) do
				local ad = select(ac, ...)
				if type(ad) ~= "table" then
					continue
				end
				for ae, ag in ipairs(ad) do
					if ag ~= aa then
						table.insert(ab, ag)
					end
				end
			end
			return ab
		end
		return concat
	end
	function a.d3()
		local function copyDeep(aa)
			local ab = table.clone(aa)
			for ac, ad in aa do
				if type(ad) == "table" then
					ab[ac] = (copyDeep(ad))
				end
			end
			return ab
		end
		return copyDeep
	end
	function a.d4()
		local aa = a.load("d3")
		local ab = a.load("d_")
		local function concatDeep(...)
			local ac = {}
			for ad = 1, select("#", ...) do
				local ae = select(ad, ...)
				if type(ae) ~= "table" then
					continue
				end
				for ag, ah in ipairs(ae) do
					if ah ~= ab then
						if type(ah) == "table" then
							table.insert(ac, aa(ah))
						else
							table.insert(ac, ah)
						end
					end
				end
			end
			return ac
		end
		return concatDeep
	end
	function a.d5()
		return table.clone
	end
	function a.d6()
		local aa = a.load("d0")
		local function equalObjects(...)
			local ab = select(1, ...)
			for ac = 2, select("#", ...) do
				if ab ~= select(ac, ...) then
					return false
				end
			end
			return true
		end
		return equalObjects
	end
	function a.d7()
		local function truthy()
			return true
		end
		local function noop() end
		local function returned(...)
			return ...
		end
		return { truthy = truthy, noop = noop, returned = returned }
	end
	function a.d8()
		local aa = a.load("d0")
		local function isEmpty(ab)
			return next(ab) == nil
		end
		return isEmpty
	end
	function a.d9()
		return { equalObjects = a.load("d6"), func = a.load("d7"), isEmpty = a.load("d8") }
	end
	function a.ea()
		local aa = a.load("d9")
		local function count(ab, ac)
			local ad = 0
			ac = if type(ac) == "function" then ac else aa.func.truthy
			for ae, ag in ipairs(ab) do
				if ac(ag, ae, ab) then
					ad += 1
				end
			end
			return ad
		end
		return count
	end
	function a.eb()
		return table.create
	end
	function a.ec()
		local function fromArray(aa)
			local ab = table.create(#aa)
			for ac, ad in ipairs(aa) do
				ab[ad] = true
			end
			return ab
		end
		return fromArray
	end
	function a.ed()
		local function toArray(aa)
			local ab = {}
			for ac, ad in pairs(aa) do
				table.insert(ab, ac)
			end
			return ab
		end
		return toArray
	end
	function a.ee()
		local aa = a.load("ec")
		local ab = a.load("ed")
		local function dedupe(ac)
			return ab(aa(ac))
		end
		return dedupe
	end
	function a.ef()
		local aa = a.load("d0")
		local function toSet(ab)
			local ac = {}
			for ad, ae in ipairs(ab) do
				ac[ae] = true
			end
			return ac
		end
		return toSet
	end
	function a.eg()
		local aa = a.load("d0")
		local function difference(ab, ...)
			local ac = table.clone(ab)
			for ad, ae in { ... } do
				if typeof(ae) ~= "table" then
					continue
				end
				for ag in ae do
					ac[ag] = nil
				end
			end
			return ac
		end
		return difference
	end
	function a.eh()
		local aa = a.load("d0")
		local ab = a.load("ef")
		local ac = a.load("ed")
		local ad = a.load("eg")
		local function difference(ae, ...)
			local ag = ab(ae)
			local ah = {}
			for ai, aj in { ... } do
				if typeof(aj) ~= "table" then
					continue
				end
				table.insert(ah, ab(aj))
			end
			local ai = ad(ag, unpack(ah))
			return ac(ai)
		end
		return difference
	end
	function a.ei()
		local aa = a.load("d0")
		local function differenceSymmetric(ab, ...)
			local ac = table.clone(ab)
			for ad, ae in { ... } do
				if typeof(ae) ~= "table" then
					continue
				end
				for ag in ae do
					ac[ag] = if ac[ag] == nil then true else false
				end
			end
			for ad, ae in ac do
				ac[ad] = if ae then true else nil
			end
			return ac
		end
		return differenceSymmetric
	end
	function a.ej()
		local aa = a.load("d0")
		local ab = a.load("ef")
		local ac = a.load("ed")
		local ad = a.load("ei")
		local function differenceSymmetric(ae, ...)
			local ag = ab(ae)
			local ah = {}
			for ai, aj in { ... } do
				if typeof(aj) ~= "table" then
					continue
				end
				table.insert(ah, ab(aj))
			end
			local ai = ad(ag, unpack(ah))
			return ac(ai)
		end
		return differenceSymmetric
	end
	function a.ek()
		local aa = a.load("d9")
		local function compare(ab, ac)
			if type(ab) ~= "table" or type(ac) ~= "table" then
				return ab == ac
			end
			local ad = #ab
			if #ac ~= ad then
				return false
			end
			for ae = 1, ad do
				if ab[ae] ~= ac[ae] then
					return false
				end
			end
			return true
		end
		local function equals(...)
			if aa.equalObjects(...) then
				return true
			end
			local ab = select("#", ...)
			local ac = select(1, ...)
			for ad = 2, ab do
				local ae = select(ad, ...)
				if not compare(ac, ae) then
					return false
				end
			end
			return true
		end
		return equals
	end
	function a.el()
		local aa = a.load("d9")
		local function compareDeep(ab, ac)
			if type(ab) ~= "table" or type(ac) ~= "table" then
				return ab == ac
			end
			local ad = #ab
			if #ac ~= ad then
				return false
			end
			for ae = 1, ad do
				if not compareDeep(ab[ae], ac[ae]) then
					return false
				end
			end
			return true
		end
		local function equalsDeep(...)
			if aa.equalObjects(...) then
				return true
			end
			local ab = select("#", ...)
			local ac = select(1, ...)
			for ad = 2, ab do
				local ae = select(ad, ...)
				if not compareDeep(ac, ae) then
					return false
				end
			end
			return true
		end
		return equalsDeep
	end
	function a.em()
		local function every(aa, ab)
			for ac, ad in ipairs(aa) do
				if not ab(ad, ac, aa) then
					return false
				end
			end
			return true
		end
		return every
	end
	function a.en()
		local aa = a.load("d9")
		local function filter(ab, ac)
			local ad = {}
			ac = if type(ac) == "function" then ac else aa.func.truthy
			for ae, ag in ipairs(ab) do
				if ac(ag, ae, ab) then
					table.insert(ad, ag)
				end
			end
			return ad
		end
		return filter
	end
	function a.eo()
		local function find(aa, ab, ac)
			local ad = #aa
			ac = if type(ac) == "number" then if ac < 1 then ad + ac else ac else 1
			return table.find(aa, ab, ac)
		end
		return find
	end
	function a.ep()
		local function findLast(aa, ab, ac)
			local ad = #aa
			ac = if type(ac) == "number" then if ac < 1 then ad + ac else ac else ad
			for ae = ac, 1, -1 do
				if aa[ae] == ab then
					return ae
				end
			end
			return
		end
		return findLast
	end
	function a.eq()
		local function findWhere(aa, ab, ac)
			local ad = #aa
			ac = if type(ac) == "number" then if ac < 1 then ad + ac else ac else 1
			for ae = ac, #aa do
				if ab(aa[ae], ae, aa) then
					return ae
				end
			end
			return
		end
		return findWhere
	end
	function a.er()
		local function findWhereLast(aa, ab, ac)
			local ad = #aa
			ac = if type(ac) == "number" then if ac < 1 then ad + ac else ac else ad
			for ae = ac, 1, -1 do
				if ab(aa[ae], ae, aa) then
					return ae
				end
			end
			return
		end
		return findWhereLast
	end
	function a.es()
		local aa = a.load("d1")
		local function first(ab)
			return aa(ab, 1)
		end
		return first
	end
	function a.et()
		local function flatten(aa, ab)
			ab = if type(ab) == "number" then ab else math.huge
			local ac = {}
			for ad, ae in ipairs(aa) do
				if type(ae) == "table" and ab > 0 then
					local ag = flatten(ae, ab - 1)
					for ah, ai in ipairs(ag) do
						table.insert(ac, ai)
					end
				else
					table.insert(ac, ae)
				end
			end
			return ac
		end
		return flatten
	end
	function a.eu()
		local aa = a.load("d5")
		local function freeze(ab)
			local ac = aa(ab)
			table.freeze(ac)
			return ac
		end
		return freeze
	end
	function a.ev()
		local function freezeDeep(aa)
			local ab = {}
			for ac = 1, #aa do
				local ad = aa[ac]
				if type(ad) == "table" then
					table.insert(ab, freezeDeep(ad))
				else
					table.insert(ab, ad)
				end
			end
			table.freeze(ab)
			return ab
		end
		return freezeDeep
	end
	function a.ew()
		local aa = a.load("eo")
		local function includes(ab, ac, ad)
			return aa(ab, ac, ad) ~= nil
		end
		return includes
	end
	function a.ex()
		local function insert(aa, ab, ...)
			local ac = #aa
			if ab < 1 then
				ab += ac + 1
			end
			if ab > ac then
				if ab > ac + 1 then
					return aa
				end
				ab = ac + 1
				ac += 1
			end
			local ad = {}
			for ae = 1, ac do
				if ae == ab then
					for ag, ah in ipairs({ ... }) do
						table.insert(ad, ah)
					end
				end
				table.insert(ad, aa[ae])
			end
			return ad
		end
		return insert
	end
	function a.ey()
		local function is(aa)
			return typeof(aa) == "table" and #aa > 0 and next(aa, #aa) == nil
		end
		return is
	end
	function a.ez()
		local aa = a.load("d1")
		local function last(ab)
			return aa(ab, 0)
		end
		return last
	end
	function a.eA()
		local function map(aa, ab)
			local ac = {}
			for ad, ae in ipairs(aa) do
				local ag = ab(ae, ad, aa)
				if ag ~= nil then
					table.insert(ac, ag)
				end
			end
			return ac
		end
		return map
	end
	function a.eB()
		local function pop(aa, ab)
			local ac = #aa
			local ad = {}
			ab = if type(ab) == "number" then ab else 1
			for ae = 1, ac - ab do
				table.insert(ad, aa[ae])
			end
			return ad
		end
		return pop
	end
	function a.eC()
		local function push(aa, ...)
			local ab = {}
			for ac, ad in ipairs(aa) do
				table.insert(ab, ad)
			end
			for ac, ad in ipairs({ ... }) do
				table.insert(ab, ad)
			end
			return ab
		end
		return push
	end
	function a.eD()
		local function reduce(aa, ab, ac)
			local ad = ac
			local ae = 1
			if ad == nil then
				ad = aa[1]
				ae = 2
			end
			for ag = ae, #aa do
				ad = ab(ad, aa[ag], ag, aa)
			end
			return ad
		end
		return reduce
	end
	function a.eE()
		local function reduceRight(aa, ab, ac)
			local ad = ac
			local ae = #aa
			if ad == nil then
				ad = aa[ae]
				ae -= 1
			end
			for ag = ae, 1, -1 do
				ad = ab(ad, aa[ag], ag, aa)
			end
			return ad
		end
		return reduceRight
	end
	function a.eF()
		local function removeIndex(aa, ab)
			local ac = #aa
			local ad = {}
			if ab < 1 then
				ab += ac
			end
			for ae, ag in ipairs(aa) do
				if ae ~= ab then
					table.insert(ad, ag)
				end
			end
			return ad
		end
		return removeIndex
	end
	function a.eG()
		local function removeIndices(aa, ...)
			local ab = #aa
			local ac = {}
			local ad = {}
			for ae, ag in ipairs({ ... }) do
				if ag < 1 then
					ag += ab
				end
				ac[ag] = true
			end
			for ae, ag in ipairs(aa) do
				if not ac[ae] then
					table.insert(ad, ag)
				end
			end
			return ad
		end
		return removeIndices
	end
	function a.eH()
		local function removeValue(aa, ab)
			local ac = {}
			for ad, ae in ipairs(aa) do
				if ae ~= ab then
					table.insert(ac, ae)
				end
			end
			return ac
		end
		return removeValue
	end
	function a.eI()
		local aa = a.load("ef")
		local function removeValues(ab, ...)
			local ac = aa({ ... })
			local ad = {}
			for ae, ag in ipairs(ab) do
				if not ac[ag] then
					table.insert(ad, ag)
				end
			end
			return ad
		end
		return removeValues
	end
	function a.eJ()
		local function reverse(aa)
			local ab = {}
			for ac = #aa, 1, -1 do
				table.insert(ab, aa[ac])
			end
			return ab
		end
		return reverse
	end
	function a.eK()
		local function set(aa, ab, ac)
			local ad = #aa
			local ae = {}
			if ab < 1 then
				ab += ad
			end
			for ag, ah in ipairs(aa) do
				if ag == ab then
					table.insert(ae, ac)
				else
					table.insert(ae, ah)
				end
			end
			return ae
		end
		return set
	end
	function a.eL()
		local function shift(aa, ab)
			local ac = #aa
			local ad = {}
			ab = if type(ab) == "number" then ab + 1 else 2
			for ae = ab, ac do
				table.insert(ad, aa[ae])
			end
			return ad
		end
		return shift
	end
	function a.eM()
		local aa = a.load("d5")
		local function shuffle(ab)
			local ac = Random.new(os.time() * #ab)
			local ad = aa(ab)
			for ae = #ad, 1, -1 do
				local ag = ac.NextInteger(ac, 1, ae)
				local ah = ad[ae]
				ad[ae] = ad[ag]
				ad[ag] = ah
			end
			return ad
		end
		return shuffle
	end
	function a.eN()
		local function slice(aa, ab, ac)
			local ad = #aa
			local ae = {}
			ab = if type(ab) == "number" then ab else 1
			ac = if type(ac) == "number" then ac else ad
			if ab < 1 then
				ab += ad
			end
			if ac < 1 then
				ac += ad
			end
			for ag = ab, ac do
				table.insert(ae, aa[ag])
			end
			return ae
		end
		return slice
	end
	function a.eO()
		local function some(aa, ab)
			for ac, ad in ipairs(aa) do
				if ab(ad, ac, aa) then
					return true
				end
			end
			return false
		end
		return some
	end
	function a.eP()
		local aa = a.load("d5")
		local function sort(ab, ac)
			local ad = aa(ab)
			table.sort(ad, ac)
			return ad
		end
		return sort
	end
	function a.eQ()
		local function splice(aa, ab, ac, ...)
			local ad = #aa
			local ae = {}
			ab = if type(ab) == "number" then ab else 1
			ac = if type(ac) == "number" then ac else ad
			if ab < 1 then
				ab += ad
			end
			if ac < 1 then
				ac += ad
			end
			for ag = 1, ab - 1 do
				table.insert(ae, aa[ag])
			end
			for ag, ah in ipairs({ ... }) do
				table.insert(ae, ah)
			end
			for ag = ac + 1, ad do
				table.insert(ae, aa[ag])
			end
			return ae
		end
		return splice
	end
	function a.eR()
		local function unshift(aa, ...)
			local ab = { ... }
			for ac, ad in ipairs(aa) do
				table.insert(ab, ad)
			end
			return ab
		end
		return unshift
	end
	function a.eS()
		local aa = a.load("d9")
		local ab = a.load("d5")
		local function call(ac, ad)
			if type(ac) == "function" then
				return ac(ad)
			end
		end
		local function update(ac, ad, ae, ag)
			local ah = #ac
			local ai = ab(ac)
			if ad < 1 then
				ad += ah
			end
			ae = if type(ae) == "function" then ae else aa.func.returned
			if ai[ad] ~= nil then
				ai[ad] = ae(ai[ad], ad)
			else
				ai[ad] = call(ag, ad)
			end
			return ai
		end
		return update
	end
	function a.eT()
		local aa = a.load("eD")
		local function zip(...)
			local ab = select("#", ...)
			local ac = { ... }
			local ad = {}
			if ab == 0 then
				return ad
			end
			local ae = aa(ac, function(ae, ag)
				return math.min(ae, #ag)
			end, #ac[1])
			for ag = 1, ae do
				local ah = {}
				for ai, aj in ipairs(ac) do
					table.insert(ah, aj[ag])
				end
				table.insert(ad, ah)
			end
			return ad
		end
		return zip
	end
	function a.eU()
		local aa = a.load("eD")
		local ab = a.load("d_")
		local function zipAll(...)
			local ac = select("#", ...)
			local ad = { ... }
			local ae = {}
			if ac == 0 then
				return ae
			end
			local ag = aa(ad, function(ag, ah)
				return math.max(ag, #ah)
			end, #ad[1])
			for ah = 1, ag do
				local ai = {}
				for aj, ak in ipairs(ad) do
					local am = ak[ah]
					table.insert(ai, if am == nil then ab else am)
				end
				table.insert(ae, ai)
			end
			return ae
		end
		return zipAll
	end
	function a.eV()
		local aa = {
			at = a.load("d1"),
			concat = a.load("d2"),
			concatDeep = a.load("d4"),
			copy = a.load("d5"),
			copyDeep = a.load("d3"),
			count = a.load("ea"),
			create = a.load("eb"),
			dedupe = a.load("ee"),
			difference = a.load("eh"),
			differenceSymmetric = a.load("ej"),
			equals = a.load("ek"),
			equalsDeep = a.load("el"),
			every = a.load("em"),
			filter = a.load("en"),
			find = a.load("eo"),
			findLast = a.load("ep"),
			findWhere = a.load("eq"),
			findWhereLast = a.load("er"),
			first = a.load("es"),
			flatten = a.load("et"),
			freeze = a.load("eu"),
			freezeDeep = a.load("ev"),
			includes = a.load("ew"),
			insert = a.load("ex"),
			is = a.load("ey"),
			last = a.load("ez"),
			map = a.load("eA"),
			pop = a.load("eB"),
			push = a.load("eC"),
			reduce = a.load("eD"),
			reduceRight = a.load("eE"),
			removeIndex = a.load("eF"),
			removeIndices = a.load("eG"),
			removeValue = a.load("eH"),
			removeValues = a.load("eI"),
			reverse = a.load("eJ"),
			set = a.load("eK"),
			shift = a.load("eL"),
			shuffle = a.load("eM"),
			slice = a.load("eN"),
			some = a.load("eO"),
			sort = a.load("eP"),
			splice = a.load("eQ"),
			toSet = a.load("ef"),
			unshift = a.load("eR"),
			update = a.load("eS"),
			zip = a.load("eT"),
			zipAll = a.load("eU"),
		}
		aa.join = aa.concat
		aa.merge = aa.concat
		aa.joinDeep = aa.concatDeep
		aa.mergeDeep = aa.concatDeep
		aa.append = aa.push
		aa.prepend = aa.unshift
		aa.indexOf = aa.find
		aa.has = aa.includes
		aa.contains = aa.includes
		aa.isArray = aa.is
		return aa
	end
	function a.eW()
		return table.clone
	end
	function a.eX()
		local function copyDeep(aa)
			local ab = table.clone(aa)
			for ac, ad in pairs(aa) do
				if type(ad) == "table" then
					ab[ac] = copyDeep(ad)
				end
			end
			return ab
		end
		return copyDeep
	end
	function a.eY()
		local aa = a.load("d9")
		local function count(ab, ac)
			local ad = 0
			ac = if type(ac) == "function" then ac else aa.func.truthy
			for ae, ag in pairs(ab) do
				if ac(ag, ae, ab) then
					ad += 1
				end
			end
			return ad
		end
		return count
	end
	function a.eZ()
		local function entries(aa)
			local ab = {}
			for ac, ad in pairs(aa) do
				table.insert(ab, { ac, ad })
			end
			return ab
		end
		return entries
	end
	function a.e_()
		local aa = a.load("d9")
		local ab = a.load("d0")
		local function compare(ac, ad)
			if type(ac) ~= "table" or type(ad) ~= "table" then
				return ac == ad
			end
			for ae, ag in pairs(ac) do
				if ad[ae] ~= ag then
					return false
				end
			end
			for ae, ag in pairs(ad) do
				if ac[ae] ~= ag then
					return false
				end
			end
			return true
		end
		local function equals(...)
			if aa.equalObjects(...) then
				return true
			end
			local ac = select("#", ...)
			local ad = select(1, ...)
			for ae = 2, ac do
				local ag = select(ae, ...)
				if not compare(ad, ag) then
					return false
				end
			end
			return true
		end
		return equals
	end
	function a.e0()
		local aa = a.load("d9")
		local ab = a.load("d0")
		local function compareDeep(ac, ad)
			if type(ac) ~= "table" or type(ad) ~= "table" then
				return ac == ad
			end
			for ae, ag in pairs(ac) do
				if not compareDeep(ag, ad[ae]) then
					return false
				end
			end
			for ae, ag in pairs(ad) do
				if not compareDeep(ag, ac[ae]) then
					return false
				end
			end
			return true
		end
		local function equalsDeep(...)
			if aa.equalObjects(...) then
				return true
			end
			local ac = select("#", ...)
			local ad = select(1, ...)
			for ae = 2, ac do
				local ag = select(ae, ...)
				if not compareDeep(ad, ag) then
					return false
				end
			end
			return true
		end
		return equalsDeep
	end
	function a.e1()
		local function every(aa, ab)
			for ac, ad in pairs(aa) do
				if not ab(ad, ac, aa) then
					return false
				end
			end
			return true
		end
		return every
	end
	function a.e2()
		local aa = a.load("d9")
		local function filter(ab, ac)
			local ad = {}
			ac = if type(ac) == "function" then ac else aa.func.truthy
			for ae, ag in pairs(ab) do
				if ac(ag, ae, ab) then
					ad[ae] = ag
				end
			end
			return ad
		end
		return filter
	end
	function a.e3()
		local aa = a.load("d0")
		local function flatten(ab, ac)
			ac = if type(ac) == "number" then ac else math.huge
			local ad = {}
			for ae, ag in pairs(ab) do
				if type(ag) == "table" and ac > 0 then
					local ah = flatten(ag, ac - 1)
					for ai, aj in pairs(ad) do
						ah[ai] = aj
					end
					ad = ah
				else
					ad[ae] = ag
				end
			end
			return ad
		end
		return flatten
	end
	function a.e4()
		local function flip(aa)
			local ab = {}
			for ac, ad in pairs(aa) do
				ab[ad] = ac
			end
			return ab
		end
		return flip
	end
	function a.e5()
		local aa = a.load("d0")
		local ab = a.load("eW")
		local function freeze(ac)
			local ad = ab(ac)
			table.freeze(ad)
			return ad
		end
		return freeze
	end
	function a.e6()
		local aa = a.load("d0")
		local function freezeDeep(ab)
			local ac = {}
			for ad, ae in pairs(ab) do
				if type(ae) == "table" then
					ac[ad] = freezeDeep(ae)
				else
					ac[ad] = ae
				end
			end
			table.freeze(ac)
			return ac
		end
		return freezeDeep
	end
	function a.e7()
		local function fromArrays(aa, ab)
			local ac = #aa
			local ad = {}
			for ae = 1, ac do
				ad[aa[ae]] = ab[ae]
			end
			return ad
		end
		return fromArrays
	end
	function a.e8()
		local function fromEntries(aa)
			local ab = {}
			for ac, ad in ipairs(aa) do
				ab[ad[1]] = ad[2]
			end
			return ab
		end
		return fromEntries
	end
	function a.e9()
		local aa = a.load("d0")
		local function has(ab, ac)
			return ab[ac] ~= nil
		end
		return has
	end
	function a.fa()
		local function includes(aa, ab)
			for ac, ad in pairs(aa) do
				if ad == ab then
					return true
				end
			end
			return false
		end
		return includes
	end
	function a.fb()
		local function keys(aa)
			local ab = {}
			for ac in pairs(aa) do
				table.insert(ab, ac)
			end
			return ab
		end
		return keys
	end
	function a.fc()
		local function map(aa, ab)
			local ac = {}
			for ad, ae in pairs(aa) do
				local ag, ah = ab(ae, ad, aa)
				ac[ah or ad] = ag
			end
			return ac
		end
		return map
	end
	function a.fd()
		local aa = a.load("d_")
		local function merge(...)
			local ab = {}
			for ac = 1, select("#", ...) do
				local ad = select(ac, ...)
				if type(ad) ~= "table" then
					continue
				end
				for ae, ag in pairs(ad) do
					ab[ae] = if ag == aa then nil else ag
				end
			end
			return ab
		end
		return merge
	end
	function a.fe()
		local aa = a.load("d_")
		local ab = a.load("eX")
		local function mergeDeep(...)
			local ac = {}
			for ad = 1, select("#", ...) do
				local ae = select(ad, ...)
				if type(ae) ~= "table" then
					continue
				end
				for ag, ah in pairs(ae) do
					if ah == aa then
						ac[ag] = nil
					elseif type(ah) == "table" then
						if ac[ag] == nil or type(ac[ag]) ~= "table" then
							ac[ag] = ab(ah)
						else
							ac[ag] = mergeDeep(ac[ag], ah)
						end
					else
						ac[ag] = ah
					end
				end
			end
			return ac
		end
		return mergeDeep
	end
	function a.ff()
		local aa = a.load("eW")
		local function removeKey(ab, ac)
			local ad = aa(ab)
			ad[ac] = nil
			return ad
		end
		return removeKey
	end
	function a.fg()
		local aa = a.load("eW")
		local function removeKeys(ab, ...)
			local ac = aa(ab)
			for ad, ae in ipairs({ ... }) do
				ac[ae] = nil
			end
			return ac
		end
		return removeKeys
	end
	function a.fh()
		local function removeValue(aa, ab)
			local ac = {}
			for ad, ae in pairs(aa) do
				if ae ~= ab then
					ac[ad] = ae
				end
			end
			return ac
		end
		return removeValue
	end
	function a.fi()
		local aa = a.load("ef")
		local function removeValues(ab, ...)
			local ac = aa({ ... })
			local ad = {}
			for ae, ag in pairs(ab) do
				if not ac[ag] then
					ad[ae] = ag
				end
			end
			return ad
		end
		return removeValues
	end
	function a.fj()
		local aa = a.load("eW")
		local function set(ab, ac, ad)
			local ae = aa(ab)
			ae[ac] = ad
			return ae
		end
		return set
	end
	function a.fk()
		local function some(aa, ab)
			for ac, ad in pairs(aa) do
				if ab(ad, ac, aa) then
					return true
				end
			end
			return false
		end
		return some
	end
	function a.fl()
		local aa = a.load("eW")
		local function update(ab, ac, ad, ae)
			local ag = aa(ab)
			if ag[ac] then
				if ad then
					ag[ac] = ad(ag[ac], ac)
				end
			else
				if typeof(ae) == "function" then
					ag[ac] = ae(ac)
				end
			end
			return ag
		end
		return update
	end
	function a.fm()
		local function values(aa)
			local ab = {}
			for ac, ad in pairs(aa) do
				table.insert(ab, ad)
			end
			return ab
		end
		return values
	end
	function a.fn()
		local function withKeys(aa, ...)
			local ab = {}
			for ac, ad in ipairs({ ... }) do
				ab[ad] = aa[ad]
			end
			return ab
		end
		return withKeys
	end
	function a.fo()
		local aa = {
			copy = a.load("eW"),
			copyDeep = a.load("eX"),
			count = a.load("eY"),
			entries = a.load("eZ"),
			equals = a.load("e_"),
			equalsDeep = a.load("e0"),
			every = a.load("e1"),
			filter = a.load("e2"),
			flatten = a.load("e3"),
			flip = a.load("e4"),
			freeze = a.load("e5"),
			freezeDeep = a.load("e6"),
			fromArrays = a.load("e7"),
			fromEntries = a.load("e8"),
			has = a.load("e9"),
			includes = a.load("fa"),
			keys = a.load("fb"),
			map = a.load("fc"),
			merge = a.load("fd"),
			mergeDeep = a.load("fe"),
			removeKey = a.load("ff"),
			removeKeys = a.load("fg"),
			removeValue = a.load("fh"),
			removeValues = a.load("fi"),
			set = a.load("fj"),
			some = a.load("fk"),
			update = a.load("fl"),
			values = a.load("fm"),
			withKeys = a.load("fn"),
		}
		aa.join = aa.merge
		aa.joinDeep = aa.mergeDeep
		return aa
	end
	function a.fp()
		local function add(aa, ...)
			local ab = {}
			for ac, ad in pairs(aa) do
				ab[ac] = true
			end
			for ac, ad in ipairs({ ... }) do
				ab[ad] = true
			end
			return ab
		end
		return add
	end
	function a.fq()
		local aa = a.load("eW")
		return aa
	end
	function a.fr()
		local aa = a.load("d9")
		local function count(ab, ac)
			local ad = 0
			ac = if type(ac) == "function" then ac else aa.func.truthy
			for ae, ag in pairs(ab) do
				if ac(ae, ab) then
					ad += 1
				end
			end
			return ad
		end
		return count
	end
	function a.fs()
		local function delete(aa, ...)
			local ab = {}
			for ac, ad in pairs(aa) do
				ab[ac] = true
			end
			for ac, ad in ipairs({ ... }) do
				ab[ad] = nil
			end
			return ab
		end
		return delete
	end
	function a.ft()
		local aa = a.load("d9")
		local function filter(ab, ac)
			local ad = {}
			ac = if type(ac) == "function" then ac else aa.func.truthy
			for ae, ag in pairs(ab) do
				if ac(ae, ab) then
					ad[ae] = true
				end
			end
			return ad
		end
		return filter
	end
	function a.fu()
		local function has(aa, ab)
			return aa[ab] == true
		end
		return has
	end
	function a.fv()
		local function intersection(...)
			local aa = select("#", ...)
			local ab = select(1, ...)
			local ac = {}
			for ad, ae in pairs(ab) do
				local ag = true
				for ah = 2, aa do
					local ai = select(ah, ...)
					if ai[ad] ~= true then
						ag = false
						break
					end
				end
				if ag then
					ac[ad] = true
				end
			end
			return ac
		end
		return intersection
	end
	function a.fw()
		local function isSubset(aa, ab)
			for ac, ad in pairs(aa) do
				if ab[ac] ~= ad then
					return false
				end
			end
			return true
		end
		return isSubset
	end
	function a.fx()
		local aa = a.load("fw")
		local function isSuperset(ab, ac)
			return aa(ac, ab)
		end
		return isSuperset
	end
	function a.fy()
		local function map(aa, ab)
			local ac = {}
			for ad, ae in pairs(aa) do
				local ag = ab(ad, aa)
				if ag ~= nil then
					ac[ag] = true
				end
			end
			return ac
		end
		return map
	end
	function a.fz()
		local function merge(...)
			local aa = {}
			for ab = 1, select("#", ...) do
				local ac = select(ab, ...)
				if type(ac) ~= "table" then
					continue
				end
				for ad, ae in pairs(ac) do
					aa[ad] = true
				end
			end
			return aa
		end
		return merge
	end
	function a.fA()
		local aa = {
			add = a.load("fp"),
			copy = a.load("fq"),
			count = a.load("fr"),
			delete = a.load("fs"),
			difference = a.load("eg"),
			differenceSymmetric = a.load("ei"),
			filter = a.load("ft"),
			fromArray = a.load("ec"),
			has = a.load("fu"),
			intersection = a.load("fv"),
			isSubset = a.load("fw"),
			isSuperset = a.load("fx"),
			map = a.load("fy"),
			merge = a.load("fz"),
			toArray = a.load("ed"),
		}
		aa.fromList = aa.fromArray
		aa.join = aa.merge
		aa.subtract = aa.delete
		aa.union = aa.merge
		return aa
	end
	function a.fB()
		local aa = a.load("d0")
		local ab = {
			Array = a.load("eV"),
			Dictionary = a.load("fo"),
			Set = a.load("fA"),
			None = a.load("d_"),
			Types = a.load("d0"),
			equalObjects = a.load("d6"),
			isEmpty = a.load("d8"),
		}
		ab.List = ab.Array
		return ab
	end
	function a.fC()
		local aa = a.load("fB")
		return aa
	end
	function a.fD()
		local aa = table.create(500)
		local function RunFunction(ab, ac, ...)
			ab(...)
			table.insert(aa, ac)
		end
		local function Yield()
			while true do
				RunFunction(coroutine.yield())
			end
		end
		local function FastDefer(ab, ...)
			local ac
			local ad = #aa
			if ad > 0 then
				ac = aa[ad]
				aa[ad] = nil
			else
				ac = coroutine.create(Yield)
				coroutine.resume(ac)
			end
			return task.defer(ac, ab, ac, ...)
		end
		return FastDefer
	end
	function a.fE()
		local aa = "Non-promise value passed into %s at index %s"
		local ab = "Please pass a list of promises to %s"
		local ac = "Please pass a handler function to %s!"
		local ad = { __mode = "k" }
		local function isCallable(ae)
			if type(ae) == "function" then
				return true
			end
			if type(ae) == "table" then
				local ag = getmetatable(ae)
				if ag and type(rawget(ag, "__call")) == "function" then
					return true
				end
			end
			return false
		end
		local function makeEnum(ae, ag)
			local ah = {}
			for ai, aj in ipairs(ag) do
				ah[aj] = aj
			end
			return setmetatable(ah, {
				__index = function(ai, aj)
					error(string.format("%s is not in %s!", aj, ae), 2)
				end,
				__newindex = function()
					error(string.format("Creating new members in %s is not allowed!", ae), 2)
				end,
			})
		end
		local ae
		do
			ae = {
				Kind = makeEnum(
					"Promise.Error.Kind",
					{ "ExecutionError", "AlreadyCancelled", "NotResolvedInTime", "TimedOut" }
				),
			}
			ae.__index = ae
			function ae.new(ag, ah)
				ag = ag or {}
				return setmetatable(
					{
						error = tostring(ag.error) or "[This error has no error text.]",
						trace = ag.trace,
						context = ag.context,
						kind = ag.kind,
						parent = ah,
						createdTick = os.clock(),
						createdTrace = debug.traceback(),
					},
					ae
				)
			end
			function ae.is(ag)
				if type(ag) == "table" then
					local ah = getmetatable(ag)
					if type(ah) == "table" then
						return rawget(ag, "error") ~= nil and type(rawget(ah, "extend")) == "function"
					end
				end
				return false
			end
			function ae.isKind(ag, ah)
				assert(ah ~= nil, "Argument #2 to Promise.Error.isKind must not be nil")
				return ae.is(ag) and ag.kind == ah
			end
			function ae:extend(ag)
				ag = ag or {}
				ag.kind = ag.kind or self.kind
				return ae.new(ag, self)
			end
			function ae:getErrorChain()
				local ag = { self }
				while ag[#ag].parent do
					table.insert(ag, ag[#ag].parent)
				end
				return ag
			end
			function ae:__tostring()
				local ag = { string.format("-- Promise.Error(%s) --", self.kind or "?") }
				for ah, ai in ipairs(self.getErrorChain(self)) do
					table.insert(ag, table.concat({ ai.trace or ai.error, ai.context }, "\n"))
				end
				return table.concat(ag, "\n")
			end
		end
		local function pack(...)
			return select("#", ...), { ... }
		end
		local function packResult(ag, ...)
			return ag, select("#", ...), { ... }
		end
		local function makeErrorHandler(ag)
			assert(ag ~= nil, "traceback is nil")
			return function(ah)
				if type(ah) == "table" then
					return ah
				end
				return ae.new({
					error = ah,
					kind = ae.Kind.ExecutionError,
					trace = debug.traceback(tostring(ah), 2),
					context = "Promise created at:\n\n" .. ag,
				})
			end
		end
		local function runExecutor(ag, ah, ...)
			return packResult(xpcall(ah, makeErrorHandler(ag), ...))
		end
		local function createAdvancer(ag, ah, ai, aj)
			return function(...)
				local ak, am, an = runExecutor(ag, ah, ...)
				if ak then
					ai(unpack(an, 1, am))
				else
					aj(an[1])
				end
			end
		end
		local function isEmpty(ag)
			return next(ag) == nil
		end
		local ag = {
			Error = ae,
			Status = makeEnum("Promise.Status", { "Started", "Resolved", "Rejected", "Cancelled" }),
			_getTime = os.clock,
			_timeEvent = cloneref(game.GetService(game, "RunService")).Heartbeat,
			_unhandledRejectionCallbacks = {},
		}
		ag.prototype = {}
		ag.__index = ag.prototype
		function ag._new(ah, ai, aj)
			if aj ~= nil and not ag.is(aj) then
				error("Argument #2 to Promise.new must be a promise or nil", 2)
			end
			local ak = {
				_thread = nil,
				_source = ah,
				_status = ag.Status.Started,
				_values = nil,
				_valuesLength = -1,
				_unhandledRejection = true,
				_queuedResolve = {},
				_queuedReject = {},
				_queuedFinally = {},
				_cancellationHook = nil,
				_parent = aj,
				_consumers = setmetatable({}, ad),
			}
			if aj and aj._status == ag.Status.Started then
				aj._consumers[ak] = true
			end
			setmetatable(ak, ag)
			local function resolve(...)
				ak._resolve(ak, ...)
			end
			local function reject(...)
				ak._reject(ak, ...)
			end
			local function onCancel(am)
				if am then
					if ak._status == ag.Status.Cancelled then
						am()
					else
						ak._cancellationHook = am
					end
				end
				return ak._status == ag.Status.Cancelled
			end
			ak._thread = coroutine.create(function()
				local am, an, ao = runExecutor(ak._source, ai, resolve, reject, onCancel)
				if not am then
					reject(ao[1])
				end
			end)
			task.spawn(ak._thread)
			return ak
		end
		function ag.new(ah)
			return ag._new(debug.traceback(nil, 2), ah)
		end
		function ag:__tostring()
			return string.format("Promise(%s)", self._status)
		end
		function ag.defer(ah)
			local ai = debug.traceback(nil, 2)
			local aj
			aj = ag._new(ai, function(ak, am, an)
				local ao
				ao = ag._timeEvent:Connect(function()
					ao.Disconnect(ao)
					local ap, aq, ar = runExecutor(ai, ah, ak, am, an)
					if not ap then
						am(ar[1])
					end
				end)
			end)
			return aj
		end
		ag.async = ag.defer
		function ag.resolve(...)
			local ah, ai = pack(...)
			return ag._new(debug.traceback(nil, 2), function(aj)
				aj(unpack(ai, 1, ah))
			end)
		end
		function ag.reject(...)
			local ah, ai = pack(...)
			return ag._new(debug.traceback(nil, 2), function(aj, ak)
				ak(unpack(ai, 1, ah))
			end)
		end
		function ag._try(ah, ai, ...)
			local aj, ak = pack(...)
			return ag._new(ah, function(am)
				am(ai(unpack(ak, 1, aj)))
			end)
		end
		function ag.try(ah, ...)
			return ag._try(debug.traceback(nil, 2), ah, ...)
		end
		function ag._all(ah, ai, aj)
			if type(ai) ~= "table" then
				error(string.format(ab, "Promise.all"), 3)
			end
			for ak, am in pairs(ai) do
				if not ag.is(am) then
					error(string.format(aa, "Promise.all", tostring(ak)), 3)
				end
			end
			if #ai == 0 or aj == 0 then
				return ag.resolve({})
			end
			return ag._new(ah, function(ak, am, an)
				local ao = {}
				local ap = {}
				local aq = 0
				local ar = 0
				local as = false
				local function cancel()
					for au, av in ipairs(ap) do
						av.cancel(av)
					end
				end
				local function resolveOne(au, ...)
					if as then
						return
					end
					aq = aq + 1
					if aj == nil then
						ao[au] = ...
					else
						ao[aq] = ...
					end
					if aq >= (aj or #ai) then
						as = true
						ak(ao)
						cancel()
					end
				end
				an(cancel)
				for au, av in ipairs(ai) do
					ap[au] = av.andThen(av, function(...)
						resolveOne(au, ...)
					end, function(...)
						ar = ar + 1
						if aj == nil or #ai - ar < aj then
							cancel()
							as = true
							am(...)
						end
					end)
				end
				if as then
					cancel()
				end
			end)
		end
		function ag.all(ah)
			return ag._all(debug.traceback(nil, 2), ah)
		end
		function ag.fold(ah, ai, aj)
			assert(type(ah) == "table", "Bad argument #1 to Promise.fold: must be a table")
			assert(isCallable(ai), "Bad argument #2 to Promise.fold: must be a function")
			local ak = ag.resolve(aj)
			return ag.each(ah, function(am, an)
				ak = ak.andThen(ak, function(ao)
					return ai(ao, am, an)
				end)
			end):andThen(function()
				return ak
			end)
		end
		function ag.some(ah, ai)
			assert(type(ai) == "number", "Bad argument #2 to Promise.some: must be a number")
			return ag._all(debug.traceback(nil, 2), ah, ai)
		end
		function ag.any(ah)
			return ag._all(debug.traceback(nil, 2), ah, 1):andThen(function(ai)
				return ai[1]
			end)
		end
		function ag.allSettled(ah)
			if type(ah) ~= "table" then
				error(string.format(ab, "Promise.allSettled"), 2)
			end
			for ai, aj in pairs(ah) do
				if not ag.is(aj) then
					error(string.format(aa, "Promise.allSettled", tostring(ai)), 2)
				end
			end
			if #ah == 0 then
				return ag.resolve({})
			end
			return ag._new(debug.traceback(nil, 2), function(ai, aj, ak)
				local am = {}
				local an = {}
				local ao = 0
				local function resolveOne(ap, ...)
					ao = ao + 1
					am[ap] = ...
					if ao >= #ah then
						ai(am)
					end
				end
				ak(function()
					for ap, aq in ipairs(an) do
						aq.cancel(aq)
					end
				end)
				for ap, aq in ipairs(ah) do
					an[ap] = aq.finally(aq, function(...)
						resolveOne(ap, ...)
					end)
				end
			end)
		end
		function ag.race(ah)
			assert(type(ah) == "table", string.format(ab, "Promise.race"))
			for ai, aj in pairs(ah) do
				assert(ag.is(aj), string.format(aa, "Promise.race", tostring(ai)))
			end
			return ag._new(debug.traceback(nil, 2), function(ai, aj, ak)
				local am = {}
				local an = false
				local function cancel()
					for ao, ap in ipairs(am) do
						ap.cancel(ap)
					end
				end
				local function finalize(ao)
					return function(...)
						cancel()
						an = true
						return ao(...)
					end
				end
				if ak(finalize(aj)) then
					return
				end
				for ao, ap in ipairs(ah) do
					am[ao] = ap.andThen(ap, finalize(ai), finalize(aj))
				end
				if an then
					cancel()
				end
			end)
		end
		function ag.each(ah, ai)
			assert(type(ah) == "table", string.format(ab, "Promise.each"))
			assert(isCallable(ai), string.format(ac, "Promise.each"))
			return ag._new(debug.traceback(nil, 2), function(aj, ak, am)
				local an = {}
				local ao = {}
				local ap = false
				local function cancel()
					for aq, ar in ipairs(ao) do
						ar.cancel(ar)
					end
				end
				am(function()
					ap = true
					cancel()
				end)
				local aq = {}
				for ar, as in ipairs(ah) do
					if ag.is(as) then
						if as.getStatus(as) == ag.Status.Cancelled then
							cancel()
							return ak(
								ae.new({
									error = "Promise is cancelled",
									kind = ae.Kind.AlreadyCancelled,
									context = string.format(
										"The Promise that was part of the array at index %d passed into Promise.each was already cancelled when Promise.each began.\n\nThat Promise was created at:\n\n%s",
										ar,
										as._source
									),
								})
							)
						elseif as.getStatus(as) == ag.Status.Rejected then
							cancel()
							return ak(select(2, as.await(as)))
						end
						local au = as.andThen(as, function(...)
							return ...
						end)
						table.insert(ao, au)
						aq[ar] = au
					else
						aq[ar] = as
					end
				end
				for ar, as in ipairs(aq) do
					if ag.is(as) then
						local au
						au, as = as.await(as)
						if not au then
							cancel()
							return ak(as)
						end
					end
					if ap then
						return
					end
					local au = ag.resolve(ai(as, ar))
					table.insert(ao, au)
					local av, aw = au.await(au)
					if not av then
						cancel()
						return ak(aw)
					end
					an[ar] = aw
				end
				aj(an)
			end)
		end
		function ag.is(ah)
			if type(ah) ~= "table" then
				return false
			end
			local ai = getmetatable(ah)
			if ai == ag then
				return true
			elseif ai == nil then
				return isCallable(ah.andThen)
			elseif
				type(ai) == "table"
				and type(rawget(ai, "__index")) == "table"
				and isCallable(rawget(rawget(ai, "__index"), "andThen"))
			then
				return true
			end
			return false
		end
		function ag.promisify(ah)
			return function(...)
				return ag._try(debug.traceback(nil, 2), ah, ...)
			end
		end
		do
			local ah
			local ai
			function ag.delay(aj)
				assert(type(aj) == "number", "Bad argument #1 to Promise.delay, must be a number.")
				if not (aj >= 1.6666666666666665E-2) or aj == math.huge then
					aj = 1.6666666666666665E-2
				end
				return ag._new(debug.traceback(nil, 2), function(ak, am, an)
					local ao = ag._getTime()
					local ap = ao + aj
					local aq = { resolve = ak, startTime = ao, endTime = ap }
					if ai == nil then
						ah = aq
						ai = ag._timeEvent:Connect(function()
							local ar = ag._getTime()
							while ah ~= nil and ah.endTime < ar do
								local as = ah
								ah = as.next
								if ah == nil then
									ai.Disconnect(ai)
									ai = nil
								else
									ah.previous = nil
								end
								as.resolve(ag._getTime() - as.startTime)
							end
						end)
					else
						if ah.endTime < ap then
							local ar = ah
							local as = ar.next
							while as ~= nil and as.endTime < ap do
								ar = as
								as = ar.next
							end
							ar.next = aq
							aq.previous = ar
							if as ~= nil then
								aq.next = as
								as.previous = aq
							end
						else
							aq.next = ah
							ah.previous = aq
							ah = aq
						end
					end
					an(function()
						local ar = aq.next
						if ah == aq then
							if ar == nil then
								ai.Disconnect(ai)
								ai = nil
							else
								ar.previous = nil
							end
							ah = ar
						else
							local as = aq.previous
							as.next = ar
							if ar ~= nil then
								ar.previous = as
							end
						end
					end)
				end)
			end
		end
		function ag.prototype:timeout(ah, ai)
			local aj = debug.traceback(nil, 2)
			return ag.race({
				ag.delay(ah):andThen(function()
					return ag.reject(
						ai == nil
								and ae.new({
									kind = ae.Kind.TimedOut,
									error = "Timed out",
									context = string.format(
										"Timeout of %d seconds exceeded.\n:timeout() called at:\n\n%s",
										ah,
										aj
									),
								})
							or ai
					)
				end),
				self,
			})
		end
		function ag.prototype:getStatus()
			return self._status
		end
		function ag.prototype:_andThen(ah, ai, aj)
			self._unhandledRejection = false
			if self._status == ag.Status.Cancelled then
				local ak = ag.new(function() end)
				ak.cancel(ak)
				return ak
			end
			return ag._new(ah, function(ak, am, an)
				local ao = ak
				if ai then
					ao = createAdvancer(ah, ai, ak, am)
				end
				local ap = am
				if aj then
					ap = createAdvancer(ah, aj, ak, am)
				end
				if self._status == ag.Status.Started then
					table.insert(self._queuedResolve, ao)
					table.insert(self._queuedReject, ap)
					an(function()
						if self._status == ag.Status.Started then
							table.remove(self._queuedResolve, table.find(self._queuedResolve, ao))
							table.remove(self._queuedReject, table.find(self._queuedReject, ap))
						end
					end)
				elseif self._status == ag.Status.Resolved then
					ao(unpack(self._values, 1, self._valuesLength))
				elseif self._status == ag.Status.Rejected then
					ap(unpack(self._values, 1, self._valuesLength))
				end
			end, self)
		end
		function ag.prototype:andThen(ah, ai)
			assert(ah == nil or isCallable(ah), string.format(ac, "Promise:andThen"))
			assert(ai == nil or isCallable(ai), string.format(ac, "Promise:andThen"))
			return self._andThen(self, debug.traceback(nil, 2), ah, ai)
		end
		function ag.prototype:catch(ah)
			assert(ah == nil or isCallable(ah), string.format(ac, "Promise:catch"))
			return self._andThen(self, debug.traceback(nil, 2), nil, ah)
		end
		function ag.prototype:tap(ah)
			assert(isCallable(ah), string.format(ac, "Promise:tap"))
			return self._andThen(self, debug.traceback(nil, 2), function(...)
				local ai = ah(...)
				if ag.is(ai) then
					local aj, ak = pack(...)
					return ai.andThen(ai, function()
						return unpack(ak, 1, aj)
					end)
				end
				return ...
			end)
		end
		function ag.prototype:andThenCall(ah, ...)
			assert(isCallable(ah), string.format(ac, "Promise:andThenCall"))
			local ai, aj = pack(...)
			return self._andThen(self, debug.traceback(nil, 2), function()
				return ah(unpack(aj, 1, ai))
			end)
		end
		function ag.prototype:andThenReturn(...)
			local ah, ai = pack(...)
			return self._andThen(self, debug.traceback(nil, 2), function()
				return unpack(ai, 1, ah)
			end)
		end
		function ag.prototype:cancel()
			if self._status ~= ag.Status.Started then
				return
			end
			self._status = ag.Status.Cancelled
			if self._cancellationHook then
				self._cancellationHook()
			end
			coroutine.close(self._thread)
			if self._parent then
				self._parent:_consumerCancelled(self)
			end
			for ah in pairs(self._consumers) do
				ah.cancel(ah)
			end
			self._finalize(self)
		end
		function ag.prototype:_consumerCancelled(ah)
			if self._status ~= ag.Status.Started then
				return
			end
			self._consumers[ah] = nil
			if next(self._consumers) == nil then
				self.cancel(self)
			end
		end
		function ag.prototype:_finally(ah, ai)
			self._unhandledRejection = false
			local aj = ag._new(ah, function(aj, ak, am)
				local an
				am(function()
					self._consumerCancelled(self, self)
					if an then
						an.cancel(an)
					end
				end)
				local ao = aj
				if ai then
					ao = function(...)
						local ap = ai(...)
						if ag.is(ap) then
							an = ap
							ap.finally(ap, function(aq)
								if aq ~= ag.Status.Rejected then
									aj(self)
								end
							end):catch(function(...)
								ak(...)
							end)
						else
							aj(self)
						end
					end
				end
				if self._status == ag.Status.Started then
					table.insert(self._queuedFinally, ao)
				else
					ao(self._status)
				end
			end)
			return aj
		end
		function ag.prototype:finally(ah)
			assert(ah == nil or isCallable(ah), string.format(ac, "Promise:finally"))
			return self._finally(self, debug.traceback(nil, 2), ah)
		end
		function ag.prototype:finallyCall(ah, ...)
			assert(isCallable(ah), string.format(ac, "Promise:finallyCall"))
			local ai, aj = pack(...)
			return self._finally(self, debug.traceback(nil, 2), function()
				return ah(unpack(aj, 1, ai))
			end)
		end
		function ag.prototype:finallyReturn(...)
			local ah, ai = pack(...)
			return self._finally(self, debug.traceback(nil, 2), function()
				return unpack(ai, 1, ah)
			end)
		end
		function ag.prototype:awaitStatus()
			self._unhandledRejection = false
			if self._status == ag.Status.Started then
				local ah = coroutine.running()
				self.finally(self, function()
					task.spawn(ah)
				end):catch(function() end)
				coroutine.yield()
			end
			if self._status == ag.Status.Resolved then
				return self._status, unpack(self._values, 1, self._valuesLength)
			elseif self._status == ag.Status.Rejected then
				return self._status, unpack(self._values, 1, self._valuesLength)
			end
			return self._status
		end
		local function awaitHelper(ah, ...)
			return ah == ag.Status.Resolved, ...
		end
		function ag.prototype:await()
			return awaitHelper(self.awaitStatus(self))
		end
		local function expectHelper(ah, ...)
			if ah ~= ag.Status.Resolved then
				error((...) == nil and "Expected Promise rejected with no value." or (...), 3)
			end
			return ...
		end
		function ag.prototype:expect()
			return expectHelper(self.awaitStatus(self))
		end
		ag.prototype.awaitValue = ag.prototype.expect
		function ag.prototype:_unwrap()
			if self._status == ag.Status.Started then
				error("Promise has not resolved or rejected.", 2)
			end
			local ah = self._status == ag.Status.Resolved
			return ah, unpack(self._values, 1, self._valuesLength)
		end
		function ag.prototype:_resolve(...)
			if self._status ~= ag.Status.Started then
				if ag.is((...)) then
					(...):_consumerCancelled(self)
				end
				return
			end
			if ag.is((...)) then
				if select("#", ...) > 1 then
					local ah = string.format(
						"When returning a Promise from andThen, extra arguments are discarded! See:\n\n%s",
						self._source
					)
					warn(ah)
				end
				local ah = ...
				local ai = ah.andThen(ah, function(...)
					self._resolve(self, ...)
				end, function(...)
					local ai = ah._values[1]
					if ah._error then
						ai = ae.new({
							error = ah._error,
							kind = ae.Kind.ExecutionError,
							context = "[No stack trace available as this Promise originated from an older version of the Promise library (< v2)]",
						})
					end
					if ae.isKind(ai, ae.Kind.ExecutionError) then
						return self._reject(
							self,
							ai.extend(
								ai,
								{
									error = "This Promise was chained to a Promise that errored.",
									trace = "",
									context = string.format(
										"The Promise at:\n\n%s\n...Rejected because it was chained to the following Promise, which encountered an error:\n",
										self._source
									),
								}
							)
						)
					end
					self._reject(self, ...)
				end)
				if ai._status == ag.Status.Cancelled then
					self.cancel(self)
				elseif ai._status == ag.Status.Started then
					self._parent = ai
					ai._consumers[self] = true
				end
				return
			end
			self._status = ag.Status.Resolved
			self._valuesLength, self._values = pack(...)
			for ah, ai in ipairs(self._queuedResolve) do
				coroutine.wrap(ai)(...)
			end
			self._finalize(self)
		end
		function ag.prototype:_reject(...)
			if self._status ~= ag.Status.Started then
				return
			end
			self._status = ag.Status.Rejected
			self._valuesLength, self._values = pack(...)
			if not isEmpty(self._queuedReject) then
				for ah, ai in ipairs(self._queuedReject) do
					coroutine.wrap(ai)(...)
				end
			else
				local ah = tostring((...))
				coroutine.wrap(function()
					ag._timeEvent:Wait()
					if not self._unhandledRejection then
						return
					end
					local ai = string.format("Unhandled Promise rejection:\n\n%s\n\n%s", ah, self._source)
					for aj, ak in ipairs(ag._unhandledRejectionCallbacks) do
						task.spawn(ak, self, unpack(self._values, 1, self._valuesLength))
					end
					if ag.TEST then
						return
					end
					warn(ai)
				end)()
			end
			self._finalize(self)
		end
		function ag.prototype:_finalize()
			for ah, ai in ipairs(self._queuedFinally) do
				coroutine.wrap(ai)(self._status)
			end
			self._queuedFinally = nil
			self._queuedReject = nil
			self._queuedResolve = nil
			if not ag.TEST then
				self._parent = nil
				self._consumers = nil
			end
			task.defer(coroutine.close, self._thread)
		end
		function ag.prototype:now(ah)
			local ai = debug.traceback(nil, 2)
			if self._status == ag.Status.Resolved then
				return self._andThen(self, ai, function(...)
					return ...
				end)
			else
				return ag.reject(
					ah == nil
							and ae.new({
								kind = ae.Kind.NotResolvedInTime,
								error = "This Promise was not resolved in time for :now()",
								context = ":now() was called at:\n\n" .. ai,
							})
						or ah
				)
			end
		end
		function ag.retry(ah, ai, ...)
			assert(isCallable(ah), "Parameter #1 to Promise.retry must be a function")
			assert(type(ai) == "number", "Parameter #2 to Promise.retry must be a number")
			local aj, ak = { ... }, select("#", ...)
			return ag.resolve(ah(...)):catch(function(...)
				if ai > 0 then
					return ag.retry(ah, ai - 1, unpack(aj, 1, ak))
				else
					return ag.reject(...)
				end
			end)
		end
		function ag.retryWithDelay(ah, ai, aj, ...)
			assert(isCallable(ah), "Parameter #1 to Promise.retry must be a function")
			assert(type(ai) == "number", "Parameter #2 (times) to Promise.retry must be a number")
			assert(type(aj) == "number", "Parameter #3 (seconds) to Promise.retry must be a number")
			local ak, am = { ... }, select("#", ...)
			return ag.resolve(ah(...)):catch(function(...)
				if ai > 0 then
					ag.delay(aj):await()
					return ag.retryWithDelay(ah, ai - 1, aj, unpack(ak, 1, am))
				else
					return ag.reject(...)
				end
			end)
		end
		function ag.fromEvent(ah, ai)
			ai = ai or function()
				return true
			end
			return ag._new(debug.traceback(nil, 2), function(aj, ak, am)
				local an
				local ao = false
				local function disconnect()
					an.Disconnect(an)
					an = nil
				end
				an = ah.Connect(ah, function(...)
					local ap = ai(...)
					if ap == true then
						aj(...)
						if an then
							disconnect()
						else
							ao = true
						end
					elseif type(ap) ~= "boolean" then
						error("Promise.fromEvent predicate should always return a boolean")
					end
				end)
				if ao and an then
					return disconnect()
				end
				am(disconnect)
			end)
		end
		function ag.onUnhandledRejection(ah)
			table.insert(ag._unhandledRejectionCallbacks, ah)
			return function()
				local ai = table.find(ag._unhandledRejectionCallbacks, ah)
				if ai then
					table.remove(ag._unhandledRejectionCallbacks, ai)
				end
			end
		end
		return ag
	end
	function a.fF()
		return a.load("fE")
	end
	function a.fG()
		local aa = (a.load("fF"))
		return aa
	end
	function a.fH()
		return a.load("fG")
	end
	function a.fI()
		local aa = cloneref or function(aa)
			return aa
		end
		local ab = a.load("fD")
		local ac = a.load("fH")
		local ad = setmetatable({}, {
			__tostring = function()
				return "LinkToInstanceIndex"
			end,
		})
		local ae = "Object is a %* and as such expected `true?` for the method name and instead got %*. Traceback: %*"
		local ag = "Object %* doesn't have method %*, are you sure you want to add it? Traceback: %*"
		local ah = "Invalid argument #1 to 'Janitor:AddPromise' (Promise expected, got %* (%*)) Traceback: %*"
		local ai = {}
		local aj = ai
		ai.ClassName = "Janitor"
		ai.CurrentlyCleaning = true
		ai.SuppressInstanceReDestroy = false
		ai.UnsafeThreadCleanup = false;
		(ai).__index = ai
		local ak = setmetatable({}, { __mode = "ks" })
		local am = { ["function"] = true, thread = true, RBXScriptConnection = "Disconnect" }
		function ai.new()
			return (setmetatable({
				CurrentlyCleaning = false,
			}, ai))
		end
		function ai.Is(an)
			return type(an) == "table" and getmetatable(an) == ai
		end
		ai.instanceof = ai.Is
		local an = game.Destroy
		local function Remove(ao, ap)
			local aq = ak[ao]
			if aq then
				local ar = aq[ap]
				if not ar then
					return ao
				end
				local as = ao[ar]
				if as then
					if as == true then
						if type(ar) == "function" then
							ar()
						else
							local au
							if coroutine.running() ~= ar then
								au = pcall(function()
									task.cancel(ar)
								end)
							end
							if not au then
								local av = ar
								if ao.UnsafeThreadCleanup then
									ab(function()
										task.cancel(av)
									end)
								else
									task.defer(function()
										task.cancel(av)
									end)
								end
							end
						end
					else
						if as == "Destroy" then
							if ao.SuppressInstanceReDestroy and typeof(ar) == "Instance" then
								pcall(an, ar)
							else
								local au = ar.Destroy
								if au then
									au(ar)
								end
							end
						elseif as == "Disconnect" then
							local au = ar.Disconnect
							if au then
								au(ar)
							end
						else
							local au = (ar)[as]
							if au then
								au(ar)
							end
						end
					end
					ao[ar] = nil
				end
				aq[ap] = nil
			end
			return ao
		end
		local function Add(ao, ap, aq, ar)
			if ar then
				Remove(ao, ar)
				local as = ak[ao]
				if not as then
					as = {}
					ak[ao] = as
				end
				as[ar] = ap
			end
			local as = typeof(ap)
			local au = aq or am[as] or "Destroy"
			if as == "function" or as == "thread" then
				if au ~= true then
					warn(string.format(ae, as, tostring(au), debug.traceback(nil, 2)))
				end
			else
				if not (ap)[au] then
					warn(string.format(ag, tostring(ap), tostring(au), debug.traceback(nil, 2)))
				end
			end
			ao[ap] = au
			return ap
		end
		aj.Add = Add
		function ai:AddObject(ao, ap, aq, ...)
			return Add(self, ao.new(...), ap, aq)
		end
		local function Get(ao, ap)
			local aq = ak[ao]
			return if aq then aq[ap] else nil
		end
		ai.Get = Get
		function ai:AddPromise(ao, ap)
			if not ac then
				return ao
			end
			if not ac.is(ao) then
				error(string.format(ah, typeof(ao), tostring(ao), debug.traceback(nil, 2)))
			end
			if ao.getStatus(ao) ~= ac.Status.Started then
				return ao
			end
			local aq = ap
			if aq == nil then
				aq = newproxy(false)
			end
			local ar = Add(
				self,
				ac.new(function(ar, as, au)
					if au(function()
						ao.cancel(ao)
					end) then
						return
					end
					ar(ao)
				end),
				"cancel",
				aq
			)
			ar.finally(ar, function()
				if Get(self, aq) == ar then
					Remove(self, aq)
				end
			end)
			return ar
		end
		aj.Remove = Remove
		function aj:RemoveNoClean(ao)
			local ap = ak[self]
			if ap then
				local aq = ap[ao]
				if aq then
					self[aq] = nil
					ap[ao] = nil
				end
			end
			return self
		end
		function ai:RemoveList(...)
			local ao = ak[self]
			if ao then
				local ap = select("#", ...)
				if ap == 1 then
					return Remove(self, ...)
				end
				if ap == 2 then
					local aq, ar = ...
					Remove(self, aq)
					Remove(self, ar)
					return self
				end
				if ap == 3 then
					local aq, ar, as = ...
					Remove(self, aq)
					Remove(self, ar)
					Remove(self, as)
					return self
				end
				for aq = 1, ap do
					local ar = select(aq, ...)
					Remove(self, ar)
				end
			end
			return self
		end
		function ai:RemoveListNoClean(...)
			local ao = ak[self]
			if ao then
				local ap = select("#", ...)
				if ap == 1 then
					local aq = ...
					local ar = ao[aq]
					if ar then
						self[ar] = nil
						ao[aq] = nil
					end
					return self
				end
				if ap == 2 then
					local aq, ar = ...
					local as = ao[aq]
					if as then
						self[as] = nil
						ao[aq] = nil
					end
					local au = ao[ar]
					if au then
						self[au] = nil
						ao[ar] = nil
					end
					return self
				end
				if ap == 3 then
					local aq, ar, as = ...
					local au = ao[aq]
					if au then
						self[au] = nil
						ao[aq] = nil
					end
					local av = ao[ar]
					if av then
						self[av] = nil
						ao[ar] = nil
					end
					local aw = ao[as]
					if aw then
						self[aw] = nil
						ao[as] = nil
					end
					return self
				end
				for aq = 1, ap do
					local ar = select(aq, ...)
					local as = ao[ar]
					if as then
						self[as] = nil
						ao[ar] = nil
					end
				end
			end
			return self
		end
		function ai:GetAll()
			local ao = ak[self]
			return if ao then table.freeze(table.clone(ao)) else {}
		end
		local function Cleanup(ao)
			if not ao.CurrentlyCleaning then
				local ap = ao.SuppressInstanceReDestroy
				local aq = ao.UnsafeThreadCleanup
				ao.CurrentlyCleaning = nil
				ao.SuppressInstanceReDestroy = nil
				ao.UnsafeThreadCleanup = nil
				local ar, as = next(ao)
				while ar and as do
					if as == true then
						if type(ar) == "function" then
							ar()
						else
							local au
							if coroutine.running() ~= ar then
								au = pcall(function()
									task.cancel(ar)
								end)
							end
							if not au then
								local av = ar
								if aq then
									ab(function()
										task.cancel(av)
									end)
								else
									task.defer(function()
										task.cancel(av)
									end)
								end
							end
						end
					else
						if as == "Destroy" then
							if ao.SuppressInstanceReDestroy and typeof(ar) == "Instance" then
								pcall(an, ar)
							else
								local au = ar.Destroy
								if au then
									au(ar)
								end
							end
						elseif as == "Disconnect" then
							local au = ar.Disconnect
							if au then
								au(ar)
							end
						else
							local au = (ar)[as]
							if au then
								au(ar)
							end
						end
					end
					ao[ar] = nil
					ar, as = next(ao, ar)
				end
				local au = ak[ao]
				if au then
					table.clear(au)
					ak[ao] = nil
				end
				ao.CurrentlyCleaning = false
				ao.SuppressInstanceReDestroy = ap
				ao.UnsafeThreadCleanup = aq
			end
		end
		aj.Cleanup = Cleanup
		function ai:Destroy()
			Cleanup(self)
			table.clear(self)
			setmetatable(self, nil)
		end
		aj.__call = Cleanup
		local function LinkToInstance(ao, ap, aq)
			local ar = if aq then newproxy(false) else ad
			return Add(
				ao,
				ap.Destroying:Connect(function()
					Cleanup(ao)
				end),
				"Disconnect",
				ar
			)
		end
		aj.LinkToInstance = LinkToInstance;
		(ai).LegacyLinkToInstance = LinkToInstance
		function ai:LinkToInstances(...)
			local ao = ai.new()
			for ap = 1, select("#", ...) do
				local aq = select(ap, ...)
				if typeof(aq) ~= "Instance" then
					continue
				end
				ao.Add(ao, LinkToInstance(self, aq, true), "Disconnect")
			end
			return ao
		end
		function aj:__tostring()
			return "Janitor"
		end
		return ai
	end
	function a.fJ()
		local aa = a.load("fI")
		return aa
	end
	function a.fK()
		local aa = a.load("fG")
		return aa
	end
	function a.fL()
		local aa
		local function acquireRunnerThreadAndCallEventHandler(ab, ...)
			local ac = aa
			aa = nil
			ab(...)
			aa = ac
		end
		local function runEventHandlerInFreeThread()
			while true do
				acquireRunnerThreadAndCallEventHandler(coroutine.yield())
			end
		end
		local ab = {}
		ab.__index = ab
		function ab.new(ac, ad)
			return setmetatable({ _connected = true, _signal = ac, _fn = ad, _next = false }, ab)
		end
		function ab:Disconnect()
			self._connected = false
			if self._signal._handlerListHead == self then
				self._signal._handlerListHead = self._next
			else
				local ac = self._signal._handlerListHead
				while ac and ac._next ~= self do
					ac = ac._next
				end
				if ac then
					ac._next = self._next
				end
			end
		end
		setmetatable(ab, {
			__index = function(ac, ad)
				error(
					("Attempt to get Connection::%s (not a valid member)").format(
						"Attempt to get Connection::%s (not a valid member)",
						tostring(ad)
					),
					2
				)
			end,
			__newindex = function(ac, ad)
				error(
					("Attempt to set Connection::%s (not a valid member)").format(
						"Attempt to set Connection::%s (not a valid member)",
						tostring(ad)
					),
					2
				)
			end,
		})
		local ac = {}
		ac.__index = ac
		function ac.new()
			return (setmetatable({ _handlerListHead = false }, ac))
		end
		function ac:Connect(ad)
			local ae = ab.new(self, ad)
			if self._handlerListHead then
				ae._next = self._handlerListHead
				self._handlerListHead = ae
			else
				self._handlerListHead = ae
			end
			return ae
		end
		function ac:DisconnectAll()
			self._handlerListHead = false
		end
		function ac:Fire(...)
			local ad = self._handlerListHead
			while ad do
				if ad._connected then
					if not aa then
						aa = coroutine.create(runEventHandlerInFreeThread)
						coroutine.resume(aa)
					end
					task.spawn(aa, ad._fn, ...)
				end
				ad = ad._next
			end
		end
		function ac:Wait()
			local ad = coroutine.running()
			local ae
			ae = self.Connect(self, function(...)
				ae.Disconnect(ae)
				task.spawn(ad, ...)
			end)
			return coroutine.yield()
		end
		function ac:Once(ad)
			local ae
			ae = self.Connect(self, function(...)
				if ae._connected then
					ae.Disconnect(ae)
				end
				ad(...)
			end)
			return ae
		end
		setmetatable(ac, {
			__index = function(ad, ae)
				error(
					("Attempt to get Signal::%s (not a valid member)").format(
						"Attempt to get Signal::%s (not a valid member)",
						tostring(ae)
					),
					2
				)
			end,
			__newindex = function(ad, ae)
				error(
					("Attempt to set Signal::%s (not a valid member)").format(
						"Attempt to set Signal::%s (not a valid member)",
						tostring(ae)
					),
					2
				)
			end,
		})
		return ac
	end
	function a.fM()
		local aa = a.load("fL")
		return aa
	end
	function a.fN()
		local aa = a.load("dE")
		return aa
	end
end
local aa = {
	React = a.load("bZ"),
	ReactRoblox = a.load("dq"),
	ReactRipple = a.load("dL"),
	ReactCharm = a.load("dY"),
	Charm = a.load("dZ"),
	Sift = a.load("fC"),
	Janitor = a.load("fJ"),
	Promise = a.load("fK"),
	Signal = a.load("fM"),
	Ripple = a.load("fN"),
}
if getgenv then
	((getgenv())).__limerence_pkgs = aa
else
	(_G).__limerence_pkgs = aa
end
return aa
