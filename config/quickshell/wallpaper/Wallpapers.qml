// The wallpaper list behind the carousel: what the scripts report, the current
// wallpaper and the apply call.
//
// Listing is done by QsWallpaper.sh rather than a FolderListModel: the folder
// is searched recursively and symlinks are followed, the same way
// WallpaperSelect.sh finds wallpapers, so a collection sorted into subfolders
// or held in a Nix store opens here with the same contents as in the rofi menu.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: wallpapers

    // Resolved from the shell root, so the applet finds the script whether it
    // runs as ~/.config/quickshell/wallpaper or straight from a checkout: both
    // sit two levels below the directory that holds hypr/.
    readonly property string script: Quickshell.shellDir + "/../../hypr/scripts/QsWallpaper.sh"

    // Every wallpaper the script listed: { path, name, folder }
    property var all: []
    // The folder the list came from, shown when the deck is empty so a missing
    // folder and an empty one can be told apart.
    property string folder: ""
    // Path of the wallpaper on the focused monitor, set by the script.
    property string currentPath: ""
    // Optional filter for the deck, set when the carousel is opened with a
    // query (QsWallpaper.sh open --query TEXT). The deck has no search field,
    // so this is the only way a filter arrives.
    property string query: ""
    // Last failure from the apply call, shown under the deck.
    property string lastError: ""

    property string pendingPath: ""

    readonly property int count: wallpapers.all.length

    // One entry per match. Every word in the query has to appear in the folder
    // and file name, so "dark 4k" narrows rather than widens.
    readonly property var filtered: {
        var needle = wallpapers.query.trim().toLowerCase();
        if (needle === "") return wallpapers.all;

        var tokens = needle.split(/\s+/);
        var out = [];
        for (var index = 0; index < wallpapers.all.length; index++) {
            var entry = wallpapers.all[index];
            var haystack = (entry.folder + "/" + entry.name).toLowerCase();
            var hit = true;
            for (var token = 0; token < tokens.length; token++) {
                if (tokens[token] !== "" && haystack.indexOf(tokens[token]) === -1) {
                    hit = false;
                    break;
                }
            }
            if (hit) out.push(entry);
        }
        return out;
    }

    function load(text) {
        var lines = (text ? text : "").split("\n");
        var out = [];
        for (var index = 0; index < lines.length; index++) {
            var path = lines[index].trim();
            if (path === "" || path.charAt(0) !== "/") continue;

            var name = path.substring(path.lastIndexOf("/") + 1);
            var folderPath = path.substring(0, path.lastIndexOf("/"));
            var folder = folderPath.substring(folderPath.lastIndexOf("/") + 1);

            out.push({ path: path, name: name, folder: folder });
        }
        wallpapers.all = out;
    }

    // Match on the file name, because the wallpaper actually applied may be an
    // effect copy of it ("<effect>-<name>") stored outside this folder.
    function isCurrent(path) {
        if (path === "" || wallpapers.currentPath === "") return false;
        var current = wallpapers.currentPath;
        var currentName = current.substring(current.lastIndexOf("/") + 1);
        var name = path.substring(path.lastIndexOf("/") + 1);
        return currentName === name || currentName.endsWith("-" + name);
    }

    function refresh() {
        wallpapers.lastError = "";
        listProcess.running = true;
        currentProcess.running = true;
        folderProcess.running = true;
    }

    function refreshCurrent() {
        currentProcess.running = true;
    }

    function apply(path) {
        if (path === "") return;
        wallpapers.lastError = "";
        wallpapers.pendingPath = path;
        applyProcess.command = [wallpapers.script, "apply", path];
        applyProcess.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: listProcess

        command: [wallpapers.script, "list"]
        stdout: StdioCollector {
            id: listOutput
            onStreamFinished: wallpapers.load(listOutput.text)
        }
    }

    Process {
        id: currentProcess

        command: [wallpapers.script, "current"]
        stdout: StdioCollector {
            id: currentOutput
            onStreamFinished: wallpapers.currentPath = currentOutput.text.trim()
        }
    }

    Process {
        id: folderProcess

        command: [wallpapers.script, "folder"]
        stdout: StdioCollector {
            id: folderOutput
            onStreamFinished: wallpapers.folder = folderOutput.text.trim()
        }
    }

    Process {
        id: applyProcess

        stdout: StdioCollector {
            id: applyOutput
        }
        stderr: StdioCollector {
            id: applyError
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0) {
                wallpapers.currentPath = wallpapers.pendingPath;
            } else {
                var message = applyError.text.trim();
                if (message === "") message = applyOutput.text.trim();
                wallpapers.lastError = message === "" ? "Could not apply the wallpaper" : message;
            }
            wallpapers.refreshCurrent();
        }
    }
}
