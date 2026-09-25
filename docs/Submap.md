# **Submaps**

Submaps let you activate a separate set of keybinds — for example a "resize mode" or a
media-control mode — without giving up your normal bindings. You can create as many
submaps as you like, which makes keybinding customisation very flexible.

The official Hyprland documentation is
[here](https://wiki.hypr.land/configuring/core/binds/submaps/).

## **KoolDots Submap**

`submap_helper.lua` (in `hypr/lua/`) wraps Hyprland's native
[`hl.dsp.submap`](https://wiki.hypr.land/configuring/core/binds/submaps/) and
`hl.define_submap` so you don't have to wire up the entry bind, the submap body and the
exit bind yourself. It is loaded for you in `hypr/UserConfigs/user_keybinds.lua` and
exposed as the `submap` table:

```
 submap
├── auto
│      ├── release
│      └── toggle
├── man
├── create
└── define
```

All of these are defined inside `hypr/UserConfigs/user_keybinds.lua`, so `submap`,
`bind`, `unbind`, `exec_cmd` and `hl` are all in scope when you call them.

If `submap_helper.lua` cannot be found you will see a `[WARN]` in the log and `submap`
will be `nil`; every other keybind still loads normally.

### Trigger keybind rules

The trigger keybind you pass to these helpers can be written as a string
(`"SUPER + SHIFT + E"`, `"SUPER, SHIFT, E"` or `"SUPER SHIFT E"`) or as a table. It must
contain **exactly one non-modifier key** and **at most 2 modifiers**. Recognised
modifiers are `SUPER`, `CTRL` (also `CONTROL`), `ALT`, `SHIFT`, `META` and `MOD1`–`MOD5`.
Keys may be ordinary keysyms (`E`), keycodes (`code:11`) or mouse buttons (`mouse:274`).

### `auto`

Sets up the complete submap — entry bind, body and exit — in one call. Use `release`
to stay in the submap only while the trigger key is held, or `toggle` to enter on one
press and leave on the next.

```lua
submap.auto.release(name, keybind, function()
  -- binds that are only active inside the submap
end)

submap.auto.toggle(name, keybind, function()
  -- binds that are only active inside the submap
end)
```

> **Note:** `submap.auto.release` needs the submap to receive the key-release event that
> entered it. This was unreliable in Hyprland's Lua config before ~0.56; on older
> versions prefer `submap.man()` with separate entry and exit chords.

### `man`

Uses separate keybinds to enter and leave the submap. This is the most portable option
and the one to use when the same trigger chord for entry and exit is a problem.

```lua
submap.man(name, entry_keybind, exit_keybind, function()
  -- binds that are only active inside the submap
end)
```

### `create`

Only binds the entry keybind to the submap. You are responsible for registering the
submap body yourself with `hl.define_submap(name, function() ... end)`. `create` takes no
body.

```lua
submap.create(name, keybind)
```

### `define`

Binds the entry keybind **and** registers the body you pass in. Unlike `auto`, it does not
add an exit bind for you, so add one (`hl.dsp.submap("reset")`) inside the body.

```lua
submap.define(name, keybind, function()
  -- binds that are only active inside the submap

  bind("", "escape", hl.dsp.submap("reset"), { description = "Leave the submap" })
end)
```

## Examples

- Trigger keybinds do not need modifiers, but they can use them.
- Remember to always provide a way out. A submap with no exit bind will trap you; if it
  happens, run `hyprctl dispatch 'hl.dsp.submap("reset")'` from another TTY.

### Example 1

Media controls while holding down the middle mouse button. Holding the button opens the
submap, and releasing it goes back to your normal binds.

```lua
submap.auto.release("Media", "mouse:274", function()

  bind("", "w", exec_cmd("playerctl volume 0.1+"))
  bind("", "s", exec_cmd("playerctl volume 0.1-"))
  bind("", "a", exec_cmd("playerctl previous"))
  bind("", "d", exec_cmd("playerctl next"))
  bind("", "e", exec_cmd("playerctl play-pause"))

end)
```

### Example 2

A secondary mode for inserting text macros. Press the trigger to enter, press it again to
leave.

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

- When injecting text, use `ydotool`; `wtype` results in undefined behaviour.

### Example 3

Submaps can also launch applications that have no binding of their own. If you would
rather reuse a chord that is already bound, call `unbind("MODS", "KEY")` first to free it.

```lua
submap.auto.toggle("App-Shortcuts", "SUPER ALT A", function()

  bind("", "S", exec_cmd("steam &"))
  bind("", "F", exec_cmd("org.ferdium.Ferdium")) --[[ great app btw ;) ]]
  bind("", "M", exec_cmd("spotify-launcher &"))

end)
```
