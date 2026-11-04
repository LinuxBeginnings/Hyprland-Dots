// Wallpaper carousel: pick the wallpaper from a row of previews instead of a
// list of names.
//
// Start:   quickshell -p ~/.config/quickshell/wallpaper
// Toggle:  ~/.config/hypr/scripts/QsWallpaper.sh toggle      (SUPER W)
//
// IPC (used by the toggle script, and available to anything else):
//   quickshell ipc -p ~/.config/quickshell/wallpaper \
//       call wallpaper-carousel toggle|open|close|isOpen|refresh
//
// The carousel starts hidden and collapses to a single pixel, so the shell
// stays resident between toggles and opening it costs nothing. QsWallpaper.sh
// starts the shell on the first toggle and opens the panel.

import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: shell

    Theme {
        id: theme
    }

    Wallpapers {
        id: wallpapers
    }

    // Wallust output: the Waybar palette has the full theme, the quickshell
    // roles file is the fallback. Both are watched so a theme change repaints
    // the carousel in place.
    // FileView exposes the contents through text(), not a text property.
    FileView {
        id: paletteColors

        path: theme.paletteFile
        watchChanges: true
        onTextChanged: theme.applyPaletteCss(paletteColors.text())
    }

    FileView {
        id: roleColors

        path: theme.jsonFile
        watchChanges: true
        onTextChanged: theme.applyJson(roleColors.text())
    }

    Carousel {
        id: carousel

        theme: theme
        wallpapers: wallpapers
    }

    IpcHandler {
        target: "wallpaper-carousel"

        function toggle(): void {
            carousel.toggle();
        }

        function open(): void {
            carousel.open();
        }

        // Opens the deck already filtered, for a caller that knows what it is
        // looking for: QsWallpaper.sh open --query TEXT.
        function openWith(query: string): void {
            carousel.open(query);
        }

        function close(): void {
            carousel.close();
        }

        function isOpen(): string {
            return carousel.shown ? "1" : "0";
        }

        function refresh(): void {
            wallpapers.refresh();
        }
    }
}
