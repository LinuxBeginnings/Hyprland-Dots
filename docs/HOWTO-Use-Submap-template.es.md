# **Submaps**

Los submaps te permiten activar un conjunto separado de atajos — por ejemplo un "modo de
redimensionado" o un modo de control multimedia — sin renunciar a tus atajos normales.
Puedes crear tantos submaps como quieras, lo que hace que la personalización de atajos
sea muy flexible.

La documentación oficial de Hyprland está
[aquí](https://wiki.hypr.land/configuring/core/binds/submaps/).

## **Submap de KoolDots**

`submap_helper.lua` (en `hypr/lua/`) envuelve el
[`hl.dsp.submap`](https://wiki.hypr.land/configuring/core/binds/submaps/) nativo de Hyprland y
`hl.define_submap` para que no tengas que conectar tú mismo el atajo de entrada, el cuerpo
del submap y el atajo de salida. Se carga automáticamente en `hypr/UserConfigs/user_keybinds.lua`
y se expone como la tabla `submap`:

```
 submap
├── auto
│      ├── release
│      └── toggle
├── man
├── create
└── define
```

Todos ellos se definen dentro de `hypr/UserConfigs/user_keybinds.lua`, de modo que `submap`,
`bind`, `unbind`, `exec_cmd` y `hl` están todos en el ámbito cuando los llamas.

Si no se encuentra `submap_helper.lua` verás un `[WARN]` en el registro y `submap`
será `nil`; todos los demás atajos se siguen cargando con normalidad.

### Reglas de los atajos de activación

El atajo de activación que pasas a estos helpers puede escribirse como una cadena
(`"SUPER + SHIFT + E"`, `"SUPER, SHIFT, E"` o `"SUPER SHIFT E"`) o como una tabla. Debe
contener **exactamente una tecla no modificadora** y **como máximo 2 modificadores**. Los
modificadores reconocidos son `SUPER`, `CTRL` (también `CONTROL`), `ALT`, `SHIFT`, `META` y `MOD1`–`MOD5`.
Las teclas pueden ser keysyms ordinarios (`E`), keycodes (`code:11`) o botones del ratón (`mouse:274`).

### `auto`

Configura el submap completo — atajo de entrada, cuerpo y salida — en una sola llamada. Usa
`release` para permanecer en el submap solo mientras se mantiene pulsada la tecla de activación,
o `toggle` para entrar con una pulsación y salir con la siguiente.

```lua
submap.auto.release(name, keybind, function()
  -- atajos que solo están activos dentro del submap
end)

submap.auto.toggle(name, keybind, function()
  -- atajos que solo están activos dentro del submap
end)
```

> **Nota:** `submap.auto.release` registra el atajo de soltar-para-salir en el submap
> padre, junto al atajo de entrada, en lugar de dentro del cuerpo del submap. Hyprland
> compara la liberación de una tecla con el submap que estaba activo cuando la tecla se
> *pulsó*, así que un atajo de liberación colocado dentro del cuerpo del submap nunca se
> dispararía y el acorde se comportaría como un toggle en lugar de liberar. Si un acorde de
> activación para entrar y salir supone un problema en tu configuración, prefiere
> `submap.man()` con acordes separados de entrada y salida.

### `man`

Usa atajos separados para entrar y salir del submap. Esta es la opción más portable
y la que debes usar cuando el mismo acorde de activación para entrar y salir es un problema.

```lua
submap.man(name, entry_keybind, exit_keybind, function()
  -- atajos que solo están activos dentro del submap
end)
```

### `create`

Solo vincula el atajo de entrada al submap. Tú eres responsable de registrar el
cuerpo del submap con `hl.define_submap(name, function() ... end)`. `create` no recibe
cuerpo.

```lua
submap.create(name, keybind)
```

### `define`

Vincula el atajo de entrada **y** registra el cuerpo que le pasas. A diferencia de `auto`, no
añade un atajo de salida por ti, así que añade uno (`hl.dsp.submap("reset")`) dentro del cuerpo.

```lua
submap.define(name, keybind, function()
  -- atajos que solo están activos dentro del submap

  bind("", "escape", hl.dsp.submap("reset"), { description = "Leave the submap" })
end)
```

## Ejemplos

- Los atajos de activación no necesitan modificadores, pero pueden usarlos.
- Recuerda proporcionar siempre una forma de salir. Un submap sin atajo de salida te
  atrapará; si ocurre, ejecuta `hyprctl dispatch 'hl.dsp.submap("reset")'` desde otra TTY.

### Ejemplo 1

Controles multimedia mientras mantienes pulsado el botón central del ratón. Mantener el botón
abre el submap, y soltarlo vuelve a tus atajos normales.

```lua
submap.auto.release("Media", "mouse:274", function()

  bind("", "w", exec_cmd("playerctl volume 0.1+"))
  bind("", "s", exec_cmd("playerctl volume 0.1-"))
  bind("", "a", exec_cmd("playerctl previous"))
  bind("", "d", exec_cmd("playerctl next"))
  bind("", "e", exec_cmd("playerctl play-pause"))

end)
```

### Ejemplo 2

Un modo secundario para insertar macros de texto. Pulsa el atajo para entrar, púlsalo de nuevo
para salir.

```lua
submap.auto.toggle("Macros", "CTRL ALT code:11", function()

  bind("", "E", exec_cmd('ydotool type "e-mail address"'))
  bind("SHIFT", "E", exec_cmd('ydotool type "e-mail address 2"'))
  bind("", "U", exec_cmd('ydotool type "Username"'))
  bind("SHIFT", "U", exec_cmd('ydotool type "Username 2"'))

  bind("", "1",
    exec_cmd('ydotool type "#include<stdio.h>" -k Return "#include<stdlib.h>" -k Return "int main()" -k Return "{}"'),
    { description = "Create std C file" })

end)
```

- Al inyectar texto, usa `ydotool`; `wtype` provoca un comportamiento indefinido.

### Ejemplo 3

Los submaps también pueden lanzar aplicaciones que no tienen un atajo propio. Si prefieres
reutilizar un acorde que ya está vinculado, llama primero a `unbind("MODS", "KEY")` para liberarlo.

```lua
submap.auto.toggle("App-Shortcuts", "SUPER ALT A", function()

  bind("", "S", exec_cmd("steam &"))
  bind("", "F", exec_cmd("org.ferdium.Ferdium")) --[[ gran app por cierto ;) ]]
  bind("", "M", exec_cmd("spotify-launcher &"))

end)
```
