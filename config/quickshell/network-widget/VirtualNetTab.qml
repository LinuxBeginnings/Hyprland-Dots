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

                delegate: RowItem {
                    required property var modelData
                    theme: root.theme
                    Layout.fillWidth: true
                    icon: "󰢬"
                    label: root.peerLabel(modelData)
                    detail: root.peerDetail(modelData)
                    trailing: modelData.online ? "Online" : "Offline"
                    dimmed: !modelData.online
                    interactive: false
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
