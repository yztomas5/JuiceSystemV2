--[[
	SlotTracker.lua
	Módulo para tracking de slots y gestión de datos de jugadores
	Mantiene un registro centralizado de todos los slots y sus conexiones
]]

local SlotTracker = {}

--------------------------------------------------------------
-- ALMACENAMIENTO DE DATOS
--------------------------------------------------------------

-- Estructura: [userId] = { slots = {}, connections = {}, cooldowns = {}, currentModel = nil, ... }
local playerData = {}

-- Estructura para slots de jugos: [userId] = { [slotNumber] = { tool, billboard, juiceFolder, collectConnection, cancelToken } }
-- Estructura para slots de compra: [userId] = { buySlots = {}, placeSlots = {} }

--------------------------------------------------------------
-- INICIALIZACIÓN DE DATOS
--------------------------------------------------------------

-- Inicializa los datos de un jugador para el sistema de jugos
function SlotTracker.initializeJuiceData(userId)
	if not playerData[userId] then
		playerData[userId] = {}
	end

	playerData[userId].slots = playerData[userId].slots or {}
	playerData[userId].connections = playerData[userId].connections or {}
	playerData[userId].cooldowns = playerData[userId].cooldowns or {}
	playerData[userId].slotConnections = playerData[userId].slotConnections or {}
	playerData[userId].modelConnections = playerData[userId].modelConnections or {}
	playerData[userId].collectZoneConnection = nil
	playerData[userId].collectZoneGuiConnection = nil
	playerData[userId].currentModel = nil

	return playerData[userId]
end

-- Inicializa los datos de un jugador para el sistema de compra de slots
function SlotTracker.initializePurchaseData(userId)
	if not playerData[userId] then
		playerData[userId] = {}
	end

	playerData[userId].buySlots = playerData[userId].buySlots or {}
	playerData[userId].placeSlots = playerData[userId].placeSlots or {}
	playerData[userId].modelConnections = playerData[userId].modelConnections or {}
	playerData[userId].currentModel = nil

	return playerData[userId]
end

--------------------------------------------------------------
-- ACCESO A DATOS
--------------------------------------------------------------

-- Obtiene los datos de un jugador
function SlotTracker.getPlayerData(userId)
	return playerData[userId]
end

-- Verifica si existen datos de un jugador
function SlotTracker.hasPlayerData(userId)
	return playerData[userId] ~= nil
end

-- Obtiene los datos de un slot específico para jugos
function SlotTracker.getSlotData(userId, slotNumber)
	if not playerData[userId] or not playerData[userId].slots then return nil end
	return playerData[userId].slots[slotNumber]
end

-- Obtiene los datos de un buy slot
function SlotTracker.getBuySlotData(userId, slotNumber)
	if not playerData[userId] or not playerData[userId].buySlots then return nil end
	return playerData[userId].buySlots[slotNumber]
end

-- Obtiene los datos de un place slot
function SlotTracker.getPlaceSlotData(userId, slotNumber)
	if not playerData[userId] or not playerData[userId].placeSlots then return nil end
	return playerData[userId].placeSlots[slotNumber]
end

--------------------------------------------------------------
-- GESTIÓN DE SLOTS DE JUGOS
--------------------------------------------------------------

-- Crea o actualiza los datos de un slot de jugo
function SlotTracker.setSlotData(userId, slotNumber, data)
	if not playerData[userId] then
		SlotTracker.initializeJuiceData(userId)
	end

	if not playerData[userId].slots[slotNumber] then
		playerData[userId].slots[slotNumber] = {}
	end

	for key, value in pairs(data) do
		playerData[userId].slots[slotNumber][key] = value
	end
end

-- Limpia los datos de un slot de jugo
function SlotTracker.clearSlotData(userId, slotNumber)
	if not playerData[userId] or not playerData[userId].slots then return end

	local slotData = playerData[userId].slots[slotNumber]
	if not slotData then return end

	-- Limpiar referencias (NO destruir objetos del Workspace)
	slotData.tool = nil
	slotData.billboard = nil
	slotData.juiceFolder = nil
	slotData.cancelToken = nil

	-- Desconectar colección si existe
	if slotData.collectConnection then
		pcall(function()
			slotData.collectConnection:Disconnect()
		end)
		slotData.collectConnection = nil
	end

	playerData[userId].slots[slotNumber] = nil

	-- Limpiar cooldown
	if playerData[userId].cooldowns then
		playerData[userId].cooldowns[slotNumber] = nil
	end
end

