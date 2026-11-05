# Wallpaper carousel

A Quickshell wallpaper picker: the wallpapers as a frameless fan of portrait
previews across the monitor, instead of a list of file names. The card in the
middle is the focused one; it is what `Enter` applies. A search bar floats under
the deck, wider than a card, so a long collection can be typed down to a name.

```
        ┌──┐┌────┐┌─────┐┌───────┐┌─────┐┌────┐┌──┐
        │  ││    ││     ││       ││     ││    ││  │
        └──┘└────┘└─────┘└───────┘└─────┘└────┘└──┘
   ┌───────────────────────────────────────────────────┐
   │ Filter wallpapers…                                │
   └───────────────────────────────────────────────────┘
                      sundown_mountain.jpg
```

Nothing is drawn behind the deck: the window is transparent, so the wallpaper
stays visible around the cards and the deck reads as floating. The cards shrink
from the middle towards both edges, which is what gives the fan its curve.

## Requirements

- `quickshell` (0.3 or newer)
- `awww` or `swww`, as everywhere else in the dots
- `wallust` for the theming that follows the wallpaper
- A Nerd Font (`JetBrainsMono Nerd Font`, the dots default)

## Usage

`copy.sh` installs this directory as `~/.config/quickshell/wallpaper`, beside
the other quickshell applets. `SUPER W` opens it; where Quickshell is not
installed the same bind still opens the rofi wallpaper menu, so no distro loses
the key.

```bash
~/.config/hypr/scripts/QsWallpaper.sh select    # carousel, or rofi
~/.config/hypr/scripts/QsWallpaper.sh toggle    # show or hide the carousel
~/.config/hypr/scripts/QsWallpaper.sh open
~/.config/hypr/scripts/QsWallpaper.sh close
```

Run it straight from a checkout, without installing - the applet finds
`QsWallpaper.sh` beside the checkout's `config/hypr/scripts`:

```bash
quickshell -p ~/Hyprland-Dots/config/quickshell/wallpaper
```

`SUPER SHIFT W` (effects) and `CTRL ALT W` (random) are unchanged, and the
carousel is on the IPC target `wallpaper-carousel` if you want to drive it from
a keybind of your own.

The carousel is also in Quick Settings under **Misc → Wallpaper Carousel**, on
the same `QsWallpaper.sh select` path as `SUPER W`, so both entry points behave
identically (and both fall back to rofi where Quickshell is missing).

```lua
bind("SUPER ALT", "W", exec_cmd("$HOME/.config/hypr/scripts/QsWallpaper.sh toggle"),
  { description = "wallpaper carousel" })
```

## Controls

The deck is keyboard and mouse driven, and a search bar floats under it - wider
than a card, so a long file name stays readable. Typing filters the deck in
place, and it re-centres on the wallpaper that is on screen. The arrows and
`Home`/`End` belong to the caret, so the deck is stepped with `Tab`, the wheel
or a click.

| Input | Action |
| --- | --- |
| **Type** | filter by folder and file name |
| **Tab / Shift+Tab** | step one wallpaper |
| **Enter** | apply the centred wallpaper |
| **Click a card** | apply it |
| **Mouse wheel** | step one wallpaper per notch |
| **Esc** | clear the filter, or close when it is empty |
| **Click the empty strip** | close |

A query can also be passed in, which opens the deck narrowed with the bar
already filled. The whole string is matched against folder and file names, and
every word has to appear:

```bash
~/.config/hypr/scripts/QsWallpaper.sh open --query aurora
~/.config/hypr/scripts/QsWallpaper.sh open --query "dark 4k"
```

or over IPC directly:

```bash
quickshell ipc -p ~/.config/quickshell/wallpaper \
    call wallpaper-carousel openWith aurora
```

The query is cleared when the deck closes, so the next `SUPER W` shows every
wallpaper again. `select --query TEXT` does the same from the keybind path, and
the rofi fallback ignores it.

Applying fades the deck out and closes the strip; the wallpaper is set without
a transition, so it is already in place.

## Theming

The carousel follows wallust, so it matches the bar, the rofi menus and the
other panels:

