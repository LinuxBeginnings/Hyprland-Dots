pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

/**
 * Loads the palette wallust generates for Quickshell into Appearance.m3colors.
 *
 * qml_color.json is one of wallust's template targets, so the panel follows
 * the wallpaper like the rest of the dots. The file is watched, so a wallpaper
 * change repaints without a restart.
 *
 * Deliberately dependency-free. Each applet is its own quickshell shell root
 * (`-p <applet dir>`) and carries only the files it needs, so this resolves the
 * config directory from the environment rather than through a shared
 * Directories singleton, and needs nothing from the shared modules tree.
 *
 * Call reapplyTheme() on startup: singletons are lazily loaded, so the first
 * read can happen before the file is there.
 */
Singleton {
    id: root

    readonly property string configHome: {
        var xdg = Quickshell.env("XDG_CONFIG_HOME");
        if (xdg) return xdg;
        var home = Quickshell.env("HOME");
        return (home ? home : "") + "/.config";
    }

    readonly property string filePath: configHome + "/quickshell/qml_color.json"

    function reapplyTheme() {
        themeFileView.reload();
        if (themeFileView.text()) root.applyColors(themeFileView.text());
    }

    Component.onCompleted: {
        if (themeFileView.text()) root.applyColors(themeFileView.text());
    }

    function applyColors(fileContent) {
        var json = null;
        try {
            json = JSON.parse(fileContent);
        } catch (error) {
            return;
        }
        if (!json) return;

        if (json.windowBackground) {
            Appearance.m3colors.m3windowBackground = json.windowBackground;
            var bgCol = Qt.color(json.windowBackground);
            Appearance.m3colors.darkmode = (bgCol.hslLightness < 0.5);
        }

        for (var key in json) {
            if (!json.hasOwnProperty(key)) continue;
            if (key === "windowBackground") continue;
            // Ignore layerBackground overrides from legacy json if they clash with dark mode
            if (key.indexOf("layerBackground") === 0) {
                var testCol = Qt.color(json[key]);
                if (Appearance.m3colors.darkmode && testCol.hslLightness > 0.4) {
                    continue;
                }
            }
            // qml_color.json is snake_case; the roles are camelCase.
            var camel = key.replace(/_([a-z])/g, function (group) {
                return group[1].toUpperCase();
            });
            Appearance.m3colors["m3" + camel] = json[key];
        }
    }

    Timer {
        id: delayedFileRead
        interval: 100
        repeat: false
        running: false
        onTriggered: root.applyColors(themeFileView.text())
    }

    FileView {
        id: themeFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: {
            this.reload();
            delayedFileRead.start();
        }
        onLoadedChanged: root.applyColors(themeFileView.text())
    }
}
