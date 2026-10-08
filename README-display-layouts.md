# Multi-Monitor Display Layouts

> Remembers how you arrange your monitors and restores that arrangement whenever
> the same set of monitors is connected — on a laptop or a desktop, with any
> number of screens. Nothing in it is tied to one specific machine.

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
                           lid, drives Waybar, imports from nwg-displays, and
                           writes the result to UserConfigs/monitors.lua.
        │ driven by
  DisplayProfileMenu.sh  — the SUPER+ALT+D rofi menu (rows built per monitor set)
  DisplayProfileSetup.sh — the grid parameter table
  MonitorProfiles.sh     — SUPER+SHIFT+E: the same layouts, plus a one-way
                           import of the legacy Monitor_Profiles/ files
  MonitorWatcher.sh      — watches Hyprland's socket2 and calls the controller
```

Applying a layout does two things: it changes the session, and it writes the
same rules to `UserConfigs/monitors.lua`. That file is not a cache —
`lua/monitors.lua` loads it on every config load, and `UserConfigs/user_laptops.lua`
reads its rules from the same place. It is what makes a layout survive a reload,
a restart and a lid event, and it is why the laptop controller does not have to
be switched off for this one to work.

Because the data model never touches the session, the entire logic is tested
from JSON fixtures with no monitors attached — **495 automated checks** cover
three- and four-monitor desktops, two identical monitors with no serial, a
rotated monitor, a closed lid, the nwg-displays bridge and the installer patch.

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
| `scripts/tests/` | 9 suites + 33 fixtures |

**Existing files changed**, each with a fallback so the dots still work without
this feature: `WaybarStartup.sh` and `Refresh.sh` (ask the controller which
Waybar config to run, and fall back to the plain one), `Kool_Quick_Settings.sh`
(the nwg-displays entry), `LidSwitch.sh`, `MonitorProfiles.sh` (now a front end
for this system), `scripts/lib_copy.sh` (ships the store, add-only),
`UserConfigs/user_keybinds.lua` and `UserConfigs/user_startup.lua` — and
`patches/80-display-layouts.sh`, which is what puts those last two into an
install that already has them.

## Getting started

Nothing needs to be configured. Plug monitors in and you get a working
arrangement. To keep one:

1. Arrange the monitors — either
   - `SUPER`+`ALT`+`D` → **Arrange monitors — drag and drop** (opens
     `nwg-displays`), or
   - `SUPER`+`ALT`+`D` → **Edit parameters (table)** (no extra program).
2. `SUPER`+`ALT`+`D` → **Save current state as…** and give it a name.

Connecting that set of monitors later applies that layout automatically.

Step 2 is about the *name*, not about whether the arrangement survives: the
arrangement is written to `UserConfigs/monitors.lua` as soon as it is applied,
so a reload or a restart brings it back. What a name buys you is a choice — an
unnamed arrangement is replaced by the set's saved layout the next time that set
of monitors is connected.

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

`nwg-displays` writes a `monitors.conf` that this Lua config never reads, and it
applies its own arrangement by dispatching `dpms` and running `hyprctl reload`.
That reload re-runs the Lua config, so what you dragged is briefly replaced by
the stored layout.

The watcher bridges the gap: it notices that nwg wrote the file, reads it,
applies it through `hl.monitor` and writes it to `UserConfigs/monitors.lua`. So
the drag both takes effect and sticks.

**Run it however you like** — from the layout menu, a launcher, or a terminal.
The result is the same, because the watcher watches the *file*, not the process.
The menu's own entry additionally reopens offering to save the arrangement under
a name; after a direct run, use `SUPER`+`ALT`+`D` → **Save current state as…**.

Three things worth knowing:

- The arrangement lands within about two seconds of pressing **Apply**, and the
  screens may jump back once in between. That is `nwg-displays`' own reload
  applying the stored layout before the import replaces it, and the end state is
  what you dragged.
- Mirroring and 10-bit colour are expressible in `nwg-displays` but not in a
  layout. Rather than silently applying a mirrored arrangement as a plain one,
  the import refuses and names the setting; use the parameter table for those
  monitors.
- **Do not add `require("monitors")` to your Hyprland config.** `nwg-displays`
  0.4.3+ writes a Lua sibling at `~/.config/hypr/monitors.lua`, and this config
  deliberately never loads that path. Adding the `require` makes it live, and it
  then competes with `UserConfigs/monitors.lua` for the same monitors. Its own
  README suggests that line for Hyprland 0.55+; ignore it here.

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

Lid handling lives in `UserConfigs/user_laptops.lua`, which is still enabled. It
reads the same `UserConfigs/monitors.lua` this system writes, so the two agree
rather than fighting; this system additionally honours the lid when it applies a
layout, so a layout applied with the lid shut does not light the panel back up.

## Coexistence — when it deliberately does nothing

If you configure monitors yourself (an uncommented `hl.monitor(...)` in
`UserConfigs/monitors.lua` that this system did not write) and the current
monitor set has no saved layout, the system stands down and leaves your
configuration alone. Saving one layout for that monitor set hands control over.

The generated file carries a marker line saying so, and a marked file never
counts as your configuration — otherwise the system would stand down for every
newly plugged-in monitor as soon as it had written the file once. Delete the
marker line to take the file over.

`Monitor Profiles` (Quick Settings → **Choose Monitor Profiles**) is a front end
for this system rather than a second one: it lists the layouts saved for the
monitors in front of you, and offers the `.lua` files in `Monitor_Profiles/` as
a one-way import.

## Command line

```
DisplayProfile.sh auto                  decide and apply
DisplayProfile.sh reapply               put back the layout already on screen
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
