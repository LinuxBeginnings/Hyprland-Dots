# Cómo agregar aplicaciones de inicio automático en KoolDots (`user_startup.lua`)

En **KoolDots (2026)** con el flujo de configuración en Lua, todas las aplicaciones personales de inicio automático, applets de la bandeja del sistema, servicios en segundo plano y scripts de inicio personalizados se administran en:

```
~/.config/hypr/UserConfigs/user_startup.lua
```

Esta guía explica cómo funciona `user_startup.lua`, en qué se diferencia de las tareas de inicio del sistema y proporciona ejemplos paso a paso para los casos de uso más comunes.

---

## 1. Descripción general y arquitectura

### Inicio del sistema vs. Inicio del usuario

- **Inicio del sistema (`~/.config/hypr/configs/system_startup.lua` y `lua/startup.lua`)**:  
  Administra los servicios esenciales del entorno como Waybar, el demonio de fondos de pantalla, el demonio de notificaciones (`swaync`), el agente Polkit, Quickshell, el historial del portapapeles, el administrador de inactividad (`hypridle`), etc.
- **Inicio del usuario (`~/.config/hypr/UserConfigs/user_startup.lua`)**:  
  Reservado exclusivamente para sus aplicaciones y preferencias personales. **No** se sobrescribirá con las actualizaciones estándar del sistema de dotfiles.

### Cómo funciona `exec_once`

Internamente, `user_startup.lua` utiliza el asistente gestionado `exec_once(command)` que:

1. **Garantiza una ejecución única**: Evita que las aplicaciones se ejecuten múltiples veces al recargar la configuración de Hyprland.
2. **Espera a una sesión utilizable**: Cada comando espera al socket de Wayland *y* a que el IPC de Hyprland informe de al menos una salida. El compositor crea su socket mucho antes de terminar de arrancar, así que un comando que se ejecuta en el primer momento posible puede inicializarse contra un compositor que todavía no tiene salidas: la misma razón por la que los scripts de inicio del sistema sondean los monitores antes de hacer nada.
3. **Lanza los procesos a través del compositor**: Los comandos se lanzan con `hl.exec_cmd` de Hyprland, la misma ruta de lanzamiento que usaba el antiguo `exec-once`. El proceso recibe el entorno de la sesión, una máscara de señales limpia y su propia sesión, que es lo que necesitan los applets de bandeja, los servicios D-Bus y las aplicaciones gráficas. Por eso `&` y `disown` son innecesarios: el comando ya queda desacoplado.
4. **Genera registros por comando**: Guarda la salida stdout/stderr en `/tmp/hypr-lua-user-startup-<cmd>.log` para facilitar la resolución de problemas.

La lista de inicio del sistema (`lua/startup.lua`) usa este mismo asistente, de modo que ambas listas se comportan igual.

---

## 2. Paso a paso: Agregar una aplicación

### Paso 1: Abrir `user_startup.lua`

Abra el archivo en su editor favorito (o desde la terminal):

```bash
nano ~/.config/hypr/UserConfigs/user_startup.lua
# o
nvim ~/.config/hypr/UserConfigs/user_startup.lua
```

### Paso 2: Ubicar la tabla `startup_commands`

Busque la lista `startup_commands` cerca de la parte inferior del archivo:

```lua
-- Add custom startup commands:
local startup_commands = {
  -- "kdeconnect-app",
  -- "blueman-applet",
  -- "$HOME/.config/hypr/UserScripts/RainbowBorders.sh",
}
```

### Paso 3: Agregar sus comandos

Añada cualquier comando o binario válido como una cadena entre comillas en la tabla. Asegúrese de que cada elemento termine con una coma `,`:

```lua
local startup_commands = {
  "blueman-applet",
  "nm-applet --indicator",
  "flatpak run com.discordapp.Discord --start-minimized",
  "spotify --minimized",
}
```

### Paso 4: Guardar y aplicar

Para probar sus nuevas entradas de inicio:
- Cierre sesión y vuelva a iniciar sesión en Hyprland, o reinicie el equipo.
- Como `exec_once` está diseñado para el arranque inicial de sesión, al reiniciar o volver a iniciar sesión se ejecutarán las aplicaciones recién añadidas.

---

## 3. Ejemplos prácticos por categoría

### A. Bandeja del sistema y applets de hardware

```lua
local startup_commands = {
  "blueman-applet",                -- Administrador de Bluetooth en la bandeja
  "nm-applet --indicator",         -- Administrador de red NetworkManager en la bandeja
  "pasystray",                     -- Control de volumen de audio en la bandeja
  "udiskie --tray",                -- Montaje automático de unidades USB con icono en bandeja
  "cbatticon",                     -- Monitor de batería para portátiles en bandeja
}
```

### B. Mensajería, chat y redes sociales

Para aplicaciones nativas y Flatpak:

```lua
local startup_commands = {
  "flatpak run com.discordapp.Discord --start-minimized",
  "flatpak run org.telegram.desktop -startintray",
  "element-desktop --hidden",
  "slack -u",
}
```

### C. Productividad, contraseñas y multimedia

```lua
local startup_commands = {
  "1password --silent",
  "copyq --start-server",
  "spotify --minimized",
  "kdeconnect-app",
}
```

### D. Sincronización en la nube y demonios de respaldo

```lua
local startup_commands = {
  "nextcloud --background",
  "insync start",
  "megasync",
}
```

