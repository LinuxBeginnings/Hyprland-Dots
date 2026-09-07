# Cómo configurar monitores en KoolDots (`monitors.lua`)

En **KoolDots (2026)** con el flujo de configuración en Lua, todas las configuraciones de pantalla y multimonitor se administran en:

```
~/.config/hypr/UserConfigs/monitors.lua
```

Esta guía explica cómo funciona la configuración de pantallas en Hyprland Lua, cómo interactúan los perfiles de monitor con las modificaciones de usuario y ofrece ejemplos prácticos para configuraciones individuales, multimonitor, alta tasa de refresco y escalado.

---

## 1. Descripción general y arquitectura

### Monitores del sistema vs. Monitores del usuario

- **Monitores del sistema (`~/.config/hypr/lua/monitors.lua`)**:
  Proporciona reglas de reserva globales (por ejemplo: `output = "", mode = "preferred", position = "auto", scale = "1"`).
- **Monitores del usuario (`~/.config/hypr/UserConfigs/monitors.lua`)**:
  Contiene las definiciones de monitor personalizadas y persistentes. Cuando se ejecuta el script `MonitorProfiles.sh` o el selector de perfiles, los ajustes se guardan en este archivo. Las llamadas personalizadas a `hl.monitor({...})` agregadas aquí se conservan tras las actualizaciones.

### Sintaxis de la función `hl.monitor()`

Las pantallas se declaran utilizando la función `hl.monitor({...})`:

```lua
hl.monitor({
    output = "eDP-1",        -- Nombre del conector de video (ej. eDP-1, DP-1, HDMI-A-1)
    mode = "1920x1080@144",  -- Resolución y tasa de refresco (o "preferred", "highrr", "highres")
    position = "0x0",        -- Posición relativa "XxY" o "auto"
    scale = "1",             -- Factor de escala (ej. "1", "1.25", "1.5", "2")
    transform = "0",         -- Opcional: Rotación (0: normal, 1: 90°, 2: 180°, 3: 270°)
    bitdepth = "10",         -- Opcional: Profundidad de color (ej. "8", "10")
})
```

---

## 2. Identificar pantallas conectadas

Para obtener los nombres exactos de los conectores, resoluciones admitidas y tasas de refresco de sus pantallas:

```bash
hyprctl monitors all
```

Observe el identificador al inicio de cada bloque (ej. `Monitor DP-1 (ID 0):`, `Monitor eDP-1 (ID 1):`).

---

## 3. Instrucciones paso a paso

### Paso 1: Abrir `monitors.lua`
Abra el archivo en su editor favorito:

```bash
nano ~/.config/hypr/UserConfigs/monitors.lua
# o
nvim ~/.config/hypr/UserConfigs/monitors.lua
```

### Paso 2: Agregar las definiciones de monitor
Añada un bloque `hl.monitor({...})` para cada pantalla.

```lua
-- Pantalla integrada de portátil
hl.monitor({
    output = "eDP-1",
    mode = "preferred",
    position = "0x0",
    scale = "1",
})
```

### Paso 3: Guardar y aplicar los cambios
Recargue Hyprland inmediatamente:

```bash
hyprctl reload
```
*(o presione `SUPER + ALT + R`).*

---

## 4. Ejemplos prácticos

### Ejemplo A: Pantalla de portátil con alta tasa de refresco (144Hz)

```lua
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@144",
    position = "0x0",
    scale = "1",
})
```

### Ejemplo B: Configuración de doble monitor (Portátil + Monitor externo a la derecha)

En este escenario:
- El portátil `eDP-1` es `1920x1080` en la posición `0x0`.
- El monitor externo `DP-1` es `2560x1440` a la derecha en la posición `1920x0`.

```lua
-- Pantalla de portátil (Izquierda)
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60",
    position = "0x0",
    scale = "1",
})

-- Monitor externo (Derecha)
hl.monitor({
    output = "DP-1",
    mode = "2560x1440@144",
    position = "1920x0",
    scale = "1",
})
```

### Ejemplo C: Configuración de doble monitor (Monitor externo arriba del portátil)

- Pantalla de portátil `eDP-1` (`1920x1080`) en `0x1080`.
- Monitor externo `HDMI-A-1` (`1920x1080`) ubicado arriba en `0x0`.

```lua
-- Monitor externo (Arriba)
hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@60",
    position = "0x0",
    scale = "1",
})

-- Pantalla de portátil (Abajo)
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60",
    position = "0x1080",
    scale = "1",
})
```

### Ejemplo D: Monitor 4K HiDPI con escalado fraccional

```lua
hl.monitor({
    output = "DP-2",
    mode = "3840x2160@60",
    position = "0x0",
    scale = "1.5",
})
```

### Ejemplo E: Monitor secundario vertical / rotado

Para rotar un monitor 90 grados en sentido horario (modo vertical):

```lua
hl.monitor({
    output = "DP-1",
    mode = "1920x1080@60",
    position = "1920x0",
    scale = "1",
    transform = "1", -- 1 = 90 grados en sentido horario
})
```

### Ejemplo F: Desactivar una salida de video en desuso

```lua
hl.monitor({
    output = "HDMI-A-1",
    mode = "disable",
})
```

---

## 5. Solución de problemas

1. **Pantalla en negro o resolución incorrecta**:
   Compruebe los modos compatibles con `hyprctl monitors all` y confirme que el valor en `mode` coincida con una resolución y tasa soportadas (ej. `2560x1440@144`).
2. **Las pantallas se superponen o el ratón queda atrapado**:
   Revise las coordenadas de `position`. Si el monitor izquierdo tiene un ancho de 1920, el monitor derecho debe tener una posición X igual o mayor a `1920`.
3. **Comprobar sintaxis de Lua**:
   ```bash
   luac -p ~/.config/hypr/UserConfigs/monitors.lua
   ```
