# Display layouts

Remembers how you arrange your monitors and puts them back by itself. Works
with any number of monitors, on a laptop or a desktop, and nothing in it is
specific to one machine.

Press **`SUPER` + `ALT` + `D`**. Everything starts there.

---

## What it does

When the set of connected monitors changes — you plug in a monitor, unplug one,
switch one off at the wall — the watcher notices and applies the layout you
saved for *that set of monitors*. If you have never saved one, it arranges them
side by side and leaves them usable.

Three ideas, and the rest follows from them:

- **A monitor is identified by the device**, as `make|model|serial`, not by the
  port it happens to be plugged into. Move a monitor from `DP-2` to `HDMI-A-1`
  and it is still the same monitor, so the same layout still applies.
- **A monitor set is the sorted list of those identities.** That list is the key
  your layouts are stored under. Two monitors at home and three at the office
  are simply two different keys.
- **A layout is a named arrangement of one monitor set**: per monitor, whether
  it is on, its mode, scale, rotation and position; plus which monitor is
  focused afterwards, and which monitors show a Waybar bar.

You can have several named layouts for the same monitors — `Home`, `Work`,
`Game` — with one marked as the default that gets applied automatically.

## Getting started

Nothing is configured out of the box, and nothing needs to be. Plug a monitor
in and you get a working arrangement immediately.

To keep an arrangement:

1. Arrange the monitors the way you want them. Either
   - `SUPER`+`ALT`+`D` → **Arrange monitors — drag and drop**, which opens
     `nwg-displays` and lets you drag them around and set each one's mode and
     scale; or
   - `SUPER`+`ALT`+`D` → **Edit parameters (table)**, which is described below
     and needs no extra program.
2. `SUPER`+`ALT`+`D` → **Save current state as…** and give it a name.

From then on, connecting that set of monitors applies that layout.

A layout for a state you are *not* in — "only the laptop panel", say — cannot be
captured, because capturing records what is actually running. Author it in the
table instead: switch the other monitors off there and save.

## The menu (`SUPER` + `ALT` + `D`)

```
Monitor set: Home (2 monitors) · running: Home

  Home                    ★ default, ← running
  Work
  ────────────────
  Automatic
  Arrange monitors — drag and drop (nwg-displays)
  Save current state as…
  Edit parameters (table)
  Set as default…
  Rename monitor set…
  Delete layout…
  Reset layout store…
  Exit
```

The layouts at the top are the ones saved for the monitors in front of you; the
list changes with them. **Automatic** re-decides from scratch, which is what you
want after changing a Waybar layout. **Rename monitor set…** gives the set a
readable name so the message line says `Home` instead of a long device string.

## The parameter table

```
Layout: Home · Monitor set: Dell|U2720Q|ABC123 + AOC|24G2|GHI789

 Dell U2720Q (DP-1)      on · 2560x1440@59.95 · x1   · row 1 · order 1 · top
 AOC 24G2 (HDMI-A-1)     on · 1920x1080@144.00 · x1  · row 1 · order 2 · bottom
 Primary                 Dell U2720Q
 Waybar                  selected → 1 monitor(s)
 Position (computed)     DP-1 0x0 · HDMI-A-1 2560x0
 Save & apply
 Cancel
```

Pick a monitor to switch it off, change its mode, scale or rotation, or move it
in the grid. Modes come from what that monitor actually reports, so you cannot
choose one it does not have.

**You never type coordinates.** You say which row a monitor is in, its order
within the row, and how it lines up vertically (`top`, `center`, `bottom`), and
the positions are computed from the logical sizes (`mode ÷ scale`). That removes
the mistake the old two-monitor version invited: its hardcoded `1280x0` was
really `1920 ÷ 1.5`, and changing the scale without redoing that arithmetic left
a gap or an overlap between the screens.

The table also covers the three things `nwg-displays` has no concept of: which
monitor is **primary** (focused after the layout is applied), which monitors are
**off** in this particular layout, and where the **bars** go.

