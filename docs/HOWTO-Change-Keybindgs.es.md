# Cómo cambiar y personalizar atajos de teclado en KoolDots (`user_keybinds.lua`)

En **KoolDots (2026)** con la arquitectura de configuración en Lua, todas las adiciones, modificaciones, desvinculaciones y reasignaciones de atajos de teclado se configuran en:

```
~/.config/hypr/UserConfigs/user_keybinds.lua
```

Esta guía explica cómo funcionan los atajos de teclado en la arquitectura Lua, cómo están estructurados los atajos predeterminados del sistema en `~/.config/hypr/configs/system_keybinds.lua`, y proporciona instrucciones paso a paso con numerosos ejemplos prácticos.

---

## 1. Descripción general y arquitectura

### Atajos predeterminados del sistema vs. Atajos del usuario

- **Predeterminados del sistema (`~/.config/hypr/configs/system_keybinds.lua`)**  
  Define los atajos listos para usar en la gestión de ventanas, scripts centrales de KoolDots (menús de Waybar, selectores de Rofi, efectos de fondos de pantalla, control de audio, disposiciones de ventanas) y navegación estándar de espacios de trabajo. Este archivo es administrado por el instalador de dotfiles y **no** debe editarse directamente, ya que futuras actualizaciones pueden sobrescribir los cambios.

- **Atajos personalizados del usuario (`~/.config/hypr/UserConfigs/user_keybinds.lua`)**  
  Reservado exclusivamente para sus atajos de teclado personales y modificaciones. Los atajos declarados aquí tienen prioridad y se **conservan intactos entre actualizaciones de dotfiles**.

---

## 2. Sintaxis y reglas de los atajos

Todos los atajos de teclado en `user_keybinds.lua` utilizan las siguientes funciones:

```lua
bind("MODIFICADORES", "TECLA", accion, [opciones])
unbind("MODIFICADORES", "TECLA")
```

### Modificadores admitidos
Los modificadores se especifican como cadenas en mayúsculas, separadas por espacios:
- Modificadores individuales: `"SUPER"`, `"SHIFT"`, `"CTRL"`, `"ALT"`
- Modificadores combinados: `"SUPER SHIFT"`, `"SUPER ALT"`, `"SUPER CTRL"`, `"CTRL ALT"`, `"SUPER CTRL SHIFT"`
- Sin modificador (por ejemplo, para teclas multimedia/hardware): `""`

### Tipos de acción
1. **`exec_cmd("comando")`**  
   Ejecuta un comando de shell, aplicación de terminal o script personalizado. Admite marcadores predefinidos como `'$term'` (terminal predeterminada) y `'$files'` (administrador de archivos predeterminado).
2. **`dispatch("despachador", [argumento])`**  
   Ejecuta una acción integrada del compositor Hyprland (por ejemplo, `killactive`, `togglefloating`, `fullscreen`, `workspace`, `movetoworkspace`).

### Tabla de opciones del atajo (`[opciones]`)
Puede pasar una tabla Lua opcional para personalizar el comportamiento del atajo:
- `description = "Texto"`: Proporciona una descripción legible que se muestra en la hoja de ayuda (`SUPER + H`) y en el menú de búsqueda de atajos (`SUPER + SHIFT + K`).
- `locked = true`: Permite que el atajo se active incluso cuando la pantalla está bloqueada por Hyprlock (por ejemplo, controles multimedia, volumen, suspensión).
- `repeating = true` (o `["repeat"] = true`): Ejecuta repetidamente la acción mientras la tecla se mantenga presionada (por ejemplo, ajuste de volumen, brillo, redimensionamiento de ventanas).

---

## 3. La regla de oro: Siempre use `unbind` antes de reasignar

Si una combinación de teclas ya está asignada en `system_keybinds.lua`, **siempre llame primero a `unbind("MODIFICADORES", "TECLA")`** antes de vincularla a una nueva acción.

```lua
-- Incorrecto: Puede ejecutar ambas acciones o provocar conflictos inesperados
bind("SUPER", "Return", exec_cmd("ghostty"))

-- Correcto: Desvincula primero la acción predeterminada (kitty) y luego vincula Ghostty
unbind("SUPER", "Return")
bind("SUPER", "Return", exec_cmd("ghostty"), { description = "Lanzar terminal Ghostty" })
```

---

## 4. Instrucciones paso a paso: Modificar atajos de teclado

### Paso 1: Comprobar los atajos predeterminados del sistema
Antes de cambiar un atajo, compruebe qué función cumple por defecto:
- Presione `SUPER + H` para abrir la hoja visual de ayuda (Key Hints).
- Presione `SUPER + SHIFT + K` para buscar entre todos los atajos registrados.
- O inspeccione `~/.config/hypr/configs/system_keybinds.lua`.

