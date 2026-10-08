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

## How a layout is stored

Applying a layout does two things. It calls `hl.monitor` for the session you are
in, and it writes the same rules to `UserConfigs/monitors.lua`.

That file is not a cache. `lua/monitors.lua` loads it on every config load, and
`UserConfigs/user_laptops.lua` reads its rules from the same place — which is
why the two are not competing controllers. It is what makes a layout survive a
reload, a restart and a lid event, and it is the reason `user_laptops.lua` is
still enabled.

The file it writes carries a marker line saying it was generated. **Delete that
marker line to take the file over**: from then on it is treated as yours, it is
never overwritten, and the lid logic still honours what it says.

## When it deliberately does nothing

**If you configure monitors yourself**, the system stands down. Specifically: if
`UserConfigs/monitors.lua` contains an uncommented `hl.monitor(...)` line that
this system did not write, and the monitor set in front of you has no saved
layout, nothing is applied and a line is written to the log.

The marker line is what separates the two cases. Without it, the file this
system generates would itself look like user configuration, and the system would
stand down for every newly plugged-in monitor the moment it had written the file
once.

**Saving one layout for that monitor set hands control over** — from then on,
this system manages that set regardless of your own `hl.monitor(...)` lines.

So "it does nothing" is the expected outcome in exactly one case: you wrote your
own rules and have not saved a layout for the monitors in front of you. Either
save a layout, or comment your rules out.

## The Monitor Profiles menu

Reached from Quick Settings (`SUPER` + `SHIFT` + `E`) → **Choose Monitor
Profiles**. This is a front end for the same system, not a second one. It lists,
in one place:

- the layouts saved for the monitors in front of you, which it applies through
  `DisplayProfile.sh` exactly as the layout menu does; and
- the `.lua` files in `Monitor_Profiles/`, offered as a **one-way import**:
  choosing one applies that profile and saves what is on screen as a layout
  under the same name, after which it restores automatically like any other
  layout.

`Monitor_Profiles/Work.lua` ships as an example profile: one `preferred` / `auto`
/ `1` rule per output, matched by port, covering `eDP-1`, `DP-1`..`DP-3` and
`HDMI-A-1`/`HDMI-A-2`. Copy it, edit it, or add your own file. Importing one is
how a profile gets into the store - it is not a second place layouts live, and a
profile matched by port does not follow a monitor moved to another port.

## Running nwg-displays directly

`nwg-displays` writes a `monitors.conf` that this Lua config never reads, and it
applies its own arrangement by dispatching `dpms` and running `hyprctl reload`.
That reload re-runs the Lua config, so what you dragged is briefly replaced by
the stored layout.

The watcher bridges the gap. It watches `~/.config/hypr/monitors.conf` - nwg's
own default - and when that file changes it hands it to the controller, which
applies it and writes `UserConfigs/monitors.lua`. So **you can run
`nwg-displays` however you like**: from the layout menu, a launcher, or a
terminal. Nothing has to know that you launched it, because the signal is the
file changing, not the process.

The arrangement lands within about two seconds of pressing **Apply**, and the
screens may jump back once in between. That is nwg's own reload applying the
stored layout before the import replaces it; the end state is what you dragged.

While nwg-displays is open the watcher drops monitor and reload events, so its
reload cannot undo the drag before the import lands. That check is by process
name, so it works for a run the menu did not start.

## Do not add `require("monitors")`

From 0.4.3, `nwg-displays` also writes a Lua sibling next to its `.conf`, at
`~/.config/hypr/monitors.lua`. **This config never loads that path, on purpose:**
`lua/monitors.lua` loads `UserConfigs/monitors.lua`, which the controller owns,
and that separation is what keeps one writer in charge.

`nwg-displays`' own README tells Hyprland 0.55+ users to add
`require("monitors")`. Do not: it would make the sibling live, and it would then
compete with `UserConfigs/monitors.lua` for the same monitors. Leave the sibling
alone and let the watcher import the arrangement instead.

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
- **An arrangement made in `nwg-displays` has no name yet.** The program knows
  nothing about monitor sets, so the menu reopens afterwards and offers to save
  it. Until you do, it is applied and written to `UserConfigs/monitors.lua` (so
  a reload does not undo it), but it is not what a newly connected monitor
  restores. Quick Settings' own `nwg-displays` entry behaves the same way.
- **`nwg-displays` applies its own arrangement and reloads Hyprland.** Its
  reload re-runs the Lua config, which does not read the file nwg writes, so the
  screens can jump back for a moment before the import re-applies your drag.
  That is expected; the end state is the arrangement you made.
- **A run of `nwg-displays` you started yourself is imported too.** The watcher
  watches nwg's own `monitors.conf`, so the menu is a convenience, not a
  requirement. See "Running nwg-displays directly" above.
- **Mirroring and 10-bit colour are refused, not dropped.** `nwg-displays` can
  express both, a layout cannot, and applying a mirrored arrangement as a plain
  one would silently un-mirror it. The import fails and names the setting
  instead; use the parameter table for those monitors.
- **Never zero screens.** Any monitor may be switched off, including a laptop
  panel, but the enabled monitors are applied and verified *before* anything is
  switched off, and if a layout would leave nothing active the system restores
  every connected monitor at scale 1.

## Files

