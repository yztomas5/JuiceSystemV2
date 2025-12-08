--[[
	ModelChangeDetector.lua
	Módulo para detectar cambios en el modelo base de la plot
	Permite reconectar sistemas cuando se cambia de rebirth o modelo
]]

local Workspace = game:GetService("Workspace")

local ModelChangeDetector = {}

--------------------------------------------------------------
-- REFERENCIAS
--------------------------------------------------------------
local plotsFolder = Workspace:WaitForChild("Plots")

--------------------------------------------------------------
-- DETECCIÓN DE CAMBIOS DE MODELO PARA SISTEMA DE JUGOS
--------------------------------------------------------------

-- Configura la detección de cambios de modelo para jugos
function ModelChangeDetector.setupForJuices(player, slotTracker, onModelAdded, onModelRemoved)
	local userId = player.UserId

	local plotName = player:FindFirstChild("CurrentPlot")
	if not plotName or not plotName:IsA("StringValue") then return end

	local function connectToCurrentRebirth()
		if plotName.Value == "" then return end

		local plotModel = plotsFolder:FindFirstChild(plotName.Value)
		if not plotModel then return end

		local baseFolder = plotModel:FindFirstChild("Base")
		if not baseFolder then return end

		local currentRebirthFolder = baseFolder:FindFirstChild("CurrentRebirth")
		if not currentRebirthFolder then return end

		-- Conectar ChildAdded para detectar cuando se añade un nuevo modelo
		local addedConnection = currentRebirthFolder.ChildAdded:Connect(function(child)
			if child.Name ~= "Position" and child:IsA("Model") then
				-- Verificar si realmente es un modelo nuevo
				local currentModel = slotTracker.getCurrentModel(userId)
				if child ~= currentModel then
					print("[ModelChangeDetector] Nuevo modelo detectado (ChildAdded), ejecutando callback para:", player.Name)
					slotTracker.setCurrentModel(userId, child)

					-- Ejecutar callback
					if onModelAdded then
						onModelAdded(player, child)
					end
				end
			end
		end)

		-- Conectar ChildRemoved para detectar cuando se elimina el modelo actual
		local removedConnection = currentRebirthFolder.ChildRemoved:Connect(function(child)
			if not slotTracker.hasPlayerData(userId) then return end

			local currentModel = slotTracker.getCurrentModel(userId)
			if child == currentModel then
				print("[ModelChangeDetector] Modelo actual removido, ejecutando callback para:", player.Name)

				-- Ejecutar callback
				if onModelRemoved then
					onModelRemoved(player)
				end

				slotTracker.setCurrentModel(userId, nil)
			end
		end)

		-- Guardar las conexiones
		slotTracker.addModelConnection(userId, addedConnection)
		slotTracker.addModelConnection(userId, removedConnection)
	end

	-- Conectar inicialmente
	connectToCurrentRebirth()

	-- Reconectar cuando cambie la plot
	plotName:GetPropertyChangedSignal("Value"):Connect(function()
		-- Desconectar conexiones anteriores
		slotTracker.clearModelConnections(userId)

		-- Conectar a la nueva plot
		connectToCurrentRebirth()
	end)

	print("[ModelChangeDetector] Sistema de detección iniciado para jugos:", player.Name)
end

--------------------------------------------------------------
-- DETECCIÓN DE CAMBIOS DE MODELO PARA SISTEMA DE SLOTS
--------------------------------------------------------------

