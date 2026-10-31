# Network & Bluetooth widget

A small Quickshell panel for the Waybar `custom/qs-network` module. It manages
ethernet, Wi-Fi and bluetooth, and shows the connection details (address,
gateway, DNS, MAC) for the active wired and wireless link.

```
┌─ 󰖟 Connections ────────────────────── 󰑐  󰅖 ─┐
│ [󰌘 Ethernet] [󰤨 Wi-Fi] [󰂯 Bluetooth]         │
│                                              │
│ 󰤨 Wi-Fi                        󰑓      [on]   │
│   Linux-Da-Bomb                              │
│ ┌──────────────────────────────────────────┐ │
│ │ Address   192.168.40.72/24               │ │
│ │ Gateway   192.168.40.1                   │ │
│ │ DNS       192.168.40.3, 8.8.4.4          │ │
│ │ MAC       0C:CD:B4:26:28:E0              │ │
│ └──────────────────────────────────────────┘ │
│ 󰤨 Linux-Da-Bomb   84% · WPA2    Connected 󰌾  │
│ 󰤢 Summer0035      67% · WPA2 WPA3            │
└─ Click a network or device to connect ───────┘
```

## Requirements

- `quickshell` (0.3 or newer)
- `NetworkManager` with `nmcli` for the ethernet and Wi-Fi tabs
- `bluez` with `bluetoothctl` for the bluetooth tab (optional)
- A Nerd Font (`JetBrainsMono Nerd Font`, the dots default)

Without NetworkManager or BlueZ the panel still opens and names the missing
part.

## Usage

`copy.sh` installs this directory as `~/.config/hypr/quickshell/network-widget`
together with the rest of `config/hypr`. Running it shows the panel straight
away:

```bash
quickshell -p ~/.config/hypr/quickshell/network-widget
```

It also runs from a checkout, because `QsNetworkPanel.sh` is resolved relative
to this directory:

```bash
quickshell -p ~/Hyprland-Dots/config/hypr/quickshell/network-widget
```

Once it is running, show or hide it with:

```bash
~/.config/hypr/scripts/QsNetworkPanel.sh toggle
```

The Waybar module (`custom/qs-network`, defined in `waybar/ModulesCustom`) is
already on the `TOP-Default` and `TOP-Default-Laptop` bars:

- left click: show or hide the panel
- right click: `nmtui` (unchanged behaviour from the old `network` module)

To bind it on the keyboard, add to `hypr/UserConfigs/UserKeybinds.conf`:

```ini
bind = $mainMod SHIFT, N, exec, $HOME/.config/hypr/scripts/QsNetworkPanel.sh toggle
```

Close the panel with the 󰅖 button or with the same Waybar click. Escape cancels
a password prompt.

## Tabs

Each tab holds everything for its device type, so the panel never becomes one
long list.

- **Ethernet** - the wired device, its state, and an info block with Address,
  Gateway, DNS and MAC. Click the device line to bring it up or take it down.
- **Wi-Fi** - radio switch and rescan, the active connection's Address,
  Gateway, DNS and MAC, then the available networks. Click a network to
  connect, the connected one to disconnect. Locked networks ask for the
  password inline; known networks connect straight away.
- **Bluetooth** - adapter switch and discovery, connected devices with their
  battery level, then paired and available devices. Click an unpaired device to
  pair and connect it, a paired one to connect, a connected one to disconnect.

Battery is shown for connected devices that report it over BlueZ. Audio
devices often do not, in which case no battery is displayed for them.

DNS and other per-connection settings can be edited with `nmtui` (Waybar right
click on the module); the tab shows the values currently in use.

## Theming

The panel follows wallust, so it tracks the current wallpaper like the rest of
the dots:

1. `~/.config/hypr/waybar/wallust/colors-waybar.css` - the full palette.
   `background` becomes the panel background, `color12` the accent (the slot
   the dots' Wallust styles use), and the brightest of `color7`/`color15`/
   `cursor` becomes the text colour.
2. `~/.config/quickshell/qml_color.json` - used when the Waybar palette is
   absent.
3. Built-in dark defaults.

Surfaces, borders, hover and muted text are mixed from the background and text
colour, so the panel stays readable with any palette, light or dark. Both files
are watched; changing the wallpaper repaints the panel without a restart.

## How it works

`QsNetworkPanel.sh` is the only thing that talks to NetworkManager and BlueZ.
The QML side calls it for two things:

- `snapshot` prints the current state as tab separated records
  (`DEV`, `WIFI`, `WIFI-ON`, `BT-ON`, `BT-SCAN`, `BT-CTL`, `BTDEV`, `NOTE`)
  which `Backend.qml` parses.
- the action subcommands (`connect-wifi`, `wifi on|off`, `bt connect`, ...)
  change state; errors are printed on stderr and shown in the panel.

`status` prints the Waybar JSON, so the module icon and tooltip come from the
same code as the panel.

Files:

| File | Purpose |
| --- | --- |
| `shell.qml` | entry point, IPC handler, wallust palette loading |
| `Panel.qml` | the layer-shell window, header, tab bar and footer |
| `EthernetTab.qml` | wired devices and their connection details |
| `WifiTab.qml` | radio, current connection details, network list |
| `BluetoothTab.qml` | adapter, discovery, devices and battery |
| `Backend.qml` | runs the script, parses the snapshot, holds the state |
| `Theme.qml` | wallust palette parsing and colour roles |
| `RowItem.qml` | one clickable line |
| `InfoBlock.qml` | labelled Address/Gateway/DNS/MAC card |
| `TabButton.qml` | one tab in the header |
| `Switch.qml` | radio on/off switch |
| `IconButton.qml` | small glyph button |

The window stays mapped at 1x1 while hidden: quickshell exits when its last
window is closed, so keeping the surface alive is what makes reopening instant.

## Troubleshooting

Run it in a terminal to see QML errors:

```bash
quickshell -p ~/.config/hypr/quickshell/network-widget
```

Check what the panel would receive:

```bash
~/.config/hypr/scripts/QsNetworkPanel.sh snapshot
~/.config/hypr/scripts/QsNetworkPanel.sh status
```

If the panel does not follow the wallpaper, check that the file exists and
contains `@define-color background`:

```bash
grep background ~/.config/hypr/waybar/wallust/colors-waybar.css
```

## Known limits

- Hidden SSIDs are not listed; join them with `nmtui`.
- Enterprise networks (`WPA2 802.1X`) need credentials `nmcli` cannot take
  from a simple password prompt; use `nmtui` for those.
- Battery only appears for devices that report it over BlueZ (mostly BLE
  accessories); many headsets report none.
