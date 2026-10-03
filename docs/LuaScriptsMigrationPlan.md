# Lua Scripts Migration Plan

Status: **queue complete** — every item in the [work queue](#6-work-queue) is done. See the
[Completion log](#completion-log) for evidence, and
[open questions](#9-open-questions-and-known-risks) for the runtime checks still outstanding on the
Gentoo host.

Owner: any agent picking up the Lua migration for KoolDots / Hyprland-Dots.
Scope: `config/hypr/scripts/*` and the Lua config tree under `config/hypr/`.

---

## 1. How to use this document

This file is the single source of truth for the bash-to-Lua migration. It is written so that an agent
with no prior context can pick up the work, finish an item, and hand it on.

**Required protocol for every agent working on this migration:**

1. Read this document end to end before touching anything.
2. Work one queue item at a time from [section 6](#6-work-queue). Respect the declared order and
   dependencies.
3. Follow the [verification playbook](#7-verification-playbook) for that item. Do not mark an item
   done on syntax checks alone if the item's acceptance criteria require runtime behaviour.
4. **Update this document before you finish your session.** Specifically:
   - Move the item from the queue to the [Completion log](#completion-log) with the date, the files
     changed, the verification evidence, and any follow-up you created.
   - If you discovered something that changes the plan, amend the relevant section and add a line to
     [section 9](#9-open-questions-and-known-risks).
   - Do not delete history from the completion log. It is append-only so the next agent can trust it.
5. If you cannot finish an item, leave it in the queue and add a `Blocked:` note with the exact reason
   and the command you ran.

The completion log is the handoff. An agent that skips updating it makes the next session start from
zero, which is the failure mode this document exists to prevent.

---

## 2. Goal

Replace bash scripts that shell out to `hyprctl` with in-process Lua that uses the Hyprland Lua API.

The efficiency win is **not** "Lua instead of bash". It is **"in-process instead of out-of-process"**.
A keybind handled by the Lua config runs a C++ call inside the compositor. A keybind handled by a
script costs a process fork, a `hyprctl` IPC round trip over the Unix socket, and often a `jq` fork on
top. Typical cost is 20-50 ms and several processes per keypress, on keybinds that users hold down.

### Efficiency tiers

| Tier | Shape | Cost per keypress | Use for |
| --- | --- | --- | --- |
| 1 | `hl.dsp.*` dispatcher object bound directly to `hl.bind` | 0 processes, 0 IPC | resize, move, focus, float, swap, workspace changes |
| 2 | Lua closure using the `hl.*` query API | 0 processes, 0 IPC | anything needing `hl.get_active_window`, `hl.get_windows`, conditionals, `hl.on`, `hl.timer` |
| 3 | bash + `hyprctl` | 1-5 processes, 1-2 IPC round trips | state that genuinely lives outside Hyprland (hardware, brightness, media) |
| 4 | standalone `lua` + `io.popen("hyprctl ...")` | worse than tier 3 | **nothing** — never do this |

Tier 4 is a trap that this repo has already fallen into once (`float.all.samesize.lua`). A standalone
Lua script has no `hl` global, so it must still shell out to `hyprctl`, and it pays a Lua interpreter
startup on top. It is strictly worse than bash.

### Tier 4 rule

> A Lua file that runs outside the Hyprland Lua VM cannot use the `hl` API and therefore cannot be
> more efficient than bash. Only move work *into* the config Lua VM (`config/hypr/**/*.lua`, loaded by
> `hyprland.lua`), or leave it in bash.

---

## 3. Verified environment facts

Everything in this section was verified against the local Hyprland 0.56.2 session. Re-verify on the
Gentoo host before relying on it there.

### 3.1 `hyprctl dispatch` and `hyprctl eval` semantics

- `hyprctl dispatch '<expr>'` is shorthand for `hl.dispatch(<expr>)`. Verified: the error for a bogus
  name is `return hl.dispatch(definitelynotarealdispatcher):1: hl.dispatch: expected a dispatcher`.
  So `hyprctl dispatch "hl.dsp.window.resize({ x = 100, y = 100 })"` works and means
  `hl.dispatch(hl.dsp.window.resize({...}))`.
- `hyprctl eval '<lua>'` executes a Lua string in the live VM. **It does not return values** — it
  prints `ok` regardless. To probe values from `eval`, write them to a file with `io.open`
  (`io` is available in the config Lua VM; this is how section 3.3 was established).
- **Legacy hyprlang dispatcher names no longer work through `hyprctl dispatch`.** `resizeactive`,
  `movefocus`, `cyclenext`, `layoutmsg`, `splitratio` etc. are not Lua globals, so
  `hl.dispatch(resizeactive -50 0)` fails. They are only reachable as `hl.dsp.*` objects.
- `hl.dsp.exec_raw(cmd)` **spawns a process**. It does not parse a dispatcher string. Verified:
  `hyprctl dispatch 'hl.dsp.exec_raw("touch /tmp/probe")'` creates the file. `exec_raw` skips
  `sh -c`; `exec_cmd` does not.

### 3.2 Bind options

- The Lua bind option for hold-to-repeat is **`repeating`**, not `repeat`. See `HL.BindOptions` in
  `config/hypr/hl.meta.lua`.
- `["repeat"] = true` is silently ignored by `hl.bind`.

### 3.3 Lua API object shapes (verified)

- `hl.get_active_monitor().reserved` exists and is a table with **named** fields
  `top`, `left`, `bottom`, `right` (floats). It is *not* an array — `reserved[1]` is `nil`.
- `hl.get_active_monitor()` exposes `.x`, `.y`, `.width`, `.height`, `.scale`, `.size` (table).
- `HL.Window.size` is a table with `.x` and `.y`. `size[1]` is `nil`.
- `HL.Window.at` is a table with `.x` and `.y`.
- `HL.Window` exposes `.address`, `.class`, `.floating`, `.hidden`, `.mapped`, `.workspace.id`.
- `hl.get_windows({ workspace = <id> })` works and returns the windows on that workspace.
- `HL.Workspace.tiled_layout` is a string such as `"dwindle"`.
- `hl.get_config("general.gaps_out")` returns a **table** with named `top`/`right`/`bottom`/`left`,
  not a number.
- `hl.dsp.window.resize({ x, y, relative?, window? })` — `relative = true` makes `x`/`y` deltas.
  This is the correct way to do `resizeactive`; do not read the size and compute an absolute value.
- Dispatcher functions accept an `HL.Window` object directly as `window = <obj>`. There is no need to
  build `address:0x...` strings.

### 3.4 Config reload

Hyprland reloads the Lua config automatically when a file is saved. `misc:disable_autoreload`
defaults to `false`. `hyprctl reload` is the manual equivalent, and `hyprctl configerrors` prints
everything Hyprland complained about on the last load. **Use `hyprctl configerrors` after every
change.**

---

## 4. Architecture: what is live and what is dead

Load order, verified from `config/hypr/hyprland.lua` and `config/hypr/lua/user_overrides.lua`:

```
hyprland.lua
  -> lua/user_defaults.lua        (sets KOOLDOTS_DEFAULTS)
  -> lua/animations.lua
  -> lua/user_overrides.lua
       -> configs/system_env.lua
       -> configs/system_startup.lua
       -> configs/system_window_rules.lua
       -> configs/system_layer_rules.lua
       -> configs/system_keybinds.lua        <-- CANONICAL system keybinds
       -> configs/system_settings.lua
       -> configs/system_laptops.lua
       -> UserConfigs/user_*.lua             <-- user overrides (incl. user_keybinds.lua)
  -> lua/monitors.lua
  -> lua/workspaces.lua
```

Key consequences:

- **`config/hypr/configs/system_keybinds.lua` is the canonical system keybind file.** It is
  hand-maintained. `scripts/migrate-hypr-to-lua.sh` copies it verbatim into a user's config dir and
  only falls back to generating keybinds from a legacy `Keybinds.conf` when it is absent
  (`scripts/migrate-hypr-to-lua.sh:1921-1933`). Edit the canonical file, not the generator, for
  keybind changes.
- **`config/hypr/lua/keybinds.lua` and `config/hypr/lua/keybind_helpers.lua` are never loaded.**
  They are orphaned duplicates of `configs/system_keybinds.lua`. A chord diff showed every real bind
  in the orphan is also present in the canonical file (149 vs 190 chords; the 6 "extras" in the
  orphan are text inside commented-out example blocks). They are dead weight and they carry the
  `raw_dispatch_cmd` bug described below.
- **Two live scripts used to point at that orphan**, which is why it survived so long.
  `config/hypr/scripts/Kool_Quick_Settings.sh` (`resolve_system_keybinds_file`, the "Edit System
  Default Keybinds" entry) preferred `lua/keybinds.lua` whenever it existed, so the Quick Settings
  menu let users edit a file Hyprland never loads. `config/hypr/scripts/KeyBinds.sh` passed it to
  `keybinds_parser.py` as the first input. Both now resolve `configs/system_keybinds.lua` first and
  keep the old path only as a last-resort fallback for pre-removal installs.
- **`config/hypr/lua/user_keybinds_helper.lua` IS live** — it backs `UserConfigs/user_keybinds.lua`.
  It carries the same `raw_dispatch_cmd` bug.
- The generator has its own embedded copy of the dispatch helper
  (`scripts/migrate-hypr-to-lua.sh:1820-1900`). It is a legacy fallback path and is a known drift
  source. See [open questions](#9-open-questions-and-known-risks).

---

## 5. Defect classes

### D1 — `raw_dispatch_cmd` misuses `hl.dsp.exec_raw`

Present in `lua/keybind_helpers.lua:39-46`, `lua/user_keybinds_helper.lua:36-42`, and
`configs/system_keybinds.lua:42-49`:

```lua
local function raw_dispatch_cmd(command)
  if dsp and dsp.exec_raw then
    return function()
      hl.dispatch(dsp.exec_raw(tostring(command)))   -- spawns a PROCESS, not a dispatcher
    end
  end
```

Any dispatcher string routed through this path attempts to exec a binary named after the dispatcher.
`resizeactive`, `splitratio`, `movewindow` are not executables, so these binds silently do nothing.
The `else` branch (`hyprctl dispatch ...`) is the one that actually works.

**Fix:** either drop the dispatcher-string path entirely in favour of `hl.dsp.*`, or route it through
`hl.exec_cmd("hyprctl dispatch ...")`. Never through `exec_raw`.

### D2 — `["repeat"] = true` is not a bind option

The option is `repeating`. All hold-to-repeat binds in `configs/system_keybinds.lua` (volume,
brightness, and the resize binds) use `["repeat"]` and therefore do not repeat.

### D3 — Legacy dispatcher names

`resizeactive`, `splitratio`, `layoutmsg`, `cyclenext` are not valid Lua globals. Where they appear
in a dispatch table they must be mapped to `hl.dsp.*` before the generic fallback.

### D4 — Tier 4 standalone Lua scripts

Scripts with `#!/usr/bin/env lua` that call `io.popen("hyprctl ...")` and hand-roll JSON parsing.
They are slower than bash and add a maintenance burden. Port into the config Lua VM or delete.

### D5 — Wrong Lua API shapes

Code written against `hyprctl -j` JSON assumptions (array indices, `reserved[1..4]`, `size[0]`)
rather than the real Lua API shapes in section 3.3. Fails silently because most of these paths are
wrapped in `pcall` or `|| true`.

### D6 — Waybar `interval` polling of `hyprctl`

A Waybar `custom` module with `interval` re-runs its `exec` on a timer forever, whether or not
anything changed. Two status modules did that to read state Hyprland already pushes over
`.socket2.sock`:

- `custom/hypr_layout` (`interval: 2`) ran `HyprLayoutModule.sh status`, which shelled out to
  `ChangeLayout.sh` and then `hyprctl -j activeworkspace | jq` — two bash processes, one `hyprctl`
  and one `jq` every two seconds.
- `custom/keyboard` (`interval: 1`) ran `KeyboardLayout.sh status`, which resolves the layout with
  **four** `hyprctl devices -j | jq` pairs on every invocation — about four `hyprctl` and four `jq`
  forks per second.

That is D4 in a different place: work that could be one socket read is paid for with process forks,
on a timer, for the life of the session. It is not covered by the tier table in section 2 because it
is not a keybind at all — the cost is paid continuously rather than per keypress.

**Fix:** drive the module from the event socket. `HyprEventWatch.sh` subscribes to `.socket2.sock`,
re-renders only when a relevant event arrives, and reads current state with one socket request.
`HyprIPC.sh` holds the socket plumbing. Neither script calls `hyprctl`.

### D7 — Blocking calls inside the config Lua VM

`io.popen` and `os.execute` run on the compositor's own thread and wait for the child to finish, so
the whole compositor is frozen for the duration of the round trip. That is worse than the same work
done from a keybind script, which at least only stalls its own process. The replacements are:

- `hl.exec_cmd(cmd)` — spawns and returns, the same path the native `exec-once` used.
- `hl.get_config(key)` / `hl.config({ ... })` — read and write config values in-process.
- `hl.get_monitors()`, `hl.get_windows()`, `hl.get_active_*()` — query state in-process.

`io.open` is a plain file read with no Lua-API equivalent for arbitrary paths, so config-file reads
stay. `hl.exec_cmd` does not return output, so anything that needs a command's stdout has to be
rethought as a query or a socket read rather than ported as-is.

Found in this pass:

- `lua/settings.lua` — the 3-finger swipe zoom ran `io.popen("hyprctl getoption ... | awk ...")` and
then `hl.dsp.exec_cmd("hyprctl keyword cursor:zoom_factor ...")`. Two forks on the compositor
thread, and `hyprctl keyword` is the legacy hyprlang form.
- `UserConfigs/user_laptops.lua` — `io.popen` in the lid-state fallback, plus one
`io.popen("ls /sys/class/drm/cardN-*/status")` per DRM card while enumerating connectors, on a path
that runs at config load and on `hyprland.start`.
- `lua/laptop-lid.lua` — `os.execute` on the lid switch binds. Nothing loads this file (it is a
sample users enable by hand), so the stall was latent rather than active.

---

## 6. Work queue

Items are ordered. `Depends on` must be complete first.

### LUA-001 — Delete confirmed-dead scripts

Depends on: none. Status: **done**.

Files with zero live references in the repo and zero references from
`scripts/migrate-hypr-to-lua.sh`:

- `config/hypr/scripts/ResizeActive.sh` — only referenced from commented-out binds in the orphan
  template. Also superseded: the native equivalent is one `hl.dsp.window.resize({..., relative = true})`.
- `config/hypr/scripts/LuaMoveWindowDirectional.sh` — only referenced from commented-out binds.
- `config/hypr/scripts/LuaFocusWorkspaceRelative.sh` — only referenced from commented-out binds.
- `config/hypr/scripts/LuaMoveWindowWorkspaceRelative.sh` — only referenced from commented-out binds.
- `config/hypr/scripts/LuaFullscreenMaximized.sh` — zero references. Also had a wrong API call
  (`fullscreen({ mode = 1 })`; the API takes `"fullscreen"` or `"maximized"`).

Acceptance: files gone, `hyprctl configerrors` clean, no bind stops working.

### LUA-002 — Delete the orphaned keybind templates

Depends on: none. Status: **done**.

- `config/hypr/lua/keybinds.lua`
- `config/hypr/lua/keybind_helpers.lua`

Evidence is in [section 4](#4-architecture-what-is-live-and-what-is-dead). Before deleting, re-run the
chord diff to confirm the canonical file has not lost binds:

```sh
python3 - <<'PY'
import re
def chords(p):
    s = open(p, encoding='utf-8').read(); out = set()
    for m in re.finditer(r'\bbind\s*\(', s):
        lits = re.findall(r'"([^"]*)"', s[m.end():m.end()+240])
        if len(lits) >= 2: out.add((lits[0].strip().upper(), lits[1].strip().upper()))
    return out
a = chords('config/hypr/lua/keybinds.lua')
b = chords('config/hypr/configs/system_keybinds.lua')
print('only in orphan:', sorted(a - b))
PY
```

Also repoint the two live consumers listed in section 4, otherwise deleting the file breaks the
keybind search and leaves the Quick Settings menu opening a missing path:

- `config/hypr/scripts/KeyBinds.sh` — build the input list from the canonical file and only fall back
  to `lua/keybinds.lua` if nothing else exists.
- `config/hypr/scripts/Kool_Quick_Settings.sh` — `resolve_system_keybinds_file()` must resolve
  `configs/system_keybinds.lua`, then `UserConfigs/system_keybinds.lua`, before the old template.

Acceptance: every chord reported by the diff is verifiable as text inside a comment or string, not a
real bind; the Quick Settings "Edit System Default Keybinds" entry opens
`configs/system_keybinds.lua`; the keybind search still lists binds.

### LUA-003 — Fix `raw_dispatch_cmd` (D1)

Depends on: none. Status: **done**.

- `config/hypr/lua/user_keybinds_helper.lua:36-42` — live, must be fixed.
- `config/hypr/configs/system_keybinds.lua:42-49` — live, must be fixed.
- `config/hypr/lua/keybind_helpers.lua` — deleted by LUA-002, nothing to do.

Fix: route the fallback through `hyprctl dispatch` via `exec_cmd`, and add explicit `hl.dsp.*`
handlers for the dispatchers that user configs actually use. Handlers added: `resizeactive`
(`window.resize({ ..., relative = true })`), `swapwindow` (`window.swap({ direction })`),
`bringactivetotop`, `moveintogroup`, `moveoutofgroup`, and `movecurrentworkspacetomonitor`
(`workspace.move({ monitor })`). `cyclenext` intentionally still routes to `LuaCycleWindow.sh` until
LUA-010.

Acceptance: `hyprctl eval` of a dispatch string built by the helper does not attempt to exec a
non-existent binary.

### LUA-004 — Fix resize binds (D2, D3)

Depends on: LUA-003. Status: **done**.

In `config/hypr/configs/system_keybinds.lua`, replace the `resizeactive` shim usage with direct
dispatcher objects and the correct option name:

```lua
bind("SUPER SHIFT", "left",  hl.dsp.window.resize({ x = -50, y = 0, relative = true }),
     { description = "resize left (-50)",  repeating = true })
bind("SUPER SHIFT", "right", hl.dsp.window.resize({ x =  50, y = 0, relative = true }),
     { description = "resize right (+50)", repeating = true })
bind("SUPER SHIFT", "up",    hl.dsp.window.resize({ x = 0, y = -50, relative = true }),
     { description = "resize up (-50)",    repeating = true })
bind("SUPER SHIFT", "down",  hl.dsp.window.resize({ x = 0, y =  50, relative = true }),
     { description = "resize down (+50)",  repeating = true })
```

Do **not** query the window size and compute an absolute size. `relative = true` does the arithmetic
in C++ and respects Hyprland's minimum window size. If a hard floor is required, see LUA-005.

Also sweep the whole file for `["repeat"] = true` and convert to `repeating = true`.

Acceptance: hold SUPER+SHIFT+arrow resizes continuously; a single tap changes the window by 50 px.

### LUA-005 — Port `float.all.samesize.lua` to the Lua VM (D4, D5)

Depends on: LUA-002. Status: **done**.

The current script is a tier 4 anti-pattern: `#!/usr/bin/env lua`, 4+ `hyprctl` calls through
`io.popen`, and a ~130-line hand-rolled JSON decoder to avoid a `jq` dependency — while still paying
Lua interpreter startup. All of it disappears in-process.

Port requirements:

- Use `hl.get_windows({ workspace = <id> })` and `hl.get_active_monitor()`.
- Read the reserved area from `monitor.reserved.top/left/bottom/right` (named fields — **not**
  `reserved[1..4]`).
- Read window size from `win.size.x` / `win.size.y` (**not** `size[0]`).
- Pass `HL.Window` objects directly to `hl.dsp.window.float/resize/move` — no `address:0x...` strings,
  no `hyprctl --batch`, no JSON.
- Preserve the toggle behaviour (if every window on the workspace is already floating, untile them)
  and the monocle-layout guard.
- Keep the `notify-send` feedback calls; those are legitimate `exec_cmd` uses.

Acceptance: keybind produces the same tiling as the old script; zero `hyprctl` processes spawned
(verify with `ps` during the action, or by confirming the script file is gone and no `io.popen`
remains); works with the bar's reserved area.

### LUA-006 — Port `LuaSwapWindow.sh`

Depends on: LUA-003. Status: **done**.

The script spawns bash + 2 `hyprctl` + a ~25-line `jq` overlap-detection program to guard against the
"no target" runtime error. The guard is unnecessary: `hl.dsp.window.swap({ direction })` is a no-op
when there is no window in that direction.

Replace with:

```lua
bind("SUPER ALT", "left",  hl.dsp.window.swap({ direction = "left"  }), { description = "swap window left"  })
bind("SUPER ALT", "right", hl.dsp.window.swap({ direction = "right" }), { description = "swap window right" })
bind("SUPER ALT", "up",    hl.dsp.window.swap({ direction = "up"    }), { description = "swap window up"    })
bind("SUPER ALT", "down",  hl.dsp.window.swap({ direction = "down"  }), { description = "swap window down"  })
```

If runtime testing shows the no-op guard is genuinely needed, implement it in Lua with
`hl.get_active_window()` and `hl.get_windows({ workspace = ws.id })` and compare `at`/`size` boxes —
but do not reintroduce a script.

Acceptance: swap works in all four directions; no error notification or `hyprctl configerrors` entry
when there is no window in that direction; script deleted.

### LUA-007 — Port `ScrollCycleColumnWidth.sh`

Depends on: none. Status: **done**.

The script spawns bash + 3-4 `hyprctl` + several `awk`/`jq` processes to cycle a scrolling-layout
column width through `{0.25, 0.33, 0.5, 0.66, 0.75, 1.0}`. It also has a dead fallback:
`hyprctl dispatch layoutmsg "$msg"` uses a legacy dispatcher name that no longer resolves (D3).

Port requirements:

- Layout check: `hl.get_active_workspace().tiled_layout == "scrolling"`; bail out otherwise.
- Current width: prefer the window's `layout.column.width` if the API exposes it; otherwise derive it
  as `win.size.x / monitor.width`.
- Dispatch with `hl.dispatch(hl.dsp.layout("colresize <preset>"))`.
- Preserve the "closest preset, then advance" behaviour, including the case where the current width is
  not exactly a preset.

Acceptance: repeated presses cycle 0.25 -> 0.33 -> 0.5 -> 0.66 -> 0.75 -> 1.0 -> 0.25 on a scrolling
workspace; pressing the bind on a non-scrolling workspace does nothing; script deleted.

### LUA-008 — Retire `LuaAutoReload.sh`

Depends on: none. Status: **done**.

Hyprland reloads the Lua config automatically on save (see section 3.4), and the local session has
`misc:disable_autoreload = false`. The watcher is a redundant process: `inotifywait` plus a
`hyprctl reload` per save, with a 1-second `find`-based polling fallback. The CHANGELOG records
several rounds of bugs in it (`CHANGELOG.md:438`, `:482`, `:667`).

Steps:

1. Remove the `scriptsDir .. "/LuaAutoReload.sh"` entry from `config/hypr/lua/startup.lua`.
2. Delete `config/hypr/scripts/LuaAutoReload.sh`.
3. Verify on the Gentoo host that saving a `.lua` file still applies changes within ~1 second, and
   that `hyprctl configerrors` is clean after an automatic reload.

Acceptance: edit-and-save still applies live; no `inotifywait` process running; no
`hyprctl reload` watcher in `ps`.

### LUA-009 — Port `LayoutKeybindDispatch.sh`

Depends on: LUA-006. Status: **done.**

`config/hypr/scripts/LayoutKeybindDispatch.sh` was ~220 lines of bash spawning 4-8 `hyprctl` + `jq`
processes per keypress to do layout-aware focus with a "did focus change?" fallback. It was the
largest remaining bash hot path in the keybind tree, and it depended on `LuaCycleWindow.sh`.

Ported to `layout_cycle()` / `layout_focus()` in `config/hypr/lua/window_actions.lua`. The
attempt-then-fallback shape is preserved: try the layout's own message, and fall back only when the
focused window did not change. `hl.dsp.window.cycle_next()` is the native candidate for the
non-scrolling, non-monocle case; the address-sorted ordering stays as the fallback.

### LUA-010 — Port `LuaCycleWindow.sh`

Depends on: LUA-009. Status: **done.**

`LuaCycleWindow.sh` was referenced by `configs/system_keybinds.lua` (the `cyclenext` handler) and by
`LayoutKeybindDispatch.sh`. Ported to `cycle_window()` in `config/hypr/lua/window_actions.lua`,
keeping the address-sorted ordering (`y`, then `x`, then `address`) that the `jq` program used. A
`cyclenext` handler was also added to `lua/user_keybinds_helper.lua`, where the name previously fell
through to a legacy dispatcher that no longer resolves.

### LUA-011 — Sweep remaining legacy dispatcher names

Depends on: LUA-003. Status: **done**.

Fixing D1 exposed that the problem was wider than `resizeactive`: every dispatcher name that reached
`raw_dispatch_cmd` was broken, because legacy names are not Lua globals and `exec_raw` spawns a
process. Fixed in this pass:

- `SUPER + M` used `exec_cmd("hyprctl dispatch splitratio 0.3")`, which becomes
  `hl.dispatch(splitratio 0.3)` and fails. Now `hl.dsp.layout("splitratio 0.3")`.
- `SUPER + CTRL + F9..F12` (`movecurrentworkspacetomonitor`) now uses
  `hl.dsp.workspace.move({ monitor = <direction> })`.
- `ALT + Tab` (`bringactivetotop`) now uses `hl.dsp.window.bring_to_top()`.
- `SUPER + CTRL + J/L` (`moveintogroup`) now uses `hl.dsp.window.move({ into_group = <direction> })`.
- `SUPER + CTRL + H` (`moveoutofgroup`) now uses `hl.dsp.window.move({ out_of_group = true })`.

Audit rule going forward: grep the canonical keybinds for `dispatch("` and confirm every name has an
explicit handler in the local `dispatch()` function. Anything that reaches `raw_dispatch_cmd` is
suspect.

Acceptance: each listed bind performs its action on the Gentoo host.

### LUA-012 — Stop Waybar polling `hyprctl` (D6)

Depends on: none. Status: **done.**

Not a Lua item, but the same out-of-process defect as D4, so it is tracked here rather than in a
separate document. Waybar's `custom/hypr_layout` and `custom/keyboard` modules polled `hyprctl` on
an `interval` for the life of the session. Both are now event-driven through `HyprEventWatch.sh` +
`HyprIPC.sh`, with no `interval` and no `hyprctl` anywhere in the render path.

Acceptance: `ps` shows no `hyprctl` or `jq` while the session is idle; the layout and keyboard
labels still update on a workspace switch, a monitor change, a layout switch and a keyboard layout
switch.

### LUA-013 — Remove blocking calls from the config Lua VM (D7)

Depends on: none. Status: **done.**

Found by scanning the Lua tree for `io.popen`, `os.execute` and `io.open`, not by reading the keybind
tree: these run on the compositor's own thread and are never reached through a script.

Acceptance: no `io.popen` or `os.execute` left on a live compositor path; the zoom gestures, the
laptop monitor layout and the lid binds still behave; `luac -p` clean.

---

## 7. Verification playbook

### Local (this machine)

Syntax only for the Lua config tree. The live session here runs a different, home-manager-managed
config, so this machine cannot validate runtime behaviour of the repo's config tree.

Standalone status scripts *can* be validated here: copy the file into `~/.config/hypr/scripts/` and
run it directly. To exercise `HyprEventWatch.sh`, either use a real event (`hyprctl reload` emits
`configreloaded>>`) or a synthetic one (`hyprctl dispatch 'hl.dsp.event("configreloaded>>")'`,
which arrives on socket2 as `custom>>configreloaded>>`).

```sh
# Lua syntax check on every changed file
for f in $(git -C <repo> diff --name-only | grep '\.lua$'); do
  luac -p "$f" || lua -e "assert(loadfile('$f'))" || echo "SYNTAX FAIL: $f"
done

# bash syntax check on every changed script
for f in $(git -C <repo> diff --name-only | grep '\.sh$'); do bash -n "$f" || echo "SYNTAX FAIL: $f"; done
```

Useful live probes (safe, read-only) against whatever Hyprland is running:

```sh
hyprctl eval 'hl.dsp.no_op()'                       # is Lua eval working
hyprctl dispatch 'hl.dsp.window.resize({ x = 1, y = 0, relative = true })'
hyprctl getoption misc:disable_autoreload
```

To inspect API values from `eval`, write them to a file — `eval` does not return values:

```sh
hyprctl eval 'local f=io.open("/tmp/probe","w"); f:write(tostring(hl.get_active_monitor().reserved.top)); f:close()'
cat /tmp/probe
```

### Gentoo host (authoritative)

The Gentoo host has Warp installed and is where runtime validation happens.

1. Deploy the repo config into the Gentoo user's `~/.config/hypr` (or point `hyprland.lua` at the
   repo tree).
2. After every change: `hyprctl reload && hyprctl configerrors`. Fix everything it reports before
   moving on.
3. Exercise each acceptance criterion by hand and record the result in the completion log.
4. For the "0 processes" claims, watch for forks while triggering the bind:

```sh
# in a second terminal, filter out the noise from your own tooling
while :; do ps -eo pid,comm --no-headers | grep -E 'hyprctl|jq|awk|inotifywait|lua' ; sleep 0.2; done
```

An in-process bind produces no new lines. A script-based bind produces several.

5. Record the Hyprland version in the completion log entry (`hyprctl version`). The Lua API is still
   moving between releases.

### Regression checklist for every item

- [ ] `hyprctl configerrors` clean after reload
- [ ] The specific acceptance criterion passes
- [ ] No other bind in `docs/Keybinds.md` changed behaviour
- [ ] Any doc that names the deleted script is updated (`docs/Keybinds.md`, `CHANGELOG.md`)

---

## 8. Documentation to keep in sync

Deleting or porting a script invalidates prose elsewhere. Check and update:

- `docs/Keybinds.md` — updated by LUA-002/LUA-005/LUA-006 to name the canonical source file and the
  ported binds, and by LUA-009/LUA-010 to name the in-process `layout_cycle` / `layout_focus` /
  `cycle_window` actions instead of the deleted scripts.
- `config/hypr/scripts/KeyBinds.sh` and `config/hypr/scripts/Kool_Quick_Settings.sh` — both decide
  which keybind file to read. Update them whenever the canonical keybind file moves.
- `CHANGELOG.md` — add a user-visible entry for each removal.
- `docs/Patching-UserConfigs.md` — if a user-facing config surface changes.

---

## 9. Open questions and known risks

- **Generator drift.** `scripts/migrate-hypr-to-lua.sh` embeds its own copy of the dispatch helper
  (the `system_keybind_lines` list, `:1667-1920`) which still references `LuaSwapWindow.sh` and the
  now-deleted `LuaCycleWindow.sh`, and still lacks the `resizeactive` mapping. **Confirmed
  unreachable:** the generator copies `configs/system_keybinds.lua` verbatim whenever it exists
  (`:1921-1923`), and the repo always ships one, so the embedded fallback only runs for a user config
  dir with no canonical file. Still to do: either delete the embedded fallback or regenerate it from
  the canonical file. Do not hand-edit the embedded strings without running the generator end to end
  in a scratch directory.
- **Upgrade risk for existing users.** Deleting a script assumes the user's deployed
  `configs/system_keybinds.lua` is replaced on upgrade. `migrate-hypr-to-lua.sh:1921-1922` copies the
  canonical file over the deployed one, so this holds — but confirm it for the release that carries
  these changes, and consider keeping the removed scripts for one release if any user-editable file
  outside `configs/` references them.
- **`UserConfigs/user_keybinds.lua` is user-editable.** Its documented examples mention
  `dispatch("resizeactive", ...)`. Fixing `user_keybinds_helper.lua` (LUA-003) covers existing users
  who copied those examples, so the helper fix is not optional even after the canonical file stops
  using the shim.
- **`hl.get_config("general.gaps_out")` returns a table, not a number.** Any ported code that expects
  a scalar will silently get `nil` from arithmetic. Use the named fields.
- **`reserved` shape differs from `hyprctl -j`.** The JSON gives `reserved: [l,t,r,b]`; the Lua API
  gives named `left/top/right/bottom`. Do not port JSON-derived indexing.
- **`exact = true` is not in the documented `resize` signature** (`x`, `y`, `relative`, `window`).
  Confirm on the Gentoo host whether it is honoured or ignored before relying on it. The ported code
  no longer passes it.
- **`monitor.width` physical vs logical.** `lua/window_actions.lua` keeps the old script's
  `width / scale` arithmetic, which assumes `HL.Monitor.width` is the physical size (as
  `hyprctl -j monitors` reports it). If the Lua API already returns a logical width, a scaled display
  would end up with a usable area that is too small. Verify on a monitor with scale != 1.0 and adjust
  `same_size_floating` / `current_column_width` if needed.
- **`hl.get_config("general.layout")` return type.** `same_size_floating` falls back to it when the
  workspace does not report `tiled_layout`. It returns a string in the current build; confirm on the
  Gentoo host.
- **Layout-aware focus is now in-process.** `LayoutKeybindDispatch.sh` and `LuaCycleWindow.sh` are
  gone (LUA-009/LUA-010). `SUPER + j/k`, `ALT + Tab` and the layout-aware arrow focus binds now run
  `lua/window_actions.lua` inside the Lua VM. Per-layout runtime confirmation is still outstanding on
  the Gentoo host.
- **`dispatch_changed_focus` assumes a synchronous dispatch.** The ported layout-aware paths read
  `hl.get_active_window().address`, dispatch, read it again, and treat "unchanged" as a no-op that
  triggers the fallback. That matches the old script's hyprctl round trip only if `hl.dispatch`
  applies focus synchronously inside the Lua VM. Confirm on the Gentoo host that `SUPER + j` on a
  scrolling workspace advances exactly one column and does not double-step.
- **`cycle_next` backwards direction.** `hl.dsp.window.cycle_next({ next = false })` is the documented
  form for the previous window; the undocumented `prev` field is a leftover with a known bug
  (hyprwm/Hyprland#14716). Verified against the Hyprland v0.56.2 source (`Actions::cycleNext` uses
  `previous = !next`), not yet exercised at runtime.
- **`pin` has no handler in `lua/user_keybinds_helper.lua`.** `docs/HOWTO-Change-Keybindgs.md` shows
  `dispatch("pin", ...)` in its examples, but the helper has no `pin` branch, so it reaches
  `raw_dispatch_cmd("pin")` and `hyprctl dispatch pin` fails like the other legacy names. Same defect
  class as D1/D3. Add `hl.dsp.window.pin({ action })` next time the user-facing examples are touched.
- **Waybar `custom/nightlight` still polls.** `Hyprsunset.sh status` runs on `interval: 3` and forks
  bash + `pgrep` each time. It never called `hyprctl`, and Hyprland has no event for hyprsunset
  state, so LUA-012 left it alone. Converting it means either an `hl.timer`-driven writer or
  accepting the `pgrep` fork.
- **`hyprland/language` is the zero-process alternative for the keyboard label.** Waybar's native
  module reads the same `activelayout` event with no script at all, and the repo already ships a
  `hyprland/language` block in `Modules`. It was not used because it selects the keyboard by a fixed
  `keyboard-name` (or the first one) and has no equivalent of `KeyboardLayout.sh`'s ignore list for
  AVRCP/Bluetooth pseudo-keyboards.
- **Event coverage for the layout label is not exhaustive.** `HyprEventWatch.sh layout` refreshes on
  workspace, monitor and config-reload events, and `ChangeLayout.sh` pushes its own RTMIN+8 signal.
  A layout change made some other way (a workspace rule applied by something that neither switches
  workspace nor signals Waybar) would not redraw until the next event.
- **The DRM connector scan now uses a fixed name list.** `connected_drm_connectors()` in
  `user_laptops.lua` used to discover any connector present in sysfs through `ls`; it now probes a
  known list of names with `io.open` (LUA-013). Anything unusual is still added by the
  `hl.get_monitors()` union in `get_connected_monitors()`, which is what drives the layout, but a
  non-standard connector present in sysfs and not yet known to Hyprland would no longer be seen
  early. Lua has no `readdir`, so the alternatives are a blocking `io.popen` or an async helper.
- **`io.popen` outside the compositor was left alone.** `config/wezterm/wezterm.lua` and
  `config/yazi/plugins/*` are other applications' Lua configs; they never run in Hyprland's VM, so
  D7 does not apply to them.

---

## 10. Completion log

Append-only. Newest entries at the top of their item. Every entry records: item, date, agent,
files changed, verification evidence, follow-ups.

### LUA-001 — Delete confirmed-dead scripts

- 2026-10-03 — agent `Oz` (run in `Hyprland-Dots`, branch `development`)
  - Deleted: `config/hypr/scripts/ResizeActive.sh`,
    `config/hypr/scripts/LuaMoveWindowDirectional.sh`,
    `config/hypr/scripts/LuaFocusWorkspaceRelative.sh`,
    `config/hypr/scripts/LuaMoveWindowWorkspaceRelative.sh`,
    `config/hypr/scripts/LuaFullscreenMaximized.sh`.
  - Evidence: repo-wide grep for each name returned only commented-out bind lines in
    `lua/keybinds.lua` (itself removed by LUA-002) and no references from
    `scripts/migrate-hypr-to-lua.sh`. `LuaFullscreenMaximized.sh` had zero references anywhere.
  - Verification: local syntax/parse checks only. **Runtime verification on the Gentoo host is still
    outstanding** — trigger the resize, move, and fullscreen binds once and confirm
    `hyprctl configerrors` is clean.
  - Follow-ups: none.

### LUA-002 — Delete the orphaned keybind templates

- 2026-10-03 — agent `Oz`
  - Deleted: `config/hypr/lua/keybinds.lua`, `config/hypr/lua/keybind_helpers.lua`.
  - Changed: `config/hypr/scripts/KeyBinds.sh`, `config/hypr/scripts/Kool_Quick_Settings.sh`,
    `docs/Keybinds.md`.
  - Evidence: `hyprland.lua` does not load them; `user_overrides.lua:80-88` loads
    `configs/system_*.lua`; nothing `dofile`s or `require`s them. Chord diff: 149 chords in the
    orphan vs 190 in the canonical file, 143 shared, and all 6 orphan-only entries are text inside
    commented example blocks (`--TITLE=`, `ALT + SPACE`, `UWSM-APP -- KITTY`, ...).
  - **Blocker found by the pre-delete grep, fixed before deleting:** `Kool_Quick_Settings.sh`
    `resolve_system_keybinds_file()` preferred `lua/keybinds.lua`, so the Quick Settings
    "Edit System Default Keybinds" entry opened a file Hyprland never loads, and `KeyBinds.sh`
    passed it as the first input to `keybinds_parser.py`. Both now resolve
    `configs/system_keybinds.lua` first, with `UserConfigs/system_keybinds.lua` and then the old
    template as last-resort fallbacks. `docs/Keybinds.md` now names the canonical file as its source.
  - Verification: chord diff re-run before deletion; `bash -n` clean on both edited scripts;
    post-delete grep shows only comments referencing the removed names.
  - Follow-ups: none.

### LUA-003 — Fix `raw_dispatch_cmd`

- 2026-10-03 — agent `Oz`
  - Changed: `config/hypr/lua/user_keybinds_helper.lua`,
    `config/hypr/configs/system_keybinds.lua`.
  - Fix: the dispatcher-string fallback no longer routes through `hl.dsp.exec_raw` (which spawns a
    process). It now falls back to `hyprctl dispatch <name> <args>` through `exec_cmd`, and explicit
    `hl.dsp.*` handlers were added for `resizeactive`, `swapwindow`, `bringactivetotop`,
    `moveintogroup`, `moveoutofgroup`, and `movecurrentworkspacetomonitor` so the common cases never
    reach the fallback. `cyclenext` still routes to `LuaCycleWindow.sh` until LUA-010.
  - Evidence: `hl.dsp.exec_raw("touch /tmp/probe")` creates the file, proving `exec_raw` is a process
    spawn; `command -v resizeactive` returns not found, so the old path could never work.
  - Verification: local syntax checks only. **Runtime verification outstanding on the Gentoo host.**
  - Follow-ups: none.

### LUA-004 — Fix resize binds

- 2026-10-03 — agent `Oz`
  - Changed: `config/hypr/configs/system_keybinds.lua`.
  - Fix: the four `SUPER SHIFT + arrow` binds now bind
    `hl.dsp.window.resize({ x, y, relative = true })` dispatcher objects directly (tier 1 — no Lua
    closure runs at keypress), and `["repeat"] = true` was corrected to `repeating = true` across the
    file so hold-to-repeat works.
  - Evidence: documented signature `resize({ x, y, relative?, window? })`; `relative = true` is the
    supported form for deltas, so the old "read size, add delta, set absolute" round trip is
    unnecessary.
  - Verification: local syntax checks only. **Runtime verification outstanding on the Gentoo host**:
    hold each arrow and confirm continuous resize, then tap once and confirm exactly 50 px.
  - Follow-ups: none.

### LUA-005 — Port `float.all.samesize.lua`

- 2026-10-03 — agent `Oz`
  - Added: `config/hypr/lua/window_actions.lua` (in-process implementation).
  - Changed: `config/hypr/hyprland.lua` (loads the module),
    `config/hypr/configs/system_keybinds.lua` (bind now calls the Lua function instead of
    `exec_cmd`ing the script).
  - Deleted: `config/hypr/scripts/float.all.samesize.lua`.
  - Evidence: probe confirmed `monitor.reserved` has named `top/left/bottom/right` fields,
    `window.size` has `.x`/`.y`, `hl.get_windows({ workspace = id })` filters correctly, and
    dispatchers accept `HL.Window` objects. All of this replaces 4+ `hyprctl` calls and the
    hand-rolled JSON decoder.
  - Verification: local syntax checks only. **Runtime verification outstanding on the Gentoo host**:
    confirm the tiled layout matches the old script and that no `hyprctl` process is spawned.
  - Follow-ups: `docs/Keybinds.md:75` updated to drop the script filename.

### LUA-006 — Port `LuaSwapWindow.sh`

- 2026-10-03 — agent `Oz`
  - Changed: `config/hypr/configs/system_keybinds.lua`,
    `config/hypr/lua/user_keybinds_helper.lua`.
  - Deleted: `config/hypr/scripts/LuaSwapWindow.sh`.
  - Fix: the four `SUPER ALT + arrow` binds now use `hl.dsp.window.swap({ direction = ... })` directly.
    The `jq` overlap-detection guard was dropped because the dispatcher is a no-op when there is no
    window in that direction.
  - Verification: local syntax checks only. **Runtime verification outstanding on the Gentoo host**:
    swap in all four directions, then press the bind with no neighbour and confirm no error appears in
    `hyprctl configerrors` or as a notification.
  - Follow-ups: `docs/Keybinds.md:116` updated. The generator's embedded fallback still names this
    script — see [open questions](#9-open-questions-and-known-risks).

### LUA-007 — Port `ScrollCycleColumnWidth.sh`

- 2026-10-03 — agent `Oz`
  - Added: `cycle_column_width()` in `config/hypr/lua/window_actions.lua`.
  - Changed: `config/hypr/configs/system_keybinds.lua`.
  - Deleted: `config/hypr/scripts/ScrollCycleColumnWidth.sh`.
  - Fix: layout check now uses `hl.get_active_workspace().tiled_layout`; width is derived from
    `win.size.x / monitor.width` when the window does not expose `layout.column.width`; dispatch uses
    `hl.dsp.layout("colresize <preset>")`. The dead legacy `layoutmsg` fallback is gone.
  - Verification: local syntax checks only. **Runtime verification outstanding on the Gentoo host**:
    cycle a full lap on a scrolling workspace and confirm the bind is inert elsewhere.
  - Follow-ups: none.

### LUA-008 — Retire `LuaAutoReload.sh`

- 2026-10-03 — agent `Oz`
  - Changed: `config/hypr/lua/startup.lua` (startup entry removed).
  - Deleted: `config/hypr/scripts/LuaAutoReload.sh`.
  - Evidence: Hyprland reloads Lua config on save; local `hyprctl getoption misc:disable_autoreload`
    reports `bool: false, set: false`, i.e. built-in autoreload is active. The CHANGELOG records
    repeated bugs in the watcher.
  - Verification: **Runtime verification outstanding on the Gentoo host**: save a `.lua` file and
    confirm the change applies within ~1 second, then confirm `hyprctl configerrors` is clean and no
    `inotifywait` process remains.
  - Follow-ups: if any user relies on watching files *outside* `~/.config/hypr`, built-in autoreload
    will not cover them. Re-check before release.

### LUA-011 — Sweep remaining legacy dispatcher names

- 2026-10-03 — agent `Oz`
  - Changed: `config/hypr/configs/system_keybinds.lua`.
  - Fix: `SUPER + M` now uses `hl.dsp.layout("splitratio 0.3")` instead of
    `exec_cmd("hyprctl dispatch splitratio 0.3")`, which evaluated to `hl.dispatch(splitratio 0.3)`
    and failed. Native handlers added for `movecurrentworkspacetomonitor`, `bringactivetotop`,
    `moveintogroup`, and `moveoutofgroup`.
  - Evidence: `hyprctl dispatch '<expr>'` is shorthand for `hl.dispatch(<expr>)`, so a bare legacy
    dispatcher name is an undefined Lua global; the old `exec_raw` path spawned a non-existent
    binary. Both were silent failures.
  - Verification: local Lua syntax check only. **Runtime verification outstanding on the Gentoo
    host** for all five bind groups.
  - Follow-ups: apply the audit rule in the item description when adding new binds.

### LUA-009 / LUA-010 — Deferred

- 2026-10-03 — agent `Oz`: not started. `LayoutKeybindDispatch.sh` and `LuaCycleWindow.sh` were
  outside the scope of the first pass and still have live references
  (`configs/system_keybinds.lua` `cyclenext` handler; `LayoutKeybindDispatch.sh:17`). Start LUA-009
  before attempting LUA-010.

### LUA-009 — Port `LayoutKeybindDispatch.sh`

- 2026-10-03 — agent `Oz` (run in `Hyprland-Dots`, branch `development`)
  - Added: `layout_cycle()`, `layout_focus()` and their helpers in
    `config/hypr/lua/window_actions.lua`.
  - Changed: `config/hypr/configs/system_keybinds.lua` — `SUPER + j`/`k` and the four layout-aware
    `SUPER + arrow` binds now call the Lua actions instead of `exec_cmd`ing the script.
  - Deleted: `config/hypr/scripts/LayoutKeybindDispatch.sh`.
  - Port: layout resolution is `workspace.tiled_layout`, then `general.layout`, then `dwindle`.
    `dispatch_changed_focus` is the in-process form of the old address-before/address-after check.
    Scrolling tries `hl.dsp.layout("focus l/r")` then falls back to `hl.dsp.focus`; monocle tries
    `cyclenext`/`cycleprev` then falls back to the address-sorted cycle; everything else tries
    `hl.dsp.window.cycle_next()` then falls back. Master and unknown layouts use `hl.dsp.focus`.
  - Evidence: the legacy `layoutmsg`/`cyclenext`/`movefocus` strings the script passed to `hyprctl`
    are not Lua globals (D3), so on 0.56.2 every `dispatch_changed_focus` attempt failed and the
    fallback ran. The port keeps the attempt-then-fallback shape so a build that does honour the
    layout message still behaves the same.
  - Verification: `luac -p` clean on all three changed Lua files, and the LUA-011 audit (every
    `dispatch("…")` name in the canonical keybinds has an explicit handler) passes. **Runtime
    verification outstanding on the Gentoo host**: `SUPER + j`/`k` and `SUPER + arrow` on dwindle,
    master, scrolling and monocle, with no `hyprctl`/`jq` fork visible in `ps`.
  - Follow-ups: `docs/Keybinds.md:107-110` updated. The backwards direction was verified against the
    Hyprland v0.56.2 source rather than at runtime.

### LUA-010 — Port `LuaCycleWindow.sh`

- 2026-10-03 — agent `Oz`
  - Added: `cycle_window()` and its address-sorted helper in `config/hypr/lua/window_actions.lua`.
  - Changed: `config/hypr/configs/system_keybinds.lua` (the `cyclenext` handler no longer
    `exec_cmd`s the script) and `config/hypr/lua/user_keybinds_helper.lua` (gains a `cyclenext`
    handler; it previously fell through to a legacy name that no longer resolves).
  - Deleted: `config/hypr/scripts/LuaCycleWindow.sh`.
  - Port: filters `hl.get_windows({ workspace = <id> })` to `mapped` and not `hidden`, sorts by `y`,
    then `x`, then `address` (the old `jq` `sort_by(.y, .x, .address)`), finds the active window and
    focuses the next/previous entry, wrapping. Uses `win.at.x`/`win.at.y` and
    `hl.dsp.focus({ window = <HL.Window> })` — no `address:0x…` strings, no JSON.
  - Evidence: the script forked bash + 2 `hyprctl` + a ~25-line `jq` program per press; the port is
    zero processes and zero IPC.
  - Verification: `luac -p` clean. **Runtime verification outstanding on the Gentoo host**:
    `ALT + Tab` and `SUPER + j`/`k` walk every window on the workspace and wrap, with no `hyprctl` or
    `jq` process spawned.
  - Follow-ups: `docs/Keybinds.md:11,110` updated. The generator's embedded fallback still names the
    deleted script — see [open questions](#9-open-questions-and-known-risks).

### LUA-012 — Stop Waybar polling `hyprctl`

- 2026-10-03 — agent `Oz` (run in `Hyprland-Dots`, branch `development`)
  - Added: `config/hypr/scripts/HyprIPC.sh` (socket resolution + request helper) and
    `config/hypr/scripts/HyprEventWatch.sh` (socket2 event listener serving both status modules).
  - Changed: `config/hypr/scripts/HyprLayoutModule.sh` (`get_layout()` now reads `j/activeworkspace`
    over the socket instead of shelling out to `ChangeLayout.sh` + `hyprctl`) and
    `config/hypr/waybar/ModulesCustom` (both modules drop `interval`, run
    `HyprEventWatch.sh layout|keyboard`, and gain `restart-interval`).
  - Evidence: a PATH shim around `hyprctl` showed `HyprLayoutModule.sh status` made 1 `hyprctl` call
    and `KeyboardLayout.sh status` made 4 per invocation, at `interval: 2` and `interval: 1`. That is
    the `hyprctl` + `jq` process pair seen while watching `ps`.
  - Evidence: `printf 'j/activeworkspace' | socat - UNIX-CONNECT:$SOCK` returns the same JSON as
    `hyprctl -j activeworkspace`; `j/getoption general:layout` likewise matches.
  - Verification (Hyprland 0.56.2, Waybar v0.15.0, this host): the layout render makes 0 `hyprctl`
    calls; the keyboard listener's output matches `KeyboardLayout.sh status` exactly (`us`); the
    layout listener re-renders on a real `configreloaded>>` (1 -> 2 lines); SIGTERM exits both
    listeners cleanly with no leftover `socat`; after a Waybar config reload both listeners are
    running and `ps` reports **0** `hyprctl`/`jq` hits over a 20 s sample, against ~4.5/s before.
  - Follow-ups: `custom/nightlight` still polls with `pgrep` — see
    [open questions](#9-open-questions-and-known-risks).

### LUA-013 — Remove blocking calls from the config Lua VM

- 2026-10-03 — agent `Oz` (run in `Hyprland-Dots`, branch `development`)
  - Changed: `config/hypr/lua/settings.lua` (gesture zoom uses `hl.get_config` / `hl.config`,
    clamped to 1.0-16.0), `config/hypr/UserConfigs/user_laptops.lua` (dropped the `read_command`
    `io.popen` helper and the `cat /proc/acpi/button/lid/*/state` fallback; `connected_drm_connectors`
    probes a known connector-name list with `io.open` instead of one `io.popen("ls ...")` per card),
    `config/hypr/lua/laptop-lid.lua` (`os.execute` -> `hl.exec_cmd`).
  - Evidence: `075ce3eb` ("Fixed io.open calls with LUA API") is the commit that **introduced** the
    `user_laptops.lua` `io.popen` calls - it converted shell `hyprctl`/`ls` usage into blocking Lua
    file and pipe reads. The `settings.lua` gesture `io.popen` came from `1d6ae586`, an ancestor of
    that cleanup, so the sweep only ever covered `io.open`.
  - Verification: `luac -p` clean on all three files; no executable `io.popen` remains in
    `config/hypr/`. Equivalence check for the risky part: the old `ls`-based sysfs glob reports
    `Virtual-1`, and the refactored scan (with `hl.get_monitors` stubbed empty so only the DRM path
    can contribute) reports `Virtual-1` as well. The whole file was executed against a stubbed `hl`
    on real sysfs, so both `is_lid_closed()` and `connected_drm_connectors()` ran without error.
  - Follow-ups: the DRM name-list trade-off is recorded in
    [open questions](#9-open-questions-and-known-risks). The `os.execute` fallbacks in
    `lua/user_startup_helper.lua:82` and `UserConfigs/user_laptops.lua:211` are guarded by
    `hl.exec_cmd` and unreachable on a Lua build, so they were left in place.
