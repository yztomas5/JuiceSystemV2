--[[
	PlacedJuicesServer.lua
	Script principal del servidor para gestión de jugos colocados
	Sistema modular robusto con identificación única por slot
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--------------------------------------------------------------
-- IMPORTAR MÓDULOS DEL SISTEMA
--------------------------------------------------------------
local JuiceSystemPath = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"):WaitForChild("JuiceSystem")

local JuiceSystemUtils = require(JuiceSystemPath:WaitForChild("JuiceSystemUtils"))
local SlotTracker = require(JuiceSystemPath:WaitForChild("SlotTracker"))
local JuiceVisuals = require(JuiceSystemPath:WaitForChild("JuiceVisuals"))
local JuiceCollection = require(JuiceSystemPath:WaitForChild("JuiceCollection"))
local ModelChangeDetector = require(JuiceSystemPath:WaitForChild("ModelChangeDetector"))

--------------------------------------------------------------
-- REFERENCIAS
--------------------------------------------------------------
local juicesToolsFolder = ServerStorage:WaitForChild("Inventario"):WaitForChild("Juices")

--------------------------------------------------------------
-- CREACIÓN DE TOOL VISUAL EN EL SLOT
--------------------------------------------------------------

local function createSlotJuiceTool(player, juiceFolder, slotNumber)
	local userId = player.UserId

	-- VERIFICAR que el jugador todavía existe en SlotTracker
	if not SlotTracker.hasPlayerData(userId) then
		print("[PlacedJuices] PlayerData no existe, jugador desconectado:", player.Name)
		return
	end

	-- PREVENIR DUPLICADOS: Verificar si ya existe una tool en este slot
	if JuiceSystemUtils.toolExistsInSlot(player, slotNumber) then
		print("[PlacedJuices] Tool ya existe en slot:", slotNumber, "abortando creación")
		return
	end

	-- Limpiar slot antes de crear nuevo
	SlotTracker.clearSlotData(userId, slotNumber)

	-- Leer valores del folder
	local modelValue = juiceFolder:FindFirstChild("Model")
	local priceValue = juiceFolder:FindFirstChild("Price")
	local pricePerSecValue = juiceFolder:FindFirstChild("PricePerSec")
	local qualityValue = juiceFolder:FindFirstChild("Quality")
	local ingredientsFolder = juiceFolder:FindFirstChild("Ingredients")

	if not modelValue or not priceValue or not pricePerSecValue or not qualityValue then
		warn("[PlacedJuices] Folder incompleto:", juiceFolder.Name)
		return
	end

	-- Buscar tool template
	local toolTemplate = juicesToolsFolder:FindFirstChild(modelValue.Value)
	if not toolTemplate or not toolTemplate:IsA("Tool") then
		warn("[PlacedJuices] Tool no encontrada:", modelValue.Value)
		return
	end

	-- Crear token de cancelación
	local cancelToken = tick()
	SlotTracker.setSlotData(userId, slotNumber, { cancelToken = cancelToken })

	-- Esperar a que el slot model esté disponible
	task.wait(0.3)

	-- VERIFICAR DESPUÉS DEL WAIT
	if not SlotTracker.hasPlayerData(userId) then
		print("[PlacedJuices] Jugador desconectado durante wait")
		return
	end

	-- CRÍTICO: Verificar que el juice folder aún existe y está en PlacedJuices
	if not juiceFolder.Parent or juiceFolder.Parent.Name ~= "PlacedJuices" then
		print("[PlacedJuices] Juice eliminado durante la creación, abortando:", slotNumber)
		SlotTracker.clearSlotData(userId, slotNumber)
		return
	end

	-- CRÍTICO: Verificar que el token no ha cambiado
	local slotData = SlotTracker.getSlotData(userId, slotNumber)
	if not slotData or slotData.cancelToken ~= cancelToken then
		print("[PlacedJuices] Creación cancelada por nueva operación en slot:", slotNumber)
		return
	end

	-- VERIFICAR NUEVAMENTE si existe tool en slot después del wait
	if JuiceSystemUtils.toolExistsInSlot(player, slotNumber) then
		print("[PlacedJuices] Tool ya existe en slot después del wait:", slotNumber, "abortando")
		SlotTracker.clearSlotData(userId, slotNumber)
		return
	end

	-- Buscar slot model
	local slotModel = JuiceSystemUtils.findSlotModel(player, slotNumber)
	if not slotModel then
		warn("[PlacedJuices] Slot model no encontrado:", slotNumber)
		return
	end

	-- Clonar tool
	local clonedTool = toolTemplate:Clone()
	clonedTool.Name = juiceFolder.Name .. "_SlotTool"

	-- Asegurar que tenga el tipo "Juice"
	local typeValue = clonedTool:FindFirstChild("Type")
	if not typeValue then
		typeValue = Instance.new("StringValue")
		typeValue.Name = "Type"
		typeValue.Value = "Juice"
		typeValue.Parent = clonedTool
	else
		typeValue.Value = "Juice"
	end

	-- Agregar identificador de slot
	local slotId = Instance.new("IntValue")
	slotId.Name = "SlotId"
	slotId.Value = slotNumber
	slotId.Parent = clonedTool

	-- Obtener color mezclado de ingredientes
	local mixedColor = JuiceVisuals.getMixedColorFromIngredients(ingredientsFolder)

	-- Aplicar texturas con el color mezclado
	JuiceVisuals.applyJuiceTextures(clonedTool, mixedColor)

	-- Aplicar mutaciones a la tool
	JuiceVisuals.applyMutationsToTool(clonedTool, ingredientsFolder)

	-- Buscar la parte Base dentro del slot model
	local slotBasePart = slotModel:FindFirstChild("Base")
	if not slotBasePart or not slotBasePart:IsA("BasePart") then
		warn("[PlacedJuices] Base part no encontrada en slot:", slotNumber)
		clonedTool:Destroy()
		return
	end

	-- Buscar la parte Base dentro de la tool
	local toolBasePart = clonedTool:FindFirstChild("Base")
	if not toolBasePart or not toolBasePart:IsA("BasePart") then
		warn("[PlacedJuices] Base part no encontrada en tool:", clonedTool.Name)
		clonedTool:Destroy()
		return
	end

	-- VERIFICACIÓN FINAL antes de parentear
	if not SlotTracker.hasPlayerData(userId) then
		print("[PlacedJuices] Jugador desconectado antes de parentear")
		clonedTool:Destroy()
		return
	end

	-- Posicionar la parte Base de la tool
	toolBasePart.CFrame = slotBasePart.CFrame
	toolBasePart.Anchored = true
	toolBasePart.CanCollide = false

	-- Configurar el InfoGui
	local moneyGeneratedValue = juiceFolder:FindFirstChild("MoneyGenerated")
	JuiceVisuals.setupJuiceInfoGui(
		clonedTool,
		juiceFolder.Name,
		priceValue.Value,
		pricePerSecValue.Value,
		qualityValue.Value,
		moneyGeneratedValue,
		JuiceSystemUtils.formatNumberWithSuffixes
	)

	-- Crear Billboard GUI con ingredientes
	local billboard = JuiceVisuals.createIngredientsBillboard(slotModel, ingredientsFolder)

	-- Parentear al slot model
	clonedTool.Parent = slotModel

	-- VERIFICACIÓN FINAL antes de guardar referencias
	if not SlotTracker.hasPlayerData(userId) then
		print("[PlacedJuices] Jugador desconectado, limpiando tool recién creada")
		JuiceSystemUtils.safeDestroy(clonedTool)
		JuiceSystemUtils.safeDestroy(billboard)
		return
	end

	-- Guardar referencias en el sistema de tracking
	SlotTracker.setSlotData(userId, slotNumber, {
		tool = clonedTool,
		billboard = billboard,
		juiceFolder = juiceFolder,
		cancelToken = cancelToken
	})

	print("[PlacedJuices] Tool creada en slot:", slotNumber, "para jugador:", player.Name)
end

--------------------------------------------------------------
-- CONECTAR EVENTO DE COLECCIÓN EN SLOT
--------------------------------------------------------------

local function connectCollectEvent(player, slotNumber)
	local userId = player.UserId

	if not SlotTracker.hasPlayerData(userId) then
		print("[PlacedJuices] PlayerData no existe, jugador desconectado:", player.Name)
		return
	end

	-- Buscar slot model
	local slotModel = JuiceSystemUtils.findSlotModel(player, slotNumber)
	if not slotModel then return end

	-- Buscar Collect part
	local collectPart = slotModel:FindFirstChild("Collect")
	if not collectPart or not collectPart:IsA("BasePart") then
		warn("[PlacedJuices] Collect part no encontrada en slot:", slotNumber)
		return
	end

	-- Conectar evento de colección
	local connection = JuiceCollection.connectSlotCollection(player, slotNumber, collectPart, SlotTracker)

	-- Guardar conexión
	local slotData = SlotTracker.getSlotData(userId, slotNumber)
	if slotData then
		slotData.collectConnection = connection
	else
		SlotTracker.setSlotData(userId, slotNumber, { collectConnection = connection })
	end

	print("[PlacedJuices] Evento de colección conectado para slot:", slotNumber)
end

--------------------------------------------------------------
-- PROCESAR UN JUICE EN PLACEDPUICES
--------------------------------------------------------------

local function processPlacedJuice(player, juiceFolder)
	if not SlotTracker.hasPlayerData(player.UserId) then
		print("[PlacedJuices] PlayerData no existe, jugador desconectado:", player.Name)
		return
	end

	local slotValue = juiceFolder:FindFirstChild("Slot")
	if not slotValue or not slotValue:IsA("IntValue") or slotValue.Value == 0 then
		return
	end

	local slotNumber = slotValue.Value

	-- Crear tool visual
	createSlotJuiceTool(player, juiceFolder, slotNumber)

	-- Conectar evento de colección
	connectCollectEvent(player, slotNumber)
end

--------------------------------------------------------------
-- REMOVER UN JUICE DE UN SLOT
--------------------------------------------------------------

local function removePlacedJuice(player, juiceFolder, slotNumber)
	if not SlotTracker.hasPlayerData(player.UserId) then
		print("[PlacedJuices] PlayerData no existe, jugador ya desconectado:", player.Name)
		return
	end

	-- Limpiar conexión de slot
	SlotTracker.clearSlotConnection(player.UserId, juiceFolder)

	-- Limpiar slot
	SlotTracker.clearSlotData(player.UserId, slotNumber)
end

--------------------------------------------------------------
-- ACTUALIZAR GUI DE COLLECTZONE
--------------------------------------------------------------

local function updateCollectZoneGui(player)
	if not SlotTracker.hasPlayerData(player.UserId) then return end

	local collectZone = JuiceSystemUtils.findCollectZone(player)
	if not collectZone then return end

	JuiceCollection.updateCollectZoneGui(player, collectZone, JuiceSystemUtils.formatNumberWithSuffixes)
end

--------------------------------------------------------------
-- CONECTAR EVENTO DE COLECCIÓN EN COLLECTZONE
--------------------------------------------------------------

local function connectCollectZoneEvent(player)
	local userId = player.UserId

	if not SlotTracker.hasPlayerData(userId) then
		print("[PlacedJuices] PlayerData no existe, jugador desconectado:", player.Name)
		return
	end

	-- Desconectar evento anterior si existe
	SlotTracker.clearCollectZoneConnection(userId)

	local collectZone = JuiceSystemUtils.findCollectZone(player)
	if not collectZone then
		warn("[PlacedJuices] CollectZone no encontrada para:", player.Name)
		return
	end

	local collectPart = collectZone:FindFirstChild("Collect")
	if not collectPart or not collectPart:IsA("BasePart") then
		warn("[PlacedJuices] Collect part no encontrada en CollectZone")
		return
	end

	-- Conectar evento de colección
	local connection = JuiceCollection.connectCollectZoneCollection(player, collectPart, SlotTracker)

	-- Guardar conexión
	SlotTracker.setCollectZoneConnection(userId, connection)

	print("[PlacedJuices] Evento de colección conectado para CollectZone")
end

--------------------------------------------------------------
-- CONFIGURAR ACTUALIZACIÓN AUTOMÁTICA DE GUI DE COLLECTZONE
--------------------------------------------------------------

local function setupCollectZoneGuiUpdater(player)
	local userId = player.UserId

	if not SlotTracker.hasPlayerData(userId) then return end

	-- Desconectar evento anterior si existe
	SlotTracker.clearCollectZoneGuiConnection(userId)

	-- Actualizar cada segundo
	local lastGuiUpdate = os.time()
	local connection = RunService.Heartbeat:Connect(function()
		local currentTime = os.time()
		if currentTime > lastGuiUpdate then
			lastGuiUpdate = currentTime
			updateCollectZoneGui(player)
		end
	end)

	SlotTracker.setCollectZoneGuiConnection(userId, connection)

	print("[PlacedJuices] Actualizador de GUI de CollectZone conectado")
end

--------------------------------------------------------------
-- INICIALIZAR PLACEDPUICES EXISTENTES
--------------------------------------------------------------

local function initializePlacedJuices(player)
	local placedJuices = player:WaitForChild("PlacedJuices", 10)
	if not placedJuices then return end

	-- Calcular dinero offline
	JuiceCollection.calculateOfflineMoney(player)

	task.wait(1)  -- Esperar a que los slots se carguen correctamente

	-- Guardar modelo actual
	local currentModel = JuiceSystemUtils.findClonedModel(player)
	SlotTracker.setCurrentModel(player.UserId, currentModel)

	-- Procesar juices existentes
	for _, juiceFolder in ipairs(placedJuices:GetChildren()) do
		if juiceFolder:IsA("Folder") then
			processPlacedJuice(player, juiceFolder)
		end
	end

	-- Configurar CollectZone
	task.wait(0.5)
	connectCollectZoneEvent(player)
	setupCollectZoneGuiUpdater(player)
end

--------------------------------------------------------------
-- CONFIGURAR VIGILANCIA DE PLACEDPUICES
--------------------------------------------------------------

local function setupPlacedJuicesWatcher(player)
	local userId = player.UserId

	-- Inicializar estructuras de datos
	SlotTracker.initializeJuiceData(userId)

	-- Esperar PlacedJuices
	local placedJuices = player:WaitForChild("PlacedJuices", 10)
	if not placedJuices then return end

	-- Procesar juices existentes
	task.spawn(function()
		initializePlacedJuices(player)
	end)

	-- Configurar detección de cambio de modelo
	ModelChangeDetector.setupForJuices(
		player,
		SlotTracker,
		function(player, newModel)
			-- Callback cuando se añade un nuevo modelo
			print("[PlacedJuices] Nuevo modelo detectado, recreando jugos para:", player.Name)

			-- Limpiar todos los slots
			local playerData = SlotTracker.getPlayerData(userId)
			if playerData and playerData.slots then
				for slotNumber in pairs(playerData.slots) do
					SlotTracker.clearSlotData(userId, slotNumber)
				end
			end

			-- Recrear todos los jugos y CollectZone
			local currentPlacedJuices = player:FindFirstChild("PlacedJuices")
			if currentPlacedJuices then
				task.wait(0.5)  -- Esperar a que el nuevo modelo se estabilice
				for _, juiceFolder in ipairs(currentPlacedJuices:GetChildren()) do
					if juiceFolder:IsA("Folder") then
						processPlacedJuice(player, juiceFolder)
					end
				end
			end

			-- Reconectar CollectZone
			task.wait(0.2)
			connectCollectZoneEvent(player)
			setupCollectZoneGuiUpdater(player)
		end,
		function(player)
			-- Callback cuando se remueve el modelo actual
			print("[PlacedJuices] Modelo actual removido, limpiando jugos para:", player.Name)

			-- Limpiar todos los slots
			local playerData = SlotTracker.getPlayerData(userId)
			if playerData and playerData.slots then
				for slotNumber in pairs(playerData.slots) do
					SlotTracker.clearSlotData(userId, slotNumber)
				end
			end
		end
	)

	-- Cuando se añade un juice
	placedJuices.ChildAdded:Connect(function(child)
		if child:IsA("Folder") then
			task.wait(0.1)  -- Esperar a que se configure
			processPlacedJuice(player, child)
		end
	end)

	-- Cuando se elimina un juice
	placedJuices.ChildRemoved:Connect(function(child)
		if not SlotTracker.hasPlayerData(userId) then return end

		if child:IsA("Folder") then
			local slotValue = child:FindFirstChild("Slot")
			if slotValue and slotValue:IsA("IntValue") then
				removePlacedJuice(player, child, slotValue.Value)
			end
		end
	end)

	-- Escuchar cambios en el valor Slot
	placedJuices.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "Slot" and descendant:IsA("IntValue") then
			local juiceFolder = descendant.Parent
			if not juiceFolder or not juiceFolder:IsA("Folder") then return end

			-- Limpiar cualquier conexión previa de este juiceFolder
			SlotTracker.clearSlotConnection(userId, juiceFolder)

			-- Crear nueva conexión
			local connection = descendant:GetPropertyChangedSignal("Value"):Connect(function()
				-- Obtener el slot anterior
				local oldSlot = nil
				local playerData = SlotTracker.getPlayerData(userId)
				if playerData and playerData.slots then
					for slotNum, slotData in pairs(playerData.slots) do
						if slotData.juiceFolder == juiceFolder then
							oldSlot = slotNum
							break
						end
					end
				end

				-- Limpiar slot anterior si existe
				if oldSlot then
					SlotTracker.clearSlotData(userId, oldSlot)
				end

				-- Procesar en el nuevo slot
				if descendant.Value > 0 then
					task.wait(0.1)
					processPlacedJuice(player, juiceFolder)
				end
			end)

			-- Guardar la conexión
			SlotTracker.setSlotConnection(userId, juiceFolder, connection)
		end
	end)

	print("[PlacedJuices] Sistema de vigilancia configurado para:", player.Name)
end

--------------------------------------------------------------
-- INICIALIZACIÓN
--------------------------------------------------------------

-- Iniciar sistema de generación de dinero
JuiceCollection.startMoneyGenerationSystem()

-- Configurar jugadores
Players.PlayerAdded:Connect(function(player)
	setupPlacedJuicesWatcher(player)
end)

-- Guardar tiempo de desconexión y limpiar datos
Players.PlayerRemoving:Connect(function(player)
	JuiceCollection.saveDisconnectTime(player)
	SlotTracker.cleanupJuiceData(player.UserId)
	print("[PlacedJuices] Jugador desconectado:", player.Name)
end)

-- Configurar jugadores que ya están en el servidor
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		setupPlacedJuicesWatcher(player)
	end)
end

print("[PlacedJuices] Sistema de jugos colocados iniciado")