-- Limpia los datos de un slot Y destruye los objetos físicos (tools, billboards)
-- Usar esta función cuando se cambia de modelo o se necesita destruir explícitamente
function SlotTracker.clearSlotDataWithDestruction(userId, slotNumber)
	if not playerData[userId] or not playerData[userId].slots then return end

	local slotData = playerData[userId].slots[slotNumber]
	if not slotData then return end

	-- Destruir tool si existe
	if slotData.tool and slotData.tool.Parent then
		pcall(function()
			slotData.tool:Destroy()
		end)
	end

	-- Destruir billboard si existe
	if slotData.billboard and slotData.billboard.Parent then
		pcall(function()
			slotData.billboard:Destroy()
		end)
	end

	-- Desconectar colección si existe
	if slotData.collectConnection then
		pcall(function()
			slotData.collectConnection:Disconnect()
		end)
	end

	-- Limpiar todo
	playerData[userId].slots[slotNumber] = nil

	-- Limpiar cooldown
	if playerData[userId].cooldowns then
		playerData[userId].cooldowns[slotNumber] = nil
	end

	print("[SlotTracker] Slot", slotNumber, "limpiado con destrucción de objetos")
end

--------------------------------------------------------------
-- GESTIÓN DE SLOTS DE COMPRA
--------------------------------------------------------------

-- Establece los datos de un buy slot
function SlotTracker.setBuySlotData(userId, slotNumber, data)
	if not playerData[userId] then
		SlotTracker.initializePurchaseData(userId)
	end

	if not playerData[userId].buySlots[slotNumber] then
		playerData[userId].buySlots[slotNumber] = {}
	end

	for key, value in pairs(data) do
		playerData[userId].buySlots[slotNumber][key] = value
	end
end

-- Limpia los datos de un buy slot
function SlotTracker.clearBuySlotData(userId, slotNumber)
	if not playerData[userId] or not playerData[userId].buySlots then return end

	local slotData = playerData[userId].buySlots[slotNumber]
	if not slotData then return end

	-- Destruir billboard si existe
	if slotData.billboard and slotData.billboard.Parent then
		slotData.billboard:Destroy()
	end

	-- Desconectar evento
	if slotData.connection then
		pcall(function()
			slotData.connection:Disconnect()
		end)
	end

	playerData[userId].buySlots[slotNumber] = nil
end

-- Establece los datos de un place slot
function SlotTracker.setPlaceSlotData(userId, slotNumber, data)
	if not playerData[userId] then
		SlotTracker.initializePurchaseData(userId)
	end

	if not playerData[userId].placeSlots[slotNumber] then
		playerData[userId].placeSlots[slotNumber] = {}
	end

	for key, value in pairs(data) do
		playerData[userId].placeSlots[slotNumber][key] = value
	end
end

-- Limpia los datos de un place slot
function SlotTracker.clearPlaceSlotData(userId, slotNumber)
	if not playerData[userId] or not playerData[userId].placeSlots then return end

	local slotData = playerData[userId].placeSlots[slotNumber]
	if not slotData then return end

	-- Destruir proximity prompt si existe
	if slotData.proximityPrompt and slotData.proximityPrompt.Parent then
		slotData.proximityPrompt:Destroy()
	end

	-- Desconectar evento
	if slotData.connection then
		pcall(function()
			slotData.connection:Disconnect()
		end)
	end

	playerData[userId].placeSlots[slotNumber] = nil
end

--------------------------------------------------------------
-- GESTIÓN DE CONEXIONES
--------------------------------------------------------------

-- Guarda una conexión de slot
function SlotTracker.setSlotConnection(userId, juiceFolder, connection)
	if not playerData[userId] then return end
	if not playerData[userId].slotConnections then
		playerData[userId].slotConnections = {}
	end

	playerData[userId].slotConnections[juiceFolder] = connection
end

-- Limpia una conexión de slot
function SlotTracker.clearSlotConnection(userId, juiceFolder)
	if not playerData[userId] or not playerData[userId].slotConnections then return end

	local connection = playerData[userId].slotConnections[juiceFolder]
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
		playerData[userId].slotConnections[juiceFolder] = nil
	end
end

-- Establece la conexión de CollectZone
function SlotTracker.setCollectZoneConnection(userId, connection)
	if not playerData[userId] then return end
	playerData[userId].collectZoneConnection = connection
end

-- Limpia la conexión de CollectZone
function SlotTracker.clearCollectZoneConnection(userId)
	if not playerData[userId] then return end

	if playerData[userId].collectZoneConnection then
		pcall(function()
			playerData[userId].collectZoneConnection:Disconnect()
		end)
		playerData[userId].collectZoneConnection = nil
	end
end

-- Establece la conexión de actualización de GUI de CollectZone
function SlotTracker.setCollectZoneGuiConnection(userId, connection)
	if not playerData[userId] then return end
	playerData[userId].collectZoneGuiConnection = connection
end

-- Limpia la conexión de actualización de GUI de CollectZone
function SlotTracker.clearCollectZoneGuiConnection(userId)
	if not playerData[userId] then return end

	if playerData[userId].collectZoneGuiConnection then
		pcall(function()
			playerData[userId].collectZoneGuiConnection:Disconnect()
		end)
		playerData[userId].collectZoneGuiConnection = nil
	end
end

-- Establece la conexión de monitoreo de modelo
function SlotTracker.setModelMonitorConnection(userId, connection)
	if not playerData[userId] then return end
	playerData[userId].modelMonitorConnection = connection
end

