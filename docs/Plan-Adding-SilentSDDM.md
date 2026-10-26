# Plan: Adding SilentSDDM and a KooL SDDM theme/preset switcher

Status: research complete. No code changes made yet.
Upstream reviewed: <https://github.com/uiriansan/SilentSDDM> (v1.5.0, GPL-3.0-or-later).

## 1. Verdict

Yes, SilentSDDM can be added to the KooL SDDM setup, and it is not a version
regression: KooL's own theme already demands more than SilentSDDM does.

- SilentSDDM needs `sddm >= 0.21` and `qt6 >= 6.5`.
- KooL's current theme (`LinuxBeginnings/simple-sddm-2`) needs `sddm >= 0.21`
  and `qt6 >= 6.8`.

It is **not** a config drop-in. SilentSDDM has no `theme.conf` and no
`Backgrounds/default`; it uses `configs/*.conf` selected through
`metadata.desktop` (`ConfigFile=`), and every background, colour and clock
setting lives in that file. All of KooL's SDDM automation is hardcoded to the
astronaut-style layout, so a SilentSDDM code path has to be written.

The Debian 13 host is a valid target today: it satisfies the floor and is one
package short of SilentSDDM's dependency set.

## 2. Scope and exclusions

In scope:

- This repo (`Hyprland-Dots`), work on `development`, PRs target `development`
- `Arch-Hyprland`, `Fedora-Hyprland`, `Debian-Hyprland` (Debian 13+)
- `Ubuntu-Hyprland` branches `25.04`, `25.10`, `26.04`, `main`

Out of scope — **never apply this plan**:

- `Ubuntu-Hyprland` branch `24.04`, and its siblings `24.04-development` and
  `24.04-deps-luac-guiutils`
- any dotfiles branch serving that base (the Ubuntu-Hyprland README points at
  `Hyprland-Dots` branch `Deb-Untu-Dots` for Debian/Ubuntu)

Reason, verified from the 24.04 branch's own scripts: it is a deliberately
older, Qt5-based SDDM solution and is left frozen.

- `install-scripts/sddm.sh` on 24.04 installs `sddm` plus Qt5 QML modules:
  `qml-module-qtgraphicaleffects`, `qml-module-qtquick-controls`,
  `qml-module-qtquick-controls2`, `qml-module-qtquick-extras`,
  `qml-module-qtquick-layouts`. No Qt6 anywhere.
- `install-scripts/sddm_theme.sh` on 24.04 clones
  `LinuxBeginnings/simple-sddm` (the Qt5 theme, not `-2`) into
  `/usr/share/sddm/themes/simple-sddm`.
- 24.04 writes the theme selection to `/etc/sddm.conf.d/theme.conf.user`
  (`[Theme] Current=simple-sddm`), not to `/etc/sddm.conf`. The 26.04 branch
  writes `/etc/sddm.conf`. The two branches therefore disagree about where
  `[Theme] Current=` lives.
- The Ubuntu 24.04 base ships `sddm 0.20.0` and Qt 6.4.2, so SilentSDDM cannot
  run there regardless.

Consequences for the design:

- SilentSDDM is never offered on the 24.04 branch, and no installer change in
  this plan touches that branch.
- Any shared code added to this repo must keep the Qt5 `simple-sddm` family
  working as a legacy family: read-only, no new features, no SilentSDDM
  exposure. The dots already reference it in `scripts/lib_prompts.sh:281`.
- The switcher must detect where `[Theme] Current=` actually lives instead of
  hardcoding `/etc/sddm.conf` (see guardrail 4).

## 3. Upstream facts

From the README, `metadata.desktop`, `configs/default.conf` and `install.sh`.

### Requirements

- `sddm >= 0.21`
- `qt6 >= 6.5`
- `qt6-svg`
- `qt6-virtualkeyboard`
- `qt6-multimedia` (animated and video backgrounds)
- `qt6-imageformats`

### Install layout

- Theme directory: `/usr/share/sddm/themes/silent`
- Fonts: `fonts/redhat` and `fonts/redhat-vf` copied to `/usr/share/fonts`,
  then `fc-cache -f` (the greeter runs as the `sddm` user, so user fonts are
  not visible to it)
- `install.sh` backs up `/etc/sddm.conf` to `/etc/sddm.conf.bkp` before edits

### `/etc/sddm.conf` as upstream expects it

```
[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard

[Theme]
Current=silent
```

`GreeterEnvironment` is the part KooL does not set anywhere today.

### Theme metadata

```
[SddmGreeterTheme]
Name=Silent
Theme-Id=silent
Theme-API=2.0
MainScript=Main.qml
QtVersion=6
ConfigFile=configs/default.conf
License=GPL-3.0-or-later
Version=1.5.0
```

### Presets shipped upstream

`default`, `default-left`, `default-right`, `rei`, `ken`, `silvia`,
`everforest`, `catppuccin-latte`, `catppuccin-frappe`,
`catppuccin-macchiato`, `catppuccin-mocha`, `nord`, `gruvbox`,
`eldritch-cthulhu`, `eldritch-abyss`, `eldritch-dusk`.

