# Plan: Dotfiles Updater (Waybar KoolDots update check → download + upgrade)
## Goal
Extend the Waybar `custom/dot_update` check so that when an update exists the user can have the updater download the distro installer for their OS and the current `Hyprland-Dots` into a randomly generated temp directory in their home directory, run the installer's `install-scripts/update-deps.sh`, then run `copy.sh --tty --express-upgrade` in a real terminal window so the user can answer its prompts. When the run is done, prompt before removing the downloaded temp files.

Phase 1 is that download-and-upgrade flow plus a preflight advisory. Phase 2 adds an OS update option and, on Debian, updating a source-built Hyprland stack to the pinned, validated versions.
## Current state
- Waybar `custom/dot_update` (`config/hypr/waybar/ModulesCustom:93`) is a click target only. It runs `config/hypr/scripts/KooLsDotsUpdate.sh`, which compares the installed `DOTS_VERSION` against `main` and then shows a yad/rofi/zenity window offering only a Changelog link and OK.
- The manual upgrade route is documented in `docs/HOWTO-Upgrade-Dotfiles.md`: clone the distro installer, run `install-scripts/update-deps.sh`, clone `Hyprland-Dots`, run `./copy.sh --tty --express-upgrade`, reboot.
- `copy.sh` already parses `--upgrade`, `--express-upgrade` and `--tty` (`copy.sh:563-593`). Express needs installed dots `>= 2.3.18` (`MIN_EXPRESS_VERSION`, `copy.sh:94`). The Debian test host is on `2.3.29-dev`, so express is available.
- `copy.sh` hard-requires `rsync` (`copy.sh:669`), refuses to run as root (`copy.sh:663`), and warns on Debian/Ubuntu when Hyprland is below `0.55` (`copy.sh:96`, `copy.sh:681`).
- Every supported distro installer (`Debian-Hyprland`, `Arch-Hyprland`, `Fedora-Hyprland`, `Ubuntu-Hyprland`, `OpenSUSE-Hyprland`) ships `install-scripts/update-deps.sh`. It resolves its own repo root and `cd`s to the parent, so it can be run by absolute path from a temp clone and it writes its logs into that clone's `Install-Logs/`.
- The Ubuntu installer is branched per release — upstream heads are `24.04`, `24.04-development`, `25.10`, `26.04`, `26.04-development`, `main`, `ubuntu-install` — while the other installers use `main`.
- There is no Gentoo installer repo upstream. NixOS has one, but it is declarative and has no `update-deps.sh`.
- Debian only: `Debian-Hyprland/hypr-tags.env` pins the validated stack (`HYPRLAND_TAG=v0.56.2`, `AQUAMARINE_TAG=v0.15.1`, `HYPRUTILS_TAG=v0.14.2`, `HYPRLANG_TAG=v0.6.8`, `HYPRCURSOR_TAG=v0.1.13`, `HYPRGRAPHICS_TAG=v0.5.1`, `HYPRLAND_PROTOCOLS_TAG=v0.8.0`, `WAYLAND_PROTOCOLS_TAG=1.49`, `HYPRIDLE_TAG=v0.1.8`, `HYPRLOCK_TAG=v0.9.6`, `HYPRPAPER_TAG=v0.8.4`, `HYPRPICKER_TAG=v0.4.7`, `HYPRSUNSET_TAG=v0.4.0`, `HYPRLAUNCHER_TAG=v0.1.7`, `HYPRWAYLAND_SCANNER_TAG=v0.4.6`, plus branch pins `HYPRTOOLKIT_TAG=main`, `HYPRWIRE_TAG=main`, `HYPRTAVERN_TAG=auto`, `HYPRWIRE_PROTOCOLS_TAG=hyprtavern`).
- `Debian-Hyprland/update-hyprland.sh` builds and installs the stack from those pins, must run from the repo root (`update-hyprland.sh:49-50`), and `--install` also purges Debian hyprland packages first (`update-hyprland.sh:445`, `update-hyprland.sh:1538-1545`).
- `config/hypr/scripts/Distro_update.sh` already performs per-distro OS updates (paru/yay, dnf, apt, zypper) and is bound to the Waybar `custom/updater` module (`ModulesCustom:245-253`). Phase 2 can reuse its commands rather than reinventing them.
- Test host facts (Debian 13 trixie, `192.168.40.48`): source-built `Hyprland` and `hyprctl` in `/usr/local/bin`, version `0.56.2`. Hyprland *is* running; an SSH probe simply has to resolve `HYPRLAND_INSTANCE_SIGNATURE` first, because a bare `hyprctl version` fails with `HYPRLAND_INSTANCE_SIGNATURE not set!`. There are no `Debian-Hyprland` or `Hyprland-Dots` directories in `$HOME`, which is exactly the target case for the temp-clone flow.
## Phase 1 — download and upgrade (this change)
### 1. Preflight advisory
Before anything is downloaded or installed, print a short advisory and ask for confirmation:
- Confirm the OS is fully up to date before upgrading the dots. In Phase 1 this is the user's own step; Phase 2 offers to do it from the updater.
- Debian, when Hyprland is built from source: confirm they are on the most current version, and point at the upgrade guide — https://github.com/LinuxBeginnings/Debian-Hyprland/blob/main/Debian-Hyprland-Install-Upgrade.md
- Both of these become actions in Phase 2; the Phase 1 text is informational only.
### 2. New terminal-run orchestrator: `config/hypr/scripts/KooLsDotsUpgrade.sh`
A bash script that runs inside a terminal window and performs the whole sequence. Flags: `--dry-run` (print the resolved plan, the advisory and the exact commands; clone nothing, change nothing), `--keep-temp` (skip the final cleanup prompt), `--force` (skip the "an update is available" re-check).

