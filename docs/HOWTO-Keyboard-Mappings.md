# How to Find Your Keyboard's Media Key Mappings in KoolDots

A keybind is written against a **keysym**, not against a key. There is no way to
bind "the key under F2" — you bind `XF86MonBrightnessUp`, or `F2`, or nothing at
all. Which one your keyboard sends depends on the model, on its firmware, and on
whether the Fn row is in "media" or "function" mode.

This guide shows how to ask the compositor what each key actually sends, and how
to turn that into an entry in:

```
~/.config/hypr/UserConfigs/user_keybinds.lua
```

---

## 1. Why guessing fails quietly

The legends printed on an Fn row describe what the **keyboard firmware** intended,
not what the Linux keymap produces. Two different laptops can print the same
brightness sun on F2 and send completely different keysyms:

- one sends `XF86MonBrightnessUp` for a bare `F2` press
- the next sends `F2` bare and `XF86MonBrightnessUp` only for `Fn+F2`
- the next sends nothing at all for `Fn+F2`, because the key is handled in
  firmware and never reaches the OS

A wrong guess does not produce an error. It produces a bind that is registered,
listed by `hyprctl binds`, shown in the `SUPER + SHIFT + K` menu, and never
fires. That is the failure mode this guide exists to remove.

The related trap is assuming the media function sits on the bare key. On most
laptops the bare key is the traditional function key, so binding `F1` to mute
means `F1` is no longer help in any application. Bind the keysym the keyboard
actually emits and the question does not arise.

---

## 2. Which file to edit

| File | Who owns it | Edit it? |
|---|---|---|
| `~/.config/hypr/configs/system_keybinds.lua` | the installer | **No** — updates overwrite it |
| `~/.config/hypr/UserConfigs/user_keybinds.lua` | you | **Yes** — survives updates |

Keybinds use two helpers, both provided by the file's own loading block:

```lua
bind("MODIFIERS", "KEYSYM", action, [options])
unbind("MODIFIERS", "KEYSYM")
```

For a hardware key there are no modifiers, so the first argument is an empty
string:

```lua
bind("", "XF86AudioRaiseVolume", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --inc"), {
  description = "volume up",
  locked = true,
  repeating = true,
})
```

- `locked = true` — fires while the screen is locked, which is what you want for
  media keys
- `repeating = true` — repeats while held, which is what you want for a volume or
  brightness ramp, and **not** for a toggle
- `description` — the label in the `SUPER + H` cheat sheet and the
  `SUPER + SHIFT + K` search menu

---

## 3. Step 1: Find out what your keys actually send

### The probe (recommended)

```
~/.config/hypr/scripts/KeybindProbe.sh
```

Press each key you want to identify, then Enter. The script prints a table of
what Hyprland received.

How it works, and why it is safe:

- It installs a probe into Hyprland's **running Lua state** with `hyprctl eval`.
  Nothing on disk is read or written.
- Every chord the probe claims is **unbound first**, so pressing a key while the
  probe runs only logs it. No volume change, no suspend, no side effect.
- On exit — including Ctrl+C and on error — it runs `hyprctl reload`, which drops
  the probe with the VM and restores your original binds.
- It needs **no dependencies** beyond a running Hyprland 0.57+ session. No root,
  no `wev`, no packages.

```
$ KeybindProbe.sh

Press each key you want to identify, one at a time.
Bare F1-F12 are claimed by the probe, so they will not reach the focused
window until it is removed. Press Enter when you are done.

KEYSYM                       PRESSES      STATE
F1                           1            not bound - add a bind if you want it
XF86MonBrightnessDown        1            already bound
XF86MonBrightnessUp          1            already bound
XF86AudioRaiseVolume         2            already bound
```

Read it like this:

- **A row appears** — that is the exact keysym to bind. Copy it verbatim.
- **`already bound`** — `system_keybinds.lua` already binds it, so the key already
  works. Only add a bind if you want to *change* what it does.
- **`not bound`** — nothing handles it yet. This is the case worth acting on.
- **No row for a key you pressed** — that key emits a keysym outside the probe's
  candidate list, which means it is not a standard media key. Add the keysym to
  `CANDIDATES` in the script and run it again.
- **`PRESSES` above 1 for a single press** — the key emitted more than one event,
  which usually means the firmware is double-reporting it.

