# Multi-Monitor Display Layouts

> A fork addition to KooL's Hyprland Dots. It remembers how you arrange your
> monitors and restores that arrangement automatically whenever the same set of
> monitors is connected — on a laptop or a desktop, with any number of screens.
> Nothing in it is tied to one specific machine.

For day-to-day use, press **`SUPER` + `ALT` + `D`**. Everything starts there.

This page describes **what the feature does, how it is built, and how to use
it**. For deep operational detail — every CLI verb, troubleshooting commands,
the exact rollback procedure — see
[`config/hypr/scripts/README-display-profiles.md`](config/hypr/scripts/README-display-profiles.md).

---

## What it does

When the set of connected monitors changes — you plug one in, unplug one, close
the lid — the system detects it and applies the layout you saved for *that set
of monitors*. If you never saved one, it arranges the monitors side by side and
leaves them usable, so a fresh install works out of the box.

Three ideas carry the whole design:

- **A monitor is identified by the device** (`make | model | serial`), not by
  the port it is plugged into. Move a monitor from `DP-2` to `HDMI-A-1` and the
  same layout still applies.
- **A monitor set is the sorted list of those identities** — the key your
  layouts are stored under. Two monitors at home and three at the office are
  simply two different keys.
- **A layout is a named arrangement** of one monitor set: per monitor its
  on/off, mode, scale, rotation and position, plus which monitor is focused and
  which show a Waybar bar.

You can keep several named layouts for the same monitors (`Home`, `Work`,
`Game`), with one marked as the default that is applied automatically.

## How it is built

A single boundary runs through the whole thing: **who may change the running
session.**

```
  lib_display_store.sh   — pure data model (identity, fingerprint, store,
                           geometry, resolve, generate, capture, nwg parse).
                           No hyprctl, no session state: JSON in, JSON out.
        │ sourced by
  DisplayProfile.sh      — the ONLY component that calls hl.monitor. Applies,
                           verifies, falls back to a rescue layout, handles the
                           lid, drives Waybar, imports from nwg-displays.
        │ driven by
  DisplayProfileMenu.sh  — the SUPER+ALT+D rofi menu (rows built per monitor set)
  DisplayProfileSetup.sh — the grid parameter table
  MonitorWatcher.sh      — watches Hyprland's socket2 and calls the controller
```

Because the data model never touches the session, the entire logic is tested
from JSON fixtures with no monitors attached — **439 automated checks** cover
three- and four-monitor desktops, two identical monitors with no serial, a
rotated monitor, a closed lid and the nwg-displays bridge.

**New files** (all under `config/hypr/`):

| File | Role |
|---|---|
| `scripts/lib_display_store.sh` | Pure data model |
| `scripts/DisplayProfile.sh` | Sole owner of session state |
| `scripts/DisplayProfileMenu.sh` | `SUPER+ALT+D` menu |
| `scripts/DisplayProfileSetup.sh` | Grid parameter table |
| `scripts/MonitorWatcher.sh` | socket2 watcher (one per session) |
| `scripts/README-display-profiles.md` | Full operational guide |
| `UserConfigs/display-layouts.json` | Your saved layouts (ships empty) |
| `scripts/tests/` | 10 suites + 34 fixtures |

**Existing dotfiles files adjusted** (small, each with a fallback so the dots
still work without this feature): `WaybarStartup.sh`, `Refresh.sh`,
`WaybarLayout.sh`, `Kool_Quick_Settings.sh`, `LidSwitch.sh`, `lib_copy.sh`,
`UserConfigs/user_keybinds.lua`, `UserConfigs/user_startup.lua`, and
`UserConfigs/user_laptops.lua` (disabled, because it was a second monitor
controller that fought this one — see "Coexistence").

## Getting started

Nothing needs to be configured. Plug monitors in and you get a working
arrangement. To keep one:

1. Arrange the monitors — either
   - `SUPER`+`ALT`+`D` → **Arrange monitors — drag and drop** (opens
     `nwg-displays`), or
   - `SUPER`+`ALT`+`D` → **Edit parameters (table)** (no extra program).
2. `SUPER`+`ALT`+`D` → **Save current state as…** and give it a name.

Connecting that set of monitors later applies that layout automatically.

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

The layouts at the top are the ones saved for the monitors in front of you, so
the list changes with them. `SUPER`+`ALT`+`W` applies a layout named `Work`
directly without opening the menu.

## The parameter table

Change each monitor's on/off, mode, scale and rotation, and place it on a grid
(row + order within the row + vertical alignment). **You never type
coordinates** — positions are computed from the logical size (`mode ÷ scale`),
which removes the arithmetic mistake the old hardcoded setup invited. The table
is also the only place to set which monitor is *primary*, which are *off* in a
layout, and where the *bars* go.

## Drag-and-drop with nwg-displays

On this Lua-config fork, `nwg-displays` can only *write a file*; it does not
apply anything at runtime, because the fork does not `source` that file. So the
menu **bridges** it: open `nwg-displays` through *Arrange monitors*, drag and
set scale, press **Apply**, then close. The system reads what nwg wrote, applies
it through `hl.monitor` (the change takes effect as you close the window), and
the menu reopens offering to save it. Run `nwg-displays` *directly* from a
terminal and this bridge does not run, so the arrangement is lost — always go
through the menu.

## Waybar

Each layout picks one: bars on **all** monitors (the default — nothing is
generated, your own config runs), on the **primary** monitor only, or on a
**selected** set. The active Waybar layout is reused; your choice of layout
(`SUPER`+`ALT`+`B`) is untouched.

## Lid / clamshell

Closing the laptop lid while an external monitor is connected switches the
internal panel off; opening it or unplugging the external brings it back. The
system never leaves you with zero active screens — a shut laptop with no
external keeps its panel on.

## Coexistence — when it deliberately does nothing

If you configure monitors yourself (an uncommented `hl.monitor(...)` in
`UserConfigs/monitors.lua`, or a profile chosen through `MonitorProfiles.sh`)
and the current monitor set has no saved layout, the system stands down and
leaves your configuration alone. Saving one layout for that monitor set hands
control over. This is why `user_laptops.lua` was disabled: it reacted to the
same monitor and lid events and fought this system; its clamshell behaviour is
now handled here instead.

## Command line

```
DisplayProfile.sh auto                  decide and apply
DisplayProfile.sh -- <layout>           apply a named layout of this set
DisplayProfile.sh capture -- <name>     save the live state under a name
DisplayProfile.sh set-default -- <name> make it this set's default
DisplayProfile.sh delete -- <name>      delete a layout
DisplayProfile.sh label -- <text>       name this monitor set
DisplayProfile.sh import-nwg <file>     apply what nwg-displays wrote
DisplayProfile.sh --dry-run auto        print the plan, change nothing
```

## Testing

No monitors required — everything runs from fixtures:

```bash
bash config/hypr/scripts/tests/run-all.sh
```

## More

Troubleshooting, the state directory, every edge case, and the exact rollback
procedure live in
[`config/hypr/scripts/README-display-profiles.md`](config/hypr/scripts/README-display-profiles.md).
