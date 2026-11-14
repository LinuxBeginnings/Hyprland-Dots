// Modal for configuring per-host Tailscale SSH settings and connection testing.

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: modal

    property Theme theme: Theme {}
    property Backend backend
    property var peer: null // { name, ip, online, os, self }

    signal close()

    radius: 12
    color: theme.surface
    border.width: 1
    border.color: theme.border

    // Host configuration fields
    property string currentHostKey: peer ? (peer.ip || peer.name) : ""
    property var initialConfig: peer && backend ? backend.getHostConfig(peer) : null

    property string hostname: initialConfig ? initialConfig.hostname : ""
    property string ip: initialConfig ? initialConfig.ip : ""
    property string port: initialConfig ? String(initialConfig.port) : "22"
    property string user: initialConfig ? initialConfig.user : (backend ? backend.currentUser : "")
    property string terminal: initialConfig ? initialConfig.terminal : (backend ? backend.defaultTerminal : "kitty")
    property string authType: initialConfig ? initialConfig.auth_type : "key"
    property string keyPath: initialConfig ? initialConfig.key_path : ""

    property bool customTerminalActive: false
    property bool customKeyActive: false
    property string testStatusMsg: ""
    property bool testStatusSuccess: false

    function resetFromPeer() {
        if (!peer || !backend) return;
        var cfg = backend.getHostConfig(peer);
        modal.hostname = cfg.hostname;
        modal.ip = cfg.ip;
        modal.port = String(cfg.port);
        modal.user = cfg.user;
        modal.terminal = cfg.terminal;
        modal.authType = cfg.auth_type;
        modal.keyPath = cfg.key_path;
        modal.testStatusMsg = "";

        // Check if terminal is in detected list
        var inTermList = false;
        for (var i = 0; i < backend.detectedTerminals.length; i++) {
            if (backend.detectedTerminals[i] === cfg.terminal) {
                inTermList = true;
                break;
            }
        }
        modal.customTerminalActive = !inTermList && cfg.terminal !== "";

        // Check if key is in detected list
        var inKeyList = false;
        for (var k = 0; k < backend.detectedSshKeys.length; k++) {
            if (backend.detectedSshKeys[k] === cfg.key_path) {
                inKeyList = true;
                break;
            }
        }
        modal.customKeyActive = !inKeyList && cfg.key_path !== "";
    }

    onPeerChanged: resetFromPeer()

    function isTerminalValid(name) {
        if (!name || name.trim() === "") return false;
        if (!backend) return true;
        for (var i = 0; i < backend.detectedTerminals.length; i++) {
            if (backend.detectedTerminals[i] === name.trim()) return true;
        }
        return false;
    }

    function isKeyValid(path) {
        if (!path || path.trim() === "") return false;
        if (!backend) return true;
        for (var i = 0; i < backend.detectedSshKeys.length; i++) {
            if (backend.detectedSshKeys[i] === path.trim()) return true;
        }
        return path.trim().length > 3;
    }

    function save() {
        if (!peer || !backend) return;
        var p = parseInt(portInput.text.trim(), 10);
        if (isNaN(p) || p <= 0) p = 22;

        var term = modal.customTerminalActive ? customTermInput.text.trim() : modal.terminal;
        var key = modal.customKeyActive ? customKeyInput.text.trim() : modal.keyPath;

        var cfg = {
            hostname: hostnameInput.text.trim() || peer.name,
            ip: ipInput.text.trim() || peer.ip,
            port: p,
            user: userInput.text.trim() || backend.currentUser,
            terminal: term || backend.defaultTerminal,
            auth_type: modal.authType,
            key_path: key
        };

        backend.saveTailscaleHost(modal.currentHostKey, cfg);
        modal.close();
    }

    function runTest() {
        if (!backend || backend.testingConnection) return;
        modal.testStatusMsg = "Testing reachability...";
        modal.testStatusSuccess = false;

        var p = parseInt(portInput.text.trim(), 10);
        if (isNaN(p) || p <= 0) p = 22;

        var key = modal.customKeyActive ? customKeyInput.text.trim() : modal.keyPath;

        backend.testTailscaleConnection(
            hostnameInput.text.trim() || (peer ? peer.name : ""),
            ipInput.text.trim() || (peer ? peer.ip : ""),
            p,
            userInput.text.trim() || backend.currentUser,
            modal.authType,
            key,
            function (result) {
                modal.testStatusSuccess = result.success;
                modal.testStatusMsg = result.message;
            }
        );
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "󰒓"
                font.family: modal.theme.iconFont
                font.pixelSize: 15
                color: modal.theme.accent
            }

            Text {
                text: "Host SSH Settings"
                font.family: modal.theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                color: modal.theme.text
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: 24
                implicitHeight: 24
                radius: 12
                color: closeMouse.containsMouse ? modal.theme.hover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: modal.theme.iconFont
                    font.pixelSize: 13
                    color: modal.theme.text
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: modal.close()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: modal.theme.border
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: formContent.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: formContent
                width: parent.width
                spacing: 8

                // Row: Hostname and IP
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Hostname"
                            font.family: modal.theme.fontFamily
                            font.pixelSize: 10
                            color: modal.theme.muted
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: 6
                            color: modal.theme.surfaceAlt
                            border.width: 1
                            border.color: hostnameInput.activeFocus ? modal.theme.accent : modal.theme.border

                            TextInput {
                                id: hostnameInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: modal.theme.text
                                font.family: modal.theme.fontFamily
                                font.pixelSize: 11
                                text: modal.hostname
                                selectByMouse: true
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "IP Address"
                            font.family: modal.theme.fontFamily
                            font.pixelSize: 10
                            color: modal.theme.muted
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: 6
                            color: modal.theme.surfaceAlt
                            border.width: 1
                            border.color: ipInput.activeFocus ? modal.theme.accent : modal.theme.border

                            TextInput {
                                id: ipInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: modal.theme.text
                                font.family: modal.theme.fontFamily
                                font.pixelSize: 11
                                text: modal.ip
                                selectByMouse: true
                            }
                        }
                    }
                }

                // Row: Port and Username
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        Layout.preferredWidth: 90
                        spacing: 2

                        Text {
                            text: "SSH Port"
                            font.family: modal.theme.fontFamily
                            font.pixelSize: 10
                            color: modal.theme.muted
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: 6
                            color: modal.theme.surfaceAlt
                            border.width: 1
                            border.color: portInput.activeFocus ? modal.theme.accent : modal.theme.border

                            TextInput {
                                id: portInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: modal.theme.text
                                font.family: modal.theme.fontFamily
                                font.pixelSize: 11
                                text: modal.port
                                selectByMouse: true
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Username"
                            font.family: modal.theme.fontFamily
                            font.pixelSize: 10
                            color: modal.theme.muted
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: 6
                            color: modal.theme.surfaceAlt
                            border.width: 1
                            border.color: userInput.activeFocus ? modal.theme.accent : modal.theme.border

                            TextInput {
                                id: userInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: modal.theme.text
                                font.family: modal.theme.fontFamily
                                font.pixelSize: 11
                                text: modal.user
                                selectByMouse: true
                            }
                        }
                    }
                }

                // Terminal Emulator selection with validation
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Terminal Emulator"
                            font.family: modal.theme.fontFamily
                            font.pixelSize: 10
                            color: modal.theme.muted
                            Layout.fillWidth: true
                        }

                        Text {
                            property string activeTerm: modal.customTerminalActive ? customTermInput.text.trim() : modal.terminal
                            property bool installed: modal.isTerminalValid(activeTerm)
                            text: installed ? "✓ Installed" : "✗ Not found in PATH"
                            font.family: modal.theme.fontFamily
                            font.pixelSize: 9
                            color: installed ? modal.theme.good : modal.theme.bad
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: modal.backend ? modal.backend.detectedTerminals : []

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool isSelected: !modal.customTerminalActive && modal.terminal === modelData
                                implicitWidth: termLabel.implicitWidth + 14
                                implicitHeight: 24
                                radius: 5
                                color: isSelected ? modal.theme.accent : (termMouse.containsMouse ? modal.theme.hover : modal.theme.surfaceAlt)
                                border.width: 1
                                border.color: isSelected ? modal.theme.accent : modal.theme.border

                                Text {
                                    id: termLabel
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: modal.theme.fontFamily
                                    font.pixelSize: 10
                                    color: isSelected ? modal.theme.accentInk : modal.theme.text
                                }

                                MouseArea {
                                    id: termMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        modal.customTerminalActive = false;
                                        modal.terminal = modelData;
                                    }
                                }
                            }
                        }

                        // Custom option button
                        Rectangle {
                            readonly property bool isSelected: modal.customTerminalActive
                            implicitWidth: customLabel.implicitWidth + 14
                            implicitHeight: 24
                            radius: 5
                            color: isSelected ? modal.theme.accent : (customMouse.containsMouse ? modal.theme.hover : modal.theme.surfaceAlt)
                            border.width: 1
                            border.color: isSelected ? modal.theme.accent : modal.theme.border

                            Text {
                                id: customLabel
                                anchors.centerIn: parent
                                text: "+ Custom..."
                                font.family: modal.theme.fontFamily
                                font.pixelSize: 10
                                color: isSelected ? modal.theme.accentInk : modal.theme.text
                            }

                            MouseArea {
                                id: customMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: modal.customTerminalActive = true
                            }
                        }
                    }

                    // Custom terminal input field
                    Rectangle {
                        visible: modal.customTerminalActive
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: 6
                        color: modal.theme.surfaceAlt
                        border.width: 1
                        border.color: customTermInput.activeFocus ? modal.theme.accent : modal.theme.border

                        TextInput {
                            id: customTermInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            color: modal.theme.text
                            font.family: modal.theme.fontFamily
                            font.pixelSize: 11
                            text: modal.terminal
                            selectByMouse: true
                        }
                    }
                }

                // Authentication method
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "SSH Authentication Method"
                        font.family: modal.theme.fontFamily
                        font.pixelSize: 10
                        color: modal.theme.muted
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: 6
                            readonly property bool isSelected: modal.authType === "key"
                            color: isSelected ? modal.theme.accent : (authKeyMouse.containsMouse ? modal.theme.hover : modal.theme.surfaceAlt)
                            border.width: 1
                            border.color: isSelected ? modal.theme.accent : modal.theme.border

                            Text {
                                anchors.centerIn: parent
                                text: "󰌆  SSH Key (Default)"
                                font.family: modal.theme.fontFamily
                                font.pixelSize: 11
                                font.bold: parent.isSelected
                                color: parent.isSelected ? modal.theme.accentInk : modal.theme.text
                            }

                            MouseArea {
                                id: authKeyMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: modal.authType = "key"
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: 6
                            readonly property bool isSelected: modal.authType === "password"
                            color: isSelected ? modal.theme.accent : (authPassMouse.containsMouse ? modal.theme.hover : modal.theme.surfaceAlt)
                            border.width: 1
                            border.color: isSelected ? modal.theme.accent : modal.theme.border

                            Text {
                                anchors.centerIn: parent
                                text: "󰌾  Password (Interactive)"
                                font.family: modal.theme.fontFamily
                                font.pixelSize: 11
                                font.bold: parent.isSelected
                                color: parent.isSelected ? modal.theme.accentInk : modal.theme.text
                            }

                            MouseArea {
                                id: authPassMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: modal.authType = "password"
                            }
                        }
                    }
                }

                // SSH Key selector (visible when authType === "key")
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: modal.authType === "key"

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Select SSH Private Key"
                            font.family: modal.theme.fontFamily
                            font.pixelSize: 10
                            color: modal.theme.muted
                            Layout.fillWidth: true
                        }

                        Text {
                            property string activeKey: modal.customKeyActive ? customKeyInput.text.trim() : modal.keyPath
                            property bool valid: modal.isKeyValid(activeKey)
                            text: valid ? "✓ Key verified" : "✗ Invalid key path"
                            font.family: modal.theme.fontFamily
                            font.pixelSize: 9
                            color: valid ? modal.theme.good : modal.theme.bad
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: modal.backend ? modal.backend.detectedSshKeys : []

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool isSelected: !modal.customKeyActive && modal.keyPath === modelData
                                implicitWidth: keyLabel.implicitWidth + 14
                                implicitHeight: 24
                                radius: 5
                                color: isSelected ? modal.theme.accent : (keyMouse.containsMouse ? modal.theme.hover : modal.theme.surfaceAlt)
                                border.width: 1
                                border.color: isSelected ? modal.theme.accent : modal.theme.border

                                function shortPath(p) {
                                    var home = Quickshell.env("HOME") || "";
                                    if (home !== "" && p.indexOf(home) === 0) {
                                        return "~" + p.substring(home.length);
                                    }
                                    return p;
                                }

                                Text {
                                    id: keyLabel
                                    anchors.centerIn: parent
                                    text: shortPath(modelData)
                                    font.family: modal.theme.fontFamily
                                    font.pixelSize: 10
                                    color: isSelected ? modal.theme.accentInk : modal.theme.text
                                }

                                MouseArea {
                                    id: keyMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        modal.customKeyActive = false;
                                        modal.keyPath = modelData;
                                    }
                                }
                            }
                        }

                        Rectangle {
                            readonly property bool isSelected: modal.customKeyActive
                            implicitWidth: customKeyLabel.implicitWidth + 14
                            implicitHeight: 24
                            radius: 5
                            color: isSelected ? modal.theme.accent : (customKeyMouse.containsMouse ? modal.theme.hover : modal.theme.surfaceAlt)
                            border.width: 1
                            border.color: isSelected ? modal.theme.accent : modal.theme.border

                            Text {
                                id: customKeyLabel
                                anchors.centerIn: parent
                                text: "+ Custom path..."
                                font.family: modal.theme.fontFamily
                                font.pixelSize: 10
                                color: isSelected ? modal.theme.accentInk : modal.theme.text
                            }

                            MouseArea {
                                id: customKeyMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: modal.customKeyActive = true
                            }
                        }
                    }

                    Rectangle {
                        visible: modal.customKeyActive
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: 6
                        color: modal.theme.surfaceAlt
                        border.width: 1
                        border.color: customKeyInput.activeFocus ? modal.theme.accent : modal.theme.border

                        TextInput {
                            id: customKeyInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            color: modal.theme.text
                            font.family: modal.theme.fontFamily
                            font.pixelSize: 11
                            text: modal.keyPath
                            selectByMouse: true
                        }
                    }
                }
            }
        }

        // Test Connection Feedback Bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: modal.testStatusMsg !== ""

            Text {
                text: modal.testStatusSuccess ? "󰄬" : "󰅖"
                font.family: modal.theme.iconFont
                font.pixelSize: 12
                color: modal.testStatusSuccess ? modal.theme.good : modal.theme.bad
            }

            Text {
                Layout.fillWidth: true
                text: modal.testStatusMsg
                font.family: modal.theme.fontFamily
                font.pixelSize: 10
                color: modal.testStatusSuccess ? modal.theme.good : modal.theme.bad
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: modal.theme.border
        }

        // Bottom Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Test connection button
            Rectangle {
                implicitHeight: 30
                implicitWidth: testBtnText.implicitWidth + 20
                radius: 6
                color: modal.theme.surfaceAlt
                border.width: 1
                border.color: modal.theme.border

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "󰙵"
                        font.family: modal.theme.iconFont
                        font.pixelSize: 12
                        color: modal.theme.accent
                    }
                    Text {
                        id: testBtnText
                        text: modal.backend && modal.backend.testingConnection ? "Testing..." : "Test Connection"
                        font.family: modal.theme.fontFamily
                        font.pixelSize: 11
                        color: modal.theme.text
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modal.runTest()
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // Cancel
            Rectangle {
                implicitHeight: 30
                implicitWidth: 70
                radius: 6
                color: modal.theme.surfaceAlt
                border.width: 1
                border.color: modal.theme.border

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.family: modal.theme.fontFamily
                    font.pixelSize: 11
                    color: modal.theme.text
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modal.close()
                }
            }

            // Save
            Rectangle {
                implicitHeight: 30
                implicitWidth: 70
                radius: 6
                color: modal.theme.accent

                Text {
                    anchors.centerIn: parent
                    text: "Save"
                    font.family: modal.theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: modal.theme.accentInk
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modal.save()
                }
            }
        }
    }
}