While the probe is loaded, bare `F1`–`F12` are claimed by it and will not reach
the focused window. That is expected, and it is undone by the reload on exit.

### Alternatives

| Tool | Needs | Shows | Use when |
|---|---|---|---|
| `KeybindProbe.sh` | nothing | the keysym Hyprland acts on | always, on Hyprland 0.57+ |
| `wev` | `wev` installed | keysym, plus raw codes and modifiers | Hyprland older than 0.57 |
| `evtest` | root | raw kernel keycodes, no keysyms | you need to see firmware-level events |

`wev` prints a line per event; the field you want is `sym:`.

```
[14:      sym: XF86AudioRaiseVolume (0x1008113), utf8: '' ]
```

---

## 4. Step 2: Write the binds

### The unbind rule, and why it is not optional

**Call `unbind("", "KEYSYM")` before every `bind(...)`.**

This is measured behaviour on Hyprland 0.57.0, not folklore. `hl.bind` on a chord
that is already bound **does not replace it** — the bind table keeps both, and
`hyprctl binds` lists the chord twice. Both handlers then run on one keypress:

- a duplicated mute bind runs `Volume.sh --toggle` twice, so the key appears to do
  nothing at all
- a duplicated volume bind steps 10% instead of 5%

The `unbind` is also safe when nothing was bound: it is a no-op. So the pattern
below is correct on a stock install and on a machine that has never had the bind.

```lua
unbind("", "XF86AudioRaiseVolume")
bind("", "XF86AudioRaiseVolume", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --inc"), {
  description = "volume up",
  locked = true,
  repeating = true,
})
```

Apply and verify:

```bash
luac -p ~/.config/hypr/UserConfigs/user_keybinds.lua   # syntax
hyprctl reload                                          # or SUPER + ALT + R
hyprctl binds | grep -i xf86                            # what is registered now
```

Check that each chord you bound appears **once**. Twice means a missing `unbind`.

---

## 5. Example A: Dell Inspiron 3501

This is the case that prompted the guide. The reported symptom is that after a
reboot the media keys only work as `Fn+F1`, `Fn+F2` and so on.

That symptom is **Fn-lock**, not a keybinding problem. The embedded controller
powers up with the row in function-key mode, so the bare key sends `F1` and the
media code appears only with `Fn` held. In the other Fn-lock state the bare key
sends the media code and `Fn+F1` sends `F1`.

The useful consequence: **the XF86 keysym is emitted in both states.** Binding the
XF86 symbol covers the row either way, which is why `system_keybinds.lua` binds
only XF86 symbols and nothing else. If those binds are already in place, the
mapping is correct and the remaining fix is firmware level:

- `Fn+Esc` toggles Fn-lock on most Dell laptops
- the BIOS option is *POST Behavior* → **Function Key Behavior** →
  **Multimedia Key**, which survives a reboot

The reported Fn row for this model is:

| Key | Emits | Action |
|---|---|---|
| `F1` | `XF86AudioMute` | mute |
| `F2` | `XF86AudioLowerVolume` | volume down |
| `F3` | `XF86AudioRaiseVolume` | volume up |
| `F11` | `XF86MonBrightnessDown` | brightness down |
| `F12` | `XF86MonBrightnessUp` | brightness up |

**Run `KeybindProbe.sh` on the machine before trusting that table.** It comes from
a forum post, not from the hardware, and the Fn row differs between Inspiron
models and BIOS revisions. The probe answers it in two minutes.

If you also want the row to work as media keys **without** `Fn`, the only way is
to bind the bare keys, which costs you the traditional function keys:

```lua
-- Inspiron 3501: media functions on the bare F-keys as well as via Fn.
-- WARNING: this takes F1, F2, F3, F11 and F12 away from every application.
-- F1 stops being help, F11 stops being fullscreen, F12 stops being devtools.
local fn_media_keys = {
  { key = "F1",  cmd = "$HOME/.config/hypr/scripts/Volume.sh --toggle",  description = "mute audio" },
  { key = "F2",  cmd = "$HOME/.config/hypr/scripts/Volume.sh --dec",     description = "volume down",     repeating = true },
  { key = "F3",  cmd = "$HOME/.config/hypr/scripts/Volume.sh --inc",     description = "volume up",       repeating = true },
  { key = "F11", cmd = "$HOME/.config/hypr/scripts/Brightness.sh --dec", description = "brightness down", repeating = true },
  { key = "F12", cmd = "$HOME/.config/hypr/scripts/Brightness.sh --inc", description = "brightness up",   repeating = true },
}

for _, media in ipairs(fn_media_keys) do
  unbind("", media.key)
  local opts = { description = media.description, locked = true }
  if media.repeating then
    opts.repeating = true
  end
  bind("", media.key, exec_cmd(media.cmd), opts)
end
```

