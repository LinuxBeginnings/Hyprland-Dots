// Horizontal location tabs for switching between configured weather locations.

import QtQuick
import QtQuick.Layouts

RowLayout {
    id: tabs

    property var theme: null
    property var locations: []
    property string activeId: ""
    property bool sideBySideMode: false

    signal selectLocation(string locId)
    signal toggleSideBySide()
    signal openSettings()

    spacing: 6

    Repeater {
        model: tabs.locations

        delegate: Rectangle {
            id: tabItem

            readonly property bool isActive: modelData.id === tabs.activeId
            implicitWidth: tabRow.implicitWidth + 16
            implicitHeight: 28
            radius: 14
            color: isActive
                ? (tabs.theme ? tabs.theme.accent : "#cba6f7")
                : (tabMouse.containsMouse ? (tabs.theme ? tabs.theme.hover : "#26262a") : (tabs.theme ? tabs.theme.surfaceAlt : "#2c2c30"))
            border.width: 1
            border.color: isActive ? (tabs.theme ? tabs.theme.accent : "#cba6f7") : (tabs.theme ? tabs.theme.border : "#3a3a3f")

            RowLayout {
                id: tabRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    visible: Boolean(modelData.is_auto)
                    text: "󰍎"
                    font.family: tabs.theme ? tabs.theme.iconFont : "sans-serif"
                    font.pixelSize: 11
                    color: tabItem.isActive
                        ? (tabs.theme ? tabs.theme.accentInk : "#161618")
                        : (tabs.theme ? tabs.theme.accent : "#cba6f7")
                }

                Text {
                    text: modelData.name || "Location"
                    font.family: tabs.theme ? tabs.theme.fontFamily : "sans-serif"
                    font.pixelSize: 11
                    font.bold: tabItem.isActive
                    color: tabItem.isActive
                        ? (tabs.theme ? tabs.theme.accentInk : "#161618")
                        : (tabs.theme ? tabs.theme.text : "#ffffff")
                    elide: Text.ElideRight
                    Layout.maximumWidth: 140
                }
            }

            MouseArea {
                id: tabMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: tabs.selectLocation(modelData.id)
            }
        }
    }

    // Side-by-Side toggle button (available when multiple locations exist)
    Rectangle {
        visible: tabs.locations.length > 1
        implicitWidth: 28
        implicitHeight: 28
        radius: 14
        color: tabs.sideBySideMode
            ? (tabs.theme ? tabs.theme.accent : "#cba6f7")
            : (sbsMouse.containsMouse ? (tabs.theme ? tabs.theme.hover : "#26262a") : "transparent")
        border.width: 1
        border.color: tabs.sideBySideMode ? (tabs.theme ? tabs.theme.accent : "#cba6f7") : (tabs.theme ? tabs.theme.border : "#3a3a3f")

        Text {
            anchors.centerIn: parent
            text: "󰨇"
            font.family: tabs.theme ? tabs.theme.iconFont : "sans-serif"
            font.pixelSize: 12
            color: tabs.sideBySideMode ? (tabs.theme ? tabs.theme.accentInk : "#161618") : (tabs.theme ? tabs.theme.text : "#ffffff")
        }

        MouseArea {
            id: sbsMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tabs.toggleSideBySide()
        }
    }

    // Add / Settings button
    Rectangle {
        implicitWidth: 28
        implicitHeight: 28
        radius: 14
        color: addMouse.containsMouse ? (tabs.theme ? tabs.theme.hover : "#26262a") : "transparent"
        border.width: 1
        border.color: tabs.theme ? tabs.theme.border : "#3a3a3f"

        Text {
            anchors.centerIn: parent
            text: "󰐕"
            font.family: tabs.theme ? tabs.theme.iconFont : "sans-serif"
            font.pixelSize: 13
            color: tabs.theme ? tabs.theme.text : "#ffffff"
        }

        MouseArea {
            id: addMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tabs.openSettings()
        }
    }
}
