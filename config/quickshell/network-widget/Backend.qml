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
    property string tailscaleAuthUrl: ""
    property var containers: []     // { kind, name, state, status, runtime, cpu, mem }
    property var containerEngines: ({}) // { docker: true, podman: false }
    property var networks: []       // { ssid, signal, security, inUse }
    property var btDevices: []      // { address, name, connected, paired, battery, icon }
    property bool wifiEnabled: false
    property bool btEnabled: false
    property bool btScanning: false
    property string controller: ""
    property string note: ""
    // The tab that note belongs to; empty means it applies anywhere.
    property string noteScope: ""
    // A note that reports something broken (no NetworkManager, for example)
    // rather than a normal hint, so the panel can colour it as an error.
    property bool noteIsError: false
    property bool loaded: false

    // Tailscale host configuration and SSH management state.
    readonly property string hostsFilePath: {
        var xdg = Quickshell.env("XDG_CONFIG_HOME");
        var home = Quickshell.env("HOME") || "";
        var base = xdg ? xdg : (home + "/.config");
        return base + "/hypr/UserConfigs/tailscale-hosts.json";
    }
    readonly property string currentUser: Quickshell.env("USER") || ""
    readonly property string defaultTerminal: Quickshell.env("TERMINAL") || "kitty"
    property var tailscaleHosts: ({})
    property var detectedTerminals: []
    property var detectedSshKeys: []
    property string tailscaleLogsText: ""
    property var tailscaleLogsJson: []
    property bool testingConnection: false
    property var testResult: null
    property var testCallback: null

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
    // A daemon that answers `info`, not merely an installed binary.
    readonly property bool dockerRunning: containerEngines["docker"] === true
    readonly property bool podmanRunning: containerEngines["podman"] === true
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
        var tailscaleAuthUrl = "";
        var containers = [];
        var containerStats = [];
        var containerEngines = {};
        var networks = [];
        var btDevices = [];
        var wifiEnabled = false;
        var btEnabled = false;
        var btScanning = false;
        var controller = "";
        var notes = [];
        var noteScope = "";
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
            case "TS-AUTH":
                tailscaleAuthUrl = field(parts, 1, "");
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
            case "BOXENGINE":
                containerEngines[field(parts, 1, "")] = field(parts, 2, "0") === "1";
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
                noteScope = field(parts, 1, "");
                notes.push(field(parts, 2, ""));
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
        backend.tailscaleAuthUrl = tailscaleAuthUrl;
        backend.containers = containers;
        backend.containerEngines = containerEngines;
        backend.networks = networks;
        backend.btDevices = btDevices;
        backend.wifiEnabled = wifiEnabled;
        backend.btEnabled = btEnabled;
        backend.btScanning = btScanning;
        backend.controller = controller;
        backend.note = notes.join(" · ");
        backend.noteScope = noteScope;
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

    // kind is docker or podman, action is start|stop|restart|logs|shell.
    function containerAction(kind, action, name, extra) {
        var argv = ["container", kind, action, name];
        if (extra !== undefined && extra !== "") argv.push(extra);
        run(argv);
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

    // Opens the container's logs in the preferred terminal: the captured file
    // in a viewer by default, the live stream when `live` is set.
    function containerLogs(kind, name, live) {
        containerAction(kind, "logs", name, live === true ? "live" : "");
    }

    // Where QsNetworkPanel.sh writes that file, named the same way, so the
    // panel can show the path before anything is opened.
    function containerLogPath(kind, name) {
        var dir = Quickshell.env("XDG_RUNTIME_DIR");
        if (dir === null || dir === "") dir = "/tmp";
        var safe = String(name).replace(/[^A-Za-z0-9_.-]/g, "_");
        return dir + "/quickshell-network-widget/" + kind + "-" + safe + ".log";
    }

    // Opens an interactive shell inside the container.
    function containerShell(kind, name) {
        containerAction(kind, "shell", name);
    }

    function setContainerEngine(kind, enabled) {
        run(["container-engine", kind, enabled ? "on" : "off"]);
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

    function openAuthUrl(url) {
        var target = url || backend.tailscaleAuthUrl;
        if (!target) return;
        run(["tailscale-open-url", target]);
    }

    // -------------------------------------------------- Tailscale SSH & Config
    function applyTailscaleHosts(text) {
        if (!text || text.trim() === "") {
            backend.tailscaleHosts = {};
            return;
        }
        try {
            var doc = JSON.parse(text);
            backend.tailscaleHosts = doc.hosts || {};
        } catch (e) {
            backend.tailscaleHosts = {};
        }
    }

    function getHostConfig(peer) {
        if (!peer) return null;
        var key = peer.ip || peer.name;
        var existing = backend.tailscaleHosts[key] || backend.tailscaleHosts[peer.name] || {};
        var fallbackKey = backend.detectedSshKeys.length > 0 ? backend.detectedSshKeys[0] : "~/.ssh/id_ed25519";
        return {
            hostname: existing.hostname || peer.name,
            ip: existing.ip || peer.ip,
            port: existing.port || 22,
            user: existing.user || backend.currentUser,
            terminal: existing.terminal || backend.defaultTerminal,
            auth_type: existing.auth_type || "key",
            key_path: existing.key_path !== undefined ? existing.key_path : fallbackKey
        };
    }

    function saveTailscaleHost(hostKey, configObj) {
        run(["tailscale-save-host", hostKey, JSON.stringify(configObj)]);
    }

    function testTailscaleConnection(host, ip, port, user, authType, keyPath, callback) {
        if (backend.testingConnection) return;
        backend.testingConnection = true;
        backend.testResult = null;
        backend.testCallback = callback || null;
        testProcess.command = [
            backend.script,
            "tailscale-ssh-test",
            host || "",
            ip || "",
            String(port || 22),
            user || backend.currentUser,
            authType || "key",
            keyPath || ""
        ];
        testProcess.running = true;
    }

    function connectTailscaleSsh(host, ip, port, user, terminal, authType, keyPath) {
        run([
            "tailscale-ssh-connect",
            host || "",
            ip || "",
            String(port || 22),
            user || backend.currentUser,
            terminal || backend.defaultTerminal,
            authType || "key",
            keyPath || ""
        ]);
    }

    function exportTailscaleConfig(targetPath, callback) {
        exportProcess.targetCallback = callback || null;
        exportProcess.command = [backend.script, "tailscale-export", targetPath || ""];
        exportProcess.running = true;
    }

    function importTailscaleConfig(sourcePath, callback) {
        importProcess.targetCallback = callback || null;
        importProcess.command = [backend.script, "tailscale-import", sourcePath];
        importProcess.running = true;
    }

    function loadTailscaleLogs(format, callback) {
        logsProcess.targetFormat = format || "text";
        logsProcess.targetCallback = callback || null;
        logsProcess.command = [backend.script, "tailscale-logs", format || "text"];
        logsProcess.running = true;
    }

    function saveTailscaleLogs(targetPath, callback) {
        saveLogsProcess.targetCallback = callback || null;
        saveLogsProcess.command = [backend.script, "tailscale-log-save", targetPath || ""];
        saveLogsProcess.running = true;
    }

    function fetchTerminalsAndKeys() {
        if (!terminalsProcess.running) terminalsProcess.running = true;
        if (!keysProcess.running) keysProcess.running = true;
    }

    Component.onCompleted: {
        backend.fetchTerminalsAndKeys();
    }

    FileView {
        id: hostsFileWatcher
        path: backend.hostsFilePath
        watchChanges: true
        onTextChanged: backend.applyTailscaleHosts(hostsFileWatcher.text())
    }

    Process {
        id: terminalsProcess
        command: [backend.script, "tailscale-list-terminals"]
        stdout: StdioCollector {
            id: terminalsOutput
            onStreamFinished: {
                var lines = terminalsOutput.text.trim().split("\n");
                var list = [];
                for (var i = 0; i < lines.length; i++) {
                    var t = lines[i].trim();
                    if (t.length > 0) list.push(t);
                }
                backend.detectedTerminals = list;
            }
        }
    }

    Process {
        id: keysProcess
        command: [backend.script, "tailscale-list-keys"]
        stdout: StdioCollector {
            id: keysOutput
            onStreamFinished: {
                var lines = keysOutput.text.trim().split("\n");
                var list = [];
                for (var i = 0; i < lines.length; i++) {
                    var k = lines[i].trim();
                    if (k.length > 0) list.push(k);
                }
                backend.detectedSshKeys = list;
            }
        }
    }

    Process {
        id: testProcess
        stdout: StdioCollector { id: testOutput }
        stderr: StdioCollector { id: testError }
        onExited: function (exitCode, exitStatus) {
            backend.testingConnection = false;
            var success = exitCode === 0;
            var msg = success ? "Connection successful" : testError.text.trim();
            if (!success && msg === "") msg = testOutput.text.trim();
            if (msg === "") msg = success ? "OK" : "Connection failed";
            var res = { success: success, message: msg };
            backend.testResult = res;
            if (backend.testCallback) {
                backend.testCallback(res);
                backend.testCallback = null;
            }
            backend.refresh();
        }
    }

    Process {
        id: exportProcess
        property var targetCallback: null
        stdout: StdioCollector { id: exportOutput }
        stderr: StdioCollector { id: exportError }
        onExited: function (exitCode, exitStatus) {
            var success = exitCode === 0;
            var path = exportOutput.text.trim();
            var err = exportError.text.trim();
            var res = { success: success, path: path, error: err };
            if (exportProcess.targetCallback) {
                exportProcess.targetCallback(res);
                exportProcess.targetCallback = null;
            }
            backend.refresh();
        }
    }

    Process {
        id: importProcess
        property var targetCallback: null
        stdout: StdioCollector { id: importOutput }
        stderr: StdioCollector { id: importError }
        onExited: function (exitCode, exitStatus) {
            var success = exitCode === 0;
            var err = importError.text.trim();
            if (!success && err === "") err = importOutput.text.trim();
            var res = { success: success, error: err };
            if (importProcess.targetCallback) {
                importProcess.targetCallback(res);
                importProcess.targetCallback = null;
            }
            backend.refresh();
        }
    }

    Process {
        id: logsProcess
        property string targetFormat: "text"
        property var targetCallback: null
        stdout: StdioCollector { id: logsOutput }
        onExited: function (exitCode, exitStatus) {
            var out = logsOutput.text;
            if (logsProcess.targetFormat === "json") {
                try {
                    backend.tailscaleLogsJson = JSON.parse(out);
                } catch (e) {
                    backend.tailscaleLogsJson = [];
                }
            } else {
                backend.tailscaleLogsText = out;
            }
            if (logsProcess.targetCallback) {
                logsProcess.targetCallback(out);
                logsProcess.targetCallback = null;
            }
        }
    }

    Process {
        id: saveLogsProcess
        property var targetCallback: null
        stdout: StdioCollector { id: saveLogsOutput }
        stderr: StdioCollector { id: saveLogsError }
        onExited: function (exitCode, exitStatus) {
            var success = exitCode === 0;
            var path = saveLogsOutput.text.trim();
            var err = saveLogsError.text.trim();
            var res = { success: success, path: path, error: err };
            if (saveLogsProcess.targetCallback) {
                saveLogsProcess.targetCallback(res);
                saveLogsProcess.targetCallback = null;
            }
        }
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
