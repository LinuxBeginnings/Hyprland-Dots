// Settings and location manager modal.

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: modal

    property var theme: null
    property var backend: null
    signal close()

    radius: 12
    color: theme ? theme.surface : "#232326"
    border.width: 1
    border.color: theme ? theme.border : "#3a3a3f"

    readonly property string unitMode: backend && backend.settings ? (backend.settings.unit || "c") : "c"

    Timer {
        id: searchDebounce
        interval: 350
        repeat: false
        onTriggered: {
            if (modal.backend && searchInput.text.trim().length >= 2) {
                modal.backend.searchLocations(searchInput.text.trim());
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "󰒓"
                font.family: modal.theme ? modal.theme.iconFont : "sans-serif"
                font.pixelSize: 15
                color: modal.theme ? modal.theme.accent : "#cba6f7"
            }

            Text {
                text: "Weather Settings"
                font.family: modal.theme ? modal.theme.fontFamily : "sans-serif"
                font.pixelSize: 14
                font.bold: true
                color: modal.theme ? modal.theme.text : "#ffffff"
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: 24
                implicitHeight: 24
                radius: 12
                color: closeBtnMouse.containsMouse ? (modal.theme ? modal.theme.hover : "#26262a") : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: modal.theme ? modal.theme.iconFont : "sans-serif"
                    font.pixelSize: 13
                    color: modal.theme ? modal.theme.text : "#ffffff"
                }

                MouseArea {
                    id: closeBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: modal.close()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: modal.theme ? modal.theme.border : "#3a3a3f"
        }

        // Section 1: Temperature Units Slider / Segmented Control
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Temperature Display Unit (Panel & Waybar)"
                font.family: modal.theme ? modal.theme.fontFamily : "sans-serif"
                font.pixelSize: 11
                font.bold: true
                color: modal.theme ? modal.theme.text : "#ffffff"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { label: "Celsius (°C)", mode: "c" },
                        { label: "Fahrenheit (°F)", mode: "f" },
                        { label: "Both (°C / °F)", mode: "both" }
                    ]

                    delegate: Rectangle {
                        id: unitBtn
                        readonly property bool isSelected: modal.unitMode === modelData.mode
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: 8
                        color: isSelected
                            ? (modal.theme ? modal.theme.accent : "#cba6f7")
                            : (unitBtnMouse.containsMouse ? (modal.theme ? modal.theme.hover : "#26262a") : (modal.theme ? modal.theme.surfaceAlt : "#2c2c30"))
                        border.width: 1
                        border.color: isSelected ? (modal.theme ? modal.theme.accent : "#cba6f7") : (modal.theme ? modal.theme.border : "#3a3a3f")

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: modal.theme ? modal.theme.fontFamily : "sans-serif"
                            font.pixelSize: 11
                            font.bold: unitBtn.isSelected
                            color: unitBtn.isSelected ? (modal.theme ? modal.theme.accentInk : "#161618") : (modal.theme ? modal.theme.text : "#ffffff")
                        }

                        MouseArea {
                            id: unitBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (modal.backend) modal.backend.setUnit(modelData.mode);
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: modal.theme ? modal.theme.border : "#3a3a3f"
        }

        // Section 2: Add Location Search
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Search & Add Location (City, State, Country or Lat, Long)"
                font.family: modal.theme ? modal.theme.fontFamily : "sans-serif"
                font.pixelSize: 11
                font.bold: true
                color: modal.theme ? modal.theme.text : "#ffffff"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 8
                    color: modal.theme ? modal.theme.surfaceAlt : "#2c2c30"
                    border.width: 1
                    border.color: searchInput.activeFocus ? (modal.theme ? modal.theme.accent : "#cba6f7") : (modal.theme ? modal.theme.border : "#3a3a3f")

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: modal.theme ? modal.theme.text : "#ffffff"
                        font.family: modal.theme ? modal.theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        selectionColor: modal.theme ? modal.theme.accent : "#cba6f7"
                        selectedTextColor: modal.theme ? modal.theme.accentInk : "#161618"
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: searchInput.text === ""
                            text: "e.g. Boston, Concord NH, Paris, or 42.36, -71.06…"
                            color: modal.theme ? modal.theme.muted : "#a9a3ab"
                            font: searchInput.font
                        }

                        onTextChanged: {
                            if (text.trim().length >= 2) {
                                searchDebounce.restart();
                            } else if (text.trim().length === 0) {
                                searchDebounce.stop();
                                if (modal.backend) {
                                    modal.backend.searchResults = [];
                                    modal.backend.lastSearchQuery = "";
                                }
                            }
                        }

                        onAccepted: {
                            searchDebounce.stop();
                            if (modal.backend) modal.backend.searchLocations(text);
                        }
                    }
                }

                Rectangle {
                    implicitWidth: 70
                    implicitHeight: 34
                    radius: 8
                    color: searchBtnMouse.containsMouse ? (modal.theme ? modal.theme.hover : "#26262a") : (modal.theme ? modal.theme.surfaceAlt : "#2c2c30")
                    border.width: 1
                    border.color: modal.theme ? modal.theme.border : "#3a3a3f"

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: modal.backend && modal.backend.searching ? "󰑐" : "󰍉"
                            font.family: modal.theme ? modal.theme.iconFont : "sans-serif"
                            font.pixelSize: 11
                            color: modal.theme ? modal.theme.text : "#ffffff"
                        }
                        Text {
                            text: "Search"
                            font.family: modal.theme ? modal.theme.fontFamily : "sans-serif"
                            font.pixelSize: 11
                            color: modal.theme ? modal.theme.text : "#ffffff"
                        }
                    }

                    MouseArea {
                        id: searchBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            searchDebounce.stop();
                            if (modal.backend) modal.backend.searchLocations(searchInput.text);
                        }
                    }
                }
            }

            // Search Feedback / Progress Banner
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 28
                radius: 6
                visible: (modal.backend && (modal.backend.searching || modal.backend.busy)) ||
                         (modal.backend && !modal.backend.searching && modal.backend.lastSearchQuery !== "" && modal.backend.searchResults.length === 0)
                color: modal.theme ? modal.theme.surfaceAlt : "#2c2c30"
                border.width: 1
                border.color: modal.theme ? modal.theme.border : "#3a3a3f"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: modal.backend && modal.backend.busy ? "󰑐" : (modal.backend && modal.backend.searching ? "󰑐" : "󰅖")
                        font.family: modal.theme ? modal.theme.iconFont : "sans-serif"
                        font.pixelSize: 12
                        color: modal.backend && (modal.backend.busy || modal.backend.searching) ? (modal.theme ? modal.theme.accent : "#cba6f7") : (modal.theme ? modal.theme.bad : "#f38ba8")
                    }

                    Text {
                        text: {
                            if (modal.backend && modal.backend.busy) return "Updating location & fetching forecast…";
                            if (modal.backend && modal.backend.searching) return "Searching for '" + searchInput.text.trim() + "'…";
                            return "No locations found for '" + (modal.backend ? modal.backend.lastSearchQuery : "") + "'. Try city name or lat, lon.";
                        }
                        font.family: modal.theme ? modal.theme.fontFamily : "sans-serif"
                        font.pixelSize: 11
                        color: modal.theme ? modal.theme.muted : "#a9a3ab"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // Search Results List
            ListView {
                id: resultsList
                visible: modal.backend && modal.backend.searchResults.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(130, modal.backend ? modal.backend.searchResults.length * 32 : 0)
                clip: true
                spacing: 3
                model: modal.backend ? modal.backend.searchResults : []

                delegate: Rectangle {
                    width: resultsList.width
                    height: 30
                    radius: 6
                    color: resMouse.containsMouse ? (modal.theme ? modal.theme.hover : "#26262a") : (modal.theme ? modal.theme.surfaceAlt : "#2c2c30")
                    border.width: 1
                    border.color: modal.theme ? modal.theme.border : "#3a3a3f"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: "󰍎"
                            font.family: modal.theme ? modal.theme.iconFont : "sans-serif"
                            font.pixelSize: 11
                            color: modal.theme ? modal.theme.accent : "#cba6f7"
                        }

                        Text {
                            text: modelData.name || ""
                            font.family: modal.theme ? modal.theme.fontFamily : "sans-serif"
                            font.pixelSize: 11
                            color: modal.theme ? modal.theme.text : "#ffffff"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            implicitWidth: addBtnText.implicitWidth + 12
                            implicitHeight: 22
                            radius: 11
                            color: modal.theme ? modal.theme.accent : "#cba6f7"

                            Text {
                                id: addBtnText
                                anchors.centerIn: parent
                                text: "+ Add"
                                font.family: modal.theme ? modal.theme.fontFamily : "sans-serif"
                                font.pixelSize: 10
                                font.bold: true
                                color: modal.theme ? modal.theme.accentInk : "#161618"
                            }
                        }
                    }

                    MouseArea {
                        id: resMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (modal.backend) {
                                modal.backend.addLocation(modelData.name, modelData.lat, modelData.lon);
                                searchInput.text = "";
                                modal.backend.searchResults = [];
                                modal.backend.lastSearchQuery = "";
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: modal.theme ? modal.theme.border : "#3a3a3f"
        }

        // Section 3: Configured Locations
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            Text {
                text: "Configured Locations (Only one can be Auto-located)"
                font.family: modal.theme ? modal.theme.fontFamily : "sans-serif"
                font.pixelSize: 11
                font.bold: true
                color: modal.theme ? modal.theme.text : "#ffffff"
            }

            ListView {
                id: locsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: modal.backend ? modal.backend.locations : []

                delegate: Rectangle {
                    id: locItem
                    readonly property bool isCurrentActive: modal.backend && modal.backend.settings && modal.backend.settings.active_location_id === modelData.id
                    width: locsList.width
                    height: 38
                    radius: 8
                    color: isCurrentActive ? (modal.theme ? modal.theme.surface : "#232326") : (modal.theme ? modal.theme.surfaceAlt : "#2c2c30")
                    border.width: isCurrentActive ? 2 : 1
                    border.color: isCurrentActive ? (modal.theme ? modal.theme.accent : "#cba6f7") : (modal.theme ? modal.theme.border : "#3a3a3f")

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (modal.backend) modal.backend.setActiveLocation(modelData.id);
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Rectangle {
                            visible: locItem.isCurrentActive
                            implicitWidth: activeLabel.implicitWidth + 10
                            implicitHeight: 20
                            radius: 10
                            color: modal.theme ? modal.theme.accent : "#cba6f7"

                            Text {
                                id: activeLabel
                                anchors.centerIn: parent
                                text: "Active"
                                font.family: modal.theme ? modal.theme.fontFamily : "sans-serif"
                                font.pixelSize: 9
                                font.bold: true
                                color: modal.theme ? modal.theme.accentInk : "#161618"
                            }
                        }

                        Text {
                            text: modelData.name || "Location"
                            font.family: modal.theme ? modal.theme.fontFamily : "sans-serif"
                            font.pixelSize: 11
                            font.bold: true
                            color: modal.theme ? modal.theme.text : "#ffffff"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Auto-locate toggle button
                        Rectangle {
                            implicitWidth: autoPill.implicitWidth + 12
                            implicitHeight: 24
                            radius: 12
                            color: modelData.is_auto ? (modal.theme ? modal.theme.accent : "#cba6f7") : (modal.theme ? modal.theme.hover : "#26262a")

                            RowLayout {
                                id: autoPill
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "󰍎"
                                    font.family: modal.theme ? modal.theme.iconFont : "sans-serif"
                                    font.pixelSize: 11
                                    color: modelData.is_auto ? (modal.theme ? modal.theme.accentInk : "#161618") : (modal.theme ? modal.theme.muted : "#a9a3ab")
                                }
                                Text {
                                    text: "Auto"
                                    font.family: modal.theme ? modal.theme.fontFamily : "sans-serif"
                                    font.pixelSize: 10
                                    font.bold: modelData.is_auto
                                    color: modelData.is_auto ? (modal.theme ? modal.theme.accentInk : "#161618") : (modal.theme ? modal.theme.text : "#ffffff")
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (modal.backend) modal.backend.setAutoLocate(modelData.id, !modelData.is_auto);
                                }
                            }
                        }

                        // Delete button (visible if more than 1 location)
                        Rectangle {
                            visible: modal.backend && modal.backend.locations.length > 1
                            implicitWidth: 24
                            implicitHeight: 24
                            radius: 12
                            color: delMouse.containsMouse ? (modal.theme ? modal.theme.bad : "#f38ba8") : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰩺"
                                font.family: modal.theme ? modal.theme.iconFont : "sans-serif"
                                font.pixelSize: 12
                                color: delMouse.containsMouse ? "#ffffff" : (modal.theme ? modal.theme.muted : "#a9a3ab")
                            }

                            MouseArea {
                                id: delMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (modal.backend) modal.backend.removeLocation(modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