---

## 6. Example B: a 75% keyboard

A 75% layout has no numpad and keeps the Fn row, but which keys the Fn layer
carries is entirely up to the maker. This is what the probe reported for one such
board:

| Key | Emits |
|---|---|
| `F1` … `F12` bare | `F1` … `F12` — traditional function keys |
| `Fn+F1` | `XF86MonBrightnessDown` |
| `Fn+F2` | `XF86MonBrightnessUp` |
| `Fn+F3` … `Fn+F6` | no event at all |
| `Fn+F7` | `XF86AudioPrev` |
| `Fn+F8` | `XF86AudioPlay` |
| `Fn+F9` | `XF86AudioNext` |
| `Fn+F10` | `XF86AudioMute` |
| `Fn+F11` | `XF86AudioLowerVolume` |
| `Fn+F12` | `XF86AudioRaiseVolume` |

The media functions live on the Fn layer, so nothing is bound on the bare keys
and the traditional function keys keep working — `F11` still fullscreens the
focused application. The result is an entry that looks like this:

```lua
-- FN-ROW MEDIA KEYS (75% keyboard)
-- Fn+F1/F2 brightness, Fn+F7..F9 transport, Fn+F10 mute, Fn+F11/F12 volume.
-- Bare F1..F12 are left unbound on purpose: they stay traditional function keys.
local media_keys = {
  { key = "XF86AudioRaiseVolume",  cmd = "$HOME/.config/hypr/scripts/Volume.sh --inc",      description = "volume up",                   repeating = true },
  { key = "XF86AudioLowerVolume",  cmd = "$HOME/.config/hypr/scripts/Volume.sh --dec",      description = "volume down",                 repeating = true },
  { key = "XF86AudioMute",         cmd = "$HOME/.config/hypr/scripts/Volume.sh --toggle",   description = "toggle mute" },
  { key = "XF86MonBrightnessUp",   cmd = "$HOME/.config/hypr/scripts/Brightness.sh --inc",  description = "increase monitor brightness", repeating = true },
  { key = "XF86MonBrightnessDown", cmd = "$HOME/.config/hypr/scripts/Brightness.sh --dec",  description = "decrease monitor brightness", repeating = true },
  { key = "XF86AudioPrev",         cmd = "$HOME/.config/hypr/scripts/MediaCtrl.sh --prv",   description = "previous track" },
  { key = "XF86AudioPlay",         cmd = "$HOME/.config/hypr/scripts/MediaCtrl.sh --pause", description = "play/pause" },
  { key = "XF86AudioNext",         cmd = "$HOME/.config/hypr/scripts/MediaCtrl.sh --nxt",   description = "next track" },
}

for _, media in ipairs(media_keys) do
  unbind("", media.key)
  local opts = { description = media.description, locked = true }
  if media.repeating then
    opts.repeating = true
  end
  bind("", media.key, exec_cmd(media.cmd), opts)
end
```

Every one of those keysyms is already bound by `system_keybinds.lua`, so this
entry changes no behaviour on a stock install. It is worth keeping anyway: it
documents what the keyboard sends, and it is the place to edit when you want a
different command on one of those keys.

---

## 7. Dependencies

**The probe needs nothing.** It runs on any Hyprland 0.57+ session with no extra
packages, no root and no `wev`. The rest of this section is for the alternatives
and for the scripts the media binds call.

Run the script's own check for your machine:

```
KeybindProbe.sh --check-deps
```