Preset selection is by editing `ConfigFile=` in `metadata.desktop`.

### Config surface (200+ options, 21 categories)

Relevant keys, from `configs/default.conf`:

```
[General]
scale = 1.0
enable-animations = true
animated-background-placeholder = ""
background-fill-mode = "fill"

[LockScreen]
display = true
background = "smoky.jpg"
use-background-color = false
background-color = "#000000"
blur = 32
brightness = 0.0
saturation = 0.0

[LockScreen.Clock]
display = true
position = "top-center"
format = "hh:mm"
font-family = "RedHatDisplay"
font-size = 70
color = "#FFFFFF"

[LoginScreen]
background = "smoky.jpg"
blur = 0

[LoginScreen.LoginArea.PasswordInput]
content-color = "#FFFFFF"
background-color = "#FFFFFF"
background-opacity = 0.15
```

Notes that matter for integration:

- Backgrounds are referenced by filename, resolved against `backgrounds/` in
  the theme directory. There is no `Backgrounds/default` convention.
- Colours are per-element `color = "#RRGGBB"` keys. There is no shared colour
  block and no `theme.conf`-style colour keys.
- The clock format key is `[LockScreen.Clock] format`, not `HourFormat`.

### Packaging

- Arch: AUR `sddm-silent-theme` and `sddm-silent-theme-git`
- NixOS: flake module (`programs.silentSDDM.enable`, `.theme`, `.settings`,
  plus a `test-sddm-silent` executable)
- Gentoo: GURU `x11-misc/silent-sddm-theme` (plus `media-fonts/redhat`)
- Fedora / Debian / Ubuntu / Void / openSUSE: manual or `install.sh`
- Pling / KDE Store 2298627

### Testing

Upstream insists on `./test.sh` (sddm-greeter test mode) after every change,
because a broken theme means an unusable login screen.

## 4. Current KooL SDDM implementation

### Installers (per distro repo)

- `install-scripts/sddm.sh` installs SDDM and Qt6 dependencies:
  - Arch: `qt6-declarative qt6-svg qt6-virtualkeyboard
    qt6-multimedia-ffmpeg qt5-quickcontrols2 sddm`
    (`Arch-Hyprland/install-scripts/sddm.sh:11-18`), plus an optional
    `--enable-wayland` cage greeter path (`:68-130`)
  - Fedora: `sddm qt6-qtvirtualkeyboard qt6-qtmultimedia qt6-qtdeclarative
    qt6-qtsvg` (`Fedora-Hyprland/install-scripts/sddm.sh:11-17`)
  - Ubuntu 25.04+: `sddm` (`--no-install-recommends`) plus `libqt6svg6
    qt6-declarative-dev qt6-svg-dev qt6-virtualkeyboard-plugin
    libqt6multimedia6 qml6-module-qtquick-controls
    qml6-module-qtquick-effects` (`Ubuntu-Hyprland/install-scripts/sddm.sh:12-24`)
  - Ubuntu 24.04: Qt5 QML modules, frozen, out of scope
- `install-scripts/sddm_theme.sh` clones `LinuxBeginnings/simple-sddm-2` into
  `/usr/share/sddm/themes/simple_sddm_2`, then:
  - sets `[Theme] Current=simple_sddm_2`
  - sets `[General] InputMethod=qtvirtualkeyboard`
  - Ubuntu/Debian variants also copy the JetBrainsMono Nerd Font
    (`Ubuntu-Hyprland/install-scripts/sddm_theme.sh:110-123`), into
    `/usr/local/share/fonts`, which is also on the fontconfig path
  - Arch variant does not copy fonts

### Dotfile automation (this repo)

- `config/hypr/scripts/sddm_wallpaper.sh`
  - resolves the themes directory and `simple_sddm_2`, and requires
    `theme.conf` and `Backgrounds/` to exist (`:349-370`)
  - seds `HeaderTextColor` / `DateTextColor` / `TimeTextColor` /
    `HighlightBackgroundColor` / … in `theme.conf` from Wallust colours, then
    copies the wallpaper over `Backgrounds/default` (`:562-585`)
  - does the privileged work in a terminal with interactive `sudo` (`:548`)
  - skips NixOS (`:388-392`) and skips when SDDM is not running (`:394-403`)
  - supports per-monitor selection via `--monitor=`
- `scripts/lib_prompts.sh`
  - `apply_sddm_12h_format` edits `HourFormat=` in `theme.conf` for
    `simple-sddm` (the Qt5 legacy theme) and `simple_sddm_2` (`:298-309`)
  - `apply_sddm_12h_format_sequoia` handles `sequoia_2`'s `clockFormat=`
    (`:311-325`)
  - both are only reachable from the install/upgrade prompt
    (`prompt_clock_12h`, `:280-286`); there is no runtime 12H toggle for SDDM
- `config/hypr/scripts/Kool_Quick_Settings.sh`
  - "Set SDDM Wallpaper" in `[[ Misc ]]` (`:571-577`, menu entries `:769`
    and `:843`)
- `copy.sh`
  - `preserve_custom_sddm_configs` is a no-op stub (`:234-236`) called at
    `:879`
  - "SDDM background auto-sync removed to avoid overriding user-selected
    themes/wallpapers" (`:1224`)