1. `~/.config/hypr/waybar/wallust/colors-waybar.css` - the full palette.
   `color12` becomes the accent (the slot the dots' Wallust styles use), and the
   brightest of `color7`/`color15`/`cursor` becomes the card border and label
   colour.
2. `~/.config/quickshell/qml_color.json` - used when the Waybar palette is
   absent.
3. Built-in dark defaults.

Borders, the focused-card outline and the label are mixed from the palette
background and text colour, so the deck stays readable over any wallpaper. Both
files are watched; changing the wallpaper repaints the deck in place.

This is a rework of the [ML4W WallpaperApp](https://github.com/mylinuxforwork/dotfiles/tree/main/dotfiles/.config/quickshell/WallpaperApp)
carousel. The deck maths are theirs; the framing is frameless rather than a
full-screen layer with a backdrop, the theming is this project's loader instead
of ML4W's `qs.CustomTheme`, and the wallpaper list and the apply call go through
`QsWallpaper.sh` rather than ML4W's `~/.config/ml4w` scripts and settings files.

## How it works

`QsWallpaper.sh` is the only thing that reads the wallpaper folder or changes
the wallpaper:

- `list` prints every still image under the wallpaper folder, recursively,
  sorted, one absolute path per line. `Wallpapers.qml` turns that into the
  deck.
- `folder` prints the folder it resolved, so an empty deck can name it.
- `current` prints the wallpaper on the focused monitor, read from the
  per-monitor link the script writes when it applies one, so the deck opens
  centred on what you are looking at.
- `apply PATH` sets the wallpaper on the focused monitor through `WallpaperCmd.sh`
  (which owns the daemon start and the resize mode), keeps the per-monitor
  link and copies the other wallpaper scripts expect, then runs
  `WallustSwww.sh` and `Refresh.sh` so the whole desktop follows.
- `select` opens the carousel where it can run, and otherwise `exec`s
  `WallpaperSelect.sh`.

The folder is `$(xdg-user-dir PICTURES)/wallpapers`, the one
`WallpaperSelect.sh` reads, with `Wallpapers/` (capitalised) accepted when the
lowercase folder is absent. Symlinked wallpapers and a symlinked wallpaper
folder are followed, so a Nix store or second-drive collection lists normally.
`KOOLDOTS_WALLPAPER_DIR` points the carousel at a different folder without
editing anything, and `QsWallpaper.sh folder` prints the folder it resolved.

Videos, GIFs and the ImageMagick effects are not in the carousel: they need
`mpvpaper` or a still preview, and `WallpaperSelect.sh` already handles them.
`SUPER W` reaches the carousel first where Quickshell exists, so use
`WallpaperSelect.sh` directly (or `SUPER SHIFT W` for effects) for a video
wallpaper.

Files:

| File | Purpose |
| --- | --- |
| `shell.qml` | entry point, IPC handler, wallust palette loading |
| `Carousel.qml` | the layer-shell strip, deck, keys and apply fade |
| `Wallpapers.qml` | the list, the current wallpaper and the apply call |
| `Theme.qml` | wallust palette parsing and colour roles |

The strip stays mapped at 1x1 while hidden: quickshell exits when its last
window is closed, so keeping the surface alive is what makes reopening instant.

## Troubleshooting

Run it in a terminal to see QML errors:

```bash
quickshell -p ~/.config/quickshell/wallpaper
```

Check what the deck receives:

```bash
~/.config/hypr/scripts/QsWallpaper.sh folder
~/.config/hypr/scripts/QsWallpaper.sh list
~/.config/hypr/scripts/QsWallpaper.sh current
```

The empty deck names the folder it looked in, so a wrong folder is visible at a
glance. If that folder has no still images:

```bash
ls "$(xdg-user-dir PICTURES)/wallpapers"
```

Only `.jpg`, `.jpeg`, `.png` and `.webp` are listed; a folder of videos opens
empty on purpose.

If the deck does not follow the wallpaper, check that the palette exists:

```bash
grep background ~/.config/hypr/waybar/wallust/colors-waybar.css
```