-- Limpia la conexión de monitoreo de modelo
function SlotTracker.clearModelMonitorConnection(userId)
	if not playerData[userId] then return end

	if playerData[userId].modelMonitorConnection then
		pcall(function()
			playerData[userId].modelMonitorConnection:Disconnect()
		end)
		playerData[userId].modelMonitorConnection = nil
	end
end

-- Agrega una conexión de modelo
function SlotTracker.addModelConnection(userId, connection)
	if not playerData[userId] then return end
	if not playerData[userId].modelConnections then
		playerData[userId].modelConnections = {}
	end

	table.insert(playerData[userId].modelConnections, connection)
end

-- Limpia todas las conexiones de modelo
function SlotTracker.clearModelConnections(userId)
	if not playerData[userId] or not playerData[userId].modelConnections then return end

	for _, connection in ipairs(playerData[userId].modelConnections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	playerData[userId].modelConnections = {}
end

--------------------------------------------------------------
-- GESTIÓN DE MODELO ACTUAL
--------------------------------------------------------------

-- Establece el modelo actual del jugador
function SlotTracker.setCurrentModel(userId, model)
	if not playerData[userId] then return end
	playerData[userId].currentModel = model
end

-- Obtiene el modelo actual del jugador
function SlotTracker.getCurrentModel(userId)
	if not playerData[userId] then return nil end
	return playerData[userId].currentModel
end

--------------------------------------------------------------
-- GESTIÓN DE COOLDOWNS
--------------------------------------------------------------

-- Establece un cooldown para un slot o identificador
function SlotTracker.setCooldown(userId, identifier, time)
	if not playerData[userId] then return end
	if not playerData[userId].cooldowns then
		playerData[userId].cooldowns = {}
	end

	playerData[userId].cooldowns[identifier] = time or tick()
end

-- Obtiene el tiempo de cooldown
function SlotTracker.getCooldown(userId, identifier)
	if not playerData[userId] or not playerData[userId].cooldowns then return nil end
	return playerData[userId].cooldowns[identifier]
end

-- Verifica si está en cooldown
function SlotTracker.isOnCooldown(userId, identifier, cooldownDuration)
	local lastTime = SlotTracker.getCooldown(userId, identifier)
	if not lastTime then return false end

	local currentTime = tick()
	return (currentTime - lastTime) < cooldownDuration
end

--------------------------------------------------------------
-- LIMPIEZA TOTAL
--------------------------------------------------------------

-- Limpia todos los datos de un jugador (jugos)
function SlotTracker.cleanupJuiceData(userId)
	if not playerData[userId] then return end

	-- Limpiar todos los slots
	if playerData[userId].slots then
		for slotNumber in pairs(playerData[userId].slots) do
			SlotTracker.clearSlotData(userId, slotNumber)
		end
	end

	-- Limpiar conexiones de slots
	if playerData[userId].slotConnections then
		for juiceFolder, connection in pairs(playerData[userId].slotConnections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		playerData[userId].slotConnections = {}
	end

	-- Limpiar conexiones de modelo
	SlotTracker.clearModelConnections(userId)

	-- Limpiar CollectZone
	SlotTracker.clearCollectZoneConnection(userId)
	SlotTracker.clearCollectZoneGuiConnection(userId)

	-- Limpiar monitoreo de modelo
	SlotTracker.clearModelMonitorConnection(userId)
end

-- Limpia todos los slots CON DESTRUCCIÓN de objetos físicos
-- Usar esta función cuando se cambia de modelo
function SlotTracker.cleanupAllSlotsWithDestruction(userId)
	if not playerData[userId] then return end

	-- Limpiar todos los slots con destrucción
	if playerData[userId].slots then
		for slotNumber in pairs(playerData[userId].slots) do
			SlotTracker.clearSlotDataWithDestruction(userId, slotNumber)
		end
	end

	-- Limpiar conexiones de slots
	if playerData[userId].slotConnections then
		for juiceFolder, connection in pairs(playerData[userId].slotConnections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		playerData[userId].slotConnections = {}
	end

	print("[SlotTracker] Todos los slots limpiados con destrucción de objetos para userId:", userId)
end

-- Limpia todos los datos de un jugador (compra de slots)
function SlotTracker.cleanupPurchaseData(userId)
	if not playerData[userId] then return end

	-- Limpiar buy slots
	if playerData[userId].buySlots then
		for slotNumber in pairs(playerData[userId].buySlots) do
			SlotTracker.clearBuySlotData(userId, slotNumber)
		end
	end

	-- Limpiar place slots
	if playerData[userId].placeSlots then
		for slotNumber in pairs(playerData[userId].placeSlots) do
			SlotTracker.clearPlaceSlotData(userId, slotNumber)
		end
	end

	-- Limpiar conexiones de modelo
	SlotTracker.clearModelConnections(userId)
end

-- Limpia completamente los datos de un jugador
function SlotTracker.removePlayer(userId)
	if playerData[userId] then
		SlotTracker.cleanupJuiceData(userId)
		SlotTracker.cleanupPurchaseData(userId)
		playerData[userId] = nil
	end
end

return SlotTracker