### Reusable precedents already in the repo

These are the patterns a theme switcher should copy rather than invent:

- `config/hypr/scripts/RofiWlogoutTheme.sh` — rofi picker with a
  `--set <theme> [--silent]` CLI (`:12-29`), state read from
  `~/.config/wlogout/.current_theme` (`:39-42`), `apply_theme` that copies
  files and records state (`:150-209`), auto-backup of the previous custom
  config, `user_backup` preset
- `scripts/lib_copy.sh:819-863` `restore_wlogout_selection` — re-applies the
  recorded selection after `copy_phase2` replaces `~/.config`
- `scripts/lib_copy.sh` `_carry_rofi_theme_selection` — carries a single
  selection line into a freshly copied repo file
- `config/hypr/scripts/tests/test-installer-selections.sh` — stubs the applier
  on `PATH` (`:123-128`), asserts the recorded selection is re-applied
  (`:142-170`), and asserts the wiring exists in `copy.sh` / `lib_copy.sh`
  (`:187-195`)
- `config/hypr/scripts/tests/run-all.sh` plus `lib_test.sh` — the harness to
  extend
- `Arch-Hyprland/install-scripts/sddm.sh:76-84` — the existing
  `sddm-greeter` binary search across distro paths, which the test wrapper
  should reuse

## 5. Validation

### 5.1 Distro versions (verified against upstream package indexes)

- Debian 13 (trixie): `sddm 0.21.0+git20250502.4fe234b-2`, Qt 6.8 — OK
- Ubuntu 25.04 (plucky): `sddm 0.21.0+git20241213.4a9aa2e-1ubuntu2` — OK
- Ubuntu 25.10 (questing): `sddm 0.21.0+git20250502.4fe234b-2ubuntu1` — OK
- Ubuntu 26.04 (resolute): `sddm 0.21.0+git20250502.4fe234b-2ubuntu3` — OK
- Ubuntu 24.04 (noble): `sddm 0.20.0-2ubuntu4.2` — too old, excluded base
- Fedora 43, 44, 45: `sddm 0.21.0` — OK
- Arch: `sddm 0.21.0` — OK
- Fedora EPEL 9: `sddm 0.20.0` — not a target, listed for completeness

On every release this plan targets, SilentSDDM's version floor is already met.
Ubuntu 24.04 is the outlier and is explicitly out of scope.

### 5.2 Test hosts

`dwilliams@192.168.40.48` (`debian-jak-trixie`) — Debian GNU/Linux 13 (trixie),
kernel `7.2.12-1-liquorix-amd64`

This is the reference target for the work: a real, in-scope, working SDDM
install.

- `sddm` package `0.21.0+git20250502.4fe234b-2` — meets the floor
- `sddm --version` **aborts** on this host (SIGABRT). Version detection must
  not depend on it; see guardrail 2.
- `sddm-greeter` is not on `PATH` (Debian keeps it outside `/usr/bin`), so the
  test wrapper must search the same candidate paths the Arch installer already
  does.
- Qt6 6.8.2 installed: `libqt6core6t64 6.8.2+dfsg-9+deb13u2`,
  `libqt6qml6 6.8.2+dfsg-7`, `libqt6svg6 6.8.2-3`,
  `libqt6multimedia6 6.8.2-8`, `qt6-virtualkeyboard-plugin 6.8.2+dfsg-3`.
  This satisfies both the 6.5 floor and simple-sddm-2's 6.8 requirement.
- Service state: `sddm` is enabled and active.
- Config is `/etc/sddm.conf` only; `/etc/sddm.conf.d` **does not exist** on
  Debian 13. Contents:

```
[Theme]
Current=simple_sddm_2

[General]
InputMethod=qtvirtualkeyboard
```

- `DisplayServer` is unset, so SDDM runs its default X11 greeter. Neither
  `cage` nor `kwin_wayland` is installed, so the Wayland-greeter path is not
  in play on this host.
- Installed themes: `simple_sddm_2` only, and it is owned by
  `dwilliams:dwilliams` (`drwxrwxr-x`), not `root:root`. Scripts must not
  assume root ownership, and must keep working when it *is* root-owned, which
  is the norm for an installer-created theme.
- Its `theme.conf` already carries the 12H preference from the dots'
  install-time prompt: `HourFormat="hh:mm AP"` active, `## HourFormat="HH:mm"`
  commented out, and `Background="Backgrounds/default"`. A theme switch must
  carry that clock preference across, or it silently reverts to 24H.
- Greeter fonts: `/usr/share/fonts` has `InterVariable.ttf` and
  `MaterialSymbolsRounded.ttf`; no RedHat fonts. The Debian theme script
  installs JetBrainsMono into `/usr/local/share/fonts`, so SilentSDDM's RedHat
  fonts can go to either location as long as `fc-cache -f` runs afterwards.
