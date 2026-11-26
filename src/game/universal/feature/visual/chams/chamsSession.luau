local InsertService = cloneref(game:GetService("InsertService")) :: InsertService

export type Style = {
	material: Enum.Material,
	color: Color3,
	transparency: number,
	reflectance: number,
}

export type Options = {
	overlayMeshParts: boolean?,
	lockTransparency: boolean?,
	lockAppearance: boolean?,
	skipTransparency: boolean?,
	skipInvisible: boolean?,
}

type MeshEntry = {
	textureId: string,
	vertexColor: Vector3?,
}

type Entry = {
	material: Enum.Material,
	color: Color3,
	transparency: number,
	reflectance: number,
	texId: string?,
	usePartColor: boolean?,
	detached: { { inst: Instance, parent: Instance } },
	meshes: { [Instance]: MeshEntry },
	usesOverlay: boolean,
	overlay: BasePart?,
	conns: { RBXScriptConnection },
	style: Style,
}

export type Session = {
	apply: (part: BasePart, style: Style) -> (),
	restore: (part: BasePart) -> (),
	restoreAll: () -> (),
	has: (part: BasePart) -> boolean,
	isOverlay: (inst: Instance) -> boolean,
	usesOverlay: (part: BasePart) -> boolean,
	setHidden: (hidden: boolean) -> (),
	onDescendantAdded: (desc: Instance) -> (),
	destroy: () -> (),
}

local function isDetachable(inst: Instance): boolean
	local className = inst.ClassName
	return className == "SurfaceAppearance" or className == "Texture" or className == "Decal"
end

local chamsSession = {}

