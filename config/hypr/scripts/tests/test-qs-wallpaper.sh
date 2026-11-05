#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   The wallpaper carousel (config/quickshell/wallpaper) reaches the desktop
#   only through QsWallpaper.sh, so that script is what these checks cover:
#   what it lists, what it applies, and which menu the bind opens.
#
#   A wallpaper collection is often a folder of symlinks (a Nix store path, a
#   second drive), and the folder itself is sometimes capitalised, so both are
#   fixtures here rather than assumptions.
#
#   The QML is checked with qmllint where it is installed, plus the things that
#   would silently undo the port: a theme loader this project does not ship, a
#   panel drawn behind the deck, and a search bar that is not the deck's filter.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
WIDGET="$ROOT/config/quickshell/wallpaper"
SCRIPT="$SCRIPT_DIR/QsWallpaper.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export XDG_CONFIG_HOME="$WORK/config"
export CALL_LOG="$WORK/calls.log"
# fit skips the monitor/image probing, so the apply assertion does not depend on
# ImageMagick being installed.
export WALLPAPER_RESIZE_MODE=fit
: >"$CALL_LOG"

WALLS="$WORK/wallpapers"
mkdir -p "$WALLS/dark" "$WALLS/light" "$WORK/external" "$WORK/pictures/wallpapers" \
  "$WORK/pictures/Wallpapers" "$XDG_CONFIG_HOME/hypr/scripts" "$WORK/bin" "$WORK/bin-noqs"

# Fixture wallpapers, plus the files the carousel must not offer.
: >"$WALLS/aurora.png"
: >"$WALLS/dark/forest.jpg"
: >"$WALLS/light/snow.jpeg"
: >"$WALLS/dark/notes.txt"
: >"$WALLS/dark/clip.mp4"
# A symlinked wallpaper, because that is how a Nix store or second drive
# collection looks on disk.
: >"$WORK/external/star.jpg"
ln -s "$WORK/external/star.jpg" "$WALLS/star-link.jpg"
# And a symlinked folder, for a collection kept somewhere else entirely.
ln -s "$WALLS" "$WORK/walls-link"

# The folder resolution fixtures: lowercase wins, capitalised is the fallback.
: >"$WORK/pictures/wallpapers/low.png"
: >"$WORK/pictures/Wallpapers/cap.png"

# The script resolves its helpers from the config home, so the sandbox carries
# the real daemon/resize helpers and logging stubs for the ones that change the
# theme.
cp "$SCRIPT_DIR/WallpaperCmd.sh" "$XDG_CONFIG_HOME/hypr/scripts/"
cat >"$XDG_CONFIG_HOME/hypr/scripts/WallustSwww.sh" <<'EOS'
#!/usr/bin/env bash
printf 'wallust %s\n' "$*" >>"$CALL_LOG"
EOS
cat >"$XDG_CONFIG_HOME/hypr/scripts/Refresh.sh" <<'EOS'
#!/usr/bin/env bash
printf 'refresh\n' >>"$CALL_LOG"
EOS
cat >"$XDG_CONFIG_HOME/hypr/scripts/WallpaperSelect.sh" <<'EOS'
#!/usr/bin/env bash
printf 'rofi-select\n' >>"$CALL_LOG"
EOS
chmod +x "$XDG_CONFIG_HOME/hypr/scripts/"*.sh

# The applet has to be where the script looks for it. Linked, not copied, so
# these checks see the real files.
mkdir -p "$XDG_CONFIG_HOME/quickshell"
ln -s "$WIDGET" "$XDG_CONFIG_HOME/quickshell/wallpaper"

cat >"$WORK/bin/hyprctl" <<'EOS'
#!/usr/bin/env bash
printf 'hyprctl %s\n' "$*" >>"$CALL_LOG"
case "${1:-}" in
  -j)
    cat <<'JSON'
