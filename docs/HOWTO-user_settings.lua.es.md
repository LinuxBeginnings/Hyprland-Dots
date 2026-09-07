# Cómo configurar ajustes de usuario en KoolDots (`user_settings.lua`)

En **KoolDots (2026)** con el flujo de configuración en Lua, todas las preferencias de dispositivos de entrada, distribución de teclado, comportamiento del touchpad, sensibilidad del cursor y opciones generales del compositor se administran en:

```
~/.config/hypr/UserConfigs/user_settings.lua
```

Esta guía explica cómo interactúa `user_settings.lua` con la configuración del sistema, enumera todas las opciones configurables y ofrece ejemplos paso a paso.

---

## 1. Descripción general y arquitectura

### Ajustes del sistema vs. Ajustes del usuario

- **Ajustes del sistema (`~/.config/hypr/configs/system_settings.lua` y `lua/settings.lua`)**:
  Define el comportamiento base del entorno, reglas de arrastrar y soltar (*drag and drop*), tipos de distribución de ventanas (*dwindle* / *master*) y configuración inicial de entrada.
- **Ajustes del usuario (`~/.config/hypr/UserConfigs/user_settings.lua`)**:
  Se carga para aplicar las personalizaciones de entrada del usuario (como idiomas del teclado, desplazamiento del touchpad, aceleración del ratón y control del cursor). Las opciones aquí definidas se conservan tras las actualizaciones de KoolDots.

### Estructura de `hl.config()`

Los ajustes de usuario se definen dentro de la tabla anidada `hl.config({...})`:

```lua
hl.config({
  input = {
    kb_layout = "us,es",
    repeat_rate = 50,
    repeat_delay = 300,
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
    },
  },
  cursor = {
    no_warps = true,
  },
})
```

---

## 2. Opciones de configuración admitidas

### Opciones de `input`

| Opción | Tipo | Descripción |
|---|---|---|
| `kb_layout` | string | Códigos de distribución de teclado (ej. `"es"`, `"us"`, `"es,us"`) |
| `kb_variant` | string | Variante del teclado (ej. `"colemak"`, `"dvorak"`) |
| `kb_options` | string | Opciones de XKB (ej. `"grp:alt_shift_toggle"`, `"caps:escape"`, `"caps:swapescape"`) |
| `repeat_rate` | number | Frecuencia de repetición de teclas en Hertz (ej. `50`) |
| `repeat_delay` | number | Retardo previo a la repetición en milisegundos (ej. `300`) |
| `sensitivity` | number | Modificador de sensibilidad del puntero desde `-1.0` hasta `1.0` |
| `follow_mouse` | number | El foco sigue al ratón (`0`: clic para enfocar, `1`: según movimiento del cursor, `2`: desacoplado) |
| `numlock_by_default` | boolean | Activa Bloq Núm automáticamente al iniciar |
| `left_handed` | boolean | Invierte los botones izquierdo y derecho del ratón (modo zurdo) |
| `float_switch_override_focus` | boolean | Controla el comportamiento del foco al cambiar entre ventanas flotantes |

### Opciones de `input.touchpad`

| Opción | Tipo | Descripción |
|---|---|---|
| `natural_scroll` | boolean | Desplazamiento natural (invierte la dirección del scroll con dos dedos) |
| `tap_to_click` | boolean | Toque en el touchpad para hacer clic izquierdo |
| `disable_while_typing` | boolean | Desactiva temporalmente el touchpad al escribir |
| `clickfinger_behavior` | boolean | 1 dedo = clic izquierdo, 2 dedos = clic derecho, 3 dedos = clic central |
| `middle_button_emulation` | boolean | Presionar clic izquierdo+derecho simultáneamente emula el botón central |
| `drag_lock` | boolean | Bloquea el arrastre en gestos de toque y desplazamiento |

### Opciones de `cursor`

| Opción | Tipo | Descripción |
|---|---|---|
| `no_warps` | boolean | Evita que el cursor salte automáticamente al cambiar el foco |
| `warp_on_change_workspace` | number | `0`: No desplazar el cursor al cambiar de espacio de trabajo |
| `inactive_timeout` | number | Segundos de inactividad antes de ocultar el cursor (`0` = nunca) |

---

## 3. Instrucciones paso a paso

### Paso 1: Abrir `user_settings.lua`
Abra el archivo en su editor preferido:

```bash
nano ~/.config/hypr/UserConfigs/user_settings.lua
# o
nvim ~/.config/hypr/UserConfigs/user_settings.lua
```

### Paso 2: Editar o agregar las opciones deseadas
Modifique los valores en la tabla `hl.config({...})`.

### Paso 3: Guardar y recargar
Recargue Hyprland inmediatamente:

```bash
hyprctl reload
```
*(o presione `SUPER + ALT + R`).*

---

## 4. Ejemplos prácticos

### Ejemplo A: Teclado bilingüe (Español/Inglés) con cambio mediante Alt+Shift

```lua
hl.config({
  input = {
    kb_layout = "es,us",
    kb_variant = "",
    kb_options = "grp:alt_shift_toggle,caps:swapescape",
    repeat_rate = 50,
    repeat_delay = 300,
    numlock_by_default = true,
  },
})
```

### Ejemplo B: Optimización para touchpad de portátil

```lua
hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
      disable_while_typing = true,
      clickfinger_behavior = true,
      middle_button_emulation = false,
      drag_lock = false,
    },
  },
})
```

### Ejemplo C: Repetición rápida de teclas y ratón para videojuegos

```lua
hl.config({
  input = {
    sensitivity = -0.2,       -- Sensibilidad reducida para sensores de alto DPI
    repeat_rate = 60,         -- Tasa de repetición rápida
    repeat_delay = 240,        -- Menor retardo de repetición
    follow_mouse = 1,
  },
  cursor = {
    no_warps = true,
    warp_on_change_workspace = 0,
  },
})
```

---

## 5. Solución de problemas

1. **El atajo de cambio de idioma del teclado no responde**:
   Verifique que haya configurado múltiples idiomas en `kb_layout` (ej. `kb_layout = "es,us"`) y asignado `kb_options = "grp:alt_shift_toggle"`.
2. **El cursor se desplaza inesperadamente al cambiar de ventana**:
   Asegúrese de incluir `cursor = { no_warps = true, warp_on_change_workspace = 0 }`.
3. **Comprobar errores de sintaxis**:
   ```bash
   luac -p ~/.config/hypr/UserConfigs/user_settings.lua
   ```