- Qt6 dependency candidates on trixie:
  - `qt6-image-formats-plugins`: not installed, candidate `6.8.2-4` —
    **the one missing dependency**
  - `qml6-module-qtmultimedia 6.8.2-8` — already installed, so the video
    background preset is viable here
  - `qml6-module-qtquick-controls 6.8.2+dfsg-7`,
    `qml6-module-qtquick-effects 6.8.2+dfsg-7`,
    `qml6-module-qtqml-workerscript 6.8.2+dfsg-7` — installed
  - `qml6-module-qtvirtualkeyboard`: no candidate under that name on trixie,
    while `qt6-virtualkeyboard-plugin` is installed. The QML virtual-keyboard
    module package name differs per distro and must be resolved per release
    rather than hardcoded.

Verdict: valid target. One package to add, and the correct place to run the
manual reboot test in section 10.

`dwilliams@192.168.40.196` (`jak-hl`) — NixOS 26.11 (Zokor)

- No `sddm` binary, no `/etc/sddm.conf`, no theme directory. There is nothing
  to add a theme to until SDDM is enabled system-wide.
- On NixOS the correct route is upstream's flake module
  (`programs.silentSDDM.enable = true`), which is a system-level change.
- The dots deliberately skip SDDM work on NixOS
  (`config/hypr/scripts/sddm_wallpaper.sh:388-392`), so wallpaper and colour
  sync would not apply there regardless.

`dwilliams@192.168.40.4` (`jak-zorin-18`) — Zorin OS 18.1 (Ubuntu 24.04 base)

- `sddm` not installed; candidate `0.20.0-2ubuntu4.2` — below the 0.21 floor
- `libqt6core6t64 6.4.2+dfsg-21.1build5`, `libqt6svg6 6.4.2-4ubuntu3` — below
  both the 6.5 floor and simple-sddm-2's 6.8 floor
- Available: `qt6-image-formats-plugins 6.4.2-5build2`,
  `qml6-module-qtmultimedia 6.4.2-11build3`,
  `qml6-module-qtquick-controls 6.4.2+dfsg-4build3`
- No candidate at all: `qml6-module-qtvirtualkeyboard`,
  `qml6-module-qtquick-effects`, `qt6-virtualkeyboard-plugin`
- Verdict: this host belongs to the excluded 24.04 class. It keeps its
  existing older SDDM and Qt5 `simple-sddm` setup. SilentSDDM is not offered
  here; reaching it would need a newer base.
- Side note: the Ubuntu installer's current Qt6 package list
  (`qml6-module-qtquick-effects`, `qt6-virtualkeyboard-plugin`) does not fully
  resolve on this base either, which is consistent with treating it as frozen.

### 5.3 Requirement deltas versus what the in-scope installers install today

- Debian 13: only `qt6-image-formats-plugins` is missing; the multimedia QML
  module is already present
- Arch: only `qt6-imageformats` is missing
- Fedora: only `qt6-qtimageformats` is missing
- Ubuntu 25.04+: need the Qt6 image-formats plugin and the Qt6 Multimedia QML
  module (names differ per release; verify with `apt-cache policy` before use)
- All: `GreeterEnvironment=QML2_IMPORT_PATH=…,QT_IM_MODULE=qtvirtualkeyboard`
  is not set by any installer today

### 5.4 Compatibility gaps (what actually breaks)

1. Backgrounds. `sddm_wallpaper.sh` writes `Backgrounds/default` and expects
   `theme.conf`. SilentSDDM wants a file under `backgrounds/` and the filename
   written into `[LoginScreen] background` and `[LockScreen] background`.
2. Colours. `sddm_wallpaper.sh` seds `theme.conf` colour keys that do not
   exist in SilentSDDM. SilentSDDM has per-element `color = "#…"` keys only.
3. Clock format. `HourFormat=` and `clockFormat=` do not exist in SilentSDDM;
   the key is `[LockScreen.Clock] format`. The Debian 13 host already has a
   user-visible 12H preference in `theme.conf`, so a switch that ignores this
   is a visible regression.
4. `GreeterEnvironment`. `QML2_IMPORT_PATH` is a single global value pointing
   at `silent/components/`. It must be added when switching to silent and
   removed when switching away, otherwise a later switch back to
   `simple_sddm_2` inherits a stale import path.
5. `[Theme] Current=` is single-valued, and its location differs by base:
   `/etc/sddm.conf` on Debian 13 and Ubuntu 26.04, and
   `/etc/sddm.conf.d/theme.conf.user` on the 24.04 branch. This is an
   alternative, not a coexistence.
6. Per-monitor SDDM wallpaper is a KooL feature (`sddm_wallpaper.sh
   --monitor=`). SilentSDDM exposes one background per screen category, so
   parity is not automatic and needs upstream verification.
7. Video wallpapers. KooL converts a video to a single PNG frame with ffmpeg.
   SilentSDDM can play video directly, and the Qt6 Multimedia QML module is
   already present on Debian 13, but the config handling differs.
8. Theme updates. `preserve_custom_sddm_configs` is a no-op stub, so dotfile
   upgrades never touch `/usr/share/sddm/themes`. An installed SilentSDDM
   survives upgrades but is never managed or updated by them either.

## 6. Guardrails

