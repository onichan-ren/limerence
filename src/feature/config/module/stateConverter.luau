return LPH_JIT_MAX(function()
	local Charm = require("@pkg/Charm")
	local configState = require("@src/feature/config/configState")
	local elementBindController = require("@ui/bind/elementBindController")
	local HttpService = cloneref(game:GetService("HttpService")) :: HttpService

	local peek = Charm.peek

	local stateConverter = {}

	local extensions: {
		[string]: {
			save: () -> any,
			load: (any) -> (),
			prepare: ((any) -> ())?,
		},
	} = {}

	local pendingExtData: { [string]: any } = {}

	function stateConverter.RegisterExtension(
		name: string,
		save: () -> any,
		load: (any) -> (),
		prepare: ((any) -> ())?
	): ()
		extensions[name] = { save = save, load = load, prepare = prepare }
		local payload = pendingExtData[name]
		if payload == nil then
			return
		end
		setthreadidentity(8)
		if prepare then
			pcall(prepare, payload)
		end
		pcall(load, payload)
		setthreadidentity(8)
	end

	function stateConverter.UnregisterExtension(name: string): ()
		extensions[name] = nil
	end

	local serializeValue = LPH_NO_VIRTUALIZE(function(value: any): any
		local valueType = typeof(value)

		if valueType == "Color3" then
			return { __t = "Color3", r = value.R, g = value.G, b = value.B }
		end

		if valueType == "UDim2" then
			return {
				__t = "UDim2",
				xs = value.X.Scale,
				xo = value.X.Offset,
				ys = value.Y.Scale,
				yo = value.Y.Offset,
			}
		end

		if valueType == "ColorSequence" then
			local keypoints = {}
			for index, keypoint in next, value.Keypoints do
				keypoints[index] = {
					time = keypoint.Time,
					r = keypoint.Value.R,
					g = keypoint.Value.G,
					b = keypoint.Value.B,
				}
			end
			return { __t = "ColorSequence", keypoints = keypoints }
		end

		return value
	end)

	local deserializeValue = LPH_NO_VIRTUALIZE(function(value: any): any
		if type(value) ~= "table" then
			return value
		end

		local tag = value.__t
		if tag == "Color3" then
			return Color3.new(value.r, value.g, value.b)
		end

		if tag == "UDim2" then
			return UDim2.new(value.xs, value.xo, value.ys, value.yo)
		end

		if tag == "ColorSequence" then
			local keypoints = {}
			for index, keypoint in next, value.keypoints do
				keypoints[index] =
					ColorSequenceKeypoint.new(keypoint.time, Color3.new(keypoint.r, keypoint.g, keypoint.b))
			end
			return ColorSequence.new(keypoints)
		end

		return value
	end)

	local function coerceValue(element: any, value: any): any
		if element._isSequence and typeof(value) == "Color3" then
			return ColorSequence.new(value)
		end
		return value
	end

	stateConverter.serializeValue = serializeValue
	stateConverter.deserializeValue = deserializeValue

	function stateConverter.toJson(): string
		local values: { [string]: any } = {}
		local transparency: { [string]: number } = {}
		local rotations: { [string]: number } = {}
		local animations: { [string]: string } = {}
		local speeds: { [string]: number } = {}
		local binds: { [string]: { any } } = {}

		for key, element in next, configState.elements do
			local elementBinds = element._binds and peek(element._binds)

			local state = peek(element._state)
			if state ~= nil then
				if elementBinds then
					for _, eb in next, elementBinds do
						if peek(eb.active) and peek(eb.mode) ~= "toggle" then
							local sv = peek(eb.savedValue)
							state = sv ~= nil and sv or false
							break
						end
					end
				end
				values[key] = serializeValue(state)
			end

			if element._transparency then
				local alpha = peek(element._transparency)
				if alpha ~= nil then
					transparency[key] = alpha
				end
			end

			if element._rotation then
				local rot = peek(element._rotation)
				if rot ~= nil then
					rotations[key] = rot
				end
			end

			if element._animation then
				local anim = peek(element._animation)
				if anim ~= nil then
					animations[key] = anim
				end
			end

			if element._speed then
				local spd = peek(element._speed)
				if spd ~= nil then
					speeds[key] = spd
				end
			end

			if elementBinds then
				if #elementBinds > 0 then
					local serialized = {}
					for _, eb in next, elementBinds do
						local serializedInputs = {}
						for _, input in next, peek(eb.inputs) do
							table.insert(serializedInputs, elementBindController.SerializeInput(input))
						end
						local tv = peek(eb.targetValue)
						local sv = peek(eb.savedValue)
						table.insert(serialized, {
							mode = peek(eb.mode),
							inputs = serializedInputs,
							showInList = peek(eb.showInList),
							targetValue = tv ~= nil and serializeValue(tv) or nil,
							active = peek(eb.active),
							savedValue = sv ~= nil and serializeValue(sv) or nil,
						})
					end
					binds[key] = serialized
				end
			end
		end

		local extData: { [string]: any } = {}
		for name, ext in next, extensions do
			local ok, data = pcall(ext.save)
			if ok and data ~= nil then
				extData[name] = data
			end
		end

		return HttpService:JSONEncode({
			values = values,
			transparency = transparency,
			rotations = rotations,
			animations = animations,
			speeds = speeds,
			binds = binds,
			extensions = extData,
		})
	end

	function stateConverter.applyRemapped(json: string, remap: (key: string) -> string?): number
		local decoded = HttpService:JSONDecode(json)
		local applied = 0

		local values = decoded.values
		if type(values) == "table" then
			for key, value in next, values do
				local localKey = remap(key)
				local element = localKey and configState.elements[localKey]
				if not element then
					continue
				end
				setthreadidentity(8)
				element._state(coerceValue(element, deserializeValue(value)))
				applied += 1
			end
		end

		local atomFields = {
			transparency = "_transparency",
			rotations = "_rotation",
			animations = "_animation",
			speeds = "_speed",
		}
		for field, atomKey in next, atomFields do
			local map = decoded[field]
			if type(map) ~= "table" then
				continue
			end
			for key, value in next, map do
				local localKey = remap(key)
				local element = localKey and configState.elements[localKey]
				if not element or not element[atomKey] then
					continue
				end
				element[atomKey](value)
			end
		end

		return applied
	end

	function stateConverter.fromJson(json: string): ()
		local decoded = HttpService:JSONDecode(json)
		local values = decoded.values or {}
		local transparency = decoded.transparency or {}
		local rotations = decoded.rotations or {}
		local animations = decoded.animations or {}
		local speeds = decoded.speeds or {}
		local binds = decoded.binds or {}

		local legitbotTargettingMigrate = {
			["aim.hitboxes"] = "targetting.hitboxes",
			["aim.conditions"] = "targetting.conditions",
			["aim.conditions.opts.blindThreshold"] = "targetting.conditions.opts.blindThreshold",
			["aim.conditions.opts.smokeThreshold"] = "targetting.conditions.opts.smokeThreshold",
			["aim.reactionTime"] = "targetting.reactionTime",
			["aim.targetSwitchDelay"] = "targetting.targetSwitchDelay",
		}
		for oldKey, newKey in next, legitbotTargettingMigrate do
			if values[newKey] == nil and values[oldKey] ~= nil then
				local el = configState.elements[newKey]
				if el then
					values[newKey] = values[oldKey]
				end
			end
		end

		local extData = decoded.extensions
		pendingExtData = type(extData) == "table" and extData or {}
		if type(extData) == "table" then
			for name, ext in next, extensions do
				local prepare = ext.prepare
				if prepare then
					local payload = extData[name]
					if payload ~= nil then
						setthreadidentity(8)
						pcall(prepare, payload)
					end
				end
			end
		end

		for key, value in next, values do
			local element = configState.elements[key]
			if not element then
				continue
			end
			setthreadidentity(8)
			element._state(coerceValue(element, deserializeValue(value)))
		end

		for key, value in next, transparency do
			local element = configState.elements[key]
			if not element or not element._transparency then
				continue
			end
			element._transparency(value)
		end

		for key, value in next, rotations do
			local element = configState.elements[key]
			if not element or not element._rotation then
				continue
			end
			element._rotation(value)
		end

		for key, value in next, animations do
			local element = configState.elements[key]
			if not element or not element._animation then
				continue
			end
			element._animation(value)
		end

		for key, value in next, speeds do
			local element = configState.elements[key]
			if not element or not element._speed then
				continue
			end
			element._speed(value)
		end

		for _, element in next, configState.elements do
			if not element._binds then
				continue
			end
			for _, eb in next, peek(element._binds) do
				element:RemoveBind(eb.id)
			end
		end

		for key, bindList in next, binds do
			local element = configState.elements[key]
			if not element or not element._binds then
				continue
			end

			local pendingActive: { { eb: any, savedValue: any } } = {}

			for _, bindData in next, bindList do
				local eb = element:AddBind()
				if not eb then
					continue
				end

				if bindData.mode then
					eb.mode(bindData.mode)
				end

				if bindData.inputs then
					local inputs = {}
					for _, inputStr in next, bindData.inputs do
						local input = elementBindController.DeserializeInput(inputStr)
						if input then
							table.insert(inputs, input)
						end
					end
					eb.inputs(inputs)
				end

				if bindData.showInList ~= nil then
					eb.showInList(bindData.showInList)
				end

				if bindData.targetValue ~= nil then
					eb.targetValue(deserializeValue(bindData.targetValue))
				end

				if bindData.savedValue ~= nil then
					eb.savedValue(deserializeValue(bindData.savedValue))
				end

				if bindData.active == true and bindData.mode == "toggle" then
					table.insert(pendingActive, { eb = eb, savedValue = bindData.savedValue })
				end
			end

			elementBindController.RewireAll(element)

			for _, entry in next, pendingActive do
				elementBindController.RestoreActive(entry.eb)
			end
		end

		if type(extData) == "table" then
			for name, ext in next, extensions do
				local payload = extData[name]
				if payload ~= nil then
					setthreadidentity(8)
					pcall(ext.load, payload)
				end
			end
		end
	end
	return stateConverter
end)()
