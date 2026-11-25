// Main UI component for Waybar Font & Size Settings

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    property var theme: null
    property var backend: null

    property string selectedFont: backend ? backend.currentFont : "JetBrainsMono Nerd Font"
    property int selectedSize: backend ? backend.currentSize : 14
    property string searchQuery: ""

    onBackendChanged: {
        if (backend) {
            selectedFont = backend.currentFont;
            selectedSize = backend.currentSize;
        }
    }

    Connections {
        target: backend
        function onCurrentFontChanged() {
            if (!backend.busy) {
                root.selectedFont = backend.currentFont;
            }
        }
        function onCurrentSizeChanged() {
            if (!backend.busy) {
                root.selectedSize = backend.currentSize;
            }
        }
    }

    readonly property var filteredFonts: {
        if (!backend || !backend.allFonts) return [];
        var q = searchQuery.toLowerCase().trim();
        if (q === "") return backend.allFonts;
        var res = [];
        for (var i = 0; i < backend.allFonts.length; i++) {
            var item = backend.allFonts[i];
            if (item.toLowerCase().indexOf(q) !== -1) {
                res.push(item);
            }
        }
        return res;
    }

    readonly property var sizePresets: [10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24]

    Rectangle {
        anchors.fill: parent
        color: theme ? theme.bg : "#161618"
        radius: 12
        border.width: 1
        border.color: theme ? theme.border : "#3a3a3f"
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 4
                    height: 20
                    radius: 2
                    color: theme ? theme.accent : "#cba6f7"
                }

                Text {
                    text: "Waybar Font & Scaling Settings"
                    font.family: theme ? theme.fontFamily : "sans-serif"
                    font.pixelSize: 16
                    font.bold: true
                    color: theme ? theme.text : "#ffffff"
                }

                Item { Layout.fillWidth: true }

                // Close (X) button
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: closeArea.containsMouse ? (theme ? theme.hover : "#2c2c30") : "transparent"
                    border.width: 1
                    border.color: theme ? theme.border : "#3a3a3f"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 12
                        color: theme ? theme.text : "#ffffff"
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.quit()
                    }
                }
            }

            // Size Selection Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Font Size:"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 13
                        font.bold: true
                        color: theme ? theme.text : "#ffffff"
                    }

                    // Stepper: - button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 6
                        color: minusArea.containsMouse ? (theme ? theme.hover : "#333338") : (theme ? theme.surface : "#222225")
                        border.width: 1
                        border.color: theme ? theme.border : "#44444a"

                        Text {
                            anchors.centerIn: parent
                            text: "−"
                            font.bold: true
                            font.pixelSize: 14
                            color: theme ? theme.text : "#ffffff"
                        }

                        MouseArea {
                            id: minusArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.selectedSize > 8) root.selectedSize -= 1;
                            }
                        }
                    }

                    // Numeric display badge
                    Rectangle {
                        width: 52
                        height: 28
                        radius: 6
                        color: theme ? theme.surfaceAlt : "#2a2a2e"
                        border.width: 1
                        border.color: theme ? theme.accent : "#cba6f7"

                        Text {
                            anchors.centerIn: parent
                            text: root.selectedSize + " px"
                            font.family: theme ? theme.fontFamily : "sans-serif"
                            font.pixelSize: 12
                            font.bold: true
                            color: theme ? theme.accent : "#cba6f7"
                        }
                    }

                    // Stepper: + button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 6
                        color: plusArea.containsMouse ? (theme ? theme.hover : "#333338") : (theme ? theme.surface : "#222225")
                        border.width: 1
                        border.color: theme ? theme.border : "#44444a"

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            font.bold: true
                            font.pixelSize: 14
                            color: theme ? theme.text : "#ffffff"
                        }

                        MouseArea {
                            id: plusArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.selectedSize < 48) root.selectedSize += 1;
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Default: " + (backend ? backend.defaultSize : 14) + "px"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        color: theme ? theme.muted : "#888888"
                    }
                }

                // Preset Chips Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: root.sizePresets
                        delegate: Rectangle {
                            id: chip
                            required property int modelData
                            implicitWidth: 32
                            implicitHeight: 24
                            radius: 4
                            color: root.selectedSize === modelData
                                ? (theme ? theme.accent : "#cba6f7")
                                : (chipMouse.containsMouse ? (theme ? theme.hover : "#333338") : (theme ? theme.surface : "#222225"))
                            border.width: 1
                            border.color: root.selectedSize === modelData
                                ? (theme ? theme.accent : "#cba6f7")
                                : (theme ? theme.border : "#3a3a3f")

                            Text {
                                anchors.centerIn: parent
                                text: String(chip.modelData)
                                font.family: theme ? theme.fontFamily : "sans-serif"
                                font.pixelSize: 11
                                font.bold: root.selectedSize === chip.modelData
                                color: root.selectedSize === chip.modelData
                                    ? (theme ? theme.accentInk : "#111111")
                                    : (theme ? theme.text : "#ffffff")
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedSize = chip.modelData
                            }
                        }
                    }
                }
            }

            // Search Box for Fonts
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 6
                color: theme ? theme.surface : "#202024"
                border.width: 1
                border.color: searchInput.activeFocus ? (theme ? theme.accent : "#cba6f7") : (theme ? theme.border : "#3a3a3f")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: ""
                        font.family: theme ? theme.iconFont : "sans-serif"
                        font.pixelSize: 12
                        color: theme ? theme.muted : "#888888"
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        color: theme ? theme.text : "#ffffff"
                        clip: true
                        onTextChanged: root.searchQuery = text

                        Text {
                            anchors.fill: parent
                            text: "Search font family name..."
                            font: parent.font
                            color: theme ? theme.muted : "#666666"
                            visible: !searchInput.text && !searchInput.activeFocus
                        }
                    }

                    // Clear search button
                    Text {
                        visible: searchInput.text.length > 0
                        text: "✕"
                        font.pixelSize: 11
                        color: theme ? theme.muted : "#888888"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                root.searchQuery = "";
                            }
                        }
                    }
                }
            }

            // Scrollable Font List
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 6
                color: theme ? theme.surface : "#1f1f22"
                border.width: 1
                border.color: theme ? theme.border : "#3a3a3f"
                clip: true

                ListView {
                    id: fontListView
                    anchors.fill: parent
                    anchors.margins: 4
                    model: root.filteredFonts
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        width: 6
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Rectangle {
                        id: rowDelegate
                        required property string modelData
                        width: fontListView.width
                        implicitHeight: 32
                        radius: 4
                        color: root.selectedFont === modelData
                            ? (theme ? theme.surfaceAlt : "#2a2a30")
                            : (rowMouse.containsMouse ? (theme ? theme.hover : "#26262a") : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            // Selection indicator dot / checkmark
                            Text {
                                text: root.selectedFont === rowDelegate.modelData ? "✓" : " "
                                font.bold: true
                                font.pixelSize: 12
                                color: theme ? theme.accent : "#cba6f7"
                            }

                            // Standard readable font name
                            Text {
                                text: rowDelegate.modelData
                                font.family: theme ? theme.fontFamily : "sans-serif"
                                font.pixelSize: 12
                                font.bold: root.selectedFont === rowDelegate.modelData
                                color: root.selectedFont === rowDelegate.modelData
                                    ? (theme ? theme.accent : "#cba6f7")
                                    : (theme ? theme.text : "#ffffff")
                                elide: Text.ElideRight
                                Layout.preferredWidth: parent.width * 0.45
                            }

                            // Sample preview in actual font
                            Text {
                                text: "12:34 󰍛 󰕾 Sample"
                                font.family: rowDelegate.modelData
                                font.pixelSize: 12
                                color: theme ? theme.muted : "#999999"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedFont = rowDelegate.modelData;
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.filteredFonts.length === 0
                        text: backend && !backend.fontsLoaded ? "Loading fonts..." : "No matching fonts found"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        color: theme ? theme.muted : "#888888"
                    }
                }
            }

            // Live Waybar Preview Card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: 8
                color: theme ? theme.surfaceAlt : "#252528"
                border.width: 1
                border.color: theme ? theme.border : "#3a3a3f"
                clip: true

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 16

                    Text {
                        text: "Preview:"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        font.bold: true
                        color: theme ? theme.muted : "#888888"
                    }

                    Text {
                        text: "12:45 PM  |   42%  |   58%  |   65%  |  󰖐 21°C  |  "
                        font.family: root.selectedFont
                        font.pixelSize: Math.min(24, Math.max(10, root.selectedSize))
                        color: theme ? theme.text : "#ffffff"
                    }
                }
            }

            // Status message
            RowLayout {
                Layout.fillWidth: true
                visible: backend && backend.statusMessage.length > 0
                spacing: 6

                Text {
                    text: backend && backend.statusType === "error" ? "⚠" : (backend && backend.statusType === "success" ? "✓" : "ℹ")
                    font.pixelSize: 11
                    color: backend && backend.statusType === "error"
                        ? (theme ? theme.bad : "#f38ba8")
                        : (backend && backend.statusType === "success" ? (theme ? theme.good : "#a6e3a1") : (theme ? theme.info : "#89b4fa"))
                }

                Text {
                    Layout.fillWidth: true
                    text: backend ? backend.statusMessage : ""
                    font.family: theme ? theme.fontFamily : "sans-serif"
                    font.pixelSize: 11
                    color: backend && backend.statusType === "error"
                        ? (theme ? theme.bad : "#f38ba8")
                        : (backend && backend.statusType === "success" ? (theme ? theme.good : "#a6e3a1") : (theme ? theme.muted : "#aaaaaa"))
                    elide: Text.ElideRight
                }
            }

            // Action Buttons Bar (Restore Defaults, Cancel, Apply, Close)
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Restore Defaults button
                Rectangle {
                    implicitWidth: 120
                    implicitHeight: 32
                    radius: 6
                    color: restoreMouse.containsMouse ? (theme ? theme.hover : "#303035") : (theme ? theme.surface : "#222226")
                    border.width: 1
                    border.color: theme ? theme.border : "#44444a"

                    Text {
                        anchors.centerIn: parent
                        text: "Restore Defaults"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        font.bold: true
                        color: theme ? theme.warning : "#f9e2af"
                    }

                    MouseArea {
                        id: restoreMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (backend) {
                                root.selectedFont = backend.defaultFont;
                                root.selectedSize = backend.defaultSize;
                                backend.restore();
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Cancel button
                Rectangle {
                    implicitWidth: 72
                    implicitHeight: 32
                    radius: 6
                    color: cancelMouse.containsMouse ? (theme ? theme.hover : "#303035") : (theme ? theme.surface : "#222226")
                    border.width: 1
                    border.color: theme ? theme.border : "#44444a"

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        color: theme ? theme.muted : "#aaaaaa"
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (backend) {
                                root.selectedFont = backend.currentFont;
                                root.selectedSize = backend.currentSize;
                            }
                            Qt.quit();
                        }
                    }
                }

                // Apply button (applies, restarts waybar, does NOT close app)
                Rectangle {
                    implicitWidth: 80
                    implicitHeight: 32
                    radius: 6
                    color: applyMouse.containsMouse
                        ? (theme ? Qt.lighter(theme.accent, 1.1) : "#d9b8ff")
                        : (theme ? theme.accent : "#cba6f7")

                    Text {
                        anchors.centerIn: parent
                        text: backend && backend.busy ? "Applying..." : "Apply"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        font.bold: true
                        color: theme ? theme.accentInk : "#111111"
                    }

                    MouseArea {
                        id: applyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !backend || !backend.busy
                        onClicked: {
                            if (backend) {
                                backend.apply(root.selectedFont, root.selectedSize);
                            }
                        }
                    }
                }

                // Close button
                Rectangle {
                    implicitWidth: 72
                    implicitHeight: 32
                    radius: 6
                    color: closeBtnMouse.containsMouse ? (theme ? theme.hover : "#303035") : (theme ? theme.surface : "#222226")
                    border.width: 1
                    border.color: theme ? theme.border : "#44444a"

                    Text {
                        anchors.centerIn: parent
                        text: "Close"
                        font.family: theme ? theme.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        color: theme ? theme.text : "#ffffff"
                    }

                    MouseArea {
                        id: closeBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.quit()
                    }
                }
            }
        }
    }
}
