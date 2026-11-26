local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

local MATERIALS = { "Neon", "ForceField", "SmoothPlastic", "Glass", "Plastic", "Metal" }
local MATERIAL_ENUM: { [string]: Enum.Material } = {
	Neon = Enum.Material.Neon,
	ForceField = Enum.Material.ForceField,
	SmoothPlastic = Enum.Material.SmoothPlastic,
	Glass = Enum.Material.Glass,
	Plastic = Enum.Material.Plastic,
	Metal = Enum.Material.Metal,
}

local folderChams = {}
folderChams.__index = folderChams

folderChams.MATERIALS = MATERIALS

function folderChams.material(name: string): Enum.Material
	return MATERIAL_ENUM[name] or Enum.Material.Neon
end

function folderChams.new(folderName: string, includePart: (BasePart) -> boolean): folderChams
	local self = setmetatable({}, folderChams)
	self._folderName = folderName
	self._includePart = includePart
	self._enabled = false
	self._color = Color3.new(1, 1, 1)
	self._material = Enum.Material.Neon
	self._models = setmetatable({}, { __mode = "k" }) :: any
	self._orig = setmetatable({}, { __mode = "k" }) :: any
	self._conns = {} :: { RBXScriptConnection }
	self._folder = nil :: Instance?
	return self
end

folderChams._colorModel = LPH_NO_VIRTUALIZE(function(self: folderChams, model: Instance): ()
	local includePart = self._includePart
	local orig = self._orig
	local color = self._color
	local material = self._material
	for _, descendant in next, model:QueryDescendants("BasePart") do
		if includePart(descendant) then
			if orig[descendant] == nil then
				orig[descendant] = { color = descendant.Color, material = descendant.Material }
			end
			descendant.Color = color
			descendant.Material = material
		end
	end
end)

function folderChams._addModel(self: folderChams, model: Instance): ()
	if not model:IsA("Model") then
		return
	end
	self._models[model] = true
	self:_colorModel(model)
end

function folderChams._bindFolder(self: folderChams, folder: Instance): ()
	self._folder = folder
	for _, child in next, folder:GetChildren() do
		self:_addModel(child)
	end
	self._conns[#self._conns + 1] = folder.ChildAdded:Connect(function(child: Instance): ()
		self:_addModel(child)
	end)
	self._conns[#self._conns + 1] = folder.ChildRemoved:Connect(function(child: Instance): ()
		self._models[child] = nil
	end)
end

function folderChams._bind(self: folderChams): ()
	local ignore = Workspace:FindFirstChild("Ignore")
	local folder = ignore and ignore:FindFirstChild(self._folderName)
	if folder then
		self:_bindFolder(folder)
		return
	end
	local conn
	conn = Workspace.DescendantAdded:Connect(function(descendant: Instance): ()
		local parent = descendant.Parent
		if descendant.Name == self._folderName and parent and parent.Name == "Ignore" then
			conn:Disconnect()
			self:_bindFolder(descendant)
		end
	end)
	self._conns[#self._conns + 1] = conn
end

function folderChams.setStyle(self: folderChams, color: Color3, material: Enum.Material): ()
	self._color = color
	self._material = material
	if not self._enabled then
		return
	end
	for model in next, self._models do
		if model.Parent then
			self:_colorModel(model)
		end
	end
end

function folderChams.enable(self: folderChams, color: Color3, material: Enum.Material): ()
	if self._enabled then
		return
	end
	self._enabled = true
	self._color = color
	self._material = material
	self:_bind()
end

function folderChams.disable(self: folderChams): ()
	if not self._enabled then
		return
	end
	self._enabled = false
	for _, conn in next, self._conns do
		conn:Disconnect()
	end
	self._conns = {}
	self._folder = nil
	for part, info in next, self._orig do
		if part.Parent then
			part.Color = info.color
			part.Material = info.material
		end
	end
	self._orig = setmetatable({}, { __mode = "k" }) :: any
	self._models = setmetatable({}, { __mode = "k" }) :: any
end

export type folderChams = typeof(setmetatable(
	{} :: {
		_folderName: string,
		_includePart: (BasePart) -> boolean,
		_enabled: boolean,
		_color: Color3,
		_material: Enum.Material,
		_models: any,
		_orig: any,
		_conns: { RBXScriptConnection },
		_folder: Instance?,
		_colorModel: (folderChams, Instance) -> (),
		_addModel: (folderChams, Instance) -> (),
		_bindFolder: (folderChams, Instance) -> (),
		_bind: (folderChams) -> (),
		setStyle: (folderChams, Color3, Enum.Material) -> (),
		enable: (folderChams, Color3, Enum.Material) -> (),
		disable: (folderChams) -> (),
	},
	folderChams
))

return folderChams