### Paso 2: Abrir `user_keybinds.lua`
Abra el archivo de configuración del usuario en su editor:

```bash
nano ~/.config/hypr/UserConfigs/user_keybinds.lua
# o
nvim ~/.config/hypr/UserConfigs/user_keybinds.lua
```

### Paso 3: Agregar sus atajos o modificaciones
Desplácese hasta el final del archivo (después del bloque de carga de asistentes) y añada sus combinaciones personalizadas.

### Paso 4: Validar la sintaxis de Lua
Asegúrese de que no falten comillas, comas o paréntesis:

```bash
luac -p ~/.config/hypr/UserConfigs/user_keybinds.lua
```

### Paso 5: Recargar Hyprland
Aplique los cambios inmediatamente sin cerrar sesión:
- Presione `SUPER + ALT + R` (atajo de refresco), o
- Ejecute `hyprctl reload` en su terminal.

---

## 5. Comparación: `system_keybinds.lua` vs. `user_keybinds.lua`

A continuación se presentan ejemplos que comparan la configuración predeterminada en `system_keybinds.lua` con su modificación en `user_keybinds.lua`:

| Acción / Función | Predeterminado del sistema (`system_keybinds.lua`) | Cómo modificar en `user_keybinds.lua` |
|---|---|---|
| **Lanzador de terminal** | `SUPER + Return` ejecuta `$term` (Kitty) | `unbind("SUPER", "Return")`<br>`bind("SUPER", "Return", exec_cmd("ghostty"))` |
| **Lanzador de aplicaciones** | `SUPER + D` ejecuta Rofi Drun | `unbind("SUPER", "D")`<br>`bind("SUPER", "SPACE", exec_cmd("rofi -show drun"))` |
| **Administrador de archivos** | `SUPER + E` ejecuta `$files` (Thunar) | `unbind("SUPER", "E")`<br>`bind("SUPER", "E", exec_cmd("nautilus"))` |
| **Cerrar ventana activa** | `SUPER + Q` despacha `killactive` | `unbind("SUPER", "Q")`<br>`bind("SUPER", "C", dispatch("killactive"))` |
| **Alternar pantalla completa** | `SUPER + SHIFT + F` (completa), `SUPER + F` (maximizar) | `unbind("SUPER", "F")`<br>`bind("SUPER", "F", dispatch("fullscreen", ""))` |
| **Alternar ventana flotante** | `SUPER + SPACE` despacha `togglefloating` | `unbind("SUPER", "SPACE")`<br>`bind("SUPER + ALT", "F", dispatch("togglefloating"))` |
| **Lanzador de navegador** | `SUPER + B` abre el navegador web predeterminado | `unbind("SUPER", "B")`<br>`bind("SUPER", "B", exec_cmd("zen-browser"))` |

---

## 6. Ejemplos prácticos por categoría

### Categoría A: Agregar nuevos atajos para aplicaciones
Añada atajos para aplicaciones que no están vinculadas por defecto:

```lua
-- Lanzar navegadores web
bind("SUPER", "B", exec_cmd("zen-browser"), { description = "Lanzar Zen Browser" })
bind("SUPER SHIFT", "C", exec_cmd("google-chrome-stable"), { description = "Lanzar Chrome" })

-- Lanzar editores de código e IDEs
bind("SUPER", "C", exec_cmd("code"), { description = "Lanzar VS Code" })
bind("SUPER", "E", exec_cmd("emacsclient -c -a 'emacs'"), { description = "Lanzar Emacs" })
bind("SUPER SHIFT", "V", exec_cmd("kitty -e nvim"), { description = "Lanzar Neovim en terminal" })

-- Lanzar herramientas de sistema y GUIs
bind("SUPER SHIFT", "P", exec_cmd("pavucontrol"), { description = "Control de volumen PulseAudio / PipeWire" })
bind("SUPER SHIFT", "B", exec_cmd("blueman-manager"), { description = "Administrador de Bluetooth" })
bind("SUPER CTRL", "T", exec_cmd("missioncenter"), { description = "Administrador de tareas Mission Center" })
```

---

### Categoría B: Reemplazar aplicaciones predeterminadas
Reemplace las aplicaciones estándar de KoolDots con sus alternativas preferidas:

