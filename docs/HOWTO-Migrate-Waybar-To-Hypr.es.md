# Cómo migrar Waybar y sus colores de Wallust a la nueva ruta

Waybar se movió de `~/.config/waybar` a `~/.config/hypr/waybar`. Todo lo que
importa la paleta de Wallust que genera Waybar tuvo que actualizarse junto con
él. `swaync` es el que más se suele pasar por alto, porque su `style.css` es un
archivo propiedad del usuario que nunca se sobrescribe al actualizar.

## Qué cambió

- Waybar ahora está en `~/.config/hypr/waybar` (`configs/`, `style/`, `Modules`,
  `wallust/`). El antiguo `~/.config/waybar` ya no existe.
- El destino de la paleta de Wallust es el mismo en contenido, pero ahora vive en
  `~/.config/hypr/waybar/wallust/colors-waybar.css` (vea la entrada
  `waybar.target` en `~/.config/hypr/wallust/wallust.toml`).
- Cualquier archivo que importe esos colores con un `@import` **relativo** debe
  apuntar a la nueva ubicación.

## Las dos cosas que se rompen

1. **Profundidad relativa incorrecta.** GTK resuelve un `@import` relativo
   tomando como base el directorio del archivo que lo importa, y cada consumidor
   está a una profundidad distinta. Por eso un buscar-y-reemplazar global en el
   repositorio no puede ser correcto: cada archivo necesita su propio número de
   `../`:

   | Archivo (ruta instalada) | Import correcto |
   | --- | --- |
   | `~/.config/swaync/style.css` | `../../.config/hypr/waybar/wallust/colors-waybar.css` |
   | `~/.config/wlogout/style.css` | `../../.config/hypr/waybar/wallust/colors-waybar.css` |
   | `~/.config/ags/user/style.css` | `../../../.config/hypr/waybar/wallust/colors-waybar.css` |
   | `~/.config/hypr/waybar/style.css` (enlace simbólico a `style/`) | `../../../.config/hypr/waybar/wallust/colors-waybar.css` |

   Los estilos de Waybar están escritos para la última fila a propósito: en
   tiempo de ejecución siempre se cargan mediante el enlace simbólico
   `~/.config/hypr/waybar/style.css`, así que tres niveles arriba es `$HOME`.

2. **Punto y coma faltante.** Una línea `@import` debe terminar en `;`. Sin él,
   GTK registra un error de análisis de CSS e ignora el import, por lo que la
   paleta nunca se aplica en silencio.

## Síntoma

El centro de control y las notificaciones de swaync se muestran con sus colores
predeterminados en lugar de la paleta del fondo de pantalla, mientras que
Waybar se ve correctamente. En los registros puede aparecer un error de análisis
de CSS/`@import`. El culpable habitual es una línea obsoleta como:

```css
@import '../../.config/waybar/wallust/colors-waybar.css';
```

Esa ruta ya no existe, así que `colors-waybar.css` nunca se carga.

## Waybar conserva los colores del fondo de pantalla anterior

Este caso se parece al anterior pero tiene otra causa: el import está bien y el
archivo de la paleta se regenera en cada cambio de fondo de pantalla, sin
embargo la barra sigue mostrando el tema anterior mientras los bordes de las
ventanas cambian.

Waybar no vigila su hoja de estilos: sólo vuelve a leer `style.css` cuando se
recarga. Los bordes, en cambio, se aplican dentro de Hyprland mediante
`WallustSwww.sh` (`hl.config` por `hyprctl eval`), así que se actualizan de
inmediato. Por eso, cualquier cosa que regenere la paleta sin recargar Waybar
deja la barra atrás:

- la rotación automática de fondos de pantalla (`WallpaperAutoChange.sh` -
  `RefreshNoWaybar.sh`), que por diseño no toca Waybar; y
- `WallpaperEffects.sh` y `WallpaperDaemon.sh`, que no ejecutan ninguna
  actualización.

`WallustSwww.sh` ahora recarga por sí mismo la barra en ejecución cuando la
paleta ya está escrita (`waybar-msg cmd reload`, con `SIGUSR2` como alternativa),
de modo que la barra sigue el fondo de pantalla en todas las rutas. Si la barra
no está en ejecución, se deja el arranque a `WaybarStartup.sh`, que lo
serializa con su propio bloqueo; además, la recarga es una señal y no un
reinicio: la barra nunca se destruye.

Para recargar la barra manualmente:

```sh
waybar-msg cmd reload || pkill -SIGUSR2 -x waybar
```

