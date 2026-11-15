// Tab for the links NetworkManager does not manage: Tailscale, Docker and
// Podman. Each link shows its state and every address it carries. The
// Tailscale tab adds up/down, the exit node picker and suggestion, the Docker
// and Podman tabs add their containers with live CPU and memory use.

import QtQuick
import QtQuick.Layouts
import Quickshell
// Aliased: the widget has its own Switch, and a plain import would sit next to
// it at the same name.
import QtQuick.Controls as Controls

ColumnLayout {
    id: root

    property Theme theme: Theme {}
    property Backend backend
    property var links: []
    property var peers: []
    property var exitNodes: []
    property var containers: []
    // Only set on the Docker and Podman tabs; containers are started and
    // stopped through the matching engine.
    property string containerKind: ""
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string hint: "No links"
    // Tailscale and Docker/Podman: the on/off switch in the heading. It
    // controls the tunnel or the container engine's daemon.
    property bool showPower: false
    property bool powered: false
    // Tailscale only: the Export/Import/Logs row under the heading.
    property bool showActions: false
    // Docker/Podman: show stopped containers as well as running ones.
    property bool showStopped: false

    signal powerToggled()
    signal openHostSettings(var peer)
    signal openConfigModal(string mode)
    signal openLogModal()

    height: implicitHeight
    spacing: 6

    readonly property var shownContainers: {
        if (root.containerKind === "") return [];
        if (root.showStopped) return root.containers;
        return root.containers.filter(function (container) {
            return container.state === "running";
        });
    }

    function rowsFor(link) {
        var rows = root.backend.formattedAddresses(link);
        if (rows.length === 0) rows.push({ label: "Address", value: "—" });
        return rows;
    }

    function peerLabel(peer) {
        return peer.self ? peer.name + " (this device)" : peer.name;
    }

    function peerDetail(peer) {
        return peer.os !== "" ? peer.ip + " · " + peer.os : peer.ip;
    }

    function containerDetail(container) {
        var parts = [];
        if (container.status !== "") parts.push(container.status);
        var usage = [];
        if (container.cpu !== "") usage.push(container.cpu);
        if (container.mem !== "") usage.push(container.mem);
        if (usage.length > 0) parts.push(usage.join(" "));
        return parts.join(" · ");
    }

    // docker and podman report the state lower case.
    function containerStateLabel(container) {
        var state = String(container.state);
        if (state === "") return "";
        return state.charAt(0).toUpperCase() + state.slice(1);
    }

    readonly property int runningCount: {
        var count = 0;
        for (var i = 0; i < root.containers.length; i++)
            if (root.containers[i].state === "running") count++;
        return count;
    }

    // Container rows that fit in the scroll window, so the heading can say
    // when the rest are out of sight.
    readonly property int visibleRows: {
        if (root.containerKind === "" || root.shownContainers.length === 0) return 0;
        var step = 50; // 46px row plus its 4px spacer
        var rowsHeight = root.shownContainers.length * step - 4;
        var above = content.implicitHeight - rowsHeight;
        var room = scroll.height - above;
        return Math.max(0, Math.min(root.shownContainers.length,
                                    Math.floor(room / step)));
    }

    function containerSubtitle() {
        if (root.containerKind === "") return "";
        var stopped = root.containers.length - root.runningCount;
        return root.showStopped
            ? root.runningCount + " running · " + stopped + " stopped"
            : root.runningCount + " running";
    }

    // Bulk actions from the heading. They act on running containers only, so
    // "Stop all" cannot trip over something already stopped.
    function stopAllContainers() {
        for (var i = 0; i < root.containers.length; i++)
            if (root.containers[i].state === "running")
                root.backend.stopContainer(root.containerKind, root.containers[i].name);
    }

    function restartAllContainers() {
        for (var i = 0; i < root.containers.length; i++)
            if (root.containers[i].state === "running")
                root.backend.restartContainer(root.containerKind, root.containers[i].name);
    }

    function toggleContainer(container) {
        if (root.containerKind === "") return;
        if (container.state === "running")
            root.backend.stopContainer(root.containerKind, container.name);
        else
            root.backend.startContainer(root.containerKind, container.name);
    }

    function selectExitNode(node) {
        root.backend.setExitNode(node.selected ? "none" : node.name);
    }

    // -------------------------------------------------------------- heading
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: root.icon
            font.family: root.theme.iconFont
            font.pixelSize: 15
            color: root.theme.accent
        }

        Text {
            text: root.title
            font.family: root.theme.fontFamily
            font.pixelSize: 12
            font.bold: true
            color: root.theme.text
        }

        Text {
            Layout.fillWidth: true
            text: root.subtitle !== "" ? root.subtitle : root.containerSubtitle()
            font.family: root.theme.fontFamily
            font.pixelSize: 10
            color: root.theme.muted
            elide: Text.ElideRight
        }

        // Engine state beside the switch, so an off switch reads as a stopped
        // daemon rather than a container filter.
        Text {
            visible: root.showPower
            text: root.powered ? "Running" : "Stopped"
            font.family: root.theme.fontFamily
            font.pixelSize: 9
            color: root.powered ? root.theme.good : root.theme.muted
        }

        Switch {
            theme: root.theme
            visible: root.showPower
            checked: root.powered
            onToggled: root.powerToggled()
        }
    }

    // ------------------------------------------------ Tailscale action row
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        Layout.bottomMargin: 2
        spacing: 6
        visible: root.showActions

        Rectangle {
            implicitHeight: 26
            implicitWidth: expBtnText.implicitWidth + 20
            radius: 5
            color: expMouse.containsMouse ? root.theme.hover : root.theme.surfaceAlt
            border.width: 1
            border.color: root.theme.border

            RowLayout {
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: "󰈔"
                    font.family: root.theme.iconFont
                    font.pixelSize: 11
                    color: root.theme.accent
                }
                Text {
                    id: expBtnText
                    text: "Export config"
                    font.family: root.theme.fontFamily
                    font.pixelSize: 10
                    color: root.theme.text
                }
            }

            MouseArea {
                id: expMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openConfigModal("export")
            }
        }

        Rectangle {
            implicitHeight: 26
            implicitWidth: impBtnText.implicitWidth + 20
            radius: 5
            color: impMouse.containsMouse ? root.theme.hover : root.theme.surfaceAlt
            border.width: 1
            border.color: root.theme.border

            RowLayout {
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: "󰈏"
                    font.family: root.theme.iconFont
                    font.pixelSize: 11
                    color: root.theme.accent
                }
                Text {
                    id: impBtnText
                    text: "Import config"
                    font.family: root.theme.fontFamily
                    font.pixelSize: 10
                    color: root.theme.text
                }
            }

            MouseArea {
                id: impMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openConfigModal("import")
            }
        }

        Rectangle {
            implicitHeight: 26
            implicitWidth: logBtnText.implicitWidth + 20
            radius: 5
            color: logMouse.containsMouse ? root.theme.hover : root.theme.surfaceAlt
            border.width: 1
            border.color: root.theme.border

            RowLayout {
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: "󰈙"
                    font.family: root.theme.iconFont
                    font.pixelSize: 11
                    color: root.theme.accent
                }
                Text {
                    id: logBtnText
                    text: "View Logs"
                    font.family: root.theme.fontFamily
                    font.pixelSize: 10
                    color: root.theme.text
                }
            }

            MouseArea {
                id: logMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openLogModal()
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }

    // -------------------------------------------------------------- content
    Item {
        id: scrollArea
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(content.implicitHeight, 340)

        Flickable {
            id: scroll
            anchors.fill: parent
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: content
                width: parent.width
                spacing: 4

            // Tailscale Authentication Banner if web login required
            Rectangle {
                visible: root.showPower && root.backend && root.backend.tailscaleAuthUrl !== ""
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 8
                color: root.theme.surfaceAlt
                border.width: 1
                border.color: root.theme.accent

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "󰖟"
                        font.family: root.theme.iconFont
                        font.pixelSize: 14
                        color: root.theme.accent
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Tailscale Authentication Required: Click to open browser"
                        font.family: root.theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: root.theme.text
                        elide: Text.ElideRight
                    }

                    Text {
                        text: "Authenticate"
                        font.family: root.theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: root.theme.accent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backend.openAuthUrl(root.backend.tailscaleAuthUrl)
                }
            }

            Repeater {
                model: root.links

                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 4

                    RowItem {
                        theme: root.theme
                        Layout.fillWidth: true
                        icon: root.icon
                        label: modelData.iface
                        detail: modelData.state !== "" ? modelData.state : "unknown"
                        highlighted: modelData.state === "up"
                        interactive: false
                    }

                    InfoBlock {
                        theme: root.theme
                        Layout.fillWidth: true
                        rows: root.rowsFor(modelData)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.topMargin: 4
                visible: root.exitNodes.length > 0
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "Exit nodes"
                    font.family: root.theme.fontFamily
                    font.pixelSize: 9
                    color: root.theme.muted
                }

                Text {
                    text: "Suggest"
                    font.family: root.theme.fontFamily
                    font.pixelSize: 9
                    color: root.theme.accent

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.backend.suggestExitNode()
                    }
                }
            }

            Repeater {
                model: root.exitNodes

                delegate: RowItem {
                    required property var modelData
                    theme: root.theme
                    Layout.fillWidth: true
                    icon: "󰢬"
                    label: modelData.name
                    detail: modelData.ip
                    trailing: modelData.selected ? "Selected" : ""
                    highlighted: modelData.selected
                    onActivated: root.selectExitNode(modelData)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.topMargin: 4
                visible: root.peers.length > 0
                text: "Peers"
                font.family: root.theme.fontFamily
                font.pixelSize: 9
                color: root.theme.muted
            }

            Repeater {
                model: root.peers

                delegate: Rectangle {
                    id: peerRow
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: 8
                    color: peerRowHover.hovered ? root.theme.hover : "transparent"

                    readonly property bool isOnline: modelData.online
                    readonly property bool isSelf: modelData.self

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: "󰢬"
                            font.family: root.theme.iconFont
                            font.pixelSize: 16
                            color: peerRow.isOnline ? root.theme.accent : root.theme.muted
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: root.peerLabel(modelData)
                                color: root.theme.text
                                font.family: root.theme.fontFamily
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.peerDetail(modelData)
                                color: root.theme.muted
                                font.family: root.theme.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Connect button (to the left of online/offline status)
                        Rectangle {
                            id: connectBtn
                            readonly property bool canConnect: peerRow.isOnline && !peerRow.isSelf
                            implicitHeight: 24
                            implicitWidth: connectBtnText.implicitWidth + 14
                            radius: 5
                            color: canConnect
                                ? (connectMouse.containsMouse ? root.theme.accent : root.theme.surfaceAlt)
                                : root.theme.surfaceAlt
                            opacity: canConnect ? 1.0 : 0.4
                            border.width: 1
                            border.color: canConnect && connectMouse.containsMouse ? root.theme.accent : root.theme.border

                            Text {
                                id: connectBtnText
                                anchors.centerIn: parent
                                text: "Connect"
                                font.family: root.theme.fontFamily
                                font.pixelSize: 10
                                font.bold: connectBtn.canConnect
                                color: connectBtn.canConnect && connectMouse.containsMouse
                                    ? root.theme.accentInk
                                    : (connectBtn.canConnect ? root.theme.text : root.theme.muted)
                            }

                            MouseArea {
                                id: connectMouse
                                anchors.fill: parent
                                enabled: connectBtn.canConnect
                                hoverEnabled: connectBtn.canConnect
                                cursorShape: connectBtn.canConnect ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (!root.backend) return;
                                    var cfg = root.backend.getHostConfig(modelData);
                                    root.backend.connectTailscaleSsh(
                                        cfg.hostname,
                                        cfg.ip,
                                        cfg.port,
                                        cfg.user,
                                        cfg.terminal,
                                        cfg.auth_type,
                                        cfg.key_path
                                    );
                                }
                            }
                        }

                        // Online / Offline Status
                        Text {
                            text: peerRow.isOnline ? "Online" : "Offline"
                            color: peerRow.isOnline ? root.theme.good : root.theme.muted
                            font.family: root.theme.fontFamily
                            font.pixelSize: 10
                            font.bold: peerRow.isOnline
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Settings Icon (to the right of online/offline status)
                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 13
                            color: settingsMouse.containsMouse ? root.theme.surfaceAlt : "transparent"
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: "󰒓"
                                font.family: root.theme.iconFont
                                font.pixelSize: 13
                                color: settingsMouse.containsMouse ? root.theme.accent : root.theme.muted
                            }

                            MouseArea {
                                id: settingsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openHostSettings(modelData)
                            }
                        }
                    }

                    HoverHandler {
                        id: peerRowHover
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 8
                Layout.topMargin: 4
                // Stays visible while the list is empty, so the filter can be
                // turned back off once every container is stopped.
                visible: root.containerKind !== ""
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    // "3 of 5" once the scroll window hides some rows.
                    text: root.shownContainers.length > root.visibleRows
                        ? "Containers · " + root.visibleRows + " of "
                            + root.shownContainers.length
                        : "Containers"
                    font.family: root.theme.fontFamily
                    font.pixelSize: 9
                    color: root.theme.muted
                }

                // Bulk actions, shown only while something is running.
                Text {
                    visible: root.runningCount > 0
                    text: "Restart all"
                    font.family: root.theme.fontFamily
                    font.pixelSize: 9
                    color: restartAllMouse.containsMouse ? root.theme.accent : root.theme.muted

                    MouseArea {
                        id: restartAllMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.restartAllContainers()
                    }
                }

                Text {
                    visible: root.runningCount > 0
                    text: "Stop all"
                    font.family: root.theme.fontFamily
                    font.pixelSize: 9
                    color: stopAllMouse.containsMouse ? root.theme.bad : root.theme.muted

                    MouseArea {
                        id: stopAllMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stopAllContainers()
                    }
                }

                // Reads as a filter, not a state: off means only running
                // containers are listed.
                Text {
                    text: "Show stopped"
                    font.family: root.theme.fontFamily
                    font.pixelSize: 9
                    color: root.theme.muted
                }

                Switch {
                    theme: root.theme
                    checked: root.showStopped
                    onToggled: root.showStopped = !root.showStopped
                }
            }

            Repeater {
                model: root.shownContainers

                delegate: Rectangle {
                    id: containerRow
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: 8
                    readonly property bool isRunning: modelData.state === "running"
                    color: containerRow.isRunning
                        ? Qt.rgba(root.theme.accent.r, root.theme.accent.g,
                                  root.theme.accent.b, 0.22)
                        : (containerHover.hovered ? root.theme.hover : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        // Clears the scroll bar on the right edge.
                        anchors.rightMargin: 12
                        spacing: 6

                        Text {
                            text: "󰏗"
                            font.family: root.theme.iconFont
                            font.pixelSize: 16
                            color: containerRow.isRunning ? root.theme.accent : root.theme.muted
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: containerRow.modelData.name
                                color: root.theme.text
                                font.family: root.theme.fontFamily
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.containerDetail(containerRow.modelData)
                                visible: text !== ""
                                color: root.theme.muted
                                font.family: root.theme.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: root.containerStateLabel(containerRow.modelData)
                            color: containerRow.isRunning ? root.theme.good : root.theme.muted
                            font.family: root.theme.fontFamily
                            font.pixelSize: 10
                            font.bold: containerRow.isRunning
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Start/stop toggle, then restart, logs and a shell.
                        IconButton {
                            theme: root.theme
                            glyph: containerRow.isRunning ? "󰓛" : "󰐊"
                            glyphColor: containerRow.isRunning ? root.theme.bad : root.theme.good
                            onClicked: root.toggleContainer(containerRow.modelData)
                        }

                        IconButton {
                            theme: root.theme
                            glyph: "󰜉"
                            enabled: containerRow.isRunning
                            onClicked: root.backend.restartContainer(
                                root.containerKind, containerRow.modelData.name)
                        }

                        IconButton {
                            id: logsButton
                            theme: root.theme
                            glyph: "󰈙"
                            // Plain click opens the captured file in a viewer,
                            // shift-click follows the stream, ctrl-click copies
                            // the file's path.
                            onClicked: function (mouse) {
                                var mods = mouse ? mouse.modifiers : 0;
                                var name = containerRow.modelData.name;
                                if (mods & Qt.ControlModifier) {
                                    Quickshell.clipboardText =
                                        root.backend.containerLogPath(root.containerKind, name);
                                    return;
                                }
                                root.backend.containerLogs(root.containerKind, name,
                                    (mods & Qt.ShiftModifier) !== 0);
                            }

                            Controls.ToolTip.delay: 500
                            Controls.ToolTip.visible: logsHover.hovered
                            Controls.ToolTip.text: "Logs · shift-click follows live"
                                + " · ctrl-click copies the path\n"
                                + root.backend.containerLogPath(
                                    root.containerKind, containerRow.modelData.name)

                            HoverHandler {
                                id: logsHover
                            }
                        }

                        IconButton {
                            theme: root.theme
                            glyph: "󰆍"
                            enabled: containerRow.isRunning
                            onClicked: root.backend.containerShell(
                                root.containerKind, containerRow.modelData.name)
                        }
                    }

                    HoverHandler {
                        id: containerHover
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.topMargin: 4
                visible: root.containerKind !== "" && root.shownContainers.length === 0
                text: root.showStopped ? "No containers" : "No containers running"
                font.family: root.theme.fontFamily
                font.pixelSize: 10
                color: root.theme.muted
            }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.topMargin: 2
                    visible: root.links.length === 0
                    text: root.hint
                    font.family: root.theme.fontFamily
                    font.pixelSize: 11
                    color: root.theme.muted
                }
            }
        }

        // The bridges and the container list share one window, so with a few
        // containers the last rows sit out of sight. The bar says so. Drawn by
        // hand: a ScrollBar attached to a plain Flickable stays invisible, and
        // one with a policy only appears while it is being dragged.
        Rectangle {
            visible: scroll.contentHeight > scroll.height
            anchors.right: parent.right
            width: 4
            radius: 2
            color: root.theme.muted
            opacity: 0.45
            y: scroll.height * scroll.visibleArea.yPosition
            height: Math.max(24, scroll.height * scroll.visibleArea.heightRatio)
        }
    }
}
