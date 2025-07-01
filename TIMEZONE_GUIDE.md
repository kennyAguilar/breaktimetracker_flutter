# Sistema de Zonas Horarias - BreakTime Tracker

## Configuración Actual

### Servidor de Base de Datos
- **Ubicación**: São Paulo, Brasil
- **Zona Horaria**: `America/Sao_Paulo` (UTC-3)
- **Horario de Verano**: Sí (octubre a febrero)

### Cliente (Aplicación)
- **Ubicación**: Punta Arenas, Chile
- **Zona Horaria**: `America/Santiago` (UTC-3)
- **Horario de Verano**: Sí (septiembre a abril)

## Funcionamiento

### 1. Entrada de Descanso
```
Usuario registra entrada → 
Obtener hora actual de Punta Arenas → 
Convertir a UTC → 
Guardar en BD
```

### 2. Salida de Descanso
```
Usuario registra salida → 
Obtener hora actual de Punta Arenas → 
Convertir inicio de UTC a Punta Arenas → 
Calcular duración → 
Guardar registro final en BD
```

### 3. Visualización
```
Datos de BD (UTC) → 
Convertir a Punta Arenas → 
Mostrar al usuario
```

## Diferencias Horarias

### Sin Horario de Verano (mayo-agosto)
- **São Paulo**: UTC-3
- **Punta Arenas**: UTC-3
- **Diferencia**: 0 horas

### Con Horario de Verano (septiembre-abril)
- **São Paulo**: UTC-2 (octubre-febrero)
- **Punta Arenas**: UTC-3 (septiembre-abril)
- **Diferencia**: 1 hora (São Paulo adelantado)

## Funciones Principales

### `_getCurrentPuntaArenasTime()`
Obtiene la hora actual de Punta Arenas usando `America/Santiago`.

### `_convertToLocalTime(DateTime utcTime)`
Convierte UTC a hora de Punta Arenas.

### `_convertToUTC(tz.TZDateTime localTime)`
Convierte hora de Punta Arenas a UTC para almacenar en BD.

### `_convertFromSaoPauloToPuntaArenas(DateTime saoPauloTime)`
Convierte hora de São Paulo a Punta Arenas (para casos especiales).

## Consideraciones

1. **Almacenamiento**: Todos los timestamps se guardan en UTC
2. **Visualización**: Siempre se muestra en hora de Punta Arenas
3. **Cálculos**: La duración se calcula usando hora local de Punta Arenas
4. **Compatibilidad**: El sistema funciona independientemente de la zona horaria del servidor

## Ejemplo de Flujo

```
1. Usuario entra a descanso a las 14:30 (Punta Arenas)
2. Se convierte a UTC: 17:30 (asumiendo UTC-3)
3. Se guarda en BD: "2025-06-30T17:30:00Z"
4. Usuario sale a las 15:15 (Punta Arenas)
5. Se convierte inicio UTC a Punta Arenas: 14:30
6. Se calcula duración: 45 minutos
7. Se determina tipo: DESCANSO (< 30 min sería DESCANSO, >= 30 min sería COMIDA)
8. Se guarda registro final en tabla tiempos_descanso
```