## Waybar

Each layout chooses one of three:

| Mode | Effect |
|---|---|
| `all` | Bars on every monitor. Nothing is generated; Waybar runs your own config. |
| `primary` | Bars only on the layout's primary monitor. |
| `selected` | Bars on the monitors you picked. |

For the last two, the active Waybar layout is copied to
`$XDG_RUNTIME_DIR/kooldots-display-profiles/config-active` with an `"output"`
array injected into every bar. Your own config and your choice of Waybar layout
(`SUPER`+`ALT`+`B`) are untouched.

`WaybarStartup.sh` asks this system which config to run, so `SUPER`+`ALT`+`R`
(Refresh), a lid-switch restart and the login start all keep the restriction.
If this feature is ever removed, those scripts fall back to the plain config on
their own.

## When it deliberately does nothing

**If you configure monitors yourself**, the system stands down. Specifically: if
`UserConfigs/monitors.lua` contains an uncommented `hl.monitor(...)` line — you
wrote one, or `MonitorProfiles.sh` wrote one — and the monitor set in front of
you has no saved layout, nothing is applied and a line is written to the log.

This is on purpose: your `monitors.lua` and the Monitor Profiles menu keep
working exactly as before, and two systems do not fight over the same screens.

**Saving one layout for that monitor set hands control over** — from then on,
this system manages that set regardless of `monitors.lua`.

So "it does nothing" is the expected outcome in exactly one case. If that is
you, either save a layout, or comment out your `hl.monitor(...)` lines.

## Things worth knowing

- **Switching a monitor off moves its workspaces.** Hyprland moves them to
  another monitor and does not move them back when the monitor returns. The log
  records which workspaces moved. Pin the ones you care about in
  `UserConfigs/workspaces.lua`.
- **A monitor with no make or model** (some cheap adapters report neither) is
  identified by its port name instead, so for that one monitor, moving the cable
  does look like a different monitor.
- **Two identical monitors with no serial number** are told apart by which port
  they were on when you saved the layout. Swap their cables and they swap places
  until you save again.
- **An arrangement made in `nwg-displays` is not saved until you save it.** That
  program knows nothing about monitor sets, so the menu reopens afterwards and
  offers to save it. Quick Settings' own `nwg-displays` entry does the same.
- **Never zero screens.** Any monitor may be switched off, including a laptop
  panel, but the enabled monitors are applied and verified *before* anything is
  switched off, and if a layout would leave nothing active the system restores
  every connected monitor at scale 1.

## Files

| Path | What it is |
|---|---|
| `UserConfigs/display-layouts.json` | Your layouts. The installer only ever *adds* this file when it is missing, so an upgrade cannot overwrite it. |
| `scripts/lib_display_store.sh` | The data model. Pure: no `hyprctl`, no session state. |
| `scripts/DisplayProfile.sh` | The only thing that changes monitors, focus and Waybar. |
| `scripts/DisplayProfileMenu.sh` | `SUPER`+`ALT`+`D`. |
| `scripts/DisplayProfileSetup.sh` | The parameter table. |
| `scripts/MonitorWatcher.sh` | Watches Hyprland's event socket. One per session. |

