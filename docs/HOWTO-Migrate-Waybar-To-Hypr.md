# How to migrate Waybar and its Wallust colors to the new path

Waybar moved from `~/.config/waybar` to `~/.config/hypr/waybar`. Everything that
imports the Wallust palette that Waybar generates had to be updated with it.
`swaync` is the one that most often gets missed, because its `style.css` is a
user-owned file that is never overwritten on upgrade.

## What changed

- Waybar is now `~/.config/hypr/waybar` (`configs/`, `style/`, `Modules`,
  `wallust/`). The old `~/.config/waybar` no longer exists.
- The Wallust palette target is unchanged in content but lives at
  `~/.config/hypr/waybar/wallust/colors-waybar.css` (see the `waybar.target`
  entry in `~/.config/hypr/wallust/wallust.toml`).
- Any file that pulls those colors in with a **relative** `@import` must point
  at the new location.

## The two things that break

1. **Wrong relative depth.** GTK resolves a relative `@import` against the
   directory of the importing file, and every consumer sits at a different
   depth. A single find-and-replace across the repo therefore cannot be
   correct - each file needs its own number of `../`:

   | File (installed path) | Correct import |
   | --- | --- |
   | `~/.config/swaync/style.css` | `../../.config/hypr/waybar/wallust/colors-waybar.css` |
   | `~/.config/wlogout/style.css` | `../../.config/hypr/waybar/wallust/colors-waybar.css` |
   | `~/.config/ags/user/style.css` | `../../../.config/hypr/waybar/wallust/colors-waybar.css` |
   | `~/.config/hypr/waybar/style.css` (symlink into `style/`) | `../../../.config/hypr/waybar/wallust/colors-waybar.css` |

   The Waybar styles are written for the last row on purpose: at runtime they
   are always loaded through the `~/.config/hypr/waybar/style.css` symlink, so
   three levels up is `$HOME`.

2. **Missing semicolon.** An `@import` line must end in `;`. Without it GTK
   logs a CSS parse error and ignores the import, so the palette silently never
   applies.

## Symptom

The swaync control center and notifications render with their built-in default
colors instead of the wallpaper palette, while Waybar itself looks correct.
Logs may show a GTK CSS parse/`@import` error. The usual culprit is a stale
line such as:

```css
@import '../../.config/waybar/wallust/colors-waybar.css';
```

That path does not exist any more, so `colors-waybar.css` is never loaded.

## Automatic migration

Run the normal upgrade and reboot:

```sh
cd ~/Hyprland-Dots
git stash && git pull
./copy.sh --express-upgrade
reboot
```

or from the menu: `copy.sh` and pick `Express update`, followed by `reboot`.

Two things happen for you:

- `copy.sh` installs Waybar at the new path, restores your layout/style
  selection, and auto-repairs any remaining `$HOME/.config/waybar/...`
  references found in the installed Waybar directory.
- `patches/30-swaync-wallust-import.sh` rewrites the Wallust `@import` in
  `~/.config/swaync/style.css` to the canonical path (and adds the missing `;`).
  Patches run on install, upgrade, express upgrade, and from the menu's update
  action, so this also reaches installs that get updated in place.

## Manual migration

Use this for NixOS/Home Manager installs, hand-managed copies of the configs, or
when you just want to verify an upgrade did the right thing.

1. Confirm the move happened:

   ```sh
   ls -ld ~/.config/hypr/waybar ~/.config/waybar 2>&1
   ls -l ~/.config/hypr/waybar/style.css
   ```

   `~/.config/waybar` should be gone (it is migrated and removed), and
   `~/.config/hypr/waybar/style.css` should be a symlink into
   `~/.config/hypr/waybar/style/`.

2. Check what swaync imports:

   ```sh
   grep -n '@import' ~/.config/swaync/style.css
   ```

   The Wallust line should read exactly:

   ```css
   @import '../../.config/hypr/waybar/wallust/colors-waybar.css';
   ```

3. Fix it in place if it still points at the old location (back up first):

   ```sh
   cp -a ~/.config/swaync/style.css ~/.config/swaync/style.css.bak
   sed -i -E "s#(@import[[:space:]]*['\"])[^'\"]*waybar/wallust/colors-waybar\.css(['\"])#\1../../.config/hypr/waybar/wallust/colors-waybar.css\2#" \
     ~/.config/swaync/style.css
   sed -i -E "s#(@import[[:space:]]*['\"][^'\"]*waybar/wallust/colors-waybar\.css['\"]);?#\1;#" \
     ~/.config/swaync/style.css
   grep -n 'colors-waybar' ~/.config/swaync/style.css
   ```

4. Make sure the palette actually exists - it is generated, not shipped:

   ```sh
   ls -l ~/.config/hypr/waybar/wallust/colors-waybar.css
   ```

   If it is missing, regenerate it from the current wallpaper:

   ```sh
   ~/.config/hypr/scripts/WallustSwww.sh
   ```

5. Reload swaync (same reload the repo uses in `Refresh.sh`):

   ```sh
   swaync-client -R -rs --skip-wait
   ```

   On a systemd-managed swaync, `systemctl --user restart swaync.service` also
   works.

6. Apply the same checks to the other consumers only if you hand-edited them -
   `copy.sh` refreshes `wlogout` and the Waybar styles for you. Use the table
   above for the correct number of `../` per file.

## Related

- `docs/HOWTO-Upgrade-Dotfiles.md` - the standard upgrade flow.
- `docs/Patching-UserConfigs.md` - how the patch mechanism works and how to add
  a patch.
