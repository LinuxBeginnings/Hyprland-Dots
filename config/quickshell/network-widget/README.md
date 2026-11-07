# Network & Bluetooth widget

A small Quickshell panel for the Waybar `custom/qs-network` module. It manages
ethernet, Wi-Fi and bluetooth, and shows the connection details (address,
gateway, DNS, MAC) for the active wired and wireless link. Tailscale, Docker
and Podman get their own tabs, but only when they are installed or their links
exist.

```
┌─ 󰖟 Connections ────────────────────── 󰑐  󰅖 ─┐
│ [󰌘 Ethernet] [󰤨 Wi-Fi] [󰂯 Bluetooth]         │
│ [󰖂 Tailscale] [ Docker] [ Podman]           │
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
part. When `nmcli` is missing, or NetworkManager reports no devices at all, the
wired devices are read from the kernel (`ip`, `/sys/class/net`) instead: the
Ethernet tab still lists each NIC with its addresses, gateway and MAC,
read-only, and the footer says why in the error colour. Opening the panel also
raises one desktop notification about the missing NetworkManager per session.

## Usage

`copy.sh` installs this directory as `~/.config/quickshell/network-widget`,
beside the other quickshell widgets. The shell starts hidden and collapses to a
single pixel, so it stays resident between toggles and never opens the panel on
its own - the Waybar module or the keybind opens it. Starting it by hand is the
same command:

```bash
quickshell -p ~/.config/quickshell/network-widget
```

It also runs from a checkout, because `QsNetworkPanel.sh` is resolved relative
to this directory:

```bash
quickshell -p ~/Hyprland-Dots/config/quickshell/network-widget
```

Once it is running, show or hide it with:

```bash
~/.config/hypr/scripts/QsNetworkPanel.sh toggle
```

The Waybar module (`custom/qs-network`, defined in `waybar/ModulesCustom`) is
on every bundled bar layout, in `modules-right`:

- left click: show or hide the panel
- right click: `nmtui` (unchanged behaviour from the old `network` module)

The module polls once a second (`"interval": 1`), so the icon and tooltip
follow a link going up or down without a click. The icon follows the
connection: wired, Wi-Fi signal strength, or a slashed Wi-Fi glyph when nothing
is connected. Two-bar layouts (`TOP-&-BOT-*`,
`TOP-&-*`, `BOT-&-*`) get it on the first bar only, so it does not appear twice.
Every stylesheet in `waybar/style` carries a `#custom-qs-network` rule; it
inherits the bar's text colour, so a style you switch to later still looks
right. To take the icon off a bar, delete the `"custom/qs-network",` line from
its `modules-right`.

Nothing is bound by default. To put it on the keyboard, add this to
`hypr/UserConfigs/user_keybinds.lua`:

```lua
bind("SUPER CTRL", "N", exec_cmd("$HOME/.config/hypr/scripts/QsNetworkPanel.sh toggle"),
  { description = "Network panel" })
```

`SUPER + CTRL + N` is free; `SUPER + SHIFT + N` already toggles the swaync
notification panel.

The panel drops down at the top-right, offset from the top and right edges, and
lines up under the Waybar module when it is opened from there. Close it with the
󰅖 button, with the same Waybar click, or by clicking anywhere outside it. While
it is open the whole screen is the dismissal target, so a click on the bar goes
to the panel and closes it. Escape cancels a password prompt.

## Tabs

Each tab holds everything for its device type, so the panel never becomes one
long list.

- **Ethernet** - every wired device, its state, and an info block with
  Address, Gateway, DNS and MAC. All addresses on an interface are listed, so
  aliased and secondary IPs appear under the first one. Click the device line
  to bring it up or take it down. A device NetworkManager leaves unmanaged
  (common in VMs where `/etc/network/interfaces` owns the NIC) is listed
  read-only, with the addresses and gateway the kernel reports.
- **Wi-Fi** - radio switch and rescan, the active connection's Address,
  Gateway, DNS and MAC, then the available networks. Click a network to
  connect, the connected one to disconnect. Locked networks ask for the
  password inline; known networks connect straight away.
- **Bluetooth** - adapter switch and discovery, connected devices with their
  battery level, then paired and available devices. Click an unpaired device to
  pair and connect it, a paired one to connect, a connected one to disconnect.
- **Tailscale** - only shown when `tailscale` is installed or `tailscale0`
  exists. The switch brings the tunnel up or down, then the backend state, the
  tunnel interface with its addresses, the exit nodes (`tailscale set
  --exit-node`, click to select or clear, "Suggest" asks Tailscale for the best
  one) and the tailnet peers with their IP, OS and online/offline state.