Flow:
1. Preflight: refuse root; require bash, `git`, `curl`, `rsync`; require a TTY on stdin and stdout (otherwise notify and exit); take an exclusive `flock` on `${XDG_RUNTIME_DIR:-/tmp}/kooldots-upgrade.lock` so two runs cannot interleave. Then print the advisory from section 1 and require a yes before continuing.
2. Detect the distro from `/etc/os-release` plus the `pacman`/`dnf`/`zypper` probes, and resolve the installer repo plus branch:
   - Debian GNU/Linux → `Debian-Hyprland`, `main`
   - Ubuntu → `Ubuntu-Hyprland`, branch `$VERSION_ID` if it exists upstream, else `$VERSION_ID-development`, else `main`, checked with `git ls-remote --heads` because this installer is branched per release
   - Arch (`pacman`) → `Arch-Hyprland`, `main`
   - Fedora (`dnf`) → `Fedora-Hyprland`, `main`
   - openSUSE (`zypper`) → `OpenSUSE-Hyprland`, `main`
   - NixOS, Gentoo and anything unmatched → unsupported: print guidance, keep the existing notify-only behaviour, exit 0 without cloning
3. Create the temp tree. A randomly generated directory in the user's home, `TEMPDIR="$(mktemp -d "${KOOLDOTS_UPGRADE_TMP_ROOT:-$HOME}/kooldots-upgrade-XXXXXX")"`, with each repo cloned into its own directory inside it: `$TEMPDIR/<Distro>-Hyprland/` (for example `$TEMPDIR/Debian-Hyprland/`) and `$TEMPDIR/Hyprland-Dots/`. The two paths in the request therefore resolve as `$TEMPDIR/<Distro>-Hyprland/install-scripts/update-deps.sh` and `$TEMPDIR/Hyprland-Dots/copy.sh`.
4. Clone both repos `--depth=1` from `https://github.com/LinuxBeginnings/<repo>.git`, passing `-b <branch>` for the installer when the branch is not `main`. Fail fast: if either clone fails, remove `$TEMPDIR` and exit non-zero without touching the installed system.
5. Run `bash "$TEMPDIR/<Distro>-Hyprland/install-scripts/update-deps.sh"`, tee'd to `$TEMPDIR/kooldots-upgrade.log`. This installs and updates the dependencies the new dots need and uses `sudo`, which is why the whole flow needs a terminal.
6. Run `( cd "$TEMPDIR/Hyprland-Dots" && ./copy.sh --tty --express-upgrade )`, tee'd to the same log. `--tty` forces the plain prompts instead of whiptail, `--express-upgrade` skips the restore questions.
7. Print the log path, remind the user to reboot, then prompt `Remove $TEMPDIR and the downloaded files? [y/N]` and `rm -rf` only on yes. `--keep-temp` skips the prompt. A failed run keeps the temp tree and prints the log path instead of deleting it.
### 3. Shared helper: `config/hypr/scripts/lib_dotfiles_upgrade.sh`
Holds the pure, testable pieces so the orchestrator stays readable and the tests do not need a real system: distro detection and repo/branch resolution, temp-dir creation, and the exact command strings for the two child scripts. Follows the existing `config/hypr/scripts/lib_display_store.sh` precedent. Phase 2 extends the same file with the version probes and the comparison.
### 4. Entry point: `config/hypr/scripts/KooLsDotsUpdate.sh`
Keep the current check, notification and version comparison exactly as they are. Add a third action to the update dialog:
- yad: add `--button="Upgrade now:3"` beside Changelog and OK, and launch on `3`.
- rofi: add a third row to the existing dmenu list.
- zenity: cannot render three buttons, so use `--question` with `Upgrade` / `Cancel` and keep the changelog URL in the body text.

