// Bridge between the QML panel and QsNetworkPanel.sh.
//
// The snapshot subcommand prints tab separated records (DEV, WIFI, WIFI-ON,
// BT-ON, BT-SCAN, BT-CTL, BTDEV, NOTE) which are parsed here into plain
// JavaScript objects, so the panel only ever renders data and never talks to
// NetworkManager or BlueZ itself.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: backend

    // Resolved from this widget's own directory, so it works both installed
    // (~/.config/hypr/quickshell/network-widget) and straight from the repo.
    readonly property string script: Quickshell.shellDir + "/../../scripts/QsNetworkPanel.sh"

    // Snapshot state.
    property var devices: []        // { iface, type, state, connection, ip, prefix, gateway, dns, mac, connected }
    property var networks: []       // { ssid, signal, security, inUse }
    property var btDevices: []      // { address, name, connected, paired, battery, icon }
    property bool wifiEnabled: false
    property bool btEnabled: false
    property bool btScanning: false
    property string controller: ""
    property string note: ""
    property bool loaded: false

    // Panel driven state.
    property bool autoRefresh: false
    property bool busy: false
    property string error: ""
    property bool queued: false

    readonly property var ethernetDevices: devices.filter(function (device) {
        return device.type === "ethernet";
    })

    readonly property var wifiDevice: {
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type === "wifi") return devices[i];
        }
        return null;
    }

    function field(parts, index, fallback) {
        var value = parts[index];
        if (value === undefined || value === null) return fallback;
        return value;
    }

    function applySnapshot(text) {
        var devices = [];
        var networks = [];
        var btDevices = [];
        var wifiEnabled = false;
        var btEnabled = false;
        var btScanning = false;
        var controller = "";
        var notes = [];

        var lines = String(text).split("\n");
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (line.length === 0) continue;
            var parts = line.split("\t");
            switch (parts[0]) {
            case "DEV": {
                var dns = field(parts, 8, "");
                devices.push({
                    iface: field(parts, 1, ""),
                    type: field(parts, 2, ""),
                    state: field(parts, 3, ""),
                    connection: field(parts, 4, ""),
                    ip: field(parts, 5, ""),
                    prefix: field(parts, 6, ""),
                    gateway: field(parts, 7, ""),
                    dns: dns === "" ? [] : dns.split(","),
                    mac: field(parts, 9, ""),
                    connected: field(parts, 3, "") === "connected"
                });
                break;
            }
            case "WIFI":
                networks.push({
                    ssid: field(parts, 1, ""),
                    signal: Number(field(parts, 2, "0")),
                    security: field(parts, 3, ""),
                    inUse: field(parts, 4, "0") === "1"
                });
                break;
            case "WIFI-ON":
                wifiEnabled = field(parts, 1, "0") === "1";
                break;
            case "BT-ON":
                btEnabled = field(parts, 1, "0") === "1";
                break;
            case "BT-SCAN":
                btScanning = field(parts, 1, "0") === "1";
                break;
            case "BT-CTL":
                controller = field(parts, 1, "");
                break;
            case "BTDEV":
                btDevices.push({
                    address: field(parts, 1, ""),
                    name: field(parts, 2, ""),
                    connected: field(parts, 3, "0") === "1",
                    paired: field(parts, 4, "0") === "1",
                    battery: (field(parts, 5, "-") === "-") ? -1 : Number(field(parts, 5, "-")),
                    icon: field(parts, 6, "")
                });
                break;
            case "NOTE":
                notes.push(field(parts, 1, ""));
                break;
            }
        }

        backend.devices = devices;
        backend.networks = networks;
        backend.btDevices = btDevices;
        backend.wifiEnabled = wifiEnabled;
        backend.btEnabled = btEnabled;
        backend.btScanning = btScanning;
        backend.controller = controller;
        backend.note = notes.join(" · ");
        backend.loaded = true;
    }

    function refresh() {
        if (poll.running) {
            queued = true;
            return;
        }
        poll.running = true;
    }

    function run(args) {
        action.command = [script].concat(args);
        error = "";
        busy = true;
        action.running = true;
    }

    function setWifi(enabled) {
        run(["wifi", enabled ? "on" : "off"]);
    }

    function connectWifi(ssid, password) {
        var args = ["connect-wifi", ssid];
        if (password && password.length > 0) args.push(password);
        run(args);
    }

    function disconnectWifi(ssid) {
        run(["disconnect-wifi", ssid]);
    }

    function rescanWifi() {
        error = "";
        run(["scan-wifi"]);
    }

    function setBluetooth(enabled) {
        run(["bt-power", enabled ? "on" : "off"]);
    }

    function scanBluetooth() {
        run(["bt-scan"]);
    }

    function connectBluetooth(address) {
        run(["bt", "connect", address]);
    }

    function disconnectBluetooth(address) {
        run(["bt", "disconnect", address]);
    }

    function pairBluetooth(address) {
        run(["bt", "pair", address]);
    }

    function connectDevice(iface) {
        run(["connect-device", iface]);
    }

    function disconnectDevice(iface) {
        run(["disconnect-device", iface]);
    }

    Timer {
        interval: 5000
        repeat: true
        running: backend.autoRefresh
        onTriggered: backend.refresh()
    }

    Process {
        id: poll
        command: [backend.script, "snapshot"]
        stdout: StdioCollector {
            id: pollOutput
            onStreamFinished: backend.applySnapshot(pollOutput.text)
        }
        onExited: function (exitCode, exitStatus) {
            if (backend.queued) {
                backend.queued = false;
                Qt.callLater(backend.refresh);
            }
        }
    }

    Process {
        id: action
        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector { id: actionError }
        onExited: function (exitCode, exitStatus) {
            backend.busy = false;
            if (exitCode === 0) {
                backend.error = "";
            } else {
                var message = actionError.text.trim();
                if (message === "") message = actionOutput.text.trim();
                backend.error = message === "" ? "Command failed (exit " + exitCode + ")" : message;
            }
            backend.refresh();
        }
    }
}