function chamsSession.new(options: Options?): Session
	local overlayMeshParts = options ~= nil and options.overlayMeshParts == true
	local lockAppearance = options ~= nil and options.lockAppearance == true
	local lockTransparency = options ~= nil and options.lockTransparency == true
	local manageTransparency = not (options ~= nil and options.skipTransparency == true)
	local skipInvisible = not (options ~= nil and options.skipInvisible == false)

	local patched: { [BasePart]: Entry } = setmetatable({}, { __mode = "k" }) :: any
	local overlays: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local hidden = false

	local styleTarget = LPH_NO_VIRTUALIZE(function(target: BasePart, style: Style, withTransparency: boolean): ()
		if target.Color ~= style.color then
			target.Color = style.color
		end
		if target.Material ~= style.material then
			target.Material = style.material
		end
		if target.Reflectance ~= style.reflectance then
			target.Reflectance = style.reflectance
		end
		if withTransparency and target.Transparency ~= style.transparency then
			target.Transparency = style.transparency
		end
	end)

	local function buildOverlay(part: BasePart, meshId: string, scale: Vector3?, entry: Entry): ()
		task.spawn(function(): ()
			local ok, overlay = pcall(
				InsertService.CreateMeshPartAsync,
				InsertService,
				meshId,
				Enum.CollisionFidelity.Box,
				Enum.RenderFidelity.Precise
			)
			if not ok or not overlay then
				if patched[part] == entry then
					part.Transparency = entry.transparency
					entry.usesOverlay = false
				end
				return
			end
			if patched[part] ~= entry or not part.Parent then
				overlay:Destroy()
				return
			end

			overlay.Size = scale and overlay.Size * scale or part.Size
			overlay.CanCollide = false
			overlay.CanQuery = false
			overlay.CanTouch = false
			overlay.Massless = true
			overlays[overlay] = true
			styleTarget(overlay, entry.style, not hidden)
			if hidden then
				overlay.Transparency = 1
			end

			local weld = Instance.new("Weld")
			weld.Part0 = part
			weld.Part1 = overlay
			weld.Parent = overlay

			overlay.CFrame = part.CFrame
			overlay.Parent = part

			entry.overlay = overlay
		end)
	end

	local function overlayMeshFor(part: BasePart): (string?, Vector3?)
		if not part:IsA("MeshPart") then
			local file = part:FindFirstChildWhichIsA("FileMesh")
			if file and (file :: FileMesh).MeshId ~= "" then
				return (file :: FileMesh).MeshId, (file :: FileMesh).Scale
			end
			return nil, nil
		end
		if overlayMeshParts and (part :: MeshPart).MeshId ~= "" then
			return (part :: MeshPart).MeshId, nil
		end
		return nil, nil
	end

	local function strip(part: BasePart, entry: Entry): ()
		if part:IsA("MeshPart") then
			entry.texId = (part :: MeshPart).TextureID
			;(part :: MeshPart).TextureID = ""
		elseif part:IsA("PartOperation") then
			entry.usePartColor = (part :: PartOperation).UsePartColor
			;(part :: PartOperation).UsePartColor = true
		end

		for _, child in next, part:GetChildren() do
			if isDetachable(child) then
				entry.detached[#entry.detached + 1] = { inst = child, parent = part }
				child.Parent = nil
			elseif child:IsA("FileMesh") then
				local meshEntry: MeshEntry = { textureId = (child :: FileMesh).TextureId }
				;(child :: FileMesh).TextureId = ""
				if child:IsA("SpecialMesh") then
					meshEntry.vertexColor = (child :: SpecialMesh).VertexColor
					;(child :: SpecialMesh).VertexColor = Vector3.new(1, 1, 1)
				end
				entry.meshes[child] = meshEntry
			end
		end
	end

	local apply = LPH_NO_VIRTUALIZE(function(part: BasePart, style: Style): ()
		if overlays[part] then
			return
		end
		local entry = patched[part]
		if entry then
			local s = entry.style
			if
				s.material ~= style.material
				or s.color ~= style.color
				or s.transparency ~= style.transparency
				or s.reflectance ~= style.reflectance
			then
				s.material = style.material
				s.color = style.color
				s.transparency = style.transparency
				s.reflectance = style.reflectance
			end
			local overlay = entry.overlay
			if overlay then
				styleTarget(overlay, s, not hidden)
			elseif not entry.usesOverlay then
				styleTarget(part, s, manageTransparency and entry.transparency < 1)
			end
			return
		end

		local originalTransparency = part.Transparency
		local meshId, scale = overlayMeshFor(part)
		if meshId and skipInvisible and originalTransparency >= 1 then
			return
		end

		entry = {
			material = part.Material,
			color = part.Color,
			transparency = originalTransparency,
			reflectance = part.Reflectance,
			texId = nil,
			usePartColor = nil,
			detached = {},
			meshes = {},
			usesOverlay = false,
			overlay = nil,
			conns = {},
			style = {
				material = style.material,
				color = style.color,
				transparency = style.transparency,
				reflectance = style.reflectance,
			},
		}
		patched[part] = entry

		strip(part, entry)

		if meshId then
			entry.usesOverlay = true
			part.Transparency = 1
			buildOverlay(part, meshId, scale, entry)
			return
		end

		local writeTransparency = manageTransparency and originalTransparency < 1
		styleTarget(part, entry.style, writeTransparency)

		local conns = entry.conns
		if lockTransparency and originalTransparency < 1 then
			conns[#conns + 1] = part:GetPropertyChangedSignal("Transparency"):Connect(function(): ()
				local current = patched[part]
				if not current or current.usesOverlay then
					return
				end
				local value = part.Transparency
				local target = current.style.transparency
				if value < 1 and math.abs(value - target) > 1e-3 then
					part.Transparency = target
				end
			end)
		end
		if lockAppearance then
			conns[#conns + 1] = part:GetPropertyChangedSignal("Material"):Connect(function(): ()
				local current = patched[part]
				if current and not current.usesOverlay and part.Material ~= current.style.material then
					part.Material = current.style.material
				end
			end)
			conns[#conns + 1] = part:GetPropertyChangedSignal("Color"):Connect(function(): ()
				local current = patched[part]
				if current and not current.usesOverlay and part.Color ~= current.style.color then
					part.Color = current.style.color
				end
			end)
			conns[#conns + 1] = part:GetPropertyChangedSignal("Reflectance"):Connect(function(): ()
				local current = patched[part]
				if current and not current.usesOverlay and part.Reflectance ~= current.style.reflectance then
					part.Reflectance = current.style.reflectance
				end
			end)
		end
	end)

	local function restore(part: BasePart): ()
		local entry = patched[part]
		if not entry then
			return
		end
		patched[part] = nil

		local conns = entry.conns
		for i = 1, #conns do
			conns[i]:Disconnect()
		end
		table.clear(conns)

		local overlay = entry.overlay
		if overlay then
			overlays[overlay] = nil
			overlay:Destroy()
			entry.overlay = nil
		end

		if part.Parent then
			if entry.usesOverlay then
				part.Transparency = entry.transparency
			else
				part.Color = entry.color
				part.Material = entry.material
				part.Reflectance = entry.reflectance
				if manageTransparency then
					part.Transparency = entry.transparency
				end
			end
			if entry.texId ~= nil and part:IsA("MeshPart") then
				(part :: MeshPart).TextureID = entry.texId
			elseif entry.usePartColor ~= nil and part:IsA("PartOperation") then
				(part :: PartOperation).UsePartColor = entry.usePartColor
			end
		end

		for mesh, meshEntry in next, entry.meshes do
			(mesh :: any).TextureId = meshEntry.textureId
			if meshEntry.vertexColor then
				(mesh :: any).VertexColor = meshEntry.vertexColor
			end
		end

		for _, detached in next, entry.detached do
			if detached.inst and detached.parent then
				detached.inst.Parent = detached.parent
			end
		end
	end

	local function restoreAll(): ()
		local list: { BasePart } = {}
		for part in next, patched do
			list[#list + 1] = part
		end
		for i = 1, #list do
			restore(list[i])
		end
	end

	local function has(part: BasePart): boolean
		return patched[part] ~= nil
	end

	local function isOverlay(inst: Instance): boolean
		return overlays[inst] == true
	end

	local function usesOverlay(part: BasePart): boolean
		local entry = patched[part]
		return entry ~= nil and entry.usesOverlay
	end

	local function setHidden(value: boolean): ()
		if hidden == value then
			return
		end
		hidden = value
		for _, entry in next, patched do
			local overlay = entry.overlay
			if overlay then
				overlay.Transparency = value and 1 or entry.style.transparency
			end
		end
	end

	local function onDescendantAdded(desc: Instance): ()
		if overlays[desc] then
			return
		end
		local part = desc.Parent
		if not part or not part:IsA("BasePart") then
			return
		end
		local entry = patched[part]
		if not entry or entry.usesOverlay then
			return
		end

		if isDetachable(desc) then
			entry.detached[#entry.detached + 1] = { inst = desc, parent = part }
			desc.Parent = nil
		elseif desc:IsA("FileMesh") and (desc :: FileMesh).MeshId ~= "" and not part:IsA("MeshPart") then
			local style = entry.style
			restore(part)
			apply(part, style)
		elseif desc:IsA("FileMesh") then
			local meshEntry: MeshEntry = { textureId = (desc :: FileMesh).TextureId }
			;(desc :: FileMesh).TextureId = ""
			if desc:IsA("SpecialMesh") then
				meshEntry.vertexColor = (desc :: SpecialMesh).VertexColor
				;(desc :: SpecialMesh).VertexColor = Vector3.new(1, 1, 1)
			end
			entry.meshes[desc] = meshEntry
		end
	end

	local function destroy(): ()
		restoreAll()
	end

	return {
		apply = apply,
		restore = restore,
		restoreAll = restoreAll,
		has = has,
		isOverlay = isOverlay,
		usesOverlay = usesOverlay,
		setHidden = setHidden,
		onDescendantAdded = onDescendantAdded,
		destroy = destroy,
	}
end

return chamsSession
