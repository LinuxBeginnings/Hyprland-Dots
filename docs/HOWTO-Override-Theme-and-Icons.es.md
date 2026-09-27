# Cómo personalizar temas GTK, cursores e iconos

En **KoolDots (2026)**, el entorno de escritorio adapta automáticamente los temas y colores según los fondos de pantalla o los perfiles dinámicos. Si prefiere **fijar un tema GTK específico, tema de cursor o conjunto de iconos** para que se aplique de forma consistente en todas las aplicaciones, esta guía explica cómo configurar modificaciones persistentes.

> **Nota importante sobre los iconos:**
> Ni GTK ni Qt admiten variables de entorno (como `ICON_THEME` o `GTK_ICON_THEME`) para temas de iconos; las aplicaciones simplemente las ignorarán. Los temas de iconos deben configurarse mediante **`nwg-look`**, **`gsettings`** o **archivos de configuración de GTK/Qt** tal como se describe en la [Sección 4](#4-cómo-cambiar-y-fijar-temas-de-iconos).

---

## 1. Descripción general de variables de entorno (`user_env.lua`)

Al agregar variables de apariencia a `~/.config/hypr/UserConfigs/user_env.lua`, estas se exportan a su sesión y se conservan tras todas las actualizaciones del sistema.

### Variables de apariencia admitidas

| Variable | Destino | Valores de ejemplo | Descripción |
|---|---|---|---|
| `GTK_THEME` | GTK 3 y GTK 4 | `"Nordic"`, `"Adwaita-dark"`, `"Catppuccin-Mocha"` | Fuerza un tema de controles GTK fijo en todas las aplicaciones GTK. |
| `HYPRCURSOR_THEME` | Hyprland | `"Bibata-Modern-Classic"`, `"Bibata-Modern-Ice"` | Tema de cursor acelerado por hardware para el compositor Hyprland. |
| `HYPRCURSOR_SIZE` | Hyprland | `"24"`, `"28"`, `"32"` | Tamaño del cursor en píxeles para Hyprland. |
| `XCURSOR_THEME` | GTK y XWayland | `"Bibata-Modern-Classic"`, `"Bibata-Modern-Ice"` | Tema de cursor de respaldo para aplicaciones XWayland y GTK. |
| `XCURSOR_SIZE` | GTK y XWayland | `"24"`, `"28"`, `"32"` | Tamaño del cursor de respaldo en píxeles para XWayland y GTK. |

---

## 2. Paso a paso: Cómo editar `user_env.lua`

### Método A: Mediante los Ajustes Rápidos (Recomendado)

1. Presione `SUPER + SHIFT + E` en su teclado para abrir el menú **Kool Quick Settings**.
2. Seleccione **`[[ User Settings ]]`** en el menú de categorías.
3. Seleccione **`Edit User ENV variables`**.
4. El archivo `~/.config/hypr/UserConfigs/user_env.lua` se abrirá automáticamente en su editor predeterminado.

### Método B: Desde la terminal

Abra una terminal y edite el archivo directamente:

```bash
nano ~/.config/hypr/UserConfigs/user_env.lua
# o
nvim ~/.config/hypr/UserConfigs/user_env.lua
```

---

## 3. Entradas de configuración y ejemplos (`user_env.lua`)

Añada las opciones deseadas utilizando la función `hl.env("CLAVE", "VALOR")`:

### Ejemplo A: Estilo Nordic Oscuro

```lua
-- Forzar tema GTK específico
hl.env("GTK_THEME", "Nordic")

-- Forzar tema y tamaño de cursor
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_SIZE", "24")
```

### Ejemplo B: Estilo Catppuccin Mocha

```lua
-- Forzar tema GTK Catppuccin
hl.env("GTK_THEME", "Catppuccin-Mocha-Standard-Blue-Dark")

-- Forzar tema y tamaño de cursor
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_SIZE", "24")
```

### Ejemplo C: Estilo estándar GNOME / Adwaita Dark

```lua
-- Forzar tema Adwaita Dark
hl.env("GTK_THEME", "Adwaita-dark")

-- Cursor estándar
hl.env("HYPRCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_SIZE", "24")
```

---

## 4. Cómo cambiar y fijar temas de iconos

Dado que los temas de iconos no se controlan mediante variables de entorno, use uno de los siguientes métodos para cambiar su tema de iconos:

### Método A: Mediante `nwg-look` (Interfaz gráfica recomendada)

1. Abra **Kool Quick Settings** (`SUPER + SHIFT + E`), diríjase a **`[[ Misc ]]`** y seleccione **`GTK Settings (nwg-look)`** (o ejecute `nwg-look` en una terminal).
2. Vaya a la pestaña **Icon Theme**.
3. Seleccione el tema de iconos deseado (ej. `candy-icons`, `Papirus-Dark`).
4. Haga clic en **Apply**.

Esto actualiza simultáneamente `gsettings`, `~/.config/gtk-3.0/settings.ini`, `~/.config/gtk-4.0/settings.ini` y `xsettingsd`.

### Método B: Mediante terminal (`gsettings` / `dconf`)

Ejecute el siguiente comando para establecer el tema de iconos en el escritorio GTK/GNOME y los portales:

```bash
gsettings set org.gnome.desktop.interface icon-theme 'candy-icons'
```

En NixOS o sistemas que utilicen dconf directamente:

```bash
dconf write /org/gnome/desktop/interface/icon-theme "'candy-icons'"
```

### Método C: Mediante archivos de configuración de GTK

Asegúrese de que el tema de iconos esté configurado en `~/.config/gtk-3.0/settings.ini` y `~/.config/gtk-4.0/settings.ini`:

```ini
[Settings]
gtk-icon-theme-name = candy-icons
```

### Método D: Para aplicaciones Qt

KoolDots configura aplicaciones Qt con `qt6ct` (`hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")`). Para establecer el tema de iconos en aplicaciones Qt:
1. Ejecute `qt6ct` (o `qt5ct`).
2. Vaya a la pestaña **Icon Theme**, seleccione su tema de iconos y haga clic en **Apply**.

---

## 5. Aplicar y verificar los cambios

1. **Guardar los archivos**:
   Guarde cualquier edición realizada en `user_env.lua` o en los archivos de configuración.
2. **Recargar Hyprland**:
   Presione `SUPER + ALT + R` o ejecute:
   ```bash
   hyprctl reload
   ```
3. **Cerrar e iniciar sesión**:
   Dado que las variables de entorno son leídas por las aplicaciones al ejecutarse, cierre sesión (`CTRL + ALT + Delete`) y vuelva a iniciarla en Hyprland para que todos los programas gráficos adopten la nueva configuración.
4. **Verificación**:
   Abra una terminal y confirme la configuración activa:
   ```bash
   echo $GTK_THEME
   echo $HYPRCURSOR_THEME
   gsettings get org.gnome.desktop.interface icon-theme
   ```