- **Docker** - only shown when `docker` is installed or a `docker0`/`br-*`
  bridge exists. Lists each bridge with its addresses, then the containers as
  name, status, runtime and live CPU/memory from `docker stats`. Running
  containers are shown; the "Stopped" switch also lists stopped ones. Click a
  container to stop it, or start it again.
- **Podman** - the same for `podman`, the `podman*`/`cni-podman*` bridges and
  `podman ps` / `podman stats`.

If a tool goes away its tab disappears and an open tab falls back to Ethernet.

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
  (`DEV`, `ADDR`, `LINK`, `FEATURE`, `WIFI`, `WIFI-ON`, `BT-ON`, `BT-SCAN`,
  `BT-CTL`, `BTDEV`, `NOTE`) which `Backend.qml` parses. `ADDR` carries every
  address of an interface (read from `ip`, so aliases are included), `LINK`
  the tailscale/docker/podman interfaces NetworkManager does not manage,
  `FEATURE` the installed tooling, `TS-STATE`/`TSPEER`/`TS-EXIT` the tailnet
  status, peers and exit nodes, and `BOX`/`BOXSTAT` the docker/podman
  containers and the resource use of the running ones.
- the action subcommands (`connect-wifi`, `wifi on|off`, `bt connect`,
  `container docker|podman start|stop|restart NAME`, `tailscale up|down`,
  `tailscale exit-node NAME|none`, `tailscale suggest`, ...) change state;
  errors are printed on stderr and shown in the panel.

`status` prints the Waybar JSON, so the module icon and tooltip come from the
same code as the panel. It is built from the device records only: the module
runs it once a second, and the container and tailnet probes behind `snapshot`
cost far more than that for records nothing on the bar draws.

Files:

| File | Purpose |
| --- | --- |
| `shell.qml` | entry point, IPC handler, wallust palette loading |
| `Panel.qml` | the layer-shell window, click-outside backdrop, header, tabs, footer |
| `EthernetTab.qml` | wired devices and their connection details |
| `VirtualNetTab.qml` | Tailscale, Docker and Podman links and their addresses |
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
While the panel is open that same surface fills the monitor, and that is what
catches a click outside the card - the card swallows its own clicks, so nothing
under it closes by accident.

## Troubleshooting

Run it in a terminal to see QML errors:

```bash
quickshell -p ~/.config/quickshell/network-widget
```

Check what the panel would receive:

```bash
~/.config/hypr/scripts/QsNetworkPanel.sh snapshot
~/.config/hypr/scripts/QsNetworkPanel.sh status
```

If the Ethernet tab marks a device as "Unmanaged by NetworkManager", something
else owns it - usually `/etc/network/interfaces` in a VM image, with
`[ifupdown] managed=false` in `/etc/NetworkManager/NetworkManager.conf`. Its
addresses are still shown. To hand the device to NetworkManager (so Connect
and Disconnect work in the panel), with `ens18` standing in for your NIC:

```bash
# 1. keep a backup, then leave the file describing only `lo`
sudo cp -a /etc/network/interfaces /etc/network/interfaces.bak
sudo sed -i -E 's/^(allow-hotplug ens18|iface ens18 .*)$/# \1/' /etc/network/interfaces

# 2. give NetworkManager a profile that autoconnects by interface name
sudo nmcli connection add type ethernet ifname ens18 con-name ens18 \
  ipv4.method auto ipv6.method auto connection.autoconnect yes

# 3. stop ifupdown and the dhcpcd it started, then let NetworkManager
#    run DHCP itself
sudo systemctl stop networking
sudo pkill -x dhcpcd
sudo nmcli connection down ens18
sudo nmcli connection up ens18
```

`nmcli device status` should now show `ens18  connected  ens18`, and
`/etc/resolv.conf` becomes NetworkManager's. The lease usually changes, so
check port forwards and bookmarks aimed at the old address. `[ifupdown]
managed=false` can stay: `lo` is then the only interface that file describes,
and NetworkManager owns the rest through its own profiles.

To go back, restore the backup, let ifupdown configure the NIC again and drop
the profile:

```bash
sudo mv /etc/network/interfaces.bak /etc/network/interfaces
sudo systemctl start networking
sudo nmcli connection delete ens18
```

With no `nmcli` at all, or when NetworkManager reports no devices, the panel
falls back to the kernel for wired hardware: `ip link`/`ip addr` for the state
and addresses, `ip route` for the gateway, `/sys/class/net` for the MAC and
`/etc/resolv.conf` for DNS (falling back to `resolvectl` when systemd-resolved
only leaves its `127.0.0.53` stub there). Those rows are read-only, and the
`ERR` record in the snapshot is what carries the reason into the footer.

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