1. Scope gate. Never apply this plan to `Ubuntu-Hyprland` branch `24.04` or
   its siblings. Detection: a Qt5 QML stack, `sddm < 0.21`, or
   `/etc/sddm.conf.d/theme.conf.user` naming `simple-sddm`. On a match, exit
   early with a message rather than attempting anything.
2. Version gate, with a fallback. Refuse the `silent` family unless
   `sddm >= 0.21` and `qt6 >= 6.5`. Detect from `sddm --version` **and** from
   the package manager, because `sddm --version` aborts on Debian 13; never
   treat a crashed probe as a failure or as "unknown → allow". Resolve Qt6
   from the runtime libraries, not from the distro name, and print what was
   found when refusing.
3. Never edit an SDDM config without a backup. Timestamped copy plus a stable
   `sddm.conf.kooldots.bak`, atomic write (temp file then `install -m 644`),
   and a `--restore` path.
4. Detect the config layout, do not assume it. Find the file that actually
   defines `[Theme] Current=` across `/etc/sddm.conf` and
   `/etc/sddm.conf.d/*.conf` (later files winning), and edit that one. Debian
   13 has no `/etc/sddm.conf.d` at all, so creating a drop-in means creating
   the directory too. This detection is what keeps the 24.04 drop-in path and
   the 26.04 direct path from fighting each other.
5. Test before apply. Run the family's own test mode before switching, using
   the `sddm-greeter` search paths from
   `Arch-Hyprland/install-scripts/sddm.sh:76-84`, because the binary is not on
   `PATH` on Debian. A generated preset is never applied unvalidated. This is
   upstream's own rule, and it exists because a broken theme means an unusable
   login screen.
6. One `Current` theme, clean environment. Family switches must add or remove
   `GreeterEnvironment` as a unit. A stale `QML2_IMPORT_PATH` is the main
   cross-theme breakage.
7. Carry the user's clock preference. The 12H/24H choice is user state and
   already set on the Debian host. Record it alongside the theme so a switch
   does not silently revert it.
8. `sudo` policy. Keep the existing split: non-interactive contexts
   (`lib_prompts.sh:303-308`) use `sudo -n` and warn-and-continue rather than
   hanging on a password prompt; only the explicit picker uses interactive
   `sudo` in a terminal, as `sddm_wallpaper.sh:548` does today. Do not assume
   the theme directory is root-owned: on Debian 13 it is user-owned, and
   writes there may succeed without privileges.
9. NixOS. Skip, as today, or route to upstream's flake module. Never write
   into `/run/current-system`.
10. Presets and licence. Upstream is GPL-3.0-or-later, compatible with this
    repo. If presets are vendored or forked under `LinuxBeginnings`, keep
    `LICENSE` and credits, mirroring how `simple-sddm-2` is handled.
11. Fonts. Greeter fonts go to `/usr/share/fonts` or `/usr/local/share/fonts`
    plus `fc-cache -f`. Do not rely on `~/.local/share/fonts`.
12. State placement. Record the active theme and preset under
    `${XDG_STATE_HOME:-$HOME/.local/state}/hypr/` so `copy_phase2` cannot
    clobber it. Anything the user authors under `~/.config/hypr/sddm/` must be
    restored by the `preserve_custom_sddm_configs` hook (`copy.sh:234-236`),
    which currently does nothing.
13. Opt-in only. Do not silently change the active theme at install time or
    during upgrades. `copy.sh:1224` records the earlier decision to stop
    auto-syncing SDDM; this plan does not reverse it. `simple_sddm_2` stays the
    default, and the legacy Qt5 `simple-sddm` family keeps working.
14. Capability checks, not assumptions. Anything family-specific (per-monitor
    background, video background, colour keys) is gated on a probe, and
    degrades to a notification rather than a failure. Dependency package names
    differ per distro and release: resolve them per release instead of
    hardcoding, as `qml6-module-qtvirtualkeyboard` versus
    `qt6-virtualkeyboard-plugin` on trixie shows.
15. Tests. New menu and selector logic gets a test under
    `config/hypr/scripts/tests/` and must pass `tests/run-all.sh`.
    `test-no-hardcoded-outputs.sh` matters if new paths are hardcoded.
16. Changelog and wiki. If any of this ships user-facing, follow the repo's
    `AGENTS.md`: entry under the next version heading in `CHANGELOG.md`, no
    version bump for a normal change, wiki sync only after the release lands
    on `main`.

## 7. Solution A — add SilentSDDM as an opt-in theme family

The low-risk path, and a prerequisite for Solution B.

- New `install-scripts/sddm_silent_theme.sh` in each in-scope distro repo,
  modelled on the existing `sddm_theme.sh`:
  - scope and version gate before anything else
  - clone upstream (`--depth=1`) and copy into
    `/usr/share/sddm/themes/silent`
  - copy `fonts/redhat` and `fonts/redhat-vf` to the greeter font path, run
    `fc-cache -f`
  - back up the SDDM config, set `[Theme] Current=silent`, add
    `GreeterEnvironment` (add it, do not append duplicates)
- Extend the dependency lists: `qt6-image-formats-plugins` (Debian 13),
  `qt6-imageformats` (Arch), `qt6-qtimageformats` (Fedora), image-formats
  plugin plus the Qt6 Multimedia QML module (Ubuntu 25.04+)
