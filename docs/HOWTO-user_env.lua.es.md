# Cómo configurar variables de entorno en KoolDots (`user_env.lua`)

En **KoolDots (2026)** con el flujo de configuración en Lua, todas las variables de entorno personales de la sesión (temas para kits de herramientas, escalado de interfaz, controladores gráficos y unidades de widgets) se administran en:

```
~/.config/hypr/UserConfigs/user_env.lua
```

Esta guía explica cómo funcionan las variables de entorno en Hyprland Lua, cómo interactúan los valores del sistema con las preferencias del usuario y ofrece ejemplos prácticos para integraciones de hardware y software comunes.

---

## 1. Descripción general y arquitectura

### Variables de entorno del sistema vs. del usuario

- **Entorno del sistema (`~/.config/hypr/configs/system_env.lua` y `lua/environment.lua`)**:
  Configura las variables base de Wayland (como `XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE`, `MOZ_ENABLE_WAYLAND`, `ELECTRON_OZONE_PLATFORM_HINT`, etc.).
- **Entorno del usuario (`~/.config/hypr/UserConfigs/user_env.lua`)**:
  Se carga para aplicar variables de entorno adicionales o modificaciones personales. Los datos aquí definidos se conservan tras las actualizaciones de KoolDots.

### Sintaxis de la función `hl.env()`

Las variables de entorno se definen en Lua utilizando la función `hl.env()`:

```lua
hl.env("NOMBRE_DE_VARIABLE", "VALOR")
```

---

## 2. Instrucciones paso a paso

### Paso 1: Abrir `user_env.lua`
Abra el archivo en su editor preferido:

```bash
nano ~/.config/hypr/UserConfigs/user_env.lua
# o
nvim ~/.config/hypr/UserConfigs/user_env.lua
```

### Paso 2: Agregar sus variables de entorno
Utilice `hl.env("CLAVE", "VALOR")` para declarar las variables deseadas.

```lua
-- Ejemplo: Motor de temas de Qt
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
```

### Paso 3: Guardar y aplicar
Dado que muchas variables de entorno son leídas por las aplicaciones al iniciarse:
- Para pruebas inmediatas: Ejecute `hyprctl reload` o presione `SUPER + ALT + R`.
- Para propagación completa a todas las aplicaciones gráficas: Cierre sesión y vuelva a iniciarla en Hyprland.

---

## 3. Ejemplos prácticos

### Ejemplo A: Personalización de temas en Qt y GTK

```lua
-- Forzar a las aplicaciones Qt a usar la configuración de qt6ct / qt5ct
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Forzar estilo de Qt (ej. kvantum, Fusion)
hl.env("QT_STYLE_OVERRIDE", "kvantum")

-- Habilitar escalado automático de pantalla en aplicaciones Qt
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
```

### Ejemplo B: Factores de escala y pantallas HiDPI

```lua
-- Escala de GTK / GDK
hl.env("GDK_SCALE", "1")

-- Factor de escala de Qt
hl.env("QT_SCALE_FACTOR", "1")

-- Escala de interfaz para aplicaciones Java / JetBrains
hl.env("_JAVA_OPTIONS", "-Dsun.java2d.uiScale=1")
```

### Ejemplo C: Tema y tamaño del cursor

```lua
-- Configuración de cursor para Hyprland
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")

-- Respaldo de XCursor para aplicaciones XWayland / GTK antiguas
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
```

### Ejemplo D: Ajustes para controladores propietarios de NVIDIA

Si utiliza una tarjeta gráfica NVIDIA con controladores privativos:

```lua
-- Aceleración de video por hardware
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- Corrección si el cursor se vuelve invisible en NVIDIA
-- hl.env("WLR_NO_HARDWARE_CURSORS", "1")
```

### Ejemplo E: Widgets y unidades de KoolDots

```lua
-- Unidades para el pronóstico del clima ("metric" para °C/km/h o "imperial" para °F/mph)
hl.env("WEATHER_UNITS", "metric")
```

---

## 4. Solución de problemas y verificación

1. **Verificar variables cargadas**:
   En la terminal, compruebe si una variable de entorno se exportó correctamente:
   ```bash
   echo $QT_QPA_PLATFORMTHEME
   echo $WEATHER_UNITS
   ```

2. **Comprobar sintaxis de Lua**:
   ```bash
   luac -p ~/.config/hypr/UserConfigs/user_env.lua
   ```
