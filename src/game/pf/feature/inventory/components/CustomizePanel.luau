local React = require("@pkg/React")
local ReactCharm = require("@pkg/ReactCharm")

local FileController = require("@feature/file/FileController")
local themeState = require("@ui/theme/themeState")
local Colorpicker = require("@ui/window/element/colorpicker/Colorpicker")
local Dropdown = require("@ui/window/element/dropdown/Dropdown")
local Slider = require("@ui/window/element/slider/Slider")

local pfSkinState = require("@game/pf/feature/inventory/pfSkinState")
local skinCatalog = require("@game/pf/feature/inventory/skinCatalog")
local SkinChanger = require("@game/pf/feature/inventory/SkinChanger")

local useMemo = React.useMemo
local useEffect = React.useEffect
local useRef = React.useRef
local useAt = ReactCharm.useAtom
local e = React.createElement

local elementColors = themeState.colors.window.element

local RENDER_OPTS = { textOffsetY = -1 }
local DEFAULT_MATERIAL = "Default"
local WHITE = Color3.fromRGB(255, 255, 255)

local MATERIAL_OPTIONS: { string } = (function()
	local out: { string } = { DEFAULT_MATERIAL }
	for _, material in next, Enum.Material:GetEnumItems() do
		if material.Name ~= "Air" and material.Name ~= "Water" then
			out[#out + 1] = material.Name
		end
	end
	return out
end)()

type Control = {
	name: string,
	group: "brick" | "texture",
	order: number,
	element: any,
	kind: "color" | "material" | "number",
}

export type CustomizePanelProps = {
	Weapon: string?,
	SlotTag: string?,
	Skin: string?,
	SlotData: pfSkinState.SlotData?,
}

return function(props: CustomizePanelProps): React.Element<any>
	local suppress = useRef(false)
	local weaponRef = useRef(nil :: string?)
	local slotRef = useRef(nil :: string?)
	weaponRef.current = props.Weapon
	slotRef.current = props.SlotTag

	local captionColor = useAt(elementColors.caption)
	local iconColor = useAt(elementColors.icon)

	local elements = useMemo(function()
		return {
			brickColor = Colorpicker("Brick Color", WHITE),
			material = Dropdown("Material", MATERIAL_OPTIONS, DEFAULT_MATERIAL):SetMode("single"):SetMin(1),
			reflectance = Slider("Reflectance", 0, 0, 1, 0.01),
			texColor = Colorpicker("Texture Color", WHITE),
			transparency = Slider("Transparency", 0, 0, 1, 0.01),
			emissivity = Slider("Emissivity", 1, 0, 100, 1),
			tileU = Slider("Tile U", 1, 0.1, 10, 0.1),
			tileV = Slider("Tile V", 1, 0.1, 10, 0.1),
			offsetU = Slider("Offset U", 0, 0, 30, 0.1),
			offsetV = Slider("Offset V", 0, 0, 30, 0.1),
		}
	end, {})

	local controls = useMemo(function(): { Control }
		return {
			{ name = "Color", group = "brick", order = 2, element = elements.brickColor, kind = "color" },
			{ name = "Material", group = "brick", order = 3, element = elements.material, kind = "material" },
			{ name = "Reflectance", group = "brick", order = 4, element = elements.reflectance, kind = "number" },
			{ name = "Color", group = "texture", order = 6, element = elements.texColor, kind = "color" },
			{ name = "Transparency", group = "texture", order = 7, element = elements.transparency, kind = "number" },
			{ name = "Emissivity", group = "texture", order = 8, element = elements.emissivity, kind = "number" },
			{ name = "StudsPerTileU", group = "texture", order = 9, element = elements.tileU, kind = "number" },
			{ name = "StudsPerTileV", group = "texture", order = 10, element = elements.tileV, kind = "number" },
			{ name = "OffsetStudsU", group = "texture", order = 11, element = elements.offsetU, kind = "number" },
			{ name = "OffsetStudsV", group = "texture", order = 12, element = elements.offsetV, kind = "number" },
		}
	end, { elements } :: { any })

	useEffect(function()
		local conns: { () -> () } = {}
		local function write(group: "brick" | "texture", name: string, value: any): ()
			if suppress.current then
				return
			end
			local weapon = weaponRef.current
			local slot = slotRef.current
			if weapon and slot then
				SkinChanger.SetProperty(weapon, slot, group, name, value)
			end
		end

		for _, control in next, controls do
			local group = control.group
			local name = control.name
			if control.kind == "color" then
				conns[#conns + 1] = control.element:OnColorChange(function(color: any): ()
					if typeof(color) == "Color3" then
						write(group, name, color)
					end
				end)
			elseif control.kind == "material" then
				conns[#conns + 1] = control.element:OnChange(function(value: any): ()
					local material = (type(value) == "string" and value ~= DEFAULT_MATERIAL and value ~= "") and value
						or nil
					write(group, name, material)
				end)
			else
				conns[#conns + 1] = control.element:OnChange(function(value: any): ()
					write(group, name, value)
				end)
			end
		end

		return function(): ()
			for _, disconnect in next, conns do
				disconnect()
			end
		end
	end, { controls } :: { any })

	useEffect(function()
		suppress.current = true
		local slot = props.SlotData or ({} :: pfSkinState.SlotData)
		local brick = slot.brick or {}
		local texture = slot.texture or {}

		elements.brickColor:SetState(brick.Color or WHITE)
		elements.material:SetSelected(brick.Material or DEFAULT_MATERIAL)
		elements.reflectance:SetValue(brick.Reflectance or 0)
		elements.texColor:SetState(texture.Color or WHITE)
		elements.transparency:SetValue(texture.Transparency or 0)
		elements.emissivity:SetValue(texture.Emissivity or 1)
		elements.tileU:SetValue(texture.StudsPerTileU or 1)
		elements.tileV:SetValue(texture.StudsPerTileV or 1)
		elements.offsetU:SetValue(texture.OffsetStudsU or 0)
		elements.offsetV:SetValue(texture.OffsetStudsV or 0)

		suppress.current = false
	end, { props.Weapon, props.SlotTag, props.Skin, props.SlotData, elements } :: { any })

	local excluded = useMemo(function(): { [string]: boolean }
		local set: { [string]: boolean } = {}
		if props.Skin then
			local list = skinCatalog.excludedProperties(props.Skin)
			if list then
				for _, name in next, list do
					set[name] = true
				end
			end
		end
		return set
	end, { props.Skin } :: { any })

	local function sectionLabel(text: string, order: number): React.Element<any>
		return e("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = FileController.Get("font", "semi_bold"),
			Text = text,
			TextColor3 = captionColor,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = order,
		})
	end

	local children: { [string]: React.Element<any> } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 10),
		}),
		BrickHeader = sectionLabel("BRICK", 1),
		TextureHeader = sectionLabel("TEXTURE", 5),
	}

	for _, control in next, controls do
		if not excluded[control.name] then
			children[`Control_{control.group}_{control.name}`] = control.element:Render(control.order, RENDER_OPTS)
		end
	end

	return e("ScrollingFrame", {
		Active = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = iconColor,
		ScrollBarImageTransparency = 0.4,
		ClipsDescendants = true,
	}, children)
end
