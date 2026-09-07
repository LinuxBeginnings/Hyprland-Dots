# Cómo configurar decoraciones de ventana en KoolDots (`user_decorations.lua`)

En **KoolDots (2026)** con el flujo de configuración en Lua, todo el estilo estético de las ventanas (bordes, espaciado/gaps, redondeo de esquinas, opacidad, desenfoque/blur, sombras y diseño de pestañas agrupadas) se administra en:

```
~/.config/hypr/UserConfigs/user_decorations.lua
```

Esta guía explica cómo funcionan las personalizaciones de decoración en Hyprland Lua, las opciones disponibles en `general`, `decoration` y `group`, y ofrece ejemplos prácticos para personalizar el entorno visual.

---

## 1. Descripción general y arquitectura

### Decoraciones del sistema vs. Decoraciones del usuario

- **Temas del sistema (`~/.config/hypr/lua/user_decorations_helper.lua`, temas y menú de ajustes rápidos)**:
  Los temas y herramientas dinámicas como `wallust` calculan los colores de los bordes, sombras y márgenes estándar.
- **Decoraciones del usuario (`~/.config/hypr/UserConfigs/user_decorations.lua`)**:
  Permite anular cualquier configuración estética predeterminada (por ejemplo, definir márgenes más grandes, desactivar el desenfoque para optimizar el rendimiento o fijar opacidades personalizadas). Los cambios se conservan tras las actualizaciones.

### Sintaxis de `hl.config()`

Las decoraciones se definen usando la función `hl.config({...})`:

```lua
hl.config({
  general = {
    border_size = 2,
    gaps_in = 6,
    gaps_out = 10,
  },
  decoration = {
    rounding = 12,
    active_opacity = 1.0,
    inactive_opacity = 0.90,
    blur = {
      enabled = true,
      size = 6,
      passes = 3,
    },
    shadow = {
      enabled = true,
      range = 4,
    },
  },
})
```

---

## 2. Opciones de configuración admitidas

### Opciones de `general`

| Opción | Tipo | Descripción |
|---|---|---|
| `border_size` | number | Grosor del borde de las ventanas en píxeles |
| `gaps_in` | number | Separación interna entre ventanas adyacentes en píxeles |
| `gaps_out` | number | Separación externa entre las ventanas y los bordes de la pantalla |

### Opciones de `decoration`

| Opción | Tipo | Descripción |
|---|---|---|
| `rounding` | number | Radio de redondeo de esquinas en píxeles |
| `active_opacity` | number | Opacidad de la ventana enfocada actualmente (`0.0` - `1.0`) |
| `inactive_opacity` | number | Opacidad de las ventanas sin foco (`0.0` - `1.0`) |
| `fullscreen_opacity` | number | Opacidad de ventanas a pantalla completa |
| `dim_inactive` | boolean | Atenuar ventanas sin foco |
| `dim_strength` | number | Nivel de atenuación (`0.0` a `1.0`) |
| `dim_special` | number | Nivel de atenuación de fondo al abrir el espacio especial (*scratchpad*) |

### Opciones de `decoration.shadow`

| Opción | Tipo | Descripción |
|---|---|---|
| `enabled` | boolean | Habilita sombras proyectadas en las ventanas |
| `range` | number | Tamaño y difusión de la sombra en píxeles |
| `render_power` | number | Potencia de renderizado y degradado de la sombra (`1` - `4`) |
| `color` | string | Cadena de color RGBA (ej. `"rgba(00000088)"`) |
| `color_inactive` | string | Color de sombra para ventanas inactivas |

### Opciones de `decoration.blur`

| Opción | Tipo | Descripción |
|---|---|---|
| `enabled` | boolean | Habilita el efecto de desenfoque para superficies translúcidas |
| `size` | number | Radio del algoritmo de desenfoque |
| `passes` | number | Número de pasadas de desenfoque (mayor = más suave, mayor uso de GPU) |
| `new_optimizations` | boolean | Habilita optimizaciones internas de desenfoque en Hyprland |
| `xray` | boolean | Ventanas flotantes desenfocan directamente el fondo a través de ventanas en mosaico |
| `ignore_opacity` | boolean | Desenfoca el fondo independientemente de la opacidad base |
| `popups` | boolean | Aplica desenfoque a menús contextuales y ventanas emergentes |

---

## 3. Instrucciones paso a paso

### Paso 1: Abrir `user_decorations.lua`
Abra el archivo en su editor favorito:

```bash
nano ~/.config/hypr/UserConfigs/user_decorations.lua
# o
nvim ~/.config/hypr/UserConfigs/user_decorations.lua
```

### Paso 2: Agregar o descomentar bloques de configuración
Añada las tablas dentro de `hl.config({...})` con las propiedades requeridas.

### Paso 3: Guardar y recargar
Aplique los cambios estéticos inmediatamente:

```bash
hyprctl reload
```
*(o presione `SUPER + ALT + R`).*

---

## 4. Ejemplos prácticos

### Ejemplo A: Estilo minimalista plano (Sin separaciones, bordes finos)

```lua
hl.config({
  general = {
    border_size = 1,
    gaps_in = 0,
    gaps_out = 0,
  },
  decoration = {
    rounding = 0,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    dim_inactive = false,
    shadow = {
      enabled = false,
    },
    blur = {
      enabled = false,
    },
  },
})
```

### Ejemplo B: Estilo de cristal esmerilado (Glass / Blur translúcido)

```lua
hl.config({
  general = {
    border_size = 2,
    gaps_in = 6,
    gaps_out = 12,
  },
  decoration = {
    rounding = 14,
    active_opacity = 0.94,
    inactive_opacity = 0.82,
    dim_inactive = true,
    dim_strength = 0.1,
    blur = {
      enabled = true,
      size = 8,
      passes = 4,
      new_optimizations = true,
      ignore_opacity = true,
      popups = true,
    },
    shadow = {
      enabled = true,
      range = 10,
      render_power = 3,
      color = "rgba(00000066)",
    },
  },
})
```

### Ejemplo C: Perfil de bajo consumo y ahorro de batería

Desactiva el desenfoque y las sombras pesadas en tarjetas gráficas integradas o portátiles antiguos:

```lua
hl.config({
  decoration = {
    rounding = 8,
    active_opacity = 1.0,
    inactive_opacity = 0.98,
    dim_inactive = false,
    shadow = {
      enabled = false,
    },
    blur = {
      enabled = false,
    },
  },
})
```

---

## 5. Solución de problemas

1. **El desenfoque no es visible**:
   Verifique que `decoration.blur.enabled = true` y que la opacidad de la ventana sea inferior a `1.0` o `ignore_opacity = true`.
2. **Caídas de FPS en GPUs de bajo rendimiento**:
   Reduzca `decoration.blur.passes` a `1` o `2`, o establezca `decoration.blur.enabled = false`.
3. **Validar la sintaxis**:
   ```bash
   luac -p ~/.config/hypr/UserConfigs/user_decorations.lua
   ```