- Wire a menu entry in each installer's `install.sh` so the theme is a choice
  (simple, silent, both), not a replacement
- Keep `simple_sddm_2` as the default

Estimated size: roughly 120 lines per distro repo, plus installer menu wiring.

## 8. Solution B — KooL SDDM theme and preset switcher

This is the custom solution: keep KooL's own code in charge, make the theme
family a variable, and use SilentSDDM's presets as sample material for a KooL
preset set.

### 8.1 Design

Introduce a thin adapter layer so every SDDM-facing script stops knowing which
theme it is talking to, and a picker that owns the switch.

```
Kool_Quick_Settings.sh ──┐
sddm_wallpaper.sh ───────┼──> lib_sddm.sh ──> per-family adapter ──> /usr/share/sddm/themes/<theme>
lib_prompts.sh (12H) ────┘         │                                  the SDDM config file in use
                                   └──> state: $XDG_STATE_HOME/hypr/sddm-theme.current
RofiSddmTheme.sh (picker) ─────────┘
```

### 8.2 Adapter contract (`config/hypr/scripts/lib_sddm.sh`)

One function per capability, one branch per family. Families:
`simple_sddm_2`, `sequoia_2`, `silent`, `simple-sddm` (Qt5 legacy, read-only),
`unknown`.

- `sddm_config_file` — resolve the config file that defines the active theme,
  covering `/etc/sddm.conf` and `/etc/sddm.conf.d/*.conf`
- `sddm_themes_dir` — resolve `/usr/share/sddm/themes` with the NixOS
  `/run/current-system/sw/share/sddm/themes` fallback, as today
- `sddm_active_theme` — parse `[Theme] Current=` from the resolved file
- `sddm_family_for <theme>` — map directory name to family
- `sddm_version`, `sddm_qt_version` — package-version and runtime-library
  probes with the `sddm --version` fallback ordering from guardrail 2
- `sddm_require` — capability gate used by every caller
- `sddm_theme_supports <family> <capability>` — `background`,
  `wallust-colors`, `clock-format`, `per-monitor-background`,
  `video-background`
- `sddm_set_background <file> [monitor]`
  - `simple_sddm_2`: copy to `Backgrounds/default`, update `theme.conf`
  - `silent`: copy into `backgrounds/`, write the filename into
    `[LoginScreen] background` and `[LockScreen] background`
- `sddm_set_colors <wallust-colors-file>`
  - `simple_sddm_2`: sed the existing colour keys, as today
  - `silent`: generate a complete `configs/kooldots.conf` from a template with
    Wallust values substituted, which is safer than sed-ing 200+ options
- `sddm_set_clock_format 12h|24h`
  - `simple-sddm` and `simple_sddm_2`: `HourFormat=`
  - `sequoia_2`: `clockFormat=`
  - `silent`: `[LockScreen.Clock] format = "hh:mm"` or `"hh:mm AP"`
- `sddm_apply_conf` — the single privileged writer: backup, atomic write,
  optional `GreeterEnvironment` add or remove

`lib_sddm.sh` is sourced by the scripts below and holds no user-facing menu
code.

### 8.3 New and changed files

New:

- `config/hypr/scripts/lib_sddm.sh` — the adapter layer above
- `config/hypr/scripts/RofiSddmTheme.sh` — picker and applier
  - CLI mirrors `RofiWlogoutTheme.sh`: `--set <family[:preset]> [--silent]`,
    plus `--restore`
  - lists installed families and their presets, marking the active one
  - runs the family's test mode before applying
  - records state, and restores the previous config on failure
- `config/hypr/scripts/SddmTestTheme.sh` — wrapper around the family's test
  mode, so the picker and the installers share one entry point
- `config/hypr/sddm/presets/silent/` — KooL preset files for the silent family
- `config/hypr/sddm/presets/simple_sddm_2/` — `theme.conf` overlay fragments so
  presets exist on both families
- `config/hypr/scripts/tests/test-sddm-theme-menu.sh`

Changed:

- `config/hypr/scripts/sddm_wallpaper.sh` — replace the hardcoded
  `simple_sddm_2` block (`:349-370`) and the colour and background block
  (`:562-585`) with `lib_sddm.sh` calls; keep the rofi menu and the
  per-monitor UX, gated on `sddm_theme_supports`
- `scripts/lib_prompts.sh` — `apply_sddm_12h_format` and
  `apply_sddm_12h_format_sequoia` (`:298-325`) become thin wrappers over
  `sddm_set_clock_format`
- `config/hypr/scripts/Kool_Quick_Settings.sh` — add "Choose SDDM Theme" to
  `[[ Misc ]]` (`:765-786`, meta at `:815`, quick links at `:843`) and a
  `handle_choice` case next to "Set SDDM Wallpaper" (`:571-577`)
- `copy.sh` — implement `preserve_custom_sddm_configs` (currently the stub at
  `:234-236`) and call an SDDM restore next to `restore_wlogout_selection`
  (`:879`)
