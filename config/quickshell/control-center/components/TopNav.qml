// Top navigation bar with horizontal tabs for major functional areas

import QtQuick
import QtQuick.Layouts

Item {
    id: nav

    property var theme: null
    property string activeTab: "home"
    signal tabSelected(string tabId)

    readonly property var tabs: [
        { "id": "home", "title": "Home", "icon": "󰋜" },
        { "id": "keybinds", "title": "Keybinds", "icon": "󰌌" },
        { "id": "settings", "title": "Settings", "icon": "󰒓" },
        { "id": "rules", "title": "Window Rules", "icon": "󰖲" },
        { "id": "startup", "title": "Startup", "icon": "󰐥" },
        { "id": "toggles", "title": "Toggles", "icon": "󰔡" },
        { "id": "monitors", "title": "Monitors", "icon": "󰍹" },
        { "id": "waybar", "title": "Waybar Editor", "icon": "󰹯" }
    ]

    implicitHeight: 46

    Rectangle {
        anchors.fill: parent
        color: theme ? theme.surface : "#1c1c20"
        border.width: 1
        border.color: theme ? theme.border : "#303036"
        radius: 8

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 6

            Repeater {
                model: nav.tabs
                delegate: Rectangle {
                    id: tabBtn
                    required property var modelData
                    Layout.fillHeight: true
                    Layout.preferredWidth: tabContent.implicitWidth + 24
                    radius: 6
                    color: nav.activeTab === modelData.id
                        ? (theme ? theme.accent : "#cba6f7")
                        : (tabMouse.containsMouse ? (theme ? theme.hover : "#282830") : "transparent")

                    RowLayout {
                        id: tabContent
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: tabBtn.modelData.icon
                            font.family: theme ? theme.iconFont : "sans-serif"
                            font.pixelSize: 14
                            color: nav.activeTab === tabBtn.modelData.id
                                ? (theme ? theme.accentInk : "#111111")
                                : (theme ? theme.text : "#ffffff")
                        }

                        Text {
                            text: tabBtn.modelData.title
                            font.family: theme ? theme.fontFamily : "sans-serif"
                            font.pixelSize: 12
                            font.bold: nav.activeTab === tabBtn.modelData.id
                            color: nav.activeTab === tabBtn.modelData.id
                                ? (theme ? theme.accentInk : "#111111")
                                : (theme ? theme.text : "#ffffff")
                        }

                        // Phase 2 badge
                        Rectangle {
                            visible: !!tabBtn.modelData.badge
                            implicitWidth: badgeText.implicitWidth + 8
                            implicitHeight: 16
                            radius: 8
                            color: nav.activeTab === tabBtn.modelData.id
                                ? (theme ? theme.accentInk : "#111111")
                                : (theme ? theme.warning : "#f9e2af")

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: tabBtn.modelData.badge || ""
                                font.pixelSize: 9
                                font.bold: true
                                color: nav.activeTab === tabBtn.modelData.id
                                    ? (theme ? theme.accent : "#cba6f7")
                                    : "#141416"
                            }
                        }
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: nav.tabSelected(tabBtn.modelData.id)
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Window Close button
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: closeMouse.containsMouse ? (theme ? theme.hover : "#303035") : "transparent"
                border.width: 1
                border.color: theme ? theme.border : "#35353d"

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 12
                    color: theme ? theme.text : "#ffffff"
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.quit()
                }
            }
        }
    }
}
