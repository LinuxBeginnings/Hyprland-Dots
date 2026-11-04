// Bridge between the QML panel and QsNetworkPanel.sh.
//
// The snapshot subcommand prints tab separated records (DEV, ADDR, LINK,
// FEATURE, WIFI, WIFI-ON, BT-ON, BT-SCAN, BT-CTL, BTDEV, NOTE) which are
// parsed here into plain JavaScript objects, so the panel only ever renders
// data and never talks to NetworkManager or BlueZ itself.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: backend

    // Resolved from this widget's own directory, so it works both installed
    // (~/.config/quickshell/network-widget) and straight from the repo. The
    // widget sits under quickshell/, the script under hypr/scripts/.
    readonly property string script: Quickshell.shellDir + "/../../hypr/scripts/QsNetworkPanel.sh"

    // Snapshot state.
    property var devices: []        // { iface, type, state, connection, ip, prefix, gateway, dns, mac, managed, connected, addresses }
    property var links: []          // { kind, iface, state, addresses }
    property var features: ({})     // { tailscale: true, docker: true, podman: true }
    property var tailscalePeers: [] // { name, ip, online, os, self }
    property var exitNodes: []      // { name, ip, selected }
    property string tailscaleState: ""
    property var containers: []     // { kind, name, state, status, runtime, cpu, mem }
    property var networks: []       // { ssid, signal, security, inUse }
    property var btDevices: []      // { address, name, connected, paired, battery, icon }
    property bool wifiEnabled: false
    property bool btEnabled: false
    property bool btScanning: false
    property string controller: ""
    property string note: ""
    // A note that reports something broken (no NetworkManager, for example)
    // rather than a normal hint, so the panel can colour it as an error.
    property bool noteIsError: false
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

    // The Tailscale/Docker/Podman tabs exist only when the tool is installed or
    // at least one of its links is present.
    readonly property var tailscaleLinks: linksFor("tailscale")
    readonly property var dockerLinks: linksFor("docker")
    readonly property var podmanLinks: linksFor("podman")
    readonly property bool hasTailscale: features["tailscale"] === true || tailscaleLinks.length > 0
    readonly property bool hasDocker: features["docker"] === true || dockerLinks.length > 0
    readonly property bool hasPodman: features["podman"] === true || podmanLinks.length > 0

    readonly property var dockerContainers: containersFor("docker")
    readonly property var podmanContainers: containersFor("podman")
    readonly property bool tailscaleRunning: tailscaleState === "Running"

    function linksFor(kind) {
        return links.filter(function (link) {
            return link.kind === kind;
        });
    }

    function containersFor(kind) {
        return containers.filter(function (container) {
            return container.kind === kind;
        });
    }

    // Addresses for the info block. Link local IPv6 is left out: every device
    // has one and it is never the address anyone wants to copy.
    function formattedAddresses(device) {
        var rows = [];
        if (!device) return rows;
        var addresses = device.addresses ? device.addresses : [];
        for (var i = 0; i < addresses.length; i++) {
            var address = addresses[i];
            if (address.ip === "" || address.scope === "link") continue;
            rows.push({
                label: rows.length === 0 ? "Address" : "Alias",
                value: address.prefix !== "" ? address.ip + "/" + address.prefix : address.ip
            });
        }
        // Older script output has no ADDR records; fall back to the DEV fields.
        if (rows.length === 0 && device.ip) {
            rows.push({
                label: "Address",
                value: device.prefix !== "" ? device.ip + "/" + device.prefix : device.ip
            });
        }
        return rows;
    }

    function field(parts, index, fallback) {
        var value = parts[index];
        if (value === undefined || value === null) return fallback;
        return value;
    }

    function applySnapshot(text) {
        var devices = [];
        var addresses = [];
        var links = [];
        var features = {};
        var tailscalePeers = [];
        var exitNodes = [];
        var tailscaleState = "";
        var containers = [];
        var containerStats = [];
        var networks = [];
        var btDevices = [];
        var wifiEnabled = false;
        var btEnabled = false;
        var btScanning = false;
        var controller = "";
        var notes = [];
        var noteIsError = false;

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
                    // Older script output has no MANAGED field; assume managed.
                    managed: field(parts, 10, "1") === "1",
                    // nmcli reports assumed configurations as "connected
                    // (externally)" or "connected (site only)" too.
                    connected: field(parts, 3, "").indexOf("connected") === 0,
                    addresses: []
                });
                break;
            }
            case "ADDR":
                addresses.push({
                    iface: field(parts, 1, ""),
                    family: field(parts, 2, "inet"),
                    ip: field(parts, 3, ""),
                    prefix: field(parts, 4, ""),
                    scope: field(parts, 5, "")
                });
                break;
            case "LINK":
                links.push({
                    kind: field(parts, 1, ""),
                    iface: field(parts, 2, ""),
                    state: field(parts, 3, ""),
                    addresses: []
                });
                break;
            case "FEATURE":
                features[field(parts, 1, "")] = true;
                break;
            case "TS-STATE":
                tailscaleState = field(parts, 1, "");
                break;
            case "TS-EXIT":
                exitNodes.push({
                    name: field(parts, 1, ""),
                    ip: field(parts, 2, ""),
                    selected: field(parts, 3, "0") === "1"
                });
                break;
            case "TSPEER":
                tailscalePeers.push({
                    name: field(parts, 1, ""),
                    ip: field(parts, 2, ""),
                    online: field(parts, 3, "0") === "1",
                    os: field(parts, 4, ""),
                    self: field(parts, 5, "0") === "1"
                });
                break;
            case "BOX":
                containers.push({
                    kind: field(parts, 1, ""),
                    name: field(parts, 2, ""),
                    state: field(parts, 3, ""),
                    status: field(parts, 4, ""),
                    runtime: field(parts, 5, ""),
                    cpu: "",
                    mem: ""
                });
                break;
            case "BOXSTAT":
                containerStats.push({
                    kind: field(parts, 1, ""),
                    name: field(parts, 2, ""),
                    cpu: field(parts, 3, ""),
                    mem: field(parts, 4, "")
                });
                break;
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
            case "ERR":
                notes.push(field(parts, 1, ""));
                noteIsError = true;
                break;
            }
        }

        // ADDR and LINK/DEV records are independent lines, so the addresses are
        // attached once everything has been read.
        function attach(list) {
            for (var j = 0; j < list.length; j++) {
                var owned = [];
                for (var k = 0; k < addresses.length; k++) {
                    if (addresses[k].iface === list[j].iface) owned.push(addresses[k]);
                }
                list[j].addresses = owned;
            }
        }
        attach(devices);
        attach(links);

        // Usage arrives as its own record per container, after the list.
        for (var s = 0; s < containerStats.length; s++) {
            var stat = containerStats[s];
            for (var c = 0; c < containers.length; c++) {
                if (containers[c].kind === stat.kind && containers[c].name === stat.name) {
                    containers[c].cpu = stat.cpu;
                    containers[c].mem = stat.mem;
                    break;
                }
            }
        }

        backend.devices = devices;
        backend.links = links;
        backend.features = features;
        backend.tailscalePeers = tailscalePeers;
        backend.exitNodes = exitNodes;
        backend.tailscaleState = tailscaleState;
        backend.containers = containers;
        backend.networks = networks;
        backend.btDevices = btDevices;
        backend.wifiEnabled = wifiEnabled;
        backend.btEnabled = btEnabled;
        backend.btScanning = btScanning;
        backend.controller = controller;
        backend.note = notes.join(" · ");
        backend.noteIsError = noteIsError;
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

    // kind is docker or podman, action is start|stop|restart.
    function containerAction(kind, action, name) {
        run(["container", kind, action, name]);
    }

    function stopContainer(kind, name) {
        containerAction(kind, "stop", name);
    }

    function startContainer(kind, name) {
        containerAction(kind, "start", name);
    }

    function restartContainer(kind, name) {
        containerAction(kind, "restart", name);
    }

    // Tailscale: bring the tunnel up or down, and switch exit node. Passing
    // "none" clears the exit node.
    function setTailscale(enabled) {
        run(["tailscale", enabled ? "up" : "down"]);
    }

    function setExitNode(name) {
        run(["tailscale", "exit-node", name]);
    }

    // Asks Tailscale for the best exit node and selects it.
    function suggestExitNode() {
        run(["tailscale", "suggest"]);
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
