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

    // Waybar Visual Editor state
    property string waybarActiveConfig: "TOP-Default"
    property var waybarConfigs: []
    property var waybarLayout: ({
        "name": "TOP-Default",
        "path": "",
        "is_custom": false,
        "suggested_clone": "[Custom-1]-TOP-Default",
        "layer": "top",
        "position": "top",
        "modules_left": [],
        "modules_center": [],
        "modules_right": [],
        "available_modules": []
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
        fetchWaybarConfigsProcess.running = true;
        loadWaybarLayoutProcess.command = [backend.script, "get-waybar-layout", ""];
        loadWaybarLayoutProcess.running = true;
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

    function editFile(targetFile) {
        if (!targetFile) return;
        editFileProcess.command = [backend.script, "edit-file", targetFile];
        editFileProcess.running = true;
    }

    function fetchWaybarConfigs() {
        fetchWaybarConfigsProcess.running = true;
    }

    function loadWaybarLayout(cfgName) {
        backend.busy = true;
        loadWaybarLayoutProcess.command = [backend.script, "get-waybar-layout", cfgName || ""];
        loadWaybarLayoutProcess.running = true;
    }

    function cloneWaybarConfig(sourceName, customName) {
        backend.busy = true;
        backend.statusMessage = "Cloning Waybar layout configuration...";
        backend.statusType = "normal";
        cloneWaybarProcess.command = [backend.script, "clone-waybar-config", sourceName || "", customName || ""];
        cloneWaybarProcess.running = true;
    }

    function saveWaybarLayout(configName, leftArr, centerArr, rightArr, activate) {
        backend.busy = true;
        backend.statusMessage = "Validating and saving Waybar layout...";
        backend.statusType = "normal";
        saveWaybarProcess.command = [
            backend.script, "save-waybar-layout",
            configName,
            JSON.stringify(leftArr || []),
            JSON.stringify(centerArr || []),
            JSON.stringify(rightArr || []),
            activate !== false ? "true" : "false"
        ];
        saveWaybarProcess.running = true;
    }

    function validateWaybarSyntax(configNameOrPath) {
        backend.busy = true;
        var p = configNameOrPath;
        if (p && !p.startsWith("/")) {
            p = configHome + "/hypr/waybar/configs/" + p;
        }
        validateWaybarProcess.command = [backend.script, "validate-waybar-syntax", p || ""];
        validateWaybarProcess.running = true;
    }

    function editWaybarModule(moduleName) {
        findWaybarModuleProcess.command = [backend.script, "find-waybar-module", moduleName];
        findWaybarModuleProcess.running = true;
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

    Process {
        id: editFileProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var res = JSON.parse(text);
                    if (res.edited) {
                        var fname = res.file.split('/').pop();
                        backend.statusMessage = "Opened in editor: " + fname;
                        backend.statusType = "success";
                    } else if (res.error) {
                        backend.statusMessage = "Failed to open editor: " + res.error;
                        backend.statusType = "error";
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: fetchWaybarConfigsProcess
        command: [backend.script, "list-waybar-configs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var res = JSON.parse(text);
                    if (res.active_config) backend.waybarActiveConfig = res.active_config;
                    if (res.configs) backend.waybarConfigs = res.configs;
                } catch (e) {}
            }
        }
    }

    Process {
        id: loadWaybarLayoutProcess
        stdout: StdioCollector {
            onStreamFinished: {
                backend.busy = false;
                try {
                    var res = JSON.parse(text);
                    if (res && !res.error) {
                        backend.waybarLayout = res;
                    } else if (res && res.error) {
                        backend.statusMessage = "Failed to load layout: " + res.error;
                        backend.statusType = "error";
                    }
                } catch (e) {}
            }
        }
        onExited: function() { backend.busy = false; }
    }

    Process {
        id: cloneWaybarProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var res = JSON.parse(text);
                    if (res.cloned) {
                        backend.statusMessage = "Cloned layout as: " + res.name;
                        backend.statusType = "success";
                        backend.fetchWaybarConfigs();
                        backend.loadWaybarLayout(res.name);
                    } else {
                        backend.statusMessage = "Clone failed: " + (res.error || "Unknown error");
                        backend.statusType = "error";
                    }
                } catch (e) {}
            }
        }
        onExited: function() { backend.busy = false; }
    }

    Process {
        id: saveWaybarProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var res = JSON.parse(text);
                    if (res.saved) {
                        backend.statusMessage = "Waybar layout applied successfully!";
                        backend.statusType = "success";
                        backend.hasError = false;
                        backend.fetchWaybarConfigs();
                        backend.loadWaybarLayout(res.name);
                    } else {
                        backend.statusMessage = "Save failed: " + (res.error || "Syntax error");
                        backend.statusType = "error";
                        backend.hasError = true;
                        backend.lastErrorMessage = res.error || "Syntax check failed";
                        backend.lastErrorTarget = res.name || "waybar config";
                    }
                } catch (e) {}
            }
        }
        onExited: function() { backend.busy = false; }
    }

    Process {
        id: validateWaybarProcess
        stdout: StdioCollector {
            onStreamFinished: {
                backend.busy = false;
                try {
                    var res = JSON.parse(text);
                    if (res.valid) {
                        backend.statusMessage = "Waybar configuration syntax check passed!";
                        backend.statusType = "success";
                    } else {
                        backend.statusMessage = "Syntax error: " + (res.error || "Invalid JSONC");
                        backend.statusType = "error";
                        backend.hasError = true;
                        backend.lastErrorMessage = res.error || "Invalid syntax";
                        backend.lastErrorTarget = "waybar config";
                    }
                } catch (e) {}
            }
        }
        onExited: function() { backend.busy = false; }
    }

    Process {
        id: findWaybarModuleProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var res = JSON.parse(text);
                    if (res.file) {
                        backend.editFile(res.file);
                    }
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: {
        backend.refreshAll();
    }
}
