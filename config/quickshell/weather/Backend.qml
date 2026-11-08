// Backend bridge between Quickshell QML and QsWeather.sh.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: backend

    readonly property string script: Quickshell.shellDir + "/../../hypr/scripts/QsWeather.sh"

    property var locations: []
    property var settings: ({
        "unit": "c",
        "unit_c": true,
        "unit_f": false,
        "active_location_id": "loc-1",
        "provider": "open-meteo"
    })
    property var searchResults: []
    property bool loaded: false
    property bool busy: false
    property string error: ""

    readonly property var activeLocation: {
        var activeId = settings.active_location_id;
        for (var i = 0; i < locations.length; i++) {
            if (locations[i].id === activeId) return locations[i];
        }
        return locations.length > 0 ? locations[0] : null;
    }

    function applySnapshot(rawText) {
        if (!rawText || rawText.trim() === "") return;
        try {
            var data = JSON.parse(rawText);
            if (data.settings) backend.settings = data.settings;
            if (data.locations) backend.locations = data.locations;
            backend.loaded = true;
            backend.error = "";
        } catch (e) {
            backend.error = "Failed to parse weather data: " + e;
        }
    }

    function refresh() {
        if (pollProcess.running) return;
        pollProcess.running = true;
    }

    function runAction(args) {
        actionProcess.command = [backend.script].concat(args);
        backend.busy = true;
        backend.error = "";
        actionProcess.running = true;
    }

    function setUnit(unitMode) {
        runAction(["set-unit", unitMode]);
    }

    function setActiveLocation(locId) {
        runAction(["set-active", locId]);
    }

    function setAutoLocate(locId, enable) {
        runAction(["set-auto-locate", locId, enable ? "1" : "0"]);
    }

    function addLocation(name, lat, lon) {
        runAction(["add-location", name, String(lat), String(lon)]);
    }

    function removeLocation(locId) {
        runAction(["remove-location", locId]);
    }

    function searchLocations(query) {
        if (!query || query.trim() === "") {
            backend.searchResults = [];
            return;
        }
        searchProcess.command = [backend.script, "search", query.trim()];
        searchProcess.running = true;
    }

    Timer {
        interval: 900000 // 15 minutes auto-refresh
        repeat: true
        running: true
        onTriggered: backend.refresh()
    }

    Process {
        id: pollProcess
        command: [backend.script, "snapshot"]
        stdout: StdioCollector {
            id: pollOutput
            onStreamFinished: backend.applySnapshot(pollOutput.text)
        }
        onExited: function (code, status) {
            backend.busy = false;
        }
    }

    Process {
        id: actionProcess
        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector { id: actionError }
        onExited: function (code, status) {
            backend.busy = false;
            backend.refresh();
        }
    }

    Process {
        id: searchProcess
        stdout: StdioCollector {
            id: searchOutput
            onStreamFinished: {
                try {
                    backend.searchResults = JSON.parse(searchOutput.text);
                } catch (e) {
                    backend.searchResults = [];
                }
            }
        }
    }

    Component.onCompleted: {
        backend.refresh();
    }
}