[{"name":"DP-1","focused":true,"width":1920,"height":1080,"scale":1.0},
 {"name":"HDMI-A-1","focused":false,"width":2560,"height":1440,"scale":1.0}]
JSON
    ;;
  *)
    cat <<'TXT'
Monitor DP-1 (DP-1): 1920x1080@60 at 0x0, focused: yes
Monitor HDMI-A-1 (HDMI-A-1): 2560x1440@60 at 1920x0, focused: no
TXT
    ;;
esac
EOS

# awww is reported as installed, so WallpaperCmd.sh picks it and the apply call
# is observable. `query` succeeding is what "the daemon is up" means here.
cat >"$WORK/bin/awww" <<'EOS'
#!/usr/bin/env bash
printf 'awww %s\n' "$*" >>"$CALL_LOG"
exit 0
EOS
cat >"$WORK/bin/awww-daemon" <<'EOS'
#!/usr/bin/env bash
printf 'awww-daemon %s\n' "$*" >>"$CALL_LOG"
exit 0
EOS
cat >"$WORK/bin/quickshell" <<'EOS'
#!/usr/bin/env bash
printf 'quickshell %s\n' "$*" >>"$CALL_LOG"
[ "${FAKE_QS:-0}" = "1" ] && exit 0
exit 1
EOS
cat >"$WORK/bin/xdg-user-dir" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "${FAKE_PICTURES:-$HOME/Pictures}"
EOS
chmod +x "$WORK/bin"/*

# The same sandbox without a quickshell binary, for the rofi fallback.
for fake in "$WORK/bin"/*; do
  name="$(basename "$fake")"
  [ "$name" = quickshell ] && continue
  ln -s "$fake" "$WORK/bin-noqs/$name"
done

export PATH="$WORK/bin:$PATH"
export FAKE_PICTURES="$WORK/pictures"
export KOOLDOTS_WALLPAPER_DIR="$WALLS"
export FAKE_QS=0

# ------------------------------------------------------------------- list --

it "list prints every still image, recursively, sorted"
expected="$WALLS/aurora.png
$WALLS/dark/forest.jpg
$WALLS/light/snow.jpeg
$WALLS/star-link.jpg"
actual="$(bash "$SCRIPT" list)"
assert_eq "listed wallpapers" "$expected" "$actual"

it "list leaves out files that are not still images"
listed="$(bash "$SCRIPT" list)"
if [[ $listed == *".txt"* || $listed == *".mp4"* ]]; then
  fail "a video or a note was listed: $listed"
else
  pass_msg
fi

it "list follows a symlinked wallpaper"
if KOOLDOTS_WALLPAPER_DIR="$WALLS" bash "$SCRIPT" list | grep -qxF "$WALLS/star-link.jpg"; then
  pass_msg
else
  fail "a symlinked wallpaper was skipped"
fi

it "list follows a symlinked wallpaper folder"
count="$(KOOLDOTS_WALLPAPER_DIR="$WORK/walls-link" bash "$SCRIPT" list | grep -c . || true)"
assert_eq "wallpapers through the folder symlink" "4" "$count"

it "a missing wallpaper folder lists nothing and still succeeds"
out="$(KOOLDOTS_WALLPAPER_DIR="$WORK/none" bash "$SCRIPT" list)"
status=$?
if [[ -z $out && $status -eq 0 ]]; then
  pass_msg
else
  fail "expected no output and status 0, got '$out' and $status"
fi

it "the folder is the lowercase one when both exist"
actual="$(env -u KOOLDOTS_WALLPAPER_DIR bash "$SCRIPT" folder)"
assert_eq "resolved folder" "$WORK/pictures/wallpapers" "$actual"

it "a capitalised Wallpapers folder is used when the lowercase one is absent"
rm -rf "$WORK/pictures/wallpapers"
actual="$(env -u KOOLDOTS_WALLPAPER_DIR bash "$SCRIPT" list)"
expected="$WORK/pictures/Wallpapers/cap.png"
assert_eq "wallpapers from the capitalised folder" "$expected" "$actual"

# ------------------------------------------------------------------ apply --

target="$WALLS/dark/forest.jpg"
: >"$CALL_LOG"

it "apply sets the wallpaper on the focused monitor without a transition"
out="$(bash "$SCRIPT" apply "$target")"
status=$?
if [[ $status -ne 0 ]]; then
  fail "apply exited $status"
elif [[ $out != "$target" ]]; then
  fail "apply printed '$out'"
elif grep -qF "awww img -o DP-1 --resize fit --transition-type none $target" "$CALL_LOG"; then
  pass_msg
else
  fail "unexpected awww call: $(grep 'awww img' "$CALL_LOG" || true)"
fi

it "apply keeps the per-monitor link and the base copy"
if [[ "$(readlink -f "$XDG_CONFIG_HOME/hypr/rofi/.current_wallpaper_DP-1")" == "$target" ]] &&
  [ -f "$XDG_CONFIG_HOME/hypr/wallpaper_effects/.wallpaper_base" ]; then
  pass_msg
else
  fail "the per-monitor link or the base copy is missing"
fi

it "apply runs wallust and the refresh for the new wallpaper"
if grep -qF "wallust $target" "$CALL_LOG" && grep -qxF 'refresh' "$CALL_LOG"; then
  pass_msg
else
  fail "wallust or the refresh was not run: $(tr '\n' ' ' <"$CALL_LOG")"
fi

it "apply --no-theming leaves the theme alone"
: >"$CALL_LOG"
bash "$SCRIPT" apply "$WALLS/light/snow.jpeg" --no-theming >/dev/null 2>&1
if grep -q '^wallust ' "$CALL_LOG"; then
  fail "wallust ran with --no-theming"
else
  pass_msg
fi

it "apply --monitor targets the named output"
: >"$CALL_LOG"
bash "$SCRIPT" apply "$WALLS/aurora.png" --monitor HDMI-A-1 >/dev/null 2>&1
if grep -qF 'awww img -o HDMI-A-1 ' "$CALL_LOG"; then
  pass_msg
else
  fail "the named output was not used: $(grep 'awww img' "$CALL_LOG" || true)"
fi

it "apply refuses a wallpaper that does not exist"
: >"$CALL_LOG"
if bash "$SCRIPT" apply "$WORK/missing.png" >/dev/null 2>&1; then
  fail "a missing path was reported as applied"
elif grep -q 'awww img' "$CALL_LOG"; then
  fail "the daemon was called for a missing path"
else
  pass_msg
fi

it "current prints the wallpaper of the focused monitor"
bash "$SCRIPT" apply "$target" >/dev/null 2>&1
actual="$(bash "$SCRIPT" current)"
assert_eq "current wallpaper" "$target" "$actual"

# ----------------------------------------------------------------- select --

: >"$CALL_LOG"
it "select falls back to the rofi menu when quickshell is missing"
PATH="$WORK/bin-noqs:$PATH" bash "$SCRIPT" select >/dev/null 2>&1
status=$?
if [[ $status -eq 0 ]] && grep -qxF 'rofi-select' "$CALL_LOG"; then
  pass_msg
else
  fail "the rofi menu was not started (status $status)"
fi

: >"$CALL_LOG"
it "select drives the carousel when quickshell is present"
FAKE_QS=1 bash "$SCRIPT" select >/dev/null 2>&1
if grep -qF 'call wallpaper-carousel toggle' "$CALL_LOG" &&
  ! grep -qxF 'rofi-select' "$CALL_LOG"; then
  pass_msg
else
  fail "the carousel was not driven: $(tr '\n' ' ' <"$CALL_LOG")"
fi

it "an unknown subcommand is a usage error"
bash "$SCRIPT" nonsense >/dev/null 2>&1
status=$?
assert_status 2 "$status" "usage"

# -------------------------------------------------------------------- qml --

if command -v qmllint >/dev/null 2>&1; then
  it "the applet's QML parses"
  if qmllint "$WIDGET"/*.qml >"$WORK/qmllint.log" 2>&1; then
    pass_msg
  else
    fail "$(head -n 3 "$WORK/qmllint.log" | tr '\n' ' ')"
  fi
else
  it "the applet's QML parses"
  printf 'skip: qmllint is not installed\n'
  pass_msg
fi

it "the applet uses this project's theme loader"
if grep -q 'qs\.CustomTheme' "$WIDGET"/*.qml; then
  fail "the upstream qs.CustomTheme module is still imported"
elif grep -qF 'colors-waybar.css' "$WIDGET/Theme.qml"; then
  pass_msg
else
  fail "Theme.qml does not read the wallust palette"
fi

it "the deck is frameless: no panel is drawn behind the cards"
if grep -qF 'id: panel' "$WIDGET/Carousel.qml"; then
  fail "a panel surface is drawn behind the deck"
elif grep -qF 'color: "transparent"' "$WIDGET/Carousel.qml"; then
  pass_msg
else
  fail "the window is not transparent"
fi

it "the deck is a fan of portrait cards"
if grep -qF 'cardWidth: Math.round(cardHeight * cardAspect)' "$WIDGET/Carousel.qml" &&
  grep -qF 'readonly property real cardAspect: 0.4' "$WIDGET/Carousel.qml" &&
  grep -qF 'stripHeight: Math.round(cardHeight + 100)' "$WIDGET/Carousel.qml"; then
  pass_msg
else
  fail "the cards are not the portrait deck shape"
fi

it "the deck has a search bar wired to its filter"
if grep -qF 'readonly property int searchBarWidth: Math.min(width - 60, 640)' "$WIDGET/Carousel.qml" &&
  grep -qF 'onTextChanged: carousel.wallpapers.query = text' "$WIDGET/Carousel.qml" &&
  grep -qF 'Keys.onEscapePressed: carousel.handleEscape()' "$WIDGET/Carousel.qml"; then
  pass_msg
else
  fail "the search bar is missing or does not drive wallpapers.query"
fi

it "the strip is sized to the deck, not the screen"
if grep -qF 'implicitHeight: carousel.shown ? carousel.stripHeight : 1' "$WIDGET/Carousel.qml" &&
  grep -qF 'anchors.right: carousel.shown' "$WIDGET/Carousel.qml"; then
  pass_msg
else
  fail "the strip is not sized to the deck"
fi

it "the deck can be opened already filtered"
if grep -qF 'function openWith(query: string)' "$WIDGET/shell.qml" &&
  grep -qF 'wallpapers.query = typeof query === "string" ? query : ""' "$WIDGET/Carousel.qml" &&
  grep -qF 'readonly property var filtered' "$WIDGET/Wallpapers.qml"; then
  pass_msg
else
  fail "the IPC filter path is missing"
fi

: >"$CALL_LOG"
it "open --query passes the filter to the deck"
FAKE_QS=1 bash "$SCRIPT" open --query aurora >/dev/null 2>&1
if grep -qF 'call wallpaper-carousel openWith aurora' "$CALL_LOG"; then
  pass_msg
else
  fail "the query did not reach the IPC call: $(tr '\n' ' ' <"$CALL_LOG")"
fi

it "Quick Settings reaches the same deck"
if grep -qF '"Wallpaper Carousel") "$scriptsDir/QsWallpaper.sh select"' \
  "$ROOT/config/hypr/scripts/Kool_Quick_Settings.sh"; then
  pass_msg
else
  fail "no Quick Settings entry for the carousel"
fi

it "SUPER W opens the carousel through the script"
if grep -qF 'QsWallpaper.sh select' "$ROOT/config/hypr/configs/system_keybinds.lua"; then
  pass_msg
else
  fail "the wallpaper bind does not point at QsWallpaper.sh"
fi

summary "test-qs-wallpaper"
