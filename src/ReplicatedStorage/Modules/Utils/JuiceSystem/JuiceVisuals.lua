--[[
	JuiceVisuals.lua
	Módulo para gestión de visuales y GUI de jugos
	Maneja colores, texturas, billboards e InfoGUI
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JuiceVisuals = {}

--------------------------------------------------------------
-- REFERENCIAS
--------------------------------------------------------------
local IngredientConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"):WaitForChild("IngredientConfig"))
local GradientEffects = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"):WaitForChild("GradientEffects"))

local juiceVFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("Juice")
local infoGuiTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("GUI"):WaitForChild("Billboards"):WaitForChild("InfoGui")

--------------------------------------------------------------
-- GESTIÓN DE COLORES
--------------------------------------------------------------

-- Mezcla múltiples colores en uno solo
function JuiceVisuals.mixColors(colors)
	if #colors == 0 then
		return Color3.fromRGB(255, 255, 255)
	end

	local r, g, b = 0, 0, 0
	for _, color in ipairs(colors) do
		r = r + color.R
		g = g + color.G
		b = b + color.B
	end

	return Color3.new(r / #colors, g / #colors, b / #colors)
end

-- Obtiene los colores de una lista de ingredientes
function JuiceVisuals.getIngredientsColors(ingredientsFolder)
	local colors = {}

	if ingredientsFolder then
		for _, ingredientFolder in ipairs(ingredientsFolder:GetChildren()) do
			if ingredientFolder:IsA("Folder") then
				local ingredientData = IngredientConfig.Ingredients[ingredientFolder.Name]
				if ingredientData and ingredientData.Color then
					table.insert(colors, ingredientData.Color)
				end
			end
		end
	end

	return colors
end

-- Obtiene el color mezclado de ingredientes
function JuiceVisuals.getMixedColorFromIngredients(ingredientsFolder)
	local colors = JuiceVisuals.getIngredientsColors(ingredientsFolder)
	return JuiceVisuals.mixColors(colors)
end

--------------------------------------------------------------
-- TEXTURAS DE JUGOS
--------------------------------------------------------------

-- Aplica texturas de jugo a una tool con un color específico
function JuiceVisuals.applyJuiceTextures(tool, color)
	local model = tool:FindFirstChild("Model")
	if not model then return end

	local contentPart = model:FindFirstChild("Content")
	if not contentPart then return end

	-- Limpiar texturas existentes
	for _, child in ipairs(contentPart:GetChildren()) do
		if child:IsA("Texture") or child:IsA("Decal") then
			child:Destroy()
		end
	end

	-- Buscar el folder Content en VFX
	local vfxContent = juiceVFX:FindFirstChild("Content")
	if not vfxContent then return end

	-- Clonar el folder
	local contentClone = vfxContent:Clone()

	-- Cambiar el color de todas las texturas y moverlas a la parte
	for _, texture in ipairs(contentClone:GetChildren()) do
		if texture:IsA("Texture") or texture:IsA("Decal") then
			texture.Color3 = color
			texture.Parent = contentPart
		end
	end

	contentClone:Destroy()
end

--------------------------------------------------------------
-- INFO GUI DEL JUGO
--------------------------------------------------------------

-- Configura el InfoGui de un jugo
function JuiceVisuals.setupJuiceInfoGui(tool, juiceName, price, pricePerSec, quality, moneyGeneratedValue, formatNumberFunc)
	local display = tool:FindFirstChild("Display")
	if not display then
		warn("[JuiceVisuals] No se encontró Display en la tool")
		return
	end

	local infoGui = display:FindFirstChild("InfoGui")
	if not infoGui then
		warn("[JuiceVisuals] No se encontró InfoGui en Display")
		return
	end

	-- Actualizar Name
	local nameLabel = infoGui:FindFirstChild("Name")
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = juiceName
	end

	-- Actualizar Rarity con gradiente
	local rarityLabel = infoGui:FindFirstChild("Rarity")
	if rarityLabel and rarityLabel:IsA("TextLabel") then
		rarityLabel.Text = quality
		GradientEffects.applyQualityGradient(rarityLabel, quality)
	end

	-- Actualizar Price
	local priceLabel = infoGui:FindFirstChild("Price")
	if priceLabel and priceLabel:IsA("TextLabel") then
		priceLabel.Text = formatNumberFunc(price)
	end

	-- Actualizar PricePerSec con MoneyGenerated
	local pricePerSecLabel = infoGui:FindFirstChild("PricePerSec")
	if pricePerSecLabel and pricePerSecLabel:IsA("TextLabel") then
		-- Conectar a cambios en MoneyGenerated para actualizar en tiempo real
		local function updatePricePerSecLabel()
			local moneyGenerated = moneyGeneratedValue and moneyGeneratedValue.Value or 0
			pricePerSecLabel.Text = formatNumberFunc(pricePerSec) .. "/s (" .. formatNumberFunc(moneyGenerated) .. ")"
		end

		-- Actualizar inicialmente
		updatePricePerSecLabel()

		-- Escuchar cambios en MoneyGenerated
		if moneyGeneratedValue then
			moneyGeneratedValue:GetPropertyChangedSignal("Value"):Connect(updatePricePerSecLabel)
		end
	end
end

--------------------------------------------------------------
-- BILLBOARD DE INGREDIENTES
--------------------------------------------------------------

-- Crea un billboard GUI con los ingredientes del jugo
function JuiceVisuals.createIngredientsBillboard(slotModel, ingredientsFolder)
	-- Buscar la parte Base dentro del slot model
	local slotBasePart = slotModel:FindFirstChild("Base")
	if not slotBasePart or not slotBasePart:IsA("BasePart") then
		warn("[JuiceVisuals] Base part no encontrada en slot para billboard")
		return
	end

	-- Clonar el template del InfoGui
	local billboardGui = infoGuiTemplate:Clone()
	billboardGui.Name = "IngredientsInfo"
	billboardGui.Parent = slotBasePart

	-- Buscar Content y Template
	local content = billboardGui:FindFirstChild("Content")
	if not content then
		warn("[JuiceVisuals] Content no encontrado en InfoGui")
		return
	end

	local template = content:FindFirstChild("Template")
	if not template then
		warn("[JuiceVisuals] Template no encontrado en Content")
		return
	end

	-- Ocultar el template original
	template.Visible = false

	-- Crear un template por cada ingrediente
	if ingredientsFolder then
		for _, ingredientFolder in ipairs(ingredientsFolder:GetChildren()) do
			if ingredientFolder:IsA("Folder") then
				local ingredientData = IngredientConfig.Ingredients[ingredientFolder.Name]
				if ingredientData then
					-- Clonar el template
					local ingredientFrame = template:Clone()
					ingredientFrame.Name = ingredientFolder.Name
					ingredientFrame.Visible = true

					-- Buscar Icon y Name
					local icon = ingredientFrame:FindFirstChild("Icon")
					local nameLabel = ingredientFrame:FindFirstChild("Name")

					if icon and icon:IsA("ImageLabel") then
						icon.Image = ingredientData.Image or ""
					end

					if nameLabel and nameLabel:IsA("TextLabel") then
						nameLabel.Text = ingredientData.Name or ingredientFolder.Name
					end

					ingredientFrame.Parent = content
				end
			end
		end
	end

	return billboardGui
end

--------------------------------------------------------------
-- MUTACIONES DE INGREDIENTES
--------------------------------------------------------------

-- Obtiene las mutaciones únicas de los ingredientes
function JuiceVisuals.getUniqueMutations(ingredientsFolder)
	local uniqueMutations = {}

	if ingredientsFolder then
		local mutationSet = {}
		for _, ingredientFolder in ipairs(ingredientsFolder:GetChildren()) do
			if ingredientFolder:IsA("Folder") then
				for _, child in ipairs(ingredientFolder:GetChildren()) do
					if child:IsA("StringValue") and not mutationSet[child.Name] then
						mutationSet[child.Name] = true
						table.insert(uniqueMutations, child.Name)
					end
				end
			end
		end
	end

	return uniqueMutations
end

-- Aplica mutaciones a la carpeta Mutation de una tool
function JuiceVisuals.applyMutationsToTool(tool, ingredientsFolder)
	local uniqueMutations = JuiceVisuals.getUniqueMutations(ingredientsFolder)

	-- Buscar o crear carpeta Mutation
	local mutationFolder = tool:FindFirstChild("Mutation")
	if not mutationFolder then
		mutationFolder = Instance.new("Folder")
		mutationFolder.Name = "Mutation"
		mutationFolder.Parent = tool
	end

	-- Limpiar mutaciones existentes
	for _, child in ipairs(mutationFolder:GetChildren()) do
		if child:IsA("StringValue") then
			child:Destroy()
		end
	end

	-- Agregar mutaciones únicas
	for _, mutationName in ipairs(uniqueMutations) do
		local mutationValue = Instance.new("StringValue")
		mutationValue.Name = mutationName
		mutationValue.Value = mutationName
		mutationValue.Parent = mutationFolder
	end
end

--------------------------------------------------------------
-- LIMPIEZA DE VISUALS
--------------------------------------------------------------

-- Limpia tools y billboards de un slot
function JuiceVisuals.cleanupSlotVisuals(placeSlotModel)
	if not placeSlotModel then return end

	-- Limpiar tools
	for _, child in ipairs(placeSlotModel:GetChildren()) do
		if child:IsA("Tool") then
			child:Destroy()
		end
	end

	-- Limpiar billboards de ingredientes de la parte Base
	local basePart = placeSlotModel:FindFirstChild("Base")
	if basePart and basePart:IsA("BasePart") then
		for _, child in ipairs(basePart:GetChildren()) do
			if child:IsA("BillboardGui") and child.Name == "IngredientsInfo" then
				child:Destroy()
			end
		end
	end
end

return JuiceVisuals