| Path | What it is |
|---|---|
| `UserConfigs/display-layouts.json` | Your layouts. The installer only ever *adds* this file when it is missing, so an upgrade cannot overwrite it. |
| `UserConfigs/monitors.lua` | Generated: the layout that is applied, as `hl.monitor` rules. Loaded by `lua/monitors.lua` and read by `user_laptops.lua`. Delete its marker line to take it over. |
| `scripts/lib_display_store.sh` | The data model. Pure: no `hyprctl`, no session state. |
| `scripts/DisplayProfile.sh` | The only thing that changes monitors, focus and Waybar. |
| `scripts/DisplayProfileMenu.sh` | `SUPER`+`ALT`+`D`. |
| `scripts/DisplayProfileSetup.sh` | The parameter table. |
| `scripts/MonitorWatcher.sh` | Watches Hyprland's event socket, and `~/.config/hypr/monitors.conf` so a directly-run `nwg-displays` is imported. One per session. |
| `scripts/MonitorProfiles.sh` | Quick Settings → **Choose Monitor Profiles**: this system's layouts, plus a one-way import of `Monitor_Profiles/`. |
| `Monitor_Profiles/Work.lua` | An example profile: one `preferred`/`auto`/`1` rule per output, matched by port. |
| `scripts/tests/` | The 504-check suite. It is installed with the rest of `config/hypr`, so it is available on an installed system too - run it with `bash ~/.config/hypr/scripts/tests/run-all.sh`. |

Runtime state lives in `$XDG_RUNTIME_DIR/kooldots-display-profiles/`:
`display-profile.log`, `monitor-watcher.log`, `current` (the fingerprint and the
running layout's name), `active-layout.json` and `active-layout.fingerprint`
(what is on screen now), `config-active`, `pause`, `monitors*.json` scratch
files, `nwg-import.stamp` (what the watcher has already imported), and the
throwaway `nwg-monitors.discard.conf` the menu points `nwg-displays` at. The
`.conf` suffix on that last one matters: `nwg-displays` derives the Lua file it
also writes from it, and a path without it makes nwg write to
`~/.config/hypr/monitors.lua` instead.

> **If you update these scripts by hand, never copy the repo's
> `UserConfigs/display-layouts.json` over your own.** The repo ships it empty,
> on purpose, so a blind `cp -r` of the repo tree erases every layout you have
> saved. The installer is safe — it only adds that file when it is missing —
> but a manual copy is not. Copy the `scripts/` files and leave that one alone.

## Command line

```
DisplayProfile.sh auto                  decide and apply
DisplayProfile.sh reapply               put back the layout already on screen
DisplayProfile.sh -- <layout>           apply a named layout of this set
DisplayProfile.sh capture -- <name>     save the live state under a name
DisplayProfile.sh set-default -- <name> make it this set's default
DisplayProfile.sh delete -- <name>      delete a layout
DisplayProfile.sh label -- <text>       name this monitor set
DisplayProfile.sh list                  layout names for this set
DisplayProfile.sh monitors-json          path to the normalized monitor list
DisplayProfile.sh waybar-config          the config path Waybar should run
DisplayProfile.sh import-nwg <file>      apply what nwg-displays wrote
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

`test-lua-syntax.sh` parses every `.lua` file under the config with `luac`. Worth
knowing because a syntax error in any one of them takes the whole config load
down, and the `UserConfigs` files are loaded through a `pcall`, so the failure is
silent — the file simply stops running.

## Rollback

Take a copy of the files the feature touches before you start, then put them
back:

```bash
# Stop the watcher first, or it will keep re-applying a layout.
pkill -f 'Monitor[W]atcher' || true

# Your own pre-change copies, or the backups copy.sh makes. Keep them BESIDE the
# config directory - copy.sh uses ~/.config/hypr-backup-<timestamp> - never
# inside it: every .lua file under ~/.config/hypr is part of the configuration,
# so a copy of a file that was already broken there fails a syntax sweep (and a
# copy of a working one is a second copy of the same rules).
B=<your-backup-dir>
cp "$B"/{WaybarStartup.sh,Refresh.sh,Kool_Quick_Settings.sh,LidSwitch.sh,MonitorProfiles.sh} \
   ~/.config/hypr/scripts/
cp "$B"/user_keybinds.lua ~/.config/hypr/UserConfigs/

# In the repo checkout: scripts/lib_copy.sh, UserConfigs/user_startup.lua,
# UserConfigs/user_laptops.lua, UserConfigs/user_keybinds.lua, and
# patches/80-display-layouts.sh.

rm -f ~/.config/hypr/scripts/{DisplayProfile.sh,DisplayProfileMenu.sh,DisplayProfileSetup.sh,MonitorWatcher.sh,lib_display_store.sh}
rm -rf "$XDG_RUNTIME_DIR/kooldots-display-profiles" \
       "$XDG_RUNTIME_DIR"/kooldots-display-profile.lock \
       "$XDG_RUNTIME_DIR"/kooldots-monitor-watcher.lock
hyprctl reload
```

Three things are yours rather than the feature's, and are safe to keep:
`UserConfigs/display-layouts.json` (deleting it only forgets your layouts) and
`UserConfigs/monitors.lua`. To stop it starting at login, remove the
`MonitorWatcher.sh` line from `UserConfigs/user_startup.lua`.