Launching reuses `config/hypr/scripts/LaunchTerminal.sh` with the terminal resolved the way `WaybarScripts.sh:36-53` does it (`KOOLDOTS_DEFAULTS.term` in `UserConfigs/user_defaults.lua`, then `lua/user_defaults.lua`, then `$TERMINAL`, then `kitty`), with the payload `"$HOME/.config/hypr/scripts/KooLsDotsUpgrade.sh"`. Also add `--upgrade` to `KooLsDotsUpdate.sh` so the terminal can be launched directly without the dialog.
### 5. Waybar module: `config/hypr/waybar/ModulesCustom`
For `custom/dot_update` (`ModulesCustom:93`), keep `on-click` as the check, add `on-click-right` running `KooLsDotsUpdate.sh --upgrade`, and update `tooltip-format` to say Left click checks and Right click downloads and upgrades.
### 6. Tests
`config/hypr/scripts/tests/test-dotfiles-upgrade.sh` (new), written against `tests/lib_test.sh` and picked up automatically by `tests/run-all.sh`, covering:
- Distro mapping: Debian trixie, Ubuntu 24.04 / 25.10 / 26.04, Arch, Fedora, openSUSE; NixOS, Gentoo and unknown all resolve to unsupported.
- Temp tree: a random directory under `$HOME`, honours `KOOLDOTS_UPGRADE_TMP_ROOT`, and contains `<Distro>-Hyprland/` and `Hyprland-Dots/` as siblings.
- `--dry-run` output asserts the exact commands and their order (`install-scripts/update-deps.sh`, then `./copy.sh --tty --express-upgrade`) and that the advisory and its Debian link are printed, using a fake `git`/`bash` sandbox in the style of `make_sandbox` in `tests/lib_test.sh`.
- Guards: refuses to run as root, and refuses without a TTY.
Run the suite with `bash config/hypr/scripts/tests/run-all.sh`.
### 7. Docs and changelog
- `docs/Plan-Dotfiles-Updater.md` — this plan.
- `docs/HOWTO-Upgrade-Dotfiles.md` and `docs/HOWTO-Upgrade-Dotfiles.es.md` — document the Waybar-driven path as the easy route and keep the manual steps.
- `CHANGELOG.md` — one `## Added:` entry under the top `## v2.3.29` heading, in the repo's bullet shape (`AGENTS.md:52-81`).
## Phase 2 — OS update and Debian Hyprland source update
### 8. OS update option
Add an opt-in step to the updater that updates the OS before the dots are copied, reusing the per-distro commands already in `config/hypr/scripts/Distro_update.sh`:
- Debian/Ubuntu: `sudo apt update && sudo apt upgrade -y`
- Arch: `paru -Syu` / `yay -Syu`
- Fedora: `sudo dnf update --refresh -y`
- openSUSE: `sudo zypper dup -y`
- Excluded: NixOS (declarative; the flow would fight the Nix store) and Gentoo (no installer repo, and portage upgrades are a different workflow).
It is prompted per run rather than automatic, and it runs in the same terminal with output tee'd to the log. Order matters: the OS update can replace Hyprland, so it runs before the Debian stack gate and before `copy.sh`.
### 9. Debian Hyprland stack gate
Runs after the OS update and only when Hyprland is source-built and `$TEMPDIR/Debian-Hyprland/hypr-tags.env` plus `update-hyprland.sh` exist. Source build is detected the same way `has_source_hyprland_artifacts` does it (`update-hyprland.sh:404`): `/usr/local/bin/Hyprland` or `/usr/local/bin/hyprland` exists, or `/usr/local/share/wayland-sessions/hyprland.desktop` exists. If the Debian packages are in use instead, print a note and skip.

