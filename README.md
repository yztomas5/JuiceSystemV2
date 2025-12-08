# Sistema Modular de Jugos - JuiceSystemV2

Sistema modular robusto para gestión de jugos y slots en Roblox. Arquitectura escalable y mantenible con separación de responsabilidades.

## 📁 Estructura del Proyecto

```
src/
├── ReplicatedStorage/
│   └── Modules/
│       └── Utils/
│           └── JuiceSystem/              # Módulos principales del sistema
│               ├── JuiceSystemUtils.lua  # Utilidades generales
│               ├── SlotTracker.lua       # Tracking de slots y datos
│               ├── JuiceVisuals.lua      # Gestión de visuals y GUI
│               ├── JuiceCollection.lua   # Sistema de colección de dinero
│               ├── SlotManager.lua       # Gestión de slots
│               └── ModelChangeDetector.lua # Detector de cambios de modelo
│
└── ServerScriptService/
    ├── PlacedJuicesServer.lua            # Script principal de jugos colocados
    └── SlotPurchaseServer.lua            # Script principal de compra de slots
```

## 🧩 Módulos del Sistema

### 1. **JuiceSystemUtils.lua**
Módulo de utilidades compartidas entre sistemas.

**Funcionalidades:**
- Formateo de números (con sufijos y comas)
- Gestión de plots y modelos clonados
- Sistema de cooldowns centralizado
- Utilidades de verificación y limpieza segura

**Funciones principales:**
```lua
JuiceSystemUtils.formatNumberWithSuffixes(num)
JuiceSystemUtils.formatNumberWithCommas(num)
JuiceSystemUtils.getPlotOwner(plotName)
JuiceSystemUtils.findClonedModel(player)
JuiceSystemUtils.findSlotModel(player, slotNumber)
JuiceSystemUtils.findCollectZone(player)
JuiceSystemUtils.isOnCooldown(identifier, cooldownTime)
JuiceSystemUtils.toolExistsInSlot(player, slotNumber)
```

### 2. **SlotTracker.lua**
Sistema centralizado de tracking para slots y datos de jugadores.

**Funcionalidades:**
- Almacenamiento centralizado de datos de jugadores
- Gestión de slots de jugos y compra
- Tracking de conexiones y eventos
- Sistema de limpieza automática

**Funciones principales:**
```lua
SlotTracker.initializeJuiceData(userId)
SlotTracker.initializePurchaseData(userId)
SlotTracker.getPlayerData(userId)
SlotTracker.setSlotData(userId, slotNumber, data)
SlotTracker.clearSlotData(userId, slotNumber)
SlotTracker.setBuySlotData(userId, slotNumber, data)
SlotTracker.setPlaceSlotData(userId, slotNumber, data)
SlotTracker.removePlayer(userId)
```

### 3. **JuiceVisuals.lua**
Gestión de todos los aspectos visuales de los jugos.

**Funcionalidades:**
- Mezcla de colores de ingredientes
- Aplicación de texturas a jugos
- Configuración de InfoGUI
- Creación de billboards de ingredientes
- Gestión de mutaciones visuales
- Limpieza de visuals de slots

**Funciones principales:**
```lua
JuiceVisuals.mixColors(colors)
JuiceVisuals.getMixedColorFromIngredients(ingredientsFolder)
JuiceVisuals.applyJuiceTextures(tool, color)
JuiceVisuals.setupJuiceInfoGui(tool, juiceName, price, ...)
JuiceVisuals.createIngredientsBillboard(slotModel, ingredientsFolder)
JuiceVisuals.applyMutationsToTool(tool, ingredientsFolder)
JuiceVisuals.cleanupSlotVisuals(placeSlotModel)
```

### 4. **JuiceCollection.lua**
Sistema completo de colección de dinero y generación pasiva.

**Funcionalidades:**
- Efectos visuales y sonido de colección
- Colección individual por slot
- Colección masiva en CollectZone
- Sistema de multiplicadores
- Generación automática de dinero
- Gestión de dinero offline
- Actualización de GUI en tiempo real