`~/.config/hypr/scripts/Refresh.sh` (recarga completa, reinicia la barra) y
`ThemeChanger.sh` hacen lo mismo en sus propios flujos.

## Migración automática

Ejecute la actualización habitual y reinicie:

```sh
cd ~/Hyprland-Dots
git stash && git pull
./copy.sh --express-upgrade
reboot
```

o desde el menú: `copy.sh` y seleccione `Express update`, seguido de `reboot`.

Se hacen dos cosas por usted:

- `copy.sh` instala Waybar en la nueva ruta, restaura la selección de
  disposición/estilo y repara automáticamente cualquier referencia
  `$HOME/.config/waybar/...` que quede en el directorio instalado de Waybar.
- `patches/30-swaync-wallust-import.sh` reescribe el `@import` de Wallust en
  `~/.config/swaync/style.css` con la ruta canónica (y añade el `;` faltante).
- `patches/40-waybar-wallust-import.sh` hace lo mismo con los estilos de Waybar
  instalados en `~/.config/hypr/waybar/style/`. `copy.sh` ya actualiza ese
  directorio, pero la acción de actualización del menú no lo hace, así que este
  parche cubre esa vía.

Los parches se ejecutan en la instalación, la actualización, la actualización
express y la acción de actualización del menú, por lo que ambas correcciones
también llegan a las instalaciones que se actualizan en el sitio.

## Migración manual

Use esto para instalaciones de NixOS/Home Manager, copias de la configuración
gestionadas a mano, o simplemente cuando quiera verificar que la actualización
hizo lo correcto.

1. Confirme que el movimiento se realizó:

   ```sh
   ls -ld ~/.config/hypr/waybar ~/.config/waybar 2>&1
   ls -l ~/.config/hypr/waybar/style.css
   ```

   `~/.config/waybar` debería haber desaparecido (se migra y se elimina), y
   `~/.config/hypr/waybar/style.css` debería ser un enlace simbólico a
   `~/.config/hypr/waybar/style/`.

2. Compruebe qué importa swaync:

   ```sh
   grep -n '@import' ~/.config/swaync/style.css
   ```

   La línea de Wallust debe ser exactamente:

   ```css
   @import '../../.config/hypr/waybar/wallust/colors-waybar.css';
   ```

3. Si todavía apunta a la ubicación antigua, corríjala en el sitio (haga copia
   de seguridad primero):

   ```sh
   cp -a ~/.config/swaync/style.css ~/.config/swaync/style.css.bak
   sed -i -E "s#(@import[[:space:]]*['\"])[^'\"]*waybar/wallust/colors-waybar\.css(['\"])#\1../../.config/hypr/waybar/wallust/colors-waybar.css\2#" \
     ~/.config/swaync/style.css
   sed -i -E "s#(@import[[:space:]]*['\"][^'\"]*waybar/wallust/colors-waybar\.css['\"]);?#\1;#" \
     ~/.config/swaync/style.css
   grep -n 'colors-waybar' ~/.config/swaync/style.css
   ```

4. Asegúrese de que la paleta exista: se genera, no se distribuye:

   ```sh
   ls -l ~/.config/hypr/waybar/wallust/colors-waybar.css
   ```

   Si falta, regenérela a partir del fondo de pantalla actual:

   ```sh
   ~/.config/hypr/scripts/WallustSwww.sh
   ```

5. Recargue swaync (la misma recarga que usa el repositorio en `Refresh.sh`):

   ```sh
   swaync-client -R -rs --skip-wait
   ```

   En un swaync gestionado por systemd, `systemctl --user restart swaync.service`
   también funciona.

6. Aplique las mismas comprobaciones a los demás consumidores sólo si los editó
   a mano: `copy.sh` actualiza `wlogout` y los estilos de Waybar por usted, y
   `patches/40-waybar-wallust-import.sh` los repara en las actualizaciones en el
   sitio. Use la tabla anterior para saber cuántos `../` necesita cada archivo.

7. Si la barra muestra los colores del fondo de pantalla anterior, significa que
   el archivo de la paleta se está escribiendo pero la barra nunca se recargó:
   vea "Waybar conserva los colores del fondo de pantalla anterior" más arriba y
   recárguela con `waybar-msg cmd reload` (o `pkill -SIGUSR2 -x waybar`).

## Relacionados

- `docs/HOWTO-Upgrade-Dotfiles.md`: el flujo de actualización estándar.
- `docs/Patching-UserConfigs.md`: cómo funciona el mecanismo de parches y cómo
  añadir uno.
