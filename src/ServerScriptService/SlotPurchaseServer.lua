--[[
	SlotPurchaseServer.lua
	Script principal del servidor para sistema de compra de slots
	Sistema modular robusto para manejo de slots con identificación única
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------------------
-- IMPORTAR MÓDULOS DEL SISTEMA
--------------------------------------------------------------
local JuiceSystemPath = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils"):WaitForChild("JuiceSystem")

local JuiceSystemUtils = require(JuiceSystemPath:WaitForChild("JuiceSystemUtils"))
local SlotTracker = require(JuiceSystemPath:WaitForChild("SlotTracker"))
local JuiceVisuals = require(JuiceSystemPath:WaitForChild("JuiceVisuals"))
local SlotManager = require(JuiceSystemPath:WaitForChild("SlotManager"))
local ModelChangeDetector = require(JuiceSystemPath:WaitForChild("ModelChangeDetector"))

--------------------------------------------------------------
-- REFERENCIAS
--------------------------------------------------------------
local warningEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Warn"):WaitForChild("Warning")

--------------------------------------------------------------
-- INYECCIÓN DE DEPENDENCIAS
--------------------------------------------------------------
SlotManager.injectDependencies({
	JuiceVisuals = JuiceVisuals,
	JuiceSystemUtils = JuiceSystemUtils
})

--------------------------------------------------------------
-- GESTIÓN DE COOLDOWNS DE INTERACCIÓN
--------------------------------------------------------------

local CooldownManager = {
	playerCooldowns = {}
}

function CooldownManager.isPlayerOnCooldown(player)
	local lastInteraction = CooldownManager.playerCooldowns[player]
	if not lastInteraction then return false end

	local currentTime = tick()
	return (currentTime - lastInteraction) < 1  -- 1 segundo de cooldown
end

function CooldownManager.updatePlayerCooldown(player)
	CooldownManager.playerCooldowns[player] = tick()
end

function CooldownManager.clearPlayer(player)
	CooldownManager.playerCooldowns[player] = nil
end

--------------------------------------------------------------
-- ACTUALIZACIÓN DE TODOS LOS SLOTS
--------------------------------------------------------------

local function updateAllSlots(player)
	SlotManager.updateAllSlots(
		player,
		SlotTracker,
		warningEvent,
		JuiceSystemUtils.formatNumberWithCommas,
		CooldownManager,
		JuiceSystemUtils
	)
end

--------------------------------------------------------------
-- CONFIGURAR MONITOREO DE SLOTS
--------------------------------------------------------------

local function setupSlotMonitoring(player)
	local userId = player.UserId

	-- Inicializar estructuras de datos
	SlotTracker.initializePurchaseData(userId)

	-- Esperar elementos necesarios
	local currentPlotValue = player:WaitForChild("CurrentPlot", 10)
	if not currentPlotValue or not currentPlotValue:IsA("StringValue") then return end

	local dataFolder = player:WaitForChild("Data", 10)
	if not dataFolder then return end

	local slotsValue = dataFolder:WaitForChild("Slots", 10)
	local rebirthValue = dataFolder:WaitForChild("Rebirth", 10)

	if not slotsValue or not slotsValue:IsA("IntValue") then return end

	-- Configurar detección de cambio de modelo
	ModelChangeDetector.setupForSlots(
		player,
		SlotTracker,
		function(player)
			-- Callback cuando cambia el modelo
			updateAllSlots(player)
		end
	)

	-- Escuchar cambios en CurrentPlot
	currentPlotValue:GetPropertyChangedSignal("Value"):Connect(function()
		updateAllSlots(player)
	end)

	-- Escuchar cambios en Slots (cuando compra un nuevo slot)
	slotsValue:GetPropertyChangedSignal("Value"):Connect(function()
		updateAllSlots(player)
	end)

	-- Escuchar cambios en Rebirth
	if rebirthValue and rebirthValue:IsA("IntValue") then
		rebirthValue:GetPropertyChangedSignal("Value"):Connect(function()
			task.wait(0.2)
			updateAllSlots(player)
		end)
	end

	-- Actualizar inmediatamente si ya tiene plot
	if currentPlotValue.Value ~= "" then
		task.wait(0.5)
		updateAllSlots(player)
	end

	print("[SlotPurchase] Sistema de monitoreo configurado para:", player.Name)
end

--------------------------------------------------------------
-- LIMPIAR AL SALIR
--------------------------------------------------------------

local function onPlayerRemoving(player)
	local userId = player.UserId

	-- Limpiar todos los datos del jugador
	SlotTracker.cleanupPurchaseData(userId)
	CooldownManager.clearPlayer(player)

	print("[SlotPurchase] Jugador desconectado:", player.Name)
end

--------------------------------------------------------------
-- INICIALIZACIÓN
--------------------------------------------------------------

-- Configurar jugadores
Players.PlayerAdded:Connect(setupSlotMonitoring)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Configurar jugadores que ya están en el servidor
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		setupSlotMonitoring(player)
	end)
end

print("[SlotPurchase] Sistema de compra de slots iniciado")