**Funciones principales:**
```lua
JuiceCollection.playMoneyEffect(collectPart)
JuiceCollection.connectSlotCollection(player, slotNumber, collectPart, slotTracker)
JuiceCollection.connectCollectZoneCollection(player, collectPart, slotTracker)
JuiceCollection.getPlayerMoneyMultiplier(player)
JuiceCollection.addMoneyToPlayer(player, amount)
JuiceCollection.updateCollectZoneGui(player, collectZone, formatNumberFunc)
JuiceCollection.startMoneyGenerationSystem()
JuiceCollection.calculateOfflineMoney(player)
JuiceCollection.saveDisconnectTime(player)
```

### 5. **SlotManager.lua**
Gestión completa de slots (compra y colocación).

**Funcionalidades:**
- Sistema de compra de slots
- Configuración de buy slots con billboards
- Configuración de place slots con ProximityPrompts
- Colocación y remoción de jugos
- Validación de acciones
- Mensajes de warning

**Funciones principales:**
```lua
SlotManager.handleSlotPurchase(player, slotNumber, ...)
SlotManager.setupBuySlot(buySlotModel, slotNumber, plotName, ...)
SlotManager.setupPlaceSlot(placeSlotModel, slotNumber, plotName, ...)
SlotManager.handlePlaceSlotInteraction(player, slotNumber, ...)
SlotManager.removeJuiceFromSlot(player, juiceFolder, slotNumber, ...)
SlotManager.placeJuiceInSlot(player, slotNumber, ...)
SlotManager.updateAllSlots(player, ...)
```

### 6. **ModelChangeDetector.lua**
Detector de cambios en modelos base de plots.

**Funcionalidades:**
- Detección automática de cambios de modelo
- Callbacks personalizables
- Reconexión automática en cambio de plot
- Soporte para múltiples sistemas
- Limpieza automática de conexiones

**Funciones principales:**
```lua
ModelChangeDetector.setupForJuices(player, slotTracker, onModelAdded, onModelRemoved)
ModelChangeDetector.setupForSlots(player, slotTracker, onModelChanged)
ModelChangeDetector.setup(player, onModelAdded, onModelRemoved, onPlotChanged)
```

## 📜 Scripts del Servidor

### 1. **PlacedJuicesServer.lua**
Script principal para gestión de jugos colocados.

**Responsabilidades:**
- Inicialización del sistema de jugos
- Creación de tools visuales en slots
- Conexión de eventos de colección
- Gestión de CollectZone
- Actualización de GUI en tiempo real
- Detección de cambios de modelo
- Cálculo de dinero offline
- Sistema de generación pasiva

### 2. **SlotPurchaseServer.lua**
Script principal para sistema de compra de slots.

**Responsabilidades:**
- Inicialización del sistema de slots
- Configuración de buy slots
- Configuración de place slots
- Gestión de compras
- Gestión de cooldowns
- Detección de cambios de modelo
- Actualización dinámica de slots

## 🚀 Características del Sistema

### ✅ Modularidad
- Código organizado en módulos especializados
- Fácil mantenimiento y extensibilidad
- Reutilización de código entre sistemas
- Inyección de dependencias

### ✅ Robustez
- Prevención de duplicados
- Validaciones exhaustivas
- Manejo seguro de errores
- Sistema de tokens de cancelación
- Limpieza automática de recursos

### ✅ Escalabilidad
- Arquitectura preparada para crecimiento
- Tracking centralizado de datos
- Sistema de eventos eficiente
- Optimización de recursos

### ✅ Seguridad
- Validación de permisos de plot
- Sistema de cooldowns anti-spam
- Verificación de integridad de datos
- Manejo seguro de desconexiones

## 🔧 Instalación

1. Copia la carpeta `src/ReplicatedStorage/Modules/Utils/JuiceSystem/` a tu `ReplicatedStorage.Modules.Utils.JuiceSystem`