Installed versions are read as follows:
- Resolve `HYPRLAND_INSTANCE_SIGNATURE` first when it is unset, by picking the directory under `${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/` that holds `.socket.sock` — the same resolution `WaybarStartup.sh:163-169` already does. Without it `hyprctl` refuses with `HYPRLAND_INSTANCE_SIGNATURE not set!`, which is what a bare SSH probe hits even while Hyprland is running.
- Hyprland and the core libraries, from the compositor itself: `hyprctl -j version` returns `version`, `tag`, `buildAquamarine`, `buildHyprlang`, `buildHyprutils`, `buildHyprcursor` and `buildHyprgraphics`, which is exactly the "built against" record the gate needs. Fallback when no session is running: `Hyprland --version` and its `Tag:` line, then `Version:` in `/usr/local/share/pkgconfig/hyprland.pc`.
- The remaining libraries from `Version:` in `/usr/local/lib/pkgconfig/<name>.pc` (`hyprtoolkit`, `hyprwire`) and `/usr/local/share/pkgconfig/<name>.pc` (`hyprland-protocols`, `wayland-protocols`).
- App binaries that do report a version: `hypridle`, `hyprlock`, `hyprpaper`, `hyprpicker`, `hyprsunset`, `hyprlauncher` via `--version`, and `hyprwayland-scanner`, which prints a bare version.
- Not probeable, reported as `unknown` and excluded from the decision: `hyprshutdown`, `hyprtavern`, `hyprsysteminfo`, `hyprpwcenter`, `hyprpolkitagent` (installed to `/usr/local/libexec`), `hyprland-guiutils`/`hyprland-dialog`, `hyprland-qt-support`, `hyprland-qtutils`. `hyprshutdown --version` and `hyprtavern --version` print an argument parse error and `hyprpwcenter --version` prints a toolkit debug line, so parsing must require a `[0-9]+.[0-9]+` match and reject any line containing `ERR`, `DEBUG` or `Failed parsing`.
- Branch-valued pins (`HYPRTOOLKIT_TAG=main`, `HYPRWIRE_TAG=main`, `HYPRTAVERN_TAG=auto`, `HYPRWIRE_PROTOCOLS_TAG=hyprtavern`) are not comparable: report them as `branch-tracked` and skip.

