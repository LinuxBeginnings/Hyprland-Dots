// Vertical subcategory navigation sidebar for active major tab

import QtQuick
import QtQuick.Layouts

Item {
    id: subnav

    property var theme: null
    property var categories: []
    property string activeSubcategory: ""
    signal subcategorySelected(string categoryId)

    implicitWidth: 200

    Rectangle {
        anchors.fill: parent
        color: theme ? theme.surface : "#1c1c20"
        border.width: 1
        border.color: theme ? theme.border : "#303036"
        radius: 8

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            ListView {
                id: catList
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: subnav.categories
                spacing: 3
                clip: true

                delegate: Rectangle {
                    id: catBtn
                    required property var modelData
                    width: catList.width
                    implicitHeight: 36
                    radius: 6
                    color: subnav.activeSubcategory === modelData.id
                        ? (theme ? theme.surfaceAlt : "#2a2a32")
                        : (catMouse.containsMouse ? (theme ? theme.hover : "#24242a") : "transparent")
                    border.width: subnav.activeSubcategory === modelData.id ? 1 : 0
                    border.color: theme ? theme.accent : "#cba6f7"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: catBtn.modelData.icon || "•"
                            font.family: theme ? theme.iconFont : "sans-serif"
                            font.pixelSize: 13
                            color: subnav.activeSubcategory === catBtn.modelData.id
                                ? (theme ? theme.accent : "#cba6f7")
                                : (theme ? theme.muted : "#9a949f")
                        }

                        Text {
                            Layout.fillWidth: true
                            text: catBtn.modelData.title
                            font.family: theme ? theme.fontFamily : "sans-serif"
                            font.pixelSize: 12
                            font.bold: subnav.activeSubcategory === catBtn.modelData.id
                            color: subnav.activeSubcategory === catBtn.modelData.id
                                ? (theme ? theme.text : "#ffffff")
                                : (theme ? theme.muted : "#c0bac4")
                            elide: Text.ElideRight
                        }

                        // Optional count badge
                        Text {
                            visible: catBtn.modelData.count !== undefined
                            text: catBtn.modelData.count !== undefined ? String(catBtn.modelData.count) : ""
                            font.pixelSize: 10
                            color: theme ? theme.muted : "#888888"
                        }
                    }

                    MouseArea {
                        id: catMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: subnav.subcategorySelected(catBtn.modelData.id)
                    }
                }
            }
        }
    }
}