Runtime state lives in `$XDG_RUNTIME_DIR/kooldots-display-profiles/`:
`display-profile.log`, `monitor-watcher.log`, `current` (the fingerprint and the
running layout's name), `config-active`, `pause`, and the throwaway
`nwg-monitors.conf.discard`.

> **If you update these scripts by hand, never copy the repo's
> `UserConfigs/display-layouts.json` over your own.** The repo ships it empty,
> on purpose, so a blind `cp -r` of the repo tree erases every layout you have
> saved. The installer is safe — it only adds that file when it is missing —
> but a manual copy is not. Copy the `scripts/` files and leave that one alone.

## Command line

```
DisplayProfile.sh auto                  decide and apply
DisplayProfile.sh -- <layout>           apply a named layout of this set
DisplayProfile.sh capture -- <name>     save the live state under a name
DisplayProfile.sh set-default -- <name> make it this set's default
DisplayProfile.sh delete -- <name>      delete a layout
DisplayProfile.sh label -- <text>       name this monitor set
DisplayProfile.sh list                  layout names for this set
DisplayProfile.sh monitors-json          path to the normalized monitor list
DisplayProfile.sh waybar-config          the config path Waybar should run
DisplayProfile.sh --dry-run auto         print the plan, change nothing
```

Names are always passed after `--`, so a layout called `-n` is a name and not an
option. Allowed in a name: letters, digits, space, `.`, `-`, `_`, up to 32
characters.

## When something looks wrong

```bash
# What would it do right now, without doing it?
~/.config/hypr/scripts/DisplayProfile.sh --dry-run auto

# What happened?
tail -40 "$XDG_RUNTIME_DIR/kooldots-display-profiles/display-profile.log"
tail -40 "$XDG_RUNTIME_DIR/kooldots-display-profiles/monitor-watcher.log"

# Is the watcher running, and is it the only one?
pgrep -af 'Monitor[W]atcher'

# Which event socket did it find?
~/.config/hypr/scripts/MonitorWatcher.sh --print-socket

# What does Hyprland actually report?
hyprctl -j monitors all | jq -c '.[] | {name, make, model, serial, width, height, refreshRate, x, y, scale, transform, disabled}'

# Exactly one bar?
pgrep -xc waybar
```

Restart the watcher in **two** commands, never one. A single command line that
both matches and launches the pattern can match itself:

```bash
pkill -f 'Monitor[W]atcher' || true
```

```bash
setsid ~/.config/hypr/scripts/MonitorWatcher.sh >/dev/null 2>&1 &
```

If the watcher says *"another MonitorWatcher is already running"* but `pgrep`
shows none, something is still holding its lock:

```bash
lsof "$XDG_RUNTIME_DIR/kooldots-monitor-watcher.lock"
```

If the layout store is damaged, nothing overwrites it: the system reads it as
empty and refuses every write. `SUPER`+`ALT`+`D` → **Reset layout store…** makes
a timestamped `.bak-` copy first.

## Tests

No monitors required: everything runs from JSON fixtures, including three- and
four-monitor desktops, two identical monitors without serial numbers, a rotated
monitor and a monitor that reports no modes.

```bash
bash ~/.config/hypr/scripts/tests/run-all.sh
```

`test-no-hardcoded-outputs.sh` is the one that answers "is this still specific
to one machine?" — it fails if a port name such as `eDP-1` reappears in any
script.

## Rollback

The files replaced when this was installed are in
`~/.config/hypr/backups/multi-monitor-<timestamp>/`.

```bash
B=~/.config/hypr/backups/multi-monitor-<timestamp>   # pick the one you want
pkill -f 'Monitor[W]atcher' || true
cp "$B"/{WaybarStartup.sh,Refresh.sh,WaybarLayout.sh,Kool_Quick_Settings.sh,LidSwitch.sh} ~/.config/hypr/scripts/
cp "$B"/user_keybinds.lua ~/.config/hypr/UserConfigs/
cp "$B"/lib_copy.sh ~/Documents/Dev/Hyperland/Hyprland-Dots/scripts/   # repo only
rm -f ~/.config/hypr/scripts/{DisplayProfile.sh,DisplayProfileMenu.sh,DisplayProfileSetup.sh,MonitorWatcher.sh,lib_display_store.sh}
rm -rf "$XDG_RUNTIME_DIR/kooldots-display-profiles" "$XDG_RUNTIME_DIR"/kooldots-display-profile.lock "$XDG_RUNTIME_DIR"/kooldots-monitor-watcher.lock
hyprctl reload
```

`UserConfigs/display-layouts.json` is yours; deleting it only forgets your
layouts. Remove the `MonitorWatcher.sh` line from `UserConfigs/user_startup.lua`
to stop it starting at login.
