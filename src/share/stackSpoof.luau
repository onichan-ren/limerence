local stackSpoof = {}

stackSpoof.install = function(source: string): ()
	if getgenv().__limStackSpoof then
		return
	end
	getgenv().__limStackSpoof = true

	local renv = getrenv()
	local baseLevel = 0
	local realInfo = nil

	local spoofInfo = nil
	spoofInfo = LPH_NO_VIRTUALIZE(function(a: any, b: any, c: any): ...any
		if baseLevel == 0 then
			baseLevel = 2
			for level = 1, 4 do
				if realInfo(level, "f") == spoofInfo then
					baseLevel = level + 1
					break
				end
			end
		end

		local base = baseLevel
		local kind = type(a)
		local thread = nil
		local level = 0
		local target = nil
		local options = nil

		if kind == "number" then
			if a < 1 or type(b) ~= "string" then
				return realInfo(base + a - 1, b)
			end
			level = base + a - 1
			options = b
			target = realInfo(level, "f")
		elseif kind == "function" and type(b) == "string" then
			target = a
			options = b
		elseif kind == "thread" and type(b) == "number" and type(c) == "string" then
			level = b
			if a == coroutine.running() then
				level = base + b - 1
			end
			if b < 1 then
				return realInfo(a, level, c)
			end
			thread = a
			options = c
			target = realInfo(a, level, "f")
		else
			return realInfo(a, b, c)
		end

		local spoof = false
		if target ~= nil and isexecutorclosure(target) and not iscclosure(target) then
			if string.find(options, "s", 1, true) ~= nil then
				local caller = realInfo(base, "f")
				spoof = caller == nil or not isexecutorclosure(caller)
			end
		end

		if not spoof then
			if thread ~= nil then
				return realInfo(thread, level, options)
			elseif level == 0 then
				return realInfo(target, options)
			end
			return realInfo(level, options)
		end

		local results
		if thread ~= nil then
			results = table.pack(realInfo(thread, level, options))
		elseif level == 0 then
			results = table.pack(realInfo(target, options))
		else
			results = table.pack(realInfo(level, options))
		end

		local index = 1
		for i = 1, #options do
			local option = string.sub(options, i, i)
			if option == "s" then
				results[index] = source
				break
			end
			if option == "a" then
				index += 2
			else
				index += 1
			end
		end

		return table.unpack(results, 1, results.n)
	end)

	realInfo = oth.hook(renv.debug.info, spoofInfo)
end

return stackSpoof