### E. Scripts personalizados y notificaciones diferidas

Utilice `$HOME` o encadenamiento de comandos en shell (`sleep`, `&&`, `;`):

```lua
local startup_commands = {
  "$HOME/.config/hypr/UserScripts/WallpaperAutoChange.sh $HOME/Pictures/wallpapers",
  "sleep 3; notify-send 'Bienvenido' '¡Sesión de Hyprland iniciada correctamente!'",
}
```

**Nota:** Los bordes arcoíris no son una entrada de `user_startup.lua`. Elija un modo en Ajustes rápidos → **Rainbow Borders Mode** (`SUPER SHIFT + E`). La elección se guarda en `~/.config/hypr/UserScripts/rainbow-borders.mode` y se vuelve a aplicar automáticamente al iniciar sesión y después de cada cambio de fondo de pantalla o tema; consulte la sección 4.

**Nota:** No añada `& disown` a los comandos. `exec_once` ya desacopla el proceso a través del compositor, y `disown` no es un builtin del shell POSIX (`sh`) con el que se ejecuta el comando, así que sólo añade una línea de "not found" al registro.

---

## 4. Orden de arranque y el parche del `sleep`

Sus comandos se ejecutan **a la vez que** la lista de inicio del sistema, no después. Esa lista contiene la pasada de fondo de pantalla:

```lua
"sleep 1; $HOME/.config/hypr/scripts/WallpaperDaemon.sh && $HOME/.config/hypr/scripts/WaybarStartup.sh"
```

Esa pasada reescribe estado de Hyprland a partir de la paleta de Wallust, incluidos `general:col.active_border`, `decoration.shadow.color` y los colores de borde de grupo. Todo lo que usted inicie y escriba esas mismas opciones queda **sobrescrito aproximadamente un segundo después**, lo que se ve exactamente como "mi comando no tuvo efecto".

Por eso un `sleep` parece arreglar algunas entradas. Es un parche, no una solución:

- Es una condición de carrera, no un retraso. Una máquina más lenta, otra pasada de fondo de pantalla o un cambio de tema más tarde en la sesión hacen que el problema vuelva.
- Un script de una sola pasada que fija un borde sólo gana hasta el siguiente cambio de fondo de pantalla. Use los modos persistentes: un modo de Rainbow Borders elegido en Ajustes rápidos se vuelve a aplicar después de cada pasada de fondo de pantalla o tema y ahora sobrevive al inicio de sesión.
- Añadir `sleep` también cambia la cadena del comando, lo que cambia el nombre del archivo marcador en `/tmp`, así que la entrada se ejecuta otra vez aunque antes se hubiera omitido.

Si algo realmente tiene que ejecutarse después de la pasada de fondo de pantalla, encadénelo detrás del script que controla ese estado (por ejemplo `WallpaperDaemon.sh && su-comando`) en lugar de adivinar un retraso.

---

## 5. Avanzado: Llamadas directas a `exec_once`

Aunque colocar los comandos en la tabla `startup_commands` es el método recomendado, también puede invocar `exec_once()` directamente en cualquier parte de `user_startup.lua`:

```lua
local exec_once = user_startup_helper.exec_once

exec_once("openrgb --startminimized --profile 'Default'")
```

---

## 6. Solución de problemas y depuración

Si una aplicación no se ejecuta tras iniciar sesión:

1. **Revisar los registros de inicio**:
   Verifique en `/tmp/` los registros creados por el asistente de inicio:
   ```bash
   ls -la /tmp/hypr-lua-user-startup-*.log
   cat /tmp/hypr-lua-user-startup-<nombre_de_app>*.log
   ```

2. **Verificar la disponibilidad del binario**:
   Asegúrese de que el programa esté instalado y disponible en su `$PATH`:
   ```bash
   which blueman-applet
   which flatpak
   ```

3. **Verificar la sintaxis de Lua**:
   Asegúrese de que no haya errores de sintaxis (como una coma o comilla faltante) ejecutando:
   ```bash
   luac -p ~/.config/hypr/UserConfigs/user_startup.lua
   ```

4. **Limpiar marcadores de sesión (para pruebas sin reiniciar)**:
   Si desea volver a ejecutar los comandos de `exec_once` sin cerrar sesión por completo, limpie los archivos de marcador:
   ```bash
   rm -f /tmp/hypr-lua-user-exec-once-*
   ```
   Un comando se marca como hecho *antes* de ejecutarse, así que una entrada que falló una vez no se reintenta en la misma sesión.

5. **La aplicación arranca pero el efecto desaparece**:
   Otro paso del inicio controla la misma opción de Hyprland. Consulte la sección 4.

6. **Una entrada que sólo funciona con `sleep` delante**:
   También la sección 4: el retraso está ocultando una condición de carrera, no resolviéndola.

---

## 7. Archivos de configuración relacionados

- **`~/.config/hypr/UserConfigs/user_keybinds.lua`**: Administrar atajos de teclado personalizados, desvinculaciones y lanzadores.
- **`~/.config/hypr/UserConfigs/user_window_rules.lua`**: Configurar reglas de ventana (flotante, anclado, asignación de espacios de trabajo).
- **`~/.config/hypr/UserConfigs/user_settings.lua`**: Personalizar apariencia general de Hyprland, dispositivos de entrada y gestos.
