// Backend communication bridge between Control Center QML and KoolSettingsEngine.sh

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

    readonly property string script: configHome + "/hypr/scripts/KoolSettingsEngine.sh"

    property var systemInfo: ({
        "dots_version": "v3.0.0",
        "hyprland_version": "v0.57.x",
        "distro": "Linux",
        "kernel": "Unknown"
    })

    property var keybinds: []
    property var windowRules: []
    property var startupApps: []
    property var toggles: ({
        "weather_units": "metric",
        "wobble_enabled": false
    })

    property bool busy: false
    property string statusMessage: ""
    property string statusType: "normal" // "normal", "success", "error"
    property bool hasError: false
    property string lastErrorMessage: ""
    property string lastErrorTarget: ""

    function refreshAll() {
        fetchInfoProcess.running = true;
        fetchKeybindsProcess.running = true;
        fetchRulesProcess.running = true;
        fetchStartupProcess.running = true;
        fetchTogglesProcess.running = true;
    }

    function applyKeybind(mods, key, actionType, actionVal, desc, origMods, origKey) {
        backend.busy = true;
        backend.statusMessage = "Validating and applying keybinding...";
        backend.statusType = "normal";
        applyKeybindProcess.command = [
            backend.script, "apply-keybind",
            mods, key, actionType, actionVal, desc,
            origMods || "", origKey || ""
        ];
        applyKeybindProcess.running = true;
    }

    function applyRule(name, matchObj, actionsObj) {
        backend.busy = true;
        backend.statusMessage = "Validating and applying window rule...";
        backend.statusType = "normal";
        applyRuleProcess.command = [
            backend.script, "apply-rule",
            name, JSON.stringify(matchObj), JSON.stringify(actionsObj)
        ];
        applyRuleProcess.running = true;
    }

    function setToggle(toggleName, val) {
        backend.busy = true;
        toggleProcess.command = [backend.script, "set-toggle", toggleName, val || ""];
        toggleProcess.running = true;
    }

    function revertFile(targetFile) {
        backend.busy = true;
        backend.statusMessage = "Reverting to backup...";
        revertProcess.command = [backend.script, "revert", targetFile];
        revertProcess.running = true;
    }

    function copyErrorToClipboard() {
        copyErrorProcess.running = true;
    }

    // Processes
    Process {
        id: fetchInfoProcess
        command: [backend.script, "get-info"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    backend.systemInfo = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: fetchKeybindsProcess
        command: [backend.script, "list-keybinds"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    backend.keybinds = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: fetchRulesProcess
        command: [backend.script, "list-rules"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    backend.windowRules = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: fetchStartupProcess
        command: [backend.script, "list-startup"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    backend.startupApps = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: fetchTogglesProcess
        command: [backend.script, "get-toggles"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    backend.toggles = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: applyKeybindProcess
        stdout: StdioCollector {
            id: applyKbOut
            onStreamFinished: {
                try {
                    var res = JSON.parse(text);
                    if (res.applied) {
                        backend.statusMessage = "Keybinding applied successfully!";
                        backend.statusType = "success";
                        backend.hasError = false;
                        fetchKeybindsProcess.running = true;
                    } else if (res.valid === false) {
                        backend.statusMessage = "Validation failed: " + res.error;
                        backend.statusType = "error";
                        backend.hasError = true;
                        backend.lastErrorMessage = res.error;
                        backend.lastErrorTarget = "user_keybinds.lua";
                    }
                } catch (e) {}
            }
        }
        onExited: function(code) {
            backend.busy = false;
        }
    }

    Process {
        id: applyRuleProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var res = JSON.parse(text);
                    if (res.applied) {
                        backend.statusMessage = "Window rule applied successfully!";
                        backend.statusType = "success";
                        backend.hasError = false;
                        fetchRulesProcess.running = true;
                    } else {
                        backend.statusMessage = "Failed to apply rule: " + (res.error || "Unknown error");
                        backend.statusType = "error";
                        backend.hasError = true;
                        backend.lastErrorMessage = res.error || "Syntax or regex error";
                        backend.lastErrorTarget = "user_window_rules.lua";
                    }
                } catch (e) {}
            }
        }
        onExited: function(code) {
            backend.busy = false;
        }
    }

    Process {
        id: toggleProcess
        onExited: function() {
            backend.busy = false;
            fetchTogglesProcess.running = true;
        }
    }

    Process {
        id: revertProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var res = JSON.parse(text);
                    if (res.reverted) {
                        backend.statusMessage = "Reverted successfully from backup!";
                        backend.statusType = "success";
                        backend.hasError = false;
                        backend.refreshAll();
                    } else {
                        backend.statusMessage = "Revert failed: " + (res.error || "No backup found");
                        backend.statusType = "error";
                    }
                } catch (e) {}
            }
        }
        onExited: function() {
            backend.busy = false;
        }
    }

    Process {
        id: copyErrorProcess
        command: [backend.script, "copy-error"]
        stdout: StdioCollector {
            onStreamFinished: {
                backend.statusMessage = "Error details copied to clipboard!";
                backend.statusType = "normal";
            }
        }
    }

    Component.onCompleted: {
        backend.refreshAll();
    }
}
