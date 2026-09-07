# Cómo configurar reglas de capas en KoolDots (`user_layer_rules.lua`)

En **KoolDots (2026)** con el flujo de configuración en Lua, todas las reglas personales aplicadas a superficies de capas (*layer surfaces* como Waybar, menús de inicio Rofi/Wofi, paneles de notificaciones y diálogos OSD) se administran en:

```
~/.config/hypr/UserConfigs/user_layer_rules.lua
```

Esta guía explica cómo funcionan las reglas de capas en Hyprland Lua, cómo inspeccionar las superficies activas y ofrece ejemplos prácticos para los componentes de interfaz más comunes.

---

## 1. Descripción general y arquitectura

### Ventanas vs. Capas en Hyprland

- **Ventanas estándar**: Se gestionan mediante `user_window_rules.lua` (ventanas de aplicaciones cliente en mosaico o flotantes).
- **Superficies de capa (*Layers*)**: Paneles de escritorio, pantallas de bloqueo, centros de notificaciones y lanzadores que se renderizan en capas específicas del compositor (`background`, `bottom`, `top`, `overlay`).
- **Reglas de capas del usuario (`~/.config/hypr/UserConfigs/user_layer_rules.lua`)**:
  Aplica efectos visuales personalizados (como desenfoque de fondo *blur*, forzado de opacidad o filtrado de transparencia) a dichas superficies.

### La función auxiliar `apply_layer_rule()`

Las reglas de capas se definen mediante la función `apply_layer_rule()`:

```lua
apply_layer_rule({
  name = "identificador-unico-de-regla",
  match = {
    namespace = "patron_regex_o_exacto",
  },
  blur = true,
  ignore_alpha = 0.2,
})
```

---

## 2. Identificar el espacio de nombres (*namespace*) de una capa

Para inspeccionar todas las superficies de capa activas y obtener su `namespace`:

```bash
hyprctl layers
```

Salida de ejemplo:
```
levels:
  top:
    (waybar): namespace: waybar
    (swaync-control-center): namespace: swaync-control-center
  overlay:
    (rofi): namespace: rofi
```

El texto después de `namespace:` corresponde al valor que debe colocarse en `match = { namespace = "..." }`.

---

## 3. Propiedades admitidas

| Propiedad | Tipo | Descripción |
|---|---|---|
| `name` | string | Nombre o identificador único para la regla |
| `match.namespace` | string | Expresión regular o nombre exacto del namespace (ej. `"rofi"`, `"waybar"`, `"swaync.*"`) |
| `blur` | boolean | Habilita el desenfoque de fondo detrás de la superficie de la capa |
| `ignore_alpha` | number | Omite el desenfoque en píxeles con transparencia inferior al umbral (`0.0` a `1.0`) |
| `no_anim` | boolean | Desactiva las animaciones de apertura y cierre para esta capa |
| `order` | number | Prioridad de orden opcional |

---

## 4. Instrucciones paso a paso

### Paso 1: Abrir `user_layer_rules.lua`
Abra el archivo en su editor preferido:

```bash
nano ~/.config/hypr/UserConfigs/user_layer_rules.lua
# o
nvim ~/.config/hypr/UserConfigs/user_layer_rules.lua
```

### Paso 2: Agregar las reglas de capa
Defina sus reglas mediante `apply_layer_rule({...})`.

### Paso 3: Guardar y recargar
Recargue Hyprland inmediatamente:

```bash
hyprctl reload
```
*(o presione `SUPER + ALT + R`).*

---

## 5. Ejemplos prácticos

### Ejemplo A: Desenfoque (*blur*) en Rofi / Lanzador de aplicaciones

```lua
apply_layer_rule({
  name = "user-rofi-blur",
  match = { namespace = "rofi" },
  blur = true,
  ignore_alpha = 0.2,
})
```

### Ejemplo B: Desenfoque en la barra superior Waybar

```lua
apply_layer_rule({
  name = "user-waybar-blur",
  match = { namespace = "waybar" },
  blur = true,
  ignore_alpha = 0.1,
})
```

### Ejemplo C: Desenfoque en centro de notificaciones y popups de SwayNC

```lua
apply_layer_rule({
  name = "user-swaync-control-center-blur",
  match = { namespace = "swaync-control-center" },
  blur = true,
  ignore_alpha = 0.2,
})

apply_layer_rule({
  name = "user-swaync-notification-blur",
  match = { namespace = "swaync-notification-window" },
  blur = true,
  ignore_alpha = 0.2,
})
```

### Ejemplo D: Desactivar animaciones en popups OSD / notificaciones

```lua
apply_layer_rule({
  name = "user-dunst-noanim",
  match = { namespace = "dunst" },
  no_anim = true,
})
```

---

## 6. Solución de problemas

1. **El desenfoque no se aplica a la capa**:
   Compruebe que `decoration.blur.enabled = true` en `user_decorations.lua` (o en los ajustes del sistema) y verifique con `hyprctl layers` que el `namespace` sea exacto.
2. **Los bordes transparentes se ven oscuros o con artefactos**:
   Ajuste `ignore_alpha` (por ejemplo de `0.1` a `0.3`) para evitar desenfocar transparencias casi imperceptibles.
3. **Validación de sintaxis**:
   ```bash
   luac -p ~/.config/hypr/UserConfigs/user_layer_rules.lua
   ```
