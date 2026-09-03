# Cómo configurar reglas de ventana en KoolDots (`user_window_rules.lua`)

En **KoolDots (2026)** con el flujo de configuración en Lua, todas las reglas de ventana personales (comportamiento flotante, tamaños personalizados, posiciones, opacidades, etiquetas y asignaciones a espacios de trabajo) se administran en:

```
~/.config/hypr/UserConfigs/user_window_rules.lua
```

Esta guía explica cómo funcionan las reglas de ventana en la arquitectura Lua, cómo encontrar las propiedades de una ventana (`class`, `title`) y proporciona ejemplos prácticos para las situaciones más comunes.

---

## 1. Descripción general y arquitectura

### Reglas de ventana del sistema vs. Reglas del usuario

- **Reglas del sistema (`~/.config/hypr/configs/system_window_rules.lua` y `lua/window_rules.lua`)**:  
  Proporciona el estilo predeterminado, definiciones de cuadros de diálogo flotantes, etiquetas y reglas para aplicaciones esenciales en toda la configuración de KoolDots.
- **Reglas del usuario (`~/.config/hypr/UserConfigs/user_window_rules.lua`)**:  
  Reservado exclusivamente para sus reglas de aplicación personalizadas y modificaciones. Los cambios aquí se conservan durante las actualizaciones estándar de dotfiles.

### El asistente `apply_window_rule`

Las reglas de ventana de usuario se registran mediante el asistente basado en tablas `apply_window_rule()`:

```lua
apply_window_rule({
  name = "nombre-unico-de-regla",
  match = {
    class = "patron_regex",
    title = "patron_regex",
  },
  float = true,
  center = true,
})
```

---

## 2. Cómo encontrar la clase (`class`) y el título (`title`) de una ventana

Para aplicar reglas con precisión, necesita la `class` o el `title` exactos reportados por Hyprland.

### Método A: Inspeccionar la ventana activa
Enfoque la aplicación deseada y ejecute en una terminal:

```bash
hyprctl activewindow
```

Busque los campos `class:` y `title:`, por ejemplo:
```
class: pavucontrol
title: Volume Control
initialClass: pavucontrol
initialTitle: Volume Control
```

### Método B: Listar todas las ventanas abiertas
Para ver todas las ventanas abiertas en formato JSON:

```bash
hyprctl clients -j | jq '.[] | {class: .class, title: .title, workspace: .workspace.name}'
```

---

## 3. Propiedades y sintaxis admitidas

Una definición de regla acepta criterios de coincidencia (*match*) y atributos de acción:

| Propiedad de coincidencia | Tipo | Descripción |
|---|---|---|
| `class` | string (regex) | Coincide con el WM_CLASS de la ventana (ej. `^([Ff]irefox)$`) |
| `title` | string (regex) | Coincide con el título actual de la ventana (ej. `^[Pp]icture-in-[Pp]icture$`) |
| `initial_class` | string (regex) | Coincide con la clase asignada al crearse la ventana |
| `initial_title` | string (regex) | Coincide con el título asignado al crearse la ventana |
| `tag` | string | Coincide con ventanas que tienen una etiqueta específica (ej. `browser`, `terminal`) |
| `fullscreen` | boolean / number | Coincide con el estado de pantalla completa (`true`, `0`, `1`) |

| Propiedad de acción | Tipo | Ejemplo / Valores |
|---|---|---|
| `float` | boolean | `float = true` |
| `center` | boolean | `center = true` |
| `size` | string | `size = "800 600"` o `size = "(monitor_w*0.6) (monitor_h*0.6)"` |
| `move` | string | `move = "100 100"` o `move = "72% 7%"` |
| `workspace` | string | `workspace = "3"` o `workspace = "special:scratchpad"` |
| `opacity` | number / string | `opacity = 0.95` o `opacity = "0.90 0.80"` (activa / inactiva) |
| `pin` | boolean | `pin = true` (visible en todos los espacios de trabajo) |
| `tag` | string | `tag = "+mitag"` |
| `idle_inhibit` | string | `"fullscreen"`, `"always"`, `"focus"` |
| `no_blur` | boolean | `no_blur = true` (desactiva el desenfoque de fondo para la ventana) |
| `no_initial_focus` | boolean | `no_initial_focus = true` (evita que robe el foco al abrirse) |
| `keep_aspect_ratio` | boolean | `keep_aspect_ratio = true` |

---

## 4. Ejemplos paso a paso

### A. Hacer flotar y centrar cuadros de diálogo de utilidades

```lua
apply_window_rule({
  name = "user-float-audio-control",
  match = {
    class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.5) (monitor_h*0.55)",
})

apply_window_rule({
  name = "user-float-bluetooth",
  match = {
    class = "^(blueman-manager)$",
  },
  float = true,
  center = true,
  size = "600 500",
})
```

### B. Anclar video Picture-in-Picture en una esquina

```lua
apply_window_rule({
  name = "user-pip-video",
  match = {
    title = "^[Pp]icture-in-[Pp]icture$",
  },
  float = true,
  pin = true,
  move = "72% 7%",
  size = "(monitor_w*0.25) (monitor_h*0.25)",
  keep_aspect_ratio = true,
})
```

### C. Asignar aplicaciones a espacios de trabajo específicos

```lua
-- Asignar Spotify al espacio de trabajo 9
apply_window_rule({
  name = "user-spotify-ws",
  match = {
    class = "^([Ss]potify)$",
  },
  workspace = "9",
})

-- Asignar Discord al espacio de trabajo 10
apply_window_rule({
  name = "user-discord-ws",
  match = {
    class = "^([Dd]iscord|[Ww]ebCord|[Vv]esktop)$",
  },
  workspace = "10",
})
```

### D. Transparencia / Opacidad personalizada de ventanas

Puede indicar un solo valor de opacidad o dos valores (`"activa inactiva"`):

```lua
apply_window_rule({
  name = "user-terminal-opacity",
  match = {
    class = "^(kitty|ghostty|Alacritty)$",
  },
  opacity = "0.90 0.80",
})
```

### E. Evitar que una aplicación robe el foco al iniciarse

Útil para aplicaciones de mensajería en segundo plano o entornos de desarrollo pesados:

```lua
apply_window_rule({
  name = "user-no-focus-slack",
  match = {
    class = "^(Slack|slack)$",
  },
  no_initial_focus = true,
})
```

### F. Inhibir la suspensión / reposo de pantalla durante videos a pantalla completa

```lua
apply_window_rule({
  name = "user-inhibit-idle-video",
  match = {
    class = "^(mpv|vlc)$",
  },
  idle_inhibit = "focus",
})
```

---

## 5. Aplicar cambios y solución de problemas

1. **Recargar la configuración**:  
   Tras guardar los cambios en `user_window_rules.lua`, recargue Hyprland:
   ```bash
   hyprctl reload
   ```

2. **Comprobar la sintaxis de Lua**:  
   Asegúrese de que no haya errores de sintaxis en Lua antes de recargar:
   ```bash
   luac -p ~/.config/hypr/UserConfigs/user_window_rules.lua
   ```

3. **Verificar las reglas activas**:  
   Para comprobar qué reglas reconoce Hyprland actualmente:
   ```bash
   hyprctl rules
   ```
