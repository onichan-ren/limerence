local protectInstance = require("@feature/protection/instanceProtection")
local instances = require("@share/instances")

local cloneFunction = clonefunction
local createInstance = instances.new
local isFunctionHooked = cloneFunction(isfunctionhooked)
local identifyExecutor = cloneFunction(identifyexecutor)
local setMetatable = cloneFunction(setmetatable)
local isCClosure = cloneFunction(iscclosure)
local getRawMetatable = cloneFunction(getrawmetatable)
local cloneRef = cloneFunction(cloneref)
local getInfo = cloneFunction(debug.getinfo)
local taskWait = cloneFunction(task.wait)
local getGC = getgc
local type = cloneFunction(type)
local pcallClone = cloneFunction(pcall)
local find = cloneFunction(string.find)
local tablePack = cloneFunction(table.pack)
local tableUnpack = cloneFunction(table.unpack)

local PlayersService = cloneRef(game:GetService("Players"))

export type ProtectionFlags = {
	[string]: {
		thread: boolean,
		detection: (flag: (message: string) -> ()) -> (),
	},
}

local ProtectionFlags: ProtectionFlags = {
	--[[antiHook = {
		thread = true,
		detection = LPH_JIT_MAX(function(flag)
			local executor = identifyExecutor()

			local checkedFunctions = {
				setfflag = {
					setfflag,
				},
				getfflag = {
					getfflag,
				},
				sethiddenproperty = {
					sethiddenproperty,
				},
				gethiddenproperty = {
					gethiddenproperty,
				},
				getgc = {
					getGC,
				},
			}

			local c = "=[C]"

			local function checkFunction(func)
				if not isCClosure(func) or getInfo(func).source ~= c then
					return false
				end

				if isFunctionHooked(func) then
					return false
				end

				return true
			end

			-- > 1 index = hooked

			local gc = getGC(false)
			local funcCounts = {}

			if executor == "Potassium" then
				funcCounts.setfflag = -1
				funcCounts.getfflag = -1
			end

			for index, func in next, gc do
				if type(func) == "function" then
					local info = getInfo(func)

					if info.source ~= c then
						continue
					end

					local name = info.name

					if not name then
						continue
					end

					local check = checkedFunctions[name]

					if not check then
						continue
					end

					if not funcCounts[name] then
						funcCounts[name] = 0
					end

					funcCounts[name] += 1
				end
			end

			for name, count in next, funcCounts do
				if count > 1 then
					flag("func c fail " .. name)
				end
			end

			for name, data in next, checkedFunctions do
				if not funcCounts[name] or funcCounts[name] == 0 then
					flag("func tc fail " .. name)
				end
			end

			local crash = setMetatable({ ClassName = "Folder" }, {
				__iter = function()
					flag("getgc trap")
				end,
				__index = function()
					flag("getgc trap")
				end,
				__newindex = function()
					flag("getgc trap")
				end,
				__tostring = function()
					return "Instance"
				end,
			})

			while true do
				if not crash then
					flag("getgc trap tamper")
					break
				end
				for index, data in next, checkedFunctions do
					if not checkFunction(data[1]) then
						flag("func fail " .. index)
					end
				end
				taskWait(1)
			end
		end),
	},--]]
	--[[antiBehavior = {
		thread = false,
		detection = function(flag)
			if true then
				return
			end

			local c = "=[C]"

			local function expectError(name, contains, fn, ...)
				if type(fn) ~= "function" then
					flag("behavior missing " .. name)
					return
				end
				local args = tablePack(...)
				local ok, err = pcallClone(function()
					return fn(tableUnpack(args, 1, args.n))
				end)
				if ok then
					flag("behavior noerr " .. name)
					return
				end
				if contains and not find(tostring(err), contains, 1, true) then
					flag("behavior err " .. name)
				end
			end

			local function checkClosure(name, fn)
				if type(fn) ~= "function" then
					flag("behavior missing " .. name)
					return
				end
				if not isCClosure(fn) then
					flag("behavior cc " .. name)
				end
				if getInfo(fn).source ~= c then
					flag("behavior src " .. name)
				end
				if isFunctionHooked(fn) then
					flag("behavior hook " .. name)
				end
			end

			checkClosure("require", require)
			checkClosure("getrawmetatable", getrawmetatable)
			checkClosure("setrawmetatable", setrawmetatable)
			checkClosure("hookmetamethod", hookmetamethod)

			expectError("require_nil", "Attempted to call require with invalid argument", require, nil)
			expectError("require_table", "Attempted to call require with invalid argument", require, {})
			expectError("require_path", "require path must start with a valid prefix", require, "abc")
			expectError("require_client", "cannot be called from a client", require, 123)

			expectError("grm_noargs", "missing argument", getrawmetatable)
			if type(getrawmetatable(game)) ~= "table" then
				flag("behavior grm game")
			end
			if getrawmetatable(game) ~= getrawmetatable(game) then
				flag("behavior grm identity")
			end

			expectError("srm_noargs", "missing argument", setrawmetatable)

			expectError("hmm_noargs", "missing argument", hookmetamethod)
			expectError("hmm_nometa", nil, hookmetamethod, nil, "__index", function() end)
			expectError("hmm_badmethod", "metamethod not found", hookmetamethod, game, "__nonexistent", function() end)
		end,
	},--]]
	antiRemote = {
		thread = false,
		detection = function(flag)
			local c = "=[C]"
			local RunService = cloneRef(game:GetService("RunService"))
			local remote = Instance.new("RemoteEvent")

			RunService.Heartbeat:Wait()

			local fireServer = remote.FireServer
			if type(fireServer) ~= "function" then
				flag("remote missing fireserver")
				remote:Destroy()
				return
			end

			if not isCClosure(fireServer) then
				flag("remote cc")
			end
			if getInfo(fireServer).source ~= c then
				flag("remote src")
			end
			if isFunctionHooked(fireServer) then
				flag("remote hook")
			end
			if remote.FireServer ~= remote.FireServer then
				flag("remote identity")
			end

			local ok, err = pcallClone(function()
				return fireServer()
			end)
			if ok then
				flag("remote noerr")
			elseif not find(tostring(err), "calling member function FireServer", 1, true) then
				flag("remote err")
			end

			remote:Destroy()
		end,
	},
	antiNamecall = {
		thread = true,
		detection = function(_flag)
			local c = "=[C]"
			local methods = { "__namecall", "__index", "__newindex" }

			local function kick()
				local localPlayer = PlayersService.LocalPlayer
				if localPlayer then
					localPlayer:Kick(
						LPH_ENCSTR(
							"[limerence.biz]\nHooking the game's metamethods is not allowed and can get you banned."
						)
					)
				end
			end

			while true do
				local mt = getRawMetatable(game)
				if not mt then
					return kick()
				end

				for _, name in next, methods do
					local fn = rawget(mt, name)
					if type(fn) ~= "function" then
						return kick()
					elseif not isCClosure(fn) then
						return kick()
					elseif getInfo(fn).source ~= c then
						return kick()
					elseif isFunctionHooked(fn) then
						return kick()
					elseif rawget(mt, name) ~= fn then
						return kick()
					end
				end

				taskWait(1)
			end
		end,
	},
	antiDex = {
		thread = true,
		detection = function(flag)
			if false then
				local setScriptable = cloneFunction(setscriptable)

				local random = Random.new()
				local nextInteger = random.NextInteger

				local possibleParents = {
					game.GetService(game, "CookiesService"),
					game.GetService(game, "ThirdPartyUserService"),
					game.GetService(game, "Visit"),
				}

				for i = 1, 9 do
					local newInstance = createInstance(
						"Motor6D",
						{
							Name = "?",
						},
						i == 9 and cloneRef(gethui())
							or cloneRef(possibleParents[nextInteger(random, 1, #possibleParents)])
					)

					setScriptable(newInstance, "Name", false)
					setScriptable(newInstance, "Parent", false)
					setScriptable(newInstance, "ClassName", false)
				end

				for index, parent in next, possibleParents do
					setScriptable(parent, "Name", false)
					setScriptable(parent, "Parent", false)
					setScriptable(parent, "ClassName", false)
				end
			end

			local isExecutorClosure = cloneFunction(isexecutorclosure)
			local getConnections = cloneFunction(getconnections)
			local descendantAdded = game.DescendantAdded

			while true do
				local connections = getConnections(descendantAdded)

				for index, connection in next, connections do
					local func = connection.Function
					if func and isExecutorClosure(func) then
						--flag("likely dex")
						break
					end
				end

				taskWait(1)
			end
		end,
	},
	antiEnvLog = {
		thread = false,
		detection = function(flag)
			local passedCheck = false
			local jobId = game.JobId

			local service = cloneRef(game:GetService("ChangeHistoryService")) :: ChangeHistoryService
			service:SetEnabled(true)

			service.OnRecordingStarted:Connect(function(name: string, displayName: string?)
				if name == jobId and displayName == jobId:reverse() then
					passedCheck = true
				else
					flag("env log fail lol")
				end
			end)

			taskWait()

			service:TryBeginRecording(jobId, jobId:reverse())

			repeat
				taskWait()
			until passedCheck == true

			service:SetEnabled(false)
		end,
	},
}

return ProtectionFlags
