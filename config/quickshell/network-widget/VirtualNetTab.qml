// Tab for the links NetworkManager does not manage: Tailscale, Docker and
// Podman. Each link shows its state and every address it carries. The
// Tailscale tab adds up/down, the exit node picker and suggestion, the Docker
// and Podman tabs add their containers with live CPU and memory use.

import QtQuick
import QtQuick.Layouts

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
    // Tailscale only: the on/off switch in the heading.
    property bool showPower: false
    property bool powered: false
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

    function containerSubtitle() {
        if (root.containerKind === "") return "";
        var running = 0;
        var stopped = 0;
        for (var i = 0; i < root.containers.length; i++) {
            if (root.containers[i].state === "running") running++;
            else stopped++;
        }
        return root.showStopped
            ? running + " running · " + stopped + " stopped"
            : running + " running";
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

        Text {
            visible: root.containerKind !== ""
            text: "Stopped"
            font.family: root.theme.fontFamily
            font.pixelSize: 9
            color: root.theme.muted
        }

        Switch {
            theme: root.theme
            visible: root.containerKind !== ""
            checked: root.showStopped
            onToggled: root.showStopped = !root.showStopped
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
        visible: root.showPower

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
    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(content.implicitHeight, 340)
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

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.topMargin: 4
                visible: root.containerKind !== "" && root.shownContainers.length > 0
                text: "Containers"
                font.family: root.theme.fontFamily
                font.pixelSize: 9
                color: root.theme.muted
            }

            Repeater {
                model: root.shownContainers

                delegate: RowItem {
                    required property var modelData
                    theme: root.theme
                    Layout.fillWidth: true
                    icon: "󰏗"
                    label: modelData.name
                    detail: root.containerDetail(modelData)
                    trailing: modelData.runtime
                    highlighted: modelData.state === "running"
                    dimmed: modelData.state !== "running"
                    onActivated: root.toggleContainer(modelData)
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
}