- `scripts/lib_copy.sh` — add `restore_sddm_selection`, modelled on
  `restore_wlogout_selection` (`:819-863`)

### 8.4 Presets

Imported samples, adapted from SilentSDDM's set with attribution kept:

- `default`, `rei`, `ken`, `silvia`, `everforest`
- `catppuccin-latte`, `catppuccin-frappe`, `catppuccin-macchiato`,
  `catppuccin-mocha`
- `nord`, `gruvbox`, `eldritch-cthulhu`, `eldritch-abyss`, `eldritch-dusk`

New KooL presets, the "create some new ones as well" part:

- `kool-wallust` — generated from the live Wallust palette, so the login
  screen tracks the wallpaper colours
- `kool-default` — KooL house style, matching the dots' own palette
- `kool-tokyo-night`, `kool-kanagawa`, `kool-rose-pine`, `kool-dracula`,
  `kool-everforest-dark`
- `kool-video` — animated background preset, offered only when the Qt6
  Multimedia QML module is present, which it already is on Debian 13

Naming: KooL-authored presets are prefixed `kool-` so imported upstream
presets stay recognisable and re-syncable.

Preset mechanics:

- a preset is a full config file for the silent family, because SilentSDDM has
  no include mechanism
- the active preset is recorded in `metadata.desktop` (`ConfigFile=`), so the
  picker must treat that file as state and rewrite it atomically
- for `simple_sddm_2`, a preset is a small set of `theme.conf` keys plus a
  background, since that theme has no preset concept of its own

### 8.5 State, upgrade and preserve semantics

- Active selection:
  `${XDG_STATE_HOME:-$HOME/.local/state}/hypr/sddm-theme.current`, format
  `family:preset`, one line. It lives outside `~/.config` so `copy_phase2`
  cannot clobber it.
- Clock preference: recorded in the same state file, so a theme switch
  preserves the user's 12H/24H choice.
- User-authored presets: `~/.config/hypr/sddm/presets/`, restored from the
  upgrade backup by the new `preserve_custom_sddm_configs`, the same way
  `restore_wlogout_selection` handles `themes/user_backup`.
- Repo-authored presets: `config/hypr/sddm/presets/`, replaced on upgrade like
  other repo files.
- Failure handling: if a switch fails its test, restore
  `sddm.conf.kooldots.bak` and the previous `ConfigFile=` value, then notify.

### 8.6 UX wiring

- Quick Settings: `[[ Misc ]]` gains "Choose SDDM Theme" next to "Set SDDM
  Wallpaper"
- Picker: family list first, then presets within the chosen family, active
  entry marked, `--silent` mode for scripted callers
- Optional but nearly free: make the 12H toggle runtime-toggleable for SDDM.
  Today it only runs during install and upgrade (`lib_prompts.sh:280-286`).

## 9. Phased implementation

Phase 0 — research and validation. Done. This document.

Phase 1 — capability detection and docs only. Add `lib_sddm.sh` with the
scope, version and capability probes, no behaviour change. Validate the probes
against the Debian 13 host, including the `sddm --version` abort path.
Low risk, and everything later depends on it.

Phase 2 — SilentSDDM installer (Solution A). In-scope distro repos only,
opt-in, version-gated, fonts and `GreeterEnvironment` handled,
`simple_sddm_2` still default.

Phase 3 — switcher and adapter (Solution B core). `RofiSddmTheme.sh`, state
file, `sddm_wallpaper.sh` and 12H refactors, Quick Settings entry,
`preserve_custom_sddm_configs` implementation, upgrade restore.

Phase 4 — presets. Import the SilentSDDM set with attribution, add the `kool-`
presets, add Wallust-generated preset support, add the video preset behind a
capability check.

Phase 5 — tests, changelog, wiki. `test-sddm-theme-menu.sh`, extend
`test-installer-selections.sh` for the preserve hook, `run-all.sh`, then the
`CHANGELOG.md` entry and wiki sync after release.

Each phase is independently shippable. Phases 3 and 4 are the bulk of the
work; phase 2 delivers the headline capability.

## 10. Tests

- `test-sddm-theme-menu.sh` (new): stub `sudo`, `sddm`, `sddm-greeter` and the
  theme directories; assert the state file content, that the active entry is
  marked, that a failed test restores the previous `ConfigFile=`, that
  `GreeterEnvironment` is added for silent and removed when leaving it, that
  the clock preference survives a switch, and that a 24.04-style drop-in
  layout is detected and refused. Follow the stub-applier pattern at
  `config/hypr/scripts/tests/test-installer-selections.sh:123-128`.
- `test-installer-selections.sh` (extend): assert `copy.sh` calls the SDDM
  restore, and that a saved user preset survives an upgrade, mirroring the
  wlogout assertions at `:142-170` and `:187-195`.
- Adapter unit coverage: each `sddm_set_*` function against a fixture theme
  tree for each family, including `unknown` and the Qt5 legacy family, which
  must be a clean no-op with a notification rather than a crash.
- Version-probe coverage: a stubbed `sddm --version` that aborts must still
  resolve the version from the package manager.
