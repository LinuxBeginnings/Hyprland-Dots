// The popup itself: a layer-shell panel that drops down from the Waybar module
// in the top-right corner, with a tab per device type - Ethernet, Wi-Fi and
// Bluetooth, plus Tailscale, Docker and Podman when those are installed. Each
// tab owns the settings for its device type, and every state change goes
// through Backend -> QsNetworkPanel.sh.
//
// The surface fills the monitor while the panel is open, because that surface
// is what catches a click outside the card and closes it. While the panel is
// closed the surface collapses to a single pixel: a mapped window is what keeps
// the shell alive between toggles, and one that stayed monitor-sized would
// swallow every click aimed at the desktop.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: panel

    property Theme theme: Theme {}
    property Backend backend
    // Starts hidden: the Waybar module and the keybind open it through the IPC
    // handler, so starting the shell - or reloading it, which is what an
    // install does when it syncs this directory - never shows the panel on its
    // own.
    property bool shown: false
    // Kept as a key rather than an index: the tab list grows and shrinks with
    // the hardware and the installed tools.
    property string tab: "ethernet"
    // Distance from the right edge; adjusted to line up under the Waybar
    // module when it is opened from there.
    property int rightMargin: 10

    // Card geometry: wide enough for all six tabs on one line, inset from its
    // own border by cardPadding, and clearing the Waybar bar above it.
    readonly property int cardWidth: 620
    readonly property int cardPadding: 14
    readonly property int cardTopMargin: 44

    readonly property var tabs: {
        var list = [
            { key: "ethernet", label: "Ethernet", icon: "󰌘" },
            { key: "wifi", label: "Wi-Fi", icon: panel.backend.wifiEnabled ? "󰤨" : "󰤭" },
            { key: "bluetooth", label: "Bluetooth", icon: panel.backend.btEnabled ? "󰂯" : "󰂲" }
        ];
        if (panel.backend.hasTailscale)
            list.push({ key: "tailscale", label: "Tailscale", icon: "󰖂" });
        if (panel.backend.hasDocker)
            list.push({ key: "docker", label: "Docker", icon: "" });
        if (panel.backend.hasPodman)
            list.push({ key: "podman", label: "Podman", icon: "" });
        return list;
    }

    visible: true
    color: "transparent"
    exclusiveZone: 0
    // Anchored on all four edges while open, so the surface is the whole
    // monitor and the backdrop below can take a click outside the card; only
    // top/left while closed, so it shrinks to one pixel and stops taking input.
    anchors.top: true
    anchors.left: true
    anchors.right: panel.shown
    anchors.bottom: panel.shown
    implicitWidth: panel.shown ? 0 : 1
    implicitHeight: panel.shown ? 0 : 1

    // The surface stays mapped while hidden (collapsed to a single pixel) so
    // the shell keeps running between toggles - quickshell exits once no
    // window is left.
    WlrLayershell.layer: panel.shown ? WlrLayer.Overlay : WlrLayer.Background
    WlrLayershell.namespace: "quickshell:network-widget"
    // Only take the keyboard while a password is being typed, so the panel
    // never steals keys from the focused window.
    WlrLayershell.keyboardFocus: (panel.shown && wifiTab.prompting)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function tabExists(key) {
        for (var i = 0; i < tabs.length; i++) {
            if (tabs[i].key === key) return true;
        }
        return false;
    }

    // A device disappearing (docker stopped, tailscale down) must not leave the
    // panel on a tab that is no longer in the bar.
    onTabsChanged: {
        if (!panel.tabExists(panel.tab)) panel.tab = "ethernet";
    }

    // Layer-shell exposes no Waybar module geometry, but the panel is opened by
    // clicking the module, so the pointer is the anchor. It is only used while
    // the pointer sits on a screen edge (a bar); a keybind with the pointer in
    // the middle of the screen keeps the default corner.
    function applyPointer(text) {
        if (!screen) return;
        var match = /(-?\d+)\s*,\s*(-?\d+)/.exec(text);
        if (!match) return;
        var edge = 80;
        var pointerX = parseInt(match[1], 10);
        var pointerY = parseInt(match[2], 10);
        if (pointerX > edge && pointerX < screen.width - edge
                && pointerY > edge && pointerY < screen.height - edge)
            return;
        // Centre the card on the pointer, clamped to the screen edges.
        var target = screen.width - pointerX - Math.round(cardWidth / 2);
        var maxRight = Math.max(8, screen.width - cardWidth - 8);
        panel.rightMargin = Math.max(8, Math.min(maxRight, target));
    }

    function alignToPointer() {
        panel.rightMargin = 10;
        cursorProbe.running = true;
    }

    function syncVisibility() {
        backend.autoRefresh = shown;
        if (shown) {
            backend.error = "";
            panel.alignToPointer();
            backend.refresh();
        } else {
            wifiTab.cancelPrompt();
        }
    }

    Component.onCompleted: syncVisibility()
    onShownChanged: syncVisibility()

    function footerText() {
        if (backend.error !== "") return backend.error;
        if (!backend.loaded) return "Loading…";
        if (backend.busy) return "Working…";
        if (backend.note !== "") return backend.note;
        return "Click a network or device to connect or disconnect";
    }

    // The whole surface is the dismissal target: a click anywhere outside the
    // card closes the panel. It is declared before the card, so the card and
    // its rows keep their own clicks, and it is transparent - this is a
    // drop-down, not a modal frame like the keybinds panel.
    MouseArea {
        anchors.fill: parent
        visible: panel.shown
        onClicked: panel.shown = false
    }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: panel.cardTopMargin
        anchors.rightMargin: panel.rightMargin
        width: panel.cardWidth
        height: body.implicitHeight + 2 * panel.cardPadding
        visible: panel.shown
        radius: 14
        color: panel.theme.bg
        border.width: 1
        border.color: panel.theme.border

        // Swallow clicks on the card's own empty space, so they cannot reach
        // the backdrop behind it and close the panel.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: body
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: panel.cardPadding
            spacing: 8

            // ------------------------------------------------------------ header
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "󰖟"
                    font.family: panel.theme.iconFont
                    font.pixelSize: 16
                    color: panel.theme.accent
                }

                Text {
                    text: "Connections"
                    font.family: panel.theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    color: panel.theme.text
                    Layout.fillWidth: true
                }

                IconButton {
                    theme: panel.theme
                    glyph: "󰑐"
                    onClicked: {
                        backend.error = "";
                        backend.refresh();
                    }
                }

                IconButton {
                    theme: panel.theme
                    glyph: "󰅖"
                    onClicked: panel.shown = false
                }
            }

            // --------------------------------------------------------------- tabs
            // A Flow instead of a Row: with six tabs the bar wraps onto a second
            // line rather than squeezing the labels out.
            Flow {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: panel.tabs

                    delegate: TabButton {
                        required property var modelData
                        theme: panel.theme
                        icon: modelData.icon
                        label: modelData.label
                        active: panel.tab === modelData.key
                        onClicked: panel.tab = modelData.key
                    }
                }
            }

            // --------------------------------------------------------- tab content
            Item {
                id: tabArea
                Layout.fillWidth: true
                implicitHeight: {
                    switch (panel.tab) {
                    case "ethernet": return ethernetTab.height;
                    case "wifi": return wifiTab.height;
                    case "bluetooth": return bluetoothTab.height;
                    case "tailscale": return tailscaleTab.height;
                    case "docker": return dockerTab.height;
                    case "podman": return podmanTab.height;
                    }
                    return 0;
                }

                EthernetTab {
                    id: ethernetTab
                    width: tabArea.width
                    visible: panel.tab === "ethernet"
                    theme: panel.theme
                    backend: panel.backend
                }

                WifiTab {
                    id: wifiTab
                    width: tabArea.width
                    visible: panel.tab === "wifi"
                    theme: panel.theme
                    backend: panel.backend
                }

                BluetoothTab {
                    id: bluetoothTab
                    width: tabArea.width
                    visible: panel.tab === "bluetooth"
                    theme: panel.theme
                    backend: panel.backend
                }

                VirtualNetTab {
                    id: tailscaleTab
                    width: tabArea.width
                    visible: panel.tab === "tailscale"
                    theme: panel.theme
                    backend: panel.backend
                    links: panel.backend.tailscaleLinks
                    peers: panel.backend.tailscalePeers
                    exitNodes: panel.backend.exitNodes
                    icon: "󰖂"
                    title: "Tailscale"
                    subtitle: panel.backend.tailscaleState !== ""
                        ? panel.backend.tailscaleState : "No tailnet status"
                    showPower: true
                    powered: panel.backend.tailscaleRunning
                    onPowerToggled: panel.backend.setTailscale(!panel.backend.tailscaleRunning)
                    hint: "Tailscale is not running"
                }

                VirtualNetTab {
                    id: dockerTab
                    width: tabArea.width
                    visible: panel.tab === "docker"
                    theme: panel.theme
                    backend: panel.backend
                    links: panel.backend.dockerLinks
                    containers: panel.backend.dockerContainers
                    containerKind: "docker"
                    icon: ""
                    title: "Docker"
                    hint: "No Docker bridge"
                }

                VirtualNetTab {
                    id: podmanTab
                    width: tabArea.width
                    visible: panel.tab === "podman"
                    theme: panel.theme
                    backend: panel.backend
                    links: panel.backend.podmanLinks
                    containers: panel.backend.podmanContainers
                    containerKind: "podman"
                    icon: ""
                    title: "Podman"
                    hint: "No Podman bridge"
                }
            }

            // ------------------------------------------------------------ footer
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: panel.footerText()
                color: backend.error !== "" || backend.noteIsError
                    ? panel.theme.bad : panel.theme.muted
                font.family: panel.theme.fontFamily
                font.pixelSize: 10
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 3
            }
        }
    }

    // Pointer position for the drop-down alignment; absence of hyprctl just
    // leaves the default margin in place.
    Process {
        id: cursorProbe
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            id: cursorOutput
            onStreamFinished: panel.applyPointer(cursorOutput.text)
        }
    }
}
