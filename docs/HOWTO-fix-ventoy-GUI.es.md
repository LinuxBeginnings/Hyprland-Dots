# Cómo solucionar el problema con la interfaz gráfica (GUI) de Ventoy en Wayland/Hyprland (con Sudo/Polkit sin contraseña)

Si utiliza Wayland (como Hyprland, Sway o Wayfire) y tiene privilegios de root sin contraseña (por ejemplo, su usuario pertenece al grupo `wheel` con `NOPASSWD` configurado en sudo/polkit), es posible que experimente un problema donde la aplicación gráfica de Ventoy se cierra silenciosamente o vuelve a la línea de comandos inmediatamente al iniciarse.

## El problema

Cuando `pkexec` eleva sus privilegios a root, elimina agresivamente las variables de entorno por motivos de seguridad. En X11 esto a veces funciona sin problemas, pero en Wayland, las aplicaciones gráficas necesitan variables de entorno específicas para saber cómo conectarse al servidor de pantalla.

Debido a que `pkexec` descarta variables como `WAYLAND_DISPLAY` y `XDG_RUNTIME_DIR`, la GUI de Ventoy (`ventoygui`) se inicia como root, no encuentra el servidor de pantalla y falla de inmediato.

## La solución

Para corregir esto, debemos pasar explícitamente las variables de pantalla necesarias al entorno de `pkexec` al iniciar Ventoy.

Existen dos formas principales de abrir aplicaciones: desde un lanzador gráfico (como Rofi, Wofi o el menú de su entorno de escritorio) y desde la línea de comandos (Terminal). A continuación se detallan las soluciones para ambos casos.

---

### Parte 1: Corregir lanzadores de aplicaciones (Rofi, Wofi, Menús de aplicaciones)

Los lanzadores de aplicaciones utilizan archivos `.desktop`. Crearemos una anulación local para el archivo `.desktop` de Ventoy y lo apuntaremos a un script envoltorio (*wrapper*) personalizado que preserve las variables de entorno.

#### 1. Crear el script envoltorio

Cree un script en su directorio local `bin` (cree el directorio si no existe):

```bash path=null start=null
mkdir -p ~/.local/bin
```

Cree el script envoltorio utilizando su editor de texto favorito (por ejemplo, `nano ~/.local/bin/ventoygui-wayland`) y añada el siguiente contenido:

```sh path=null start=null
#!/bin/sh
pkexec env DISPLAY=$DISPLAY WAYLAND_DISPLAY=$WAYLAND_DISPLAY XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR GTK_THEME=Adwaita:dark /usr/bin/ventoygui "$@"
```

Haga el script ejecutable:

```bash path=null start=null
chmod +x ~/.local/bin/ventoygui-wayland
```

#### 2. Crear la anulación del archivo `.desktop`

Copie el archivo `.desktop` global de Ventoy a su carpeta local de aplicaciones:

```bash path=null start=null
mkdir -p ~/.local/share/applications/
cp /usr/share/applications/ventoy.desktop ~/.local/share/applications/ventoy.desktop
```

Edite la copia local (`~/.local/share/applications/ventoy.desktop`) y modifique la línea `Exec=` para que apunte al nuevo script. **Asegúrese de reemplazar `USERNAME` con su nombre de usuario real:**

```ini path=null start=null
[Desktop Entry]
Type=Application
Icon=ventoy
Name=Ventoy
Exec=/home/USERNAME/.local/bin/ventoygui-wayland
Terminal=false
Hidden=false
Categories=Utility
Comment=Ventoy2Disk GUI
StartupWMClass=Ventoy2Disk.gtk3
```

Por último, actualice la base de datos del escritorio para que los lanzadores como Rofi detecten el cambio inmediatamente:

```bash path=null start=null
update-desktop-database ~/.local/share/applications
```

---

### Parte 2: Corregir la línea de comandos (Terminal)

Si escribe `ventoygui` en su terminal, seguirá ejecutando el binario original que falla. Para solucionar esto, podemos configurar un alias o función en el shell.

Añada el fragmento correspondiente a continuación al archivo de configuración de su shell.

#### Para Bash o Zsh

Añada esto al final de `~/.bashrc` (para Bash) o `~/.zshrc` (para Zsh):

```bash path=null start=null
# Corrección para VentoyGUI en Wayland/Hyprland
alias ventoygui='pkexec env DISPLAY=$DISPLAY WAYLAND_DISPLAY=$WAYLAND_DISPLAY XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR /usr/bin/ventoygui'
```

Aplique los cambios:

```bash path=null start=null
# Para Bash
source ~/.bashrc

# Para Zsh
source ~/.zshrc
```

#### Para Fish

Añada esto al final de `~/.config/fish/config.fish`:

```fish path=null start=null
# Corrección para VentoyGUI en Wayland/Hyprland
function ventoygui
    sh -c 'pkexec env DISPLAY=$DISPLAY WAYLAND_DISPLAY=$WAYLAND_DISPLAY XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR /usr/bin/ventoygui $argv'
end
```

Aplique los cambios:

```fish path=null start=null
source ~/.config/fish/config.fish
```

## ¡Listo!

Ahora debería poder iniciar la GUI de Ventoy tanto desde su terminal como desde su lanzador de aplicaciones sin ningún problema bajo Wayland.
