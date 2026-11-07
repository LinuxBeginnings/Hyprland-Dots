# KooL's Hyprland-Dots — Guía de usuario

Una guía práctica de los atajos de teclado predeterminados y de los archivos en
`$HOME/.config/hypr/UserConfigs`, que es donde vive todo lo personal.

- Wiki: <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki>
- Repositorio: <https://github.com/LinuxBeginnings/Hyprland-Dots>
- Registro de cambios: <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Changelogs>

---

## Tabla de contenido

1. [Descripción general](#1-descripción-general)
2. [Instalación](#2-instalación)
3. [El menú de ajustes rápidos (SUPER + SHIFT + E)](#3-el-menú-de-ajustes-rápidos-super--shift--e)
4. [Atajos de teclado predeterminados](#4-atajos-de-teclado-predeterminados)
   - [4.1 Lanzadores, menús y aplicaciones](#41-lanzadores-menús-y-aplicaciones)
   - [4.2 Gestión de ventanas](#42-gestión-de-ventanas)
   - [4.3 Enfoque, mover, redimensionar e intercambiar](#43-enfoque-mover-redimensionar-e-intercambiar)
   - [4.4 Diseños y grupos](#44-diseños-y-grupos)
   - [4.5 Espacios de trabajo y espacio especial](#45-espacios-de-trabajo-y-espacio-especial)
   - [4.6 Capturas de pantalla](#46-capturas-de-pantalla)
   - [4.7 Monitores y disposiciones de pantalla](#47-monitores-y-disposiciones-de-pantalla)
   - [4.8 Tema, apariencia y sesión](#48-tema-apariencia-y-sesión)
   - [4.9 Medios, volumen, brillo y teclas de hardware](#49-medios-volumen-brillo-y-teclas-de-hardware)
5. [El directorio UserConfigs](#5-el-directorio-userconfigs)
   - [5.1 Qué cubre cada archivo](#51-qué-cubre-cada-archivo)
   - [5.2 Orden de carga (por qué ganan algunos archivos)](#52-orden-de-carga-por-qué-ganan-algunos-archivos)
6. [Editar los archivos de UserConfigs](#6-editar-los-archivos-de-userconfigs)
   - [6.1 `user_keybinds.lua`](#61-user_keybindslua)
   - [6.2 `user_settings.lua`](#62-user_settingslua)
   - [6.3 `user_decorations.lua`](#63-user_decorationslua)
   - [6.4 `user_animations.lua`](#64-user_animationslua)
   - [6.5 `user_window_rules.lua`](#65-user_window_ruleslua)
   - [6.6 `user_layer_rules.lua`](#66-user_layer_ruleslua)
   - [6.7 `user_startup.lua`](#67-user_startuplua)
   - [6.8 `user_env.lua`](#68-user_envlua)
   - [6.9 `user_defaults.lua`](#69-user_defaultslua)
   - [6.10 `monitors.lua`](#610-monitorslua)
   - [6.11 `workspaces.lua`](#611-workspaceslua)
   - [6.12 `user_laptops.lua`](#612-user_laptopslua)
7. [Aplicar, comprobar y deshacer cambios](#7-aplicar-comprobar-y-deshacer-cambios)
8. [El panel de red / Bluetooth](#8-el-panel-de-red--bluetooth)
9. [Lecturas adicionales](#9-lecturas-adicionales)

---

## 1. Descripción general

KooL's Hyprland-Dots es un conjunto de dotfiles de Hyprland ya configurados para
escritorios Wayland, que se distribuye junto con un script de copia que los
instala en `$HOME/.config`. El repositorio instala **solo la configuración**: ni
paquetes ni servicios. Los scripts de instalación de cada distribución
(enlazados más abajo) instalan los paquetes y, opcionalmente, traen estos dots.

La configuración actual está escrita con la **API de configuración en Lua** de
Hyprland (`hyprland.lua` y módulos cargados con `dofile`), no con el flujo
anterior de `.conf`/Hyprlang. Por eso todos los ejemplos de esta guía son
llamadas a tablas Lua como `hl.config({...})`, `hl.bind(...)` o
`apply_window_rule({...})`.

La disposición está dividida deliberadamente en dos partes:

| Capa                        | Ubicación en este repositorio   | Se instala en                         | Gestionado por                         |
| --------------------------- | ------------------------------- | ------------------------------------- | -------------------------------------- |
| Valores del sistema         | `config/hypr/configs/`          | `$HOME/.config/hypr/configs/`         | los dotfiles — se reemplaza al actualizar |
| Módulos compartidos         | `config/hypr/lua/`              | `$HOME/.config/hypr/lua/`             | los dotfiles — se reemplaza al actualizar |
| **Su configuración**        | **`config/hypr/UserConfigs/`**  | **`$HOME/.config/hypr/UserConfigs/`** | **usted — se conserva al actualizar**  |
| Sus scripts                 | `config/hypr/UserScripts/`      | `$HOME/.config/hypr/UserScripts/`     | usted — se conserva al actualizar      |
| Punto de entrada            | `config/hypr/hyprland.lua`      | `$HOME/.config/hypr/hyprland.lua`     | los dotfiles                           |

De esa tabla se desprenden dos reglas:

- Edite `UserConfigs/`, no `configs/`. `configs/` se sobrescribe al actualizar.
- No renombre los archivos de `UserConfigs/`. `hyprland.lua` y
  `lua/user_overrides.lua` los cargan por nombre; un cambio de nombre hace que el
  archivo deje de cargarse en silencio.

Las actualizaciones nunca reemplazan sus archivos de `UserConfigs`. Pueden
aplicarles parches pequeños y no destructivos (añadir un valor, nunca reescribir
el archivo); consulte [`Patching-UserConfigs.md`](./Patching-UserConfigs.md).

---

## 2. Instalación

Las instrucciones completas, los requisitos y la solución de problemas están en
la wiki:

> **Hyprland-Dots Wiki — Instalación y actualización:**
> <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Install_&_Update>

La ruta recomendada es el script de instalación de la distribución de su
sistema. Cada uno instala los paquetes necesarios y ofrece traer estos dotfiles:

| Distribución                    | Scripts de instalación                                          |
| ------------------------------- | --------------------------------------------------------------- |
| Arch Linux                      | <https://github.com/LinuxBeginnings/Arch-Hyprland>              |
| Fedora (43 / 44 / Rawhide)      | <https://github.com/LinuxBeginnings/Fedora-Hyprland>            |
| Debian (Trixie / Testing / SID) | <https://github.com/LinuxBeginnings/Debian-Hyprland>            |
| NixOS (25.05+)                  | <https://github.com/LinuxBeginnings/NixOS-Hyprland>             |
| Ubuntu 24.04 LTS                | <https://github.com/LinuxBeginnings/Ubuntu-Hyprland/tree/24.04> |
| Ubuntu 26.04 LTS                | <https://github.com/LinuxBeginnings/Ubuntu-Hyprland/tree/26.04> |

Ya no se admiten: OpenSUSE Tumbleweed, Ubuntu 24.10 / 25.04 / 25.10.

Script de arranque (clona el instalador correcto y lo inicia):

```bash
sh <(curl -L https://raw.githubusercontent.com/LinuxBeginnings/Hyprland-Dots/main/Distro-Hyprland.sh)
```

> El script de arranque no es seguro en fish-shell. En fish, clone el
> repositorio Distro-Hyprland de su distribución y ejecute `install.sh`
> directamente.

Instalar o actualizar solo los dots (se asume que los paquetes ya están):

```bash
git clone --depth=1 https://github.com/LinuxBeginnings/Hyprland-Dots.git
cd Hyprland-Dots
chmod +x copy.sh
./copy.sh
```

`copy.sh` hace una copia de seguridad de todo lo que va a reemplazar en
`$HOME/.config`, copia `config/` en `$HOME/.config` y deja intactos
`UserConfigs/` y `UserScripts/` en una instalación existente. Revise
`$HOME/.config` después y borre las copias de seguridad que no quiera.

Después de instalar:

- **Usuarios de NVIDIA:** lean las preguntas frecuentes de la wiki
  (<https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/FAQ_NVIDIA>) y revisen
  `$HOME/.config/hypr/UserConfigs/user_env.lua`.
- **Portátiles híbridos Intel/NVIDIA o AMD/NVIDIA:** el instalador activa los
  respaldos de cursor automáticamente; es normal que el cursor se reinicie al
  iniciar la sesión.
- Cierre la sesión y vuelva a entrar (o reinicie) para que se cargue la nueva
  configuración.

---

## 3. El menú de ajustes rápidos (SUPER + SHIFT + E)

```
SUPER + SHIFT + E
```

Abre un menú de rofi que es la forma más rápida de llegar a los archivos de esta
guía. Al elegir una entrada `Edit …` se abre ese archivo en su editor, en este
orden: primero `user_defaults.lua`, luego `$VISUAL`/`$EDITOR` y después
`nvim`/`vim`/`nano`. Los editores de terminal se abren dentro de su terminal.
Cuando el editor se cierra, el script ejecuta `luac -p` sobre el archivo y le
avisa si la sintaxis Lua está rota, que es justamente el error que impide que
Hyprland cargue una configuración.

El menú principal tiene dos columnas:

- **Izquierda — categorías:** `[[ User Settings ]]`, `[[ System Settings ]]`,
  `[[ Toggle Options ]]`, `[[ Misc ]]`
- **Derecha — enlaces rápidos:** las entradas que se usan con más frecuencia

| Categoría       | Entradas                                                                                                                                                                                                                                                                                      |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| User Settings   | Manage / Edit User Defaults, Edit User Keybinds, Edit User ENV variables, Edit User Startup Apps, Edit User Window Rules, Edit User Layer Rules, Edit User Settings, Edit User Decorations, Edit User Animations, Edit User Laptop Settings, Edit User Monitor config, Select Hyprview Layout |
| System Settings | Edit System Default Keybinds, Startup Apps, Window Rules, Layer Rules, Settings                                                                                                                                                                                                               |
| Toggle Options  | Waybar weather units, Waybar clock 12H/24H, Game Mode, Window Wobble                                                                                                                                                                                                                          |
| Misc            | Starship prompt, SDDM wallpaper, Kitty/Ghostty/Wlogout themes, nwg-displays, nwg-look, qt6ct/qt5ct, Hyprlock wallpaper, animations, monitor profiles, rofi themes, keybind search, palette source, rainbow borders                                                                            |

Otros dos menús que conviene conocer:

- `SUPER + SHIFT + K`: lista de atajos con búsqueda (los mismos datos que las tablas siguientes)
- `SUPER + H`: hoja de referencia rápida de atajos

---

## 4. Atajos de teclado predeterminados

Estos son los valores de fábrica de
`$HOME/.config/hypr/configs/system_keybinds.lua`. Están definidos como se muestra
y no están pensados para editarse en el lugar: copie lo que quiera cambiar en
`$HOME/.config/hypr/UserConfigs/user_keybinds.lua`.

`SUPER` es la tecla Windows/Super. Los nombres de tecla son keysyms de XKB, así
que las flechas son `left/right/up/down`, y la fila de números se enlaza por
código de tecla (`code:10` = `1`) para que funcione en distribuciones donde el
dígito no se produce sin Shift.

### 4.1 Lanzadores, menús y aplicaciones

| Teclas                   | Acción                            |
| ------------------------ | --------------------------------- |
| `SUPER + D`              | Lanzador de aplicaciones (rofi drun) |
| `SUPER + Return`         | Terminal                          |
| `SUPER + E`              | Gestor de archivos                |
| `SUPER + B`              | Navegador predeterminado          |
| `SUPER + A`              | Vista general del escritorio      |
| `SUPER + CTRL + A`       | Vista general de AGS (shell)      |
| `SUPER + SHIFT + Return` | Terminal desplegable              |
| `SUPER + C`              | Gestor de sesiones SSH            |
| `SUPER + S`              | Búsqueda web                      |
| `SUPER + CTRL + S`       | Conmutador de ventanas            |
| `SUPER + ALT + E`        | Selector de emojis                |
| `SUPER + ALT + V`        | Gestor del portapapeles           |
| `SUPER + ALT + C`        | Calculadora                       |
| `SUPER + SHIFT + M`      | Música en línea (RofiBeats)       |
| `SUPER + SHIFT + N`      | Panel de notificaciones (swaync)  |
| `SUPER + SHIFT + K`      | Buscar atajos                     |
| `SUPER + SHIFT + E`      | Menú de ajustes rápidos           |
| `SUPER + H`              | Atajos / hoja de referencia       |
| `SUPER + ALT + R`        | Recargar Waybar y los menús       |

### 4.2 Gestión de ventanas

| Teclas                                   | Acción                                       |
| ---------------------------------------- | -------------------------------------------- |
| `SUPER + Q`                              | Cerrar la ventana activa                     |
| `SUPER + SHIFT + Q`                      | Terminar el proceso de la ventana activa     |
| `SUPER + F`                              | Maximizar la ventana                         |
| `SUPER + SHIFT + F`                      | Alternar pantalla completa                   |
| `SUPER + SPACE`                          | Alternar flotante para la ventana activa     |
| `SUPER + ALT + SPACE`                    | Hacer flotantes todas las ventanas           |
| `SUPER + CTRL + SPACE`                   | Hacer flotantes todas las ventanas al mismo tamaño |
| `SUPER + CTRL + O`                       | Alternar la opacidad de la ventana activa    |
| `SUPER + SHIFT + H`                      | Silenciar / reactivar el audio de la ventana activa |
| `ALT + Tab`                              | Pasar a la siguiente ventana, trayéndola al frente |
| `SUPER + j` / `SUPER + k`                | Pasar a la ventana siguiente / anterior (según el diseño) |
| `SUPER + arrastrar con botón derecho` (`mouse:273`) | Redimensionar la ventana          |
| `SUPER + arrastrar con botón izquierdo` (`mouse:272`) | Mover la ventana                |

### 4.3 Enfoque, mover, redimensionar e intercambiar

| Teclas                    | Acción                                              |
| ------------------------- | --------------------------------------------------- |
| `SUPER + ←/→/↑/↓`         | Enfocar en esa dirección (según el diseño)          |
| `SUPER + CTRL + ←/→/↑/↓`  | Mover la ventana en esa dirección                   |
| `SUPER + SHIFT + ←/→/↑/↓` | Redimensionar la ventana (`±50 px`, se repite mientras se mantiene) |
| `SUPER + ALT + ←/→/↑/↓`   | Intercambiar la ventana con la vecina en esa dirección |

### 4.4 Diseños y grupos

| Teclas                    | Acción                                    |
| ------------------------- | ----------------------------------------- |
| `SUPER + ALT + 1`         | Diseño Dwindle                            |
| `SUPER + ALT + 2`         | Diseño Master                             |
| `SUPER + ALT + 3`         | Diseño Scrolling                          |
| `SUPER + ALT + 4`         | Diseño Monocle                            |
| `SUPER + ALT + L`         | Recorrer los diseños                      |
| `SUPER + P`               | Alternar pseudo-tiling (dwindle)          |
| `SUPER + SHIFT + I`       | Alternar división (dwindle)               |
| `SUPER + M`               | Fijar la proporción de división en `0.3`  |
| `SUPER + I`               | Añadir maestro (diseño master)            |
| `SUPER + CTRL + D`        | Quitar maestro                            |
| `SUPER + CTRL + Return`   | Intercambiar la ventana con el maestro    |
| `SUPER + R`               | Recorrer las proporciones de columna predefinidas (scrolling) |
| `SUPER + ALT + H`         | Diseño scrolling: dirección horizontal    |
| `SUPER + CTRL + V`        | Diseño scrolling: dirección vertical      |
| `SUPER + ALT + S`         | Alternar la dirección del diseño scrolling (V/H) |
| `SUPER + SHIFT + .` / `,` | Mover la ventana a la columna derecha / izquierda |
| `SUPER + ALT + .` / `,`   | Intercambiar columnas a la derecha / izquierda |
| `SUPER + G`               | Alternar grupo                            |
| `SUPER + Tab`             | Siguiente ventana del grupo               |
| `SUPER + SHIFT + Tab`     | Ventana anterior del grupo                |
| `SUPER + CTRL + J` / `L`  | Mover la ventana al grupo (izquierda / derecha) |
| `SUPER + CTRL + H`        | Sacar la ventana del grupo                |
| `SUPER + CTRL + Tab`      | Alternar la vista general de Hyprview     |

### 4.5 Espacios de trabajo y espacio especial

| Teclas                    | Acción                                             |
| ------------------------- | -------------------------------------------------- |
| `SUPER + 1…0`             | Cambiar al espacio de trabajo 1…10                 |
| `SUPER + SHIFT + 1…0`     | Mover la ventana activa al espacio de trabajo 1…10 |
| `SUPER + CTRL + 1…0`      | Mover la ventana sin seguirlas (sin cambiar el foco) |
| `SUPER + Tab`             | Siguiente espacio de trabajo (usa el hueco libre, `m+1`) |
| `SUPER + SHIFT + Tab`     | Espacio de trabajo anterior                        |
| `SUPER + .` / `,`         | Siguiente / anterior espacio de trabajo (`e+1` / `e-1`) |
| `SUPER + rueda del ratón` | Siguiente / anterior espacio de trabajo            |
| `SUPER + SHIFT + ]` / `[` | Mover la ventana al siguiente / anterior espacio de trabajo |
| `SUPER + CTRL + ]` / `[`  | Mover la ventana en silencio al siguiente / anterior espacio de trabajo |
| `SUPER + U`               | Alternar el espacio especial                       |
| `SUPER + SHIFT + U`       | Mover la ventana activa al espacio especial        |
| `SUPER + CTRL + F9…F12`   | Mover el espacio de trabajo al monitor izquierdo / derecho / superior / inferior |

`SUPER + Tab` y `SUPER + SHIFT + Tab` también cambian de grupo cuando un grupo
tiene el foco; es una superposición heredada de Hyprland, no un fallo.

### 4.6 Capturas de pantalla

| Teclas                                               | Acción                              |
| ---------------------------------------------------- | ----------------------------------- |
| `SUPER + Print` o `SUPER + F6`                       | Captura de pantalla ahora           |
| `SUPER + SHIFT + Print` o `SUPER + SHIFT + F6`       | Captura de un área seleccionada     |
| `SUPER + CTRL + Print` o `SUPER + CTRL + F6`         | Captura después de 5 s              |
| `SUPER + CTRL + SHIFT + Print` o `SUPER + ALT + F6`  | Captura después de 10 s             |
| `ALT + Print` o `ALT + F6`                           | Captura de la ventana activa        |
| `SUPER + SHIFT + S`                                  | Captura de área, abierta en swappy  |
| `ALT + SHIFT + S`                                    | Captura de región con Hyprshot      |

### 4.7 Monitores y disposiciones de pantalla

| Teclas            | Acción                                                     |
| ----------------- | ---------------------------------------------------------- |
| `SUPER + ALT + D` | Menú de disposiciones de pantalla para los monitores conectados |
| `SUPER + ALT + W` | Aplicar la disposición guardada llamada `Work`             |

Las disposiciones se guardan por conjunto de monitores (no por puerto) y se
escriben en `$HOME/.config/hypr/UserConfigs/monitors.lua`. Pulse
`SUPER + ALT + D`, ordene las pantallas y luego "Save current state as…".
`SUPER + SHIFT + E` → **Choose Monitor Profiles** lista esas mismas
disposiciones más los archivos antiguos de `Monitor_Profiles/`, que puede
importar en un solo sentido. Descripción completa:
[`README-display-layouts.md`](../README-display-layouts.md).

### 4.8 Tema, apariencia y sesión

| Teclas                     | Acción                            |
| -------------------------- | --------------------------------- |
| `SUPER + T`                | Selector global de tema (Wallust) |
| `SUPER + W`                | Elegir fondo de pantalla          |
| `SUPER + SHIFT + W`        | Efectos del fondo de pantalla     |
| `CTRL + ALT + W`           | Fondo de pantalla aleatorio       |
| `SUPER + N`                | Alternar Hyprsunset (luz nocturna) |
| `SUPER + SHIFT + G`        | Alternar el modo juego            |
| `SUPER + SHIFT + X`        | Alternar el efecto wobble de las ventanas |
| `SUPER + ALT + O`          | Alternar el desenfoque            |
| `SUPER + SHIFT + A`        | Menú de animaciones              |
| `SUPER + SHIFT + B`        | Menú de modos de bordes arcoíris  |
| `SUPER + SHIFT + O`        | Cambiar el tema de oh-my-zsh      |
| `SUPER + CTRL + B`         | Menú de estilos de Waybar         |
| `SUPER + ALT + B`          | Menú de diseños de Waybar         |
| `SUPER + CTRL + ALT + B`   | Activar / desactivar Waybar       |
| `SUPER + CTRL + R`         | Selector de temas de Rofi         |
| `SUPER + CTRL + SHIFT + R` | Selector de temas de Rofi (modificado) |
| `SUPER + CTRL + K`         | Selector de temas de Kitty        |
| `SUPER + CTRL + G`         | Selector de temas de Ghostty      |
| `SUPER + CTRL + W`         | Selector de temas de wlogout      |
| `SUPER + CTRL + SHIFT + W` | Selector de fondo de pantalla de wlogout |
| `CTRL + ALT + L`           | Bloquear la pantalla             |
| `CTRL + ALT + P`           | Menú de apagado (wlogout)        |
| `CTRL + ALT + D`           | Activar / desactivar el dock     |
| `CTRL + ALT + Delete`      | Salir de Hyprland                |
| `ALT + Shift` (cualquiera de las dos)   | Cambiar la distribución del teclado de forma global |
| `SHIFT + Alt` (cualquiera de las dos)   | Cambiar la distribución del teclado por ventana |

### 4.9 Medios, volumen, brillo y teclas de hardware

Estas usan la combinación `""` (sin modificador) y están marcadas como `locked`,
así que siguen funcionando con la pantalla de bloqueo activa.

| Teclas                                                                                   | Acción                                    |
| ---------------------------------------------------------------------------------------- | ----------------------------------------- |
| `XF86AudioRaiseVolume` / `XF86AudioLowerVolume`                                          | Subir / bajar el volumen                  |
| `ALT + XF86AudioRaiseVolume` / `XF86AudioLowerVolume`                                    | Subir / bajar el volumen (paso fino)      |
| `XF86AudioMute`                                                                          | Silenciar / reactivar                     |
| `XF86AudioMicMute`                                                                       | Silenciar / reactivar el micrófono        |
| `XF86AudioPlay` / `XF86AudioPause` / `XF86AudioNext` / `XF86AudioPrev` / `XF86AudioStop` | Control de reproducción                   |
| `XF86MonBrightnessUp` / `XF86MonBrightnessDown`                                          | Brillo de la pantalla                     |
| `CTRL + ALT + =` / `-`, `CTRL + ALT + KP_Add` / `KP_Subtract`                            | Brillo de la pantalla (sin fila Fn)       |
| `XF86KbdBrightnessUp` / `XF86KbdBrightnessDown` / `XF86KbdLightOnOff`                    | Retroiluminación del teclado              |
| `XF86TouchpadToggle`                                                                     | Activar / desactivar el touchpad          |
| `XF86Sleep`                                                                              | Suspender                                 |
| `XF86Rfkill`                                                                             | Modo avión                                |
| `XF86Launch1`                                                                            | Botón Armoury Crate de ASUS               |
| `XF86Launch3`                                                                            | ASUS: siguiente perfil de RGB del teclado |
| `XF86Launch4`                                                                            | ASUS: siguiente perfil de ventiladores    |

También hay un submapa de paso directo del teclado: `SUPER + SHIFT + P` envía sus
pulsaciones a la ventana enfocada (útil para máquinas virtuales y sesiones
remotas), y `SUPER + ALT + P` sale de él. Waybar muestra `submap: Bind KB`
mientras está activo.

El panel de red / Bluetooth no tiene atajo predeterminado, por eso no aparece en
las tablas anteriores. La sección 8 muestra la línea `bind(...)` para asignarle
uno; `SUPER + CTRL + N` está libre y es el que usa ese ejemplo. Una vez añadido,
`SUPER + SHIFT + K` lo lista con su descripción.

---

## 5. El directorio UserConfigs

Todo lo siguiente es `$HOME/.config/hypr/UserConfigs/` una vez instalado (en este
repositorio: `config/hypr/UserConfigs/`).

### 5.1 Qué cubre cada archivo

| Archivo                 | Qué cubre                                                                                                       |
| ----------------------- | --------------------------------------------------------------------------------------------------------------- |
| `user_keybinds.lua`     | Sus atajos: añadir combinaciones nuevas, sobrescribir o mover los predeterminados                                |
| `user_settings.lua`     | Dispositivos de entrada: distribuciones de teclado, velocidad de repetición, touchpad, ratón, tabletas y opciones de `misc`/`cursor` |
| `user_decorations.lua`  | Aspecto de las ventanas: espacios, tamaño y color del borde, redondeo, opacidad, desenfoque, sombras, atenuación, colores de grupo, wobble |
| `user_animations.lua`   | Activación de animaciones y curvas y estilos por animación                                                      |
| `user_window_rules.lua` | Reglas de ventana por aplicación: flotar, tamaño, posición, espacio de trabajo, opacidad, fijar, etiquetas, sin desenfoque |
| `user_layer_rules.lua`  | Reglas de capas para barras, lanzadores y notificaciones (por ejemplo, el desenfoque de rofi)                    |
| `user_startup.lua`      | Inicio automático: iconos de bandeja, demonios, scripts personales                                               |
| `user_env.lua`          | Variables de entorno de la sesión (`hl.env`)                                                                    |
| `user_defaults.lua`     | `KOOLDOTS_DEFAULTS`: terminal, gestor de archivos, editor, editor visual, motor de búsqueda                       |
| `monitors.lua`          | Modos, posiciones y escalas de los monitores; también lo escribe el sistema de disposiciones de pantalla         |
| `workspaces.lua`        | Reglas de espacio de trabajo por monitor; también las escribe el sistema de disposiciones de pantalla            |
| `user_laptops.lua`      | Comportamiento de la tapa / modo clamshell y de conexión en caliente en portátiles (se autogestiona; normalmente no lo toque) |

Archivos que no son de configuración en el mismo directorio, editados
directamente en lugar de desde el menú de ajustes:

| Archivo                       | Propósito                                            |
| ----------------------------- | ---------------------------------------------------- |
| `kitty.conf`, `kitty-themes/` | Configuración y conjunto de temas de la terminal Kitty |
| `ghostty.conf`                | Configuración de la terminal Ghostty                 |
| `hyprview-layout.conf`        | Diseño seleccionado para la vista general de Hyprview |
| `display-layouts.json`        | Disposiciones de pantalla guardadas (las escribe el sistema de disposiciones) |

### 5.2 Orden de carga (por qué ganan algunos archivos)

`$HOME/.config/hypr/hyprland.lua` es el punto de entrada. Carga
`lua/user_defaults.lua` (que a su vez lee su `UserConfigs/user_defaults.lua`),
después el índice de atajos y después `lua/user_overrides.lua`, que carga en este
orden:

```
configs/system_env.lua        →  UserConfigs/user_env.lua
configs/system_startup.lua    →  UserConfigs/user_startup.lua
configs/system_window_rules.lua → UserConfigs/user_window_rules.lua
configs/system_layer_rules.lua  → UserConfigs/user_layer_rules.lua
configs/system_keybinds.lua   →  UserConfigs/user_keybinds.lua
configs/system_settings.lua   →  UserConfigs/user_settings.lua
configs/system_laptops.lua    →  UserConfigs/user_laptops.lua
                              →  UserConfigs/user_decorations.lua
                              →  UserConfigs/user_animations.lua
```

y después `lua/monitors.lua` y `lua/workspaces.lua`, que leen sus
`UserConfigs/monitors.lua` y `UserConfigs/workspaces.lua`.

Consecuencias que conviene recordar:

- Su archivo se carga **después** del archivo del sistema, así que un valor que
  repita allí gana.
- `user_decorations.lua` se carga después de `user_settings.lua`, así que una
  tabla `general` en `user_settings.lua` sería sobrescrita por la de
  `user_decorations.lua`. Ponga los espacios y bordes en `user_decorations.lua`.
- Los atajos se añaden, no se reemplazan. Si una combinación ya está enlazada,
  ejecute primero `unbind("MODS", "KEY")` y luego vuelva a enlazarla con
  `bind(...)`.

---

## 6. Editar los archivos de UserConfigs

Abra cualquiera de ellos con `SUPER + SHIFT + E`, o edite el archivo
directamente. Guarde el archivo y la configuración se recarga:
`scripts/LuaConfigWatch.sh` vigila los directorios cargados y avisa al punto de
entrada, porque la recarga automática de Hyprland solo vigila `hyprland.lua`.
Si el vigilante no está en ejecución (necesita `inotify-tools`), ejecute
`hyprctl reload` usted mismo.

Cada archivo incluye ejemplos comentados. Abajo están esos ejemplos y algunos
más; descomente y ajuste.

### 6.1 `user_keybinds.lua`

`$HOME/.config/hypr/UserConfigs/user_keybinds.lua`

```lua
bind("MODS", "KEY", action, [options])
unbind("MODS", "KEY")
```

- Modificadores: `"SUPER"`, `"SHIFT"`, `"CTRL"`, `"ALT"`, combinaciones como
  `"SUPER SHIFT"` / `"SUPER CTRL SHIFT"`, o `""` para teclas de hardware.
- Acciones: `exec_cmd("comando")` para ejecutar un comando, `dispatch("nombre", "arg")`
  para los despachadores del compositor.

Añadir una combinación nueva, en teclas que nadie más usa:

```lua
bind("SUPER", "Z", exec_cmd("ghostty"), { description = "Launch Ghostty" })
bind("SUPER SHIFT", "V", exec_cmd("pavucontrol"), { description = "Audio control" })
bind("SUPER", "X", dispatch("killactive"), { description = "Close active window" })
```

Cambiar lo que hace una combinación existente: desenlace primero y luego enlace:

```lua
-- SUPER + Return abre kitty por defecto; que abra ghostty
unbind("SUPER", "Return")
bind("SUPER", "Return", exec_cmd("ghostty"), { description = "Launch Ghostty" })
```

Mover una acción a otra combinación:

```lua
-- Gestor de archivos: SUPER + E → SUPER + F. Emacs se queda con SUPER + E.
unbind("SUPER", "E")
unbind("SUPER", "F")   -- por defecto: maximizar
bind("SUPER", "F", exec_cmd("$HOME/.config/hypr/scripts/LaunchFileManager.sh '$files' '$term'"),
  { description = "File manager" })
bind("SUPER", "E", exec_cmd("emacsclient -c -a 'emacs'"), { description = "Launch Emacs" })
```

Reasignar una acción del compositor:

```lua
unbind("SUPER", "Q")
bind("SUPER", "Q", dispatch("killactive"), { description = "Close active window" })
bind("SUPER SHIFT", "F", dispatch("fullscreen", "0"), { description = "Toggle fullscreen" })
bind("SUPER ALT", "W", dispatch("workspace", "special:scratchpad"), { description = "Scratchpad" })
```

Opciones de `bind`:

```lua
-- locked = true    → sigue funcionando con la pantalla de bloqueo activa (teclas multimedia)
-- repeating = true → se repite mientras se mantiene la tecla (volumen, brillo)
bind("CTRL ALT", "bracketright", exec_cmd("$HOME/.config/hypr/scripts/Brightness.sh --inc"),
  { description = "Brightness up", repeating = true })
bind("", "XF86AudioMute", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --toggle"),
  { description = "Mute audio", locked = true })
```

Conviene saber:

- `$term`, `$files`, `$edit` y `$visual` se sustituyen por los valores de
  `user_defaults.lua`, así que un solo lugar cambia todos los comandos enlazados.
- Evite las teclas que ya usan los valores predeterminados (las tablas de la
  sección 4) salvo que las desenlace con `unbind`. La lista completa de valores
  predeterminados también está en `SUPER + SHIFT + K`.
- `dispatch()` entiende los despachadores habituales — `killactive`,
  `togglefloating`, `fullscreen`, `workspace`, `movetoworkspace`,
  `togglespecialworkspace`, `togglegroup`, `pseudo`, `layoutmsg`, `resizeactive`,
  `movewindow`, `moveintogroup`, `moveoutofgroup` — y avisa con una advertencia
  al cargar cuando el nombre no tiene manejador, en lugar de quedarse en
  silencio sin hacer nada.

Más detalles: [`HOWTO-Change-Keybindgs.md`](./HOWTO-Change-Keybindgs.md) y
[`Keybinds.md`](./Keybinds.md).

### 6.2 `user_settings.lua`

`$HOME/.config/hypr/UserConfigs/user_settings.lua`

Comportamiento del teclado, el touchpad, el ratón y las tabletas, además de
algunas opciones de `misc`/`cursor`. El ejemplo incluido es un bloque `input`
completo; recórtelo a lo que realmente quiera cambiar.

Cambiar la distribución del teclado y habilitar dos distribuciones:

```lua
hl.config({
  input = {
    kb_layout = "us,de",
    kb_variant = "",
    kb_options = "grp:alt_shift_toggle",   -- ALT + SHIFT cambia la distribución
  },
  misc = {
    focus_on_activate = true,              -- atender las peticiones de foco de las aplicaciones
  },
})
```

`kb_layout` y `kb_variant` deben tener la misma cantidad de comas:
`kb_layout = "fr,de"` se combina con `kb_variant = "azerty,"` o con
`kb_variant = ""`.

Ajustes de touchpad y ratón:

```lua
hl.config({
  input = {
    sensitivity = 0.2,              -- -1.0 … 1.0
    follow_mouse = 1,               -- 0 clic, 1 puntero, 2 separado
    touchpad = {
      natural_scroll = false,
      tap_to_click = true,
      disable_while_typing = true,
      middle_button_emulation = true,
    },
  },
  cursor = {
    no_warps = true,                -- no recentrar el cursor al cambiar de espacio de trabajo
    warp_on_change_workspace = 0,
  },
})
```

Bloq Mayús como Escape, y sin repetición en la fila de números, son valores de
`kb_options`:

```lua
hl.config({ input = { kb_options = "caps:escape" } })
```

Los espacios, los bordes y el desenfoque **no** van aquí: viven en
`user_decorations.lua`, que se carga después y sobrescribiría una tabla `general`
o `decoration` definida en este archivo.

Más detalles: [`HOWTO-user_settings.lua.md`](./HOWTO-user_settings.lua.md) y
[`HOWTO-Keyboard-Mappings.md`](./HOWTO-Keyboard-Mappings.md).

### 6.3 `user_decorations.lua`

`$HOME/.config/hypr/UserConfigs/user_decorations.lua`

El aspecto de las ventanas: tamaño y color del borde, espacios, redondeo,
opacidad, desenfoque, sombras, atenuación, colores de grupo y wobble. Los colores
salen de `$HOME/.config/hypr/wallust/wallust-hyprland.conf`, así que por defecto
siguen al fondo de pantalla.

Espacios más ajustados y sin redondeo:

```lua
hl.config({
  general = {
    border_size = 2,
    gaps_in = 2,
    gaps_out = 8,
  },
  decoration = {
    rounding = 0,
  },
})
```

Colores de borde fijos (no ligados al fondo de pantalla):

```lua
hl.config({
  general = {
    col = {
      active_border = "rgba(f7077eff)",
      inactive_border = "rgba(5f6578ff)",
    },
  },
})
```

Más desenfoque, y terminales translúcidas:

```lua
hl.config({
  decoration = {
    active_opacity = 1.0,
    inactive_opacity = 0.90,
    blur = {
      enabled = true,
      size = 8,
      passes = 3,
      xray = true,
    },
  },
})
```

El wobble es un transformador de ventanas, no una animación. Esta tabla es el
único lugar donde se configura, y `scripts/ToggleWobble.sh` (y
`SUPER + SHIFT + X`) cambia `enabled` en el mismo sitio, buscando las claves por
nombre: conserve las claves y cambie los valores con libertad:

```lua
hl.config({
  decoration = {
    wobble = {
      enabled = true,
      mesh = 12,
      stiffness = 240,   -- más bajo = más flotante
      damping = 16,      -- más alto = se asienta antes
      mass = 1,
      intensity = 0.25,
    },
  },
})
```

Consulte el valor en vivo con `hyprctl getoption decoration:wobble:enabled`.

Más detalles: [`HOWTO-user_decorations.lua.md`](./HOWTO-user_decorations.lua.md)
y [`HOWTO-Override-Theme-and-Icons.md`](./HOWTO-Override-Theme-and-Icons.md).

### 6.4 `user_animations.lua`

`$HOME/.config/hypr/UserConfigs/user_animations.lua`

Desactivar las animaciones, o cambiar una sola en lugar de todas:

```lua
hl.config({ animations = { enabled = true } })

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "wind", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "wind", style = "slide" })
```

`SUPER + SHIFT + A` abre un menú con conjuntos ya preparados y escribe aquí por
usted. Los valores predeterminados están en
`$HOME/.config/hypr/lua/animations.lua`.

### 6.5 `user_window_rules.lua`

`$HOME/.config/hypr/UserConfigs/user_window_rules.lua`

Comportamiento por aplicación: flotar, tamaño, posición, espacio de trabajo,
opacidad, fijar, etiquetas, sin desenfoque, mantener la relación de aspecto y
bloquear el foco inicial.

Primero busque la clase o el título exactos de una ventana:

```bash
hyprctl activewindow        # o: hyprctl clients
```

Hacer flotante y centrar una ventana de ajustes:

```lua
apply_window_rule({
  name = "user-float-pavucontrol",
  match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol)$" },
  float = true,
  center = true,
  size = "(monitor_w*0.5) (monitor_h*0.55)",
})
```

Enviar aplicaciones a espacios de trabajo fijos:

```lua
apply_window_rule({ name = "user-spotify-workspace", match = { class = "^([Ss]potify)$" }, workspace = "9" })
apply_window_rule({
  name = "user-discord-workspace",
  match = { class = "^([Dd]iscord|[Ww]ebCord|[Vv]esktop)$" },
  workspace = "10",
})
```

Opacidad por aplicación:

```lua
apply_window_rule({
  name = "user-transparent-terminal",
  match = { class = "^(kitty|ghostty|Alacritty)$" },
  opacity = "0.90 0.80",            -- activa inactiva
})
```

Una ventana de imagen en imagen que le sigue entre espacios de trabajo:

```lua
apply_window_rule({
  name = "user-pip-video",
  match = { title = "^[Pp]icture-in-[Pp]icture$" },
  float = true,
  pin = true,
  move = "72% 7%",
  size = "(monitor_w*0.25) (monitor_h*0.25)",
  keep_aspect_ratio = true,
})
```

Evitar que una aplicación robe el foco al iniciar sesión:

```lua
apply_window_rule({ name = "user-no-focus-slack", match = { class = "^(Slack|slack)$" }, no_initial_focus = true })
```

`match` también acepta `initial_class`, `initial_title`, `tag` y `fullscreen`;
las acciones también aceptan `idle_inhibit`, `no_blur` y `tag = "+nombre"`.
`name` debe ser único.

Más detalles: [`HOWTO-user_window_rules.lua.md`](./HOWTO-user_window_rules.lua.md).

### 6.6 `user_layer_rules.lua`

`$HOME/.config/hypr/UserConfigs/user_layer_rules.lua`

Las reglas de capas se aplican a superficies que no son ventanas: barras,
lanzadores, demonios de notificaciones, pantallas de bloqueo. El `namespace` es
el espacio de nombres de capa que informa `hyprctl layers`.

Desenfocar rofi y swaync:

```lua
apply_layer_rule({
  name = "user-rofi-blur",
  match = { namespace = "rofi" },
  blur = true,
  ignore_alpha = 0,
})

apply_layer_rule({
  name = "user-swaync-blur",
  match = { namespace = "notifications" },
  blur = true,
})
```

Más detalles: [`HOWTO-user_layer_rules.lua.md`](./HOWTO-user_layer_rules.lua.md).

### 6.7 `user_startup.lua`

`$HOME/.config/hypr/UserConfigs/user_startup.lua`

Comandos que se ejecutan una vez por sesión de Hyprland. Añádalos a la tabla
`startup_commands`; `exec_once` se asegura de que recargar la configuración no
los inicie por segunda vez. La salida de cada comando va a
`/tmp/hypr-lua-user-startup-<cmd>.log`.

```lua
local startup_commands = {
  "$HOME/.config/hypr/scripts/MonitorWatcher.sh",   -- incluido: disposiciones de pantalla
  "kdeconnect-app",
  "blueman-applet",
  "nm-applet --indicator",
  "$HOME/.config/hypr/UserScripts/RainbowBorders.sh",
  "sleep 3; notify-send 'Welcome' 'Hyprland session started'",
}
```

Entradas habituales:

```lua
"pasystray",                                   -- icono de volumen
"udiskie --tray",                              -- montar medios extraíbles automáticamente
"copyq --start-server",                        -- historial del portapapeles
"flatpak run org.telegram.desktop -startintray",
"1password --silent",
"wlsunset -l 37.77 -l -122.41 -t 4000 -T 6500", -- temperatura de color nocturna
```

**No** añada `DisplayProfile.sh` aquí: `MonitorWatcher.sh` ya lo ejecuta, y dos
controladores aplicarían disposiciones al mismo tiempo.

Más detalles: [`HOWTO-Add-Apps-To-user_startup.lua.md`](./HOWTO-Add-Apps-To-user_startup.lua.md).

### 6.8 `user_env.lua`

`$HOME/.config/hypr/UserConfigs/user_env.lua`

Variables de entorno para toda la sesión, con `hl.env("NOMBRE", "valor")`.
Sobreviven a las actualizaciones.

```lua
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GDK_SCALE", "1")
hl.env("QT_SCALE_FACTOR", "1")
hl.env("WEATHER_UNITS", "imperial")     -- clima de Waybar
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("XCURSOR_SIZE", "24")
```

`WEATHER_UNITS` también se cambia desde el menú de ajustes rápidos. Las variables
que deben existir antes de que arranque Hyprland (las del gestor de inicio, por
ejemplo) van en su shell de inicio de sesión o en el archivo de sesión, no aquí.

Usuarios de NVIDIA: revisen las variables comentadas en este archivo y lean las
preguntas frecuentes de la wiki.

Más detalles: [`HOWTO-user_env.lua.md`](./HOWTO-user_env.lua.md).

### 6.9 `user_defaults.lua`

`$HOME/.config/hypr/UserConfigs/user_defaults.lua`

Los programas que llaman los atajos. Cámbielos una vez aquí y cada `$term`,
`$files`, `$edit` y `$visual` de la configuración los seguirá.

```lua
KOOLDOTS_DEFAULTS = KOOLDOTS_DEFAULTS or {}

KOOLDOTS_DEFAULTS.term = "ghostty"          -- SUPER + Return, LaunchTerminal.sh
KOOLDOTS_DEFAULTS.files = "nemo"            -- SUPER + E
KOOLDOTS_DEFAULTS.edit = "nano"             -- editor predeterminado
KOOLDOTS_DEFAULTS.visual = "code"           -- sustituye a edit para editores gráficos
KOOLDOTS_DEFAULTS.search_engine = "https://duckduckgo.com/?q={}"
```

`{}` es el lugar donde va la consulta. Los valores recurren a `$TERMINAL`,
`$EDITOR` y `$VISUAL`, y después a los valores incluidos (`kitty`, `thunar`,
`nano`).

Más detalles: [`HOWTO-user_defaults.lua.md`](./HOWTO-user_defaults.lua.md).

### 6.10 `monitors.lua`

`$HOME/.config/hypr/UserConfigs/monitors.lua`

Modo, posición, escala y transformación de los monitores, un `hl.monitor({...})`
por salida. Los nombres de salida salen de `hyprctl monitors`.

```lua
hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = "1" })
hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144", position = "1920x0", scale = "1" })
hl.monitor({ output = "DP-1", disabled = true })
```

Este archivo también lo escribe el sistema de disposiciones de pantalla
(`scripts/DisplayProfile.sh`) y las disposiciones guardadas con `SUPER + ALT + D`,
así que las ediciones a mano pueden reemplazarse la próxima vez que se aplique
una disposición; guarde la organización como disposición si quiere que se
mantenga. Si ejecuta `nwg-displays` desde el menú de ajustes rápidos, su
organización se importa aquí.

Más detalles: [`HOWTO-monitors.lua.md`](./HOWTO-monitors.lua.md) y
[`README-display-layouts.md`](../README-display-layouts.md).

### 6.11 `workspaces.lua`

`$HOME/.config/hypr/UserConfigs/workspaces.lua`

Reglas de espacio de trabajo. La importante es vincular un espacio de trabajo a
un monitor: sin regla, `SUPER + 1…0` pone el espacio de trabajo en el monitor que
tenga el foco, lo que parece que el espacio de trabajo salta al cambiar de
pantalla.

```lua
hl.workspace_rule({ workspace = "1", monitor = "eDP-1" })
hl.workspace_rule({ workspace = "2", monitor = "eDP-1" })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-1", default = true })
```

Las reglas también pueden llevar `gaps_in`, `gaps_out`, `no_rounding`,
`persistent` y un diseño; consulte `WorkspaceRuleSpec` en
`$HOME/.config/hypr/hl.meta.lua`.

No toque las reglas que terminan en `-- nwg-displays: ...`: ese marcador registra
qué campos pertenecen a la importación de nwg-displays, y la importación solo
reescribe esos. `scripts/PersistWorkspaceLayout.sh` también escribe aquí.

### 6.12 `user_laptops.lua`

`$HOME/.config/hypr/UserConfigs/user_laptops.lua`

Comportamiento específico de portátiles: detecta el panel interno (`eDP`, `LVDS`,
`DSI`), vigila la conexión en caliente y los eventos de la tapa, desactiva el
panel interno cuando la tapa está cerrada con una pantalla externa conectada, y
lo restaura cuando la tapa se abre o se desconecta la pantalla externa. Lee la
disposición desde `monitors.lua`.

Se autogestiona a propósito: enlaza el interruptor de la tapa por sí mismo, así
que nada más debería hacerlo. Déjelo activado y gestione las organizaciones con
`UserConfigs/monitors.lua` o con una disposición de pantalla guardada, en lugar
de editar la lógica de aquí. Las constantes que podría querer están al principio:

```lua
local FALLBACK_INTERNAL = "eDP-1"   -- se usa cuando la detección por sysfs no encuentra nada
```

---

## 7. Aplicar, comprobar y deshacer cambios

**Aplicar.** Guardar cualquier archivo en `$HOME/.config/hypr/` activa
`scripts/LuaConfigWatch.sh`, que recarga la configuración mediante el propio
mecanismo de recarga de Hyprland. Si no pasa nada (no hay `inotify-tools`, o el
vigilante fue terminado):

```bash
hyprctl reload
```

**Comprobar.** Un error de sintaxis Lua impide que un archivo se cargue, y
Hyprland conserva la configuración anterior. Dos formas de detectarlo antes de
cerrar la sesión:

```bash
luac -p "$HOME/.config/hypr/UserConfigs/user_keybinds.lua"   # solo sintaxis
hyprctl reload && hyprctl configerrors                        # de qué se quejó Hyprland
```

`SUPER + SHIFT + E` ejecuta la comprobación con `luac -p` por usted cuando se
cierra el editor.

**Ver a qué se resuelve un atajo.** `SUPER + SHIFT + K` busca entre los atajos
cargados, con la descripción de cada `bind(...)`. `hyprctl binds` imprime la
tabla sin procesar.

**Deshacer.** `UserConfigs` se conserva al actualizar, lo que también significa
que nada sobrescribe un error. Guarde una copia antes de las ediciones grandes:

```bash
cp -r "$HOME/.config/hypr/UserConfigs" "$HOME/.config/hypr/UserConfigs.bak.$(date +%F)"
```

Los archivos también están en el repositorio, así que un `git checkout` sobre un
clon limpio restaura la plantilla original.

**Actualizar.** `copy.sh`, desde el repositorio que ya clonó, actualiza todo lo
que gestionan los dotfiles y deja intactos `UserConfigs` y `UserScripts`.
Consulte [`HOWTO-Upgrade-Dotfiles.md`](./HOWTO-Upgrade-Dotfiles.md).

---

## 8. El panel de red / Bluetooth

El icono de la derecha de Waybar (`custom/qs-network`) abre un panel de Quickshell
para las conexiones cableadas, inalámbricas y Bluetooth. El clic izquierdo lo
muestra u oculta, el clic derecho sigue abriendo `nmtui`. No tiene atajo
predeterminado; añada uno en `user_keybinds.lua` si lo quiere en el teclado:

```lua
bind("SUPER CTRL", "N", exec_cmd("$HOME/.config/hypr/scripts/QsNetworkPanel.sh toggle"),
  { description = "Panel de red" })
```

El panel permanece oculto hasta que se abre, se despliega en la esquina superior
derecha bajo el módulo, y se cierra con su botón 󰅖, con el mismo clic de Waybar o
con un clic en cualquier punto fuera de él.

Cada pestaña cubre un tipo de dispositivo: Ethernet, Wi-Fi y Bluetooth, más
Tailscale, Docker y Podman cuando esas herramientas o sus interfaces existen. Al
hacer clic en un dispositivo o en una red se conecta o se desconecta; una red
Wi-Fi protegida pide la contraseña en el propio panel. El bloque de información
muestra Dirección, Puerta de enlace, DNS y MAC del enlace activo, con todas las
direcciones de esa interfaz, alias incluidos.

Hay dos situaciones que conviene conocer, porque el panel se comporta distinto:

- **NetworkManager no gestiona la NIC.** Algunas imágenes de máquina virtual
entregan la interfaz a `/etc/network/interfaces`, y NetworkManager la informa
como `unmanaged`; antes la pestaña Ethernet quedaba vacía. Ahora el dispositivo
aparece en solo lectura, con la dirección, la puerta de enlace y la MAC que
informa el kernel, y sin Conectar/Desconectar en esa fila. Cómo pasar la NIC a
NetworkManager se describe en
[`network-widget/README.md`](../config/quickshell/network-widget/README.md).
- **Falta `nmcli`.** La lista cableada se lee de `ip` y `/sys/class/net` en vez
de quedar vacía, el pie explica el motivo en el color de error y se envía una
notificación por sesión indicando lo que falta. Instale `networkmanager` para
recuperar el panel completo.

El DNS se lee de `/etc/resolv.conf`; cuando systemd-resolved deja allí solo su
stub `127.0.0.53`, el panel pregunta a `resolvectl` por los servidores reales.

---

## 9. Lecturas adicionales

Las guías HOWTO por archivo están en `docs/`:

| Tema                                   | Documento                                                                                                        |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Atajos de teclado                      | [`HOWTO-Change-Keybindgs.md`](./HOWTO-Change-Keybindgs.md), [`Keybinds.md`](./Keybinds.md)                       |
| Asignaciones de teclado                | [`HOWTO-Keyboard-Mappings.md`](./HOWTO-Keyboard-Mappings.md)                                                     |
| Ajustes y entrada                      | [`HOWTO-user_settings.lua.md`](./HOWTO-user_settings.lua.md)                                                     |
| Decoraciones                           | [`HOWTO-user_decorations.lua.md`](./HOWTO-user_decorations.lua.md)                                               |
| Reglas de ventana                      | [`HOWTO-user_window_rules.lua.md`](./HOWTO-user_window_rules.lua.md)                                             |
| Reglas de capa                         | [`HOWTO-user_layer_rules.lua.md`](./HOWTO-user_layer_rules.lua.md)                                               |
| Aplicaciones de inicio                 | [`HOWTO-Add-Apps-To-user_startup.lua.md`](./HOWTO-Add-Apps-To-user_startup.lua.md)                               |
| Entorno                                | [`HOWTO-user_env.lua.md`](./HOWTO-user_env.lua.md)                                                               |
| Valores predeterminados                | [`HOWTO-user_defaults.lua.md`](./HOWTO-user_defaults.lua.md)                                                     |
| Monitores                              | [`HOWTO-monitors.lua.md`](./HOWTO-monitors.lua.md)                                                               |
| Disposiciones de pantalla              | [`README-display-layouts.md`](../README-display-layouts.md)                                                      |
| Submapas                               | [`HOWTO-Use-Submap-template.md`](./HOWTO-Use-Submap-template.md)                                                 |
| Módulos e iconos de Waybar             | [`HOWTO-Add-New-Application-Icons-ModulesWorkspaces.md`](./HOWTO-Add-New-Application-Icons-ModulesWorkspaces.md) |
| Temas e iconos                         | [`HOWTO-Override-Theme-and-Icons.md`](./HOWTO-Override-Theme-and-Icons.md)                                       |
| Actualizaciones                        | [`HOWTO-Upgrade-Dotfiles.md`](./HOWTO-Upgrade-Dotfiles.md)                                                       |
| Comportamiento de los parches en `UserConfigs` | [`Patching-UserConfigs.md`](./Patching-UserConfigs.md)                                                   |
| Migrar Waybar a Hyprland               | [`HOWTO-Migrate-Waybar-To-Hypr.md`](./HOWTO-Migrate-Waybar-To-Hypr.md)                                           |

En línea:

- Inicio de la wiki: <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki>
- Instalación y actualización: <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Install_&_Update>
- Atajos de teclado: <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Keybinds>
- Paquetes necesarios: <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Packages_Required>
- Registro de cambios: <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Changelogs>
- Preguntas frecuentes (NVIDIA): <https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/FAQ_NVIDIA>
- Documentación propia de Hyprland: <https://wiki.hypr.land/>
