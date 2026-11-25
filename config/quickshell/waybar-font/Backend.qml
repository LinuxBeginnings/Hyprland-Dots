// Backend bridge between Quickshell QML and WaybarFont.sh

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: backend

    readonly property string configHome: {
        var xdg = Quickshell.env("XDG_CONFIG_HOME");
        if (xdg) return xdg;
        var home = Quickshell.env("HOME");
        return (home ? home : "") + "/.config";
    }

    readonly property string script: configHome + "/hypr/scripts/WaybarFont.sh"

    property string currentFont: "JetBrainsMono Nerd Font"
    property int currentSize: 14
    property string defaultFont: "JetBrainsMono Nerd Font"
    property int defaultSize: 14
    property bool overrideActive: false

    property var allFonts: []
    property bool fontsLoaded: false
    property bool busy: false
    property string statusMessage: ""
    property string statusType: "normal" // "normal", "success", "error"

    function refresh() {
        getStatusProcess.running = true;
    }

    function loadFonts() {
        listFontsProcess.running = true;
    }

    function apply(font, size) {
        backend.busy = true;
        backend.statusMessage = "Applying changes & restarting Waybar...";
        backend.statusType = "normal";
        applyProcess.command = [backend.script, "apply", font, String(size)];
        applyProcess.running = true;
    }

    function restore() {
        backend.busy = true;
        backend.statusMessage = "Restoring default font and size...";
        backend.statusType = "normal";
        restoreProcess.command = [backend.script, "restore"];
        restoreProcess.running = true;
    }

    // Process to get active status
    Process {
        id: getStatusProcess
        command: [backend.script, "get"]
        stdout: StdioCollector {
            id: statusOutput
            onStreamFinished: {
                try {
                    var data = JSON.parse(statusOutput.text);
                    if (data.font) backend.currentFont = data.font;
                    if (data.size) backend.currentSize = parseInt(data.size, 10) || 14;
                    if (data.default_font) backend.defaultFont = data.default_font;
                    if (data.default_size) backend.defaultSize = parseInt(data.default_size, 10) || 14;
                    backend.overrideActive = !!data.override_active;
                } catch (e) {
                    // Fallback to defaults
                }
            }
        }
    }

    // Process to list installed fonts
    Process {
        id: listFontsProcess
        command: [backend.script, "list-fonts"]
        stdout: StdioCollector {
            id: fontsOutput
            onStreamFinished: {
                var lines = fontsOutput.text.split("\n");
                var list = [];
                for (var i = 0; i < lines.length; i++) {
                    var name = lines[i].trim();
                    if (name.length > 0 && list.indexOf(name) === -1) {
                        list.push(name);
                    }
                }
                backend.allFonts = list;
                backend.fontsLoaded = true;
            }
        }
    }

    // Process to apply font & size
    Process {
        id: applyProcess
        onExited: function(code, status) {
            backend.busy = false;
            if (code === 0) {
                backend.statusMessage = "Waybar restarted with new font settings!";
                backend.statusType = "success";
                backend.refresh();
            } else {
                backend.statusMessage = "Failed to apply font settings.";
                backend.statusType = "error";
            }
        }
    }

    // Process to restore defaults
    Process {
        id: restoreProcess
        onExited: function(code, status) {
            backend.busy = false;
            if (code === 0) {
                backend.statusMessage = "Default Waybar font and size restored!";
                backend.statusType = "success";
                backend.refresh();
            } else {
                backend.statusMessage = "Failed to restore defaults.";
                backend.statusType = "error";
            }
        }
    }

    Component.onCompleted: {
        backend.refresh();
        backend.loadFonts();
    }
}