- `test-no-hardcoded-outputs.sh` must still pass if new paths are introduced.
- Manual: `./test.sh` in the installed theme, plus one real reboot per family
  on a host that satisfies the version gate. The Debian 13 host
  (`debian-jak-trixie`) is the target for this; the Zorin 18.1 host is not a
  valid target.

## 11. Changelog, wiki and licence

- `CHANGELOG.md`: one top-level bullet per user-facing change, nested detail
  bullets, `Fixed:` first, under the next version heading. No version bump for
  any of this; the version only moves when a release is cut.
- Wiki (`Changelogs.md`, `Changelogs.es.md`): sync only after the release
  lands on `main`.
- Licence: SilentSDDM is GPL-3.0-or-later. Keep `LICENSE` and credits for
  anything vendored or forked under `LinuxBeginnings`, as `simple-sddm-2`
  does. Cloning upstream at install time avoids vendoring entirely.
- Commit messages: short subject, files by basename, no root-cause narration.

## 12. Open questions

1. Fork or layer? Cloning upstream and layering KooL presets keeps licence and
   update handling simple. Forking under `LinuxBeginnings`, as with
   `simple-sddm-2`, gives control but adds a repo to maintain. Recommendation:
   layer first.
2. Default theme. Recommendation: keep `simple_sddm_2` as default and offer
   silent as an option, given that the 24.04 class of bases cannot run it.
3. Config write target. Editing `/etc/sddm.conf` in place matches Debian 13
   and Ubuntu 26.04 today, while a KooL-owned drop-in in `/etc/sddm.conf.d/`
   that sorts last is cleaner and would need the directory created on Debian
   13. Recommendation: detect, then prefer the drop-in, so nothing is silently
   overridden.
4. Per-monitor SDDM backgrounds on the silent family. Needs upstream
   verification before promising parity. The adapter design degrades
   gracefully either way.
5. Video backgrounds. Adopt SilentSDDM's native video support, which is a new
   feature and already possible on Debian 13, or keep the ffmpeg-frame
   approach for parity? Recommendation: offer both, video only when the module
   is present.
6. Wallust to preset. Generating a full config file is safer than sed-ing
   per-element colour keys. Confirm the generated file stays within the
   documented option set so upstream updates cannot break it.
7. Should the 12H toggle become a runtime Quick Settings action for SDDM, not
   just an install-time prompt? Recommendation: yes, it is nearly free once
   `sddm_set_clock_format` exists.
8. Do we fold `sequoia_2` into the adapter too, or leave it on its current
   special-case path? Recommendation: fold it in for one code path, but only
   if it can be tested.

## 13. Verification appendix

Commands and sources used for the claims above.

- Upstream README, `metadata.desktop`, `configs/default.conf`, `install.sh`:
  <https://github.com/uiriansan/SilentSDDM>
- KooL theme requirements (`sddm >= 0.21`, `qt6 >= 6.8`):
  <https://github.com/LinuxBeginnings/simple-sddm-2>
- Debian trixie `sddm`: `0.21.0+git20250502.4fe234b-2`
- Ubuntu suites: jammy `0.19.0`, noble `0.20.0`, plucky `0.21.0+git…`,
  questing `0.21.0+git…`, resolute `0.21.0+git…`
- Fedora: 43, 44, 45 `sddm 0.21.0`; EPEL 9 `0.20.0`
- `Ubuntu-Hyprland` branch `24.04`, read with
  `git show 24.04:install-scripts/sddm.sh` and
  `git show 24.04:install-scripts/sddm_theme.sh`: Qt5 QML modules,
  `LinuxBeginnings/simple-sddm`, and `/etc/sddm.conf.d/theme.conf.user`
- Host probes (read-only, over SSH), each reading `/etc/os-release`,
  `dpkg-query -W` for the installed versions, `systemctl is-enabled/is-active`
  for the service, `cat /etc/sddm.conf` and `/etc/sddm.conf.d/*`,
  `ls /usr/share/sddm/themes`, the theme's `theme.conf` keys, `ls
  /usr/share/fonts`, and `apt-cache policy` for the Qt6 dependency set:
  - `192.168.40.48`: Debian 13 (trixie), kernel `7.2.12-1-liquorix-amd64`,
    `sddm 0.21.0+git20250502.4fe234b-2` enabled and active, Qt6 6.8.2,
    `/etc/sddm.conf` only with `Current=simple_sddm_2`, user-owned theme dir,
    `HourFormat="hh:mm AP"` already set, `qt6-image-formats-plugins` the only
    missing dependency, no `cage` or `kwin_wayland`
  - `192.168.40.196`: `/etc/os-release` reports NixOS 26.11, `command -v sddm`
    is empty, no `/etc/sddm.conf`, no theme directory
  - `192.168.40.4`: `/etc/os-release` reports Zorin OS 18.1,
    `apt-cache policy sddm` candidate `0.20.0-2ubuntu4.2`,
    `dpkg-query -W libqt6core6t64` reports `6.4.2+dfsg-21.1build5`, and the
    Qt6 dependency set listed in section 5.2
- Local repository state at time of writing: `Hyprland-Dots` on `development`,
  `Ubuntu-Hyprland` checked out at branch `26.04`