```lua
-- 1. Reemplazar la terminal predeterminada (Kitty) por Ghostty o WezTerm
unbind("SUPER", "Return")
bind("SUPER", "Return", exec_cmd("ghostty"), { description = "Terminal (Ghostty)" })

-- 2. Reemplazar Rofi por Fuzzel o Wofi
unbind("SUPER", "D")
bind("SUPER", "D", exec_cmd("fuzzel"), { description = "Lanzador de aplicaciones (Fuzzel)" })

-- 3. Reemplazar Thunar por Dolphin o Yazi
unbind("SUPER", "E")
bind("SUPER", "E", exec_cmd("dolphin"), { description = "Administrador de archivos (Dolphin)" })

-- 4. Lanzar administrador de archivos Yazi en terminal
bind("SUPER SHIFT", "E", exec_cmd("ghostty -e yazi"), { description = "Administrador de archivos Yazi" })
```

---

### Categoría C: Gestión de ventanas y despachadores del compositor
Reconfigure el comportamiento de mosaico, flotado y cierre de ventanas:

```lua
-- Cerrar ventana activa con SUPER+W en lugar de SUPER+Q
unbind("SUPER", "Q")
bind("SUPER", "W", dispatch("killactive"), { description = "Cerrar ventana activa" })

-- Alternar pantalla completa real con SUPER+F (por defecto es maximizar)
unbind("SUPER", "F")
unbind("SUPER SHIFT", "F")
bind("SUPER", "F", dispatch("fullscreen", "0"), { description = "Alternar pantalla completa" })
bind("SUPER SHIFT", "F", dispatch("fullscreen", "1"), { description = "Alternar maximizado" })

-- Alternar ventana flotante con SUPER+V
unbind("SUPER", "SPACE")
bind("SUPER", "V", dispatch("togglefloating"), { description = "Alternar ventana flotante" })

-- Anclar ventana flotante para que permanezca visible en todos los espacios de trabajo
bind("SUPER SHIFT", "P", dispatch("pin"), { description = "Anclar ventana en todos los espacios" })

-- Alternar pseudo-mosaico (conserva dimensiones originales en mosaico)
unbind("SUPER", "P")
bind("SUPER", "P", dispatch("pseudo"), { description = "Alternar pseudo-mosaico" })
```

---

### Categoría D: Espacios de trabajo, Scratchpads y multimonitor

```lua
-- Cambiar a espacios de trabajo 1-3 con SUPER + [1-3]
bind("SUPER", "1", dispatch("workspace", "1"), { description = "Cambiar a espacio de trabajo 1" })
bind("SUPER", "2", dispatch("workspace", "2"), { description = "Cambiar a espacio de trabajo 2" })
bind("SUPER", "3", dispatch("workspace", "3"), { description = "Cambiar a espacio de trabajo 3" })

-- Mover ventana activa a un espacio de trabajo en silencio (sin cambiar el foco)
bind("SUPER ALT", "1", dispatch("movetoworkspacesilent", "1"), { description = "Mover ventana a espacio 1 en silencio" })
bind("SUPER ALT", "2", dispatch("movetoworkspacesilent", "2"), { description = "Mover ventana a espacio 2 en silencio" })

-- Alternar espacio de trabajo especial / Scratchpad
bind("SUPER", "U", dispatch("togglespecialworkspace", "scratchpad"), { description = "Alternar Scratchpad" })
bind("SUPER SHIFT", "U", dispatch("movetoworkspace", "special:scratchpad"), { description = "Mover ventana a Scratchpad" })

-- Mover espacio de trabajo entre monitores
bind("SUPER CTRL", "Left", dispatch("movecurrentworkspacetomonitor", "l"), { description = "Mover espacio al monitor izquierdo" })
bind("SUPER CTRL", "Right", dispatch("movecurrentworkspacetomonitor", "r"), { description = "Mover espacio al monitor derecho" })
```

---

### Categoría E: Redimensionamiento y movimiento de foco (estilo Vim)

```lua
-- Mover foco de ventana usando teclas Vim (H, J, K, L)
bind("SUPER", "H", dispatch("movefocus", "l"), { description = "Enfocar izquierda" })
bind("SUPER", "L", dispatch("movefocus", "r"), { description = "Enfocar derecha" })
bind("SUPER", "K", dispatch("movefocus", "u"), { description = "Enfocar arriba" })
bind("SUPER", "J", dispatch("movefocus", "d"), { description = "Enfocar abajo" })

-- Mover/Intercambiar posición de la ventana activa
bind("SUPER SHIFT", "H", dispatch("movewindow", "l"), { description = "Mover ventana a la izquierda" })
bind("SUPER SHIFT", "L", dispatch("movewindow", "r"), { description = "Mover ventana a la derecha" })
bind("SUPER SHIFT", "K", dispatch("movewindow", "u"), { description = "Mover ventana hacia arriba" })
bind("SUPER SHIFT", "J", dispatch("movewindow", "d"), { description = "Mover ventana hacia abajo" })

-- Redimensionar ventana activa con repetición al mantener presionada la tecla
bind("SUPER CTRL", "Right", dispatch("resizeactive", "30 0"), { description = "Ensanchar ventana", repeating = true })
bind("SUPER CTRL", "Left", dispatch("resizeactive", "-30 0"), { description = "Estrechar ventana", repeating = true })
bind("SUPER CTRL", "Up", dispatch("resizeactive", "0 -30"), { description = "Hacer más alta", repeating = true })
bind("SUPER CTRL", "Down", dispatch("resizeactive", "0 30"), { description = "Hacer más baja", repeating = true })
```