Comparison strips a leading `v` from both sides and uses `sort -V`, the same idiom as `KooLsDotsUpdate.sh:121`. Each module reports one of: `ok` (equal), `outdated` (pinned is higher), `newer` (installed is higher, so leave it alone because the pin is a validated set), `unknown`, `branch-tracked`.

If any module is `outdated`, print the full report and prompt: upgrade the Hyprland stack to the pinned versions now? On yes, run `( cd "$TEMPDIR/Debian-Hyprland" && ./update-hyprland.sh --install --no-fetch --source )`, which is the command used by hand today:
- `--install` builds and installs the stack, `--no-fetch` keeps the repo's pinned validated tags instead of pulling the newest upstream releases, and `--source` skips the interactive mode menu.
- Warn before running: it purges Debian hyprland packages and rebuilds the whole stack, and a build can fail. That is precisely why the repo pins a tested set, so the pin is preferred over upstream latest.
- If the user declines, continue to `copy.sh` and note the Hyprland `0.55` minimum the dots require.
## Support matrix
- Phase 1 works on Debian, Ubuntu, Arch, Fedora and openSUSE, since each of those has an installer with `update-deps.sh`.
- Phase 2's OS update covers the same five distros and excludes NixOS and Gentoo.
- Phase 2's Hyprland stack gate is Debian-only. It keys off the presence of `hypr-tags.env` and `update-hyprland.sh` in the cloned installer, so another installer can adopt it later without changes here.
- Anything unmatched: report unsupported and keep the existing notify-only behaviour.
## Rollout note
The Waybar module and every script involved are repo-managed files under `config/hypr/`, which `copy.sh` replaces during an upgrade. Existing installs therefore pick up the new flow on their next upgrade, and the first run still goes through the current manual path or the old notify-only dialog.
## Verification
- Phase 1, on the Debian trixie host (`dwilliams@192.168.40.48`): run `KooLsDotsUpgrade.sh --dry-run` and confirm the advisory and the Debian-Hyprland link print, the temp tree is created under `$HOME` with both repos as siblings, and the two commands are listed in order and not run.
- Phase 1 end-to-end on a disposable host or snapshot: trigger the dialog from Waybar, confirm the terminal opens, `update-deps.sh` and `copy.sh --tty --express-upgrade` run with prompts answerable, and the final cleanup prompt removes `$TEMPDIR` only on confirmation.
- Phase 2, on the same Debian host: resolve the instance signature and confirm `hyprctl -j version` reports `tag` `v0.56.2`, `buildAquamarine` `0.15.1`, `buildHyprlang` `0.6.8`, `buildHyprutils` `0.14.2`, `buildHyprcursor` `0.1.13` and `buildHyprgraphics` `0.5.1`, and that the report marks hyprland, aquamarine, hyprlang, hyprutils, hyprcursor and hyprgraphics `ok` against the current `main` pins, with `hyprtoolkit`/`hyprwire` as `branch-tracked` rather than a false mismatch. The stack there is already current, so the gate must not offer an upgrade.
- Phase 2, same host: with a temporarily edited copy of `hypr-tags.env` in the temp tree, confirm the gate flips to `outdated` and offers the `update-hyprland.sh --install --no-fetch --source` command without running it.
- Run the test suite through `tests/run-all.sh` after each phase.
## Open points
- Whether the Phase 1 advisory should be a confirmation gate or only a printed notice. The plan assumes a confirmation, so the user cannot start an upgrade with a stale OS by accident.
- The Phase 2 OS update command per distro: `Distro_update.sh` uses `apt upgrade`/`dnf update`/`zypper dup`/`paru -Syu`. Whether to match those exactly or offer `full-upgrade`/`dist-upgrade` on the apt side is still open.
- The Debian stack gate stays in Phase 2, so Phase 1 cannot help a user whose source-built Hyprland is behind the pins. The advisory and its link cover that case for now.