2. Copia los scripts del servidor:
   - `src/ServerScriptService/PlacedJuicesServer.lua` → `ServerScriptService`
   - `src/ServerScriptService/SlotPurchaseServer.lua` → `ServerScriptService`

3. Asegúrate de tener las siguientes dependencias en tu proyecto:
   - `ReplicatedStorage.Modules.Config.IngredientConfig`
   - `ReplicatedStorage.Modules.Config.SlotConfig`
   - `ReplicatedStorage.Modules.Utils.GradientEffects`
   - `ReplicatedStorage.Assets.VFX.Juice`
   - `ReplicatedStorage.Assets.VFX.Money`
   - `ReplicatedStorage.Assets.GUI.Billboards.InfoGui`
   - `ReplicatedStorage.Assets.GUI.Billboards.Slot`
   - `ServerStorage.Inventario.Juices`
   - `ReplicatedStorage.RemoteEvents.Warn.Warning`

4. Configura la función global `_G.GetPlotOwner(plotName)` en tu sistema de plots

## 📊 Flujo de Datos

### Sistema de Jugos Colocados
```
Player joins → Initialize JuiceData → Calculate offline money →
→ Load placed juices → Create visual tools → Connect collection events →
→ Setup CollectZone → Start money generation → Monitor changes
```

### Sistema de Compra de Slots
```
Player joins → Initialize PurchaseData → Monitor player values →
→ Setup buy slots → Setup place slots → Handle interactions →
→ Update on changes → Monitor model changes
```

## 🔄 Ciclo de Vida de un Jugo

1. **Colocación**: Jugador equipa jugo y usa ProximityPrompt en slot
2. **Validación**: Sistema valida permisos e integridad
3. **Creación Visual**: Se crea tool visual con texturas y colores
4. **Generación**: Comienza generación pasiva de dinero
5. **Colección**: Jugador toca Collect part o CollectZone
6. **Remoción**: Jugador remueve jugo, se limpia y vuelve al inventario

## 🎯 Beneficios de la Arquitectura Modular

1. **Mantenibilidad**: Cambios localizados en módulos específicos
2. **Testabilidad**: Módulos independientes fáciles de probar
3. **Reutilización**: Funciones compartibles entre sistemas
4. **Claridad**: Responsabilidades bien definidas
5. **Escalabilidad**: Fácil agregar nuevas funcionalidades
6. **Colaboración**: Múltiples desarrolladores pueden trabajar en paralelo

## 📝 Notas Importantes

- Los módulos usan `WaitForChild` para asegurar que las dependencias estén cargadas
- El sistema incluye protección contra memory leaks con limpieza automática
- Los cooldowns previenen spam y mejoran el rendimiento
- El sistema de tokens previene race conditions en operaciones asíncronas
- El tracking centralizado facilita el debugging y monitoreo

## 🐛 Debug y Logging

El sistema incluye prints informativos en puntos clave:
- `[JuiceSystemUtils]` - Utilidades generales
- `[SlotTracker]` - Tracking de datos
- `[JuiceVisuals]` - Operaciones visuales
- `[JuiceCollection]` - Colección de dinero
- `[SlotManager]` - Gestión de slots
- `[ModelChangeDetector]` - Cambios de modelo
- `[PlacedJuices]` - Sistema de jugos
- `[SlotPurchase]` - Sistema de compra

## 🚧 Requisitos del Sistema

- Roblox Studio con Luau habilitado
- Estructura de plots existente
- Sistema de datos de jugador (Data folder)
- Sistema de inventario
- Assets y GUI templates

## 📈 Rendimiento

El sistema está optimizado para:
- Mínimo uso de memoria con limpieza automática
- Actualización eficiente cada segundo (no cada frame)
- Conexiones desconectadas apropiadamente
- Prevención de operaciones duplicadas
- Uso inteligente de task.wait()

---

**Desarrollado para JuiceSystemV2**
**Arquitectura modular escalable y mantenible**