---

### Categoría F: Teclas de medios, volumen, brillo y hardware

Las teclas de hardware utilizan símbolos XF86 y generalmente deben incluir `locked = true` y `repeating = true`:

```lua
-- Control de volumen (con opciones de repetición y bloqueo)
bind("", "XF86AudioRaiseVolume", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --inc"), { description = "Subir volumen", locked = true, repeating = true })
bind("", "XF86AudioLowerVolume", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --dec"), { description = "Bajar volumen", locked = true, repeating = true })
bind("", "XF86AudioMute", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --toggle"), { description = "Silenciar audio", locked = true })
bind("", "XF86AudioMicMute", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --toggle-mic"), { description = "Silenciar micrófono", locked = true })

-- Reproducción multimedia
bind("", "XF86AudioPlay", exec_cmd("playerctl play-pause"), { description = "Reproducir/Pausar", locked = true })
bind("", "XF86AudioNext", exec_cmd("playerctl next"), { description = "Pista siguiente", locked = true })
bind("", "XF86AudioPrev", exec_cmd("playerctl previous"), { description = "Pista anterior", locked = true })

-- Brillo de pantalla
bind("", "XF86MonBrightnessUp", exec_cmd("$HOME/.config/hypr/scripts/Brightness.sh --inc"), { description = "Subir brillo", repeating = true })
bind("", "XF86MonBrightnessDown", exec_cmd("$HOME/.config/hypr/scripts/Brightness.sh --dec"), { description = "Bajar brillo", repeating = true })
```

---

### Categoría G: Capturas de pantalla y grabación

```lua
-- Captura de región personalizada al portapapeles y archivo mediante Hyprshot
bind("ALT SHIFT", "S", exec_cmd("$HOME/.config/hypr/scripts/hyprshot.sh -m region -o $HOME/Pictures/Screenshots"), { description = "Capturar región" })

-- Captura de pantalla completa directamente al portapapeles
bind("", "Print", exec_cmd("$HOME/.config/hypr/scripts/hyprshot.sh -m output --clipboard-only"), { description = "Capturar pantalla completa al portapapeles" })

-- Captura de ventana activa
bind("SUPER", "Print", exec_cmd("$HOME/.config/hypr/scripts/hyprshot.sh -m window -o $HOME/Pictures/Screenshots"), { description = "Capturar ventana activa" })
```

---

## 7. Cómo averiguar nombres de teclas y keycodes

Si no está seguro del nombre exacto de una tecla especial o no estándar:

1. Abra una terminal y ejecute el visor de eventos de Wayland:
   ```bash
   wev
   ```
2. Presione la tecla mientras enfoca la ventana de prueba de `wev`.
3. Busque el campo `sym:` en la salida de la terminal:
   ```
   [14: sym: XF86AudioRaiseVolume (0x1008113), utf8: '' ]
   ```
4. Utilice ese nombre de símbolo exacto como parámetro `TECLA` en `bind(...)` y `unbind(...)`.

---

## 8. Solución de problemas y preguntas frecuentes

### 1. El nuevo atajo no funciona tras editar `user_keybinds.lua`
- Compruebe si hay errores de sintaxis en Lua:
  ```bash
  luac -p ~/.config/hypr/UserConfigs/user_keybinds.lua
  ```
- Asegúrese de recargar la configuración de Hyprland con `SUPER + ALT + R` o `hyprctl reload`.

### 2. Se ejecutan tanto la acción antigua como la nueva al mismo tiempo
- Olvidó desvincular la combinación predeterminada primero. Agregue `unbind("MODIFICADORES", "TECLA")` justo encima de su instrucción `bind(...)`.

### 3. Un atajo no responde cuando la pantalla está bloqueada
- Añada `{ locked = true }` a la tabla de opciones de su llamada `bind(...)`.

### 4. ¿Cómo puedo ver todos los atajos de teclado actualmente activos?
- Ejecute `hyprctl binds` en su terminal, o presione `SUPER + SHIFT + K` para abrir el menú de búsqueda de atajos de Rofi.
