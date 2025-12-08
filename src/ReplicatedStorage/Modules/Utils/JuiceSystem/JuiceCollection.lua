--[[
	JuiceCollection.lua
	Módulo para gestión de colección de dinero de jugos
	Maneja eventos de colección, efectos visuales y gestión de dinero offline
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local JuiceCollection = {}

--------------------------------------------------------------
-- REFERENCIAS
--------------------------------------------------------------
local moneyVFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("Money")
local JuiceDataStore = DataStoreService:GetDataStore("JuiceOfflineData")

--------------------------------------------------------------
-- CONSTANTES
--------------------------------------------------------------
local COLLECTION_COOLDOWN = 1  -- Cooldown entre colecciones en segundos

--------------------------------------------------------------
-- EFECTOS VISUALES Y SONIDO
--------------------------------------------------------------

-- Reproduce el efecto de dinero colectado
function JuiceCollection.playMoneyEffect(collectPart)
	-- Clonar el VFX de dinero
	local moneyEffect = moneyVFX:Clone()
	moneyEffect.CFrame = collectPart.CFrame
	moneyEffect.Parent = collectPart

	-- Buscar y reproducir el sonido
	local cashSound = moneyEffect:FindFirstChild("Cash")
	if cashSound and cashSound:IsA("Sound") then
		cashSound:Play()
	end

	-- Activar todas las partículas
	for _, child in ipairs(moneyEffect:GetDescendants()) do
		if child:IsA("ParticleEmitter") then
			child.Enabled = true
		end
	end

	-- Desactivar después de 0.2 segundos
	task.delay(0.2, function()
		if moneyEffect and moneyEffect.Parent then
			for _, child in ipairs(moneyEffect:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					child.Enabled = false
				end
			end
		end
	end)

	-- Destruir después de 1.5 segundos
	task.delay(1.5, function()
		if moneyEffect and moneyEffect.Parent then
			moneyEffect:Destroy()
		end
	end)
end

--------------------------------------------------------------
-- COLECCIÓN DE DINERO DE SLOTS INDIVIDUALES
--------------------------------------------------------------

-- Conecta el evento de colección para un slot específico
function JuiceCollection.connectSlotCollection(player, slotNumber, collectPart, slotTracker)
	local userId = player.UserId

	local connection = collectPart.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local touchingPlayer = Players:GetPlayerFromCharacter(character)
		if not touchingPlayer or touchingPlayer ~= player then return end

		-- Verificar cooldown
		if slotTracker.isOnCooldown(userId, slotNumber, COLLECTION_COOLDOWN) then
			return
		end

		-- Buscar el juice en PlacedJuices
		local placedJuices = player:FindFirstChild("PlacedJuices")
		if not placedJuices then return end

		local juiceFolder = nil
		for _, folder in ipairs(placedJuices:GetChildren()) do
			local slotValue = folder:FindFirstChild("Slot")
			if slotValue and slotValue:IsA("IntValue") and slotValue.Value == slotNumber then
				juiceFolder = folder
				break
			end
		end

		if not juiceFolder then return end

		-- Obtener MoneyGenerated
		local moneyGenerated = juiceFolder:FindFirstChild("MoneyGenerated")
		if not moneyGenerated or not moneyGenerated:IsA("IntValue") then return end

		-- Si no hay dinero generado, no hacer nada
		if moneyGenerated.Value <= 0 then return end

		-- Obtener MoneyMultiplier del jugador
		local multiplierValue = JuiceCollection.getPlayerMoneyMultiplier(player)

		-- Multiplicar el dinero generado
		local finalMoney = moneyGenerated.Value * multiplierValue

		-- Sumar a Data.Money
		if JuiceCollection.addMoneyToPlayer(player, finalMoney) then
			print("[JuiceCollection] Dinero colectado:", finalMoney, "(", moneyGenerated.Value, "x", multiplierValue, ") del slot:", slotNumber)

			-- Reproducir efecto
			JuiceCollection.playMoneyEffect(collectPart)

			-- Resetear MoneyGenerated
			moneyGenerated.Value = 0

			-- Actualizar cooldown
			slotTracker.setCooldown(userId, slotNumber, tick())
		end
	end)

	return connection
end

--------------------------------------------------------------
-- COLECCIÓN DE DINERO DE COLLECTZONE
--------------------------------------------------------------

-- Conecta el evento de colección para la CollectZone
function JuiceCollection.connectCollectZoneCollection(player, collectPart, slotTracker)
	local userId = player.UserId

	local connection = collectPart.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local touchingPlayer = Players:GetPlayerFromCharacter(character)
		if not touchingPlayer or touchingPlayer ~= player then return end

		-- Verificar cooldown
		if slotTracker.isOnCooldown(userId, "collectzone", COLLECTION_COOLDOWN) then
			return
		end

		-- Calcular dinero total de todos los jugos
		local placedJuices = player:FindFirstChild("PlacedJuices")
		if not placedJuices then return end

		local totalMoneyGenerated = 0
		local juiceFolders = {}

		for _, juiceFolder in ipairs(placedJuices:GetChildren()) do
			if juiceFolder:IsA("Folder") then
				local moneyGenerated = juiceFolder:FindFirstChild("MoneyGenerated")
				if moneyGenerated and moneyGenerated:IsA("IntValue") and moneyGenerated.Value > 0 then
					totalMoneyGenerated = totalMoneyGenerated + moneyGenerated.Value
					table.insert(juiceFolders, juiceFolder)
				end
			end
		end

		-- Si no hay dinero generado, no hacer nada
		if totalMoneyGenerated <= 0 then return end

		-- Obtener MoneyMultiplier del jugador
		local multiplierValue = JuiceCollection.getPlayerMoneyMultiplier(player)

		-- Multiplicar el dinero total
		local finalMoney = totalMoneyGenerated * multiplierValue

		-- Sumar a Data.Money
		if JuiceCollection.addMoneyToPlayer(player, finalMoney) then
			print("[JuiceCollection] Dinero colectado en CollectZone:", finalMoney, "(", totalMoneyGenerated, "x", multiplierValue, ")")

			-- Reproducir efecto
			JuiceCollection.playMoneyEffect(collectPart)

			-- Resetear MoneyGenerated de todos los jugos
			for _, juiceFolder in ipairs(juiceFolders) do
				local moneyGenerated = juiceFolder:FindFirstChild("MoneyGenerated")
				if moneyGenerated and moneyGenerated:IsA("IntValue") then
					moneyGenerated.Value = 0
				end
			end

			-- Actualizar cooldown
			slotTracker.setCooldown(userId, "collectzone", tick())
		end
	end)

	return connection
end

--------------------------------------------------------------
-- GESTIÓN DE DINERO DEL JUGADOR
--------------------------------------------------------------

-- Obtiene el multiplicador de dinero del jugador
function JuiceCollection.getPlayerMoneyMultiplier(player)
	local dataFolder = player:FindFirstChild("Data")
	if not dataFolder then return 1 end

	local moneyMultiplier = dataFolder:FindFirstChild("MoneyMultiplier")
	if moneyMultiplier and moneyMultiplier:IsA("IntValue") then
		return moneyMultiplier.Value
	end

	return 1
end

-- Añade dinero al jugador
function JuiceCollection.addMoneyToPlayer(player, amount)
	local dataFolder = player:FindFirstChild("Data")
	if not dataFolder then return false end

	local moneyValue = dataFolder:FindFirstChild("Money")
	if not moneyValue or not moneyValue:IsA("IntValue") then return false end

	moneyValue.Value = moneyValue.Value + amount
	return true
end

--------------------------------------------------------------
-- ACTUALIZACIÓN DE GUI DE COLLECTZONE
--------------------------------------------------------------

-- Actualiza la GUI de la CollectZone con información de dinero
function JuiceCollection.updateCollectZoneGui(player, collectZone, formatNumberFunc)
	local basePart = collectZone:FindFirstChild("Base")
	if not basePart or not basePart:IsA("BasePart") then return end

	local slotGui = basePart:FindFirstChild("Slot")
	if not slotGui or not slotGui:IsA("BillboardGui") then return end

	local info = slotGui:FindFirstChild("Info")
	if not info then return end

	local pricePerSecLabel = info:FindFirstChild("PricePerSec")
	local multiplierLabel = info:FindFirstChild("Multiplier")

	-- Calcular dinero total generado de todos los jugos
	local totalMoneyGenerated = JuiceCollection.getTotalMoneyGenerated(player)

	-- Actualizar PricePerSec
	if pricePerSecLabel and pricePerSecLabel:IsA("TextLabel") then
		pricePerSecLabel.Text = formatNumberFunc(totalMoneyGenerated)
	end

	-- Actualizar Multiplier
	if multiplierLabel and multiplierLabel:IsA("TextLabel") then
		local moneyMultiplier = JuiceCollection.getPlayerMoneyMultiplier(player)
		multiplierLabel.Text = "MONEY MULTI: X" .. tostring(moneyMultiplier)
	end
end

-- Obtiene el dinero total generado de todos los jugos
function JuiceCollection.getTotalMoneyGenerated(player)
	local placedJuices = player:FindFirstChild("PlacedJuices")
	local totalMoneyGenerated = 0

	if placedJuices then
		for _, juiceFolder in ipairs(placedJuices:GetChildren()) do
			if juiceFolder:IsA("Folder") then
				local moneyGenerated = juiceFolder:FindFirstChild("MoneyGenerated")
				if moneyGenerated and moneyGenerated:IsA("IntValue") then
					totalMoneyGenerated = totalMoneyGenerated + moneyGenerated.Value
				end
			end
		end
	end

	return totalMoneyGenerated
end

--------------------------------------------------------------
-- SISTEMA DE GENERACIÓN DE DINERO
--------------------------------------------------------------

-- Actualiza el dinero generado de todos los jugos de todos los jugadores
function JuiceCollection.updateAllJuicesMoneyGeneration()
	for _, player in ipairs(Players:GetPlayers()) do
		local placedJuices = player:FindFirstChild("PlacedJuices")
		if placedJuices then
			for _, juiceFolder in ipairs(placedJuices:GetChildren()) do
				if juiceFolder:IsA("Folder") then
					local pricePerSecValue = juiceFolder:FindFirstChild("PricePerSec")
					local moneyGeneratedValue = juiceFolder:FindFirstChild("MoneyGenerated")

					if pricePerSecValue and pricePerSecValue:IsA("IntValue") and
						moneyGeneratedValue and moneyGeneratedValue:IsA("IntValue") then
						moneyGeneratedValue.Value = moneyGeneratedValue.Value + pricePerSecValue.Value
					end
				end
			end
		end
	end
end

-- Inicia el sistema de generación automática de dinero
function JuiceCollection.startMoneyGenerationSystem()
	local lastUpdateTime = os.time()

	RunService.Heartbeat:Connect(function()
		local currentTime = os.time()

		-- Solo actualizar cada segundo
		if currentTime > lastUpdateTime then
			lastUpdateTime = currentTime
			JuiceCollection.updateAllJuicesMoneyGeneration()
		end
	end)

	print("[JuiceCollection] Sistema de generación de dinero iniciado")
end

--------------------------------------------------------------
-- GESTIÓN DE DINERO OFFLINE
--------------------------------------------------------------

-- Calcula y añade el dinero generado mientras el jugador estuvo offline
function JuiceCollection.calculateOfflineMoney(player)
	local success, lastDisconnectTime = pcall(function()
		return JuiceDataStore:GetAsync("Player_" .. player.UserId)
	end)

	if not success or not lastDisconnectTime then
		return -- Primera vez o error
	end

	local currentTime = os.time()
	local timeOffline = currentTime - lastDisconnectTime

	-- Solo calcular si estuvo offline más de 1 segundo
	if timeOffline <= 0 then return end

	local placedJuices = player:FindFirstChild("PlacedJuices")
	if not placedJuices then return end

	-- Calcular dinero generado para cada jugo
	for _, juiceFolder in ipairs(placedJuices:GetChildren()) do
		if juiceFolder:IsA("Folder") then
			local pricePerSecValue = juiceFolder:FindFirstChild("PricePerSec")
			local moneyGeneratedValue = juiceFolder:FindFirstChild("MoneyGenerated")

			if pricePerSecValue and pricePerSecValue:IsA("IntValue") and
				moneyGeneratedValue and moneyGeneratedValue:IsA("IntValue") then

				local offlineMoney = pricePerSecValue.Value * timeOffline
				moneyGeneratedValue.Value = moneyGeneratedValue.Value + offlineMoney

				print("[JuiceCollection] Dinero offline calculado para", juiceFolder.Name, ":", offlineMoney)
			end
		end
	end
end

-- Guarda el tiempo de desconexión del jugador
function JuiceCollection.saveDisconnectTime(player)
	local success, err = pcall(function()
		JuiceDataStore:SetAsync("Player_" .. player.UserId, os.time())
	end)

	if not success then
		warn("[JuiceCollection] Error al guardar tiempo de desconexión:", err)
	end
end

return JuiceCollection