| Purpose | Tool | Arch | Debian / Ubuntu | Fedora | Gentoo | NixOS |
|---|---|---|---|---|---|---|
| probe | `hyprctl` | hyprland | hyprland | hyprland | gui-wm/hyprland | hyprland |
| alternative inspector | `wev` | wev | wev | wev | gui-apps/wev ¹ | wev |
| raw keycodes (root) | `evtest` | evtest | evtest | evtest | app-misc/evtest | evtest |
| input debugging | `libinput` | libinput | libinput-tools | libinput | dev-libs/libinput | libinput |
| volume (`Volume.sh`) | `pamixer` | pamixer | pamixer | pamixer | media-sound/pamixer | pamixer |
| brightness (`Brightness.sh`) | `brightnessctl` | brightnessctl | brightnessctl | brightnessctl | app-misc/brightnessctl ¹ | brightnessctl |
| transport (`MediaCtrl.sh`) | `playerctl` | playerctl | playerctl | playerctl | media-sound/playerctl | playerctl |
| notifications / OSD | `notify-send` | libnotify | libnotify-bin | libnotify | x11-libs/libnotify | libnotify |
| syntax check | `luac` | lua | lua5.1 | lua | dev-lang/lua | lua |

Install lines for everything above:

```bash
# Arch
sudo pacman -S wev evtest libinput pamixer brightnessctl playerctl libnotify lua

# Debian / Ubuntu
sudo apt install wev evtest libinput-tools pamixer brightnessctl playerctl libnotify-bin lua5.1

# Fedora
sudo dnf install wev evtest libinput pamixer brightnessctl playerctl libnotify lua

# openSUSE
sudo zypper install wev evtest libinput-tools pamixer brightnessctl playerctl libnotify-tools lua
```

¹ **Gentoo:** `wev` and `brightnessctl` are **not** in the main tree. They come
from the `guru` overlay, so enable it first. The probe itself needs neither, so it
runs on Gentoo as it is.

```bash
eselect repository enable guru && emerge --sync guru
sudo emerge -av gui-apps/wev app-misc/brightnessctl
sudo emerge -av app-misc/evtest media-sound/pamixer media-sound/playerctl x11-libs/libnotify dev-lang/lua
```

**NixOS** is declarative, and it ships no `update-deps.sh`. There is nothing to
install ad hoc — add the packages to your configuration instead:

```nix
environment.systemPackages = with pkgs; [
  wev evtest libinput pamixer brightnessctl playerctl libnotify lua
];
```

For a one-off session without editing the configuration:

```bash
nix-shell -p wev evtest pamixer brightnessctl playerctl libnotify lua
```

**openSUSE** is supported by the installer alongside Debian, Arch and Fedora.
Ubuntu is branched per release, matched on `VERSION_ID`, with Linux Mint and
Zorin OS supported as Ubuntu 24.04 based.

---

## 8. Troubleshooting

**A key fires twice, or a mute key appears to do nothing.**
A chord is bound more than once. `hyprctl binds | grep -i xf86` will show the
duplicate. Add `unbind("", "KEYSYM")` above the `bind(...)`.

**A key stopped reaching applications.**
Something is bound on the bare key. Bare `F1`, `F11` and `F12` are help,
fullscreen and devtools in many applications. Remove the bare-key binds, or
accept the trade-off knowingly.

**A brightness key raises the OSD but the screen does not change.**
Expected on a desktop with no `/sys/class/backlight/` device. `brightnessctl`
falls back to the first device it finds — often a keyboard LED — so the OSD
appears and the value is meaningless. Check with:

```bash
ls /sys/class/backlight/
brightnessctl -m
```

**The key does nothing and the probe logged nothing for it.**
The key emits a keysym outside the probe's candidate list, or it is handled
entirely in firmware and never reaches the OS. Nothing in Hyprland can bind an
event it never receives. Confirm at the kernel level with `sudo evtest`.

**`hyprctl eval` did not answer `ok`.**
The probe was not installed. Only the exact reply `ok` counts as a successful
write — `hyprctl` can exit 0 while answering something else. Check that you are on
Hyprland 0.57 or newer, and that `HYPRLAND_INSTANCE_SIGNATURE` is set in your
shell.

**Media keys only work with `Fn` held.**
That is the keyboard's Fn layer, not the config. The XF86 binds already cover it.
To flip the row so the bare keys send media codes, use the keyboard's Fn-lock
(`Fn+Esc` on many boards) or the firmware setting — at the cost of the
traditional function keys.

**Verify what is registered.**
```bash
hyprctl binds | grep -iE 'xf86|brightness|volume'
```
