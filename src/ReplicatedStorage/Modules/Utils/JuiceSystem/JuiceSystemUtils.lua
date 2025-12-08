--[[
	JuiceSystemUtils.lua
	Módulo de utilidades generales para el sistema de jugos
	Contiene funciones helper compartidas entre sistemas
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local JuiceSystemUtils = {}

--------------------------------------------------------------
-- CONSTANTES
--------------------------------------------------------------
local SUFFIXES = {"", "k", "m", "b", "t", "q", "Q", "s", "S", "o", "n", "d"}
local plotsFolder = Workspace:WaitForChild("Plots")

--------------------------------------------------------------
-- FORMATEO DE NÚMEROS
--------------------------------------------------------------

-- Formatea números con sufijos (k, m, b, etc.)
function JuiceSystemUtils.formatNumberWithSuffixes(num)
	local index = 1
	while num >= 1000 and index < #SUFFIXES do
		num = num / 1000
		index = index + 1
	end
	local formatted = string.format("%.1f", num)
	if formatted:sub(-2) == ".0" then
		formatted = formatted:sub(1, -3)
	end
	return "$" .. formatted .. SUFFIXES[index]
end

-- Formatea números con comas
function JuiceSystemUtils.formatNumberWithCommas(num)
	local formatted = tostring(math.floor(math.abs(num)))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then break end
	end
	return "$" .. formatted
end

--------------------------------------------------------------
-- GESTIÓN DE PLOTS Y MODELOS
--------------------------------------------------------------

-- Obtiene el jugador dueño de una plot
function JuiceSystemUtils.getPlotOwner(plotName)
	while not _G.GetPlotOwner do
		RunService.Heartbeat:Wait()
	end
	return _G.GetPlotOwner(plotName)
end

-- Busca el modelo clonado actual en una plot
function JuiceSystemUtils.findClonedModel(player)
	local plotName = player:FindFirstChild("CurrentPlot")
	if not plotName or plotName.Value == "" then return nil end

	local plotModel = plotsFolder:FindFirstChild(plotName.Value)
	if not plotModel then return nil end

	local baseFolder = plotModel:FindFirstChild("Base")
	if not baseFolder then return nil end

	local currentRebirthFolder = baseFolder:FindFirstChild("CurrentRebirth")
	if not currentRebirthFolder then return nil end

	for _, child in ipairs(currentRebirthFolder:GetChildren()) do
		if child.Name ~= "Position" and child:IsA("Model") then
			return child
		end
	end

	return nil
end

-- Busca el modelo clonado por nombre de plot
function JuiceSystemUtils.findClonedModelByPlotName(plotName)
	local plotModel = plotsFolder:FindFirstChild(plotName)
	if not plotModel then return nil end

	local baseFolder = plotModel:FindFirstChild("Base")
	if not baseFolder then return nil end

	local currentRebirthFolder = baseFolder:FindFirstChild("CurrentRebirth")
	if not currentRebirthFolder then return nil end

	for _, child in ipairs(currentRebirthFolder:GetChildren()) do
		if child.Name ~= "Position" and child:IsA("Model") then
			return child
		end
	end

	return nil
end

-- Busca un slot específico en la plot del jugador
function JuiceSystemUtils.findSlotModel(player, slotNumber)
	local clonedModel = JuiceSystemUtils.findClonedModel(player)
	if not clonedModel then return nil end

	local slotsFolder = clonedModel:FindFirstChild("Slots")
	if not slotsFolder then return nil end

	local placeFolder = slotsFolder:FindFirstChild("Place")
	if not placeFolder then return nil end

	return placeFolder:FindFirstChild(tostring(slotNumber))
end

-- Busca la CollectZone en la plot del jugador
function JuiceSystemUtils.findCollectZone(player)
	local clonedModel = JuiceSystemUtils.findClonedModel(player)
	if not clonedModel then return nil end

	local slotsFolder = clonedModel:FindFirstChild("Slots")
	if not slotsFolder then return nil end

	return slotsFolder:FindFirstChild("CollectZone")
end

-- Obtiene la carpeta Slots de un modelo clonado
function JuiceSystemUtils.getSlotsFolder(clonedModel)
	if not clonedModel then return nil end
	return clonedModel:FindFirstChild("Slots")
end

--------------------------------------------------------------
-- GESTIÓN DE COOLDOWNS
--------------------------------------------------------------

local cooldownStorage = {}

-- Verifica si un identificador está en cooldown
function JuiceSystemUtils.isOnCooldown(identifier, cooldownTime)
	local lastTime = cooldownStorage[identifier]
	if not lastTime then return false end

	local currentTime = tick()
	return (currentTime - lastTime) < cooldownTime
end

-- Actualiza el cooldown de un identificador
function JuiceSystemUtils.updateCooldown(identifier)
	cooldownStorage[identifier] = tick()
end

-- Limpia el cooldown de un identificador
function JuiceSystemUtils.clearCooldown(identifier)
	cooldownStorage[identifier] = nil
end

-- Limpia todos los cooldowns de un jugador
function JuiceSystemUtils.clearPlayerCooldowns(player)
	local userId = player.UserId
	for key in pairs(cooldownStorage) do
		if type(key) == "string" and key:find("^" .. userId .. "_") then
			cooldownStorage[key] = nil
		end
	end
end

--------------------------------------------------------------
-- UTILIDADES DE VERIFICACIÓN
--------------------------------------------------------------

-- Verifica si existe una tool en un slot específico
function JuiceSystemUtils.toolExistsInSlot(player, slotNumber)
	local slotModel = JuiceSystemUtils.findSlotModel(player, slotNumber)
	if not slotModel then return false end

	for _, child in ipairs(slotModel:GetChildren()) do
		if child:IsA("Tool") then
			local typeValue = child:FindFirstChild("Type")
			if typeValue and typeValue:IsA("StringValue") and typeValue.Value == "Juice" then
				return true
			end
		end
	end

	return false
end

-- Obtiene el juice folder de un slot específico
function JuiceSystemUtils.getJuiceFolderInSlot(player, slotNumber)
	local placedJuices = player:FindFirstChild("PlacedJuices")
	if not placedJuices then return nil end

	for _, juiceFolder in ipairs(placedJuices:GetChildren()) do
		if juiceFolder:IsA("Folder") then
			local slotValue = juiceFolder:FindFirstChild("Slot")
			if slotValue and slotValue:IsA("IntValue") and slotValue.Value == slotNumber then
				return juiceFolder
			end
		end
	end

	return nil
end

--------------------------------------------------------------
-- UTILIDADES DE LIMPIEZA
--------------------------------------------------------------

-- Desconecta una conexión de forma segura
function JuiceSystemUtils.safeDisconnect(connection)
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
	end
end

-- Destruye un objeto de forma segura
function JuiceSystemUtils.safeDestroy(object)
	if object and object.Parent then
		pcall(function()
			object:Destroy()
		end)
	end
end

return JuiceSystemUtils
