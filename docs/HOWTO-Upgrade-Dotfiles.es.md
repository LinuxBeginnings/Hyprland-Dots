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
