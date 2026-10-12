# Cómo actualizar los instaladores y dotfiles de KoolDots

- Al actualizar los dotfiles, actualice primero el instalador
  - Esto garantiza que se instalen las dependencias nuevas o actualizadas
    - Elimine las versiones antiguas del instalador de su distribución
      - Por ejemplo: `Arch-Hyprland` o `Debian-Hyprland`
      - `rm -r ~/Arch-Hyprland` (o la distribución que esté utilizando)
      - Clone el instalador más reciente para su distribución.

```sh
 git clone https://github.com/Linuxbeginnings/Arch-Hyprland --depth 1
 cd ~/Arch-Hyprland
 install-scripts/update-deps.sh
```

- Elimine el directorio antiguo de `Hyprland-Dots` si corresponde
  - Clone la versión más reciente de Hyprland-Dots

```sh
   git clone https://github.com/Linuxbeginnings/Hyprland-Dots  --depth 1
   cd ~/Hyprland-Dots
   ./copy.sh
   seleccione `Express update`
```

- `Express update` es más rápido y muchas de las preguntas de restauración ya no son necesarias
- Especialmente al migrar desde los archivos de configuración antiguos en `Hyprlang` a los archivos de configuración en `LUA`
- Un atajo útil es:
  `./copy.sh --express-upgrade`
  - También hay disponible un menú simple en `TTY`:
    - `./copy.sh --tty --express-upgrade`

- Si no hubo errores, reinicie el sistema con `reboot`

| Nota: Si desea mantener limpio su directorio personal ($HOME), puede mover estos directorios

- Para usuarios más familiarizados con `git`:
  - Ejecute:
    - Arch se muestra aquí como ejemplo:

    ```sh
      cd ~/Arch-Hyprland
      git stash && git pull
      install-scripts/update-deps.sh
      cd ~/Hyprland-Dots
      git stash && git pull
      ./copy.sh
      seleccione Express Upgrade
    ```

  | Nota: Este método puede generar ocasionalmente conflictos de fusión (`merge`) en `git`. El método anterior siempre funciona

## Qué conserva una actualización

Una actualización reemplaza la configuración gestionada por el repositorio con
la copia del repositorio y luego vuelve a poner encima sus propias elecciones.
Se conservan:

- el tema de rofi del selector de temas: la línea `@theme` en
  `hypr/rofi/config.rasi`
- el preset de wlogout del selector de wlogout: `wlogout/.current_theme`,
  incluido un `user_backup` guardado
- sus disposiciones de pantalla guardadas: `UserConfigs/display-layouts.json`
- todo lo que hay en `UserConfigs/`, `UserScripts/` y `Monitor_Profiles/`
- `hyprlock.conf`, `hypridle.conf` y `wallpaper_effects/`

Todo lo que edite a mano dentro de un archivo gestionado por el repositorio que
el instalador reescribe se sigue reemplazando. Guarde sus cambios personales en
los directorios indicados arriba.
