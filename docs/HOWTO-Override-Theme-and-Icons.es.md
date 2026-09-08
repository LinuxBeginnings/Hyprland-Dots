# Cómo personalizar temas GTK, iconos y cursores (`user_env.lua`)

En **KoolDots (2026)**, el entorno de escritorio adapta automáticamente los temas y colores según los fondos de pantalla o los perfiles dinámicos. Si prefiere **fijar un tema GTK específico, un paquete de iconos o un tema de cursor** para que se aplique de forma consistente en todas las aplicaciones, puede definir variables de entorno persistentes en:

```
~/.config/hypr/UserConfigs/user_env.lua
```

Esta guía explica cómo editar su archivo de entorno de usuario, añadir las variables de apariencia y proporciona ejemplos paso a paso.

---

## 1. Descripción general y variables principales

Al agregar variables de apariencia a `user_env.lua`, estas se exportan a su sesión y se conservan tras todas las actualizaciones del sistema.

### Variables de apariencia admitidas

| Variable | Destino | Valores de ejemplo | Descripción |
|---|---|---|---|
| `GTK_THEME` | GTK 3 y GTK 4 | `"Nordic"`, `"Adwaita-dark"`, `"Catppuccin-Mocha"` | Fuerza un tema de controles GTK fijo en todas las aplicaciones GTK. |
| `ICON_THEME` | Kits / Apps | `"Papirus-Dark"`, `"Tela-circle-dracula"`, `"Flat-Remix-Blue-Dark"` | Especifica el tema de iconos predeterminado para aplicaciones y Flatpaks. |
| `GTK_ICON_THEME` | GTK Fallback | `"Papirus-Dark"`, `"Adwaita"` | Definición explícita de iconos para entornos de sesión GTK. |
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

## 3. Entradas de configuración y ejemplos

Añada las opciones deseadas utilizando la función `hl.env("CLAVE", "VALOR")`:

### Ejemplo A: Estilo Nordic Oscuro (Nordic + Papirus-Dark)

```lua
-- Forzar tema GTK específico
hl.env("GTK_THEME", "Nordic")

-- Forzar tema de Iconos específico
hl.env("ICON_THEME", "Papirus-Dark")
hl.env("GTK_ICON_THEME", "Papirus-Dark")

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

-- Forzar tema de Iconos
hl.env("ICON_THEME", "Papirus-Dark")
hl.env("GTK_ICON_THEME", "Papirus-Dark")

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

-- Iconos estándar Adwaita
hl.env("ICON_THEME", "Adwaita")
hl.env("GTK_ICON_THEME", "Adwaita")

-- Cursor estándar
hl.env("HYPRCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_SIZE", "24")
```

---

## 4. Aplicar y verificar los cambios

1. **Guardar el archivo**:
   Guarde sus cambios y cierre el editor de texto.
2. **Recargar Hyprland**:
   Presione `SUPER + ALT + R` o ejecute:
   ```bash
   hyprctl reload
   ```
3. **Cerrar e iniciar sesión**:
   Dado que las variables de entorno son leídas por las aplicaciones al ejecutarse, cierre sesión (`CTRL + ALT + Delete`) y vuelva a iniciarla en Hyprland para que todos los programas gráficos adopten la nueva configuración.
4. **Verificación**:
   Abra una terminal y confirme que las variables están activas:
   ```bash
   echo $GTK_THEME
   echo $ICON_THEME
   echo $HYPRCURSOR_THEME
   ```
