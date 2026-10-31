# Keybinds panel

A searchable, centred frame showing every keybind the compositor has registered,
one key cap per key in the chord.

## Start and toggle

```sh
quickshell -p ~/.config/quickshell/keybinds          # start, stays resident
~/.config/hypr/scripts/QsKeybinds.sh toggle          # SUPER SHIFT K
~/.config/hypr/scripts/QsKeybinds.sh open | close | refresh
~/.config/hypr/scripts/QsKeybinds.sh which           # quickshell or rofi
```

The shell starts hidden and collapses to a single pixel, so it stays resident
between toggles and the panel opens instantly. `QsKeybinds.sh` starts the shell
if it is not already running.

`SUPER SHIFT K` is the entry point, and it reaches both menus. Where quickshell
is missing - the Ubuntu 24.04 based installs - or the panel will not start, the
script opens the rofi menu (`KeyBinds.sh`) instead, so the keybind is never
dead. `which` prints the menu that would open without opening it.

IPC, if something else wants to drive it:

```sh
quickshell ipc -p ~/.config/quickshell/keybinds call keybinds toggle|open|close|isOpen|refresh
```

## Where the list comes from

`services/HyprlandKeybinds.qml` reads `$XDG_RUNTIME_DIR/kooldots-keybinds.txt`,
which `hypr/lua/keybind_index.lua` writes from inside Hyprland's Lua VM: it hooks
`hl.bind` and records every registered chord with its description. The same file
feeds the `SUPER SHIFT K` rofi menu through `KeyBinds.sh`.

That is why the panel lists what the compositor has bound rather than what the
config text says. Chords the helpers derive, the lid-switch binds, and binds
registered by another module all appear, and a bind added with `hyprctl eval`
appears the next time the panel opens.

If the hook is not installed - a config whose `hyprland.lua` predates
`keybind_index.lua` - the service falls back to `hyprctl -j binds`, the same
fallback `KeyBinds.sh` uses.

## Search and keys

- Type to filter: every whitespace-separated token must appear in the chord or
  the description, so `super shift` and `volume` both narrow the list.
- `↑` / `↓` move the selection, `←` / `→` step between the two cells of a row,
  `Enter` copies the chord, `Esc` closes.
- A click outside the frame closes it; a double click copies a chord.
- The list is sorted into categories with a header per category, two binds to a
  row. It is one scrollable page, so both columns always move together.

## Layout

```text
keybinds/
  shell.qml                       ShellRoot, theme wiring, IPC handler
  services/HyprlandKeybinds.qml   the bind list (singleton)
  modules/Theme.qml               wallust palette loader
  modules/Keycap.qml              one 3D key cap
  modules/KeybindRow.qml          a chord as caps, plus its description
  modules/Panel.qml               the centred frame, search box and list
```

Each applet is its own quickshell shell root (`-p <applet dir>`), and an import
cannot reach a sibling applet's directory, so `Theme.qml` is carried here as
`network-widget/Theme.qml` is carried there. The caps themselves are drawn from
rectangles rather than shipped as images, so they follow the wallpaper palette
and stay sharp at any scale.

## Layer rule

`configs/system_layer_rules.lua` matches the namespace `quickshell:keybinds` and
blurs it with `ignore_alpha = 0.5`: the opaque card is blurred, the 0.35-alpha
backdrop is not.