-- Configura la detección de cambios de modelo para slots
function ModelChangeDetector.setupForSlots(player, slotTracker, onModelChanged)
	local userId = player.UserId

	local plotName = player:FindFirstChild("CurrentPlot")
	if not plotName or not plotName:IsA("StringValue") then return end

	local function connectToCurrentRebirth()
		if plotName.Value == "" then return end

		local plotModel = plotsFolder:FindFirstChild(plotName.Value)
		if not plotModel then return end

		local baseFolder = plotModel:FindFirstChild("Base")
		if not baseFolder then return end

		local currentRebirthFolder = baseFolder:FindFirstChild("CurrentRebirth")
		if not currentRebirthFolder then return end

		-- Conectar ChildAdded para detectar cuando se añade un nuevo modelo
		local addedConnection = currentRebirthFolder.ChildAdded:Connect(function(child)
			if child.Name ~= "Position" and child:IsA("Model") then
				-- Verificar si realmente es un modelo nuevo
				local currentModel = slotTracker.getCurrentModel(userId)
				if child ~= currentModel then
					print("[ModelChangeDetector] Nuevo modelo detectado (ChildAdded), recreando slots para:", player.Name)
					slotTracker.setCurrentModel(userId, child)

					-- Ejecutar callback
					if onModelChanged then
						task.wait(0.5)  -- Esperar a que el nuevo modelo se estabilice
						onModelChanged(player)
					end
				end
			end
		end)

		-- Conectar ChildRemoved para detectar cuando se elimina el modelo actual
		local removedConnection = currentRebirthFolder.ChildRemoved:Connect(function(child)
			if not slotTracker.hasPlayerData(userId) then return end

			local currentModel = slotTracker.getCurrentModel(userId)
			if child == currentModel then
				print("[ModelChangeDetector] Modelo actual removido, limpiando slots para:", player.Name)

				-- Limpiar todos los slots
				slotTracker.cleanupPurchaseData(userId)
				slotTracker.setCurrentModel(userId, nil)
			end
		end)

		-- Guardar las conexiones
		slotTracker.addModelConnection(userId, addedConnection)
		slotTracker.addModelConnection(userId, removedConnection)
	end

	-- Conectar inicialmente
	connectToCurrentRebirth()

	-- Reconectar cuando cambie la plot
	plotName:GetPropertyChangedSignal("Value"):Connect(function()
		-- Desconectar conexiones anteriores
		slotTracker.clearModelConnections(userId)

		-- Conectar a la nueva plot
		connectToCurrentRebirth()
	end)

	print("[ModelChangeDetector] Sistema de detección iniciado para slots:", player.Name)
end

--------------------------------------------------------------
-- DETECCIÓN GENÉRICA
--------------------------------------------------------------

-- Configura una detección genérica de cambios de modelo
function ModelChangeDetector.setup(player, onModelAdded, onModelRemoved, onPlotChanged)
	local plotName = player:FindFirstChild("CurrentPlot")
	if not plotName or not plotName:IsA("StringValue") then return end

	local currentModel = nil
	local connections = {}

	local function cleanup()
		for _, connection in ipairs(connections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		connections = {}
	end

	local function connectToCurrentRebirth()
		cleanup()

		if plotName.Value == "" then return end

		local plotModel = plotsFolder:FindFirstChild(plotName.Value)
		if not plotModel then return end

		local baseFolder = plotModel:FindFirstChild("Base")
		if not baseFolder then return end

		local currentRebirthFolder = baseFolder:FindFirstChild("CurrentRebirth")
		if not currentRebirthFolder then return end

		-- Conectar ChildAdded
		local addedConnection = currentRebirthFolder.ChildAdded:Connect(function(child)
			if child.Name ~= "Position" and child:IsA("Model") then
				if child ~= currentModel then
					print("[ModelChangeDetector] Nuevo modelo detectado para:", player.Name)
					currentModel = child

					if onModelAdded then
						onModelAdded(player, child)
					end
				end
			end
		end)

		-- Conectar ChildRemoved
		local removedConnection = currentRebirthFolder.ChildRemoved:Connect(function(child)
			if child == currentModel then
				print("[ModelChangeDetector] Modelo actual removido para:", player.Name)

				if onModelRemoved then
					onModelRemoved(player)
				end

				currentModel = nil
			end
		end)

		table.insert(connections, addedConnection)
		table.insert(connections, removedConnection)
	end

	-- Conectar inicialmente
	connectToCurrentRebirth()

	-- Reconectar cuando cambie la plot
	local plotConnection = plotName:GetPropertyChangedSignal("Value"):Connect(function()
		connectToCurrentRebirth()

		if onPlotChanged then
			onPlotChanged(player)
		end
	end)

	table.insert(connections, plotConnection)

	-- Retornar función de limpieza
	return function()
		cleanup()
	end
end

return ModelChangeDetector
