--[[
	SlotManager.lua
	Módulo para gestión de slots (compra, configuración, limpieza)
	Maneja tanto slots de compra como slots de colocación
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SlotManager = {}

--------------------------------------------------------------
-- REFERENCIAS
--------------------------------------------------------------
local SlotConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"):WaitForChild("SlotConfig"))
local slotBillboardTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("GUI"):WaitForChild("Billboards"):WaitForChild("Slot")
local juicesToolsFolder = ServerStorage:WaitForChild("Inventario"):WaitForChild("Juices")

-- Referencias a otros módulos del sistema (se inyectan)
local JuiceVisuals = nil
local JuiceSystemUtils = nil

--------------------------------------------------------------
-- INICIALIZACIÓN DE DEPENDENCIAS
--------------------------------------------------------------

function SlotManager.injectDependencies(modules)
	JuiceVisuals = modules.JuiceVisuals
	JuiceSystemUtils = modules.JuiceSystemUtils
end

--------------------------------------------------------------
-- CONSTANTES
--------------------------------------------------------------
local COLOR_SUCCESS = Color3.fromRGB(0, 255, 0)
local COLOR_ERROR = Color3.fromRGB(255, 0, 0)
local INTERACTION_COOLDOWN = 1

--------------------------------------------------------------
-- COMPRA DE SLOTS
--------------------------------------------------------------

-- Maneja la compra de un slot
function SlotManager.handleSlotPurchase(player, slotNumber, warningEvent, formatNumberFunc, cooldownManager)
	-- Verificar cooldown
	if cooldownManager and cooldownManager.isPlayerOnCooldown(player) then
		return
	end

	local dataFolder = player:FindFirstChild("Data")
	if not dataFolder then return end

	local moneyValue = dataFolder:FindFirstChild("Money")
	local slotsValue = dataFolder:FindFirstChild("Slots")

	if not moneyValue or not slotsValue then return end

	-- Verificar que solo se pueda comprar el siguiente slot
	if slotNumber ~= slotsValue.Value + 1 then
		if warningEvent then
			warningEvent:FireClient(player, "You can only buy the next slot!", COLOR_ERROR)
		end
		if cooldownManager then
			cooldownManager.updatePlayerCooldown(player)
		end
		return
	end

	-- Obtener precio del slot
	local slotData = SlotConfig.Slots[tostring(slotNumber)]
	if not slotData or not slotData.Price then
		if warningEvent then
			warningEvent:FireClient(player, "Invalid slot!", COLOR_ERROR)
		end
		if cooldownManager then
			cooldownManager.updatePlayerCooldown(player)
		end
		return
	end

	local price = slotData.Price

	-- Verificar si tiene suficiente dinero
	if moneyValue.Value < price then
		if warningEvent then
			warningEvent:FireClient(player, "Not enough money! Need " .. formatNumberFunc(price), COLOR_ERROR)
		end
		if cooldownManager then
			cooldownManager.updatePlayerCooldown(player)
		end
		return
	end

	-- Realizar compra
	moneyValue.Value = moneyValue.Value - price
	slotsValue.Value = slotsValue.Value + 1

	if warningEvent then
		warningEvent:FireClient(player, "Slot " .. slotNumber .. " purchased for " .. formatNumberFunc(price) .. "!", COLOR_SUCCESS)
	end

	if cooldownManager then
		cooldownManager.updatePlayerCooldown(player)
	end

	print("[SlotManager] Slot", slotNumber, "comprado por", player.Name)
end

--------------------------------------------------------------
-- CONFIGURACIÓN DE BUY SLOTS
--------------------------------------------------------------

-- Configura un buy slot con su billboard y evento de compra
function SlotManager.setupBuySlot(buySlotModel, slotNumber, plotName, slotTracker, warningEvent, formatNumberFunc, cooldownManager, utils)
	if not buySlotModel then return end

	local basePart = buySlotModel:FindFirstChild("Base")
	if not basePart or not basePart:IsA("BasePart") then return end

	-- Obtener owner
	local owner = utils.getPlotOwner(plotName)
	if not owner then return end

	local userId = owner.UserId

	-- Limpiar recursos anteriores
	slotTracker.clearBuySlotData(userId, slotNumber)

	-- Obtener precio del SlotConfig
	local slotData = SlotConfig.Slots[tostring(slotNumber)]
	if not slotData or not slotData.Price then return end

	-- Clonar y configurar billboard
	local billboard = slotBillboardTemplate:Clone()
	billboard.Name = "SlotPriceBillboard_" .. slotNumber

	local infoFrame = billboard:FindFirstChild("Info")
	if infoFrame then
		local priceLabel = infoFrame:FindFirstChild("Price")
		if priceLabel and priceLabel:IsA("TextLabel") then
			priceLabel.Text = formatNumberFunc(slotData.Price)
		end
	end

	billboard.Parent = basePart

	-- Conectar evento Touched
	basePart.CanTouch = true
	local connection = basePart.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		local currentOwner = utils.getPlotOwner(plotName)
		if currentOwner ~= player then
			if not (cooldownManager and cooldownManager.isPlayerOnCooldown(player)) then
				if warningEvent then
					warningEvent:FireClient(player, "This is not your plot!", COLOR_ERROR)
				end
				if cooldownManager then
					cooldownManager.updatePlayerCooldown(player)
				end
			end
			return
		end

		SlotManager.handleSlotPurchase(player, slotNumber, warningEvent, formatNumberFunc, cooldownManager)
	end)

	-- Guardar referencias
	slotTracker.setBuySlotData(userId, slotNumber, {
		billboard = billboard,
		connection = connection,
		model = buySlotModel
	})

	print("[SlotManager] Buy slot configurado:", slotNumber)
end

--------------------------------------------------------------
-- CONFIGURACIÓN DE PLACE SLOTS
--------------------------------------------------------------

-- Configura un place slot con su ProximityPrompt y eventos
function SlotManager.setupPlaceSlot(placeSlotModel, slotNumber, plotName, slotTracker, warningEvent, utils)
	if not placeSlotModel then return end

	local collectPart = placeSlotModel:FindFirstChild("Collect")
	if not collectPart or not collectPart:IsA("BasePart") then return end

	local owner = utils.getPlotOwner(plotName)
	if not owner then return end

	local userId = owner.UserId

	-- Limpiar recursos anteriores
	slotTracker.clearPlaceSlotData(userId, slotNumber)

	-- Verificar si hay un juice colocado en este slot
	local juiceInSlot = utils.getJuiceFolderInSlot(owner, slotNumber)

	-- Crear ProximityPrompt
	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.Name = "PlaceJuicePrompt_" .. slotNumber
	proximityPrompt.MaxActivationDistance = 10
	proximityPrompt.HoldDuration = 0.15
	proximityPrompt.RequiresLineOfSight = false
	proximityPrompt.Style = Enum.ProximityPromptStyle.Custom

	if juiceInSlot then
		proximityPrompt.ActionText = "Remove Juice"
		proximityPrompt.ObjectText = juiceInSlot.Name
	else
		proximityPrompt.ActionText = "Place Juice"
		proximityPrompt.ObjectText = "Slot " .. slotNumber
	end

	proximityPrompt.Parent = collectPart

	-- Conectar evento Triggered
	local connection = proximityPrompt.Triggered:Connect(function(player)
		SlotManager.handlePlaceSlotInteraction(player, slotNumber, plotName, proximityPrompt, placeSlotModel, warningEvent, utils)
	end)

	-- Guardar referencias
	slotTracker.setPlaceSlotData(userId, slotNumber, {
		proximityPrompt = proximityPrompt,
		connection = connection,
		model = placeSlotModel
	})

	print("[SlotManager] Place slot configurado:", slotNumber)
end

-- Maneja la interacción con un place slot (colocar/remover juice)
function SlotManager.handlePlaceSlotInteraction(player, slotNumber, plotName, proximityPrompt, placeSlotModel, warningEvent, utils)
	local currentOwner = utils.getPlotOwner(plotName)
	if currentOwner ~= player then
		if warningEvent then
			warningEvent:FireClient(player, "This is not your plot!", COLOR_ERROR)
		end
		return
	end

	local juiceInSlot = utils.getJuiceFolderInSlot(player, slotNumber)

	-- Si HAY juice, removerlo
	if juiceInSlot then
		SlotManager.removeJuiceFromSlot(player, juiceInSlot, slotNumber, placeSlotModel, proximityPrompt)
	else
		-- Si NO hay juice, colocarlo
		SlotManager.placeJuiceInSlot(player, slotNumber, placeSlotModel, proximityPrompt, warningEvent)
	end
end

-- Remueve un juice de un slot
function SlotManager.removeJuiceFromSlot(player, juiceFolder, slotNumber, placeSlotModel, proximityPrompt)
	-- Limpiar visuals del slot
	if JuiceVisuals then
		JuiceVisuals.cleanupSlotVisuals(placeSlotModel)
	end

	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return end

	local juicesFolder = inventory:FindFirstChild("Juices")
	if not juicesFolder then return end

	-- Sumar MoneyGenerated a Money del jugador
	local moneyGenerated = juiceFolder:FindFirstChild("MoneyGenerated")
	if moneyGenerated and moneyGenerated:IsA("IntValue") then
		local dataFolder = player:FindFirstChild("Data")
		if dataFolder then
			local moneyValue = dataFolder:FindFirstChild("Money")
			if moneyValue and moneyValue:IsA("IntValue") then
				moneyValue.Value = moneyValue.Value + moneyGenerated.Value
			end
		end
		moneyGenerated:Destroy()
	end

	-- Mover a inventario
	juiceFolder.Parent = juicesFolder

	-- Resetear slot
	local slotValue = juiceFolder:FindFirstChild("Slot")
	if slotValue and slotValue:IsA("IntValue") then
		slotValue.Value = 0
	end

	-- Actualizar ProximityPrompt
	proximityPrompt.ActionText = "Place Juice"
	proximityPrompt.ObjectText = "Slot " .. slotNumber

	print("[SlotManager] Juice removido del slot:", slotNumber)
end

-- Coloca un juice en un slot
function SlotManager.placeJuiceInSlot(player, slotNumber, placeSlotModel, proximityPrompt, warningEvent)
	local character = player.Character
	if not character then return end

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		if warningEvent then
			warningEvent:FireClient(player, "You need to equip a juice first!", COLOR_ERROR)
		end
		return
	end

	-- Verificar que sea un juice
	local typeValue = tool:FindFirstChild("Type")
	if not typeValue or not typeValue:IsA("StringValue") or typeValue.Value ~= "Juice" then
		if warningEvent then
			warningEvent:FireClient(player, "You need to equip a juice!", COLOR_ERROR)
		end
		return
	end

	local toolId = tool:FindFirstChild("Id")
	if not toolId or not toolId:IsA("IntValue") then
		if warningEvent then
			warningEvent:FireClient(player, "Invalid juice tool!", COLOR_ERROR)
		end
		return
	end

	-- Buscar juice en inventario
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return end

	local juicesFolder = inventory:FindFirstChild("Juices")
	if not juicesFolder then return end

	-- BUSCAR EN TODOS LOS FOLDERS CON EL MISMO NOMBRE hasta encontrar el que tenga el ID correcto
	local juiceFolder = nil
	for _, folder in ipairs(juicesFolder:GetChildren()) do
		if folder:IsA("Folder") and folder.Name == tool.Name then
			local juiceFolderId = folder:FindFirstChild("Id")
			if juiceFolderId and juiceFolderId:IsA("IntValue") and juiceFolderId.Value == toolId.Value then
				juiceFolder = folder
				break
			end
		end
	end

	if not juiceFolder then
		if warningEvent then
			warningEvent:FireClient(player, "Juice not found in inventory with matching ID!", COLOR_ERROR)
		end
		return
	end

	-- Ya encontramos el folder correcto con nombre e ID coincidentes

	-- Mover a PlacedJuices
	local placedJuicesFolder = player:FindFirstChild("PlacedJuices")
	if not placedJuicesFolder then
		placedJuicesFolder = Instance.new("Folder")
		placedJuicesFolder.Name = "PlacedJuices"
		placedJuicesFolder.Parent = player
	end

	juiceFolder.Parent = placedJuicesFolder

	-- Eliminar Id
	local juiceFolderId = juiceFolder:FindFirstChild("Id")
	if juiceFolderId then
		juiceFolderId:Destroy()
	end

	-- Establecer slot
	local slotValue = juiceFolder:FindFirstChild("Slot")
	if slotValue and slotValue:IsA("IntValue") then
		slotValue.Value = slotNumber
	else
		local newSlot = Instance.new("IntValue")
		newSlot.Name = "Slot"
		newSlot.Value = slotNumber
		newSlot.Parent = juiceFolder
	end

	-- Crear MoneyGenerated
	local moneyGenerated = Instance.new("IntValue")
	moneyGenerated.Name = "MoneyGenerated"
	moneyGenerated.Value = 0
	moneyGenerated.Parent = juiceFolder

	-- Destruir tool
	tool:Destroy()

	-- Actualizar ProximityPrompt
	proximityPrompt.ActionText = "Remove Juice"
	proximityPrompt.ObjectText = juiceFolder.Name

	-- Limpiar visuals del slot (por si quedaron residuos)
	task.wait(0.1)
	if JuiceVisuals then
		JuiceVisuals.cleanupSlotVisuals(placeSlotModel)
	end

	print("[SlotManager] Juice colocado en slot:", slotNumber)
end

--------------------------------------------------------------
-- ACTUALIZACIÓN DE TODOS LOS SLOTS
--------------------------------------------------------------

-- Actualiza todos los slots de un jugador
function SlotManager.updateAllSlots(player, slotTracker, warningEvent, formatNumberFunc, cooldownManager, utils)
	local plotName = player:FindFirstChild("CurrentPlot")
	if not plotName or plotName.Value == "" then return end

	local dataFolder = player:FindFirstChild("Data")
	if not dataFolder then return end

	local slotsValue = dataFolder:FindFirstChild("Slots")
	if not slotsValue or not slotsValue:IsA("IntValue") then return end

	task.wait(0.1)

	local clonedModel = utils.findClonedModel(player)
	if not clonedModel then return end

	local slotsFolder = utils.getSlotsFolder(clonedModel)
	if not slotsFolder then return end

	local userId = player.UserId

	-- Limpiar todos los slots existentes
	if slotTracker.hasPlayerData(userId) then
		local playerData = slotTracker.getPlayerData(userId)
		if playerData and playerData.buySlots then
			for slotNumber in pairs(playerData.buySlots) do
				slotTracker.clearBuySlotData(userId, slotNumber)
			end
		end
		if playerData and playerData.placeSlots then
			for slotNumber in pairs(playerData.placeSlots) do
				slotTracker.clearPlaceSlotData(userId, slotNumber)
			end
		end
	end

	-- Configurar Buy slots
	local buyFolder = slotsFolder:FindFirstChild("Buy")
	if buyFolder then
		for _, child in ipairs(buyFolder:GetChildren()) do
			local slotNumber = tonumber(child.Name)
			if slotNumber and slotNumber == slotsValue.Value + 1 then
				SlotManager.setupBuySlot(child, slotNumber, plotName.Value, slotTracker, warningEvent, formatNumberFunc, cooldownManager, utils)
			end
		end
	end

	-- Configurar Place slots
	local placeFolder = slotsFolder:FindFirstChild("Place")
	if placeFolder then
		for _, child in ipairs(placeFolder:GetChildren()) do
			local slotNumber = tonumber(child.Name)
			if slotNumber and slotNumber <= slotsValue.Value then
				SlotManager.setupPlaceSlot(child, slotNumber, plotName.Value, slotTracker, warningEvent, utils)
			end
		end
	end
end

return SlotManager
